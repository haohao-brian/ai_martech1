# Glue Bridge Onboarding

Operational guide for adding a new prerawdata source via the glue layer
(spectra change `glue-layer-prerawdata-bridge`, issue #489).

> **Audience**: developers and 工讀生 onboarding a new company / new
> platform / new spreadsheet export. If you've never used the glue
> layer before, read top-to-bottom. If you've shipped a bridge before,
> jump straight to the §"Authoring a new bridge" checklist.

## Mental model

```
prerawdata source                        canonical raw layer
(GSheet / xlsx / CSV / API)              (DDL-enforced, MP102 v1.2)
        |                                          ^
        |                                          |
        v                                          |
     read into R data.frame  --[ glue bridge ]-->  INSERT
                                ^
                                |
                  shared/global_scripts/01_db/raw_schema/
                  _authoring/bridges/{COMPANY}/{platform}/
                  {source}.bridge.yaml
```

The bridge yaml is a **per-company config**. The interpreter
(`fn_glue_bridge` in `05_etl_utils/glue/`) is **shared** across all
companies. Bridge yamls are committed; the interpreter is committed;
together they form a deterministic, auditable, LLM-free runtime path.

## Phase 5 PoC results — QEF_DESIGN amz sales

This is the first bridge shipped under #489. The findings below are
generally applicable to subsequent bridges.

### Source

- File: `QEF_DESIGN/data/local_data/rawdata_QEF_DESIGN/amazon_sales/{YYYY-M}/{YYYY-MM}.xlsx`
- Format: Amazon Seller Central All Orders Report (v2 export, 41 columns)
- Sample tested: `2024-1/2024-01.xlsx` (8,492 rows)
- Schema fingerprint (sha256, full read): `6f4d53e1fd0ce2f88e718b1dd87ccb5a9...`

### Result table — 2024-01 sample

| Pipeline | Output table | Row count | Notes |
|---|---|---|---|
| Existing ETL 0IM | `df_amazon_sales` (raw_data.duckdb) | 8,227 | Includes 7,878 Shipped + 349 Cancelled |
| Glue bridge | `df_amz_sales___raw` (canonical) | 0 written / 8,132 attempted | Pre_filter excludes 360 Cancelled; 12 rows fail validation |

### Reconciliation

| Source rows | 8,492 |
|---|---|
| − pre_filter excludes (Cancelled / Pending) | − 360 |
| = bridge attempted | 8,132 |
| − validation errors (real data quality issues) | − 12 |
| = clean rows that *would* INSERT under lenient_mode | 8,120 |

The remaining 95-row gap vs. existing ETL (8,227 vs 8,132) is because
existing ETL keeps cancelled orders in `df_amazon_sales`. The
canonical schema (per MP102) treats `sales` as completed transactions
only — cancelled orders belong in `df_amz_orders___raw` with
`order_status = "Cancelled"`. **This is a contract clarification, not
a bug.**

### Validation errors observed (12 rows / 0.15%)

| Field | Error | Count | Root cause |
|---|---|---|---|
| `total_amount` | NOT NULL | 4 | Source row has NA total despite Shipped status |
| `unit_price` | NOT NULL | 4 | Same rows as above |
| `quantity` | range (>= 1) | 2 | Shipped orders with quantity 0 (rare; ~0.02% of source) |
| `amz_amazon_order_id` | pattern_mismatch | 2 | Order IDs don't match `^[0-9]{3}-[0-9]{7}-[0-9]{7}$` |

These are **real data quality issues** in the upstream source, not
bridge mapping bugs. They were silently accepted by existing ETL.

## Authoring a new bridge — checklist

### 1. Inspect source schema

```r
library(readxl)  # or googlesheets4 / readr / httr depending on source_type
df <- read_excel(source_file)  # full read; do NOT use n_max for fingerprint
source("shared/global_scripts/05_etl_utils/glue/fn_hash_prerawdata_schema.R")
fp <- hash_prerawdata_schema(
  column_names = colnames(df),
  column_types = vapply(df, function(x) class(x)[1], character(1))
)
print(fp$value)  # save this; you'll paste into bridge yaml
```

### 2. Locate canonical schema

- Read `01_db/raw_schema/_authoring/core_schemas.yaml` for required fields.
- Read `01_db/raw_schema/_authoring/platform_extensions/{platform}_extensions.yaml`
  for platform-specific fields.
- For each required canonical field, identify which prerawdata column
  maps to it (use the schema's `aliases:` list to cross-reference).

### 3. Choose mapping strategy per canonical field

Decision tree:

```
Does prerawdata have a 1:1 column?
├── Yes, same value shape          -> from_column: "<name>"
├── Yes, value needs normalization -> from_column + value_map
└── No
    ├── Constant for this company    -> use_value: <literal>
    ├── Derived from other fields    -> apply_fallback: true (relies on
    │                                   schema's derive_from rule)
    └── Genuinely missing            -> apply_fallback: true + accept
                                        sentinel; document gap in
                                        review_notes
```

### 4. Add pre_filter for non-canonical rows (optional)

If the source contains rows that don't belong in the canonical
datatype (e.g., cancelled orders in a `sales` source), add:

```yaml
pre_filter:
  - column: "<source-col>"
    exclude_values: ["<value-1>", "<value-2>"]
```

Pre_filter runs before column_mapping. Cheap, deterministic,
documented in the bridge yaml.

### 5. Fill required metadata

| Field | Value |
|---|---|
| `prerawdata_source.schema_fingerprint.value` | from step 1 |
| `prerawdata_source.schema_fingerprint.fingerprinted_against` | sample file path |
| `prerawdata_source.schema_fingerprint.fingerprinted_at` | ISO 8601 UTC |
| `generated_at` | ISO 8601 UTC |
| `generated_by` | `"hand-written"` or `"glue-bridge skill v1.0"` |
| `reviewed_by` | **real human identifier** (rejected if "AI", "TBD", "REQUIRES_HUMAN_REVIEW") |

### 6. Run the bridge against a sample

```r
source("shared/global_scripts/05_etl_utils/glue/fn_glue_bridge.R")
# (also source the four sibling fn_*.R files)
con <- DBI::dbConnect(duckdb::duckdb(), ":memory:")
ddl <- paste(readLines(
  "shared/global_scripts/01_db/raw_schema/_generated/platforms/<platform>/<datatype>.sql"
), collapse = "\n")
DBI::dbExecute(con, ddl)

result <- fn_glue_bridge(
  company = "<COMPANY>",
  platform = "<platform>",
  source = "<source>",
  prerawdata = df,
  target_con = con
)
# result$n_input_rows / n_output_rows / n_errors / errors
```

If `result$n_errors > 0`, inspect `result$errors` and decide:

- **Mapping bug** (wrong column name / wrong value_map) → fix bridge yaml, re-run.
- **Source data quality issue** → document in `review_notes`; consider
  `pre_filter` if the bad rows have a stable shape.
- **Schema constraint mismatch** → if many rows fail and the constraint
  is wrong-by-design, escalate to amend MP102 (Phase 1 binding gives
  you the discipline; do not unilaterally relax constraints in the
  bridge).

### 7. Commit

Commit the bridge yaml. The commit message MUST include:

```
[FEAT] glue bridge: <COMPANY> <platform> <source> (#489 Phase N)

Verified: bridge mapping reviewed by <real human>.
Refs #489
```

## Common gotchas (Phase 5 lessons)

### Gotcha #1 — fingerprint instability from partial reads

readxl/readr type-infer from the first N rows by default
(`guess_max = 1000`). Sparse columns (e.g., `gift-wrap-price` in
QEF amz data) flip from `logical` to `numeric` once a non-NA value
appears later. Always fingerprint with a full file read.

### Gotcha #2 — "Amazon"/"Merchant" vs "AFN"/"MFN"

Amazon's All Orders Report uses long-form names; Amazon SP-API uses
short codes. Canonical schema follows SP-API. Use `value_map:` to
translate.

### Gotcha #3 — buyer email PII

Amazon redacts buyer email in All Orders Report. Don't promise the
canonical schema's `customer_email` field a real address — fall back
to empty-string sentinel and document.

### Gotcha #4 — total_amount derivation

If source has `quantity` and `unit_price` but no line subtotal,
delegate to schema's `derive_from: "unit_price * quantity"` via
`apply_fallback: true`. The interpreter handles this rule
specifically.

### Gotcha #5 — cancelled rows leak into "sales"

Cancelled orders have `quantity = 0` and NA prices. They violate the
sales schema. Use `pre_filter` to exclude.

## Drift detection — what happens when the source schema changes

When the prerawdata source adds/removes/renames a column, the runtime
fingerprint diverges from the bridge's stored fingerprint, and
`fn_glue_bridge` halts with:

```
Schema drift detected.
  Expected fingerprint (from bridge yaml): <old hash>
  Actual fingerprint (from current source): <new hash>
Action: re-run the glue-bridge skill to regenerate the bridge yaml,
        have a human reviewer sign off, then commit the updated yaml.
        Do NOT bypass this check — schema drift breaks downstream DRV.
```

Recovery: regenerate the bridge yaml via the `/glue-bridge` skill,
update column_mapping for any new/renamed/removed fields, get human
review, commit. The audit trail is in git history.

## Related principles

- **MP102 v1.2** — binds the bridge yaml shape (Category A Schema
  Contract).
- **MP156** — Two-Tier Normativity binding mechanism.
- **MP154** — sentinel-aware fallback (no silent NA).
- **MP029** — bridge yamls describe real prerawdata; the
  `reviewed_by` guard rejects AI-only review.
- **DM_R064** — column lookup is by name + alias only; no positional
  inference.
- **IC_P002** — bridge changes that affect canonical contract require
  cross-company verification trailer in commit message.

## Quick reference

| File | Purpose |
|---|---|
| `01_db/raw_schema/_authoring/core_schemas.yaml` | Canonical schema (Tier-2 spec) |
| `01_db/raw_schema/_authoring/platform_extensions/*.yaml` | Per-platform extensions |
| `01_db/raw_schema/_authoring/bridges/{COMPANY}/{platform}/{source}.bridge.yaml` | Per-company bridges |
| `01_db/raw_schema/_generated/{core,platforms/*}/*.sql` | Committed DDL artifact |
| `05_etl_utils/glue/fn_glue_bridge.R` | Runtime entry |
| `05_etl_utils/glue/fn_apply_mapping.R` | Pure data transform |
| `05_etl_utils/glue/fn_validate_against_schema.R` | Post-mapping validation |
| `05_etl_utils/glue/fn_hash_prerawdata_schema.R` | Drift fingerprint |
| `05_etl_utils/glue/fn_call_llm_for_mapping.R` | Codegen-time only |
| `00_principles/.claude/skills/glue-bridge/SKILL.md` | Codegen workflow |
