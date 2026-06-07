# Case Study: Email Archive Workflow (che-apple-mail-mcp v2.7 → v2.9)

A real-world adoption of NSQL outside its original SQL/data-query domain. The
`che-apple-mail-mcp` Claude Code plugin adapts NSQL's 4-phase confirmation
protocol to Apple Mail archive operations, then iteratively hardens it from
spec-level to enforce-level using IDD-style task tracking.

> **TL;DR**: NSQL ports cleanly to email operations. But "AI follows the
> spec" is not the same as "AI follows the spec under load" — the gap was
> only closed by binding each NSQL phase to a `TaskCreate`'d harness item
> that becomes a UI-visible incomplete task if skipped.

---

## Domain mapping

| NSQL concept (data query)                | Email-domain analogue                                  |
|------------------------------------------|--------------------------------------------------------|
| Pipeline (`from X -> filter -> sort`)    | `Mail -> filter(sender = ...) -> sort(date desc)`     |
| Disambiguation (vague business term)     | Vague filter ("陳老師", "最近的信", "VIP 寄來的")       |
| Operation Confirmation (UPDATE 247 rows) | "Will write 18 markdown files + download 1 attachment" |
| Destructive op confirmation              | `delete_email`, `empty Trash`, bulk `move_email`       |
| Skip conditions (precise where clause)   | Explicit `Message-ID`, single `mark_read`, pure search |

Skill files in the plugin:
- `skills/confirmation-protocol/SKILL.md` — overall 4-phase workflow
- `skills/email-search-disambiguation/SKILL.md` — Phase 1 triggers (E1–E5)
- `skills/bulk-operation-preview/SKILL.md` — Phase 2 preview format
- `rules/false-positive-detection.md` — flag patterns (sibling activity, CC pollution, subject collision)
- `rules/confirmation-triggers.md` — when to confirm, when to skip

---

## Why the port was needed (the 2026-05-01 incident)

User asked Claude to archive emails related to "陳老師" (Prof. Chen). The
plugin ran sender-search, fetched 19 emails, wrote markdown — and only
afterward did anyone notice that one email (id 265250, subject 應徵資料科學
統計合作社…) was sent to a different recipient: `scchen@stat.sinica.edu.tw`,
not `cchen`. The substring "陳" / "cchen" had matched a sibling lab.

Cleanup cost: `rm` the markdown, manually edit `email_index.json` and
`threads.json` to remove the orphan entry, write down the lesson.

This is exactly the failure mode NSQL is designed for: **vague filter +
bulk side-effect operation, no preview before execute**.

---

## v2.7.0 — NSQL adopted at spec level

Three new skills + two new rules + a refactored `commands/archive-mail.md`
that documents 4 phases:

```
Phase 1: Disambiguation       — vague filter? list candidates, let user pick
Phase 2: Search Preview       — show thread breakdown + flag false positives
Phase 3: Operation Confirm    — show file count + attachment size before write
Phase 4: Execute or Iterate   — execute / narrow / abort
```

Skip conditions: precise email address in filter, `--no-confirm` flag,
single `Message-ID` operation, etc.

Pipeline-style format for filter (borrowed from NSQL):

```
Mail
  -> filter(sender = '...' OR recipient = '...' OR subject contains '...')
  -> sort(date desc)
```

Operation format for destructive ops (borrowed from NSQL):

```
DELETE on Mail
with sender = "spam@example.com"
affecting 247 emails

⚠ This operation cannot be undone (Trash auto-purges after 30 days)

Confirm execution?
```

---

## v2.8.0 — namespace consolidation (orthogonal but related)

Adopted IDD's `.claude/.idd/` pattern. Config + state collapsed to
`.claude/.mail/` namespace:

```
.claude/.mail/
├── config.md                              # was .claude/emails.md
└── state/archives/{slug}/
    ├── email_index.json                   # was {output_dir}/.email_index.json
    └── threads.json                       # was {output_dir}/.threads.json
```

Auto-migration on every `archive-mail` / `view` / `rebuild-threads` invocation.
Not part of NSQL itself but reduces config drift that could feed Phase 1
disambiguation noise.

---

## v2.9.0 — the spec/enforce gap, closed

After v2.7/v2.8 shipped, an honest assessment surfaced an uncomfortable fact:

> Architecture is solid (4 phases written down, false-positive rule documented,
> skills wired up). **Behavior is still spec-level**. Whether Phase 2 preview
> actually fires hinges on Claude reading the markdown spec and deciding to
> follow it. Under conversational load, Claude can rationalize away phases
> ("應該還好吧") and silently skip the false-positive scan — exactly the
> 2026-05-01 incident path.

The fix: borrow IDD's "Step 0: Bootstrap Stage Task List (鐵律)" pattern.
**The first action of `/archive-mail` and of `confirmation-protocol` skill
must be `TaskCreate` calls that register every downstream phase as a
harness-level todo item.** Each phase mark-completes immediately on
finish. **Silent completion = violation.**

```
# /archive-mail Step 0 — required before any other action
TaskCreate(subject="resolve_filter_and_paths", ...)
TaskCreate(subject="phase1_disambiguation", ...)
TaskCreate(subject="load_indices_and_config", ...)
TaskCreate(subject="search_emails", ...)
TaskCreate(subject="filter_and_scan_false_positives", ...)
TaskCreate(subject="phase2_3_preview_and_confirm", ...)
TaskCreate(subject="fetch_and_write_markdown", ...)
TaskCreate(subject="download_and_classify_attachments", ...)
TaskCreate(subject="update_indices", ...)
TaskCreate(subject="report_and_audit", ...)
```

Skippable phases (e.g., explicit email address skips Phase 1) **must still
`TaskUpdate → completed` with skip-reason in the description**. Not doing
the work is fine. Not recording why is the violation.

---

## Stress test (same day v2.9.0 deployed)

User invoked `/archive-mail` with no arguments. The plugin:

1. **Bootstrap fired**: 10 stage tasks created before any other action.
2. **Phase 1 disambiguation triggered**: User said "陳老師實驗室都要、老師
   助理都要" — vague. Plugin enumerated 4 candidates from existing
   `threads.json` participants (cchen, 林助理, yijulee, tsoping) and asked
   user to pick scope. User narrowed to cchen + 林助理.
3. **Search ran on 6 accounts in parallel**: sender + subject + recipient
   searches, 17 raw hits.
4. **False-positive scan (the enforced task) caught 3 ⚠⚠**:
   - Wedding invitation with 100+ recipients including `charlenejcchen@gmail.com`
     — the substring "cchen" matched.
   - **Email id 265250** — the original 2026-05-01 incident email
     (`scchen@stat.sinica.edu.tw`). This time it was caught before write.
   - Email to `wcchen@ntu.edu.tw` (NTU professor, unrelated course
     recruitment).

   All three were surfaced **only by recipient search**; sender-only search
   would never have seen them. Without enforced false-positive scan as a
   `TaskCreate`'d step, the recipient-search expansion would have silently
   added them to the corpus.
5. **Phase 2/3 skipped honestly**: After dedup, 0 new emails to write. Skip
   conditions met. Each phase still `TaskUpdate completed` with a skip
   reason in the description. Not silent — visible in the harness UI.

Final report explicitly listed the 3 false positives that were caught and
held back, so the user could verify the catch.

---

## What NSQL deliberately does *not* solve (out of scope, by design)

These came up in conversation as "things NSQL didn't give us" but on
closer look they aren't NSQL's job. Listing them so future adopters
don't mis-attribute them as protocol limitations:

- **Entity / contact resolution** — "who counts as 陳老師's lab?" is an
  ontology question (LDAP, CardDAV, address book, prior thread
  participants). NSQL's Phase 1 disambiguation surfaces the *ambiguity*;
  resolving the candidates is the host application's responsibility.
- **Domain-specific search depth** — bare-subject thread expansion vs
  full `In-Reply-To` chain traversal is an engineering choice in the
  mail plugin, not something NSQL specifies. Different domains will pick
  different traversal strategies.
- **Round-trip overhead on truly precise operations** — yes, `get_email`
  by Message-ID under NSQL would be pure overhead. But this is *handled*
  by the protocol: `confirmation-triggers.md`-style skip conditions
  (precise identifier, single read-only op, `--no-confirm`) are
  first-class in the spec. Adopters are expected to define their skip
  list, not bypass the protocol entirely.

## Real protocol-level limitations (worth knowing about)

These *are* NSQL's responsibility and adopters should plan for them:

- **Pipeline syntax assumes some structural literacy** — `Mail ->
  filter(...) -> sort(...)` reads cleanly to anyone who has seen a
  shell pipe or SQL. For a fully non-technical audience the host may
  need a second-render path (natural-language paraphrase of the
  pipeline). NSQL doesn't currently spec one.
- **False-positive flagging is host-defined** — NSQL says Phase 2
  preview should flag false positives; it does not provide a generic
  detection algorithm. Each domain re-invents it (mail uses sibling
  activity / CC pollution / subject collision; SQL uses cardinality
  estimates; bulk file ops would use path-pattern collision; etc.).
  Worth surveying these implementations to extract patterns that could
  be lifted up into the spec.
- **No built-in enforcement** — this is the biggest one. NSQL is a
  *protocol*, not a *runtime*. If the host LLM doesn't follow it, NSQL
  itself has no recourse. v2.9.0's `TaskCreate`-per-phase pattern
  (borrowed from IDD) is the host-side commitment device that makes
  enforcement observable. NSQL the spec might want to acknowledge this
  and recommend a host-level enforcement mechanism rather than rely on
  "the LLM will follow the spec because it's documented".

---

## Lessons for NSQL adopters

### 1. NSQL ports outside SQL cleanly when the operation has the same shape

The shape is: **vague natural-language input + irreversible side effect at
scale**. Email archive matches. So would: bulk file moves, Slack message
deletion, calendar event creation, IDE refactors that touch many files.

The shape is *not*: read-only single-resource fetches. Those are pure
overhead under NSQL — the plugin's `confirmation-triggers.md` lists explicit
skip conditions to keep them lightweight.

### 2. Pipeline format works in non-SQL domains

`Mail -> filter(...) -> sort(...)` is just as legible as the SQL version.
Users absorb it in the same 2-3 seconds. Don't feel obliged to invent a
domain-specific notation — the SQL-derived pipeline already reads fine.

### 3. Disambiguation triggers are domain-specific; copy the *shape* not the *list*

Original NSQL D1–D5 (vague time, undefined business term, ambiguous metric,
etc.) became E1–E5 in email-search-disambiguation skill (vague person name,
relative time like "最近", generic scope like "全部", etc.). The taxonomy
template carried over; the items underneath had to be re-derived for the
email domain.

### 4. **Spec ≠ enforcement.** Bind every NSQL phase to a `TaskCreate`

This is the load-bearing lesson. NSQL's protocol can be perfectly written
down, perfectly understood, and still skipped under load. The fix is not
more documentation — it's a harness-level commitment device. Every phase
becomes a task; the task either marks completed (with a reason if skipped)
or stands as a visibly-incomplete reminder in the UI.

The 2026-05-01 incident proves this is not paranoia. v2.7.0 shipped the
spec; v2.9.0's stress test caught 3 false positives the v2.7.0 design
*should* have caught but in practice didn't, because spec-level
"recommended" kept losing to "this looks fine, just write it".

### 5. Skip-with-reason > silent skip

Counter-intuitively, the most useful effect of enforced task tracking
isn't preventing skips — many skips are correct. It's making *every* skip
visible-and-justified. That distinction is what lets reviewers (and
future-you) audit whether a skip was a careful judgement or a silent
omission.

---

## References

- Plugin source: https://github.com/PsychQuant/psychquant-claude-plugins/tree/main/plugins/che-apple-mail-mcp
- Original incident archive: `.claude/.mail/state/archives/communications-emails/` in the chchen-postdoc-2026 repo (private)
- IDD enforcement pattern (the `TaskCreate` model copied for v2.9.0):
  `plugins/issue-driven-dev/skills/idd-implement/SKILL.md` Step 0 section
- NSQL spec: this repo's `protocol.yaml` and `docs/concept.md`

## Versions referenced

- che-apple-mail-mcp v2.7.0 — NSQL spec adopted (skills + rules)
- che-apple-mail-mcp v2.8.0 — `.claude/.mail/` namespace (orthogonal)
- che-apple-mail-mcp v2.9.0 — `TaskCreate` enforcement (this case study)
- issue-driven-dev v2.18.0+ — origin of the Step 0 Bootstrap pattern
- NSQL v3.1 — schema-aware confirmation protocol (current)
