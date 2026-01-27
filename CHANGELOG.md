# Changelog

All notable changes to this project will be documented in this file.
The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

> **Looking for older changes?** \
> See [CHANGELOG_ARCHIVE.md](./CHANGELOG_ARCHIVE.md) for versions 0.1.0 through 4.2.0.

---
## [4.8.5] - 2026-01-27 (Unreleased)

### Added

- **`TestRelevance` enum**: New three-value enum (`never`, `always`, `testOnly`) for granular control over whether lint rules run on test files. Rules can now declare their test file relationship explicitly instead of using a boolean flag.

### Changed

- **Rules now skip test files by default**: The default `testRelevance` is `TestRelevance.never`, meaning ~1600 production-focused rules no longer fire on test files. This eliminates thousands of irrelevant violations (e.g., `prefer_matcher_over_equals`, `move_variable_closer_to_its_usage`, `no_empty_string`) that were flooding test code. Rules that should run on tests can override `testRelevance => TestRelevance.always`.
- **Backwards-compatible auto-detection**: Rules using `applicableFileTypes => {FileType.test}` are automatically treated as `TestRelevance.testOnly` with no code changes required.

### Deprecated

- **`skipTestFiles` getter**: Replaced by `testRelevance`. The old boolean getter still compiles but is marked `@Deprecated`. Migration: `skipTestFiles => true` is now the default; `skipTestFiles => false` becomes `testRelevance => TestRelevance.always`.

---
## [4.8.4] - 2026-01-27

### Added

- **Test coverage top offenders report**: The publish workflow's test coverage summary now lists the 10 worst categories ranked by untested rule count, color-coded by severity.
- **File health top offenders**: The "Files needing quick fixes" audit section now lists the top 5 worst files sorted by fix coverage, showing fixes/rules and percentage.
- **Doc reference auto-fix in publish pipeline**: The `--fix-docs` flag and Step 6 analysis now detect and auto-fix unresolvable `[reference]` patterns in DartDoc comments (OWASP codes, file names, snake_case rule names) alongside the existing angle bracket fixer.

### Changed

- **Improved DX messages for 58 high-impact rules**: Expanded `problemMessage` and `correctionMessage` text across `navigation_rules`, `notification_rules`, `package_specific_rules`, `performance_rules`, `platform_rules`, `qr_scanner_rules`, `resource_management_rules`, `riverpod_rules`, `scroll_rules`, `security_rules`, and `state_management_rules` to explain user-facing consequences and provide more specific fix guidance. Each problem message now meets the 180-character minimum with clear issue/consequence/impact structure; each correction message meets the 80-character minimum with actionable fix guidance.
- **DX audit: relaxed vague language check for low-impact rules**: The `_audit_dx.py` scoring module no longer penalises advisory phrasing ("consider", "prefer", etc.) in low-impact rules, since suggestive language is appropriate for rules that are informational by nature.

### Fixed

- **20 unresolved doc reference warnings**: Escaped non-symbol references in DartDoc comments (OWASP codes, rule names, Flutter widget names, file names) that `dart doc` could not resolve, eliminating all documentation generation warnings.
- **Publish script commit step**: "No changes to commit" message now shows as success (green) instead of warning (yellow), since it is not an error condition.
- **Publish script Step 9**: Suppressed spurious Windows `nul` path warning in pre-publish validation output.
- **ROADMAP near-match false positives**: `_test` variant rules are now excluded from near-match detection, matching the existing duplicate exclusion logic.

### Removed

- **`doc/flutter_widget_rules_full_table.md`**: Obsolete split-plan document that was no longer referenced.

## [4.8.3] - 2026-01-26

### Added

- **`avoid_dynamic_code_loading`** (Essential, ERROR): Detects runtime code loading via `Isolate.spawnUri()` and package management commands in `Process.run()`/`Process.start()`. OWASP M2 (Supply Chain Security).
- **`avoid_unverified_native_library`** (Essential, ERROR): Detects `DynamicLibrary.open()` with dynamic or absolute paths that bypass package verification. OWASP M2 (Supply Chain Security).
- **`avoid_hardcoded_signing_config`** (Recommended, WARNING): Detects hardcoded keystore paths, signing aliases, and configuration strings extractable from compiled binaries. OWASP M7 (Binary Protections).
- **OWASP Mobile coverage**: 8/10 → 10/10 (100%). Added M2 and M7 coverage; also mapped `avoid_eval_like_patterns` to M7.

### Fixed

- **141 orphan rules restored**: Rules that were implemented but never registered in `_allRuleFactories` or assigned to tiers are now fully active. Includes rules for Bloc, GetX, Isar, Dio, Riverpod, image_picker, permissions, notifications, WebView, and more. Critical-impact rules assigned to recommended tier, high to professional, medium/low to comprehensive.
- **9 GetX rules unhidden**: Removed `hide` directives in `all_rules.dart` that blocked GetX rules from export.
- **3 opinionated rules registered**: `prefer_early_return`, `prefer_mutable_collections`, and `prefer_record_over_equatable` moved from dead code to stylistic tier.
- **`format_comment_style` moved to insanity tier**: Previously in professional tier, now correctly placed as documentation pedantry.
- **Pre-publish audit script bugs fixed**: `_code\s*=` regex now matches variant field names (`_codeField`, `_codeMethod`), eliminating phantom rule false positives. Opinionated prefer_* detection uses class-scoped search instead of backward search, preventing cross-class name resolution errors.

### Changed

- **Improved DX message quality for 25 critical/high-impact lint rules**: Expanded problem messages to clearly explain the detected issue, its real-world consequence, and the user impact. Expanded correction messages with specific, actionable fix guidance. Affected rules span forms, navigation, memory management, images, Riverpod, GetX, lifecycle, Firebase, JSON, and API categories.
- **Critical DX pass rate**: 98.3% → 100% (60/60 rules passing)
- **High DX pass rate**: 34.8% → 42.7% (+23 additional rules passing)
- **Audit scripts refactored**: `_audit.py` split into `_audit_checks.py` (extraction/display) and `_audit_dx.py` (DX quality analysis) for maintainability.

## [4.8.2] - 2026-01-26

### Added

- **`require_https_only_test` rule**: New test-file variant of `require_https_only` at INFO severity (Professional tier). The production rule now skips test files, and the test variant covers them independently so teams can disable HTTP URL linting in tests without affecting production enforcement.
- **`avoid_hardcoded_config_test` rule**: New test-file variant of `avoid_hardcoded_config` at INFO severity (Professional tier). Hardcoded URLs and keys in test files are typically test fixture data; this rule surfaces them at reduced severity for awareness without blocking.
- **`require_deep_link_fallback` test fixture**: Added coverage for lazy-loading getters that use utility class methods (e.g., `_uri ??= UrlUtils.getSecureUri(url)`) to prevent false positives.

### Changed

- **98 opinionated rules moved to stylistic tier**: Rules that are subjective or conflict with each other are now opt-in only via `--stylistic` flag, not enabled by default in any tier. This includes member ordering, argument ordering, naming conventions, and similar stylistic preferences.
- **8 stylistic rules renamed for consistency**: All stylistic rules now use `prefer_` prefix:
  - `always_fail_test_case` → `prefer_fail_test_case`
  - `enforce_member_ordering` → `prefer_member_ordering`
  - `enforce_arguments_ordering` → `prefer_arguments_ordering`
  - `capitalize_comment_start` → `prefer_capitalized_comment_start`
  - `avoid_continue_statement` → `prefer_no_continue_statement`
  - `avoid_getter_prefix` → `prefer_no_getter_prefix`
  - `avoid_commented_out_code` → `prefer_no_commented_out_code`
  - `avoid_inferrable_type_arguments` → `prefer_inferred_type_arguments`
  - Old names preserved as `configAliases` for backwards compatibility.
- **Conflicting member-ordering rules moved to stylistic tier**: `prefer_static_members_first`, `prefer_instance_members_first`, `prefer_public_members_first`, `prefer_private_members_first` now require explicit opt-in since they conflict in pairs.
- **Tier assignment: single source of truth**: `tiers.dart` is now the sole authority for rule tier assignments. Removed the `RuleTier get tier` getter from `SaropaLintRule` and the legacy two-phase fallback in `bin/init.dart`. The init script now reads tier assignments exclusively from `tiers.dart` sets.
- **Unified CLI entry point**: Added `bin/saropa_lints.dart` as a dispatcher supporting `init`, `baseline`, and `impact-report` subcommands.
- **Progress tracking improvements**: `ProgressTracker` now derives project root from the first analyzed file path instead of using `.` (which fails in plugin mode). Shows enabled rule count instead of misleading file percentage.

### Fixed

- **`avoid_context_after_await_in_static` false positives in try-catch**: The rule now recurses into try, catch, and finally blocks instead of skipping the entire `TryStatement`. Mounted guards and ternary patterns inside try-catch are correctly recognized.
- **`avoid_context_across_async` false positives in try-catch**: Same try-catch recursion fix applied to the non-static context rule.
- **`avoid_storing_context` false positives on function type fields**: Fields declaring callback signatures (e.g., `void Function(BuildContext)`) no longer trigger the rule. Only actual `BuildContext` storage is flagged.
- **`avoid_expanded_outside_flex` false positives**: Three scenarios fixed:
  - `Expanded` inside `List.generate()` or `.map()` callbacks within helper methods is now trusted.
  - Expression-body helper methods (e.g., `List<Widget> _items() => [Expanded(...)]`) are now trusted.
  - Top-level `FunctionDeclaration` boundaries are now recognized.
- **`avoid_builder_index_out_of_bounds` false positives with `itemCount`**: Lists whose bounds are guaranteed by `itemCount: list.length` are no longer flagged.
- **`avoid_long_running_isolates` false positive on `Isolate.run`**: `Isolate.run()` is now correctly classified as short-lived (like `compute()`), not as a persistent isolate like `Isolate.spawn()`. Context window expanded from 200 to 500 chars. Added fire-and-forget and never-block awareness keywords.
- **`require_immutable_bloc_state` false positives on non-BLoC classes**: Skip indirect Flutter State subclasses (`PopupMenuItemState`, `FormFieldState`, `AnimatedWidgetBaseState`, `ScrollableState`, `RefreshIndicatorState`) and `StatefulWidget`/`StatelessWidget` subclasses using "State" as a domain term.
- **`require_cache_key_determinism` false positive on metadata parameters**: Common metadata parameter names (`createdAt`, `updatedAt`, `timestamp`, `expiresAt`, `ttl`, etc.) are now excluded from determinism checks. Diagnostics now report at the specific offending argument instead of the entire variable declaration. Extracted shared `_checkArgumentList` helper to reduce duplication.

---
## [4.8.1] - 2026-01-25

### Added

- **`avoid_uncaught_future_errors` quick fix**: New "Add // ignore: comment" quick fix for cases where the called method handles errors internally but is defined in a different file. The rule cannot detect cross-file try-catch, so this fix provides a convenient workaround.

### Changed

- **`avoid_builder_index_out_of_bounds` documentation**: Added note clarifying the rule's limitation with synchronized lists. The rule cannot detect cross-method relationships like `List.generate(otherList.length, ...)`, so explicit bounds checks or ignore comments are recommended for multiple lists of the same length.
- **`avoid_uncaught_future_errors` documentation**: Added "Limitation: Cross-file analysis" section explaining that the rule can only detect try-catch in functions defined in the same file.

### Fixed

- **`require_deep_link_fallback` false positives**: Fixed three false positive scenarios:
  - `return null;` statements now recognized as valid fallback patterns
  - Ternary expressions with null fallback (e.g., `condition ? value : null`) now recognized
  - Methods returning `String?` or `Uri?` are now skipped as they are URL parsers/converters, not deep link handlers

---
## [4.8.0] - 2026-01-25

### Changed

- **Lazy rule loading for reduced memory usage**: Rules are now instantiated on-demand instead of at compile time. Previously, all 1500+ rules were created as a `const List<LintRule>`, consuming ~4GB of memory regardless of which tier was selected. Now only rules needed for the selected tier are created. For essential tier (~250 rules), this reduces memory usage significantly and eliminates OOM crashes on resource-constrained systems.
  - Rule list changed from `const List<LintRule>` to `final List<LintRule Function()>` factories
  - Factory map built lazily on first access
  - No generated files required - stays in sync automatically when rules are added/removed

---
## [4.7.6] - 2026-01-25

### Fixed

- **`require_ios_permission_description` false positive on ImagePicker constructor**: Fixed false positives where the rule required both `NSPhotoLibraryUsageDescription` AND `NSCameraUsageDescription` when only `ImagePicker()` was instantiated, before any method was called. The rule now uses smart method-level detection:
  - `ImagePicker()` constructor alone → no warning
  - `picker.pickImage(source: ImageSource.gallery)` → requires only `NSPhotoLibraryUsageDescription`
  - `picker.pickImage(source: ImageSource.camera)` → requires only `NSCameraUsageDescription`
  - `picker.pickImage(source: variable)` → requires both (can't determine statically)

---
## [4.7.5] - 2026-01-24

### Added

- **Mid-chain ignore comments**: `// ignore:` comments now work when placed before the method or property name in chained calls. Previously, ignore comments had to be placed before the entire statement. Now both formats work:
  ```dart
  // Before (still works):
  // ignore: rule_name
  object.method();

  // Now also works:
  object
      // ignore: rule_name
      .method();
  ```

---
## [4.7.4] - 2026-01-24

### Added

- **Quick fix for `avoid_unbounded_cache_growth`**: New quick fix adds a `static const int maxSize = 100;` field to cache classes. Developers need to manually add eviction logic in mutation methods.

### Fixed

- **`avoid_unbounded_cache_growth` static regex patterns**: Improved performance by making regex patterns (`_limitPattern`, `_mutationMethodPattern`, `_mapKeyPattern`) static class fields instead of creating them on each method call.
- **`avoid_overlapping_animations` false positives on different-axis SizeTransitions**: Fixed false positives when nesting `SizeTransition` widgets with different axes. `SizeTransition(axis: Axis.vertical)` animates height while `SizeTransition(axis: Axis.horizontal)` animates width - these are independent properties and should not conflict. The rule now distinguishes `size_vertical` from `size_horizontal` based on the `axis` parameter.
- **`avoid_unbounded_cache_growth` false positives on enum-keyed maps**: Fixed false positives on caches that use enum keys (e.g., `Map<PanelEnum, Widget>`). Enum-keyed maps are inherently bounded by the number of enum values and cannot grow indefinitely. Also added detection for immutable caches (read-only maps with no mutation methods like `add`, `set`, or index assignment).
- **`require_stream_controller_close` false positives on helper classes**: Fixed false positives on helper/wrapper classes that have a `close()` method instead of `dispose()`. Classes like `CustomStreamController` with a `close()` method that properly closes the internal StreamController are no longer flagged. The rule now checks both `dispose()` and `close()` methods for cleanup calls.
- **`avoid_unbounded_cache_growth` false positives on database models**: Fixed false positives on Isar (`@collection`), Hive (`@HiveType`), and Floor (`@Entity`) database models that have "cache" in the class name. These ORM models use disk-based storage with external cleanup, not in-memory Map caching. Also improved detection to only flag actual Map field declarations, not `toMap()` serialization method return types.
- **`avoid_path_traversal` false positives on trusted system paths**: Fixed false positives when file paths are constructed using trusted system APIs (e.g., `path_provider`, platform MethodChannels) combined with hardcoded constants. The rule now only flags paths containing function parameters (actual user input), not paths using private fields, constants, or system API returns like `getApplicationDocumentsDirectory()`.
- **`require_deep_link_fallback` false positives on URI getters**: Fixed false positives on simple URI getter and converter methods that are not deep link handlers. Now skips: lazy-loading patterns (`_uri ??= parseUri(url)`), method invocations on fields (`url.toUri()`), and null-aware property access (`url?.uri`).
- **`require_stream_controller_dispose` false positive with typed StreamControllers**: Fixed false positives when `StreamController<T>` has a concrete type parameter (e.g., `StreamController<String>`, `StreamController<(double, double)>`). The type classification logic incorrectly treated these as wrapper types. Also fixed wrapper types to accept both `.close()` and `.dispose()` methods.
- **`avoid_expanded_outside_flex` false positive in helper methods**: Fixed false positives when `Expanded`/`Flexible` is created inside helper methods that return `List<Widget>`, or inside collection builders like `List.generate()` and `.map()`. These patterns are now trusted since the widgets typically end up inside Flex parents at runtime.
- **`avoid_flashing_content` false positives on non-repeating animations**: Fixed false positives where the rule flagged all `AnimationController` instances with `duration < 333ms`, regardless of whether the animation actually repeats. Per WCAG 2.3.1, a "flash" requires alternating between states, so only `.repeat()` cascades now trigger the rule. Single-direction animations (`.forward()`, `.reverse()`, `.animateTo()`) are no longer flagged.

### Added

- **Quick fix for `avoid_flashing_content`**: New quick fix increases animation duration to 333ms (minimum WCAG 2.3.1 compliant threshold).
- **Quick fix for `require_stream_controller_close`**: New quick fix adds `controller.close()` call to the dispose/close method.

---
## [4.7.3] - 2026-01-24

### Added

- **Interactive analysis prompt**: After init completes, prompts user "🔍 Run analysis now? [y/N]" to optionally run `dart run custom_lint` immediately.

### Fixed

- **Progress tracking: misleading percentages**: Fixed bug where progress would show constantly recalibrating percentages (e.g., "130/149 (87%)") when file discovery failed. Now shows simple file count ("X files") when accurate totals aren't available.

- **Progress tracking: rule name prefix spam**: Fixed progress output being prefixed with rule name (e.g., `[require_ios_privacy_manifest]`) for every update. Progress now uses stderr to avoid custom_lint's automatic rule tagging.

---
## [4.7.2] - 2026-01-24

### Added

- **Custom overrides file**: New `analysis_options_custom.yaml` file for rule customizations that survive `--reset`. Place rule overrides in this file to always apply them regardless of tier or reset.

- **Timestamped backups**: Backup files now include datetime stamp (`yyyymmdd_hhmmss_filename.bak`) for history tracking.

- **Enhanced debugging**: Added version number, file paths, and file size to init script output.

- **Detailed log files**: Init script now writes detailed logs to `reports/yyyymmdd_hhmmss_saropa_lints_init.log` for history and debugging.

### Fixed

- **Init script: false "user customizations" count**: Fixed bug where switching tiers would incorrectly count all tier-changed rules as "user customizations". Now only rules explicitly in the USER CUSTOMIZATIONS section are preserved. Added warning when >50 customizations detected (suggests using `--reset` to fix corrupted config).

---
## [4.7.0] - 2026-01-24

### Added

- **Single source of truth for rule tiers**: Rules now declare their tier directly in the rule class via `RuleTier get tier` getter. The init script reads tier from rule classes with fallback to legacy `tiers.dart` for backwards compatibility.

- **Enhanced init script output**:
  - Cross-platform ANSI color support (Windows Terminal, ConEmu, macOS, Linux)
  - Rules organized by tier with visual tier headers
  - Problem message comments next to every rule in YAML
  - Stylistic rules in dedicated section
  - Summary with counts by tier and severity
  - Massive ASCII art section headers for easy navigation

- **Progress tracking with ETA**:
  - File discovery at startup for accurate progress percentage
  - Rolling average for stable ETA calculation
  - Slow file detection (files taking >5 seconds)
  - Violation count tracking
  - Recalibration when more files found than expected

### Fixed

- **`prefer_small_length_files` and `prefer_small_length_test_files` tier misassignment**: Fixed bug where these insanity-tier rules were incorrectly enabled in comprehensive tier. Rules now correctly have `tier => RuleTier.insanity` override.

---
## [4.6.2] - 2026-01-24

### Removed

- **require_build_context_scope**: Removed duplicate rule and added `require_build_context_scope` as a config alias to `avoid_context_across_async`. The `avoid_context_across_async` rule (Essential tier) provides better detection with mounted guard awareness and a quick fix. Users with `require_build_context_scope` in their config will now use `avoid_context_across_async` automatically.

### Added

- **Slow rule deferral system**: New two-pass analysis mode for faster feedback:
  - `SAROPA_LINTS_DEFER=true` - Skip rules that historically take >50ms in first pass
  - `SAROPA_LINTS_DEFERRED=true` - Run only the deferred slow rules in second pass
  - Rules exceeding 50ms are automatically tracked for future deferral

- **Report generation** (experimental): `SAROPA_LINTS_REPORT=true` enables detailed reports:
  - Timing report with all rules sorted by execution time
  - Slow rules report (rules exceeding 10ms threshold)
  - Skipped files report
  - Impact report (violations grouped by severity)

- **Expanded file exclusion patterns**: Additional generated file detection:
  - New suffixes: `.chopper.dart`, `.reflectable.dart`, `.pb.dart`, `.pbjson.dart`, `.pbenum.dart`, `.pbserver.dart`, `.mapper.dart`, `.module.dart`
  - Global folder exclusions: `/ios/Pods/`, `/ios/.symlinks/`, `/android/.gradle/`, `/windows/flutter/`, `/linux/flutter/`, `/macos/Flutter/`, `/.fvm/`
  - Content-based detection for generated files without recognizable suffixes (checks first 500 chars for markers like "GENERATED CODE", "DO NOT EDIT")

### Changed

- **Quote/apostrophe style rules moved to stylistic tier**: The following conflicting rules are now opt-in only (require explicit configuration):
  - `prefer_double_quotes`
  - `prefer_single_quotes`
  - `prefer_doc_curly_apostrophe`
  - `prefer_doc_straight_apostrophe`
  - `prefer_straight_apostrophe`

### Performance

- **RegExp caching**: Cached ~30 RegExp patterns as `static final` fields across 13 rule files. Previously, patterns were recompiled on every method call.

- **Widget detection optimization**: `_WidgetDepthVisitor` now uses O(1) Set lookup + single regex pattern instead of 19 separate `.endsWith()` calls.

- **Consolidated duplicate RegExp**: Merged two identical `_privateMethodCallPattern` definitions in `flutter_widget_rules.dart` into a single shared constant.

---
## [4.6.1] - 2026-01-24

### Added

- **`getAllDefinedRules()` function**: New public function in `tiers.dart` returns the complete set of all rule names across all tiers (including stylistic). Used by both the CLI tool and unit tests to eliminate code duplication.

### Changed

- **Import style rules moved to stylistic tier**: The following rules are now opt-in only (not included in any tier by default) since import style is a team preference:
  - `prefer_absolute_imports`
  - `prefer_flat_imports`
  - `prefer_grouped_imports`
  - `prefer_named_imports`
  - `prefer_relative_imports`

- **Test refactoring**: Tier validation tests now use `setUpAll` to compute rule sets once and share across tests, eliminating duplication.

### Fixed

- **avoid_stateful_without_state**: Fixed false positives when StatefulWidget calls `setState` but has no mutable fields or lifecycle methods. The rule now correctly excludes State classes that:
  - Have non-final instance fields (mutable state)
  - Override lifecycle methods (initState, didChangeDependencies, didUpdateWidget, deactivate, dispose)
  - Call `setState` anywhere in method bodies (new detection via AST visitor)
  - Changed severity from ERROR to WARNING for less disruptive feedback
  - Added quick fix: Inserts TODO comment to convert to StatelessWidget

- **Tier/plugin sync validation**: Added unit tests to validate that all plugin rules are assigned to a tier in `tiers.dart` and all tier entries have corresponding implementations. This prevents:
  - Rules defaulting to unknown state when not assigned to any tier
  - Phantom rules (tier entries without implementations) causing config errors
  - Typos in tier rule names going undetected

- **Tier cleanup**: Removed 144 phantom rules from `tiers.dart` (rules defined in tiers but never implemented). Added 3 missing rules (`no_empty_block`, `prefer_uuid_v4`, `prefer_ios_storekit2`) to professionalOnlyRules. Cleaned up empty section comments left after phantom rule removal.

---

## [4.6.0] - 2026-01-24

### Added

- **New CLI tool: `saropa_lints:init`** - Generates `analysis_options.yaml` with explicit rule configuration, bypassing custom_lint's unreliable plugin config mechanism:
  - Select tier via `--tier` (1-5 or name: essential, recommended, professional, comprehensive, insanity)
  - Include stylistic rules with `--stylistic` flag
  - Preview changes with `--dry-run`
  - Preserves user customizations when regenerating (use `--reset` to discard)
  - Preserves non-custom_lint sections (analyzer, linter, formatter, etc.)
  - Creates backup before overwriting existing files

- **BROKEN_TIERS.md** - Documentation explaining why YAML tier configuration doesn't work and how to use the CLI tool instead

### Changed

- **README.md**: Updated Quick Start to recommend CLI tool instead of YAML tier config
- **README_STYLISTIC.md**: Updated to use CLI tool approach
- **bin/init.dart**: Extracted duplicate regex patterns to shared constants

### Fixed

- **Tier configuration reliability**: The new CLI tool generates explicit `- rule_name: true/false` for all 1674+ rules, eliminating the silent fallback to essential tier that occurred with YAML config

---

## [4.5.7] - 2026-01-23

### Changed

- **CLI tool (bin/init.dart) improvements:**
  - Enhanced doc header with comprehensive parameter documentation, examples, and exit codes
  - Fixed section header padding bug that caused malformed output for very long titles
  - Fixed asymmetric centering for odd-length section titles
  - Added graceful truncation for titles exceeding 72 characters

### Fixed

- **avoid_platform_channel_on_web**: Fixed false positives when MethodChannel is properly guarded with a ternary operator. The rule now recognizes both patterns:
  - `if (!kIsWeb) { MethodChannel(...) }` (already supported)
  - `kIsWeb ? null : MethodChannel(...)` (now supported)

- **Trailing ignore comment detection**: Fixed `// ignore:` comments not being recognized in certain contexts:
  - Constructor arguments: `url: 'http://example.com', // ignore: rule`
  - List items: `WebsiteItem(url: 'test.com'), // ignore: rule`
  - Added line-based validation to distinguish trailing comments (apply to same-line code) from leading comments (apply to next statement).
  - This prevents a trailing ignore on one argument from incorrectly suppressing lints on subsequent arguments.

- **require_deep_link_fallback**: Fixed false positives on utility methods:
  - Skip methods starting with `reset`, `clear`, `set`
  - Skip simple expression body methods returning a field (e.g., `=> _uri`)
  - Skip trivial method bodies with single assignment or simple return statements
  - `get*` methods now use body-based detection (skip only if returning a simple field/null)

### Added

- **require_deep_link_fallback quick fix**: Wraps handler body with try/catch for fallback handling

### Documentation

- Updated README.md version badge to 4.5.7
- Updated example/analysis_options_template.yaml tier counts to match actual rule counts

---

## [4.5.6] - 2026-01-23

### Changed
- **Major upgrade to developer-facing lint rule messages:**
  - All `problemMessage` and `correctionMessage` fields for the following rules were rewritten to be context-rich, actionable, and consequence-focused, referencing best practices and real-world risks. This includes the latest upgrades for:
    - `require_bluetooth_state_check`, `require_ble_disconnect_handling`, `require_geolocator_service_enabled`, `require_geolocator_stream_cancel`, `require_geolocator_error_handling`, `avoid_snackbar_in_build`, `avoid_analytics_in_build`, `avoid_canvas_operations_in_build`, `avoid_unreachable_for_loop`, `require_key_for_collection`, `avoid_print_in_release`, `require_default_config`, `require_lifecycle_observer`, `require_file_handle_close`, `require_deep_equality_collections`, `avoid_throw_in_catch_block`, `avoid_throw_objects_without_tostring`, `require_graphql_error_handling`, `require_sqflite_error_handling`, `require_sqflite_close`, `avoid_sqflite_reserved_words`, `avoid_loading_full_pdf_in_memory`, `avoid_database_in_build`, `avoid_secure_storage_on_web`, `require_database_migration`.
  - Each message now clearly explains the context and consequences of ignoring the rule (e.g., memory leaks, security risks, user confusion, app crashes), and the best practice for remediation.

- **require_field_dispose** lint rule is now much smarter:
  - Maintains a list of controller types that never require manual disposal (e.g., `WebViewController`, `GoogleMapController`, `MapController`, `QuillController`, etc.), skipping disposal checks for these types. This prevents false positives for controllers managed by plugins or the framework.
  - For common controllers (e.g., `TabController`, `ScrollController`, `PageController`, `AnimationController`, `TextEditingController`), disposal is only required if they are manually instantiated in the State class. If managed by a widget (such as `DefaultTabController`, `ListView.builder`, `AnimatedWidget`, or `TextFormField`), disposal is handled automatically and not flagged.
  - The rule now includes substantial code comments explaining the rationale, edge cases, and references to official documentation, making future maintenance and audits easier.
  - Edge cases and plugin-managed controllers are now handled correctly, ensuring only true disposal issues are flagged and reducing noise for developers.

- **require_stream_controller_close** lint rule is now smarter:
- Rule now detects wrapper types (e.g., IsarStreamController, custom wrappers) and accepts .dispose() as valid for those, while requiring .close() for direct StreamController instances.
- Improved detection logic for disposal in dispose() method.
- Messages remain context-rich and actionable, emphasizing consequences and best practices.

---

## [4.5.5] - 2026-01-23

### Changed
- **Major upgrade to developer-facing lint rule messages:**
  - All `problemMessage` and `correctionMessage` fields for the following rules were rewritten to be context-rich, actionable, and consequence-focused, referencing best practices and real-world risks:
    - `avoid_dio_debug_print_production`, `require_url_launcher_error_handling`, `require_image_picker_error_handling`, `require_geolocator_timeout`, `require_permission_denied_handling`, `require_sqflite_migration`, `require_permission_status_check`, `prefer_timeout_on_requests`, `avoid_future_ignore`, `avoid_redundant_async`, `avoid_stream_tostring`, `prefer_async_await`, `prefer_specifying_future_value_type`, `prefer_return_await`, `require_future_timeout`, `require_completer_error_handling`, `avoid_unawaited_future`, and more.
  - Each message now clearly explains the widget/resource context, the consequences of ignoring the rule (e.g., memory leaks, security risks, user confusion, app crashes), and the best practice for remediation.
  - This batch completes the full upgrade of all remaining rules flagged as too short, vague, or generic in previous audits.

### Documentation

- **PERFORMANCE.md**: Updated to reflect current best practices for configuration and performance:
  - The summary table now states that tier set caching and rule filtering cache are "Built-in" (not just v3.0.0).
  - The guide now recommends using the CLI tool for tier selection and config generation, not YAML `tier:` keys.
  - All quick start and troubleshooting sections now match the latest workflow and recommendations from README.md and bin/init.dart.

### Fixed

- **require_camera_permission_check**: False positive fixed for `.initialize()` calls on non-camera controllers (e.g., IsarStreamController). The rule now checks the static type to ensure only `CameraController` is flagged. Thanks to user report and test case.
- Added test fixture: `example/lib/isar_stream_controller_initialize_fixture.dart` to document and prevent regression of this false positive.

### Added
 - **Automated release announcements:**
   - Added a GitHub Actions workflow that automatically posts a new Discussion in the Announcements category whenever a new version is published. The announcement includes the relevant section from the CHANGELOG for the released version.
   - See .github/workflows/announce-release.yml for details.

- **Roadmap/issue/discussion tracking improvements:**
  - Added 🐙 emoji to the legend in ROADMAP.md and README.md to indicate rules tracked as GitHub issues.
  - Added 💡 emoji to the legend in ROADMAP.md and README.md to indicate planned enhancements tracked as GitHub Discussions.
  - This improves transparency, prioritization, and community contribution for both complex rules and planned enhancements.

---
## [4.5.4] - 2026-01-22

### Changed

- **All remaining lint rule messages upgraded:**
  - Updated all `problemMessage` and `correctionMessage` fields for every rule in:
    - `unnecessary_code_rules.dart`
    - `ui_ux_rules.dart`
    - `type_safety_rules.dart`
  - All messages now follow the latest DX, clarity, and style guide standards.
  - This completes the full upgrade of all 30 targeted lint rules.

### Notes
- This change ensures all lint rule messages are actionable, concise, and consistent with the project's documentation and audit requirements.
- No rules remain to be upgraded; all tracked batches are now complete.

### Fixed

- Fixed a type error in the CLI tool (`bin/init.dart`) when serializing YAML to JSON for config generation. The tool now correctly converts `YamlMap` and nested YAML structures to regular Dart maps before passing them to `json2yaml`, preventing runtime exceptions when updating `analysis_options.yaml`.

---
## [4.5.3] - 2026-01-22

### Fixed

- Moved `json2yaml` and added `yaml` to main dependencies in pubspec.yaml to satisfy pub.dev requirements for CLI tools in `bin/`.
  This fixes publishing errors and allows versions above 4.5.0 to be published to pub.dev.

## [4.5.2] - 2026-01-22

### Changed

- **Major improvements to lint rule messages:**
  - All critical and high-impact rules now have detailed, actionable `problemMessage` and `correctionMessage` fields.
  - Messages now clearly explain the risk, impact, and how to fix each violation, following accessibility and best-practice standards.
  - The following files were updated with improved messages for many rules:
    - `debug_rules.dart`
    - `disposal_rules.dart`
    - `equatable_rules.dart`
    - `file_handling_rules.dart`
    - `hive_rules.dart`
    - `internationalization_rules.dart`
    - `json_datetime_rules.dart`
    - `memory_management_rules.dart`
    - `security_rules.dart`
    - `type_safety_rules.dart`
  - Notable rules improved: `avoid_sensitive_in_logs`, `require_page_controller_dispose`, `avoid_websocket_memory_leak`, `avoid_mutable_field_in_equatable`, `require_sqflite_whereargs`, `avoid_hive_field_index_reuse`, `require_intl_args_match`, `prefer_try_parse_for_dynamic_data`, `require_image_disposal`, `avoid_expando_circular_references`, `avoid_path_traversal`, `require_null_safe_json_access`, and others.
  - Many rules now provide context-specific examples and describe the consequences of ignoring the lint.

- **Stylistic tier now includes both type argument rules:**
  - `prefer_inferred_type_arguments` and `prefer_explicit_type_arguments` have been added to the `stylisticRules` set in `tiers.dart`.
  - Both rules are now included when the stylistic tier is enabled, but remain mutually exclusive in effect (enabling both will cause conflicting lints).
  - This change makes it easier to opt into either style preference via the `--stylistic` flag or tier selection, but users should only enable one of the two in their configuration to avoid conflicts.

## [4.5.1] - 2026-01-22

### Package Dependancies

- Ensure custom_lint and custom_lint_builder use the same version in pubspec.yaml to avoid compatibility issues. If you downgrade, set both to the same version (e.g., ^0.8.0).
- Upgraded dev dependencies: test to v1.29.0 and json2yaml to v3.0.1.

### Changed

- **CLI tool (bin/init.dart) improvements:**
  - Added `--no-pager` flag to print the full dry-run preview without pausing (useful for CI/non-interactive environments).
  - Dry-run pagination is now automatically skipped if stdin is not a terminal.
  - YAML parse errors in existing analysis_options.yaml are now caught and reported, with a fallback to a fresh config if needed.
  - Added and improved code comments throughout for clarity and maintainability.
  - Help output now documents the new flag and behaviors.

- Migrated rules 4.2.0 and below to [CHANGELOG_ARCHIVE.md](./CHANGELOG_ARCHIVE.md)

#### File Length Rules Renamed (structure_rules.dart)

All file length rules have been renamed to include `_length` for clarity and consistency:

**Production file length rules:**

- `prefer_small_files` → `prefer_small_length_files` (insanity tier, >200 lines)
- `avoid_medium_files` → `avoid_medium_length_files` (professional tier, >300 lines)
- `avoid_long_files` → `avoid_long_length_files` (comprehensive tier, >500 lines)
- `avoid_very_long_files` → `avoid_very_long_length_files` (recommended tier, >1000 lines)

**Test file length rules:**

- `prefer_small_test_files` → `prefer_small_length_test_files` (insanity tier, >400 lines)
- `avoid_medium_test_files` → `avoid_medium_length_test_files` (professional tier, >600 lines)
- `avoid_long_test_files` → `avoid_long_length_test_files` (comprehensive tier, >1000 lines)
- `avoid_very_long_test_files` → `avoid_very_long_length_test_files` (recommended tier, >2000 lines)

Production file length rules now skip test files automatically.

**Explanation:**
Production file length rules (such as `prefer_small_length_files`, `avoid_medium_length_files`, etc.) now automatically exclude test files from their checks. This prevents false positives on large test files and means you no longer need to manually disable these rules for test files in your configuration. Only production (non-test) Dart files are checked for file length limits by these rules.

## [4.5.0] - 2026-01-21

### Added

- **New Dart CLI tool: `bin/init.dart`**
  - Generates `analysis_options.yaml` with explicit `- rule_name: true/false` for all 1668 rules
  - Supports tier selection: `--tier essential|recommended|professional|comprehensive|insanity` (or 1-5)
  - Supports `--stylistic` flag to include opinionated formatting rules
  - Supports `--dry-run` to preview output without writing
  - Creates a backup of the existing file before overwriting

### Changed

- **pubspec.yaml**
  - Added `executables` section exposing `init`, `baseline`, and `impact_report` commands

- **Documentation**
  - Updated `README.md` Quick Start to use the CLI tool
  - Updated "Using a tier", "Customizing rules", "Stylistic Rules", and "Performance" sections
  - Updated troubleshooting to recommend the CLI tool instead of workarounds
  - Updated `README_STYLISTIC.md` to use the CLI approach

### Usage

```bash
# Generate config for comprehensive tier (1618 rules) - recommended
dart run saropa_lints:init --tier comprehensive

# Generate config for essential tier (342 rules) - fastest
dart run saropa_lints:init --tier essential

# Include stylistic rules
dart run saropa_lints:init --tier comprehensive --stylistic

# Preview without writing
dart run saropa_lints:init --dry-run

# See all options
dart run saropa_lints:init --help
```

---

## [4.4.0] - 2026-01-21

### Added

**Split duplicate collection element detection into 3 separate rules** - The original `avoid_duplicate_collection_elements` rule has been replaced with three type-specific rules that can be suppressed independently:

- `avoid_duplicate_number_elements` - Detects duplicate numeric literals (int, double) in lists and sets. Can be suppressed for legitimate cases like `const daysInMonth = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]`.
- `avoid_duplicate_string_elements` - Detects duplicate string literals in lists and sets.
- `avoid_duplicate_object_elements` - Detects duplicate identifiers, booleans, and null literals in lists and sets.

All three rules include quick fixes to remove duplicate elements.

### Removed

- `avoid_duplicate_collection_elements` - Replaced by the three type-specific rules above. If you had this rule disabled in your configuration, update to disable the new rules individually.

### Fixed

**`avoid_variable_shadowing` false positives on sibling closures** - The rule was incorrectly flagging variables with the same name in sibling closures (like separate `test()` callbacks within a `group()`) as shadowing. These are independent scopes, not nested scopes, so they don't actually shadow each other. The rule now properly tracks scope boundaries.

## [4.3.0] - 2026-01-21

### Added

**2 new test-specific magic literal rules** - Test files legitimately use more literal values for test data, expected values, and test descriptions. The existing `no_magic_number` and `no_magic_string` rules now skip test files entirely, and two new test-specific variants provide appropriate enforcement for tests:

- `no_magic_number_in_tests` - Warns when magic numbers are used in test files. More relaxed than the production rule, allowing common test values like HTTP status codes (200, 404, 500), small integers (0-5, 10, 100, 1000), and common floats (0.5, 1.0, 10.0, 100.0). Still encourages named constants for domain-specific values like `29.99` in a product price test.
- `no_magic_string_in_tests` - Warns when magic strings are used in test files. More relaxed than the production rule, allowing common test values like single letters ('a', 'x', 'foo', 'bar') and automatically skipping test descriptions (first argument to `test()`, `group()`, `testWidgets()`, etc.). Still encourages named constants for meaningful test data like email addresses or URLs.

Both rules are in the comprehensive tier with INFO severity. They use `applicableFileTypes: {FileType.test}` to only run on test files.

### Changed

**Production code rules now skip test files** - `no_magic_number` and `no_magic_string` now have `skipTestFiles: true`, preventing false positives on legitimate test data like hex strings ('7FfFfFfFfFfFfFf'), test descriptions, and expected values. Use the test-specific variants for appropriate enforcement in tests.

### Fixed

**`no_magic_string` and `no_magic_string_in_tests` now skip regex patterns** - The rules were flagging regex pattern strings as magic strings, even when passed directly to `RegExp()` constructors. The rules now detect and skip:

- Strings passed as arguments to `RegExp()` constructors
- Raw strings (`r'...'`) that contain regex-specific syntax (anchors `^`/`$`, quantifiers `+`/`*`/`?`, character classes `\d`/`\w`/`\s`, etc.)

This prevents false positives on legitimate regex patterns like `RegExp(r'0+$')` or `RegExp(r'\d{3}-\d{4}')`.

**`prefer_no_commented_out_code` and `prefer_capitalized_comment_start` false positives on prose comments** - These rules use shared heuristics to detect commented-out code vs prose comments. The previous pattern matched keywords at the start of comments too broadly, causing false positives on natural language sentences like `// null is before non-null` or `// return when the condition is met`. The detection patterns are now context-aware and only match keywords when they appear in actual code contexts:

- Control flow keywords (`if`, `for`, `while`) now require opening parens/braces: `if (` or `while {`
- Simple statements (`return`, `break`, `throw`) now require semicolons or specific literals
- Declarations (`final`, `const`, `var`) now require identifiers after them
- Literals (`null`, `true`, `false`) now require code punctuation (`;`, `,`, `)`) or standalone usage

This eliminates false positives while maintaining detection of actual commented-out code.

## [4.2.3] - 2026-01-20

### Added

**Progress reporting for large codebases** - Real-time feedback during CLI analysis showing files analyzed, elapsed time, and throughput. Reports every 25 files or every 3 seconds, whichever comes first. Output format: `[saropa_lints] Progress: 25 files analyzed (2s, 12.5 files/sec) - home_screen.dart`. Enabled by default, can be disabled via `--define=SAROPA_LINTS_PROGRESS=false`.

**2 new stylistic apostrophe rules** - complementary opposite rules for the existing apostrophe preferences:

- `prefer_doc_straight_apostrophe` - Warns when curly apostrophes (U+2019) are used in doc comments. Opposite of `prefer_doc_curly_apostrophe`. Quick fix replaces curly with straight apostrophes.
- `prefer_curly_apostrophe` - Warns when straight apostrophes are used in string literals instead of curly. Opposite of `prefer_straight_apostrophe`. Quick fix replaces contractions with typographic apostrophes.

Both rules are opinionated and not included in any tier by default. Enable them explicitly if your team prefers consistent apostrophe style.

### Fixed

**`avoid_sensitive_in_logs` false positives** - The rule was matching sensitive keywords (token, credential, session, etc.) in plain string literals, even when they were just descriptive text like `'Updating local token.'` or `'failed (null credential)'`. The rule now uses AST-based detection:

- **Plain string literals** (`SimpleStringLiteral`) → Always safe, no actual data being logged
- **String interpolation** → Only checks the interpolated expressions, not the literal text parts
- **Variable references** (`$password`) → Check if the variable name is sensitive
- **Property access** (`user.token`) → Check if the property name is sensitive
- **Conditionals** → Recursively check the branches, not the condition

**Quick fix added**: Comments out the sensitive log statement with `// SECURITY:` prefix.

**`require_subscription_status_check` false positives on similar identifiers** - The rule used simple substring matching to detect premium indicators like `isPro`, which caused false positives when identifiers contained these as substrings (e.g., `isProportional` falsely matched `isPro`). The rule now uses word boundary regex (`\b`) to match whole words only.

**`require_deep_link_fallback` false positives on utility getters** - The rule was incorrectly flagging utility getters that check URI state (e.g., `isNotUriNullOrEmpty`, `hasValidUri`, `isUriEmpty`) as if they were deep link handlers requiring fallback logic. The rule now skips getters that are clearly utility methods: those starting with `is`, `has`, `check`, `valid`, or ending with `empty`, `null`, or `nullable` (uses suffix matching for precision, so `handleEmptyDeepLink` would still be checked).

**`require_https_only` false positives on safe URL upgrades** - The rule was flagging `http://` strings even when used in safe replacement patterns like `url.replaceFirst('http://', 'https://')`. The rule now detects and allows these safe HTTP-to-HTTPS upgrade patterns using `replaceFirst`, `replaceAll`, or `replace` methods.

**`avoid_mixed_environments` false positives on conditional configs** - The rule was incorrectly flagging classes that use Flutter's mode constants (`kReleaseMode`, `kDebugMode`, `kProfileMode`) to conditionally set values.

The rule now detects fields with mode constant checks and marks them as "properly conditional", skipping both production and development indicator checks for those fields. Doc header enhanced with `[HEURISTIC]` tag and additional examples. Added `requiresClassDeclaration` override for performance.

### Changed

**Rule consolidation** - `avoid_sensitive_data_in_logs` (security_rules.dart) has been removed as a duplicate of `avoid_sensitive_in_logs` (debug_rules.dart). The canonical rule now:

- Has a config alias `avoid_sensitive_data_in_logs` for backwards compatibility
- Uses proper AST analysis instead of regex matching (more accurate)
- Has a quick fix to comment out sensitive log statements

If you had `avoid_sensitive_data_in_logs` in your config, it will continue to work via the alias.

**Shared utility for mode constant detection** - Extracted `usesFlutterModeConstants()` to `mode_constants_utils.dart` for detecting `kReleaseMode`, `kDebugMode`, and `kProfileMode` guards. Used by 5 rule files: config_rules.dart, debug_rules.dart, iap_rules.dart, isar_rules.dart, ios_rules.dart. This also fixed missing `kProfileMode` checks in iap_rules.dart and isar_rules.dart.

## [4.2.2] - 2026-01-19

### Fixed

**Critical bug fixes for rule execution** - Two bugs were causing rules to be silently skipped, resulting in "No issues found" or far fewer issues than expected:

1. **Throttle key missing rule name** - The analysis throttle used `path:contentHash` as a cache key, but didn't include the rule name. When rule A analyzed a file, rules B through Z would see the cache entry and skip the file thinking it was "just analyzed" within the 300ms throttle window. Now uses `path:contentHash:ruleName` so each rule has its own throttle.

2. **Rapid edit mode false triggering** - The adaptive tier switching feature (designed to show only essential rules during rapid IDE saves) was incorrectly triggering during CLI batch analysis. When `dart run custom_lint` ran 268 rules on a file, the edit counter hit 268 in under 2 seconds, triggering "rapid edit mode" and skipping non-essential rules. This check is now disabled for CLI runs.

**Impact**: These bugs affected all users on all platforms. Windows users were additionally affected by path normalization issues fixed in earlier commits.

## [4.2.1] - 2026-01-19

### Changed

- **Rule renamed**: `avoid_mutating_parameters` → `avoid_parameter_reassignment` (old name kept as deprecated alias in doc header). Tier changed from Recommended to Stylistic to reflect that reassignment is a style preference, not a correctness issue.
- **Heuristics improved** - `require_android_backup_rules` now uses word-boundary matching to avoid false positives on keys like "authentication_method"
- **File reorganization** - Consolidated v4.1.7 rules from separate `v417_*.dart` files into their appropriate category files:
  - Caching rules → `memory_management_rules.dart`
  - WebSocket reconnection → `api_network_rules.dart`
  - Currency code rule → `money_rules.dart`
  - Lazy singleton rule → `dependency_injection_rules.dart`
  - Performance rules → `performance_rules.dart`
  - Clipboard/encryption security → `security_rules.dart`
  - State management rules → `state_management_rules.dart`
  - Testing rules → `testing_best_practices_rules.dart`
  - Widget rules → `flutter_widget_rules.dart`

## [4.2.0] and Earlier

For details on the initial release and versions 0.1.0 through 4.2.0, please refer to [CHANGELOG_ARCHIVE.md](./CHANGELOG_ARCHIVE.md).
