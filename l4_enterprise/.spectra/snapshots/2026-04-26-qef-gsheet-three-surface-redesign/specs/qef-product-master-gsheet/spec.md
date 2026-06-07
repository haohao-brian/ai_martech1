# qef-product-master-gsheet Specification

## Purpose

QEF_DESIGN's Amazon product master (`company_product_master`) resolution capability. Defines how SKU↔ASIN tuples and supporting product metadata are integrated from multiple sources (Gsheets `company_product_master` / `SKU to ASIN`, KEYS.xlsx, SKUtoASIN.xlsx, `df_amz_product_master` catalogue, `df_amz_sales___transformed` sales), how conflicts are arbitrated (default per `source_priority`, with per-field overrides per `priority_per_class` for fields classified as `System-Sourced` / `System-Suggested` per MP155), and how anomalies / drift surface to the Status Gsheet for business review.

This capability is the foundation for the QEF 3-Surface architecture (Master Gsheet = human input; Status Gsheet = system observations; DuckDB = source of truth). It applies the MP155 Three Categories model to the `amz_asin` field (System-Sourced from sales transactions and product catalogue; business retains override via KEYS.xlsx + Master Gsheet trial annotation).

Capability scope: Amazon platform only (non-Amazon companies see graceful degradation — readers return empty data.frames when their respective tables / files are absent).

## Requirements

### Requirement: Sales source in resolver

The `fn_resolve_company_product_master.R` resolver SHALL provide a fifth source named `sales` that derives `(sku, marketplace, amz_asin)` tuples from the `df_amz_sales___transformed` table. This source MUST aggregate observations using the most-frequent (mode) `amz_asin` per `(sku, marketplace)` pair within a configurable lookback window. The default lookback window MUST be 90 days; companies MAY override via `app_config.yaml` key `etl_sources.amz_sales_lookback_days`.

The reader MUST tolerate Amazon's raw column naming: when the `amz_asin` column is absent the reader SHALL accept `asin` (or `ASIN`) as a synonym and canonicalise to `amz_asin` in the returned data.frame. Similarly, when the `marketplace` column is absent but `sales_channel` is present, the reader SHALL derive `marketplace` from `sales_channel` (e.g. `Amazon.com` → `amz_us`, `Amazon.ca` → `amz_ca`, `Amazon.com.mx` → `amz_mx`); rows whose `sales_channel` does not map to a known Amazon storefront (e.g. `Non-Amazon`) SHALL be excluded.

#### Scenario: Sales source produces SKU-ASIN tuples from transformed sales table

- **WHEN** the resolver runs against a project where `transformed_data.duckdb` exists and `df_amz_sales___transformed` contains `sku`, `amz_asin` (or alias `asin`), `marketplace` (or alias `sales_channel`), and a date column among `order_date` / `purchase_date` / `time`
- **THEN** the resolver SHALL include rows from the sales source with `source_origin = "sales"`, AND each row's `amz_asin` MUST equal the most-frequent ASIN observed for that `(sku, marketplace)` pair within the lookback window

#### Scenario: Sales reader derives marketplace from sales_channel when canonical column absent

- **GIVEN** `df_amz_sales___transformed` has columns `sku`, `asin`, `sales_channel`, `purchase_date` (no `amz_asin`, no `marketplace`)
- **AND** sales rows include `sales_channel = 'Amazon.com'`, `'Amazon.ca'`, and `'Non-Amazon'`
- **WHEN** sales source reads
- **THEN** rows are returned with `marketplace = 'amz_us'` (from Amazon.com) and `marketplace = 'amz_ca'` (from Amazon.ca), AND `Non-Amazon` rows are excluded, AND the `amz_asin` column is populated from the `asin` source column

##### Example: mode aggregation chooses dominant ASIN over noise

- **GIVEN** sales rows for SKU=`F23A-BK`, marketplace=`amz_us` over the last 90 days: 100 rows with `amz_asin=B07ABC123`, 1 row with `amz_asin=B07XYZ999` (data entry typo on a single returned order)
- **WHEN** sales source aggregates
- **THEN** the sales source row for `(F23A-BK, amz_us)` SHALL have `amz_asin = B07ABC123` (mode wins; single-row noise excluded)


---
### Requirement: Sales source graceful degradation

The sales source reader MUST gracefully degrade when prerequisites are absent: when `transformed_data.duckdb` does not exist, OR when `df_amz_sales___transformed` table does not exist in that database, the reader SHALL return an empty data.frame and emit a single informational `message()`. The reader MUST NOT call `stop()` for these cases. However, when the table exists but a required column is missing, the reader MUST `stop()` with an actionable error identifying the missing column.

#### Scenario: Missing transformed database does not break resolver

- **WHEN** the resolver runs in a fresh project where `transformed_data.duckdb` has not yet been created
- **THEN** the sales source reader SHALL return an empty data.frame, emit one informational message, AND the resolver MUST continue with the remaining sources without error

#### Scenario: Schema mismatch fails fast

- **WHEN** the sales source reader finds `df_amz_sales___transformed` exists but is missing the `amz_asin` column
- **THEN** the reader MUST `stop()` with an error message naming the missing column AND the table location


---
### Requirement: Catalogue source in resolver

The `fn_resolve_company_product_master.R` resolver SHALL provide a sixth source named `catalogue` that reads `(sku, marketplace, amz_asin)` tuples from the `df_amz_product_master` table in `raw_data.duckdb`. This table is produced by the existing `amz_ETL_product_profiles_0IM.R` script (which unions all `product_profile_<line>` Gsheet tabs); the catalogue source MUST NOT rebuild or modify this table. The catalogue source MUST deduplicate on `(sku, marketplace)`: when a duplicate is encountered the reader SHALL emit a warning naming the SKU + marketplace and SHALL retain the first observed row.

#### Scenario: Catalogue source produces tuples from the unioned product master table

- **WHEN** the resolver runs against a project where `raw_data.duckdb` exists and `df_amz_product_master` contains rows with `sku`, `marketplace`, and `amz_asin` columns
- **THEN** the resolver SHALL include rows from the catalogue source with `source_origin = "catalogue"`, AND each `(sku, marketplace)` pair MUST appear at most once in the catalogue source output

#### Scenario: Duplicate (sku, marketplace) emits warning and keeps first row

- **GIVEN** `df_amz_product_master` has two rows for SKU=`F23A-BK`, marketplace=`amz_us` with `amz_asin=B07AAA111` and `amz_asin=B07BBB222` respectively
- **WHEN** the catalogue source reader runs
- **THEN** the reader SHALL emit one warning naming `(F23A-BK, amz_us)`, AND the catalogue source output SHALL contain exactly one row for that pair with `amz_asin=B07AAA111` (first observed)


---
### Requirement: Catalogue source graceful degradation

The catalogue source reader MUST gracefully degrade when prerequisites are absent: when `raw_data.duckdb` does not exist, OR when `df_amz_product_master` table does not exist in that database, OR when the table exists but lacks the `sku` column (ASIN-keyed metadata-only catalogue, e.g. when `amz_ETL_product_profiles_0IM.R` does not preserve SKU mapping), the reader SHALL return an empty data.frame and emit a single informational `message()`. The reader MUST NOT call `stop()` for these cases. When the table exists but the `marketplace` or `amz_asin` column is missing, the reader MUST `stop()` with an actionable error identifying the missing column.

#### Scenario: Missing catalogue table does not break resolver

- **WHEN** the resolver runs in a project where `raw_data.duckdb` exists but `amz_ETL_product_profiles_0IM.R` has never been run (so `df_amz_product_master` does not exist)
- **THEN** the catalogue source reader SHALL return an empty data.frame, emit one informational message, AND the resolver MUST continue with the remaining sources without error

#### Scenario: ASIN-only catalogue (no sku column) does not break resolver

- **GIVEN** `df_amz_product_master` exists with columns `amz_asin`, `marketplace`, `product_line_id`, `brand`, `product_name` — but no `sku` column (catalogue is ASIN-keyed metadata only, not a SKU↔ASIN map)
- **WHEN** the resolver runs
- **THEN** the catalogue source reader SHALL return an empty data.frame, emit one informational message instructing the operator to enhance `amz_ETL_product_profiles_0IM.R` to preserve SKU, AND the resolver MUST continue with the remaining sources without error


---
### Requirement: Sales and catalogue priority placement in source_priority and per-class

The `product_master_fields.yaml` configuration MUST place `catalogue` and `sales` as the **last two** entries in the global `source_priority` list (so Human-Decided fields fall back to these sources only when all other sources are NA), AND MUST place `sales` followed by `catalogue` as the **first two** entries in `priority_per_class.System-Sourced` (so System-Sourced fields prefer sales transactions over catalogue intent over file/Gsheet sources).

#### Scenario: Human-Decided field with sales and catalogue at the end of default priority

- **GIVEN** field `cost` configured as Human-Decided (default; no `field_class` entry)
- **AND** rows from sales (cost=NA), catalogue (cost=NA), keys_xlsx (cost=5.50), and gsheet_master (cost=5.80) for the same `(sku, marketplace)` pair
- **WHEN** arbitration runs
- **THEN** the resolved `cost` SHALL be 5.80 (gsheet_master wins per default `source_priority`); placement of sales and catalogue at the end of the priority list MUST NOT affect Human-Decided fields

#### Scenario: System-Sourced field with sales-then-catalogue first priority

- **GIVEN** field `amz_asin` configured as `field_class: System-Sourced`
- **AND** rows from sales (`amz_asin=B07ABC123`), catalogue (`amz_asin=B07CAT000`), keys_xlsx (`amz_asin=B07ZZZ000`), and gsheet_master (`amz_asin=B07YYY555`) for the same `(sku, marketplace)` pair
- **WHEN** arbitration runs
- **THEN** the resolved `amz_asin` SHALL be `B07ABC123` (sales wins per `priority_per_class.System-Sourced`)

#### Scenario: System-Sourced field falls back to catalogue when sales is empty

- **GIVEN** field `amz_asin` configured as `field_class: System-Sourced`
- **AND** sales source has zero rows for the `(sku, marketplace)` pair (newly listed SKU not yet sold)
- **AND** catalogue (`amz_asin=B07CAT000`), keys_xlsx (`amz_asin=B07ZZZ000`) both have values
- **WHEN** arbitration runs
- **THEN** the resolved `amz_asin` SHALL be `B07CAT000` (catalogue wins because sales is empty; catalogue beats xlsx per `priority_per_class.System-Sourced`)


---
### Requirement: amz_asin enabled as System-Sourced in shared yaml

The shared `product_master_fields.yaml` MUST set `field_class.amz_asin = System-Sourced`, activating sales-derived ASIN for all 5 companies that consume the shared yaml. Companies without an active Amazon platform MUST experience zero behavior change because their `try_read_sales` returns an empty data.frame (per Sales source graceful degradation requirement above).

#### Scenario: Company without Amazon platform unaffected

- **WHEN** a company whose `app_config.yaml` does not enable the `amz` platform runs the company product master ETL
- **THEN** the sales source SHALL return zero rows, AND the resolved master MUST be byte-identical to the pre-Track-C baseline output for that company

#### Scenario: Company with Amazon platform sees sales-derived ASIN winners

- **WHEN** a company with active Amazon platform runs the company product master ETL, AND that company's KEYS.xlsx records `amz_asin=B07XLSX001` for SKU=`SKU1`, while sales transactions consistently observe `amz_asin=B07SALES99`
- **THEN** the resolved master row for `SKU1` SHALL have `amz_asin = B07SALES99` (sales wins per System-Sourced policy), AND the arbitrator SHALL emit an `OVERRIDE[System-Sourced]` log entry naming both values


---
### Requirement: System-Sourced override surfaced in anomalies output

When the arbitrator overrides a default-priority winner using `priority_per_class.System-Sourced` (i.e., sales ASIN beats xlsx ASIN), the arbitrator MUST record the event in `attr(result, "system_sourced_override_log")` as a data.frame with columns `sku`, `marketplace`, `field`, `default_value`, `default_source`, `system_sourced_value`, `system_sourced_source`. The `fn_detect_anomalies` function MUST consume this attribute and emit one anomaly row per logged event into the anomalies output, with `suggested_action` text routing the business to update KEYS.xlsx (or accept the new sales value).

#### Scenario: Override log captures the conflict

- **WHEN** sales source contains `amz_asin=B07SALES99` for `(SKU1, amz_us)`, and keys_xlsx contains `amz_asin=B07XLSX001` for the same pair, and `field_class.amz_asin = System-Sourced`
- **THEN** the arbitrator result MUST carry `attr(result, "system_sourced_override_log")` containing a row with `sku=SKU1`, `field=amz_asin`, `default_value=B07XLSX001`, `default_source=keys_xlsx`, `system_sourced_value=B07SALES99`, `system_sourced_source=sales`

#### Scenario: Anomalies output includes system_sourced_override row routing business to xlsx

- **WHEN** `fn_detect_anomalies()` receives a resolved master with a non-empty `system_sourced_override_log`
- **THEN** the anomalies output SHALL contain one row per logged event, AND the `suggested_action` text MUST mention both the sales-observed value AND the xlsx-recorded value AND instruct the business to either update KEYS.xlsx or annotate the SKU as trial in Master Gsheet


---
### Requirement: Audit script reports sales-vs-xlsx delta

The `QEF_DESIGN/scripts/audit_qef_master_drift.R` script MUST add a `sales_value` column to its CSV output, populated with the sales-source-observed `amz_asin` value (or NA when no sales rows exist for the SKU). The CSV MUST include rows where `sales_value` differs from `xlsx_value`, even when there is no Gsheet conflict.

#### Scenario: Audit row includes sales-vs-xlsx delta

- **WHEN** the audit script runs against a project where SKU=`SKU2` has `keys_xlsx` value `amz_asin=B07XLSX111` and `sales` source value `amz_asin=B07SALES22`, with no Gsheet entry
- **THEN** the audit CSV SHALL contain a row for `SKU2` with `xlsx_value=B07XLSX111`, `sales_value=B07SALES22`, `delta_indicator=DIFFERS`

