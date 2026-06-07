# Dropbox Git Index Corruption Incident

**Date**: 2026-02-11
**Type**: Incident Report + Prevention
**Affected**: QEF_DESIGN (l4_enterprise)

## Summary

During batch git commits in a Dropbox-synced repository, Dropbox overwrote `.git/index` with an older version, causing a subsequent commit to silently include 77 files with reverted (old) content.

## Timeline

| Time  | Event |
|-------|-------|
| 19:55 | Batch commits 1-5: organized 154 files into 6 themed commits |
| 19:59 | Commit 5 completed. `git status` clean. HEAD = index = working tree = NEW |
| ~20:05 | **Dropbox overwrites `.git/index`** with older cached version |
| 20:19 | Issue #147 commit: `git add` only 2 issue files, `git commit` records entire index |
| 20:19 | **Result**: 82 files committed (2 intended + 77 reverted + 3 unrelated) |
| 20:30 | Fix commits `34d5eda` + `2b7e6b7` restore correct versions from working tree |

## Root Cause Analysis

### The Three Trees

```
After commit 5 (clean state):
  HEAD (commit)  = NEW
  Index (.git/index) = NEW
  Working Tree (disk) = NEW

After Dropbox corrupted .git/index:
  HEAD (commit)  = NEW
  Index (.git/index) = OLD  <-- Dropbox overwrote this
  Working Tree (disk) = NEW  <-- Files on disk were NEVER changed
```

### Why This Happened

1. **`.git/` was NOT excluded from Dropbox sync** (`com.dropbox.ignored` was not set)
2. Rapid git operations (6 commits in ~2 minutes) caused many writes to `.git/index`
3. Dropbox's conflict resolution replaced `.git/index` with a cached older version
4. When only 2 specific files were `git add`-ed for the issue commit, the other 77 entries in the corrupted index retained their old state
5. `git commit` recorded the entire index, including the 77 stale entries

### Evidence

- **71/71 overlapping files** between commit 5 and issue commit matched exactly the state at `3a524c8` (pre-batch commit)
- **0/71 files** had any new/unknown content — all were reversions to old versions
- Only **23/71** matched the subrepo upstream (`37b5f9e`), ruling out subrepo as the cause
- Fix commits successfully restored correct content from **working tree** (disk files were always correct)
- `git reflog` showed **no intermediate git operations** between commit 5 and issue commit

### Key Insight

The **disk files were never changed**. Only `.git/index` was corrupted. This means:
- `git add -A` would have **fixed** the issue (re-staging new content from disk)
- `git add <specific files>` only updated those files in the index, leaving 77 stale entries

## Prevention

### Immediate Fix (applied 2026-02-11)

```bash
# Set Dropbox ignore on all .git directories in ai_martech
find /path/to/ai_martech -name ".git" -type d -exec xattr -w com.dropbox.ignored 1 {} \;
```

37 `.git` directories found, 4 were missing the ignore flag (including QEF_DESIGN).

### Automated Prevention (SessionStart hook)

Created `.claude/hooks/dropbox-git-ignore.sh` — a SessionStart hook that automatically checks and excludes `.git` from Dropbox sync at the beginning of every Claude Code session.

### Git + Dropbox Safety Rules

1. **Always exclude `.git/` from Dropbox** via `com.dropbox.ignored` xattr
2. **Never use `git add -A` or `git add .`** — always add specific files by name
3. **Run `git status` after batch commits** to verify clean state
4. **Check `git diff --cached`** before committing to confirm staged content is correct

## Affected Commits

| Commit | Role |
|--------|------|
| `59064f2` | Last correct batch commit (commit 5) |
| `b23e7a0` | Corrupted issue commit (77 files reverted) |
| `34d5eda` | Fix: restored deployment restructure |
| `2b7e6b7` | Fix: restored remaining 75 files |
