# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.4.0] - Unreleased

### Added

- **14 new lint rules**:

  **Memory Leak Prevention (3 - Essential)**:
  - `require_scroll_controller_dispose` - ScrollController fields must be disposed to prevent memory leaks
  - `require_focus_node_dispose` - FocusNode fields must be disposed to prevent memory leaks
  - `require_bloc_close` - Bloc/Cubit fields must be closed in dispose

  **Security (1 - Essential)**:
  - `avoid_dynamic_sql` - SQL queries built with string interpolation are vulnerable to injection attacks

  **Widget Best Practices (5 - Recommended/Professional)**:
  - `require_text_overflow_handling` - Text widgets with dynamic content should have overflow handling
  - `require_image_error_builder` - Network images should have errorBuilder for graceful failure
  - `require_image_dimensions` - Network images should specify dimensions to prevent layout shifts
  - `require_placeholder_for_network` - Network images should have loading placeholders
  - `avoid_nested_scrollables` - Nested scrollables cause gesture conflicts; use NestedScrollView

  **State Management (3 - Recommended/Professional)**:
  - `require_auto_dispose` - Riverpod providers should use autoDispose to prevent memory leaks
  - `prefer_consumer_widget` - Prefer ConsumerWidget over wrapping with Consumer
  - `prefer_text_theme` - Prefer Theme.textTheme over hardcoded TextStyle for consistency

  **Testing (1 - Recommended)**:
  - `prefer_pump_and_settle` - Use pumpAndSettle() after interactions to wait for animations

### Improved

- **Rule logic fixes**:
  - `require_text_overflow_handling` - Now only flags dynamic content (variables, interpolation), not static strings
  - `require_image_dimensions` - Now only flags network images, checks parent containers for sizing
  - All State class detection rules - Now use exact `State<T>` matching instead of `contains('State')` to avoid false positives on classes like StateManager
  - `require_auto_dispose` - Fixed method invocation detection for `Provider.family()` patterns
  - `prefer_pump_and_settle` - Now only suggests when pump() follows interaction methods, skips explicit duration calls

## [1.3.0] - 2025-01-06

### Added

- **37 new lint rules** with quick-fixes where applicable:

  **Modern Dart 3.0+ Class Modifier Rules (4)**:
  - `avoid_unmarked_public_class` - Public classes should use `base`, `final`, `interface`, or `sealed` modifier
  - `prefer_final_class` - Non-extensible classes should be marked `final`
  - `prefer_interface_class` - Pure abstract contracts should use `interface class`
  - `prefer_base_class` - Abstract classes with shared implementation should use `base`

  **Modern Dart 3.0+ Pattern Rules (3)**:
  - `prefer_pattern_destructuring` - Use pattern destructuring instead of multiple `.$1`, `.$2` accesses
  - `prefer_when_guard_over_if` - Use `when` guards in switch cases instead of nested `if`
  - `prefer_wildcard_for_unused_param` - Use `_` for unused parameters (Dart 3.7+) (quick-fix)

  **Modern Flutter Widget Rules (5)**:
  - `avoid_material2_fallback` - Avoid `useMaterial3: false` (Material 3 is default since Flutter 3.16) (quick-fix)
  - `prefer_overlay_portal` - Use OverlayPortal for declarative overlays (Flutter 3.10+)
  - `prefer_carousel_view` - Use CarouselView for carousel patterns (Flutter 3.24+)
  - `prefer_search_anchor` - Use SearchAnchor for Material 3 search (Flutter 3.10+)
  - `prefer_tap_region_for_dismiss` - Use TapRegion for tap-outside-to-dismiss patterns (Flutter 3.10+)

  **Flutter Widget Rules (10)**:
  - `avoid_raw_keyboard_listener` - Use KeyboardListener instead of deprecated RawKeyboardListener (quick-fix)
  - `avoid_image_repeat` - Image.repeat is rarely needed; explicit ImageRepeat.noRepeat preferred (quick-fix)
  - `avoid_icon_size_override` - Use IconTheme instead of per-icon size
  - `prefer_inkwell_over_gesture` - InkWell provides material ripple feedback (quick-fix)
  - `avoid_fitted_box_for_text` - FittedBox can cause text scaling issues
  - `prefer_listview_builder` - Use ListView.builder for long/infinite lists
  - `avoid_opacity_animation` - Use AnimatedOpacity/FadeTransition instead of Opacity widget (quick-fix)
  - `avoid_sized_box_expand` - Use SizedBox.expand() constructor instead of double.infinity (quick-fix)
  - `prefer_selectable_text` - Use SelectableText for user-copyable content (quick-fix)
  - `prefer_spacing_over_sizedbox` - Use Row/Column/Wrap spacing parameter instead of SizedBox spacers (Flutter 3.10+)

  **Security Rules (3)**:
  - `avoid_token_in_url` - Tokens/API keys should be in headers, not URL query params
  - `avoid_clipboard_sensitive` - Don't copy passwords or tokens to clipboard
  - `avoid_storing_passwords` - Never store passwords in SharedPreferences; use flutter_secure_storage

  **Performance Rules (2)**:
  - `avoid_string_concatenation_loop` - Use StringBuffer for string building in loops (quick-fix)
  - `avoid_large_list_copy` - List.from() copies entire list; consider Iterable operations

- **20 new stylistic/opinionated rules** (not in any tier by default - enable individually):
  - `prefer_relative_imports` - Use relative imports for same-package files
  - `prefer_one_widget_per_file` - One widget class per file
  - `prefer_arrow_functions` - Use arrow syntax for simple functions
  - `prefer_all_named_parameters` - Use named parameters instead of positional
  - `prefer_trailing_comma_always` - Trailing commas on all multi-line structures
  - `prefer_private_underscore_prefix` - Underscore prefix for private members
  - `prefer_widget_methods_over_classes` - Helper methods instead of private widget classes
  - `prefer_explicit_types` - Explicit type annotations instead of `var`/`final`
  - `prefer_class_over_record_return` - Named classes instead of record return types
  - `prefer_inline_callbacks` - Inline callbacks instead of separate methods
  - `prefer_single_quotes` - Prefer single quotes for string literals (quick-fix)
  - `prefer_todo_format` - TODOs follow `TODO(author): description` format
  - `prefer_fixme_format` - FIXMEs follow `FIXME(author): description` format
  - `prefer_sentence_case_comments` - Comments start with capital letter (quick-fix)
  - `prefer_period_after_doc` - Doc comment sentences end with period (quick-fix)
  - `prefer_screaming_case_constants` - Constants in SCREAMING_SNAKE_CASE (quick-fix)
  - `prefer_descriptive_bool_names` - Boolean names use is/has/can/should prefix
  - `prefer_snake_case_files` - File names in snake_case.dart
  - `avoid_small_text` - Minimum 12sp text size for accessibility (quick-fix)
  - `prefer_doc_comments_over_regular` - Use `///` instead of `//` for member docs (quick-fix)

- **Quick fixes added to existing rules**:
  - `avoid_explicit_pattern_field_name` - Auto-convert `fieldName: fieldName` to `:fieldName` shorthand
  - `prefer_digit_separators` - Auto-add digit separators to large numbers (e.g., `1000000` → `1_000_000`)

- **SaropaLintRule base class enhancements** - All rules now use the enhanced base class with:
  - **Hyphenated ignore comments** - Both `// ignore: no_empty_block` and `// ignore: no-empty-block` formats work
  - **Context-aware file skipping** - Generated files (`*.g.dart`, `*.freezed.dart`), fixture files skipped by default
  - **Documentation URLs** - Each rule has `documentationUrl` and `hyphenatedName` getters
  - **Severity override support** - Configure `SaropaLintRule.severityOverrides` for project-level severity changes
- **Automatic file skipping** for:
  - Generated code: `*.g.dart`, `*.freezed.dart`, `*.gen.dart`, `*.gr.dart`, `*.config.dart`, `*.mocks.dart`
  - Fixture files: `fixture/**`, `fixtures/**`, `*_fixture.dart`
  - Optional: test files (`skipTestFiles`), example files (`skipExampleFiles`)

### Fixed

- `prefer_when_guard_over_if` - Removed incorrect handler for traditional `SwitchCase` which doesn't support `when` guards (only `SwitchPatternCase` does)

**Logic fixes across 5 rule files** to reduce false positives and improve accuracy:

- **async_rules.dart**:
  - `AvoidStreamToStringRule` - Now uses `staticType` instead of string matching to avoid false positives on variable names like "upstream"
  - `AvoidPassingAsyncWhenSyncExpectedRule` - Only flags async callbacks passed to methods that ignore Futures (`forEach`, `map`, etc.) instead of all async callbacks
  - `PreferAsyncAwaitRule` - Only flags `.then()` inside async functions where `await` could actually be used
  - `PreferCommentingFutureDelayedRule` - Simplified token loop logic to use reliable `precedingComments` check
  - `AvoidNestedStreamsAndFuturesRule` - No longer duplicates `AvoidNestedFuturesRule` for `Future<Future>` cases

- **control_flow_rules.dart**:
  - `AvoidNestedConditionalExpressionsRule` - Fixed double-reporting by only flagging outermost conditional
  - `AvoidUnnecessaryContinueRule` - Fixed parent check to correctly identify loop contexts
  - `AvoidIfWithManyBranchesRule` - Fixed else-if chain detection using `elseStatement` identity
  - `PreferReturningConditionalsRule` - No longer overlaps with `PreferReturningConditionRule`

- **security_rules.dart**:
  - `RequireSecureStorageRule` - Removed overly broad `'key'` pattern that matched `'selectedThemeKey'`
  - `AvoidLoggingSensitiveDataRule` - Changed `'pin'` to `'pincode'`/`'pin_code'` to avoid matching "spinning", "pinned"
  - `RequireCertificatePinningRule` - Fixed cascade expression detection logic
  - `AvoidEvalLikePatternsRule` - Removed `noSuchMethod` check (valid for mocking/proxying)

- **testing_best_practices_rules.dart**:
  - `AvoidRealNetworkCallsInTestsRule` - Removed `Uri.parse`/`Uri.https`/`Uri.http` from network patterns (URL construction, not network calls)
  - `AvoidVagueTestDescriptionsRule` - Relaxed minimum length from 10 to 5 chars
  - `AvoidProductionConfigInTestsRule` - Removed overly broad `'api.com'` and `'api.io'` patterns

- **type_safety_rules.dart**:
  - `RequireSafeJsonParsingRule` - Regex now matches any `map['key']`/`data['key']` patterns, not just `json['key']`

**Performance improvements**:

- **debug_rules.dart** - Moved `RegExp` patterns to `static final` class fields to avoid recompilation:
  - `AvoidUnguardedDebugRule` - Pre-compiled `_isDebugPattern` and `_debugSuffixPattern`
  - `PreferCommentingAnalyzerIgnoresRule` - Pre-compiled `_ignorePattern`, `_ignoreForFilePattern`, `_ignoreDirectivePattern`

- **naming_style_rules.dart** - `FormatCommentRule` - Pre-compiled `_lowercaseStartPattern`

### Changed

- **README** - Added "Automatic File Skipping" section documenting which files are skipped by default
- **README** - Added hyphenated ignore comment example in "Suppressing Warnings" section
- **ROADMAP** - Added section 5.0 "SaropaLintRule Base Class Enhancements" documenting implemented and planned features

## [1.2.0] - 2025-01-06

### Changed

- **README overhaul** - Expanded "Why saropa_lints?" section:
  - Added "Linting vs static analysis" explanation
  - Added concrete code examples of bugs it catches
  - Added comparison to enterprise tools (SonarQube, Coverity, Checkmarx)
  - Added regulatory context (European Accessibility Act, GitHub leaked secrets stats)
- **pub.dev compatibility** - Fixed all relative links to use absolute GitHub URLs:
  - Banner image now uses raw.githubusercontent.com
  - Migration guides, CONTRIBUTING.md, ENTERPRISE.md, LICENSE all link to GitHub
- **Accurate tier counts** - Corrected inflated rule counts across all documentation:
  - Essential: ~50 (was ~100)
  - Recommended: ~150 (was ~300)
  - Professional: ~250 (was ~600)
  - Comprehensive: ~400 (was ~800)
  - Insanity: ~475 (was 1000)
- **Tier descriptions** - Updated Recommended tier to highlight null safety and collection bounds checking
- **Package description** - Updated pub.dev description from "1,000+" to "500+" rules

## [1.1.19] - 2025-01-06

### Changed

- `avoid_unsafe_collection_methods` - Now recognizes collection-if guards:
  - `[if (list.isNotEmpty) list.first]` - guarded in collection literal
  - `{if (set.length > 0) set.first}` - guarded in set literal
  - `[if (list.isEmpty) 0 else list.first]` - inverted guard in else branch
- `require_value_notifier_dispose` - Now recognizes loop-based disposal patterns for collections of ValueNotifiers:
  - `for (final n in _notifiers) { n.dispose(); }` - for-in loop disposal
  - `_notifiers.forEach((n) => n.dispose())` - forEach disposal
  - Supports `List<ValueNotifier<T>>`, `Set<ValueNotifier<T>>`, `Iterable<ValueNotifier<T>>`
- `require_file_close_in_finally` - Reduced false positives by requiring file indicators (File, IOSink, RandomAccessFile) for generic `.open()` calls

### Fixed

- `avoid_null_assertion` - Added additional safe pattern detection to reduce false positives:
  - Null-coalescing assignment: `x ??= value; x!` - safe after `??=`
  - Negated null checks: `if (!(x == null)) { x! }`
  - Compound && conditions: `if (a && x != null) { x! }`
  - Compound || with early return: `if (a || x == null) return; x!`
  - Flutter async builder patterns: `if (snapshot.hasData) { snapshot.data! }`, `if (snapshot.hasError) { snapshot.error! }`
  - While loops: `while (x != null) { x! }`
  - For loops: `for (; x != null; ) { x! }`
- `avoid_undisposed_instances` - Fixed type annotation access for analyzer 8.x (`name2.lexeme`); now follows helper method calls to detect indirect disposal patterns
- `avoid_undisposed_instances` - Enhanced field extraction to handle parenthesized expressions and cascade expressions

## [1.1.18] - 2025-01-06

### Added

- `no_empty_block` - Added quick fix that inserts an explanatory comment inside the empty block
- `avoid_null_assertion` - Added quick fix that converts `x!.prop` to `x?.prop` in conditions, or adds HACK comment

### Changed

- `avoid_null_assertion` - Refactored null-check extension names into documented const sets (`_truthyNullCheckNames` for && patterns, `_falsyNullCheckNames` for || patterns) for maintainability
- `avoid_unsafe_collection_methods` - Now recognizes guarded access patterns and won't flag safe usage:
  - If statements: `if (list.isNotEmpty) { list.first }`, `if (list.length > 0) { ... }`
  - Ternaries: `list.isNotEmpty ? list.first : fallback`, `list.length > 1 ? list.last : fallback`
  - Inverted guards: `if (list.isEmpty) { } else { list.first }`
  - Quick fix now suggests `*OrNull` methods (firstOrNull, lastOrNull, singleOrNull) instead of adding HACK comments
- `require_future_error_handling` - Now uses actual type checking (`isDartAsyncFuture`) instead of method name heuristics. Added quick fix that adds `.catchError()` handler.

### Fixed

- `avoid_null_assertion` - Added support for inverted if-blocks (`if (x.isEmpty) { } else { x! }`) and numeric checks (`isPositive`, `isZeroOrNegative`, `isNegativeOrZero`, `isNegative`). Also added `isNotListNullOrEmpty`, `isNotNullOrZero`, `isNullOrZero`
- `avoid_undisposed_instances` - Now recognizes `disposeSafe()`, `cancelSafe()`, and `closeSafe()` as valid disposal methods
- `require_stream_controller_dispose` - Now recognizes `closeSafe()` as valid close method
- `require_value_notifier_dispose` - Now recognizes `disposeSafe()` as valid dispose method; only checks owned fields (with initializers), not parameters passed in
- `require_database_close` - Now recognizes `closeSafe()` and `disposeSafe()` as valid cleanup methods
- `require_http_client_close` - Now recognizes `closeSafe()` as valid close method
- `require_websocket_close` - Now recognizes `closeSafe()` as valid close method
- `require_platform_channel_cleanup` - Now recognizes `cancelSafe()` as valid cancel method
- `require_image_disposal` - Now recognizes `disposeSafe()` as valid dispose method

## [1.1.17] - 2025-01-06

### Added

- `require_timer_cancellation` - New dedicated rule for Timer and StreamSubscription fields that require `cancel()`. Separated from `require_dispose` for clearer semantics. Crashes can occur if uncancelled timers call setState after widget disposal.
- `nullify_after_dispose` - New rule that suggests setting nullable disposable fields to null after disposal (e.g., `_timer = null` after `_timer?.cancel()`). Helps garbage collection and prevents accidental reuse.

### Changed

- `require_dispose` - Removed Timer and StreamSubscription (now handled by `require_timer_cancellation`). Now focuses on controllers that use `dispose()` and streams that use `close()`.

### Fixed

- `require_animation_disposal` - Now only checks State classes, eliminating false positives on StatelessWidgets that receive AnimationControllers as constructor parameters (they don't own the controller, parent disposes it)
- `require_dispose` - Now follows helper method calls from dispose() to detect indirect disposal patterns like `_cancelTimer()` that internally call the disposal method
- `require_timer_cancellation` - Follows helper method calls from dispose() to detect indirect cancellation patterns

## [1.1.16] - 2025-01-05

### Changed

- Renamed `docs/` to `doc/guides/` to follow Dart/Pub package layout conventions

## [1.1.15] - 2025-01-05

### Fixed

- `require_dispose` - Fixed `disposeSafe` pattern matching (was `xSafe()`, now correctly matches `x.disposeSafe()`)
- `avoid_logging_sensitive_data` - Added safe pattern detection to avoid false positives on words like `oauth`, `authenticated`, `authorization`, `unauthorized`

### Changed

- README: Clarified that rules must use YAML list format (`- rule: value`) not map format
- README: Updated IDE integration section with realistic expectations and CLI recommendation

## [1.1.14] - 2025-01-05

### Fixed

- `avoid_null_assertion` - Added short-circuit evaluation detection to reduce false positives:
  - `x == null || x!.length` - safe due to || short-circuit
  - `x.isListNullOrEmpty || x!.length < 2` - extension method short-circuit
  - `x != null && x!.doSomething()` - safe due to && short-circuit
  - Added `isListNullOrEmpty`, `isNullOrEmpty`, `isNullOrBlank` to recognized null checks

## [1.1.13] - 2025-01-05

### Changed

- `avoid_null_assertion` - Now recognizes safe null assertion patterns to reduce false positives:
  - Safe ternaries: `x == null ? null : x!`, `x != null ? x! : default`
  - Safe if-blocks: `if (x != null) { use(x!) }`
  - After null-check extensions: `.isNotNullOrEmpty`, `.isNotNullOrBlank`, `.isNotEmpty`
- `dispose_controllers` - Now recognizes `disposeSafe()` as a valid dispose method

## [1.1.12] - 2025-01-05

### Fixed

- `avoid_hardcoded_credentials` - Improved pattern matching to reduce false positives
  - Added minimum length requirements: sk-/pk- tokens (20+), GitHub tokens (36+), Bearer (20+), Basic (10+)
  - More accurate character sets for Base64 encoding in Basic auth
  - End-of-string anchoring for Bearer/Basic tokens

## [1.1.11] - 2025-01-05

### Changed

- **Breaking**: New tier configuration system using Dart code instead of YAML includes
  - `custom_lint` doesn't follow `include:` directives, so tiers are now defined in Dart
  - Configure via `custom_lint: saropa_lints: tier: recommended` in analysis_options.yaml
  - Individual rules can still be overridden on top of tier selection
  - Tiers: essential, recommended, professional, comprehensive, insanity

### Added

- `lib/src/tiers.dart` with rule sets for each tier defined as Dart constants
- `getRulesForTier(String tier)` function for tier-based rule resolution

### Removed

- YAML-based tier configuration (include directives were not being followed by custom_lint)

## [1.1.10] - 2025-01-05

### Fixed

- Added `license: MIT` field to pubspec.yaml for proper pub.dev display

## [1.1.9] - 2025-01-05

### Added

- Quick fixes for 37+ lint rules (IDE code actions to resolve issues)
- `ROADMAP.md` with specifications for ~500 new rules to reach 1000 total
- `ENTERPRISE.md` with business value, adoption strategy, and professional services info
- "Why saropa_lints?" section in README explaining project motivation
- Contact emails: `lints@saropa.com` (README), `dev@saropa.com` (CONTRIBUTING), `enterprise@saropa.com` (ENTERPRISE)

### Changed

- README: Updated rule counts to reflect 1000-rule goal
- README: Tier table now shows target distribution (~100/~300/~600/~800/1000)
- README: Added migration guide links in Quick Start section
- Reorganized documentation structure
- `CONTRIBUTING.md`: Updated quick fix requirements documentation
- `ENTERPRISE.md`: Added migration FAQ with links to guides

### Removed

- `doc/PLAN_LINT_RULES_AND_TESTING.md` (replaced by `ROADMAP.md`)
- `doc/SAROPA_LINT_RULES_GUIDE.md` (replaced by `ENTERPRISE.md`)

## [0.1.8] - 2025-01-05

### Added

- Test infrastructure with unit tests (`test/`) and lint rule fixtures (`example/lib/`)
- Unit tests for plugin instantiation
- Lint rule test fixtures for `avoid_hardcoded_credentials`, `avoid_unsafe_collection_methods`, `avoid_unsafe_reduce`
- `TEST_PLAN.md` documenting testing strategy
- CI workflow for GitHub Actions (analyze, format, test)
- Style badge for projects using saropa_lints
- CI status badge in README
- Badge section in README with copy-paste markdown for users
- Migration guide for very_good_analysis users (`doc/guides/migration_from_vga.md`)

### Changed

- Publish script now runs unit tests and custom_lint tests before publishing
- README: More welcoming tone, clearer introduction
- README: Added link to VGA migration guide
- README: Added link to DCM migration guide
- Updated SECURITY.md for saropa_lints package (was templated for mobile app)
- Updated links.md with saropa_lints development resources
- Added `analysis_options.yaml` to exclude `example/` from main project analysis

### Fixed

- Doc reference warnings in rule comments (`[i]`, `[0]`, `[length-1]`)

## [0.1.7] - 2025-01-05

### Fixed

- **Critical**: `getLintRules()` now reads tier configuration from `custom_lint.yaml`
  - Previously ignored `configs` parameter and used hard-coded 25-rule list
  - Now respects rules enabled/disabled in tier YAML files (essential, recommended, etc.)
  - Supports `enable_all_lint_rules: true` to enable all 500+ rules

## [0.1.6] - 2025-01-05

### Fixed

- Updated for analyzer 8.x API (requires `>=8.0.0 <10.0.0`)
  - Reverted `ErrorSeverity` back to `DiagnosticSeverity`
  - Reverted `ErrorReporter` back to `DiagnosticReporter`
  - Reverted `NamedType.name2` back to `NamedType.name`
  - Changed `enclosingElement3` to `enclosingElement`

## [0.1.5] - 2025-01-05

### Fixed

- Fixed `MethodElement.enclosingElement3` error - `MethodElement` requires cast to `Element` for `enclosingElement3` access
- Expanded analyzer constraint to support version 9.x (`>=6.0.0 <10.0.0`)

## [0.1.4] - 2025-01-05

### Fixed

- **Breaking compatibility fix**: Updated all rule files for analyzer 7.x API changes
  - Migrated from `DiagnosticSeverity` to `ErrorSeverity` (31 files)
  - Migrated from `DiagnosticReporter` to `ErrorReporter` (31 files)
  - Updated `NamedType.name` to `NamedType.name2` for AST type access (12 files)
  - Updated `enclosingElement` to `enclosingElement3` (2 files)
  - Fixed `Element2`/`Element` type inference issue
- Suppressed TODO lint warnings in documentation examples

### Changed

- Now fully compatible with `analyzer ^7.5.0` and `custom_lint ^0.8.0`

## [0.1.3] - 2025-01-05

### Fixed

- Removed custom documentation URL so pub.dev uses its auto-generated API docs

## [0.1.2] - 2025-01-05

### Added

- New formatting lint rules:
  - `AvoidDigitSeparatorsRule` - Flag digit separators in numeric literals
  - `FormatCommentFormattingRule` - Enforce consistent comment formatting
  - `MemberOrderingFormattingRule` - Enforce class member ordering
  - `PreferSortedParametersRule` - Prefer sorted parameters in functions
- Export all rule classes for documentation generation
- Automated publish script for pub.dev releases

### Changed

- Renamed `ParametersOrderingRule` to `ParametersOrderingConventionRule`
- Updated README with accurate rule count (497 rules)
- Simplified README messaging and performance guidance

## [0.1.1] - 2024-12-27

### Fixed

- Improved documentation formatting and examples

## [0.1.0] - 2024-12-27

### Added

- Initial release with 475 lint rules
- 5 tier configuration files:
  - `essential.yaml` (~50 rules) - Crash prevention, memory leaks, security
  - `recommended.yaml` (~150 rules) - Performance, accessibility, testing basics
  - `professional.yaml` (~350 rules) - Architecture, documentation, comprehensive testing
  - `comprehensive.yaml` (~700 rules) - Full best practices
  - `insanity.yaml` (~1000 rules) - Every rule enabled
- Rule categories:
  - Accessibility (10 rules)
  - API & Network (7 rules)
  - Architecture (7 rules)
  - Async (20+ rules)
  - Class & Constructor (15+ rules)
  - Code Quality (20+ rules)
  - Collection (15+ rules)
  - Complexity (10+ rules)
  - Control Flow (15+ rules)
  - Debug (5+ rules)
  - Dependency Injection (8 rules)
  - Documentation (8 rules)
  - Equality (10+ rules)
  - Error Handling (8 rules)
  - Exception (10+ rules)
  - Flutter Widget (40+ rules)
  - Formatting (10+ rules)
  - Internationalization (8 rules)
  - Memory Management (7 rules)
  - Naming & Style (20+ rules)
  - Numeric Literal (5+ rules)
  - Performance (25 rules)
  - Record & Pattern (5+ rules)
  - Resource Management (7 rules)
  - Return (10+ rules)
  - Security (8 rules)
  - State Management (10 rules)
  - Structure (10+ rules)
  - Test (15+ rules)
  - Testing Best Practices (7 rules)
  - Type (15+ rules)
  - Type Safety (7 rules)
  - Unnecessary Code (15+ rules)

### Notes

- Built on `custom_lint_builder: ^0.8.0`
- Compatible with Dart SDK >=3.1.0 <4.0.0
- MIT licensed - free for any use
