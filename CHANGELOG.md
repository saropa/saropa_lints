# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.5.2] - 2026-01-07

### Changed

- **API documentation** - Added `dartdoc_options.yaml` to exclude internal `custom_lint_client` library from generated docs, so only the main `saropa_lints` library appears in the sidebar.

- **API documentation landing page** - Added `doc/README.md` with API-focused content instead of repeating the project README on the documentation homepage.

## [1.5.1] - 2026-01-07

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

## [1.5.0] - 2026-01-07

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

## [1.4.4] - 2025-01-07

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

## [1.4.3] - 2025-01-07

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
  for an extra import (`package:flutter/foundation.dart`) and is consistent with
  how parameterized async callbacks are written (e.g., `Future<void> Function(String)`).

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

## [1.4.2] - 2025-01-07

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
  - `prefer_fractional_sizing` - Use FractionallySizedBox instead of MediaQuery * 0.x [Info tier]
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

## [1.4.1] - 2025-01-07

### Changed

- `prefer_boolean_prefixes`, `prefer_boolean_prefixes_for_locals`, `prefer_boolean_prefixes_for_params` - **Enhanced boolean naming validation**:
  - Now supports leading underscores (strips `_` prefix before validation)
  - Added 23 new action verb prefixes: `add`, `animate`, `apply`, `block`, `collapse`, `expand`, `filter`, `load`, `lock`, `log`, `merge`, `mute`, `pin`, `remove`, `reverse`, `save`, `send`, `sort`, `split`, `sync`, `track`, `trim`, `validate`, `wrap`
  - Added valid suffixes: `Active`, `Checked`, `Disabled`, `Enabled`, `Hidden`, `Loaded`, `Loading`, `Required`, `Selected`, `Valid`, `Visibility`, `Visible`
  - Added allowed exact names: `value` (Flutter Checkbox/Switch convention)
  - Examples now passing: `_deviceEnabled`, `sortAlphabetically`, `filterCountryHasContacts`, `applyScrollView`, `defaultHideIcons`

## [1.4.0] - 2025-01-07

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

## [1.3.1] - 2025-01-06

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
