# Keychain Setup & Auto-Login

Stores the Posit Connect Cloud password in macOS Keychain (OS-encrypted) and retrieves it inline during agent-browser login. Avoids hardcoding the password anywhere, and matches the user's existing security discipline (same pattern as the `che-mcps-notary` notarization profile in their global CLAUDE.md).

---

## First-time setup (user runs ONCE)

The user must run this **interactively in their own Terminal** (not via Claude Code) so the password never enters the conversation log:

```bash
security add-generic-password -U -s "posit-connect-cloud" -a "posit-login" -w
```

Breakdown:
- `-U` = update if entry already exists (idempotent)
- `-s posit-connect-cloud` = service name (skill greps this)
- `-a posit-login` = account name
- `-w` (no value) = interactive hidden-input prompt

After Enter, terminal shows `password:` prompt with hidden input. User types Posit password, presses Enter, then a second confirmation Enter. Done.

The first time the skill retrieves this password, macOS will pop a Keychain Access dialog: **"security wants to use your keychain"**. User should click **"Always Allow"** so subsequent runs don't prompt.

---

## What the skill does to log in

Posit's login is a two-step form:
1. Email field + Continue button
2. Password field + Log in button

Then a destination picker (Posit Connect Cloud / Posit Cloud / shinyapps.io).

### Step 1: Email

After opening `https://login.posit.cloud/login`:

```bash
S="posit-connect"
# Snapshot to get email + continue refs (use tail -1 per form-disciplines.md)
SNAP=$(agent-browser snapshot -i --session $S 2>/dev/null)
EMAIL_REF=$(echo "$SNAP" | grep 'textbox "Email"' | tail -1 | grep -oE 'ref=e[0-9]+' | cut -d= -f2)
CONT_REF=$(echo "$SNAP" | grep 'button "Continue"' | tail -1 | grep -oE 'ref=e[0-9]+' | cut -d= -f2)

# Get email from companies.yaml or use default
EMAIL=$(yq ".companies[\"$COMPANY\"].posit_login_email // \"mr.no.one01@gmail.com\"" "$L4_ROOT/.claude/companies.yaml" -r)

agent-browser fill "@$EMAIL_REF" "$EMAIL" --session $S >/dev/null 2>&1
sleep 1
agent-browser click "@$CONT_REF" --session $S >/dev/null 2>&1
sleep 5  # wait for password form to render
```

### Step 2: Password (Keychain pipe — no intermediate variable)

```bash
SNAP=$(agent-browser snapshot -i --session $S 2>/dev/null)
PW_REF=$(echo "$SNAP" | grep 'textbox "Password"' | tail -1 | grep -oE 'ref=e[0-9]+' | cut -d= -f2)
LOGIN_REF=$(echo "$SNAP" | grep 'button "Log in"' | tail -1 | grep -oE 'ref=e[0-9]+' | cut -d= -f2)

# Pipe password directly from Keychain into agent-browser argv via $(...)
# - shell expands $(...) into argv
# - command literal in the bash tool call shows "$(security...)" not the value
# - agent-browser fill doesn't echo the value to stdout
# Net result: value lives in argv momentarily (visible only via local `ps`),
# never in conversation log
agent-browser fill "@$PW_REF" "$(security find-generic-password -s posit-connect-cloud -a posit-login -w)" --session $S >/dev/null 2>&1
sleep 0.5
agent-browser click "@$LOGIN_REF" --session $S >/dev/null 2>&1
sleep 5  # wait for redirect to destination picker
```

### Step 3: Destination

```bash
DEST_REF=$(agent-browser snapshot -i --session $S 2>/dev/null | grep 'link "Posit Connect Cloud"' | tail -1 | grep -oE 'ref=e[0-9]+' | cut -d= -f2)
agent-browser click "@$DEST_REF" --session $S >/dev/null 2>&1
sleep 4  # wait for /kyleyhl/ home to load
```

After this, URL should be `https://connect.posit.cloud/<account>` — verify with URL guard.

---

## When Keychain entry is missing

Detect with metadata-only query (does NOT retrieve the value):

```bash
if ! security find-generic-password -s "posit-connect-cloud" -a "posit-login" >/dev/null 2>&1; then
  echo "✗ Keychain entry missing. Run in your Terminal:"
  echo ""
  echo "  security add-generic-password -U -s \"posit-connect-cloud\" -a \"posit-login\" -w"
  echo ""
  echo "Then enter your Posit password at the hidden prompt. Press Enter twice to confirm."
  echo "After that, re-run /posit-deploy."
  exit 1
fi
```

---

## What this design solves vs doesn't

| Solves | Doesn't solve |
|---|---|
| Password at rest (encrypted in Keychain, not in `.env`) | Posit form rendering leak (mid-edit snapshot exposes typed values) |
| Password in conversation log during storage (`-w` hidden prompt) | Form values visible if you screenshot mid-edit |
| Repeated re-typing across deploys | Posit session expiry (~30 min) — see URL guard pattern |
| Accidental `Read .env` exposing all secrets | argv exposure during fill (local-only, low risk) |

The `agent-browser fill ... "$(security ...)"` pattern is the gold standard for THIS specific layer (password value never sits in a shell variable or echo). For form-rendering leaks see `form-disciplines.md` rule 3.

---

## Session timeout handling

Posit Connect sessions expire after ~30 min inactivity. The skill should re-login automatically when URL guard detects the login page:

```bash
URL=$(agent-browser get url --session posit-connect 2>&1 | tail -1)
if [[ "$URL" == *"login.posit.cloud"* ]]; then
  echo "⚠ Session expired — re-logging in via Keychain"
  # Run steps 1-3 above
fi
```

Add this guard at the start of every Phase 2-5 operation. Without it, post-expiry clicks operate on stale refs and silently fail (UI may even show success — see form-disciplines.md rule 1 for analogous pattern).
