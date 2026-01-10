# Implementation Plan: Next 59 Rules

Rules in tiers.dart that need implementation.

---

## Recommended Tier (4 rules - from previous list)

| Rule | Target File | Impact | Detection |
|------|-------------|--------|-----------|
| `require_image_loading_placeholder` | image_rules.dart | medium | `Image.network` without `loadingBuilder` or `frameBuilder` |
| `require_location_timeout` | bluetooth_hardware_rules.dart | high | `Geolocator.getCurrentPosition` without `timeLimit` |
| `avoid_motion_without_reduce` | accessibility_rules.dart | medium | AnimatedX widget without `MediaQuery.disableAnimations` check |
| `require_refresh_indicator_on_lists` | scroll_rules.dart | medium | ListView/GridView without RefreshIndicator ancestor |

## Professional Tier (5 rules - from previous list)

| Rule | Target File | Impact | Detection |
|------|-------------|--------|-----------|
| `prefer_firestore_batch_write` | firebase_rules.dart | medium | 3+ sequential Firestore writes in same method |
| `require_animation_status_listener` | animation_rules.dart | medium | AnimationController without `addStatusListener` |
| `avoid_touch_only_gestures` | architecture_rules.dart | medium | GestureDetector without `onSecondaryTap`/hover |
| `require_test_cleanup` | test_rules.dart | medium | Test with File.create without tearDown |
| `require_accessibility_tests` | test_rules.dart | high | Widget test file without `meetsGuideline` |

---

## NEW: 50 Easy-to-Implement Rules

### Group A: Missing Parameter Detection (12 rules)

Simple detection: Constructor/method call without required parameter.

| Rule | Target File | Tier | Detection |
|------|-------------|------|-----------|
| `require_dark_mode_testing` | theming_rules.dart | Essential | `MaterialApp` without `darkTheme` parameter |
| `prefer_camera_resolution_selection` | media_rules.dart | Recommended | `CameraController` without `ResolutionPreset` |
| `require_crashlytics_user_id` | firebase_rules.dart | Professional | `FirebaseCrashlytics.instance` without `.setUserIdentifier()` |
| `require_firebase_app_check` | firebase_rules.dart | Professional | Firebase usage without `AppCheck.instance.activate()` |
| `require_should_rebuild` | flutter_widget_rules.dart | Professional | InheritedWidget without `updateShouldNotify` override |
| `prefer_audio_session_config` | media_rules.dart | Professional | `AudioPlayer.play()` without audio session config |
| `require_pagination_loading_state` | scroll_rules.dart | Recommended | Paginated list without loading state indicator |
| `require_empty_results_state` | ui_ux_rules.dart | Recommended | Search results without empty state handling |
| `require_search_loading_indicator` | ui_ux_rules.dart | Recommended | Search trigger without loading state |
| `prefer_adaptive_dialog` | dialog_snackbar_rules.dart | Comprehensive | `showDialog` without platform-adaptive styling |
| `require_snackbar_action_for_undo` | dialog_snackbar_rules.dart | Recommended | Delete operation with SnackBar without action |
| `prefer_skeleton_over_spinner` | ui_ux_rules.dart | Recommended | `CircularProgressIndicator` for content loading |

### Group B: Exact Method Call Detection (10 rules)

Simple detection: Specific method/function call that should be avoided or replaced.

| Rule | Target File | Tier | Detection |
|------|-------------|------|-----------|
| `avoid_yield_in_on_event` | state_management_rules.dart | Professional | `yield` keyword in Bloc `on<Event>` handler |
| `prefer_consumer_over_provider_of` | state_management_rules.dart | Recommended | `Provider.of<T>(context)` in build method |
| `avoid_listen_in_async` | state_management_rules.dart | Essential | `context.watch()` inside async callback |
| `prefer_getx_builder` | state_management_rules.dart | Recommended | `.obs` property access without `Obx` wrapper |
| `avoid_any_version` | pubspec_rules.dart | Essential | `any` version constraint in dependencies |
| `prefer_publish_to_none` | pubspec_rules.dart | Recommended | Private package without `publish_to: none` |
| `prefer_semver_version` | pubspec_rules.dart | Essential | Version not matching `x.y.z` format |
| `prefer_caret_version_syntax` | pubspec_rules.dart | Stylistic | Version constraint without `^` prefix |
| `avoid_dependency_overrides` | pubspec_rules.dart | Recommended | `dependency_overrides` without comment explaining why |
| `prefer_correct_package_name` | pubspec_rules.dart | Essential | Package name not matching Dart conventions |

### Group C: Pattern Detection (10 rules)

Detectable via AST patterns in same file.

| Rule | Target File | Tier | Detection |
|------|-------------|------|-----------|
| `emit_new_bloc_state_instances` | state_management_rules.dart | Professional | `emit(state..property = x)` mutation pattern |
| `avoid_bloc_public_fields` | state_management_rules.dart | Professional | Public non-final fields in Bloc class |
| `avoid_bloc_public_methods` | state_management_rules.dart | Professional | Public methods other than `add()` in Bloc |
| `prefer_inherited_widget_cache` | performance_rules.dart | Professional | Multiple `.of(context)` same type in method |
| `require_async_value_order` | state_management_rules.dart | Recommended | AsyncValue.when with data/error/loading wrong order |
| `avoid_storing_user_data_in_auth` | firebase_rules.dart | Recommended | `setCustomClaims()` with object > 1000 bytes |
| `prefer_dot_shorthand` | code_quality_rules.dart | Recommended | `EnumType.value` where `.value` context allows |
| `prefer_null_aware_elements` | collection_rules.dart | Recommended | Collection without `?element` for nullable items |
| `avoid_websocket_without_heartbeat` | api_network_rules.dart | Professional | WebSocketChannel without periodic ping |
| `require_orientation_handling` | flutter_widget_rules.dart | Recommended | App without orientation lock or OrientationBuilder |

### Group D: Widget/Constructor Detection (8 rules)

Detect specific widget patterns that indicate issues.

| Rule | Target File | Tier | Detection |
|------|-------------|------|-----------|
| `require_exif_handling` | image_rules.dart | Professional | `Image.file` without EXIF orientation handling |
| `avoid_keyboard_overlap` | forms_rules.dart | Essential | TextField in bottom without viewInsets handling |
| `prefer_layout_builder_over_media_query` | performance_rules.dart | Professional | `MediaQuery.of` in ListView item |
| `avoid_elevation_opacity_in_dark` | theming_rules.dart | Professional | Card/Material elevation without brightness check |
| `prefer_theme_extensions` | theming_rules.dart | Professional | ThemeData with custom color fields outside extensions |
| `require_search_debounce` | ui_ux_rules.dart | Essential | TextField.onChanged with network call without delay |
| `avoid_work_in_paused_state` | lifecycle_rules.dart | Professional | Timer without AppLifecycleState check |
| `require_resume_state_refresh` | lifecycle_rules.dart | Recommended | WidgetsBindingObserver without handling `resumed` |

### Group E: Security Rules (5 rules)

Exact API detection for security issues.

| Rule | Target File | Tier | Detection |
|------|-------------|------|-----------|
| `require_url_validation` | security_rules.dart | Essential | `Uri.parse()` on user input without scheme validation |
| `require_content_type_check` | api_network_rules.dart | Professional | HTTP response parsing without Content-Type check |
| `avoid_redirect_injection` | security_rules.dart | Essential | Redirect URL from parameter without domain check |
| `avoid_external_storage_sensitive` | security_rules.dart | Essential | `getExternalStorageDirectory` with sensitive data |
| `prefer_local_auth` | security_rules.dart | Professional | Payment/sensitive operation without biometric check |

### Group F: Additional Easy Rules (5 rules)

| Rule | Target File | Tier | Detection |
|------|-------------|------|-----------|
| `require_bloc_selector` | state_management_rules.dart | Recommended | BlocBuilder that only uses one field from state |
| `prefer_selector` | state_management_rules.dart | Professional | `context.watch<T>()` without `.select()` |
| `require_getx_binding` | state_management_rules.dart | Professional | GetxController without Binding registration |
| `prefer_iterable_operations` | collection_rules.dart | Professional | `.map().where().toList()` when lazy would suffice |
| `require_web_renderer_awareness` | flutter_widget_rules.dart | Professional | `kIsWeb` without checking renderer type |

---

## Implementation Priority

### Phase 1: Pubspec Rules (6 rules) - NEW FILE
Quick wins, simple string/pattern matching in YAML.

1. `avoid_any_version`
2. `prefer_publish_to_none`
3. `prefer_semver_version`
4. `prefer_caret_version_syntax`
5. `avoid_dependency_overrides`
6. `prefer_correct_package_name`

### Phase 2: State Management Rules (10 rules) - EXTEND EXISTING
Add to state_management_rules.dart.

1. `avoid_yield_in_on_event`
2. `prefer_consumer_over_provider_of`
3. `avoid_listen_in_async`
4. `prefer_getx_builder`
5. `emit_new_bloc_state_instances`
6. `avoid_bloc_public_fields`
7. `avoid_bloc_public_methods`
8. `require_async_value_order`
9. `require_bloc_selector`
10. `prefer_selector`

### Phase 3: Firebase Rules (3 rules) - EXTEND EXISTING
Add to firebase_rules.dart.

1. `require_crashlytics_user_id`
2. `require_firebase_app_check`
3. `avoid_storing_user_data_in_auth`

### Phase 4: Theming Rules (3 rules) - NEW FILE
Create theming_rules.dart.

1. `require_dark_mode_testing`
2. `avoid_elevation_opacity_in_dark`
3. `prefer_theme_extensions`

### Phase 5: UI/UX Rules (4 rules) - EXTEND EXISTING
Add to ui_ux_rules.dart.

1. `prefer_skeleton_over_spinner`
2. `require_empty_results_state`
3. `require_search_loading_indicator`
4. `require_search_debounce`

### Phase 6: Lifecycle Rules (2 rules) - NEW FILE
Create lifecycle_rules.dart.

1. `avoid_work_in_paused_state`
2. `require_resume_state_refresh`

### Phase 7: Remaining Rules (22 rules)
Spread across existing files.

---

## Checklist

### Before Each Rule
- [ ] Verify not already implemented (check all_rules.dart)
- [ ] Confirm tier assignment in tiers.dart

### After Each Rule
- [ ] Add BAD/GOOD examples in doc header
- [ ] Set correct LintImpact
- [ ] Add to all_rules.dart
- [ ] Create fixture in example/lib/
- [ ] Update CHANGELOG.md

### After All Rules
- [ ] Update README rule count
- [ ] Update pubspec.yaml version

---

## Detection Pattern Reference

### Pattern 1: Missing Parameter
```dart
// Detect: Constructor call without specific named parameter
context.registry.addInstanceCreationExpression((node) {
  if (node.staticType?.element?.name == 'MaterialApp') {
    final hasParam = node.argumentList.arguments.any(
      (arg) => arg is NamedExpression && arg.name.label.name == 'darkTheme',
    );
    if (!hasParam) reporter.atNode(node, code);
  }
});
```

### Pattern 2: Method Call Detection
```dart
// Detect: Specific method call
context.registry.addMethodInvocation((node) {
  if (node.methodName.name == 'print') {
    reporter.atNode(node, code);
  }
});
```

### Pattern 3: Missing Method in Class
```dart
// Detect: Class missing expected method
context.registry.addClassDeclaration((node) {
  if (extendsClass(node, 'InheritedWidget')) {
    final hasMethod = node.members.any((m) =>
      m is MethodDeclaration && m.name.lexeme == 'updateShouldNotify');
    if (!hasMethod) reporter.atNode(node, code);
  }
});
```

### Pattern 4: Keyword in Context
```dart
// Detect: yield keyword in Bloc handler
context.registry.addYieldStatement((node) {
  if (isInsideBlocHandler(node)) {
    reporter.atNode(node, code);
  }
});
```
