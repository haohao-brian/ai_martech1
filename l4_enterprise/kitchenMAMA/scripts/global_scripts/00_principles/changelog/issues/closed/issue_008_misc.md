---
issue: "ISSUE_008"
title: "Fix of bug"
severity: "medium"
component: "general"
app: "mamba"
created: "2025-01-01"
status: "closed"
---

# Fix of bug

## global_scripts/17_transform/fn_transform_sales_to_sales_by_customer.by_date.R

-   [x] May have negative IPT (Or fn_transform_sales_by_customer.by_date_to_sales_by_customer.R)

Solution: set oder in data setorder(df,customer_id,date )

## fn_analysis_dna.R

\~/Library/CloudStorage/Dropbox/precision_marketing/precision_marketing_MAMBA/precision_marketing_app/update_scripts/D01_04_P07.R

use

\~/Library/CloudStorage/Dropbox/precision_marketing/precision_marketing_MAMBA/precision_marketing_app/update_scripts/global_scripts/04_utils/fn_analysis_dna.R

-   [x] ni產生ni.x和ni.y

-   [ ] 看看還有什麼方法可以變更快

nes 計算用到 merge 兩個有ni 的 table。用cleancolnames 把dup 的一個拿掉 check fixed point

```         
Calculating NES metrics... Fixing duplicated column: ni
```
