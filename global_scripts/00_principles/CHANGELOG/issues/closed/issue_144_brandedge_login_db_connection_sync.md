# Issue 144: BrandEdge Login Failure - db_connection.R Not Synced

**Status**: CLOSED
**Date**: 2025-01-08
**Severity**: Critical
**App**: BrandEdge (sandbox)

---

## Error Message

BrandEdge login failure - unable to authenticate users.

---

## Root Cause

**BrandEdge's `db_connection.R` was not synced after the PostgreSQL placeholder fix**

| App | db_connection.R Lines | Status |
|-----|----------------------|--------|
| sandbox_test | 460 | ✅ Has helper functions |
| deployment/tagpilot | 460 | ✅ Synced |
| **deployment/brandedge** | **405** | ❌ **Missing 55 lines** |

Missing functions (lines 407-460):
- `convert_placeholders()` - Converts `?` to PostgreSQL `$1, $2, $3`
- `db_query()` - SELECT query wrapper
- `db_execute()` - INSERT/UPDATE/DELETE wrapper

**Why login failed**:
1. Login module uses `$1` placeholder: `SELECT * FROM users WHERE username = $1`
2. Without `convert_placeholders()`, SQL syntax errors occur
3. Query fails, login rejected

---

## Solution

Synced BrandEdge using Makefile:

```bash
cd /Users/che/.../sandbox
make brandedge
```

Then pushed to GitHub for auto-deployment.

---

## Commits

| Repo | Commit | Description |
|------|--------|-------------|
| sandbox_brandedge | `cccfe8a` | fix: Sync db_connection.R with PostgreSQL placeholder helpers |

---

## Related Issues

- **Issue 142**: TagPilot db_execute PostgreSQL placeholder fix
- **Issue 143**: TagPilot analyze_customer_dynamics_new missing

All three issues share the same root cause: incomplete sync of `db_connection.R` helper functions across all deployment apps.

---

## Prevention

When making changes to shared files like `database/db_connection.R`:
1. Always sync ALL apps: `make sync-all`
2. Or sync individually: `make brandedge && make insightforge && make vitalsigns && make tagpilot`

---

## Verification

After deployment:
1. Navigate to https://kyleyhl-sandbox-brandedge.share.connect.posit.cloud/
2. Login with admin / 12345
3. Confirm successful authentication
