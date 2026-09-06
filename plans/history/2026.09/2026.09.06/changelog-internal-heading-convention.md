# Changelog Internal Heading Convention

The CHANGELOG convention for non-user-facing entries used `<details><summary>Maintenance</summary>` HTML expanders. This was replaced with a plain `### Internal` markdown heading for readability and consistency.

## Finish Report (2026-09-06)

### Work completed

All references to the `<details><summary>Maintenance</summary>` pattern were replaced with `### Internal` across:

- `CHANGELOG.md` binding contract comment (lines 53, 55)
- Skill: `saropa-lints-docs-and-writing` (section 2.6, section 7)
- Skill: `saropa-lints-change-control` (N5 rule)
- Skill: `finish` (both variant section 6 headings)
- Memory: `feedback_changelog_maintenance.md` (full rewrite)
- Memory: `MEMORY.md` (index line)
- Memory: `project_precommit_doc_and_ci_checklist.md` (reference)

### Hardening

Grep sweep of CONTRIBUTING.md, `.githooks/`, `scripts/`, and `CHANGELOG_ARCHIVE.md` confirmed zero stale `<summary>Maintenance</summary>` references outside archived history files (which are frozen and exempt). No publish or CI scripts parse the changed MAINTENANCE NOTES comment text — only the comment delimiter `MAINTENANCE NOTES` is used programmatically (by `_version_changelog.py` and its test).

### Pre-commit enforcement

Added a gate to `.githooks/pre-commit` that blocks commits introducing `<details><summary>Maintenance</summary>` in CHANGELOG.md. The gate checks staged content (not working tree) and allows the one "NEVER use" instruction in the MAINTENANCE NOTES comment. This prevents the retired pattern from recurring — the same defense-in-depth approach used for British spellings (N9) and AI attribution (N7).

### Work still to do

None.

### Verification

- Grep for `<summary>Maintenance</summary>` across `.claude/`, `memory/`, `scripts/`, `CONTRIBUTING.md`, and `CHANGELOG_ARCHIVE.md` returns zero actionable hits.
- The only remaining occurrences are in frozen `plans/history/` archives (exempt) and the "NEVER use" instruction in CHANGELOG.md line 55 (correct).

### Done confirmation

Eight files updated (seven convention replacements + one pre-commit gate). The `### Internal` heading is now the sole documented and mechanically enforced convention for non-user-facing changelog entries.
