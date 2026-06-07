# companies.yaml Schema & Update Pattern

The skill reads `<l4_enterprise>/.claude/companies.yaml` to resolve per-company config, and writes back after successful deploy. This file is the single source of truth for what's deployed where.

---

## File location

```
l4_enterprise/.claude/companies.yaml
```

The skill walks up from cwd to find `l4_enterprise/` then appends `.claude/companies.yaml`. Defined at top of skill flow as `L4_ROOT`.

---

## Schema

```yaml
schema_version: "1.0"
last_updated: "YYYY-MM-DD"      # bump this whenever any company entry changes

companies:
  COMPANY_NAME:
    deployed_url: <string|null>      # full https URL or null = not deployed
    content_id: <string|null>        # Posit Connect content UUID (v2 field, may not exist on older entries)
    project_dir: <string>            # path relative to l4_enterprise/, e.g. "QEF_DESIGN/"
    account: <string>                # Posit account name, e.g. "kyle-lin"
    app_name: <string>               # Connect app slug, e.g. "qef_design-analytics"
    status: <enum>                   # see status values below
    last_deployed: <YYYY-MM-DD|null>
    posit_login_email: <string?>     # optional, default mr.no.one01@gmail.com

    # === Content customization (optional, see Phase 2.5 in SKILL.md) ===
    title: <string?>                 # Settings → Info → Title. Default = repo name
                                     # e.g., "ai_martech_l4_QEF_DESIGN" (strips "_deploy" suffix)
    url_slug: <string?>              # Settings → URL → Customize slug. Default = UUID-based
                                     # e.g., "ai-martech-qef-design"
                                     # Final URL: https://<account-slug>-<url_slug>.share.connect.posit.cloud/
                                     # Where <account-slug> = "kyleyhl" (kyle-lin's Connect slug, not the account name)
    compute:                         # Settings → Compute. Default 4 GB / 1 CPU
      memory_gb: <int?>              # 4 (free), 8, 16, 32 (plan-dependent)
      cpu_count: <int?>              # 1 (free), 2, 4, 8 (plan-dependent)
    runtime:                         # Settings → Runtime. Defaults vary by tier
      r_version: <string?>           # e.g., "4.4.0" — usually auto-detected from manifest
      init_timeout_seconds: <int?>   # default 60s; L4 heavy apps with many R packages may need 180+
      idle_timeout_seconds: <int?>   # default 300s; raise if customers leave tabs open
      max_processes: <int?>          # default 3; raise for higher concurrency
      max_connections_per_process: <int?>  # default 20; rarely changed
    schedule:                        # Settings → Schedule (optional, for periodic refresh jobs)
      enabled: <bool?>               # false = skip schedule setup
      cron: <string?>                # cron expression, e.g., "0 6 * * *" = daily 6 AM
      timezone: <string?>            # IANA timezone, e.g., "Asia/Taipei"
    share:                           # Settings → Share. List of additional collaborators
      collaborators:
        - email: <string>            # e.g., "teammate@example.com"
          role: <Viewer|Editor>      # Viewer = read-only, Editor = can modify settings

    notes: |
      Multi-line free text. Document what this entry was set up for,
      any quirks, related issues/PRs.
```

### Customization field semantics

| Field | Empty/missing means | Set means | Rebuild needed? |
|---|---|---|---|
| `title` | Keep Connect's default (= repo name from publish) | Settings → Info → Title, fill + Save | No |
| `url_slug` | Keep UUID-based default URL | Settings → URL → toggle Customize ON + slug + Save | Yes (URL routing) |
| `compute.memory_gb` / `compute.cpu_count` | Free tier defaults (4 GB / 1 CPU) | Settings → Compute, dropdowns + Save | Yes (applied on next Republish — rolls into Phase 4 final) |
| `runtime.*` | Connect defaults (init 60s / idle 300s / max_proc 3) | Settings → Runtime, fields + Save | Yes (next Republish) |
| `schedule.enabled` | No scheduled trigger | Settings → Schedule, add cron + timezone | No (schedule kicks in on next trigger time) |
| `share.collaborators` | Only owner has access | Settings → Share, add by email + role | No |

### Example: QEF_DESIGN's actual customization (2026-05-23)

```yaml
QEF_DESIGN:
  deployed_url: "https://kyleyhl-ai-martech-qef-design.share.connect.posit.cloud/"
  content_id: "019e5290-434f-0331-836a-28d853123cd3"
  project_dir: "QEF_DESIGN/"
  account: "kyle-lin"
  app_name: "qef_design-analytics"
  status: "production"
  last_deployed: "2026-05-23"
  title: "ai_martech_l4_QEF_DESIGN"     # stripped _deploy suffix
  url_slug: "ai-martech-qef-design"      # without "l4" (per user choice)
  compute:
    memory_gb: 16                        # max on current plan
    cpu_count: 4                         # max on current plan
  notes: |
    First-time deployed 2026-05-23 via /posit-deploy skill.
    Customized title/URL/compute via Phase 2.5 (post-publish, pre-vars).
```

### URL pattern note

The customized URL format is `https://<connect-account-slug>-<url_slug>.share.connect.posit.cloud/`.

The `<connect-account-slug>` is **not** the same as `account` in this yaml — it's Posit's internal account URL slug. For Kyle Lin's account (`account: kyle-lin`), the slug is `kyleyhl` (derived from his email's local-part historically). MAMBA uses `kyleyhl-ai-martech-l4-mamba.share.connect.posit.cloud` so the slug is just for the app, prepended by Posit's account slug.

If you ever onboard a new account holder, add `connect_account_slug:` as an additional field. For now, all companies share Kyle Lin's account = `kyleyhl`.

### Status values

| value | meaning |
|---|---|
| `production` | Live on Posit Connect, served to customers |
| `template_source` | Base template used by `/new-company` skill |
| `bootstrap` | Partial setup (config incomplete or no deploy yet) |
| `not_deployed` | Config complete but deploy pending |
| `unknown` | Needs audit |
| `archived` | Historical, no longer maintained |

---

## What the skill reads

At start of Phase 1:

```bash
# Resolve target company
COMPANY="${1:-$(detect_from_cwd)}"

# Parse company entry via yq (or grep/sed if yq unavailable)
YAML="$L4_ROOT/.claude/companies.yaml"

PROJECT_DIR=$(yq ".companies[\"$COMPANY\"].project_dir" "$YAML" -r)
ACCOUNT=$(yq ".companies[\"$COMPANY\"].account" "$YAML" -r)
APP_NAME=$(yq ".companies[\"$COMPANY\"].app_name" "$YAML" -r)
DEPLOYED_URL=$(yq ".companies[\"$COMPANY\"].deployed_url" "$YAML" -r)
CONTENT_ID=$(yq ".companies[\"$COMPANY\"].content_id" "$YAML" -r)
STATUS=$(yq ".companies[\"$COMPANY\"].status" "$YAML" -r)

# Validate
if [ "$PROJECT_DIR" = "null" ]; then
  echo "✗ Company '$COMPANY' not found in companies.yaml"
  exit 1
fi
```

If `yq` not available, fall back to grep:

```bash
parse_yaml_field() {
  local company="$1" field="$2"
  awk "/^  $company:/,/^  [A-Z]/" "$YAML" | grep "^    $field:" | head -1 | sed "s/^    $field: *//; s/^\"//; s/\"$//"
}
PROJECT_DIR=$(parse_yaml_field "$COMPANY" "project_dir")
# etc
```

### Branch logic from yaml state

| Yaml state | Workflow branch |
|---|---|
| `deployed_url: null` AND `content_id: null` | **First-time publish** (Phase 2 form-fill) |
| `deployed_url: <url>` AND `content_id: <uuid>` | **Existing-content update** (navigate direct to /settings/variables) |
| `deployed_url: <url>` BUT `content_id: null` | Migration case — extract content_id from URL, write back |

---

## What the skill writes (Phase 5)

After successful deploy + verify, update the company entry:

```yaml
COMPANY_NAME:
  deployed_url: "https://<content_id>.share.connect.posit.cloud/"
  content_id: "<UUID>"
  project_dir: "..."  # unchanged
  account: "..."      # unchanged
  app_name: "..."     # unchanged
  status: "production"
  last_deployed: "YYYY-MM-DD"  # today's date
  notes: |
    <existing notes, preserved>
    
    Deploy YYYY-MM-DD via /posit-deploy skill:
    - 21 env vars committed via 3 Republish cycles
    - URL is default UUID-based; customize via Settings → URL toggle if desired
    - Refs: <any related issues>
```

Also bump file-level `last_updated:` at top:

```yaml
schema_version: "1.0"
last_updated: "YYYY-MM-DD"   # ← today's date
```

### Update mechanics

Use `Edit` tool with exact match on the company entry. Don't sed/yq-write — that risks unintended YAML reformat. Specifically:

```python
# Find the company block, preserve existing notes, append deploy line
OLD = "  COMPANY_NAME:\n    deployed_url: null\n    project_dir: \"...\"\n    ..."
NEW = "  COMPANY_NAME:\n    deployed_url: \"https://...\"\n    content_id: \"...\"\n    project_dir: \"...\"\n    ..."
Edit(file_path=YAML, old_string=OLD, new_string=NEW)
```

Then separately bump `last_updated:` via `sed -i ''`:

```bash
sed -i '' "s/^last_updated: \"[0-9-]*\"/last_updated: \"$(date +%Y-%m-%d)\"/" "$YAML"
```

---

## After updating: commit the change

The `companies.yaml` lives in the `l4_enterprise` git repo. After updating:

```bash
cd "$L4_ROOT"
git add .claude/companies.yaml
git commit -m "[OPS] Update $COMPANY deploy URL + status=production ($(date +%Y-%m-%d))

Deployed to Posit Connect via /posit-deploy skill.
URL: https://<content_id>.share.connect.posit.cloud/"
git push origin main  # ask user before pushing if you're uncertain about branch
```

(If you're uncertain whether to push, just commit locally and let the user push.)

---

## Cross-check: companies referenced in other code

Some scripts may have hardcoded URLs that should match companies.yaml:

- `scripts/check_production_data.R` in each company project (e.g., `QEF_DESIGN/scripts/check_production_data.R`)
- Sister-company DEPLOY_URL references in shared MAMBA/QEF_DESIGN docs

After updating companies.yaml, grep for the old URL pattern across l4_enterprise to find anywhere else that needs to match:

```bash
grep -r "share.connect.posit.cloud" "$L4_ROOT" --include="*.R" --include="*.md" --include="*.yaml" 2>/dev/null | grep "$COMPANY"
```
