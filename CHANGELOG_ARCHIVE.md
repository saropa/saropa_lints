# Changelog Archive

<!-- cspell:disable -->

Archived releases 0.1.0 through 4.9.0. See [CHANGELOG.md](https://github.com/saropa/saropa_lints/blob/main/CHANGELOG.md) for the latest versions.

---
## [4.9.0]

### Added

- **Automatic ignore quick fixes for all rules**: Every rule extending `SaropaLintRule` now automatically provides two quick fixes: "Ignore 'rule_name' for this line" (inserts `// ignore: rule_name` above the violation with matching indentation) and "Ignore 'rule_name' for this file" (inserts `// ignore_for_file: rule_name` after header comments). This enables one-click suppression for any lint violation. Rules can disable this via `includeIgnoreFixes => false` for critical security rules. New `customFixes` getter allows rules to provide specific fixes while retaining ignore fixes. Insertion logic respects existing ignore_for_file comments (groups them together) and copyright/license headers (inserts after, not before).

- **Quick fixes for 26 additional rules**: Added automated quick fix support for frequently triggered rules to enable one-click corrections. Stylistic: `prefer_if_null_over_ternary` (replaces `x != null ? x : d` → `x ?? d`), `prefer_ternary_over_if_null` (replaces `x ?? d` → `x != null ? x : d`), `prefer_where_type_over_where_is` (replaces `.where((e) => e is T)` → `.whereType<T>()`), `prefer_nullable_over_late` (replaces `late Type` → `Type?`), `prefer_rethrow_over_throw_e` (replaces `throw e;` → `rethrow;`). Image: `prefer_image_size_constraints` (adds `cacheWidth`/`cacheHeight`), `require_cached_image_dimensions` (adds `memCacheWidth`/`memCacheHeight`), `prefer_cached_image_fade_animation` (adds `fadeInDuration`), `prefer_image_picker_request_full_metadata` (adds `requestFullMetadata: false`), `avoid_image_picker_large_files` (adds `imageQuality: 85`), `require_image_cache_dimensions` (adds `cacheWidth`/`cacheHeight`). Dependency Injection: `avoid_singleton_for_scoped_dependencies` (changes to `registerFactory` with factory wrapper), `require_typed_di_registration` (adds `<Type>` generic parameter), `avoid_functions_in_register_singleton` (changes to `registerLazySingleton`), `prefer_lazy_singleton_registration` (changes to `registerLazySingleton` with factory wrapper). Class/Constructor: `prefer_const_string_list` (adds `const` keyword), `prefer_declaring_const_constructor` (adds `const` keyword), `prefer_final_class` (adds `final` modifier), `prefer_interface_class` (adds `interface` modifier), `prefer_base_class` (adds `base` modifier). Scroll/List: `avoid_refresh_without_await` (adds `async` keyword), `prefer_item_extent` (adds `itemExtent` parameter), `prefer_prototype_item` (adds `prototypeItem` parameter), `require_key_for_reorderable` (adds `key` parameter), `require_add_automatic_keep_alives_off` (adds `addAutomaticKeepAlives: false`). Control Flow: `prefer_async_only_when_awaiting` (removes unnecessary `async` keyword). All fixes include comprehensive documentation and preserve code formatting.

### Changed

- **DX message quality improvements for 25 medium/low priority rules**: Improved lint message clarity by replacing vague language with specific, actionable problem descriptions. Changes include: (1) Replaced "better performance" with quantified impacts (e.g., "reduces throughput by 10-100x", "causes full table scan", "recalculates layout on every scroll"), (2) Replaced "consider X" suggestions with direct problem statements (e.g., "loads all entries into memory at once", "collects EXIF metadata by default", "prevents garbage collection under memory pressure"), (3) Replaced "should be/have" with consequence explanations (e.g., "shows blank space during load", "locks out users with damaged sensors", "slow code review and refactoring"). Affected rules: `prefer_sqflite_batch`, `require_database_index`, `prefer_firestore_batch_write`, `prefer_marker_clustering`, `prefer_item_extent`, `prefer_lazy_box_for_large`, `prefer_hive_value_listenable`, `prefer_image_size_constraints`, `require_image_loading_placeholder`, `prefer_image_picker_request_full_metadata`, `prefer_weak_references_for_cache`, `prefer_wildcard_for_unused_param`, `require_svg_error_handler`, `prefer_deferred_loading_web`, `require_menu_bar_for_desktop`, `move_records_to_typedefs`, `prefer_sorted_pattern_fields`, `prefer_simpler_patterns_null_check`, `prefer_sorted_record_fields`, `prefer_immutable_provider_arguments`, `prefer_prototype_item`, `require_biometric_fallback`, `prefer_data_masking`, `avoid_screenshot_sensitive`, `prefer_notifier_over_state`.
- **Audit report organization improved**: Refactored audit scripts to reduce repetition and improve report readability.

---
## [4.8.8]

### Added

- **Quick fixes for 9 rules**: Added automated quick fix support for frequently triggered rules to enable one-click corrections. Internationalization: `require_directional_widgets` (converts `EdgeInsets.only(left: x)` → `EdgeInsetsDirectional.only(start: x)` for RTL support), `prefer_intl_name` (adds `name` parameter to `Intl.message()`), `prefer_providing_intl_description` (adds `desc` parameter with TODO), `prefer_providing_intl_examples` (adds `examples` parameter). Stylistic: `prefer_double_quotes` (converts single quotes to double quotes), `prefer_object_over_dynamic` (replaces `dynamic` → `Object?`), `prefer_dynamic_over_object` (replaces `Object?` → `dynamic`). Hive: `prefer_hive_lazy_box` (converts `Hive.openBox()` → `Hive.openLazyBox()` for large collections). Logging: `prefer_logger_over_print` (replaces `print()` → `log()` from dart:developer). All fixes include comprehensive documentation and preserve code formatting.

### Changed

- **Widget rules refactored into 3 focused files**: Split the 18,953-line `flutter_widget_rules.dart` into three thematic categories for improved maintainability and discoverability: `widget_lifecycle_rules.dart` (34 rules for State management, dispose, setState patterns), `widget_layout_rules.dart` (65 rules for layout structure, constraints, rendering), and `widget_patterns_rules.dart` (103 rules for best practices, accessibility, themes, platform-specific patterns). All 202 rules remain functionally identical with no breaking changes. This is a pure code reorganization with no logic modifications.
- **README badges upgraded**: Replaced static badges with dynamic, auto-updating badges organized into logical groups (CI/CD, pub.dev metrics, GitHub activity, technical info). Added popularity, likes, stars, forks, last commit, issues count, Dart SDK version, and Flutter platform badges with appropriate logos. The pub version badge now auto-updates from pub.dev, eliminating the need for manual version updates in documentation.
- **DX message quality improvements for 24 critical/high impact rules**: Achieved 100% pass rate (293/293 high, 61/61 critical) for developer experience message quality audit. Fixed missing consequences (added security/accessibility impact statements), expanded too-short messages to meet 180+ character requirement (added specific failure scenarios and technical details), replaced generic terms with specific types (e.g., "controller" → "animation controller", "widget" → "StatefulWidget", "resource" → "memory and processing resources"), and enhanced correction messages to meet 80+ character requirement with actionable guidance. Affected rules: `avoid_deep_link_sensitive_params`, `avoid_color_only_indicators`, `require_cached_image_dimensions`, `avoid_image_picker_large_files`, `require_notification_initialize_per_platform`, `avoid_unsafe_deserialization`, `require_image_semantics`, `require_vsync_mixin`, `avoid_unassigned_stream_subscriptions`, `avoid_obs_outside_controller`, `require_key_for_collection`, `require_workmanager_constraints`, `prefer_riverpod_auto_dispose`, `require_test_widget_pump`, `avoid_notification_payload_sensitive`, `require_url_validation`, `avoid_bloc_context_dependency`, `avoid_provider_value_rebuild`, `avoid_riverpod_notifier_in_build`, `avoid_bloc_business_logic_in_ui`, `require_mock_http_client`, `avoid_dynamic_json_access`, `require_enum_unknown_value`, `avoid_future_tostring`.

---
## [4.8.7]

### Fixed

- **`avoid_context_across_async` and `avoid_context_after_await_in_static` false positives on mounted ternary guards**: Fixed two issues where safe mounted guard patterns were incorrectly flagged: (1) Ternary guards in catch blocks (`context.mounted ? context : null`) were not detected due to premature AST traversal termination at statement boundaries. (2) Nullable-safe mounted checks (`context?.mounted ?? false ? context : null`) were not recognized. Both patterns now correctly suppress violations.
- **Trailing ignore comments now work for all rules**: Fixed critical bug in `IgnoreUtils._checkTokenCommentsOnLine()` where trailing `// ignore:` comments (same-line format: `final x = y; // ignore: rule_name`) were not detected. Root cause: the function checked if the token was past the target line before examining the token's preceding comments, causing it to miss trailing comments attached to the next line's first token (a common Dart tokenization pattern). The fix reorders the logic to examine comments first, then check token position. Also added statement-level trailing comment detection for cases where the comment is at the end of a statement rather than immediately after the expression. Now properly detects both leading (`// ignore:` on preceding line) and trailing (`// ignore:` on same line) ignore patterns for all rule name formats (underscores and hyphens). Affects all 1677 saropa_lints rules.

---
## [4.8.6]

### Added

- **`TestRelevance` enum**: New three-value enum (`never`, `always`, `testOnly`) for granular control over whether lint rules run on test files. Rules can now declare their test file relationship explicitly instead of using a boolean flag.

### Changed

- **Rules now skip test files by default**: The default `testRelevance` is `TestRelevance.never`, meaning ~1600 production-focused rules no longer fire on test files. This eliminates thousands of irrelevant violations (e.g., `prefer_matcher_over_equals`, `move_variable_closer_to_its_usage`, `no_empty_string`) that were flooding test code. Rules that should run on tests can override `testRelevance => TestRelevance.always`.
- **Backwards-compatible auto-detection**: Rules using `applicableFileTypes => {FileType.test}` are automatically treated as `TestRelevance.testOnly` with no code changes required.
- **DX message quality improvements for 25 rules**: Expanded `problemMessage` text for rules that were below the 180-character minimum or lacked a clear consequence. Each message now explains both the problem and its real-world impact (e.g., memory leaks, crashes, stale UI). Affected rules: `prefer_consumer_widget`, `avoid_bloc_in_bloc`, `avoid_change_notifier_in_widget`, `require_provider_dispose`, `require_error_handling_in_async`, `require_getx_controller_dispose`, `dispose_provider_instances`, `avoid_getx_rx_inside_build`, `avoid_mutable_rx_variables`, `dispose_provided_instances`, `avoid_listen_in_async`, `avoid_equatable_mutable_collections`, `avoid_static_state`, `avoid_provider_in_init_state`, `require_bloc_manual_dispose`, `prefer_bloc_listener_for_side_effects`, `avoid_bloc_context_dependency`, `avoid_provider_value_rebuild`, `avoid_riverpod_notifier_in_build`, `avoid_bloc_business_logic_in_ui`, `require_mock_http_client`, `avoid_dynamic_json_access`, `require_enum_unknown_value`, `require_image_semantics`, `require_badge_semantics`.

### Fixed

- **`avoid_isar_clear_in_production` false positive on non-Isar types**: The rule previously flagged every `.clear()` call regardless of receiver type, producing ERROR-severity false positives on `Map.clear()`, `List.clear()`, `Set.clear()`, `TextEditingController.clear()`, and any other class with a `clear()` method. Now uses static type checking to verify the receiver is an `Isar` instance before reporting.
- **`require_error_case_tests` false positives**: Expanded test name keyword detection to recognize boundary/defensive test patterns (`null`, `empty`, `boundary`, `edge`, `negative`, `fallback`, `missing`) in addition to error keywords. Updated correction message to acknowledge that test files for pure enums, defensive try/catch code, and non-nullable extension methods legitimately have no error-throwing paths.
- **`prefer_setup_teardown` false positive on independent locals**: The rule no longer flags repeated primitive variable declarations (`int count = 0`, `const int iterations = 1000`) as duplicated setup code. Simple literal initializations and const declarations are now excluded from the setup signature comparison, so only meaningful setup (object construction, service initialization) triggers the suggestion.
- **`require_change_notifier_dispose` false positives**: Fixed three categories of false positive: (1) Fields not owned by the class (e.g., controllers received from `Autocomplete` callbacks) are no longer flagged — the rule now uses `_findOwnedFieldsOfType` ownership detection consistent with sibling disposal rules. (2) Generic container types like `Map<K, ScrollController>` no longer match via substring — exact type matching is now used. (3) Extension method disposal wrappers (e.g., `.disposeSafe()`) are now recognized as valid disposal patterns by all disposal rules.

### Deprecated

- **`skipTestFiles` getter**: Replaced by `testRelevance`. The old boolean getter still compiles but is marked `@Deprecated`. Migration: `skipTestFiles => true` is now the default; `skipTestFiles => false` becomes `testRelevance => TestRelevance.always`.

---
## [4.8.5]

### Added

- **`TestRelevance` enum**: New three-value enum (`never`, `always`, `testOnly`) for granular control over whether lint rules run on test files. Rules can now declare their test file relationship explicitly instead of using a boolean flag.

### Changed

- **Rules now skip test files by default**: The default `testRelevance` is `TestRelevance.never`, meaning ~1600 production-focused rules no longer fire on test files. This eliminates thousands of irrelevant violations (e.g., `prefer_matcher_over_equals`, `move_variable_closer_to_its_usage`, `no_empty_string`) that were flooding test code. Rules that should run on tests can override `testRelevance => TestRelevance.always`.
- **Backwards-compatible auto-detection**: Rules using `applicableFileTypes => {FileType.test}` are automatically treated as `TestRelevance.testOnly` with no code changes required.
- **DX message quality improvements for 25 rules**: Expanded `problemMessage` text for rules that were below the 180-character minimum or lacked a clear consequence. Each message now explains both the problem and its real-world impact (e.g., memory leaks, crashes, stale UI). Affected rules: `prefer_consumer_widget`, `avoid_bloc_in_bloc`, `avoid_change_notifier_in_widget`, `require_provider_dispose`, `require_error_handling_in_async`, `require_getx_controller_dispose`, `dispose_provider_instances`, `avoid_getx_rx_inside_build`, `avoid_mutable_rx_variables`, `dispose_provided_instances`, `avoid_listen_in_async`, `avoid_equatable_mutable_collections`, `avoid_static_state`, `avoid_provider_in_init_state`, `require_bloc_manual_dispose`, `prefer_bloc_listener_for_side_effects`, `avoid_bloc_context_dependency`, `avoid_provider_value_rebuild`, `avoid_riverpod_notifier_in_build`, `avoid_bloc_business_logic_in_ui`, `require_mock_http_client`, `avoid_dynamic_json_access`, `require_enum_unknown_value`, `require_image_semantics`, `require_badge_semantics`.

### Fixed

- **`avoid_isar_clear_in_production` false positive on non-Isar types**: The rule previously flagged every `.clear()` call regardless of receiver type, producing ERROR-severity false positives on `Map.clear()`, `List.clear()`, `Set.clear()`, `TextEditingController.clear()`, and any other class with a `clear()` method. Now uses static type checking to verify the receiver is an `Isar` instance before reporting.
- **`require_error_case_tests` false positives**: Expanded test name keyword detection to recognize boundary/defensive test patterns (`null`, `empty`, `boundary`, `edge`, `negative`, `fallback`, `missing`) in addition to error keywords. Updated correction message to acknowledge that test files for pure enums, defensive try/catch code, and non-nullable extension methods legitimately have no error-throwing paths.
- **`prefer_setup_teardown` false positive on independent locals**: The rule no longer flags repeated primitive variable declarations (`int count = 0`, `const int iterations = 1000`) as duplicated setup code. Simple literal initializations and const declarations are now excluded from the setup signature comparison, so only meaningful setup (object construction, service initialization) triggers the suggestion.
- **`require_change_notifier_dispose` false positives**: Fixed three categories of false positive: (1) Fields not owned by the class (e.g., controllers received from `Autocomplete` callbacks) are no longer flagged — the rule now uses `_findOwnedFieldsOfType` ownership detection consistent with sibling disposal rules. (2) Generic container types like `Map<K, ScrollController>` no longer match via substring — exact type matching is now used. (3) Extension method disposal wrappers (e.g., `.disposeSafe()`) are now recognized as valid disposal patterns by all disposal rules.

### Deprecated

- **`skipTestFiles` getter**: Replaced by `testRelevance`. The old boolean getter still compiles but is marked `@Deprecated`. Migration: `skipTestFiles => true` is now the default; `skipTestFiles => false` becomes `testRelevance => TestRelevance.always`.

---
## [4.8.4]

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

## [4.8.3]

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

## [4.8.2]

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
## [4.8.1]

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
## [4.8.0]

### Changed

- **Lazy rule loading for reduced memory usage**: Rules are now instantiated on-demand instead of at compile time. Previously, all 1500+ rules were created as a `const List<LintRule>`, consuming ~4GB of memory regardless of which tier was selected. Now only rules needed for the selected tier are created. For essential tier (~250 rules), this reduces memory usage significantly and eliminates OOM crashes on resource-constrained systems.
  - Rule list changed from `const List<LintRule>` to `final List<LintRule Function()>` factories
  - Factory map built lazily on first access
  - No generated files required - stays in sync automatically when rules are added/removed

---
## [4.7.6]

### Fixed

- **`require_ios_permission_description` false positive on ImagePicker constructor**: Fixed false positives where the rule required both `NSPhotoLibraryUsageDescription` AND `NSCameraUsageDescription` when only `ImagePicker()` was instantiated, before any method was called. The rule now uses smart method-level detection:
  - `ImagePicker()` constructor alone → no warning
  - `picker.pickImage(source: ImageSource.gallery)` → requires only `NSPhotoLibraryUsageDescription`
  - `picker.pickImage(source: ImageSource.camera)` → requires only `NSCameraUsageDescription`
  - `picker.pickImage(source: variable)` → requires both (can't determine statically)

---
## [4.7.5]

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
## [4.7.4]

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
## [4.7.3]

### Added

- **Interactive analysis prompt**: After init completes, prompts user "🔍 Run analysis now? [y/N]" to optionally run `dart run custom_lint` immediately.

### Fixed

- **Progress tracking: misleading percentages**: Fixed bug where progress would show constantly recalibrating percentages (e.g., "130/149 (87%)") when file discovery failed. Now shows simple file count ("X files") when accurate totals aren't available.

- **Progress tracking: rule name prefix spam**: Fixed progress output being prefixed with rule name (e.g., `[require_ios_privacy_manifest]`) for every update. Progress now uses stderr to avoid custom_lint's automatic rule tagging.

---
## [4.7.2]

### Added

- **Custom overrides file**: New `analysis_options_custom.yaml` file for rule customizations that survive `--reset`. Place rule overrides in this file to always apply them regardless of tier or reset.

- **Timestamped backups**: Backup files now include datetime stamp (`yyyymmdd_hhmmss_filename.bak`) for history tracking.

- **Enhanced debugging**: Added version number, file paths, and file size to init script output.

- **Detailed log files**: Init script now writes detailed logs to `reports/yyyymmdd_hhmmss_saropa_lints_init.log` for history and debugging.

### Fixed

- **Init script: false "user customizations" count**: Fixed bug where switching tiers would incorrectly count all tier-changed rules as "user customizations". Now only rules explicitly in the USER CUSTOMIZATIONS section are preserved. Added warning when >50 customizations detected (suggests using `--reset` to fix corrupted config).

---
## [4.7.0]

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
## [4.6.2]

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
## [4.6.1]

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

## [4.6.0]

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

## [4.5.7]

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

## [4.5.6]

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

## [4.5.5]

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
## [4.5.4]

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
## [4.5.3]

### Fixed

- Moved `json2yaml` and added `yaml` to main dependencies in pubspec.yaml to satisfy pub.dev requirements for CLI tools in `bin/`.
  This fixes publishing errors and allows versions above 4.5.0 to be published to pub.dev.

## [4.5.2]

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

## [4.5.1]

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

- Migrated rules 4.2.0 and below to [CHANGELOG_ARCHIVE.md](https://github.com/saropa/saropa_lints/blob/main/CHANGELOG_ARCHIVE.md)

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

## [4.5.0]

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

## [4.4.0]

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

## [4.3.0]

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

## [4.2.3]

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

## [4.2.2]

### Fixed

**Critical bug fixes for rule execution** - Two bugs were causing rules to be silently skipped, resulting in "No issues found" or far fewer issues than expected:

1. **Throttle key missing rule name** - The analysis throttle used `path:contentHash` as a cache key, but didn't include the rule name. When rule A analyzed a file, rules B through Z would see the cache entry and skip the file thinking it was "just analyzed" within the 300ms throttle window. Now uses `path:contentHash:ruleName` so each rule has its own throttle.

2. **Rapid edit mode false triggering** - The adaptive tier switching feature (designed to show only essential rules during rapid IDE saves) was incorrectly triggering during CLI batch analysis. When `dart run custom_lint` ran 268 rules on a file, the edit counter hit 268 in under 2 seconds, triggering "rapid edit mode" and skipping non-essential rules. This check is now disabled for CLI runs.

**Impact**: These bugs affected all users on all platforms. Windows users were additionally affected by path normalization issues fixed in earlier commits.

## [4.2.1]

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

---
## [4.2.0]

### Added

**Config key aliases** - Rules can now define alternate config keys that users can use in `custom_lint.yaml`. This helps when rule names have prefixes (like `enforce_`) that users commonly omit:

```yaml
rules:
  # Both work now:
  - enforce_arguments_ordering: false # canonical name
  - arguments_ordering: false # alias
```

Added aliases for:

- `enforce_arguments_ordering` → `arguments_ordering`
- `enforce_member_ordering` → `member_ordering`
- `enforce_parameters_ordering` → `parameters_ordering`

**41 new lint rules** covering Android platform, in-app purchases, URL launching, permissions, connectivity, geolocation, SQLite, test file handling, and more:

#### Android Platform Rules (android_rules.dart) - 6 rules

- `require_android_permission_request` - Runtime permission not requested before using permission-gated API
- `avoid_android_task_affinity_default` - Multiple activities with default taskAffinity cause back stack issues
- `require_android_12_splash` - Flutter splash may cause double-splash on Android 12+
- `prefer_pending_intent_flags` - PendingIntent without FLAG_IMMUTABLE/FLAG_MUTABLE crashes on Android 12+
- `avoid_android_cleartext_traffic` - HTTP URLs blocked by default on Android 9+
- `require_android_backup_rules` - Sensitive data in SharedPreferences may be backed up

#### In-App Purchase Rules (iap_rules.dart) - 3 rules

- `avoid_purchase_in_sandbox_production` - Hardcoded IAP environment URL causes receipt validation failures
- `require_subscription_status_check` - Premium content shown without verifying subscription status
- `require_price_localization` - Hardcoded prices instead of store-provided localized prices

#### URL Launcher Rules (url_launcher_rules.dart) - 3 rules

- `require_url_launcher_can_launch_check` - launchUrl without canLaunchUrl check
- `avoid_url_launcher_simulator_tests` - URL launcher tests with tel:/mailto: fail on simulator
- `prefer_url_launcher_fallback` - launchUrl without fallback for unsupported schemes

#### Permission Rules (permission_rules.dart) - 3 rules

- `require_location_permission_rationale` - Location permission requested without showing rationale
- `require_camera_permission_check` - Camera initialized without permission check
- `prefer_image_cropping` - Profile image picked without cropping option

#### Connectivity Rules (connectivity_rules.dart) - 1 rule

- `require_connectivity_error_handling` - Connectivity check without error handling

#### Geolocator Rules (geolocator_rules.dart) - 1 rule

- `require_geolocator_battery_awareness` - High-accuracy continuous location tracking without battery consideration

#### SQLite Rules (sqflite_rules.dart) - 1 rule

- `avoid_sqflite_type_mismatch` - SQLite type may not match Dart type (bool vs INTEGER, DateTime vs TEXT)

#### Rules Added to Existing Files - 19 rules

- **firebase_rules.dart**: `require_firestore_index` - Firestore query requires composite index
- **notification_rules.dart**: `prefer_notification_grouping`, `avoid_notification_silent_failure`
- **hive_rules.dart**: `require_hive_migration_strategy`
- **async_rules.dart**: `avoid_stream_sync_events`, `avoid_sequential_awaits`
- **file_handling_rules.dart**: `prefer_streaming_for_large_files`, `require_file_path_sanitization`
- **error_handling_rules.dart**: `require_app_startup_error_handling`, `avoid_assert_in_production`
- **accessibility_rules.dart**: `prefer_focus_traversal_order`
- **ui_ux_rules.dart**: `avoid_loading_flash`
- **performance_rules.dart**: `avoid_animation_in_large_list`, `prefer_lazy_loading_images`
- **json_datetime_rules.dart**: `require_json_schema_validation`, `prefer_json_serializable`
- **forms_rules.dart**: `prefer_regex_validation`
- **package_specific_rules.dart**: `prefer_typed_prefs_wrapper`, `prefer_freezed_for_data_classes`

### Tier Assignments

- **Essential tier:** 14 rules (permissions, security, crashes)
- **Recommended tier:** 10 rules (best practices, UX improvements)
- **Professional tier:** 13 rules (architecture, performance, maintainability)

#### Parameter Safety Rules (code_quality_rules.dart) - 1 new rule + 1 renamed

- `avoid_parameter_mutation` **(NEW)** - Detects when parameter objects are mutated (caller's data modified). Essential tier.
- `avoid_parameter_reassignment` - Renamed from `avoid_mutating_parameters`. Detects parameter variable reassignment. Moved to Stylistic tier.

**Quick fix for `prefer_explicit_type_arguments`** - Adds explicit type arguments to empty collection literals and generic constructor calls.

**Conflicting rule detection** - Warns at analysis startup when mutually exclusive stylistic rules are both enabled:

- `avoid_inferrable_type_arguments` ↔ `prefer_explicit_type_arguments`
- `prefer_relative_imports` ↔ `always_use_package_imports`

**Stylistic rule tier changes** - Removed opposing stylistic rules from Comprehensive tier (now opt-in only):

- `avoid_inferrable_type_arguments` - conflicts with `prefer_explicit_type_arguments`
- `prefer_explicit_type_arguments` - conflicts with `avoid_inferrable_type_arguments`

### Changed

- **Rule renamed**: `avoid_mutating_parameters` → `avoid_parameter_reassignment` (old name kept as deprecated alias in doc header). Tier changed from Recommended to Stylistic to reflect that reassignment is a style preference, not a correctness issue.
- **Heuristics improved** - `require_android_backup_rules` now uses word-boundary matching to avoid false positives on keys like "authentication_method"

### Fixed

- **`function_always_returns_null` false positives on void functions** - The rule was incorrectly flagging void functions that use bare `return;` statements for early exit. Now correctly skips:
  - Functions with explicit `void` return type
  - Functions with `Future<void>` or `FutureOr<void>` return types (including type aliases via resolved type checking)
  - Functions with no explicit return type that only use bare `return;` statements (inferred void)

- **`capitalize_comment_start` code detection overhauled** - The previous regex pattern `[:\.\(\)\[\]\{\};,=>]` was too broad, matching ANY comment containing punctuation (periods, colons, commas). This caused massive false negatives where legitimate prose comments like `// this is important.` were incorrectly skipped as "code". The new pattern specifically detects:
  - Identifier followed by code punctuation: `foo.bar`, `x = 5`
  - Dart keywords at start: `return`, `if (`, `final x`
  - Function calls: `doSomething()`, `list.add(item)`
  - Statement terminators: ends with `;`
  - Annotations: `@override`
  - Arrow functions: `=>`
  - Block delimiters at boundaries: `{`, `}`

  **Quick fix added**: Capitalizes the first letter of the comment.

- **`avoid_commented_out_code` completely overhauled** - Moved from `debug_rules.dart` to `stylistic_rules.dart`. The rule now:
  - Reports at the **actual comment location** (previously reported at file start)
  - Reports **all instances** (previously only reported once per file)
  - Has a **quick fix** to delete the commented-out code
  - Uses shared `CommentPatterns` utility with `capitalize_comment_start`
  - **Tier changed**: Moved from Insanity tier to Stylistic tier (not enabled by default in any tier)

- **New shared utility: `comment_utils.dart`** - Extracted common comment detection patterns into `CommentPatterns` class used by both `capitalize_comment_start` and `avoid_commented_out_code`. This ensures consistent behavior between the two complementary rules.

### Improved

**`prefer_utc_for_storage` rule enhanced:**

- Added 6 new serialization patterns: `toJson`, `toMap`, `serialize`, `encode`, `cache`, `persist`
- Removed `toString()` from method check (reduces false positives from logging/debugging)
- Patterns moved to `static final` class member (compiled once at class load, not per invocation)
- Added comprehensive doc header with multiple BAD/GOOD examples
- **Quick fix added**: Inserts `.toUtc()` before the serialization call

**DX message quality for 60+ lint rules** - Added clear consequences to problem messages explaining _why_ issues matter. Messages now follow the pattern: "[What's wrong]. [Why it matters]." Extended short messages to meet 180-character minimum for critical/high impact rules.

#### Security Rules (11 rules)

- `avoid_sensitive_data_in_clipboard` - "Malicious apps can silently read clipboard contents, stealing passwords, tokens, or API keys"
- `require_certificate_pinning` - "Attackers on the same network can intercept and modify traffic"
- `avoid_generic_key_in_url` - "Exposes credentials in access logs and browser history"
- `avoid_jwt_decode_client` - "Attackers can manipulate decoded claims to bypass permissions"
- `require_logout_cleanup` - "Next user on shared device could access previous user data"
- `require_deep_link_validation` - "Malicious links can inject arbitrary data, leading to crashes or unauthorized access"
- `require_shared_prefs_null_handling` - "Common source of production crashes on first launch or after app updates"
- `require_url_validation` - "Attackers can make your app request internal network resources"
- `prefer_webview_javascript_disabled` - "Malicious scripts can steal data or execute arbitrary code"
- `avoid_unsafe_deserialization` - "Attackers can exploit this to corrupt state or trigger unexpected behavior"
- `avoid_notification_payload_sensitive` - "Anyone nearby can see passwords, tokens, or PII without unlocking"

#### Performance Rules (7 rules)

- `prefer_const_widgets` - "Wastes CPU cycles and battery, slowing down UI rendering"
- `avoid_widget_creation_in_loop` - "Causes jank and high memory usage for long lists"
- `avoid_calling_of_in_build` - "Adds unnecessary overhead that slows down frame rendering"
- `avoid_rebuild_on_scroll` - "Memory leaks and duplicate callbacks that compound over time"
- `avoid_shrinkwrap_in_scrollview` - "Forces all items to render immediately, causing jank"
- `avoid_text_span_in_build` - "Causes visible jank when scrolling or animating"
- `avoid_money_arithmetic_on_double` - "Users may be charged incorrect amounts or see wrong totals"

#### State Management Rules (7 rules)

- `avoid_bloc_in_bloc` - "Makes testing difficult and breaks unidirectional data flow"
- `avoid_static_state` - "Causes flaky tests, unexpected state retention, and hard-to-reproduce bugs"
- `require_bloc_manual_dispose` - "Memory leaks that accumulate over time, eventually crashing the app"
- `prefer_bloc_listener_for_side_effects` - "Causes duplicate navigation, multiple snackbars, or repeated API calls"
- `avoid_bloc_context_dependency` - "Makes Bloc untestable and can cause crashes when context is invalid"
- `avoid_provider_value_rebuild` - "Loses all state and causes infinite rebuild loops"
- `avoid_ref_watch_outside_build` - "Causes missed updates, stale data, and hard-to-debug state inconsistencies"

#### Notification Rules (3 rules)

- `avoid_notification_same_id` - "Users will miss important alerts and messages without any indication"
- `require_notification_initialize_per_platform` - "Users on unsupported platform will never receive notifications"
- `avoid_refresh_without_await` - "Spinner dismisses immediately while data is still loading"

#### Other Rules (7 rules)

- `avoid_image_picker_without_source` - "Users will see an empty dialog and be unable to select images"
- `avoid_unbounded_cache_growth` - "Eventually exhausts device memory and crashes the app"
- `require_websocket_reconnection` - "Users will see stale data or miss real-time updates"
- `require_sqflite_error_handling` - "Operations can fail due to disk full, corruption, or constraint violations"
- `require_avatar_fallback` - "Users will see a broken or blank avatar with no indication of the error"
- `require_image_error_fallback` - "Users see an ugly error state instead of a graceful fallback"
- `require_google_signin_error_handling` / `require_supabase_error_handling` - "Users will see unexpected crashes instead of friendly error messages"

#### Disposal & Memory Rules (10 rules)

- `require_stream_controller_close` - "Listeners accumulate in memory, eventually crashing the app"
- `require_video_player_controller_dispose` - "Video decoder stays active, audio continues, battery drains"
- `require_change_notifier_dispose` - "Disposed widgets remain referenced, crashes on notification"
- `require_receive_port_close` - "Isolate port stays open, memory leaks accumulate"
- `require_socket_close` - "TCP connection stays occupied, file descriptors leak"
- `require_lifecycle_observer` - "Timer drains battery and stale callbacks cause inconsistent state"
- `avoid_closure_memory_leak` - "StatefulWidget leaks memory, setState crashes on unmounted"
- `require_dispose_pattern` - "Controllers leak memory and crash when accessed after disposal"
- `require_hive_box_close` - "File handle stays open, database can't compact"
- `require_getx_permanent_cleanup` - "GetxController remains in memory forever"

#### Additional Security Rules (8 rules)

- `avoid_dynamic_sql` - "Attackers can read, modify, or delete database contents"
- `avoid_ignoring_ssl_errors` - "Man-in-the-middle attackers can intercept all HTTPS traffic"
- `avoid_user_controlled_urls` - "SSRF vulnerability allows attackers to access internal services"
- `require_apple_signin_nonce` - "Replay attacks allow impersonation of the user"
- `require_webview_ssl_error_handling` - "Invalid certificates silently accepted, credentials stolen"
- `prefer_secure_random_for_crypto` - "Predictable seed allows attackers to guess keys and tokens"
- `require_unique_iv_per_encryption` - "Same key+IV breaks confidentiality"
- `avoid_webview_file_access` - "Malicious content can read local files, exposing data"

#### Platform & Context Rules (6 rules)

- `avoid_mixed_environments` - "Debug APIs expose data, development endpoints corrupt production"
- `avoid_storing_context` - "Stored context crashes when widget disposed"
- `avoid_web_only_dependencies` - "Web-only imports crash on mobile and desktop"
- `avoid_future_tostring` - "Logs show useless output, debugging becomes impossible"
- `require_ios_callkit_integration` - "Calls fail to show, App Store rejection"
- `avoid_navigator_push_unnamed` - "Deep linking fails, users can't share screens"

#### Widget & State Rules (7 rules)

- `avoid_obs_outside_controller` - "Observables leak memory without lifecycle management"
- `pass_existing_future_to_future_builder` - "Duplicate network calls, slow UI with visible loading"
- `require_late_initialization_in_init_state` - "Objects recreated on every setState"
- `require_media_loading_state` - "Shows black rectangle or crashes"
- `list_all_equatable_fields` - "Equality checks fail silently"
- `require_openai_error_handling` - "Rate limits crash instead of graceful fallback"
- `prefer_value_listenable_builder` - "Full-widget rebuilds cause jank"

## [4.1.9]

### Changed

**Tier rebalancing** - Redistributed rules across tiers to match tier philosophy:

- **Essential**: Now strictly crash/security/memory-leak rules. Removed style preferences (`prefer_list_first`, `enforce_member_ordering`, `avoid_continue_statement`). Added crash-causing rules from Recommended (`require_getit_registration_order`, `require_default_config`, `avoid_builder_index_out_of_bounds`).

- **Stylistic**: Expanded with ordering/naming rules that were incorrectly in Essential/Recommended. Now 129 rules for formatting, ordering, and naming conventions.

- **Comprehensive**: Expanded from 5 to 51 rules. Added optimization hints and strict patterns from Professional (immutability patterns, type strictness, documentation extras, testing extras).

- **Insanity**: Expanded from 1 to 10 rules. Added pedantic rules like `avoid_object_creation_in_hot_loops`, `prefer_feature_folder_structure`, `avoid_returning_widgets`.

**Documentation**: Updated README tier table with detailed purpose, target user, and examples for each tier.

## [4.1.8]

### Added

**25 new lint rules** focusing on state management, performance, security, caching, testing, and widgets:

#### State Management Rules (v417_state_rules.dart)

- `avoid_riverpod_for_network_only` - `[HEURISTIC]` Riverpod just for network access is overkill
- `avoid_large_bloc` - `[HEURISTIC]` Blocs with too many event handlers (>7) need splitting
- `avoid_overengineered_bloc_states` - `[HEURISTIC]` Too many state subclasses; use single state
- `avoid_getx_static_context` - Get.offNamed/Get.dialog use untestable static context
- `avoid_tight_coupling_with_getx` - `[HEURISTIC]` Heavy GetX usage reduces testability

#### Performance Rules (v417_performance_rules.dart)

- `prefer_element_rebuild` - Conditional widget returns destroy Elements and state
- `require_isolate_for_heavy` - Heavy computation blocks UI (jsonDecode, encrypt)
- `avoid_finalizer_misuse` - Finalizers add GC overhead; prefer dispose()
- `avoid_json_in_main` - `[HEURISTIC]` jsonDecode in async context should use compute()

#### Security Rules (v417_security_rules.dart)

- `avoid_sensitive_data_in_clipboard` - `[HEURISTIC]` Clipboard accessible to other apps
- `require_clipboard_paste_validation` - Validate clipboard content before using
- `avoid_encryption_key_in_memory` - `[HEURISTIC]` Keys as fields can be extracted from dumps

#### Caching Rules (v417_caching_rules.dart)

- `require_cache_expiration` - `[HEURISTIC]` Caches without TTL serve stale data forever
- `avoid_unbounded_cache_growth` - `[HEURISTIC]` Caches without limits cause OOM
- `require_cache_key_uniqueness` - Cache keys need stable hashCode

#### Testing Rules (v417_testing_rules.dart)

- `require_dialog_tests` - Dialogs need pumpAndSettle after showing
- `prefer_fake_platform` - Platform widgets need fakes/mocks in tests
- `require_test_documentation` - `[HEURISTIC]` Complex tests (>15 lines) need comments

#### Widget Rules (v417_widget_rules.dart)

- `prefer_custom_single_child_layout` - Deep positioning nesting should use delegate
- `require_locale_for_text` - DateFormat/NumberFormat need explicit locale
- `require_dialog_barrier_consideration` - `[HEURISTIC]` Destructive dialogs need explicit barrierDismissible
- `prefer_feature_folder_structure` - `[HEURISTIC]` Type-based folders (/blocs/) should be feature-based

#### Misc Rules (v417_misc_rules.dart)

- `require_websocket_reconnection` - `[HEURISTIC]` WebSocket needs reconnection logic
- `require_currency_code_with_amount` - `[HEURISTIC]` Money amounts need currency field
- `prefer_lazy_singleton_registration` - `[HEURISTIC]` Expensive services should be lazy

### Tier Assignments

- **Essential tier:** 3 rules (websocket, clipboard security, cache limits)
- **Recommended tier:** 5 rules (dialog tests, clipboard validation, currency, cache TTL, dialog barrier)
- **Professional tier:** 11 rules (locale, state management, performance, security, caching)
- **Comprehensive tier:** 5 rules (folder structure, element rebuild, finalizer, platform fakes, test docs)
- **Insanity tier:** 1 rule (CustomSingleChildLayout preference)

### Changed

- **Shared utilities extracted** - Added `isInsideIsolate()` and `isInAsyncContext()` to `async_context_utils.dart` to reduce code duplication across performance rules
- **Performance file type filtering** - Added `applicableFileTypes` to `RequireDialogBarrierConsiderationRule` to skip non-widget files
- **Template updated** - Added all 25 new rules to `analysis_options_template.yaml` with proper categorization

## [4.1.7]

### Fixed

**Critical Windows compatibility bugs** that caused rules to not fire on Windows:

- **Cache key incomplete** - Rule filtering cache only checked `tier` and `enableAll`, ignoring individual rule overrides like `- always_fail_test_case: true`. Now includes hash of all rule configurations.

- **Windows path normalization** - File paths used as map keys without normalizing backslashes. On Windows, analyzer provides `d:\src\file.dart` but caches may store `d:/src/file.dart`. Added `normalizePath()` utility and fixed 15+ locations:
  - `IncrementalAnalysisTracker` - disk-persisted cache
  - `RuleBatchExecutor` - batch execution plan
  - `BaselineAwareEarlyExit` - baseline suppression
  - `FileContentCache` - content change detection
  - `FileTypeDetector` - file type classification
  - `ProjectContext.findProjectRoot()` - project detection

### Added

- `normalizePath()` utility function with documentation to prevent future path issues

---

## [4.1.6]

### Added

**14 new lint rules** focusing on logging, platform safety, JSON/API handling, and configuration:

#### Logging Rules (debug_rules.dart)

- `avoid_print_in_release` - print() executes in release builds; guard with kDebugMode
- `require_structured_logging` - Use structured logging instead of string concatenation
- `avoid_sensitive_in_logs` - Detect passwords, tokens, secrets in log calls

#### Platform Rules (platform_rules.dart)

- `require_platform_check` - Platform-specific APIs need Platform/kIsWeb guards
- `prefer_platform_io_conditional` - Platform.isX crashes on web; use kIsWeb first
- `avoid_web_only_dependencies` - dart:html and web-only imports crash on mobile
- `prefer_foundation_platform_check` - Use defaultTargetPlatform in widget code

#### JSON/API Rules (json_datetime_rules.dart)

- `require_date_format_specification` - DateTime.parse may fail on server dates
- `prefer_iso8601_dates` - Use ISO 8601 format for date serialization
- `avoid_optional_field_crash` - JSON field chaining needs null-aware operators
- `prefer_explicit_json_keys` - Use @JsonKey instead of manual mapping

#### Configuration Rules (config_rules.dart)

- `avoid_hardcoded_config` - Hardcoded URLs/keys should use environment variables
- `avoid_mixed_environments` - Don't mix production and development config

#### Lifecycle Rules (lifecycle_rules.dart)

- `require_late_initialization_in_init_state` - Late fields should init in initState(), not build()

### Tier Assignments

- **Essential tier:** 9 rules for critical safety (print in release, platform crashes, etc.)
- **Recommended tier:** 2 rules for best practices
- **Professional tier:** 3 rules for code quality

## [4.1.5]

### Added

**24 new lint rules** focusing on architecture, accessibility, navigation, and internationalization:

#### Dependency Injection Rules

- `avoid_di_in_widgets` - Widgets shouldn't directly use GetIt/service locators
- `prefer_abstraction_injection` - Inject abstract types, not concrete implementations

#### Accessibility Rules

- `prefer_large_touch_targets` - Touch targets should be at least 48dp for WCAG compliance
- `avoid_time_limits` - Short durations (< 5s) disadvantage users needing more time
- `require_drag_alternatives` - Provide button alternatives for drag gestures

#### Flutter Widget Rules

- `avoid_global_keys_in_state` - GlobalKey fields in StatefulWidget cause issues
- `avoid_static_route_config` - Static final router configs limit testability

#### State Management Rules

- `require_flutter_riverpod_not_riverpod` - Flutter apps need flutter_riverpod, not base riverpod
- `avoid_riverpod_navigation` - Navigation logic belongs in widgets, not providers

#### Firebase Rules

- `require_firebase_error_handling` - Firebase async calls need try-catch
- `avoid_firebase_realtime_in_build` - Don't start Firebase listeners in build method

#### Security Rules

- `require_secure_storage_error_handling` - Secure storage needs error handling
- `avoid_secure_storage_large_data` - Large data shouldn't use secure storage

#### Navigation Rules

- `avoid_navigator_context_issue` - Avoid GlobalKey.currentContext in navigation
- `require_pop_result_type` - Navigator.push should specify result type parameter
- `avoid_push_replacement_misuse` - Don't use pushReplacement for detail pages
- `avoid_nested_navigators_misuse` - Nested Navigators need WillPopScope/PopScope
- `require_deep_link_testing` - Routes should support deep links, not just object params

#### Internationalization Rules

- `avoid_string_concatenation_l10n` - String concatenation in Text breaks translations
- `prefer_intl_message_description` - Intl.message needs desc parameter for translators
- `avoid_hardcoded_locale_strings` - Don't hardcode strings that need localization

#### Async Rules

- `require_network_status_check` - Check connectivity before network requests
- `avoid_sync_on_every_change` - Debounce API calls in onChanged callbacks
- `require_pending_changes_indicator` - Notify users when changes haven't synced

### Tier Assignments

- **Recommended tier:** 14 rules for common best practices
- **Professional tier:** 11 rules for stricter architecture/quality standards

## [4.1.4]

### Added

**25 new lint rules** from ROADMAP star priorities:

#### Bloc/Cubit Rules

- `avoid_passing_bloc_to_bloc` - Detects Bloc depending on another Bloc (tight coupling)
- `avoid_passing_build_context_to_blocs` - Warns when BuildContext is passed to Bloc/Cubit
- `avoid_returning_value_from_cubit_methods` - Cubit methods should emit states, not return values
- `require_bloc_repository_injection` - Blocs should receive repositories via constructor injection
- `prefer_bloc_hydration` - Suggests HydratedBloc for persistent state instead of SharedPreferences

#### GetX Rules

- `avoid_getx_dialog_snackbar_in_controller` - UI dialogs shouldn't be called from controllers
- `require_getx_lazy_put` - Prefer lazyPut for efficient GetX dependency injection

#### Hive/SharedPreferences Rules

- `prefer_hive_lazy_box` - Use LazyBox for potentially large collections
- `avoid_hive_binary_storage` - Don't store large binary data in Hive
- `require_shared_prefs_prefix` - Set prefix to avoid key conflicts
- `prefer_shared_prefs_async_api` - Use SharedPreferencesAsync for new code
- `avoid_shared_prefs_in_isolate` - SharedPreferences doesn't work in isolates

#### Stream Rules

- `prefer_stream_distinct` - Add .distinct() before .listen() for UI streams
- `prefer_broadcast_stream` - Use broadcast streams when multiple listeners needed

#### Async/Build Rules

- `avoid_future_in_build` - Don't create Futures inside build() method
- `require_mounted_check_after_await` - Check mounted before setState after await
- `avoid_async_in_build` - Build methods must never be async
- `prefer_async_init_state` - Use Future field + FutureBuilder pattern

#### Widget Lifecycle Rules

- `require_widgets_binding_callback` - Wrap showDialog in addPostFrameCallback in initState

#### Navigation Rules

- `prefer_route_settings_name` - Include RouteSettings with name for debugging

#### Internationalization Rules

- `prefer_number_format` - Use NumberFormat for locale-aware number formatting
- `provide_correct_intl_args` - Intl.message args must match placeholders

#### Package-specific Rules

- `avoid_freezed_for_logic_classes` - Freezed is for data classes, not Blocs/Services

#### Disposal Rules

- `dispose_class_fields` - Classes with disposable fields need dispose/close methods

#### State Management Rules

- `prefer_change_notifier_proxy_provider` - Use ProxyProvider for dependent notifiers

### Tier Assignments

- **Essential tier:** avoid_shared_prefs_in_isolate, avoid_future_in_build, require_mounted_check_after_await, provide_correct_intl_args, dispose_class_fields, avoid_async_in_build
- **Recommended tier:** 17 rules covering best practices
- **Professional tier:** require_bloc_repository_injection, avoid_freezed_for_logic_classes

## [4.1.3]

- Migrated all single/double-word lint rules to three-word convention for clarity and discoverability. Notable migrations include:
  - `arguments_ordering` → `enforce_arguments_ordering`
  - `capitalize_comment` → `capitalize_comment_start`
  - `prefer_first_method_usage` → `prefer_list_first`
  - `prefer_last_method_usage` → `prefer_list_last`
  - `prefer_member_ordering` → `enforce_member_ordering`
  - `prefer_container_widget` → `prefer_single_container`
  - `prefer_pagination_pattern` → `prefer_api_pagination`
  - `prefer_contains_method_usage` → `prefer_list_contains`
  - `avoid_dynamic_typing` → `avoid_dynamic_type`
  - `avoid_substring_usage` → `avoid_string_substring`
  - `avoid_continue_statement` → `avoid_continue_statement`
  - `extend_equatable` → `require_extend_equatable`
  - `require_dispose_method` → `require_field_dispose`
  - `dispose_fields` → `dispose_widget_fields`
  - `parameters_ordering` → `enforce_parameters_ordering`
  - `format_comment` → `format_comment_style`
  - `max_imports` → `limit_max_imports`
  - `avoid_shadowing` → `avoid_variable_shadowing`
  - `prefer_selector` → `prefer_context_selector`
  - `dispose_providers` → `dispose_provider_instances`
  - `prefer_first` → `prefer_list_first`
  - `prefer_last` → `prefer_list_last`
  - `prefer_contains` → `prefer_list_contains`
  - `prefer_container` → `prefer_single_container`
  - `prefer_pagination` → `prefer_api_pagination`
  - `avoid_dynamic` → `avoid_dynamic_type`
  - `avoid_substring` → `avoid_string_substring`
  - `member_ordering` → `enforce_member_ordering`
  - `parameters_ordering` → `enforce_parameters_ordering`
  - `format_comment` → `format_comment_style`
  - `require_dispose` → `require_field_dispose`
  - `dispose_fields` → `dispose_widget_fields`
  - `avoid_continue` → `avoid_continue_statement`
  - `extend_equatable` → `require_extend_equatable`
  - `avoid_shadowing` → `avoid_variable_shadowing`

## [4.1.2]

### Fixed

- Removed a stray change log entry from the readme

## [4.1.1]

### Added

- **New Rule:** `avoid_cached_isar_stream` ([lib/src/rules/isar_rules.dart])
  - Detects and prevents caching of Isar query streams (must be created inline).
  - **Tier:** Professional
  - **Quick Fix:** Inlines offending Isar stream expressions at usage sites and removes the cached variable.
  - **Example:** [example/lib/isar/avoid_cached_isar_stream_fixture.dart]

### Tier Assignment for Previously Unassigned Rules

The following 6 rules, previously implemented but not assigned to any tier, are now included in the most appropriate tier sets in `lib/src/tiers.dart`:

- **Recommended Tier:**
  - `avoid_duplicate_test_assertions` (test quality)
  - `avoid_real_network_calls_in_tests` (test reliability)
  - `require_error_case_tests` (test completeness)
  - `require_test_isolation` (test reliability)
  - `prefer_where_or_null` (idiomatic Dart collections)
- **Professional Tier:**
  - `prefer_copy_with_for_state` (state management, immutability)

This ensures all implemented rules are available through tiered configuration and improves coverage for test and state management best practices.

### Rule Tier Assignment Audit

- Ran `scripts/audit_rules.py` to identify all implemented rules not assigned to any tier.
- Assigned the following rules to the most appropriate tier sets in `lib/src/tiers.dart`:
  - **Recommended:** `avoid_duplicate_test_assertions`, `avoid_real_network_calls_in_tests`, `require_error_case_tests`, `require_test_isolation`, `prefer_where_or_null`
  - **Professional:** `prefer_copy_with_for_state`
- All implemented rules are now available through tiered configuration. This ensures no orphaned rules and improves test and state management coverage.
- Updated changelog to document these assignments and maintain full transparency of tier coverage.

### Tier Set Maintenance

- Commented out unimplemented rules in all tier sets in `lib/src/tiers.dart` to ensure only implemented rules are active per tier.
- Confirmed all unimplemented rules are tracked in `ROADMAP.md` for future implementation.
- This change improves roadmap alignment and prevents accidental activation of unimplemented rules.
- Materially improve the message quality for all Critical rules

## [4.1.0]

### Tier Assignment Audit

**181 rules** previously unassigned to any tier are now properly categorized. These rules existed but were not included in tier configurations, meaning users weren't getting them unless explicitly enabled.

#### Essential Tier (+50 rules)

Critical and high-impact rules now included in the essential tier:

| Category                  | Rules Added                                                                                                                                                                                                                                                          |
| ------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Security**              | `avoid_deep_link_sensitive_params`, `avoid_path_traversal`, `avoid_webview_insecure_content`, `require_data_encryption`, `require_secure_password_field`, `prefer_html_escape`                                                                                       |
| **JSON/Type Safety**      | `avoid_dynamic_json_access`, `avoid_dynamic_json_chains`, `avoid_unrelated_type_casts`, `require_null_safe_json_access`                                                                                                                                              |
| **Platform Permissions**  | `avoid_platform_channel_on_web`, `require_image_picker_permission_android`, `require_image_picker_permission_ios`, `require_permission_manifest_android`, `require_permission_plist_ios`, `require_url_launcher_queries_android`, `require_url_launcher_schemes_ios` |
| **Memory/Resource Leaks** | `avoid_stream_subscription_in_field`, `avoid_websocket_memory_leak`, `prefer_dispose_before_new_instance`, `require_dispose_implementation`, `require_video_player_controller_dispose`                                                                               |
| **Widget Lifecycle**      | `check_mounted_after_async`, `avoid_ref_in_build_body`, `avoid_flashing_content`                                                                                                                                                                                     |
| **Animation**             | `avoid_animation_rebuild_waste`, `avoid_overlapping_animations`                                                                                                                                                                                                      |
| **Navigation**            | `prefer_maybe_pop`, `require_deep_link_fallback`, `require_stepper_validation`                                                                                                                                                                                       |
| **Firebase/Backend**      | `prefer_firebase_remote_config_defaults`, `require_background_message_handler`, `require_fcm_token_refresh_handler`                                                                                                                                                  |
| **Forms/WebView**         | `require_validator_return_null`, `avoid_image_picker_large_files`, `prefer_webview_javascript_disabled`, `require_webview_error_handling`, `require_webview_navigation_delegate`, `require_websocket_message_validation`                                             |
| **Data/Storage**          | `prefer_utc_for_storage`, `require_database_migration`, `require_enum_unknown_value`                                                                                                                                                                                 |
| **State/UI**              | `require_error_widget`, `require_feature_flag_default`, `require_immutable_bloc_state`, `require_map_idle_callback`, `require_media_loading_state`, `prefer_bloc_listener_for_side_effects`, `require_cors_handling`                                                 |

#### Recommended Tier (+83 rules)

Medium-impact rules for better code quality:

| Category                | Rules Added                                                                                                                                                                                                                                                                             |
| ----------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Widget Structure**    | `avoid_deep_widget_nesting`, `avoid_find_child_in_build`, `avoid_layout_builder_in_scrollable`, `avoid_nested_providers`, `avoid_opacity_misuse`, `avoid_shrink_wrap_in_scroll`, `avoid_unbounded_constraints`, `avoid_unconstrained_box_misuse`                                        |
| **Gesture/Input**       | `avoid_double_tap_submit`, `avoid_gesture_conflict`, `avoid_gesture_without_behavior`, `prefer_actions_and_shortcuts`, `prefer_cursor_for_buttons`, `require_disabled_state`, `require_drag_feedback`, `require_focus_indicator`, `require_hover_states`, `require_long_press_callback` |
| **Forms/Testing**       | `require_button_loading_state`, `require_form_validation`, `avoid_flaky_tests`, `avoid_real_timer_in_widget_test`, `avoid_stateful_test_setup`, `prefer_matcher_over_equals`, `prefer_mock_http`, `require_golden_test`, `require_mock_verification`                                    |
| **Performance**         | `avoid_hardcoded_layout_values`, `avoid_hardcoded_text_styles`, `avoid_large_images_in_memory`, `avoid_map_markers_in_build`, `avoid_stack_overflow`, `prefer_clip_behavior`, `prefer_deferred_loading_web`, `prefer_keep_alive`, `prefer_sliver_app_bar`, `prefer_sliver_list`         |
| **State Management**    | `avoid_late_context`, `prefer_cubit_for_simple_state`, `prefer_selector_over_consumer`, `require_bloc_consumer_when_both`                                                                                                                                                               |
| **Accessibility**       | `avoid_screenshot_sensitive`, `avoid_semantics_exclusion`, `prefer_merge_semantics`, `avoid_small_text`                                                                                                                                                                                 |
| **Database/Navigation** | `require_database_index`, `prefer_transaction_for_batch`, `prefer_typed_route_params`, `require_refresh_indicator`, `require_scroll_controller`, `require_scroll_physics`                                                                                                               |
| **Desktop/i18n**        | `require_menu_bar_for_desktop`, `require_window_close_confirmation`, `require_intl_locale_initialization`, `require_notification_timezone_awareness`                                                                                                                                    |

#### Comprehensive Tier (+48 rules)

Low-impact style and pattern rules:

- Code style: `avoid_digit_separators`, `avoid_nested_try_statements`, `avoid_type_casts`
- Documentation: `prefer_doc_comments_over_regular`, `prefer_error_suffix`, `prefer_exception_suffix`
- Patterns: `prefer_class_over_record_return`, `prefer_record_over_equatable`, `prefer_guard_clauses`
- Async: `prefer_async_only_when_awaiting`, `prefer_await_over_then`, `prefer_sync_over_async_where_possible`
- Testing: `prefer_expect_over_assert_in_tests`, `prefer_single_expectation_per_test`
- And 33 more...

#### Intentionally Untiered (81 rules)

Stylistic/opinionated rules remain untiered for team-specific configuration:

- Quote style: `prefer_single_quotes` vs `prefer_double_quotes`
- Import style: `prefer_relative_imports` vs `prefer_absolute_imports`
- Member ordering: `prefer_fields_before_methods` vs `prefer_methods_before_fields`
- Control flow: `prefer_ternary_over_if_null` vs `prefer_if_null_over_ternary`
- Debug rules: `always_fail`, `greeting`, `firebase_custom`

---

## [4.0.1]

### Testing Best Practices Rules

Activated 5 previously unregistered testing best practices rules:

| Rule                                  | Tier         | Description                                                              |
| ------------------------------------- | ------------ | ------------------------------------------------------------------------ |
| `prefer_test_find_by_key`             | Recommended  | Suggests `find.byKey()` over `find.byType()` for reliable widget testing |
| `prefer_setup_teardown`               | Recommended  | Detects duplicated test setup code (3+ occurrences)                      |
| `require_test_description_convention` | Recommended  | Ensures test names include descriptive words                             |
| `prefer_bloc_test_package`            | Professional | Suggests `blocTest()` when detecting Bloc testing patterns               |
| `prefer_mock_verify`                  | Professional | Warns when `when()` is used without `verify()`                           |

**Note:** `avoid_test_sleep` was already registered.

**Code cleanup:** Removed redundant test file path checks from these rules (file type filtering is handled by `applicableFileTypes`).

### DX Message Quality Improvements

Improved problem messages for 7 critical-impact rules to provide specific consequences instead of generic descriptions:

| Rule                                  | Improvement                                                     |
| ------------------------------------- | --------------------------------------------------------------- |
| `require_secure_storage`              | Now explains XML storage exposure enables credential extraction |
| `avoid_storing_sensitive_unencrypted` | Added backup extraction and identity theft consequence          |
| `check_mounted_after_async`           | Specifies State disposal during async gap                       |
| `avoid_stream_subscription_in_field`  | Clarifies callbacks fire after State disposal                   |
| `require_stream_subscription_cancel`  | Specifies State disposal context                                |
| `require_interval_timer_cancel`       | Specifies State disposal context                                |
| `avoid_dialog_context_after_async`    | Clarifies BuildContext deactivation during async gap            |

**Result**: Critical impact rules now at 100% DX compliance (40/40 passing).

### Documentation

- **PROFESSIONAL_SERVICES.md**: Rewrote professional services documentation with clearer service offerings and contact information

---

## [4.0.0]

### OWASP Compliance Mapping

Security rules are now mapped to **OWASP Mobile Top 10 (2024)** and **OWASP Top 10 (2021)** standards, transforming saropa_lints from a developer tool into a **security audit tool**.

#### Coverage

| OWASP Mobile        | Rules | OWASP Web                   | Rules |
| ------------------- | ----- | --------------------------- | ----- |
| M1 Credential Usage | 5+    | A01 Broken Access Control   | 4+    |
| M3 Authentication   | 5+    | A02 Cryptographic Failures  | 10+   |
| M4 Input Validation | 6+    | A03 Injection               | 6+    |
| M5 Communication    | 2+    | A05 Misconfiguration        | 4+    |
| M6 Privacy Controls | 5+    | A07 Authentication Failures | 8+    |
| M8 Misconfiguration | 4+    | A09 Logging Failures        | 2+    |
| M9 Data Storage     | 7+    |                             |       |
| M10 Cryptography    | 4+    |                             |       |

**Gaps**: M2 (Supply Chain), M7 (Binary Protection), and A06 (Outdated Components) require separate tooling — dependency scanners and build-time protections.

#### New Files

- `lib/src/owasp/owasp_category.dart` - `OwaspMobile` and `OwaspWeb` enums with category metadata
- `lib/src/owasp/owasp_mapping.dart` - Compliance reporting utilities
- `lib/src/owasp/owasp.dart` - Barrel export

#### API

Rules expose OWASP mappings via the `owasp` property:

```dart
final rule = AvoidHardcodedCredentialsRule();
print(rule.owasp); // Mobile: M1 | Web: A07

// Generate compliance report
final mappings = getAllSecurityRuleMappings();
final report = generateComplianceReport(mappings);
```

#### Modified Files

- `lib/src/saropa_lint_rule.dart` - Added `OwaspMapping? get owasp` to `SaropaLintRule` base class
- `lib/src/rules/security_rules.dart` - Added OWASP mappings to 41 security rules
- `lib/src/rules/crypto_rules.dart` - Added OWASP mappings to 4 cryptography rules
- `lib/saropa_lints.dart` - Export `OwaspMapping`, `OwaspMobile`, `OwaspWeb`

### Baseline Feature for Brownfield Projects

**The problem**: You want to adopt saropa_lints on an existing project, but running analysis shows 500+ violations in legacy code. You can't fix them all before your next sprint, but you want new code to be clean.

**The solution**: The baseline feature records existing violations and hides them. Old code is "baselined" (hidden), new code is still checked. You can adopt linting today without fixing legacy code first.

#### Quick Start

```bash
# Generate baseline - hides all current violations
dart run saropa_lints:baseline
```

This command creates `saropa_baseline.json` and updates your `analysis_options.yaml`. Old violations are hidden, new code is still checked.

#### Three Combinable Baseline Types

| Type           | Config           | Description                                         |
| -------------- | ---------------- | --------------------------------------------------- |
| **File-based** | `baseline.file`  | JSON file listing specific violations to ignore     |
| **Path-based** | `baseline.paths` | Glob patterns for directories (e.g., `lib/legacy/`) |
| **Date-based** | `baseline.date`  | Git blame - ignore code unchanged since a date      |

All three types are combinable - any match suppresses the violation.

#### Full Configuration

```yaml
custom_lint:
  saropa_lints:
    tier: recommended
    baseline:
      file: "saropa_baseline.json" # Specific violations
      date: "2025-01-15" # Code unchanged since this date
      paths: # Directories/patterns
        - "lib/legacy/"
        - "lib/deprecated/"
        - "**/generated/"
      only_impacts: [low, medium] # Only baseline these severities
```

#### CLI Commands

```bash
dart run saropa_lints:baseline              # Generate new baseline
dart run saropa_lints:baseline --update     # Refresh, remove fixed violations
dart run saropa_lints:baseline --dry-run    # Preview without changes
dart run saropa_lints:baseline --help       # See all options
```

#### New Files

- `lib/src/baseline/baseline_config.dart` - Configuration parsing
- `lib/src/baseline/baseline_file.dart` - JSON file handling
- `lib/src/baseline/baseline_paths.dart` - Glob pattern matching
- `lib/src/baseline/baseline_date.dart` - Git blame integration
- `lib/src/baseline/baseline_manager.dart` - Central orchestrator
- `bin/baseline.dart` - CLI tool

See [README.md](README.md#baseline-for-brownfield-projects) for full documentation.

### New Rules

#### OWASP Coverage Gap Rules

Five new rules to fill gaps in OWASP coverage:

| Rule                           | OWASP   | Severity | Description                                                                                |
| ------------------------------ | ------- | -------- | ------------------------------------------------------------------------------------------ |
| `avoid_ignoring_ssl_errors`    | M5, A05 | ERROR    | Detects `badCertificateCallback = (...) => true` that bypasses SSL validation              |
| `require_https_only`           | M5, A05 | WARNING  | Flags `http://` URLs (except localhost). Has quick fix to replace with HTTPS               |
| `avoid_unsafe_deserialization` | M4, A08 | WARNING  | Detects `jsonDecode` results used in dangerous operations without type validation          |
| `avoid_user_controlled_urls`   | M4, A10 | WARNING  | Flags user input (text controllers) passed directly to HTTP methods without URL validation |
| `require_catch_logging`        | M8, A09 | WARNING  | Catch blocks that silently swallow exceptions without logging or rethrowing                |

---

## [3.4.0]

### Performance Optimizations

Added comprehensive performance infrastructure to support 1400+ lint rules efficiently.

#### Caching Infrastructure

- **`SourceLocationCache`**: O(log n) offset-to-line lookups via binary search with cached line start offsets
- **`SemanticTokenCache`**: Caches resolved type information and symbol metadata across rules
- **`CompilationUnitCache`**: Caches expensive AST traversal results (class names, method names, imports)
- **`ImportGraphCache`**: Caches project import graph for dependency queries and circular import detection

#### IDE Integration (Infrastructure Only)

- **`ThrottledAnalysis`**: Debounces analysis during rapid typing (requires IDE hooks not available in custom_lint)
- **`SpeculativeAnalysis`**: Pre-analyzes files likely to be opened next (requires IDE hooks not available in custom_lint)
- **Note**: These classes exist for future IDE integration but cannot be fully wired up without custom_lint framework changes

#### Rule Execution Optimization

- **`RuleGroupExecutor`**: Groups related rules to share setup/teardown costs and intermediate results
- **`ConsolidatedVisitorDispatch`**: Single AST traversal for multiple rules (reduces O(rules × nodes) to O(nodes))
- **`BaselineAwareEarlyExit`**: Skips rules when all violations are baselined
- **`DiffBasedAnalysis`**: Only re-analyzes changed regions of files

#### Memory Optimization

- **`StringInterner`**: Interns common strings (StatelessWidget, BuildContext) to reduce memory allocation
- Pre-interns 35+ common Dart/Flutter strings at startup
- **`LruCache`**: Generic LRU cache with configurable size limits to prevent unbounded memory growth
- **`MemoryPressureHandler`**: Monitors memory usage and auto-clears caches when threshold exceeded

#### Profiling

- **`HotPathProfiler`**: Instruments hot paths to identify slow rules and operations
- Tracks execution times, slow operations (>50ms threshold), and provides statistical analysis
- Enable via `HotPathProfiler.enable()` for development debugging

#### Parallel Execution

- **`ParallelAnalyzer`**: Now uses real `Isolate.run()` for true parallel file analysis
- Distributes work across multiple CPU cores for 2-4x speedup on large projects
- Automatic fallback to sequential processing when isolates unavailable

#### Integration Wiring

- **Startup initialization**: `initializeCacheManagement()` and `StringInterner.preInternCommon()` called at plugin startup
- **Memory tracking**: `MemoryPressureHandler.recordFileProcessed()` called per-file to trigger auto-clearing
- **Rule groups registered**: 6 groups defined (async, widget, context, dispose, test, security) for batch execution
- **Rapid analysis throttle**: Content-hash-based throttle prevents duplicate analysis of identical content within 300ms
- **Bloom filter pre-screening**: O(1) probabilistic membership testing in `PatternIndex` before expensive string searches
- **Content region skipping**: Rules can declare `requiresClassDeclaration`, `requiresMainFunction`, `requiresImports` to skip irrelevant files
- **Git-aware file priority**: `GitAwarePriority` tracks modified/staged files for prioritized analysis
- **Import-based rule filtering**: `requiresFlutterImport` getter skips widget rules instantly for pure Dart files
- **Adaptive tier switching**: Auto-switches to essential-tier rules during rapid editing (3+ analyses in 2 seconds)

### New Rules

- **`avoid_circular_imports`**: Detects circular import dependencies using `ImportGraphCache`
  - Reports when files are part of an import cycle
  - Suggests extracting shared types to break cycles

---

## [3.3.1]

### Quick Fix Policy Update

Updated contribution guidelines and roadmap with a plan to achieve 90% quick fix coverage.

#### HACK Comment Fixes Discouraged

`// HACK: fix this manually` fixes are now discouraged. They provide no real value. See [CONTRIBUTING.md](CONTRIBUTING.md#hack-comment-fixes-are-discouraged) for details.

- Real fixes that transform code are required
- If a fix can't be implemented safely, don't add one
- Document "no fix possible" in the rule's doc comment

#### Quick Fix Implementation Plan

Added comprehensive plan to [ROADMAP.md](ROADMAP.md#quick-fix-implementation-plan) with:

- **Category A**: Safe transformations (100% target) - ~200 rules
- **Category B**: Contextual transformations (80% target) - ~400 rules
- **Category C**: Multi-choice fixes (50% target) - ~300 rules
- **Category D**: Human judgment required (0% fixes) - ~600 rules

Safety checklist: no deleting code, no behavior changes, works in edge cases.

### Tooling

- **`scripts/audit_rules.py`**: Now displays per-file statistics table with line counts, rule counts, and fix counts for each rule file

---

## [3.3.0]

### Audit Script v2.0

The `scripts/audit_rules.py` has been completely redesigned with improved readability and comprehensive analysis.

#### New Features

- **OWASP Coverage Stats** - Visual progress bars showing Mobile (8/10) and Web (10/10) coverage with uncovered categories listed
- **Tier Distribution** - Rule counts per tier (essential, recommended, professional, comprehensive, insanity) with cumulative totals and visual bars
- **Severity Distribution** - Critical/high/medium/low breakdown with percentages
- **Quality Metrics** - Quick fix coverage (13%), correction message coverage (99.6%), lines of code stats
- **Orphan Rules Detection** - Identifies rules implemented but not assigned to any tier (262 found)
- **File Health Analysis** - Largest files by rule count, files needing quick fixes
- **DX Message Audit** - Now shows all impact levels with pass rates and percentages

#### Improved Output

- Organized into logical sections: Rule Inventory, Distribution Analysis, Security & Compliance, Quality Metrics, ROADMAP Sync, DX Message Audit
- Visual progress bars for coverage metrics
- Cleaner section headers with Unicode box-drawing characters
- Compact mode (`--compact`) to skip the file table for faster runs
- Top 3 worst offenders shown in terminal, full details in exported report

#### Command Options

```bash
python scripts/audit_rules.py              # Full audit
python scripts/audit_rules.py --compact    # Skip file table
python scripts/audit_rules.py --dx-all     # Show all DX issues
python scripts/audit_rules.py --no-dx      # Skip DX audit
```

---

## [3.1.2]

### New Rules

#### Tiered File Length Rules (OPINIONATED)

Opinionated style preferences for teams that prefer smaller files. **Not quality indicators** - large files are often necessary and valid for data, enums, constants, generated code, configs, and lookup tables.

| Rule                           | Threshold  | Tier          | Severity |
| ------------------------------ | ---------- | ------------- | -------- |
| `prefer_small_length_files`    | 200 lines  | insanity      | INFO     |
| `avoid_medium_length_files`    | 300 lines  | professional  | INFO     |
| `avoid_long_length_files`      | 500 lines  | comprehensive | INFO     |
| `avoid_very_long_length_files` | 1000 lines | recommended   | INFO     |

All rules can be disabled per-file with `// ignore_for_file: rule_name`.

### Performance Optimizations

#### Combined Pattern Index

- **Global pattern index**: Instead of each rule scanning for its patterns individually, we now build a combined index at startup and scan file content ONCE.
- **O(patterns) instead of O(rules x patterns)**: For 1400+ rules with multiple patterns, this is a massive speedup in the pre-filtering phase.
- **New `PatternIndex` class**: Automatically built when rules are loaded, transparent to rule authors.

#### Incremental Analysis Tracking

- **Skip unchanged files**: New `IncrementalAnalysisTracker` remembers which rules passed on which files.
- **Content hash comparison**: Only re-runs rules when file content actually changes.
- **Config-aware cache invalidation**: Cache automatically clears when tier or rule configuration changes.
- **Per-rule tracking**: Individual rules that pass are recorded, so even partial re-analysis benefits.
- **Disk persistence**: Cache survives IDE restarts! Saved to `.dart_tool/saropa_lints_cache.json`.
- **Auto-save throttling**: Saves after every 50 changes to balance performance vs data safety.
- **Atomic writes**: Uses temp file + rename to prevent corruption on crash.

#### File Metrics Cache

- **Cached file metrics**: New `FileMetricsCache` computes line count, class count, function count, etc. once per file.
- **Shared across rules**: All rules accessing file metrics use the same cached values.
- **Includes content indicators**: `hasAsyncCode`, `hasWidgets` for fast filtering.

#### New Rule Optimization Hooks

- **`requiresAsync` getter**: Skip rules on files without async/Future patterns.
- **`requiresWidgets` getter**: Skip rules on files without Widget/State patterns.
- **`maximumLineCount` getter**: (DANGEROUS - use sparingly) Skip rules on very large files. Only for O(n²) rules where analysis time is prohibitive. Off by default.

#### Smart Content Filter

- **New `SmartContentFilter` class**: Combines multiple heuristics in a single filter check.
- **Supports patterns, line counts, keywords, async, widgets**: One call to check all constraints.

#### Rule Priority Queue

- **Cost-based rule ordering**: Rules sorted by cost so cheap rules run first.
- **Fail-fast optimization**: Cheaper rules provide faster initial feedback.
- **New `RulePriorityQueue` class**: Sorts rules by cost + pattern count for optimal execution order.

#### Content Region Index

- **Pre-indexed file regions**: Imports, class declarations, and top-level code indexed separately.
- **Targeted scanning**: Rules checking imports don't need to scan function bodies.
- **New `ContentRegionIndex` class**: Computes and caches structural regions per file.

#### AST Node Type Registry

- **Batch rules by node type**: Group rules that care about the same AST nodes.
- **Reduced visitor overhead**: Instead of each rule registering callbacks, batch invocations.
- **New `AstNodeTypeRegistry` class**: Tracks which rules care about which node categories.

#### Content Fingerprinting

- **Structural fingerprints**: Quick hash of file characteristics (imports, classes, async, widgets).
- **Similarity detection**: Files with same fingerprint likely have same violations.
- **New `ContentFingerprint` class**: Enables caching across similar files.

#### Rule Dependency Graph

- **Fail-fast chains**: If rule A finds violations, skip dependent rule B.
- **Prerequisite tracking**: Declare rule dependencies for smarter execution.
- **New `RuleDependencyGraph` class**: Track and query rule dependencies.

#### Rule Execution Statistics

- **Historical performance tracking**: Track execution time and violation rates per rule.
- **Dynamic optimization**: Identify slow rules and rules that rarely find violations.
- **New `RuleExecutionStats` class**: Records and queries rule performance data.

#### Lazy Pattern Compilation

- **Deferred regex compilation**: Patterns compiled only when actually needed.
- **Skip compilation for filtered rules**: If early filtering skips a rule, its patterns are never compiled.
- **New `LazyPattern` and `LazyPatternCache` classes**: Lazy regex infrastructure.

#### Parallel Pre-Analysis

- **Parallel file scanning**: Pre-analyze files in parallel to populate caches before rules execute.
- **Async batch processing**: Files processed in batches with async gaps to avoid blocking.
- **Unified cache warming**: Computes metrics, fingerprints, file types, and pattern matches in one pass.
- **Batch execution planning**: Determines which rules should run on which files upfront.
- **New `ParallelAnalyzer` class**: Manages parallel pre-analysis of files.
- **New `ParallelAnalysisResult` class**: Contains all pre-computed analysis data for a file.
- **New `RuleBatchExecutor` class**: Plans and tracks which rules apply to which files.
- **New `BatchableRuleInfo` class**: Rule metadata for batch execution planning.

#### Consolidated Visitor Dispatch

- **Single-pass AST traversal**: Instead of each rule registering separate visitors, dispatch to all rules from one traversal.
- **Reduced traversal overhead**: O(nodes) instead of O(rules × nodes) for visitor callbacks.
- **Category-based registration**: Rules register for specific AST node categories (imports, classes, invocations, etc.).
- **New `ConsolidatedVisitorDispatch` class**: Manages rule callbacks by node category.
- **New `NodeVisitCallback` typedef**: Standard callback signature for consolidated visitors.

#### Baseline-Aware Early Exit

- **Skip fully-baselined rules**: If all violations of a rule in a file are baselined, skip the rule entirely.
- **Path-based baseline detection**: Files covered by path-based baseline can skip matching rules.
- **Violation counting**: Track baselined violation counts for optimization decisions.
- **New `BaselineAwareEarlyExit` class**: Tracks and queries baseline coverage per file/rule.

#### Diff-Based Analysis

- **Changed region tracking**: Only re-analyze lines that changed since last analysis.
- **Line range overlap detection**: Skip rules whose scope doesn't overlap with changes.
- **Simple line-by-line diff**: Fast diff computation without external dependencies.
- **Range merging**: Consolidate overlapping change regions for efficient queries.
- **New `DiffBasedAnalysis` class**: Computes and caches changed regions per file.
- **New `LineRange` class**: Represents line ranges with overlap/merge operations.

#### Import Graph Cache

- **Project-wide import graph**: Parse imports once and cache the dependency graph.
- **Transitive dependency queries**: Check if file A transitively imports file B.
- **Reverse graph**: Track which files import a given file.
- **Circular import detection**: Find import cycles involving a specific file.
- **New `ImportGraphCache` class**: Builds and queries the import graph.
- **New `ImportNode` class**: Represents a file's import relationships.

---

## [3.1.1]

### New Rules

- **prefer_descriptive_bool_names_strict**: Strict version of bool naming rule for insanity tier. Requires traditional prefixes (`is`, `has`, `can`, `should`). Does not allow action verbs.

### Enhancements

- **prefer_descriptive_bool_names**: Now lenient (professional tier). Allows action verb prefixes (`process`, `sort`, `remove`, etc.) and `value` suffix.

### Bug Fixes

- **no_boolean_literal_compare**: Fixed rule not being registered in plugin. Was implemented but missing from `saropa_lints.dart`.
- **avoid_conditions_with_boolean_literals**: Now only checks logical operators (`&&`, `||`). Equality comparisons (`==`, `!=`) are handled by `no_boolean_literal_compare` which has proper nullable type checking. This eliminates double-linting and false positives on `nullableBool == true`.
- **require_ios_permission_description**: Fixed false positive on `ImagePicker()` constructor. The rule now only triggers on method calls (`pickImage`, `pickVideo`, etc.) where it can detect the actual source (gallery vs camera).
- **require_ios_face_id_usage_description**: Now checks Info.plist before reporting. Previously always triggered on `LocalAuthentication` usage regardless of whether `NSFaceIDUsageDescription` was already present.
- **AvoidContextAcrossAsyncRule**: Now recognizes mounted-guarded ternary pattern `context.mounted ? context : null` as safe.
- **PreferDocCurlyApostropheRule**: Fixed quick fix not appearing - was searching `precedingComments` instead of `documentationComment`. Renamed from `PreferCurlyApostropheRule` to clarify it only applies to documentation.
- **Missing rule name prefixes**: Fixed 17 rules that were missing the `[rule_name]` prefix in their `problemMessage`. Affected rules: `avoid_future_tostring`, `prefer_async_await`, `avoid_late_keyword`, `prefer_simpler_boolean_expressions`, `avoid_context_in_initstate_dispose`, `avoid_shrink_wrap_in_lists`, `prefer_widget_private_members`, `avoid_hardcoded_locale`, `require_ios_permission_description`, `avoid_getter_prefix`, `prefer_correct_callback_field_name`, `prefer_straight_apostrophe`, `prefer_curly_apostrophe`, `avoid_dynamic`, `no_empty_block`.

---

## [3.1.0]

### Enhancements

- **Rule name prefix in messages**: All 1536 rules now prefix `problemMessage` with `[rule_name]` for visibility in VS Code's Problems panel.

### Bug Fixes

- **AvoidContextAfterAwaitInStaticRule**: Now recognizes `context.mounted` guards to prevent false positives.
- **AvoidStoringContextRule**: No longer flags function types that accept `BuildContext` as a parameter (callback signatures).
- **RequireIntlPluralRulesRule**: Only flags `== 1` or `!= 1` patterns, not general int comparisons.
- **AvoidLongRunningIsolatesRule**: Less aggressive on `compute()` - skips when comments indicate foreground use or in StreamTransformer patterns.

---

## [3.0.2]

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

## [3.0.1]

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

## [3.0.0]

### Performance Optimizations

This release focuses on **significant performance improvements** for large codebases. custom_lint is notoriously slow with 1400+ rules, and these optimizations address the main bottlenecks.

#### Tier Set Caching

- **Cached tier rule sets**: Previously, `getRulesForTier()` was rebuilding Set unions on EVERY file analysis. Now tier sets are computed once on first access and cached for all subsequent calls.
- **Impact**: ~5-10x faster tier filtering after first access.

#### Rule Filtering Cache

- **Cached filtered rule list**: Previously, the 1400+ rule list was filtering on every file. Now the filtered list is computed once per analysis session and reused.
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

## [2.7.0]

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

## [2.6.0]

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

## [2.5.0]

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

## [2.4.2]

### Changed

- Minor doc header escaping in ios_rules.dart

## [2.4.1]

### Changed

- Minor doc header escaping of `Provider.of<T>(context)`

## [2.4.0]

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
- **`require_app_lifecycle_handling`**: Warns when Timer.periodic or subscriptions lack lifecycle handling. (INFO)
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

## [2.3.11]

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

## [2.3.10]

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

## [2.3.9]

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

## [2.3.8]

### Fixed

- **`require_sse_subscription_cancel`**: Fixed false positives for field names like `addressesFuture` or `hasSearched` that contain "sse" substring. Now uses word-boundary regex `(^|_)sse($|_|[A-Z])` on the original (case-preserved) field name to correctly detect camelCase patterns like `sseClient` while avoiding false matches.
- **`avoid_shrink_wrap_expensive`**: No longer warns when `physics: NeverScrollableScrollPhysics()` is used. This is an intentional pattern for nested non-scrolling lists inside another scrollable.
- **`avoid_redirect_injection`**: Fixed false positives for object property access like `item.destination`. Now uses AST node type checking (`PropertyAccess`, `PrefixedIdentifier`) to skip property access patterns, and checks for custom object types when type info is available.
- **`use_setstate_synchronously`**: Fixed false positives in async lambda callbacks. Now skips nested `FunctionExpression` nodes (they have their own async context) and checks for ancestor mounted guards before reporting.

### Changed

- **Formatting**: Applied consistent code formatting to api_network_rules.dart (cosmetic only, no behavior change)

---

## [2.3.7]

### Added

#### Scroll & List Performance Rules (5 rules)

- **`avoid_shrink_wrap_expensive`**: Warns when `shrinkWrap: true` is used in expensive scroll contexts
- **`prefer_item_extent`**: Suggests setting `itemExtent` for uniform ListView items
- **`prefer_prototype_item`**: Suggests using `prototypeItem` for consistent list item sizing
- **`require_key_for_reorderable`**: Requires unique keys for ReorderableListView items (ERROR)
- **`require_add_automatic_keep_alives_off`**: Suggests disabling keep-alives for long lists

#### Accessibility Rules (3 rules)

- **`require_semantic_label_icons`**: Requires `semanticLabel` on Icon widgets (WARNING)
- **`require_accessible_images`**: Requires accessibility attributes on images (WARNING)
- **`avoid_auto_play_media`**: Warns against auto-playing media without user control

#### Form UX Rules (3 rules)

- **`require_form_auto_validate_mode`**: Suggests setting `autovalidateMode` on Forms
- **`require_autofill_hints`**: Suggests `autofillHints` for better autofill support
- **`prefer_on_field_submitted`**: Suggests handling field submission for form navigation

#### Equatable & Freezed Rules (5 rules)

- **`prefer_equatable_stringify`**: Suggests enabling `stringify: true` on Equatable
- **`prefer_immutable_annotation`**: Suggests `@immutable` annotation on Equatable classes
- **`require_freezed_explicit_json`**: Warns when Freezed lacks `explicit_to_json` for nested objects
- **`prefer_freezed_default_values`**: Suggests using `@Default` annotation
- **`prefer_record_over_equatable`**: Suggests Dart 3 records for simple value types

#### Boolean & Control Flow Rules (1 rule)

- **`prefer_simpler_boolean_expressions`**: Detects boolean expressions simplifiable via De Morgan's laws

#### Dispose Pattern Rules (9 rules)

- **`require_bloc_manual_dispose`**: Warns when Bloc controllers lack cleanup
- **`require_getx_worker_dispose`**: Warns when GetX Workers lack `onClose` cleanup
- **`require_getx_permanent_cleanup`**: Warns about permanent GetX instances
- **`require_animation_ticker_disposal`**: Requires Ticker `stop()` in dispose (ERROR)
- **`require_image_stream_dispose`**: Warns when ImageStream listeners not removed
- **`require_sse_subscription_cancel`**: Requires EventSource `close()` (ERROR)
- **`avoid_stream_subscription_in_field`**: Warns when subscriptions aren't stored for cancellation
- **`require_dispose_implementation`**: Warns when StatefulWidget with resources lacks `dispose()`
- **`prefer_dispose_before_new_instance`**: Warns when disposable fields are reassigned without cleanup

#### Type Safety Rules (6 rules)

- **`avoid_unrelated_type_casts`**: Detects casts between unrelated types (ERROR)
- **`avoid_dynamic_json_access`**: Warns against chained JSON access without null checks
- **`require_null_safe_json_access`**: Requires null check before JSON key access (ERROR)
- **`avoid_dynamic_json_chains`**: Warns against deeply chained JSON access (ERROR)
- **`require_enum_unknown_value`**: Requires fallback for enum parsing from API
- **`require_validator_return_null`**: Requires form validators to return null for valid input (ERROR)

#### Widget Replacement & State Management Rules (6 rules)

- **`prefer_selector_over_consumer`**: Suggests Selector for granular Provider rebuilds
- **`prefer_cubit_for_simple_state`**: Suggests Cubit for single-event Blocs
- **`prefer_bloc_listener_for_side_effects`**: Detects side effects in BlocBuilder
- **`require_bloc_consumer_when_both`**: Suggests BlocConsumer for nested listener+builder
- **`prefer_proxy_provider`**: Suggests ProxyProvider for dependent providers
- **`require_update_callback`**: Warns when ProxyProvider update callback is unused

#### Navigation & Debug Rules (3 rules)

- **`prefer_maybe_pop`**: Suggests `maybePop()` instead of `pop()` for route safety
- **`prefer_go_router_extra_typed`**: Warns against untyped `extra` parameter in go_router
- **`prefer_debugPrint`**: Suggests `debugPrint` instead of `print` for throttling

#### Code Quality Rules (2 rules)

- **`prefer_late_final`**: Suggests `late final` for singly-assigned late variables
- **`avoid_late_for_nullable`**: Warns against `late` for nullable types

#### WebView Security Rules (4 rules)

- **`prefer_webview_javascript_disabled`**: Warns when JavaScript enabled without justification
- **`avoid_webview_insecure_content`**: Warns against allowing mixed content (ERROR)
- **`require_webview_error_handling`**: Requires `onWebResourceError` handler
- **`require_webview_progress_indicator`**: Suggests progress indicator for WebViews

#### Image Picker Rules (2 rules)

- **`prefer_image_picker_request_full_metadata`**: Suggests disabling full metadata when not needed
- **`avoid_image_picker_large_files`**: Warns when `imageQuality` not set for compression

#### Package-Specific Rules (7 rules)

- **`avoid_graphql_string_queries`**: Warns against raw GraphQL query strings
- **`prefer_ble_mtu_negotiation`**: Suggests MTU negotiation for large BLE transfers
- **`avoid_loading_full_pdf_in_memory`**: Warns against loading large PDFs entirely (WARNING)
- **`require_qr_content_validation`**: Requires validation of QR code content (WARNING)
- **`require_notification_timezone_awareness`**: Suggests `TZDateTime` for scheduled notifications
- **`require_intl_locale_initialization`**: Warns when Intl locale not initialized
- **`prefer_geolocator_distance_filter`**: Suggests `distanceFilter` to reduce GPS battery drain

#### Firebase Rules (1 rule)

- **`prefer_firebase_auth_persistence`**: Suggests explicit persistence setting on web

#### GetX Rules (1 rule)

- **`avoid_getx_context_outside_widget`**: Warns against GetX context access outside widgets

#### Stylistic Rules (1 rule)

- **`arguments_ordering`**: Enforces consistent ordering of function arguments

### Fixed

- **`prefer_late_final`**: Now correctly counts inline initializers and only flags fields assigned exactly once (not zero times)
- **`require_qr_content_validation`**: Added explicit parentheses to fix operator precedence in validation check

## [2.3.6]

### Fixed

- **CI/CD**: Reverted example project to pure Dart (no Flutter SDK dependency) to fix CI failures caused by `dart pub get` requiring Flutter SDK
- **ROADMAP cleanup**: Removed 72 entries from ROADMAP.md that were already implemented (14 as aliases, 58 as rules)

### Added

- **flutter_mocks.dart**: Created comprehensive mock Flutter types (~490 lines) for lint rule testing without Flutter SDK:
  - Core types: `Widget`, `StatelessWidget`, `StatefulWidget`, `State`, `BuildContext`
  - Layout widgets: `Container`, `SizedBox`, `Padding`, `Align`, `Center`, `Column`, `Row`
  - Material widgets: `Scaffold`, `ElevatedButton`, `TextField`, `TabBar`, `AlertDialog`, `SnackBar`
  - Controllers: `TextEditingController`, `TabController`, `PageController`, `FocusNode`
  - Provider mocks: `Provider`, `MultiProvider`, `ChangeNotifierProvider`
  - BLoC mocks: `Bloc`, `BlocProvider`, `MultiBlocProvider`
- **scripts/audit_rules.py**: New script to audit implemented rules against ROADMAP entries
  - Detects rules that are already implemented (as rules or aliases)
  - Finds near-matches that may need aliases added
  - Features colorful output with Saropa ASCII logo
  - Returns exit code 1 if duplicates found for CI integration

### Changed

- Updated 12 fixture files to import `flutter_mocks.dart` instead of Flutter/external packages
- **prefer_dedicated_media_query_method**: Added alias `prefer_dedicated_media_query_methods`

## [2.3.5]

### Fixed

- **use_setstate_synchronously**: Fixed false positive for nested mounted checks (e.g., `if (mounted) { setState(...) }` inside callbacks or try blocks). Now properly traverses the AST to find protecting mounted checks in ancestor chain. Also handles `if (!mounted) return;` guard pattern correctly.
- **avoid_redirect_injection**: Fixed false positive for non-URL types. Now only flags `String`, `Uri`, or `dynamic` arguments, skipping object types like `AppGridMenuItem` that happen to have "destination" in their name.
- **avoid_keyboard_overlap**: Fixed false positive for dialogs and `Scrollable.ensureVisible`. Added checks for: class names containing "Dialog", file paths containing "dialog", files containing `showDialog`/`showDialogCommon` calls, and files using `ensureVisible`.
- **avoid_hardcoded_encryption_keys**: Added support for named constructors (e.g., `Key.fromUtf8(...)`, `Key.fromBase64(...)`) in addition to static method calls. The `encrypt` package uses named constructors.
- **Documentation**: Fixed unresolved doc references (`[...]` in scroll_rules.dart and `[Ticker]` in animation_rules.dart) by wrapping in backticks
- **Test fixtures**: Fixed 45 `unfulfilled_expect_lint` errors in example fixtures:
  - Fixed `// expect_lint` comment placement (must be directly before flagged line)
  - Enabled rules from higher tiers in example/analysis_options.yaml for testing
  - Removed expect_lint from commented-out code blocks

### Changed

- **example/analysis_options.yaml**: Explicitly enabled all tested rules regardless of tier

### Added

- **Quick fixes for 4 rules:**
  - `use_setstate_synchronously`: Wraps setState in `if (mounted) { ... }` check
  - `avoid_redirect_injection`: Adds comment for manual domain validation
  - `avoid_keyboard_overlap`: Adds comment for manual keyboard handling
  - `avoid_hardcoded_encryption_keys`: Adds comment for secure key loading

## [2.3.4]

### Fixed

- **avoid_dialog_context_after_async**: Fixed `RangeError` crash when analyzing files where `toSource()` produces a different length string than the original source
- **avoid_set_state_after_async**: Fixed the same `RangeError` in `_hasAwaitBefore` method

## [2.3.3]

### Changed

- **ENTERPRISE.md → PROFESSIONAL_SERVICES.md**: Renamed and restructured with New Projects / Upgrade / Audit service framework
- **README.md**: Added adoption strategy paragraph; updated documentation links
- **PROFESSIONAL_SERVICES.md**: Consolidated phased approach into Upgrade section; removed redundant adoption section
- **CONTRIBUTING.md**: Added rule prohibiting TODO comments as quick fixes
- **41 rules**: Updated doc headers to explain "**Manual fix required:**" for issues requiring human judgment
- **62 quick fixes**: Converted remaining `// TODO:` comments to `// HACK:` comments to avoid triggering the `todo` analyzer diagnostic

### Improved

**Converted 25+ TODO quick fixes to real automated fixes:**

- **complexity_rules.dart**: `AvoidCascadeAfterIfNullRule` now wraps `??` in parentheses
- **equality_rules.dart**: `AvoidSelfAssignmentRule` now comments out the statement
- **structure_rules.dart**:
  - Double slash imports now get the extra slash removed
  - Duplicate exports/imports/mixins now get commented out
  - Mutable globals now get `final` keyword added
- **type_rules.dart**:
  - Implicitly nullable extensions now get `implements Object` added
  - Nullable interpolations now get `?? ''` added
  - Nullable params with defaults now get `?` removed
- **exception_rules.dart**:
  - Non-final fields now get `final` keyword added
  - Pointless rethrows now get try-catch commented out
  - Throw in catch now gets replaced with `rethrow`
- **async_rules.dart**:
  - Future.ignore() now gets wrapped with `unawaited()`
  - Unassigned subscriptions now get assigned to `final _ =`
- **control_flow_rules.dart**: Collapsible if statements now get combined with `&&`
- **performance_rules.dart**: setState in build now gets wrapped in `addPostFrameCallback`
- **collection_rules.dart**: Collection equality now gets wrapped with `DeepCollectionEquality().equals()`
- **testing_best_practices_rules.dart**: Future.delayed now gets replaced with `tester.pumpAndSettle()`
- **test_rules.dart**: GetIt tests now get `GetIt.I.reset()` added to setUp
- **package_specific_rules.dart**:
  - File access now sets `allowFileAccess: false`
  - Envied now gets `obfuscate: true` parameter
  - Image picker now gets `maxWidth`/`maxHeight` parameters
  - API calls now get wrapped in try-catch
  - Calendar events now get `timeZone: tz.local` parameter

### Removed

- **41 TODO quick fixes**: Removed quick fixes that only added TODO comments (these just created noise by triggering the `todo` lint rule)

## [2.3.2]

### Added

#### Image & Package-Specific Rules (5 rules)

**Image Picker Rules**

- **`prefer_image_picker_max_dimensions`**: Warns when `pickImage()` is called without `maxWidth`/`maxHeight` parameters - prevents OOM on high-resolution cameras (12-108MP). Quick fix available.

**Cached Network Image Rules**

- **`prefer_cached_image_fade_animation`**: Suggests explicitly setting `fadeInDuration` on CachedNetworkImage for intentional UX design (default is 500ms).

**URL Launcher Rules**

- **`require_url_launcher_mode`**: Warns when `launchUrl()` is called without `mode` parameter - behavior varies by platform without explicit mode.

**SQLite Database Rules**

- **`avoid_sqflite_read_all_columns`**: Warns when `SELECT *` is used in `rawQuery()` - wastes memory and bandwidth by fetching unnecessary columns.

**Notification Rules**

- **`require_notification_initialize_per_platform`**: Warns when `InitializationSettings` is missing `android:` or `iOS:` parameters - notifications fail silently on missing platforms. Quick fix available.

### Changed

- **Added aliases** to pre-existing rules:
  - `require_await_in_async` → alias for `avoid_redundant_async`
  - `avoid_riverpod_ref_in_dispose` → alias for `avoid_ref_inside_state_dispose`
  - `avoid_set_state_in_build` → alias for `avoid_setstate_in_build`

## [2.3.1]

### Changed

- **`pass_existing_future_to_future_builder`**: Merged `avoid_future_builder_rebuild` into this rule
  - Now detects inline futures anywhere (not just in build method)
  - Added `InstanceCreationExpression` detection (e.g., `Future.value()`)
  - Added alias note in documentation

- **`avoid_uncaught_future_errors`**: Improved false positive handling
  - Now skips functions that have internal try-catch error handling

- **`avoid_keyboard_overlap`**: Improved detection accuracy
  - Skips Dialog and BottomSheet widgets (Flutter handles keyboard overlap for these)
  - Changed to file-level viewInsets check (handles nested widget composition)

- **`require_webview_ssl_error_handling`**: Fixed callback name
  - Changed from `onSslError` to `onSslAuthError` (correct API for webview_flutter 4.0+)
  - Removed `onHttpAuthRequest` from check (different purpose: HTTP 401 auth, not SSL)

- **`require_apple_signin_nonce`**: Improved documentation with Supabase example

### Removed

- **`avoid_future_builder_rebuild`**: Merged into `pass_existing_future_to_future_builder`

## [2.3.0]

### Added

#### ROADMAP_NEXT Parts 1-7 Rules (11 new rules + ~70 rules registered in tiers)

**GoRouter Navigation Rules (2 rules)**

- **`prefer_go_router_redirect_auth`**: Suggests using redirect callback instead of auth checks in page builders
- **`require_go_router_typed_params`**: Warns when path parameters are used without type conversion

**Provider State Management Rules (2 rules)**

- **`avoid_provider_in_init_state`**: Warns when Provider.of or context.read/watch is used in initState
- **`prefer_context_read_in_callbacks`**: Suggests using context.read instead of context.watch in callbacks

**Hive Database Rules (1 rule)**

- **`require_hive_type_id_management`**: Warns when @HiveType typeId may conflict with others

**Image Picker Rules (1 rule)**

- **`require_image_picker_result_handling`**: Warns when pickImage result is not checked for null

**Cached Network Image Rules (1 rule)**

- **`avoid_cached_image_in_build`**: Warns when CachedNetworkImage uses variable cacheKey in build

**SQLite Migration Rules (1 rule)**

- **`require_sqflite_migration`**: Warns when onUpgrade callback doesn't check oldVersion

**Permission Handler Rules (3 rules)**

- **`require_permission_rationale`**: Suggests checking shouldShowRequestRationale before requesting permission
- **`require_permission_status_check`**: Warns when using permission-gated features without checking status
- **`require_notification_permission_android13`**: Warns when notifications shown without POST_NOTIFICATIONS permission

### Changed

- Registered ~70 existing rules from Parts 1-7 into appropriate tiers (Essential, Recommended, Professional)
- All Isar, Dispose, Lifecycle, Widget, API, and Package-Specific rules now properly included in tier system
- **`prefer_test_wrapper`**: Added to Recommended tier

### Fixed

- **`avoid_uncaught_future_errors`**: Reduced false positives significantly:
  - Now recognizes `.then(onError: ...)` as valid error handling
  - Skips `unawaited()` wrapped futures (explicit acknowledgment)
  - Skips `.ignore()` chained futures
  - Added 20+ safe fire-and-forget methods: analytics (`logEvent`, `trackEvent`), cache (`prefetch`, `warmCache`), cleanup (`dispose`, `drain`)
- **`require_stream_subscription_cancel`**: Fixed false positive for collection-based cancellation patterns. Now correctly recognizes `for (final sub in _subscriptions) { sub.cancel(); }` and `_subscriptions.forEach((s) => s.cancel())` patterns. Added support for LinkedHashSet and HashSet collection types. Improved loop variable validation to prevent false negatives. Added quick fix to insert cancel() calls (handles both single and collection subscriptions, creates dispose() if missing).
- **`prefer_test_wrapper`**: Fixed false positive for teardown patterns where `SizedBox`, `Container`, or `Placeholder` are pumped to unmount widgets before disposing controllers. Added quick fix to wrap with `MaterialApp`.
- **`missing_test_assertion`**: Fixed duplicate tier assignment (was in both Essential and Recommended). Now correctly only in Essential tier. Added quick fix to insert `expect()` placeholder.
- **`avoid_assigning_notifiers`**: Fixed missing visitor class causing compilation error. Added Riverpod import check to only apply to files using Riverpod. Added RHS type fallback for `late final` variables. Added quick fix to comment out problematic assignments. Documented in using_with_riverpod.md guide.
- **`require_api_timeout`**: Removed duplicate rule. Merged into `require_request_timeout` which has better logic (more HTTP methods, avoids apiClient false positives, handles await patterns). Old name kept as alias for migration.
- **tiers.dart**: Added 9 missing rules that were implemented but not registered:
  - `require_type_adapter_registration` → Essential (Hive adapter not registered)
  - `require_hive_database_close` → Professional (database resource leak)
  - `prefer_lazy_box_for_large` → Professional (Hive memory optimization)
  - `prefer_http_connection_reuse` → Professional (network performance)
  - `avoid_redundant_requests` → Professional (resource efficiency)
  - `prefer_pagination` → Professional (memory efficiency)
  - `require_cancel_token` → Professional (cancel on dispose)
  - `require_response_caching` → Comprehensive (opinionated)
  - `avoid_over_fetching` → Comprehensive (opinionated)
- **test_rules.dart**: Added 7 test rules to tiers that were registered but never enabled:
  - `prefer_descriptive_test_name` → Professional
  - `prefer_fake_over_mock` → Professional
  - `require_edge_case_tests` → Professional
  - `avoid_test_implementation_details` → Professional
  - `prefer_test_data_builder` → Professional
  - `prefer_test_variant` → Professional
  - `require_animation_tests` → Professional
- **`avoid_uncaught_future_errors`**: Fixed false positives for awaited futures. Rule now only flags fire-and-forget futures (unawaited calls). Merged duplicate `require_future_error_handling` rule into this one (old name kept as alias). Added exceptions for `dispose()` methods, `cancel()`/`close()` methods, and futures inside try blocks. Added quick fix to add `.catchError()`.
- **`require_test_cleanup`**: Fixed false positives from generic substring matching. Now uses specific patterns to avoid matching `createWidget()`, `insertText()`, `output()` and similar unrelated methods. Only flags actual File/Directory operations, database inserts, and Hive box operations.
- **`require_pump_after_interaction`**: Fixed indexOf logic that only checked first interaction occurrence. Now tracks ALL interaction positions and checks each segment for proper pump() placement between interactions and expects.
- **`prefer_test_data_builder`**: Added null check for `name2` token access to prevent runtime errors on complex type constructs.
- **`require_hive_initialization`**: Changed LintImpact from medium to low since this is an informational heuristic that cannot verify cross-file initialization.
- **hive_rules.dart**: Extracted shared `_isHiveBoxTarget()` and `_isHiveBoxField()` utilities to reduce duplication and improve box detection accuracy. Now uses word boundary matching to avoid false positives like 'infobox' or 'checkbox'.
- **`require_error_identification`**: Fixed false positives from substring matching `.contains('red')`. Now uses regex pattern matching (`colors\.red`, `.red\b`, etc.) to avoid matching words like 'thread', 'spread', 'shredded'.
- **api_network_rules.dart**: Added import validation for package-specific rules to prevent false positives:
  - `avoid_dio_debug_print_production`: Now checks for Dio import and uses type-based detection for LogInterceptor
  - `require_geolocator_timeout`: Only applies to files importing geolocator package
  - `require_connectivity_subscription_cancel`: Only applies to files importing connectivity_plus package
  - `require_notification_handler_top_level`: Only applies to files importing firebase_messaging package
  - `require_permission_denied_handling`: Only applies to files importing permission_handler package; uses AST-based property access detection instead of string contains
- **navigation_rules.dart**: Added import validation for all go_router rules to prevent false positives in projects not using go_router:
  - `avoid_go_router_inline_creation`
  - `require_go_router_error_handler`
  - `require_go_router_refresh_listenable`
  - `avoid_go_router_string_paths`
  - `prefer_go_router_redirect_auth`
  - `require_go_router_typed_params`
- **state_management_rules.dart**: Fixed `prefer_context_read_in_callbacks` rule to properly detect Flutter callback conventions. Now checks for `on` prefix followed by uppercase letter (e.g., `onPressed`, `onTap`) to avoid false positives on words like `once`, `only`, `ongoing`.
- **import_utils.dart**: New shared utility file for package import validation. Provides `fileImportsPackage()` function and `PackageImports` constants for Dio, Geolocator, Connectivity, Firebase Messaging, Permission Handler, GoRouter, Riverpod, Hive, GetIt, Provider, Bloc, and more. Reduces code duplication across rule files.

## [2.2.0]

### Added

#### Pubspec Analyzer Script

- **`scripts/analyze_pubspec.py`**: Python script that analyzes a Flutter project's `pubspec.yaml` and recommends the optimal saropa_lints tier based on packages used. Features:
  - Recommends tier (essential/recommended/professional/comprehensive/insanity) based on dependencies
  - Shows package-specific rules that will be active for your packages
  - Identifies packages not yet covered by saropa_lints
  - Outputs JSON report with detailed analysis
  - Usage: `python scripts/analyze_pubspec.py <path_to_pubspec.yaml>`

#### Package-Specific Rules (19 rules)

**Authentication Rules (3 rules)**

- **`require_google_signin_error_handling`**: Warns when `signIn()` call lacks try-catch error handling
- **`require_apple_signin_nonce`**: Warns when Apple Sign-In is missing `rawNonce` parameter - security requirement
- **`avoid_openai_key_in_code`**: Warns when OpenAI API key pattern (`sk-...`) appears in source code

**Supabase Rules (3 rules)**

- **`require_supabase_error_handling`**: Warns when Supabase client calls lack try-catch error handling
- **`avoid_supabase_anon_key_in_code`**: Warns when Supabase anon key appears hardcoded in source
- **`require_supabase_realtime_unsubscribe`**: Warns when Supabase realtime channel lacks unsubscribe in dispose

**WebView Security Rules (2 rules)**

- **`require_webview_ssl_error_handling`**: Warns when WebView lacks `onSslError` handler
- **`avoid_webview_file_access`**: Warns when WebView has `allowFileAccess: true` enabled

**WorkManager Rules (2 rules)**

- **`require_workmanager_constraints`**: Warns when WorkManager task lacks network/battery constraints
- **`require_workmanager_result_return`**: Warns when WorkManager callback doesn't return TaskResult

**Dispose Pattern Rules (3 rules)**

- **`require_keyboard_visibility_dispose`**: Warns when KeyboardVisibilityController subscription not disposed
- **`require_speech_stop_on_dispose`**: Warns when SpeechToText instance not stopped in dispose
- **`require_calendar_timezone_handling`**: Warns when calendar events lack time zone handling

**Deep Linking & Security Rules (3 rules)**

- **`avoid_app_links_sensitive_params`**: Warns when deep link URLs contain sensitive parameters (token, password)
- **`require_envied_obfuscation`**: Warns when @Envied annotation lacks `obfuscate: true`
- **`require_openai_error_handling`**: Warns when OpenAI API calls lack error handling

**UI Component Rules (3 rules)**

- **`require_svg_error_handler`**: Warns when SvgPicture lacks `errorBuilder` parameter
- **`require_google_fonts_fallback`**: Warns when GoogleFonts lacks `fontFamilyFallback`
- **`prefer_uuid_v4`**: Suggests using UUID v4 over v1 for better randomness

## [2.1.0]

#### SharedPreferences Security Rules (4 rules)

- **`avoid_shared_prefs_sensitive_data`**: Warns when sensitive data (passwords, tokens) is stored in SharedPreferences
- **`require_secure_storage_for_auth`**: Warns when auth tokens use SharedPreferences instead of flutter_secure_storage
- **`require_shared_prefs_null_handling`**: Warns when SharedPreferences getter is used with null assertion
- **`require_shared_prefs_key_constants`**: Warns when string literals are used as SharedPreferences keys

#### sqflite Database Rules (5 rules)

- **`require_sqflite_whereargs`**: Warns when SQL queries use string interpolation - SQL injection vulnerability
- **`require_sqflite_transaction`**: Warns when multiple sequential writes should use transaction
- **`require_sqflite_error_handling`**: Warns when database operations lack try-catch
- **`prefer_sqflite_batch`**: Warns when database insert is in a loop - use batch operations
- **`require_sqflite_close`**: Warns when database is opened but not closed in dispose

#### Hive Database Rules (5 rules)

- **`require_hive_initialization`**: Reminds to ensure Hive.init() is called before openBox (heuristic)
- **`require_hive_type_adapter`**: Warns when custom object is stored in Hive without @HiveType
- **`require_hive_box_close`**: Warns when Hive box is opened but not closed in dispose
- **`prefer_hive_encryption`**: Warns when sensitive data is stored in unencrypted Hive box
- **`require_hive_encryption_key_secure`**: Warns when HiveAesCipher uses hardcoded key

#### Dio HTTP Client Rules (6 rules)

- **`require_dio_timeout`**: Warns when Dio instance lacks timeout configuration
- **`require_dio_error_handling`**: Warns when Dio requests lack error handling
- **`require_dio_interceptor_error_handler`**: Warns when InterceptorsWrapper lacks onError callback
- **`prefer_dio_cancel_token`**: Warns when long-running Dio requests lack CancelToken
- **`require_dio_ssl_pinning`**: Warns when Dio auth endpoints lack SSL certificate pinning
- **`avoid_dio_form_data_leak`**: Warns when FormData with files lacks cleanup

#### Stream/Future Rules (6 rules)

- **`avoid_stream_in_build`**: Warns when StreamController is created in build() method
- **`require_stream_controller_close`**: Warns when StreamController field is not closed in dispose
- **`avoid_multiple_stream_listeners`**: Warns when multiple listen() calls on non-broadcast stream
- **`require_stream_error_handling`**: Warns when stream.listen() lacks onError callback
- **`avoid_future_builder_rebuild`**: Warns when FutureBuilder has inline future in build
- **`require_future_timeout`**: Warns when long-running Future lacks timeout

#### go_router Navigation Rules (4 rules)

- **`avoid_go_router_inline_creation`**: Warns when GoRouter is created inside build() method
- **`require_go_router_error_handler`**: Warns when GoRouter lacks errorBuilder
- **`require_go_router_refresh_listenable`**: Warns when GoRouter with redirect lacks refreshListenable
- **`avoid_go_router_string_paths`**: Warns when string literals used in go_router navigation

#### Riverpod Rules (3 rules)

- **`require_riverpod_error_handling`**: Warns when AsyncValue is accessed without error handling
- **`avoid_riverpod_state_mutation`**: Warns when state is mutated directly in Notifier
- **`prefer_riverpod_select`**: Warns when ref.watch() accesses single field - use select()

#### cached_network_image Rules (3 rules)

- **`require_cached_image_dimensions`**: Warns when CachedNetworkImage lacks cache dimensions
- **`require_cached_image_placeholder`**: Warns when CachedNetworkImage lacks placeholder
- **`require_cached_image_error_widget`**: Warns when CachedNetworkImage lacks errorWidget

#### Geolocator Rules (4 rules)

- **`require_geolocator_permission_check`**: Warns when location request lacks permission check
- **`require_geolocator_service_enabled`**: Warns when location request lacks service enabled check
- **`require_geolocator_stream_cancel`**: Warns when position stream subscription lacks cancel
- **`require_geolocator_error_handling`**: Warns when location request lacks error handling

#### State Management Rules (11 rules)

- **`avoid_yield_in_on_event`**: Warns when yield is used in Bloc event handler (deprecated in Bloc 8.0+)
- **`prefer_consumer_over_provider_of`**: Warns when Provider.of<T>(context) is used in build method
- **`avoid_listen_in_async`**: Warns when context.watch() is used inside async callback
- **`prefer_getx_builder`**: Warns when .obs property is accessed without Obx wrapper
- **`emit_new_bloc_state_instances`**: Warns when emit(state..property = x) cascade mutation is used
- **`avoid_bloc_public_fields`**: Warns when Bloc has public non-final fields
- **`avoid_bloc_public_methods`**: Warns when Bloc has public methods other than add()
- **`require_async_value_order`**: Warns when AsyncValue.when() has wrong parameter order
- **`require_bloc_selector`**: Warns when BlocBuilder only uses one field from state
- **`prefer_selector`**: Warns when context.watch<T>() is used without select()
- **`require_getx_binding`**: Warns when Get.put() is used in widget build - use Bindings

#### Theming Rules (3 rules)

- **`require_dark_mode_testing`**: Warns when MaterialApp is missing darkTheme parameter
- **`avoid_elevation_opacity_in_dark`**: Warns when high elevation used without brightness check
- **`prefer_theme_extensions`**: Warns when ThemeData.copyWith used for custom colors

#### UI/UX Rules (5 rules)

- **`prefer_skeleton_over_spinner`**: Suggests skeleton loaders over CircularProgressIndicator
- **`require_empty_results_state`**: Warns when search list lacks empty state handling
- **`require_search_loading_indicator`**: Warns when search callback lacks loading state
- **`require_search_debounce`**: Warns when search onChanged triggers API without debounce
- **`require_pagination_loading_state`**: Warns when paginated list lacks loading indicator

#### Lifecycle Rules (2 rules)

- **`avoid_work_in_paused_state`**: Warns when Timer.periodic runs without lifecycle handling
- **`require_resume_state_refresh`**: Warns when didChangeAppLifecycleState handles paused but not resumed

#### Security Rules (4 rules)

- **`require_url_validation`**: Warns when Uri.parse on variable lacks scheme validation
- **`avoid_redirect_injection`**: Warns when redirect URL from parameter lacks domain validation
- **`avoid_external_storage_sensitive`**: Warns when sensitive data written to external storage
- **`prefer_local_auth`**: Warns when payment/sensitive operation lacks biometric authentication

#### Firebase Rules (3 rules)

- **`require_crashlytics_user_id`**: Warns when Crashlytics setup lacks setUserIdentifier
- **`require_firebase_app_check`**: Warns when Firebase.initializeApp lacks App Check activation
- **`avoid_storing_user_data_in_auth`**: Warns when setCustomClaims stores large user data

#### Collection/Performance Rules (4 rules)

- **`prefer_null_aware_elements`**: Warns when if (x != null) x can use ?x syntax
- **`prefer_iterable_operations`**: Warns when .toList() after chain in for-in is unnecessary
- **`prefer_inherited_widget_cache`**: Warns when same .of(context) called 3+ times in method
- **`prefer_layout_builder_over_media_query`**: Warns when MediaQuery.of in list item builder

#### Flutter Widget Rules (3 rules)

- **`require_should_rebuild`**: Warns when InheritedWidget missing updateShouldNotify
- **`require_orientation_handling`**: Warns when MaterialApp lacks orientation handling
- **`require_web_renderer_awareness`**: Warns when kIsWeb check uses HTML APIs without renderer check

#### Image/Media Rules (4 rules)

- **`require_exif_handling`**: Warns when Image.file may show photos rotated
- **`prefer_camera_resolution_selection`**: Warns when CameraController uses max resolution
- **`prefer_audio_session_config`**: Warns when AudioPlayer lacks audio session config
- **`require_image_loading_placeholder`**: Warns when Image.network lacks loadingBuilder

#### Scroll/Navigation Rules (1 rule)

- **`require_refresh_indicator_on_lists`**: Warns when ListView lacks RefreshIndicator wrapper

#### Dialog/SnackBar Rules (2 rules)

- **`prefer_adaptive_dialog`**: Warns when AlertDialog lacks adaptive styling
- **`require_snackbar_action_for_undo`**: Warns when delete SnackBar lacks undo action

#### API/Network Rules (2 rules)

- **`require_content_type_check`**: Warns when response parsed without Content-Type check
- **`avoid_websocket_without_heartbeat`**: Warns when WebSocket lacks heartbeat/ping mechanism

#### Forms Rules (1 rule)

- **`avoid_keyboard_overlap`**: Warns when TextField in Column may be hidden by keyboard

#### Location Rules (1 rule)

- **`require_location_timeout`**: Warns when Geolocator.getCurrentPosition lacks timeLimit

#### Code Quality Rules (1 rule)

- **`prefer_dot_shorthand`**: Suggests Dart 3 dot shorthand (.value) for enum values

#### Architecture Rules (1 rule)

- **`avoid_touch_only_gestures`**: Warns when GestureDetector only handles touch gestures

#### Async Rules (3 rules)

- **`require_future_wait_error_handling`**: Warns when Future.wait lacks eagerError: false
- **`require_stream_on_done`**: Warns when Stream.listen lacks onDone handler
- **`require_completer_error_handling`**: Warns when Completer in try-catch lacks completeError

## [2.0.0]

### Changed

- **Rule aliases**: Each rule now tracks numerous aliases and alternate names, making it easier to find rules by different naming conventions (e.g., `avoid_`, `prefer_`, `require_` variants)

### Fixed

- **`require_text_editing_controller_dispose`**: Fixed false positives for controllers passed in from callbacks (e.g., Autocomplete's `fieldViewBuilder`). Rule now only flags controllers that are actually instantiated by the class (via inline initialization or in `initState`), not those assigned from external sources.
- **`require_page_controller_dispose`**: Same ownership-based detection fix as above.

### Added

#### Riverpod Rules (8 rules)

- **`avoid_ref_read_inside_build`**: Warns when ref.read() is used inside build() - use ref.watch() for reactivity
- **`avoid_ref_watch_outside_build`**: Warns when ref.watch() is used outside build() - causes subscription leaks
- **`avoid_ref_inside_state_dispose`**: Warns when ref is accessed in dispose() - ref is unavailable there
- **`use_ref_read_synchronously`**: Warns when ref.read() is called after await - cache before async gap
- **`use_ref_and_state_synchronously`**: Warns when ref/state is used after await - cache before async gap
- **`avoid_assigning_notifiers`**: Warns when assigning to notifier variables - breaks provider contract
- **`avoid_notifier_constructors`**: Warns when Notifier has constructor - use build() for initialization
- **`prefer_immutable_provider_arguments`**: Warns when provider arguments are not final

#### Bloc State Management Rules (8 rules)

- **`check_is_not_closed_after_async_gap`**: Warns when emit() is called after await without isClosed check
- **`avoid_duplicate_bloc_event_handlers`**: Warns when multiple on<SameEvent> handlers are registered
- **`prefer_immutable_bloc_events`**: Warns when Bloc event classes have mutable fields
- **`prefer_immutable_bloc_state`**: Warns when Bloc state classes have mutable fields
- **`prefer_sealed_bloc_events`**: Suggests using sealed keyword for event base classes
- **`prefer_sealed_bloc_state`**: Suggests using sealed keyword for state base classes
- **`prefer_bloc_event_suffix`**: Suggests Bloc event classes end with 'Event' suffix
- **`prefer_bloc_state_suffix`**: Suggests Bloc state classes end with 'State' suffix

#### Riverpod Widget Rules (2 rules)

- **`avoid_unnecessary_consumer_widgets`**: Warns when ConsumerWidget doesn't use ref
- **`avoid_nullable_async_value_pattern`**: Warns when nullable access patterns used on AsyncValue

#### Collection & Loop Rules (2 rules)

- **`prefer_correct_for_loop_increment`**: Warns when for loop uses non-standard increment patterns
- **`avoid_unreachable_for_loop`**: Warns when for loop has impossible bounds

#### Widget Optimization Rules (4 rules)

- **`prefer_single_setstate`**: Warns when multiple setState calls in same method
- **`prefer_compute_over_isolate_run`**: Suggests using compute() instead of Isolate.run()
- **`prefer_for_loop_in_children`**: Warns when List.generate used in widget children
- **`prefer_container`**: Warns when nested decoration widgets could be Container

#### Flame Engine Rules (2 rules)

- **`avoid_creating_vector_in_update`**: Warns when Vector2/Vector3 created in update() - GC churn
- **`avoid_redundant_async_on_load`**: Warns when async onLoad() has no await

#### Code Quality Rules (4 rules)

- **`prefer_typedefs_for_callbacks`**: Suggests using typedefs for callback function types
- **`prefer_redirecting_superclass_constructor`**: Suggests using super parameters
- **`avoid_empty_build_when`**: Warns when buildWhen always returns true
- **`prefer_use_prefix`**: Suggests using 'use' prefix for custom hooks

#### Provider Advanced Rules (5 rules)

- **`prefer_immutable_selector_value`**: Warns when mutable values used in Selector
- **`prefer_provider_extensions`**: Warns when long provider access chains used
- **`dispose_provided_instances`**: Warns when Provider.create returns disposable without dispose callback
- **`dispose_getx_fields`**: Warns when GetxController has Worker fields not disposed in onClose
- **`prefer_nullable_provider_types`**: Warns when Provider type is non-nullable but create may return null

#### GetX Build Rules (2 rules)

- **`avoid_getx_rx_inside_build`**: Warns when .obs is used inside build() - memory leaks
- **`avoid_mutable_rx_variables`**: Warns when Rx variables are reassigned - breaks reactivity

#### Internationalization Rules (4 rules)

- **`prefer_date_format`**: Warns when raw DateTime methods (toIso8601String, toString) are used - use DateFormat for locale-aware formatting
- **`prefer_intl_name`**: Warns when Intl.message() lacks name parameter - required for translation extraction
- **`prefer_providing_intl_description`**: Warns when Intl.message() lacks desc parameter - helps translators understand context
- **`prefer_providing_intl_examples`**: Warns when Intl.message() lacks examples parameter - helps translators with placeholders

#### Error Handling Rules (1 rule)

- **`avoid_uncaught_future_errors`**: Warns when Future is used without error handling (catchError, onError, or try-catch)

#### Type Safety Rules (1 rule)

- **`prefer_explicit_type_arguments`**: Warns when generic types lack explicit type arguments - prevents accidental dynamic typing

#### Container Widget Rules (5 rules)

- **`prefer_sized_box_square`**: Warns when SizedBox(width: X, height: X) uses identical values - use SizedBox.square() instead
- **`prefer_center_over_align`**: Warns when Align(alignment: Alignment.center) is used - use Center widget instead
- **`prefer_align_over_container`**: Warns when Container is used only for alignment - use Align widget instead
- **`prefer_padding_over_container`**: Warns when Container is used only for padding - use Padding widget instead
- **`prefer_constrained_box_over_container`**: Warns when Container is used only for constraints - use ConstrainedBox instead
- **`prefer_multi_bloc_provider`**: Warns when nested BlocProviders are used - use MultiBlocProvider instead
- **`avoid_instantiating_in_bloc_value_provider`**: Warns when BlocProvider.value creates a new bloc - memory leak risk
- **`avoid_existing_instances_in_bloc_provider`**: Warns when BlocProvider(create:) returns existing variable - use .value instead
- **`prefer_correct_bloc_provider`**: Warns when wrong BlocProvider variant is used for the use case
- **`prefer_multi_provider`**: Warns when nested Providers are used - use MultiProvider instead
- **`avoid_instantiating_in_value_provider`**: Warns when Provider.value creates a new instance - lifecycle not managed
- **`dispose_providers`**: Warns when Provider lacks dispose callback - resource cleanup
- **`proper_getx_super_calls`**: Warns when GetxController lifecycle methods don't call super
- **`always_remove_getx_listener`**: Warns when GetX workers are not assigned for cleanup
- **`avoid_hooks_outside_build`**: Warns when Flutter hooks (use\* functions) are called outside build methods
- **`avoid_conditional_hooks`**: Warns when hooks are called inside conditionals (breaks hook rules)
- **`avoid_unnecessary_hook_widgets`**: Warns when HookWidget doesn't use any hooks - use StatelessWidget instead
- **`extend_equatable`**: Warns when a class overrides operator == but doesn't use Equatable
- **`list_all_equatable_fields`**: Warns when Equatable class has fields not included in props
- **`prefer_equatable_mixin`**: Suggests using EquatableMixin instead of extending Equatable
- **`enum_constants_ordering`**: Warns when enum constants are not in alphabetical order
- **`missing_test_assertion`**: Warns when a test body has no assertions (expect, verify, etc.)
- **`avoid_async_callback_in_fake_async`**: Warns when async callback is used inside fakeAsync - defeats fake time control
- **`prefer_symbol_over_key`**: Suggests using constant Keys instead of string literals in tests
- **`incorrect_firebase_event_name`**: Warns when Firebase Analytics event name doesn't follow conventions
- **`incorrect_firebase_parameter_name`**: Warns when Firebase Analytics parameter name doesn't follow conventions
- **`prefer_transform_over_container`**: Warns when Container only has transform - use Transform widget
- **`prefer_action_button_tooltip`**: Warns when IconButton/FAB lacks tooltip for accessibility
- **`prefer_void_callback`**: Suggests using VoidCallback typedef instead of void Function()
- **`avoid_functions_in_register_singleton`**: Warns when function is passed to registerSingleton (use registerLazySingleton)

#### Image & Media Rules (4 rules)

- **`require_image_loading_placeholder`**: Warns when Image.network lacks loadingBuilder - improves UX during image load
- **`require_media_loading_state`**: Warns when VideoPlayer is used without isInitialized check - prevents blank widget display
- **`require_pdf_loading_indicator`**: Warns when PDF viewer lacks loading state handling - large PDFs need load feedback
- **`prefer_clipboard_feedback`**: Warns when Clipboard.setData lacks user feedback (SnackBar/Toast) - users need confirmation

#### Disposal & Cleanup Rules (1 rule)

- **`require_stream_subscription_cancel`**: Warns when StreamSubscription field is not cancelled in dispose() - memory leak risk

#### Async Safety Rules (5 rules)

- **`avoid_dialog_context_after_async`**: Warns when Navigator.pop uses context after await in dialog callback - context may be invalid
- **`require_websocket_message_validation`**: Warns when WebSocket message is processed without validation/try-catch
- **`require_feature_flag_default`**: Warns when RemoteConfig is accessed without fallback value - graceful degradation
- **`prefer_utc_for_storage`**: Warns when DateTime is stored without .toUtc() - causes timezone inconsistencies
- **`require_location_timeout`**: Warns when Geolocator request lacks timeout parameter - GPS can hang indefinitely

#### Firebase & Maps Rules (8 rules)

- **`prefer_firestore_batch_write`**: Warns when multiple sequential Firestore writes should use batch operation
- **`avoid_firestore_in_widget_build`**: Warns when Firestore query is inside build() method - causes unnecessary reads
- **`prefer_firebase_remote_config_defaults`**: Warns when RemoteConfig.getInstance() used without setDefaults()
- **`require_fcm_token_refresh_handler`**: Warns when FCM usage lacks onTokenRefresh listener - tokens expire
- **`require_background_message_handler`**: Warns when FCM lacks top-level background handler - required for background messages
- **`avoid_map_markers_in_build`**: Warns when Map Marker() is created inside build() - causes rebuilds
- **`require_map_idle_callback`**: Warns when data fetch is on onCameraMove instead of onCameraIdle - too frequent
- **`prefer_marker_clustering`**: Warns when many individual markers are used without clustering - performance issue

#### Accessibility Rules (7 rules)

- **`require_image_description`**: Warns when Image lacks semanticLabel or explicit excludeFromSemantics
- **`avoid_semantics_exclusion`**: Warns when excludeFromSemantics:true is used - should be justified with comment
- **`prefer_merge_semantics`**: Warns when Icon+Text siblings lack MergeSemantics wrapper - better screen reader UX
- **`require_focus_indicator`**: Warns when interactive widgets lack visible focus styling
- **`avoid_flashing_content`**: Warns when animation flashes more than 3 times per second - seizure risk
- **`prefer_adequate_spacing`**: Warns when touch targets have less than 8dp spacing - accessibility guideline
- **`avoid_motion_without_reduce`**: Warns when animation lacks MediaQuery.disableAnimations check - accessibility

#### Navigation & Dialog Rules (6 rules)

- **`require_deep_link_fallback`**: Warns when deep link handler lacks error/not-found fallback
- **`avoid_deep_link_sensitive_params`**: Warns when deep link contains password/token params - security risk
- **`prefer_typed_route_params`**: Warns when route parameters are used without type parsing
- **`require_stepper_validation`**: Warns when Stepper onStepContinue lacks validation before proceeding
- **`require_step_count_indicator`**: Warns when multi-step flow lacks progress indicator
- **`require_refresh_indicator_on_lists`**: Warns when ListView.builder lacks RefreshIndicator wrapper

#### Animation Rules (5 rules)

- **`prefer_tween_sequence`**: Warns when multiple chained .forward().then() should use TweenSequence
- **`require_animation_status_listener`**: Warns when one-shot animation lacks StatusListener for completion
- **`avoid_overlapping_animations`**: Warns when multiple transitions animate the same property (scale, opacity)
- **`avoid_animation_rebuild_waste`**: Warns when AnimatedBuilder wraps large widget trees (Scaffold, etc.)
- **`prefer_physics_simulation`**: Warns when drag-release uses animateTo instead of SpringSimulation

#### Platform-Specific Rules (7 rules)

- **`avoid_platform_channel_on_web`**: Warns when MethodChannel is used without kIsWeb check - not available on web
- **`require_cors_handling`**: Warns when HTTP calls in web-specific files lack CORS consideration
- **`prefer_deferred_loading_web`**: Warns when heavy packages lack deferred import on web - improves load time
- **`require_menu_bar_for_desktop`**: Warns when desktop app lacks PlatformMenuBar - standard desktop UX
- **`avoid_touch_only_gestures`**: Warns when GestureDetector lacks mouse handlers on desktop
- **`require_window_close_confirmation`**: Warns when desktop app's WidgetsBindingObserver lacks didRequestAppExit
- **`prefer_native_file_dialogs`**: Warns when showDialog is used for file picking on desktop - use native dialogs

#### Testing Rules (4 rules)

- **`require_test_cleanup`**: Warns when test creates files/data without tearDown cleanup
- **`prefer_test_variant`**: Warns when similar tests with different screen sizes should use variant
- **`require_accessibility_tests`**: Warns when widget tests lack meetsGuideline accessibility checks
- **`require_animation_tests`**: Warns when animated widget tests use pump() without duration

---

## [1.8.2]

### Added

- **`require_text_editing_controller_dispose`**: Warns when TextEditingController is not disposed in StatefulWidget - very common source of memory leaks in forms
- **`require_page_controller_dispose`**: Warns when PageController is not disposed - prevents memory leaks in PageView widgets
- **`require_avatar_alt_text`**: Warns when CircleAvatar lacks semanticLabel - accessibility requirement for screen readers
- **`require_badge_semantics`**: Warns when Badge widget is not wrapped in Semantics - notification badges need accessible labels
- **`require_badge_count_limit`**: Warns when Badge shows count > 99 - UX best practice to show "99+" for large counts
- **`avoid_image_rebuild_on_scroll`**: Warns when Image.network is used in ListView.builder - causes unnecessary rebuilds and network requests
- **`require_avatar_fallback`**: Warns when CircleAvatar with NetworkImage lacks onBackgroundImageError - network failures leave broken avatars
- **`prefer_video_loading_placeholder`**: Warns when video player widgets (Chewie, BetterPlayer) lack placeholder - improves UX during load
- **`require_snackbar_duration`**: Warns when SnackBar lacks explicit duration - ensures consistent UX timing
- **`require_dialog_barrier_dismissible`**: Warns when showDialog lacks explicit barrierDismissible - makes dismiss behavior explicit
- **`require_dialog_result_handling`**: Warns when showDialog result is not awaited - prevents missed user confirmations
- **`avoid_snackbar_queue_buildup`**: Warns when showSnackBar is called without clearing previous - prevents stale message queues
- **`require_keyboard_action_type`**: Warns when TextField/TextFormField lacks textInputAction - improves form navigation UX
- **`require_keyboard_dismiss_on_scroll`**: Warns when scroll views lack keyboardDismissBehavior - better form UX on scroll
- **`prefer_duration_constants`**: Warns when Duration can use cleaner units (e.g., seconds: 60 -> minutes: 1)
- **`avoid_datetime_now_in_tests`**: Warns when DateTime.now() is used in test files - causes flaky tests
- **`require_responsive_breakpoints`**: Warns when MediaQuery width is compared to magic numbers - promotes named breakpoint constants
- **`prefer_cached_paint_objects`**: Warns when Paint() is created inside CustomPainter.paint() - recreated every frame
- **`require_custom_painter_shouldrepaint`**: Warns when shouldRepaint always returns true - causes unnecessary repaints
- **`require_currency_formatting_locale`**: Warns when NumberFormat.currency lacks locale - currency format varies by locale
- **`require_number_formatting_locale`**: Warns when NumberFormat lacks locale - number format varies by locale
- **`require_graphql_operation_names`**: Warns when GraphQL query/mutation lacks operation name - harder to debug
- **`avoid_badge_without_meaning`**: Warns when Badge shows count 0 without hiding - empty badges confuse users
- **`prefer_logger_over_print`**: Warns when print() is used instead of dart:developer log() - better log management
- **`prefer_itemextent_when_known`**: Warns when ListView.builder lacks itemExtent - improves scroll performance
- **`require_tab_state_preservation`**: Warns when TabBarView children may lose state on tab switch
- **`avoid_bluetooth_scan_without_timeout`**: Warns when BLE scan lacks timeout - drains battery
- **`require_bluetooth_state_check`**: Warns when BLE operations start without adapter state check
- **`require_ble_disconnect_handling`**: Warns when BLE connection lacks disconnect state listener
- **`require_audio_focus_handling`**: Warns when audio playback lacks AudioSession configuration
- **`require_qr_permission_check`**: Warns when QR scanner is used without camera permission check - critical for app store
- **`require_qr_scan_feedback`**: Warns when QR scan callback lacks haptic/visual feedback
- **`avoid_qr_scanner_always_active`**: Warns when QR scanner lacks lifecycle pause/resume handling
- **`require_file_exists_check`**: Warns when file read operations lack exists() check or try-catch
- **`require_pdf_error_handling`**: Warns when PDF loading lacks error handling
- **`require_graphql_error_handling`**: Warns when GraphQL result is used without checking hasException
- **`prefer_image_size_constraints`**: Warns when Image lacks cacheWidth/cacheHeight for memory optimization
- **`require_lifecycle_observer`**: Warns when Timer.periodic is used without WidgetsBindingObserver lifecycle handling

### Documentation

- **Migration from solid_lints**: Complete rewrite of [migration_from_solid_lints.md](doc/guides/migration_from_solid_lints.md):
  - Corrected rule count: solid_lints has 16 custom rules (not ~50)
  - Full rule mapping table: saropa_lints implements 15 of 16 rules (94% coverage)
  - Fixed mappings: `avoid_final_with_getter` → `avoid_unnecessary_getter`, `avoid_unnecessary_return_variable` → `prefer_immediate_return`
  - Added `no_magic_number` and `avoid_late_keyword` mappings that were missing
  - Documented the one missing rule: `avoid_using_api` (configurable API restriction)
- **ROADMAP.md**: Added `avoid_banned_api` to Architecture Rules section (inspired by solid_lints' `avoid_using_api`)
- **State management guides**: New "Using with" guides for popular libraries:
  - [using_with_riverpod.md](doc/guides/using_with_riverpod.md) - 8 Riverpod-specific rules with examples
  - [using_with_bloc.md](doc/guides/using_with_bloc.md) - 8 Bloc-specific rules with examples
  - [using_with_provider.md](doc/guides/using_with_provider.md) - 4 Provider-specific rules with examples
  - [using_with_getx.md](doc/guides/using_with_getx.md) - 3 GetX-specific rules with examples
  - [using_with_isar.md](doc/guides/using_with_isar.md) - Isar enum corruption prevention
- **ROADMAP.md**: Added 12 new planned rules based on community research:
  - Riverpod: AsyncValue order, navigation patterns, package confusion
  - Bloc: BlocSelector usage, state over-engineering, manual dispose
  - GetX: Context access patterns, static context testing issues

## [1.8.1]

### Fixed

- **`avoid_double_for_money`**: Fixed remaining false positives:
  - Switched from substring matching to **word-boundary matching** - variable names are now split into words (camelCase/snake_case aware) and only exact word matches trigger the rule
  - Fixes issues like `audioVolume` matching `aud` or `imageUrlVerticalOffsetPercent` triggering false positives
  - Removed short currency codes (`usd`, `eur`, `gbp`, `jpy`, `cad`, `aud`, `yen`) - still too ambiguous even as complete words (e.g., "cad" for CAD files, "aud" for audio-related)

### Changed

- **Refactored rule files** for better organization:
  - Created `money_rules.dart` - moved `AvoidDoubleForMoneyRule`
  - Created `media_rules.dart` - moved `AvoidAutoplayAudioRule`
  - Moved `AvoidSensitiveDataInLogsRule` to `security_rules.dart`
  - Moved `RequireGetItResetInTestsRule` to `test_rules.dart`
  - Moved `RequireWebSocketErrorHandlingRule` to `api_network_rules.dart`
  - `json_datetime_rules.dart` now only contains JSON and DateTime parsing rules

### Quick Fixes

- `avoid_double_for_money`: Adds review comment for manual attention
- `avoid_sensitive_data_in_logs`: Comments out the sensitive log statement
- `require_getit_reset_in_tests`: Adds reminder comment for GetIt reset
- `require_websocket_error_handling`: Adds onError handler stub

## [1.8.0]

### Changed

- **`avoid_double_for_money`**: **BREAKING** - Rule is now much stricter to eliminate false positives. Only flags unambiguous money terms: `price`, `money`, `currency`, `salary`, `wage`, and currency codes (`dollar`, `euro`, `yen`, `usd`, `eur`, `gbp`, `jpy`, `cad`, `aud`). Generic terms like `total`, `amount`, `balance`, `cost`, `fee`, `tax`, `discount`, `payment`, `revenue`, `profit`, `budget`, `expense`, `income` are **no longer flagged** as they have too many non-monetary uses.

### Fixed

- **`avoid_sensitive_data_in_logs`**: Fixed false positives for null checks and property access. Now only flags direct value interpolation (`$password`, `${password}`), not expressions like `${credential != null}`, `${password.length}`, or `${token?.isEmpty}`. Pre-compiled regex patterns for better performance.
- **`avoid_hardcoded_encryption_keys`**: Simplified rule to only detect string literals passed directly to `Key.fromUtf8()`, `Key.fromBase64()`, etc. - removes false positives from variable name heuristics

## [1.7.12]

### Fixed

- **`require_unique_iv_per_encryption`**: Improved IV variable name detection to avoid false positives like "activity", "private", "derivative" - now uses proper word boundary detection for camelCase and snake_case patterns

### Quick Fixes

- **`require_unique_iv_per_encryption`**: Auto-replaces `IV.fromUtf8`/`IV.fromBase64` with `IV.fromSecureRandom(16)`

## [1.7.11]

### Fixed

- **`avoid_shrinkwrap_in_scrollview`**: Rule now properly skips widgets with `NeverScrollableScrollPhysics` - the recommended fix should no longer trigger the lint
- **Test fixtures**: Updated fixture files with correct `expect_lint` annotations and disabled conflicting rules in example analysis_options.yaml

## [1.7.10]

### Fixed

- **Rule detection for implicit constructors**: Fixed `avoid_gradient_in_build`, `avoid_shrinkwrap_in_scrollview`, `avoid_nested_scrollables_conflict`, and `avoid_excessive_bottom_nav_items` rules not detecting widgets created without explicit `new`/`const` keywords
- **AST visitor pattern**: Rules now use `GeneralizingAstVisitor` or `addNamedExpression` callbacks to properly detect both explicit and implicit constructor calls
- **Test fixtures**: Updated expect_lint positions to match actual lint locations

### Changed

- **Rule implementation**: `AvoidGradientInBuildRule` now uses `GeneralizingAstVisitor` with both `visitInstanceCreationExpression` and `visitMethodInvocation`
- **Rule implementation**: `AvoidShrinkWrapInScrollViewRule` now uses `addNamedExpression` to detect `shrinkWrap: true` directly
- **Rule implementation**: `AvoidNestedScrollablesConflictRule` now uses visitor pattern with `RecursiveAstVisitor`
- **Rule implementation**: `AvoidExcessiveBottomNavItemsRule` now uses `addNamedExpression` to detect excessive items

## [1.7.9]

### Added

- **29 New Rules** covering disposal, build method anti-patterns, scroll/list issues, cryptography, and JSON/DateTime handling:

#### Disposal Rules (2 rules)

- `require_media_player_dispose` - Warns when VideoPlayerController/AudioPlayer is not disposed
- `require_tab_controller_dispose` - Warns when TabController is not disposed

#### Build Method Anti-Patterns (8 rules)

- `avoid_gradient_in_build` - Warns when Gradient objects are created inside build()
- `avoid_dialog_in_build` - Warns when showDialog is called inside build()
- `avoid_snackbar_in_build` - Warns when showSnackBar is called inside build()
- `avoid_analytics_in_build` - Warns when analytics calls are made inside build()
- `avoid_json_encode_in_build` - Warns when jsonEncode is called inside build()
- `avoid_getit_in_build` - Warns when GetIt service locator is used inside build()
- `avoid_canvas_operations_in_build` - Warns when Canvas operations are used outside CustomPainter
- `avoid_hardcoded_feature_flags` - Warns when if(true)/if(false) patterns are used

#### Scroll and List Rules (7 rules)

- `avoid_shrinkwrap_in_scrollview` - Warns when shrinkWrap: true is used inside a ScrollView
- `avoid_nested_scrollables_conflict` - Warns when nested scrollables don't have explicit physics
- `avoid_listview_children_for_large_lists` - Suggests ListView.builder for large lists
- `avoid_excessive_bottom_nav_items` - Warns when BottomNavigationBar has more than 5 items
- `require_tab_controller_length_sync` - Validates TabController length matches tabs count
- `avoid_refresh_without_await` - Ensures RefreshIndicator onRefresh returns Future
- `avoid_multiple_autofocus` - Warns when multiple widgets have autofocus: true

#### Cryptography Rules (4 rules)

- `avoid_hardcoded_encryption_keys` - Warns when encryption keys are hardcoded
- `prefer_secure_random_for_crypto` - Warns when Random() is used for cryptographic purposes
- `avoid_deprecated_crypto_algorithms` - Warns when MD5, SHA1, DES are used
- `require_unique_iv_per_encryption` - Warns when static or reused IVs are detected

#### JSON and DateTime Rules (8 rules)

- `require_json_decode_try_catch` - Warns when jsonDecode is used without try-catch
- `avoid_datetime_parse_unvalidated` - Warns when DateTime.parse is used without try-catch
- `prefer_try_parse_for_dynamic_data` - **CRITICAL**: Warns when int/double/num.parse is used without try-catch
- `avoid_double_for_money` - Warns when double is used for money/currency values
- `avoid_sensitive_data_in_logs` - Warns when sensitive data appears in log statements
- `require_getit_reset_in_tests` - Warns when GetIt is used in tests without reset
- `require_websocket_error_handling` - Warns when WebSocket listeners lack error handlers
- `avoid_autoplay_audio` - Warns when autoPlay: true is set on audio/video players

### Changed

- **Docs**: Updated rule count from 792+ to 821+
- **Impact tuning**: `avoid_hardcoded_feature_flags` and `avoid_autoplay_audio` changed to `low` to match INFO severity
- **Impact tuning**: `avoid_double_for_money` promoted to `critical` to match ERROR severity (financial bugs)

### Quick Fixes

- `prefer_secure_random_for_crypto`: Auto-replaces `Random()` with `Random.secure()`
- `avoid_datetime_parse_unvalidated`: Auto-replaces `DateTime.parse` with `DateTime.tryParse`
- `prefer_try_parse_for_dynamic_data`: Auto-replaces `int/double/num.parse` with `tryParse`
- `avoid_autoplay_audio`: Auto-sets `autoPlay: false`
- `avoid_hardcoded_feature_flags`: Adds TODO comment for feature flag replacement

## [1.7.8]

### Added

- **25 New Rules** covering network performance, state management, testing, security, and database patterns:

#### Network Performance (6 rules)

- `prefer_http_connection_reuse` - Warns when HTTP clients are created without connection reuse
- `avoid_redundant_requests` - Warns about API calls in build()/initState() without caching
- `require_response_caching` - Warns when GET responses aren't cached
- `prefer_pagination` - Warns when APIs return large collections without pagination
- `avoid_over_fetching` - Warns when fetching more data than needed
- `require_cancel_token` - Warns when async requests lack cancellation in StatefulWidgets

#### State Management (3 rules)

- `require_riverpod_lint` - Warns when Riverpod projects don't include riverpod_lint
- `require_multi_provider` - Warns about nested Provider widgets instead of MultiProvider
- `avoid_nested_providers` - Warns about Provider inside Consumer callbacks

#### Testing (4 rules)

- `prefer_fake_over_mock` - Warns about excessive mocking vs simpler fakes
- `require_edge_case_tests` - Warns when tests don't cover edge cases
- `prefer_test_data_builder` - Warns about complex test objects without builders
- `avoid_test_implementation_details` - Warns when tests verify internal implementation

#### Security (6 rules)

- `require_data_encryption` - Warns when sensitive data stored without encryption
- `prefer_data_masking` - Warns when sensitive data displayed without masking
- `avoid_screenshot_sensitive` - Warns about sensitive screens without screenshot protection
- `require_secure_password_field` - Warns about password fields without secure keyboard settings
- `avoid_path_traversal` - Warns about file path traversal vulnerabilities
- `prefer_html_escape` - Warns about user content in WebViews without HTML escaping

#### Database (6 rules)

- `require_database_migration` - Warns about database schema changes without migration support
- `require_database_index` - Warns about queries on non-indexed fields
- `prefer_transaction_for_batch` - Warns about multiple writes not batched in transactions
- `require_hive_database_close` - Warns when database connections not properly closed
- `require_type_adapter_registration` - Warns about Hive type adapters not registered
- `prefer_lazy_box_for_large` - Warns about large data in regular Hive boxes vs lazy boxes

### Changed

- **Docs**: Updated rule count from 767+ to 792+
- **Impact tuning**: `prefer_fake_over_mock`, `prefer_test_data_builder`, `require_response_caching`, `avoid_over_fetching` changed to `opinionated`

### Quick Fix

- `require_secure_password_field`: Auto-adds `enableSuggestions: false` and `autocorrect: false`

## [1.7.7]

### Changed

- **Docs**: README now has a Limitations section clarifying Dart-only analysis and dependency_overrides behavior.

## [1.7.6]

### Added

- **Quick fix**: avoid_isar_enum_field auto-converts enum fields to string storage.

### Changed

- **Impact tuning**: avoid_isar_enum_field promoted to LintImpact.high.

### Fixed

- Restored NullabilitySuffix-based checks for analyzer compatibility.

## [1.7.5]

### Added

- **Opinionated severity**: Added LintImpact.opinionated.
- **New rule**: prefer_future_void_function_over_async_callback.
- **Configuration template**: Added example/analysis_options_template.yaml with 767+ rules.

### Fixed

- Empty block warnings in async callback fixture tests.

### Changed

- **Docs**: Updated counts to reflect 767+ rules.
- **Severity**: Stylistic rules moved to LintImpact.opinionated.

## [1.7.4]

- Updated the banner image to show the project name Saropa Lints.

## [1.7.3]

### Added

- **New documentation guides**: using_with_flutter_lints.md and migration_from_solid_lints.md.
- Added "Related Packages" section to VGA guide.

### Changed

- **Naming**: Standardized "Saropa Lints" vs saropa_lints across all docs.
- **Migration Guides**: Updated rules (766+), versions (^1.3.0), and tier counts.

## [1.7.2]

### Added

- **Impact Classification System**: Categorized rules by critical, high, medium, and low.
- **Impact Report CLI Tool**: dart run saropa_lints:impact_report for prioritized violation reporting.
- **47 New Rules**: Covering Riverpod, GetX, Bloc, Accessibility, Security, and Testing.
- **11 New Quick Fixes**.

## [1.7.1]

### Fixed

- Resolved 25 violations for curly_braces_in_flow_control_structures.

## [1.7.0]

### Added

- **50 New Rules**: Massive expansion across Riverpod, Build Performance, Testing, Security, and Forms.
- Added support for sealed events in Bloc.

---

## [1.6.0]

### Added

- **18 new lint rules** across 7 categories:

  **Animation Rules (4)**:
  - `avoid_hardcoded_duration` - Duration literals should be extracted to named constants for consistency [Info tier]
  - `require_animation_curve` - Animations without curves feel robotic; use CurvedAnimation [Info tier]
  - `prefer_implicit_animations` - Simple transitions (fade, scale) should use AnimatedOpacity etc. [Info tier]
  - `require_staggered_animation_delays` - List item animations should use Interval for cascade effect [Info tier]

  **Widget/UI Rules (4)**:
  - `avoid_fixed_dimensions` - Fixed pixel dimensions >200px break on different screen sizes [Info tier]
  - `require_theme_color_from_scheme` - Hardcoded Color/Colors.\* breaks theming [Info tier]
  - `prefer_color_scheme_from_seed` - Manual ColorScheme is error-prone; use fromSeed() [Info tier]
  - `prefer_rich_text_for_complex` - 3+ Text widgets in Row should use Text.rich [Info tier]

  **Forms Rules (1)**:
  - `require_error_message_context` - Generic validator messages like "Invalid" lack context [Info tier]

  **Storage Rules (1)**:
  - `avoid_prefs_for_large_data` - SharedPreferences is for small settings, not collections [Warning tier]

  **Network/API Rules (1)**:
  - `require_offline_indicator` - Connectivity checks without UI feedback confuse users [Info tier]

  **Resource Management Rules (3)**:
  - `require_camera_dispose` - CameraController must be disposed to release hardware [Error tier]
  - `require_image_compression` - Camera images should use maxWidth/maxHeight/imageQuality [Info tier]
  - `prefer_coarse_location_when_sufficient` - High GPS accuracy drains battery unnecessarily [Info tier]

  **State Management Rules (2)**:
  - `prefer_cubit_for_simple` - Bloc with ≤2 events is simpler as Cubit [Info tier]
  - `require_bloc_observer` - BlocProvider without BlocObserver loses centralized logging [Info tier]

  **Navigation Rules (1)**:
  - `require_route_transition_consistency` - Mixed route types (Material/Cupertino) look unprofessional [Info tier]

  **Testing Rules (1)**:
  - `require_test_groups` - 5+ tests without group() organization are hard to navigate [Info tier]

### Fixed

- **RequireThemeColorFromSchemeRule** - Now correctly excludes `Colors.transparent` from warnings
- **RequireTestGroupsRule** - Now correctly detects Windows-style test paths (`\test\`)
- **PreferImplicitAnimationsRule** - Fixed O(n²) performance issue; now uses efficient per-class tracking

## [1.5.3]

### Fixed

- **pub.dev scoring** - Fixed issues that caused loss of 70 pub points:
  - Added `.pubignore` to exclude `example/pubspec.yaml` which had a `path: ../` dependency that broke pana analysis
  - Excluded generated API docs (`doc/api/`), log files, scripts, and test fixtures from published package
  - Package size reduced from 4MB to 469KB

- **Dependency compatibility** - Updated `analyzer` constraint from `<10.0.0` to `<11.0.0` to support analyzer v10.0.0

### Added

- **GitHub Actions publish workflow** - Added `.github/workflows/publish.yml` for automated pub.dev publishing with dry-run option, analysis, format check, and tests

- **README badges** - Added pub points badge and rules count badge (650+)

### Changed

- **Troubleshooting documentation** - Reorganized README troubleshooting section with clearer subsections:
  - "IDE doesn't show lint warnings" - consolidated IDE troubleshooting steps
  - "Out of Memory errors" - new section with 3 solutions (cache clean, heap size, delete artifacts)
  - "Native crashes (Windows)" - moved existing crash fix content

## [1.5.2]

### Changed

- **API documentation** - Added `dartdoc_options.yaml` to exclude internal `custom_lint_client` library from generated docs, so only the main `saropa_lints` library appears in the sidebar.

- **API documentation landing page** - Added `doc/README.md` with API-focused content instead of repeating the project README on the documentation homepage.

## [1.5.1]

### Fixed

- **Fixture files in example directory were being skipped** - The `skipFixtureFiles` logic incorrectly skipped all `*_fixture.dart` files, including test fixtures in the `example/` directory that are specifically for validating lint rules. Now fixture files in `example/` and `examples/` directories are analyzed.

- **`avoid_unsafe_collection_methods`** - Fixed enum `.values` detection:
  - `TestEnum.values.first` was incorrectly flagged as unsafe
  - Now properly recognizes `List<EnumType>` from `.values` as guaranteed non-empty
  - Uses `staticType` of the entire expression to detect enum element types

- **`prefer_where_or_null`** - Made type checking more robust:
  - Changed from `startsWith` to `contains` for type name matching
  - Now handles cases where type resolution returns null gracefully

- **Removed duplicate rule** - `MissingTestAssertionRule` was duplicating `RequireTestAssertionsRule`. Removed the duplicate from test_rules.dart.

- **`prefer_unique_test_names`** - Fixed potential race condition where `testNames` set was cleared in one callback but used in another. Refactored to use visitor pattern inside single callback.

- **`avoid_unnecessary_return`** - Quick fix now properly deletes the unnecessary return statement instead of commenting it out.

- **Test file detection** - Fixed 4 rules to detect test files in `/test/` and `\test\` directories, not just `_test.dart` suffix:
  - `AvoidEmptyTestGroupsRule`
  - `PreferExpectLaterRule`
  - `PreferTestStructureRule`
  - `AvoidTopLevelMembersInTestsRule`

- **`no_empty_block`** - Quick fix no longer uses hardcoded 6-space indentation; now uses minimal indentation and relies on formatter.

### Changed

- **`FormatTestNameRule`** - Renamed to `PreferDescriptiveTestNameRule` to match its LintCode name `prefer_descriptive_test_name`.

- **Example analysis_options.yaml** - Explicitly enabled `avoid_debug_print`, `avoid_print_in_production`, and `prefer_where_or_null` for fixture testing (these rules are in higher tiers than the default `recommended` tier)

### Added

- **`prefer_expect_later`** - Added quick fix that replaces `expect` with `expectLater` for Future assertions.

- **`prefer_returning_shorthands`** - Added quick fix that converts `{ return x; }` to `=> x` arrow syntax.

## [1.5.0]

### Changed

- **`require_animation_controller_dispose`** - Improved detection accuracy:
  - Now recognizes `disposeSafe()` as a valid disposal method alongside `dispose()`, supporting safe disposal extension patterns commonly used in Flutter apps
  - Excludes collection types (`List<>`, `Set<>`, `Map<>`, `Iterable<>`) containing AnimationController from detection, as these require loop-based disposal patterns that the rule cannot validate
  - Expanded documentation with detection criteria, valid disposal patterns, and collection handling guidance

### Added

- **24 new lint rules** across 7 categories:

  **Animation Rules (5)** - New `animation_rules.dart`:
  - `require_vsync_mixin` - AnimationController requires vsync parameter; warns when missing [Error tier] (quick-fix)
  - `avoid_animation_in_build` - AnimationController in build() recreates on every rebuild [Error tier]
  - `require_animation_controller_dispose` - AnimationController must be disposed to prevent memory leaks [Error tier] (quick-fix)
  - `require_hero_tag_uniqueness` - Duplicate Hero tags cause "Multiple heroes" runtime error [Error tier]
  - `avoid_layout_passes` - IntrinsicWidth/Height cause two layout passes, hurting performance [Warning tier]

  **Forms & Validation Rules (4)** - New `forms_rules.dart`:
  - `prefer_autovalidate_on_interaction` - AutovalidateMode.always validates every keystroke; poor UX [Info tier] (quick-fix)
  - `require_keyboard_type` - Email/phone fields should use appropriate keyboardType [Info tier]
  - `require_text_overflow_in_row` - Text in Row without overflow handling may cause overflow errors [Info tier]
  - `require_secure_keyboard` - Password fields must use obscureText: true [Warning tier] (quick-fix)

  **Navigation Rules (2)** - New `navigation_rules.dart`:
  - `require_unknown_route_handler` - MaterialApp/CupertinoApp with routes should have onUnknownRoute [Warning tier]
  - `avoid_context_after_navigation` - Using context after await navigation; widget may be disposed [Warning tier] (quick-fix)

  **Firebase & Database Rules (4)** - New `firebase_rules.dart`:
  - `avoid_firestore_unbounded_query` - Firestore query without limit() could return excessive data [Warning tier]
  - `avoid_database_in_build` - Database query in build() runs on every rebuild [Warning tier]
  - `require_prefs_key_constants` - SharedPreferences keys should be constants, not string literals [Info tier]
  - `avoid_secure_storage_on_web` - flutter_secure_storage uses localStorage on web (not secure) [Warning tier]

  **Security Rules (3)**:
  - `prefer_secure_random` - Random() is predictable; use Random.secure() for security-sensitive code [Warning tier] (quick-fix)
  - `prefer_typed_data` - List<int> for binary data wastes memory; use Uint8List instead [Info tier]
  - `avoid_unnecessary_to_list` - .toList() may be unnecessary; lazy iterables are more efficient [Info tier]

  **State Management Rules (3)**:
  - `avoid_provider_of_in_build` - Provider.of in build() causes rebuilds; use context.read() for actions [Info tier]
  - `avoid_get_find_in_build` - Get.find() in build() is inefficient; use GetBuilder or Obx instead [Info tier]
  - `avoid_provider_recreate` - Provider created in frequently rebuilding build() loses state [Warning tier]

  **Accessibility Rules (3)**:
  - `avoid_text_scale_factor_ignore` - Don't ignore textScaleFactor; users need accessibility scaling [Warning tier]
  - `require_image_semantics` - Decorative images should use excludeFromSemantics: true [Info tier]
  - `avoid_hidden_interactive` - Interactive elements hidden from screen readers but visible [Warning tier]

### Fixed

- **RequireHeroTagUniquenessRule** - Fixed logic bug where heroTags map was local to runWithReporter callback, preventing duplicate detection across file. Now uses CompilationUnit visitor pattern.

- **Quick fix professionalism** - Replaced all "HACK" comments with "TODO" comments across 10 rule files (34 quick fixes total):
  - async_rules.dart (7 fixes)
  - collection_rules.dart (2 fixes)
  - control_flow_rules.dart (1 fix)
  - complexity_rules.dart (2 fixes)
  - error_handling_rules.dart (1 fix)
  - equality_rules.dart (4 fixes)
  - exception_rules.dart (3 fixes)
  - performance_rules.dart (2 fixes)
  - structure_rules.dart (5 fixes)
  - type_rules.dart (7 fixes)

## [1.4.4]

### Changed

- **ROADMAP.md** - Major documentation expansion:
  - Expanded all rule descriptions in sections 2.1-2.6 with detailed, actionable explanations
  - Added 14 new rule categories (sections 2.7-2.20) with 130+ new planned rules:
    - 2.7 Animation Rules (12 rules)
    - 2.8 Navigation & Routing Rules (16 rules)
    - 2.9 Forms & Validation Rules (12 rules)
    - 2.10 Database & Storage Rules (14 rules)
    - 2.11 Platform-Specific Rules (24 rules for iOS, Android, Web, Desktop)
    - 2.12 Firebase Rules (12 rules)
    - 2.13 Offline-First & Sync Rules (8 rules)
    - 2.14 Background Processing Rules (6 rules)
    - 2.15 Push Notification Rules (8 rules)
    - 2.16 Payment & In-App Purchase Rules (8 rules)
    - 2.17 Maps & Location Rules (8 rules)
    - 2.18 Camera & Media Rules (8 rules)
    - 2.19 Theming & Dark Mode Rules (8 rules)
    - 2.20 Responsive & Adaptive Design Rules (10 rules)
  - Total planned rules now 347 (up from ~253)

- **README.md** - Updated rule counts:
  - Essential tier: 60 critical rules (was 55)
  - Total implemented: 628 rules (was 500+)
  - Added planned rule count (347) to project description

- **cspell.json** - Added technical terms: assetlinks, autovalidate, backgrounded, backgrounding, EXIF, geofencing, unfocus, unindexed, vsync, workmanager

## [1.4.3]

### Added

- **7 new high-impact lint rules**:

  **Flutter Widget Rules (3)**:
  - `avoid_shrink_wrap_in_scroll` - Detects ListView/GridView/SingleChildScrollView with shrinkWrap: true, which causes O(n) layout cost and defeats lazy loading [Warning tier]
  - `avoid_deep_widget_nesting` - Warns when widget build methods have depth > 15 levels; extract to separate widgets for maintainability [Info tier]
  - `prefer_safe_area_aware` - Scaffold body content should be wrapped in SafeArea for edge content handling [Info tier]

  **State Management Rules (2)**:
  - `avoid_ref_in_build_body` - Detects ref.read() inside build() method body; use ref.watch() for reactive updates in Riverpod [Warning tier]
  - `require_immutable_bloc_state` - BLoC state classes should be annotated with @immutable or extend Equatable [Error tier]

  **API & Network Rules (1)**:
  - `require_request_timeout` - HTTP requests (http.get/post/etc, Dio) should have timeout configured to prevent hanging requests [Warning tier]

  **Testing Best Practices Rules (1)**:
  - `avoid_flaky_tests` - Detects flaky test patterns: unseeded Random(), DateTime.now(), File/Directory operations, and network calls without mocking [Warning tier]

### Changed

- **`prefer_async_callback` rule**: Quick fix now replaces `VoidCallback` with
  `Future<void> Function()` instead of `AsyncCallback`. This eliminates the need
  for importing Flutter foundation types (directly via
  `package:flutter/foundation.dart` or indirectly through `widgets.dart`/`material.dart`)
  and is consistent with how parameterized async callbacks are written (e.g.,
  `Future<void> Function(String)`).

- **`prefer_safe_area_aware`**: Reduced false positives - now skips Scaffolds with:
  - `extendBody: true` or `extendBodyBehindAppBar: true` (intentional fullscreen)
  - Body wrapped in `CustomScrollView`, `NestedScrollView`, or `MediaQuery`

- **`require_request_timeout`**: Reduced false positives - now more specific about
  HTTP client detection, no longer matches generic 'api' prefix (e.g., `apiResponse.get()`)

- **`require_focus_node_dispose`**: Now recognizes iteration-based disposal patterns
  for `List<FocusNode>` and `Map<..., FocusNode>` (matching ScrollController rule)

- **`avoid_ref_in_build_body`**: Added more callback methods where `ref.read()` is
  acceptable: `onDismissed`, `onEnd`, `onStatusChanged`, `onComplete`, `onError`,
  `onDoubleTap`, `onPanUpdate`, `onDragEnd`, `onSaved`, `addPostFrameCallback`

### Improved

- **All testing rules**: Added Windows path support (`\test\` in addition to `/test/`)
  for test file detection. Now correctly identifies test files on Windows.

- **`avoid_flaky_tests`**: Enhanced detection accuracy:
  - Added `Process.run(` and `Platform.environment` to flaky patterns
  - Improved seeded Random detection using regex (any numeric seed, not just 1/42)
  - Added `withClock` and `TestWidgetsFlutterBinding` to safe patterns

- **`require_scroll_controller_dispose`, `require_focus_node_dispose`, and `require_bloc_close` quick fixes**:
  Rewrote to actually fix the issue instead of adding TODO comments:
  - If `dispose()` exists: inserts `.dispose()` or `.close()` call before `super.dispose()`
  - If `dispose()` missing: creates full `@override void dispose()` method

- **`prefer_async_callback` documentation**: Comprehensive rewrite explaining:
  - Why `VoidCallback` silently discards Futures (lost errors, race conditions)
  - Which callback names trigger detection (onSubmit, onDelete, onRefresh, etc.)
  - Why `Future<void> Function()` is preferred over `AsyncCallback`
  - Clear BAD/GOOD code examples

- **`prefer_async_callback` prefix detection**: Added missing prefixes for better
  detection of compound names like `onProcessPayment`, `onConfirmDelete`,
  `onBackupData`, etc.

## [1.4.2]

### Added

- **50 new lint rules**:

  **Flutter Widget Rules - UX & Interaction (10)**:
  - `avoid_hardcoded_layout_values` - Extract magic numbers to named constants [Info tier]
  - `prefer_ignore_pointer` - Suggests IgnorePointer when AbsorbPointer may block unintentionally [Info tier]
  - `avoid_gesture_without_behavior` - GestureDetector should specify HitTestBehavior [Info tier]
  - `avoid_double_tap_submit` - Submit buttons should prevent double-tap [Warning tier]
  - `prefer_cursor_for_buttons` - Interactive widgets should specify mouse cursor for web [Info tier]
  - `require_hover_states` - Interactive widgets should handle hover for web/desktop [Info tier]
  - `require_button_loading_state` - Async buttons should show loading state [Info tier]
  - `avoid_hardcoded_text_styles` - Use Theme.of(context).textTheme instead of inline TextStyle [Info tier]
  - `prefer_page_storage_key` - Scrollables should use PageStorageKey to preserve position [Info tier]
  - `require_refresh_indicator` - Lists with remote data should have pull-to-refresh [Info tier]

  **Flutter Widget Rules - Scrolling & Lists (9)**:
  - `require_scroll_physics` - Scrollables should specify physics for consistent behavior [Info tier]
  - `prefer_sliver_list` - Use SliverList instead of ListView inside CustomScrollView [Warning tier]
  - `prefer_keep_alive` - State classes in tabs should use AutomaticKeepAliveClientMixin [Info tier]
  - `require_default_text_style` - Multiple Text widgets with same style should use DefaultTextStyle [Info tier]
  - `prefer_wrap_over_overflow` - Row with many small widgets should use Wrap [Info tier]
  - `prefer_asset_image_for_local` - Use AssetImage for bundled assets, not FileImage [Warning tier]
  - `prefer_fit_cover_for_background` - Background images should use BoxFit.cover [Info tier]
  - `require_disabled_state` - Buttons with conditional onPressed should customize disabled style [Info tier]
  - `require_drag_feedback` - Draggable should have feedback widget [Info tier]

  **Flutter Widget Rules - Layout & Performance (8)**:
  - `avoid_gesture_conflict` - Nested GestureDetector widgets may cause conflicts [Warning tier]
  - `avoid_large_images_in_memory` - Images should specify size constraints [Info tier]
  - `avoid_layout_builder_in_scrollable` - LayoutBuilder in scrollables causes rebuilds [Warning tier]
  - `prefer_intrinsic_dimensions` - Use IntrinsicWidth/Height for dynamic sizing [Info tier]
  - `prefer_actions_and_shortcuts` - Use Actions/Shortcuts for keyboard handling [Info tier]
  - `require_long_press_callback` - Important actions should have onLongPress alternative [Info tier]
  - `avoid_find_child_in_build` - Don't traverse widget tree in build() [Warning tier]
  - `avoid_unbounded_constraints` - Avoid widgets with unbounded constraints in scrollables [Warning tier]

  **Flutter Widget Rules - Advanced (10)**:
  - `prefer_fractional_sizing` - Use FractionallySizedBox instead of MediaQuery \* 0.x [Info tier]
  - `avoid_unconstrained_box_misuse` - UnconstrainedBox in constrained parent may overflow [Warning tier]
  - `require_error_widget` - FutureBuilder/StreamBuilder should handle error state [Warning tier]
  - `prefer_sliver_app_bar` - Use SliverAppBar in CustomScrollView, not AppBar [Info tier]
  - `avoid_opacity_misuse` - Use AnimatedOpacity when opacity uses variables [Info tier]
  - `prefer_clip_behavior` - Specify clipBehavior on Stack/Container for performance [Info tier]
  - `require_scroll_controller` - ListView.builder should have ScrollController [Info tier]
  - `prefer_positioned_directional` - Use PositionedDirectional for RTL support [Info tier]
  - `avoid_stack_overflow` - Stack children should use Positioned/Align [Info tier]
  - `require_form_validation` - TextFormField inside Form should have validator [Warning tier]

  **Testing Best Practices Rules (13)**:
  - `avoid_test_sleep` - Tests should use fakeAsync/pumpAndSettle, not sleep() [Warning tier]
  - `avoid_find_by_text` - Prefer find.byKey() for widget interactions [Info tier]
  - `require_test_keys` - Interactive widgets in tests should have Keys [Info tier]
  - `require_arrange_act_assert` - Tests should follow AAA pattern [Info tier]
  - `prefer_mock_navigator` - Navigator usage should be mocked for verification [Info tier]
  - `avoid_real_timer_in_widget_test` - Use fakeAsync instead of Timer [Warning tier]
  - `require_mock_verification` - Stubbed mocks should be verified [Info tier]
  - `prefer_matcher_over_equals` - Use matchers (isTrue, isNull, hasLength) [Info tier]
  - `prefer_test_wrapper` - Widget tests should wrap with MaterialApp [Info tier]
  - `require_screen_size_tests` - Responsive widgets should test multiple sizes [Info tier]
  - `avoid_stateful_test_setup` - setUp should not mutate shared state [Warning tier]
  - `prefer_mock_http` - Use MockClient instead of real HTTP [Warning tier]
  - `require_golden_test` - Visual tests should use golden comparison [Info tier]

### Changed

- `prefer_ignore_pointer` - Improved documentation explaining when to use AbsorbPointer vs IgnorePointer
- `require_disabled_state` - Clarified that Flutter buttons have default disabled styling; rule suggests customization
- `require_refresh_indicator` - Now only triggers for lists that appear to show remote data
- `avoid_find_by_text` - Now only warns when find.text() is used for interactions (tap/drag), not content verification

### Fixed

- `prefer_mock_http` - Consolidated duplicate InstanceCreationExpression registrations into single handler

## [1.4.1]

### Changed

- `prefer_boolean_prefixes`, `prefer_boolean_prefixes_for_locals`, `prefer_boolean_prefixes_for_params` - **Enhanced boolean naming validation**:
  - Now supports leading underscores (strips `_` prefix before validation)
  - Added 23 new action verb prefixes: `add`, `animate`, `apply`, `block`, `collapse`, `expand`, `filter`, `load`, `lock`, `log`, `merge`, `mute`, `pin`, `remove`, `reverse`, `save`, `send`, `sort`, `split`, `sync`, `track`, `trim`, `validate`, `wrap`
  - Added valid suffixes: `Active`, `Checked`, `Disabled`, `Enabled`, `Hidden`, `Loaded`, `Loading`, `Required`, `Selected`, `Valid`, `Visibility`, `Visible`
  - Added allowed exact names: `value` (Flutter Checkbox/Switch convention)
  - Examples now passing: `_deviceEnabled`, `sortAlphabetically`, `filterCountryHasContacts`, `applyScrollView`, `defaultHideIcons`

## [1.4.0]

### Added

- **4 new lint rules**:

  **Async Rules (1)**:
  - `prefer_async_callback` - Warns when `VoidCallback` is used for potentially async operations (onSubmit, onSave, onLoad, etc.). Discarded Futures hide exceptions. (quick-fix) [Professional tier]

  **Naming & Style Rules (2)**:
  - `prefer_boolean_prefixes_for_locals` - Local boolean variables should use is/has/can/should prefix [Comprehensive tier]
  - `prefer_boolean_prefixes_for_params` - Boolean parameters should use is/has/can/should prefix [Professional tier]

  **Security Rules (1)**:
  - `avoid_generic_key_in_url` - Stricter variant that catches generic `key=` and `auth=` URL parameters (higher false positive rate) [Insanity tier]

- **VS Code extension** - Optional status bar button for running custom_lint (see README for installation)

### Changed

- `prefer_boolean_prefixes` - **Reduced scope**: Now only checks class fields and top-level variables. Local variables and parameters are handled by the new separate rules for gradual adoption.

- `avoid_token_in_url` - Removed generic `auth` and `key` patterns to reduce false positives. These are now in `avoid_generic_key_in_url` for stricter codebases.

- `require_scroll_controller_dispose` - Now recognizes iteration-based disposal patterns:
  - `for (final c in _controllers) { c.dispose(); }` - for-in loop disposal
  - `for (final c in _controllers.values) { c.dispose(); }` - Map values disposal

- `require_database_close` - Fixed word boundary detection to avoid false positives on method names containing database keywords (e.g., `initIsarDatabase`)

**False positive reductions** in 4 rules:

- `avoid_commented_out_code` - Now skips annotation markers (TODO, FIXME, NOTE, HACK, BUG, OPTIMIZE, WARNING, CHANGED, REVIEW, DEPRECATED, IMPORTANT, MARK)

- `format_comment_formatting` - Consolidated annotation marker detection using single regex pattern

- `prefer_sentence_case_comments` - Now detects and skips commented-out code:
  - Dart keywords (return, if, for, while, class, import, etc.)
  - Code constructs (function calls, assignments, operators)
  - Code symbols (brackets, braces, increment/decrement, ternary)

- `prefer_doc_comments_over_regular` - Now skips:
  - Annotation markers (TODO, FIXME, NOTE, HACK, etc.)
  - Commented-out code (type declarations, control flow, imports)

### Fixed

- **Ignore comment handling for catch clauses** - Comments placed before the closing `}` of a try block now properly suppress warnings on the catch clause:

  ```dart
  try {
    // code
  // ignore: avoid_swallowing_exceptions
  } on Exception catch (e) {
    // empty
  }
  ```

- `avoid_unsafe_where_methods` - Removed debug print statements from quick fix

## [1.3.1]

### Fixed

- **License detection on pub.dev** - LICENSE file now uses LF line endings instead of CRLF, fixing the "(pending)" license display in the pub.dev sidebar
- **CI failures during publish** - Publish script now handles unpushed commits gracefully, ensuring code is formatted before push so CI passes on release commits

### Changed

- **Documentation cross-references** - All markdown files now use full GitHub URLs instead of relative paths for better discoverability on pub.dev:
  - README.md: Updated Documentation table and STYLISTIC.md references
  - STYLISTIC.md: Updated ROADMAP.md reference
  - ROADMAP.md: Updated CHANGELOG.md, CONTRIBUTING.md, and STYLISTIC.md references
  - CONTRIBUTING.md: Updated STYLISTIC.md reference
  - ENTERPRISE.md: Updated migration guide references

### Added

- **.gitattributes** - Enforces LF line endings for LICENSE file to prevent future license detection issues

## [1.3.0]

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

## [1.2.0]

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

## [1.1.19]

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

## [1.1.18]

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

## [1.1.17]

### Added

- `require_timer_cancellation` - New dedicated rule for Timer and StreamSubscription fields that require `cancel()`. Separated from `require_dispose` for clearer semantics. Crashes can occur if uncancelled timers call setState after widget disposal.
- `nullify_after_dispose` - New rule that suggests setting nullable disposable fields to null after disposal (e.g., `_timer = null` after `_timer?.cancel()`). Helps garbage collection and prevents accidental reuse.

### Changed

- `require_dispose` - Removed Timer and StreamSubscription (now handled by `require_timer_cancellation`). Now focuses on controllers that use `dispose()` and streams that use `close()`.

### Fixed

- `require_animation_disposal` - Now only checks State classes, eliminating false positives on StatelessWidgets that receive AnimationControllers as constructor parameters (they don't own the controller, parent disposes it)
- `require_dispose` - Now follows helper method calls from dispose() to detect indirect disposal patterns like `_cancelTimer()` that internally call the disposal method
- `require_timer_cancellation` - Follows helper method calls from dispose() to detect indirect cancellation patterns

## [1.1.16]

### Changed

- Renamed `docs/` to `doc/guides/` to follow Dart/Pub package layout conventions

## [1.1.15]

### Fixed

- `require_dispose` - Fixed `disposeSafe` pattern matching (was `xSafe()`, now correctly matches `x.disposeSafe()`)
- `avoid_logging_sensitive_data` - Added safe pattern detection to avoid false positives on words like `oauth`, `authenticated`, `authorization`, `unauthorized`

### Changed

- README: Clarified that rules must use YAML list format (`- rule: value`) not map format
- README: Updated IDE integration section with realistic expectations and CLI recommendation

## [1.1.14]

### Fixed

- `avoid_null_assertion` - Added short-circuit evaluation detection to reduce false positives:
  - `x == null || x!.length` - safe due to || short-circuit
  - `x.isListNullOrEmpty || x!.length < 2` - extension method short-circuit
  - `x != null && x!.doSomething()` - safe due to && short-circuit
  - Added `isListNullOrEmpty`, `isNullOrEmpty`, `isNullOrBlank` to recognized null checks

## [1.1.13]

### Changed

- `avoid_null_assertion` - Now recognizes safe null assertion patterns to reduce false positives:
  - Safe ternaries: `x == null ? null : x!`, `x != null ? x! : default`
  - Safe if-blocks: `if (x != null) { use(x!) }`
  - After null-check extensions: `.isNotNullOrEmpty`, `.isNotNullOrBlank`, `.isNotEmpty`
- `dispose_controllers` - Now recognizes `disposeSafe()` as a valid dispose method

## [1.1.12]

### Fixed

- `avoid_hardcoded_credentials` - Improved pattern matching to reduce false positives
  - Added minimum length requirements: sk-/pk- tokens (20+), GitHub tokens (36+), Bearer (20+), Basic (10+)
  - More accurate character sets for Base64 encoding in Basic auth
  - End-of-string anchoring for Bearer/Basic tokens

## [1.1.11]

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

## [1.1.10]

### Fixed

- Added `license: MIT` field to pubspec.yaml for proper pub.dev display

## [1.1.9]

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

## [0.1.8]

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

## [0.1.7]

### Fixed

- **Critical**: `getLintRules()` now reads tier configuration from `custom_lint.yaml`
  - Previously ignored `configs` parameter and used hard-coded 25-rule list
  - Now respects rules enabled/disabled in tier YAML files (essential, recommended, etc.)
  - Supports `enable_all_lint_rules: true` to enable all 500+ rules

## [0.1.6]

### Fixed

- Updated for analyzer 8.x API (requires `>=8.0.0 <10.0.0`)
  - Reverted `ErrorSeverity` back to `DiagnosticSeverity`
  - Reverted `ErrorReporter` back to `DiagnosticReporter`
  - Reverted `NamedType.name2` back to `NamedType.name`
  - Updated `enclosingElement3` to `enclosingElement`

## [0.1.5]

### Fixed

- Fixed `MethodElement.enclosingElement3` error - `MethodElement` requires cast to `Element` for `enclosingElement3` access
- Expanded analyzer constraint to support version 9.x (`>=6.0.0 <10.0.0`)

## [0.1.4]

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

## [0.1.3]

### Fixed

- Removed custom documentation URL so pub.dev uses its auto-generated API docs

## [0.1.2]

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

## [0.1.1]

### Fixed

- Improved documentation formatting and examples

## [0.1.0]

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
