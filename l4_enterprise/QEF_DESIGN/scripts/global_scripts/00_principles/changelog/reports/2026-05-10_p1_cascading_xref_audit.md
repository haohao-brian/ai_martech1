# Cascading Cross-Reference Audit for P1 Vocabulary Realignment

> **Spectra change**: `etl-vocabulary-realignment-glue-era` Task 1.2
> **Date**: 2026-05-10
> **Author**: Claude (autonomous /spectra-apply)
> **Risk mitigation**: design **Risk 1 — Vocabulary amendment 引發 cascading cross-reference update**

---

## Reference Count Summary

| MP target | Files referencing | Substantive-update needed |
|---|---:|---:|
| MP064 | 178 | ~5 (Layer 2/3 + Layer 1 frontmatter mentions only) |
| DM_R028 | 72 | ~4 |
| MP102 | 84 | ~5 |
| MP104 | 66 | ~3 |
| MP107 | 33 | (covered by MP107 own amendment) |
| MP108 | 34 | (covered by MP108 own amendment) |

**Total reference files**: ~470
**Substantive cross-reference updates**: ~17

## Why Most References Don't Need Substantive Update

Most references are "see MP064" / "per MP064" / "依 MP064" type — they cite the principle by ID without re-stating its normative content. When MP064's content is amended, these references automatically inherit the new content because they only point to the principle ID, not its specific wording.

Substantive cross-reference updates are needed only when:

1. The reference inline-quotes the amended principle's normative wording (e.g. "ETL handles preparation, canonical 在 transformed 層")
2. The reference is in a Layer 2 yaml or Layer 3 rules.md (which IS the DOC_R009 three-layer sync target — already in P1 task scope)
3. The reference is in another MP qmd's frontmatter `related_to:` description (cosmetic — usually fine)

## Substantive Update Locations Identified

### Layer 2 yaml — `00_principles/llm/CH02_data.yaml`

5 mention sites for ETL-axis principles:
- `MP064` reference in 6-layer ETL section (line ~varies by location)
- `MP064` parent_principle annotation in derived rules
- `MP102 v1.3` reference in bridge yaml section
- `DM_R028` reference in ETL naming
- `MP104` reference in data flow

These are the canonical Layer 2 sync targets per DOC_R009. Will be updated in each MP's amendment task (Tasks 2-6) per atomic three-layer sync (design Decision 2).

### Layer 3 rules — `00_principles/.claude/rules/02-coding.md`

Mention sites identified by line:
- L116: MP102 (ETL Output Standardization) reference
- L117: DM_R028 (ETL Data Type Separation) reference
- L206: Bridge reviewed_by (MP102 v1.3) section
- L210: 結構化形式 (canonical, MP102 v1.3) reference
- L294: MP102 v1.3 fourth member (sign off)
- L298: MP102 path reference for self-converging review section
- L342: ETL vs Derivation 分離 (MP064) section header
- L406: Code comment example "# Following MP064"
- L448: Binding principles list (MP102 v1.2 + MP156 + MP157 Layer 1)
- L531: DM_R028 (ETL Data Type Separation) related-principle reference

Will be updated in each MP's amendment task per DOC_R009 sync.

### Layer 1 cross-references in other MP qmd

The references in other MP qmd files are mostly in `related_to:` frontmatter descriptions (cosmetic, doesn't need text change) OR inline "per MP064" references that auto-inherit amended content.

Spot-check found NO references containing the specific stale wording "canonical 在 transformed", "canonical at transformed", "ETL handles preparation", or "2TR.*canonical schema" patterns. The amendment surface is contained.

## Out of Scope

- 178 references to MP064 across CH12 / CH13 / CH18 / CH19 / CH20 implementation chapters — most are "see MP064" type, no substantive update needed.
- changelog/reports/* historical mentions — immutable per MP030 archive rule, never updated.
- _implementation_rules.yaml derivation specs (CH13 derivations) — these are derived rule definitions citing parent_principle: MP064, structurally inherited.
- archived openspec/changes/ — immutable.

## Risk 1 Mitigation Verdict

**Risk 1 successfully timeboxed**. Audit completed in <15 minutes (well under the 1-hour timebox).

Cascading update scope is bounded to:
- 4 MP qmd amendments (Tasks 2.1, 3.1, 4.1, 5.1) — each handles its own DOC_R009 sync
- 2 MP qmd amendments contingent on Task 1.1 evaluation (Tasks 6.1, 6.2 — both in-scope per Task 1.1 report)
- 1 Layer 2 yaml file (`CH02_data.yaml`) — touched by each MP amendment task
- 1 Layer 3 rules.md file (`02-coding.md`) — touched by each MP amendment task

Total substantive file changes ≈ 14-15 files (6 en MP qmd + 6 zh MP qmd + 1 Layer 2 yaml + 1 Layer 3 rules).

Inline references in other docs auto-inherit amended principle content. No additional cascading update tasks needed.

## Cross-references

- **Spectra change**: `openspec/changes/etl-vocabulary-realignment-glue-era/`
- **Master plan**: `openspec/specs/etl-architecture-roadmap/spec.md`
- **DOC_R009 mandate**: `00_principles/docs/en/part1_principles/CH19_documentation/rules/DOC_R009_principle_triple_layer_synchronization.qmd`
- **MP030**: archive immutability prevents historical changelog/report mention updates
