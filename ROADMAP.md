# Roadmap: 1000 Lint Rules

## Current Status

See [CHANGELOG.md](https://github.com/saropa/saropa_lints/blob/main/CHANGELOG.md) for implemented rules. Goal: 1000 rules.

### Recently Implemented (v1.7.0) - 50 Rules

The following rules from this roadmap have been implemented:

**State Management (Riverpod/Bloc):**
- `avoid_ref_in_dispose`, `require_provider_scope`, `prefer_select_for_partial`, `avoid_provider_in_widget`, `prefer_family_for_params`
- `avoid_bloc_event_mutation`, `prefer_copy_with_for_state`, `avoid_bloc_listen_in_build`, `require_initial_state`, `require_error_state`, `avoid_bloc_in_bloc`, `prefer_sealed_events`

**Performance:**
- `avoid_scroll_listener_in_build`, `prefer_value_listenable_builder`, `avoid_global_key_misuse`, `require_repaint_boundary`, `avoid_text_span_in_build`
- `prefer_const_widgets`, `avoid_expensive_computation_in_build`, `avoid_widget_creation_in_loop`, `require_build_context_scope`, `avoid_calling_of_in_build`
- `require_image_cache_management`, `avoid_memory_intensive_operations`, `avoid_closure_memory_leak`, `prefer_static_const_widgets`, `require_dispose_pattern`

**Testing:**
- `avoid_test_coupling`, `require_test_isolation`, `avoid_real_dependencies_in_tests`, `require_scroll_tests`, `require_text_input_tests`

**Navigation:**
- `avoid_navigator_push_unnamed`, `require_route_guards`, `avoid_circular_redirects`, `avoid_pop_without_result`, `prefer_shell_route_for_persistent_ui`

**Security:**
- `require_auth_check`, `require_token_refresh`, `avoid_jwt_decode_client`, `require_logout_cleanup`, `avoid_auth_in_query_params`

**Forms:**
- `require_form_key`, `avoid_validation_in_build`, `require_submit_button_state`, `avoid_form_without_unfocus`
- `require_form_restoration`, `avoid_clearing_form_on_error`, `require_form_field_controller`, `avoid_form_in_alert_dialog`

---

## Part 1: Detailed Rule Specifications

### 1.1 Widget Rules

#### Layout & Composition

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| `require_overflow_box_rationale` | Comprehensive | INFO | OverflowBox allows children to overflow parent bounds, which can cause visual glitches. Require a comment explaining why overflow is intentional. |
| `prefer_custom_single_child_layout` | Insanity | INFO | For complex single-child positioning logic, CustomSingleChildLayout is more efficient than nested Positioned/Align/Transform widgets. |

#### Text & Typography

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| `prefer_text_theme` | Recommended | INFO | Hardcoded TextStyle values ignore theme changes. Use `Theme.of(context).textTheme` for consistent typography that respects user preferences. |
| `require_text_overflow_handling` | Essential | WARNING | Text without overflow handling causes layout errors or clipped content on small screens. Add `overflow: TextOverflow.ellipsis` or wrap in Flexible/Expanded. |
| `prefer_rich_text_for_complex` | Comprehensive | INFO | Multiple adjacent Text widgets with different styles are less efficient than a single RichText with TextSpans. |
| `avoid_text_scale_factor_ignore` | Recommended | WARNING | Using `textScaleFactor: 1.0` ignores user accessibility settings. Users with visual impairments rely on system text scaling. |
| `require_locale_for_text` | Professional | INFO | Some text operations (date formatting, number formatting, sorting) produce incorrect results without explicit Locale. |

#### Images & Media

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| `require_image_semantics` | Recommended | WARNING | Images without `semanticLabel` are invisible to screen readers. Provide descriptive alt text for accessibility compliance. |
| `avoid_unconstrained_images` | Professional | INFO | Images without sizing constraints cause layout shifts when they load. Acceptable constraints include: explicit dimensions, AspectRatio parent, Expanded/Flexible parent, FractionallySizedBox, or SizedBox. Images with `fit` property in unconstrained contexts still need bounds. |

#### Input & Interaction

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| `avoid_absorb_pointer_misuse` | Professional | WARNING | AbsorbPointer blocks ALL touch events including scrolling. Often IgnorePointer (which allows events to pass through) is the correct choice. |

### 1.2 State Management

#### Riverpod Rules

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| `prefer_ref_watch_over_read` | Recommended | INFO | `ref.read` doesn't subscribe to changes - widget won't rebuild when provider updates. Use `ref.watch` in build methods for reactive updates. |
| `require_riverpod_override_in_tests` | Professional | INFO | Tests using real providers have hidden dependencies and unpredictable state. Override providers with mocks for isolated, deterministic tests. |
| `avoid_provider_recreate` | Essential | WARNING | Creating providers inside build() creates new instances every rebuild, losing state. Define providers as top-level final variables. |
| `prefer_family_for_params` | Professional | INFO | Providers that need parameters should use `.family` modifier instead of passing params through other means, enabling proper caching per parameter. |
| `require_auto_dispose` | Recommended | INFO | Providers without autoDispose keep state forever, even when no longer used. Add autoDispose to free resources when all listeners are removed. |
| `avoid_circular_provider_deps` | Essential | ERROR | Provider A depending on Provider B which depends on Provider A causes stack overflow or infinite loops at runtime. |
| `prefer_notifier_over_state` | Professional | INFO | StateProvider is for simple values. Complex state with multiple fields or validation logic should use Notifier/AsyncNotifier for better organization. |
| `require_error_handling_in_async` | Essential | WARNING | AsyncValue can be loading, data, or error. Code that only handles `.value` crashes or shows blank UI when errors occur. Handle all three states. |
| `avoid_provider_in_widget` | Recommended | WARNING | Declaring providers inside widget classes makes them instance-specific and breaks Riverpod's global state model. Declare at file level. |
| `prefer_select_for_partial` | Professional | INFO | Watching an entire object rebuilds when any field changes. Use `ref.watch(provider.select((s) => s.field))` to rebuild only when specific fields change. |
| `require_riverpod_lint` | Comprehensive | INFO | The official riverpod_lint package catches Riverpod-specific mistakes. Add it alongside saropa_lints for complete coverage. |
| `avoid_ref_in_dispose` | Essential | ERROR | The `ref` object is invalid during dispose - providers may already be destroyed. Accessing ref in dispose throws exceptions. |
| `prefer_consumer_widget` | Recommended | INFO | Consumer widget as a child requires extra nesting. ConsumerWidget as the parent class is cleaner and gives ref access throughout build(). |
| `require_provider_scope` | Essential | ERROR | Riverpod requires ProviderScope at the widget tree root. Without it, all provider access throws "ProviderScope not found" errors. |

#### Bloc/Cubit Rules

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| `avoid_bloc_event_mutation` | Essential | ERROR | Bloc events should be immutable. Mutating an event after dispatch causes race conditions and makes debugging impossible. |
| `prefer_copyWith_for_state` | Recommended | INFO | Directly modifying state fields breaks immutability. Use `state.copyWith(field: newValue)` to create new state instances. |
| `avoid_yield_in_on_event` | Professional | WARNING | The `yield` keyword is deprecated in bloc event handlers. Use `emit()` instead for emitting new states. |
| `require_bloc_test_coverage` | Professional | INFO | Blocs should have tests covering all state transitions. Untested state machines have hidden bugs in edge cases. |
| `prefer_cubit_for_simple` | Recommended | INFO | Bloc's event system adds overhead for simple state. Cubit (direct method calls) is simpler when you don't need event traceability. |
| `avoid_bloc_listen_in_build` | Essential | WARNING | `BlocProvider.of(context)` with listen:true in build causes rebuilds on every state change. Use BlocBuilder or listen:false. |
| `require_bloc_transformer` | Professional | INFO | Without an event transformer, rapid events process sequentially causing UI lag. Use `droppable()`, `debounce()`, or `restartable()`. |
| `avoid_long_event_handlers` | Professional | INFO | Event handlers over 50 lines are hard to test and maintain. Extract business logic into separate methods or use cases. |
| `prefer_sealed_events` | Comprehensive | INFO | Sealed classes for events enable exhaustive switch statements, so the compiler catches unhandled events. |
| `require_initial_state` | Essential | ERROR | Bloc without an initial state throws at runtime. Always pass initial state to super() in the constructor. |
| `avoid_bloc_in_bloc` | Recommended | WARNING | Blocs calling other blocs directly creates tight coupling. Use a parent widget or service to coordinate between blocs. |
| `prefer_bloc_observer` | Professional | INFO | BlocObserver logs all state transitions and errors globally. Essential for debugging state issues in complex apps. |
| `require_error_state` | Recommended | INFO | States should include an error variant. Without it, errors are either swallowed or crash the app instead of showing error UI. |

#### Provider Package Rules

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| `avoid_provider_of_in_build` | Essential | WARNING | `Provider.of(context)` defaults to listen:true, causing unnecessary rebuilds. Use `context.read()` for one-time access or Consumer for scoped rebuilds. |
| `prefer_consumer_over_provider_of` | Recommended | INFO | Consumer widget limits rebuilds to its subtree. `Provider.of` in build() rebuilds the entire widget even when only part needs the value. |
| `require_provider_dispose` | Essential | WARNING | ChangeNotifier and other resources must be disposed. Use `create` with `dispose` callback, or ChangeNotifierProvider which auto-disposes. |
| `avoid_change_notifier_in_widget` | Recommended | WARNING | Creating ChangeNotifier inside a widget's build() creates new instances on rebuild, losing state. Create in provider or stateful widget. |
| `prefer_selector` | Professional | INFO | Selector rebuilds only when the selected value changes. Watching the whole object rebuilds on any field change, wasting CPU cycles. |
| `require_multi_provider` | Professional | INFO | Nested Provider widgets create deep indentation. MultiProvider flattens the tree and is easier to read and maintain. |
| `avoid_nested_providers` | Comprehensive | INFO | Deeply nested provider trees are hard to reason about. Flatten with MultiProvider and avoid provider-in-provider patterns. |
| `prefer_proxy_provider` | Comprehensive | INFO | When a provider depends on another provider, use ProxyProvider to automatically update when dependencies change. |
| `require_update_callback` | Comprehensive | INFO | ProxyProvider's `update` callback runs on dependency changes. Without explicit handling, stale closures or missing updates cause bugs. |
| `avoid_listen_in_async` | Essential | WARNING | `context.watch()` in async callbacks uses stale context. Use `context.read()` to get values once without subscribing to changes. |

#### GetX Rules

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| `require_getx_controller_dispose` | Essential | WARNING | GetX controllers must clean up resources in `onClose()`. Streams, timers, and listeners not cancelled cause memory leaks. |
| `avoid_get_find_in_build` | Essential | WARNING | `Get.find()` in build() can throw if controller isn't registered yet. Use `Get.put()` first or access via GetBuilder/GetX widget. |
| `prefer_getx_builder` | Recommended | INFO | Direct `.obs` access in build() doesn't trigger rebuilds. Use GetX, GetBuilder, or Obx widgets to properly subscribe to reactive values. |
| `require_getx_binding` | Professional | INFO | Bindings ensure controllers are created and disposed at the right time. Without them, manual Get.put/delete calls are error-prone. |
| `avoid_obs_outside_controller` | Recommended | WARNING | `.obs` reactive variables outside GetxController aren't disposed automatically. This causes memory leaks when the widget is destroyed. |

### 1.3 Performance Rules

#### Build Optimization

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| `avoid_rebuild_on_scroll` | Essential | WARNING | ScrollController listeners or NotificationListener in build() trigger rebuilds on every scroll pixel, causing jank. Move scroll handling to StatefulWidget. |
| `prefer_const_widgets` | Recommended | INFO | Widgets that can be const are created once and reused. Without const, Flutter creates new instances on every parent rebuild. |
| `avoid_expensive_computation_in_build` | Essential | WARNING | build() is called frequently (60fps during animations). Sorting, filtering, or complex calculations here cause frame drops. Cache results or use compute(). |
| `require_repaint_boundary` | Professional | INFO | RepaintBoundary isolates painting to a subtree. Complex animations or frequently changing content should be wrapped to avoid repainting siblings. |
| `prefer_builder_for_conditional` | Professional | INFO | Conditional widgets (if/else in build) can be wrapped in Builder to limit rebuild scope when the condition changes. |
| `require_widget_key_strategy` | Professional | INFO | Lists without proper Keys cause Flutter to rebuild all items when one changes. Use ValueKey, ObjectKey, or UniqueKey based on your data identity. |
| `avoid_layout_passes` | Professional | WARNING | Widgets like IntrinsicWidth/IntrinsicHeight cause two layout passes. Avoid them in lists or frequently rebuilt widgets. |
| `prefer_value_listenable_builder` | Recommended | INFO | For single-value reactivity, ValueListenableBuilder is more efficient than full state management solutions. Less boilerplate for simple cases. |
| `avoid_calling_of_in_build` | Professional | WARNING | `Theme.of()`, `MediaQuery.of()` traverse the widget tree. Call once and store in a local variable, or use specific methods like `MediaQuery.sizeOf()`. |
| `prefer_inherited_widget_cache` | Professional | INFO | Repeated InheritedWidget lookups (`.of(context)`) traverse the tree each time. Cache the result in a local variable when used multiple times. |
| `avoid_text_span_rebuild` | Comprehensive | INFO | Creating new TextSpan objects in build() prevents Flutter's text layout caching. Store TextSpans as final fields when content is static. |
| `require_should_rebuild` | Professional | INFO | Custom InheritedWidgets should override `updateShouldNotify` to return false when the value hasn't meaningfully changed. |
| `avoid_widget_creation_in_loop` | Essential | WARNING | Creating widgets inside loops (`.map()`) in build creates new instances every rebuild. Extract to a method or use ListView.builder. |
| `prefer_element_rebuild` | Comprehensive | INFO | Returning the same widget type with same key reuses Elements. Changing widget types or keys destroys Elements, losing state and causing expensive rebuilds. |
| `require_build_context_scope` | Recommended | WARNING | BuildContext becomes invalid after async gaps. Storing context and using it after await can access disposed widgets, causing crashes. |
| `prefer_selector_over_consumer` | Professional | INFO | Selector rebuilds only when selected value changes. Consumer rebuilds on any provider change, even fields you don't use. |
| `avoid_global_key_misuse` | Essential | WARNING | GlobalKey prevents widget reuse across the tree. Overusing GlobalKeys negates Flutter's efficient diffing algorithm. |

#### Memory Optimization

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| `require_image_cache_management` | Essential | WARNING | Flutter's ImageCache grows unbounded by default. Large images accumulate in memory. Call `imageCache.clear()` or `imageCache.evict()` when appropriate. |
| `avoid_memory_intensive_operations` | Essential | WARNING | Allocating large lists, loading full images into memory, or string concatenation in loops can cause out-of-memory crashes on low-end devices. |
| `prefer_weak_reference` | Comprehensive | INFO | Caches holding strong references prevent garbage collection. Use WeakReference for objects that can be recreated, allowing GC to reclaim memory under pressure. |
| `require_list_preallocate` | Professional | INFO | `List.filled(n, value)` or `List.generate(n, ...)` preallocates capacity. Growing lists with `.add()` causes repeated reallocations and memory fragmentation. |
| `prefer_typed_data` | Professional | INFO | `Uint8List` uses 1 byte per element; `List<int>` uses 8 bytes. For binary data, typed data lists use 8x less memory and are faster. |
| `require_isolate_for_heavy` | Professional | WARNING | Heavy computation on main isolate blocks UI (16ms budget per frame). Use `compute()` or `Isolate.run()` for JSON parsing, image processing, or data transforms. |
| `avoid_finalizer_misuse` | Comprehensive | INFO | Dart Finalizers run non-deterministically and add GC overhead. Prefer explicit dispose() methods. Finalizers are only for native resource cleanup as a safety net. |
| `prefer_pool_pattern` | Comprehensive | INFO | Frequently created/destroyed objects cause GC churn. Object pools reuse instances (e.g., for particles, bullet hell games, or recyclable list items). |
| `require_dispose_pattern` | Essential | ERROR | Objects holding resources (streams, controllers, subscriptions) must be disposed. Undisposed resources leak memory and can cause crashes. |
| `avoid_closure_memory_leak` | Essential | WARNING | Closures capture their enclosing scope. A closure referencing `this` in a callback keeps the entire widget alive even after disposal. |
| `prefer_static_const_widgets` | Professional | INFO | `static const` widgets are created once at compile time. Instance widgets are recreated on every parent rebuild, wasting memory and CPU. |
| `require_expando_cleanup` | Comprehensive | INFO | Expando attaches data to objects without modifying them. Entries persist until the key object is GC'd. Remove entries explicitly when done. |
| `prefer_iterable_operations` | Professional | INFO | `.map()`, `.where()` return lazy iterables. Using `.toList()` unnecessarily allocates memory. Keep operations lazy until you need a concrete list. |

#### Network Performance

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| `prefer_http_connection_reuse` | Professional | INFO | Each new HTTP connection requires DNS lookup, TCP handshake, and TLS negotiation. Reuse connections via http.Client or dio's connection pooling. |
| `avoid_redundant_requests` | Essential | WARNING | Multiple widgets requesting the same data simultaneously wastes bandwidth. Deduplicate concurrent requests to the same endpoint. |
| `require_response_caching` | Professional | INFO | GET responses for static data should be cached. Repeated fetches for unchanged data waste bandwidth and battery. |
| `prefer_pagination` | Recommended | INFO | Loading thousands of items at once is slow and memory-intensive. Paginate with limit/offset or cursor-based pagination. |
| `avoid_over_fetching` | Professional | INFO | Fetching entire objects when you only need a few fields wastes bandwidth. Use GraphQL field selection or REST sparse fieldsets. |
| `require_compression` | Comprehensive | INFO | Large JSON/text responses should use gzip compression. Reduces bandwidth 60-80% for typical API responses. |
| `prefer_batch_requests` | Professional | INFO | Multiple small requests have more overhead than one batched request. Combine related queries when the API supports it. |
| `require_retry_strategy` | Recommended | INFO | Network requests fail transiently. Implement exponential backoff retry for idempotent requests (GET, PUT, DELETE). |
| `avoid_blocking_main_thread` | Essential | WARNING | Network I/O on main thread blocks UI during DNS/TLS. While Dart's http is async, large response processing should use isolates. |
| `prefer_streaming_response` | Comprehensive | INFO | Large downloads should stream to disk instead of buffering in memory. Prevents out-of-memory for large files. |
| `require_cancel_token` | Professional | WARNING | Requests for disposed screens waste resources. Use CancelToken (dio) or cancel HTTP client requests when the widget is disposed. |
| `avoid_json_in_main` | Professional | INFO | `jsonDecode()` for large payloads (>100KB) blocks the main thread. Use `compute()` to parse JSON in a background isolate. |
| `prefer_binary_format` | Comprehensive | INFO | Protocol Buffers or MessagePack are smaller and faster to parse than JSON. Consider for high-frequency or large-payload APIs. |
| `require_network_status_check` | Recommended | INFO | Check connectivity before making requests that will obviously fail. Show appropriate offline UI instead of timeout errors. |

### 1.4 Testing Rules

#### Unit Testing

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| `avoid_test_coupling` | Essential | WARNING | Tests that depend on other tests' state or execution order are fragile. Each test must set up its own state and clean up after itself. |
| `prefer_single_assertion` | Professional | INFO | Tests with multiple assertions are harder to debug - you only see the first failure. One logical assertion per test clarifies what broke. |
| `avoid_real_dependencies` | Essential | WARNING | Tests hitting real databases, APIs, or file systems are slow, flaky, and can corrupt data. Mock external dependencies. |
| `prefer_fake_over_mock` | Comprehensive | INFO | Fakes (simple implementations) are easier to maintain than mocks with verify() chains. Use mocks only when you need to verify interactions. |
| `require_edge_case_tests` | Professional | INFO | Test boundary conditions: empty lists, null values, max int, empty strings, unicode, negative numbers. Edge cases cause most production bugs. |
| `prefer_test_data_builder` | Comprehensive | INFO | Builder pattern for test objects (e.g., `UserBuilder().withName('test').build()`) is cleaner than constructors with many parameters. |
| `require_error_case_tests` | Recommended | INFO | Happy path tests are insufficient. Test that errors are thrown for invalid input, network failures, and permission denials. |
| `avoid_test_implementation_details` | Professional | INFO | Tests that verify internal method calls break when you refactor. Test observable behavior (outputs, state changes) instead. |
| `require_test_isolation` | Essential | WARNING | Tests sharing state (static variables, singletons, database rows) fail randomly based on execution order. Reset state in setUp/tearDown. |

#### Widget Testing

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| `prefer_pump_and_settle` | Recommended | INFO | `pump()` advances one frame. Animations and async operations need `pumpAndSettle()` to complete all pending frames before assertions. |
| `require_scroll_tests` | Recommended | INFO | Scrollable widgets may hide content. Test that items appear after scrolling with `drag()` or `scrollUntilVisible()`. |
| `avoid_find_all` | Professional | INFO | `find.byType(Text)` matches many widgets. Use specific finders like `find.text('exact')` or `find.byKey()` for reliable tests. |
| `require_text_input_tests` | Recommended | INFO | TextFields have complex behavior: focus, validation, keyboard types. Test with `enterText()`, `testTextInput`, and form submission. |
| `prefer_test_variant` | Comprehensive | INFO | Testing multiple screen sizes or themes? Use `testWidgets` with `variant: ValueVariant({...})` instead of duplicating tests. |
| `require_accessibility_tests` | Recommended | WARNING | Use `meetsGuideline(textContrastGuideline)` and `meetsGuideline(androidTapTargetGuideline)` to verify accessibility compliance. |
| `require_dialog_tests` | Recommended | INFO | Dialogs require special handling: tap to open, find within dialog context, test dismiss behavior. Don't forget barrier dismiss tests. |
| `prefer_fake_platform` | Comprehensive | INFO | Platform channels (camera, GPS, storage) need fakes in tests. Use `TestDefaultBinaryMessengerBinding` to mock platform responses. |
| `require_animation_tests` | Comprehensive | INFO | Animations should be tested for start/end states and interruption. Use `pump(duration)` to advance to specific points. |

#### Integration Testing

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| `require_integration_test_setup` | Recommended | INFO | Integration tests need `IntegrationTestWidgetsFlutterBinding.ensureInitialized()` in main(). Without it, tests hang or crash on device. |
| `prefer_test_groups` | Professional | INFO | Group related tests with `group()` for better organization. Shared setUp/tearDown runs for the group, reducing duplication. |
| `require_test_ordering` | Professional | INFO | Integration tests may depend on database state from previous tests. Document dependencies or use `setUp` to ensure required state. |
| `prefer_retry_flaky` | Comprehensive | INFO | Integration tests on real devices are inherently flaky. Configure retry count in CI (e.g., `--retry=2`) rather than deleting useful tests. |
| `require_test_cleanup` | Professional | INFO | Tests that create files, database entries, or user accounts must clean up in `tearDown`. Leftover data causes subsequent test failures. |
| `avoid_hardcoded_delays` | Essential | WARNING | `await Future.delayed(Duration(seconds: 2))` is flaky - too short fails, too long wastes time. Use `pumpAndSettle()` or wait for conditions. |
| `prefer_test_data_reset` | Professional | INFO | Each test should start with known state. Reset database, clear shared preferences, and log out users in setUp to prevent test pollution. |
| `require_e2e_coverage` | Professional | INFO | Integration tests are expensive. Focus on critical user journeys: signup, purchase, core features. Don't duplicate unit test coverage. |
| `avoid_screenshot_in_ci` | Comprehensive | INFO | Screenshots in CI consume storage and slow tests. Take screenshots only on failure for debugging, not on every test. |
| `prefer_test_report` | Comprehensive | INFO | Generate JUnit XML or JSON reports for CI dashboards. Raw console output is hard to track over time. |
| `require_performance_test` | Professional | INFO | Measure frame rendering time and startup latency in integration tests. Catch performance regressions before they reach production. |
| `avoid_test_on_real_device` | Recommended | INFO | Real devices vary in performance and state. Use emulators/simulators in CI for consistent, reproducible results. |
| `prefer_parallel_tests` | Comprehensive | INFO | Independent integration tests can run in parallel with `--concurrency`. Reduces total CI time significantly for large test suites. |
| `require_test_documentation` | Comprehensive | INFO | Complex integration tests with unusual setup or assertions need comments explaining the test scenario and why it matters. |

### 1.5 Security Rules

#### Authentication & Authorization

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| `require_auth_check` | Essential | ERROR | Routes showing user data must verify authentication. Without checks, users can access protected screens via deep links or back navigation. |
| `require_token_refresh` | Recommended | WARNING | Access tokens expire. Without refresh logic, users get logged out unexpectedly. Implement token refresh before expiry or on 401 responses. |
| `avoid_auth_state_in_prefs` | Essential | WARNING | SharedPreferences stores data as plain text. Auth tokens and session data must use flutter_secure_storage or platform keychain. |
| `require_logout_cleanup` | Essential | WARNING | Logout must clear tokens, cached user data, and navigation state. Incomplete cleanup leaves sensitive data accessible to the next user. |
| `prefer_oauth_pkce` | Professional | INFO | Mobile OAuth without PKCE is vulnerable to authorization code interception. Use PKCE (Proof Key for Code Exchange) for secure OAuth flows. |
| `avoid_jwt_decode_client` | Recommended | INFO | JWTs can be forged client-side. Never trust decoded JWT claims for authorization - always verify with the backend. |
| `require_session_timeout` | Professional | INFO | Sessions without timeout remain valid forever if tokens are stolen. Implement idle timeout and absolute session limits. |
| `prefer_deep_link_auth` | Professional | INFO | Deep links with auth tokens (password reset, magic links) must validate tokens server-side and expire quickly. |
| `avoid_remember_me_insecure` | Recommended | WARNING | "Remember me" storing unencrypted credentials is a security risk. Use refresh tokens with proper rotation and revocation. |
| `require_multi_factor` | Comprehensive | INFO | Sensitive operations (payments, account changes) should offer or require multi-factor authentication for additional security. |
| `avoid_auth_in_query_params` | Essential | ERROR | Tokens in URLs appear in browser history, server logs, and referrer headers. Pass auth tokens in headers or POST body only. |

#### Data Protection

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| `require_data_encryption` | Essential | WARNING | Sensitive data (PII, financial, health) must be encrypted at rest. Use AES-256 or platform encryption APIs, not custom schemes. |
| `prefer_secure_random` | Recommended | WARNING | `Random()` is predictable. Use `Random.secure()` for tokens, IVs, salts, and anything security-sensitive. |
| `require_keychain_access` | Professional | INFO | iOS Keychain requires proper access groups and entitlements. Incorrect configuration causes data loss on app reinstall. |
| `prefer_encrypted_prefs` | Recommended | INFO | SharedPreferences is plain text. Use encrypted_shared_preferences or flutter_secure_storage for sensitive values. |
| `prefer_data_masking` | Professional | INFO | Sensitive data displayed on screen (SSN, credit cards) should be partially masked (••••1234) to prevent shoulder surfing. |
| `avoid_screenshot_sensitive` | Recommended | WARNING | Financial and auth screens should disable screenshots using platform APIs. Screenshots expose sensitive data. |
| `require_secure_keyboard` | Professional | INFO | Password fields should use secure text entry to disable keyboard autocomplete, suggestions, and clipboard history. |
| `prefer_local_auth` | Professional | INFO | Sensitive operations (viewing saved passwords, confirming payments) should require biometric or PIN re-authentication. |
| `avoid_external_storage_sensitive` | Essential | ERROR | Android external storage (SD card) is world-readable. Never store sensitive data there - use app-private internal storage. |
| `require_backup_exclusion` | Professional | INFO | Sensitive data should be excluded from iCloud/Google backups. Backups are often less protected than the device. |
| `prefer_root_detection` | Professional | INFO | Rooted/jailbroken devices bypass security controls. Detect and warn users, or disable sensitive features on compromised devices. |

#### Input Validation & Injection

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| `avoid_dynamic_sql` | Essential | ERROR | String concatenation in SQL queries enables SQL injection. Use parameterized queries (`?` placeholders) for all user input. |
| `prefer_html_escape` | Recommended | WARNING | User content displayed in WebViews must be HTML-escaped to prevent XSS attacks. Use html.escape() or sanitization libraries. |
| `require_url_validation` | Essential | WARNING | URLs from user input can point to malicious sites or internal resources. Validate scheme (https only) and domain against allowlist. |
| `prefer_regex_validation` | Recommended | INFO | Format validation (email, phone, postal code) should use regex patterns. String checks like `.contains('@')` miss invalid formats. |
| `avoid_path_traversal` | Essential | ERROR | File paths from user input like `../../../etc/passwd` can access arbitrary files. Sanitize paths and validate they stay within allowed directories. |
| `require_json_schema_validation` | Professional | INFO | API responses should be validated against expected schema. Malformed responses can crash the app or cause unexpected behavior. |
| `prefer_whitelist_validation` | Professional | INFO | Validate input against known-good values (allowlist) rather than blocking known-bad values (blocklist). Blocklists miss novel attacks. |
| `avoid_redirect_injection` | Essential | WARNING | Redirect URLs from user input enable phishing. Validate redirect targets are on your domain or an explicit allowlist. |
| `require_content_type_check` | Professional | INFO | Verify response Content-Type before parsing. A JSON endpoint returning HTML could indicate an attack or misconfiguration. |
| `prefer_csrf_protection` | Professional | WARNING | State-changing requests need CSRF tokens. Without protection, malicious sites can trigger actions on behalf of logged-in users. |
| `require_deep_link_validation` | Essential | WARNING | Deep links can pass arbitrary data to your app. Validate and sanitize all deep link parameters before using them. |
| `prefer_intent_filter_export` | Professional | INFO | Android intent filters should be exported only when necessary. Unexported components can't be invoked by malicious apps. |

### 1.6 Accessibility Rules

#### Screen Reader Support

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| `prefer_explicit_semantics` | Recommended | INFO | Widgets without Semantics are invisible to screen readers. Add explicit Semantics wrapper with label for custom widgets. |
| `require_image_description` | Essential | WARNING | Decorative images need `excludeFromSemantics: true`. Meaningful images need `semanticLabel` describing their content. |
| `avoid_semantics_exclusion` | Recommended | WARNING | `excludeFromSemantics` hides content from screen readers. Only use for truly decorative elements, with a comment explaining why. |
| `prefer_merge_semantics` | Professional | INFO | Related elements (icon + text) should be wrapped in MergeSemantics so screen readers announce them as one unit. |
| `require_heading_hierarchy` | Professional | INFO | Screen reader users navigate by headings. Use Semantics with `header: true` and ensure logical heading order (h1 before h2). |
| `avoid_redundant_semantics` | Comprehensive | INFO | An Image with semanticLabel inside a Semantics wrapper announces twice. Remove duplicate semantic information. |
| `prefer_semantics_container` | Professional | INFO | Groups of related widgets should use Semantics `container: true` to indicate they form a logical unit for navigation. |
| `require_button_semantics` | Recommended | INFO | Custom tap targets (GestureDetector on Container) need Semantics with `button: true` so screen readers announce them as buttons. |
| `avoid_hidden_interactive` | Essential | ERROR | Elements with `excludeFromSemantics: true` that have onTap handlers are unusable by screen reader users. Critical accessibility bug. |
| `prefer_semantics_sort` | Professional | INFO | Complex layouts may need `sortKey` to control screen reader navigation order. Default order may not match visual layout. |
| `require_live_region` | Recommended | INFO | Dynamic content updates (toasts, counters) need Semantics with `liveRegion: true` so screen readers announce changes. |
| `avoid_semantics_in_animation` | Comprehensive | INFO | Semantics should not change during animations. Screen readers get confused by rapidly changing semantic trees. |
| `prefer_announce_for_changes` | Comprehensive | INFO | Important state changes should use `SemanticsService.announce()` to inform screen reader users of non-visual feedback. |

#### Visual Accessibility

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| `require_minimum_contrast` | Essential | WARNING | Text must have 4.5:1 contrast ratio against background (3:1 for large text). Use contrast checker tools during design. |
| `avoid_color_only_meaning` | Essential | WARNING | Never use color alone to convey information (red=error). Add icons, text, or patterns for colorblind users. |
| `prefer_scalable_text` | Recommended | INFO | Text should scale with system font size settings. Avoid fixed pixel sizes; use MediaQuery.textScaleFactor. |
| `require_focus_indicator` | Recommended | WARNING | Keyboard/switch users need visible focus indicators. Ensure focused elements have distinct borders or highlights. |
| `avoid_small_text` | Recommended | INFO | Text smaller than 12sp is difficult to read. Ensure minimum readable size, especially for body text. |
| `prefer_high_contrast_mode` | Professional | INFO | Support MediaQuery.highContrast for users who need stark color differences. Provide high-contrast theme variant. |
| `require_error_identification` | Essential | WARNING | Errors must be identifiable without color: use icons, text labels, and position (near the field) to indicate problems. |
| `avoid_motion_without_reduce` | Recommended | INFO | Check MediaQuery.disableAnimations and reduce/disable animations for users with vestibular disorders. |
| `prefer_dark_mode_colors` | Professional | INFO | Dark mode isn't just inverted colors. Ensure proper contrast, reduce pure white text, and test readability. |
| `require_link_distinction` | Comprehensive | INFO | Links must be distinguishable from regular text without relying on color alone. Use underline or other visual treatment. |
| `avoid_flashing_content` | Essential | WARNING | Content flashing more than 3 times per second can trigger seizures. Avoid strobing effects entirely. |
| `prefer_outlined_icons` | Comprehensive | INFO | Outlined icons have better visibility than filled icons for users with low vision. Consider icon style for accessibility. |

#### Motor Accessibility

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| `prefer_adequate_spacing` | Recommended | INFO | Touch targets too close together cause mis-taps for users with motor impairments. Maintain 8dp+ spacing between interactive elements. |
| `require_drag_alternatives` | Professional | INFO | Drag gestures are difficult for some users. Provide button alternatives for drag-to-reorder, swipe-to-delete, etc. |
| `avoid_time_limits` | Recommended | INFO | Timed interactions (auto-logout, disappearing toasts) disadvantage users who need more time. Allow extension or disable timeouts. |
| `prefer_external_keyboard` | Comprehensive | INFO | Support full keyboard navigation for users who can't use touch. Ensure all actions are reachable via Tab and Enter. |
| `require_switch_control` | Comprehensive | INFO | Switch control users navigate sequentially. Ensure logical focus order and that all interactive elements are focusable. |
| `avoid_hover_only` | Recommended | INFO | Touch devices and screen readers don't have hover. Never hide essential information or actions behind hover states. |

### 1.7 Animation Rules

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| `require_animation_curve` | Recommended | INFO | Linear animations feel robotic. Use Curves (easeInOut, bounceIn, etc.) for natural motion that matches platform conventions. |
| `avoid_animation_in_build` | Essential | WARNING | Creating AnimationController in build() creates new controllers every frame. Initialize in initState and dispose properly. |
| `require_vsync_mixin` | Essential | ERROR | AnimationController without vsync wastes battery animating when widget is off-screen. Add SingleTickerProviderStateMixin. |
| `prefer_tween_sequence` | Professional | INFO | Complex multi-stage animations should use TweenSequence rather than chaining multiple controllers or delayed futures. |
| `avoid_hardcoded_duration` | Recommended | INFO | Animation durations should come from theme or constants for consistency. 300ms buttons and 500ms page transitions are common defaults. |
| `require_animation_status_listener` | Professional | INFO | One-shot animations need StatusListener to know when complete. Without it, you can't trigger follow-up actions reliably. |
| `prefer_implicit_animations` | Recommended | INFO | AnimatedContainer, AnimatedOpacity are simpler than explicit controllers for basic transitions. Use implicit when possible. |
| `avoid_overlapping_animations` | Professional | WARNING | Multiple animations on same property conflict. Use AnimationController.stop() before starting new animation on same widget. |
| `require_hero_tag_uniqueness` | Essential | ERROR | Duplicate Hero tags cause "Multiple heroes" crash. Ensure unique tags, especially in lists where items might share structure. |
| `prefer_physics_simulation` | Comprehensive | INFO | SpringSimulation and FrictionSimulation create more natural feel than fixed curves for drag-release and momentum scrolling. |
| `avoid_animation_rebuild_waste` | Professional | WARNING | AnimatedBuilder should wrap only the animating subtree. Wrapping entire screen rebuilds everything 60fps. |
| `require_staggered_animation_delays` | Professional | INFO | List item animations should stagger (50-100ms delay between items). Simultaneous animations look jarring and hurt performance. |

### 1.8 Navigation & Routing Rules

#### Navigator & GoRouter

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| `avoid_navigator_push_unnamed` | Recommended | INFO | `Navigator.push(MaterialPageRoute(...))` bypasses named routes, breaking deep links and analytics. Use named routes or GoRouter. |
| `require_route_guards` | Essential | WARNING | Protected routes must check auth before rendering. GoRouter's redirect or Navigator observers prevent unauthorized access. |
| `avoid_nested_navigators_misuse` | Professional | WARNING | Nested Navigators (tabs with own stacks) need careful WillPopScope handling. Back button behavior confuses users when done wrong. |
| `require_deep_link_testing` | Professional | INFO | Every route should be testable via deep link. Routes only reachable through navigation chains break when users share links. |
| `prefer_go_router_redirect` | Professional | INFO | Auth checks in redirect() run before build, preventing flash of protected content. Checking in build shows then redirects. |
| `avoid_context_after_navigation` | Essential | ERROR | Context is invalid after Navigator.pop(). Using context in .then() after navigation causes "Looking up deactivated widget" crash. |
| `require_route_transition_consistency` | Recommended | INFO | Mix of slide, fade, and no transitions feels broken. Define consistent page transitions in theme or router config. |
| `prefer_typed_route_params` | Professional | INFO | Route parameters as strings require parsing and can fail silently. Use typed extras (GoRouter) or arguments with type checking. |
| `avoid_circular_redirects` | Essential | ERROR | Route A redirecting to B which redirects to A causes infinite loop. Track redirect chain and break cycles. |
| `require_unknown_route_handler` | Essential | WARNING | Unhandled routes show red error screen. Define onUnknownRoute (Navigator) or errorBuilder (GoRouter) for graceful 404. |
| `prefer_shell_route_for_persistent_ui` | Professional | INFO | Bottom nav bars and side drawers should use ShellRoute (GoRouter) to persist across child routes without rebuilding. |
| `avoid_pop_without_result` | Professional | INFO | Screens expecting results from pushed routes should handle null (user pressed back). Always check Navigator.pop result. |

#### Deep Linking

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| `require_universal_link_validation` | Essential | WARNING | iOS Universal Links and Android App Links need server-side apple-app-site-association and assetlinks.json. Test on real devices. |
| `avoid_deep_link_sensitive_params` | Essential | ERROR | Passwords and tokens in deep links appear in system logs and can be intercepted. Use one-time codes that expire quickly. |
| `require_deep_link_fallback` | Recommended | INFO | Deep links should gracefully degrade when target content doesn't exist (deleted item, expired link). Show helpful error, not crash. |
| `prefer_branch_io_or_firebase_links` | Professional | INFO | Raw deep links break when app not installed. Branch.io or Firebase Dynamic Links provide install-then-open flow. |

### 1.9 Forms & Validation Rules

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| `require_form_key` | Essential | ERROR | Forms without GlobalKey can't call validate() or save(). The FormState is inaccessible without a key. |
| `prefer_autovalidate_on_interaction` | Recommended | INFO | AutovalidateMode.always shows errors before user types. Use onUserInteraction to validate after first input. |
| `require_form_field_controller` | Professional | INFO | TextFormField without controller loses value on rebuild. Either use controller or onSaved, but be consistent. |
| `avoid_validation_in_build` | Essential | WARNING | Complex validation (regex, API calls) in validator runs on every keystroke. Debounce or validate on submit only. |
| `require_error_message_context` | Recommended | INFO | "Invalid input" is useless. Error messages should explain what's wrong and how to fix it: "Email must contain @". |
| `prefer_form_bloc_for_complex` | Professional | INFO | Forms with >5 fields, conditional logic, or multi-step flows benefit from form state management (FormBloc, Reactive Forms). |
| `avoid_clearing_form_on_error` | Essential | WARNING | Clearing fields when validation fails forces users to re-enter everything. Preserve input and highlight errors. |
| `require_keyboard_type` | Recommended | INFO | Email fields need TextInputType.emailAddress, phone needs .phone, numbers need .number. Wrong keyboard frustrates users. |
| `prefer_input_formatters` | Professional | INFO | Phone numbers, credit cards, dates should auto-format as user types using TextInputFormatter for better UX. |
| `require_submit_button_state` | Recommended | INFO | Submit buttons should disable during submission and show loading indicator. Prevents double-submit and shows progress. |
| `avoid_form_without_unfocus` | Professional | INFO | Forms should unfocus (FocusScope.of(context).unfocus()) on submit. Keyboard staying open after submit feels broken. |
| `require_form_restoration` | Professional | INFO | Long forms should survive app backgrounding. Use RestorationMixin or persist draft state to avoid losing user input. |

### 1.10 Database & Storage Rules

#### Local Database (Hive/Isar/Drift)

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| `require_database_migration` | Essential | ERROR | Schema changes without migration corrupt data or crash. Define migration strategy before shipping v1. |
| `avoid_blocking_database_ui` | Essential | WARNING | Database operations block UI if run on main isolate. Use compute() or database's async APIs for large queries. |
| `require_database_index` | Professional | INFO | Queries filtering/sorting on unindexed fields are O(n). Add indexes for fields used in where clauses. |
| `prefer_lazy_box_for_large` | Professional | INFO | Hive's regular Box loads all data into memory. Use LazyBox for large collections to load entries on demand. |
| `avoid_storing_sensitive_unencrypted` | Essential | ERROR | Hive/Isar store data as readable files. Use encrypted box or flutter_secure_storage for tokens and passwords. |
| `require_database_close` | Essential | WARNING | Database connections must close on logout/dispose. Open connections leak memory and can lock files. |
| `prefer_transaction_for_batch` | Professional | INFO | Multiple writes should use transactions. Individual writes have overhead and can leave partial state on crash. |
| `avoid_database_in_widget` | Recommended | WARNING | Database access directly in widgets couples UI to storage. Use repository pattern for testability and flexibility. |
| `require_type_adapter_registration` | Essential | ERROR | Hive custom types need TypeAdapter registered before use. Missing adapter causes "Adapter not found" crash. |
| `prefer_isar_for_complex_queries` | Comprehensive | INFO | Hive's query capabilities are limited. Isar supports complex queries, full-text search, and links between objects. |

#### SharedPreferences & Secure Storage

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| `avoid_prefs_for_large_data` | Recommended | WARNING | SharedPreferences loads entire file on first access. Keep it small (<100 keys, simple values). Use database for collections. |
| `require_prefs_key_constants` | Recommended | INFO | String literals for pref keys cause typos. Define keys as constants in one place for autocomplete and refactoring. |
| `prefer_typed_prefs_wrapper` | Professional | INFO | Raw SharedPreferences returns dynamic. Wrap in typed class with getters/setters for type safety and documentation. |
| `avoid_secure_storage_on_web` | Essential | WARNING | flutter_secure_storage uses localStorage on web, which isn't secure. Use different strategy for web platform. |

### 1.11 Platform-Specific Rules

#### iOS-Specific

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| `require_ios_permission_description` | Essential | ERROR | iOS rejects apps without Info.plist usage descriptions for camera, location, etc. Add NSCameraUsageDescription etc. |
| `avoid_http_without_ats_exception` | Essential | ERROR | iOS blocks non-HTTPS by default (App Transport Security). Add exception in Info.plist only if absolutely necessary. |
| `prefer_cupertino_for_ios_feel` | Recommended | INFO | Material widgets look foreign on iOS. Use CupertinoPageRoute, CupertinoAlertDialog for native feel, or adaptive widgets. |
| `require_ios_background_mode` | Professional | INFO | Background tasks need specific capabilities in Xcode: background fetch, remote notifications, audio, location. |
| `avoid_ios_13_deprecations` | Recommended | WARNING | iOS 13+ deprecates UIWebView, UIAlertView, and others. Use WKWebView and modern APIs to avoid App Store rejection. |
| `require_apple_sign_in` | Essential | ERROR | Apps with third-party login (Google, Facebook) must also offer Sign in with Apple per App Store guidelines. |

#### Android-Specific

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| `require_android_permission_request` | Essential | ERROR | Android 6+ requires runtime permission requests. Declaring in manifest isn't enough; call requestPermission(). |
| `avoid_android_task_affinity_default` | Professional | INFO | Multiple activities with default taskAffinity can cause confusing back stack. Set explicit affinity for each activity. |
| `require_android_12_splash` | Recommended | INFO | Android 12+ enforces system splash screen. Customize via themes to avoid double splash (system + Flutter). |
| `prefer_pending_intent_flags` | Essential | ERROR | PendingIntent without FLAG_IMMUTABLE or FLAG_MUTABLE crashes on Android 12+. Specify flag explicitly. |
| `avoid_android_cleartext_traffic` | Essential | WARNING | Android 9+ blocks HTTP by default. Enable cleartextTrafficPermitted only for specific debug domains, never production. |
| `require_android_backup_rules` | Professional | INFO | Define backup_rules.xml to control what's backed up. Sensitive data in shared_prefs backs up by default. |

#### Web-Specific

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| `avoid_platform_channel_on_web` | Essential | ERROR | MethodChannel doesn't work on web. Use conditional imports and dart:js_interop for web-specific functionality. |
| `require_web_renderer_awareness` | Professional | INFO | CanvasKit vs HTML renderer have different capabilities and bundle sizes. Test on both; choose based on needs. |
| `prefer_url_strategy_for_web` | Recommended | INFO | Hash URLs (/#/page) look ugly and break SEO. Use PathUrlStrategy for clean URLs in production web apps. |
| `avoid_large_assets_on_web` | Recommended | WARNING | Web has no app install; assets download on demand. Lazy-load images and use appropriate formats (WebP) for faster loads. |
| `require_cors_handling` | Essential | ERROR | Web apps face CORS restrictions desktop/mobile don't have. API must send proper headers or use proxy for third-party APIs. |
| `prefer_deferred_loading_web` | Professional | INFO | Web bundle size matters for initial load. Use deferred imports to split code and load features on demand. |

#### Desktop-Specific (Windows/macOS/Linux)

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| `require_window_size_constraints` | Recommended | INFO | Desktop apps need minimum window size to prevent unusable layouts. Set constraints in main() or platform runner. |
| `prefer_keyboard_shortcuts` | Recommended | INFO | Desktop users expect Ctrl+S, Ctrl+Z, etc. Implement Shortcuts and Actions for standard keyboard interactions. |
| `require_menu_bar_for_desktop` | Professional | INFO | macOS apps need menu bar. Use PlatformMenuBar for standard menus (File, Edit, View) on desktop platforms. |
| `avoid_touch_only_gestures` | Recommended | WARNING | Desktop has mouse, not touch. GestureDetector works, but also handle mouse hover, right-click, scroll wheel. |
| `require_window_close_confirmation` | Professional | INFO | Unsaved changes should prompt on window close. Handle windowShouldClose callback to prevent data loss. |
| `prefer_native_file_dialogs` | Professional | INFO | Use file_picker or file_selector for native open/save dialogs. Custom dialogs feel out of place on desktop. |

### 1.12 Firebase Rules

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| `require_firebase_init_before_use` | Essential | ERROR | Firebase.initializeApp() must complete before accessing any Firebase service. Await it in main() before runApp(). |
| `avoid_firestore_unbounded_query` | Essential | WARNING | Firestore without limit() fetches entire collection, costing money and time. Always limit results or use pagination. |
| `require_firestore_index` | Essential | ERROR | Compound queries need composite indexes. Firestore throws error with link to create index; don't ignore in dev. |
| `prefer_firestore_batch_write` | Professional | INFO | Multiple writes should use batch() or transaction(). Individual writes have higher latency and cost. |
| `avoid_firestore_in_widget_build` | Essential | WARNING | StreamBuilder with Firestore query in build() creates new listener on every rebuild. Cache stream reference. |
| `require_firebase_auth_state_listener` | Essential | WARNING | Checking currentUser once misses sign-out events. Use authStateChanges() stream to react to auth state. |
| `prefer_firebase_auth_persistence` | Recommended | INFO | Web Firebase Auth defaults to session persistence. Set persistence to LOCAL for "remember me" functionality. |
| `avoid_storing_user_data_in_auth` | Recommended | WARNING | Firebase Auth custom claims are limited (1000 bytes). Store user profiles in Firestore, not in auth token. |
| `require_crashlytics_user_id` | Professional | INFO | Set Crashlytics userIdentifier to correlate crashes with users. Helps debug user-reported issues. |
| `prefer_firebase_remote_config_defaults` | Recommended | INFO | Remote Config returns null if fetch fails. Set in-app defaults so app works offline on first launch. |
| `avoid_firebase_storage_public_rules` | Essential | ERROR | Storage rules "allow read, write: if true" lets anyone upload anything. Require auth and validate file types. |
| `require_firebase_app_check` | Professional | WARNING | Firebase App Check prevents abuse from non-app clients. Enable for production to protect backend resources. |

### 1.13 Offline-First & Sync Rules

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| `require_offline_indicator` | Recommended | INFO | Users should know when they're offline. Show banner or icon when connectivity is lost; don't silently fail. |
| `prefer_optimistic_updates` | Professional | INFO | Update local state immediately, sync to server in background. Waiting for server makes UI feel slow. |
| `require_conflict_resolution_strategy` | Professional | WARNING | Offline edits that conflict with server need resolution: last-write-wins, merge, or user prompt. Define strategy upfront. |
| `avoid_sync_on_every_change` | Professional | WARNING | Syncing each keystroke wastes battery and bandwidth. Batch changes and sync on intervals or app background. |
| `require_pending_changes_indicator` | Recommended | INFO | Users should see when local changes haven't synced. Show "Saving..." or pending count to set expectations. |
| `prefer_background_sync` | Professional | INFO | Use WorkManager (Android) or BGTaskScheduler (iOS) to sync when app is backgrounded, not just when open. |
| `require_sync_error_recovery` | Essential | WARNING | Failed syncs must retry with exponential backoff. Unrecoverable errors should notify user, not silently lose data. |
| `avoid_full_sync_on_every_launch` | Professional | WARNING | Downloading entire dataset on launch is slow and expensive. Use delta sync with timestamps or change feeds. |

### 1.14 Background Processing Rules

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| `require_workmanager_for_background` | Essential | WARNING | Dart isolates die when app backgrounds. Use workmanager package for reliable background tasks on Android/iOS. |
| `avoid_long_running_isolates` | Professional | WARNING | iOS kills background tasks after ~30 seconds. Design tasks to be short or use background fetch appropriately. |
| `require_notification_for_long_tasks` | Recommended | INFO | Long operations (uploads, processing) should show progress notification. Silent background work gets killed by OS. |
| `prefer_foreground_service_android` | Professional | INFO | Android kills background services aggressively. Use foreground service with notification for ongoing work. |
| `avoid_compute_for_quick_tasks` | Recommended | INFO | compute() has overhead for spawning isolate. For tasks under 10ms, just run on main isolate. |
| `require_isolate_error_handling` | Essential | WARNING | Errors in isolates don't propagate to main. Set up error port or use compute() which handles errors properly. |

### 1.15 Push Notification Rules

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| `require_notification_permission_request` | Essential | ERROR | iOS and Android 13+ require explicit notification permission. Request before sending; denied = no notifications ever. |
| `prefer_delayed_permission_prompt` | Recommended | INFO | Don't ask for notification permission on first launch. Wait until user sees value, then explain why before asking. |
| `require_fcm_token_refresh_handler` | Essential | WARNING | FCM tokens can change. Listen to onTokenRefresh and update server. Stale tokens mean undelivered notifications. |
| `avoid_notification_payload_sensitive` | Essential | ERROR | Push payloads may be logged or visible in notification center. Never include passwords, full messages, or tokens. |
| `require_background_message_handler` | Essential | WARNING | FCM background messages need top-level handler function. Instance methods don't work when app is killed. |
| `prefer_local_notification_for_immediate` | Recommended | INFO | flutter_local_notifications is better for app-generated notifications. FCM is for server-triggered messages. |
| `require_notification_channel_android` | Essential | ERROR | Android 8+ requires notification channels. Define channels with appropriate importance level for different notification types. |
| `avoid_notification_spam` | Recommended | WARNING | Too many notifications cause users to disable all notifications or uninstall. Batch, dedupe, and respect user preferences. |

### 1.16 Payment & In-App Purchase Rules

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| `require_purchase_verification` | Essential | ERROR | Verify purchases server-side with Apple/Google receipts. Client-side verification can be bypassed by attackers. |
| `prefer_revenue_cat` | Professional | INFO | In-app purchases are complex (subscriptions, restores, receipt validation). RevenueCat handles cross-platform edge cases. |
| `require_purchase_restoration` | Essential | ERROR | App Store requires "Restore Purchases" button for non-consumables and subscriptions. Users switching devices need it. |
| `avoid_purchase_in_sandbox_production` | Essential | ERROR | Sandbox purchases in production or vice versa fail validation. Use correct environment configuration. |
| `require_subscription_status_check` | Essential | WARNING | Subscriptions can be cancelled, refunded, or expired. Check status on app launch, not just after purchase. |
| `prefer_grace_period_handling` | Professional | INFO | Users with expired cards get billing grace period. Handle "grace period" status to avoid locking out paying customers. |
| `require_price_localization` | Recommended | INFO | Show prices from store (with currency) not hardcoded. $4.99 in US might be €5.49 in EU. Use productDetails.price. |
| `avoid_entitlement_without_server` | Professional | WARNING | Client-side entitlement checks can be bypassed. Verify subscription status server-side for valuable content. |

### 1.17 Maps & Location Rules

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| `require_location_permission_rationale` | Essential | WARNING | Explain why you need location before requesting. "Weather app needs location for local forecast." Improves grant rate. |
| `prefer_coarse_location_when_sufficient` | Recommended | INFO | Precise location isn't always needed. City-level (coarse) location uses less battery and feels less invasive. |
| `avoid_continuous_location_updates` | Professional | WARNING | GPS polling drains battery fast. Use significant location changes or geofencing when you don't need real-time updates. |
| `require_location_timeout` | Essential | WARNING | Location requests can hang indefinitely on airplane mode. Set timeout and handle failure gracefully. |
| `prefer_geocoding_cache` | Professional | INFO | Reverse geocoding (coords to address) costs API calls. Cache results; coordinates rarely change for same address. |
| `avoid_map_markers_in_build` | Professional | WARNING | Creating map markers in build() causes flicker and performance issues. Cache marker instances and update selectively. |
| `require_map_idle_callback` | Professional | INFO | Fetching data for visible map region should wait for onCameraIdle, not onCameraMove. Move fires continuously while panning. |
| `prefer_marker_clustering` | Professional | INFO | Thousands of markers crash or slow the map. Use clustering to group nearby markers at low zoom levels. |

### 1.18 Camera & Media Rules

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| `require_camera_permission_check` | Essential | ERROR | Camera access without permission crashes on iOS, throws on Android. Check and request permission before initializing. |
| `prefer_camera_resolution_selection` | Recommended | INFO | Max resolution isn't always best. Profile photos don't need 4K. Select resolution appropriate for use case to save storage. |
| `require_camera_dispose` | Essential | ERROR | CameraController must be disposed. Undisposed camera keeps hardware locked, preventing other apps from using camera. |
| `avoid_image_picker_without_source` | Essential | WARNING | ImagePicker without specifying source shows confusing blank picker on some devices. Always specify camera or gallery. |
| `require_image_compression` | Recommended | WARNING | Phone cameras produce 5-20MB images. Compress before upload (quality 70-85% is usually indistinguishable) to save bandwidth. |
| `prefer_image_cropping` | Recommended | INFO | Profile photos should be cropped to square. Offer cropping UI after selection rather than forcing users to pre-crop. |
| `avoid_loading_full_images_in_memory` | Essential | WARNING | Loading multiple full-resolution images causes OOM. Use ResizeImage or cacheWidth/cacheHeight for display. |
| `require_exif_handling` | Professional | INFO | Image orientation is in EXIF metadata. Failure to read EXIF results in sideways or upside-down images on some devices. |

### 1.19 Theming & Dark Mode Rules

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| `require_theme_color_from_scheme` | Recommended | INFO | Hardcoded Colors ignore theme. Use Theme.of(context).colorScheme.primary etc. for colors that adapt to light/dark mode. |
| `prefer_color_scheme_from_seed` | Recommended | INFO | ColorScheme.fromSeed generates harmonious palette from single color. Easier than defining all scheme colors manually. |
| `avoid_brightness_check_for_theme` | Recommended | WARNING | Don't check brightness to pick colors. Use colorScheme which already provides appropriate colors for current theme. |
| `require_dark_mode_testing` | Essential | WARNING | Many apps look broken in dark mode (black text on black background). Test both modes; don't just invert colors. |
| `prefer_system_theme_default` | Recommended | INFO | Default to ThemeMode.system to respect user's OS preference. Offer manual override in settings. |
| `avoid_elevation_opacity_in_dark` | Professional | INFO | Dark mode uses surface tints instead of shadows for elevation. Material 3 handles this; Material 2 needs manual handling. |
| `require_semantic_colors` | Professional | INFO | Name colors by purpose (errorColor, successColor) not appearance (redColor). Purposes stay constant; appearances change with theme. |
| `prefer_theme_extensions` | Professional | INFO | Custom colors beyond ColorScheme should use ThemeExtension for proper inheritance and type safety. |

### 1.20 Responsive & Adaptive Design Rules

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| `require_responsive_breakpoints` | Recommended | INFO | Define consistent breakpoints (compact <600, medium 600-840, expanded >840). Ad-hoc checks create inconsistent layouts. |
| `prefer_layout_builder_over_media_query` | Professional | INFO | LayoutBuilder gives widget's actual constraints. MediaQuery gives screen size, which may differ in split view or dialogs. |
| `avoid_fixed_dimensions` | Recommended | WARNING | Fixed pixel widths break on different screens. Use Flexible, Expanded, FractionallySizedBox, or constraints. |
| `require_orientation_handling` | Recommended | INFO | Many apps break in landscape. Either support it properly with different layouts, or lock to portrait explicitly. |
| `prefer_master_detail_for_large` | Professional | INFO | On tablets, list-detail flows should show both panes (master-detail) rather than stacked navigation. |
| `avoid_text_overflow_on_small` | Essential | WARNING | Long text must handle small screens. Use maxLines with overflow, or Flexible to allow wrapping. |
| `require_safe_area_handling` | Essential | WARNING | Notches, home indicators, and rounded corners clip content. Use SafeArea or MediaQuery.padding appropriately. |
| `prefer_adaptive_icons` | Recommended | INFO | Icons at 24px default are too small on tablets, too large on watches. Use IconTheme or scale based on screen size. |
| `avoid_keyboard_overlap` | Essential | WARNING | Soft keyboard covers bottom content. Use SingleChildScrollView or adjust padding with MediaQuery.viewInsets.bottom. |
| `require_foldable_awareness` | Comprehensive | INFO | Foldable devices have hinges and multiple displays. Use DisplayFeature API to avoid placing content on fold. |

---

## Part 2: Tier Assignments

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

## Part 3: Technical Debt & Improvements

### 3.0 SaropaLintRule Base Class Enhancements

The `SaropaLintRule` base class provides enhanced features for all lint rules.

#### Planned Enhancements

| Feature | Priority | Description |
|---------|----------|-------------|
| **Diagnostic Statistics** | Medium | Track hit counts per rule for metrics/reporting |
| **Related Rules** | Low | Link related rules together, suggest complementary rules |
| **Suppression Tracking** | High | Audit trail of suppressed lints for tech debt tracking |
| **Batch Deduplication** | Low | Prevent duplicate reports at same offset |
| **Custom Ignore Prefixes** | Low | Support `// saropa-ignore:`, `// tech-debt:` prefixes |
| **Performance Tracking** | Medium | Measure rule execution time for optimization |
| **Tier-Based Filtering** | Medium | Enable/disable rules by tier at runtime |

##### 3.0.1 Diagnostic Statistics

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

##### 3.0.2 Related Rules

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

##### 3.0.3 Suppression Tracking

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

##### 3.0.4 Batch Deduplication

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

##### 3.0.5 Custom Ignore Prefixes

Support project-specific ignore comment styles:

```dart
// All of these would suppress the lint:
// ignore: avoid_print
// saropa-ignore: avoid_print
// tech-debt: avoid_print (tracked separately for auditing)
```

##### 3.0.6 Performance Tracking

Measure rule execution time to identify slow rules:

```dart
abstract class SaropaLintRule extends DartLintRule {
  static final Map<String, Duration> executionTimes = {};

  // Output report:
  // avoid_excessive_widget_depth: 2.3s (needs optimization!)
  // require_dispose: 0.1s
}
```

##### 3.0.7 Tier-Based Filtering

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

## Part 4: Modern Dart & Flutter Language Features

This section tracks new Dart/Flutter language features that developers should learn, and corresponding lint rules to help adopt them.

### 4.1 Dart Language Features

| Version | Date | Feature | Description | Lint Rule |
|---------|------|---------|-------------|-----------|
| 3.10 | Nov 2025 | Dot Shorthands | Write `.center` instead of `MainAxisAlignment.center` | `prefer_dot_shorthand` |
| 3.10 | Nov 2025 | Specific Deprecation Annotations | Finer-grained deprecation control | `use_specific_deprecation` |
| 3.9 | Aug 2025 | Improved Type Promotion | Null safety assumed for type promotion/reachability | `avoid_redundant_null_check` |
| 3.8 | May 2025 | Null-Aware Elements | `?item` in collections - include only if non-null | `prefer_null_aware_elements` |
| 3.5 | Aug 2024 | Web Interop APIs (Stable) | `dart:js_interop` at 1.0 | `prefer_js_interop_over_dart_js` |
| 3.3 | Feb 2024 | Extension Types | Zero-cost wrappers for types | `prefer_extension_type_for_wrapper` |
| 3.0 | May 2023 | Records | Tuple-like data: `(String, int)` | `prefer_record_over_tuple_class` |
| 3.0 | May 2023 | Sealed Classes | Exhaustive type hierarchies | `prefer_sealed_for_state` |
| 3.0 | May 2023 | Switch Expressions | Expression-based switching | `prefer_switch_expression` |

**Not lintable:** Some Dart features are tooling/infrastructure changes:
- **Analyzer Plugin System** (3.10) — Official plugin architecture. Saropa Lints may migrate from custom_lint in future, but new system doesn't support assists yet. See [migration guide](https://leancode.co/blog/migrating-to-dart-analyzer-plugin-system).
- **JNIgen** (3.5) — Code generator for Java/Kotlin interop. Generates bindings, doesn't produce patterns needing lint rules.
- **Sound Null Safety Only** (3.9) — `--no-sound-null-safety` flag removed. No code patterns to lint.
- **Auto Trailing Commas** (3.8) — Formatter handles commas automatically.
- **Tall Style Formatter** (3.7) — New vertical formatting style.
- **Pub Workspaces** (3.6) — Monorepo support, tooling feature.

---

### 4.2 Flutter Widget Features

| Version | Date | Feature | Description | Lint Rule |
|---------|------|---------|-------------|-----------|
| 3.38 | Nov 2025 | OverlayPortal.overlayChildLayoutBuilder | Render overlays outside parent constraints | `prefer_overlay_portal_layout_builder` |
| 3.27 | Dec 2024 | Cupertino widget updates | CupertinoCheckbox, CupertinoRadio | Cupertino rules |

**Not lintable:** Some Flutter features cannot be detected through static analysis:
- **Impeller** (3.24-3.27) — Runtime rendering engine with no Dart code patterns to analyze
- **Swift Package Manager** (3.24) — Native iOS build tooling, outside Dart static analysis scope
- **WebAssembly support** (3.22) — Compilation target, not detectable code patterns

---

### 4.3 Modern Dart Rules Summary

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
