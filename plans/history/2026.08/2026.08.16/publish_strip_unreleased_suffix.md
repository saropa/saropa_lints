# Publish Script: Strip "- Unreleased" Suffix from Versioned CHANGELOG Headings

The publish pipeline expected CHANGELOG headings in either `## [Unreleased]` or clean `## [X.Y.Z]` form. A hybrid like `## [15.1.0] - Unreleased` — commonly written during development — fell through both detection and rename paths, leaving the suffix in the published heading or causing `has_unreleased_section()` to return `False` when unreleased content existed.

## Changes

### `scripts/modules/_version_changelog.py`

- Added `_UNRELEASED_SUFFIX_PAT` — a regex pattern fragment matching ` - Unreleased` and common typos (case-insensitive, covers "Unreleasted" etc.).
- Added `_strip_unreleased_suffix(content)` — rewrites versioned headings with the suffix to clean `## [X.Y.Z]` form (line-anchored, `MULTILINE`).
- `has_unreleased_section()` now also detects versioned headings carrying the suffix, in addition to the pure `## [Unreleased]` form.
- `rename_unreleased_to_version()` strips the suffix before processing. Uses a single `original` variable instead of re-reading the file from disk to detect changes.
- `_promote_top_section_to_version()` strips the suffix before matching, preventing the suffix from surviving in the renamed heading. Same redundant-re-read fix applied.

### Tests

- `test_unreleased_prose_mention.py` — 5 new tests in `TestVersionedUnreleasedSuffix`: detection (2), suffix stripping during rename (2, including version-mismatch assertion), case insensitivity (1).
- `test_tag_clash_promotion.py` — 2 new tests: suffix stripping during tag-clash promotion and typo variant handling.

## Finish Report (2026-08-16)

The `_UNRELEASED_SUFFIX_PAT` pattern uses `unreleas\w*` which is intentionally broad to catch typos. The pattern is a plain string constant (not `re.compile`) because every call site embeds it in a larger regex with its own flags.

The `_strip_unreleased_suffix` function operates on the entire file content (not scoped to the top heading), which is acceptable because it only matches line-leading `## [...]` headings — prose mentions in backtick code-spans do not start the line.

When `rename_unreleased_to_version` encounters a versioned heading like `## [15.1.0] - Unreleased` and the publish target is a *different* version (e.g. `15.2.0`), it strips the suffix and returns `True` but does NOT rename the heading to the target version. The version mismatch is resolved downstream by `reconcile_pubspec_changelog_versions`, which is the designated handler for pubspec/CHANGELOG version disagreements.
