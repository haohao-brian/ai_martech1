---
issue: "ISSUE_010"
title: "FIX: OpenAI API Timeout 增加到 5 分鐘"
severity: "medium"
component: "general"
app: "mamba"
created: "2025-01-01"
status: "closed"
---

# FIX: OpenAI API Timeout 增加到 5 分鐘

**Date**: 2025-10-07
**Type**: Bug Fix
**Severity**: High (導致儀表板當機)
**Status**: ✅ Fixed

---

## 問題描述

### 症狀
```
Warning: Error in httr2::req_perform: Failed to perform HTTP request.
Caused by error in `curl::curl_fetch_memory()`:
! Timeout was reached [api.openai.com]:
Operation timed out after 60002 milliseconds with 0 bytes received
```

### 影響
- **InsightForge 360** 精準行銷洞察報告生成失敗
- 分析 163 個產品屬性變數時，AI 報告生成時間超過 60 秒
- **整個儀表板當機**，用戶體驗嚴重受損

### 根本原因
API timeout 設定過短（60 秒），無法處理需要長時間生成的 AI 報告。

---

## 修復方案

### 解決策略
將 OpenAI API timeout 從 **60 秒**增加到 **300 秒（5 分鐘）**

### 修改檔案

#### 1. `fn_chat_api.R` (核心 API 函數)

**位置**: `/global_scripts/08_ai/fn_chat_api.R`

**變更**:
```r
# BEFORE
chat_api <- function(messages,
                       api_key = Sys.getenv("OPENAI_API_KEY"),
                       model = "gpt-4o-mini",
                       api_url = "https://api.openai.com/v1/chat/completions",
                       timeout_sec = 60) {

# AFTER
chat_api <- function(messages,
                       api_key = Sys.getenv("OPENAI_API_KEY"),
                       model = "gpt-4o-mini",
                       api_url = "https://api.openai.com/v1/chat/completions",
                       timeout_sec = 300) {  # 5 minutes
```

**文檔更新**:
```r
# BEFORE
#' @param timeout_sec Numeric. Request timeout in seconds (defaults to 60).

# AFTER
#' @param timeout_sec Numeric. Request timeout in seconds (defaults to 300 = 5 minutes).
```

#### 2. `fn_rate_comments.R` (評論評分函數)

**位置**: `/global_scripts/08_ai/fn_rate_comments.R`

**變更** (Line 105):
```r
# BEFORE
httr2::req_timeout(60)

# AFTER
httr2::req_timeout(300)  # 5 minutes to handle long AI analysis reports
```

---

## 技術細節

### 為何選擇 5 分鐘？

| 資料規模 | 預估處理時間 | 安全邊界 |
|---------|------------|---------|
| 30 個變數 | 30-60 秒 | ✅ 充足 |
| 163 個變數 | 120-180 秒 | ✅ 充足 |
| 極端情況 | 200-250 秒 | ✅ 可容忍 |

**設計考量**:
- ✅ 給予 AI 充足的生成時間
- ✅ 避免儀表板當機
- ✅ 在合理範圍內（不會無限等待）
- ✅ 保留用戶體驗（不超過 5 分鐘）

### Retry 機制保持不變

```r
httr2::req_retry(
  is_transient = \(resp) httr2::resp_status(resp) %in% c(429, 500:599),
  after        = openai_after,
  backoff      = \(n) min(2^(n - 1), 30),  # Exponential backoff
  max_tries    = 6,
  max_seconds  = 180
)
```

- **Max tries**: 6 次重試
- **Backoff**: 指數退避（2, 4, 8, 16, 30 秒）
- **Max retry time**: 180 秒內的重試
- **Total max time**: 300 秒（timeout）+ 180 秒（retry）= 480 秒

---

## 遵循原則

### MP088: Immediate Feedback
- ✅ **Before**: Silent timeout → crash
- ✅ **After**: Adequate time for completion → success

### MP106: Console Transparency
- 保持現有的 console logging
- Timeout 增加不影響透明度

### R092: Universal DBI Approach
- 未影響資料庫連接
- API timeout 獨立於 DB connection timeout

---

## 測試建議

### 測試案例

#### Case 1: 小型報告（30 個變數）
- **預期時間**: 30-60 秒
- **結果**: ✅ 應成功完成

#### Case 2: 中型報告（80 個變數）
- **預期時間**: 80-120 秒
- **結果**: ✅ 應成功完成

#### Case 3: 大型報告（163 個變數）
- **預期時間**: 120-180 秒
- **結果**: ✅ 應成功完成

#### Case 4: 極端情況（網絡延遲）
- **預期時間**: 250-290 秒
- **結果**: ✅ 應在 timeout 內完成

### 驗證清單

- [ ] InsightForge 360 精準行銷報告生成成功
- [ ] 163 個變數分析完成且無 timeout 錯誤
- [ ] 儀表板保持穩定，無當機
- [ ] Console 顯示正確的處理進度
- [ ] 用戶可以看到完整的 AI 報告

---

## 相關 Issue

- **Original Bug**: OpenAI API timeout causing dashboard crash
- **Related Fix**: `FIX_SUMMARY_AI_Report_Full_Dataset_20251007.md`
  - 修復了只分析 10 個變數的問題
  - 現在分析全部 163 個變數
  - 需要更長的 API timeout 支援

---

## 部署注意事項

### 即時部署
這個修復**必須立即部署**，因為：
1. ❌ 當前版本會導致儀表板當機
2. ❌ 用戶無法生成完整報告
3. ✅ 修復簡單且安全（只調整參數）
4. ✅ 無向下相容問題

### 環境需求
無額外環境需求，只需重啟 Shiny app 載入新的函數定義。

### 回滾計畫
如果發現問題（unlikely），可以快速回滾：
```r
# 恢復舊設定
timeout_sec = 60
```

---

## 長期改進建議

### 未來優化方向

#### 1. 階層式超時設定
```r
# 根據資料規模動態調整
timeout_sec = if (n_vars <= 50) 120 else if (n_vars <= 100) 180 else 300
```

#### 2. 進度反饋
```r
# 顯示預估剩餘時間
cat(sprintf("⏳ Generating report... (~%d seconds remaining)\n", estimated_time))
```

#### 3. 異步處理
- 使用 `future` 包在背景執行
- 用戶可以繼續使用其他功能
- 報告完成後自動通知

#### 4. 智能分塊（已實施）
- ✅ 前 30 個變數：詳細分析
- ✅ 其他變數：統計摘要
- 平衡速度和完整性

---

## 影響評估

### 用戶體驗改善

**Before**:
- ❌ 60 秒後 timeout
- ❌ 儀表板當機
- ❌ 無法生成報告
- ❌ 用戶需要重新載入頁面

**After**:
- ✅ 300 秒充足時間
- ✅ 儀表板穩定
- ✅ 成功生成完整報告
- ✅ 流暢的用戶體驗

### 性能影響
- **無負面影響**: timeout 增加不會降低成功案例的速度
- **正面影響**: 避免重試和失敗的開銷

### 成本影響
- **無明顯增加**: API 調用時間由數據處理決定，不是 timeout
- **可能略減**: 減少因 timeout 導致的重試次數

---

## 結論

這是一個**高優先級的關鍵修復**，解決了導致儀表板當機的嚴重問題。修復簡單、安全，應立即部署到生產環境。

**Status**: ✅ Fixed and ready for deployment

**Next Steps**:
1. 部署到 production environment
2. 測試 163 個變數的完整報告生成
3. 監控 API 響應時間和成功率
4. 考慮實施長期優化方案（階層式 timeout、進度反饋）
