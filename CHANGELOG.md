# Changelog

All notable changes to this project will be documented in this file.
The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).
Dates are not included in version headers — [pub.dev](https://pub.dev/packages/saropa_lints/changelog) displays publish dates separately.

> **Looking for older changes?** \
> See [CHANGELOG_ARCHIVE.md](https://github.com/saropa/saropa_lints/blob/main/CHANGELOG_ARCHIVE.md) for versions 0.1.0 through 4.15.1.

** See the current published changelog: [saropa_lints/changelog](https://pub.dev/packages/saropa_lints/changelog)

---
## [5.0.0-beta.9]

### Fixed
- Plugin silently ignored by `dart analyze` — generated `analysis_options.yaml` was missing the required `version:` key under `plugins: saropa_lints:`; the Dart SDK's plugin loader returns `null` when no version/path constraint is present, causing zero lint issues to be reported
- Analysis server crash loop (FormatException) — `ProgressTracker` was writing ANSI progress bars to `stdout`, which corrupts the JSON-RPC protocol used by the analysis server; all output now routes through `stderr`

### Added
- Pre-flight validation checks in `init`: verifies pubspec dependency, Dart SDK >= 3.6, and audits existing config for stale `custom_lint:` sections or missing `version:` keys
- Post-write validation: confirms the generated file has `plugins:`, `version:`, `diagnostics:` sections and expected rule count
- Analysis results now captured in the init log file (previously only shown on terminal)
- Log summary section with version, tier, rule counts, and collected warnings

### Changed
- `dart analyze` output is now captured and streamed (was `inheritStdio` with no capture)
- Log file write deferred until after analysis completes so the report includes everything
- All tier YAML files now include `version: "^5.0.0-beta.8"` for direct-include users
- All report-generating scripts now write to `reports/YYYYMMDD/` date subfolders with timestamped filenames (todo audit, full audit, lint candidates, rule versions)

### Archive

- Rules 4.15.1 and older moved to [CHANGELOG_ARCHIVE.md](https://github.com/saropa/saropa_lints/blob/main/CHANGELOG_ARCHIVE.md)

---
## [5.0.0-beta.8]

### Changed
- Version bump

---
## [5.0.0-beta.7]

### Added
- Init log file now includes a detailed rule-by-rule report listing every rule with its status, severity, tier, and any override/filter notes

### Changed
- Report files now write into `reports/YYYYMMDD/` date subfolders instead of flat in `reports/` — reduces clutter when many reports accumulate
- `--tier` / `--output` flags without a value now warn instead of silently using defaults
- `dart run saropa_lints:init` without `--tier` now prompts for interactive tier selection (was silently defaulting to comprehensive)

### Fixed
- `.pubignore` pattern `test/` was excluding `lib/src/fixes/test/` from published package — anchored to `/test/` so only the root test directory is excluded; this caused `dart run saropa_lints:init` to fail with a missing import error for `replace_expect_with_expect_later_fix.dart`
- Publish script `dart format` step failed on fixture files using future language features (extension types, digit separators, non-ASCII identifiers) — now tolerates exit code 65 when all unparseable files are in example fixture directories

---
## [5.0.0-beta.6]

### Added
- Quick fix for `require_subscription_status_check` — inserts TODO reminder to verify subscription status in build methods
- `getLineIndent()` utility on `SaropaFixProducer` base class for consistent indentation in fix output

### Changed
- Moved generated export folders (`dart_code_exports/`, `dart_sdk_exports/`, `flutter_sdk_exports/`) and report caches from `scripts/` to `reports/` — scripts now write output to the gitignored `reports/` directory, keeping `scripts/` clean
- Filled TODO placeholders in 745 fixture files across all example directories — core and async fixtures now have real bad/good triggering code; widget, package, and platform fixtures have NOTE placeholders documenting rule requirements
- Expanded ROADMAP task backlog with 138 detailed implementation specs
- Deduplicated `_getIndent` from 5 fix files into shared `SaropaFixProducer.getLineIndent()`

### Fixed
- Audit script `get_rules_with_corrections()` now handles variable-referenced rule names (e.g. `LintCode(_name, ...)`) — previously undercounted correction messages by 1 (`no_empty_block`)
- OWASP M2 coverage now correctly reported as 10/10 — audit scanner regex updated to match both single-line and dart-formatted multiline `OwaspMapping` getters; `avoid_dynamic_code_loading` and `avoid_unverified_native_library` (M2), `avoid_hardcoded_signing_config` (M7), and `avoid_sudo_shell_commands` (M1) were previously invisible to the scanner
- Completed test fixtures for `avoid_unverified_native_library` and `avoid_sudo_shell_commands` (previously empty stubs)
- Removed 4 dead references to unimplemented rule classes from registration and tier files (`require_ios_platform_check`, `avoid_ios_background_fetch_abuse`, `require_method_channel_error_handling`, `require_universal_link_validation`) — tracked as `bugs/todo_001` through `todo_004`

---
## [5.0.0-beta.5]

### Added
- Auto-migration from v4 (custom_lint) to v5 (native plugin) — `dart run saropa_lints:init` auto-detects and converts v4 config, with `--fix-ignores` for ignore comment conversion
- Plugin reads `diagnostics:` section from `analysis_options.yaml` to determine which rules are enabled/disabled — previously the generated config was not consumed by the plugin
- Registration-time rule filtering — disabled rules are never registered with the analyzer, improving startup performance

### Fixed
- Plugin now respects rule enable/disable config from `dart run saropa_lints:init` — previously all rules were registered unconditionally regardless of tier selection
- V4 migration no longer imports all rule settings as overrides — only settings that differ from the selected v5 tier defaults are preserved, preventing mass rule disablement
- Init script scans and auto-fixes broken ignore comments — detects trailing explanations (`// ignore: rule // reason` or `// ignore: rule - reason`) that silently break suppression, and moves the text to the line above
- Quick fix support for 108 rules via native `SaropaFixProducer` system — enables IDE lightbulb fixes and `dart fix --apply`
- 3 reusable fix base classes: `InsertTextFix`, `ReplaceNodeFix`, `DeleteNodeFix` in `lib/src/fixes/common/`
- 108 individual fix implementation files in `lib/src/fixes/<category>/`, all with real implementations (zero TODO placeholders)
- Test coverage for all 95 rule categories (Phase 1-3): every category now has a dedicated `test/*_rules_test.dart` file with fixture verification and semantic test stubs
- 506 missing fixture stubs across all example directories (Phase 1-4)
- 12 new package fixture directories: flutter_hooks, workmanager, supabase, qr_scanner, get_it, geolocator, flame, sqflite, graphql, firebase, riverpod, url_launcher

### Changed
- PERFORMANCE.md rewritten for v5 native plugin architecture — replaced all custom_lint references with `dart analyze`, updated rule counts, documented lazy rule instantiation and compile-time constant tier sets, added rule deferral info

### Fixed
- Test fixture paths for bloc, firebase, riverpod, provider, and url_launcher now point to individual category directories instead of shared `packages/` directory
- Platform fixture paths reorganized from shared `platforms/` directory to per-platform directories (`ios/`, `macos/`, `android/`, `web/`, `linux/`, `windows/`) — fixes 0% coverage report for all platform categories
- Coverage script fallback search for fixture files in subdirectories, with prefix-match anchoring and OS error handling

---
## [5.0.0-beta.4]

### Fixed
- Untrack `.github/copilot-instructions.md` — was gitignored but tracked, causing `dart pub publish --dry-run` to exit 65 (warning)
- Publish workflow dry-run step now tolerates warnings (exit 65) but still fails on errors (exit 66)
- Publish script now waits for GitHub Actions workflow to complete and reports real success/failure — previously printed "PUBLISHED" immediately without checking CI status

---
## [5.0.0-beta.3]

### Fixed
- Add `analyzer` as explicit dependency — `dart pub publish` rejected transitive-only imports, causing silent publish failure
- Remove `|| [ $? -eq 65 ]` from publish workflow — was silently swallowing publish failures

---
## [5.0.0-beta.2]

### Fixed
- Publish script regex patterns updated for v5 positional `LintCode` constructor — tier integrity, audit checks, OWASP coverage, prefix validation, and correction message stats now match both v5 positional and v4 named parameter formats
- Publish script version utilities now support pre-release versions (`5.0.0-beta.1` → `5.0.0-beta.2`) — version parsing, comparison, pubspec read/write, changelog extraction, and input validation all handle `-suffix.N` format

---
## [5.0.0-beta.1] — Native Plugin Migration

Migrated from `custom_lint_builder` to the native `analysis_server_plugin` system. This is a **breaking change** for consumers (v4 → v5).

**Why this matters:**
- **Quick fixes now work in IDE** — the old analyzer_plugin protocol never forwarded fix requests to custom_lint plugins (Dart SDK #61491). The native system delivers fixes properly.
- **Per-file filtering is enforced** — 425+ uses of `applicableFileTypes`, `requiredPatterns`, `requiresWidgets`, etc. were defined but never checked. Now enforced via `SaropaContext._wrapCallback()`, cached per file.
- **Future-proof** — the old `analyzer_plugin` protocol is being deprecated (Dart SDK #62164). custom_lint was the primary client.
- **~18K lines removed** — native API eliminates boilerplate (no more `CustomLintResolver`/`ErrorReporter`/`CustomLintContext` parameter triples).

### Added
- Native plugin entry point (`lib/main.dart`) with `SaropaLintsPlugin`
- `SaropaFixProducer` base class for quick fixes (`analysis_server_plugin`)
- `fixGenerators` getter on `SaropaLintRule` for automatic fix registration
- `SaropaContext` with per-file filtering wrapper on all 83 `addXxx()` methods
- `CompatVisitor` bridging callbacks to native `SimpleAstVisitor` dispatch
- PoC quick fixes: `CommentOutDebugPrintFix`, `RemoveEmptySetStateFix`
- Native framework provides ignore-comment fixes automatically (no custom code needed)
- Config loader (`config_loader.dart`) reads `analysis_options_custom.yaml` at startup
- Severity overrides via `severities:` section (ERROR/WARNING/INFO/false per rule)
- Baseline suppression wired into reporter — checks `BaselineManager` before every report
- Impact tracking — every violation recorded in `ImpactTracker` by impact level
- Progress tracking — files and violations tracked in `ProgressTracker` per file/rule
- `Plugin.start()` lifecycle hook for one-time config loading
- Tier preset YAML files updated to native `plugins: saropa_lints: diagnostics:` format
- Migration guide (`MIGRATION_V5.md`) for v4 to v5 upgrade

### Changed
- `bin/init.dart` generates native `plugins:` format (was `custom_lint:`)
- Tier presets use `diagnostics:` map entries (was `rules:` list entries)
- Init command runs `dart analyze` after generation (was `dart run custom_lint`)
- All 96 rule files migrated to native `AnalysisRule` API
- `SaropaLintRule` now extends `AnalysisRule` (was `DartLintRule`)
- `LintCode` uses positional constructor: `LintCode('name', 'message')` (was named params)
- `runWithReporter` drops `CustomLintResolver` parameter
- `context.addXxx()` replaces `context.registry.addXxx()`
- `reporter.atNode(node)` replaces `reporter.atNode(node, code)` (code is implicit)
- Dependencies: `analysis_server_plugin: ^0.3.3` replaces `custom_lint_builder`
- README updated for v5: `dart analyze` replaces `dart run custom_lint`, tier preset includes, v4 migration FAQ

### Removed
- `custom_lint_builder` dependency and `lib/custom_lint_client.dart`
- Redundant PoC files (`saropa_analysis_rule.dart`, `poc_rules.dart`, `saropa_reporter.dart`)
- Old v4 ignore-fix classes — superseded by native framework

---

## [4.15.1] and Earlier

For details on the initial release and versions 0.1.0 through 4.15.1, please refer to [CHANGELOG_ARCHIVE.md](https://github.com/saropa/saropa_lints/blob/main/CHANGELOG_ARCHIVE.md).
