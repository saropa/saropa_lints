# Changelog

All notable changes to this project will be documented in this file.
The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

> **Looking for older changes?**  \
> See [CHANGELOG_ARCHIVE.md](./CHANGELOG_ARCHIVE.md) for versions 0.1.0 through 1.8.2.

## [2.3.2] - 2026-01-11

### Added

#### Image & Package-Specific Rules (5 rules)

**Image Picker Rules**
- **`prefer_image_picker_max_dimensions`**: Warns when `pickImage()` is called without `maxWidth`/`maxHeight` parameters - prevents OOM on high-resolution cameras (12-108MP). Quick fix available.

**Cached Network Image Rules**
- **`prefer_cached_image_fade_animation`**: Suggests explicitly setting `fadeInDuration` on CachedNetworkImage for intentional UX design (default is 500ms).

**URL Launcher Rules**
- **`require_url_launcher_mode`**: Warns when `launchUrl()` is called without `mode` parameter - behavior varies by platform without explicit mode.

**SQLite Database Rules**
- **`avoid_sqflite_read_all_columns`**: Warns when `SELECT *` is used in `rawQuery()` - wastes memory and bandwidth by fetching unnecessary columns.

**Notification Rules**
- **`require_notification_initialize_per_platform`**: Warns when `InitializationSettings` is missing `android:` or `iOS:` parameters - notifications fail silently on missing platforms. Quick fix available.

### Changed

- **Added aliases** to pre-existing rules:
  - `require_await_in_async` → alias for `avoid_redundant_async`
  - `avoid_riverpod_ref_in_dispose` → alias for `avoid_ref_inside_state_dispose`
  - `avoid_set_state_in_build` → alias for `avoid_setstate_in_build`

## [2.3.1] - 2026-01-11

### Changed

- **`pass_existing_future_to_future_builder`**: Merged `avoid_future_builder_rebuild` into this rule
  - Now detects inline futures anywhere (not just in build method)
  - Added `InstanceCreationExpression` detection (e.g., `Future.value()`)
  - Added alias note in documentation

- **`avoid_uncaught_future_errors`**: Improved false positive handling
  - Now skips functions that have internal try-catch error handling

- **`avoid_keyboard_overlap`**: Improved detection accuracy
  - Skips Dialog and BottomSheet widgets (Flutter handles keyboard overlap for these)
  - Changed to file-level viewInsets check (handles nested widget composition)

- **`require_webview_ssl_error_handling`**: Fixed callback name
  - Changed from `onSslError` to `onSslAuthError` (correct API for webview_flutter 4.0+)
  - Removed `onHttpAuthRequest` from check (different purpose: HTTP 401 auth, not SSL)

- **`require_apple_signin_nonce`**: Improved documentation with Supabase example

### Removed

- **`avoid_future_builder_rebuild`**: Merged into `pass_existing_future_to_future_builder`

## [2.3.0] - 2026-01-10

### Added

#### ROADMAP_NEXT Parts 1-7 Rules (11 new rules + ~70 rules registered in tiers)

**GoRouter Navigation Rules (2 rules)**
- **`prefer_go_router_redirect_auth`**: Suggests using redirect callback instead of auth checks in page builders
- **`require_go_router_typed_params`**: Warns when path parameters are used without type conversion

**Provider State Management Rules (2 rules)**
- **`avoid_provider_in_init_state`**: Warns when Provider.of or context.read/watch is used in initState
- **`prefer_context_read_in_callbacks`**: Suggests using context.read instead of context.watch in callbacks

**Hive Database Rules (1 rule)**
- **`require_hive_type_id_management`**: Warns when @HiveType typeId may conflict with others

**Image Picker Rules (1 rule)**
- **`require_image_picker_result_handling`**: Warns when pickImage result is not checked for null

**Cached Network Image Rules (1 rule)**
- **`avoid_cached_image_in_build`**: Warns when CachedNetworkImage uses variable cacheKey in build

**SQLite Migration Rules (1 rule)**
- **`require_sqflite_migration`**: Warns when onUpgrade callback doesn't check oldVersion

**Permission Handler Rules (3 rules)**
- **`require_permission_rationale`**: Suggests checking shouldShowRequestRationale before requesting permission
- **`require_permission_status_check`**: Warns when using permission-gated features without checking status
- **`require_notification_permission_android13`**: Warns when notifications shown without POST_NOTIFICATIONS permission

### Changed

- Registered ~70 existing rules from Parts 1-7 into appropriate tiers (Essential, Recommended, Professional)
- All Isar, Dispose, Lifecycle, Widget, API, and Package-Specific rules now properly included in tier system
- **`prefer_test_wrapper`**: Added to Recommended tier

### Fixed

- **`avoid_uncaught_future_errors`**: Reduced false positives significantly:
  - Now recognizes `.then(onError: ...)` as valid error handling
  - Skips `unawaited()` wrapped futures (explicit acknowledgment)
  - Skips `.ignore()` chained futures
  - Added 20+ safe fire-and-forget methods: analytics (`logEvent`, `trackEvent`), cache (`prefetch`, `warmCache`), cleanup (`dispose`, `drain`)
- **`require_stream_subscription_cancel`**: Fixed false positive for collection-based cancellation patterns. Now correctly recognizes `for (final sub in _subscriptions) { sub.cancel(); }` and `_subscriptions.forEach((s) => s.cancel())` patterns. Added support for LinkedHashSet and HashSet collection types. Improved loop variable validation to prevent false negatives. Added quick fix to insert cancel() calls (handles both single and collection subscriptions, creates dispose() if missing).
- **`prefer_test_wrapper`**: Fixed false positive for teardown patterns where `SizedBox`, `Container`, or `Placeholder` are pumped to unmount widgets before disposing controllers. Added quick fix to wrap with `MaterialApp`.
- **`missing_test_assertion`**: Fixed duplicate tier assignment (was in both Essential and Recommended). Now correctly only in Essential tier. Added quick fix to insert `expect()` placeholder.
- **`avoid_assigning_notifiers`**: Fixed missing visitor class causing compilation error. Added Riverpod import check to only apply to files using Riverpod. Added RHS type fallback for `late final` variables. Added quick fix to comment out problematic assignments. Documented in using_with_riverpod.md guide.
- **`require_api_timeout`**: Removed duplicate rule. Merged into `require_request_timeout` which has better logic (more HTTP methods, avoids apiClient false positives, handles await patterns). Old name kept as alias for migration.
- **tiers.dart**: Added 9 missing rules that were implemented but not registered:
  - `require_type_adapter_registration` → Essential (Hive adapter not registered)
  - `require_hive_database_close` → Professional (database resource leak)
  - `prefer_lazy_box_for_large` → Professional (Hive memory optimization)
  - `prefer_http_connection_reuse` → Professional (network performance)
  - `avoid_redundant_requests` → Professional (resource efficiency)
  - `prefer_pagination` → Professional (memory efficiency)
  - `require_cancel_token` → Professional (cancel on dispose)
  - `require_response_caching` → Comprehensive (opinionated)
  - `avoid_over_fetching` → Comprehensive (opinionated)
- **test_rules.dart**: Added 7 test rules to tiers that were registered but never enabled:
  - `prefer_descriptive_test_name` → Professional
  - `prefer_fake_over_mock` → Professional
  - `require_edge_case_tests` → Professional
  - `avoid_test_implementation_details` → Professional
  - `prefer_test_data_builder` → Professional
  - `prefer_test_variant` → Professional
  - `require_animation_tests` → Professional
- **`avoid_uncaught_future_errors`**: Fixed false positives for awaited futures. Rule now only flags fire-and-forget futures (unawaited calls). Merged duplicate `require_future_error_handling` rule into this one (old name kept as alias). Added exceptions for `dispose()` methods, `cancel()`/`close()` methods, and futures inside try blocks. Added quick fix to add `.catchError()`.
- **`require_test_cleanup`**: Fixed false positives from generic substring matching. Now uses specific patterns to avoid matching `createWidget()`, `insertText()`, `output()` and similar unrelated methods. Only flags actual File/Directory operations, database inserts, and Hive box operations.
- **`require_pump_after_interaction`**: Fixed indexOf logic that only checked first interaction occurrence. Now tracks ALL interaction positions and checks each segment for proper pump() placement between interactions and expects.
- **`prefer_test_data_builder`**: Added null check for `name2` token access to prevent runtime errors on complex type constructs.
- **`require_hive_initialization`**: Changed LintImpact from medium to low since this is an informational heuristic that cannot verify cross-file initialization.
- **hive_rules.dart**: Extracted shared `_isHiveBoxTarget()` and `_isHiveBoxField()` utilities to reduce duplication and improve box detection accuracy. Now uses word boundary matching to avoid false positives like 'infobox' or 'checkbox'.
- **`require_error_identification`**: Fixed false positives from substring matching `.contains('red')`. Now uses regex pattern matching (`colors\.red`, `.red\b`, etc.) to avoid matching words like 'thread', 'spread', 'shredded'.
- **api_network_rules.dart**: Added import validation for package-specific rules to prevent false positives:
  - `avoid_dio_debug_print_production`: Now checks for Dio import and uses type-based detection for LogInterceptor
  - `require_geolocator_timeout`: Only applies to files importing geolocator package
  - `require_connectivity_subscription_cancel`: Only applies to files importing connectivity_plus package
  - `require_notification_handler_top_level`: Only applies to files importing firebase_messaging package
  - `require_permission_denied_handling`: Only applies to files importing permission_handler package; uses AST-based property access detection instead of string contains
- **navigation_rules.dart**: Added import validation for all go_router rules to prevent false positives in projects not using go_router:
  - `avoid_go_router_inline_creation`
  - `require_go_router_error_handler`
  - `require_go_router_refresh_listenable`
  - `avoid_go_router_string_paths`
  - `prefer_go_router_redirect_auth`
  - `require_go_router_typed_params`
- **state_management_rules.dart**: Fixed `prefer_context_read_in_callbacks` rule to properly detect Flutter callback conventions. Now checks for `on` prefix followed by uppercase letter (e.g., `onPressed`, `onTap`) to avoid false positives on words like `once`, `only`, `ongoing`.
- **import_utils.dart**: New shared utility file for package import validation. Provides `fileImportsPackage()` function and `PackageImports` constants for Dio, Geolocator, Connectivity, Firebase Messaging, Permission Handler, GoRouter, Riverpod, Hive, GetIt, Provider, Bloc, and more. Reduces code duplication across rule files.

## [2.2.0] - 2026-01-10

### Added

#### Pubspec Analyzer Script

- **`scripts/analyze_pubspec.py`**: Python script that analyzes a Flutter project's `pubspec.yaml` and recommends the optimal saropa_lints tier based on packages used. Features:
  - Recommends tier (essential/recommended/professional/comprehensive/insanity) based on dependencies
  - Shows package-specific rules that will be active for your packages
  - Identifies packages not yet covered by saropa_lints
  - Outputs JSON report with detailed analysis
  - Usage: `python scripts/analyze_pubspec.py <path_to_pubspec.yaml>`

#### Package-Specific Rules (19 rules)

**Authentication Rules (3 rules)**
- **`require_google_signin_error_handling`**: Warns when `signIn()` call lacks try-catch error handling
- **`require_apple_signin_nonce`**: Warns when Apple Sign-In is missing `rawNonce` parameter - security requirement
- **`avoid_openai_key_in_code`**: Warns when OpenAI API key pattern (`sk-...`) appears in source code

**Supabase Rules (3 rules)**
- **`require_supabase_error_handling`**: Warns when Supabase client calls lack try-catch error handling
- **`avoid_supabase_anon_key_in_code`**: Warns when Supabase anon key appears hardcoded in source
- **`require_supabase_realtime_unsubscribe`**: Warns when Supabase realtime channel lacks unsubscribe in dispose

**WebView Security Rules (2 rules)**
- **`require_webview_ssl_error_handling`**: Warns when WebView lacks `onSslError` handler
- **`avoid_webview_file_access`**: Warns when WebView has `allowFileAccess: true` enabled

**WorkManager Rules (2 rules)**
- **`require_workmanager_constraints`**: Warns when WorkManager task lacks network/battery constraints
- **`require_workmanager_result_return`**: Warns when WorkManager callback doesn't return TaskResult

**Dispose Pattern Rules (3 rules)**
- **`require_keyboard_visibility_dispose`**: Warns when KeyboardVisibilityController subscription not disposed
- **`require_speech_stop_on_dispose`**: Warns when SpeechToText instance not stopped in dispose
- **`require_calendar_timezone_handling`**: Warns when calendar events lack time zone handling

**Deep Linking & Security Rules (3 rules)**
- **`avoid_app_links_sensitive_params`**: Warns when deep link URLs contain sensitive parameters (token, password)
- **`require_envied_obfuscation`**: Warns when @Envied annotation lacks `obfuscate: true`
- **`require_openai_error_handling`**: Warns when OpenAI API calls lack error handling

**UI Component Rules (3 rules)**
- **`require_svg_error_handler`**: Warns when SvgPicture lacks `errorBuilder` parameter
- **`require_google_fonts_fallback`**: Warns when GoogleFonts lacks `fontFamilyFallback`
- **`prefer_uuid_v4`**: Suggests using UUID v4 over v1 for better randomness

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

## [1.8.2] and Earlier
For details on the initial release and versions 0.1.0 through 1.6.0, please refer to [CHANGELOG_ARCHIVE.md](./CHANGELOG_ARCHIVE.md).
