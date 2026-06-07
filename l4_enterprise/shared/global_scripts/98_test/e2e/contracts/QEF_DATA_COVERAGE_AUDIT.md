# QEF_DESIGN Data Coverage Audit (向創_20260520.docx cluster)

> **Generated**: 2026-05-21 by `/idd-all #795 #797 #807 #808 --pr` cluster work
> **Status**: investigation phase — documents known data-coverage gaps surfaced by client suggestion document. Real fix (ETL backfill / UI empty-state / contract gating decisions) deferred to follow-up sessions.
> **Cluster issues**: #795 / #797 / #807 / #808
> **Upstream issue**: #774 (sfg/psg/rpl df_amz_sales_complete_time_series_* empty)

---

## TL;DR

向創設計於 2026-05-20 提交建議文件,反映 **3 個 product_line** 在多個 dashboard module 完全無數據。本文件**集中歸檔**該 cluster 的已知資料缺口 + 對應 fix scope,作為下一輪 implement session 的 starting point。

---

## Known-empty (PL × module) matrix

| Product Line | Code | dashboardOverview | TagPilot | VitalSigns | BrandEdge 市場賽道 | InsightForge 時間區段 | Source |
|---|---|---|---|---|---|---|---|
| 動力運動護目鏡 | `psg` | ❌ empty | ❌ empty | ❌ empty | ❌ empty | ❌ empty | #774, #795, #807, #808 |
| 替換鏡片 | `rpl` | ❌ empty | ❌ empty | ❌ empty | ❌ empty | ❌ empty | #774, #795, #807, #808 |
| 安全眼鏡 | `sgf` | (partial) | (partial) | (partial) | ❌ empty | ❌ empty | #774, #797, #807, #808 |
| 套鏡式太陽眼鏡 | `sfo` | partial | partial | partial | partial | partial | #797 (predictor count = 10, expected more) |

> **Legend**: ❌ empty = 0 rows or fallback HTML rendered;partial = some panels render but predictors / facets incomplete

---

## Common root cause(per #774 investigation chain)

Upstream `df_amz_sales_complete_time_series_<pl>` 在 sgf / psg / rpl 三個 PL 是空表 →
- D04 Poisson derivation 沒輸入 → 對應 `df_amz_poisson_analysis_<pl>` 0 rows
- D05 macro trend 沒輸入 → `df_amz_macro_monthly_summary_<pl>` 缺 PL
- D01 customer DNA 沒輸入 → `df_dna_by_customer_<pl>` 空
- 所有 dashboard module 從這些 DRV table reactive `tbl2(con, ...)` → collect() 0 rows → fallback HTML

InsightForge predictor count(`sfg` 只 10 個)— 不是 0,可能 root cause 略不同:
- product attribute extraction(reviews → AI scoring)pipeline 不完整
- 或 D04 schema 對 sfg 的 predictor_type 分佈不均

---

## Fix scope decision matrix(per cluster issue)

| Approach | Fix scope | 工程量 | Trade-off |
|---|---|---|---|
| **A. Data layer fix(ETL backfill)** | 修 ETL/D04/D05/D01,讓 sgf/psg/rpl 真的有資料 | 多日 + 業務協調(向創需確認這些 PL 是否真的有銷售) | 治本但風險最高 |
| **B. UI empty-state** | 每個 module 加 explicit empty-state UI(per MP163 visible-gap sentinel) | 1-2 天(觸及 5 modules × ≥2 PL) | 中等;不解決資料問題但提升 UX |
| **C. Contract YAML severity downgrade** | `qef_design.yaml` 對 sgf/psg/rpl 改 `severity: warning`(per MP165 v1.3) | 30 分鐘 | 最小工程量;**違反 contract author 原意**(per qef_design.yaml top comment 明示 critical 是故意保留以推動資料補齊) |
| **D. Mark PL as inactive in app_config.yaml** | 從 active_product_lines 移除 sgf/psg/rpl | 5 分鐘 + IC_P002 cross-co | 短期效果但客戶會看不到產品線 dropdown,需業務確認 |

**建議路徑(per /idd-all-chain 上游 spec discussion)**: A + B 並行
- A 屬 ops/data engineering work,需 ETL audit + 向創業務協調(本文件不 cover)
- B 屬 UI engineering,單 PR 可 ship,作為 user-facing 改善 first

---

## InsightForge predictor count diagnostic(#797)

`sfg` 套鏡式太陽眼鏡 predictor 只 10 個,合理 expectation:
- Time features(weekday + month):7 + 12 = 19
- Product attributes(per QEF 12 categories):~30+
- Promotion / sales features:~5-10

Total expected: 50+。**10 個說明 D04 input 的 product_master + sales_join 嚴重不足**,需獨立調查。

可能 root cause:
1. `df_amz_products_<sfg>` 缺欄位(per QEF product master complexity)— 需檢 `01_db/raw_schema/_authoring/companies/QEF_DESIGN/`
2. AI scoring(reviews → attribute scores)未跑完(per #601 spirit)
3. Joining logic 在 D04 對 sfg 失效(可能 schema mismatch)

---

## E2E contract status

`shared/global_scripts/98_test/e2e/contracts/qef_design.yaml` 對 sgf/psg/rpl 維持 `severity: critical` per author intent(comment 明示「BrandEdge contracts are EXPECTED to fail — that surfaces the data-quality gap correctly」)。

本 audit 文件**不**降級 contract — 維持 critical 作為 deploy-gate pressure,推動 data layer fix。

---

## Next session checklist

### Path A(data layer)
- [ ] 向創業務確認 sgf / psg / rpl 在 Amazon 上是否真的有 active SKU + 訂單
- [ ] 如有,audit ETL 為何沒抓到(可能 product_master 缺 mapping)
- [ ] 如真無訂單,走 Path D + 業務協調預期

### Path B(UI empty-state)
- [ ] 列出受影響的 5+ Shiny components(tagpilot / vitalsigns / position/ * / poisson / D05 trend)
- [ ] 設計 unified empty-state pattern(可放 `04_utils/fn_render_empty_state.R`)
- [ ] 各 component reactive 加 `if (nrow(data) == 0) return(empty_state_ui(...))` 
- [ ] Wiki 更新(per DOC_R006):TagPilot.md / VitalSigns.md / BrandEdge.md 加「無資料 PL 行為」
- [ ] cross-co IC_P002 verify(5 公司,empty-state 不同 PL 但行為一致)

### Path C(coverage audit table — MP163 implementation)
- [ ] 新建 `df_qef_coverage_audit` table(per MP163 § 3 Surface-to-Attention Gaps)
- [ ] D-group derivation script 自動生成(每次 ETL 跑完寫回)
- [ ] Dashboard 新增「Data Coverage」tab(business team-visible)

---

## Provenance

- **首次版本**: 2026-05-21,由 `/idd-all #795 #797 #807 #808 --pr` cluster session 產出
- **限制**:本文件為 audit + planning artifact,**不**是 code fix
- **下次 session 直接 starting point**:依 Path A/B/C trade-off 跟客戶 + 老師對齊後選一條走

Refs #774, #795, #797, #807, #808
