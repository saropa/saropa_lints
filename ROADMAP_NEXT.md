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

### Additional Rules (5 implemented)
- `require_sqflite_whereargs` - file_handling_rules.dart
- `require_provider_dispose` - state_management_rules.dart
- `require_getx_controller_dispose` - state_management_rules.dart
- `avoid_shared_prefs_sensitive_data` - security_rules.dart

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

## Part 2: Dispose Pattern Rules (7 remaining)

Constructor + dispose pattern matching - detect resource creation without cleanup.

| # | Rule Name | Tier | Severity | Detection Pattern |
|---|-----------|------|----------|-------------------|
| 20 | `require_change_notifier_dispose` | Essential | ERROR | `ChangeNotifier` without `dispose()` |
| 21 | `require_web_socket_close` | Essential | ERROR | `WebSocket` without `close()` |
| 22 | `require_receive_port_close` | Essential | ERROR | `ReceivePort` without `close()` |
| 23 | `require_socket_close` | Essential | ERROR | `Socket` without `close()` |
| 24 | `require_debouncer_cancel` | Essential | ERROR | Debounce timer without `cancel()` |
| 25 | `require_interval_timer_cancel` | Essential | ERROR | `Timer.periodic` without `cancel()` (explicit periodic) |
| 26 | `require_file_handle_close` | Essential | WARNING | `RandomAccessFile` without `close()` |

---

## Part 3: Widget Lifecycle Rules (6 remaining)

Exact method/context pattern matching in StatefulWidget lifecycle.

| # | Rule Name | Tier | Severity | Detection Pattern |
|---|-----------|------|----------|-------------------|
| 27 | `avoid_context_in_init_state` | Essential | ERROR | `Theme.of(context)` in `initState` |
| 28 | `require_super_dispose_call` | Essential | ERROR | `dispose()` without `super.dispose()` |
| 29 | `require_super_init_state_call` | Essential | ERROR | `initState()` without `super.initState()` |
| 30 | `avoid_set_state_in_build` | Essential | ERROR | `setState` call inside `build()` |
| 31 | `avoid_set_state_in_dispose` | Essential | ERROR | `setState` call inside `dispose()` |
| 32 | `avoid_navigation_in_build` | Essential | ERROR | `Navigator.push` inside `build()` |

---

## Part 4: Missing Parameter Rules (4 remaining)

Detect required parameters that are frequently omitted.

| # | Rule Name | Tier | Severity | Detection Pattern |
|---|-----------|------|----------|-------------------|
| 33 | `require_provider_generic_type` | Essential | ERROR | `Provider.of(context)` without `<Type>` |
| 34 | `require_form_global_key` | Essential | ERROR | `Form` without `GlobalKey` |
| 35 | `require_text_form_field_in_form` | Essential | WARNING | `TextFormField` without `Form` ancestor |
| 36 | `require_webview_navigation_delegate` | Essential | WARNING | `WebView` without `navigationDelegate` |

---

## Part 5: Exact API Pattern Rules (14 remaining)

Direct API name or pattern matching with low false-positive risk.

| # | Rule Name | Tier | Severity | Detection Pattern |
|---|-----------|------|----------|-------------------|
| 37 | `require_flutter_riverpod_package` | Essential | ERROR | `riverpod` import without `flutter_riverpod` |
| 38 | `avoid_bloc_emit_after_close` | Essential | ERROR | `emit` without `isClosed` check in async |
| 39 | `avoid_bloc_state_mutation` | Essential | ERROR | `state.field = value` instead of `copyWith` |
| 40 | `require_bloc_initial_state` | Essential | ERROR | Bloc without `super(InitialState)` |
| 41 | `require_list_view_builder` | Essential | WARNING | `ListView(children:)` with >20 items |
| 42 | `avoid_single_child_scroll_view_list` | Essential | WARNING | `SingleChildScrollView` + `Column` for lists |
| 43 | `require_physics_for_nested_scroll` | Essential | WARNING | Nested scroll without `NeverScrollableScrollPhysics` |
| 44 | `avoid_opacity_widget_animation` | Essential | WARNING | `Opacity` widget in animated context |
| 45 | `require_animated_builder_child` | Essential | WARNING | `AnimatedBuilder` without `child` parameter |
| 46 | `avoid_empty_catch` | Essential | WARNING | Empty `catch` block |
| 47 | `require_rethrow_preserve_stack` | Essential | WARNING | `throw e` instead of `rethrow` |
| 48 | `require_https_over_http` | Essential | ERROR | `http://` URL in network calls |
| 49 | `require_wss_over_ws` | Essential | ERROR | `ws://` URL for WebSocket |
| 50 | `avoid_late_without_guarantee` | Essential | WARNING | `late` field without guaranteed init |

---

## Part 6: Additional Easy Rules (11 remaining)

More straightforward detection patterns.

| # | Rule Name | Tier | Severity | Detection Pattern |
|---|-----------|------|----------|-------------------|
| 51 | `require_secure_storage_auth_data` | Essential | ERROR | JWT in `SharedPreferences` instead of `flutter_secure_storage` |
| 52 | `avoid_freezed_json_serializable_conflict` | Essential | ERROR | Both `@freezed` and `@JsonSerializable` |
| 53 | `require_freezed_arrow_syntax` | Essential | ERROR | `fromJson` factory with block body |
| 54 | `require_freezed_private_constructor` | Essential | ERROR | Freezed methods without private constructor |
| 55 | `require_equatable_immutable` | Essential | ERROR | Non-final fields in `Equatable` |
| 56 | `require_equatable_props_override` | Essential | ERROR | `Equatable` without `props` getter |
| 57 | `require_equatable_all_fields_in_props` | Essential | WARNING | Fields missing from `props` list |
| 58 | `avoid_equatable_mutable_collections` | Essential | WARNING | Mutable `List`/`Map` in `Equatable` |
| 59 | `require_bloc_loading_state` | Recommended | INFO | Async handler without loading emission |
| 60 | `require_bloc_error_state` | Recommended | INFO | State sealed class without error case |
| 61 | `avoid_static_state` | Essential | WARNING | Static mutable state |

---

## Summary

**Total remaining rules to implement: 61**

- Isar rules: 19
- Dispose patterns: 7
- Lifecycle rules: 6
- Missing parameters: 4
- API patterns: 14
- Additional: 11

**Already implemented: ~46 rules** (see reference section above)

---

## Implementation Priority

### Wave 1: Critical Safety (Rules 1-19)
All remaining Isar rules - prevent data corruption.

### Wave 2: Memory Leaks (Rules 20-26)
Remaining dispose patterns - prevent memory leaks.

### Wave 3: Lifecycle Bugs (Rules 27-32)
Widget lifecycle - prevent runtime crashes.

### Wave 4: Common Mistakes (Rules 33-36)
Missing parameters - improve UX.

### Wave 5: API Patterns (Rules 37-50)
Exact API matching - enforce best practices.

### Wave 6: Additional (Rules 51-61)
Remaining easy wins.

---

## Notes

- Each rule should have comprehensive tests before merging
- See [CONTRIBUTING.md](CONTRIBUTING.md) for implementation guidelines
- Estimated effort: 1-3 hours per rule for these "easy" rules
