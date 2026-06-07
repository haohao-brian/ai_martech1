---
issue: "ISSUE_076"
title: "追蹤並確保所有金額正確換算為美金"
severity: "high"
component: "data_quality"
app: "mamba"
created: "2025-11-02"
status: "working"
assigned_to: "Data Quality Team"
priority: "high"
tags: ["currency", "data_quality", "etl", "price_standardization"]
---

## Problem

需要系統性追蹤和驗證所有金額欄位都正確換算為美金，確保跨平台、跨貨幣的價格數據可以直接比較和分析。

**背景脈絡**：
- ISSUE_243 解決了 `original_price` 顯示問題（排除混合貨幣欄位）
- 但這只是表面處理，需要更根本地追蹤整個系統的金額換算邏輯
- 確保所有用於分析的價格欄位都是標準化的美金金額

## Expected Behavior

### 1. 金額欄位標準化
所有用於分析的金額欄位應該：
- 統一換算為美金 (USD)
- 清楚標示貨幣單位
- 可追溯換算來源和匯率

### 2. 欄位命名規範
建立清楚的命名慣例：
- `price_usd` - 已換算美金價格 ✅
- `converted_price` - 已轉換價格 ✅
- `price` - 主要價格欄位（如果已標準化）✅
- `original_price` - 原始貨幣價格 ❌ (僅供參考，不用於分析)
- `local_price` - 當地貨幣價格 ❌ (僅供參考)

### 3. 資料完整性檢查
- 所有產品都有美金換算價格
- 換算比率合理性驗證
- 缺失值處理規範

## Actual Behavior

**目前狀態待確認**：
- [ ] 哪些表格包含價格欄位？
- [ ] 哪些欄位已經是美金？哪些不是？
- [ ] 換算邏輯在哪裡實作？（ETL? 應用層？）
- [ ] 是否有匯率表？更新頻率？
- [ ] 不同平台（CBZ, AMZ）的處理是否一致？

## Investigation Tasks

### Phase 1: 盤點現有狀況

#### 1.1 資料庫欄位清查
```sql
-- 需要檢查的表格
- df_cbz_order_item
- df_cbz_product
- df_amz_order_item
- df_amz_product
-- ... 其他包含價格的表格

-- 需要檢查的欄位
- price
- original_price
- price_usd
- converted_price
- unit_price
- total_price
-- ... 所有價格相關欄位
```

#### 1.2 ETL 換算邏輯追蹤
```r
# 需要檢查的 ETL 腳本
- scripts/update_scripts/cbz_ETL*.R
- scripts/update_scripts/amz_ETL*.R
- scripts/global_scripts/01_db/currency_conversion.R (如果存在)

# 需要確認
- 換算在哪一層發生？（1ST? 2TR?）
- 使用什麼匯率？
- 匯率來源？更新頻率？
```

#### 1.3 應用層使用情況
```r
# 檢查各組件使用哪些價格欄位
- Poisson regression analysis
- Positioning analysis
- Trend analysis
- Customer segmentation

# 確認是否都使用標準化欄位
```

### Phase 2: 建立追蹤機制

#### 2.1 建立欄位清單文檔
```yaml
# currency_fields_registry.yaml
price_fields:
  standardized:
    - name: "price_usd"
      description: "美金換算價格"
      source: "ETL layer conversion"
      used_in: ["poisson", "positioning", "trend"]
    - name: "converted_price"
      description: "標準化價格"
      source: "ETL layer conversion"
      used_in: ["segmentation"]

  non_standardized:
    - name: "original_price"
      description: "原始貨幣價格"
      status: "excluded from analysis (ISSUE_243)"
      reason: "Mixed currencies"
    - name: "local_price"
      description: "當地貨幣價格"
      status: "excluded from analysis (ISSUE_243)"
      reason: "Not standardized"

conversion_logic:
  cbz_platform:
    source_currency: "CNY"
    target_currency: "USD"
    rate_source: "manual/api/database"
    update_frequency: "daily/weekly/static"

  amz_platform:
    source_currency: "varies"
    target_currency: "USD"
    rate_source: "..."
    update_frequency: "..."
```

#### 2.2 換算驗證腳本
```r
# scripts/global_scripts/98_test/test_currency_conversion.R
test_currency_conversion_completeness <- function() {
  # 檢查所有產品都有美金價格
  # 檢查換算比率合理性
  # 檢查缺失值處理
}

test_currency_conversion_consistency <- function() {
  # 檢查同一產品不同表格價格一致性
  # 檢查跨平台換算邏輯一致性
}
```

### Phase 3: 改進建議

#### 3.1 短期改進（1-2週）
- [ ] 完成欄位清查
- [ ] 文檔化現有換算邏輯
- [ ] 建立驗證測試

#### 3.2 中期改進（1-2月）
- [ ] 統一換算邏輯到 ETL 層
- [ ] 建立匯率管理機制
- [ ] 自動化驗證流程

#### 3.3 長期規劃（3-6月）
- [ ] 多幣別支援架構
- [ ] 即時匯率更新
- [ ] 歷史匯率追蹤

## Proposed Resolution

### 建議架構

#### 1. ETL Layer 統一換算
```r
# 在 2TR (Transform) 階段統一處理
fn_convert_to_usd <- function(amount, currency, conversion_date) {
  # 1. 查詢匯率表
  # 2. 執行換算
  # 3. 記錄換算資訊
  # 4. 返回標準化金額
}

# 應用於所有價格欄位
price_usd <- fn_convert_to_usd(original_price, source_currency, order_date)
```

#### 2. 匯率管理
```sql
-- 建立匯率表
CREATE TABLE exchange_rates (
  currency_pair VARCHAR(10),  -- 'CNY/USD', 'EUR/USD'
  rate DECIMAL(10, 6),
  effective_date DATE,
  source VARCHAR(50),
  created_at TIMESTAMP
);

-- 索引以提升查詢效能
CREATE INDEX idx_rates_date ON exchange_rates(currency_pair, effective_date);
```

#### 3. 資料品質檢查
```r
# 在 ETL 完成後執行
validate_price_conversion <- function(con) {
  # 檢查 1: 所有記錄都有 price_usd
  missing_usd <- tbl2(con, "df_cbz_order_item") %>%
    filter(is.na(price_usd)) %>%
    count() %>%
    collect()

  # 檢查 2: 換算比率合理性
  suspicious_rates <- tbl2(con, "df_cbz_order_item") %>%
    mutate(implied_rate = price_usd / original_price) %>%
    filter(implied_rate < 0.1 | implied_rate > 10) %>%
    collect()

  # 檢查 3: 價格一致性
  # ...

  return(validation_report)
}
```

## Related Issues

- **ISSUE_243**: Exclude original_price from Poisson analysis (已解決)
  - 相關：ISSUE_243 排除顯示，本 issue 追蹤根本換算邏輯
  - 關係：ISSUE_243 是表面處理，ISSUE_254 是系統性解決

## Dependencies

- ETL 腳本修改
- 資料庫 schema 可能需要調整（匯率表）
- 測試資料準備
- 文檔更新

## Success Criteria

### 可驗證的成功指標

1. **完整性**：所有產品都有美金換算價格（100% coverage）
2. **一致性**：同一產品在不同表格的價格一致
3. **可追溯性**：能追蹤每筆換算的來源和匯率
4. **自動化**：換算驗證納入 CI/CD 流程
5. **文檔化**：清楚的欄位說明和使用指南

## Priority Justification

**為何 HIGH Priority**：

1. **資料品質核心**：價格是分析的基礎指標
2. **跨境業務需求**：多平台、多貨幣是常態
3. **決策可靠性**：錯誤的價格換算會導致錯誤決策
4. **系統性影響**：影響所有下游分析組件
5. **法規遵循**：財務報表需要準確的貨幣轉換

## Risk Assessment

### 不處理的風險

- 分析結果不可靠（混合貨幣比較）
- 商業決策錯誤（基於錯誤數據）
- 用戶信任度下降
- 數據品質債務累積

### 處理的風險

- ETL 邏輯修改可能影響現有流程
- 匯率管理增加系統複雜度
- 需要時間進行完整測試

**風險緩解**：
- 分階段實施
- 完整的測試覆蓋
- 保留舊邏輯作為備份
- 詳細文檔化

## Notes

### 調查起點

1. **資料庫檢查**
   ```r
   # 查看 CBZ 訂單價格欄位
   con <- dbConnect_universal()
   tbl2(con, "df_cbz_order_item") %>% glimpse()

   # 檢查是否有 price_usd 欄位
   # 檢查 original_price 分布
   # 查看是否有 currency 欄位
   ```

2. **ETL 腳本檢查**
   ```bash
   # 搜尋價格換算相關程式碼
   cd scripts/update_scripts
   grep -r "price" cbz_ETL*.R
   grep -r "convert" cbz_ETL*.R
   grep -r "usd\|USD" cbz_ETL*.R
   ```

3. **已知欄位（從 ISSUE_243）**
   - `original_price` - 混合貨幣（已排除顯示）
   - `price_usd` - 應該存在的標準化欄位
   - `converted_price` - 可能存在的標準化欄位

### 下一步行動

1. [ ] 建立價格欄位盤點清單
2. [ ] 追蹤 ETL 換算邏輯
3. [ ] 設計匯率管理機制
4. [ ] 建立驗證測試框架
5. [ ] 文檔化發現和建議

---

**Created by**: MAMBA Framework AI Team
**Created date**: 2025-11-02
**Status**: Working - Investigation Phase
**Next review**: 待與團隊討論優先順序和資源分配
