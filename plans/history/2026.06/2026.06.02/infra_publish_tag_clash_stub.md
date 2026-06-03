# BUG: publish script — tag-clash bump inserts meaningless `"Release version"` stub, desyncing `.vsix` filename from CHANGELOG

**Status: Fixed**

Created: 2026-06-02
Closed: 2026-06-02
Area: `scripts/modules/_version_changelog.py` — `maybe_bump_for_tag_clash`
Severity: Release-integrity (ships wrong release notes to end users)
Affected versions: v13.11.9 (Marketplace `.vsix`) — pub.dev v13.11.8 was not affected because that publish path uses the CHANGELOG snapshot frozen at the first tag push.

---

## Summary

When `pubspec.yaml` was at `X.Y.Z` and tag `v{X.Y.Z}` already existed on the remote, the publish script auto-bumped to `X.Y.Z+1`, set `pubspec.yaml` to the bumped version, packaged `saropa-lints-{X.Y.Z+1}.vsix`, and inserted a placeholder `## [X.Y.Z+1]` CHANGELOG section whose only content was the literal string `"Release version"`. The real release notes (authored under `[X.Y.Z]` between the two publish runs) stayed under the now-stale `[X.Y.Z]` heading; the new stub landed past the file's auto-archive `---` boundary, far below the top section. Result: the `.vsix` filename and the top CHANGELOG section disagreed on what shipped, and the Marketplace listing's "Changelog" tab for `v{X.Y.Z+1}` showed `"Release version"` instead of the actual fix.

---

## Reproducer (script-level)

1. Land a release: `pubspec.yaml` at `13.11.8`, top CHANGELOG section `## [Unreleased]` → renamed by publish script to `## [13.11.8]`, tag `v13.11.8` pushed, pub.dev publish succeeds via GitHub Actions.
2. Author a fix in working tree. Add the fix description under the existing `## [13.11.8]` heading (instead of resetting to `## [Unreleased]`).
3. Re-run `python scripts/publish.py` without bumping `pubspec.yaml`.
4. Script reads `pubspec.yaml` (`13.11.8`), checks remote — tag `v13.11.8` exists. Script auto-bumps to `13.11.9`, writes `13.11.9` to `pubspec.yaml`, calls `add_version_section(changelog_path, "13.11.9", "Release version")`.
5. `add_version_section` inserts `## [13.11.9]` at the first `---\n\n## [VERSION]` match — which is the auto-archive boundary, not the top of the file. New stub lands between `[13.11.5]` and `[13.11.4]`.
6. `.vsix` packages as `saropa-lints-13.11.9.vsix`. Top CHANGELOG section remains `## [13.11.8]` with the real notes. `## [13.11.9]` stub sits in the archived block reading `"Release version"`.

**Frequency:** Every time a publish re-runs against a tag that already exists on remote, regardless of CHANGELOG state.

---

## Expected vs Actual

|              | Behavior                                                                                                                                                                                              |
| ------------ | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Expected** | `.vsix` filename, `pubspec.yaml` version, and top CHANGELOG section heading are always the same string. The release notes the user reads on Marketplace / pub.dev match the version they install.    |
| **Actual**   | `.vsix` filename advanced to `13.11.9`; top CHANGELOG section stayed `[13.11.8]` with the real `avoid_nullable_interpolation` fix notes; stranded `[13.11.9] = "Release version"` stub past archive split. |

---

## Root Cause

`maybe_bump_for_tag_clash` in `scripts/modules/_version_changelog.py` (pre-fix, line 584) treated the tag-collision case as "insert a fresh placeholder section above the existing history" rather than "the existing top section was authored against the colliding version — promote it to the bumped version." Two compounding problems:

1. **Wrong intent.** The stub inserter assumed the top CHANGELOG section was already correct for the prior release and that any new release needed its own new section. In practice, when a re-publish happens against an existing tag, the top section's content was almost always authored *for* the new release (because `pubspec.yaml` hadn't been bumped, the publish process couldn't have advanced past it). A rename, not an insert, was the right move.
2. **Wrong insertion position.** `add_version_section` searches for the first `---\n\n?## \[VERSION\]` boundary. Recent sections in this repo's CHANGELOG omit the `---` separator between them (only the archive split has one), so the search jumps past every recent section and lands in the archive block — invisible to readers.

The user's rule was stated directly in the conversation that closed this: **"the filename and the changelog MUST be in sync."** The script had no enforcement of that invariant.

---

## Fix (landed)

`scripts/modules/_version_changelog.py` — `maybe_bump_for_tag_clash` rewritten:

- New helper `_promote_top_section_to_version(changelog, expected, next)` renames the first `## [...]` heading from `[expected]` (or `[Unreleased]`) to `[next]`. Returns the original label on success, `None` when the top section is something the script cannot safely repurpose.
- On tag collision: bump `pubspec.yaml`, then call the promote helper. On `None` return, **abort with a clear error** instead of inserting a stub — the user must add `[next_version]` notes manually before re-running. The published version, `.vsix` filename, and top CHANGELOG section are now in sync by construction.
- No active code path inserts the literal string `"Release version"` anymore. The only CHANGELOG-section inserters (`add_version_section`, `reconcile_pubspec_changelog_versions`) now write `"Version bump"`. The string survives only as historical references in comments, the regression-test docstring, `CHANGELOG_ARCHIVE.md`, and `plans/history/`.

Tests pinned in `scripts/modules/tests/test_tag_clash_promotion.py` (4 cases):

1. Top section matches the colliding version → rename to bumped version (body travels with rename).
2. Top section is `[Unreleased]` → rename to bumped version.
3. Top section is an unrelated version → refuse (return `None`, file untouched).
4. Target version section already exists → refuse (no silent merge of two histories).

---

## Manual cleanup applied for v13.11.9

The bad `.vsix` for v13.11.9 was never uploaded. The corrective sequence before the Marketplace upload:

1. `CHANGELOG.md`: renamed the `[13.11.8]` heading (carrying the real `avoid_nullable_interpolation` notes) to `[13.11.9]`; collapsed `[13.11.8]` to a one-line pointer noting the re-package; deleted the orphan `[13.11.9] = "Release version"` stub from the archived block.
2. `extension/CHANGELOG.md`: re-copied from root (gitignored; regenerated at publish time per repo convention).
3. `extension/saropa-lints-13.11.9.vsix`: rebuilt via `npm run compile && npx @vscode/vsce package --no-dependencies`. Verified the bundled `extension/changelog.md` leads with the real `[13.11.9]` fix notes.

---

## Why this won't recur

The script-level abort makes "release `[X.Y.Z+1]` with a top section reading `[X.Y.Z]`" impossible without a manual override of the CHANGELOG by the user. The four-case test pins the helper's behavior. The historical incident is documented above so the failure pattern survives.

---

## Finish Report (2026-06-03)

**Trigger:** User asked to "review and fix" this bug doc.

**Scope:** (C) docs/scripts only. The underlying code fix (`maybe_bump_for_tag_clash` rewrite + `_promote_top_section_to_version` helper + 4-case regression test) had already landed in commit `c724d148`. This pass reviewed that fix against the live repo and corrected the doc.

**Review findings — code fix is real and verified:**
- `maybe_bump_for_tag_clash` promotes the top CHANGELOG section on tag clash and aborts (via `exit_with_error`) when the top section is neither the colliding version nor `[Unreleased]` — matches this doc's "Fix (landed)" section.
- `scripts/modules/tests/test_tag_clash_promotion.py` — all 4 cases pass (`python -m unittest scripts.modules.tests.test_tag_clash_promotion -v` → `Ran 4 tests OK`).
- No active code path inserts a `"Release version"` stub; the two CHANGELOG-section inserters (`add_version_section`, `reconcile_pubspec_changelog_versions`) write `"Version bump"`.

**Defect found in the doc (not the code):** the "Fix (landed)" bullet claimed the literal `"Release version"` "no longer appears in the codebase." `grep` shows it in 5 files (source comment, this doc, the test docstring, `CHANGELOG_ARCHIVE.md`, a prior history file). Corrected the bullet to the accurate claim: no active code path *inserts* it; remaining hits are historical references.

**Changes made this pass:**
- Corrected the false `"Release version"` claim in this file's "Fix (landed)" section.
- Archived this report `bugs/ → plans/history/2026.06/2026.06.02/` (Status was already `Fixed`, closed 2026-06-02) — commit `3cb8929c`.
- Repointed the stale `bugs/infra_publish_tag_clash_stub.md` reference in `scripts/modules/_version_changelog.py` to this archived path.

**Outstanding work:** none.
