# Issue 143: TagPilot analyze_customer_dynamics_new Function Not Found

**Status**: CLOSED
**Date**: 2025-01-08
**Severity**: Critical
**App**: TagPilot (sandbox)

---

## Error Message

```
[ERROR] Step 6 FAILED: analyze_customer_dynamics_new() - could not find function "analyze_customer_dynamics_new"
檔案處理錯誤: could not find function "analyze_customer_dynamics_new"
```

---

## Root Cause

**Module source path mismatch**:
- Modules source `utils/analyze_customer_dynamics_new.R`
- But the function `analyze_customer_dynamics_new()` is defined in `utils/tagpilot_customer_dynamics.R`

The module expects a file at a specific path, but the actual implementation is in a differently-named file.

---

## Solution

**Add wrapper files** that redirect to the actual implementation:

### 1. `utils/analyze_customer_dynamics_new.R` (wrapper)

```r
# Legacy compatibility wrapper for analyze_customer_dynamics_new()
if (!exists("analyze_customer_dynamics_new", mode = "function")) {
  source("utils/tagpilot_customer_dynamics.R")
}
```

### 2. `utils/calculate_customer_tags.R` (wrapper)

```r
# Legacy compatibility wrapper for calculate_customer_tags.R
if (!exists("calculate_base_value_tags", mode = "function")) {
  source("utils/tagpilot_calculate_tags.R")
}
```

---

## Affected Apps

| App | Status |
|-----|--------|
| TagPilot | Fixed (wrapper files added) |
| BrandEdge | Fixed (wrapper files added) |
| InsightForge | Fixed (wrapper files added) |

---

## Related Issues

- **Issue 142**: TagPilot db_execute PostgreSQL placeholder fix (same deployment session)

---

## Verification

After deploying:
1. Navigate to TagPilot: https://kyleyhl-sandbox-tagpilot.share.connect.posit.cloud/
2. Login with admin / 12345
3. Go to "資料上傳" (Data Upload)
4. Upload a test CSV file
5. Confirm no "could not find function" errors

---

## Timeline

| Time | Action |
|------|--------|
| 2025-01-08 07:00 | Error reported in Posit Connect logs |
| 2025-01-08 07:17 | Issue 143 created |
| 2025-01-08 07:17 | Wrapper files verified in deployment/tagpilot/utils/ |
| 2025-01-08 07:xx | Redeployment triggered |

---

## Principle Reference

- **SO_R007**: One Function One File - Function files should be named consistently
- Wrapper pattern maintains backward compatibility while redirecting to consolidated implementation files
