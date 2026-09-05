# Tag-clash CHANGELOG promotion matched its own doc-comment's example heading instead of the real one

During a live 16.0.0-beta.2 to 16.0.0-beta.3 publish (triggered by a prior
tag clash — `v16.0.0-beta.2` already existed on remote after an earlier
run's Ctrl-C crash had actually succeeded), the publish script's automatic
CHANGELOG promotion refused to rename the top section, reporting it as
"neither [16.0.0-beta.2] nor [Unreleased] nor [16.0.0-beta.3]" even though
the top section was in fact exactly `## [16.0.0-beta.2]`.

## Root cause

`_promote_top_section_to_version()` in `scripts/modules/_version_changelog.py`
located the top heading with `re.search(r"## \[([^\]]+)\]", content)` — not
anchored to the start of a line. `CHANGELOG.md` carries a maintenance
doc-comment above the first real release section that documents the
heading convention using literal inline-code text: `` `## [X.Y.Z] —
Unreleased` ``. That substring appears earlier in the file than the real
`## [16.0.0-beta.2]` heading, so the unanchored search matched it first,
capturing the placeholder `"X.Y.Z"` as the "top heading" instead of the
real one. `"X.Y.Z"` matched neither the expected version, `next_version`,
nor `"Unreleased"`, so the function returned `None` and the caller
(`maybe_bump_for_tag_clash`) surfaced the "cannot publish" prompt in an
infinite retry loop — the file's real heading was already correct, but the
buggy match never looked at it.

Because the already-running `publish.py` process had imported the buggy
module before the fix was applied to disk, pressing Enter to retry could
never succeed even after the source was patched — Python does not
hot-reload modules mid-process. The process had to be aborted and
`publish.py` restarted so the fix would actually take effect.

## Fix

Anchored all three headline-matching regexes in
`_promote_top_section_to_version()` with `^` + `re.MULTILINE`, so only an
actual `## [...]` heading at the start of a line can match — inline-code
mentions of the same pattern inside prose (this file's own convention
documentation) are no longer eligible.

## Test

Added `test_ignores_heading_example_in_leading_doc_comment` to
`scripts/modules/tests/test_tag_clash_promotion.py`, reproducing the exact
shape of the incident: a leading `<!-- -->` doc-comment containing a
literal `"## [X.Y.Z] - Unreleased"` example above a real `## [13.11.8]`
section. Also fixed the test file's own `_top_heading()` helper, which
carried the identical unanchored-regex bug and would have silently
validated a false pass had it been left alone. All 7 tests in the file
pass: `python -m unittest scripts.modules.tests.test_tag_clash_promotion -v`.

## Files changed

- `scripts/modules/_version_changelog.py` — anchored the three `## [...]`
  matching regexes in `_promote_top_section_to_version()`.
- `scripts/modules/tests/test_tag_clash_promotion.py` — new regression
  test; fixed the same bug in the test helper `_top_heading()`.

Not committed as part of this change: `CHANGELOG.md` and `pubspec.yaml`,
which carry the live publish run's own in-progress version-bump state
(`16.0.0-beta.3`) — those are the publish script's own working-tree state
to commit in its "Git commit & push" step, not this fix's.

---

## Finish Report (2026-09-04)

Closes nothing in `bugs/`; SKIPPED [NO-BUG-FIXED] — this fix was diagnosed
live during an active publish run's failure, not from a filed bug report.

Scope: (C) docs/scripts only — Python publish-pipeline module
`scripts/modules/_version_changelog.py` and its test file. No Dart lint
rules, no extension TypeScript, no user-facing behavior change (affects
only the developer-facing `publish.py` CLI's tag-clash recovery path).
