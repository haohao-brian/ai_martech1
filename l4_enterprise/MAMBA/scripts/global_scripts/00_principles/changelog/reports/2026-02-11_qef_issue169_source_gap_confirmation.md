# QEF Issue #169 Source Gap Confirmation (2026-02-11)

## Scope
- Repository: `QEF_DESIGN`
- Related issue: `https://github.com/kiki830621/ai_martech_global_scripts/issues/169`
- Objective: confirm whether remaining `psg/rpl` zero-coverage is ETL defect or source-data gap.

## Work Completed
1. Re-ran AMZ sales chain after 2TR datetime parsing fix:
   - `amz_ETL_sales_1ST.R`
   - `amz_ETL_sales_2TR.R`
   - `amz_ETL_sales_2TS.R`
2. Re-ran D01 full flow:
   - `amz_D01_06.R` (includes D01_00~D01_05)
3. Ran product-line coverage guardrail:
   - `amz_D01_07_product_line_coverage_audit.R`

## Key Verification
### A) Profile ASIN vs raw sales table (`raw_data.df_amazon_sales`)
- `psg`: `profile_asin=18`, `raw_rows=0`, `raw_distinct_asin=0`
- `rpl`: `profile_asin=15`, `raw_rows=0`, `raw_distinct_asin=0`
- Control check:
  - `sfo`: `raw_rows=7416`
  - `blb`: `raw_rows=1391`

### B) Direct source file scan (`rawdata_QEF_DESIGN/amazon_sales/*.xlsx`)
- Files scanned: 23
- Files containing `psg` profile ASINs: 0
- Files containing `rpl` profile ASINs: 0

### C) Latest coverage output (after rerun)
File:
- `output/etl_validation/amz/product_line_coverage/product_line_coverage_report_latest.csv`

Rows of interest:
- `sfo`: `sales_rows=7027`, `dna_rows=6317`, `gap_type=OK`
- `blb`: `sales_rows=1294`, `dna_rows=1215`, `gap_type=OK`
- `psg`: `sales_rows=0`, `dna_rows=0`, `gap_type=B_profile_present_but_no_sales_coverage`
- `rpl`: `sales_rows=0`, `dna_rows=0`, `gap_type=B_profile_present_but_no_sales_coverage`

## Conclusion
For the remaining two lines (`psg`, `rpl`), evidence is consistent with **source sales data absence**, not current ETL import/transform loss.

- ETL defect previously affecting broad coverage was fixed (`2TR` date parsing).
- Remaining gap is source coverage for `psg/rpl`.

## Issue Handling
- Updated issue `#169` with rerun evidence.
- Closed issue `#169` as root cause confirmed to be source-data gap for the remaining lines.
