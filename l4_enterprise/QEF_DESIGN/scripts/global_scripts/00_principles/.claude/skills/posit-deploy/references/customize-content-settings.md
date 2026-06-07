# Customize Content Settings (Phase 2.5)

After publish creates the content (UUID-based default URL, repo-name title, free-tier compute), apply per-company customizations from `companies.yaml`. Each setting lives on its own Settings sub-tab.

All three settings are **optional** — if companies.yaml doesn't specify them, skip and use Connect defaults. Skill is **idempotent**: reading a field that already matches the desired value should be a no-op.

---

## Setting 1: Title (Settings → Info)

### What & why

Posit auto-titles content from the repo name on Publish (e.g., `ai_martech_l4_QEF_DESIGN_deploy`). The `_deploy` suffix is internal jargon — customers seeing the Connect breadcrumb don't need to see it. Cleaner: `ai_martech_l4_QEF_DESIGN`.

### Sequence

```bash
S="posit-connect"
TITLE=$(yq ".companies[\"$COMPANY\"].title" "$YAML" -r)
[ "$TITLE" = "null" ] && return 0  # skip if not configured

# Navigate to Info tab
agent-browser open "https://connect.posit.cloud/kyleyhl/content/${CONTENT_ID}/settings/info" --headed --session $S >/dev/null 2>&1
sleep 4

# URL guard
URL=$(agent-browser get url --session $S 2>&1 | tail -1)
[[ "$URL" == *login* ]] && { echo "✗ session expired"; relogin; }

# Find Title textbox + Save button (tail -1 per form-disciplines.md)
SNAP=$(agent-browser snapshot -i --session $S 2>/dev/null)
TITLE_REF=$(echo "$SNAP" | grep 'textbox "Title"' | tail -1 | grep -oE 'ref=e[0-9]+' | cut -d= -f2)
SAVE_REF=$(echo "$SNAP" | grep 'button "Save"' | tail -1 | grep -oE 'ref=e[0-9]+' | cut -d= -f2)

# Check current value — if matches, skip
CURRENT=$(echo "$SNAP" | grep "textbox \"Title\".*: " | tail -1 | sed 's/.*: //')
if [ "$CURRENT" = "$TITLE" ]; then
  echo "  Title already set to '$TITLE' — skip"
else
  agent-browser fill "@$TITLE_REF" "$TITLE" --session $S >/dev/null 2>&1
  sleep 1
  # Scroll Save into view
  agent-browser eval "Array.from(document.querySelectorAll('button')).filter(b=>b.textContent.trim()==='Save').pop()?.scrollIntoView({block:'center'}); 'ok'" --session $S >/dev/null 2>&1
  sleep 0.4
  agent-browser click "@$SAVE_REF" --session $S >/dev/null 2>&1
  sleep 2
  echo "  ✓ Title set to '$TITLE'"
fi
```

### Notes

- Title is **NOT** secret — comparison via snapshot text is fine (no leak risk)
- Save button on Info tab might be disabled until Title differs from current — that's why the comparison check matters
- **No Republish needed** for title change — purely cosmetic, applies immediately

---

## Setting 2: URL slug (Settings → URL)

### What & why

Default URL is UUID-based: `https://019e5290-434f-0331-836a-28d853123cd3.share.connect.posit.cloud/`. Customers can't memorize that. Customize gives: `https://kyleyhl-ai-martech-qef-design.share.connect.posit.cloud/` — much more memorable + matches MAMBA's pattern (`kyleyhl-ai-martech-l4-mamba.share...`).

The `kyleyhl-` prefix is Posit's account slug (auto-prepended); we only configure the part AFTER the dash.

### Sequence

```bash
S="posit-connect"
URL_SLUG=$(yq ".companies[\"$COMPANY\"].url_slug" "$YAML" -r)
[ "$URL_SLUG" = "null" ] && return 0  # skip

# Navigate to URL tab
agent-browser open "https://connect.posit.cloud/kyleyhl/content/${CONTENT_ID}/settings/url" --headed --session $S >/dev/null 2>&1
sleep 4

# URL guard
URL=$(agent-browser get url --session $S 2>&1 | tail -1)
[[ "$URL" == *login* ]] && { echo "✗ session expired"; relogin; }

# Check if Customize URL toggle is currently OFF — toggle it ON if so
SNAP=$(agent-browser snapshot -i --session $S 2>/dev/null)
TOGGLE_STATE=$(echo "$SNAP" | grep 'switch "Customize your URL"' | head -1)

if echo "$TOGGLE_STATE" | grep -q 'checked=false'; then
  # Need to enable customize
  TOGGLE_REF=$(echo "$TOGGLE_STATE" | grep -oE 'ref=e[0-9]+' | cut -d= -f2)
  agent-browser eval "Array.from(document.querySelectorAll('label, button, [role=switch]')).find(el=>el.textContent.includes('Customize your URL'))?.scrollIntoView({block:'center'}); 'ok'" --session $S >/dev/null 2>&1
  sleep 0.3
  agent-browser click "@$TOGGLE_REF" --session $S >/dev/null 2>&1
  sleep 2
  # Re-snapshot to find newly-visible URL slug field
  SNAP=$(agent-browser snapshot -i --session $S 2>/dev/null)
fi

# Fill slug textbox (appears after toggle ON; field name may vary — try common labels)
SLUG_REF=$(echo "$SNAP" | grep -E 'textbox "(URL|Slug|Custom URL|Path)"' | tail -1 | grep -oE 'ref=e[0-9]+' | cut -d= -f2)
[ -z "$SLUG_REF" ] && SLUG_REF=$(echo "$SNAP" | grep 'textbox' | tail -1 | grep -oE 'ref=e[0-9]+' | cut -d= -f2)

agent-browser fill "@$SLUG_REF" "$URL_SLUG" --session $S >/dev/null 2>&1
sleep 1

# Save (URL changes need Republish to take effect, but Save commits the change first)
SNAP=$(agent-browser snapshot -i --session $S 2>/dev/null)
SAVE_REF=$(echo "$SNAP" | grep 'button "Save"' | tail -1 | grep -oE 'ref=e[0-9]+' | cut -d= -f2)
agent-browser eval "Array.from(document.querySelectorAll('button')).filter(b=>b.textContent.trim()==='Save').pop()?.scrollIntoView({block:'center'}); 'ok'" --session $S >/dev/null 2>&1
sleep 0.4
agent-browser click "@$SAVE_REF" --session $S >/dev/null 2>&1
sleep 2

# URL change requires Republish to actually mint the new route
REPUB_REF=$(agent-browser snapshot -i --session $S 2>/dev/null | grep -E 'button "Republish"' | tail -1 | grep -oE 'ref=e[0-9]+' | cut -d= -f2)
if [ -n "$REPUB_REF" ]; then
  agent-browser eval "Array.from(document.querySelectorAll('button')).filter(b=>b.textContent.trim()==='Republish').pop()?.scrollIntoView({block:'center'}); 'ok'" --session $S >/dev/null 2>&1
  sleep 0.4
  agent-browser click "@$REPUB_REF" --session $S >/dev/null 2>&1
  sleep 10  # wait for republish to start
  echo "  ✓ URL customized to kyleyhl-${URL_SLUG} + Republished"
else
  echo "  ⚠ URL slug saved but no Republish button found — may need manual Republish"
fi
```

### Notes

- The new URL `https://kyleyhl-<URL_SLUG>.share.connect.posit.cloud/` takes effect **only after Republish**. Before that, the UUID URL still works.
- **The UUID URL keeps working** even after customization (Connect keeps both routes). Old links don't break.
- After this phase, update `LIVE_URL` variable in skill to the new customized URL for downstream verification.

---

## Setting 3: Compute (Settings → Compute)

### What & why

Free tier defaults: 4 GB / 1 CPU. For L4 Enterprise R Shiny apps that do Supabase queries + cache big DataFrames + render plotly, this is tight. Plan-allowed maxes (16 GB / 4 CPU) give headroom for concurrent users.

### Sequence

```bash
S="posit-connect"
MEM_GB=$(yq ".companies[\"$COMPANY\"].compute.memory_gb" "$YAML" -r)
CPU_COUNT=$(yq ".companies[\"$COMPANY\"].compute.cpu_count" "$YAML" -r)
[ "$MEM_GB" = "null" ] && [ "$CPU_COUNT" = "null" ] && return 0  # skip

# Navigate to Compute tab
agent-browser open "https://connect.posit.cloud/kyleyhl/content/${CONTENT_ID}/settings/compute" --headed --session $S >/dev/null 2>&1
sleep 4

# URL guard
URL=$(agent-browser get url --session $S 2>&1 | tail -1)
[[ "$URL" == *login* ]] && { echo "✗ session expired"; relogin; }

# Memory dropdown — Connect uses react-select pattern (need mousedown not click)
if [ "$MEM_GB" != "null" ]; then
  SNAP=$(agent-browser snapshot -i --session $S 2>/dev/null)
  MEM_COMBO_REF=$(echo "$SNAP" | grep 'combobox "Memory"' | tail -1 | grep -oE 'ref=e[0-9]+' | cut -d= -f2)
  
  # Open dropdown via mousedown (form-disciplines rule 4 for react-select)
  agent-browser eval "
  (function(){
    var ci = document.querySelector('input[id=\"compute.memory\"]') || document.querySelector('[aria-label=\"Memory\"]');
    if (!ci) return 'not found';
    var ctrl = ci.closest('[class*=control]');
    if (!ctrl) return 'no ctrl';
    ctrl.dispatchEvent(new MouseEvent('mousedown', {bubbles:true, button:0}));
    ctrl.dispatchEvent(new MouseEvent('mouseup', {bubbles:true, button:0}));
    return 'opened';
  })()
  " --session $S 2>&1 | tail -1
  sleep 1
  
  # Click "{N} GB" option
  agent-browser eval "
  (function(){
    var opt = Array.from(document.querySelectorAll('div')).find(d => 
      d.className && d.className.includes('-option') && d.textContent.trim() === '${MEM_GB} GB'
    );
    if (!opt) return 'no option ${MEM_GB} GB';
    opt.dispatchEvent(new MouseEvent('mousedown', {bubbles:true, button:0}));
    opt.dispatchEvent(new MouseEvent('mouseup', {bubbles:true, button:0}));
    opt.click();
    return 'clicked ${MEM_GB} GB';
  })()
  " --session $S 2>&1 | tail -1
  sleep 1
fi

# CPU dropdown — same pattern
if [ "$CPU_COUNT" != "null" ]; then
  SNAP=$(agent-browser snapshot -i --session $S 2>/dev/null)
  
  agent-browser eval "
  (function(){
    var ci = document.querySelector('input[id=\"compute.cpu\"]') || document.querySelector('[aria-label=\"CPU\"]');
    if (!ci) return 'not found';
    var ctrl = ci.closest('[class*=control]');
    ctrl.dispatchEvent(new MouseEvent('mousedown', {bubbles:true, button:0}));
    ctrl.dispatchEvent(new MouseEvent('mouseup', {bubbles:true, button:0}));
    return 'opened';
  })()
  " --session $S 2>&1 | tail -1
  sleep 1
  
  agent-browser eval "
  (function(){
    var opt = Array.from(document.querySelectorAll('div')).find(d => 
      d.className && d.className.includes('-option') && d.textContent.trim() === '${CPU_COUNT} CPU'
    );
    if (!opt) return 'no option';
    opt.dispatchEvent(new MouseEvent('mousedown', {bubbles:true, button:0}));
    opt.dispatchEvent(new MouseEvent('mouseup', {bubbles:true, button:0}));
    opt.click();
    return 'clicked ${CPU_COUNT} CPU';
  })()
  " --session $S 2>&1 | tail -1
  sleep 1
fi

# Save
SAVE_REF=$(agent-browser snapshot -i --session $S 2>/dev/null | grep 'button "Save"' | tail -1 | grep -oE 'ref=e[0-9]+' | cut -d= -f2)
agent-browser eval "Array.from(document.querySelectorAll('button')).filter(b=>b.textContent.trim()==='Save').pop()?.scrollIntoView({block:'center'}); 'ok'" --session $S >/dev/null 2>&1
sleep 0.4
agent-browser click "@$SAVE_REF" --session $S >/dev/null 2>&1
sleep 2

echo "  ✓ Compute set to ${MEM_GB} GB / ${CPU_COUNT} CPU (applies on next Republish)"
```

### Notes

- Compute setting **takes effect on next rebuild** — usually rolls into Phase 4's final Republish (after Variables batch). No need to Republish here just for compute change.
- Plan limit: ask Connect what's available. If user specifies `memory_gb: 64` but plan only allows 32, the dropdown won't have that option and skill will fail at "no option" check. Skill should validate against the visible options before attempting.
- React-select dropdown selector IDs are guesses (`compute.memory`, `compute.cpu`). Verify with screenshot of actual page on first run; update selectors if needed.

---

## Setting 4: Source (Settings → Source) — RARELY changed

### What & why

Repository / branch / primary file were set during Publish form. Changing post-publish is unusual (it's essentially "deploy a different app to the same content"). Skill SHOULD warn if `companies.yaml` specifies values that differ from current Connect state — usually means yaml is wrong, not Connect.

### When you'd actually change Source

- Migrating deploy repo to a new GitHub org
- Switching branch from `main` to `release/v2`
- Pointing to a different `primary_file` (e.g., `app_compact.R` for a lite variant)

### Sequence (UNVERIFIED — first use should confirm UI layout)

```bash
S="posit-connect"
agent-browser open "https://connect.posit.cloud/kyleyhl/content/${CONTENT_ID}/settings/source" --headed --session $S >/dev/null 2>&1
sleep 4

# Three combobox fields like the Publish form: Repository, Branch, Primary file
# Use same react-select mousedown pattern as Public access
# (See Phase 2 publish form code in SKILL.md)
```

Skill default: **detect drift but don't auto-change**. If yaml says branch=`release/v2` and Connect shows `main`, log a warning and ask user before applying.

---

## Setting 5: Runtime (Settings → Runtime)

### What & why

R startup for L4 Enterprise apps loads ~100 packages + sources global_scripts. Default init timeout (60s) sometimes too tight, causing intermittent "Startup Error" on cold start. Bumping to 180s gives headroom.

Other knobs (idle timeout, max processes) affect concurrency cost vs responsiveness tradeoff — usually leave at default unless customer reports issues.

### Sequence (UNVERIFIED — first use should confirm UI layout)

```bash
S="posit-connect"
agent-browser open "https://connect.posit.cloud/kyleyhl/content/${CONTENT_ID}/settings/runtime" --headed --session $S >/dev/null 2>&1
sleep 4

INIT_TIMEOUT=$(yq ".companies[\"$COMPANY\"].runtime.init_timeout_seconds" "$YAML" -r)
IDLE_TIMEOUT=$(yq ".companies[\"$COMPANY\"].runtime.idle_timeout_seconds" "$YAML" -r)
MAX_PROC=$(yq ".companies[\"$COMPANY\"].runtime.max_processes" "$YAML" -r)
MAX_CONN=$(yq ".companies[\"$COMPANY\"].runtime.max_connections_per_process" "$YAML" -r)

# Fields are likely textbox (numeric) — fill with value (skip if null)
set_runtime_field() {
  local label="$1" value="$2"
  [ "$value" = "null" ] && return 0
  local SNAP=$(agent-browser snapshot -i --session $S 2>/dev/null)
  local REF=$(echo "$SNAP" | grep "textbox \"$label\"" | tail -1 | grep -oE 'ref=e[0-9]+' | cut -d= -f2)
  [ -z "$REF" ] && { echo "  ⚠ field '$label' not found — UI may differ from expected"; return 1; }
  agent-browser fill "@$REF" "$value" --session $S >/dev/null 2>&1
  sleep 0.5
  echo "  ✓ $label = $value"
}

# Field labels are guesses based on common Posit Connect terminology;
# verify against actual page text on first run
set_runtime_field "Initialization timeout (seconds)" "$INIT_TIMEOUT"
set_runtime_field "Idle timeout (seconds)" "$IDLE_TIMEOUT"
set_runtime_field "Max processes" "$MAX_PROC"
set_runtime_field "Max connections per process" "$MAX_CONN"

# Save
SAVE_REF=$(agent-browser snapshot -i --session $S 2>/dev/null | grep 'button "Save"' | tail -1 | grep -oE 'ref=e[0-9]+' | cut -d= -f2)
agent-browser eval "Array.from(document.querySelectorAll('button')).filter(b=>b.textContent.trim()==='Save').pop()?.scrollIntoView({block:'center'}); 'ok'" --session $S >/dev/null 2>&1
sleep 0.4
agent-browser click "@$SAVE_REF" --session $S >/dev/null 2>&1
sleep 2
echo "  ✓ Runtime settings saved (applied on next Republish)"
```

### Notes

- Runtime changes apply on **next Republish** — usually rides on Phase 4's final Republish
- R version field is typically auto-detected from `manifest.json`; only set explicitly if you need to pin
- **VERIFY on first run**: field labels (`"Initialization timeout (seconds)"` etc.) are my best guess; Posit may label them slightly differently. Update the grep patterns if so.

---

## Setting 6: Schedule (Settings → Schedule)

### What & why

For Shiny **apps**, schedule is rarely relevant — they're reactive (run on user request). For Rmd reports / Quarto docs that re-render periodically, schedule is essential.

Current L4 Enterprise dashboards are Shiny apps → most companies should leave `schedule.enabled: false` or omit entirely.

### Sequence (UNVERIFIED — first use should confirm)

```bash
S="posit-connect"
SCHED_ENABLED=$(yq ".companies[\"$COMPANY\"].schedule.enabled" "$YAML" -r)
[ "$SCHED_ENABLED" != "true" ] && return 0

CRON=$(yq ".companies[\"$COMPANY\"].schedule.cron" "$YAML" -r)
TZ=$(yq ".companies[\"$COMPANY\"].schedule.timezone" "$YAML" -r)

agent-browser open "https://connect.posit.cloud/kyleyhl/content/${CONTENT_ID}/settings/schedule" --headed --session $S >/dev/null 2>&1
sleep 4

# Posit's schedule UI typically: "Add schedule" button → cron field + timezone dropdown → Save
ADD_REF=$(agent-browser snapshot -i --session $S 2>/dev/null | grep -E 'button "(Add schedule|New schedule)"' | tail -1 | grep -oE 'ref=e[0-9]+' | cut -d= -f2)
agent-browser click "@$ADD_REF" --session $S >/dev/null 2>&1
sleep 2

# Fill cron expression
CRON_REF=$(agent-browser snapshot -i --session $S 2>/dev/null | grep -E 'textbox "(Cron|Schedule|Custom)"' | tail -1 | grep -oE 'ref=e[0-9]+' | cut -d= -f2)
agent-browser fill "@$CRON_REF" "$CRON" --session $S >/dev/null 2>&1

# Select timezone (react-select pattern)
# ... (similar mousedown dispatch as Public access)

SAVE_REF=$(agent-browser snapshot -i --session $S 2>/dev/null | grep 'button "Save"' | tail -1 | grep -oE 'ref=e[0-9]+' | cut -d= -f2)
agent-browser click "@$SAVE_REF" --session $S >/dev/null 2>&1
sleep 2
echo "  ✓ Schedule set: $CRON ($TZ)"
```

### Notes

- Most L4 deploys can skip this entirely
- If used for periodic data refresh, consider whether the refresh logic should be in a separate Connect content (a scheduled Rmd that triggers ETL) rather than the Shiny app

---

## Setting 7: Share / Collaborators (Settings → Share)

### What & why

Add team members who can view or edit the Connect content. Useful when:
- Multi-person team manages a customer dashboard (don't all share one Connect account)
- Auditor needs read-only access
- Co-developer needs ability to update vars / republish

Default state: only the publishing account (kyle-lin) has access.

### Sequence (UNVERIFIED — first use should confirm)

```bash
S="posit-connect"
COLLAB_COUNT=$(yq ".companies[\"$COMPANY\"].share.collaborators | length" "$YAML")
[ "$COLLAB_COUNT" = "0" ] || [ "$COLLAB_COUNT" = "null" ] && return 0

agent-browser open "https://connect.posit.cloud/kyleyhl/content/${CONTENT_ID}/settings/share" --headed --session $S >/dev/null 2>&1
sleep 4

# For each collaborator
for i in $(seq 0 $((COLLAB_COUNT-1))); do
  EMAIL=$(yq ".companies[\"$COMPANY\"].share.collaborators[$i].email" "$YAML" -r)
  ROLE=$(yq ".companies[\"$COMPANY\"].share.collaborators[$i].role" "$YAML" -r)
  
  # Check if already added (count existing collaborator rows, look for email)
  if agent-browser snapshot -i --session $S 2>/dev/null | grep -q "$EMAIL"; then
    echo "  $EMAIL already added — skip"
    continue
  fi
  
  # Click "Add collaborator" → fill email → pick role → Save
  ADD_REF=$(agent-browser snapshot -i --session $S 2>/dev/null | grep -E 'button "(Add collaborator|Invite)"' | tail -1 | grep -oE 'ref=e[0-9]+' | cut -d= -f2)
  agent-browser click "@$ADD_REF" --session $S >/dev/null 2>&1
  sleep 1
  
  EMAIL_REF=$(agent-browser snapshot -i --session $S 2>/dev/null | grep 'textbox "Email"' | tail -1 | grep -oE 'ref=e[0-9]+' | cut -d= -f2)
  agent-browser fill "@$EMAIL_REF" "$EMAIL" --session $S >/dev/null 2>&1
  
  # Role dropdown (react-select)
  # ... mousedown + click "$ROLE" option
  
  SAVE_REF=$(agent-browser snapshot -i --session $S 2>/dev/null | grep 'button "Save"' | tail -1 | grep -oE 'ref=e[0-9]+' | cut -d= -f2)
  agent-browser click "@$SAVE_REF" --session $S >/dev/null 2>&1
  sleep 2
  echo "  ✓ Added $EMAIL as $ROLE"
done
```

### Notes

- Posit may require collaborator to have a Connect account already; skill should detect "user not found" error and instruct user to invite them via Posit first
- Role values typically `Viewer` or `Editor`; check actual Posit terminology on first run

---

## Phase 2.5 entry point in main skill

In `SKILL.md` Phase 2.5 section, the orchestration is:

```bash
# Read customizations (all optional)
TITLE=$(yq ".companies[\"$COMPANY\"].title" "$YAML" -r)
URL_SLUG=$(yq ".companies[\"$COMPANY\"].url_slug" "$YAML" -r)
MEM_GB=$(yq ".companies[\"$COMPANY\"].compute.memory_gb" "$YAML" -r)
CPU_COUNT=$(yq ".companies[\"$COMPANY\"].compute.cpu_count" "$YAML" -r)
# Optional advanced (skip silently if missing)
RUNTIME_INIT=$(yq ".companies[\"$COMPANY\"].runtime.init_timeout_seconds" "$YAML" -r)
SCHED_ENABLED=$(yq ".companies[\"$COMPANY\"].schedule.enabled" "$YAML" -r)
SHARE_COUNT=$(yq ".companies[\"$COMPANY\"].share.collaborators | length" "$YAML")

# Apply order matters (rebuild-cost-aware):
# 1. No-rebuild settings first (Title, Share, Schedule)
[ "$TITLE" != "null" ] && customize_title "$TITLE"
[ "$SCHED_ENABLED" = "true" ] && customize_schedule
[ "$SHARE_COUNT" != "0" ] && [ "$SHARE_COUNT" != "null" ] && customize_share

# 2. URL — needs its own Republish (routing must be minted)
[ "$URL_SLUG" != "null" ] && customize_url "$URL_SLUG"

# 3. Compute + Runtime — apply on next Republish, rolls into Phase 4 final
[ "$MEM_GB" != "null" ] || [ "$CPU_COUNT" != "null" ] && customize_compute "$MEM_GB" "$CPU_COUNT"
[ "$RUNTIME_INIT" != "null" ] && customize_runtime

# Update LIVE_URL for downstream verification
if [ "$URL_SLUG" != "null" ]; then
  LIVE_URL="https://kyleyhl-${URL_SLUG}.share.connect.posit.cloud/"
fi
```

URL customize is the only one that warrants an immediate Republish (URL routing must be minted). Title, Share, Schedule have no rebuild. Compute and Runtime ride on Phase 4's final Republish.

---

## Verification rigor for UNVERIFIED settings (4-7)

For Source / Runtime / Schedule / Share, the agent-browser patterns above are **inferred from common Posit UI conventions but not tested**. On first real use:

1. Open the target Settings tab manually in browser, observe the actual field labels and structure
2. Run `agent-browser snapshot -i --session posit-connect` and verify the grep patterns match
3. If labels differ, update the reference accordingly and commit the fix

This skill captures the WORKFLOW SHAPE — exact selectors are subject to Posit UI updates. The 3 critical disciplines (scrollIntoView / tail -1 / count-only) apply universally regardless of label drift.

---

## Verification after customizations

After Phase 2.5 + Phase 3 (Variables) + Phase 4 (final Republish), the live URL should be:

```
https://kyleyhl-${URL_SLUG}.share.connect.posit.cloud/
```

Test:

```bash
curl -sI "$LIVE_URL" --max-time 8 | head -1
# Expected: HTTP/2 200
```

If 404, URL customize Save didn't commit (re-do Phase 2.5 setting 2). If 500, env vars missing (re-check Phase 3 server count).

Also the UUID URL should STILL work as a fallback:

```bash
curl -sI "https://${CONTENT_ID}.share.connect.posit.cloud/" --max-time 8 | head -1
# Expected: also HTTP/2 200
```

Both should resolve to the same Shiny app.
