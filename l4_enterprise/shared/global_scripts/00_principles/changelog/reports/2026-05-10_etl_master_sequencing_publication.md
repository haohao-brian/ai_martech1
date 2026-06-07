# ETL Master Sequencing — Publication Announcement

> **Spectra change**: `etl-master-sequencing`
> **Date**: 2026-05-10
> **Author**: Claude (autonomous /spectra-apply Tasks 3.1 + 3.2)
> **Audience**: future AI sessions + human maintainers consulting roadmap

---

## TL;DR

ETL master plan capability `etl-architecture-roadmap` 已 ship。**未來任何 ETL 軸新工作必先 consult roadmap 決定 phase classification(P0 / P1 / P2 / P3)+ 確認 predecessor invariants**。

Roadmap 主要 architectural shift:**canonical schema 從 transformed 層(pre-glue)前移到 raw 層(post-glue)**。

---

## Architectural Shift — Pre-glue vs Post-glue

### Pre-glue era (legacy ETL,2025 之前)

每個公司 × platform × datatype 寫獨立 R 腳本(73 ETL files per #613 audit):

```
Source xlsx                   raw (df_*___raw)              staged (df_*___staged)        transformed (df_*___transformed)
(amazon-order-id, ...)        (源欄名 + 編碼)                (encoding fix)                 (canonical: order_id, ...)
       │                            │                              │                              │
       ▼                            ▼                              ▼                              ▼
   *_ETL_*_0IM.R   ────►    *_ETL_*_1ST.R   ────►   *_ETL_*_2TR.R     ────► DRV reads here
                                                          ▲
                                                          │
                                          Schema mapping 在這裡發生 (2TR phase)
```

- **Canonical schema**: emergent property of transformed layer,each platform 各自定義
- **Cross-platform consistency**: 靠 DRV 層補(amz `order_id` 跟 cbz `order_id` 不保證一致)
- **Onboarding cost**: 新公司 × 新 platform 從零寫 R 腳本

### Post-glue era (current,#489 spectra change `glue-layer-prerawdata-bridge` 落地起)

```
Source xlsx                   raw (df_*___raw)              staged (df_*___staged)        transformed (df_*___transformed)
(amazon-order-id, ...)        (canonical:                   ↑                              ↑
       │                       order_id, customer_id, ...)  │                              │
       │                            ↑                       │                              │
       ▼                            │                       │                              │
   *.bridge.yaml ─►──────► fn_glue_bridge.R                 │                              │
   ↑                       (Layer 2 mapping per source)     │                              │
   Layer 1 schema               ↑                           │                              │
   (core_schemas.yaml)          ▼                           ▼                              ▼
                                                      *_ETL_*_1ST.R                  *_ETL_*_2TR.R
                                                      (quality only,no schema)        (post-canonical
                                                                                       transformation only)
```

- **Canonical schema**: declared in Layer 1 (`core_schemas.yaml` + `platform_extensions/<platform>_extensions.yaml`)
- **Cross-platform consistency**: 強制(MP161 universal vs company-scoped 規範)
- **Onboarding cost**: 新公司 × 新 platform 只要寫 1 個 bridge yaml(per MP158 3-step composition)

### Empirical evidence

QEF_DESIGN/amz 14 個 production bridges + 1 wip bridge 已落地 post-glue 模式:

| Bridge | Lines | Pattern |
|---|---:|---|
| sales.bridge.yaml | 326 | column_mapping 1086 entries(全平台累計)+ apply_fallback 8(schema fallback delegation) |
| reviews.bridge.yaml (wip) | (deferred) | 5 CRITICAL findings under prerawdata-driven model;P2 redesign 後 schema-driven 重做 |
| 12 product_attributes_*.bridge.yaml | 203-527 | per-PL eyewear-specific(MP161 company-scoped) |

**1086 個 `from_column` entries** 證實 column_mapping 是 raw 層的 schema declaration mechanism — 不是「2TR 工作搬到 bridge 偷做」,而是「raw 層本來就該是 canonical」的設計實現。

---

## Roadmap 5 Normative Requirements

完整內容見 `openspec/specs/etl-architecture-roadmap/spec.md`。摘要:

1. **4-Phase Ordering Invariant SHALL Govern All ETL Work** — P0 STABILIZE → P1 VOCABULARY REALIGNMENT → P2 SKILL REDESIGN → P3 AGGRESSIVE MIGRATION,順序強制
2. **Per-Phase Scope Boundary SHALL Be Documented and Enforced** — in-scope / out-of-scope per phase
3. **Canonical Schema SHALL Live at Raw Layer Post-Glue** — Layer 1 declare canonical;bridge yaml mapping;1ST/2TR 不重複 schema work
4. **Vocabulary Realignment SHALL Lift MP Principles in P1** — MP064 / DM_R028 / MP102 / MP104 / MP107 / MP108 amend
5. **In-Flight Closure Recommendations SHALL Provide Per-Change Disposition** — 16 in-flight changes 各標 push-to-done / absorb-into-child / keep-open-until-P3

---

## Walkthrough Scenario — 「為 shp platform 加 sales datatype」

驗證 roadmap 的 ordering invariant + scope boundary 對 fictional new ETL work 給出 deterministic + actionable 路徑(對應 design Decision 1 + Behavior + Interface 段落)。

### Setup

假設 2026 年某公司決定要追蹤 Shopify(shp)平台 sales,目前 codebase 沒有 shp ETL 跟 shp bridge。

### Phase classification flow per roadmap requirement

#### Step 1:Consult `etl-architecture-roadmap` spec

讀 Requirement 2(Per-Phase Scope Boundary):

| Phase | In-scope check | 是否命中? |
|---|---|---|
| P0 STABILIZE | "production fire fixes for ETL/glue/bridge runtime errors" | ❌ 不是 fire fix,是 new datatype |
| P0 STABILIZE | "test infrastructure drift fixes" | ❌ |
| P0 STABILIZE | "push-to-done activities for stabilization-eligible in-flight" | ❌ |
| P1 VOCABULARY | "amendments to MP064 / DM_R028 / MP102 / MP104 / MP107 / MP108" | ❌ 不是 vocabulary work |
| P2 SKILL REDESIGN | "/glue-bridge skill workflow rewrite" | ❌ 不是 skill redesign |
| P2 SKILL REDESIGN | "fn_glue_bridge.R interpreter rewrite" | ❌ |
| P2 SKILL REDESIGN | "Migration tool for 14 existing bridges" | ❌ |
| P3 AGGRESSIVE MIGRATION | "Tier B per-datatype migration: replace 0IM R script with bridge yaml" | ⚠️ 半命中 — 是 datatype 工作,但這 datatype 沒既存 0IM R script,是全新 |
| P3 AGGRESSIVE MIGRATION | "Per-platform IC_P002 verify on each datatype migration" | ⚠️ 半命中 — IC_P002 verify is needed,但 not migration |
| (out-of-roadmap) | new datatype authoring | 待澄清 |

P3 描述用了 「migration」 字眼,跟「new datatype authoring」字面有差。但 spec Requirement 1 說 「all ETL-related work SHALL be classified into one of four phases」,所以必須 fit 進去,不能逃逸。

#### Step 2:Apply MP158 + MP161 + roadmap interaction

MP158 規定 new datatype onboarding 用 3-step composition:enrich Layer 1 → build DDL → write bridge yaml。這在 roadmap 的哪個 phase?

- 如果 Layer 1 已涵蓋(universal datatype like sales)→ 只剩 Step 3 寫 bridge yaml → 屬 P3 scope
- 如果 Layer 1 不涵蓋(company-scoped per MP161)→ 需 Step 1 + Step 2 + Step 3 → 也屬 P3 scope(P3 容納 datatype-level 工作,包括 new + migration)

判定:**P3 work**(new datatype authoring 是 P3 範疇,因為動作機制(寫 bridge yaml)跟 migration(替代 0IM R)是同一機制)。

#### Step 3:Predecessor invariant check

P3 SHALL NOT begin before P1 + P2 done。

- P1(vocabulary realignment)done? → 要等到 `etl-vocabulary-realignment-glue-era` child change apply 完成
- P2(skill redesign)done? → 要等到 `glue-bridge-schema-driven-redesign` child change apply 完成

→ 「為 shp platform 加 sales datatype」**目前 blocked-by P1 + P2**。

#### Step 4:Action items

1. 等 P1 + P2 落地
2. 屆時 file new spectra change `add-shp-sales-datatype`
3. 用 P2 redesign 後的 schema-driven shape 寫 shp/sales.bridge.yaml
4. IC_P002 cross-co verify(若 sales 已 universal,則 verify 影響 5 公司無 regression;若 shp 是 company-specific,則 verify 範圍更窄)

### Verdict

**Walkthrough 結論:P3 work, blocked-by P1 + P2**。

Roadmap 給出 deterministic 路徑(同一 work item 在多次 consult 下都 classify 為 P3),actionable 路徑(列出 4 個 action items 含 dependencies)。Per design 的 Acceptance criteria 通過。

---

## 對 AI Sessions 的指引

未來任何 AI session 接手 ETL 軸工作前:

1. **必讀** `openspec/specs/etl-architecture-roadmap/spec.md`(完整 5 個 normative requirements)
2. **必驗** predecessor invariant — 不要在 P1+P2 done 前啟動 P3
3. **必 reference** Requirement 5 的 closure recommendation table 看 既有 16 in-flight 對應 phase
4. **發現 drift** 用 `00_principles/changelog/scripts/audit_etl_roadmap_drift.sh`(by Task 6.2)+ file follow-up issue per IC_R011

---

## 對 GitHub Issue Triage 的影響

(由 Task 2.2 已落地)

新增 milestones:
- `etl-master-sequencing`(parent)
- `P0-stabilize`(#607 / #621)
- `P1-vocabulary-realignment`(#617)
- `P2-skill-redesign`(#618)
- `P3-aggressive-migration`(#619 / #613)

未來 ETL 軸新 issues 應 assign 對應 milestone 反映 phase classification。

---

## Cross-references

- **etl-architecture-roadmap** spec: `openspec/specs/etl-architecture-roadmap/spec.md`(由 `/spectra-apply` archive 後落地)
- **IC_P002 dry-run**: `00_principles/changelog/reports/2026-05-10_etl_roadmap_ic_p002_dry_run.md`
- **#608** ETL pipeline overhaul umbrella(由 Task 6.3 close,引用本報告)
- **MP158** Glue-Driven Raw Layer Extensibility — 3-step composition 對應 roadmap P3 工作機制
- **MP161** Company-Scoped Schema Recognition — universal vs company-scoped 分類影響 IC_P002 verify scope
- **MP102 v1.3** ETL Output Standardization — bridge yaml authoring contract,roadmap 的上游 spec
