# fix-amz-sales-sister-scripts-canonical-names — IC_P002 Cross-Company Dry-Run

> **Spectra change**: `fix-amz-sales-sister-scripts-canonical-names`
> **Date**: 2026-05-12
> **Compliance**: AC-7 (IC_P002 5 公司 verdicts PASS)

## Per-company verification

amz/sales sister scripts(`amz_ETL_sales_2TS.R` + `amz_ETL_sales_time_series_2TR.R`)是 **universal datatype**(per MP161),透過 `shared/update_scripts/` symlink 共用於 5 公司。Sister script rename(legacy → canonical)是 atomic mechanical change,只影響「reads `df_amz_sales___transformed`」的 ETL path。

### QEF_DESIGN — actual runtime verify

| Surface | Result | Detail |
|---------|--------|--------|
| `amz_ETL_sales_2TS.R` against canonical | ✓ PASS | Exit 0,250,920 rows,0 column-not-found |
| `amz_ETL_sales_time_series_2TR.R` against canonical | ✓ PASS | Exit 0,14 tables created,0 column-not-found |
| lineproduct_price values reasonable | ✓ PASS | Sample 10/10 valid,avg $44, no NULL |
| Sister output schema unchanged | ✓ PASS | DRV consumers see same downstream contract |

**Verdict for QEF_DESIGN**:PASS(actual runtime executed)。詳見 `2026-05-12_fix_sister_scripts_runtime_verify.md`。

### D_RACING / MAMBA / WISER / kitchenMAMA — paper exercise

Sister scripts 透過 `shared/update_scripts/` symlink 共用。

| Company | Active amz/sales bridge? | Sister script needed? | Verdict |
|---------|:-----------------------:|:--------------------:|:-------:|
| D_RACING | NO (no amz active platform) | n/a | ✓ NO REGRESSION |
| MAMBA | NO (focus on cbz/eby) | n/a | ✓ NO REGRESSION |
| WISER | NO (template only) | n/a | ✓ NO REGRESSION |
| kitchenMAMA | NO (focus on cbz) | n/a | ✓ NO REGRESSION |

4 paper-exercise companies 沒 active amz/sales bridge → sister script changes(都是 amz-only path)**不影響** non-amz datatypes。即使未來這 4 公司啟用 amz/sales,新版 sister scripts 對齊 canonical schema,直接 consumable。

**Verdict for 4 paper-exercise companies**:PASS。

## Cross-company conflict analysis

| Conflict scenario | Found? | Resolution |
|------------------|:------:|-----------|
| Sister script rename breaks non-amz workflows | NO | Sister scripts 是 amz-only path,跟 cbz/eby/shp/eby pipelines 隔離 |
| Sister output schema 改變影響 DRV consumers | NO | Output column names 不變(per Decision 6 + Risk 4 mitigation);sister scripts 只改 input reading,output schema 不動 |
| 5 公司其中一家有 hidden amz/sales 客製 sister script | NO | `shared/` symlink:single source of truth,no per-co fork |
| line_total 計算差異引發 DRV regression | NO | `total_amount` bridge derive = `unit_price * quantity`,R numeric 域一致 |

## Verdict

✅ **fix-amz-sales-sister-scripts-canonical-names IC_P002 PASSES across 5 consuming companies.**

Atomic cutover commit on `idd/fix-amz-sales-sister-scripts-canonical-names` 安全 land production。

**Commit trailer**:`Verified: QEF_DESIGN, D_RACING, MAMBA, WISER, kitchenMAMA`

## Out-of-scope (this dry-run)

- amz-sales pipeline 在其他 4 公司的 deploy 啟用(separate per-co activation work)
- amz/reviews / amz/products 等其他 amz datatypes 的類似 sister-script audit(separate per-datatype change per playbook)
- cbz / eby 等其他 platform 的 sister-script audit(separate per-platform changes)

## Cross-references

- Audit report:`2026-05-12_fix_sister_scripts_audit.md`
- Runtime verify:`2026-05-12_fix_sister_scripts_runtime_verify.md`
- Pilot source:amz-sales-pilot-execution(archived 2026-05-12)
- Issue:kiki830621/ai_martech_l4_enterprise#640
