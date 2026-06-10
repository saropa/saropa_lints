# Publish gate: CHANGELOG Overview + version-pinned [log] link

User request (verbatim):

> 1. update the publish.py script to check for the release intro and log link in
> changelog.md. the log link must be set to the proposed version.
> 2. if the intro is not found then ask the user to retry/ignore/abort. default to retry

The publish workflow renamed `[Unreleased]` to `[version]` and validated that the
section existed, but never enforced that the section opens with the user-facing
Overview paragraph (and its `[log](.../vX.Y.Z/CHANGELOG.md)` link) mandated by the
CHANGELOG MAINTENANCE NOTES. Releases could ship with no summary, or with a `[log]`
link still pointing at `/main/` or a prior tag. This task adds that gate.

## Finish Report (2026-06-10)

This work will be reviewed by another AI.

### Scope
**(C) docs/scripts only** — Python publish tooling under `scripts/modules/` plus a
CHANGELOG Maintenance note and a new Python unit test. No Dart lint rules, analyzer
plugin code, `tiers.dart`, `example/`, or `extension/` files touched.

### Deep Review
- **Logic & Safety:** `check_changelog_overview` re-reads the file on every call, so
  the retry loop in `_gate_changelog_overview` picks up an in-place fix without state
  carryover. The loop has three exits (retry/ignore/abort); empty input and any `r*`
  retry, `i*` ignores, `a*` aborts — no infinite loop because ignore/abort always
  terminate. The intro/link regexes are anchored and bounded (`[^)]+`), no catastrophic
  backtracking.
- **Architecture & Adherence:** detection logic lives in `_version_changelog.py`
  (the module that already owns all CHANGELOG parsing — `validate_changelog_version`,
  `find_empty_version_sections`, the tag-clash promotion helpers); the interactive
  prompt lives in `_publish_steps.py` alongside the other Step-9 prompts. This mirrors
  the existing split (pure logic in the changelog module, I/O in the steps module) and
  reuses the module-level `_VERSION_RE`. The new `_extract_changelog_section_body`
  shares the exact section-capture regex shape used by `validate_changelog_version`,
  differing only in that it does NOT strip (the Overview check needs the pre-`###`
  prose verbatim).
- **Linter-Specific Integrity:** N/A — no lint rule, tier, or `LintImpact` change.
- **Performance:** runs once per publish at Step 9; negligible.
- **Documentation Quality:** both new functions carry doc headers explaining WHY
  (the wrong-tag-snapshot and missing-summary failure modes); the gate documents the
  default-to-retry rationale inline.

### Testing Validation
**A. Existing-test audit (MANDATORY):** grepped `test/` and `scripts/modules/tests/`
for `validate_changelog`, `check_changelog_overview`, `validate_changelog_version`,
`_extract_changelog_section_body`, `_gate_changelog_overview`. No existing test
references any symbol touched (matches were source files only). The two existing
changelog tests (`test_changelog_empty_sections.py`, `test_tag_clash_promotion.py`)
exercise sibling functions I did not modify; ran them anyway as a regression guard —
all pass.

**B. New tests:** added `scripts/modules/tests/test_changelog_overview.py` (9 cases):
valid section, leading-`---` tolerance, missing section, missing intro+link both
reported, intro-present-but-link-missing, link-present-but-wrong-version (`/main/`),
link-pinned-to-prior-tag, missing file, and a live-CHANGELOG sanity check against the
real `13.12.3` section.

Command run:
`python -m unittest scripts.modules.tests.test_changelog_overview scripts.modules.tests.test_changelog_empty_sections scripts.modules.tests.test_tag_clash_promotion -v`
Result: **21 passed, 0 failed.**

Import sanity: `python -c "import scripts.modules._publish_steps, scripts.modules._publish_workflow, scripts.modules._version_changelog"` → OK.

### Project Maintenance & Tracking
- CHANGELOG: Maintenance entry added under `[Unreleased]`.
- README verified — no updates needed (rule/doc counts unchanged).
- pubspec / pubspec.lock — SKIPPED [C-NOT-IN-SCOPE], no dependency or release change.
- TODOs/plans — none closed by this task.
- guides reviewed — nothing user-facing changed.
- Roadmap — SKIPPED [C-NOT-IN-SCOPE], no lint rule added or removed.
- Extension l10n — SKIPPED [C-NOT-IN-SCOPE], no `extension/` user-facing code touched.
- No bug archive — task did not close a `bugs/*.md` file.

### Finish report persistence
Finish report saved: plans/history/2026.06/2026.06.10/publish_changelog_overview_log_link_gate.md

### Core diff summary (for Reviewer AI)
- `scripts/modules/_version_changelog.py`: `+_extract_changelog_section_body(content, version)`
  (raw, unstripped section body) and `+check_changelog_overview(changelog_path, version) -> list[str]`
  (returns problems: missing section / missing intro prose / missing `[log]` link /
  `[log]` link not containing `/blob/v{version}/`).
- `scripts/modules/_publish_steps.py`: import `check_changelog_overview`; add
  `_gate_changelog_overview(project_dir, version) -> bool` (retry-default prompt loop);
  call it inside `validate_changelog` after the version-exists check — `False` aborts
  the publish via the existing `CHANGELOG failed` → `ExitCode.CHANGELOG_FAILED` path.
- `CHANGELOG.md`: Maintenance entry.
- `scripts/modules/tests/test_changelog_overview.py`: new (9 cases).

### Outstanding work
None. Note: the live `[Unreleased]` section currently has no Overview intro or
`[log]` link, so the next real publish run will (correctly) hit this gate and prompt
the author to add them.
