# Changelog

All notable changes to this project will be documented in this file.
The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

> **Looking for older changes?**  \
> See [CHANGELOG_ARCHIVE.md](./CHANGELOG_ARCHIVE.md) for versions 0.1.0 through 1.6.0.

## [2.1.0] - 2026-01-10

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

## [2.0.0] - 2026-01-10

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
- **`avoid_hooks_outside_build`**: Warns when Flutter hooks (use* functions) are called outside build methods
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

## [1.8.2] - 2026-01-10

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

## [1.8.1] - 2026-01-10

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

## [1.8.0] - 2026-01-10

### Changed
- **`avoid_double_for_money`**: **BREAKING** - Rule is now much stricter to eliminate false positives. Only flags unambiguous money terms: `price`, `money`, `currency`, `salary`, `wage`, and currency codes (`dollar`, `euro`, `yen`, `usd`, `eur`, `gbp`, `jpy`, `cad`, `aud`). Generic terms like `total`, `amount`, `balance`, `cost`, `fee`, `tax`, `discount`, `payment`, `revenue`, `profit`, `budget`, `expense`, `income` are **no longer flagged** as they have too many non-monetary uses.

### Fixed
- **`avoid_sensitive_data_in_logs`**: Fixed false positives for null checks and property access. Now only flags direct value interpolation (`$password`, `${password}`), not expressions like `${credential != null}`, `${password.length}`, or `${token?.isEmpty}`. Pre-compiled regex patterns for better performance.
- **`avoid_hardcoded_encryption_keys`**: Simplified rule to only detect string literals passed directly to `Key.fromUtf8()`, `Key.fromBase64()`, etc. - removes false positives from variable name heuristics

## [1.7.12] - 2026-01-10

### Fixed
- **`require_unique_iv_per_encryption`**: Improved IV variable name detection to avoid false positives like "activity", "private", "derivative" - now uses proper word boundary detection for camelCase and snake_case patterns

### Quick Fixes
- **`require_unique_iv_per_encryption`**: Auto-replaces `IV.fromUtf8`/`IV.fromBase64` with `IV.fromSecureRandom(16)`

## [1.7.11] - 2026-01-10

### Fixed
- **`avoid_shrinkwrap_in_scrollview`**: Rule now properly skips widgets with `NeverScrollableScrollPhysics` - the recommended fix should no longer trigger the lint
- **Test fixtures**: Updated fixture files with correct `expect_lint` annotations and disabled conflicting rules in example analysis_options.yaml

## [1.7.10] - 2026-01-10

### Fixed
- **Rule detection for implicit constructors**: Fixed `avoid_gradient_in_build`, `avoid_shrinkwrap_in_scrollview`, `avoid_nested_scrollables_conflict`, and `avoid_excessive_bottom_nav_items` rules not detecting widgets created without explicit `new`/`const` keywords
- **AST visitor pattern**: Rules now use `GeneralizingAstVisitor` or `addNamedExpression` callbacks to properly detect both explicit and implicit constructor calls
- **Test fixtures**: Updated expect_lint positions to match actual lint locations

### Changed
- **Rule implementation**: `AvoidGradientInBuildRule` now uses `GeneralizingAstVisitor` with both `visitInstanceCreationExpression` and `visitMethodInvocation`
- **Rule implementation**: `AvoidShrinkWrapInScrollViewRule` now uses `addNamedExpression` to detect `shrinkWrap: true` directly
- **Rule implementation**: `AvoidNestedScrollablesConflictRule` now uses visitor pattern with `RecursiveAstVisitor`
- **Rule implementation**: `AvoidExcessiveBottomNavItemsRule` now uses `addNamedExpression` to detect excessive items

## [1.7.9] - 2026-01-09

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

## [1.7.8] - 2026-01-09

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

## [1.7.7] - 2026-01-09

### Changed
- **Docs**: README now has a Limitations section clarifying Dart-only analysis and dependency_overrides behavior.

## [1.7.6] - 2026-01-09

### Added
- **Quick fix**: avoid_isar_enum_field auto-converts enum fields to string storage.

### Changed
- **Impact tuning**: avoid_isar_enum_field promoted to LintImpact.high.

### Fixed
- Restored NullabilitySuffix-based checks for analyzer compatibility.

## [1.7.5] - 2026-01-09

### Added
- **Opinionated severity**: Added LintImpact.opinionated.
- **New rule**: prefer_future_void_function_over_async_callback.
- **Configuration template**: Added example/analysis_options_template.yaml with 767+ rules.

### Fixed
- Empty block warnings in async callback fixture tests.

### Changed
- **Docs**: Updated counts to reflect 767+ rules.
- **Severity**: Stylistic rules moved to LintImpact.opinionated.

## [1.7.4] - 2026-01-08
- Updated the banner image to show the project name Saropa Lints.

## [1.7.3] - 2026-01-08

### Added
- **New documentation guides**: using_with_flutter_lints.md and migration_from_solid_lints.md.
- Added "Related Packages" section to VGA guide.

### Changed
- **Naming**: Standardized "Saropa Lints" vs saropa_lints across all docs.
- **Migration Guides**: Updated rules (766+), versions (^1.3.0), and tier counts.

## [1.7.2] - 2026-01-08

### Added
- **Impact Classification System**: Categorized rules by critical, high, medium, and low.
- **Impact Report CLI Tool**: dart run saropa_lints:impact_report for prioritized violation reporting.
- **47 New Rules**: Covering Riverpod, GetX, Bloc, Accessibility, Security, and Testing.
- **11 New Quick Fixes**.

## [1.7.1] - 2026-01-08

### Fixed
- Resolved 25 violations for curly_braces_in_flow_control_structures.

## [1.7.0] - 2026-01-08

### Added
- **50 New Rules**: Massive expansion across Riverpod, Build Performance, Testing, Security, and Forms.
- Added support for sealed events in Bloc.

---

## [1.6.0] and Earlier
For details on the initial release and versions 0.1.0 through 1.6.0, please refer to [CHANGELOG_ARCHIVE.md](./CHANGELOG_ARCHIVE.md).
