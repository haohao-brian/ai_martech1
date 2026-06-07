# Funnel Math + D05 Trend Cluster Audit (向創_20260520.docx)

> **Generated**: 2026-05-21 by /idd-all-chain goal cluster session
> **Status**: investigation phase — root cause + fix-scope catalog ready,real implementation 推遲(multi-day work,risk-sensitive boundary,跨 IC_P002 5 公司 verify)
> **Cluster issues**: #800 / #801 / #802 / #803 + #799(P1+P2 合併)
> **Related**: per /idd-diagnose comments,#800-#803 + #799 同 root cause family — 分母 / 分子 / 時間軸定義不一致

---

## TL;DR

向創設計於 2026-05-20 提出 **5 個關聯 issue**,全部源於同一個 systemic problem:
- **分母混亂**(per #800/#801/#802)
- **時間軸 baseline 錯**(per #803)
- **聚合維度缺**(per #799 by-brand/category MoM/QoQ)

這 5 個 issue **不是獨立 bug**,是「客戶生命週期 + 業績趨勢」這個分析家族的**架構不一致**。Fix 需:
1. 統一 funnel / retention / conversion 分母定義 → 跨 04_utils + 多 UI 元件
2. D05 trend 加未完整月處理 → 改 fn_D05_01_core + downstream UI
3. D05 by-brand/category 新表 → 新 DRV scripts + UI 圖表 + Wiki QoQ 新增

**估算 7-15 person-days**。本 session **不**做 real code change,只 distill 設計 + decision matrix。

---

## Root cause family — 共同訊號

| Issue | Symptom 客戶看到 | 共同 root cause |
|---|---|---|
| #800 | 獲客漏斗首購 100% + 階段相加 > 100% + 轉化率/新增率 = 100% | 分母從「有購買 N」切換到「客戶總數」不一致 |
| #801 | 顧客回購率超級高 | 同上 — 分母過小(只算「有購買」)讓比率虛高 |
| #802 | 轉換漏斗 1 次購買 = 100% | funnel(cumulative)vs distribution(partition)語意混淆 |
| #803 | MoM/YoY 對未完整月(2026/3 partial)算出怪數 | D05 時間軸 baseline 沒過濾未完整月 |
| #799 | 業績成長驗證全空 + 缺 brand/category MoM/QoQ | D05 缺 by-brand / by-category 維度;新功能 |

**模式**:全部跟「分母 / baseline 定義」有關。

---

## Fix scope per issue

### #800 獲客漏斗(P1)

**真正 fix**:
1. 統一分母為「客戶總數 N(含未購買訪客)」
2. 各階段以「累積 nested subset」呈現,嚴格遞減(首購 ≥ 回購 ≥ 多次 ≥ 核心)
3. 互補性指標(「新客占比」+「老客占比」加總 100)改名 + 分開 KPI 卡

**檔案**:
- `04_utils/fn_analysis_dna.R` 公式
- `10_rshinyapp_components/tagpilot/` / `vitalsigns/` funnel UI 元件
- Wiki 新建 `Term-Funnel.md`

**估算**:2 days(含 IC_P002)

### #801 回購率(P1)

**真正 fix**:
1. Audit 既有公式 — customer-level vs order-level 哪個
2. 統一為 customer-level(`(購買≥2)/(總客戶 incl. visitors)`)
3. UI 加 tooltip 公式說明

**檔案**:
- `04_utils/fn_analysis_dna.R` / `fn_analysis_btyd.R` 相關公式
- VitalSigns / TagPilot retention tab UI
- Wiki `Term-Repurchase-Rate.md` 新建

**估算**:1.5 days

### #802 轉換漏斗 distribution(P1)

**真正 fix**:
- 改 UI 從 cumulative funnel → distribution(各購買次數 % 加總 = 100)
- 或加 toggle 讓 user 選兩種視角
- 命名重整:「轉換漏斗」(cumulative)/ 「購買次數分布」(distribution)

**檔案**:
- UI 元件(同 #800 範圍)
- Wiki 新建 `Term-Purchase-Frequency-Distribution.md`

**估算**:1 day(含與 #800 共修部分)

### #803 MoM/YoY 未完整月(P1)

**真正 fix**(per `fn_D05_01_core.R:200, 232-257`):
- 在 `aggregate_monthly()` 結束加 helper `is_partial_month(yyyy_mm, today, lag_days)` 判定
- 加 column `is_partial_month: bool` to `df_macro_monthly_summary`
- Downstream UI 過濾 `is_partial_month = TRUE` 不畫
- 或:在 D05 末尾直接 filter 掉未完整月

**檔案**:
- `16_derivations/fn_D05_01_core.R` 計算 + schema
- 所有用 `df_macro_monthly_summary` 的 trend chart UI(macro/dashboardOverview / VitalSigns trends)
- Wiki `Term-MoM.md` / `Term-YoY.md` 補「未完整月處理」原則

**估算**:1.5 days(D05 schema change → IC_P002 5 公司 verify)

### #799 業績成長驗證 + by-brand/category(P2)

**真正 fix**:
1. **子題 1 業績驗證空白**:trace 哪個 module/element name「業績成長驗證」對應 → fix UI wiring(可能就是 #803 fix 結果)
2. **子題 2 by-brand/category MoM/QoQ**:
   - 新 DRV scripts:`fn_D05_02_by_brand.R` / `fn_D05_03_by_category.R`(per DM_R066 platform-agnostic)
   - 新表:`df_amz_macro_monthly_summary_by_brand`、`df_amz_macro_quarterly_summary_by_brand`(加 QoQ)+ category 對等
   - UI:4 個新圖表 + 切換維度 toggle
   - Wiki 新建 `Term-QoQ.md`

**檔案**:
- `16_derivations/fn_D05_02_*.R` 新檔
- `update_scripts/DRV/all/all_D05_02_*.R`(per DM_R066)
- `_targets.R` 加新 target
- BrandEdge / dashboardOverview UI
- Wiki `Term-QoQ.md`(目前只有 MoM/YoY)

**估算**:2 days

### Cluster total

**Real implementation effort**:約 8-10 person-days,跨 D05 derivation + 4 個 UI 元件 + Wiki 5 個 Term page + IC_P002 5 公司 verify。

---

## 為什麼本 session 不 ship real fix

1. **Risk-sensitive boundary**:funnel 數學語意是核心 KPI(VitalSigns 漏斗 / TagPilot retention 兩個模組都用)— fix 修錯影響整個 dashboard 可信度
2. **IC_P002 cost**:5 公司 verify 1.5-2 days 額外負擔
3. **客戶 communication 需要**:fix 後數值會大幅變化(首購可能從 100% 變 20%),需主動告訴向創原因
4. **Cluster cohesion**:#800-#803 真的是 cluster — 拆開逐個 fix 會修同一段 code 多次,效率低
5. **Spectra-tier candidates**:funnel 數學重設可能涉及 Spec contract change(downstream 模組依賴「funnel 階段是 nested」),per MP102 可能需 spec authoring → 真要 ship 需走 `/spectra-discuss` rather than `/idd-all`

---

## Recommended next session plan

### Option A — 走 spectra workflow(對 cluster 嚴肅處理)

```
/spectra-discuss
# 對齊 funnel 分母統一定義 + 公式透明度 + 跨模組一致性
→ /spectra-propose qef-funnel-math-redesign
→ /spectra-apply
```

### Option B — 走 idd-all-chain cluster

```
/idd-all-chain #800 #801 #802 #803 #799
# 由於 Plan tier + EnterPlanMode approval gate,user 有機會 review 完整 Implementation Plan
```

### Option C — 拆 atomic / 各自 P-plan-gated

最保守:逐個 `/idd-all #N` 各自 review,適合 user 想 partial ship。但 cluster cohesion 損失,改同段 code N 次。

---

## Refs

#774 #795 #797 #807 #808(data coverage,本 PR cover 已 audit)
#800 #801 #802 #803 #799(funnel + D05 cluster,本 audit cover)
#796 #806 #798(P1 standalone,#806 / #798 fix 已在 PR #809)
#804 #805(spectra-discuss scaffold,跨 #406/#407 supersede 待裁決)

Milestone: 向創建議_20260520
