# 2026-02-04 D01 Product Line Requirement

## Summary
D01 DNA derivations now require `product_line_id_filter` as a first-class dimension, and the principles/docs have been updated to match.

## Rationale
DNA KPIs should vary by product line. Treating product line as a placeholder causes all product lines to collapse into one group and produces identical KPI outputs.

## Changes
- Updated D01_01/D01_02/D01_03 principles to require product-line granularity and per-product-line processing.
- Updated D01 core scripts to compute RFM percentiles per product line and run DNA analysis per product line.

## Current Status
- Product line is preserved across D01_01 → D01_03.
- If upstream standardized sales lack `product_line_id`, the pipeline falls back to `"all"` and logs a warning.
