# Changelog Version Drift Fix

Claude sessions were independently incrementing the version number in `pubspec.yaml`, `extension/package.json`, and CHANGELOG.md between publishes, producing multiple numbered changelog sections (15.2.3, 15.2.4, 15.2.5) for content that had never been released. The last published tag was `v15.2.2`.

## Finish Report (2026-08-28)

### Problem

Each Claude session that added changelog entries also bumped the version number and created a new `## [X.Y.Z]` section, so three unpublished sections accumulated since the last `v15.2.2` release. The publish script already supported `## [Unreleased]` and `_strip_unreleased_suffix()` for hybrid headings, but nothing enforced using them.

### Changes

1. **Merged three unpublished sections** (15.2.3, 15.2.4, 15.2.5) into one `## [15.2.3] — Unreleased` section, organized by category (Fixed / Added / Changed / Maintenance). Removed dead `[log]` links to non-existent tags.

2. **Reset version numbers** in `pubspec.yaml` and `extension/package.json` from 15.2.4 back to 15.2.2 (last published tag).

3. **Widened `_UNRELEASED_SUFFIX_PAT` regex** in `scripts/modules/_version_changelog.py` from `r"\s*-\s*unreleas\w*"` to `r"\s*(?:-|—)\s*unreleas\w*"` so the publish script strips both hyphen and em-dash variants.

4. **Documented the convention** in two places:
   - CHANGELOG.md maintenance notes: `**Unreleased convention**` paragraph explaining the `## [X.Y.Z] — Unreleased` heading format and that version numbers stay at the last published version.
   - CLAUDE.md: `## Versioning & Changelog (HARD RULE)` section forbidding version bumps and new changelog sections.

5. **Added `assert_single_unreleased_section()` validation gate** in `scripts/modules/_version_changelog.py` — hard-fails the publish if CHANGELOG.md contains more than one unreleased section (either `## [Unreleased]` or `## [X.Y.Z] — Unreleased`). Wired into `sync_version_with_changelog()` alongside the existing empty-section guard. Prevents the version-drift problem from recurring mechanically, not just by documentation.

6. **Corrected documentation claim** — the CHANGELOG maintenance notes previously stated "the publish script creates the next unreleased section after publishing," which was false (post-publish auto-bump was removed). Changed to "manually add a new section."

### Verification

- `git tag --sort=-v:refname | head -1` confirms `v15.2.2` is the latest published tag.
- `grep -n "^## \[" CHANGELOG.md` shows one unreleased section (`[15.2.3] — Unreleased`) followed directly by `[15.2.2]`.
- The regex change is a strict superset of the old pattern — existing hyphen-separated headings still match.
- The new `assert_single_unreleased_section()` would catch the exact drift pattern (multiple unreleased sections) at publish time.

7. **Added `scripts/hooks/changelog_guard.py`** — dual-mode pre-commit / PostToolUse hook (same pattern as `spelling_guard.py`) that catches version drift at write time, not just publish time. Guards against multiple unreleased sections in CHANGELOG.md AND version numbers in pubspec.yaml / package.json that don't match the last published git tag. Wired into `.claude/settings.json` PostToolUse alongside the spelling guard. Exit code 2 blocks the commit or surfaces the error to Claude.
