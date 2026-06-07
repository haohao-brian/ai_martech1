# 2026-04-26 — QEF Gsheet Three-Surface Redesign 實作 log

**Spectra change**: `qef-gsheet-three-surface-redesign`
**狀態**: in_progress (Phase 1 尚未開工)
**對應 GitHub issues**: #464 (origin), #465 (Track A done), refs #460 / #461 / #462 / #412
**前置 change (archived)**: `2026-04-26-principle-minimize-human-input` (commit `a4f425f`)

---

## 1. 本 change 範圍 vs MP155 spec 分界

Track A 在 commit `a4f425f` 已 ship 兩件東西:

1. **MP155 Meta-Principle**(`shared/global_scripts/00_principles/docs/en/.../MP155_minimize_human_input.qmd`)— 設計階段 contract,定義 4-Question Decision Framework / Three Categories / Three-Surface Model / Pull-not-Push notification
2. **Spec capability**(`openspec/specs/minimize-human-input/spec.md`)— spectra 系統內的可消費 capability,描述「最小化人為輸入」這個 capability 對任何 application 應提供的 normative behavior

本 change 是 **MP155 的第一個 consumer**,**不是 MP155 的修改者**。具體分界:

| 層級 | Track A 已 ship | Track B 本 change |
|---|---|---|
| 原則層 | MP155 .qmd / llm yaml / .claude rules(三層) | 不動 |
| Capability spec | `openspec/specs/minimize-human-input/spec.md` | 不動,只引用 |
| Application | (none) | `qef-product-master-gsheet` capability spec + QEF Gsheet 結構 + shared per-field priority infrastructure |
| Cross-company | (none) | 5 公司 IC_P002 verify(QEF full apply, 4 公司 infrastructure compatible) |

**重要邊界**:本 change implementation 期間**禁止**修改:
- `shared/global_scripts/00_principles/docs/en/.../MP155_minimize_human_input.qmd`
- `shared/global_scripts/00_principles/llm/CH00_meta.yaml` 內的 MP155 entry
- `openspec/specs/minimize-human-input/spec.md`

如發現 MP155 spec 描述不足以指引本 change 實作,應**先**開後續 spectra change 改 MP155(走完整 propose / apply / archive 流程),不可在 Track B 隱性改 contract。

---

## 2. QEF business onboarding 大綱(draft;完整內容於 task 4.2 完成)

對齊 design.md 的「Stakeholders」/「Goals」/「Non-Goals」/「Communication to QEF business」段落。

### 2.1 受影響角色

| 角色 | 變化前 | 變化後 |
|---|---|---|
| QEF 業務(主要) | 在 Master Gsheet 維護整張表(含 ASIN / product_name) | 只維護 Human-Decided 欄;ASIN / product_name 不再手填 |
| QEF 老闆 / 審計 | 須跟業務要報表 | 直接看 Status Gsheet(view-only,anyone-with-link) |
| 工程 / Claude session | 設計 capability 時手動套用 MP155 思考 | 引用 Track B 為 MP155 application reference |
| 4 公司業務 | 無 | 不變(backwards-compat,本 change 不動其 Gsheet) |

### 2.2 期望結果(Goals,給業務看的版本)

- 業務每月在 Master Gsheet 的工作量降低(只補卡住的格,不再維護全表)
- 異常出現時不需被通知;業務想看時直接打開 Status Gsheet 即可
- ASIN 寫錯 / 漏寫不會 silent override sales 的正確值(避免 #403、#460 類問題)
- audit CSV 季度產出,業務 / 老闆可比對「以前手填」vs「現在系統 derive」

### 2.3 明確不做的事(Non-Goals,給業務看的版本)

- ❌ Status Gsheet **沒有** approve 按鈕 / 編輯介面 — 想改值請去 Master Gsheet 補資料
- ❌ Status Gsheet **不會**主動發 email / Slack 通知 — pull-only
- ❌ MAMBA / D_RACING / WISER / kitchenMAMA 的 Gsheet 結構**不變**(屬後續獨立 changes)
- ❌ Master Gsheet 的「SKU to ASIN」tab **不會**被刪除 — 只是改名為 `_archive_*`,業務歷史可查

### 2.4 異常出現時 SOP(精簡版,完整流程於 4.2 onboarding doc)

```
Status Gsheet 出現一筆 anomaly
    ↓
讀 suggested_action 欄文字(例:「Master Gsheet 補上 SKU=ABC 的 brand 為 X」)
    ↓
業務打開 Master Gsheet,在對應位置補上資料
    ↓
等下次 ETL 跑完(daily),Status Gsheet 該筆異常自動消失
```

### 2.5 完整 onboarding doc 將涵蓋

- 一張圖:Master / Status / DuckDB 三 surface 關係
- Status Gsheet 各 tab 用途說明
- 「我看到一筆異常,該怎麼辦」流程
- audit CSV 在哪裡 / 多久產一次
- Rollback runbook(如需回退本 change 怎麼做)

---

## 3. Implementation 順序對齊

對齊 design「Deploy(實作順序)」三 phase:

| Phase | 範圍 | Repo / 路徑 |
|---|---|---|
| 1 (shared infra) | yaml schema + arbitrator refactor + 2 new R fns + 3 unit test files | `shared/global_scripts/{30_global_data, 05_etl_utils/amz, 98_test/etl}` |
| 2 (QEF apply) | app_config + audit script + ETL hook + Status Gsheet 業務動作 | `QEF_DESIGN/`、`shared/update_scripts/ETL/amz/`、QEF Master & Status Gsheet |
| 3 (cross-company) | 4 公司 dry-run + onboarding doc + GitHub issue | `MAMBA/D_RACING/WISER/kitchenMAMA/` + `00_principles/docs/...onboarding...` + GitHub |

**IC_P002 commit message trailer**(每個 commit):
```
Verified: QEF (full apply); MAMBA/D_RACING/WISER/kitchenMAMA (infrastructure compatible, no Gsheet changes in this change)
```

---

## 4. 已完成 tasks

- [x] 1.1 對齊 design「Track A 留下的東西」+「#460 留下的 baseline」+「既有約束」(本 log section 1)
- [x] 1.2 對齊 design「Stakeholders」+「Goals」+「Non-Goals」(本 log section 2)
- [ ] 2.1 onwards — Phase 1 shared infrastructure(尚未開工)

下一步將進入 Phase 1 實作。
