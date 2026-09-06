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

The pre-commit hook was hardened: instead of counting occurrences and comparing against "NEVER use" matches (fragile if the instruction line is reformatted), the hook now strips the entire `<!-- ... -->` comment block with `sed` before checking, making it immune to comment rewording.

### Enforcement (two layers)

1. **Pre-commit hook** (`.githooks/pre-commit`): blocks commits introducing `<summary>Maintenance</summary>` in CHANGELOG.md content sections. Strips the HTML comment block before checking so the "NEVER use" instruction does not false-positive.

2. **Publish gate** (`scripts/modules/_publish_steps.py`): `_gate_changelog_internal_heading()` checks the version section at publish time, with the same retry/ignore/abort prompt pattern as the Overview check. Backed by `check_changelog_internal_heading()` in `_version_changelog.py`.

### Work still to do

None.

### Verification

- Grep for `<summary>Maintenance</summary>` across `.claude/`, `memory/`, `scripts/`, `CONTRIBUTING.md`, and `CHANGELOG_ARCHIVE.md` returns zero actionable hits.
- The only remaining occurrences are in frozen `plans/history/` archives (exempt) and the "NEVER use" instruction in CHANGELOG.md line 55 (correct).

### Done confirmation

Convention updated across all documentation, memory, and skills. Enforcement added at both commit time (pre-commit hook) and publish time (changelog validation gate). The `### Internal` heading is the sole documented and mechanically enforced convention.
