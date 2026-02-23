# Changelog

All notable changes to this project will be documented in this file.
The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).
Dates are not included in version headers — [pub.dev](https://pub.dev/packages/saropa_lints/changelog) displays publish dates separately.

> **Looking for older changes?** \
> See [CHANGELOG_ARCHIVE.md](https://github.com/saropa/saropa_lints/blob/main/CHANGELOG_ARCHIVE.md) for versions 0.1.0 through 4.15.1.

** See the current published changelog: [saropa_lints/changelog](https://pub.dev/packages/saropa_lints/changelog)

---
## [Unreleased]

### Added
- Quick fixes for 5 blank-line formatting rules: `prefer_blank_line_before_case`, `prefer_blank_line_before_constructor`, `prefer_blank_line_before_method`, `prefer_blank_line_after_declarations`, `prefer_blank_lines_between_members`

### Fixed
- `prefer_static_class`: no longer fires on `abstract final class` declarations (regression from beta.15 fix)
- `avoid_hardcoded_locale`: skip locale-pattern strings inside collection literals (Set, List, Map lookup data)
- `avoid_datetime_comparison_without_precision`: skip comparisons against compile-time constants (e.g., epoch sentinel checks)
- `avoid_unsafe_collection_methods`: strengthen guard detection with source-text fallback for length/isNotEmpty checks
- `avoid_medium_length_files`: exempt files containing only `abstract final` utility namespace classes
- `prefer_single_declaration_per_file`: exempt files where all classes are `abstract final` static-only namespaces
- `prefer_no_continue_statement`: exempt early-skip guard pattern (`if (cond) { continue; }` at top of loop body)

### Changed
- `avoid_high_cyclomatic_complexity`: raise threshold from 10 to 15 to align with industry standards (SonarQube, ESLint)

---
## [5.0.0-beta.15]

### Added
- `avoid_cached_image_web`: warns when CachedNetworkImage is used inside a `kIsWeb` branch where it provides no caching benefit (Recommended tier)
- `avoid_clip_during_animation`: warns when Clip widgets are nested inside animated widgets, causing expensive per-frame rasterization (Professional tier)
- `avoid_auto_route_context_navigation`: warns when string-based `context.push`/`context.go` is used in auto_route projects instead of typed routes (Professional tier)
- `avoid_auto_route_keep_history_misuse`: warns when `replaceAll`/`popUntilRoot` is used outside authentication flows, destroying navigation history (Professional tier)
- `avoid_accessing_other_classes_private_members`: warns when code accesses another class's private members through same-file library privacy (Professional tier)
- `avoid_closure_capture_leaks`: warns when `setState` is called inside Timer/Future.delayed callbacks without a `mounted` check (Professional tier, quick fix)
- `avoid_behavior_subject_last_value`: warns when `.value` is accessed on a BehaviorSubject inside an `isClosed` true-branch (Professional tier)
- `avoid_cache_stampede`: warns when async methods use a Map cache without in-flight request deduplication (Professional tier)
- `avoid_deep_nesting`: warns when code blocks are nested more than 5 levels deep (Professional tier)
- `avoid_high_cyclomatic_complexity`: warns when functions exceed cyclomatic complexity of 10 (Professional tier)
- `avoid_void_async`: warns when async functions return `void` instead of `Future<void>` (Recommended tier)
- `avoid_redundant_await`: warns when `await` is used on a non-Future expression (Recommended tier)
- `avoid_unused_constructor_parameters`: warns when constructor parameters are not stored or used (Recommended tier)
- `avoid_returning_null_for_void`: warns when `return null` is used in void functions (Recommended tier)
- `avoid_returning_null_for_future`: warns when `null` is returned from non-async Future functions (Recommended tier)
- `avoid_shadowing_type_parameters`: warns when method type parameters shadow class type parameters (Recommended tier)
- `avoid_redundant_null_check`: warns when non-nullable values are compared to null (Recommended tier)
- `avoid_collection_mutating_methods`: warns when collections are mutated in-place inside setState (Professional tier)
- `avoid_equatable_nested_equality`: warns when mutable collections are included in Equatable props (Professional tier)
- `avoid_getx_rx_nested_obs`: warns when GetX Rx observables are nested (Professional tier)
- `avoid_freezed_any_map_issue`: warns when @freezed class with fromJson lacks @JsonSerializable(anyMap: true) (Professional tier)
- `avoid_hive_datetime_local`: warns when DateTime is stored in Hive without UTC conversion (Professional tier)
- `avoid_hive_type_modification`: warns when @HiveField indices are duplicated (Professional tier)
- `avoid_hive_large_single_entry`: warns when large objects are stored as single Hive entries (Professional tier)
- `require_auto_route_guard_resume`: warns when AutoRouteGuard may not call resolver.next() on all paths (Essential tier)
- `require_auto_route_full_hierarchy`: warns when push() is used instead of navigate() in auto_route (Essential tier)
- `avoid_firebase_user_data_in_auth`: warns when too many custom claims are accessed from Firebase auth tokens (Professional tier)
- `require_firebase_app_check_production`: warns when Firebase is initialized without App Check (Professional tier)

### Fixed
- `avoid_god_class`: false positive on static-constant namespace classes — `static const` and `static final` fields are now excluded from the field count since they represent compile-time constants, not instance state
- `prefer_static_class`: conflicting diagnostic with `prefer_abstract_final_static_class` on classes with private constructors — `prefer_static_class` now defers to `prefer_abstract_final_static_class` when a private constructor is present
- `avoid_similar_names`: false positive on single-character variable pairs (`y`, `m`, `d`, `h`, `s`) — edit distance is always 1 for any two single-char names, which is not meaningful; confusable-char detection (1/l, 0/O) still catches genuinely dangerous cases
- `avoid_unused_assignment`: false positive on definite assignment via if/else branches — assignments in mutually exclusive branches of the same if/else are now recognized as alternatives, not sequential overwrites

---
## [5.0.0-beta.14]

### Fixed
- `avoid_variable_shadowing`: false positive on sequential for/while/do loops reusing the same variable name — loop variables are scoped to their body and don't shadow each other
- `avoid_unused_assignment`: false positive on conditional reassignment (`x = x.toLowerCase()` inside if-blocks) — now skips loop-body assignments, may-overwrite conditionals, and self-referencing RHS
- `prefer_switch_expression`: false positive on switch cases containing control flow (`if`/`for`/`while`) or multiple statements — also detects non-exhaustive switches with post-switch code
- `no_magic_number`: false positive on numeric literals used as default parameter values — the parameter name provides context, making the number self-documenting
- `avoid_unnecessary_to_list` / `avoid_large_list_copy`: false positive when `.toList()` is required by return type, method chain, expression function body, or argument position
- `prefer_named_boolean_parameters`: false positive on lambda/closure parameters — their signature is constrained by the expected function type
- `avoid_unnecessary_nullable_return_type`: false positive on ternary expressions with null branches, map `[]` operator, and nullable method delegation — now checks static type nullability recursively
- `avoid_duplicate_string_literals` / `avoid_duplicate_string_literals_pair`: false positive on domain-inherent literals (`'true'`, `'false'`, `'null'`, `'none'`) that are self-documenting
- `avoid_excessive_expressions`: false positive on guard clauses (early-return if-statements) and symmetric structural patterns — guard clauses now allowed up to 10 operators, symmetric repeating patterns are exempt
- `prefer_digit_separators`: false positive on 5-digit numbers — threshold raised from 10,000 to 100,000 (6+ digits) to match common style guide recommendations
- `require_list_preallocate`: false positive when `List.add()` is inside a conditional branch within a loop — preallocation is impossible when the number of additions is data-dependent

---
## [5.0.0-beta.13]

### Fixed
- `prefer_match_file_name`: false positive on Windows — backslash paths caused file name extraction to fail, reporting every correctly-named class
- `prefer_match_file_name`: false positive when file has multiple public classes — second class was reported even when first class matched
- `avoid_unnecessary_nullable_return_type`: false positive on expression-bodied functions — ternaries with null branches, map lookups, and other nullable expressions were not recognized
- `prefer_unique_test_names`: false positives when same test name appears in different `group()` blocks — now builds fully-qualified names from group hierarchy, matching Flutter's test runner behavior
- `avoid_dynamic_type`: false positives for `Map<String, dynamic>` — the canonical Dart JSON type is now exempt
- `no_magic_number_in_tests`: expanded allowed integers to include 6–31 (day/month numbers), common round numbers (10000, 100000, 1000000), and exemptions for DateTime constructor arguments and expect() calls
- `no_magic_string_in_tests`: false positives for test fixture data — strings passed as arguments to functions under test and strings in expect() calls are now exempt
- `avoid_large_list_copy`: false positives for required copies — `List<T>.from()` with explicit type arguments (type-casting pattern) is now exempt; `.toList()` is exempt when returned, assigned, or otherwise structurally required

### Changed
- Merged duplicate rule `prefer_sorted_members` into `prefer_member_ordering`; `prefer_sorted_members` continues to work as a config alias
- Clarified correction messages for `prefer_boolean_prefixes`, `prefer_descriptive_bool_names`, and `prefer_descriptive_bool_names_strict` to distinguish scope (fields-only vs all booleans)

### Publishing
- Publish audit: consolidated quality checks into a single pass/warn/fail list instead of separate subsections per check
- Publish audit: US English spelling check displayed as a simple bullet instead of a standalone subsection
- Publish audit: bug reports grouped by status (done, in progress, unsolved) with scaled bars per group
- Publish audit: test coverage columns dynamically aligned to longest category name
- Init: "what's new" summary now shows all items (no `+N more` or section truncation) — only individual lines are truncated at 78 chars
- Init: tier default changed from `comprehensive` to `essential` for fresh setups; re-runs default to the previously selected tier
- Init: stale config version warning now tells the user how to fix it (`re-run "dart run saropa_lints" to update`)
- Init: stylistic walkthrough shows per-rule progress counter (`4/120 — 3%`) and `[quick fix]` indicator for rules with IDE auto-fixes
- Init: stylistic walkthrough rule descriptions rendered in default terminal color instead of dim gray for readability
---
## [5.0.0-beta.12]

### Added
- Init: interactive stylistic rule walkthrough — shows code examples and lets users enable/disable each rule individually with y/n/skip/abort support and resume via `[reviewed]` markers
- Init: `--stylistic-all` flag for bulk-enabling all stylistic rules (replaces old `--stylistic` behavior); `--no-stylistic` to skip walkthrough; `--reset-stylistic` to clear reviewed markers
- Init: auto-detect project type from pubspec.yaml — Flutter widget rules are skipped for pure Dart projects, package-specific rules filtered by dependencies
- `SaropaLintRule`: `exampleBad`/`exampleGood` properties for concise terminal-friendly code snippets (40 rules covered)
- `tiers.dart`: `flutterStylisticRules` set for widget-specific stylistic rules filtered by platform
- Init: "what's new" summary shown during `dart run saropa_lints:init`, with line truncation and a link to the full changelog
- New rule: `prefer_sorted_imports` (Comprehensive) — detects unsorted imports within each group (dart, package, relative) with quick fix to sort A-Z
- New rule: `prefer_import_group_comments` (Stylistic) — detects missing `///` section headers between import groups with quick fix to add them
- New rule: `avoid_asset_manifest_json` (Essential) — detects usage of removed `AssetManifest.json` path (Flutter 3.38.0); runtime crash since the file no longer exists in built bundles
- New rule: `prefer_dropdown_initial_value` (Recommended) — detects deprecated `value` parameter on `DropdownButtonFormField`, suggests `initialValue` (Flutter 3.35.0) with quick fix
- New rule: `prefer_on_pop_with_result` (Recommended) — detects deprecated `onPop` callback on routes, suggests `onPopWithResult` (Flutter 3.35.0) with quick fix

### Fixed
- `no_empty_string`: only flag empty strings in equality comparisons (`== ''`, `!= ''`) where `.isEmpty`/`.isNotEmpty` is a viable alternative — skip return values, default params, null-coalescing, replacement args
- `prefer_cached_getter`: skip methods inside extensions and extension types (cannot have instance fields) and static methods (cannot cache to instance fields)
- `prefer_compute_for_heavy_work`: only flag encode/decode/compress calls inside widget lifecycle methods (`build`, `initState`, etc.) — library utility methods have no UI thread to protect
- `prefer_keep_alive`: check for `TabBarView`/`PageView` identifiers instead of naive `contains('Tab')`/`contains('Page')` substring matching
- `prefer_prefixed_global_constants`: case-insensitive descriptive pattern check for lowerCamelCase constants; expand pattern list (width, height, padding, etc.); narrow threshold to only flag names < 5 chars
- `prefer_secure_random`: only flag `Random()` in security-related contexts (variable/method names containing token, password, encrypt, etc.); skip `.shuffle()` usage and literal-seeded constructors
- `prefer_static_method`: skip methods inside extensions and extension types (cannot be made static in Dart)
- `require_currency_code_with_amount`: split into strong (price, amount, cost, fee) and weak (total, balance, rate) monetary signals; weak signals require 2+ matches with double/Decimal type; skip non-monetary class names (stats, count, metric, score, etc.)
- `require_dispose_pattern`: skip classes with `const` constructors (hold borrowed references, not owned resources)
- `require_envied_obfuscation`: skip class-level `@Envied` warning when all `@EnviedField` annotations explicitly specify `obfuscate`
- `require_https_only_test`: skip HTTP URLs inside test infrastructure calls (`test()`, `expect()`, `group()`, etc.) since URL utility tests must exercise HTTP
- `require_ios_callkit_integration`: replace brand name string matching (Agora, Twilio, Vonage, WebRTC) with import-based detection for 13 VoIP packages; keep only unambiguous technical terms for string matching
- `avoid_barrel_files`: skip files with `library` directive and the mandatory package entry point (`lib/<package_name>.dart`)
- `avoid_duplicate_number_elements`: only flag `Set` literals — duplicate numeric values in `List` literals are intentional (e.g. days-in-month)
- `avoid_ignoring_return_values`: skip property setter assignments (`obj.prop = value`) which have no return value
- `avoid_money_arithmetic_on_double`: use camelCase word-boundary matching instead of substring matching to avoid false positives on `totalWidth`, `frameRate`, etc.
- `avoid_non_ascii_symbols`: narrow from all non-ASCII to invisible/confusable characters only (zero-width, invisible formatters, non-standard whitespace)
- `avoid_static_state`: skip `static const` and `static final` with known-immutable types (`RegExp`, `DateTime`, etc.); retain detection of `static final` mutable collections
- `avoid_stream_subscription_in_field`: skip `.listen()` calls whose return value is passed as an argument (e.g. `subs.add(stream.listen(...))`)
- `avoid_string_concatenation_l10n`: skip numeric-only interpolated strings (e.g. `'$a / $b'`) that contain no translatable word content
- `avoid_unmarked_public_class`: skip classes where all constructors are private (extension already prevented)

### Package Publishing Changes
- Publish audit: added 3 new blocking checks — `flutterStylisticRules` subset validation, `packageRuleSets` tier consistency, `exampleBad`/`exampleGood` pairing
- Publish audit: doc comment auto-fix (angle brackets, references) now runs during audit step instead of only during analysis step

---
## [5.0.0-beta.11]

### Changed
- CLI defaults to `init` command when run without arguments (`dart run saropa_lints` now equivalent to `dart run saropa_lints init`)
- Publish script: `dart format` now targets specific top-level paths, excluding `example*/` directories upfront instead of tolerating exit-code 65 after the fact
- Publish script: roadmap summary now includes color-coded bug report breakdown (unsolved/categorized/resolved) from sibling `saropa_dart_utils/bugs/` directory
- Deferred `avoid_misused_hooks` rule removed from ROADMAP_DEFERRED (hook rules vary by context — not viable as static lint)

---
## [5.0.0-beta.10]

### Fixed
- Init: `_stylisticRuleCategories` synced with `tiers.stylisticRules` — removed obsolete `prefer_async_only_when_awaiting`, added ~40 rules to proper categories instead of "Other stylistic rules" catch-all
- Init: obsolete stylistic rules in consumer `analysis_options_custom.yaml` are now cleaned up during rebuild, with warnings for user-enabled rules being dropped
- Init: stylistic rules redundantly placed in RULE OVERRIDES section are detected — interactive prompt offers to move them to the STYLISTIC RULES section
- Init: `_buildStylisticSection()` now filters against `tiers.stylisticRules` to prevent future category/tier desyncs
- `dart analyze` exit codes 1-2 (issues found) no longer reported as "failed" — only exit code 3+ (analyzer error) is treated as failure
- Progress bar stuck at ~83% — recalibration threshold no longer inflates expected file count when discovery overcounts
- Progress bar now shows 100% completion before the summary box
- Publish script: restored post-publish version bump (pubspec + `[Unreleased]` section) — accidentally removed in v4.9.17 refactor
- Publish script: optional `_offer_custom_lint` prompt no longer blocks success status or timing summary on interrupt

### Changed
- Init log (`*_saropa_lints_init.log`) now contains only setup/configuration data; raw `dart analyze` output is no longer mixed in — the plugin's report (`*_saropa_lint_report.log`) covers analysis results
- Init log written before analysis prompt so the path is available upfront
- Plugin report path displayed after analysis completes (with retry for async flush)
- Old report files in `reports/` root are automatically migrated to `reports/YYYYMMDD/` date subfolders during init
- Stream drain and exit code now awaited together via `Future.wait` to prevent interleaved output
- Persistent cache files (`rule_version_cache.json`, export directories) moved from `reports/` root to `reports/_cache/` subfolder

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
