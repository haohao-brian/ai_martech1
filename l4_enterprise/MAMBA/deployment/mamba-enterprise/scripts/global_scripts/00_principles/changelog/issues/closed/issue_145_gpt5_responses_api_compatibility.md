# Issue 145: GPT-5 Responses API Compatibility Fix

## Status: CLOSED
## Date: 2025-01-08
## Apps Affected: BrandEdge, InsightForge, VitalSigns

---

## Problem

Multiple modules had local `chat_api()` implementations using **Chat Completions API format** which is incompatible with `gpt-5-nano` model.

### Error Message
```
屬性萃取失敗： HTTP 400 Bad Request.
請確認 OpenAI API 設定正確且有足夠配額
```

### Root Cause

GPT-5 models require the **Responses API** (`/v1/responses`) with different:
- Endpoint: `/v1/responses` (not `/v1/chat/completions`)
- Input format: `input` string (not `messages` array)
- Parameters: `reasoning`, `text`, `max_output_tokens` (not `temperature`, `max_tokens`)

Local `chat_api()` implementations were using Chat Completions API format, causing HTTP 400 errors.

---

## Files Fixed

| File | Change |
|------|--------|
| `modules/module_brandedge_scoring.R` | Source global chat_api, remove local implementation |
| `modules/module_brandedge_shared.R` | Source global chat_api, remove local implementation |
| `modules/module_brandedge_advanced_attribute.R` | Remove local chat_api, update call sites |
| `modules/module_tagpilot_wo_b.R` | Source global chat_api, remove local implementation |
| `utils/openai_utils.R` | Update fallback to use gpt-4o-mini (Chat Completions compatible) |

---

## Solution

### Strategy: Centralize API calls to global fn_chat_api.R

All modules now use `scripts/global_scripts/08_ai/fn_chat_api.R` which correctly:
1. Detects GPT-5 models: `is_gpt5 <- grepl("^gpt-5", model)`
2. Uses Responses API endpoint: `https://api.openai.com/v1/responses`
3. Formats request body correctly for GPT-5

### Fallback Safety

`utils/openai_utils.R` fallback updated to:
- Default to `gpt-4o-mini` (Chat Completions compatible)
- Auto-downgrade GPT-5 requests with warning
- Clear documentation about GPT-5 requirements

---

## Commits

| App | Commit | Date |
|-----|--------|------|
| BrandEdge | 80242cc | 2025-01-08 |
| InsightForge | 0d416aa | 2025-01-08 |
| VitalSigns | 25cbd63 | 2025-01-08 |

---

## Verification

1. Navigate to BrandEdge 屬性評分 page
2. Enter attribute count and click "產生屬性"
3. Verify no HTTP 400 error
4. Verify attributes are generated successfully

---

## Related Principles

- Centralized API management reduces code duplication
- Global scripts ensure consistent behavior across apps
- Fallback implementations should fail gracefully
