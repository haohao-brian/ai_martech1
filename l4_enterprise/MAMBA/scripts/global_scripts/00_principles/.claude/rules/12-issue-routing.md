# Issue 路由規則(IC_R010)

**使用時機**:建立 / diagnose / triage GitHub issue 時

---

## 第一動作:標 confidence label

每個 issue **必須**標恰好一個 `confidence:*` label:

| Label | 何時用 |
|---|---|
| `confidence:confirmed` | 客戶 / stakeholder 明確反映,有截圖 / 錯誤 / missing data |
| `confidence:vague` | 來源提到但 form 模糊,需 clarify |
| `confidence:exploratory` | 內部探索 / 學術理論 / brainstorm |

跟既有 `bug` / `enhancement` / `priority:*` / `company:*` / `module:*` / `source:*` **自由疊加**(orthogonal)。

---

## Routing decision tree

```
Q1: confidence 是什麼?

  confirmed
    → source-doc milestone(active sprint,e.g. 向創建議_20260411)
    + 適用的 Company project + Module project
    Close = 客戶滿意 / spec done

  vague
    → source-doc milestone + needs:scope-clarification label + Company project
    Close = 對齊後升 confirmed 或降 exploratory

  exploratory
    Q2: team 已 commit 要做嗎?
      
      not yet (just considering)
        → Lab project(e.g. Marketing Theory Lab) "Considering" column ONLY
        + NO milestone
        Close = drop 或 升 vague
      
      committed-future
        → Lab project "Future Planning" column
        + Future Planning milestone
        Close = 內部團隊 ship / drop 決定
```

---

## 5 destinations(canonical)

| Destination | 用途 | Close 條件 |
|---|---|---|
| Source-doc milestone(`<source>_<date>`)| 客戶反映 cycle | 客戶滿意 / spec done |
| `Future Planning` milestone(repo-wide singleton,no due date)| Team-committed but unscheduled | 內部 ship / drop 決定 |
| Lab project(`<topic> Lab`)| 探索性 organizational tracker | drop 或 upgrade 後移出 |
| Company project(既有 `company:*`) | per-company 跨 milestone tracking | issue close |
| Module project(既有 `module:*`)| per-module 跨 company tracking | issue close |

Lab project 標準 4 columns:`Considering` / `Future Planning` / `In Progress` / `Done`(對應 schedule 軸)。

---

## State machine

```
[New issue]
   │
   ├─ confidence:exploratory + Lab only ──┬─ [team commits]──→ + Future Planning milestone
   │                                      │
   │                                      └─ [drop]──→ close
   │
   ├─ confidence:vague + source-doc milestone ──┬─ [clarify]──→ confidence:confirmed
   │                                            │
   │                                            └─ [downgrade]──→ confidence:exploratory
   │
   └─ confidence:confirmed + source-doc milestone ──→ close
      [客戶滿意 / verify pass]
```

每個 transition 對應具體 `gh issue edit` 操作:label 改 + milestone 改 + project column 改。

---

## Plugin step(idd-issue / idd-diagnose)

### `idd-issue` Step 4.4 — Source Confidence Triage

**觸發 predicate**:
- 來源是 document file(`.docx` / `.pdf` / `.md`)
- 該 invocation 建 ≥ 2 個 issue

**行為**:scan body keyword regex → 建議 confidence → AskUserQuestion 確認 → apply label + route。
**不命中 predicate**:silent-skip。

### `idd-diagnose` Step 3.4 — Re-evaluate Source Confidence

**觸發 predicate**:issue 已有 `confidence:*` label

**行為**:re-scan diagnosis content → 比對 current label → mismatch 則 AskUserQuestion(keep/upgrade/downgrade)。
**不命中**:silent-skip。

### Heuristic patterns(advisory only)

| Signal type | Suggests | Examples |
|---|---|---|
| Specific scholar 全名 | `exploratory` | `Keller` / `Holt` / `Kapferer` / `Sinek` / `Ansoff` |
| Structured prompt template | `exploratory` | `prompt:` / `Stage 1` / `步驟一` |
| Algorithm references | `exploratory` | `K-means` / `chi-square` / `卡方檢定` / `Cox PH` |
| Image attachment | `confirmed` | `![...](...)` markdown |
| Error / missing-data language | `confirmed` | `沒有資料` / `無數據` / `錯誤` / `crash` |
| Customer voice | `confirmed` | `客戶反映` / `客戶提到` |
| Default(no signal match)| `vague` | — |

**User override always wins**。

---

## 常見錯誤(anti-pattern)

| 錯誤 | 正確 |
|---|---|
| `confidence:exploratory` issue 放 source-doc milestone | exploratory 屬 Lab project ± Future Planning,**不**進 source-doc milestone |
| 自動 apply label 不問 user | Step 4.4 / 3.4 必須 AskUserQuestion;silent classify 是 violation |
| 把 confidence 當成 type 取代 | confidence + bug 可共存(orthogonal),不取代 |
| Future Planning 設 due date | repo-wide singleton 無 due date,設 due date = INVARIANT 4 violation |
| Lab project columns 重新排序 | 必須 `Considering` / `Future Planning` / `In Progress` / `Done` 順序 |

---

## Backfill / migration 範例

**Migrate 1 個 exploratory issue**(e.g., #406 K-means):

```bash
# 1. 加 label
gh issue edit 406 --repo kiki830621/ai_martech_global_scripts \
  --add-label "confidence:exploratory"

# 2. 移出 milestone
gh issue edit 406 --repo kiki830621/ai_martech_global_scripts \
  --milestone ""    # remove milestone

# 3. 加到 Lab project(GitHub UI 或 gh project item-add)
gh project item-add <Marketing Theory Lab project number> \
  --owner kiki830621 \
  --url "https://github.com/kiki830621/ai_martech_global_scripts/issues/406"

# 4. 在 issue 留 cross-link comment
gh issue comment 406 --repo kiki830621/ai_martech_global_scripts \
  --body "Migrated to Marketing Theory Lab per IC_R010 (issue routing)..."
```

---

## Rollback escape hatch

緊急狀況(plugin step 造成 marketplace consumer 問題):

```bash
SKIP_CONFIDENCE_TRIAGE=true Rscript ...
```

讓 `idd-issue` Step 4.4 + `idd-diagnose` Step 3.4 silent-skip。Manual triage(直接 `gh issue edit --add-label confidence:*`)仍可用。

---

## 完整原則

`docs/en/part1_principles/CH06_integration_collaboration/rules/IC_R010_issue_source_confidence_triage.qmd`(Layer 1 權威來源)

## 相關原則

- **IC_R007**:GitHub Issue Attachments(sister:同 axis)
- **IC_R008**:Issue Scope Governance(sister:per-company / per-module label;IC_R010 加 confidence + schedule axes)
- **IC_R009**:Bidirectional Commit-Issue Traceability(sister:closure discipline;IC_R010 governs routing pre-closure)
- **MP155**:Minimize Human Input(sibling:heuristic 機械化 first-pass,user override 永遠 wins)
- **DOC_R009**:Triple-Layer Sync
