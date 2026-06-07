# Issues Directory - Legacy Archive (GitHub Issues Source of Truth)

Issue tracking source of truth is **GitHub Issues**.  
This directory is retained as a **legacy archive** for historical records only.

## Structure

```
issues/
├── open/                    # Legacy historical open records
├── closed/                  # Legacy historical closed records
├── issue_{NUMBER}_{topic}/  # Legacy multi-file issues
└── README.md                # This file
```

## Current Policy

- New and active issues are created and managed in GitHub Issues.
- `issues/` is read-only historical context and should not receive new tracking files.
- Local active documentation should go to `../reports/` with naming:
  - `YYYY-MM-DD_issue-<number>_<topic>.md`

## GitHub Label Scope Convention

In the `global_scripts` repository:
- Company scope uses `company:<COMPANY_CODE>` (example: `company:MAMBA`)
- Module scope uses `module:<ModuleName>` (example: `module:BrandEdge`)
- Do not use `project:*`, `app:*`, or uppercase `Company:*` labels for issue scope
- GitHub Project is a container, not a scope type by itself
- Use scope-specific boards for `company:*` and `module:*`
- Add each issue to the matching scope board

## Migration Notes

- Previous structure: date-based subdirectories, ACTIVE/CLOSED/REJECTED_KEEP
- Migrated: 2026-01-06
- ~138 open issues, ~69 closed issues after migration
