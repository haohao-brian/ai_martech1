---
issue: "ISSUE_037"B"
title: "增加 MAMBA 評分容量從 30 項至 50 項"
severity: "medium"
component: "ai_integration"
app: "mamba"
created: "2025-11-02"
status: "open"
parent_issue: "ISSUE_037"
original_source: "20251021/曼巴問題_20251021.md#21"
priority: "medium-high"
estimated_effort: "3-5 days"
---

## Problem

客戶明確要求：**「曼巴評分數增加到 50 個」**

當前系統限制 MAMBA 評分功能最多處理 30 個項目，但客戶需要同時分析更多產品/項目（50 個）以進行更全面的市場分析。

## Expected Behavior

用戶應能夠：
1. 選擇最多 50 個產品進行 MAMBA 評分分析
2. 系統能穩定處理 50 項的 OpenAI API 批次請求
3. UI 能清晰呈現 50 項的分析結果
4. 整體性能不顯著下降

## Actual Behavior

**當前限制**:
- 最大項目數：30 個（根據原始文檔 #3）
- 超過限制時：[需確認當前行為 - 是否顯示錯誤？截斷？]

**影響範圍**:
- 限制了大規模產品組合分析能力
- 客戶無法進行完整的產品線評估

## Proposed Resolution

### Phase 1: Technical Assessment (Day 1)

#### 1.1 確認當前架構
```r
# 找出當前限制設定的位置
scripts/global_scripts/05_openai/        # OpenAI API 調用邏輯
scripts/global_scripts/10_rshinyapp_components/  # UI 組件限制
app_config.yaml                           # 配置文件中的限制
```

#### 1.2 評估技術可行性

**OpenAI API 限制檢查**:
```r
# 當前 API 配置
- Rate limits: [待確認]
- Batch size: [待確認]
- Timeout settings: [待確認]
- Cost per request: [待確認]

# 50 項需求
- Estimated API calls: 50 calls (或更多，取決於處理邏輯)
- Estimated cost per batch: [計算]
- Response time: [估算]
```

**性能影響評估**:
- 記憶體使用量增加：30 → 50 項 (~67% 增加)
- API 調用時間：取決於並行處理策略
- UI 渲染性能：需測試 50 項的顯示效果

### Phase 2: Implementation (Day 2-4)

#### 2.1 更新配置限制
```yaml
# app_config.yaml 或相關配置文件
mamba_scoring:
  max_items: 50          # 從 30 更新到 50
  batch_size: 10         # 批次處理大小
  parallel_requests: 5   # 並行請求數
```

#### 2.2 實施批次處理優化
```r
# scripts/global_scripts/05_openai/batch_processing.R

process_mamba_scoring_batch <- function(items, max_items = 50) {
  # 驗證項目數
  if (length(items) > max_items) {
    stop(sprintf("Maximum %d items allowed", max_items))
  }

  # 分批處理策略
  batch_size <- 10
  batches <- split(items, ceiling(seq_along(items) / batch_size))

  # 並行處理
  library(future)
  plan(multisession, workers = 5)

  results <- future_map(batches, function(batch) {
    # OpenAI API 調用邏輯
    process_batch_with_retry(batch)
  }, .progress = TRUE)

  # 合併結果
  bind_rows(results)
}
```

#### 2.3 更新 UI 組件

**選擇器更新**:
```r
# 更新產品選擇器最大值
selectInput(
  "products",
  "選擇產品",
  choices = product_list,
  multiple = TRUE,
  # 添加驗證提示
  options = list(
    `max-options` = 50,
    `max-options-text` = "最多選擇 50 個產品"
  )
)
```

**顯示優化**:
```r
# 實施分頁或虛擬滾動
DT::datatable(
  results,
  options = list(
    pageLength = 25,      # 每頁顯示 25 項
    scrollY = "500px",    # 可滾動視圖
    scrollCollapse = TRUE
  )
)
```

### Phase 3: Testing & Validation (Day 5)

#### 3.1 功能測試
- [ ] 測試 50 項完整處理流程
- [ ] 測試各種項目數量（10, 30, 40, 50）
- [ ] 測試錯誤處理（超過 50 項）
- [ ] 測試並行處理穩定性

#### 3.2 性能測試
- [ ] 測量 30 項 vs 50 項的執行時間
- [ ] 監控記憶體使用
- [ ] 驗證 API rate limits 不被觸發
- [ ] 檢查 UI 響應性

#### 3.3 成本分析
```r
# 成本影響評估
current_cost_30_items <- 30 * cost_per_api_call
new_cost_50_items <- 50 * cost_per_api_call
cost_increase_pct <- ((new_cost_50_items - current_cost_30_items) / current_cost_30_items) * 100

# 預期：67% 成本增加（線性成長）
```

## Technical Context

**受影響組件**:
```
scripts/global_scripts/05_openai/
├── openai_utils.R          # API 調用邏輯
├── batch_processing.R      # 批次處理（可能需新建）
└── rate_limiting.R         # 速率限制管理

scripts/global_scripts/10_rshinyapp_components/
└── [MAMBA 評分相關 UI 組件]

app_config.yaml             # 配置限制
```

**相關原則**:
- **MP029**: No Fake Data（確保真實處理 50 項的能力）
- **MP099**: Real-Time Progress Reporting（顯示處理進度）
- 性能優化原則
- 成本效益原則

## Risk Assessment

### HIGH Risk: OpenAI API Rate Limits
**風險**: API 速率限制可能不支援 50 個並發請求
- **機率**: Medium
- **影響**: High
- **緩解**:
  - 實施批次處理和排隊機制
  - 添加重試邏輯
  - 監控 API usage

### MEDIUM Risk: UI 性能下降
**風險**: 50 項結果可能導致 UI 渲染緩慢
- **機率**: Medium
- **影響**: Medium
- **緩解**:
  - 實施分頁或虛擬滾動
  - 延遲渲染非可見項目
  - 優化表格組件

### LOW Risk: 成本增加
**風險**: API 調用成本增加 67%
- **機率**: High (確定會發生)
- **影響**: Low-Medium
- **緩解**:
  - 與客戶溝通成本影響
  - 考慮添加使用量追蹤
  - 評估批次折扣可能性

## Priority Justification

**優先級**: MEDIUM-HIGH
- **業務價值**: High - 直接客戶需求，擴展分析能力
- **客戶影響**: High - 客戶明確要求此功能
- **技術複雜度**: Medium - 需要多層面調整但可行
- **時機**: 可獨立實施，不依賴 Milestone 3

## Implementation Timeline

| Phase | Days | Tasks |
|-------|------|-------|
| Assessment | 1 | 確認當前架構、評估可行性 |
| Implementation | 3 | 更新配置、實施批次處理、UI 更新 |
| Testing | 1 | 功能測試、性能測試、成本分析 |
| **Total** | **5** | **完整實施週期** |

## Dependencies

- OpenAI API 存取權限和配額
- 現有 MAMBA 評分模組的代碼位置
- 測試環境中的 API credits

## Acceptance Criteria

✅ 系統支援選擇最多 50 個項目進行評分
✅ 50 項評分能穩定完成，無錯誤
✅ 執行時間在可接受範圍內（< 5 分鐘）
✅ UI 能清晰顯示 50 項結果
✅ API rate limits 不被觸發
✅ 成本影響已記錄並與客戶溝通
✅ 添加適當的錯誤處理和進度顯示

## Related Issues

- Parent: ISSUE_244 (已分解)
- Related: [可能與 OpenAI 集成的其他 issues]
- Blocked by: None
- Blocks: None

## Notes

- 此 issue 從 ISSUE_244 分解而來
- 客戶明確需求，優先級高於一般 UI 優化
- 建議在 Milestone 3 開始前或並行處理
- 成功實施後可作為系統擴展能力的案例

## Action Items

- [ ] Day 1: 確認當前 30 項限制的代碼位置
- [ ] Day 1: 評估 OpenAI API rate limits 和成本
- [ ] Day 2-3: 實施批次處理和配置更新
- [ ] Day 4: UI 組件更新和優化
- [ ] Day 5: 完整測試和驗證
- [ ] Post-impl: 監控生產環境使用情況

---
**Created**: 2025-11-02
**Last Updated**: 2025-11-02
**Status**: Open (Working)
**Assigned To**: [待指派]
