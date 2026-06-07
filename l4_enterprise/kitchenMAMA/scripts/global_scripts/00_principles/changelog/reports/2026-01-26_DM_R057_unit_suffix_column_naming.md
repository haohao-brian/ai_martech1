# DM_R057: Unit Suffix Column Naming - Implementation Report

**Date**: 2026-01-26
**Type**: New Principle Addition
**Status**: Completed
**Author**: Claude (Opus 4.5)

---

## Summary

Added new data management rule **DM_R057: Unit Suffix Column Naming** to formalize the existing codebase convention of including unit suffixes in column names when values contain specific units.

## Background

The MAMBA codebase already uses unit suffix naming conventions in various locations:
- `customer_tenure_days` - Days since first purchase
- `execution_time_secs` - Script execution duration in seconds
- `ipt_hours` - Inter-purchase time in hours
- `file_size_bytes` - File size in bytes
- `discount_pct` - Discount percentage

This principle formalizes these patterns and makes them a required standard, particularly for `difftime()` conversions where the default "auto" units can cause ambiguity.

## Files Created

| File | Description |
|------|-------------|
| `docs/en/part1_principles/CH02_data_management/rules/DM_R057_unit_suffix_column_naming.qmd` | Full principle specification (9.3 KB) |

## Files Modified

| File | Change |
|------|--------|
| `llm/CH02_data.yaml` | Added DM_R057 entry with rule_natural and rule_formal |
| `llm/RELATIONSHIPS.yaml` | Added relationship to DM_R025 and P0005 |
| `llm/TAGS.yaml` | Added to `naming_conventions` tag group |

## Principle Content

### Standard Unit Suffixes

**Time:**
- `_secs`, `_minutes`, `_hours`, `_days`, `_weeks`, `_months`, `_years`

**Data Size:**
- `_bytes`, `_kb`, `_mb`, `_gb`

**Ratio:**
- `_pct`, `_ratio`, `_bps`

**Currency:**
- `_usd`, `_twd`, `_jpy`

### Mandatory Application

- All `difftime()` to numeric conversions MUST specify units AND use corresponding suffix
- Time interval columns MUST have unit suffix
- File size columns MUST specify unit suffix

### Example

```r
# WRONG - Ambiguous unit
processing_time = as.numeric(difftime(end_time, start_time))

# CORRECT - Explicit unit
processing_time_secs = as.numeric(difftime(end_time, start_time, units = "secs"))
```

## Validation Results

- CH02_data.yaml: YAML syntax valid
- RELATIONSHIPS.yaml: YAML syntax valid
- TAGS.yaml: YAML syntax valid
- QMD frontmatter: YAML syntax valid

## Related Principles

- **DM_R025**: Type Conversion Between R and DuckDB (complementary)
- **DM_R016**: Lowercase Natural Key (extends)
- **P0005**: Naming Principles (implements)

## Note

Original plan specified DM_R055, but DM_R055 and DM_R056 already exist in the codebase. The new principle was assigned **DM_R057**.

---

**Principles Compliance**: SO_P018 (Directory Governance), MP030 (Archive Immutability)
