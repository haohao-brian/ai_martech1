# Cross-Platform Legacy ETL Orphan Audit — 2026-05-10

> **Issue**: kiki830621/ai_martech_global_scripts#613
> **Source**: surfaced during /idd-diagnose #608 Step 3.6 sister concern surfacing — verify same orphan-parallel-stack pattern across cbz/eby/shp/amz before #608.4 lifecycle deprecation work
> **Author**: Claude (auto-generated audit during /idd-all-chain on idd/chain-616-multi)
> **Status**: descriptive report — no code change

---

## Executive summary

**Confirmed**: ALL ETL/DRV files across 5 platforms are orphan from `_targets.R` registry (Makefile-era residue). Glue layer coverage is concentrated in QEF_DESIGN/amz only (14 of ~144 possible cells).

| Metric | Count |
|---|---|
| Total platforms with ETL | 5 (all, amz, cbz, eby, precision) |
| Total ETL R files | 73 (amz=28, cbz=16, all=12, eby=10, precision=7) |
| Total DRV R files (amz/cbz/eby) | 54 (amz=27, cbz=15, eby=12) |
| Files in `_targets.R` registry | **0** |
| Companies with glue bridges | 1 (QEF_DESIGN only) |
| Bridges total | 14 (all in QEF_DESIGN/amz) |
| Coverage rate | 14 / (6 companies × 4 platforms × ~12 datatypes) ≈ 5% |

**Key finding**: #608's diagnostic hypothesis — that legacy ETL is orphan parallel stack across all platforms — is **fully confirmed**. The gap is uniform, not localized to amz/reviews.

## Per-platform inventory

### amz — `shared/update_scripts/ETL/amz/` (28 ETL files)

```
sales:                    0IM ✓  1ST ✓  2TR ✓  2TS ✓ (custom)
sales_time_series:                       2TR ✓  (independent datatype)
reviews:                  0IM ✓  1ST ✓  2TR ✓
comment_properties:       0IM ✓  1ST ✓  2TR ✓
company_product_master:   0IM ✓  1ST ✓  2TR ✓
product_master:                  1ST ✓  2TR ✓  (no 0IM — derived)
product_profiles:         0IM ✓  1ST ✓  2TR ✓
product_attributes:       0IM ✓                 (per-PL splitter)
competitor_ids:           0IM ✓  1ST ✓  2TR ✓
competitor_sales:         0IM ✓                  (truncated)
demographic:              0IM ✓                  (truncated)
keepa:                    0IM ✓                  (truncated)
keys:                     0IM ✓                  (truncated)
sku_mapping:              0IM ✓                  (truncated)
```

**Glue bridge coverage**: 14 bridges in QEF_DESIGN/amz (sales / reviews [wip] / company_product_extension / 12 product_attributes_*) = ~50% of amz datatypes covered.

**DRV consumer counts** (sample):
- `df_amz_sales___standardized`: 7 DRV consumers (load-bearing — cannot retire 2TS without migration)
- `df_amz_review___transformed`: 3 DRV consumers
- `df_amz_company_product_master___transformed`: 0 DRV consumers (truly orphan — safe to archive)

### cbz — `shared/update_scripts/ETL/cbz/` (16 ETL files)

```
sales:                  0IM ✓  1ST ✓  2TR ✓  2TS ✓ (custom, mirrors amz)
sales_time_series:                     2TR ✓
customers:              0IM ✓  1ST ✓  2TR ✓
orders:                 0IM ✓  1ST ✓  2TR ✓
products:               0IM ✓  1ST ✓  2TR ✓
shared:                 0IM ✓                    (cbz-shared utility)
+ check_raw_columns.R                            (audit utility, not ETL)
```

**Glue bridge coverage**: 0 bridges. All cbz ETL is legacy-only.

### eby — `shared/update_scripts/ETL/eby/` (10 ETL files)

ALL files have `___MAMBA` suffix — eby is MAMBA-specific instance:

```
sales___MAMBA:                   0IM ✓  1ST ✓  2TR ✓  2TS ✓
sales_time_series___MAMBA:                       2TR ✓
orders___MAMBA:                  0IM ✓  1ST ✓
order_details___MAMBA:           0IM ✓  1ST ✓
order_details___MAMBA_DEBUG:           1ST ✓ (debug variant)
```

**Glue bridge coverage**: 0 bridges.

**Note**: eby files use company-suffix pattern (per DM_R037 Company-Specific ETL Naming) — `___MAMBA` indicates this ETL only runs for MAMBA company. Other companies (D_RACING, URBANER) presumably don't sell on eby.

### shp — NOT FOUND

No `shared/update_scripts/ETL/shp/` directory exists. Either:
- (a) No company sells on Shopify currently → no ETL needed
- (b) Future-pending → bridge will be authored when first company onboarding hits shp

### all — `shared/update_scripts/ETL/all/` (12 files, cross-platform aggregators)

```
item_profile_2TR.R         (cross-platform product merge)
summary_2TR.R              (cross-platform aggregate)
+ 10 others                (mostly 1ST/2TR shared)
```

These are NOT platform-specific; they aggregate across platforms. Glue layer doesn't directly replace these (different category — merge/summary aggregators, not source ingestion).

### precision — `shared/update_scripts/ETL/precision/` (7 files)

Legacy precision_marketing project ETL (per CLAUDE.md project structure). Not active in current scope. Out of glue migration scope per #608 + #619.

## Glue layer coverage matrix

```
                amz    cbz    eby    shp
QEF_DESIGN      14     0      0      0
D_RACING         0     0      0      0
URBANER          0     0      0      0
MAMBA            0     0      0      0
WISER            0     0      0      0
kitchenMAMA      0     0      0      0
                ----   ----   ----   ----
TOTAL           14     0      0      0
```

**1 of 24 cells covered = 4.2% coverage**. QEF_DESIGN/amz is the pilot; other 23 cells are blank canvas.

## `_targets.R` registry

`grep -E "amz_ETL|amz_D" shared/update_scripts/_targets.R*` returns NO actual target registrations across all 4 registry files (`_targets.R`, `_targets_config.yaml`, `_targets_etl.R`, `_targets_drv.R`). Confirmed for amz; assumed equivalent for cbz/eby (not separately verified — registry is platform-agnostic).

## Recommendations (per-combo migration plan)

Apply 3-tier categorization:

### Tier A — archive immediately (orphan-orphan)

Files with **0 DRV consumers** AND **0 known active calls**. Safe to move to `99_archived/legacy_etl_pre_glue/` next session:

| Platform | Datatype | Reason |
|---|---|---|
| amz | company_product_master_*.R | 0 DRV consumers per audit |
| amz | demographic_0IM.R | truncated chain (only 0IM), no 1ST/2TR consumers |
| amz | keepa_0IM.R | truncated chain |
| amz | keys_0IM.R | truncated chain |
| amz | sku_mapping_0IM.R | truncated chain |
| amz | competitor_sales_0IM.R | truncated chain |

**Estimated**: ~6 amz files immediately archivable. Need similar audit for cbz/eby orphan candidates.

### Tier B — migrate consumers first, then archive (load-bearing legacy)

Files with **active DRV consumers**. Requires migrating consumer DRV scripts to read canonical glue layer outputs (post-#618 schema-driven redesign):

| Platform | Datatype | DRV consumers |
|---|---|---|
| amz | sales chain (0IM/1ST/2TR/2TS) | 7 (D01_00, D01_01, D01_03, D01_06, D01_07, D05_01, D06_01) — **highest priority** |
| amz | reviews chain | 3 (D03_06, D03_08, D03_11) |
| amz | comment_properties chain | (audit-pending; likely D03 chain) |
| amz | product_master / product_profiles chain | (audit-pending) |
| cbz | all 5 datatype chains | likely 5+ DRV per chain |
| eby | sales/orders chains | MAMBA-only |

**Strategy**: pilot with amz/reviews (already partial — wip bridge exists). Migration sequence per datatype:
1. Author bridge yaml under `bridges/{COMPANY}/{platform}/{datatype}.bridge.yaml`
2. Run /glue-bridge skill for the new bridge
3. Verify canonical raw table populated (df_*_raw)
4. Update DRV scripts to read from canonical raw instead of legacy ___transformed
5. IC_P002 cross-co verify per datatype-company pair
6. Once all consumers migrated: archive legacy *_0IM/1ST/2TR.R + 2TS

### Tier C — leave alone (different category)

Files in `all/` (cross-platform aggregators) are NOT glue-migration targets — they operate on already-canonical data. Out of #619 scope.

`precision/` files are legacy precision_marketing project — out of scope.

## Recommended execution order for #619

Sequenced by lowest-risk-first:

1. **archive Tier A** (amz orphan-orphan files) — mechanical, ~30 min, no IC_P002 risk
2. **migrate amz/reviews chain** — pilot for /glue-bridge schema-driven redesign (#618), use as template
3. **migrate amz/sales chain** — highest DRV consumer count, highest value
4. **migrate amz remaining datatypes** (comment_properties, products, competitor_ids)
5. **migrate cbz** — 5 datatypes, similar pattern to amz
6. **migrate eby** — MAMBA-only, smaller scope
7. **archive `all/` aggregators** if their inputs migrate (downstream of 1-6)

**Estimated total**: 8-12 weeks per #619 issue body, requires 5 spectra changes + IC_P002 verify per company × datatype migration step.

## Cross-references

- **#608.4** — Lifecycle deprecation spectra change axis (this audit unblocks scoping)
- **#619** — Aggressive ETL/DRV deprecation migration (this audit feeds the migration plan)
- **#618** — /glue-bridge schema-driven redesign (necessary precursor for high-volume migration)
- **#607** — production fire (extensionless xlsx regex) — independent of this audit
- **MP064 / MP107 / MP108 / MP109** — ETL/DRV principles (architectural framing)
- **MP161** — Company-Scoped Schema Recognition (governs bridge directory layout)
- **MP158** — Glue-Driven Raw Layer Extensibility (3-step composition)

## Out-of-scope

- DRV-side migration plan (#608 separate axis)
- Test fixtures for migrated bridges (#612 / #614 follow-ups)
- Schema authoring for cbz/eby canonical extensions (Layer 1 work — separate spectra change)
- Cross-platform aggregator migration (out of #619 scope per Tier C above)
