#!/bin/bash
# DEV_R056 Language Discipline Advisory Hook
# Triggered as PreToolUse on Edit/Write/MultiEdit invocations
#
# Emits an advisory warning when a .py file is being written outside the
# permitted Python territory (shared/global_scripts/09_python_scripts/).
#
# This hook is NON-BLOCKING — it only surfaces guidance, never aborts.
# Per DEV_R056 strength decision (advisory / convention, NOT mechanical
# correctness), the hook exits 0 even when emitting a warning.
#
# Test cases (per spectra change dev-r056-r-first-language tasks.md 3.1):
#   (a) write to 09_python_scripts/new_script.py SHALL NOT fire warning
#   (b) write to 04_utils/foo.py SHALL fire warning
#   (c) write to relative path during git rebase SHALL handle path
#       normalization correctly
#
# Known gap (R4 from design.md):
#   This hook fires on Write / Edit / MultiEdit tools. It does NOT fire
#   when an AI agent uses Bash to write a .py file (e.g., cat > foo.py,
#   tee foo.py, python -c '...' > foo.py). Primary defense for these
#   cases is the principle text in 01-always.md / 02-coding.md, which
#   loads into context regardless of which tool the AI uses.
#
# Related:
#   DEV_R056 (Project Primary Language — R First)
#   GitHub issue #498 (rule proposal source)
#   spectra change dev-r056-r-first-language

set -e

INPUT=$(cat /dev/stdin)

FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty')

# No file path → nothing to check
if [ -z "$FILE_PATH" ]; then
  exit 0
fi

# Only inspect .py files (DEV_R056 only governs Python; other languages
# have their own scope rules covered in the principle's full text).
case "$FILE_PATH" in
  *.py) : ;;
  *)    exit 0 ;;
esac

# Permitted Python territory: anywhere under 09_python_scripts/.
# Match either /09_python_scripts/ as a path segment or 09_python_scripts/
# at the start of a relative path.
case "$FILE_PATH" in
  */09_python_scripts/*) exit 0 ;;
  09_python_scripts/*)   exit 0 ;;
esac

# Reaching here means: a .py file is about to be written/edited outside
# the permitted Python territory. Emit advisory warning to stderr.
cat >&2 <<EOF

⚠ DEV_R056 advisory: Python file outside permitted territory

  File:   $FILE_PATH
  Tool:   $TOOL_NAME

  Project primary language is R. Python files SHALL only live in
  shared/global_scripts/09_python_scripts/ (currently 4 files: NLP/AI
  workloads). This file is outside that territory.

  Corrective options:
    1. Re-author as .R using readr / yaml / dplyr / data.table
       (most data-tooling tasks have R equivalents)
    2. If the file genuinely belongs in 09_python_scripts/, move it
       there before writing
    3. If a new Python territory is genuinely needed, file a spectra
       change with IC_P002 cross-company verification to expand the
       boundary (governance path)

  Reference: shared/global_scripts/00_principles/docs/en/part1_principles/
             CH03_development_methodology/rules/DEV_R056_project_primary_language.qmd

  This warning is advisory (exit 0). The write is not blocked, but
  consider correcting before commit. Triggered by GitHub issue #498.

EOF

# Advisory: exit 0, do not block.
exit 0
