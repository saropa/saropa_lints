# Roadmap: 1000 Lint Rules

## Current Status

See [CHANGELOG.md](https://github.com/saropa/saropa_lints/blob/main/CHANGELOG.md) for implemented rules. Goal: 1000 rules.

---

## Part 1: Test Coverage

### Current Status

| Category | Rules | Fixtures | Coverage |
|----------|-------|----------|----------|
| collection | 16 | 3 | 19% |
| security | 12 | 1 | 8% |
| debug | 5 | 1 | 20% |
| *31 other categories* | 534 | 0 | 0% |
| **Total** | **567** | **5** | **<1%** |

### Priority Categories

Focus testing on high-impact categories first:

1. **error_handling** (8 rules) - prevent silent failures
2. **async** (15 rules) - common source of bugs
3. **security** (12 rules) - 1 fixture, need more
4. **flutter_widget** (107 rules) - largest category

### How to Add Tests

See [CONTRIBUTING.md](https://github.com/saropa/saropa_lints/blob/main/CONTRIBUTING.md) section 5 for the fixture-based testing approach.

### CI Integration

- [ ] Add `dart run custom_lint` to CI pipeline for example/ folder
- [ ] Fail CI if expected lints don't fire

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

### 3.1 Widget Rules

#### Layout & Composition

| # | Rule Name | Tier | Severity | Description |
|---|-----------|------|----------|-------------|
| 2 | `avoid_unbounded_constraints` | Essential | WARNING | Column/Row inside unconstrained widget |
| 4 | `avoid_deep_widget_nesting` | Professional | INFO | Widget depth > 15 levels |
| 5 | `prefer_wrap_over_overflow` | Recommended | WARNING | Use Wrap instead of overflow |
| 6 | `avoid_hardcoded_layout_values` | Comprehensive | INFO | Magic numbers in layout |
| 7 | `prefer_fractional_sizing` | Comprehensive | INFO | FractionallySizedBox for responsive |
| 8 | `avoid_layout_builder_in_scrollable` | Professional | WARNING | LayoutBuilder perf in scrollable |
| 9 | `prefer_intrinsic_dimensions` | Comprehensive | INFO | IntrinsicWidth/Height when needed |
| 11 | `prefer_safe_area_aware` | Recommended | INFO | SafeArea for edge content |
| 12 | `avoid_unconstrained_box_misuse` | Professional | WARNING | UnconstrainedBox causing overflow |
| 13 | `require_overflow_box_rationale` | Comprehensive | INFO | Document OverflowBox usage |
| 14 | `prefer_custom_single_child_layout` | Insanity | INFO | CustomSingleChildLayout for complex |

#### Text & Typography

| # | Rule Name | Tier | Severity | Description |
|---|-----------|------|----------|-------------|
| 16 | `prefer_text_theme` | Recommended | INFO | Use Theme.of(context).textTheme |
| 17 | `avoid_hardcoded_text_styles` | Professional | INFO | Extract text styles to theme |
| 18 | `require_text_overflow_handling` | Essential | WARNING | Long text needs overflow handler |
| 19 | `prefer_rich_text_for_complex` | Comprehensive | INFO | RichText for mixed styles |
| 20 | `avoid_text_scale_factor_ignore` | Recommended | WARNING | Respect textScaleFactor |
| 21 | `require_default_text_style` | Professional | INFO | DefaultTextStyle for consistency |
| 24 | `require_locale_for_text` | Professional | INFO | Locale affects text rendering |

#### Images & Media

| # | Rule Name | Tier | Severity | Description |
|---|-----------|------|----------|-------------|
| 26 | `require_image_error_builder` | Essential | WARNING | Handle image loading errors |
| 28 | `avoid_large_images_in_memory` | Essential | WARNING | Resize large images |
| 29 | `require_image_semantics` | Recommended | WARNING | Alt text for accessibility |
| 30 | `prefer_asset_image_for_local` | Professional | INFO | AssetImage for bundled images |
| 32 | `require_placeholder_for_network` | Recommended | INFO | Show loading placeholder |
| 33 | `prefer_fit_cover_for_background` | Comprehensive | INFO | BoxFit.cover for backgrounds |
| 35 | `require_image_dimensions` | Professional | INFO | Specify width/height |

#### Input & Interaction

| # | Rule Name | Tier | Severity | Description |
|---|-----------|------|----------|-------------|
| 36 | `require_button_loading_state` | Recommended | INFO | Show loading during async |
| 37 | `avoid_gesture_conflict` | Essential | WARNING | Overlapping gesture detectors |
| 39 | `require_disabled_state` | Professional | INFO | Buttons need disabled state |
| 40 | `avoid_double_tap_submit` | Essential | WARNING | Prevent double form submit |
| 41 | `prefer_cursor_for_buttons` | Comprehensive | INFO | Mouse cursor on web |
| 42 | `require_focus_node_dispose` | Essential | ERROR | FocusNode must be disposed |
| 44 | `prefer_actions_and_shortcuts` | Professional | INFO | Use Actions/Shortcuts system |
| 45 | `require_hover_states` | Comprehensive | INFO | Hover feedback on web/desktop |
| 46 | `avoid_absorb_pointer_misuse` | Professional | WARNING | AbsorbPointer blocks all input |
| 47 | `prefer_ignore_pointer` | Comprehensive | INFO | IgnorePointer over AbsorbPointer |
| 48 | `require_drag_feedback` | Professional | INFO | Visual feedback during drag |
| 49 | `avoid_gesture_without_behavior` | Recommended | INFO | Set HitTestBehavior |
| 50 | `require_long_press_callback` | Comprehensive | INFO | Handle onLongPress for context |

#### Lists & Scrolling

| # | Rule Name | Tier | Severity | Description |
|---|-----------|------|----------|-------------|
| 52 | `require_scroll_controller_dispose` | Essential | ERROR | ScrollController must dispose |
| 53 | `avoid_nested_scrollables` | Professional | WARNING | NestedScrollView for nesting |
| 54 | `prefer_sliver_list` | Professional | INFO | SliverList for mixed content |
| 55 | `require_scroll_physics` | Comprehensive | INFO | Define scroll physics |
| 56 | `avoid_shrink_wrap_in_scroll` | Professional | WARNING | shrinkWrap perf impact |
| 57 | `prefer_page_storage_key` | Comprehensive | INFO | Preserve scroll position |
| 58 | `require_refresh_indicator` | Recommended | INFO | Pull to refresh pattern |
| 59 | `avoid_find_child_in_build` | Professional | WARNING | findChildIndexCallback in build |
| 60 | `prefer_keep_alive` | Comprehensive | INFO | AutomaticKeepAliveClientMixin |

### 3.2 State Management

#### Riverpod Rules

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

#### Bloc/Cubit Rules

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

#### Provider Package Rules

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

#### GetX Rules

| # | Rule Name | Tier | Severity | Description |
|---|-----------|------|----------|-------------|
| 101 | `require_getx_controller_dispose` | Essential | WARNING | OnClose for cleanup |
| 102 | `avoid_get_find_in_build` | Essential | WARNING | Get.find in build |
| 103 | `prefer_getx_builder` | Recommended | INFO | GetX/GetBuilder for rebuild |
| 104 | `require_getx_binding` | Professional | INFO | Use Bindings pattern |
| 105 | `avoid_obs_outside_controller` | Recommended | WARNING | .obs in controllers only |

### 3.3 Performance Rules

#### Build Optimization

| # | Rule Name | Tier | Severity | Description |
|---|-----------|------|----------|-------------|
| 106 | `avoid_rebuild_on_scroll` | Essential | WARNING | Rebuilding on scroll |
| 107 | `prefer_const_widgets` | Recommended | INFO | Mark widgets const |
| 108 | `avoid_expensive_computation_in_build` | Essential | WARNING | Heavy work in build |
| 109 | `require_repaint_boundary` | Professional | INFO | RepaintBoundary for isolation |
| 111 | `prefer_builder_for_conditional` | Professional | INFO | Builder widget pattern |
| 113 | `require_widget_key_strategy` | Professional | INFO | Key strategy for lists |
| 114 | `avoid_layout_passes` | Professional | WARNING | Multiple layout passes |
| 115 | `prefer_value_listenable_builder` | Recommended | INFO | ValueListenable for single value |
| 116 | `avoid_calling_of_in_build` | Professional | WARNING | Expensive .of() calls |
| 117 | `prefer_inherited_widget_cache` | Professional | INFO | Cache InheritedWidget lookup |
| 118 | `avoid_text_span_rebuild` | Comprehensive | INFO | Reuse TextSpan objects |
| 119 | `require_should_rebuild` | Professional | INFO | shouldRebuild optimization |
| 120 | `avoid_widget_creation_in_loop` | Essential | WARNING | Create widgets once |
| 121 | `prefer_element_rebuild` | Comprehensive | INFO | Element rebuild optimization |
| 123 | `require_build_context_scope` | Recommended | WARNING | BuildContext invalid after |
| 124 | `prefer_selector_over_consumer` | Professional | INFO | More granular rebuilds |
| 125 | `avoid_global_key_misuse` | Essential | WARNING | GlobalKey causes rebuild |

#### Memory Optimization

| # | Rule Name | Tier | Severity | Description |
|---|-----------|------|----------|-------------|
| 126 | `require_image_cache_management` | Essential | WARNING | Clear image cache |
| 127 | `avoid_memory_intensive_operations` | Essential | WARNING | Large allocations |
| 128 | `prefer_weak_reference` | Comprehensive | INFO | WeakReference for cache |
| 129 | `require_list_preallocate` | Professional | INFO | List.filled for known size |
| 131 | `prefer_typed_data` | Professional | INFO | Uint8List over List<int> |
| 132 | `require_isolate_for_heavy` | Professional | WARNING | compute() for heavy work |
| 133 | `avoid_finalizer_misuse` | Comprehensive | INFO | Finalizer rarely needed |
| 134 | `prefer_pool_pattern` | Comprehensive | INFO | Object pooling for reuse |
| 135 | `require_dispose_pattern` | Essential | ERROR | Disposable resources |
| 136 | `avoid_closure_memory_leak` | Essential | WARNING | Closures holding references |
| 137 | `prefer_static_const_widgets` | Professional | INFO | Static const for reuse |
| 138 | `require_expando_cleanup` | Comprehensive | INFO | Clean Expando objects |
| 140 | `prefer_iterable_operations` | Professional | INFO | Lazy iteration |

#### Network Performance

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

### 3.4 Testing Rules

#### Unit Testing

| # | Rule Name | Tier | Severity | Description |
|---|-----------|------|----------|-------------|
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

#### Widget Testing

| # | Rule Name | Tier | Severity | Description |
|---|-----------|------|----------|-------------|
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

#### Integration Testing

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

### 3.5 Security Rules

#### Authentication & Authorization

| # | Rule Name | Tier | Severity | Description |
|---|-----------|------|----------|-------------|
| 204 | `require_auth_check` | Essential | ERROR | Protected routes check auth |
| 208 | `require_token_refresh` | Recommended | WARNING | Handle token expiry |
| 210 | `avoid_auth_state_in_prefs` | Essential | WARNING | Secure storage for auth |
| 211 | `require_logout_cleanup` | Essential | WARNING | Clear data on logout |
| 212 | `prefer_oauth_pkce` | Professional | INFO | PKCE for mobile OAuth |
| 213 | `avoid_jwt_decode_client` | Recommended | INFO | Don't trust client JWT |
| 214 | `require_session_timeout` | Professional | INFO | Session expiry |
| 215 | `prefer_deep_link_auth` | Professional | INFO | Validate deep link auth |
| 216 | `avoid_remember_me_insecure` | Recommended | WARNING | Secure remember me |
| 217 | `require_multi_factor` | Comprehensive | INFO | Consider MFA |
| 218 | `avoid_auth_in_query_params` | Essential | ERROR | Auth not in URL |

#### Data Protection

| # | Rule Name | Tier | Severity | Description |
|---|-----------|------|----------|-------------|
| 220 | `require_data_encryption` | Essential | WARNING | Encrypt sensitive data |
| 221 | `prefer_secure_random` | Recommended | WARNING | SecureRandom for crypto |
| 223 | `require_keychain_access` | Professional | INFO | iOS keychain properly |
| 224 | `prefer_encrypted_prefs` | Recommended | INFO | Encrypt SharedPrefs |
| 227 | `prefer_data_masking` | Professional | INFO | Mask sensitive display |
| 228 | `avoid_screenshot_sensitive` | Recommended | WARNING | Prevent screenshots |
| 229 | `require_secure_keyboard` | Professional | INFO | Secure keyboard input |
| 230 | `prefer_local_auth` | Professional | INFO | Local auth for sensitive |
| 231 | `avoid_external_storage_sensitive` | Essential | ERROR | No sensitive on SD |
| 232 | `require_backup_exclusion` | Professional | INFO | Exclude from backup |
| 233 | `prefer_root_detection` | Professional | INFO | Detect rooted devices |

#### Input Validation & Injection

| # | Rule Name | Tier | Severity | Description |
|---|-----------|------|----------|-------------|
| 235 | `avoid_dynamic_sql` | Essential | ERROR | Parameterized queries |
| 236 | `prefer_html_escape` | Recommended | WARNING | Escape HTML output |
| 238 | `require_url_validation` | Essential | WARNING | Validate URLs |
| 239 | `prefer_regex_validation` | Recommended | INFO | Regex for format check |
| 240 | `avoid_path_traversal` | Essential | ERROR | Validate file paths |
| 241 | `require_json_schema_validation` | Professional | INFO | Validate JSON schema |
| 242 | `prefer_whitelist_validation` | Professional | INFO | Whitelist over blacklist |
| 243 | `avoid_redirect_injection` | Essential | WARNING | Validate redirects |
| 244 | `require_content_type_check` | Professional | INFO | Check response types |
| 245 | `prefer_csrf_protection` | Professional | WARNING | CSRF tokens |
| 247 | `require_deep_link_validation` | Essential | WARNING | Validate deep links |
| 248 | `prefer_intent_filter_export` | Professional | INFO | Limit intent filters |

### 3.6 Accessibility Rules

#### Screen Reader Support

| # | Rule Name | Tier | Severity | Description |
|---|-----------|------|----------|-------------|
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

#### Visual Accessibility

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

#### Motor Accessibility

| # | Rule Name | Tier | Severity | Description |
|---|-----------|------|----------|-------------|
| 278 | `prefer_adequate_spacing` | Recommended | INFO | Spacing between targets |
| 279 | `require_drag_alternatives` | Professional | INFO | Alternative to drag |
| 280 | `avoid_time_limits` | Recommended | INFO | No strict time limits |
| 281 | `prefer_external_keyboard` | Comprehensive | INFO | External keyboard support |
| 282 | `require_switch_control` | Comprehensive | INFO | Switch control support |
| 283 | `avoid_hover_only` | Recommended | INFO | Not hover-dependent |

### 3.7 - 3.12 Additional Categories

See the full specification for:
- Error Handling Rules
- Async/Concurrency Rules
- Architecture Rules
- Package-Specific Rules: Dio, Hive/Isar, GoRouter, Firebase
- Platform-Specific Rules: Web, Desktop, iOS, Android
- Documentation, API/Network, Database, Animation, Navigation, Forms, Localization, DI

---

## Part 4: Tier Assignments

### Tier 1: Essential

Critical rules that prevent crashes, data loss, and security holes.

### Tier 2: Recommended

Essential + common mistakes, performance basics, accessibility basics.

### Tier 3: Professional

Recommended + architecture, testing, maintainability.

### Tier 4: Comprehensive

Professional + documentation, style, edge cases.

### Tier 5: Insanity

Everything. For the truly obsessive.

### Stylistic / Opinionated Rules (No Tier)

These rules are **not included in any tier** by default. They represent team preferences where there is no objectively "correct" answer. Teams explicitly enable them based on their coding conventions.

> **See [STYLISTIC.md](https://github.com/saropa/saropa_lints/blob/main/STYLISTIC.md)** for full documentation on implemented stylistic rules.

**Planned:**

#### Import & File Organization

| Rule Name | Description |
|-----------|-------------|
| `prefer_sorted_imports` | Alphabetically sort imports within groups |
| `prefer_import_groups` | Group imports: dart, package, relative (with blank lines) |
| `prefer_absolute_imports` | Use absolute `package:` imports (opposite of prefer_relative_imports) |
| `prefer_deferred_imports` | Use deferred imports for large libraries |
| `prefer_show_hide` | Explicit `show`/`hide` on imports |
| `prefer_part_over_import` | Use `part`/`part of` for tightly coupled files |
| `prefer_import_over_part` | Use imports instead of `part`/`part of` |

#### Naming Conventions

| Rule Name | Description |
|-----------|-------------|
| `prefer_lowercase_constants` | Constants in `lowerCamelCase` (Dart style guide) |
| `prefer_verb_method_names` | Methods start with verbs (`get`, `set`, `fetch`, `compute`) |
| `prefer_noun_class_names` | Class names are nouns or noun phrases |
| `prefer_adjective_bool_getters` | Boolean getters as adjectives (`isEmpty` vs `getIsEmpty`) |
| `prefer_i_prefix_interfaces` | Interface classes use `I` prefix (`IRepository`) |
| `prefer_no_i_prefix_interfaces` | Interface classes without `I` prefix |
| `prefer_impl_suffix` | Implementation classes use `Impl` suffix |
| `prefer_base_prefix` | Base classes use `Base` prefix |
| `prefer_mixin_prefix` | Mixins use `Mixin` suffix or no suffix |
| `prefer_extension_suffix` | Extensions use `Extension` or `X` suffix |

#### Member Ordering

| Rule Name | Description |
|-----------|-------------|
| `prefer_public_members_first` | Public members before private in classes |
| `prefer_private_members_first` | Private members before public in classes |
| `prefer_fields_before_methods` | Field declarations at top of class |
| `prefer_methods_before_fields` | Methods before field declarations |
| `prefer_constructors_first` | Constructors before other members |
| `prefer_getters_before_setters` | Getters immediately before their setters |
| `prefer_static_before_instance` | Static members before instance members |
| `prefer_factory_before_named` | Factory constructors before named constructors |
| `prefer_overrides_last` | `@override` methods at bottom of class |

#### Comments & Documentation

| Rule Name | Description |
|-----------|-------------|
| `prefer_no_commented_code` | Disallow commented-out code blocks |
| `prefer_inline_comments_sparingly` | Limit inline comments; prefer self-documenting code |

#### String Preferences

| Rule Name | Description |
|-----------|-------------|
| `prefer_double_quotes` | Double quotes `"string"` for strings |
| `prefer_raw_strings` | Raw strings `r'...'` when escapes are heavy |
| `prefer_adjacent_strings` | Adjacent strings over `+` concatenation |
| `prefer_interpolation_to_compose` | String interpolation `${}` over concatenation |

#### Function & Method Style

| Rule Name | Description |
|-----------|-------------|
| `prefer_function_over_static_method` | Top-level functions over static methods |
| `prefer_static_method_over_function` | Static methods over top-level functions |
| `prefer_expression_body_getters` | Arrow `=>` for simple getters |
| `prefer_block_body_setters` | Block body `{}` for setters |
| `prefer_positional_bool_params` | Boolean parameters as positional |
| `prefer_named_bool_params` | Boolean parameters as named |
| `prefer_optional_positional_params` | `[optional]` over `{named}` |
| `prefer_optional_named_params` | `{named}` over `[positional]` |

#### Type & Class Style

| Rule Name | Description |
|-----------|-------------|
| `prefer_final_fields_always` | All instance fields should be `final` |
| `prefer_mixin_over_abstract` | Mixins over abstract classes when appropriate |
| `prefer_extension_over_utility_class` | Extension methods over static utility classes |
| `prefer_typedef_for_callbacks` | `typedef` for function type aliases |
| `prefer_inline_function_types` | Inline function types over `typedef` |
| `prefer_sealed_classes` | Sealed classes for closed type hierarchies |

**Usage:**

```yaml
custom_lint:
  rules:
    - prefer_relative_imports: true
    - prefer_explicit_types: true
```

---

## Part 5: Technical Debt & Improvements

### 5.0 SaropaLintRule Base Class Enhancements

The `SaropaLintRule` base class provides enhanced features for all lint rules.

#### Planned Enhancements

| # | Feature | Priority | Description |
|---|---------|----------|-------------|
| 1 | **Diagnostic Statistics** | Medium | Track hit counts per rule for metrics/reporting |
| 2 | **Related Rules** | Low | Link related rules together, suggest complementary rules |
| 3 | **Suppression Tracking** | High | Audit trail of suppressed lints for tech debt tracking |
| 4 | **Batch Deduplication** | Low | Prevent duplicate reports at same offset |
| 5 | **Custom Ignore Prefixes** | Low | Support `// saropa-ignore:`, `// tech-debt:` prefixes |
| 6 | **Performance Tracking** | Medium | Measure rule execution time for optimization |
| 7 | **Tier-Based Filtering** | Medium | Enable/disable rules by tier at runtime |

##### 5.0.1 Diagnostic Statistics (#1)

Track how many times each rule fires across a codebase for:
- Prioritizing fixes ("847 `avoid_print` vs 3 `avoid_hardcoded_credentials`")
- Measuring progress over time
- Identifying problem files
- Tuning overly aggressive rules

```dart
abstract class SaropaLintRule extends DartLintRule {
  static final Map<String, int> hitCounts = {};
  static final Map<String, Set<String>> fileHits = {};

  int get hitCount => hitCounts[code.name] ?? 0;
}
```

##### 5.0.2 Related Rules (#2)

Link rules together for better discoverability:

```dart
class RequireDisposeRule extends SaropaLintRule {
  @override
  List<String> get relatedRules => [
    'require_stream_controller_dispose',
    'require_animation_controller_dispose',
  ];
}
```

##### 5.0.3 Suppression Tracking (#3)

Record every time a lint is suppressed for tech debt auditing:

```dart
class SaropaDiagnosticReporter {
  static final List<SuppressionRecord> suppressions = [];

  // Output: "avoid_print: 12 suppressions in 5 files"
}
```

Use cases:
- Tech debt tracking
- Security audits ("are security rules being suppressed?")
- Cleanup campaigns

##### 5.0.4 Batch Deduplication (#4)

Prevent the same issue from being reported multiple times when AST visitors traverse nodes from multiple angles:

```dart
class SaropaDiagnosticReporter {
  final Set<int> _reportedOffsets = {};

  void atNode(AstNode node, LintCode code) {
    if (_reportedOffsets.contains(node.offset)) return;
    _reportedOffsets.add(node.offset);
    // ...
  }
}
```

##### 5.0.5 Custom Ignore Prefixes (#5)

Support project-specific ignore comment styles:

```dart
// All of these would suppress the lint:
// ignore: avoid_print
// saropa-ignore: avoid_print
// tech-debt: avoid_print (tracked separately for auditing)
```

##### 5.0.6 Performance Tracking (#6)

Measure rule execution time to identify slow rules:

```dart
abstract class SaropaLintRule extends DartLintRule {
  static final Map<String, Duration> executionTimes = {};

  // Output report:
  // avoid_excessive_widget_depth: 2.3s (needs optimization!)
  // require_dispose: 0.1s
}
```

##### 5.0.7 Tier-Based Filtering (#7)

Enable/disable rules based on strictness tiers at runtime:

```dart
// Configure via environment or analysis_options.yaml
// SAROPA_TIER=recommended dart analyze

abstract class SaropaLintRule extends DartLintRule {
  SaropaTier get tier;

  bool shouldRunForTier(SaropaTier activeTier) =>
    tier.index <= activeTier.index;
}
```

---

## Part 6: Implementation Priority

### Phase 1: Test Coverage
- [ ] Add fixtures for error_handling rules (8 rules)
- [ ] Add fixtures for async rules (15 rules)
- [ ] Add fixtures for remaining security rules (11 rules)
- [ ] Add `dart run custom_lint` to CI for example/ folder

### Phase 2: Highest Impact
- Widget Rules
- Essential State Management
- Core Performance

### Phase 3: Common Needs
- Testing Rules
- Security Fundamentals
- Accessibility Core

### Phase 4: Advanced Patterns
- Advanced State Management
- Error Handling
- Async Patterns
- More Testing

### Phase 5: Enterprise
- Architecture Rules
- More Security
- Accessibility Complete
- Platform-Specific Start

### Phase 6: Package Ecosystem
- Package-Specific
- Platform Complete
- Remaining Categories

---

## Part 7: Modern Dart & Flutter Language Features

This section tracks new Dart/Flutter language features that developers should learn, and corresponding lint rules to help adopt them.

### 7.1 Dart Language Features

| Version | Date | Feature | Description | Lint Rule | Status |
|---------|------|---------|-------------|-----------|--------|
| 3.10 | Nov 2025 | Dot Shorthands | Write `.center` instead of `MainAxisAlignment.center` | `prefer_dot_shorthand` | Planned |
| 3.10 | Nov 2025 | Analyzer Plugin System | Official plugin architecture for custom analysis | Consider migration | Research |
| 3.10 | Nov 2025 | Specific Deprecation Annotations | Finer-grained deprecation control | `use_specific_deprecation` | Planned |
| 3.9 | Aug 2025 | Improved Type Promotion | Null safety assumed for type promotion/reachability | `avoid_redundant_null_check` | Planned |
| 3.9 | Aug 2025 | Sound Null Safety Only | `--no-sound-null-safety` flag removed | N/A | - |
| 3.8 | May 2025 | Null-Aware Elements | `?item` in collections - include only if non-null | `prefer_null_aware_elements` | Planned |
| 3.8 | May 2025 | Auto Trailing Commas | Formatter handles commas automatically | N/A (formatter) | - |
| 3.7 | Feb 2025 | Tall Style Formatter | New vertical formatting style | N/A (formatter) | - |
| 3.6 | Dec 2024 | Pub Workspaces | Monorepo support | N/A (tooling) | - |
| 3.5 | Aug 2024 | Web Interop APIs (Stable) | `dart:js_interop` at 1.0 | `prefer_js_interop_over_dart_js` | Planned |
| 3.5 | Aug 2024 | JNIgen (Preview) | Java/Kotlin interop generator | Interop rules | Research |
| 3.3 | Feb 2024 | Extension Types | Zero-cost wrappers for types | `prefer_extension_type_for_wrapper` | Planned |
| 3.0 | May 2023 | Records | Tuple-like data: `(String, int)` | `prefer_record_over_tuple_class` | Planned |
| 3.0 | May 2023 | Sealed Classes | Exhaustive type hierarchies | `prefer_sealed_for_state` | Planned |
| 3.0 | May 2023 | Switch Expressions | Expression-based switching | `prefer_switch_expression` | Planned |

---

### 7.2 Flutter Widget Features

| Version | Date | Feature | Description | Lint Rule | Status |
|---------|------|---------|-------------|-----------|--------|
| 3.38 | Nov 2025 | OverlayPortal.overlayChildLayoutBuilder | Render overlays outside parent constraints | `prefer_overlay_portal_layout_builder` | Planned |
| 3.27 | Dec 2024 | Cupertino widget updates | CupertinoCheckbox, CupertinoRadio | Cupertino rules | Planned |
| 3.27 | Dec 2024 | Impeller default on Android | New rendering engine | N/A (engine) | - |
| 3.24 | Aug 2024 | Impeller API | Low-level graphics API | N/A (engine) | - |
| 3.24 | Aug 2024 | Swift Package Manager (Preview) | iOS package management | N/A (tooling) | - |
| 3.22 | May 2024 | WebAssembly (Wasm) Support | Near-native web performance | N/A (platform) | - |
| 3.19 | Feb 2024 | Material 2 to 3 Migration | Theme migration guidance | `prefer_material3_theme` | Planned |

---

### 7.3 Modern Dart Rules Summary

#### High Priority (Widely Applicable)

| Rule Name | Tier | Description | Version |
|-----------|------|-------------|---------|
| `prefer_dot_shorthand` | Recommended | Use `.value` instead of `EnumType.value` | Dart 3.10 |
| `prefer_null_aware_elements` | Recommended | Use `?item` in collections | Dart 3.8 |
| `prefer_switch_expression` | Recommended | Use switch expressions over statements | Dart 3.0 |

#### Medium Priority (Architecture/Design)

| Rule Name | Tier | Description | Version |
|-----------|------|-------------|---------|
| `prefer_sealed_for_state` | Professional | Use sealed classes for state | Dart 3.0 |
| `prefer_extension_type_for_wrapper` | Professional | Zero-cost wrappers | Dart 3.3 |
| `require_exhaustive_sealed_switch` | Essential | Exhaustive switches on sealed types | Dart 3.0 |

---

## Contributing

Want to help implement these rules? See [CONTRIBUTING.md](https://github.com/saropa/saropa_lints/blob/main/CONTRIBUTING.md) for guidelines.

Pick a rule from the list above and submit a PR!

---

## About This Document

> "Plans are nothing; planning is everything." — Dwight D. Eisenhower

> "The best time to plant a tree was 20 years ago. The second best time is now." — Chinese Proverb

This **roadmap** outlines our path to 1000 lint rules. The goal is comprehensive coverage of Flutter and Dart best practices — from essential safety rules that prevent crashes to advanced architectural patterns that scale to enterprise applications.

Rules are prioritized by impact: memory safety, security, and accessibility before style preferences. We welcome contributions at any skill level. Pick a rule, implement it, submit a PR. The Flutter community benefits when we all contribute.

**Keywords:** Flutter roadmap, Dart lint rules planned, custom_lint development, Flutter static analysis future, lint rule implementation, open source contribution, Flutter code quality tools, Riverpod lints, Bloc lints, Provider lints, accessibility rules, security rules

**Hashtags:** #Flutter #Dart #OpenSource #Roadmap #Contributing #FlutterDev #DartLang #StaticAnalysis #CodeQuality #Community

---

## Sources

- **Dart 3.x Release Notes** — New language features by version
  https://dart.dev/guides/language/evolution

- **Flutter Release Notes** — Widget and framework changes
  https://docs.flutter.dev/release/release-notes

- **custom_lint Documentation** — Building custom lint rules
  https://pub.dev/packages/custom_lint

- **Dart Analyzer API** — AST visitor documentation
  https://pub.dev/documentation/analyzer/latest/

- **Riverpod Documentation** — State management patterns
  https://riverpod.dev/

- **Bloc Documentation** — Bloc pattern best practices
  https://bloclibrary.dev/

- **WCAG 2.1 Guidelines** — Accessibility success criteria
  https://www.w3.org/WAI/WCAG21/quickref/

- **OWASP Mobile Security** — Mobile application security testing
  https://owasp.org/www-project-mobile-security-testing-guide/
