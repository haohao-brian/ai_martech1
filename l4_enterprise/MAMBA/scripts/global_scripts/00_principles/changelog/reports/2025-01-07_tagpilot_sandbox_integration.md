# TagPilot Sandbox Integration Report

**Date**: 2025-01-07
**Type**: Feature Addition
**Status**: Completed

---

## Summary

Integrated TagPilot_premium into the sandbox environment, following all sandbox architecture conventions.

---

## Changes

### Added

| Item | Description |
|------|-------------|
| `sandbox_test/app_tagpilot.R` | Main TagPilot application |
| `modules/module_tagpilot_*.R` | 13 renamed modules following `module_{appname}_{feature}.R` pattern |
| `utils/tagpilot_*.R` | 3 utility files with `tagpilot_` prefix |
| `config/yaml/tagpilot_config/app_config.yaml` | TagPilot configuration |
| `archive/tagpilot_dna_versions/` | Archived 6 legacy DNA module versions |
| `deployment/tagpilot/` | Deployment directory with git subrepo |
| GitHub repo `sandbox_tagpilot` | Private repository for deployment |

### Modified

| File | Change |
|------|--------|
| `sandbox/Makefile` | Added `tagpilot`, `manifest-tagpilot`, `init-tagpilot` targets |

---

## Module Mapping

| Original (TagPilot_premium) | New (sandbox_test) |
|-----------------------------|--------------------|
| `module_dna_multi_premium_v2.R` | `module_tagpilot_dna.R` |
| `module_customer_value_analysis.R` | `module_tagpilot_customer_value.R` |
| `module_customer_status.R` | `module_tagpilot_customer_status.R` |
| `module_customer_activity.R` | `module_tagpilot_customer_activity.R` |
| `module_customer_base_value.R` | `module_tagpilot_customer_base_value.R` |
| `module_customer_export.R` | `module_tagpilot_customer_export.R` |
| `module_rsv_matrix.R` | `module_tagpilot_rsv_matrix.R` |
| `module_advanced_analytics.R` | `module_tagpilot_advanced_analytics.R` |
| `module_lifecycle_prediction.R` | `module_tagpilot_lifecycle.R` |
| `module_marketing_decision.R` | `module_tagpilot_marketing.R` |
| `module_score.R` | `module_tagpilot_score.R` |
| `module_upload.R` | `module_tagpilot_upload.R` |
| `module_wo_b.R` | `module_tagpilot_wo_b.R` |

---

## Archived DNA Versions

The following legacy DNA modules were archived to `archive/tagpilot_dna_versions/`:

- `module_dna.R` (v1)
- `module_dna_multi.R`
- `module_dna_multi_VS.R`
- `module_dna_multi_premium.R`
- `module_dna_multi_premium2.R`
- `module_dna_multi_pro2.R`

**Canonical version**: `module_dna_multi_premium_v2.R` → `module_tagpilot_dna.R`

---

## Usage

```bash
# Sync TagPilot to deployment
cd sandbox
make tagpilot

# Sync all apps
make sync-all

# Copy manifest
make manifest-tagpilot
```

---

## GitHub Repository

- **URL**: https://github.com/kiki830621/sandbox_tagpilot
- **Visibility**: Private
- **Subrepo**: `scripts/global_scripts` linked to `ai_martech_global_scripts`

---

## Related Principles

- **SO_P018**: Directory Governance (module naming conventions)
- **MP122**: Triple-Track Subrepo Architecture
