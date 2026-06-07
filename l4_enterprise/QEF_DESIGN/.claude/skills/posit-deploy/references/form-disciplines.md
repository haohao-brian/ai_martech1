# Posit Connect Form Disciplines (the 3 hard-won rules)

Three rules that EACH cost ~30 minutes to discover on 2026-05-22/23 during QEF_DESIGN first deploy. **Following them is not optional** — each rule directly maps to a class of silent failures that mimic success.

---

## Rule 1: `scrollIntoView` before every Save click

### What goes wrong without this

agent-browser's `.click()` operates on element coordinates **as currently positioned in the viewport**. If the Save button is below the visible area (e.g., after 7+ vars are listed above the form), `.click()` silently fires on a coordinate where nothing actionable exists — or worse, on a different element entirely.

**Worst part**: client-side React state may still update (count++) because the Save button's React handler fires from some other interaction, but the actual XHR to Posit's server never happens. UI shows "1 variable added!", server still has 0.

### What to do

Scroll the target into view immediately before clicking:

```bash
# Scroll the LAST Save button (newly-opened form) into center of viewport
agent-browser eval "Array.from(document.querySelectorAll('button')).filter(b=>b.textContent.trim()==='Save').pop()?.scrollIntoView({block:'center'}); 'ok'" --session posit-connect >/dev/null 2>&1
sleep 0.4

agent-browser click "@$SAVE_REF" --session posit-connect >/dev/null 2>&1
```

The `pop()` is intentional — there may be multiple Save buttons on the page (e.g., per-row edit forms). Want the freshly-opened one.

Apply same pattern to Add variable, Republish, and any other action that may scroll out of view as the page accumulates state.

### When this rule first failed

2026-05-23 batch loop: stages 1-7 succeeded, 8th failed. Diagnosis showed Save button at `top: 782` (below viewport bottom ~700). After scrollIntoView, click worked. Same root cause for all batches >7.

---

## Rule 2: `tail -1` for newly-opened form refs

### What goes wrong without this

When you click "Add variable" and snapshot, Posit's React may render BOTH:
- The just-opened new form (empty Name + Value + new Save)
- Some leftover/cached element from previous interaction

Grep'ing with `head -1` picks the FIRST match in the snapshot output, which is often the stale/cached one — not the form you just opened. Fill goes to a hidden/dead input, Save click hits a stale button, nothing happens.

### What to do

Use `tail -1` to grab the LAST occurrence (the just-opened form):

```bash
SNAP=$(agent-browser snapshot -i --session posit-connect 2>/dev/null)
NAME_REF=$(echo "$SNAP" | grep 'textbox "Name"' | tail -1 | grep -oE 'ref=e[0-9]+' | cut -d= -f2)
VAL_REF=$(echo "$SNAP" | grep 'textbox "Value"' | tail -1 | grep -oE 'ref=e[0-9]+' | cut -d= -f2)
SAVE_REF=$(echo "$SNAP" | grep 'button "Save"' | tail -1 | grep -oE 'ref=e[0-9]+' | cut -d= -f2)
```

Same pattern for "Add variable", "Republish", "Cancel" — always `tail -1`.

### Edge case

For initial page load (before any Add click), `head -1` and `tail -1` are equivalent (only one form-related element exists). Using `tail -1` uniformly is safe.

### When this rule first failed

2026-05-23: 9th var failed even WITH scrollIntoView. Diagnosis: snapshot had multiple `textbox "Name"` matches (the new form's empty Name + leftover from previous form). `head -1` grabbed leftover → fill went nowhere. Switching to `tail -1` fixed.

---

## Rule 3: count-only verification, NEVER snapshot mid-edit form values

### What goes wrong without this

Posit Connect's Variables form uses `<input type="text">` and `<textarea>` (not `type="password"`). The DOM `value` attribute is plaintext.

`agent-browser snapshot -i` reads input/textarea values and includes them in the output stream:

```
- textbox "Value" [ref=e39]: sk-proj-zH-4NE...real_api_key_here...
```

That output goes to stdout → bash tool result → conversation log. **Permanent leak.**

Same problem for `agent-browser screenshot` — Posit displays the value visually in the form, screenshot captures it.

### What to do

**Verify by counting saved vars, not by reading values:**

```bash
COUNT=$(agent-browser snapshot -i --session posit-connect 2>/dev/null | grep -cE '"Edit variable"')
```

Each saved variable produces an "Edit variable" button in the list. Counting matches gives total saved count without ever exposing names or values.

**Comparison pattern:**

```bash
EXPECTED=$((PREV+1))
if [ "$COUNT" = "$EXPECTED" ]; then
  echo "✓ $name (count=$COUNT)"
else
  echo "✗ $name (got=$COUNT exp=$EXPECTED)"
  # Cancel mid-edit form before retry
fi
```

Notice we **never** log the value, **never** log success with the value, **never** snapshot the form after fill.

### Defense in depth

Even if you accidentally snapshot, immediately:

1. Cancel the form (so the value is no longer in DOM): find Cancel ref → click
2. Alert user that the value leaked
3. Strongly recommend rotating the affected secret (API keys, DB passwords)

### When this rule first failed

2026-05-22 + 2026-05-23: **TWO** independent leaks in one session:
- `SUPABASE_DB_PASSWORD` (16 chars) — via safari-browser screenshot of mid-edit form
- `OPENAI_API_KEY` (164 chars) — via agent-browser snapshot when investigating why Save failed

Both required user to rotate the secrets.

---

## Bonus: react-select dropdowns need `mousedown` not `click`

For Public access / Framework / similar comboboxes built with react-select, `.click()` doesn't open the dropdown. Need:

```bash
agent-browser eval "
(function(){
  var ci = document.querySelector('input[id=\"content.publicAccess\"]');
  var ctrl = ci.closest('[class*=control]');
  ctrl.dispatchEvent(new MouseEvent('mousedown', {bubbles:true, button:0}));
  ctrl.dispatchEvent(new MouseEvent('mouseup', {bubbles:true, button:0}));
  return 'opened';
})()
" --session posit-connect 2>&1 | tail -1
```

Once open, can typeahead-fill ("Enabled") then click the matching option.

---

## Combined safe-Add-var pattern

Here's the canonical safe loop incorporating all 3+1 rules:

```bash
safe_add_var() {
  local name="$1" val="$2"
  local S="posit-connect"

  # Find Add via tail
  local ADD_REF=$(agent-browser snapshot -i --session $S 2>/dev/null | grep '"Add variable"' | tail -1 | grep -oE 'ref=e[0-9]+' | cut -d= -f2)
  [ -z "$ADD_REF" ] && { echo "✗ no Add button — page broken?"; return 1; }

  # Scroll Add into view + click
  agent-browser eval "Array.from(document.querySelectorAll('button')).filter(b=>b.textContent.trim()==='Add variable').pop()?.scrollIntoView({block:'center'}); 'ok'" --session $S >/dev/null 2>&1
  sleep 0.3
  agent-browser click "@$ADD_REF" --session $S >/dev/null 2>&1
  sleep 2

  # Grab newest form refs via tail
  local SNAP=$(agent-browser snapshot -i --session $S 2>/dev/null)
  local NAME_REF=$(echo "$SNAP" | grep 'textbox "Name"' | tail -1 | grep -oE 'ref=e[0-9]+' | cut -d= -f2)
  local VAL_REF=$(echo "$SNAP" | grep 'textbox "Value"' | tail -1 | grep -oE 'ref=e[0-9]+' | cut -d= -f2)
  local SAVE_REF=$(echo "$SNAP" | grep 'button "Save"' | tail -1 | grep -oE 'ref=e[0-9]+' | cut -d= -f2)

  # Fill (fill itself doesn't echo value to stdout — safe)
  agent-browser fill "@$NAME_REF" "$name" --session $S >/dev/null 2>&1
  sleep 0.5
  agent-browser fill "@$VAL_REF" "$val" --session $S >/dev/null 2>&1

  # Length-scaled wait for React state to settle
  if [ ${#val} -gt 150 ]; then sleep 4
  elif [ ${#val} -gt 100 ]; then sleep 2.5
  else sleep 1; fi

  # Scroll Save into view RIGHT before click (form may have shifted during fill)
  agent-browser eval "Array.from(document.querySelectorAll('button')).filter(b=>b.textContent.trim()==='Save').pop()?.scrollIntoView({block:'center'}); 'ok'" --session $S >/dev/null 2>&1
  sleep 0.4
  agent-browser click "@$SAVE_REF" --session $S >/dev/null 2>&1
  sleep 2

  # Count-only verify (NEVER snapshot the form value)
  local NEW=$(agent-browser snapshot -i --session $S 2>/dev/null | grep -cE '"Edit variable"')
  local EXP=$((PREV_COUNT+1))
  if [ "$NEW" = "$EXP" ]; then
    echo "✓ $name (count=$NEW len=${#val})"
    PREV_COUNT=$NEW
    return 0
  else
    echo "✗ $name (got=$NEW exp=$EXP len=${#val})"
    # Cancel any open form so we don't accumulate dirty state
    local CANCEL_REF=$(agent-browser snapshot -i --session $S 2>/dev/null | grep 'button "Cancel"' | tail -1 | grep -oE 'ref=e[0-9]+' | cut -d= -f2)
    [ -n "$CANCEL_REF" ] && { agent-browser click "@$CANCEL_REF" --session $S >/dev/null 2>&1; sleep 1; }
    return 1
  fi
}
```

Use this as the primitive for all variable additions.
