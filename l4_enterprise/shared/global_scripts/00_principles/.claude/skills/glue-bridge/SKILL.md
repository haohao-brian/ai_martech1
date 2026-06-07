---
name: glue-bridge
description: Use this skill EVERY TIME the user wants to write a bridge yaml that maps per-company prerawdata (GSheet / xlsx / CSV / API) to the canonical raw layer. Triggers — "write a bridge", "generate a bridge for X", "onboard company X to glue layer", "bridge product_profile_blb", "create products bridge for QEF", or any mention of `_authoring/bridges/`, `fn_glue_bridge`, the glue layer, prerawdata, or schema fingerprint. Drives end-to-end codegen — inspect prerawdata source → compute fingerprint → read canonical schema → assemble LLM prompt → draft yaml → validate → request human review → commit. NOT a runtime LLM caller — runtime uses the deterministic R interpreter `fn_glue_bridge.R` only; this skill is codegen-time only and the only path that touches an LLM in this architecture.
---

# glue-bridge — Generate prerawdata bridge mappings

This skill is the **codegen-time** workflow for authoring bridge yamls. Production runtime (`fn_glue_bridge.R`) is interpreter-only — no LLM, no dynamic-R-execution patterns, no remote network access. The skill exists to make bridge authoring fast, accurate, and auditable.

## ⚡ v2.0 (2026-05-11) Schema-Driven Workflow — DEFAULT

Per `etl-architecture-roadmap` Requirement 2 P2 scope + per `glue-bridge-schema-driven-shape` capability spec, the canonical authoring workflow is **schema-driven (top-down)** for new bridge authoring as of 2026-05-11.

### 5-step schema-driven authoring flow

1. **Read canonical schema** (Layer 1) — `01_db/raw_schema/_authoring/core_schemas.yaml` (universal datatypes) or `01_db/raw_schema/_authoring/companies/<COMPANY>/<datatype>.yaml` (company-scoped per MP161) — list `required_fields` + `optional_fields` for the target datatype.
2. **Read source structure** — inspect prerawdata (xlsx/csv/gsheet/API) to learn its column names.
3. **For each canonical field, declare an extractor** in `field_extractors:` (see Extractor Type Reference below). The bridge yaml is structured top-down: schema declares what's needed, extractors specify how to get it.
4. **Reverse-coverage check** — every source column should appear in either an extractor's reference OR be explicitly listed in `unused_source_columns:`. Source columns not covered emit WARNING (advisory, non-blocking). Replaces pre-v2.0 MP160 enumeration tax.
5. **Validate + commit** — `Rscript scripts/validate_bridge_yaml.R` then commit per MP102 v1.3 self-converging review structure.

### Extractor Type Reference

| Extractor type | Use case | YAML example |
|---|---|---|
| `column` | Direct mapping from source column to canonical | `{type: column, name: "amazon-order-id", coercion: "as.character + trimws"}` |
| `const` | Constant value not from source | `{type: const, value: "amz"}` |
| `derive` | Computed from other extracted fields | `{type: derive, expression: "unit_price * quantity"}` |
| `sha256` | Cryptographic hash of multiple fields | `{type: sha256, components: ["product_id", "customer_id", "review_date"]}` |
| `regex` | Pattern extraction from a source field | `{type: regex, source_field: "review_url", pattern: "/R([A-Z0-9]+)$"}` |

### Schema-driven bridge yaml shape

```yaml
canonical_target:
  datatype: sales
  platform: amz
  company: QEF_DESIGN

prerawdata_source:
  type: xlsx
  pattern: "data_unstructured/QEF_DESIGN/amz/sales/*.xlsx"

field_extractors:
  order_id:
    type: column
    name: "amazon-order-id"
    coercion: "as.character + trimws"
  customer_id:
    type: column
    name: "amazon-order-id"          # surrogate per pre-glue convention
    coercion: "as.character + trimws"
  total_amount:
    type: derive
    expression: "unit_price * quantity"
  platform_id:
    type: const
    value: "amz"
  import_timestamp:
    type: const
    value: "Sys.time()"               # interpreted at run time

unused_source_columns:                # reverse-coverage list (advisory, replaces MP160 enumeration)
  - "is-business-order"
  - "is-iba"

reviewed_by:                          # MP102 v1.3 structure preserved (see v1.3 self-converging review)
  human_reviewer: "<github-handle>"
  review_mode: "glue-ensemble-v1"
  ai_reviewers: [...]
  findings_summary: {critical: 0, high: 0, ...}
  approved_at: "<ISO 8601 UTC>"
  approved_in_commit: "<git-sha>"
```

### Shape detection at runtime

`fn_glue_bridge.R` detects bridge yaml shape via top-level key presence:

- `field_extractors:` present → schema-driven path (v2.0)
- `column_mapping:` present → legacy prerawdata-driven path (v1.x) + deprecation WARNING
- Both present → ERROR (shape ambiguity)
- Neither present → ERROR (invalid bridge yaml)

### Migration from legacy column_mapping shape (Task 6.4 onboarding section)

If you're amending an existing bridge that uses the legacy `column_mapping` shape (any of the 14 QEF_DESIGN/amz bridges authored before 2026-05-11), you can:

1. **Auto-convert via migration tool**:
   ```bash
   cd shared/global_scripts/01_db/raw_schema/_authoring
   Rscript migrate_bridge_to_field_extractors.R bridges/<COMPANY>/<platform>/<datatype>.bridge.yaml --in-place
   ```
   The `--in-place` flag rewrites the file directly; omit it to produce a `.bridge.v2.yaml` sibling for diff review first.

2. **Migration tool behavior**:
   - Idempotent: re-running on already-migrated yaml is a no-op
   - Faithfully preserves all source semantics (`from_column` → `column` extractor with same `coercion`, `apply_fallback + derive` → matching `derive`/`sha256`/`regex` extractor, etc.)
   - Renames `ignored_columns:` → `unused_source_columns:` (semantic rename per v2.0 reverse-coverage check)
   - Pre-existing legacy CRITICAL issues persist after migration (migration tool transforms shape, not content; address per-datatype follow-up)

3. **Continue authoring against migrated yaml** using the schema-driven 5-step flow above.

| Legacy `column_mapping` entry | v2.0 `field_extractors` equivalent |
|---|---|
| `from_column: "amazon-order-id"` + `coercion: "as.character"` | `{type: column, name: "amazon-order-id", coercion: "as.character"}` |
| `use_value: "amz"` | `{type: const, value: "amz"}` |
| `apply_fallback: true` + `derive: "unit_price * quantity"` | `{type: derive, expression: "unit_price * quantity"}` |
| `apply_fallback: true` + `derive: "sha256(a + b + c)"` | `{type: sha256, components: [a, b, c]}` |
| `apply_fallback: true` + `derive: "extract_regex(field, 'pattern')"` | `{type: regex, source_field: field, pattern: "pattern"}` |
| `apply_fallback: true` (no derive — schema fallback handles) | (entry removed; schema fallback applied automatically) |

## ⚠️ Legacy prerawdata-driven workflow — DEPRECATED 2026-08-31

The pre-v2.0 `column_mapping` + `ignored_columns` shape (Steps 0-10 below) remains **accepted by `fn_glue_bridge.R` runtime** during the deprecation window (2026-05-11 → 2026-08-31). After deadline, runtime SHALL refuse legacy shape with explicit error.

Existing 14 production bridges (QEF_DESIGN/amz/*) authored under legacy shape; use migration tool `01_db/raw_schema/_authoring/migrate_bridge_to_field_extractors.R` to convert. Per `etl-architecture-roadmap` Requirement 2 P3 scope, per-datatype migration completes the transition.

New bridge authoring SHOULD use the v2.0 schema-driven workflow above. The legacy 11-step workflow below remains documented for reference until 2026-08-31 deprecation deadline.

---

## When to use

- Onboarding a new company that has prerawdata which doesn't yet have a bridge.
- New platform / new datatype combination for an existing company (e.g., QEF_DESIGN starts selling on Shopify).
- Schema drift detection halted at runtime and a human reviewer needs to regenerate the bridge yaml.
- Adding a new product line / new source tab that maps to the canonical raw layer.

## When NOT to use

- Runtime ETL — that's `fn_glue_bridge()` directly, not this skill.
- Schema content changes (renames, new required fields, type changes) — those go through MP102 amendment + DOC_R009 triple-layer sync, not a per-company bridge.
- Modifying canonical schema (`core_schemas.yaml`, `platform_extensions/*.yaml`) — that is Layer 1 work owned by MP102; this skill only authors Layer 2 (bridge yamls).

## Architecture context (1-paragraph)

The glue layer (#489) splits schema authoring into two yamls per MP157: Layer 1 = canonical schema (`01_db/raw_schema/_authoring/core_schemas.yaml` + `platform_extensions/*.yaml`, universal contract, DDL codegen target); Layer 2 = bridge yaml per `(company, platform, source)` tuple at `01_db/raw_schema/_authoring/bridges/{COMPANY}/{platform}/{source}.bridge.yaml`. This skill produces Layer 2 yamls. Per MP158, growing the canonical raw layer is repeatable: schema yaml + DDL codegen + bridge yaml = new raw table. Read `shared/handbook/onboarding/glue-bridge-onboarding.md` for the operational handbook + 5 known gotchas before authoring an unfamiliar source.

## Operational workflow — execute these steps in order

The agent invoking this skill (you) drives an 11-step workflow (Step 0 + Steps 1-10). Use the **AskUserQuestion** tool at the marked decision points; otherwise execute the commands as written. Do not skip steps — each one closes a class of bug surfaced during the #489 Phase 5 PoC + the qef-product-master-redesign Phase 9 review.

### Step 0 — Immutability preflight (MP159) — DO NOT SKIP

Before doing anything else, read this preflight aloud (so the user knows the rule is in effect):

> **MP159 — Glue Authoring Boundary Immutability**
>
> This skill flow SHALL NOT modify Layer 1 canonical schema files:
>
> - `shared/global_scripts/01_db/raw_schema/_authoring/core_schemas.yaml`
> - `shared/global_scripts/01_db/raw_schema/_authoring/platform_extensions/*_extensions.yaml`
> - `shared/global_scripts/01_db/raw_schema/_authoring/_meta_schema.yaml`
>
> When the source cannot be cleanly mapped, the un-mappable parts go inside the bridge yaml using:
>
> | Situation | Bridge primitive |
> |---|---|
> | Source has unexpected column | `ignored_columns:` |
> | Source missing canonical required field | `apply_fallback: true` (delegate to schema fallback) or `use_value:` (per-co constant) |
> | Source uses unusual encoding (e.g. 標竿產品 / 競爭對手) | `value_map:` |
> | Source has data-quality issues to skip rows | `pre_filter:` |
> | Source has multiple columns mapping to one canonical field | `from_columns: + merge_strategy:` (DM_R065) |
>
> **If during this skill flow you find that Layer 1 needs editing**, STOP. Do not edit Layer 1 here. Instead:
>
> 1. Inform the user: "this bridge requires a Layer 1 change; that needs its own change spec"
> 2. Suggest: "open a separate spectra change spec for the Layer 1 work first; come back to bridge authoring after it lands"
> 3. End the skill flow without writing the bridge.
>
> **Exception**: if the user explicitly asked you to do Layer 1 work (e.g., "refactor the products schema"), then this is NOT a glue-bridge skill flow — it's a Layer 1 refactor task, and MP159 doesn't apply.

The validator at Step 7 (`validate_bridge_yaml.R`) enforces this mechanically by checking that every canonical field referenced in the bridge's `column_mapping` exists in the current `core_schemas.yaml` or applicable `platform_extensions/{platform}_extensions.yaml`. A reference to a field that doesn't exist suggests Layer 1 was edited mid-session and the edit was reverted — CRITICAL violation.

Acknowledge this preflight in writing (one sentence, e.g., "Step 0 acknowledged; Layer 1 will not be modified during this bridge authoring session"), then proceed to Step 1.

### Step 1 — Gather inputs from the user

Ask the user (via AskUserQuestion if available, otherwise plain text) for:

- **Company code** (matches `l4_enterprise/{COMPANY}/`): e.g., `QEF_DESIGN`, `MAMBA`, `D_RACING`, `WISER`, `kitchenMAMA`
- **Platform**: e.g., `amz`, `cbz`, `eby`, `shp`, `official_website`
- **Datatype**: one of `sales` / `customers` / `orders` / `products` / `reviews`, or for products datatype with D11 split, a per-PL attribute datatype (`product_attributes_{pl_id}`) or `company_product_extension`
- **Source identifier** (used as bridge yaml basename): e.g., `sales`, `products_profile_blb`, `company_product_extension`
- **Source type**: `gsheet` / `xlsx` / `csv` / `api`
- **Source location**:
  - For gsheet: `sheet_id` + `sheet_name`
  - For xlsx: file path (relative to project root or absolute)
  - For csv: file path
  - For api: API endpoint URL + auth method

Capture these into shell variables for use in subsequent steps. If any answer is unclear, ask follow-up questions before proceeding.

### Step 2 — Read the prerawdata schema (column names + types)

Read the source via R, capturing column names and inferred types. **Use a FULL read, not a truncated sample** — see Gotcha #1 below. Run via Bash:

```bash
Rscript -e '
source("shared/global_scripts/05_etl_utils/glue/fn_hash_prerawdata_schema.R")
suppressPackageStartupMessages({library(<source-reader-pkg>)})
df <- <source-reader-call>(<source-args>)  # FULL read, no n_max
cols <- colnames(df)
types <- infer_column_types_for_fingerprint(df)  # normalized helper (matches runtime per #628)
cat("Columns (", length(cols), "):\n", sep="")
for (i in seq_along(cols)) cat(sprintf("  %2d. %s : %s\n", i, cols[i], types[i]))
cat("\nNrow:", nrow(df), "\n")
' 2>&1
```

Reader package per source type:
- gsheet → `googlesheets4::read_sheet(googlesheets4::as_sheets_id(sheet_id), sheet = sheet_name)` (assumes auth cached via `gs4_auth(cache = TRUE)`)
- xlsx → `readxl::read_excel(path)` (no `n_max`)
- csv → `readr::read_csv(path, show_col_types = FALSE)`
- api → use the company's existing API client

Show the column list to the user. If anything looks wrong (e.g., expected columns missing, suspicious types), pause and clarify before fingerprinting.

### Step 3 — Compute the schema fingerprint

Use the canonical fingerprint helper. The fingerprint MUST be computed using `infer_column_types_for_fingerprint()` (NOT raw `class(x)[1]`) so it matches the runtime computation in `fn_glue_bridge.R`. The helper normalizes all-NA logical columns to `"character"` per #501 D3, preventing false-positive drift when a column flips from all-NA to typed values between fingerprint time and runtime.

**Important** (per #628 + fix-glue-layer-infra-blockers 2026-05-12): Use the canonical helper `infer_column_types_for_fingerprint(df)`, not raw `vapply(df, function(x) class(x)[1], character(1))`. The two methods diverge for any source column that is `all-NA` (raw method returns `"logical"`, normalized returns `"character"`). Bridge yaml stores the authoring-time fingerprint; runtime computes the normalized fingerprint via `infer_column_types_for_fingerprint`. If you author with the raw method, the stored fingerprint will never match runtime, causing every bridge run to halt with false-positive "Schema drift detected".

Run via Bash:

```bash
Rscript -e '
source("shared/global_scripts/05_etl_utils/glue/fn_hash_prerawdata_schema.R")
suppressPackageStartupMessages({library(<source-reader-pkg>)})
df <- <source-reader-call>(<source-args>)
fp <- hash_prerawdata_schema(
  column_names = colnames(df),
  column_types = infer_column_types_for_fingerprint(df)
)
cat("algorithm:", fp$algorithm, "\nvalue:", fp$value, "\nnrows_used:", nrow(df), "\n")
' 2>&1
```

Save the fingerprint value — it goes into the bridge yaml `prerawdata_source.schema_fingerprint`. Also capture the `nrows_used` for the bridge's `fingerprinted_against` field (humans reading the yaml later need to know what file size produced the hash).

### Step 4 — Read the canonical schema yamls

Read both Layer 1 yamls so the LLM prompt has the full canonical contract to map against:

```bash
SCHEMA_PATH="shared/global_scripts/01_db/raw_schema/_authoring/core_schemas.yaml"
EXT_PATH="shared/global_scripts/01_db/raw_schema/_authoring/platform_extensions/${PLATFORM}_extensions.yaml"
```

Read with the Read tool. Verify the requested datatype exists in `core_schemas.yaml` and the platform extension yaml exists. If the platform extension is missing, that's a Layer 1 gap — pause and ask whether to (a) extend the canonical schema yaml first (separate Layer 1 work), or (b) proceed without extension (rare; only for platforms with no platform-specific fields).

For products datatype under D11 (per `qef-product-master-redesign` Phase 9), the datatype name will be one of: `products` (thin master), `product_attributes_{pl_id}` (per-PL attribute table), or `company_product_extension` (SKU-keyed financial). The schema yaml must declare each as a separate datatype entry.

### Step 5 — Assemble the LLM prompt via the prompt builder

Source the skill-only helper (only file in the codebase that touches LLM machinery — declares `LLM_CODEGEN_TIME_ONLY = TRUE`) and call its prompt builder:

```bash
Rscript -e '
source("shared/global_scripts/05_etl_utils/glue/fn_call_llm_for_mapping.R")
source("shared/global_scripts/05_etl_utils/glue/fn_hash_prerawdata_schema.R")
suppressPackageStartupMessages({library(<reader-pkg>); library(yaml)})

df <- <source-reader-call>(<source-args>)
cols <- colnames(df)
types <- infer_column_types_for_fingerprint(df)  # normalized helper (matches runtime per #628)
fp <- hash_prerawdata_schema(cols, types)
prerawdata_columns <- setNames(types, cols)

canonical <- paste(readLines("shared/global_scripts/01_db/raw_schema/_authoring/core_schemas.yaml"),
                   collapse = "\n")
ext_path <- paste0("shared/global_scripts/01_db/raw_schema/_authoring/platform_extensions/",
                   "<platform>_extensions.yaml")
extension <- if (file.exists(ext_path)) {
  paste(readLines(ext_path), collapse = "\n")
} else ""

prompt <- build_bridge_codegen_prompt(
  company = "<company>",
  platform = "<platform>",
  datatype = "<datatype>",
  prerawdata_columns = prerawdata_columns,
  schema_fingerprint = fp,
  canonical_schema_yaml = canonical,
  platform_extension_yaml = extension
)
cat(prompt)
' > /tmp/glue_bridge_prompt.txt 2>&1
```

The prompt encodes the contract: every required canonical field must have a `column_mapping` / `derive_from` / `apply_fallback` / `use_value` decision; every prerawdata column must either appear in `column_mapping` or in `ignored_columns`; `reviewed_by` must be the placeholder `"REQUIRES_HUMAN_REVIEW"` (a human reviewer fills it before commit).

### Step 6 — Self-converging codegen + ensemble review loop

This is the largest change in skill v1.2 (per spectra change `glue-bridge-self-converging-review`, issue #500). Step 6 was previously "generate the draft yaml". It is now a **closed loop** with five sub-steps (6a-6e) that terminate only by content-based convergence — not by iteration count, not by human override. Output is a ship-ready bridge with structured `reviewed_by` provenance and a co-located audit trail.

#### Step 6a — Codegen draft (initial bridge yaml)

You (the agent invoking this skill) read `/tmp/glue_bridge_prompt.txt` and **directly produce the draft bridge yaml** — write it to disk at the canonical location:

```bash
BRIDGE_DIR="shared/global_scripts/01_db/raw_schema/_authoring/bridges/${COMPANY}/${PLATFORM}"
mkdir -p "$BRIDGE_DIR"
BRIDGE_PATH="$BRIDGE_DIR/${SOURCE}.bridge.yaml"
REVIEW_LOG_PATH="$BRIDGE_DIR/${SOURCE}.bridge.review.md"
```

Use the **Write tool** to author the yaml. Conform to the template in `## Bridge yaml schema` below. Reference Gotchas 1-5 — the LLM should pre-emptively handle each known pitfall:

- Match column names case-insensitively against `aliases:` in the canonical schema.
- Use `value_map:` for any value-translation (e.g., long-form → short-code).
- Use `use_value:` for per-company constants the source doesn't carry.
- Use `pre_filter:` to exclude rows that violate the canonical schema before mapping (e.g., cancelled orders out of `sales`).
- Apply `apply_fallback: true` to delegate to schema-defined fallback rules (sentinels, derive_from rules).

Set `reviewed_by: "REQUIRES_HUMAN_REVIEW"` in the draft (placeholder; will be overwritten by Step 6e structured form on convergence).

Set `generated_by: "glue-bridge skill v1.2"` and `generated_at:` to current ISO 8601 UTC timestamp.

##### MP160 — Exhaustive Enumeration (mandatory at draft stage)

Per **MP160 (AI Schema/Bridge Authoring Completeness)**, the draft you write SHALL satisfy the following set equality:

```
set(source_columns) === set(column_mapping.keys.from_column ∪ from_columns)
                       ∪ set(ignored_columns)
```

Every column the source actually has MUST be either mapped (via `from_column` / `from_columns`) or explicitly listed in `ignored_columns:`. Partial coverage is **forbidden** under MP160 — this is not a "best effort" — it is a contract.

Concrete rules for the AI agent generating the draft:

- **No empty `ignored_columns:`** when the source has columns beyond the canonical-required fields. If 80 source columns exist and `column_mapping` covers 30, then `ignored_columns:` MUST list exactly 50 columns.
- **No "TODO" / "TBD" placeholder** entries. If a source column's handling is genuinely undecided, list it in `ignored_columns:` with a one-line `# TBD: pending business decision` comment as a placeholder reason — but the column MUST still appear in the enumeration. The ensemble in Step 6b will surface and resolve genuine TBD cases.
- **No "pilot one then replicate"** patterns when the bridge generator is iterating across multiple datatypes / PLs in one session. Author every variant fully in the same pass; AI authoring time is cheap, downstream rework is expensive.
- **`apply_fallback: true` and `use_value:` entries do NOT consume a source column**. They emit constants / fallback values, so listing them does NOT make a source column accounted-for. The corresponding source column (if any) must still appear in either `column_mapping[*].from_column` or `ignored_columns:`.

Legal partial-completion escape hatch — `wip/` subdirectory:

- Bridges in `bridges/{COMPANY}/wip/{platform}/` are exempt from MP160 enforcement (the validator emits an INFO-level skip).
- WIP bridges are NOT consumed by `fn_glue_bridge` runtime; they exist for iteration only.
- Promote a bridge from `wip/` to `bridges/{COMPANY}/{platform}/` only after MP160 enumeration is complete.

#### Step 6b — Spawn 4-agent ensemble review

Invoke the orchestration helper which spawns four reviewer agents in parallel against the just-written draft:

```bash
Rscript -e '
source("shared/global_scripts/00_principles/.claude/skills/glue-bridge/scripts/run_ensemble_review.R")
result <- run_ensemble_review(
  bridge_path        = "'"$BRIDGE_PATH"'",
  source_csv_path    = "'"$SOURCE_CSV_PATH"'",
  schema_yaml_paths  = c(
    canonical = "shared/global_scripts/01_db/raw_schema/_authoring/core_schemas.yaml",
    extension = "shared/global_scripts/01_db/raw_schema/_authoring/platform_extensions/'"$PLATFORM"'_extensions.yaml"
  ),
  review_log_path    = "'"$REVIEW_LOG_PATH"'",
  iteration_n        = '"$ITERATION_N"'
)
cat(sprintf("verdict: %s\nfindings_count: %d\nfindings_hash: %s\n",
            result$verdict, result$findings_count, result$findings_hash))
' 2>&1
```

The four reviewer roles (full prompt templates in `## Reviewer roles for the ensemble` section below):

1. **codex-cli** — cross-model independent verification (gpt-5.5 with `model_reasoning_effort="xhigh"` and `service_tier="fast"`)
2. **claude-correctness** — data semantics, MP160 mechanical enumeration, business-semantic spot-check
3. **claude-security** — value tampering, governance gates, fingerprint integrity, hardcoded secrets
4. **claude-devils-advocate** — rebut other reviewers' PASS / LOW judgments, surface systemic blind spots

(The `architecture` reviewer role from `/parallel-ai-agents:ensemble-code-review` is **not used** here. Codegen plus the validator already enforce structural correctness for bridges; an architecture-lens reviewer added negligible value in the pilot session and its 11 PASS judgments were all overruled by Devil's Advocate.)

#### Step 6c — Collect findings + write iteration entry to review log

The orchestration helper appends one `## Iteration N` section to `$REVIEW_LOG_PATH` per iteration, structured as:

```markdown
## Iteration N — <ISO 8601 UTC>

**Reviewers**: codex-cli@0.124, claude-correctness@opus-4-7, claude-security@opus-4-7, claude-devils-advocate@opus-4-7

**Findings**: <count> (<criticals> CRITICAL / <highs> HIGH / <mediums> MEDIUM / <lows> LOW)

| ID  | Severity | Source              | Description                       |
|-----|----------|---------------------|-----------------------------------|
| C-1 | CRITICAL | correctness         | sku NA ...                        |
...

**Findings hash**: <sha256-of-sorted-finding-tuples>

**Codegen response (iteration N → N+1)**: <summary of fixes applied if not converged>

**Result**: <count> findings remain (<...>)
```

The `findings_hash` field is the input to plateau detection (Step 6d). The hash covers the deterministic tuple `(severity, rule_id, file, line, summary)` per finding, sorted then sha256.

#### Step 6d — Check convergence terminators (3 stopping conditions)

Evaluate the iteration's outcome against the three terminators (any one fires → STOP loop):

| # | Terminator | Condition | Action |
|---|------------|-----------|--------|
| 1 | **CONVERGED** | `findings_summary.critical == 0 && high == 0` AND every remaining MEDIUM/LOW has an explicit `findings_resolutions:` entry in the bridge yaml with acceptance rationale | proceed to Step 6e; bridge ship-ready |
| 2 | **PLATEAUED** | `findings_hash[N] == findings_hash[N-1]` (same findings two iterations in a row) | auto-file GitHub issue with the unresolved findings; add `review_status: blocked-on-upstream` to bridge yaml; **do NOT** write structured `reviewed_by`; STOP — runtime gate will reject |
| 3 | **DIMINISHING** | iteration N+1 only added SUGGESTION-level findings (no new CRITICAL/HIGH/MEDIUM) | proceed to Step 6e with notes; bridge ship-ready with future-iteration list |

**Anti-oscillation invariant** — fires before the three terminators above:

```
if findings_count[N] > findings_count[N-1]:
    # codegen broke something while fixing — instability
    ROLLBACK bridge yaml to iteration N-1 state (use git or backup file)
    add review_status: blocked-on-codegen-instability to bridge yaml
    STOP — do not write structured reviewed_by
```

If none of the terminators fire, feed findings back to codegen via a follow-up prompt (you, the agent, regenerate the bridge yaml addressing each finding in order of severity), then loop back to Step 6b for iteration N+1.

#### Step 6e — Write structured `reviewed_by` + finalize review log Verdict

On CONVERGED or DIMINISHING outcome, replace the `reviewed_by: REQUIRES_HUMAN_REVIEW` placeholder with the structured form:

```yaml
reviewed_by:
  human_reviewer: "<github-handle>"      # the user who invoked /glue-bridge
  review_mode: "glue-ensemble-v1"        # methodology marker
  ai_reviewers:
    - codex-cli@0.124.0
    - claude-opus-4-7-correctness
    - claude-opus-4-7-security
    - claude-opus-4-7-devils-advocate
  findings_summary:
    critical: 0
    high: 0
    medium: <N>          # all MUST appear in findings_resolutions block below
    low: <M>
    suggestions: <K>
    resolved_in_iterations: <iteration count>
  approved_at: "<ISO 8601 UTC>"
  approved_in_commit: ""   # filled by post-commit hook (initially empty)
  review_artifacts: "<source>.bridge.review.md"

findings_resolutions:                    # required when findings_summary.medium + low > 0
  - finding_id: M-2
    severity: MEDIUM
    description: "value_map missing English translation for status field"
    resolution: "accepted; sentinel 'pending' covers unknown values"
    accepted_by: "<github-handle>"
```

Append the verdict line to the review log:

```markdown
## Verdict: CONVERGED at iteration <N>
```

(Or `DIMINISHING at iteration <N>` for the diminishing outcome.)

The bridge is now ship-ready. Proceed to Step 7 (validator standalone run, optional sanity check) and Step 9 (smoke test).

### Step 7 — Validate the draft

Run the bundled validation script to lint the draft:

```bash
Rscript shared/global_scripts/00_principles/.claude/skills/glue-bridge/scripts/validate_bridge_yaml.R "$BRIDGE_PATH"
```

The script checks:
- Required top-level keys (`prerawdata_source`, `canonical_target`, `column_mapping`, `generated_at`, `generated_by`, `reviewed_by`)
- `prerawdata_source.schema_fingerprint` present + sha256 format
- `column_mapping` covers every canonical required field for this datatype
- Every prerawdata column either appears in `column_mapping` or `ignored_columns` (**MP160 mechanical equality**, CRITICAL on violation)
- `reviewed_by` is the placeholder (expected at draft stage) or a real identifier (expected at commit stage)
- yaml itself parses cleanly via R `yaml` package
- (`wip/` bridges skip the MP160 enumeration check — INFO-level skip)

If validation fails, fix the issues in the draft and re-run validation. Iterate until pass.

### Step 8 — Request human review

Show the validated draft to the user. Use AskUserQuestion (or plain text) to ask:

1. Are there any field mappings the human disagrees with?
2. Are there any columns in `ignored_columns` that should actually be mapped?
3. Provide a real `reviewed_by` identifier (GitHub handle, name + handle, or initials + handle — never just `"AI"`, `"REQUIRES_HUMAN_REVIEW"`, or `"TBD"`).

Update the draft with the human's feedback. Replace `reviewed_by: "REQUIRES_HUMAN_REVIEW"` with the real identifier. Re-run Step 7 validation.

### Step 9 — Smoke test against the actual source (optional but recommended)

Before commit, verify the bridge actually works end-to-end against a small DuckDB instance. This catches column-mapping bugs that pure validation misses:

```bash
Rscript -e '
for (fn in c("fn_hash_prerawdata_schema.R", "fn_apply_mapping.R",
             "fn_validate_against_schema.R", "fn_glue_bridge.R")) {
  source(file.path("shared/global_scripts/05_etl_utils/glue", fn))
}
suppressPackageStartupMessages({library(DBI); library(duckdb); library(<reader-pkg>)})
prerawdata <- <source-reader-call>(<source-args>)
con <- DBI::dbConnect(duckdb::duckdb(), ":memory:")
ddl <- paste(readLines("<generated-ddl-path>"), collapse = "\n")
DBI::dbExecute(con, ddl)
result <- fn_glue_bridge(
  company = "<company>", platform = "<platform>", source = "<source>",
  prerawdata = prerawdata, target_con = con,
  bridges_root = "shared/global_scripts/01_db/raw_schema/_authoring/bridges"
)
cat(sprintf("input_rows: %d\noutput_rows: %d\nerrors: %d\n",
            result$n_input_rows, result$n_output_rows, result$n_errors))
if (result$n_errors > 0) print(head(result$errors, 5))
DBI::dbDisconnect(con, shutdown = TRUE)
' 2>&1
```

If `n_errors > 0`, inspect `result$errors`. Common shapes: missing required field (mapping bug), pattern mismatch (value_map needed), range violation (pre_filter needed for known-bad rows). Iterate Steps 6-7-8 if mappings need adjustment.

### Step 10 — Commit

After the user approves the draft and validation + smoke test pass, commit the bridge yaml. The commit message MUST include the reviewer trailer per MP102 Change Discipline:

```bash
git add "$BRIDGE_PATH"
git commit -m "[FEAT] glue bridge: ${COMPANY} ${PLATFORM} ${SOURCE} (#<issue>)

<one-paragraph description of what the bridge does>

Verified: bridge mapping reviewed by <reviewer-from-step-8>.
Refs #<issue> (and #489 for the underlying glue-layer architecture)"
```

After commit, the bridge is part of the codebase — `fn_glue_bridge` will execute it at production runtime, drift detection will kick in on schema changes, and reviewer accountability persists in git history.

## Bridge yaml schema (Tier-2 spec, bound by MP102)

Every bridge yaml SHALL have these top-level keys (canonical reference for what Step 6 generates):

```yaml
prerawdata_source:
  company: "QEF_DESIGN"          # required - matches l4_enterprise/{company}/
  platform: "amz"                 # required - matches platform_id
  source_type: "xlsx"             # required - gsheet | xlsx | csv | api
  source_uri: "data/.../*.xlsx"   # optional - for human reference
  sheet_name: null                # optional - for spreadsheet sources
  schema_fingerprint:
    algorithm: "sha256"
    value: "<hex>"                # required - output of fn_hash_prerawdata_schema (full read)
    fingerprinted_against: "<file-path> (full read, <N> rows)"  # provenance
    fingerprinted_at: "<ISO 8601 UTC>"

canonical_target:
  datatype: "sales"               # required - sales|customers|orders|products|reviews
                                  # or product_attributes_{pl_id} / company_product_extension under D11
  platform: "amz"                 # required - same as prerawdata_source.platform
  table: "df_amz_sales___raw"     # required - derived from core_schemas.yaml#table_pattern
  schema_yaml_path: "01_db/raw_schema/_authoring/core_schemas.yaml"
  platform_extension_yaml_path: "01_db/raw_schema/_authoring/platform_extensions/amz_extensions.yaml"

pre_filter:                       # optional - exclude rows before mapping
  - column: "<source-col>"
    exclude_values: ["<v1>", "<v2>"]

column_mapping:                   # required - covers every canonical required field
  <canonical_field>:
    from_column: "<source-col>"   # case-insensitive lookup
    coercion: "<rule>"            # optional - defaults to schema's coercion
    value_map: { "<src-val>": "<canonical-val>" }  # optional - value translation
    use_value: <literal>          # alternative to from_column - per-company constant
    apply_fallback: true          # alternative - delegate to schema-defined fallback
    notes: "<rationale>"          # optional but encouraged for non-obvious mappings

ignored_columns:                  # required when prerawdata has unmapped cols
  - "<source-col-1>"              # all unmapped source cols MUST be listed here

generated_at: "<ISO 8601 UTC>"    # required
generated_by: "glue-bridge skill v1.1"  # required (or "hand-written" for manual bridges)
reviewed_by: "<real-human-id>"    # required - rejected at runtime if AI/REQUIRES_HUMAN_REVIEW/TBD
review_notes: |                   # optional - context for future reviewers
  <free-form notes>
```

## Common gotchas (5 lessons from #489 Phase 5 PoC)

The handbook at `shared/handbook/onboarding/glue-bridge-onboarding.md` has the long-form versions; here are the operational summaries.

### Gotcha 1 - fingerprint instability from partial reads

`readxl` / `readr` infer column types from the first N rows by default (`guess_max = 1000`). Sparse columns flip from `logical` to `numeric` once a non-NA value appears later in the file. Always fingerprint with a full file read; never use `n_max` or `head()` shortcuts. Step 3 explicitly does the full read.

### Gotcha 2 - value translation, not just column-name translation

`aliases:` in the canonical schema only handles **column names**. Source values like `"Amazon"` / `"Merchant"` need translation to canonical `"AFN"` / `"MFN"` (or whatever the schema defines). Use `value_map:` in the bridge for this.

### Gotcha 3 - PII redaction surprises

Some sources redact PII (e.g., Amazon's All Orders Report anonymizes buyer email). Don't promise canonical fields a real value when the source can't deliver - fall back to empty-string sentinel and document the limitation in `notes:`.

### Gotcha 4 - derived fields via schema's derive_from

If the source has the inputs but not the output (e.g., `quantity` and `unit_price` but no line subtotal), delegate to the canonical schema's `derive_from` rule via `apply_fallback: true`. The interpreter's deterministic primitives handle common patterns like `unit_price * quantity` for `total_amount`.

### Gotcha 5 - schema-violating rows belong elsewhere

Cancelled / pending / draft rows often have NULLs that violate canonical NOT NULL constraints. Use `pre_filter:` to exclude them before mapping. They likely belong in a different datatype (e.g., cancelled rows in `orders` not `sales`) and a separate bridge picks them up there.

## Convergence Protocol Reference (Step 6d detail)

This section is the canonical reference for the convergence terminators and failure modes used inside Step 6d. The orchestration helper `run_ensemble_review.R` implements them; this section documents the contract.

### Three stopping conditions (any one fires → STOP loop)

| Terminator | Condition | Bridge ship-ready? | Action |
|------------|-----------|---------------------|--------|
| **CONVERGED** | `findings_summary.critical == 0 && high == 0` AND every remaining MEDIUM/LOW has explicit `findings_resolutions:` entry with acceptance rationale | Yes | Step 6e writes structured `reviewed_by`; verdict line `## Verdict: CONVERGED at iteration <N>` appended to review log |
| **PLATEAUED** | `findings_hash[N] == findings_hash[N-1]` (same findings two iterations) | No | Auto-file GitHub issue with unresolved findings; bridge yaml gets `review_status: blocked-on-upstream`; `reviewed_by` NOT written; verdict line `## Verdict: PLATEAUED — issue #<NNN> filed` |
| **DIMINISHING** | Iteration N+1 only adds SUGGESTION-level findings (no new CRITICAL/HIGH/MEDIUM) | Yes (with notes) | Step 6e writes structured `reviewed_by`; verdict line `## Verdict: DIMINISHING at iteration <N>`; SUGGESTIONs logged for future iteration |

### Anti-oscillation invariant (fires before terminators)

```
if iteration_N.findings_count > iteration_{N-1}.findings_count:
    # codegen broke something while fixing — instability
    ROLLBACK bridge yaml to iteration N-1 state
    add review_status: blocked-on-codegen-instability to bridge yaml
    STOP — do not write structured reviewed_by
    verdict line: "## Verdict: blocked-on-codegen-instability — rolled back to iteration <N-1>"
```

This catches the case where codegen "fixes" CRITICAL #1 but introduces CRITICAL #4. Rollback uses either `git stash` (if bridge was previously committed) or a backup file written by the helper at iteration start.

### Verdict line format

The final line in `{source}.bridge.review.md` is one of exactly four formats. The validator (`validate_bridge_yaml.R`) reads this line to decide whether the bridge is ship-ready.

| Verdict line | Bridge ship-ready? | reviewed_by struct? |
|--------------|---------------------|---------------------|
| `## Verdict: CONVERGED at iteration <N>` | yes | yes |
| `## Verdict: DIMINISHING at iteration <N>` | yes (with notes) | yes |
| `## Verdict: PLATEAUED — issue #<NNN> filed` | no | no — runtime gate rejects |
| `## Verdict: blocked-on-codegen-instability — rolled back to iteration <N-1>` | no | no — runtime gate rejects |

### Failure mode handling

**`blocked-on-upstream`** (PLATEAUED): the loop exhausted its ability to fix the issue at the bridge layer. Root cause is upstream — typically Layer 1 schema, source data quality, or business rule definition. The auto-filed GitHub issue contains the unresolved findings. Resolution path: open a separate spectra change for the upstream fix, then re-run `/glue-bridge` for this bridge after the upstream change lands.

**`blocked-on-codegen-instability`** (anti-oscillation): the loop saw findings count increase between iterations, indicating codegen is creating new problems while solving old ones. Resolution path: human inspection of the iteration log to identify the regression pattern; may require prompt-engineering improvement on the codegen step (Step 6a).

## Reviewer roles for the ensemble (Step 6b detail)

Step 6b spawns four reviewer agents in parallel via `run_ensemble_review.R`. Each agent has a distinct role, prompt template, and output format. This section documents the canonical prompts the orchestration helper uses.

### Reviewer 1 — codex-cli (cross-model independent verification)

**Model**: gpt-5.5 via `codex exec --full-auto` with `model_reasoning_effort="xhigh"` and `service_tier="fast"`. Canonical invocation:

```bash
codex exec --full-auto \
  -c 'model="gpt-5.5"' \
  -c 'model_reasoning_effort="xhigh"' \
  -c 'service_tier="fast"' \
  --output-last-message "$CODEX_FINDINGS_PATH" \
  "$PROMPT"
```

Why these settings:
- `model="gpt-5.5"`: cross-model independent verification (different family from Anthropic Claude)
- `model_reasoning_effort="xhigh"`: maximum reasoning depth — bridge schema review benefits from deep analysis (small input, high signal-per-token)
- `service_tier="fast"`: speed over credit cost — operator is waiting for ensemble verdict, not running unattended batch

**Why**: independent model family (OpenAI not Anthropic) for blind cross-verification — different training data, different prompt-conditioning patterns, catches different blind spots.

**Prompt focus**:
- Read source CSV header + bridge yaml + canonical schema yaml
- Verify MP160 mechanical equality `set(source_columns) === set(column_mapping.keys) ∪ set(ignored_columns)`
- Verify `column_mapping` business-semantic correctness (Chinese → English)
- Verify `value_map` covers observed source values
- Verify `schema_fingerprint.value` is 64-char hex; algorithm string matches implementation
- Output structured findings table with severity (CRITICAL/WARNING/LOW), rule_id, evidence (file:line), recommendation

**Output**: `/tmp/{run_id}/codex_findings.md` (parsed by helper into structured form).

### Reviewer 2 — claude-correctness (data semantics + MP160)

**Model**: claude-opus-4-7 via `Agent` tool with `subagent_type: general-purpose`.

**Why**: domain-aware lens — looks at source data values not just structure; spot-checks Chinese-to-English mapping for business-semantic plausibility.

**Prompt focus**:
- Read source CSV with full content (not just header)
- Verify MP160 enumeration via Python set comparison
- Detect type mismatches (Boolean schema vs `'0'/'1'/'NA'` string source)
- Detect mojibake / encoding corruption in source values
- Detect required-field NA values that bridge doesn't handle (MP154 sentinel violation)
- Spot-check business-semantic plausibility ("成本" → cost vs price, "上架日期" → launched_at vs created_at)
- Cross-bridge family-level consistency (when reviewing one of multiple PL bridges)

**Output**: `/tmp/{run_id}/correctness_findings.md`.

### Reviewer 3 — claude-security (governance + tampering)

**Model**: claude-opus-4-7 via `Agent` tool with `subagent_type: general-purpose`.

**Why**: attacker mindset — looks at the bridge as part of a supply chain that can be tampered with by insider or compromised account.

**Prompt focus**:
- Hardcoded secrets (API keys, passwords, tokens)
- SQL injection / code injection / path traversal attack surface (audit `fn_glue_bridge.R` + `fn_apply_mapping.R` for risky patterns)
- `reviewed_by` gate strength (today: structured form replacing string)
- Source data trust gap (no value-domain validation = attacker can flip values without triggering fingerprint drift)
- `schema_fingerprint` placeholder vs real (placeholder is a future engineer footgun)
- Hardcoded Google Sheet doc IDs / marketplace IDs (low risk in private repo, escalates if repo shared)

**Output**: `/tmp/{run_id}/security_findings.md`.

### Reviewer 4 — claude-devils-advocate (rebuts PASS/LOW + systemic)

**Model**: claude-opus-4-7 via `Agent` tool with `subagent_type: general-purpose`.

**Why**: dedicated adversarial role — explicitly tries to upgrade other reviewers' PASS / LOW judgments and surfaces collective blind spots.

**Prompt focus**:
- After other 3 reviewers report, read their findings files
- For every PASS / LOW judgment, attempt to find an upgrade rationale; if found, write it as new finding with severity escalation
- Surface systemic concerns: codegen bias (12 outputs from one generator), ground-truth issues (sales bridge has dead coercion keys), reviewer scope errors
- Read the codegen R script (`gen_*.R`) — other reviewers typically don't read generator code
- Cross-bridge family-level analysis (12 PL bridges all 0 value_maps = systemic missing primitive)

**Output**: `/tmp/{run_id}/devils_advocate_findings.md`.

### Why architecture role is dropped

The pilot session (issue #500) ran 5 reviewers (codex + 4 Claude). The architecture-lens reviewer's 11 PASS judgments were all overruled by Devil's Advocate as semantic-blind structural-only assessments. Codegen plus the validator (`validate_bridge_yaml.R`) already enforce structural correctness mechanically. The 4 remaining roles (codex / correctness / security / devils-advocate) cover all distinct lenses with no redundancy.

## Critical contract: LLM_CODEGEN_TIME_ONLY

This skill is the only place in the codebase that touches LLM machinery. The runtime path (`fn_glue_bridge.R` and its helpers `fn_apply_mapping.R`, `fn_validate_against_schema.R`, `fn_hash_prerawdata_schema.R`) MUST remain interpreter-only:

- No dynamic-R-execution patterns in runtime files.
- No `source()` of `fn_call_llm_for_mapping.R` from runtime files.
- No remote network access from runtime files.

The audit-grep test at `shared/global_scripts/98_test/etl/test_fn_glue_bridge.R` ("Production runtime path contains no LLM calls (audit grep)") enforces this. Any modification to this skill that wants to wire LLM calls into the runtime is **rejected by design** - please reread #489 Phase 4 design before considering it.

The marker variable `LLM_CODEGEN_TIME_ONLY <- TRUE` in `fn_call_llm_for_mapping.R` documents this contract for future readers.

## Bundled scripts

`scripts/validate_bridge_yaml.R` - bridge yaml lint script invoked by Step 7. Checks required keys, fingerprint format, column_mapping coverage, ignored_columns completeness, reviewed_by guard. See script header for the full assertion list.

## Related principles

- **MP102** (v1.2): binds bridge yaml shape via `## Files Bound by This Principle` -> `bridges/{COMPANY}/{platform}/{source}.bridge.yaml` Category A (Schema Contract).
- **MP156**: Two-Tier Normativity binding mechanism for both yaml layers.
- **MP157**: Two-Layer YAML Authoring - this skill produces Layer 2 (bridge yaml) only; Layer 1 changes go through MP102 amendment.
- **MP158**: Glue-Driven Raw Layer Extensibility - adding a new datatype/platform/company is a 3-step composition; this skill executes Step 3 (write the bridge yaml).
- **MP154**: Side Effect Defense - sentinel over silent NA; `value_map` and `fallback` rules MUST produce deterministic outputs (never NA without sentinel).
- **MP029**: bridge yamls describe real prerawdata, not invented schema. Step 2 reads actual columns; Step 8 requires real reviewer.
- **DM_R064**: column lookup is by name only (with alias fallback); no positional inference. The skill's `column_mapping` always uses field names.
- **IC_P002**: bridge changes that affect canonical contract require cross-company verification. Per-company bridge changes do NOT need cross-co verify (they're per-instance), but Layer 1 changes triggered by bridge findings do.

## Issue link

Spectra change: `glue-layer-prerawdata-bridge` (issue #489 Phase 4 + 5). This skill's upgrade ships under `qef-product-master-redesign` Phase 9 task 9.0a (issue #460 / #461 / #462).
