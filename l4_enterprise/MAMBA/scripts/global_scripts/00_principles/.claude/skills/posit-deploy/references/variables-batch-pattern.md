# Variables Batch Pattern (Save-stage / Republish-commit)

The hardest part of the workflow. Posit Connect Cloud's Variables UI has a non-obvious lifecycle where **Save only stages** and **Republish actually commits**. Plus there's an effective per-batch limit. Get this wrong and your deploy silently fails with the UI showing success.

---

## The Save-stage / Republish-commit model

```
[Add variable] ─► form opens
                  │
                  ├─ fill Name + Value
                  │
[Save] ─► variable goes to client-side staged list
         (UI shows "Edit variable" row, count++)
         (NOTHING reaches Posit server yet)
                  │
                  ├─ repeat Add + Save × N more
                  │
[Republish] ─► commits ALL staged vars to server + triggers rebuild
              (this is the actual transactional commit)
```

Without the final Republish, all staged vars are lost on page reload or session expiry.

### How to verify a var is actually on server

```bash
# Reload the page (force server read, not cached client state)
agent-browser open "https://connect.posit.cloud/kyleyhl/content/<content_id>/settings/variables" --headed --session posit-connect >/dev/null 2>&1
sleep 4

# Count Edit-variable buttons — each one = one server-persisted var
COUNT=$(agent-browser snapshot -i --session posit-connect 2>/dev/null | grep -cE '"Edit variable"')
```

This is the gold standard for "did it actually persist?" — anything else (inline count after Save, snapshot of staged list) is client-side only.

---

## The ~7-vars-per-batch limit

After ~7 vars are staged (without Republish), Save stops incrementing. The form opens, fills, but Save click no longer adds to the list. UI shows nothing wrong — just the count fails to increase.

**Workaround**: After each batch (≤7 vars), Republish to commit them. This resets the "staging buffer" so you can add the next 7.

### Empirical batch breakdown for 21 standard l4_enterprise vars

```
Batch 1 (7): APP_ENV APP_DEBUG APP_LOG_LEVEL APP_PASSWORD AMZ_ACCESS_KEY AMZ_REGION AMZ_SECRET_KEY
  └─ Republish to commit → server count = 7

Batch 2 (7): PGDATABASE PGHOST PGPASSWORD PGPORT PGSSLMODE PGUSER SUPABASE_DB_HOST
  └─ Republish to commit → server count = 14

Batch 3 (7): SUPABASE_DB_NAME SUPABASE_DB_PASSWORD SUPABASE_DB_PORT SUPABASE_DB_USER SUPABASE_URL SUPABASE_ANON_KEY OPENAI_API_KEY
  └─ Republish to commit → server count = 21 ✓
```

3 batches × Republish = 3 rebuild cycles. Each rebuild = 1-3 min. Total ~10-15 min for the vars phase.

### Why save the longest (OPENAI_API_KEY, SUPABASE_ANON_KEY) for last

Long values (>150 chars) need extra time for React to settle before the Save click. By putting them in a batch where they're the trailing items, the pre-Save sleep can be longer without delaying earlier vars.

```bash
if [ ${#val} -gt 150 ]; then sleep 4
elif [ ${#val} -gt 100 ]; then sleep 2.5
else sleep 1; fi
```

---

## The canonical batch loop

```bash
stage_batch() {
  local batch_name="$1"; shift
  local S="posit-connect"
  echo "=== Batch: $batch_name ($# vars) ==="
  
  # Capture starting count (server-truth, after any previous Republish)
  local START=$(agent-browser snapshot -i --session $S 2>/dev/null | grep -cE '"Edit variable"')
  echo "  starting count: $START"
  
  local i=0
  for name in "$@"; do
    local val=$(get_env "$name")
    [ -z "$val" ] && { echo "  ✗ $name MISSING in .env"; continue; }
    
    # Inline call to safe_add_var (see form-disciplines.md)
    # Includes: scrollIntoView, tail -1 ref selection, count-only verify
    if safe_add_var "$name" "$val" "$((START+i))"; then
      ((i++))
    else
      echo "  ✗ batch broke at $name — stopping"
      return 1
    fi
  done
  
  # Commit the batch
  local REPUB_REF=$(agent-browser snapshot -i --session $S 2>/dev/null | grep -E 'button "Republish"' | tail -1 | grep -oE 'ref=e[0-9]+' | cut -d= -f2)
  if [ -z "$REPUB_REF" ]; then
    echo "  ✗ no Republish button — session may have expired"
    return 1
  fi
  
  echo "  Republishing to commit batch..."
  agent-browser eval "Array.from(document.querySelectorAll('button')).filter(b=>b.textContent.trim()==='Republish').pop()?.scrollIntoView({block:'center'}); 'ok'" --session $S >/dev/null 2>&1
  sleep 0.5
  agent-browser click "@$REPUB_REF" --session $S >/dev/null 2>&1
  sleep 10  # wait for republish to start + first commit roundtrip
  
  # Verify server-truth (forces page reload)
  agent-browser open "https://connect.posit.cloud/kyleyhl/content/${CONTENT_ID}/settings/variables" --headed --session $S >/dev/null 2>&1
  sleep 5
  
  # URL guard
  local URL=$(agent-browser get url --session $S 2>&1 | tail -1)
  if [[ "$URL" == *login* ]]; then
    echo "  ✗ session expired after Republish"
    return 2
  fi
  
  local SERVER=$(agent-browser snapshot -i --session $S 2>/dev/null | grep -cE '"Edit variable"')
  local EXPECTED=$((START+i))
  echo "  server-truth after batch: $SERVER (expected $EXPECTED)"
  
  if [ "$SERVER" = "$EXPECTED" ]; then
    return 0
  else
    echo "  ✗ batch commit failed — server has $SERVER not $EXPECTED"
    return 1
  fi
}
```

---

## Handling partial commits

If a batch partially commits (e.g., 5 of 7 vars made it to server), the skill should:

1. Re-query server for actual saved var names (not just count)
2. Diff against expected 21 list
3. Add only the missing ones in next batch

To get saved var names (without exposing values):

```bash
# Each "Edit variable" button is preceded by the var name in a textbox
# Snapshot shows: textbox "<NAME>" [disabled]: value-hidden  → button "Edit variable"
agent-browser snapshot -i --session posit-connect 2>/dev/null | grep -B 2 '"Edit variable"' | grep 'textbox' | grep -oE '"[A-Z_]+"' | tr -d '"'
```

Returns list of saved var names. Set-difference with target list = remaining to add.

---

## Why "Save+Republish" not "Save once":

The old plugin's `add-env-var` SKILL.md does ONE var + Republish per invocation. Reasonable for one-at-a-time use. For bulk (21 vars), Republish-per-var = 21 rebuilds = unacceptable. Batching gets it to 3 rebuilds.

The batch limit (~7) appears empirically; not documented by Posit. Could be a UI buffer, a debounced commit, or a React state cap. Doesn't matter — design around it.

---

## Verifying the deploy succeeded after final Republish

After last batch's Republish, Connect rebuilds the content. The container restarts with the new env vars. Poll the live URL:

```bash
LIVE_URL="https://${CONTENT_ID}.share.connect.posit.cloud/"
for i in {1..20}; do
  STATUS=$(curl -sI "$LIVE_URL" --max-time 8 2>/dev/null | head -1)
  echo "[$i] $STATUS"
  echo "$STATUS" | grep -q "200" && { echo "✓ live"; break; }
  sleep 15
done
```

HTTP 200 = container responding. But the app might still be in "Startup Error" state (R code failed). Smoke test via agent-browser snapshot:

```bash
agent-browser open "$LIVE_URL" --headed --session posit-live  # separate session, no login needed for public access
sleep 5
agent-browser snapshot -i --session posit-live 2>&1 | grep -iE "password|VIBE|admin|startup error"
```

Expected for l4_enterprise apps: textbox "請輸入系統密碼" + button "進入系統". If "Startup Error" appears, go to `/content/<id>/history` and read the build log.
