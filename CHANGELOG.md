# Changelog

All notable changes to this project will be documented in this file.
The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

> **Looking for older changes?**  \
> See [CHANGELOG_ARCHIVE.md](./CHANGELOG_ARCHIVE.md) for versions 0.1.0 through 2.3.8.

## [3.1.1] - 2026-01-12

### New Rules

- **prefer_descriptive_bool_names_strict**: Strict version of bool naming rule for insanity tier. Requires traditional prefixes (`is`, `has`, `can`, `should`). Does not allow action verbs.

### Enhancements

- **prefer_descriptive_bool_names**: Now lenient (professional tier). Allows action verb prefixes (`process`, `sort`, `remove`, etc.) and `value` suffix.

### Bug Fixes

- **require_ios_permission_description**: Fixed false positive on `ImagePicker()` constructor. The rule now only triggers on method calls (`pickImage`, `pickVideo`, etc.) where it can detect the actual source (gallery vs camera).
- **require_ios_face_id_usage_description**: Now checks Info.plist before reporting. Previously always triggered on `LocalAuthentication` usage regardless of whether `NSFaceIDUsageDescription` was already present.
- **AvoidContextAcrossAsyncRule**: Now recognizes mounted-guarded ternary pattern `context.mounted ? context : null` as safe.
- **PreferDocCurlyApostropheRule**: Fixed quick fix not appearing - was searching `precedingComments` instead of `documentationComment`. Renamed from `PreferCurlyApostropheRule` to clarify it only applies to documentation.
- **Missing rule name prefixes**: Fixed 17 rules that were missing the `[rule_name]` prefix in their `problemMessage`. Affected rules: `avoid_future_tostring`, `prefer_async_await`, `avoid_late_keyword`, `prefer_simpler_boolean_expressions`, `avoid_context_in_initstate_dispose`, `avoid_shrink_wrap_in_lists`, `prefer_widget_private_members`, `avoid_hardcoded_locale`, `require_ios_permission_description`, `avoid_getter_prefix`, `prefer_correct_callback_field_name`, `prefer_straight_apostrophe`, `prefer_curly_apostrophe`, `avoid_dynamic`, `no_empty_block`.

---

## [3.1.0] - 2026-01-12

### Enhancements

- **Rule name prefix in messages**: All 1536 rules now prefix `problemMessage` with `[rule_name]` for visibility in VS Code's Problems panel.

### Bug Fixes

- **AvoidContextAfterAwaitInStaticRule**: Now recognizes `context.mounted` guards to prevent false positives.
- **AvoidStoringContextRule**: No longer flags function types that accept `BuildContext` as a parameter (callback signatures).
- **RequireIntlPluralRulesRule**: Only flags `== 1` or `!= 1` patterns, not general int comparisons.
- **AvoidLongRunningIsolatesRule**: Less aggressive on `compute()` - skips when comments indicate foreground use or in StreamTransformer patterns.

---

## [3.0.2] - 2026-01-12

### Bug Fixes

#### Async Context Utils

- **Compound `&&` mounted checks**: Fixed detection of mounted checks in compound conditions. `if (mounted && otherCondition)` now correctly protects the then-branch since short-circuit evaluation guarantees `mounted` is true when the body executes.
- **Nested mounted guards**: Fixed `ContextUsageFinder` to recognize context usage inside nested `if (mounted)` blocks. Previously, patterns like `if (someCondition) { if (context.mounted) context.doThing(); }` would incorrectly flag the inner usage.

#### AvoidUnawaitedFutureRule

- **Lifecycle method support**: Extended safe fire-and-forget detection to include `didUpdateWidget()` and `deactivate()` in addition to `dispose()`. These lifecycle methods are synchronous and subscription cleanup doesn't need to be awaited.
- **onDone callback support**: Added support for `StreamController.close()` in `onDone` and `onError` callbacks. The `onDone` parameter of `Stream.listen()` is `void Function()`, so you cannot await inside it - closing the controller here is standard cleanup for transformed streams.

#### PreferExplicitTypesRule

- **No longer flags `dynamic`**: The rule now only flags `var` and `final` without explicit types. `dynamic` is an explicit type choice (commonly used for JSON handling), not implicit inference like `var`.

#### PreferSnakeCaseFilesRule

- **Multi-part extension support**: Added recognition of common multi-part file extensions used in Dart/Flutter projects: `.io.dart`, `.dto.dart`, `.model.dart`, `.entity.dart`, `.service.dart`, `.repository.dart`, `.controller.dart`, `.provider.dart`, `.bloc.dart`, `.cubit.dart`, `.state.dart`, `.event.dart`, `.notifier.dart`, `.view.dart`, `.widget.dart`, `.screen.dart`, `.page.dart`, `.dialog.dart`, `.utils.dart`, `.helper.dart`, `.extension.dart`, `.mixin.dart`, `.test.dart`, `.mock.dart`, `.stub.dart`, `.fake.dart`.

#### SaropaDiagnosticReporter

- **Fixed zero-width highlight in `atToken`**: The built-in `atToken` method had a bug where `endColumn` equaled `startColumn`, resulting in zero-width diagnostic highlights. Now uses `atOffset` with explicit length to ensure proper span highlighting.

---

## [3.0.1] - 2026-01-12

### Performance Optimizations

#### Content Pre-filtering

- **New `requiredPatterns` getter**: Rules can specify string patterns that must be present for the rule to run.
- **Fast string search**: Checks for patterns BEFORE AST parsing, skipping irrelevant files instantly.
- **Example usage**: A rule checking `Timer.periodic` can return `{'Timer.periodic'}` to skip files without timers.

#### Skip Small Files

- **New `minimumLineCount` getter**: High-cost rules can skip files under a threshold line count.
- **Efficient counting**: Uses fast character scan instead of splitting into lines.
- **Example usage**: Complex nested callback rules can set `minimumLineCount => 50` to skip small files.

#### File Content Caching

- **New `FileContentCache` class**: Tracks file content hashes to detect unchanged files.
- **Rule pass tracking**: Records which rules passed on unchanged files to skip redundant analysis.
- **Impact**: Files that haven't changed between saves can skip re-running passing rules.

### Documentation

- **Updated ROADMAP.md**: Added "Future Optimizations" section with Batch AST Visitors and Lazy Rule Instantiation as planned major refactors.

---

## [3.0.0] - 2026-01-12

### Performance Optimizations

This release focuses on **significant performance improvements** for large codebases. custom_lint is notoriously slow with 1400+ rules, and these optimizations address the main bottlenecks.

#### Tier Set Caching

- **Cached tier rule sets**: Previously, `getRulesForTier()` was rebuilding Set unions on EVERY file analysis. Now tier sets are computed once on first access and cached for all subsequent calls.
- **Impact**: ~5-10x faster tier filtering after first access.

#### Rule Filtering Cache

- **Cached filtered rule list**: Previously, the 1400+ rule list was filtered on every file. Now the filtered list is computed once per analysis session and reused.
- **Impact**: Eliminates O(n) filtering on each of thousands of files.

#### Analyzer Excludes

- **Added comprehensive analyzer excludes** in `analysis_options.yaml`:
  - Generated code (`*.g.dart`, `*.freezed.dart`, `*.gr.dart`, `*.gen.dart`, `*.mocks.dart`, `*.config.dart`)
  - Build artifacts (`build/**`, `.dart_tool/**`)
  - Example files (`example/**`)
- **Impact**: Skips files that can't be manually fixed, reducing analysis time significantly.

#### Rule Timing Instrumentation

- **New `RuleTimingTracker`**: Tracks execution time of each rule to identify slow rules.
- **Enable profiling**: Set `SAROPA_LINTS_PROFILE=true` environment variable.
- **Slow rule logging**: Rules taking >10ms are logged immediately for investigation.
- **Timing report**: Access `RuleTimingTracker.summary` for a report of the 20 slowest rules.

#### Rule Cost Classification

- **New `RuleCost` enum**: `trivial`, `low`, `medium`, `high`, `extreme`
- **1483 rules tagged**: Every rule now has a `cost` getter indicating execution cost.
- **Rule priority ordering**: Rules are sorted by cost so fast rules run first.
- **Impact**: Expensive rules (type resolution, full AST traversal) run last, after quick wins.

#### File Type Filtering

- **New `FileType` enum**: `widget`, `test`, `bloc`, `provider`, `model`, `service`, `general`
- **Early exit optimization**: Rules can declare `applicableFileTypes` to skip non-matching files entirely.
- **377 rules with file type filtering**: Widget rules skip non-widget files, test rules skip non-test files, etc.
- **`FileTypeDetector`**: Caches file type detection per file path for fast repeated access.
- **Impact**: Widget-specific rules skip ~80% of files in typical projects.

#### Project Context Caching

- **New `ProjectContext` class**: Caches project root detection and pubspec parsing.
- **One-time parsing**: Pubspec.yaml is parsed once per project, not per file.
- **Impact**: Eliminates redundant file I/O across 1400+ rules.

### Documentation

- **Added performance tips to README**: Guidance on using lower tiers during development for faster iteration.
- **Tier speed comparison**: Documented the performance impact of each tier level.
- **Updated CONTRIBUTING.md**: Added rule author guidance for `cost` and `applicableFileTypes` getters.

### New Rules

- **`prefer_expanded_at_call_site`**: Warns when a widget's `build()` method returns `Expanded`/`Flexible` directly. Returning these widgets couples the widget to Flex parents; if later wrapped with Padding etc., it will crash. Better to let the caller add `Expanded` where needed. **Quick fix available:** Adds HACK comment to mark for manual refactoring. (WARNING, recommended tier)

### Improved Rules

- **`avoid_expanded_outside_flex`**: Enhanced documentation explaining false positive cases (widgets returning Expanded that are used directly in Flex) and design guidance for preferring Expanded at call sites.

### Breaking Changes

None. All changes are backwards-compatible performance improvements.

---

## [2.7.0] - 2026-01-12

### Added

#### Stylistic/Opinionated Lint Rules (92 rules)

**IMPORTANT**: These rules are **not included in any tier by default**. They express team style preferences where valid arguments exist for opposing approaches. Enable them individually based on your team's style guide.

**Widget Style Rules (11 rules)** - `stylistic_widget_rules.dart`
- **`prefer_sized_box_over_container`**: Prefer SizedBox over Container when only setting dimensions. (INFO)
- **`prefer_container_over_sized_box`**: Opposite - prefer Container for consistency. (INFO)
- **`prefer_text_rich_over_richtext`**: Prefer Text.rich over RichText widget. (INFO)
- **`prefer_richtext_over_text_rich`**: Opposite - prefer RichText for complex spans. (INFO)
- **`prefer_edge_insets_symmetric`**: Prefer EdgeInsets.symmetric over LTRB when applicable. (INFO)
- **`prefer_edge_insets_only`**: Prefer EdgeInsets.only for explicit padding. (INFO)
- **`prefer_const_widgets`**: Prefer const constructors for widgets. (INFO)
- **`prefer_builder_over_closure`**: Prefer Builder widgets over inline closures in build. (INFO)
- **`prefer_closure_over_builder`**: Opposite - prefer closures for simplicity. (INFO)
- **`prefer_fractionally_sized_box`**: Prefer FractionallySizedBox over MediaQuery calculations. (INFO)
- **`prefer_media_query_over_fractional`**: Opposite - prefer explicit MediaQuery. (INFO)

**Null & Collection Style Rules (14 rules)** - `stylistic_null_collection_rules.dart`
- **`prefer_if_null_operator`**: Prefer `??` over ternary null checks. (INFO)
- **`prefer_ternary_over_if_null`**: Opposite - prefer ternary for explicitness. (INFO)
- **`prefer_null_aware_assignment`**: Prefer `??=` over if-null assignment patterns. (INFO)
- **`prefer_explicit_null_assignment`**: Opposite - prefer explicit null checks. (INFO)
- **`prefer_spread_operator`**: Prefer spread operator `...` over addAll. (INFO)
- **`prefer_add_all_over_spread`**: Opposite - prefer addAll for clarity. (INFO)
- **`prefer_collection_literals`**: Prefer `[]`, `{}` over `List()`, `Map()`. (INFO)
- **`prefer_constructor_over_literal`**: Opposite - prefer constructors. (INFO)
- **`prefer_where_over_for_if`**: Prefer where/map over for-if loops. (INFO)
- **`prefer_for_loop_over_functional`**: Opposite - prefer imperative loops. (INFO)
- **`prefer_cascade_notation`**: Prefer cascade `..` for multiple operations on same object. (INFO)
- **`prefer_separate_calls_over_cascade`**: Opposite - prefer separate method calls. (INFO)
- **`prefer_final_in_for_each`**: Prefer final in for-each loops. (INFO)
- **`prefer_var_in_for_each`**: Opposite - prefer var for mutability. (INFO)

**Control Flow & Async Rules (14 rules)** - `stylistic_control_flow_rules.dart`
- **`prefer_early_return`**: Prefer early return over nested if-else. (INFO)
- **`prefer_single_exit_point`**: Opposite - prefer structured single exit. (INFO)
- **`prefer_switch_expression`**: Prefer switch expressions over statements. (INFO)
- **`prefer_switch_statement_over_expression`**: Opposite - prefer statements. (INFO)
- **`prefer_pattern_matching`**: Prefer pattern matching over manual type checks. (INFO)
- **`prefer_manual_type_checks`**: Opposite - prefer explicit is/as checks. (INFO)
- **`prefer_ternary_over_if_else`**: Prefer ternary for simple conditionals. (INFO)
- **`prefer_if_else_over_ternary`**: Opposite - prefer if-else for readability. (INFO)
- **`prefer_guard_clauses`**: Prefer guard clauses at start of methods. (INFO)
- **`prefer_positive_conditions`**: Opposite - prefer positive condition flow. (INFO)
- **`prefer_async_only_when_awaiting`**: Warn when async function doesn't contain await. (INFO)
- **`prefer_await_over_then`**: Prefer await over .then() chains. (INFO)
- **`prefer_then_over_await`**: Opposite - prefer functional .then() style. (INFO)
- **`prefer_sync_over_async_where_possible`**: Prefer sync when no await needed. (INFO)

**Whitespace & Constructor Rules (18 rules)** - `stylistic_whitespace_constructor_rules.dart`
- **`prefer_blank_line_before_return`**: Prefer blank line before return statements. (INFO)
- **`prefer_no_blank_line_before_return`**: Opposite - prefer compact returns. (INFO)
- **`prefer_blank_line_after_declarations`**: Prefer blank line after variable declarations. (INFO)
- **`prefer_compact_declarations`**: Opposite - prefer compact variable sections. (INFO)
- **`prefer_blank_line_between_members`**: Prefer blank line between class members. (INFO)
- **`prefer_compact_class_body`**: Opposite - prefer compact class bodies. (INFO)
- **`prefer_trailing_commas`**: Prefer trailing commas in multi-line. (INFO)
- **`prefer_no_trailing_commas`**: Opposite - prefer no trailing commas. (INFO)
- **`prefer_super_parameters`**: Prefer super parameters over super.x in constructor body. (INFO)
- **`prefer_explicit_super_calls`**: Opposite - prefer explicit super. calls. (INFO)
- **`prefer_initializing_formals`**: Prefer this.x parameters over assignment. (INFO)
- **`prefer_explicit_field_assignment`**: Opposite - prefer explicit assignments. (INFO)
- **`prefer_factory_constructors`**: Prefer factory for conditional construction. (INFO)
- **`prefer_assertion_constructors`**: Opposite - prefer assertions in regular constructors. (INFO)
- **`prefer_named_constructors`**: Prefer named constructors over positional parameters. (INFO)
- **`prefer_unnamed_constructors`**: Opposite - prefer simple unnamed constructors. (INFO)
- **`prefer_const_constructors_in_immutables`**: Prefer const in immutable classes. (INFO)
- **`prefer_mutable_constructors`**: Opposite - allow mutable patterns. (INFO)

**Error Handling & Testing Style Rules (13 rules)** - `stylistic_error_testing_rules.dart`
- **`prefer_specific_exceptions`**: Prefer specific exception types over Exception/Error. (INFO)
- **`prefer_generic_exceptions`**: Opposite - prefer generic for catch-all. (INFO)
- **`prefer_rethrow`**: Prefer rethrow over throw e. (INFO)
- **`prefer_throw_over_rethrow`**: Opposite - prefer explicit throw for modification. (INFO)
- **`prefer_on_clause`**: Prefer on TypeError catch over generic catch. (INFO)
- **`prefer_catch_over_on`**: Opposite - prefer catch for simplicity. (INFO)
- **`prefer_aaa_test_structure`**: Prefer Arrange-Act-Assert comments in tests. (INFO)
- **`prefer_gwt_test_structure`**: Opposite - prefer Given-When-Then comments. (INFO)
- **`prefer_expect_over_assert`**: Prefer expect() matchers over assert in tests. (INFO)
- **`prefer_assert_over_expect`**: Opposite - prefer assert for simplicity. (INFO)
- **`prefer_test_description_prefix`**: Prefer should/when/it prefixes in test names. (INFO)
- **`prefer_descriptive_test_names`**: Opposite - prefer full sentence descriptions. (INFO)
- **`prefer_single_expectation_per_test`**: Prefer one expect per test. (INFO)

**Additional Style Rules (22 rules)** - `stylistic_additional_rules.dart`
- **`prefer_string_interpolation`**: Prefer interpolation over concatenation. (INFO)
- **`prefer_string_concatenation`**: Opposite - prefer explicit concatenation. (INFO)
- **`prefer_single_quotes`**: Prefer single quotes for strings. (INFO)
- **`prefer_double_quotes`**: Opposite - prefer double quotes. (INFO)
- **`prefer_grouped_imports`**: Prefer imports grouped by type (dart/package/relative). (INFO)
- **`prefer_flat_imports`**: Opposite - prefer flat import list. (INFO)
- **`prefer_fields_before_methods`**: Prefer fields declared before methods. (INFO)
- **`prefer_methods_before_fields`**: Opposite - prefer methods first. (INFO)
- **`prefer_static_members_first`**: Prefer static members before instance members. (INFO)
- **`prefer_instance_members_first`**: Opposite - prefer instance first. (INFO)
- **`prefer_public_members_first`**: Prefer public members before private. (INFO)
- **`prefer_private_members_first`**: Opposite - prefer private first. (INFO)
- **`prefer_explicit_types`**: Prefer explicit type annotations over var. (INFO)
- **`prefer_var_keyword`**: Opposite - prefer var for inferred types. (INFO)
- **`prefer_dynamic_over_object`**: Prefer dynamic over Object? for unknown types. (INFO)
- **`prefer_object_over_dynamic`**: Opposite - prefer Object? for type safety. (INFO)
- **`prefer_lower_camel_case_constants`**: Prefer lowerCamelCase for constants. (INFO)
- **`prefer_screaming_case_constants`**: Opposite - prefer SCREAMING_CASE. (INFO)
- **`prefer_short_variable_names`**: Prefer short names for short-lived variables. (INFO)
- **`prefer_descriptive_variable_names`**: Opposite - prefer descriptive names. (INFO)
- **`prefer_explicit_this`**: Prefer explicit this. for field access. (INFO)
- **`prefer_implicit_boolean_comparison`**: Prefer `if (isValid)` over `if (isValid == true)`. (INFO)
- **`prefer_explicit_boolean_comparison`**: Opposite - prefer explicit comparisons for nullable. (INFO)

### Changed

- Updated rule counts in README.md (1360+ → 1450+)
- Updated pubspec.yaml version to 2.7.0
- Updated analysis_options_template.yaml with all 92 stylistic rules

## [2.6.0] - 2026-01-12

### Added

#### New Lint Rules (23 rules from ROADMAP_NEXT)

**Code Quality Rules (1 rule)**
- **`prefer_returning_conditional_expressions`**: Warns when if/else blocks only contain return statements. Use ternary expression or direct return. **Quick fix available.** (INFO)

**Riverpod Rules (2 rules)**
- **`prefer_riverpod_auto_dispose`**: Warns when providers don't use `.autoDispose` modifier. Prevents memory leaks from retained providers. (INFO)
- **`prefer_riverpod_family_for_params`**: Warns when `StateProvider<T?>` with `=> null` initializer is used for parameterized data. Use `.family` modifier instead. (INFO)

**GetX Rules (2 rules)**
- **`avoid_getx_global_navigation`**: Warns when `Get.to()`, `Get.off()`, etc. are used outside widgets. Hurts testability. (WARNING)
- **`require_getx_binding_routes`**: Warns when `GetPage` is created without `binding:` parameter. (INFO)

**Dio HTTP Rules (3 rules)**
- **`require_dio_response_type`**: Warns when Dio `download()` is called without explicit `responseType`. (INFO)
- **`require_dio_retry_interceptor`**: Warns when `Dio()` is created without retry interceptor. (INFO)
- **`prefer_dio_transformer`**: Warns when `Dio()` is created without custom transformer for background parsing. (INFO)

**GoRouter Rules (3 rules)**
- **`prefer_shell_route_shared_layout`**: Warns when `GoRoute` builder includes `Scaffold` with `AppBar`. Use `ShellRoute` instead. (INFO)
- **`require_stateful_shell_route_tabs`**: Warns when `ShellRoute` with tab-like navigation should use `StatefulShellRoute`. (INFO)
- **`require_go_router_fallback_route`**: Warns when `GoRouter` is created without `errorBuilder` or `errorPageBuilder`. (INFO)

**SQLite Rules (2 rules)**
- **`prefer_sqflite_singleton`**: Warns when `openDatabase()` is called outside a singleton pattern. (INFO)
- **`prefer_sqflite_column_constants`**: Warns when string literals are used for column names in database queries. (INFO)

**Freezed Rules (2 rules)**
- **`require_freezed_json_converter`**: Warns when Freezed classes with DateTime/Color fields lack `JsonConverter`. (INFO)
- **`require_freezed_lint_package`**: Warns when project uses Freezed but doesn't import `freezed_lint`. (INFO)

**Geolocation Rules (2 rules)**
- **`prefer_geolocator_accuracy_appropriate`**: Warns when `LocationAccuracy.high` is used. Consider lower accuracy to save battery. (INFO)
- **`prefer_geolocator_last_known`**: Warns when `getCurrentPosition` with low accuracy could use `getLastKnownPosition`. (INFO)

**Resource Management Rules (1 rule)**
- **`prefer_image_picker_multi_selection`**: Warns when `pickImage()` is called inside a loop. Use `pickMultiImage()`. (INFO)

**Notification Rules (1 rule)**
- **`require_notification_action_handling`**: Warns when notification actions are defined without handler setup. (INFO)

**Error Handling Rules (1 rule)**
- **`require_finally_cleanup`**: Warns when cleanup code (close/dispose) is in catch block instead of finally. (INFO)

**DI Rules (1 rule)**
- **`require_di_scope_awareness`**: Warns about potential scope mismatches in GetIt registration (stateful as singleton, expensive as factory). (INFO)

**Equatable Rules (3 rules)**
- **`require_deep_equality_collections`**: Warns when List/Set/Map fields in Equatable props are compared by reference. (WARNING)
- **`avoid_equatable_datetime`**: Warns when DateTime fields in Equatable props may cause flaky equality. (WARNING)
- **`prefer_unmodifiable_collections`**: Warns when collection fields in Equatable/State classes could be mutated externally. (INFO)

**Hive Rules (1 rule)**
- **`prefer_hive_value_listenable`**: Warns when `setState()` is called after Hive operations. Use `box.listenable()`. (INFO)

### Changed

- Updated rule counts in README.md (1340+ → 1360+)
- Updated pubspec.yaml version to 2.6.0

## [2.5.0] - 2026-01-12

### Changed

- **`avoid_context_across_async`**: Improved detection logic using proper AST type checking instead of string matching. Now correctly reports context usage in else-branch of `if (mounted)` blocks. Added quick fix to insert `if (!mounted) return;` guard.
- **`use_setstate_synchronously`**: Refactored to use shared mounted-check utilities for consistency
- **`avoid_scaffold_messenger_after_await`**: Refactored to use shared await detection utilities
- **`require_ios_permission_description`**: Now **actually reads Info.plist** to verify if required permission keys are present. Only reports warnings when keys are genuinely missing, eliminating false positives. Reports specific missing key names in the error message. **Smart ImagePicker detection**: analyzes the `source:` parameter to determine if `ImageSource.gallery` or `ImageSource.camera` is used, requiring only the relevant permission (`NSPhotoLibraryUsageDescription` or `NSCameraUsageDescription`) instead of both.

### Added

#### New Lint Rules (17 rules)

**Code Quality Rules (1 rule)**
- **`no_boolean_literal_compare`**: Warns when comparing boolean expressions to `true` or `false` literals (e.g., `if (x == true)`). Use the expression directly or negate it. **Quick fix available.** (INFO)

**JSON Serialization Rules (1 rule)**
- **`avoid_not_encodable_in_to_json`**: Warns when `toJson()` methods return non-JSON-encodable types (DateTime, Function, Widget, etc.). **Quick fix available** for DateTime → `.toIso8601String()`. (WARNING)

**Dependency Injection Rules (1 rule)**
- **`prefer_constructor_injection`**: Warns when setter/method injection is used instead of constructor injection. Flags `late` fields for service types, setter methods for dependencies, and `init()`/`configure()` methods. (INFO)

**Async Performance Rules (1 rule)**
- **`prefer_future_wait`**: Warns when sequential independent awaits could run in parallel with `Future.wait()`. Detects dependency chains to avoid false positives. (INFO)

**Testing Best Practices Rules (6 rules)**
- **`prefer_test_find_by_key`**: Warns when `find.byType` is used instead of `find.byKey` in widget tests. Keys are more reliable. (INFO)
- **`prefer_setup_teardown`**: Warns when test setup code is duplicated 3+ times. Use `setUp()`/`tearDown()` instead. (INFO)
- **`require_test_description_convention`**: Warns when test descriptions don't follow conventions (should explain what is tested and expected behavior). (INFO)
- **`prefer_bloc_test_package`**: Suggests using `blocTest()` from `bloc_test` package for Bloc testing. (INFO)
- **`prefer_mock_verify`**: Warns when `when()` mock setup is used without `verify()` to check method was called. (INFO)
- **`require_error_logging`**: Warns when catch blocks don't log errors. Silent failures are hard to debug. (INFO)

**State Management Rules (7 rules)**
- **`prefer_change_notifier_proxy`**: Warns when `Provider.of` is used without `listen: false` in callbacks. Use `context.read()` instead. (INFO)
- **`prefer_selector_widget`**: Warns when `Consumer` rebuilds entire subtree. Consider `Selector` for targeted rebuilds. (INFO)
- **`require_bloc_event_sealed`**: Warns when Bloc event hierarchy uses `abstract class` instead of `sealed class` for Dart 3+ exhaustive pattern matching. (INFO)
- **`require_bloc_repository_abstraction`**: Warns when Bloc depends on concrete repository implementations (e.g., `FirebaseUserRepository`) instead of abstract interfaces. (INFO)
- **`avoid_getx_global_state`**: Warns when `Get.put()`/`Get.find()` is used for global state. Use `GetBuilder` with `init:` parameter instead. (INFO)
- **`prefer_bloc_transform`**: Warns when search/input Bloc events lack debounce/throttle transformer. (INFO)

#### Other Additions

- **`info_plist_utils.dart`**: New utility for smart Info.plist checking - finds project root, caches parsed content per project, checks for specific permission keys

- **`require_cache_key_determinism`**: Added quick fix that inserts HACK comment for manual cache key review
- **`avoid_exception_in_constructor`**: Added quick fix that inserts HACK comment suggesting factory constructor conversion
- **`require_permission_permanent_denial_handling`**: Added quick fix that inserts TODO comment for permanent denial handling
- **`avoid_builder_index_out_of_bounds`**: Added quick fix that inserts TODO comment for bounds check
- **Alias**: Added `avoid_using_context_after_dispose` as alias for `avoid_context_across_async` and `avoid_context_in_initstate_dispose`
- **Test fixtures**: Added `error_handling_v2311_fixture.dart` with test cases for v2.3.11 error handling rules (`avoid_exception_in_constructor`, `require_cache_key_determinism`, `require_permission_permanent_denial_handling`)

### Fixed

- **`require_ios_face_id_usage_description`**: Fixed false positives from overly broad method name matching. Previously flagged any `authenticate()` call (e.g., Google Sign-In). Now uses proper AST type resolution via `staticType?.element?.name` to verify the receiver is `LocalAuthentication` from the `local_auth` package.
- **`require_cache_key_determinism`**: Fixed false positives from substring matching. Now uses regex with word boundaries to avoid matching variable names like `myHashCode`, `userUuid`. Removed overly generic `generateId(` pattern.
- **`avoid_builder_index_out_of_bounds`**: Improved detection to verify bounds check is on the SAME list being accessed. Previously would miss cases where `otherList.length` was checked but `items[index]` was accessed.
- **Shared utilities**: Created `async_context_utils.dart` with reusable mounted-check and await detection logic

### Removed

- **ROADMAP**: Removed `avoid_using_context_after_dispose` (now covered by `avoid_context_across_async` + `avoid_context_in_initstate_dispose`)

## [2.4.2] - 2026-01-11

### Changed

- Minor doc header escaping in ios_rules.dart

## [2.4.1] - 2026-01-11

### Changed

- Minor doc header escaping of `Provider.of<T>(context)`

## [2.4.0] - 2026-01-11

### Added

#### Apple Platform Rules (104 rules)

This release adds comprehensive iOS and macOS platform rules to help Flutter developers build apps that pass App Store review, handle platform requirements correctly, and provide native user experiences.

See the [Apple Platform Rules Guide](https://github.com/saropa/saropa_lints/blob/main/doc/guides/apple_platform_rules.md) for detailed documentation.

**iOS Core Rules (14 rules)**
- **`prefer_ios_safe_area`**: Warns when Scaffold body doesn't use SafeArea. Content may be hidden by iOS notch or Dynamic Island. (INFO)
- **`avoid_ios_hardcoded_status_bar`**: Warns when hardcoded status bar heights (20, 44, 47, 59) are used. Use MediaQuery.padding.top instead. (WARNING)
- **`prefer_ios_haptic_feedback`**: Suggests adding haptic feedback for important button interactions on iOS devices. (INFO)
- **`require_ios_platform_check`**: Warns when iOS-specific MethodChannel calls lack Platform.isIOS guard. (WARNING)
- **`avoid_ios_background_fetch_abuse`**: Warns when Future.delayed exceeds iOS 30-second background limit. (WARNING)
- **`require_apple_sign_in`**: Warns when apps use third-party login without Sign in with Apple. App Store rejection per Guidelines 4.8. (ERROR)
- **`require_ios_background_mode`**: Reminds to add iOS background capabilities when using background task APIs. (INFO)
- **`avoid_ios_13_deprecations`**: Warns when deprecated iOS 13+ APIs (UIWebView, UIAlertView) are detected. (WARNING)
- **`avoid_ios_simulator_only_code`**: Warns when iOS Simulator-only patterns are detected in production code. (WARNING)
- **`require_ios_minimum_version_check`**: Warns when iOS version-specific APIs are used without version checks. (INFO)
- **`avoid_ios_deprecated_uikit`**: Warns when deprecated UIKit APIs are used in platform channel code. (WARNING)
- **`require_ios_dynamic_island_safe_zones`**: Warns when fixed top padding doesn't account for Dynamic Island. (WARNING)
- **`require_ios_deployment_target_consistency`**: Warns when iOS 15+ APIs are used without version checks. (WARNING)
- **`require_ios_scene_delegate_awareness`**: Suggests using Flutter's unified lifecycle handler for iOS 13+ Scene Delegate. (INFO)

**App Store Review Rules (12 rules)**
- **`require_ios_app_tracking_transparency`**: Warns when ad SDKs are used without ATT implementation. Required for iOS 14.5+. (ERROR)
- **`require_ios_face_id_usage_description`**: Warns when biometric auth is used without NSFaceIDUsageDescription. (WARNING)
- **`require_ios_photo_library_add_usage`**: Warns when photo saving APIs lack NSPhotoLibraryAddUsageDescription. (WARNING)
- **`avoid_ios_in_app_browser_for_auth`**: Warns when OAuth is loaded in WebView. Google/Apple block this for security. (ERROR)
- **`require_ios_app_review_prompt_timing`**: Warns when app review is requested too early. (WARNING)
- **`require_ios_review_prompt_frequency`**: Reminds about Apple's 3x per year limit on StoreKit review prompts. (INFO)
- **`require_ios_receipt_validation`**: Warns when in-app purchases lack server-side receipt validation. (WARNING)
- **`require_ios_age_rating_consideration`**: Reminds to verify App Store age rating for WebViews or user-generated content. (INFO)
- **`avoid_ios_misleading_push_notifications`**: Warns when push notification content may violate Apple's guidelines. (INFO)
- **`require_ios_permission_description`**: Warns when permission-requiring APIs lack Info.plist usage descriptions. (WARNING)
- **`require_ios_privacy_manifest`**: Warns when APIs requiring iOS 17+ Privacy Manifest entries are used. (WARNING)
- **`require_https_for_ios`**: Warns when HTTP URLs are used that will be blocked by App Transport Security. (WARNING)

**Security & Authentication Rules (8 rules)**
- **`require_ios_keychain_accessibility`**: Suggests specifying iOS Keychain accessibility level for secure storage. (INFO)
- **`require_ios_keychain_sync_awareness`**: Warns when sensitive keys may sync via iCloud Keychain. (INFO)
- **`require_ios_keychain_for_credentials`**: Warns when credentials are stored in SharedPreferences instead of Keychain. (ERROR)
- **`require_ios_certificate_pinning`**: Suggests SSL certificate pinning for sensitive API endpoints. (INFO)
- **`require_ios_biometric_fallback`**: Reminds to provide fallback authentication for devices without biometrics. (INFO)
- **`require_ios_healthkit_authorization`**: Warns when HealthKit data is accessed without authorization request. (WARNING)
- **`avoid_ios_hardcoded_bundle_id`**: Warns when bundle IDs are hardcoded instead of from configuration. (INFO)
- **`avoid_ios_debug_code_in_release`**: Warns when debug logging may be included in release builds. (INFO)

**Platform Integration Rules (14 rules)**
- **`require_ios_push_notification_capability`**: Reminds to enable Push Notifications capability in Xcode. (INFO)
- **`require_ios_background_audio_capability`**: Reminds to enable Background Modes > Audio capability. (INFO)
- **`require_ios_background_refresh_declaration`**: Reminds about UIBackgroundModes "fetch" in Info.plist. (INFO)
- **`require_ios_app_group_capability`**: Reminds about App Groups capability for extension data sharing. (INFO)
- **`require_ios_siri_intent_definition`**: Reminds about Intent Definition file for Siri Shortcuts. (INFO)
- **`require_ios_widget_extension_capability`**: Reminds about Widget Extension target for Home Screen widgets. (INFO)
- **`require_ios_live_activities_setup`**: Reminds about ActivityKit and Widget Extension setup. (INFO)
- **`require_ios_carplay_setup`**: Reminds about CarPlay entitlement requirements. (INFO)
- **`require_ios_callkit_integration`**: Warns when VoIP call handling lacks CallKit integration. (WARNING)
- **`require_ios_nfc_capability_check`**: Warns when NFC is used without capability check. (WARNING)
- **`require_ios_method_channel_cleanup`**: Warns when MethodChannel handler lacks cleanup in dispose(). (WARNING)
- **`avoid_ios_force_unwrap_in_callbacks`**: Warns when force unwrap is used on MethodChannel results. (WARNING)
- **`require_method_channel_error_handling`**: Warns when MethodChannel.invokeMethod lacks try-catch. (WARNING)
- **`prefer_ios_app_intents_framework`**: Suggests migrating from legacy SiriKit to App Intents framework. (INFO)

**Device & Hardware Rules (8 rules)**
- **`avoid_ios_hardcoded_device_model`**: Warns when device model names are hardcoded. Breaks on new devices. (WARNING)
- **`require_ios_orientation_handling`**: Reminds to configure UISupportedInterfaceOrientations. (INFO)
- **`require_ios_photo_library_limited_access`**: Warns when photo library access may not handle iOS 14+ limited access. (INFO)
- **`avoid_ios_continuous_location_tracking`**: Warns when continuous location tracking uses high accuracy. (INFO)
- **`require_ios_lifecycle_handling`**: Warns when Timer.periodic or subscriptions lack lifecycle handling. (INFO)
- **`require_ios_promotion_display_support`**: Warns when manual frame timing may not adapt to ProMotion 120Hz. (INFO)
- **`require_ios_pasteboard_privacy_handling`**: Warns when clipboard access may trigger iOS 16+ privacy notification. (INFO)
- **`prefer_ios_storekit2`**: Suggests evaluating StoreKit 2 for new IAP implementations. (INFO)

**Data & Storage Rules (6 rules)**
- **`require_ios_database_conflict_resolution`**: Reminds to implement conflict resolution for cloud-synced databases. (INFO)
- **`require_ios_icloud_kvstore_limitations`**: Reminds about iCloud Key-Value Storage 1 MB and 1024 key limits. (INFO)
- **`require_ios_share_sheet_uti_declaration`**: Reminds about UTI declarations for custom file type sharing. (INFO)
- **`require_ios_app_clip_size_limit`**: Warns about App Clip 10 MB size limit. (INFO)
- **`require_ios_ats_exception_documentation`**: Suggests documenting ATS exceptions when HTTP URLs are used. (INFO)
- **`require_ios_local_notification_permission`**: Warns when local notifications are scheduled without permission request. (WARNING)

**Deep Linking Rules (2 rules)**
- **`require_universal_link_validation`**: Reminds to validate iOS Universal Links server configuration. (INFO)
- **`require_ios_universal_links_domain_matching`**: Reminds to verify apple-app-site-association paths match. (INFO)

**macOS Platform Rules (12 rules)**
- **`prefer_macos_menu_bar_integration`**: Suggests using PlatformMenuBar for native macOS menu integration. (INFO)
- **`prefer_macos_keyboard_shortcuts`**: Suggests implementing standard macOS keyboard shortcuts. (INFO)
- **`require_macos_window_size_constraints`**: Warns when macOS apps lack window size constraints. (INFO)
- **`require_macos_window_restoration`**: Suggests implementing window state restoration for better UX. (INFO)
- **`require_macos_file_access_intent`**: Warns when direct file paths are used in sandboxed apps. (INFO)
- **`require_macos_hardened_runtime`**: Warns when operations may require Hardened Runtime entitlements. (INFO)
- **`require_macos_sandbox_entitlements`**: Warns when features require macOS sandbox entitlements. (WARNING)
- **`avoid_macos_deprecated_security_apis`**: Warns when deprecated macOS Security framework APIs are used. (WARNING)
- **`avoid_macos_catalyst_unsupported_apis`**: Warns when APIs unavailable on Mac Catalyst are used. (WARNING)
- **`avoid_macos_full_disk_access`**: Warns when protected paths are accessed directly. (WARNING)
- **`prefer_cupertino_for_ios`**: Suggests Cupertino widgets over Material widgets in Platform.isIOS blocks. (INFO)
- **`require_ios_accessibility_labels`**: Warns when interactive widgets lack Semantics wrapper for VoiceOver. (INFO)

**Background Processing Rules (5 rules)**
- **`avoid_long_running_isolates`**: Warns when Dart isolates perform long operations. iOS terminates isolates after 30 seconds in background. (WARNING)
- **`require_workmanager_for_background`**: Warns when Timer.periodic is used without workmanager. Dart isolates die when app backgrounds. (WARNING)
- **`require_notification_for_long_tasks`**: Warns when long-running tasks may run in background without progress notification. (WARNING)
- **`prefer_background_sync`**: Suggests using BGTaskScheduler for data synchronization instead of manual polling. (INFO)
- **`require_sync_error_recovery`**: Warns when data sync operations don't implement retry/recovery for failed syncs. (WARNING)

**Notification Rules (2 rules)**
- **`prefer_delayed_permission_prompt`**: Warns when permission requests occur in initState. Show context before requesting. (WARNING)
- **`avoid_notification_spam`**: Warns when notifications may be sent in loops or without proper batching. (WARNING)

**In-App Purchase Rules (2 rules)**
- **`require_purchase_verification`**: Warns when purchases lack server-side receipt verification. Prevents IAP fraud. (ERROR)
- **`require_purchase_restoration`**: Warns when IAP implementation lacks restorePurchases. App Store requires restore functionality. (ERROR)

**iOS Platform Enhancement Rules (16 rules)**
- **`avoid_ios_wifi_only_assumption`**: Warns when large downloads don't check connectivity. Users may incur cellular charges. (WARNING)
- **`require_ios_low_power_mode_handling`**: Warns when apps don't adapt behavior for Low Power Mode. (WARNING)
- **`require_ios_accessibility_large_text`**: Warns when fixed text sizes don't support Dynamic Type. (WARNING)
- **`prefer_ios_context_menu`**: Suggests CupertinoContextMenu for long-press context menus on iOS. (INFO)
- **`require_ios_quick_note_awareness`**: Warns when NSUserActivity isn't used. Content may be inaccessible in Quick Note. (INFO)
- **`avoid_ios_hardcoded_keyboard_height`**: Warns when keyboard heights are hardcoded. Use MediaQuery.viewInsets.bottom. (WARNING)
- **`require_ios_multitasking_support`**: Warns when iPad apps may not handle Split View or Slide Over correctly. (WARNING)
- **`prefer_ios_spotlight_indexing`**: Suggests implementing Core Spotlight indexing for searchable content. (INFO)
- **`require_ios_data_protection`**: Warns when sensitive files don't specify FileProtection attributes. (WARNING)
- **`avoid_ios_battery_drain_patterns`**: Warns when code patterns may cause excessive battery drain. (WARNING)
- **`require_ios_entitlements`**: Reminds to add iOS entitlements when using capabilities like Push, iCloud, etc. (INFO)
- **`require_ios_launch_storyboard`**: Reminds that Launch Storyboard is required for App Store submission. (INFO)
- **`require_ios_version_check`**: Warns when iOS version-specific APIs are used without @available checks. (INFO)
- **`require_ios_focus_mode_awareness`**: Suggests setting appropriate interruptionLevel for notifications during Focus Mode. (INFO)
- **`prefer_ios_handoff_support`**: Suggests implementing NSUserActivity for Handoff and Continuity features. (INFO)
- **`require_ios_voiceover_gesture_compatibility`**: Warns when custom gestures may conflict with VoiceOver gestures. (INFO)

**macOS Platform Enhancement Rules (5 rules)**
- **`require_macos_sandbox_exceptions`**: Warns when macOS apps may need sandbox exception entitlements. (WARNING)
- **`avoid_macos_hardened_runtime_violations`**: Warns when code may violate Hardened Runtime requirements. (WARNING)
- **`require_macos_app_transport_security`**: Warns when HTTP URLs may be blocked by macOS App Transport Security. (WARNING)
- **`require_macos_notarization_ready`**: Reminds to verify notarization requirements before distribution. (WARNING)
- **`require_macos_entitlements`**: Reminds to add macOS entitlements when using capabilities. (INFO)

### Changed

- **`avoid_catch_all`**: Simplified to only flag bare `catch` blocks (without `on` clause). The `on Exception catch` detection has been moved to a new separate rule. **Quick fix available:** Adds `on Object` before bare catch.

#### New Error Handling Rule (1 rule)

- **`avoid_catch_exception_alone`**: Warns when `on Exception catch` is used without an `on Object catch` fallback. `on Exception catch` only catches `Exception` subclasses, silently missing all `Error` types (StateError, TypeError, RangeError, etc.) which crash without logging! Allowed if paired with `on Object catch` in the same try statement. **Quick fix available:** Changes `Exception` to `Object`. (WARNING)

#### BuildContext Safety Rules - Tiered Static Method Rules (2 new rules)

The original `avoid_context_in_static_methods` rule has been refined into a tiered system for different strictness levels:

- **`avoid_context_after_await_in_static`** (Essential/ERROR): Warns when BuildContext is used AFTER an await expression in async static methods. This is the truly dangerous case - the widget may have disposed during the async gap, making the context invalid and causing crashes.

- **`avoid_context_in_async_static`** (Recommended/WARNING): Warns when ANY async static method has a BuildContext parameter. Even if context is used before the first await, this pattern is risky and encourages unsafe additions later. **Quick fix available:** Adds `bool Function() isMounted` parameter.

- **`avoid_context_in_static_methods`** (Comprehensive/INFO): Now only warns for SYNC static methods with BuildContext. Async methods are handled by the more specific rules above. Sync methods are generally safe but the pattern is still discouraged.

**Migration:**
- Essential tier users get only the critical `avoid_context_after_await_in_static` rule (ERROR)
- Recommended tier users also get `avoid_context_in_async_static` (WARNING)
- Comprehensive tier users get all three including the INFO-level sync method rule

### Fixed

- **pubspec.yaml**: Shortened package description to comply with pub.dev 180-character limit
- **`require_rethrow_preserve_stack`**: Fixed type comparison error where `Token` was compared to `String`. Now correctly uses `.lexeme` to extract the exception parameter name
- **`avoid_yield_in_on_event`**: Fixed doc comment where `on<Event>` angle brackets were being interpreted as HTML. Wrapped in backticks for proper escaping

## [2.3.11] - 2026-01-11

### Changed

- **`audit_rules.py`**: Now counts and displays the number of quick fixes (DartFix classes) in the statistics output

### Added

#### Test Rules (2 rules)
- **`require_test_widget_pump`**: Warns when widget test interactions (tap, enterText, drag) are not followed by pump() or pumpAndSettle(). Events may not be processed. (ERROR)
- **`require_integration_test_timeout`**: Warns when integration tests don't have a timeout. Long tests can hang CI indefinitely. (WARNING)

#### Hive Database Rules (4 rules)
- **`require_hive_field_default_value`**: Warns when @HiveField on nullable fields lacks defaultValue. Existing data may fail to load after schema changes. (WARNING)
- **`require_hive_adapter_registration_order`**: Warns when Hive.openBox is called before registering adapters. Will cause runtime crash. (ERROR)
- **`require_hive_nested_object_adapter`**: Warns when @HiveField contains custom types without @HiveType annotation. (ERROR)
- **`avoid_hive_box_name_collision`**: Warns when generic Hive box names are used that may cause collisions. (WARNING)

#### Security Rules (2 rules)
- **`avoid_api_key_in_code`**: Warns when API keys appear hardcoded in source code. Keys can be extracted from builds. (ERROR)
- **`avoid_storing_sensitive_unencrypted`**: Warns when sensitive data (tokens, passwords) is stored in unencrypted storage. (ERROR)

#### State Management Rules (3 rules)
- **`avoid_riverpod_notifier_in_build`**: Warns when Notifiers are instantiated in build methods. State is lost on rebuild. (WARNING)
- **`require_riverpod_async_value_guard`**: Suggests using AsyncValue.guard over try-catch in Riverpod providers. (WARNING)
- **`avoid_bloc_business_logic_in_ui`**: Warns when UI code (Navigator, showDialog) is used inside Bloc classes. (WARNING)

#### Navigation Rules (2 rules)
- **`require_url_launcher_encoding`**: Warns when URL strings with interpolation may have unencoded characters. (WARNING)
- **`avoid_nested_routes_without_parent`**: Warns when navigating to deeply nested routes without ensuring parent routes are in stack. (WARNING)

#### Equatable Rules (1 rule)
- **`require_copy_with_null_handling`**: Warns when copyWith methods use ?? operator and can't set nullable fields to null. (WARNING)

#### Internationalization Rules (2 rules)
- **`require_intl_args_match`**: Warns when Intl.message args don't match placeholders in the message. (ERROR)
- **`avoid_string_concatenation_for_l10n`**: Warns when string concatenation is used in Text widgets, breaking l10n word order. (WARNING)

#### Performance Rules (3 rules)
- **`avoid_blocking_database_ui`**: Warns when database operations are performed in build method. Causes UI jank. (WARNING)
- **`avoid_money_arithmetic_on_double`**: Warns when arithmetic is performed on double for money values. Precision issues. (WARNING)
- **`avoid_rebuild_on_scroll`**: Warns when scroll listeners are added in build method. Causes memory leaks. (WARNING)

#### Error Handling Rules (3 rules)
- **`avoid_exception_in_constructor`**: Warns when exceptions are thrown in constructors. Use factory methods instead. (WARNING)
- **`require_cache_key_determinism`**: Warns when cache keys use non-deterministic values like DateTime.now(). (ERROR)
- **`require_permission_permanent_denial_handling`**: Warns when permission requests don't handle permanent denial with settings redirect. (WARNING)

#### Dependency Injection Rules (2 rules)
- **`require_getit_registration_order`**: Warns when GetIt registration order may cause unresolved dependencies. (WARNING)
- **`require_default_config`**: Warns when config/env access doesn't provide default values for missing values. (WARNING)

#### Widget Rules (1 rule)
- **`avoid_builder_index_out_of_bounds`**: Warns when itemBuilder accesses list without bounds check. Index may be out of bounds if list changes. (WARNING)

## [2.3.10] - 2026-01-11

### Added

#### BuildContext Safety Rules (3 rules)
- **`avoid_storing_context`**: Warns when BuildContext is stored in a field. Context may become invalid after widget disposal, causing crashes. (ERROR)
- **`avoid_context_across_async`**: Warns when BuildContext is used after an await without checking `mounted`. Widget may be disposed during async operation. (ERROR)
- **`avoid_context_in_static_methods`**: Warns when BuildContext is passed to static methods. Static methods cannot check `mounted` state. (ERROR)

#### Test Rules (2 rules)
- **`avoid_test_print_statements`**: Warns when print() is used in test files. Use expect() assertions or proper test logging instead. (WARNING)
- **`require_mock_http_client`**: Warns when real HTTP clients are used in test files. Mock HTTP calls to ensure reliable, fast tests. (ERROR)

#### Async Rules (2 rules)
- **`avoid_future_then_in_async`**: Warns when .then() is used inside an async function. Use await for cleaner, more readable code. (WARNING)
- **`avoid_unawaited_future`**: Warns when a Future is returned without being awaited in an async function. May cause silent failures. (ERROR)

#### Forms Rules (3 rules)
- **`require_text_input_type`**: Warns when TextField lacks keyboardType. Set appropriate keyboard for better UX (email, phone, number). (INFO)
- **`prefer_text_input_action`**: Warns when TextField lacks textInputAction. Set action for better keyboard UX (next, done, search). (INFO)
- **`require_form_key_in_stateful_widget`**: Warns when GlobalKey<FormState> is created inside build(). Create keys in initState or as class fields. (ERROR)

#### API/Network Rules (2 rules)
- **`prefer_timeout_on_requests`**: Warns when HTTP requests lack timeout. Add timeout to prevent hanging requests. (WARNING)
- **`prefer_dio_over_http`**: Suggests using Dio over http package for better features like interceptors, cancellation, retries. (INFO)

#### Error Handling Rules (1 rule)
- **`avoid_catch_all`**: Warns when catch block has no exception type. Catch specific exceptions for proper error handling. (ERROR)

#### State Management Rules (2 rules)
- **`avoid_bloc_context_dependency`**: Warns when BuildContext is passed to Bloc constructor. Bloc should not depend on widget lifecycle. (ERROR)
- **`avoid_provider_value_rebuild`**: Warns when Provider.value() creates instance inline. Create instance outside to avoid rebuilds. (WARNING)

#### Lifecycle Rules (1 rule)
- **`require_did_update_widget_check`**: Warns when didUpdateWidget doesn't check if widget properties changed. May cause unnecessary updates. (WARNING)

#### Equatable Rules (1 rule)
- **`require_equatable_copy_with`**: Suggests adding copyWith() method to Equatable classes for immutable updates. (INFO)

#### Notification Rules (1 rule)
- **`avoid_notification_same_id`**: Warns when notifications use same hardcoded ID. Use unique IDs to avoid overwriting. (WARNING)

#### Internationalization Rules (1 rule)
- **`require_intl_plural_rules`**: Warns when Intl.plural() is missing required forms (zero, one, other). Incomplete forms cause i18n issues. (ERROR)

#### Image Rules (2 rules)
- **`prefer_cached_image_cache_manager`**: Suggests providing custom CacheManager to CachedNetworkImage for better cache control. (INFO)
- **`require_image_cache_dimensions`**: Warns when CachedNetworkImage lacks memCacheWidth/Height. Set dimensions to reduce memory usage. (WARNING)

#### Navigation Rules (2 rules)
- **`prefer_url_launcher_uri_over_string`**: Suggests using launchUrl(Uri) over launch(String) for type safety. (INFO)
- **`avoid_go_router_push_replacement_confusion`**: Warns when pushReplacement is used where go() or push() may be intended. (WARNING)

#### Flutter Widget Rules (2 rules)
- **`avoid_stack_without_positioned`**: Warns when Stack has children without Positioned wrapper. Non-positioned children overlay each other. (WARNING)
- **`avoid_expanded_outside_flex`**: Warns when Expanded/Flexible is used outside Row, Column, or Flex. Will cause runtime error. (ERROR)

## [2.3.9] - 2026-01-11

### Added

#### Internationalization Rules (4 rules)
- **`require_intl_date_format_locale`**: Warns when DateFormat is used without explicit locale parameter. Format varies by device/platform.
- **`require_number_format_locale`**: Warns when NumberFormat is used without explicit locale parameter. Decimal separators vary by locale (1,234.56 vs 1.234,56).
- **`avoid_manual_date_formatting`**: Warns when dates are formatted manually using DateTime properties instead of DateFormat.
- **`require_intl_currency_format`**: Warns when currency values are formatted manually with symbols like $, €, £ instead of NumberFormat.currency.

#### Equatable Rules (1 rule)
- **`avoid_mutable_field_in_equatable`**: Warns when Equatable class has non-final fields. Mutable fields break equality contracts. (ERROR)

#### Error Handling Rules (1 rule)
- **`avoid_print_error`**: Warns when print() is used for error logging in catch blocks. Use proper logging frameworks in production.

#### Collection/Widget Rules (1 rule)
- **`require_key_for_collection`**: Warns when widgets in ListView.builder, GridView.builder lack a Key parameter. May cause inefficient rebuilds or state loss.

#### Database Rules (2 rules)
- **`avoid_hive_field_index_reuse`**: Warns when @HiveField indices are duplicated within a class. Data corruption will occur. (ERROR)
- **`avoid_sqflite_reserved_words`**: Warns when SQLite reserved words (ORDER, GROUP, SELECT, etc.) are used as column names without escaping.

---

## [2.3.8] and Earlier
For details on the initial release and versions 0.1.0 through 1.6.0, please refer to [CHANGELOG_ARCHIVE.md](./CHANGELOG_ARCHIVE.md).
