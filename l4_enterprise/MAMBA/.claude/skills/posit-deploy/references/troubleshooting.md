# Troubleshooting Posit Deploy Failures

Common failure modes encountered on 2026-05-22/23 + their resolutions. Check here before deep-diving when something goes wrong.

---

## Build phase failures

### "Startup Error" on live URL after Republish

**Symptoms**: `curl -sI <url>` returns HTTP 500 (or 502/503). Browser shows "Startup Error / There was an error setting up this content."

**Root causes** (in order of likelihood):

1. **Env var missing or wrong value**
   - Navigate to `https://connect.posit.cloud/kyleyhl/content/<content_id>/history`
   - Latest build entry → Logs section will say things like `Set SUPABASE_DB_HOST and SUPABASE_DB_PASSWORD env vars`
   - Fix: navigate to Variables tab, add or fix the missing var, Republish

2. **R package install failure** (rare for established companies)
   - History log shows pip/install errors during build phase
   - Fix: check `manifest.json` in deploy repo, may need regeneration via `make deploy-manifest`

3. **App code error** (R `stop()` at startup)
   - Look for R-side traceback in History log
   - Fix in dev tree, commit, deploy-sync + deploy-push, then Republish on Connect

### Build succeeds but app shows blank screen

App rendered without R error but UI empty. Usually:
- `database.mode` in `app_config.yaml` set wrong (e.g., `duckdb` but no duckdb deployed)
- Fix is in code: change to `auto` (per #595 fix in QEF), rebuild via Posit

---

## Login / session failures

### "Continue" button doesn't advance email step

agent-browser clicks Continue but URL stays on `/login`. Probably:
- Bot detection rate limit (too many failed attempts)
- agent-browser session has stale cookie

**Resolution**: Ask user to log in manually in the Chromium window. Once on `/kyleyhl/` home, continue from Phase 2c (search for content).

### OAuth redirect loop

Login page redirects back to itself indefinitely. Usually agent-browser session cookie is corrupted.

**Resolution**: Close + reopen session:

```bash
agent-browser close --all
agent-browser open "https://connect.posit.cloud" --headed --session posit-connect
# Then re-trigger Keychain login flow
```

### Keychain prompt not appearing (silent failure)

`security find-generic-password -w` returns nothing, no GUI prompt. Either:
- Entry doesn't exist → run setup command (see `keychain-setup.md`)
- Entry exists but Claude Code process doesn't have Keychain access yet → run command manually in user's Terminal once to trigger initial allow dialog

---

## Variables phase failures

### Save count doesn't increment after click

Saved staged var to 7, attempting 8th — Save click does nothing visible.

**This is the canonical ~7 batch limit.** Republish to commit current 7, then continue.

If it's NOT the 8th (e.g., happens at 3rd), something else is wrong:
- Save button off-screen → use scrollIntoView (`form-disciplines.md` rule 1)
- Wrong form ref (got stale form) → use `tail -1` (rule 2)
- Form value validation failed (rare, Connect doesn't show errors gracefully) → Cancel + retry

### Server count goes to 0 after reload

Staged vars all disappeared post-reload. Two scenarios:

1. **No Republish was issued between Save and reload** → expected behavior, Save is stage-only. Re-add and Republish properly.
2. **Republish was issued but session expired before commit** → URL guard catches this. Re-login, re-add, Republish again.

### Mid-batch session expiry

Halfway through batch 2, agent-browser snapshot shows blank or login page.

**Resolution**:
1. URL guard detects + auto-relogin (see keychain-setup.md)
2. Navigate back to `/settings/variables`
3. Count current saved (server-truth via reload)
4. Skip already-saved names, continue from next missing one

---

## Form-disciplines failures (silent classes)

If a batch reports all-success but server count after reload doesn't match, **assume one of the 3 disciplines was violated**:

1. Save off-screen but click "succeeded" → check `scrollIntoView` is happening
2. Form ref was stale → check `tail -1` is used (not `head -1`)
3. Count was inline (client state), not post-reload (server) → re-verify by force-reload

---

## YAML / Edit failures

### Edit tool fails "old_string not unique"

When updating companies.yaml, the company block isn't unique enough for Edit to match.

**Resolution**: Include more context in old_string (full block with surrounding lines). Or use sed for the specific field:

```bash
# Update single field
yq -i ".companies[\"$COMPANY\"].deployed_url = \"$URL\"" "$YAML"
yq -i ".companies[\"$COMPANY\"].status = \"production\"" "$YAML"
yq -i ".companies[\"$COMPANY\"].last_deployed = \"$(date +%Y-%m-%d)\"" "$YAML"
```

(yq preserves YAML structure better than sed for nested fields.)

---

## When all else fails: ask user to take over

The skill is designed to be **interruptable + resumable**. If something goes wrong that you can't diagnose:

1. Tell user clearly what state things are in:
   - Local dev tree: clean / dirty / committed-but-unpushed
   - Deploy repo: pushed to commit X
   - Posit Connect: content created? variables added? Republished?
   - companies.yaml: updated?

2. Recommend a partial recovery action they can take manually

3. Note that re-running `/posit-deploy <COMPANY>` is safe — the skill will detect existing state and skip already-done phases

---

## Known issues to file (issue #794 follow-up)

Things to surface in issue #794 when rewriting the posit-* plugin:

- `08-shiny-testing.md`'s "live URL → safari-browser" rule needs an exception for management UI (this skill)
- agent-browser doesn't have built-in `scrollIntoView` helper (every skill that uses it has to inline the JS)
- agent-browser snapshot exposes input.value for non-password fields — could mask if input has aria-hidden or specific class hints
- Posit Connect's ~7 staging limit is undocumented; worth filing upstream feedback
- Posit Connect session timeout is undocumented; URL guard pattern should be in plugin SKILL.md template
