---
name: posit-deploy
description: |
  End-to-end deploy of an L4 Enterprise R Shiny dashboard to Posit Connect
  Cloud. Drives the full pipeline: dev-tree commit → make deploy-sync →
  make deploy-push (with MP165 gate) → Posit Connect first-time publish (or
  Variables update if content exists) → batched env vars (per .env) →
  Republish + live URL verify → companies.yaml bookkeeping. Reads
  `.claude/companies.yaml` for per-company config.

  Use this skill whenever the user mentions deploying, publishing, pushing,
  or "上線" / "部署" / "deploy" a known L4 Enterprise company project to
  Posit Connect Cloud, OR mentions any of: QEF_DESIGN / MAMBA / D_RACING /
  kitchenMAMA / WISER / URBANER paired with deploy/publish/上線/部署/環境.
  Triggers even if user doesn't explicitly say "Posit Connect" — any L4
  Enterprise project deploy request routes here. Also triggers when user
  says "把 X 上到環境" / "deploy X 到 Connect" / "publish X dashboard" /
  "push X to production". Do NOT use for: deploying mid-cycle re-publish
  of an already-set-up app (use posit-connect-cloud plugin's `republish`),
  single-variable updates (use plugin's `add-env-var`), or non-Posit
  deploys (Shinyapps.io etc).
---

# posit-deploy

End-to-end deploy of an L4 Enterprise Shiny app to Posit Connect Cloud.
Captures **every gotcha discovered on 2026-05-22/23 during QEF_DESIGN
first-time deploy** — ~10 distinct pitfalls that each cost 10-30 minutes
the first time around.

## Usage

```
/posit-deploy QEF_DESIGN
/posit-deploy MAMBA
/posit-deploy             # auto-detect from cwd if inside l4_enterprise/<COMPANY>/
```

## When to use this skill vs other posit-* skills

| Situation | Use |
|---|---|
| First-time deploy of a company to Posit Connect | **this skill** |
| Adding/changing one or two env vars on already-deployed app | `posit-connect-cloud:add-env-var` |
| Just re-trigger a build after dev change | `posit-connect-cloud:republish` |
| Verify deployed app is responding | `posit-connect-cloud:test-app` |
| Bulk batch update across many sandbox apps | `posit-connect-cloud:batch-update` (legacy 21-sandbox pattern; see issue #794) |

## Workflow (6 phases)

```
Phase 1: Pre-flight
  └─ verify cwd is correct company, handle uncommitted changes,
     make deploy-sync, make deploy-push (triggers MP165 gate)

Phase 2: Posit Connect setup
  └─ login via Keychain pipe (see references/keychain-setup.md),
     search Home for existing content matching app_name,
     branch: first-time publish vs existing-content update

Phase 2.5: Customize content settings (if companies.yaml specifies any)
  └─ Title (Settings → Info), URL slug (Settings → URL),
     Compute Memory + CPU (Settings → Compute).
     See references/customize-content-settings.md

Phase 3: Env vars batch
  └─ stage vars in batches of ~7 → Republish to commit each batch,
     follows references/variables-batch-pattern.md + form-disciplines.md

Phase 4: Republish + verify
  └─ final Republish → poll live URL until HTTP 200 → page-content smoke test

Phase 5: Bookkeeping
  └─ update .claude/companies.yaml (deployed_url, status, last_deployed)
```

## Required prerequisites (skill checks at start)

- `agent-browser` in PATH (`which agent-browser` returns a path; minimum v0.27)
- macOS Keychain entry exists: `security find-generic-password -s posit-connect-cloud -a posit-login` returns metadata. If missing → halt and instruct user to set up via `security add-generic-password -U -s posit-connect-cloud -a posit-login -w` (interactive prompt, password never enters chat).
- Posit login email (default: `mr.no.one01@gmail.com`; configurable per company in companies.yaml if needed)
- Company entry exists in `<l4_enterprise>/.claude/companies.yaml`
- Target company has `<company>/.env` with all needed vars
- Company's `Makefile` has `deploy-sync` + `deploy-push` targets (existing companies confirmed; new ones need #579-style prep first)

## Phase 1: Pre-flight (local)

### 1a. Resolve target company

```bash
# If arg provided
COMPANY="${1:-}"
# Else auto-detect by walking up from cwd
if [ -z "$COMPANY" ]; then
  COMPANY=$(basename "$(pwd | grep -oE 'l4_enterprise/[^/]+' | head -1 | cut -d/ -f2)")
fi
# Validate against companies.yaml
yq ".companies[\"$COMPANY\"]" "$L4_ROOT/.claude/companies.yaml" || halt
```

Pull from companies.yaml:
- `app_name`
- `account`
- `project_dir`
- `deployed_url` (null = first-time; URL = existing content)
- `content_id` (UUID for direct navigation if exists)

### 1b. Verify cwd + handle uncommitted

```bash
cd "$L4_ROOT/$PROJECT_DIR"

# Show uncommitted, ask user how to handle
git status --short
```

AskUserQuestion 3 options: (1) commit then deploy / (2) stash + deploy clean / (3) abort and let user clean manually.

If commit chosen, write a chore commit. Otherwise stash.

### 1c. Run deploy-sync + deploy-push

```bash
make deploy-sync   # rsync dev → deployment/
make deploy-push   # MP165 gate + git commit + push to deploy repo
```

Both must succeed. If MP165 gate fails (Tier-2 deploy gate per #599) → halt with the contract that failed, ask user to fix or override with `MP165_SKIP=true` (emergency only).

## Phase 2: Posit Connect setup

### 2a. Open Connect via agent-browser

**Critical:** Use `--headed` and a named session for cookie persistence:

```bash
agent-browser open "https://connect.posit.cloud" --headed --session posit-connect
```

**Why named session:** OAuth cookie persists between deploys; user doesn't re-login every time. See `references/keychain-setup.md` for the underlying security design.

### 2b. Check login state + auto-login if needed

URL guard pattern (use before every operation):

```bash
URL=$(agent-browser get url --session posit-connect 2>&1 | tail -1)
if [[ "$URL" == *"login.posit.cloud"* ]]; then
  # session expired → auto-login from Keychain
  source references/keychain-setup.md flow
fi
```

If login needed: see `references/keychain-setup.md` for the email→Continue→password (from Keychain)→Log in→pick destination flow.

**Why URL guard everywhere:** Posit Connect's session expires after ~30 min inactivity with no warning. Without this guard, subsequent agent-browser clicks operate on stale refs and silently fail. UI may even show success (count++) but server unchanged.

### 2c. Check for existing content

```bash
# After login, on /kyleyhl home
agent-browser fill <search-field> "$APP_NAME" --session posit-connect
sleep 2
# Parse snapshot: if 1+ content cards match → existing, get its URL
# If "Oops, no luck with that search" → first-time
```

### 2d. Branch: first-time vs existing

**First-time path (deployed_url=null in companies.yaml):**

Click Publish button → /content/new form:

1. Click "Shiny" radio (framework selection)
2. Click Repository combobox → select `kiki830621/ai_martech_l4_<COMPANY>_deploy`
3. (Branch auto-fills to `main`)
4. Click Primary file combobox → type "app.R" → select `app.R` option (top-level, not the deeper template ones)
5. Verify "Automatically publish on push" toggle ON (default)
6. Set Public access combobox → type "Enabled" → click `Enabled` option
   - Connect's react-select needs **mousedown event**, not click — see `references/form-disciplines.md` for the dispatch pattern
7. Click Publish button
8. Wait for redirect to `/content/<UUID>` — that UUID is the content_id

**Existing-content path (deployed_url already in companies.yaml):**

Navigate directly:
```
https://connect.posit.cloud/kyleyhl/content/<content_id>/settings/variables
```

## Phase 2.5: Customize content settings

After Publish creates the content (first-time path) OR if existing content has uncustomized settings, apply the per-company customizations from `companies.yaml`. Covers all 7 Posit Connect Settings tabs except Variables (which is Phase 3):

| Posit Settings tab | companies.yaml field | Effect | Rebuild? | Verified? |
|---|---|---|---|---|
| Info | `title` | Display title (default = repo name like `..._deploy`; strip the suffix) | No | ✓ |
| Source | (not in yaml — set during Publish) | Repository / branch / primary file. Rarely changed post-publish | Yes | ✓ (via Publish) |
| URL | `url_slug` | Toggle Customize ON, fill slug. URL becomes `https://kyleyhl-<slug>.share.connect.posit.cloud/` | Yes (immediate) | ✓ |
| Variables | (Phase 3 — separate workflow) | env vars batch | Yes (per-batch Republish) | ✓ |
| Compute | `compute.memory_gb` / `compute.cpu_count` | Memory + CPU dropdowns (4/8/16/32 GB, 1/2/4/8 CPU per plan) | Yes (on next Republish) | ✓ |
| Runtime | `runtime.{init_timeout_seconds,idle_timeout_seconds,max_processes,max_connections_per_process}` | Performance tuning (init timeout for heavy R startup, etc.) | Yes (on next Republish) | ⚠ unverified |
| Schedule | `schedule.{enabled,cron,timezone}` | Cron-driven re-trigger (rarely used for Shiny apps) | No | ⚠ unverified |
| Share | `share.collaborators[]` | Add team members by email + role (Viewer/Editor) | No | ⚠ unverified |

Settings marked **⚠ unverified** have skill patterns based on inferred Posit UI conventions but haven't been tested in production. First real use should confirm field labels match. The 3 critical disciplines (scrollIntoView / tail -1 / count-only) apply universally.

If a field is missing/null in companies.yaml, skip that setting (keep Connect's default). The skill is **idempotent** — re-running checks current value first and skips if already matches desired.

**Why this is its own phase**: URL change triggers a rebuild (Connect needs to mint new routing). Apply customizations BEFORE the Variables batch so the Phase 4 final Republish is the only rebuild that also validates env vars. Title/Share/Schedule don't need rebuild; Compute/Runtime ride on Phase 4 final.

See `references/customize-content-settings.md` for the exact agent-browser sequence per setting.

After Phase 2.5, the `LIVE_URL` should be updated:

```bash
if [ -n "$URL_SLUG" ]; then
  LIVE_URL="https://kyleyhl-${URL_SLUG}.share.connect.posit.cloud/"
else
  LIVE_URL="https://${CONTENT_ID}.share.connect.posit.cloud/"
fi
```

## Phase 3: Env vars batch

Read `references/variables-batch-pattern.md` for the canonical loop. Critical
points:

- **Posit Connect's Variables Save is stage-only** — does NOT persist to server.
- **Republish is the actual commit** — Save+Save+Save → ONE Republish commits all + rebuilds.
- **Max ~7 vars staged per cycle** — after that, Save stops incrementing. Must Republish to commit + reset, then stage next batch.
- Each Add+Fill+Save round MUST follow `references/form-disciplines.md`:
  - scrollIntoView Save button BEFORE click
  - Use `tail -1` (not `head -1`) for form refs — new form is at END of snapshot
  - **count-only verification** — never snapshot mid-edit form value

### Variable source

Read `<company>/.env` and pull all `^[A-Z_]+=` keys. Skip `.env.template` placeholder values (matches `your_*` pattern).

Standard 21 vars for l4_enterprise (verified against QEF_DESIGN/MAMBA):

```
APP_ENV APP_DEBUG APP_LOG_LEVEL APP_PASSWORD
AMZ_ACCESS_KEY AMZ_REGION AMZ_SECRET_KEY
OPENAI_API_KEY
PGDATABASE PGHOST PGPASSWORD PGPORT PGSSLMODE PGUSER
SUPABASE_ANON_KEY SUPABASE_DB_HOST SUPABASE_DB_NAME
SUPABASE_DB_PASSWORD SUPABASE_DB_PORT SUPABASE_DB_USER
SUPABASE_URL
```

(Plugin `variable-templates.md` says PG* are legacy and SUPABASE_DB_* are the new canonical, but keeping both is harmless.)

### Critical: ⚠ cwd discipline

`get_env()` greps the local `.env`. Each l4_enterprise level has its OWN `.env`:

| cwd | .env content |
|---|---|
| `l4_enterprise/` | sandbox shared (5 vars only) — **WRONG for company deploy** |
| `l4_enterprise/<COMPANY>/` | company-specific 21 vars — **CORRECT** |

Always `cd` to company project root at start of each bash invocation that calls `get_env()`. Failure mode: 2026-05-23 session silently used l4_enterprise's `.env` for the first 5 SUPABASE_DB_* vars then had to delete them. Always-explicit `cd` prevents.

## Phase 4: Republish + verify

After final batch's Republish:

```bash
LIVE_URL=$(yq ".companies[\"$COMPANY\"].deployed_url" "$L4_ROOT/.claude/companies.yaml")
# For first-time, build URL from content_id
LIVE_URL="https://${CONTENT_ID}.share.connect.posit.cloud/"

# Poll HTTP status until 200 or timeout
for i in {1..20}; do
  STATUS=$(curl -sI "$LIVE_URL" --max-time 8 2>/dev/null | head -1)
  echo "[$i] $STATUS"
  echo "$STATUS" | grep -q "200" && break
  sleep 15
done
```

If still not 200 after 5 minutes → navigate to `/content/<id>/history` to read build log.

### Smoke test page content

```bash
agent-browser open "$LIVE_URL" --headed --session posit-live  # different session
sleep 4
agent-browser snapshot -i --session posit-live | grep -iE "password|VIBE|admin|login"
```

Expected: textbox "請輸入系統密碼" + button "進入系統" (the Shiny app's password gate).

If empty or "Startup Error" → see `references/troubleshooting.md`.

## Phase 5: Bookkeeping — update companies.yaml

```yaml
COMPANY_NAME:
  deployed_url: "https://<content_id>.share.connect.posit.cloud/"
  content_id: "<UUID>"
  project_dir: "..."
  account: "..."
  app_name: "..."
  status: "production"        # was "not_deployed" or "bootstrap"
  last_deployed: "YYYY-MM-DD"
  notes: |
    Deployed YYYY-MM-DD via /posit-deploy skill.
    URL is default UUID-based (Customize URL toggle off); can be migrated
    to kyleyhl-style pattern via Settings → URL → toggle on.
    Refs: prior deploys, related issues.
```

Also bump file-level `last_updated:` at top.

## Critical disciplines (the lessons)

Three rules — each cost ~30 min to discover. **Read `references/form-disciplines.md` for full reasoning + code patterns.**

1. **scrollIntoView before every click** — agent-browser's `.click()` doesn't auto-scroll. Off-screen Save button → silent miss. UI may even show success (count++ in client) but server unchanged.

2. **`tail -1` for newly-opened form refs** — When form opens and you snapshot, the new form's Name/Value/Save elements are at the END of the matching elements list, not the beginning. `head -1` grabs the stale (closed) form ref.

3. **count-only verification, never snapshot mid-edit form values** — Posit's Variables form input is plain `type="text"`, not `type="password"`. `agent-browser snapshot -i` returns input.value verbatim → leaks plaintext secret to conversation log. Verify only via `grep -cE '"Edit variable"'` (counts saved vars, no value introspection).

## Why agent-browser (not safari-browser)

Posit Connect management UI is React-heavy form interaction (controlled inputs, react-select, dynamic rows). agent-browser uses Puppeteer/CDP with Chromium native events that React captures. safari-browser via AppleScript bypasses React's valueTracker on dynamic inputs — discovered painfully on 2026-05-22.

Per `08-shiny-testing.md`'s "live URL → safari-browser" rule: that rule is for **dashboard validation** (read-only smoke test, screenshot what user sees), not management UI form interaction. The two scenarios are different despite both being "live URL". See issue #794 comment 2026-05-23 for full analysis.

## Estimated time

| Phase | Time |
|---|---|
| Pre-flight (commit + sync + push + MP165) | 2-3 min |
| Posit login (if Keychain set up) | 30 sec |
| First-time publish form | 1 min |
| 21 vars × 3 batches × (stage 7 + Republish) | 6-10 min |
| Build + live URL verify | 2-5 min |
| companies.yaml update | 30 sec |
| **Total first-time** | **~15-20 min** |

Existing-content re-deploy (skip publish form, just update vars + republish): ~8-12 min.

## When something fails mid-flow

The skill is designed to be **resumable**. If interrupted:

- Saved vars persist on server after each batch's Republish (NOT just Save)
- Re-run /posit-deploy and skill will:
  - Detect existing content via companies.yaml (or by searching Connect)
  - Skip already-committed vars (count what's on server, compare to .env)
  - Resume from where left off

## References

- `references/form-disciplines.md` — Why the 3 critical rules, with code patterns
- `references/keychain-setup.md` — Posit password storage + retrieval flow
- `references/customize-content-settings.md` — Title / URL slug / Compute (Phase 2.5)
- `references/variables-batch-pattern.md` — The Save-stage / Republish-commit lifecycle, batch sizing
- `references/companies-yaml-schema.md` — Schema + which fields to update
- `references/troubleshooting.md` — Common failures (build error, OAuth loop, session expiry)
