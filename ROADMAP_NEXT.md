# ROADMAP_NEXT.md - Priority Implementation Queue

This document contains the **easiest rules to implement** plus **all Isar rules**. These rules have low false-positive risk because they match exact API patterns, constructor/dispose patterns, or check for missing required parameters.

## Selection Criteria

Rules were selected based on the "Truly Easy Rules" criteria from ROADMAP.md:
- **Exact API/method name matching** - `jsonDecode()`, `DateTime.parse()`
- **Specific named parameter checks** - `shrinkWrap: true`, `autoPlay: true`
- **Missing required parameter detection** - `Image.network` without `errorBuilder`
- **Constructor + dispose patterns** - `ScrollController` without `dispose()`

Rules marked with `[HEURISTIC]`, `[CONTEXT]`, `[CROSS-FILE]`, or `[TOO-COMPLEX]` were excluded.

---

## Already Implemented Rules (Reference)

The following rules from the original list already exist. They are listed here for reference but are NOT in the implementation queue.

### Isar Rules (1 implemented)
- `avoid_isar_enum_field` - isar_rules.dart (aliases: avoid_isar_enum_index_change)

### Dispose Pattern Rules (13 implemented)
- `require_scroll_controller_dispose` - flutter_widget_rules.dart
- `require_focus_node_dispose` - flutter_widget_rules.dart
- `require_animation_controller_dispose` - animation_rules.dart
- `require_stream_subscription_cancel` - disposal_rules.dart
- `require_timer_cancellation` - flutter_widget_rules.dart (alias: require_timer_cancel)
- `require_text_editing_controller_dispose` - disposal_rules.dart
- `require_page_controller_dispose` - disposal_rules.dart
- `require_tab_controller_dispose` - disposal_rules.dart
- `require_value_notifier_dispose` - state_management_rules.dart
- `require_stream_controller_close` - async_rules.dart
- `require_http_client_close` - resource_management_rules.dart
- `require_isolate_kill` - resource_management_rules.dart

### Lifecycle Rules (6 implemented)
- `require_mounted_check` - state_management_rules.dart
- `avoid_controller_in_build` - performance_rules.dart
- `avoid_stream_in_build` - async_rules.dart
- `avoid_future_builder_rebuild` - async_rules.dart
- `require_vsync_mixin` - animation_rules.dart
- `avoid_animation_in_build` - animation_rules.dart

### Missing Parameter Rules (10 implemented)
- `require_dio_timeout` - api_network_rules.dart
- `require_dio_error_handling` - api_network_rules.dart
- `require_avatar_alt_text` - accessibility_rules.dart
- `require_image_error_builder` - flutter_widget_rules.dart (alias: require_image_error_fallback)
- `require_avatar_fallback` - image_rules.dart
- `require_image_error_fallback` - image_rules.dart
- `require_image_loading_placeholder` - image_rules.dart
- `require_cached_image_dimensions` - image_rules.dart
- `require_cached_image_placeholder` - image_rules.dart
- `require_cached_image_error_widget` - image_rules.dart
- `require_go_router_error_handler` - navigation_rules.dart

### Exact API Rules (6 implemented)
- `avoid_shrink_wrap_in_lists` / `avoid_shrink_wrap_in_scroll` - flutter_widget_rules.dart
- `avoid_nested_scrollables` / `avoid_nested_scrollables_conflict` - flutter_widget_rules.dart / scroll_rules.dart
- `avoid_yield_in_on_event` - state_management_rules.dart
- `require_riverpod_error_handling` - riverpod_rules.dart
- `require_hive_initialization` - file_handling_rules.dart / hive_rules.dart
- `require_hive_type_adapter` - file_handling_rules.dart / hive_rules.dart

### Additional Rules (7 implemented)
- `require_sqflite_whereargs` - file_handling_rules.dart
- `require_provider_dispose` - state_management_rules.dart
- `require_getx_controller_dispose` - state_management_rules.dart
- `avoid_shared_prefs_sensitive_data` - security_rules.dart
- `require_webview_navigation_delegate` - flutter_widget_rules.dart (aliases: webview_missing_navigation_delegate, insecure_webview)
- `avoid_logging_sensitive_data` - security_rules.dart (aliases: no_sensitive_logs, pii_in_logs, credential_logging)

### Animation Rules (5 implemented)
- `prefer_tween_sequence` - animation_rules.dart
- `require_animation_status_listener` - animation_rules.dart
- `avoid_overlapping_animations` - animation_rules.dart
- `avoid_animation_rebuild_waste` - animation_rules.dart
- `prefer_physics_simulation` - animation_rules.dart

---

## Part 1: Isar Database Rules (19 remaining)

Critical for preventing data corruption. `avoid_isar_enum_field` already implemented.

| # | Rule Name | Tier | Severity | Detection Pattern |
|---|-----------|------|----------|-------------------|
| 1 | `require_isar_collection_annotation` | Essential | ERROR | Class used with Isar missing `@collection` |
| 2 | `require_isar_id_field` | Essential | ERROR | `@collection` class missing `Id? id` field |
| 3 | `prefer_isar_index_for_queries` | Professional | INFO | `.where()` on non-indexed field |
| 4 | `avoid_isar_embedded_large_objects` | Professional | WARNING | Large embedded objects in collection |
| 5 | `require_isar_close_on_dispose` | Essential | WARNING | `Isar.openSync` without `.close()` in dispose |
| 6 | `prefer_isar_async_writes` | Recommended | INFO | `writeTxnSync` in build methods |
| 7 | `avoid_isar_schema_breaking_changes` | Essential | ERROR | Field removal/rename without `@Name` |
| 8 | `prefer_isar_lazy_links` | Professional | INFO | `IsarLinks` without `.lazy` for large collections |
| 9 | `avoid_isar_web_limitations` | Recommended | WARNING | Isar sync API on web platform |
| 10 | `require_isar_links_load` | Essential | ERROR | `IsarLinks` access without prior `load()` |
| 11 | `avoid_isar_transaction_nesting` | Essential | ERROR | `writeTxn` inside another `writeTxn` |
| 12 | `prefer_isar_batch_operations` | Professional | INFO | `put()` in loop instead of `putAll()` |
| 13 | `avoid_isar_string_contains_without_index` | Professional | WARNING | String `.contains()` without full-text index |
| 14 | `require_isar_non_nullable_migration` | Essential | ERROR | Nullable to non-nullable without default |
| 15 | `prefer_isar_composite_index` | Professional | INFO | Multi-field where without composite `@Index` |
| 16 | `avoid_isar_float_equality_queries` | Professional | WARNING | `.equalTo()` on double fields |
| 17 | `require_isar_inspector_debug_only` | Essential | WARNING | Isar Inspector without `kDebugMode` guard |
| 18 | `prefer_isar_query_stream` | Professional | INFO | Timer-based Isar queries instead of `watch()` |
| 19 | `avoid_isar_clear_in_production` | Essential | ERROR | `isar.clear()` without debug guard |

---

## Part 2: Dispose Pattern Rules (6 remaining)

Constructor + dispose pattern matching - detect resource creation without cleanup.

| # | Rule Name | Tier | Severity | Detection Pattern |
|---|-----------|------|----------|-------------------|
| 20 | `require_change_notifier_dispose` | Essential | ERROR | `ChangeNotifier` without `dispose()` |
| 21 | `require_receive_port_close` | Essential | ERROR | `ReceivePort` without `close()` |
| 22 | `require_socket_close` | Essential | ERROR | `Socket` without `close()` |
| 23 | `require_debouncer_cancel` | Essential | ERROR | Debounce timer without `cancel()` |
| 24 | `require_interval_timer_cancel` | Essential | ERROR | `Timer.periodic` without `cancel()` (explicit periodic) |
| 25 | `require_file_handle_close` | Essential | WARNING | `RandomAccessFile` without `close()` |

---

## Part 3: Widget Lifecycle Rules (5 remaining)

Exact method/context pattern matching in StatefulWidget lifecycle.

| # | Rule Name | Tier | Severity | Detection Pattern |
|---|-----------|------|----------|-------------------|
| 26 | `require_super_dispose_call` | Essential | ERROR | `dispose()` without `super.dispose()` |
| 27 | `require_super_init_state_call` | Essential | ERROR | `initState()` without `super.initState()` |
| 28 | `avoid_set_state_in_build` | Essential | ERROR | `setState` call inside `build()` |
| 29 | `avoid_set_state_in_dispose` | Essential | ERROR | `setState` call inside `dispose()` |
| 30 | `avoid_navigation_in_build` | Essential | ERROR | `Navigator.push` inside `build()` |

---

## Part 4: Missing Parameter Rules (3 remaining)

Detect required parameters that are frequently omitted.

| # | Rule Name | Tier | Severity | Detection Pattern |
|---|-----------|------|----------|-------------------|
| 31 | `require_provider_generic_type` | Essential | ERROR | `Provider.of(context)` without `<Type>` |
| 32 | `require_text_form_field_in_form` | Essential | WARNING | `TextFormField` without `Form` ancestor |
| 33 | `require_webview_navigation_delegate` | Essential | WARNING | `WebView` without `navigationDelegate` |

---

## Part 5: Exact API Pattern Rules (10 remaining)

Direct API name or pattern matching with low false-positive risk.

| # | Rule Name | Tier | Severity | Detection Pattern |
|---|-----------|------|----------|-------------------|
| 34 | `require_flutter_riverpod_package` | Essential | ERROR | `riverpod` import without `flutter_riverpod` |
| 35 | `avoid_bloc_emit_after_close` | Essential | ERROR | `emit` without `isClosed` check in async |
| 36 | `avoid_bloc_state_mutation` | Essential | ERROR | `state.field = value` instead of `copyWith` |
| 37 | `require_bloc_initial_state` | Essential | ERROR | Bloc without `super(InitialState)` |
| 38 | `require_physics_for_nested_scroll` | Essential | WARNING | Nested scroll without `NeverScrollableScrollPhysics` |
| 39 | `require_animated_builder_child` | Essential | WARNING | `AnimatedBuilder` without `child` parameter |
| 40 | `require_rethrow_preserve_stack` | Essential | WARNING | `throw e` instead of `rethrow` |
| 41 | `require_https_over_http` | Essential | ERROR | `http://` URL in network calls |
| 42 | `require_wss_over_ws` | Essential | ERROR | `ws://` URL for WebSocket |
| 43 | `avoid_late_without_guarantee` | Essential | WARNING | `late` field without guaranteed init |

---

## Part 6: Additional Easy Rules (10 remaining)

More straightforward detection patterns.

| # | Rule Name | Tier | Severity | Detection Pattern |
|---|-----------|------|----------|-------------------|
| 44 | `require_secure_storage_auth_data` | Essential | ERROR | JWT in `SharedPreferences` instead of `flutter_secure_storage` |
| 45 | `avoid_freezed_json_serializable_conflict` | Essential | ERROR | Both `@freezed` and `@JsonSerializable` |
| 46 | `require_freezed_arrow_syntax` | Essential | ERROR | `fromJson` factory with block body |
| 47 | `require_freezed_private_constructor` | Essential | ERROR | Freezed methods without private constructor |
| 48 | `require_equatable_immutable` | Essential | ERROR | Non-final fields in `Equatable` |
| 49 | `require_equatable_props_override` | Essential | ERROR | `Equatable` without `props` getter |
| 50 | `avoid_equatable_mutable_collections` | Essential | WARNING | Mutable `List`/`Map` in `Equatable` |
| 51 | `require_bloc_loading_state` | Recommended | INFO | Async handler without loading emission |
| 52 | `require_bloc_error_state` | Recommended | INFO | State sealed class without error case |
| 53 | `avoid_static_state` | Essential | WARNING | Static mutable state |

---

## Part 7: Newly Identified Easy Rules (28 remaining)

These rules were identified as part of the ROADMAP organization and don't have complex markers.

### Dio HTTP Client Rules

| # | Rule Name | Tier | Severity | Detection Pattern |
|---|-----------|------|----------|-------------------|
| 54 | `avoid_dio_debug_print_production` | Essential | WARNING | Dio with debugPrint without `kDebugMode` check |
| 55 | `require_dio_singleton` | Professional | INFO | Multiple `Dio()` constructor calls without shared instance |
| 56 | `prefer_dio_base_options` | Professional | INFO | Repeated options in multiple requests without BaseOptions |
| 57 | `avoid_dio_without_base_url` | Recommended | INFO | Dio without baseUrl and full URLs in requests |

### go_router Navigation Rules

| # | Rule Name | Tier | Severity | Detection Pattern |
|---|-----------|------|----------|-------------------|
| 58 | `prefer_go_router_redirect_auth` | Professional | INFO | Auth logic in page builders instead of redirect |
| 59 | `require_go_router_typed_params` | Professional | INFO | String path params without type conversion |

### Provider State Management Rules

| # | Rule Name | Tier | Severity | Detection Pattern |
|---|-----------|------|----------|-------------------|
| 60 | `avoid_provider_circular_dependency` | Essential | ERROR | Provider A watches Provider B watches A |
| 61 | `avoid_provider_in_init_state` | Essential | WARNING | `Provider.of` in initState |
| 62 | `prefer_context_read_in_callbacks` | Essential | WARNING | `context.watch` in button handlers |

### Hive Database Rules

| # | Rule Name | Tier | Severity | Detection Pattern |
|---|-----------|------|----------|-------------------|
| 63 | `require_hive_type_id_management` | Essential | WARNING | Duplicate or changing typeIds |

### SQLite Database Rules

| # | Rule Name | Tier | Severity | Detection Pattern |
|---|-----------|------|----------|-------------------|
| 64 | `require_sqflite_migration` | Essential | WARNING | onUpgrade without version check |

### Cached Network Image Rules

| # | Rule Name | Tier | Severity | Detection Pattern |
|---|-----------|------|----------|-------------------|
| 65 | `avoid_cached_image_in_build` | Essential | WARNING | Variable cacheKey in build method |

### Image Picker Rules

| # | Rule Name | Tier | Severity | Detection Pattern |
|---|-----------|------|----------|-------------------|
| 66 | `require_image_picker_error_handling` | Essential | WARNING | pickImage without null check or try-catch |
| 67 | `require_image_picker_source_choice` | Recommended | INFO | Hardcoded ImageSource |
| 68 | `require_image_picker_result_handling` | Essential | WARNING | pickImage result unused |

### Permission Handler Rules

| # | Rule Name | Tier | Severity | Detection Pattern |
|---|-----------|------|----------|-------------------|
| 69 | `require_permission_rationale` | Recommended | INFO | Request without prior explanation |
| 70 | `require_permission_denied_handling` | Essential | WARNING | Request without denied state handling |
| 71 | `require_permission_status_check` | Recommended | INFO | Feature usage without permission check |

### Geolocator Rules

| # | Rule Name | Tier | Severity | Detection Pattern |
|---|-----------|------|----------|-------------------|
| 72 | `require_geolocator_timeout` | Essential | WARNING | getCurrentPosition without timeLimit |

### Notification Rules

| # | Rule Name | Tier | Severity | Detection Pattern |
|---|-----------|------|----------|-------------------|
| 73 | `require_notification_handler_top_level` | Essential | ERROR | Background handler is instance method |
| 74 | `require_notification_permission_android13` | Essential | ERROR | Notification without POST_NOTIFICATIONS |

### Connectivity Rules

| # | Rule Name | Tier | Severity | Detection Pattern |
|---|-----------|------|----------|-------------------|
| 75 | `require_connectivity_subscription_cancel` | Essential | ERROR | onConnectivityChanged without cancel |

### URL Launcher Rules

| # | Rule Name | Tier | Severity | Detection Pattern |
|---|-----------|------|----------|-------------------|
| 76 | `require_url_launcher_error_handling` | Essential | WARNING | launchUrl without try-catch |

### Cross-File Rules (Lower Priority)

These require analysis of native configuration files:

| # | Rule Name | Tier | Severity | Detection Pattern |
|---|-----------|------|----------|-------------------|
| 77 | `require_image_picker_permission_ios` | Essential | ERROR | image_picker without NSPhotoLibraryUsageDescription |
| 78 | `require_image_picker_permission_android` | Essential | ERROR | Camera usage without manifest permission |
| 79 | `require_permission_manifest_android` | Essential | ERROR | Runtime request without manifest entry |
| 80 | `require_permission_plist_ios` | Essential | ERROR | Request without plist description |
| 81 | `require_url_launcher_queries_android` | Essential | ERROR | Launch without manifest queries element |
| 82 | `require_url_launcher_schemes_ios` | Essential | ERROR | canLaunchUrl without LSApplicationQueriesSchemes |

---

## Summary

**Total remaining rules to implement: 82**

- Part 1 - Isar rules: 19
- Part 2 - Dispose patterns: 6
- Part 3 - Lifecycle rules: 5
- Part 4 - Missing parameters: 3
- Part 5 - API patterns: 10
- Part 6 - Additional: 10
- Part 7 - Newly identified: 29 (including 6 cross-file)

**Already implemented: ~54 rules** (see reference section above)

---

## Implementation Priority

### Wave 1: Critical Safety (Rules 1-19)
All remaining Isar rules - prevent data corruption.

### Wave 2: Memory Leaks (Rules 20-25)
Remaining dispose patterns - prevent memory leaks.

### Wave 3: Lifecycle Bugs (Rules 26-30)
Widget lifecycle - prevent runtime crashes.

### Wave 4: Common Mistakes (Rules 31-33)
Missing parameters - improve UX.

### Wave 5: API Patterns (Rules 34-43)
Exact API matching - enforce best practices.

### Wave 6: Additional (Rules 44-53)
Remaining easy wins.

### Wave 7: Package-Specific (Rules 54-76)
Dio, GoRouter, Provider, Hive, SQLite, ImagePicker, Permissions, Geolocator, Notifications, Connectivity, URL Launcher.

### Wave 8: Cross-File (Rules 77-82)
Requires manifest/plist analysis - lower priority due to complexity.

---

## Part 8: Package-Specific Rules from saropa Project (0 remaining, 21 implemented, 36 deferred)

> Generated from `analyze_pubspec.py` analysis of the saropa contacts app dependencies.
> **Note:** 36 rules moved to ROADMAP.md "Deferred & Complex Rules" section due to heuristic/cross-file requirements.

### Already Implemented (21 rules)

| # | Rule Name | Location |
|---|-----------|----------|
| 83 | `require_google_signin_error_handling` | package_specific_rules.dart |
| 86 | `require_apple_signin_nonce` | package_specific_rules.dart |
| 89 | `require_supabase_error_handling` | package_specific_rules.dart |
| 90 | `avoid_supabase_anon_key_in_code` | package_specific_rules.dart |
| 92 | `require_supabase_realtime_unsubscribe` | package_specific_rules.dart |
| 97 | `require_webview_navigation_delegate` | flutter_widget_rules.dart |
| 98 | `require_webview_ssl_error_handling` | package_specific_rules.dart |
| 100 | `avoid_webview_file_access` | package_specific_rules.dart |
| 101 | `require_workmanager_constraints` | package_specific_rules.dart |
| 104 | `require_workmanager_result_return` | package_specific_rules.dart |
| 106 | `require_calendar_timezone_handling` | package_specific_rules.dart |
| 116 | `require_keyboard_visibility_dispose` | package_specific_rules.dart |
| 118 | `require_speech_stop_on_dispose` | package_specific_rules.dart |
| 127 | `avoid_app_links_sensitive_params` | package_specific_rules.dart |
| 129 | `require_envied_obfuscation` | package_specific_rules.dart |
| 130 | `avoid_openai_key_in_code` | package_specific_rules.dart |
| 131 | `require_openai_error_handling` | package_specific_rules.dart |
| 135 | `require_svg_error_handler` | package_specific_rules.dart |
| 136 | `require_google_fonts_fallback` | package_specific_rules.dart |
| 138 | `avoid_logging_sensitive_data` | security_rules.dart |
| 141 | `prefer_uuid_v4` | package_specific_rules.dart |

### Deferred to ROADMAP.md (36 rules)

The following rules require heuristic detection, cross-file analysis, or have vague detection criteria. See ROADMAP.md "Deferred: Package-Specific Rules (saropa)" section.

**Heuristic/"Logout" detection (7):** 84, 85, 87, 88, 93, 94, 95, 96, 99, 137
**"Check before use" patterns (12):** 91, 102, 103, 105, 107-115, 117, 119-126, 132-134, 142
**Cross-file analysis (5):** 91, 102, 128, 139, 140

---

## Summary

**Total remaining rules to implement: 82**

- Part 1 - Isar rules: 19
- Part 2 - Dispose patterns: 6
- Part 3 - Lifecycle rules: 5
- Part 4 - Missing parameters: 3
- Part 5 - API patterns: 10
- Part 6 - Additional: 10
- Part 7 - Newly identified: 29 (including 6 cross-file)
- ~~Part 8 - Package-specific (saropa): 0~~ *(21 implemented, 36 deferred to ROADMAP.md)*

**Already implemented: ~77 rules** (see reference section above)
**Deferred to ROADMAP.md: 36 rules** (heuristic/cross-file detection required)

---

## Implementation Priority

### Wave 1: Critical Safety (Rules 1-19)
All remaining Isar rules - prevent data corruption.

### Wave 2: Memory Leaks (Rules 20-25)
Remaining dispose patterns - prevent memory leaks.

### Wave 3: Lifecycle Bugs (Rules 26-30)
Widget lifecycle - prevent runtime crashes.

### Wave 4: Common Mistakes (Rules 31-33)
Missing parameters - improve UX.

### Wave 5: API Patterns (Rules 34-43)
Exact API matching - enforce best practices.

### Wave 6: Additional (Rules 44-53)
Remaining easy wins.

### Wave 7: Package-Specific (Rules 54-76)
Dio, GoRouter, Provider, Hive, SQLite, ImagePicker, Permissions, Geolocator, Notifications, Connectivity, URL Launcher.

### Wave 8: Cross-File (Rules 77-82)
Requires manifest/plist analysis - lower priority due to complexity.

### Wave 9: Authentication & Security (Rules 83-100)
Google Sign-In, Apple Sign-In, Supabase, WebView security.

### Wave 10: Platform Features (Rules 101-142)
WorkManager, Contacts, Calendar, Speech, IAP, Deep Links, Environment secrets, File handling.

---

## Notes

- Each rule should have comprehensive tests before merging
- See [CONTRIBUTING.md](CONTRIBUTING.md) for implementation guidelines
- Estimated effort: 1-3 hours per rule for these "easy" rules
- Cross-file rules (77-82) may require additional infrastructure for native config analysis
- Part 8 rules generated from real-world app analysis - high practical value
