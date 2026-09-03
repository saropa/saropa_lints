# Migration Pack Generator & Hardening

Built an automated code-generation pipeline for migration pack rule sets and fixed 6 migration packs whose code sets had silently drifted from their source guides.

## Finish Report (2026-09-02)

### Problem

`lib/src/config/rule_pack_migration_codes.dart` was hand-maintained — each migration pack's `Set<String>` of saropa rule codes was manually transcribed from its migration guide's HAVE/ENHANCED table. Nothing enforced consistency between the two. Four packs had drifted (missing codes, spurious codes, typos), and five guides referenced phantom rule codes (a Dart class name or a nonexistent rule) that silently matched nothing.

### Changes

**Generator pipeline** (`tool/generate_migration_pack_codes.dart`, `tool/migration_pack_guide_sync.dart`):
- Reads every migration guide's HAVE/ENHANCED table rows, extracts saropa rule codes, validates them against `lib/src/tiers.dart`, and writes the complete `rule_pack_migration_codes.dart`.
- `migration_pack_guide_sync.dart` is the shared parsing library imported by both the generator and the drift test — guide-file map, row regex, coverage-line parser, repo-root finder, and block extractors all live here so the two tools can never disagree about how to read a guide.
- `flutter_skill_lints` (no guide table) is carried forward from the previous generated file but validated against tiers.dart on each run.
- `kRulePackMigrationPubspecMarkers` (pub.dev package names) is carried forward verbatim since it isn't guide content.
- Validation skips comment lines in tiers.dart to prevent commented-out rule names from false-passing.

**Drift-detection test** (`test/config/rule_packs_migration_guide_sync_test.dart`, 25 cases):
- Re-derives each pack's expected code set from its guide and diffs against the actual pack.
- `flutter_skill_lints` uses arithmetic (total - GAP - PARTIAL - dedup) with a shared `kFlutterSkillLintsDedupDelta` constant.

**Guide fixes** (6 guides, 6 rule references):
- `NewlineBeforeReturnRule` → `prefer_blank_line_before_return` in dcm, dart_code_linter, pyramid_lint, mad_lint guides.
- `avoid_magic_numbers` → `no_magic_number` in solid_lints guide.
- `prefer_returning_shorthands` → `prefer_arrow_functions` in many_lints guide (rule was removed, merged into prefer_arrow_functions).

**Pack drift fixes** (5 packs):
- `migrate_dcm`: 9 missing codes + 1 typo'd phantom removed.
- `migrate_dart_code_metrics_presets`: 1 missing code added.
- `migrate_dart_code_linter`: 1 spurious code removed.
- `migrate_awesome_lints`: 4 spurious codes removed.
- `migrate_many_lints`: `prefer_returning_shorthands` (removed rule) replaced with `prefer_arrow_functions`.

### Verification

- `dart test test/config/rule_packs_migration_guide_sync_test.dart` — 25/25 pass.
- `dart test test/config/rule_packs_migration_membership_test.dart test/config/rule_packs_pubspec_markers_test.dart test/config/rule_packs_config_test.dart test/config/rule_pack_registry_test.dart` — 24/24 pass.
- Generator is idempotent: re-running produces byte-identical output.
- `dart format --set-exit-if-changed` clean on all touched Dart files.
- All file lengths ≤200 lines, all functions ≤50 lines.

### Hardening (post-review)

- Decomposed `main()` into `_buildPackEntries`, `_assembleSource`, `_formatSource`, and moved `_buildComment`, `_findRepoRoot`, `_allQuotedIdentifiers`, `_extractBlock`, `_extractPackCodes` to `migration_pack_guide_sync.dart` as public functions — generator file is now 199 lines (under 200 cap).
- Fixed `activeQuotedIdentifiers` (renamed from `_allQuotedIdentifiers`) to filter out `//` comment lines before matching, preventing commented-out rule names from false-passing validation. This immediately caught `prefer_returning_shorthands` — a removed rule only appearing in a tiers.dart comment — referenced by the `many_lints` guide.
- Added `kFlutterSkillLintsDedupDelta` shared constant so the generator and drift test can't silently disagree on the dedup count.
- Removed dead `_haveRowPattern` regex that was hoisted but never used (the real pattern is built dynamically in `codesFromGuideTable`).
- Added `--check` mode: `dart run tool/generate_migration_pack_codes.dart -- --check` exits non-zero if the pack file would change, suitable for CI enforcement.
- Documented migration pack generator steps in `doc/guides/rule_packs.md`.

### Hardening Round 2 (2026-09-03)

- `extractBlock` rewritten to use balanced brace counting instead of `\n};` string search — handles nested map/set literals correctly.
- `extractPackCodes` likewise switched from `\n  },` end marker to balanced brace counting.
- `activeQuotedIdentifiers` now strips `/* ... */` block comments (dotAll regex) in addition to `//` line comments.
- `.dart_tool/` temp directory created with `createSync(recursive: true)` before writing the format temp file — no longer fails on fresh checkouts where `.dart_tool/` doesn't exist yet.
- Diff output integrated into both normal and `--check` modes: normal run prints `+ added_code` / `- removed_code` per pack after regenerating; `--check` prints drifted codes before the re-run instruction. Not a separate flag — always shown when there are changes.
- `diffPackEntries()` added to `migration_pack_guide_sync.dart` as the shared diff engine.
- `_reportCheckResult()` extracted from `main()` to keep function length under 50 lines.

### Known Limitations

- `flutter_skill_lints`'s 229 codes are validated per-code against tiers.dart (catches renames/removals) but cannot be re-derived from the guide. A removed code replaced by a different code at the same count would pass the count-only drift test.
- `kFlutterSkillLintsDedupDelta = 2` must be updated manually if a third dedup collision appears.
- `activeQuotedIdentifiers` uses a greedy dotAll regex for block comments (`/\*.*?\*/`) — correctly handles non-greedy matching but would break on pathological nested `/* /* */ */` (Dart doesn't support nested block comments, so this is safe).
- `dart format` determinism across SDK versions is assumed — the generated file is formatted with whatever SDK is on PATH.
