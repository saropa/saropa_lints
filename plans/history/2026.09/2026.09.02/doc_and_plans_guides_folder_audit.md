# doc/guides vs plans/guides folder audit

`PACKAGE_VIBRANCY.md` was misplaced under `plans/guides/` even though it is
public SDK version-history data consumed at a repo-root path by the VS Code
extension. Separately, `plans/` — internal planning, UX specs, and research
notes — was not excluded from the pub.dev package, so it shipped inside the
published tarball alongside user-facing docs.

## Findings

A full-repo audit of `doc/guides/` (19 files) and `plans/guides/` (9 files)
confirmed 26 of 27 files were correctly split: `doc/guides/` holds
user-facing docs (migration guides, library integration guides, CLI
reference) shipped with the package; `plans/guides/` holds internal dev
reference material (UX guidelines, style guides, research writeups).
`good_methods.md` was confirmed genuinely user-facing (linked from in-code
doc comments in `lib/src/init/stylistic_rulesets.dart` and
`lib/src/rules/stylistic/formatting_rules.dart`) and stays in `doc/guides/`.
`UX_UI_GUIDELINES.md` and `UX_GUIDELINES.md` are not duplicates — a
canonical spec and its companion compliance/backlog tracker.

Two stale references were found independent of the folder split:
`extension/scripts/i18n/generate_locales.py` pointed at
`plans/EXTENSION_LOCALIZATION_GUIDE.md` (missing the `/guides/` segment),
and `README.md` contained two dead relative links into paths not shipped
with the package (`bugs/discussion/RULE_METADATA_BULK_STATUS.md`, which no
longer exists, and `plans/history/2026.04/2026.04.28/project_vibrancy_report.md`).

## Changes

- Moved `PACKAGE_VIBRANCY.md` from `plans/guides/` to the repo root, matching
  the path `extension/src/vibrancy/sdk-vibrancy-table.ts` expects.
- Fixed the stale `/guides/`-less path in `generate_locales.py`.
- Added `plans/` to `.pubignore`. The directory remains git-tracked and
  fully visible on GitHub; the exclusion only trims the pub.dev tarball.
- Removed the two dead relative links from `README.md`.
- Added `scripts/check_doc_links_excluded_paths.py`, a standalone guard that
  fails if a shipped doc (`doc/**`, `README.md`) links to a path excluded by
  `.pubignore` (`plans/`, `bugs/`, `scripts/`). Wired into
  `.github/workflows/ci.yml` next to the existing dependency-import check.
  Running it against the repo before the README fix caught the two dead
  links above; it passes clean after.

## Verification

- `python scripts/check_doc_links_excluded_paths.py` — exit 1 with the two
  README violations before the fix, exit 0 clean after.
- `dart pub publish --dry-run` was not run (tool permission denied in this
  session) — the package-size effect of excluding `plans/` from the tarball
  is unverified by direct dry-run output, though the mechanism
  (`.pubignore` directory-prefix exclusion) matches the existing pattern
  used for `bugs/` and `scripts/`.
- Grepped the repo for remaining references to the old
  `plans/guides/PACKAGE_VIBRANCY.md` path; none found outside frozen
  history entries for an unrelated same-named file
  (`PACKAGE_VIBRANCY_REPORT_REMAINING.md`).

## Finish Report (2026-09-02)

Scope: docs/scripts only. No Dart rule/analyzer code or extension
TypeScript logic touched. `/code-review low` was run twice (once for the
initial three-file fix, once after adding the CI check); both passes
surfaced only pre-existing findings in `extension/src/systemHealth/` and
`extension/src/scanOnSave/` from unrelated concurrent work already present
in the working tree — none applicable to this change's diff.
