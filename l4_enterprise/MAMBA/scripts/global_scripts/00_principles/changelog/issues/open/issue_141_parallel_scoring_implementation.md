# Issue 141: Sandbox 平行評分實作

## 狀態
- **建立日期**: 2025-01-07
- **狀態**: 已完成 (Completed)
- **優先級**: P0 (Demo 前必須完成)
- **影響範圍**: BrandEdge, InsightForge, VitalSigns

## 問題描述

### 背景
Posit Connect 在 4+ 並發用戶時崩潰，主要原因之一是 OpenAI 評分為同步阻塞操作：
- 50 筆評論 × 15 屬性 = 750 次 API 呼叫
- 每次呼叫 3-5 秒 = 總共 30-60 分鐘
- Worker 被佔用期間無法服務其他用戶

### 解決方案
參考 MAMBA `global_scripts/08_ai/` 的平行處理機制，實作：
1. `furrr::future_map()` 平行評分
2. Rate Limiting 指數退避
3. 4 workers 同時處理

## 實作內容

### 1. 修改檔案清單

| 檔案 | 修改內容 |
|------|---------|
| `utils/openai_utils.R` | 改為 global_scripts 轉接器 |
| `utils/archive/openai_utils_20250107.R` | 舊版備份 |
| `modules/module_brandedge_scoring.R` | 加入 furrr 平行處理 |
| `modules/module_scoring.R` | 加入 furrr 平行處理 |

### 2. 平行處理核心程式碼

```r
# 設定平行處理 workers
n_workers <- min(4, parallel::detectCores() - 1)
future::plan(future::multisession, workers = n_workers)

# 使用 furrr::future_map 平行處理
scores_list <- furrr::future_map(
  seq_len(total_reviews),
  function(i) {
    tryCatch({
      score_review(review_texts[i], attributes,
                  review_idx = i, brand_name = review_brands[i])
    }, error = function(e) {
      rep(NA_real_, length(attributes))
    })
  },
  .options = furrr::furrr_options(seed = TRUE),
  .progress = FALSE
)

# 重置為循序處理
future::plan(future::sequential)
```

### 3. Rate Limiting 機制

使用 `global_scripts/08_ai/fn_rate_comments.R` 的機制：

```r
httr2::req_retry(
  is_transient = \(resp) httr2::resp_status(resp) %in% c(429, 500:599),
  after        = openai_rate_limit_handler,  # 解析 Retry-After header
  backoff      = \(n) min(2^(n - 1), 30),    # 指數退避: 2,4,8,16,30 秒
  max_tries    = 6,
  max_seconds  = 180
)
```

### 4. 效能改善

| 指標 | 改善前 | 改善後 |
|------|--------|--------|
| 評分時間 (50筆×15屬性) | 30-60 分鐘 | ~8-15 分鐘 |
| 速度提升 | - | ~4 倍 |
| Worker 佔用時間 | 30-60 分鐘 | ~8-15 分鐘 |

## 部署資訊

### GitHub 推送
| App | Commit |
|-----|--------|
| BrandEdge | `8cad1b1..5622d7b` |
| InsightForge | `e53bc61..4c8dca9` |
| VitalSigns | `c0b28a0..a498548` |

### Posit Connect Runtime 建議設定

```
Worker settings:
- Max worker processes: 2 → 4
- Idle timeout: 60 → 3600 secs
- Startup timeout: 90 → 120 secs

Connection settings:
- Max connections: 15 → 20
```

## 相關原則

- **MP140**: Pipeline Orchestration - 平行處理架構
- **DM_R042**: Makefile Command Reference - 部署命令

## 測試建議

1. 開 5+ 瀏覽器分頁同時存取
2. 同時觸發 2 人評分，確認平行處理正常
3. 監控 OpenAI API rate limit 是否被觸發

## 後續改善方向

1. **佇列系統**: 實作 `scoring_queue` 資料庫表，支援評分排隊
2. **背景任務**: 評分改為背景執行，完成後通知用戶
3. **批次 API**: 考慮使用 OpenAI Batch API 進一步優化

---

## 結論（2025-01-08 更新）

### ❌ 平行處理在 Shiny Cloud 環境失敗

**錯誤訊息**：
```
The total size of the 13 globals exported for future expression is 817.59 MiB.
This exceeds the maximum allowed size 500.00 MiB (future.globals.maxSize)

The three largest globals are:
- 'score_review' (817.51 MiB)  ← 問題根源！
- 'chat_api' (26.68 KiB)
- 'review_texts' (14.65 KiB)
```

**根本原因**：
- Shiny 函數定義在 reactive context 中會捕獲整個父環境（closure）
- 環境大小可達 800+ MB
- `future` 需要序列化 closure 傳給 worker
- 超過 `future.globals.maxSize` 限制（預設 500MB）→ 報錯

### ✅ 最終解決方案

1. **移除平行處理**：改用循序處理（for loop）+ 即時進度更新
2. **InsightForge 效率修復**：改用批次評分 prompt (`score_attributes`)，API 呼叫從 750 → 50 次
3. **新增原則**：CLOUD_P001 - Shiny Cloud 環境禁用 furrr 平行處理

### 修改檔案

| 檔案 | 修改內容 |
|------|---------|
| `modules/module_brandedge_scoring.R` | 移除 furrr，改用 for loop |
| `modules/module_scoring.R` | 移除 furrr，改用批次評分 + for loop |
| `database/content/*/insightforge/prompt.csv` | 新增 `score_attributes` prompt |

### 效能對比

| App | 修改前 | 修改後 | 改善 |
|-----|--------|--------|------|
| BrandEdge | 50 API calls（平行但會失敗） | 50 API calls（循序穩定） | 穩定性 |
| InsightForge | 750 API calls（平行但會失敗） | **50 API calls**（循序穩定） | **15 倍效率提升** |

---

**關閉時間**: 2025-01-08
**狀態**: 已關閉 (Closed) - 改用循序處理
**相關原則**: CLOUD_P001 - Shiny Cloud 環境禁用 furrr 平行處理
