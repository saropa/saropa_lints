# Plan: 500 New Lint Rules + Testing Framework

## Overview

- **Current state**: 475 rules implemented, 475 configured in `custom_lint.yaml`, 0 enabled, 0 tests
- **Goal**: Add 500 new rules to reach ~1,000 total + comprehensive testing framework
- **Tier system**: Rules assigned to 5 tiers (Essential → Insanity)
- **Package**: `saropa_lints` using `custom_lint_builder: ^0.8.1`

---

## Part 1: Testing Framework

### 1.1 Directory Structure

```
custom_lints/
├── lib/
│   └── src/rules/          # Existing 20 rule files
├── test/
│   ├── test_utils/
│   │   ├── lint_test_helper.dart      # Core test utilities
│   │   ├── analyze_code.dart          # Code analysis helper
│   │   └── lint_expectation.dart      # Matcher utilities
│   ├── fixtures/
│   │   ├── accessibility/             # Bad/good examples per category
│   │   ├── performance/
│   │   ├── security/
│   │   └── ...
│   └── rules/
│       ├── accessibility_rules_test.dart
│       ├── performance_rules_test.dart
│       ├── security_rules_test.dart
│       └── ...
```

### 1.2 Test Helper Implementation

```dart
// test/test_utils/lint_test_helper.dart
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';
import 'package:test/test.dart';

/// Result of analyzing code with a lint rule
class LintTestResult {
  final List<LintMatch> matches;
  final String source;

  LintTestResult(this.matches, this.source);

  bool get hasLints => matches.isNotEmpty;
  int get lintCount => matches.length;
}

class LintMatch {
  final String ruleName;
  final int line;
  final int column;
  final String message;

  LintMatch({
    required this.ruleName,
    required this.line,
    required this.column,
    required this.message,
  });
}

/// Analyzes Dart code with the specified rule
Future<LintTestResult> analyzeDartCode(
  String code,
  DartLintRule rule,
) async {
  final matches = <LintMatch>[];

  final result = parseString(
    content: code,
    throwIfDiagnostics: false,
  );

  // Create mock reporter that captures lints
  final reporter = _TestErrorReporter((lint, node) {
    matches.add(LintMatch(
      ruleName: lint.name,
      line: node.offset, // Simplified - real impl needs line calc
      column: 0,
      message: lint.problemMessage,
    ));
  });

  // Run the rule
  // Note: Real implementation needs CustomLintResolver mock

  return LintTestResult(matches, code);
}

/// Test that code triggers the lint
void expectLint(LintTestResult result, {int count = 1}) {
  expect(result.hasLints, isTrue,
    reason: 'Expected lint to trigger but it did not');
  expect(result.lintCount, count,
    reason: 'Expected $count lint(s) but got ${result.lintCount}');
}

/// Test that code does NOT trigger the lint
void expectNoLint(LintTestResult result) {
  expect(result.hasLints, isFalse,
    reason: 'Expected no lint but got: ${result.matches.map((m) => m.message)}');
}
```

### 1.3 Test Pattern

```dart
// test/rules/accessibility_rules_test.dart
import 'package:test/test.dart';
import 'package:saropa_lints/src/rules/accessibility_rules.dart';
import '../test_utils/lint_test_helper.dart';

void main() {
  group('RequireSemanticsLabelRule', () {
    final rule = RequireSemanticsLabelRule();

    test('triggers on IconButton without tooltip', () async {
      final result = await analyzeDartCode('''
import 'package:flutter/material.dart';

Widget build() {
  return IconButton(
    icon: Icon(Icons.add),
    onPressed: () {},
  );
}
''', rule);

      expectLint(result);
    });

    test('passes with tooltip', () async {
      final result = await analyzeDartCode('''
import 'package:flutter/material.dart';

Widget build() {
  return IconButton(
    icon: Icon(Icons.add),
    onPressed: () {},
    tooltip: 'Add item',
  );
}
''', rule);

      expectNoLint(result);
    });

    test('passes with Semantics wrapper', () async {
      final result = await analyzeDartCode('''
import 'package:flutter/material.dart';

Widget build() {
  return Semantics(
    label: 'Add item',
    child: IconButton(
      icon: Icon(Icons.add),
      onPressed: () {},
    ),
  );
}
''', rule);

      expectNoLint(result);
    });
  });
}
```

### 1.4 Fixture-Based Testing (Alternative)

```dart
// test/rules/fixture_based_test.dart
import 'dart:io';
import 'package:test/test.dart';

void main() {
  final fixturesDir = Directory('test/fixtures');

  for (final category in fixturesDir.listSync().whereType<Directory>()) {
    group(category.path.split('/').last, () {
      for (final file in category.listSync().whereType<File>()) {
        if (!file.path.endsWith('.dart')) continue;

        final name = file.path.split('/').last;
        final shouldFail = name.startsWith('bad_');

        test(name, () async {
          final code = await file.readAsString();
          // Extract expected rule from file comment
          // Run analysis
          // Verify result matches expectation
        });
      }
    });
  }
}
```

### 1.5 Dependencies to Add

```yaml
# custom_lints/pubspec.yaml
dev_dependencies:
  test: ^1.25.0
  path: ^1.9.0
```

### 1.6 CI Integration

- [ ] Add `dart test` to CI pipeline
- [ ] Add coverage reporting

---

## Part 1B: Localization Testing Framework

*Merged from PLAN_LOCALIZATION.md*

### The Core Problem

`LocaleEnum.i18n` and any code using `appGlobalContext` will fail in unit tests because:

1. No `MaterialApp` is pumped
2. No `NavigatorState` is available
3. `appGlobalNavigatorKey.currentState` is null
4. Exception thrown: `[appGlobalNavigatorKey] is not available yet.`

### Current Global Context Dependencies

The following patterns create testing difficulties:

| Pattern | Files Affected | Test Impact |
|---------|----------------|-------------|
| `LocaleEnum.*.i18n` | 148 files, 225 occurrences | Fails in unit tests |
| `appGlobalContext` | 127 files | Fails in unit tests |
| `S.of(appGlobalContext)` | Several | Fails in unit tests |

### Specific Problem Areas

**contact_status_enum.dart** - Uses `LocaleEnum.i18n` in getters:
```dart
String get displayName => switch (this) {
  ContactStatus.Favorite => LocaleEnum.word_Favorite.i18n, // FAILS in tests
  // ...
};
```

This means any test that accesses `ContactStatus.Favorite.displayName` will fail without widget test setup.

### Testing Strategies

**Strategy A: Widget Tests with Localization Setup**

```dart
Widget buildTestApp({required Widget child}) {
  return MaterialApp(
    localizationsDelegates: S.localizationsDelegates,
    supportedLocales: S.supportedLocales,
    home: child,
  );
}

testWidgets('test with localization', (tester) async {
  await tester.pumpWidget(buildTestApp(child: MyWidget()));
  await tester.pumpAndSettle();
  // Test localized strings
});
```

**Strategy B: Context-Accepting Methods**

For testable code, prefer passing context explicitly:

```dart
// AVOID (untestable in unit tests):
String get displayName => LocaleEnum.word_Favorite.i18n;

// PREFER (testable):
String displayName(BuildContext context) => LocaleEnum.word_Favorite.tr(context);

// OR provide fallback for tests:
String get displayName {
  if (!hasGlobalContext) return name; // Fallback to enum name
  return LocaleEnum.word_Favorite.i18n;
}
```

**Strategy C: Test Isolation**

For model/enum tests that don't need localization verification:
- Test the enum values exist
- Test business logic separately from display strings
- Accept that display name tests require widget test setup
- Use `hasGlobalContext` guard to provide fallbacks

**Strategy D: Mock Global Context (Complex)**

```dart
// In test setup:
void setupTestLocalization() {
  // Create a minimal app context for testing
  // This is complex and fragile
}
```

### Recommended Approach

1. **New code:** Always use `context.s` or `LocaleEnum.tr(context)`
2. **Existing i18n usage:** Add `hasGlobalContext` guards with fallbacks
3. **Tests:** Use widget tests for UI, accept that some display tests need MaterialApp
4. **Enums:** Consider keeping `displayName` hardcoded for internal use, add `localizedName(context)` for UI

### Localization Test Categories

**1. Localization Unit Tests (Existing)**
- File: `test/lib/l10n/localization_test.dart`
- Tests ARB key existence and values
- Requires widget test setup

**2. Model Tests That Touch DisplayName**
- Risk: Will fail if accessing localized displayName
- Solution: Use widget test wrapper OR test only non-localized properties

**3. Widget Tests**
- Already have context available
- Safe to use `context.s` patterns

**4. Integration Tests**
- Full app context available
- All localization patterns work

### Localization Test Helper

```dart
// test/helpers/localization_test_helper.dart

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:saropa/l10n/app_localizations.dart';

/// Wraps a widget with localization support for testing
Widget wrapWithLocalization(Widget child, {Locale locale = const Locale('en')}) {
  return MaterialApp(
    locale: locale,
    localizationsDelegates: const [
      ...S.localizationsDelegates,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: S.supportedLocales,
    home: child,
  );
}

/// For unit tests that don't need full widget setup,
/// provides a fallback-aware way to access display names
extension TestableDisplayName on ContactStatus {
  String get testDisplayName {
    // In tests without context, return enum name
    // In real app, returns localized string
    try {
      return displayName;
    } catch (_) {
      return name;
    }
  }
}
```

### Tests That Need Migration

| Test File | Issue | Solution |
|-----------|-------|----------|
| `quick_launch_bar_test.dart` | Accesses `ContactStatus.displayName` | Wrap with `wrapWithLocalization` |
| Model tests using displayName | Global context not available | Use `testDisplayName` extension or widget test |

### Test Files with Acceptable Hardcoding

These test files use hardcoded strings for assertions - this is correct:

- `quick_launch_order_io_test.dart` - Tests database values
- `quick_launch_bar_test.dart` - Tests enum contains "Favorite"
- `contact_pre_processor_test.dart` - Tests group name matching
- `localization_test.dart` - Tests localized values equal expected strings

### Localization Testing Risk Assessment

| Risk | Impact | Mitigation |
|------|--------|------------|
| Tests fail after localization changes | CI breaks | Add hasGlobalContext guards |
| Wrong locale shown to users | UX confusion | Thorough QA testing |
| Missing translations in production | Broken UI | Fallback to English |

---

## Part 2: The 500 New Rules

### Category Distribution

| Category | Current | To Add | Total | Notes |
|----------|---------|--------|-------|-------|
| Widget Rules | 60 | +60 | 120 | Flutter-specific widget patterns |
| State Management | 15 | +45 | 60 | Riverpod, Bloc, Provider, GetX |
| Performance | 30 | +50 | 80 | Build optimization, memory |
| Testing | 22 | +48 | 70 | Unit, widget, integration tests |
| Security | 15 | +45 | 60 | Auth, data protection, secrets |
| Accessibility | 15 | +35 | 50 | Screen readers, touch targets |
| Error Handling | 25 | +30 | 55 | Exceptions, logging, recovery |
| Async/Concurrency | 40 | +30 | 70 | Futures, Streams, Isolates |
| Architecture | 20 | +40 | 60 | Clean arch, patterns |
| Package-Specific | 0 | +80 | 80 | Popular Flutter packages |
| Platform-Specific | 5 | +40 | 45 | Web, Desktop, iOS, Android |
| Documentation | 15 | +25 | 40 | Comments, API docs |
| API/Network | 10 | +25 | 35 | HTTP, REST, GraphQL |
| Database/Storage | 5 | +25 | 30 | SQL, NoSQL, prefs |
| Animation | 5 | +20 | 25 | Controllers, curves |
| Navigation | 5 | +20 | 25 | Routes, deep links |
| Forms/Validation | 5 | +25 | 30 | Input, validators |
| Localization | 12 | +18 | 30 | i18n, l10n |
| DI | 8 | +17 | 25 | GetIt, Injectable |
| Other | 188 | -78 | 110 | Redistributed to categories |
| **Total** | **~475** | **+500** | **~975** | |

---

## Part 3: Detailed Rule Specifications

### 3.1 Widget Rules (+60 rules)

#### Layout & Composition (15 rules)

| # | Rule Name | Tier | Severity | Description |
|---|-----------|------|----------|-------------|
| 1 | `avoid_nested_scaffolds` | Essential | ERROR | Scaffolds inside Scaffolds cause issues |
| 2 | `avoid_unbounded_constraints` | Essential | WARNING | Column/Row inside unconstrained widget |
| 3 | `prefer_sized_box_for_whitespace` | Recommended | INFO | SizedBox over Container for spacing |
| 4 | `avoid_deep_widget_nesting` | Professional | INFO | Widget depth > 15 levels |
| 5 | `prefer_wrap_over_overflow` | Recommended | WARNING | Use Wrap instead of overflow |
| 6 | `avoid_hardcoded_layout_values` | Comprehensive | INFO | Magic numbers in layout |
| 7 | `prefer_fractional_sizing` | Comprehensive | INFO | FractionallySizedBox for responsive |
| 8 | `avoid_layout_builder_in_scrollable` | Professional | WARNING | LayoutBuilder perf in scrollable |
| 9 | `prefer_intrinsic_dimensions` | Comprehensive | INFO | IntrinsicWidth/Height when needed |
| 10 | `avoid_multiple_material_apps` | Essential | ERROR | Only one MaterialApp per tree |
| 11 | `prefer_safe_area_aware` | Recommended | INFO | SafeArea for edge content |
| 12 | `avoid_unconstrained_box_misuse` | Professional | WARNING | UnconstrainedBox causing overflow |
| 13 | `require_overflow_box_rationale` | Comprehensive | INFO | Document OverflowBox usage |
| 14 | `prefer_custom_single_child_layout` | Insanity | INFO | CustomSingleChildLayout for complex |
| 15 | `avoid_fitted_box_for_text` | Comprehensive | INFO | FittedBox scaling text issues |

#### Text & Typography (10 rules)

| # | Rule Name | Tier | Severity | Description |
|---|-----------|------|----------|-------------|
| 16 | `prefer_text_theme` | Recommended | INFO | Use Theme.of(context).textTheme |
| 17 | `avoid_hardcoded_text_styles` | Professional | INFO | Extract text styles to theme |
| 18 | `require_text_overflow_handling` | Essential | WARNING | Long text needs overflow handler |
| 19 | `prefer_rich_text_for_complex` | Comprehensive | INFO | RichText for mixed styles |
| 20 | `avoid_text_scale_factor_ignore` | Recommended | WARNING | Respect textScaleFactor |
| 21 | `require_default_text_style` | Professional | INFO | DefaultTextStyle for consistency |
| 22 | `prefer_selectable_text` | Comprehensive | INFO | SelectableText for copyable |
| 23 | `avoid_font_weight_as_number` | Insanity | INFO | Use FontWeight constants |
| 24 | `require_locale_for_text` | Professional | INFO | Locale affects text rendering |
| 25 | `avoid_empty_text_widgets` | Recommended | INFO | Text('') wastes resources |

#### Images & Media (10 rules)

| # | Rule Name | Tier | Severity | Description |
|---|-----------|------|----------|-------------|
| 26 | `require_image_error_builder` | Essential | WARNING | Handle image loading errors |
| 27 | `prefer_cached_network_image` | Recommended | INFO | Cache network images |
| 28 | `avoid_large_images_in_memory` | Essential | WARNING | Resize large images |
| 29 | `require_image_semantics` | Recommended | WARNING | Alt text for accessibility |
| 30 | `prefer_asset_image_for_local` | Professional | INFO | AssetImage for bundled images |
| 31 | `avoid_image_repeat` | Comprehensive | INFO | ImageRepeat rarely needed |
| 32 | `require_placeholder_for_network` | Recommended | INFO | Show loading placeholder |
| 33 | `prefer_fit_cover_for_background` | Comprehensive | INFO | BoxFit.cover for backgrounds |
| 34 | `avoid_icon_size_override` | Comprehensive | INFO | Use IconTheme instead |
| 35 | `require_image_dimensions` | Professional | INFO | Specify width/height |

#### Input & Interaction (15 rules)

| # | Rule Name | Tier | Severity | Description |
|---|-----------|------|----------|-------------|
| 36 | `require_button_loading_state` | Recommended | INFO | Show loading during async |
| 37 | `avoid_gesture_conflict` | Essential | WARNING | Overlapping gesture detectors |
| 38 | `prefer_inkwell_over_gesture` | Recommended | INFO | InkWell for material feedback |
| 39 | `require_disabled_state` | Professional | INFO | Buttons need disabled state |
| 40 | `avoid_double_tap_submit` | Essential | WARNING | Prevent double form submit |
| 41 | `prefer_cursor_for_buttons` | Comprehensive | INFO | Mouse cursor on web |
| 42 | `require_focus_node_dispose` | Essential | ERROR | FocusNode must be disposed |
| 43 | `avoid_raw_keyboard_listener` | Comprehensive | INFO | Deprecated, use KeyboardListener |
| 44 | `prefer_actions_and_shortcuts` | Professional | INFO | Use Actions/Shortcuts system |
| 45 | `require_hover_states` | Comprehensive | INFO | Hover feedback on web/desktop |
| 46 | `avoid_absorb_pointer_misuse` | Professional | WARNING | AbsorbPointer blocks all input |
| 47 | `prefer_ignore_pointer` | Comprehensive | INFO | IgnorePointer over AbsorbPointer |
| 48 | `require_drag_feedback` | Professional | INFO | Visual feedback during drag |
| 49 | `avoid_gesture_without_behavior` | Recommended | INFO | Set HitTestBehavior |
| 50 | `require_long_press_callback` | Comprehensive | INFO | Handle onLongPress for context |

#### Lists & Scrolling (10 rules)

| # | Rule Name | Tier | Severity | Description |
|---|-----------|------|----------|-------------|
| 51 | `prefer_listview_builder` | Recommended | WARNING | Builder for long lists |
| 52 | `require_scroll_controller_dispose` | Essential | ERROR | ScrollController must dispose |
| 53 | `avoid_nested_scrollables` | Professional | WARNING | NestedScrollView for nesting |
| 54 | `prefer_sliver_list` | Professional | INFO | SliverList for mixed content |
| 55 | `require_scroll_physics` | Comprehensive | INFO | Define scroll physics |
| 56 | `avoid_shrink_wrap_in_scroll` | Professional | WARNING | shrinkWrap perf impact |
| 57 | `prefer_page_storage_key` | Comprehensive | INFO | Preserve scroll position |
| 58 | `require_refresh_indicator` | Recommended | INFO | Pull to refresh pattern |
| 59 | `avoid_find_child_in_build` | Professional | WARNING | findChildIndexCallback in build |
| 60 | `prefer_keep_alive` | Comprehensive | INFO | AutomaticKeepAliveClientMixin |

### 3.2 State Management (+45 rules)

#### Riverpod Rules (15 rules)

| # | Rule Name | Tier | Severity | Description |
|---|-----------|------|----------|-------------|
| 61 | `avoid_ref_in_build_body` | Essential | WARNING | ref.read in build can miss updates |
| 62 | `prefer_ref_watch_over_read` | Recommended | INFO | watch for reactive updates |
| 63 | `require_riverpod_override_in_tests` | Professional | INFO | Override providers in tests |
| 64 | `avoid_provider_recreate` | Essential | WARNING | Provider recreated each build |
| 65 | `prefer_family_for_params` | Professional | INFO | Use .family for parameterized |
| 66 | `require_auto_dispose` | Recommended | INFO | AutoDispose for cleanup |
| 67 | `avoid_circular_provider_deps` | Essential | ERROR | Circular provider dependency |
| 68 | `prefer_notifier_over_state` | Professional | INFO | Notifier for complex state |
| 69 | `require_error_handling_in_async` | Essential | WARNING | AsyncValue error handling |
| 70 | `avoid_provider_in_widget` | Recommended | WARNING | Providers outside widgets |
| 71 | `prefer_select_for_partial` | Professional | INFO | select() for partial rebuilds |
| 72 | `require_riverpod_lint` | Comprehensive | INFO | Enable riverpod_lint package |
| 73 | `avoid_ref_in_dispose` | Essential | ERROR | ref invalid in dispose |
| 74 | `prefer_consumer_widget` | Recommended | INFO | ConsumerWidget over Consumer |
| 75 | `require_provider_scope` | Essential | ERROR | ProviderScope at root |

#### Bloc/Cubit Rules (15 rules)

| # | Rule Name | Tier | Severity | Description |
|---|-----------|------|----------|-------------|
| 76 | `require_immutable_bloc_state` | Essential | ERROR | State must be immutable |
| 77 | `avoid_bloc_event_mutation` | Essential | ERROR | Don't mutate events |
| 78 | `require_bloc_close` | Essential | WARNING | Close bloc when done |
| 79 | `prefer_copyWith_for_state` | Recommended | INFO | Use copyWith pattern |
| 80 | `avoid_yield_in_on_event` | Professional | WARNING | Use emit instead |
| 81 | `require_bloc_test_coverage` | Professional | INFO | Test all bloc states |
| 82 | `prefer_cubit_for_simple` | Recommended | INFO | Cubit over Bloc for simple |
| 83 | `avoid_bloc_listen_in_build` | Essential | WARNING | listen: false in build |
| 84 | `require_bloc_transformer` | Professional | INFO | Define event transformer |
| 85 | `avoid_long_event_handlers` | Professional | INFO | Extract complex handlers |
| 86 | `prefer_sealed_events` | Comprehensive | INFO | Sealed classes for events |
| 87 | `require_initial_state` | Essential | ERROR | Define initial state |
| 88 | `avoid_bloc_in_bloc` | Recommended | WARNING | BLoC calling another BLoC |
| 89 | `prefer_bloc_observer` | Professional | INFO | Use BlocObserver for debug |
| 90 | `require_error_state` | Recommended | INFO | Handle error states |

#### Provider Package Rules (10 rules)

| # | Rule Name | Tier | Severity | Description |
|---|-----------|------|----------|-------------|
| 91 | `avoid_provider_of_in_build` | Essential | WARNING | Provider.of(listen:true) in build |
| 92 | `prefer_consumer_over_provider_of` | Recommended | INFO | Consumer for rebuilds |
| 93 | `require_provider_dispose` | Essential | WARNING | Dispose providers |
| 94 | `avoid_change_notifier_in_widget` | Recommended | WARNING | Notifier outside widget |
| 95 | `prefer_selector` | Professional | INFO | Selector for optimization |
| 96 | `require_multi_provider` | Professional | INFO | MultiProvider at root |
| 97 | `avoid_nested_providers` | Comprehensive | INFO | Flatten provider tree |
| 98 | `prefer_proxy_provider` | Comprehensive | INFO | ProxyProvider for deps |
| 99 | `require_update_callback` | Comprehensive | INFO | Handle updates explicitly |
| 100 | `avoid_listen_in_async` | Essential | WARNING | context.read in async |

#### GetX Rules (5 rules)

| # | Rule Name | Tier | Severity | Description |
|---|-----------|------|----------|-------------|
| 101 | `require_getx_controller_dispose` | Essential | WARNING | OnClose for cleanup |
| 102 | `avoid_get_find_in_build` | Essential | WARNING | Get.find in build |
| 103 | `prefer_getx_builder` | Recommended | INFO | GetX/GetBuilder for rebuild |
| 104 | `require_getx_binding` | Professional | INFO | Use Bindings pattern |
| 105 | `avoid_obs_outside_controller` | Recommended | WARNING | .obs in controllers only |

### 3.3 Performance Rules (+50 rules)

#### Build Optimization (20 rules)

| # | Rule Name | Tier | Severity | Description |
|---|-----------|------|----------|-------------|
| 106 | `avoid_rebuild_on_scroll` | Essential | WARNING | Rebuilding on scroll |
| 107 | `prefer_const_widgets` | Recommended | INFO | Mark widgets const |
| 108 | `avoid_expensive_computation_in_build` | Essential | WARNING | Heavy work in build |
| 109 | `require_repaint_boundary` | Professional | INFO | RepaintBoundary for isolation |
| 110 | `avoid_opacity_animation` | Recommended | WARNING | FadeTransition over Opacity |
| 111 | `prefer_builder_for_conditional` | Professional | INFO | Builder widget pattern |
| 112 | `avoid_media_query_in_build` | Recommended | INFO | Cache MediaQuery results |
| 113 | `require_widget_key_strategy` | Professional | INFO | Key strategy for lists |
| 114 | `avoid_layout_passes` | Professional | WARNING | Multiple layout passes |
| 115 | `prefer_value_listenable_builder` | Recommended | INFO | ValueListenable for single value |
| 116 | `avoid_calling_of_in_build` | Professional | WARNING | Expensive .of() calls |
| 117 | `prefer_inherited_widget_cache` | Professional | INFO | Cache InheritedWidget lookup |
| 118 | `avoid_text_span_rebuild` | Comprehensive | INFO | Reuse TextSpan objects |
| 119 | `require_should_rebuild` | Professional | INFO | shouldRebuild optimization |
| 120 | `avoid_widget_creation_in_loop` | Essential | WARNING | Create widgets once |
| 121 | `prefer_element_rebuild` | Comprehensive | INFO | Element rebuild optimization |
| 122 | `avoid_sized_box_expand` | Comprehensive | INFO | SizedBox.expand impact |
| 123 | `require_build_context_scope` | Recommended | WARNING | BuildContext invalid after |
| 124 | `prefer_selector_over_consumer` | Professional | INFO | More granular rebuilds |
| 125 | `avoid_global_key_misuse` | Essential | WARNING | GlobalKey causes rebuild |

#### Memory Optimization (15 rules)

| # | Rule Name | Tier | Severity | Description |
|---|-----------|------|----------|-------------|
| 126 | `require_image_cache_management` | Essential | WARNING | Clear image cache |
| 127 | `avoid_memory_intensive_operations` | Essential | WARNING | Large allocations |
| 128 | `prefer_weak_reference` | Comprehensive | INFO | WeakReference for cache |
| 129 | `require_list_preallocate` | Professional | INFO | List.filled for known size |
| 130 | `avoid_string_concatenation_loop` | Recommended | INFO | StringBuffer in loops |
| 131 | `prefer_typed_data` | Professional | INFO | Uint8List over List<int> |
| 132 | `require_isolate_for_heavy` | Professional | WARNING | compute() for heavy work |
| 133 | `avoid_finalizer_misuse` | Comprehensive | INFO | Finalizer rarely needed |
| 134 | `prefer_pool_pattern` | Comprehensive | INFO | Object pooling for reuse |
| 135 | `require_dispose_pattern` | Essential | ERROR | Disposable resources |
| 136 | `avoid_closure_memory_leak` | Essential | WARNING | Closures holding references |
| 137 | `prefer_static_const_widgets` | Professional | INFO | Static const for reuse |
| 138 | `require_expando_cleanup` | Comprehensive | INFO | Clean Expando objects |
| 139 | `avoid_large_list_copy` | Recommended | WARNING | List.from() copies all |
| 140 | `prefer_iterable_operations` | Professional | INFO | Lazy iteration |

#### Network Performance (15 rules)

| # | Rule Name | Tier | Severity | Description |
|---|-----------|------|----------|-------------|
| 141 | `require_request_timeout` | Essential | WARNING | HTTP timeout required |
| 142 | `prefer_http_connection_reuse` | Professional | INFO | Connection pooling |
| 143 | `avoid_redundant_requests` | Essential | WARNING | Dedupe identical requests |
| 144 | `require_response_caching` | Professional | INFO | Cache GET responses |
| 145 | `prefer_pagination` | Recommended | INFO | Paginate large datasets |
| 146 | `avoid_over_fetching` | Professional | INFO | Fetch only needed fields |
| 147 | `require_compression` | Comprehensive | INFO | gzip for large payloads |
| 148 | `prefer_batch_requests` | Professional | INFO | Batch multiple calls |
| 149 | `require_retry_strategy` | Recommended | INFO | Retry with backoff |
| 150 | `avoid_blocking_main_thread` | Essential | WARNING | Network on isolate |
| 151 | `prefer_streaming_response` | Comprehensive | INFO | Stream large responses |
| 152 | `require_cancel_token` | Professional | WARNING | Cancel abandoned requests |
| 153 | `avoid_json_in_main` | Professional | INFO | Parse JSON in isolate |
| 154 | `prefer_binary_format` | Comprehensive | INFO | Protocol buffers option |
| 155 | `require_network_status_check` | Recommended | INFO | Check connectivity first |

### 3.4 Testing Rules (+48 rules)

#### Unit Testing (15 rules)

| # | Rule Name | Tier | Severity | Description |
|---|-----------|------|----------|-------------|
| 156 | `require_test_assertions` | Essential | WARNING | Test must have assertions |
| 157 | `avoid_vague_test_names` | Recommended | INFO | Descriptive test names |
| 158 | `require_arrange_act_assert` | Professional | INFO | AAA pattern |
| 159 | `avoid_test_coupling` | Essential | WARNING | Tests independent |
| 160 | `prefer_single_assertion` | Professional | INFO | One assertion per test |
| 161 | `require_mock_verification` | Professional | INFO | Verify mock calls |
| 162 | `avoid_real_dependencies` | Essential | WARNING | Mock external deps |
| 163 | `prefer_fake_over_mock` | Comprehensive | INFO | Fakes for simple cases |
| 164 | `require_edge_case_tests` | Professional | INFO | Test boundary conditions |
| 165 | `avoid_test_sleep` | Essential | WARNING | No real timers in tests |
| 166 | `prefer_test_data_builder` | Comprehensive | INFO | Builders for test data |
| 167 | `require_error_case_tests` | Recommended | INFO | Test error scenarios |
| 168 | `avoid_test_implementation_details` | Professional | INFO | Test behavior not impl |
| 169 | `prefer_matcher_over_equals` | Comprehensive | INFO | Rich matchers |
| 170 | `require_test_isolation` | Essential | WARNING | Clean state per test |

#### Widget Testing (18 rules)

| # | Rule Name | Tier | Severity | Description |
|---|-----------|------|----------|-------------|
| 171 | `require_pump_after_action` | Essential | ERROR | pump after tap/enter |
| 172 | `prefer_pump_and_settle` | Recommended | INFO | pumpAndSettle for anim |
| 173 | `avoid_find_by_text` | Professional | INFO | Find by key/type instead |
| 174 | `require_test_keys` | Professional | INFO | Keys for testability |
| 175 | `prefer_test_wrapper` | Professional | INFO | Wrap with required widgets |
| 176 | `require_screen_size_tests` | Recommended | INFO | Test multiple sizes |
| 177 | `avoid_real_timer_in_widget` | Essential | WARNING | Fake timers |
| 178 | `prefer_mock_navigator` | Professional | INFO | Mock navigation |
| 179 | `require_scroll_tests` | Recommended | INFO | Test scroll behavior |
| 180 | `avoid_find_all` | Professional | INFO | Specific finders |
| 181 | `require_text_input_tests` | Recommended | INFO | Test text fields |
| 182 | `prefer_test_variant` | Comprehensive | INFO | Variant for permutations |
| 183 | `require_accessibility_tests` | Recommended | WARNING | Semantics tests |
| 184 | `avoid_stateful_test_setup` | Professional | INFO | Fresh state each test |
| 185 | `prefer_mock_http` | Professional | INFO | Mock http client |
| 186 | `require_dialog_tests` | Recommended | INFO | Test dialogs |
| 187 | `prefer_fake_platform` | Comprehensive | INFO | Fake platform channels |
| 188 | `require_animation_tests` | Comprehensive | INFO | Test animations |

#### Integration Testing (15 rules)

| # | Rule Name | Tier | Severity | Description |
|---|-----------|------|----------|-------------|
| 189 | `require_integration_test_setup` | Recommended | INFO | IntegrationTestWidgetsFlutterBinding |
| 190 | `prefer_test_groups` | Professional | INFO | Group related tests |
| 191 | `require_test_ordering` | Professional | INFO | Order matters |
| 192 | `avoid_flaky_tests` | Essential | WARNING | Deterministic tests |
| 193 | `prefer_retry_flaky` | Comprehensive | INFO | Retry for flakiness |
| 194 | `require_test_cleanup` | Professional | INFO | Clean after test |
| 195 | `avoid_hardcoded_delays` | Essential | WARNING | No fixed delays |
| 196 | `prefer_test_data_reset` | Professional | INFO | Reset data between |
| 197 | `require_e2e_coverage` | Professional | INFO | Critical paths covered |
| 198 | `avoid_screenshot_in_ci` | Comprehensive | INFO | Screenshot only on fail |
| 199 | `prefer_test_report` | Comprehensive | INFO | Generate test reports |
| 200 | `require_performance_test` | Professional | INFO | Perf regression tests |
| 201 | `avoid_test_on_real_device` | Recommended | INFO | Emulator consistency |
| 202 | `prefer_parallel_tests` | Comprehensive | INFO | Parallel execution |
| 203 | `require_test_documentation` | Comprehensive | INFO | Document complex tests |

### 3.5 Security Rules (+45 rules)

#### Authentication & Authorization (15 rules)

| # | Rule Name | Tier | Severity | Description |
|---|-----------|------|----------|-------------|
| 204 | `require_auth_check` | Essential | ERROR | Protected routes check auth |
| 205 | `avoid_storing_passwords` | Essential | ERROR | Never store plain passwords |
| 206 | `require_secure_storage` | Essential | WARNING | Use flutter_secure_storage |
| 207 | `avoid_token_in_url` | Essential | ERROR | Tokens in headers only |
| 208 | `require_token_refresh` | Recommended | WARNING | Handle token expiry |
| 209 | `prefer_biometric_with_fallback` | Professional | INFO | Fallback for biometric |
| 210 | `avoid_auth_state_in_prefs` | Essential | WARNING | Secure storage for auth |
| 211 | `require_logout_cleanup` | Essential | WARNING | Clear data on logout |
| 212 | `prefer_oauth_pkce` | Professional | INFO | PKCE for mobile OAuth |
| 213 | `avoid_jwt_decode_client` | Recommended | INFO | Don't trust client JWT |
| 214 | `require_session_timeout` | Professional | INFO | Session expiry |
| 215 | `prefer_deep_link_auth` | Professional | INFO | Validate deep link auth |
| 216 | `avoid_remember_me_insecure` | Recommended | WARNING | Secure remember me |
| 217 | `require_multi_factor` | Comprehensive | INFO | Consider MFA |
| 218 | `avoid_auth_in_query_params` | Essential | ERROR | Auth not in URL |

#### Data Protection (15 rules)

| # | Rule Name | Tier | Severity | Description |
|---|-----------|------|----------|-------------|
| 219 | `avoid_logging_pii` | Essential | ERROR | No PII in logs |
| 220 | `require_data_encryption` | Essential | WARNING | Encrypt sensitive data |
| 221 | `prefer_secure_random` | Recommended | WARNING | SecureRandom for crypto |
| 222 | `avoid_hardcoded_secrets` | Essential | ERROR | No secrets in code |
| 223 | `require_keychain_access` | Professional | INFO | iOS keychain properly |
| 224 | `prefer_encrypted_prefs` | Recommended | INFO | Encrypt SharedPrefs |
| 225 | `avoid_clipboard_sensitive` | Essential | WARNING | Don't copy passwords |
| 226 | `require_certificate_pinning` | Professional | WARNING | SSL pinning |
| 227 | `prefer_data_masking` | Professional | INFO | Mask sensitive display |
| 228 | `avoid_screenshot_sensitive` | Recommended | WARNING | Prevent screenshots |
| 229 | `require_secure_keyboard` | Professional | INFO | Secure keyboard input |
| 230 | `prefer_local_auth` | Professional | INFO | Local auth for sensitive |
| 231 | `avoid_external_storage_sensitive` | Essential | ERROR | No sensitive on SD |
| 232 | `require_backup_exclusion` | Professional | INFO | Exclude from backup |
| 233 | `prefer_root_detection` | Professional | INFO | Detect rooted devices |

#### Input Validation & Injection (15 rules)

| # | Rule Name | Tier | Severity | Description |
|---|-----------|------|----------|-------------|
| 234 | `require_input_sanitization` | Essential | WARNING | Sanitize user input |
| 235 | `avoid_dynamic_sql` | Essential | ERROR | Parameterized queries |
| 236 | `prefer_html_escape` | Recommended | WARNING | Escape HTML output |
| 237 | `avoid_eval_patterns` | Essential | ERROR | No dynamic code exec |
| 238 | `require_url_validation` | Essential | WARNING | Validate URLs |
| 239 | `prefer_regex_validation` | Recommended | INFO | Regex for format check |
| 240 | `avoid_path_traversal` | Essential | ERROR | Validate file paths |
| 241 | `require_json_schema_validation` | Professional | INFO | Validate JSON schema |
| 242 | `prefer_whitelist_validation` | Professional | INFO | Whitelist over blacklist |
| 243 | `avoid_redirect_injection` | Essential | WARNING | Validate redirects |
| 244 | `require_content_type_check` | Professional | INFO | Check response types |
| 245 | `prefer_csrf_protection` | Professional | WARNING | CSRF tokens |
| 246 | `avoid_webview_js_interface` | Recommended | WARNING | WebView JS bridge risk |
| 247 | `require_deep_link_validation` | Essential | WARNING | Validate deep links |
| 248 | `prefer_intent_filter_export` | Professional | INFO | Limit intent filters |

### 3.6 Accessibility Rules (+35 rules)

#### Screen Reader Support (15 rules)

| # | Rule Name | Tier | Severity | Description |
|---|-----------|------|----------|-------------|
| 249 | `require_semantics_label` | Essential | WARNING | Interactive needs label |
| 250 | `avoid_icon_only_buttons` | Essential | WARNING | Icon buttons need tooltip |
| 251 | `prefer_explicit_semantics` | Recommended | INFO | Explicit semantics |
| 252 | `require_image_description` | Essential | WARNING | Images need alt text |
| 253 | `avoid_semantics_exclusion` | Recommended | WARNING | Justify excludeSemantics |
| 254 | `prefer_merge_semantics` | Professional | INFO | Group related semantics |
| 255 | `require_heading_hierarchy` | Professional | INFO | Proper heading levels |
| 256 | `avoid_redundant_semantics` | Comprehensive | INFO | No duplicate labels |
| 257 | `prefer_semantics_container` | Professional | INFO | Container for groups |
| 258 | `require_button_semantics` | Recommended | INFO | Button role for custom |
| 259 | `avoid_hidden_interactive` | Essential | ERROR | Hidden but interactive |
| 260 | `prefer_semantics_sort` | Professional | INFO | Sort order for focus |
| 261 | `require_live_region` | Recommended | INFO | Dynamic content announce |
| 262 | `avoid_semantics_in_animation` | Comprehensive | INFO | Static semantics tree |
| 263 | `prefer_announce_for_changes` | Comprehensive | INFO | Announce important changes |

#### Visual Accessibility (12 rules)

| # | Rule Name | Tier | Severity | Description |
|---|-----------|------|----------|-------------|
| 264 | `require_minimum_contrast` | Essential | WARNING | 4.5:1 contrast ratio |
| 265 | `avoid_color_only_meaning` | Essential | WARNING | Color not only indicator |
| 266 | `prefer_scalable_text` | Recommended | INFO | Respect text scale |
| 267 | `require_focus_indicator` | Recommended | WARNING | Visible focus state |
| 268 | `avoid_small_text` | Recommended | INFO | Minimum 12sp text |
| 269 | `prefer_high_contrast_mode` | Professional | INFO | Support high contrast |
| 270 | `require_error_identification` | Essential | WARNING | Identify errors clearly |
| 271 | `avoid_motion_without_reduce` | Recommended | INFO | Reduce motion support |
| 272 | `prefer_dark_mode_colors` | Professional | INFO | Proper dark mode colors |
| 273 | `require_link_distinction` | Comprehensive | INFO | Links visually distinct |
| 274 | `avoid_flashing_content` | Essential | WARNING | No seizure triggers |
| 275 | `prefer_outlined_icons` | Comprehensive | INFO | Outlined over filled |

#### Motor Accessibility (8 rules)

| # | Rule Name | Tier | Severity | Description |
|---|-----------|------|----------|-------------|
| 276 | `require_minimum_touch_target` | Essential | WARNING | 48dp minimum tap target |
| 277 | `avoid_gesture_only` | Recommended | WARNING | Keyboard alternative |
| 278 | `prefer_adequate_spacing` | Recommended | INFO | Spacing between targets |
| 279 | `require_drag_alternatives` | Professional | INFO | Alternative to drag |
| 280 | `avoid_time_limits` | Recommended | INFO | No strict time limits |
| 281 | `prefer_external_keyboard` | Comprehensive | INFO | External keyboard support |
| 282 | `require_switch_control` | Comprehensive | INFO | Switch control support |
| 283 | `avoid_hover_only` | Recommended | INFO | Not hover-dependent |

### 3.7 Error Handling Rules (+30 rules)

#### Exception Handling (15 rules)

| # | Rule Name | Tier | Severity | Description |
|---|-----------|------|----------|-------------|
| 284 | `avoid_empty_catch` | Essential | ERROR | Handle or rethrow |
| 285 | `prefer_typed_catch` | Recommended | INFO | Specific exception types |
| 286 | `require_error_logging` | Essential | WARNING | Log all errors |
| 287 | `avoid_catch_generic` | Recommended | WARNING | Don't catch Exception |
| 288 | `prefer_error_types` | Professional | INFO | Custom error types |
| 289 | `require_stack_trace_preserve` | Essential | WARNING | Keep stack trace |
| 290 | `avoid_throw_string` | Essential | ERROR | Throw Error/Exception |
| 291 | `prefer_result_type` | Professional | INFO | Result over exceptions |
| 292 | `require_finally_cleanup` | Recommended | INFO | Cleanup in finally |
| 293 | `avoid_rethrow_modified` | Professional | INFO | Rethrow preserves trace |
| 294 | `prefer_assert_in_debug` | Recommended | INFO | Assert for debug checks |
| 295 | `require_error_context` | Professional | INFO | Error includes context |
| 296 | `avoid_silent_failure` | Essential | ERROR | No silent catch-ignore |
| 297 | `prefer_error_factory` | Comprehensive | INFO | Factory for errors |
| 298 | `require_error_recovery` | Professional | INFO | Recovery strategy |

#### Async Error Handling (15 rules)

| # | Rule Name | Tier | Severity | Description |
|---|-----------|------|----------|-------------|
| 299 | `require_future_error_handler` | Essential | WARNING | Handle Future errors |
| 300 | `avoid_unhandled_async` | Essential | ERROR | Unawaited throws |
| 301 | `prefer_async_try_catch` | Recommended | INFO | try-catch for async |
| 302 | `require_stream_error_handler` | Essential | WARNING | Handle stream errors |
| 303 | `avoid_completer_error_ignore` | Professional | WARNING | Completer error handling |
| 304 | `prefer_timeout_for_futures` | Recommended | WARNING | Timeout long futures |
| 305 | `require_zone_error_handler` | Professional | INFO | Zone error boundaries |
| 306 | `avoid_catch_async_gap` | Professional | WARNING | Catch across async gap |
| 307 | `prefer_error_widget_builder` | Essential | WARNING | ErrorWidget.builder |
| 308 | `require_stream_done_handler` | Recommended | INFO | Handle stream completion |
| 309 | `avoid_parallel_error_loss` | Professional | WARNING | Future.wait error handling |
| 310 | `prefer_error_group` | Comprehensive | INFO | ErrorGroup for multi-future |
| 311 | `require_cancel_on_error` | Professional | INFO | Cancel stream on error |
| 312 | `avoid_timer_error_ignore` | Recommended | WARNING | Timer callback errors |
| 313 | `prefer_onError_callback` | Professional | INFO | onError for listeners |

### 3.8 Async/Concurrency Rules (+30 rules)

#### Future/Async Patterns (15 rules)

| # | Rule Name | Tier | Severity | Description |
|---|-----------|------|----------|-------------|
| 314 | `avoid_nested_futures` | Recommended | WARNING | Flatten future chains |
| 315 | `prefer_async_await` | Recommended | INFO | async/await over then |
| 316 | `require_unawaited_annotation` | Professional | INFO | Mark intentional unawaited |
| 317 | `avoid_future_wait_long` | Professional | WARNING | Too many parallel futures |
| 318 | `prefer_future_delayed_cancel` | Comprehensive | INFO | Cancelable delays |
| 319 | `require_async_init_dispose` | Recommended | WARNING | Async init/dispose pattern |
| 320 | `avoid_sync_over_async` | Professional | INFO | Don't wrap sync in Future |
| 321 | `prefer_microtask` | Comprehensive | INFO | scheduleMicrotask usage |
| 322 | `require_loading_states` | Recommended | INFO | Loading/loaded states |
| 323 | `avoid_future_or_misuse` | Professional | WARNING | FutureOr careful usage |
| 324 | `prefer_value_future` | Comprehensive | INFO | SynchronousFuture for sync |
| 325 | `require_cancellation_token` | Professional | INFO | Cancellation support |
| 326 | `avoid_future_builder_in_build` | Essential | WARNING | FutureBuilder rebuild |
| 327 | `prefer_async_generator` | Comprehensive | INFO | async* for sequences |
| 328 | `require_error_future` | Recommended | INFO | Future.error for fails |

#### Stream Patterns (15 rules)

| # | Rule Name | Tier | Severity | Description |
|---|-----------|------|----------|-------------|
| 329 | `require_stream_cancel` | Essential | ERROR | Cancel subscriptions |
| 330 | `prefer_stream_controller_close` | Essential | WARNING | Close controllers |
| 331 | `avoid_broadcast_overhead` | Professional | INFO | Broadcast only when needed |
| 332 | `prefer_stream_transform` | Professional | INFO | Transform over listen |
| 333 | `require_stream_first_error` | Recommended | INFO | Handle first value error |
| 334 | `avoid_nested_listen` | Recommended | WARNING | Flatten nested listens |
| 335 | `prefer_rxdart_patterns` | Comprehensive | INFO | RxDart for complex |
| 336 | `require_stream_sync` | Professional | INFO | Sync stream carefully |
| 337 | `avoid_stream_timeout_infinite` | Recommended | WARNING | Timeout for streams |
| 338 | `prefer_async_expand` | Comprehensive | INFO | asyncExpand for sequences |
| 339 | `require_drain_unused` | Recommended | INFO | Drain unused streams |
| 340 | `avoid_stream_cast` | Professional | WARNING | Type-safe streams |
| 341 | `prefer_event_sink` | Comprehensive | INFO | EventSink for events |
| 342 | `require_stream_iterator` | Professional | INFO | StreamIterator pattern |
| 343 | `avoid_stream_distinct_expensive` | Comprehensive | INFO | distinct equality cost |

### 3.9 Architecture Rules (+40 rules)

#### Clean Architecture (15 rules)

| # | Rule Name | Tier | Severity | Description |
|---|-----------|------|----------|-------------|
| 344 | `require_layer_separation` | Professional | WARNING | Domain independent |
| 345 | `avoid_ui_in_domain` | Essential | ERROR | No UI in domain layer |
| 346 | `prefer_repository_interface` | Professional | INFO | Repository abstraction |
| 347 | `require_use_case_pattern` | Professional | INFO | Use cases for logic |
| 348 | `avoid_direct_data_access` | Recommended | WARNING | Access via repository |
| 349 | `prefer_entity_immutability` | Professional | INFO | Immutable entities |
| 350 | `require_mapper_pattern` | Professional | INFO | DTO to entity mappers |
| 351 | `avoid_circular_dependencies` | Essential | ERROR | No circular imports |
| 352 | `prefer_dependency_injection` | Professional | INFO | DI for dependencies |
| 353 | `require_interface_segregation` | Comprehensive | INFO | Small focused interfaces |
| 354 | `avoid_god_class` | Recommended | WARNING | Classes too large |
| 355 | `prefer_single_responsibility` | Professional | INFO | One responsibility |
| 356 | `require_feature_folders` | Comprehensive | INFO | Feature-based structure |
| 357 | `avoid_deep_inheritance` | Professional | INFO | Max 3 levels deep |
| 358 | `prefer_composition` | Professional | INFO | Composition over inheritance |

#### Design Patterns (15 rules)

| # | Rule Name | Tier | Severity | Description |
|---|-----------|------|----------|-------------|
| 359 | `prefer_factory_pattern` | Professional | INFO | Factory for creation |
| 360 | `require_singleton_care` | Recommended | WARNING | Singleton side effects |
| 361 | `prefer_builder_pattern` | Comprehensive | INFO | Builder for complex objects |
| 362 | `require_observer_unsubscribe` | Essential | WARNING | Unsubscribe observers |
| 363 | `prefer_strategy_pattern` | Professional | INFO | Strategy for algorithms |
| 364 | `require_adapter_consistency` | Professional | INFO | Consistent adapters |
| 365 | `prefer_decorator_pattern` | Comprehensive | INFO | Decorator for extension |
| 366 | `require_facade_simplicity` | Professional | INFO | Facade hides complexity |
| 367 | `prefer_command_pattern` | Comprehensive | INFO | Command for actions |
| 368 | `require_iterator_pattern` | Comprehensive | INFO | Iterator for collections |
| 369 | `prefer_mediator_pattern` | Comprehensive | INFO | Mediator for communication |
| 370 | `require_memento_care` | Comprehensive | INFO | Memento for state |
| 371 | `prefer_prototype_clone` | Comprehensive | INFO | Prototype pattern |
| 372 | `require_state_pattern` | Professional | INFO | State pattern |
| 373 | `prefer_template_method` | Comprehensive | INFO | Template method |

#### Code Organization (10 rules)

| # | Rule Name | Tier | Severity | Description |
|---|-----------|------|----------|-------------|
| 374 | `require_export_barrel` | Professional | INFO | Barrel exports |
| 375 | `avoid_relative_imports_outside` | Recommended | INFO | Package imports |
| 376 | `prefer_part_files` | Comprehensive | INFO | Part files for large |
| 377 | `require_library_doc` | Comprehensive | INFO | Library documentation |
| 378 | `avoid_wildcard_imports` | Recommended | INFO | No show * imports |
| 379 | `prefer_sorted_imports` | Comprehensive | INFO | Sorted imports |
| 380 | `require_feature_test_folder` | Professional | INFO | Tests mirror features |
| 381 | `avoid_src_exposure` | Professional | INFO | Don't export src |
| 382 | `prefer_consistent_naming` | Recommended | INFO | Naming conventions |
| 383 | `require_readme_per_feature` | Comprehensive | INFO | Feature documentation |

### 3.10 Package-Specific Rules (+80 rules)

*See detailed breakdowns in sections 3.2 (Riverpod, Bloc, Provider, GetX) above*

#### Dio/HTTP Rules (15 rules)

| # | Rule Name | Tier | Severity | Description |
|---|-----------|------|----------|-------------|
| 384 | `require_dio_interceptor` | Professional | INFO | Use interceptors |
| 385 | `prefer_dio_transformer` | Professional | INFO | Custom transformers |
| 386 | `require_base_options` | Recommended | INFO | Set base options |
| 387 | `avoid_dio_instance_per_call` | Essential | WARNING | Reuse Dio instance |
| 388 | `prefer_cancel_token` | Recommended | INFO | Cancel support |
| 389 | `require_error_interceptor` | Essential | WARNING | Error handling |
| 390 | `prefer_log_interceptor` | Professional | INFO | Request logging |
| 391 | `require_timeout_options` | Essential | WARNING | Set timeouts |
| 392 | `avoid_form_data_memory` | Professional | WARNING | Stream large files |
| 393 | `prefer_response_type` | Recommended | INFO | Explicit response type |
| 394 | `require_retry_interceptor` | Professional | INFO | Retry on failure |
| 395 | `avoid_cookie_misuse` | Professional | WARNING | Cookie handling |
| 396 | `prefer_progress_callback` | Comprehensive | INFO | Upload progress |
| 397 | `require_cache_interceptor` | Professional | INFO | Response caching |
| 398 | `avoid_dio_test_mock` | Professional | INFO | Mock adapter for tests |

#### Hive/Isar Rules (15 rules)

| # | Rule Name | Tier | Severity | Description |
|---|-----------|------|----------|-------------|
| 399 | `require_type_adapter` | Essential | ERROR | Register adapters |
| 400 | `avoid_box_in_widget` | Recommended | WARNING | Box access outside widget |
| 401 | `prefer_lazy_box` | Professional | INFO | LazyBox for large |
| 402 | `require_box_close` | Essential | WARNING | Close boxes |
| 403 | `avoid_watch_in_build` | Recommended | WARNING | box.watch() in build |
| 404 | `prefer_compact_on_launch` | Professional | INFO | Compact boxes |
| 405 | `require_encryption_key` | Professional | WARNING | Encrypt sensitive |
| 406 | `avoid_nested_objects` | Professional | INFO | Flatten for performance |
| 407 | `prefer_indexes` | Professional | INFO | Index query fields |
| 408 | `require_migration_strategy` | Professional | WARNING | Handle schema changes |
| 409 | `avoid_isar_on_main` | Professional | WARNING | Isar queries async |
| 410 | `prefer_batch_write` | Recommended | INFO | Batch for multiple |
| 411 | `require_unique_type_id` | Essential | ERROR | Unique type IDs |
| 412 | `avoid_storing_widgets` | Essential | ERROR | No widget storage |
| 413 | `prefer_value_equality` | Comprehensive | INFO | Value equality for models |

#### GoRouter Rules (15 rules)

| # | Rule Name | Tier | Severity | Description |
|---|-----------|------|----------|-------------|
| 414 | `require_route_names` | Recommended | INFO | Named routes |
| 415 | `avoid_route_string_literal` | Recommended | INFO | Route constants |
| 416 | `prefer_typed_params` | Professional | INFO | TypedGoRoute |
| 417 | `require_redirect_guard` | Essential | WARNING | Auth redirect |
| 418 | `avoid_nested_route_depth` | Professional | INFO | Max nesting depth |
| 419 | `prefer_shell_route` | Professional | INFO | ShellRoute for tabs |
| 420 | `require_error_route` | Essential | WARNING | Error page handler |
| 421 | `avoid_push_replacement_misuse` | Recommended | WARNING | Replace vs push |
| 422 | `prefer_route_observer` | Comprehensive | INFO | Observer for analytics |
| 423 | `require_deep_link_config` | Professional | INFO | Deep link setup |
| 424 | `avoid_context_navigation` | Professional | INFO | Use GoRouter.of |
| 425 | `prefer_extra_type_safe` | Professional | INFO | Type-safe extra |
| 426 | `require_refresh_listenable` | Recommended | INFO | Refresh on state change |
| 427 | `avoid_initial_location_misuse` | Recommended | WARNING | initialLocation use |
| 428 | `prefer_state_restoration` | Comprehensive | INFO | State restoration |

#### Firebase Rules (20 rules)

| # | Rule Name | Tier | Severity | Description |
|---|-----------|------|----------|-------------|
| 429 | `require_firebase_init` | Essential | ERROR | Firebase.initializeApp |
| 430 | `avoid_firestore_batch_limit` | Essential | WARNING | 500 doc batch limit |
| 431 | `prefer_firestore_pagination` | Recommended | INFO | Paginate queries |
| 432 | `require_auth_state_listener` | Recommended | WARNING | Listen auth changes |
| 433 | `avoid_storage_large_upload` | Professional | WARNING | Resumable uploads |
| 434 | `prefer_composite_index` | Professional | INFO | Composite indexes |
| 435 | `require_security_rules` | Essential | ERROR | Security rules |
| 436 | `avoid_realtime_db_nesting` | Professional | WARNING | Flatten RTDB |
| 437 | `prefer_transaction_for_atomic` | Essential | WARNING | Transactions |
| 438 | `require_offline_persistence` | Professional | INFO | Enable persistence |
| 439 | `avoid_query_without_limit` | Essential | WARNING | Limit queries |
| 440 | `prefer_server_timestamp` | Recommended | INFO | Server timestamps |
| 441 | `require_fcm_token_refresh` | Professional | INFO | Handle token refresh |
| 442 | `avoid_analytics_pii` | Essential | ERROR | No PII in analytics |
| 443 | `prefer_remote_config_defaults` | Professional | INFO | Config defaults |
| 444 | `require_crashlytics_setup` | Recommended | INFO | Crashlytics init |
| 445 | `avoid_firestore_in_loop` | Essential | WARNING | Batch Firestore ops |
| 446 | `prefer_where_field_path` | Professional | INFO | FieldPath for where |
| 447 | `require_cloud_function_timeout` | Professional | INFO | Function timeout |
| 448 | `avoid_storage_rules_bypass` | Essential | ERROR | Rules not bypassable |

### 3.11 Platform-Specific Rules (+40 rules)

#### Web Platform (15 rules)

| # | Rule Name | Tier | Severity | Description |
|---|-----------|------|----------|-------------|
| 449 | `require_web_url_strategy` | Recommended | INFO | Hash vs path strategy |
| 450 | `avoid_web_only_packages` | Recommended | WARNING | Cross-platform packages |
| 451 | `prefer_deferred_loading` | Professional | INFO | Deferred components |
| 452 | `require_seo_meta` | Professional | INFO | SEO meta tags |
| 453 | `avoid_canvas_kit_large` | Professional | INFO | CanvasKit bundle size |
| 454 | `prefer_html_renderer` | Comprehensive | INFO | HTML renderer option |
| 455 | `require_loading_indicator` | Recommended | INFO | Web loading state |
| 456 | `avoid_localstorage_sensitive` | Essential | WARNING | LocalStorage insecure |
| 457 | `prefer_service_worker` | Professional | INFO | Service worker cache |
| 458 | `require_favicon` | Comprehensive | INFO | Favicon configured |
| 459 | `avoid_window_location` | Professional | INFO | GoRouter for navigation |
| 460 | `prefer_responsive_breakpoints` | Recommended | INFO | Responsive design |
| 461 | `require_keyboard_navigation` | Recommended | WARNING | Keyboard accessible |
| 462 | `avoid_hover_only_web` | Recommended | INFO | Touch also works |
| 463 | `prefer_browser_specific_handling` | Comprehensive | INFO | Browser differences |

#### Desktop Platform (10 rules)

| # | Rule Name | Tier | Severity | Description |
|---|-----------|------|----------|-------------|
| 464 | `require_window_title` | Recommended | INFO | Window title set |
| 465 | `avoid_desktop_fixed_size` | Professional | INFO | Resizable windows |
| 466 | `prefer_menu_bar` | Professional | INFO | Desktop menu bar |
| 467 | `require_keyboard_shortcuts` | Recommended | INFO | Keyboard shortcuts |
| 468 | `avoid_touch_only_ui` | Recommended | WARNING | Mouse-friendly UI |
| 469 | `prefer_scroll_physics_desktop` | Comprehensive | INFO | Desktop scroll feel |
| 470 | `require_context_menu` | Professional | INFO | Right-click menu |
| 471 | `avoid_mobile_patterns` | Professional | INFO | Desktop patterns |
| 472 | `prefer_native_dialog` | Comprehensive | INFO | Native file dialogs |
| 473 | `require_tray_support` | Comprehensive | INFO | System tray option |

#### iOS Platform (8 rules)

| # | Rule Name | Tier | Severity | Description |
|---|-----------|------|----------|-------------|
| 474 | `require_ios_permissions` | Essential | WARNING | Info.plist permissions |
| 475 | `avoid_cupertino_on_android` | Recommended | INFO | Platform-appropriate UI |
| 476 | `prefer_platform_channel_safety` | Professional | WARNING | Safe platform calls |
| 477 | `require_notch_safety` | Recommended | INFO | Safe areas |
| 478 | `avoid_ios_simulator_only` | Professional | WARNING | Test on device |
| 479 | `prefer_haptic_feedback` | Comprehensive | INFO | Haptics for iOS |
| 480 | `require_ats_compliance` | Essential | WARNING | App Transport Security |
| 481 | `avoid_keychain_misuse` | Professional | WARNING | Keychain correctly |

#### Android Platform (7 rules)

| # | Rule Name | Tier | Severity | Description |
|---|-----------|------|----------|-------------|
| 482 | `require_android_permissions` | Essential | WARNING | Manifest permissions |
| 483 | `avoid_material_on_ios` | Recommended | INFO | Platform-appropriate UI |
| 484 | `prefer_edge_to_edge` | Recommended | INFO | Edge-to-edge display |
| 485 | `require_back_button_handling` | Essential | WARNING | Back button behavior |
| 486 | `avoid_legacy_android_api` | Professional | WARNING | Target recent API |
| 487 | `prefer_splash_screen` | Recommended | INFO | Android 12 splash |
| 488 | `require_proguard_rules` | Professional | INFO | ProGuard config |

### 3.12 Remaining Categories

#### Documentation Rules (+25)
Rules 489-513: Covering docstrings, API docs, README, changelogs

#### API/Network Rules (+25)
Rules 514-538: REST patterns, GraphQL, WebSockets, gRPC

#### Database/Storage Rules (+25)
Rules 539-563: SQLite, drift, ObjectBox, caching patterns

#### Animation Rules (+20)
Rules 564-583: Controllers, curves, performance, accessibility

#### Navigation Rules (+20)
Rules 584-603: Auto-route, Navigator 2.0, deep linking

#### Forms/Validation Rules (+25)
Rules 604-628: FormField, validators, masks, focus

#### Localization Rules (+18)
Rules 629-646: ARB files, plural forms, number formats

#### Dependency Injection Rules (+17)
Rules 647-663: GetIt, Injectable, Provider patterns

---

## Part 4: Tier Assignments

### Tier 1: Essential (~50 rules)

Critical rules that prevent crashes, data loss, and security holes.

```yaml
# essential.yaml - ~50 rules
saropa_lints:
  rules:
    # Memory (must dispose)
    require_dispose_controllers: true
    require_stream_cancel: true
    require_scroll_controller_dispose: true
    require_focus_node_dispose: true

    # Null Safety
    avoid_bang_after_await: true
    avoid_unhandled_async: true

    # Security
    avoid_hardcoded_secrets: true
    avoid_logging_pii: true
    avoid_storing_passwords: true

    # Widget Safety
    avoid_nested_scaffolds: true
    avoid_multiple_material_apps: true

    # State Management
    require_riverpod_scope: true
    require_immutable_bloc_state: true

    # ... ~35 more critical rules
```

### Tier 2: Recommended (~150 rules)

Essential + common mistakes, performance basics, accessibility basics.

```yaml
# recommended.yaml - ~150 rules
include: package:saropa_lints/tiers/essential.yaml

saropa_lints:
  rules:
    # Performance
    prefer_const_widgets: true
    avoid_rebuild_on_scroll: true
    prefer_listview_builder: true

    # Accessibility
    require_semantics_label: true
    avoid_icon_only_buttons: true
    require_minimum_touch_target: true

    # Testing
    require_test_assertions: true
    avoid_test_sleep: true

    # ... ~95 more recommended rules
```

### Tier 3: Professional (~350 rules)

Recommended + architecture, testing, maintainability.

```yaml
# professional.yaml - ~350 rules
include: package:saropa_lints/tiers/recommended.yaml

saropa_lints:
  rules:
    # Architecture
    require_layer_separation: true
    prefer_repository_interface: true
    require_use_case_pattern: true

    # Testing
    require_arrange_act_assert: true
    require_mock_verification: true

    # ... ~195 more professional rules
```

### Tier 4: Comprehensive (~700 rules)

Professional + documentation, style, edge cases.

```yaml
# comprehensive.yaml - ~700 rules
include: package:saropa_lints/tiers/professional.yaml

saropa_lints:
  rules:
    # Documentation
    require_library_doc: true
    require_readme_per_feature: true

    # Style
    prefer_sorted_imports: true

    # ... ~345 more comprehensive rules
```

### Tier 5: Insanity (~1000 rules)

Everything. For the truly obsessive.

```yaml
# insanity.yaml - ALL rules
include: package:saropa_lints/tiers/comprehensive.yaml

saropa_lints:
  rules:
    # Every remaining rule enabled
    # Many are INFO level and may be noisy
    prefer_font_weight_as_number: true  # Pedantic but valid
    prefer_custom_single_child_layout: true  # Rarely needed
    # ... all remaining rules
```

---

## Part 5: Implementation Priority

### Phase 1: Testing Framework
- [ ] Add test dependencies to `pubspec.yaml`
- [ ] Create `test/test_utils/lint_test_helper.dart`
- [ ] Create `test/test_utils/analyze_code.dart`
- [ ] Create test directory structure
- [ ] Write tests for 10 existing rules (validation)
- [ ] Add `dart test` to CI pipeline
- [ ] Add coverage reporting

### Phase 2: Highest Impact (Rules 1-100)
- Widget Rules (60)
- Essential State Management (20)
- Core Performance (20)

### Phase 3: Common Needs (Rules 101-200)
- Testing Rules (48)
- Security Fundamentals (30)
- Accessibility Core (22)

### Phase 4: Advanced Patterns (Rules 201-300)
- Advanced State Management (25)
- Error Handling (30)
- Async Patterns (30)
- More Testing (15)

### Phase 5: Enterprise (Rules 301-400)
- Architecture Rules (40)
- More Security (15)
- Accessibility Complete (13)
- Platform-Specific Start (32)

### Phase 6: Package Ecosystem (Rules 401-500)
- Package-Specific (80)
- Platform Complete (8)
- Remaining Categories (12)

---

## Part 6: File Structure

### New Rule Files to Create

```
custom_lints/lib/src/rules/
├── widget/
│   ├── layout_rules.dart           (15 rules)
│   ├── text_rules.dart             (10 rules)
│   ├── image_rules.dart            (10 rules)
│   ├── input_rules.dart            (15 rules)
│   └── list_rules.dart             (10 rules)
├── state/
│   ├── riverpod_rules.dart         (15 rules)
│   ├── bloc_rules.dart             (15 rules)
│   ├── provider_rules.dart         (10 rules)
│   └── getx_rules.dart             (5 rules)
├── performance/
│   ├── build_rules.dart            (20 rules)
│   ├── memory_rules.dart           (15 rules)
│   └── network_perf_rules.dart     (15 rules)
├── testing/
│   ├── unit_test_rules.dart        (15 rules)
│   ├── widget_test_rules.dart      (18 rules)
│   └── integration_test_rules.dart (15 rules)
├── security/
│   ├── auth_rules.dart             (15 rules)
│   ├── data_rules.dart             (15 rules)
│   └── input_rules.dart            (15 rules)
├── accessibility/
│   ├── screen_reader_rules.dart    (15 rules)
│   ├── visual_rules.dart           (12 rules)
│   └── motor_rules.dart            (8 rules)
├── error/
│   ├── exception_rules.dart        (15 rules)
│   └── async_error_rules.dart      (15 rules)
├── async/
│   ├── future_rules.dart           (15 rules)
│   └── stream_rules.dart           (15 rules)
├── architecture/
│   ├── clean_arch_rules.dart       (15 rules)
│   ├── pattern_rules.dart          (15 rules)
│   └── organization_rules.dart     (10 rules)
├── packages/
│   ├── dio_rules.dart              (15 rules)
│   ├── hive_isar_rules.dart        (15 rules)
│   ├── gorouter_rules.dart         (15 rules)
│   └── firebase_rules.dart         (20 rules)
├── platform/
│   ├── web_rules.dart              (15 rules)
│   ├── desktop_rules.dart          (10 rules)
│   ├── ios_rules.dart              (8 rules)
│   └── android_rules.dart          (7 rules)
└── tiers/
    ├── essential.yaml              (~50 rules)
    ├── recommended.yaml            (~150 rules)
    ├── professional.yaml           (~350 rules)
    ├── comprehensive.yaml          (~700 rules)
    └── insanity.yaml               (~1000 rules)
```

### Test Files to Create

```
custom_lints/test/
├── test_utils/
│   ├── lint_test_helper.dart
│   ├── analyze_code.dart
│   └── lint_expectation.dart
├── fixtures/
│   ├── accessibility/
│   ├── performance/
│   ├── security/
│   └── ...
└── rules/
    ├── accessibility_rules_test.dart
    ├── performance_rules_test.dart
    ├── security_rules_test.dart
    └── ...
```

---

## Summary

| Metric | Value |
|--------|-------|
| Current rules | 475 |
| New rules to add | 500 |
| **Total rules** | **~975** |
| New rule categories | 20+ |
| New rule files | ~30 |
| Test files to create | ~12 |
| Tier configurations | 5 |

This plan provides a comprehensive path to ~1,000 rules with:
- A testing framework for validating all rules
- A clear tier system for managing adoption complexity
- Package-specific rules for the Flutter ecosystem
- Platform-specific rules for web, desktop, iOS, and Android
