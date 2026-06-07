# MP108: ETL Phase Sequence Principle

**Date**: 2025-08-29
**Author**: Claude
**Type**: New Meta-Principle
**Status**: Active

## Summary

Created MP108 to document the vertical phase sequence requirement within ETL pipelines, complementing MP107's horizontal independence between pipelines.

## Context

The user identified an important architectural pattern that needed formal documentation:
- While ETLs are independent of each other (MP107 - horizontal)
- Within each ETL, phases must execute in sequence: 0IM → 1ST → 2TR (vertical)
- This natural data flow doesn't violate independence but complements it

## Changes Made

### 1. Created MP108: ETL Phase Sequence Principle
- **Location**: `docs/en/part1_principles/CH00_fundamental_principles/04_data_management/MP108_etl_phase_sequence.qmd`
- **Purpose**: Documents the vertical data flow within ETL pipelines
- **Key Concepts**:
  - Phases within a pipeline execute sequentially when running complete pipeline
  - Each phase depends on data output from the previous phase
  - You CAN skip phases if prerequisite data already exists
  - You CANNOT run phases out of order

### 2. Updated MP107: ETL Pipeline Independence
- Added reference to MP108 in related_to section
- Added new section explaining the relationship between MP107 and MP108
- Clarified that MP107 defines horizontal independence while MP108 defines vertical sequencing

### 3. Updated ETL Independence Implementation Guide
- Added MP108 to implements section
- Added visual representation of the two-dimensional execution model
- Explained how MP107 and MP108 work together

## Architectural Model

```
HORIZONTAL INDEPENDENCE (MP107):
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    ETL_A     ←→     ETL_B     ←→     ETL_C
   Can run in ANY order or SIMULTANEOUSLY
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

VERTICAL SEQUENCE (MP108):
┌────────┐  ┌────────┐  ┌────────┐
│ ETL_A  │  │ ETL_B  │  │ ETL_C  │
├────────┤  ├────────┤  ├────────┤
│  0IM   │  │  0IM   │  │  0IM   │
│   ↓    │  │   ↓    │  │   ↓    │
│  1ST   │  │  1ST   │  │  1ST   │
│   ↓    │  │   ↓    │  │   ↓    │
│  2TR   │  │  2TR   │  │  2TR   │
└────────┘  └────────┘  └────────┘
```

## Key Clarifications

### What MP108 Means:
- Data naturally progresses: raw → staged → transformed
- Each phase enriches data from the previous phase
- Design ETLs with three-phase structure in mind
- Can skip phases if data already exists
- Can re-run from any phase for updates

### What MP108 Does NOT Mean:
- NOT: Must always run all three phases
- NOT: Cannot run individual phases
- NOT: Phases are tightly coupled scripts
- NOT: Phases across ETLs must synchronize
- NOT: System-wide phase coordination required

## Impact

### Positive:
- Clarifies the complete ETL execution model
- Distinguishes between horizontal and vertical aspects
- Provides clear guidance for ETL implementation
- Enables both parallelization and logical data flow

### No Breaking Changes:
- This principle documents existing best practices
- No code changes required for compliant ETLs
- Enhances understanding without changing requirements

## Implementation Guidelines

1. **Phase Structure**: Each ETL should have clear 0IM → 1ST → 2TR phases
2. **Data Dependencies**: Phases depend on data, not scripts
3. **Selective Execution**: Support starting from any phase if data exists
4. **Parallel ETLs**: Different ETLs run independently (MP107)
5. **Sequential Phases**: Within each ETL, phases run in order (MP108)

## Testing Recommendations

```r
# Test phase sequence enforcement
test_phase_sequence <- function() {
  # Should fail: 2TR without staged data
  result <- try(run_etl_phase("cbz", "sales", "2TR"))
  expect_error(result)
  
  # Should succeed: phases in order
  run_etl_phase("cbz", "sales", "0IM")
  run_etl_phase("cbz", "sales", "1ST")
  run_etl_phase("cbz", "sales", "2TR")
}

# Test selective re-run
test_selective_rerun <- function() {
  # Assuming staged data exists
  result <- run_etl_phase("cbz", "sales", "2TR")
  expect_success(result)
}
```

## Conclusion

MP108 completes the ETL architecture model by formally documenting the vertical phase sequence requirement. Together with MP107's horizontal independence, these principles create a robust, scalable ETL system that maximizes parallelization while maintaining logical data flow.

The two principles work in harmony:
- **MP107**: ETLs are independent of EACH OTHER (horizontal)
- **MP108**: Phases within an ETL are SEQUENTIAL (vertical)
- **Result**: Maximum flexibility with natural data progression