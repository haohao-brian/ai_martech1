# eBay Column Mapping Verification Report

## Executive Summary
This document verifies the alignment between the official codebook.csv definitions and the column mappings used in the eBay ETL scripts.

## BAYORD (Orders) Table Mapping

### Codebook Definitions vs ETL Mappings

| Column | Codebook Description (Chinese) | ETL Mapped Name | Status | Notes |
|--------|-------------------------------|-----------------|--------|-------|
| ORD001 | 單號 (Order Number) | order_id | ✅ Correct | Primary key |
| ORD002 | 其它單號 (Other Order Number) | warehouse_code | ⚠️ Mismatch | Should be "other_order_number" |
| ORD003 | 訂單日期 (Order Date) | order_date | ✅ Correct | |
| ORD004 | 付款日期 (Payment Date) | shipped_date | ⚠️ Mismatch | Should be "payment_date" |
| ORD005 | 付款總額 (Payment Total) | order_status | ❌ Wrong | Should be "payment_total" |
| ORD006 | 付款方式 (Payment Method) | currency_code | ❌ Wrong | Should be "payment_method" |
| ORD007 | 付款幣別 (Payment Currency) | gross_amount | ❌ Wrong | Should be "payment_currency" |
| ORD008 | 賣家EBAY帳號 (Seller eBay Account) | actual_amount | ❌ Wrong | Should be "seller_ebay_account" |
| ORD009 | 賣家EBAY郵件 (Seller eBay Email) | batch_key | ❌ Wrong | Should be "seller_ebay_email" |
| ORD010 | 收件人 (Recipient) | recipient_name | ✅ Correct | |
| ORD011 | Street1 | street_address_1 | ✅ Correct | |
| ORD012 | Street2 | street_address_2 | ✅ Correct | |
| ORD013 | CityName | city | ✅ Correct | |
| ORD014 | StateOrProvince | state | ✅ Correct | |
| ORD015 | PostalCode | postal_code | ✅ Correct | |
| ORD016 | CountryName | country_name | ✅ Correct | Geographic data available |
| ORD017 | 地址來源 (Address Source) | (not mapped) | - | Not in 1ST script |
| ORD018 | 電話區碼 (Phone Area Code) | (not mapped) | - | Not in 1ST script |
| ORD019 | 電話 (Phone) | (not mapped) | - | Not in 1ST script |
| ORD020 | 買家EBAY (Buyer eBay) | (not mapped) | - | Not in 1ST script |
| ORD021 | 運費 (Shipping Fee) | (not mapped) | - | Not in 1ST script |
| ORD022 | 捉取註記 (Capture Note) | (not mapped) | - | Likely the batch_key |

## BAYORE (Order Details) Table Mapping

| Column | Codebook Description (Chinese) | ETL Mapped Name | Status | Notes |
|--------|-------------------------------|-----------------|--------|-------|
| ORE001 | 單號 (Order Number) | order_id | ✅ Correct | Links to BAYORD.ORD001 |
| ORE002 | 流水號 (Serial Number) | line_item_number | ✅ Correct | |
| ORE003 | EBAY商品代號 (eBay Item Code) | warehouse_code | ❌ Wrong | Should be "ebay_item_code" |
| ORE004 | 品名 (Product Name) | transaction_date | ❌ Wrong | Should be "product_name" |
| ORE005 | ERP品號 (ERP Product No) | order_status | ❌ Wrong | Should be "erp_product_no" |
| ORE006 | ApplicationData | product_sku | ⚠️ Mismatch | Should be "application_data" |
| ORE007 | 新舊程度 (Condition) | product_title | ❌ Wrong | Should be "condition" |
| ORE008 | 數量 (Quantity) | product_category | ❌ Wrong | Should be "quantity" |
| ORE009 | 單價 (Unit Price) | quantity | ❌ Wrong | Column shift - ORE009 is unit_price |
| ORE010 | 上架國別 (Listing Country) | unit_price | ❌ Wrong | Column shift - ORE010 is listing_country |
| ORE011 | Email | line_total | ❌ Wrong | Should be "email" |
| ORE012 | StaticAlias | discount_amount | ❌ Wrong | Should be "static_alias" |
| ORE013 | (unnamed in codebook) | batch_key | ⚠️ Unknown | Critical for JOIN |
| ORE014 | (unnamed in codebook) | product_condition | ⚠️ Unknown | |

## Critical Issues Found

### 1. Severe Column Mapping Errors in BAYORD
The current 1ST script has significant mapping errors:
- **ORD005-ORD009**: All mappings are incorrect
- **Payment information** is mapped to wrong fields
- **Seller information** is mapped to amount fields

### 2. Column Shift Error in BAYORE
There appears to be a systematic column shift starting from ORE008:
- ORE008 (Quantity) → mapped to product_category
- ORE009 (Unit Price) → mapped to quantity
- ORE010 (Listing Country) → mapped to unit_price

### 3. Missing Critical Business Fields
- Payment method (ORD006)
- Payment currency (ORD007)
- Seller account info (ORD008, ORD009)
- Buyer eBay ID (ORD020)
- Shipping fee (ORD021)

## Recommended Actions

### Immediate Fixes Required

1. **Fix BAYORD Mappings**:
```r
# Correct mappings based on codebook:
rename(
  order_id = ORD001,           # 單號
  other_order_number = ORD002,  # 其它單號
  order_date = ORD003,          # 訂單日期
  payment_date = ORD004,        # 付款日期
  payment_total = ORD005,       # 付款總額
  payment_method = ORD006,      # 付款方式
  payment_currency = ORD007,    # 付款幣別
  seller_ebay_account = ORD008, # 賣家EBAY帳號
  seller_ebay_email = ORD009,   # 賣家EBAY郵件
  recipient_name = ORD010,      # 收件人
  street_address_1 = ORD011,
  street_address_2 = ORD012,
  city = ORD013,
  state = ORD014,
  postal_code = ORD015,
  country_name = ORD016,
  buyer_ebay_id = ORD020,       # 買家EBAY
  shipping_fee = ORD021,        # 運費
  batch_key = ORD022            # 捉取註記
)
```

2. **Fix BAYORE Mappings**:
```r
# Correct mappings based on codebook:
rename(
  order_id = ORE001,           # 單號
  line_item_number = ORE002,   # 流水號
  ebay_item_code = ORE003,     # EBAY商品代號
  product_name = ORE004,       # 品名
  erp_product_no = ORE005,     # ERP品號
  application_data = ORE006,   # ApplicationData
  condition = ORE007,          # 新舊程度
  quantity = ORE008,           # 數量
  unit_price = ORE009,         # 單價
  listing_country = ORE010,    # 上架國別
  email = ORE011,              # Email
  static_alias = ORE012,       # StaticAlias
  batch_key = ORE013           # For JOIN with BAYORD
)
```

## Data Flow Impact

### JOIN Key Analysis
- **Primary JOIN**: BAYORE.ORE001 ↔ BAYORD.ORD001 (order_id)
- **Batch JOIN**: BAYORE.ORE013 ↔ BAYORD.ORD022 (batch_key)
  - Note: Current mapping has ORD009 as batch_key, but ORD022 is likely correct

### Geographic Analysis Capability
- **ORD016** (CountryName) is correctly available for geographic sales analysis
- Additional geographic fields: ORD013 (City), ORD014 (State), ORD015 (PostalCode)

## Validation Checklist

- [ ] Update eby_ETL_orders_1ST___MAMBA.R with correct mappings
- [ ] Update eby_ETL_order_details_1ST___MAMBA.R with correct mappings
- [ ] Verify JOIN keys after remapping
- [ ] Test data type conversions with new mappings
- [ ] Update documentation to reflect correct field meanings
- [ ] Consider creating a central mapping configuration file

---

**Report Generated**: 2025-08-29
**Severity**: CRITICAL - Production ETL has incorrect column mappings
**Recommendation**: Immediate fix required before further data processing