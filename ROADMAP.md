# Roadmap: 1000 Lint Rules

## Current Status

- **Implemented**: ~500 rules
- **Goal**: 1000 rules
- **Remaining**: ~500 new rules

---

## Part 1: Testing Framework

### 1.1 Directory Structure

```
saropa_lints/
├── lib/
│   └── src/rules/          # Rule implementations
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
  });
}
```

### 1.4 CI Integration

- [ ] Add `dart test` to CI pipeline
- [ ] Add coverage reporting

---

## Part 2: New Rules by Category

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
| **Total** | **~500** | **+500** | **~1000** | |

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

### 3.7 - 3.12 Additional Categories

See the full specification for:
- Error Handling Rules (+30)
- Async/Concurrency Rules (+30)
- Architecture Rules (+40)
- Package-Specific Rules (+80): Dio, Hive/Isar, GoRouter, Firebase
- Platform-Specific Rules (+40): Web, Desktop, iOS, Android
- Documentation, API/Network, Database, Animation, Navigation, Forms, Localization, DI

---

## Part 4: Tier Assignments

### Tier 1: Essential (~100 rules)

Critical rules that prevent crashes, data loss, and security holes.

### Tier 2: Recommended (~300 rules)

Essential + common mistakes, performance basics, accessibility basics.

### Tier 3: Professional (~600 rules)

Recommended + architecture, testing, maintainability.

### Tier 4: Comprehensive (~800 rules)

Professional + documentation, style, edge cases.

### Tier 5: Insanity (1000 rules)

Everything. For the truly obsessive.

---

## Part 5: Technical Debt & Improvements

### 5.1 Migrate Rules to SaropaLintRule Base Class

**Status**: In Progress
**Priority**: High
**Rationale**: Support hyphenated ignore comments (e.g., `// ignore: no-empty-block`) alongside standard underscore format (`// ignore: no_empty_block`).

**New Infrastructure Created**:
- `lib/src/ignore_utils.dart` - Utilities for checking ignore comments with hyphen/underscore flexibility
- `lib/src/saropa_lint_rule.dart` - Base class that wraps `DiagnosticReporter` to automatically handle hyphenated aliases

**Migration Steps for Each Rule**:
1. Import `saropa_lint_rule.dart`
2. Change `extends DartLintRule` → `extends SaropaLintRule`
3. Rename `run(` → `runWithReporter(`
4. Change `DiagnosticReporter reporter` → `SaropaDiagnosticReporter reporter`

**Files to Migrate** (~35 files, ~500 rules):
- [ ] `accessibility_rules.dart`
- [ ] `api_network_rules.dart`
- [ ] `architecture_rules.dart`
- [ ] `async_rules.dart`
- [ ] `class_constructor_rules.dart`
- [ ] `code_quality_rules.dart`
- [ ] `collection_rules.dart`
- [ ] `complexity_rules.dart`
- [ ] `control_flow_rules.dart`
- [ ] `debug_rules.dart`
- [ ] `dependency_injection_rules.dart`
- [ ] `documentation_rules.dart`
- [ ] `equality_rules.dart`
- [ ] `error_handling_rules.dart`
- [ ] `exception_rules.dart`
- [ ] `flutter_widget_rules.dart`
- [ ] `formatting_rules.dart`
- [ ] `internationalization_rules.dart`
- [ ] `memory_management_rules.dart`
- [ ] `naming_style_rules.dart`
- [ ] `numeric_literal_rules.dart`
- [ ] `performance_rules.dart`
- [ ] `record_pattern_rules.dart`
- [ ] `resource_management_rules.dart`
- [ ] `return_rules.dart`
- [ ] `security_rules.dart`
- [ ] `state_management_rules.dart`
- [ ] `structure_rules.dart`
- [ ] `test_rules.dart`
- [ ] `testing_best_practices_rules.dart`
- [ ] `type_rules.dart`
- [ ] `type_safety_rules.dart`
- [x] `unnecessary_code_rules.dart` (NoEmptyBlockRule migrated as example)

**Example Migration** (NoEmptyBlockRule):
```dart
// Before
class NoEmptyBlockRule extends DartLintRule {
  @override
  void run(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
    CustomLintContext context,
  ) { ... }
}

// After
class NoEmptyBlockRule extends SaropaLintRule {
  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) { ... }
}
```

---

## Part 6: Implementation Priority

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

## Contributing

Want to help implement these rules? See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

Pick a rule from the list above and submit a PR!
