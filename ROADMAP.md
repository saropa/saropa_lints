# Roadmap: 1000 Lint Rules
<!-- cspell:disable -->
## Current Status

See [CHANGELOG.md](https://github.com/saropa/saropa_lints/blob/main/CHANGELOG.md) for implemented rules. Goal: 1000 rules.

## Moved to Implementation (57 rules)

The following rules have been added to `tiers.dart` and are tracked in [roadmap_up_next.md](roadmap_up_next.md). Rules marked with (alias) map to existing implementations.

### Disposal Rules
- `require_scroll_controller_dispose` - Essential
- `require_focus_node_dispose` - Essential
- `require_animation_controller_dispose` → (alias: `require_animation_disposal`)
- `require_stream_subscription_cancel` → (alias: `avoid_unassigned_stream_subscriptions`)
- `require_timer_cancel` → (alias: `require_timer_cancellation`)
- `require_text_editing_controller_dispose` - Essential
- `require_page_controller_dispose` - Essential
- `require_tab_controller_dispose` - Essential
- `require_video_player_controller_dispose` → (alias: `require_media_player_dispose`)
- `avoid_websocket_memory_leak` - Essential (NEW)

### Widget/Image Rules
- `require_image_error_fallback` → (alias: `require_image_error_builder`)
- `require_image_loading_placeholder` - Recommended (NEW)
- `prefer_cached_network_image` - Recommended
- `prefer_image_size_constraints` - DEFERRED (heuristic)
- `prefer_action_button_tooltip` → (alias: `avoid_icon_buttons_without_tooltip`)
- `require_avatar_fallback` - Recommended
- `require_avatar_alt_text` - Recommended
- `prefer_video_loading_placeholder` - DEFERRED (heuristic)
- `require_media_loading_state` - DEFERRED (state analysis)
- `require_pdf_loading_indicator` - DEFERRED (package-specific)
- `require_pdf_error_handling` - Recommended (NEW)
- `require_qr_scan_feedback` - Recommended
- `prefer_clipboard_feedback` - DEFERRED (cross-method)
- `require_keyboard_action_type` - DEFERRED (Form detection)
- `require_keyboard_dismiss_on_scroll` - DEFERRED (Form detection)

### Async/Context Rules
- `avoid_dialog_context_after_async` → (alias: `avoid_context_after_navigation`)
- `check_mounted_after_async` → (alias: `require_mounted_check`)
- `require_graphql_error_handling` - Essential (NEW)
- `require_websocket_message_validation` - DEFERRED (vague)
- `require_feature_flag_default` - DEFERRED (package-specific)
- `prefer_utc_for_storage` - DEFERRED (heuristic)
- `require_file_exists_check` - Recommended
- `require_location_timeout` - Essential (NEW)

### Firebase/Maps Rules
- `prefer_firestore_batch_write` - Professional (NEW)
- `avoid_firestore_in_widget_build` → (alias: `avoid_database_in_build`)
- `prefer_firebase_remote_config_defaults` - DEFERRED (cross-file)
- `require_fcm_token_refresh_handler` - DEFERRED (class-level)
- `require_background_message_handler` - DEFERRED (cross-file)
- `avoid_bluetooth_scan_without_timeout` - Recommended
- `require_bluetooth_state_check` - Recommended
- `require_ble_disconnect_handling` - Recommended
- `require_graphql_operation_names` - Recommended
- `avoid_map_markers_in_build` - DEFERRED (package-specific)
- `require_map_idle_callback` - DEFERRED (package-specific)
- `prefer_marker_clustering` - DEFERRED (heuristic)

### Accessibility Rules
- `require_image_description` → (alias: `require_image_semantics`)
- `avoid_semantics_exclusion` - DEFERRED (comment detection)
- `prefer_merge_semantics` - DEFERRED (sibling detection)
- `require_focus_indicator` - DEFERRED (runtime)
- `avoid_flashing_content` - DEFERRED (timing analysis)
- `require_badge_semantics` - Recommended
- `avoid_badge_without_meaning` - Professional
- `require_badge_count_limit` - Recommended (NEW)
- `prefer_adequate_spacing` - DEFERRED (layout calc)
- `avoid_motion_without_reduce` - Recommended (NEW)

### Navigation/Dialog Rules
- `require_deep_link_fallback` - DEFERRED (package-specific)
- `avoid_deep_link_sensitive_params` - DEFERRED (heuristic)
- `prefer_typed_route_params` - DEFERRED (package-specific)
- `require_dialog_result_handling` - Professional
- `avoid_snackbar_queue_buildup` - Professional
- `require_stepper_validation` - DEFERRED (validation detection)
- `require_step_count_indicator` - DEFERRED (too abstract)
- `require_refresh_indicator_on_lists` - Recommended (NEW)

### Animation Rules
- `prefer_tween_sequence` - DEFERRED (detection unclear)
- `require_animation_status_listener` - Professional (NEW)
- `avoid_overlapping_animations` - DEFERRED (cross-context)
- `avoid_animation_rebuild_waste` - DEFERRED (heuristic)
- `prefer_physics_simulation` - DEFERRED (package-specific)

### Platform Rules
- `avoid_platform_channel_on_web` - DEFERRED (cross-file)
- `require_cors_handling` - REMOVED (server-side)
- `prefer_deferred_loading_web` - DEFERRED (import size unknown)
- `require_menu_bar_for_desktop` - DEFERRED (cross-file)
- `avoid_touch_only_gestures` - Professional (NEW)
- `require_window_close_confirmation` - DEFERRED (cross-file)
- `prefer_native_file_dialogs` - DEFERRED (detection unclear)

### Testing Rules
- `avoid_real_dependencies` → (alias: `avoid_real_network_calls_in_tests`)
- `require_test_cleanup` - Professional (NEW)
- `prefer_test_variant` - DEFERRED (too abstract)
- `require_accessibility_tests` - Professional (NEW)
- `require_animation_tests` - DEFERRED (cross-file)

## Implementation Difficulty Warning

> **Not all rules are created equal.** Rules that appear simple often require multiple revisions due to false positives from heuristic-based detection.

### Truly Easy Rules (low false-positive risk)
- Match **exact API/method names**: `jsonDecode()`, `DateTime.parse()`
- Check **specific named parameters**: `shrinkWrap: true`, `autoPlay: true`
- Detect **missing required parameters**: `Image.network` without `errorBuilder`
- Match **constructor + dispose pattern**: `ScrollController` without `dispose()`

### Deceptively Hard Rules (high false-positive risk)
- **Variable name heuristics**: `money`, `price`, `token` → matches `audioVolume`, `cadence`, `tokenizer`
- **Generic terms**: `cost`, `fee`, `balance` have many non-target meanings
- **Short abbreviations**: `iv` matches `activity`, `private`, `derivative`
- **String content analysis**: Must distinguish `$password` from `${password.length}`

**See [CONTRIBUTING.md](CONTRIBUTING.md#avoiding-false-positives-critical)** for detailed guidance on avoiding false positives.

### Risk Legend (used in rule descriptions below)

| Marker | Meaning | Example Pattern |
|--------|---------|-----------------|
| — | Safe: Exact API/parameter matching | `Image.network` without `errorBuilder` |
| `[CONTEXT]` | Needs build/test context detection | Detect if inside `build()` method |
| `[HEURISTIC]` | Variable name or string pattern matching | Detect "money" in variable names |
| `[CROSS-FILE]` | Requires analysis across multiple files | Check if type is registered elsewhere |
| `[TOO-COMPLEX]` | Pattern too abstract for reliable AST detection | Detect "loading state" or "user feedback" generically |

## Part 1: Detailed Rule Specifications

### 1.1 Widget Rules

#### Layout & Composition

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| `require_overflow_box_rationale` | Comprehensive | INFO | `[HEURISTIC]` OverflowBox allows children to overflow parent bounds, which can cause visual glitches. Require a comment explaining why overflow is intentional. |
| `prefer_custom_single_child_layout` | Insanity | INFO | For complex single-child positioning logic, CustomSingleChildLayout is more efficient than nested Positioned/Align/Transform widgets. |

#### Text & Typography

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| `require_locale_for_text` | Professional | INFO | Some text operations (date formatting, number formatting, sorting) produce incorrect results without explicit Locale. |

### 1.2 State Management

#### Riverpod Rules

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| `require_riverpod_override_in_tests` | Professional | INFO | `[CROSS-FILE]` Tests using real providers have hidden dependencies and unpredictable state. Override providers with mocks for isolated, deterministic tests. |
| `require_async_value_order` | Recommended | WARNING | AsyncValue pattern matching order matters - check for values before errors, handle loading last. Wrong order causes incorrect behavior. |
| `avoid_riverpod_navigation` | Recommended | INFO | Riverpod shouldn't handle navigation via global navigator keys. Navigation belongs in widgets, not state management. |
| `require_flutter_riverpod_package` | Essential | ERROR | Using `riverpod` instead of `flutter_riverpod` in Flutter apps - ConsumerWidget and ref.watch() won't work without the Flutter bindings. |
| `avoid_riverpod_for_network_only` | Professional | INFO | `[HEURISTIC]` Using Riverpod just to access network layer when direct injection would suffice adds unnecessary complexity. |

#### Bloc/Cubit Rules

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| `avoid_yield_in_on_event` | Professional | WARNING | The `yield` keyword is deprecated in bloc event handlers. Use `emit()` instead for emitting new states. |
| `require_bloc_test_coverage` | Professional | INFO | `[CROSS-FILE]` Blocs should have tests covering all state transitions. Untested state machines have hidden bugs in edge cases. |
| `require_bloc_selector` | Recommended | INFO | Not using BlocSelector leads to unnecessary rebuilds. BlocBuilder rebuilds on any state change even if irrelevant. |
| `avoid_large_bloc` | Professional | INFO | `[HEURISTIC]` Blocs handling too many responsibilities become hard to maintain. Keep Blocs focused on single domain. |
| `avoid_overengineered_bloc_states` | Professional | INFO | `[HEURISTIC]` Separate states for "loading" and "idle" when a boolean would suffice. Simpler state machines are easier to reason about. |
| `require_bloc_manual_dispose` | Essential | WARNING | Even though Bloc handles cleanup, manually created controllers or streams inside a Bloc must still be disposed in close(). |
| `prefer_feature_folder_structure` | Comprehensive | INFO | `[HEURISTIC]` Group files by feature (/auth, /profile) instead of type (/bloc, /ui) for better scalability. |

#### Provider Rules

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| `prefer_consumer_over_provider_of` | Recommended | INFO | Consumer widget limits rebuilds to its subtree. `Provider.of` in build() rebuilds the entire widget even when only part needs the value. |
| `prefer_selector` | Professional | INFO | Selector rebuilds only when the selected value changes. Watching the whole object rebuilds on any field change, wasting CPU cycles. |
| `prefer_proxy_provider` | Comprehensive | INFO | When a provider depends on another provider, use ProxyProvider to automatically update when dependencies change. |
| `require_update_callback` | Comprehensive | INFO | ProxyProvider's `update` callback runs on dependency changes. Without explicit handling, stale closures or missing updates cause bugs. |
| `avoid_listen_in_async` | Essential | WARNING | `context.watch()` in async callbacks uses stale context. Use `context.read()` to get values once without subscribing to changes. |

#### GetX Rules

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| `prefer_getx_builder` | Recommended | INFO | Direct `.obs` access in build() doesn't trigger rebuilds. Use GetX, GetBuilder, or Obx widgets to properly subscribe to reactive values. |
| `require_getx_binding` | Professional | INFO | Bindings ensure controllers are created and disposed at the right time. Without them, manual Get.put/delete calls are error-prone. |
| `avoid_getx_context_outside_widget` | Essential | WARNING | GetX relies on context for navigation, dialogs, etc. Accessing context outside widgets (in services/utilities) causes runtime errors. |
| `avoid_getx_static_context` | Professional | WARNING | `[HEURISTIC]` Get.offNamed and Get.dialog use static context internally - cannot be unit tested. Consider abstraction for testability. |
| `avoid_tight_coupling_with_getx` | Professional | INFO | `[HEURISTIC]` Using GetX for everything leads to tight coupling and hard-to-test code. Use only necessary features. |

### 1.3 Performance Rules

#### Build Optimization

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| `avoid_rebuild_on_scroll` | Essential | WARNING | `[CONTEXT]` ScrollController listeners or NotificationListener in build() trigger rebuilds on every scroll pixel, causing jank. Move scroll handling to StatefulWidget. |
| `prefer_inherited_widget_cache` | Professional | INFO | Repeated InheritedWidget lookups (`.of(context)`) traverse the tree each time. Cache the result in a local variable when used multiple times. |
| `require_should_rebuild` | Professional | INFO | Custom InheritedWidgets should override `updateShouldNotify` to return false when the value hasn't meaningfully changed. |
| `prefer_element_rebuild` | Comprehensive | INFO | Returning the same widget type with same key reuses Elements. Changing widget types or keys destroys Elements, losing state and causing expensive rebuilds. |
| `prefer_selector_over_consumer` | Professional | INFO | Selector rebuilds only when selected value changes. Consumer rebuilds on any provider change, even fields you don't use. |

#### Memory Optimization

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| `require_isolate_for_heavy` | Professional | WARNING | Heavy computation on main isolate blocks UI (16ms budget per frame). Use `compute()` or `Isolate.run()` for JSON parsing, image processing, or data transforms. |
| `avoid_finalizer_misuse` | Comprehensive | INFO | Dart Finalizers run non-deterministically and add GC overhead. Prefer explicit dispose() methods. Finalizers are only for native resource cleanup as a safety net. |
| `prefer_pool_pattern` | Comprehensive | INFO | Frequently created/destroyed objects cause GC churn. Object pools reuse instances (e.g., for particles, bullet hell games, or recyclable list items). |
| `require_expando_cleanup` | Comprehensive | INFO | Expando attaches data to objects without modifying them. Entries persist until the key object is GC'd. Remove entries explicitly when done. |
| `prefer_iterable_operations` | Professional | INFO | `.map()`, `.where()` return lazy iterables. Using `.toList()` unnecessarily allocates memory. Keep operations lazy until you need a concrete list. |

#### Network Performance

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| `require_compression` | Comprehensive | INFO | Large JSON/text responses should use gzip compression. Reduces bandwidth 60-80% for typical API responses. |
| `prefer_batch_requests` | Professional | INFO | Multiple small requests have more overhead than one batched request. Combine related queries when the API supports it. |
| `avoid_blocking_main_thread` | Essential | WARNING | Network I/O on main thread blocks UI during DNS/TLS. While Dart's http is async, large response processing should use isolates. |
| `avoid_json_in_main` | Professional | INFO | `[HEURISTIC]` `jsonDecode()` for large payloads (>100KB) blocks the main thread. Use `compute()` to parse JSON in a background isolate. |
| `prefer_binary_format` | Comprehensive | INFO | Protocol Buffers or MessagePack are smaller and faster to parse than JSON. Consider for high-frequency or large-payload APIs. |
| `require_network_status_check` | Recommended | INFO | Check connectivity before making requests that will obviously fail. Show appropriate offline UI instead of timeout errors. |

### 1.4 Testing Rules

#### Unit Testing

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| `avoid_real_dependencies` | Essential | WARNING | Tests hitting real databases, APIs, or file systems are slow, flaky, and can corrupt data. Mock external dependencies. |

#### Widget Testing

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| `prefer_test_variant` | Comprehensive | INFO | Testing multiple screen sizes or themes? Use `testWidgets` with `variant: ValueVariant({...})` instead of duplicating tests. |
| `require_accessibility_tests` | Recommended | WARNING | Use `meetsGuideline(textContrastGuideline)` and `meetsGuideline(androidTapTargetGuideline)` to verify accessibility compliance. |
| `require_dialog_tests` | Recommended | INFO | Dialogs require special handling: tap to open, find within dialog context, test dismiss behavior. Don't forget barrier dismiss tests. |
| `prefer_fake_platform` | Comprehensive | INFO | Platform channels (camera, GPS, storage) need fakes in tests. Use `TestDefaultBinaryMessengerBinding` to mock platform responses. |
| `require_animation_tests` | Comprehensive | INFO | Animations should be tested for start/end states and interruption. Use `pump(duration)` to advance to specific points. |

#### Integration Testing

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| `require_test_ordering` | Professional | INFO | Integration tests may depend on database state from previous tests. Document dependencies or use `setUp` to ensure required state. |
| `prefer_retry_flaky` | Comprehensive | INFO | Integration tests on real devices are inherently flaky. Configure retry count in CI (e.g., `--retry=2`) rather than deleting useful tests. |
| `require_test_cleanup` | Professional | INFO | Tests that create files, database entries, or user accounts must clean up in `tearDown`. Leftover data causes subsequent test failures. |
| `prefer_test_data_reset` | Professional | INFO | Each test should start with known state. Reset database, clear shared preferences, and log out users in setUp to prevent test pollution. |
| `require_e2e_coverage` | Professional | INFO | `[CROSS-FILE]` Integration tests are expensive. Focus on critical user journeys: signup, purchase, core features. Don't duplicate unit test coverage. |
| `avoid_screenshot_in_ci` | Comprehensive | INFO | Screenshots in CI consume storage and slow tests. Take screenshots only on failure for debugging, not on every test. |
| `prefer_test_report` | Comprehensive | INFO | Generate JUnit XML or JSON reports for CI dashboards. Raw console output is hard to track over time. |
| `require_performance_test` | Professional | INFO | Measure frame rendering time and startup latency in integration tests. Catch performance regressions before they reach production. |
| `avoid_test_on_real_device` | Recommended | INFO | Real devices vary in performance and state. Use emulators/simulators in CI for consistent, reproducible results. |
| `prefer_parallel_tests` | Comprehensive | INFO | Independent integration tests can run in parallel with `--concurrency`. Reduces total CI time significantly for large test suites. |
| `require_test_documentation` | Comprehensive | INFO | `[HEURISTIC]` Complex integration tests with unusual setup or assertions need comments explaining the test scenario and why it matters. |

### 1.5 Security Rules

#### Authentication & Authorization

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| `prefer_oauth_pkce` | Professional | INFO | Mobile OAuth without PKCE is vulnerable to authorization code interception. Use PKCE (Proof Key for Code Exchange) for secure OAuth flows. |
| `require_session_timeout` | Professional | INFO | Sessions without timeout remain valid forever if tokens are stolen. Implement idle timeout and absolute session limits. |
| `prefer_deep_link_auth` | Professional | INFO | Deep links with auth tokens (password reset, magic links) must validate tokens server-side and expire quickly. |
| `avoid_remember_me_insecure` | Recommended | WARNING | "Remember me" storing unencrypted credentials is a security risk. Use refresh tokens with proper rotation and revocation. |
| `require_multi_factor` | Comprehensive | INFO | Sensitive operations (payments, account changes) should offer or require multi-factor authentication for additional security. |

#### Data Protection

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| `require_keychain_access` | Professional | INFO | iOS Keychain requires proper access groups and entitlements. Incorrect configuration causes data loss on app reinstall. |
| `prefer_local_auth` | Professional | INFO | Sensitive operations (viewing saved passwords, confirming payments) should require biometric or PIN re-authentication. |
| `avoid_external_storage_sensitive` | Essential | ERROR | Android external storage (SD card) is world-readable. Never store sensitive data there - use app-private internal storage. |
| `require_backup_exclusion` | Professional | INFO | Sensitive data should be excluded from iCloud/Google backups. Backups are often less protected than the device. |
| `prefer_root_detection` | Professional | INFO | Rooted/jailbroken devices bypass security controls. Detect and warn users, or disable sensitive features on compromised devices. |

#### Input Validation & Injection

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| `require_url_validation` | Essential | WARNING | URLs from user input can point to malicious sites or internal resources. Validate scheme (https only) and domain against allowlist. |
| `prefer_regex_validation` | Recommended | INFO | Format validation (email, phone, postal code) should use regex patterns. String checks like `.contains('@')` miss invalid formats. |
| `require_json_schema_validation` | Professional | INFO | API responses should be validated against expected schema. Malformed responses can crash the app or cause unexpected behavior. |
| `prefer_whitelist_validation` | Professional | INFO | Validate input against known-good values (allowlist) rather than blocking known-bad values (blocklist). Blocklists miss novel attacks. |
| `avoid_redirect_injection` | Essential | WARNING | Redirect URLs from user input enable phishing. Validate redirect targets are on your domain or an explicit allowlist. |
| `require_content_type_check` | Professional | INFO | Verify response Content-Type before parsing. A JSON endpoint returning HTML could indicate an attack or misconfiguration. |
| `prefer_csrf_protection` | Professional | WARNING | State-changing requests need CSRF tokens. Without protection, malicious sites can trigger actions on behalf of logged-in users. |
| `prefer_intent_filter_export` | Professional | INFO | Android intent filters should be exported only when necessary. Unexported components can't be invoked by malicious apps. |

### 1.6 Accessibility Rules

#### Screen Reader Support

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| `require_image_description` | Essential | WARNING | Decorative images need `excludeFromSemantics: true`. Meaningful images need `semanticLabel` describing their content. |
| `avoid_semantics_exclusion` | Recommended | WARNING | `excludeFromSemantics` hides content from screen readers. Only use for truly decorative elements, with a comment explaining why. |
| `prefer_merge_semantics` | Professional | INFO | Related elements (icon + text) should be wrapped in MergeSemantics so screen readers announce them as one unit. |
| `avoid_redundant_semantics` | Comprehensive | INFO | An Image with semanticLabel inside a Semantics wrapper announces twice. Remove duplicate semantic information. |
| `prefer_semantics_container` | Professional | INFO | Groups of related widgets should use Semantics `container: true` to indicate they form a logical unit for navigation. |
| `prefer_semantics_sort` | Professional | INFO | Complex layouts may need `sortKey` to control screen reader navigation order. Default order may not match visual layout. |
| `avoid_semantics_in_animation` | Comprehensive | INFO | Semantics should not change during animations. Screen readers get confused by rapidly changing semantic trees. |
| `prefer_announce_for_changes` | Comprehensive | INFO | Important state changes should use `SemanticsService.announce()` to inform screen reader users of non-visual feedback. |

#### Visual Accessibility

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| `avoid_color_only_meaning` | Essential | WARNING | Never use color alone to convey information (red=error). Add icons, text, or patterns for colorblind users. |
| `require_focus_indicator` | Recommended | WARNING | Keyboard/switch users need visible focus indicators. Ensure focused elements have distinct borders or highlights. |
| `prefer_high_contrast_mode` | Professional | INFO | Support MediaQuery.highContrast for users who need stark color differences. Provide high-contrast theme variant. |
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

### 1.7 Animation Rules

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| `prefer_tween_sequence` | Professional | INFO | Complex multi-stage animations should use TweenSequence rather than chaining multiple controllers or delayed futures. |
| `require_animation_status_listener` | Professional | INFO | One-shot animations need StatusListener to know when complete. Without it, you can't trigger follow-up actions reliably. |
| `avoid_overlapping_animations` | Professional | WARNING | Multiple animations on same property conflict. Use AnimationController.stop() before starting new animation on same widget. |
| `prefer_physics_simulation` | Comprehensive | INFO | SpringSimulation and FrictionSimulation create more natural feel than fixed curves for drag-release and momentum scrolling. |
| `avoid_animation_rebuild_waste` | Professional | WARNING | AnimatedBuilder should wrap only the animating subtree. Wrapping entire screen rebuilds everything 60fps. |

### 1.8 Navigation & Routing Rules

#### Navigator & GoRouter

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| `avoid_nested_navigators_misuse` | Professional | WARNING | Nested Navigators (tabs with own stacks) need careful WillPopScope handling. Back button behavior confuses users when done wrong. |
| `require_deep_link_testing` | Professional | INFO | Every route should be testable via deep link. Routes only reachable through navigation chains break when users share links. |
| `prefer_go_router_redirect` | Professional | INFO | Auth checks in redirect() run before build, preventing flash of protected content. Checking in build shows then redirects. |
| `prefer_typed_route_params` | Professional | INFO | Route parameters as strings require parsing and can fail silently. Use typed extras (GoRouter) or arguments with type checking. |

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
| `require_error_message_context` | Recommended | INFO | "Invalid input" is useless. Error messages should explain what's wrong and how to fix it: "Email must contain @". |
| `prefer_form_bloc_for_complex` | Professional | INFO | Forms with >5 fields, conditional logic, or multi-step flows benefit from form state management (FormBloc, Reactive Forms). |
| `prefer_input_formatters` | Professional | INFO | Phone numbers, credit cards, dates should auto-format as user types using TextInputFormatter for better UX. |

### 1.10 Database & Storage Rules

#### Local Database (Hive/Isar/Drift)

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| `avoid_blocking_database_ui` | Essential | WARNING | Database operations block UI if run on main isolate. Use compute() or database's async APIs for large queries. |
| `avoid_storing_sensitive_unencrypted` | Essential | ERROR | Hive/Isar store data as readable files. Use encrypted box or flutter_secure_storage for tokens and passwords. |
| `prefer_isar_for_complex_queries` | Comprehensive | INFO | Hive's query capabilities are limited. Isar supports complex queries, full-text search, and links between objects. |

#### SharedPreferences & Secure Storage

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| `prefer_typed_prefs_wrapper` | Professional | INFO | Raw SharedPreferences returns dynamic. Wrap in typed class with getters/setters for type safety and documentation. |

### 1.11 Platform-Specific Rules

#### iOS-Specific

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| `require_ios_permission_description` | Essential | ERROR | iOS rejects apps without Info.plist usage descriptions for camera, location, etc. Add NSCameraUsageDescription etc. |
| `avoid_http_without_ats_exception` | Essential | ERROR | iOS blocks non-HTTPS by default (App Transport Security). Add exception in Info.plist only if absolutely necessary. |
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
| `avoid_large_assets_on_web` | Recommended | WARNING | Web has no app install; assets download on demand. Lazy-load images and use appropriate formats (WebP) for faster loads. |
| `require_cors_handling` | Essential | ERROR | Web apps face CORS restrictions desktop/mobile don't have. API must send proper headers or use proxy for third-party APIs. |
| `prefer_deferred_loading_web` | Professional | INFO | Web bundle size matters for initial load. Use deferred imports to split code and load features on demand. |

#### Desktop-Specific (Windows/macOS/Linux)

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| `require_menu_bar_for_desktop` | Professional | INFO | macOS apps need menu bar. Use PlatformMenuBar for standard menus (File, Edit, View) on desktop platforms. |
| `avoid_touch_only_gestures` | Recommended | WARNING | Desktop has mouse, not touch. GestureDetector works, but also handle mouse hover, right-click, scroll wheel. |
| `require_window_close_confirmation` | Professional | INFO | Unsaved changes should prompt on window close. Handle windowShouldClose callback to prevent data loss. |
| `prefer_native_file_dialogs` | Professional | INFO | Use file_picker or file_selector for native open/save dialogs. Custom dialogs feel out of place on desktop. |

### 1.12 Firebase Rules

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| `require_firestore_index` | Essential | ERROR | Compound queries need composite indexes. Firestore throws error with link to create index; don't ignore in dev. |
| `prefer_firestore_batch_write` | Professional | INFO | Multiple writes should use batch() or transaction(). Individual writes have higher latency and cost. |
| `avoid_firestore_in_widget_build` | Essential | WARNING | StreamBuilder with Firestore query in build() creates new listener on every rebuild. Cache stream reference. |
| `prefer_firebase_auth_persistence` | Recommended | INFO | Web Firebase Auth defaults to session persistence. Set persistence to LOCAL for "remember me" functionality. |
| `avoid_storing_user_data_in_auth` | Recommended | WARNING | Firebase Auth custom claims are limited (1000 bytes). Store user profiles in Firestore, not in auth token. |
| `require_crashlytics_user_id` | Professional | INFO | Set Crashlytics userIdentifier to correlate crashes with users. Helps debug user-reported issues. |
| `prefer_firebase_remote_config_defaults` | Recommended | INFO | Remote Config returns null if fetch fails. Set in-app defaults so app works offline on first launch. |
| `require_firebase_app_check` | Professional | WARNING | Firebase App Check prevents abuse from non-app clients. Enable for production to protect backend resources. |

### 1.13 Offline-First & Sync Rules

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
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

### 1.15 Push Notification Rules

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| `prefer_delayed_permission_prompt` | Recommended | INFO | Don't ask for notification permission on first launch. Wait until user sees value, then explain why before asking. |
| `require_fcm_token_refresh_handler` | Essential | WARNING | FCM tokens can change. Listen to onTokenRefresh and update server. Stale tokens mean undelivered notifications. |
| `require_background_message_handler` | Essential | WARNING | FCM background messages need top-level handler function. Instance methods don't work when app is killed. |
| `prefer_local_notification_for_immediate` | Recommended | INFO | flutter_local_notifications is better for app-generated notifications. FCM is for server-triggered messages. |
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
| `prefer_image_cropping` | Recommended | INFO | Profile photos should be cropped to square. Offer cropping UI after selection rather than forcing users to pre-crop. |
| `require_exif_handling` | Professional | INFO | Image orientation is in EXIF metadata. Failure to read EXIF results in sideways or upside-down images on some devices. |

### 1.19 Theming & Dark Mode Rules

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| `require_dark_mode_testing` | Essential | WARNING | Many apps look broken in dark mode (black text on black background). Test both modes; don't just invert colors. |
| `avoid_elevation_opacity_in_dark` | Professional | INFO | Dark mode uses surface tints instead of shadows for elevation. Material 3 handles this; Material 2 needs manual handling. |
| `require_semantic_colors` | Professional | INFO | Name colors by purpose (errorColor, successColor) not appearance (redColor). Purposes stay constant; appearances change with theme. |
| `prefer_theme_extensions` | Professional | INFO | Custom colors beyond ColorScheme should use ThemeExtension for proper inheritance and type safety. |

### 1.20 Responsive & Adaptive Design Rules

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| `require_responsive_breakpoints` | Recommended | INFO | Define consistent breakpoints (compact <600, medium 600-840, expanded >840). Ad-hoc checks create inconsistent layouts. |
| `prefer_layout_builder_over_media_query` | Professional | INFO | LayoutBuilder gives widget's actual constraints. MediaQuery gives screen size, which may differ in split view or dialogs. |
| `require_orientation_handling` | Recommended | INFO | Many apps break in landscape. Either support it properly with different layouts, or lock to portrait explicitly. |
| `prefer_master_detail_for_large` | Professional | INFO | On tablets, list-detail flows should show both panes (master-detail) rather than stacked navigation. |
| `prefer_adaptive_icons` | Recommended | INFO | Icons at 24px default are too small on tablets, too large on watches. Use IconTheme or scale based on screen size. |
| `avoid_keyboard_overlap` | Essential | WARNING | Soft keyboard covers bottom content. Use SingleChildScrollView or adjust padding with MediaQuery.viewInsets.bottom. |
| `require_foldable_awareness` | Comprehensive | INFO | Foldable devices have hinges and multiple displays. Use DisplayFeature API to avoid placing content on fold. |

### 1.21 WebSocket & Real-time Rules

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| `require_websocket_reconnection` | Essential | WARNING | `[HEURISTIC]` WebSocket connections drop unexpectedly. Implement automatic reconnection with exponential backoff. Detection: Find `WebSocketChannel` without reconnection logic (may have false positives if reconnection is in wrapper class). |
| `avoid_websocket_without_heartbeat` | Professional | INFO | WebSockets may silently disconnect. Send periodic ping/pong to detect stale connections. |
| `require_websocket_message_validation` | Essential | WARNING | Incoming WebSocket messages can be malformed or malicious. Validate schema before processing. |
| `avoid_websocket_memory_leak` | Essential | WARNING | WebSocket subscriptions must be cancelled on dispose. Detect `WebSocketChannel` stream subscriptions without cancellation in dispose(). |

### 1.22 GraphQL Rules

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| `require_graphql_error_handling` | Essential | WARNING | GraphQL returns errors in response body, not HTTP status. Detect GraphQL response usage without checking `.errors` field. |
| `require_graphql_operation_names` | Recommended | INFO | Anonymous GraphQL operations are harder to debug in network logs. Detect query/mutation strings without operation names. |
| `avoid_graphql_string_queries` | Professional | INFO | Raw GraphQL query strings are error-prone. Prefer code-generated typed queries from schema. |

### 1.23 Audio & Video Player Rules

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| `require_audio_focus_handling` | Professional | INFO | Apps should request audio focus and respect other apps. Detect audio playback without audio session configuration. |
| `prefer_video_loading_placeholder` | Recommended | INFO | Show video thumbnail or placeholder before playing. Detect VideoPlayer without placeholder widget. |
| `avoid_audio_in_background_without_config` | Essential | ERROR | `[CROSS-FILE]` Background audio requires proper iOS/Android configuration. Detect audio playback in apps without background audio capability. |
| `require_media_loading_state` | Recommended | INFO | Video/audio players need loading indicators. Detect VideoPlayer without checking `isInitialized` before display. |

### 1.24 Bluetooth & IoT Rules

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| `require_bluetooth_state_check` | Essential | WARNING | Bluetooth operations fail if Bluetooth is off. Detect FlutterBluePlus/flutter_blue usage without adapter state check. |
| `avoid_bluetooth_scan_without_timeout` | Professional | WARNING | Bluetooth scanning drains battery. Detect `startScan()` without timeout parameter. |
| `require_ble_disconnect_handling` | Essential | WARNING | BLE devices disconnect unexpectedly. Detect device connection without disconnect state listener. |
| `prefer_ble_mtu_negotiation` | Professional | INFO | Default BLE MTU is small (23 bytes). Detect large data transfers without MTU negotiation. |

### 1.25 PDF & Document Rules

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| `avoid_loading_full_pdf_in_memory` | Essential | WARNING | Large PDFs cause OOM crashes. Detect PDF loading without streaming or pagination. |
| `require_pdf_error_handling` | Recommended | INFO | PDFs can be corrupted or password-protected. Detect PDF load operations without try-catch. |
| `require_pdf_loading_indicator` | Recommended | INFO | PDF rendering is slow. Detect PDF viewer without loading state handling. |

### 1.26 QR Code & Barcode Rules

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| `require_qr_content_validation` | Essential | WARNING | QR codes can contain malicious URLs or commands. Detect QR scan result usage without validation before navigation/execution. |
| `avoid_qr_scanner_always_active` | Professional | INFO | Camera for QR scanning drains battery. Detect QRView without pause/resume lifecycle handling. |
| `require_qr_scan_feedback` | Recommended | INFO | Provide visual/haptic feedback on successful scan. Detect QR scanner without success callback UI feedback. |
| `require_qr_permission_check` | Essential | ERROR | QR scanning requires camera permission. Detect QR scanner usage without permission request. |

### 1.27 Clipboard Rules

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| `avoid_sensitive_data_in_clipboard` | Essential | WARNING | `[HEURISTIC]` Clipboard contents are accessible to other apps. Detect `Clipboard.setData` with variables named password, token, secret, apiKey, or similar. |
| `require_clipboard_paste_validation` | Recommended | INFO | `[HEURISTIC]` Pasted content can be unexpected format. Detect `Clipboard.getData` usage in security-sensitive contexts without validation. |
| `prefer_clipboard_feedback` | Recommended | INFO | "Copied!" feedback confirms clipboard action. Detect `Clipboard.setData` without accompanying SnackBar/Toast. |

### 1.28 Analytics & Tracking Rules

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| `require_analytics_event_naming` | Professional | INFO | Consistent event naming improves analysis. Detect analytics events not matching configured naming pattern (e.g., snake_case). |
| `require_analytics_error_handling` | Recommended | INFO | Analytics failures shouldn't crash the app. Detect analytics calls without try-catch wrapper. |

### 1.29 Feature Flag Rules

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| `require_feature_flag_default` | Essential | WARNING | Feature flags must have defaults for offline/error cases. Detect feature flag checks without fallback value. |
| `require_feature_flag_type_safety` | Recommended | INFO | Use typed feature flag accessors, not raw string lookups. Detect string literal keys in feature flag calls. |

### 1.30 Date & Time Rules

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| `prefer_utc_for_storage` | Essential | WARNING | Store dates in UTC. Detect DateTime storage/serialization without `.toUtc()` conversion. |
| `require_timezone_display` | Recommended | INFO | When displaying times, indicate timezone or use relative time. Detect time formatting without timezone context. |
| ~~`prefer_duration_constants`~~ | Recommended | INFO | [IMPLEMENTED v1.8.2] `Duration(seconds: 60)` is less clear than `Duration(minutes: 1)`. |
| ~~`avoid_datetime_now_in_tests`~~ | Essential | WARNING | [IMPLEMENTED v1.8.2] Tests using `DateTime.now()` are non-deterministic. |
| `avoid_datetime_comparison_without_precision` | Professional | INFO | DateTime equality fails due to microsecond differences. Detect direct DateTime equality; suggest difference threshold. |

### 1.31 Money & Currency Rules

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| `require_currency_code_with_amount` | Recommended | INFO | `[HEURISTIC]` Amounts without currency are ambiguous. Detect money-related classes without currency field. |
| `require_currency_formatting_locale` | Recommended | INFO | Currency formatting varies by locale. Detect NumberFormat.currency without explicit locale parameter. |
| `avoid_money_arithmetic_on_double` | Essential | WARNING | `[HEURISTIC]` Arithmetic on money doubles compounds rounding errors. Detect +, -, *, / operations on money-named doubles. |

### 1.32 File I/O Rules

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| `require_file_exists_check` | Recommended | INFO | File operations on non-existent files throw. Detect File read operations without exists() check or try-catch. |
| `avoid_synchronous_file_io` | Essential | WARNING | `[CONTEXT]` Sync file operations block UI. Detect readAsStringSync, writeAsBytesSync, readAsBytesSync usage outside isolates. |
| `require_temp_file_cleanup` | Professional | INFO | `[CROSS-FILE]` Temp files accumulate over time. Detect temp file creation without corresponding delete. |
| `prefer_streaming_for_large_files` | Professional | INFO | Reading large files into memory causes OOM. Detect readAsBytes on files without size check. |
| `require_file_path_sanitization` | Essential | WARNING | User-provided file paths can escape app directory. Detect file operations with unsanitized path input. |

### 1.33 Encryption & Cryptography Rules

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| `avoid_encryption_key_in_memory` | Professional | INFO | `[HEURISTIC]` Keys kept in memory can be extracted from dumps. Detect encryption keys stored as class fields. |

### 1.34 JSON & Serialization Rules

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| `avoid_dynamic_json_access` | Recommended | WARNING | `json['key']['nested']` crashes on missing keys. Detect chained bracket access on dynamic JSON without null checks. |
| `prefer_json_codegen` | Professional | INFO | Manual fromJson/toJson is error-prone. Detect hand-written fromJson methods; suggest json_serializable/freezed. |
| `require_json_date_format_consistency` | Professional | INFO | Dates in JSON need consistent format. Detect DateTime serialization without explicit format. |

### 1.35 GetIt & Dependency Injection Rules

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| `prefer_lazy_singleton_registration` | Professional | INFO | `[HEURISTIC]` Eager registration creates all singletons at startup. Detect registerSingleton with expensive constructors; suggest registerLazySingleton. |
| `avoid_getit_unregistered_access` | Essential | ERROR | `[CROSS-FILE]` Accessing unregistered type crashes. Detect GetIt.I<T>() for types not registered in visible scope. |
| `require_getit_dispose_registration` | Professional | INFO | Disposable singletons need dispose callbacks. Detect registerSingleton of Disposable types without dispose parameter. |

### 1.36 Logging Rules

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| `avoid_print_in_production` | Essential | WARNING | `[CONTEXT]` print() ships to production, exposing debug info. Detect print() calls outside debug/test code. |
| `prefer_logger_over_print` | Recommended | INFO | Logger packages provide levels, formatting, filtering. Detect print() usage; suggest logger package. |
| `require_log_level_for_production` | Professional | INFO | Debug logs in production waste resources. Detect verbose logging without level checks. |
| `avoid_expensive_log_string_construction` | Professional | INFO | Don't build expensive strings for logs that won't print. Detect string interpolation in log calls without level guard. |

### 1.37 Caching Rules

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| `require_cache_expiration` | Recommended | WARNING | `[HEURISTIC]` Caches without TTL serve stale data indefinitely. Detect cache implementations without expiration logic. |
| `avoid_unbounded_cache_growth` | Essential | WARNING | `[HEURISTIC]` Caches without size limits cause OOM. Detect Map used as cache without size limiting or LRU eviction. |
| `require_cache_key_uniqueness` | Professional | INFO | Cache keys must be deterministic. Detect Object used as cache key without stable hashCode/equality. |
| `avoid_cache_in_build` | Essential | WARNING | `[CONTEXT]` Cache lookups in build() may be expensive. Detect cache operations inside build methods. |

### 1.38 Pagination Rules

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| `require_pagination_for_large_lists` | Essential | WARNING | Loading all items at once causes OOM and slow UI. Detect ListView/GridView with large itemCount without pagination. |
| `require_pagination_loading_state` | Recommended | INFO | Show loading indicator when fetching next page. Detect paginated list without loading state handling. |
| `avoid_pagination_refetch_all` | Professional | WARNING | Refetching all pages on refresh wastes bandwidth. Detect refresh logic that resets all paginated data. |
| `require_pagination_error_recovery` | Recommended | INFO | Failed page loads need retry option. Detect pagination without error state handling. |

### 1.39 Search & Filter Rules

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| `require_search_debounce` | Essential | WARNING | Searching on every keystroke overloads server. Detect TextField onChanged calling network/database without debounce. |
| `require_empty_results_state` | Recommended | INFO | "No results found" message is essential. Detect search results UI without empty state handling. |
| `prefer_search_cancel_previous` | Professional | INFO | Cancel previous search request when new search starts. Detect search without CancelToken or similar mechanism. |
| `require_search_loading_indicator` | Recommended | INFO | Show loading state during search. Detect search trigger without loading state update. |

### 1.40 Lifecycle & App State Rules

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| `require_lifecycle_observer` | Essential | WARNING | Network requests and timers should pause when app is backgrounded. Detect long-running operations without WidgetsBindingObserver. |
| `require_resume_state_refresh` | Recommended | INFO | Refresh stale data when app resumes. Detect apps without didChangeAppLifecycleState handling resumed state. |
| `avoid_work_in_paused_state` | Professional | INFO | Operations in paused state waste battery. Detect timers/streams continuing without pause in inactive state. |
| `require_app_startup_error_handling` | Essential | WARNING | Startup failures should show error UI, not crash. Detect initialization code without error handling. |

### 1.41 Image Loading & Optimization Rules

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| `require_image_loading_placeholder` | Recommended | INFO | Show placeholder while images load. Detect Image.network without loadingBuilder or frameBuilder. |
| `prefer_cached_network_image` | Recommended | INFO | Network images should use caching. Detect Image.network without caching; suggest CachedNetworkImage. |
| `require_image_error_fallback` | Recommended | INFO | Network images fail. Detect Image.network without errorBuilder. |
| `prefer_image_size_constraints` | Professional | INFO | Decode images at display size to save memory. Detect Image without cacheWidth/cacheHeight for large images. |
| `avoid_image_rebuild_on_scroll` | Professional | WARNING | Image widgets in lists should use caching to avoid re-fetch on scroll. Detect Image.network in ListView without caching. |

### 1.42 ListView & ScrollView Rules

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| `prefer_itemextent_when_known` | Professional | INFO | ListView with fixed item heights should use itemExtent for performance. Detect ListView without itemExtent when items are uniform. |
| `require_scroll_controller_dispose` | Essential | ERROR | ScrollController must be disposed. Detect ScrollController field without dispose() call. |
| `prefer_sliverfillremaining_for_empty` | Professional | INFO | Empty state in CustomScrollView needs SliverFillRemaining. Detect empty state widget as regular sliver. |

### 1.43 Focus & Keyboard Rules

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| `require_focus_node_dispose` | Essential | ERROR | FocusNode must be disposed. Detect FocusNode field in StatefulWidget without dispose() call. |
| `require_keyboard_action_type` | Recommended | INFO | Text fields need appropriate keyboard action. Detect TextField without textInputAction in forms. |
| `prefer_focus_traversal_order` | Professional | INFO | Tab order should be logical. Detect forms without FocusTraversalGroup for complex layouts. |
| `require_keyboard_dismiss_on_scroll` | Recommended | INFO | Keyboard should dismiss when scrolling. Detect ListView in form without keyboardDismissBehavior. |

### 1.44 Internationalization (L10n) Rules

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| `avoid_string_concatenation_for_l10n` | Essential | WARNING | `[HEURISTIC]` String concatenation breaks in RTL and different word orders. Detect string + variable in UI text. |
| `require_plural_handling` | Recommended | INFO | `[HEURISTIC]` "1 items" is wrong. Detect numeric values next to hardcoded plural nouns. |
| `require_rtl_layout_support` | Recommended | WARNING | RTL languages need directional awareness. Detect hardcoded left/right in layouts without Directionality check. |
| `avoid_hardcoded_locale_strings` | Recommended | INFO | User-visible strings should be localized. Detect string literals in Text widgets not using l10n. |
| `require_number_formatting_locale` | Professional | INFO | Number formatting varies by locale. Detect NumberFormat without explicit locale. |

### 1.45 Gradient & CustomPaint Rules

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| `require_custom_painter_shouldrepaint` | Professional | INFO | CustomPainter without proper shouldRepaint causes excessive repaints or stale UI. Detect CustomPainter with default shouldRepaint. |
| `prefer_cached_paint_objects` | Professional | INFO | Paint objects are expensive to create. Detect Paint() construction inside paint() method. |

### 1.46 Dialog & Modal Rules

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| `require_dialog_barrier_consideration` | Recommended | INFO | `[HEURISTIC]` Destructive confirmations shouldn't dismiss on barrier tap. Detect showDialog without explicit barrierDismissible for destructive actions. |
| `require_dialog_result_handling` | Professional | INFO | Dialogs returning values need result handling. Detect showDialog without await or .then() for dialogs with return values. |
| `avoid_dialog_context_after_async` | Essential | ERROR | Context may be invalid after async in dialog. Detect Navigator.pop using context after await in dialog. |
| `prefer_adaptive_dialog` | Comprehensive | INFO | Dialogs should adapt to platform. Detect showDialog without platform-specific styling consideration. |

### 1.47 Snackbar & Toast Rules

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| `require_snackbar_action_for_undo` | Recommended | INFO | `[HEURISTIC]` Destructive actions should offer undo. Detect delete operations showing SnackBar without action. |
| `avoid_snackbar_queue_buildup` | Professional | INFO | Rapid snackbar calls queue up. Detect multiple showSnackBar calls without clearSnackBars. |
| `require_snackbar_duration_consideration` | Recommended | INFO | `[HEURISTIC]` Important messages need longer duration. Detect SnackBar without explicit duration for important content. |

### 1.48 Tab & Bottom Navigation Rules

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| `require_tab_state_preservation` | Professional | INFO | Tab state should persist on switch. Detect TabBarView children without AutomaticKeepAliveClientMixin. |

### 1.49 Stepper & Multi-step Flow Rules

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| `require_stepper_validation` | Recommended | INFO | Validate each step before allowing next. Detect Stepper onStepContinue without validation logic. |
| `require_stepper_state_management` | Professional | INFO | Stepper state should handle back navigation. Detect Stepper without preserving form state across steps. |
| `require_step_count_indicator` | Recommended | INFO | Show step X of Y progress. Detect multi-step flow without progress indication. |

### 1.50 Badge & Indicator Rules

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| `require_badge_count_limit` | Recommended | INFO | Large counts should show "99+". Detect Badge with count > 99 displayed as-is. |
| `require_badge_semantics` | Recommended | INFO | Badges need accessibility labels. Detect Badge without Semantics for notification count. |
| `avoid_badge_without_meaning` | Comprehensive | INFO | Empty badges confuse users. Detect Badge shown when count is 0. |

### 1.51 Avatar & Profile Image Rules

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| `require_avatar_fallback` | Recommended | INFO | Missing profile images need fallback. Detect CircleAvatar with network image without fallback/error handling. |
| `prefer_avatar_loading_placeholder` | Recommended | INFO | Show placeholder while avatar loads. Detect CircleAvatar without placeholder during load. |
| `require_avatar_alt_text` | Recommended | WARNING | Avatars need accessibility description. Detect CircleAvatar without semanticLabel. |

### 1.52 Loading State Rules

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| `prefer_skeleton_over_spinner` | Recommended | INFO | Skeleton loaders feel faster than spinners. Detect CircularProgressIndicator for content loading; suggest shimmer/skeleton. |
| `require_loading_timeout` | Essential | WARNING | `[TOO-COMPLEX]` Infinite loading states lose users. Cannot reliably detect "loading state" generically via AST - would need package-specific implementations (dio timeout, etc.). |
| `avoid_loading_flash` | Professional | INFO | Brief loading flash looks glitchy. Detect loading indicator shown without minimum delay (150-200ms). |
| `require_loading_state_distinction` | Recommended | INFO | `[TOO-COMPLEX]` Initial load vs refresh should differ. Cannot reliably distinguish "initial load" vs "refresh" states in static analysis. |

### 1.53 Pull-to-Refresh Rules

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| `require_refresh_indicator_on_lists` | Recommended | INFO | Scrollable lists should support pull-to-refresh. Detect ListView without RefreshIndicator wrapper. |
| `require_refresh_completion_feedback` | Recommended | INFO | `[TOO-COMPLEX]` Refresh without visible change confuses users. Cannot detect "visible change" or "user feedback" generically - setState could update anything. |

### 1.54 Infinite Scroll Rules

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| `require_infinite_scroll_end_indicator` | Recommended | INFO | `[TOO-COMPLEX]` Detect when all items loaded. Pattern requires detecting scroll listener + hasMore flag + end indicator - too many variables for reliable detection. |
| `prefer_infinite_scroll_preload` | Professional | INFO | Load next page before reaching end. Detect ScrollController listener triggering at 100% scroll. |
| `require_infinite_scroll_error_recovery` | Recommended | INFO | Failed page loads need retry. Detect infinite scroll without error state and retry button. |
| `avoid_infinite_scroll_duplicate_requests` | Professional | WARNING | Prevent multiple simultaneous page requests. Detect scroll listener without loading guard. |

### 1.55 Architecture Rules

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| `avoid_banned_api` | Professional | WARNING | Configurable rule to restrict usage of specific APIs based on source package, class name, identifier, or named parameter, with include/exclude file patterns. Useful for enforcing layer boundaries (e.g., UI cannot call database directly). Inspired by solid_lints' `avoid_using_api`. |

### 1.56 Type Safety & Casting Rules

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| `avoid_non_null_assertion` | Recommended | WARNING | Avoid `!` null assertion operator - use null checks or `??` instead. |
| `avoid_type_casts` | Professional | INFO | Prefer type checks over casts where possible. |
| `avoid_unrelated_type_casts` | Essential | ERROR | Casting between unrelated types will always fail. |
| `prefer_explicit_type_arguments` | Professional | INFO | Prefer explicit type arguments over inference in complex cases. |
| `avoid_explicit_type_declaration` | Stylistic | INFO | Prefer type inference over explicit type declarations where the type is obvious. |

### 1.57 Error Handling Rules

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| `avoid_nested_try_statements` | Professional | INFO | Nested try-catch blocks indicate overly complex error handling. |
| `avoid_uncaught_future_errors` | Essential | WARNING | Futures without error handling can cause unhandled exceptions. |
| `handle_throwing_invocations` | Professional | INFO | Invocations that can throw should be handled appropriately. |
| `prefer_correct_throws` | Professional | INFO | Document thrown exceptions with `@Throws` annotation. |

### 1.58 Class & Inheritance Rules

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| `avoid_accessing_other_classes_private_members` | Professional | WARNING | Detect access to private members of other classes through workarounds. |
| `avoid_referencing_subclasses` | Professional | INFO | Base classes should not reference their subclasses directly. |
| `avoid_renaming_representation_getters` | Professional | INFO | Extension type representation getters should not be renamed. |
| `avoid_suspicious_super_overrides` | Professional | WARNING | Detect suspicious super.method() calls in overrides. |
| `prefer_redirecting_superclass_constructor` | Recommended | INFO | Use redirecting constructors to call super constructors. |
| `prefer_class_destructuring` | Professional | INFO | Use record destructuring for class field access when beneficial. |

### 1.59 Boolean & Conditional Rules

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| `no_boolean_literal_compare` | Recommended | INFO | Avoid comparing boolean expressions to boolean literals (`if (x == true)`). |
| `prefer_simpler_boolean_expressions` | Recommended | INFO | Simplify complex boolean expressions using De Morgan's laws. |
| `prefer_returning_conditional_expressions` | Recommended | INFO | Return conditional expressions directly instead of if/else blocks. |

### 1.60 JSON & Serialization Rules

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| `avoid_not_encodable_in_to_json` | Professional | WARNING | Detect toJson methods that return non-encodable types. |
| `prefer_correct_json_casts` | Professional | INFO | Use proper type casts when working with JSON data. |

### 1.61 Ordering & Pattern Rules

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| `arguments_ordering` | Stylistic | INFO | Enforce consistent ordering of function arguments (alphabetical, required first, etc.). |
| `pattern_fields_ordering` | Stylistic | INFO | Enforce consistent ordering of fields in pattern matching. |
| `record_fields_ordering` | Stylistic | INFO | Enforce consistent ordering of fields in record declarations. |

### 1.62 Code Quality Rules

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| `avoid_deprecated_usage` | Recommended | WARNING | Warn when using deprecated APIs, classes, or methods. |
| `avoid_high_cyclomatic_complexity` | Professional | WARNING | Warn when functions exceed a configurable cyclomatic complexity threshold. |
| `avoid_ignoring_return_values` | Recommended | INFO | Warn when function return values are ignored (unless explicitly marked). |
| `avoid_importing_entrypoint_exports` | Professional | INFO | Avoid importing from files that re-export entry points. |
| `avoid_missing_interpolation` | Recommended | WARNING | Detect string concatenation that should use interpolation. |
| `avoid_never_passed_parameters` | Professional | INFO | `[CROSS-FILE]` Detect function parameters that are never passed by any caller. |
| `avoid_suspicious_global_reference` | Professional | WARNING | Detect suspicious references to global state in methods. |
| `avoid_unreachable_for_loop` | Recommended | WARNING | Detect for loops that will never execute (empty ranges). |
| `avoid_unused_local_variable` | Recommended | WARNING | Local variables that are declared but never used. |
| `no_empty_block` | Recommended | WARNING | Empty blocks indicate missing implementation or dead code. |
| `prefer_correct_for_loop_increment` | Recommended | INFO | Use standard for-loop increment patterns. |
| `prefer_typedefs_for_callbacks` | Professional | INFO | Use typedefs for function type signatures to improve readability. |
| `tag_name` | Professional | INFO | Validate custom element tag names follow conventions. |
| `banned_usage` | Professional | WARNING | Configurable rule to ban specific APIs, classes, or patterns. |

### 1.63 Bloc/Cubit Rules

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| `avoid_bloc_public_fields` | Professional | WARNING | Bloc fields should be private - expose state through streams only. |
| `avoid_bloc_public_methods` | Professional | WARNING | Bloc should only expose event handling - use add() for events. |
| `avoid_cubits` | Stylistic | INFO | Prefer Bloc over Cubit for better event traceability. |
| `avoid_empty_build_when` | Recommended | WARNING | Empty buildWhen in BlocBuilder means it always rebuilds. |
| `avoid_passing_bloc_to_bloc` | Professional | WARNING | Blocs should not directly depend on other Blocs - use streams or events. |
| `avoid_passing_build_context_to_blocs` | Essential | WARNING | BuildContext in Blocs couples UI to business logic. |
| `avoid_returning_value_from_cubit_methods` | Professional | INFO | Cubit methods should emit states, not return values. |
| `emit_new_bloc_state_instances` | Professional | WARNING | Always emit new state instances - mutating existing state breaks equality checks. |
| `handle_bloc_event_subclasses` | Professional | INFO | Ensure all event subclasses are handled in event handlers. |
| `prefer_bloc_event_suffix` | Stylistic | INFO | Bloc event classes should have `Event` suffix. |
| `prefer_bloc_extensions` | Professional | INFO | Use Bloc extension methods for cleaner code. |
| `prefer_bloc_state_suffix` | Stylistic | INFO | Bloc state classes should have `State` suffix. |

#### Riverpod Rules

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|

#### Provider Rules

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| `prefer_immutable_selector_value` | Professional | INFO | Selector values should be immutable for proper equality checks. |
| `prefer_nullable_provider_types` | Professional | INFO | Provider types should be nullable when the value can be absent. |
| `prefer_provider_extensions` | Professional | INFO | Use Provider extension methods for cleaner code. |
| `dispose_provided_instances` | Essential | WARNING | Instances created in Provider.create should be disposed. |

#### GetX Rules

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| `avoid_getx_rx_inside_build` | Professional | WARNING | Creating Rx variables in build causes unnecessary rebuilds. |
| `avoid_mutable_rx_variables` | Professional | INFO | Rx variables should not be reassigned - update their values instead. |
| `dispose_getx_fields` | Essential | WARNING | GetX controllers and workers must be disposed. |

#### Flutter Hooks Rules

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| `avoid_misused_hooks` | Essential | WARNING | Detect common hook misuse patterns. |
| `prefer_use_callback` | Professional | INFO | Use useCallback for memoizing callback functions. |
| `prefer_use_prefix` | Stylistic | INFO | Custom hooks should start with `use` prefix. |

#### Flame Engine Rules

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| `avoid_creating_vector_in_update` | Essential | WARNING | Creating Vector2/3 in update() causes GC pressure - reuse vectors. |
| `avoid_redundant_async_on_load` | Recommended | INFO | onLoad doesn't need async if it doesn't await anything. |

#### Intl/Localization Rules

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| `avoid_missing_tr` | Essential | WARNING | Detect strings that should be translated but aren't. |
| `avoid_missing_tr_on_strings` | Essential | WARNING | User-visible strings should use translation methods. |
| `prefer_date_format` | Recommended | INFO | Use DateFormat with locale for consistent date formatting. |
| `prefer_intl_name` | Professional | INFO | Intl.message name parameter should match the getter name. |
| `prefer_number_format` | Recommended | INFO | Use NumberFormat with locale for consistent number formatting. |
| `prefer_providing_intl_description` | Professional | INFO | Intl.message should include description for translators. |
| `prefer_providing_intl_examples` | Professional | INFO | Intl.message should include examples for complex strings. |
| `provide_correct_intl_args` | Essential | ERROR | Intl.message args must match placeholders in the message. |

#### Testing Rules

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| `avoid_missing_controller` | Essential | WARNING | Widgets with controllers should have controllers provided. |
| `avoid_missing_test_files` | Professional | INFO | `[CROSS-FILE]` Source files should have corresponding test files. |
| `avoid_misused_test_matchers` | Recommended | WARNING | Detect incorrect usage of test matchers. |
| `format_test_name` | Stylistic | INFO | Test names should follow a consistent format. |
| `prefer_custom_finder_over_find` | Professional | INFO | Use custom finders for better test readability and maintenance. |

#### Patrol Testing Rules

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| `prefer_custom_finder_over_find` | Professional | INFO | Use Patrol's custom finders for clearer integration tests. |

#### Pubspec Rules

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| `add_resolution_workspace` | Professional | INFO | Add resolution workspace for monorepo dependency management. |
| `avoid_any_version` | Essential | WARNING | Avoid `any` version constraint - specify version ranges. |
| `avoid_dependency_overrides` | Recommended | WARNING | dependency_overrides should only be used temporarily. |
| `dependencies_ordering` | Stylistic | INFO | Dependencies should be sorted alphabetically. |
| `newline_before_pubspec_entry` | Stylistic | INFO | Add blank lines between major pubspec sections. |
| `prefer_caret_version_syntax` | Stylistic | INFO | Use `^1.0.0` caret syntax for version constraints. |
| `prefer_commenting_pubspec_ignores` | Professional | INFO | Document why pubspec rules are ignored. |
| `prefer_correct_package_name` | Essential | ERROR | Package name must follow Dart naming conventions. |
| `prefer_correct_screenshots` | Professional | INFO | Screenshots in pubspec should have valid paths and descriptions. |
| `prefer_correct_topics` | Professional | INFO | Topics should be valid pub.dev topics. |
| `prefer_pinned_version_syntax` | Professional | INFO | Pin exact versions for production stability. |
| `prefer_publish_to_none` | Recommended | INFO | Private packages should have `publish_to: none`. |
| `prefer_semver_version` | Essential | WARNING | Version should follow semantic versioning (major.minor.patch). |
| `pubspec_ordering` | Stylistic | INFO | Pubspec fields should follow recommended ordering. |

#### Widget/Flutter Rules

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| `add_copy_with` | Professional | INFO | Immutable classes should have copyWith method. |
| `avoid_collection_mutating_methods` | Professional | WARNING | Avoid methods that mutate collections in place. |
| `avoid_missing_controller` | Essential | WARNING | Widgets requiring controllers should have them provided. |
| `avoid_unnecessary_consumer_widgets` | Recommended | INFO | Don't use ConsumerWidget if not using ref. |
| `avoid_unnecessary_null_aware_elements` | Recommended | INFO | Null-aware elements in collections that can't be null. |
| `dispose_class_fields` | Essential | WARNING | Class fields that are disposable should be disposed. |
| `prefer_compute_over_isolate_run` | Professional | INFO | Use compute() for simpler isolate operations. |
| `prefer_container` | Comprehensive | INFO | Use Container when combining multiple decorations. |
| `prefer_dedicated_media_query_methods` | Recommended | INFO | Use MediaQuery.sizeOf() instead of MediaQuery.of().size. |
| `prefer_for_loop_in_children` | Professional | INFO | Use for loops instead of List.generate in widget children. |
| `prefer_single_setstate` | Professional | INFO | Batch multiple state changes into single setState call. |
| `prefer_spacing` | Recommended | INFO | Use Spacing widget (or SizedBox) for consistent spacing. |
| `use_closest_build_context` | Professional | INFO | Use the closest available BuildContext for better performance. |

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
