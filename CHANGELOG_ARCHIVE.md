# Changelog Archive

Archived releases 0.1.0 through 2.3.8. See [CHANGELOG.md](./CHANGELOG.md) for the latest versions.

---

## [2.3.8] - 2026-01-11

### Fixed

- **`require_sse_subscription_cancel`**: Fixed false positives for field names like `addressesFuture` or `hasSearched` that contain "sse" substring. Now uses word-boundary regex `(^|_)sse($|_|[A-Z])` on the original (case-preserved) field name to correctly detect camelCase patterns like `sseClient` while avoiding false matches.
- **`avoid_shrink_wrap_expensive`**: No longer warns when `physics: NeverScrollableScrollPhysics()` is used. This is an intentional pattern for nested non-scrolling lists inside another scrollable.
- **`avoid_redirect_injection`**: Fixed false positives for object property access like `item.destination`. Now uses AST node type checking (`PropertyAccess`, `PrefixedIdentifier`) to skip property access patterns, and checks for custom object types when type info is available.
- **`use_setstate_synchronously`**: Fixed false positives in async lambda callbacks. Now skips nested `FunctionExpression` nodes (they have their own async context) and checks for ancestor mounted guards before reporting.

### Changed

- **Formatting**: Applied consistent code formatting to api_network_rules.dart (cosmetic only, no behavior change)

---

## [2.3.7] - 2026-01-11

### Added

#### Scroll & List Performance Rules (5 rules)
- **`avoid_shrink_wrap_expensive`**: Warns when `shrinkWrap: true` is used in expensive scroll contexts
- **`prefer_item_extent`**: Suggests setting `itemExtent` for uniform ListView items
- **`prefer_prototype_item`**: Suggests using `prototypeItem` for consistent list item sizing
- **`require_key_for_reorderable`**: Requires unique keys for ReorderableListView items (ERROR)
- **`require_add_automatic_keep_alives_off`**: Suggests disabling keep-alives for long lists

#### Accessibility Rules (3 rules)
- **`require_semantic_label_icons`**: Requires `semanticLabel` on Icon widgets (WARNING)
- **`require_accessible_images`**: Requires accessibility attributes on images (WARNING)
- **`avoid_auto_play_media`**: Warns against auto-playing media without user control

#### Form UX Rules (3 rules)
- **`require_form_auto_validate_mode`**: Suggests setting `autovalidateMode` on Forms
- **`require_autofill_hints`**: Suggests `autofillHints` for better autofill support
- **`prefer_on_field_submitted`**: Suggests handling field submission for form navigation

#### Equatable & Freezed Rules (5 rules)
- **`prefer_equatable_stringify`**: Suggests enabling `stringify: true` on Equatable
- **`prefer_immutable_annotation`**: Suggests `@immutable` annotation on Equatable classes
- **`require_freezed_explicit_json`**: Warns when Freezed lacks `explicit_to_json` for nested objects
- **`prefer_freezed_default_values`**: Suggests using `@Default` annotation
- **`prefer_record_over_equatable`**: Suggests Dart 3 records for simple value types

#### Boolean & Control Flow Rules (1 rule)
- **`prefer_simpler_boolean_expressions`**: Detects boolean expressions simplifiable via De Morgan's laws

#### Dispose Pattern Rules (9 rules)
- **`require_bloc_manual_dispose`**: Warns when Bloc controllers lack cleanup
- **`require_getx_worker_dispose`**: Warns when GetX Workers lack `onClose` cleanup
- **`require_getx_permanent_cleanup`**: Warns about permanent GetX instances
- **`require_animation_ticker_disposal`**: Requires Ticker `stop()` in dispose (ERROR)
- **`require_image_stream_dispose`**: Warns when ImageStream listeners not removed
- **`require_sse_subscription_cancel`**: Requires EventSource `close()` (ERROR)
- **`avoid_stream_subscription_in_field`**: Warns when subscriptions aren't stored for cancellation
- **`require_dispose_implementation`**: Warns when StatefulWidget with resources lacks `dispose()`
- **`prefer_dispose_before_new_instance`**: Warns when disposable fields are reassigned without cleanup

#### Type Safety Rules (6 rules)
- **`avoid_unrelated_type_casts`**: Detects casts between unrelated types (ERROR)
- **`avoid_dynamic_json_access`**: Warns against chained JSON access without null checks
- **`require_null_safe_json_access`**: Requires null check before JSON key access (ERROR)
- **`avoid_dynamic_json_chains`**: Warns against deeply chained JSON access (ERROR)
- **`require_enum_unknown_value`**: Requires fallback for enum parsing from API
- **`require_validator_return_null`**: Requires form validators to return null for valid input (ERROR)

#### Widget Replacement & State Management Rules (6 rules)
- **`prefer_selector_over_consumer`**: Suggests Selector for granular Provider rebuilds
- **`prefer_cubit_for_simple_state`**: Suggests Cubit for single-event Blocs
- **`prefer_bloc_listener_for_side_effects`**: Detects side effects in BlocBuilder
- **`require_bloc_consumer_when_both`**: Suggests BlocConsumer for nested listener+builder
- **`prefer_proxy_provider`**: Suggests ProxyProvider for dependent providers
- **`require_update_callback`**: Warns when ProxyProvider update callback is unused

#### Navigation & Debug Rules (3 rules)
- **`prefer_maybe_pop`**: Suggests `maybePop()` instead of `pop()` for route safety
- **`prefer_go_router_extra_typed`**: Warns against untyped `extra` parameter in go_router
- **`prefer_debugPrint`**: Suggests `debugPrint` instead of `print` for throttling

#### Code Quality Rules (2 rules)
- **`prefer_late_final`**: Suggests `late final` for singly-assigned late variables
- **`avoid_late_for_nullable`**: Warns against `late` for nullable types

#### WebView Security Rules (4 rules)
- **`prefer_webview_javascript_disabled`**: Warns when JavaScript enabled without justification
- **`avoid_webview_insecure_content`**: Warns against allowing mixed content (ERROR)
- **`require_webview_error_handling`**: Requires `onWebResourceError` handler
- **`require_webview_progress_indicator`**: Suggests progress indicator for WebViews

#### Image Picker Rules (2 rules)
- **`prefer_image_picker_request_full_metadata`**: Suggests disabling full metadata when not needed
- **`avoid_image_picker_large_files`**: Warns when `imageQuality` not set for compression

#### Package-Specific Rules (7 rules)
- **`avoid_graphql_string_queries`**: Warns against raw GraphQL query strings
- **`prefer_ble_mtu_negotiation`**: Suggests MTU negotiation for large BLE transfers
- **`avoid_loading_full_pdf_in_memory`**: Warns against loading large PDFs entirely (WARNING)
- **`require_qr_content_validation`**: Requires validation of QR code content (WARNING)
- **`require_notification_timezone_awareness`**: Suggests `TZDateTime` for scheduled notifications
- **`require_intl_locale_initialization`**: Warns when Intl locale not initialized
- **`prefer_geolocator_distance_filter`**: Suggests `distanceFilter` to reduce GPS battery drain

#### Firebase Rules (1 rule)
- **`prefer_firebase_auth_persistence`**: Suggests explicit persistence setting on web

#### GetX Rules (1 rule)
- **`avoid_getx_context_outside_widget`**: Warns against GetX context access outside widgets

#### Stylistic Rules (1 rule)
- **`arguments_ordering`**: Enforces consistent ordering of function arguments

### Fixed

- **`prefer_late_final`**: Now correctly counts inline initializers and only flags fields assigned exactly once (not zero times)
- **`require_qr_content_validation`**: Added explicit parentheses to fix operator precedence in validation check

## [2.3.6] - 2026-01-11

### Fixed

- **CI/CD**: Reverted example project to pure Dart (no Flutter SDK dependency) to fix CI failures caused by `dart pub get` requiring Flutter SDK
- **ROADMAP cleanup**: Removed 72 entries from ROADMAP.md that were already implemented (14 as aliases, 58 as rules)

### Added

- **flutter_mocks.dart**: Created comprehensive mock Flutter types (~490 lines) for lint rule testing without Flutter SDK:
  - Core types: `Widget`, `StatelessWidget`, `StatefulWidget`, `State`, `BuildContext`
  - Layout widgets: `Container`, `SizedBox`, `Padding`, `Align`, `Center`, `Column`, `Row`
  - Material widgets: `Scaffold`, `ElevatedButton`, `TextField`, `TabBar`, `AlertDialog`, `SnackBar`
  - Controllers: `TextEditingController`, `TabController`, `PageController`, `FocusNode`
  - Provider mocks: `Provider`, `MultiProvider`, `ChangeNotifierProvider`
  - BLoC mocks: `Bloc`, `BlocProvider`, `MultiBlocProvider`
- **scripts/audit_rules.py**: New script to audit implemented rules against ROADMAP entries
  - Detects rules that are already implemented (as rules or aliases)
  - Finds near-matches that may need aliases added
  - Features colorful output with Saropa ASCII logo
  - Returns exit code 1 if duplicates found for CI integration

### Changed

- Updated 12 fixture files to import `flutter_mocks.dart` instead of Flutter/external packages
- **prefer_dedicated_media_query_method**: Added alias `prefer_dedicated_media_query_methods`

## [2.3.5] - 2026-01-11

### Fixed

- **use_setstate_synchronously**: Fixed false positive for nested mounted checks (e.g., `if (mounted) { setState(...) }` inside callbacks or try blocks). Now properly traverses the AST to find protecting mounted checks in ancestor chain. Also handles `if (!mounted) return;` guard pattern correctly.
- **avoid_redirect_injection**: Fixed false positive for non-URL types. Now only flags `String`, `Uri`, or `dynamic` arguments, skipping object types like `AppGridMenuItem` that happen to have "destination" in their name.
- **avoid_keyboard_overlap**: Fixed false positive for dialogs and `Scrollable.ensureVisible`. Added checks for: class names containing "Dialog", file paths containing "dialog", files containing `showDialog`/`showDialogCommon` calls, and files using `ensureVisible`.
- **avoid_hardcoded_encryption_keys**: Added support for named constructors (e.g., `Key.fromUtf8(...)`, `Key.fromBase64(...)`) in addition to static method calls. The `encrypt` package uses named constructors.
- **Documentation**: Fixed unresolved doc references (`[...]` in scroll_rules.dart and `[Ticker]` in animation_rules.dart) by wrapping in backticks
- **Test fixtures**: Fixed 45 `unfulfilled_expect_lint` errors in example fixtures:
  - Fixed `// expect_lint` comment placement (must be directly before flagged line)
  - Enabled rules from higher tiers in example/analysis_options.yaml for testing
  - Removed expect_lint from commented-out code blocks

### Changed

- **example/analysis_options.yaml**: Explicitly enabled all tested rules regardless of tier

### Added

- **Quick fixes for 4 rules:**
  - `use_setstate_synchronously`: Wraps setState in `if (mounted) { ... }` check
  - `avoid_redirect_injection`: Adds comment for manual domain validation
  - `avoid_keyboard_overlap`: Adds comment for manual keyboard handling
  - `avoid_hardcoded_encryption_keys`: Adds comment for secure key loading

## [2.3.4] - 2026-01-11

### Fixed

- **avoid_dialog_context_after_async**: Fixed `RangeError` crash when analyzing files where `toSource()` produces a different length string than the original source
- **avoid_set_state_after_async**: Fixed the same `RangeError` in `_hasAwaitBefore` method

## [2.3.3] - 2026-01-11

### Changed

- **ENTERPRISE.md → PROFESSIONAL_SERVICES.md**: Renamed and restructured with New Projects / Upgrade / Audit service framework
- **README.md**: Added adoption strategy paragraph; updated documentation links
- **PROFESSIONAL_SERVICES.md**: Consolidated phased approach into Upgrade section; removed redundant adoption section
- **CONTRIBUTING.md**: Added rule prohibiting TODO comments as quick fixes
- **41 rules**: Updated doc headers to explain "**Manual fix required:**" for issues requiring human judgment
- **62 quick fixes**: Converted remaining `// TODO:` comments to `// HACK:` comments to avoid triggering the `todo` analyzer diagnostic

### Improved

**Converted 25+ TODO quick fixes to real automated fixes:**

- **complexity_rules.dart**: `AvoidCascadeAfterIfNullRule` now wraps `??` in parentheses
- **equality_rules.dart**: `AvoidSelfAssignmentRule` now comments out the statement
- **structure_rules.dart**:
  - Double slash imports now get the extra slash removed
  - Duplicate exports/imports/mixins now get commented out
  - Mutable globals now get `final` keyword added
- **type_rules.dart**:
  - Implicitly nullable extensions now get `implements Object` added
  - Nullable interpolations now get `?? ''` added
  - Nullable params with defaults now get `?` removed
- **exception_rules.dart**:
  - Non-final fields now get `final` keyword added
  - Pointless rethrows now get try-catch commented out
  - Throw in catch now gets replaced with `rethrow`
- **async_rules.dart**:
  - Future.ignore() now gets wrapped with `unawaited()`
  - Unassigned subscriptions now get assigned to `final _ =`
- **control_flow_rules.dart**: Collapsible if statements now get combined with `&&`
- **performance_rules.dart**: setState in build now gets wrapped in `addPostFrameCallback`
- **collection_rules.dart**: Collection equality now gets wrapped with `DeepCollectionEquality().equals()`
- **testing_best_practices_rules.dart**: Future.delayed now gets replaced with `tester.pumpAndSettle()`
- **test_rules.dart**: GetIt tests now get `GetIt.I.reset()` added to setUp
- **package_specific_rules.dart**:
  - File access now sets `allowFileAccess: false`
  - Envied now gets `obfuscate: true` parameter
  - Image picker now gets `maxWidth`/`maxHeight` parameters
  - API calls now get wrapped in try-catch
  - Calendar events now get `timeZone: tz.local` parameter

### Removed

- **41 TODO quick fixes**: Removed quick fixes that only added TODO comments (these just created noise by triggering the `todo` lint rule)

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

## [1.6.0] - 2026-01-07

### Added

- **18 new lint rules** across 7 categories:

  **Animation Rules (4)**:
  - `avoid_hardcoded_duration` - Duration literals should be extracted to named constants for consistency [Info tier]
  - `require_animation_curve` - Animations without curves feel robotic; use CurvedAnimation [Info tier]
  - `prefer_implicit_animations` - Simple transitions (fade, scale) should use AnimatedOpacity etc. [Info tier]
  - `require_staggered_animation_delays` - List item animations should use Interval for cascade effect [Info tier]

  **Widget/UI Rules (4)**:
  - `avoid_fixed_dimensions` - Fixed pixel dimensions >200px break on different screen sizes [Info tier]
  - `require_theme_color_from_scheme` - Hardcoded Color/Colors.* breaks theming [Info tier]
  - `prefer_color_scheme_from_seed` - Manual ColorScheme is error-prone; use fromSeed() [Info tier]
  - `prefer_rich_text_for_complex` - 3+ Text widgets in Row should use Text.rich [Info tier]

  **Forms Rules (1)**:
  - `require_error_message_context` - Generic validator messages like "Invalid" lack context [Info tier]

  **Storage Rules (1)**:
  - `avoid_prefs_for_large_data` - SharedPreferences is for small settings, not collections [Warning tier]

  **Network/API Rules (1)**:
  - `require_offline_indicator` - Connectivity checks without UI feedback confuse users [Info tier]

  **Resource Management Rules (3)**:
  - `require_camera_dispose` - CameraController must be disposed to release hardware [Error tier]
  - `require_image_compression` - Camera images should use maxWidth/maxHeight/imageQuality [Info tier]
  - `prefer_coarse_location_when_sufficient` - High GPS accuracy drains battery unnecessarily [Info tier]

  **State Management Rules (2)**:
  - `prefer_cubit_for_simple` - Bloc with ≤2 events is simpler as Cubit [Info tier]
  - `require_bloc_observer` - BlocProvider without BlocObserver loses centralized logging [Info tier]

  **Navigation Rules (1)**:
  - `require_route_transition_consistency` - Mixed route types (Material/Cupertino) look unprofessional [Info tier]

  **Testing Rules (1)**:
  - `require_test_groups` - 5+ tests without group() organization are hard to navigate [Info tier]

### Fixed

- **RequireThemeColorFromSchemeRule** - Now correctly excludes `Colors.transparent` from warnings
- **RequireTestGroupsRule** - Now correctly detects Windows-style test paths (`\test\`)
- **PreferImplicitAnimationsRule** - Fixed O(n²) performance issue; now uses efficient per-class tracking

## [1.5.3] - 2026-01-07

### Fixed

- **pub.dev scoring** - Fixed issues that caused loss of 70 pub points:
  - Added `.pubignore` to exclude `example/pubspec.yaml` which had a `path: ../` dependency that broke pana analysis
  - Excluded generated API docs (`doc/api/`), log files, scripts, and test fixtures from published package
  - Package size reduced from 4MB to 469KB

- **Dependency compatibility** - Updated `analyzer` constraint from `<10.0.0` to `<11.0.0` to support analyzer v10.0.0

### Added

- **GitHub Actions publish workflow** - Added `.github/workflows/publish.yml` for automated pub.dev publishing with dry-run option, analysis, format check, and tests

- **README badges** - Added pub points badge and rules count badge (650+)

### Changed

- **Troubleshooting documentation** - Reorganized README troubleshooting section with clearer subsections:
  - "IDE doesn't show lint warnings" - consolidated IDE troubleshooting steps
  - "Out of Memory errors" - new section with 3 solutions (cache clean, heap size, delete artifacts)
  - "Native crashes (Windows)" - moved existing crash fix content

## [1.5.2] - 2026-01-07

### Changed

- **API documentation** - Added `dartdoc_options.yaml` to exclude internal `custom_lint_client` library from generated docs, so only the main `saropa_lints` library appears in the sidebar.

- **API documentation landing page** - Added `doc/README.md` with API-focused content instead of repeating the project README on the documentation homepage.

## [1.5.1] - 2026-01-07

### Fixed

- **Fixture files in example directory were being skipped** - The `skipFixtureFiles` logic incorrectly skipped all `*_fixture.dart` files, including test fixtures in the `example/` directory that are specifically for validating lint rules. Now fixture files in `example/` and `examples/` directories are analyzed.

- **`avoid_unsafe_collection_methods`** - Fixed enum `.values` detection:
  - `TestEnum.values.first` was incorrectly flagged as unsafe
  - Now properly recognizes `List<EnumType>` from `.values` as guaranteed non-empty
  - Uses `staticType` of the entire expression to detect enum element types

- **`prefer_where_or_null`** - Made type checking more robust:
  - Changed from `startsWith` to `contains` for type name matching
  - Now handles cases where type resolution returns null gracefully

- **Removed duplicate rule** - `MissingTestAssertionRule` was duplicating `RequireTestAssertionsRule`. Removed the duplicate from test_rules.dart.

- **`prefer_unique_test_names`** - Fixed potential race condition where `testNames` set was cleared in one callback but used in another. Refactored to use visitor pattern inside single callback.

- **`avoid_unnecessary_return`** - Quick fix now properly deletes the unnecessary return statement instead of commenting it out.

- **Test file detection** - Fixed 4 rules to detect test files in `/test/` and `\test\` directories, not just `_test.dart` suffix:
  - `AvoidEmptyTestGroupsRule`
  - `PreferExpectLaterRule`
  - `PreferTestStructureRule`
  - `AvoidTopLevelMembersInTestsRule`

- **`no_empty_block`** - Quick fix no longer uses hardcoded 6-space indentation; now uses minimal indentation and relies on formatter.

### Changed

- **`FormatTestNameRule`** - Renamed to `PreferDescriptiveTestNameRule` to match its LintCode name `prefer_descriptive_test_name`.

- **Example analysis_options.yaml** - Explicitly enabled `avoid_debug_print`, `avoid_print_in_production`, and `prefer_where_or_null` for fixture testing (these rules are in higher tiers than the default `recommended` tier)

### Added

- **`prefer_expect_later`** - Added quick fix that replaces `expect` with `expectLater` for Future assertions.

- **`prefer_returning_shorthands`** - Added quick fix that converts `{ return x; }` to `=> x` arrow syntax.

## [1.5.0] - 2026-01-07

### Changed

- **`require_animation_controller_dispose`** - Improved detection accuracy:
  - Now recognizes `disposeSafe()` as a valid disposal method alongside `dispose()`, supporting safe disposal extension patterns commonly used in Flutter apps
  - Excludes collection types (`List<>`, `Set<>`, `Map<>`, `Iterable<>`) containing AnimationController from detection, as these require loop-based disposal patterns that the rule cannot validate
  - Expanded documentation with detection criteria, valid disposal patterns, and collection handling guidance

### Added

- **24 new lint rules** across 7 categories:

  **Animation Rules (5)** - New `animation_rules.dart`:
  - `require_vsync_mixin` - AnimationController requires vsync parameter; warns when missing [Error tier] (quick-fix)
  - `avoid_animation_in_build` - AnimationController in build() recreates on every rebuild [Error tier]
  - `require_animation_controller_dispose` - AnimationController must be disposed to prevent memory leaks [Error tier] (quick-fix)
  - `require_hero_tag_uniqueness` - Duplicate Hero tags cause "Multiple heroes" runtime error [Error tier]
  - `avoid_layout_passes` - IntrinsicWidth/Height cause two layout passes, hurting performance [Warning tier]

  **Forms & Validation Rules (4)** - New `forms_rules.dart`:
  - `prefer_autovalidate_on_interaction` - AutovalidateMode.always validates every keystroke; poor UX [Info tier] (quick-fix)
  - `require_keyboard_type` - Email/phone fields should use appropriate keyboardType [Info tier]
  - `require_text_overflow_in_row` - Text in Row without overflow handling may cause overflow errors [Info tier]
  - `require_secure_keyboard` - Password fields must use obscureText: true [Warning tier] (quick-fix)

  **Navigation Rules (2)** - New `navigation_rules.dart`:
  - `require_unknown_route_handler` - MaterialApp/CupertinoApp with routes should have onUnknownRoute [Warning tier]
  - `avoid_context_after_navigation` - Using context after await navigation; widget may be disposed [Warning tier] (quick-fix)

  **Firebase & Database Rules (4)** - New `firebase_rules.dart`:
  - `avoid_firestore_unbounded_query` - Firestore query without limit() could return excessive data [Warning tier]
  - `avoid_database_in_build` - Database query in build() runs on every rebuild [Warning tier]
  - `require_prefs_key_constants` - SharedPreferences keys should be constants, not string literals [Info tier]
  - `avoid_secure_storage_on_web` - flutter_secure_storage uses localStorage on web (not secure) [Warning tier]

  **Security Rules (3)**:
  - `prefer_secure_random` - Random() is predictable; use Random.secure() for security-sensitive code [Warning tier] (quick-fix)
  - `prefer_typed_data` - List<int> for binary data wastes memory; use Uint8List instead [Info tier]
  - `avoid_unnecessary_to_list` - .toList() may be unnecessary; lazy iterables are more efficient [Info tier]

  **State Management Rules (3)**:
  - `avoid_provider_of_in_build` - Provider.of in build() causes rebuilds; use context.read() for actions [Info tier]
  - `avoid_get_find_in_build` - Get.find() in build() is inefficient; use GetBuilder or Obx instead [Info tier]
  - `avoid_provider_recreate` - Provider created in frequently rebuilding build() loses state [Warning tier]

  **Accessibility Rules (3)**:
  - `avoid_text_scale_factor_ignore` - Don't ignore textScaleFactor; users need accessibility scaling [Warning tier]
  - `require_image_semantics` - Decorative images should use excludeFromSemantics: true [Info tier]
  - `avoid_hidden_interactive` - Interactive elements hidden from screen readers but visible [Warning tier]

### Fixed

- **RequireHeroTagUniquenessRule** - Fixed logic bug where heroTags map was local to runWithReporter callback, preventing duplicate detection across file. Now uses CompilationUnit visitor pattern.

- **Quick fix professionalism** - Replaced all "HACK" comments with "TODO" comments across 10 rule files (34 quick fixes total):
  - async_rules.dart (7 fixes)
  - collection_rules.dart (2 fixes)
  - control_flow_rules.dart (1 fix)
  - complexity_rules.dart (2 fixes)
  - error_handling_rules.dart (1 fix)
  - equality_rules.dart (4 fixes)
  - exception_rules.dart (3 fixes)
  - performance_rules.dart (2 fixes)
  - structure_rules.dart (5 fixes)
  - type_rules.dart (7 fixes)

## [1.4.4] - 2025-01-07

### Changed

- **ROADMAP.md** - Major documentation expansion:
  - Expanded all rule descriptions in sections 2.1-2.6 with detailed, actionable explanations
  - Added 14 new rule categories (sections 2.7-2.20) with 130+ new planned rules:
    - 2.7 Animation Rules (12 rules)
    - 2.8 Navigation & Routing Rules (16 rules)
    - 2.9 Forms & Validation Rules (12 rules)
    - 2.10 Database & Storage Rules (14 rules)
    - 2.11 Platform-Specific Rules (24 rules for iOS, Android, Web, Desktop)
    - 2.12 Firebase Rules (12 rules)
    - 2.13 Offline-First & Sync Rules (8 rules)
    - 2.14 Background Processing Rules (6 rules)
    - 2.15 Push Notification Rules (8 rules)
    - 2.16 Payment & In-App Purchase Rules (8 rules)
    - 2.17 Maps & Location Rules (8 rules)
    - 2.18 Camera & Media Rules (8 rules)
    - 2.19 Theming & Dark Mode Rules (8 rules)
    - 2.20 Responsive & Adaptive Design Rules (10 rules)
  - Total planned rules now 347 (up from ~253)

- **README.md** - Updated rule counts:
  - Essential tier: 60 critical rules (was 55)
  - Total implemented: 628 rules (was 500+)
  - Added planned rule count (347) to project description

- **cspell.json** - Added technical terms: assetlinks, autovalidate, backgrounded, backgrounding, EXIF, geofencing, unfocus, unindexed, vsync, workmanager

## [1.4.3] - 2025-01-07

### Added

- **7 new high-impact lint rules**:

  **Flutter Widget Rules (3)**:
  - `avoid_shrink_wrap_in_scroll` - Detects ListView/GridView/SingleChildScrollView with shrinkWrap: true, which causes O(n) layout cost and defeats lazy loading [Warning tier]
  - `avoid_deep_widget_nesting` - Warns when widget build methods have depth > 15 levels; extract to separate widgets for maintainability [Info tier]
  - `prefer_safe_area_aware` - Scaffold body content should be wrapped in SafeArea for edge content handling [Info tier]

  **State Management Rules (2)**:
  - `avoid_ref_in_build_body` - Detects ref.read() inside build() method body; use ref.watch() for reactive updates in Riverpod [Warning tier]
  - `require_immutable_bloc_state` - BLoC state classes should be annotated with @immutable or extend Equatable [Error tier]

  **API & Network Rules (1)**:
  - `require_request_timeout` - HTTP requests (http.get/post/etc, Dio) should have timeout configured to prevent hanging requests [Warning tier]

  **Testing Best Practices Rules (1)**:
  - `avoid_flaky_tests` - Detects flaky test patterns: unseeded Random(), DateTime.now(), File/Directory operations, and network calls without mocking [Warning tier]

### Changed

- **`prefer_async_callback` rule**: Quick fix now replaces `VoidCallback` with
  `Future<void> Function()` instead of `AsyncCallback`. This eliminates the need
  for importing Flutter foundation types (directly via
  `package:flutter/foundation.dart` or indirectly through `widgets.dart`/`material.dart`)
  and is consistent with how parameterized async callbacks are written (e.g.,
  `Future<void> Function(String)`).

- **`prefer_safe_area_aware`**: Reduced false positives - now skips Scaffolds with:
  - `extendBody: true` or `extendBodyBehindAppBar: true` (intentional fullscreen)
  - Body wrapped in `CustomScrollView`, `NestedScrollView`, or `MediaQuery`

- **`require_request_timeout`**: Reduced false positives - now more specific about
  HTTP client detection, no longer matches generic 'api' prefix (e.g., `apiResponse.get()`)

- **`require_focus_node_dispose`**: Now recognizes iteration-based disposal patterns
  for `List<FocusNode>` and `Map<..., FocusNode>` (matching ScrollController rule)

- **`avoid_ref_in_build_body`**: Added more callback methods where `ref.read()` is
  acceptable: `onDismissed`, `onEnd`, `onStatusChanged`, `onComplete`, `onError`,
  `onDoubleTap`, `onPanUpdate`, `onDragEnd`, `onSaved`, `addPostFrameCallback`

### Improved

- **All testing rules**: Added Windows path support (`\test\` in addition to `/test/`)
  for test file detection. Now correctly identifies test files on Windows.

- **`avoid_flaky_tests`**: Enhanced detection accuracy:
  - Added `Process.run(` and `Platform.environment` to flaky patterns
  - Improved seeded Random detection using regex (any numeric seed, not just 1/42)
  - Added `withClock` and `TestWidgetsFlutterBinding` to safe patterns

- **`require_scroll_controller_dispose`, `require_focus_node_dispose`, and `require_bloc_close` quick fixes**:
  Rewrote to actually fix the issue instead of adding TODO comments:
  - If `dispose()` exists: inserts `.dispose()` or `.close()` call before `super.dispose()`
  - If `dispose()` missing: creates full `@override void dispose()` method

- **`prefer_async_callback` documentation**: Comprehensive rewrite explaining:
  - Why `VoidCallback` silently discards Futures (lost errors, race conditions)
  - Which callback names trigger detection (onSubmit, onDelete, onRefresh, etc.)
  - Why `Future<void> Function()` is preferred over `AsyncCallback`
  - Clear BAD/GOOD code examples

- **`prefer_async_callback` prefix detection**: Added missing prefixes for better
  detection of compound names like `onProcessPayment`, `onConfirmDelete`,
  `onBackupData`, etc.

## [1.4.2] - 2025-01-07

### Added

- **50 new lint rules**:

  **Flutter Widget Rules - UX & Interaction (10)**:
  - `avoid_hardcoded_layout_values` - Extract magic numbers to named constants [Info tier]
  - `prefer_ignore_pointer` - Suggests IgnorePointer when AbsorbPointer may block unintentionally [Info tier]
  - `avoid_gesture_without_behavior` - GestureDetector should specify HitTestBehavior [Info tier]
  - `avoid_double_tap_submit` - Submit buttons should prevent double-tap [Warning tier]
  - `prefer_cursor_for_buttons` - Interactive widgets should specify mouse cursor for web [Info tier]
  - `require_hover_states` - Interactive widgets should handle hover for web/desktop [Info tier]
  - `require_button_loading_state` - Async buttons should show loading state [Info tier]
  - `avoid_hardcoded_text_styles` - Use Theme.of(context).textTheme instead of inline TextStyle [Info tier]
  - `prefer_page_storage_key` - Scrollables should use PageStorageKey to preserve position [Info tier]
  - `require_refresh_indicator` - Lists with remote data should have pull-to-refresh [Info tier]

  **Flutter Widget Rules - Scrolling & Lists (9)**:
  - `require_scroll_physics` - Scrollables should specify physics for consistent behavior [Info tier]
  - `prefer_sliver_list` - Use SliverList instead of ListView inside CustomScrollView [Warning tier]
  - `prefer_keep_alive` - State classes in tabs should use AutomaticKeepAliveClientMixin [Info tier]
  - `require_default_text_style` - Multiple Text widgets with same style should use DefaultTextStyle [Info tier]
  - `prefer_wrap_over_overflow` - Row with many small widgets should use Wrap [Info tier]
  - `prefer_asset_image_for_local` - Use AssetImage for bundled assets, not FileImage [Warning tier]
  - `prefer_fit_cover_for_background` - Background images should use BoxFit.cover [Info tier]
  - `require_disabled_state` - Buttons with conditional onPressed should customize disabled style [Info tier]
  - `require_drag_feedback` - Draggable should have feedback widget [Info tier]

  **Flutter Widget Rules - Layout & Performance (8)**:
  - `avoid_gesture_conflict` - Nested GestureDetector widgets may cause conflicts [Warning tier]
  - `avoid_large_images_in_memory` - Images should specify size constraints [Info tier]
  - `avoid_layout_builder_in_scrollable` - LayoutBuilder in scrollables causes rebuilds [Warning tier]
  - `prefer_intrinsic_dimensions` - Use IntrinsicWidth/Height for dynamic sizing [Info tier]
  - `prefer_actions_and_shortcuts` - Use Actions/Shortcuts for keyboard handling [Info tier]
  - `require_long_press_callback` - Important actions should have onLongPress alternative [Info tier]
  - `avoid_find_child_in_build` - Don't traverse widget tree in build() [Warning tier]
  - `avoid_unbounded_constraints` - Avoid widgets with unbounded constraints in scrollables [Warning tier]

  **Flutter Widget Rules - Advanced (10)**:
  - `prefer_fractional_sizing` - Use FractionallySizedBox instead of MediaQuery * 0.x [Info tier]
  - `avoid_unconstrained_box_misuse` - UnconstrainedBox in constrained parent may overflow [Warning tier]
  - `require_error_widget` - FutureBuilder/StreamBuilder should handle error state [Warning tier]
  - `prefer_sliver_app_bar` - Use SliverAppBar in CustomScrollView, not AppBar [Info tier]
  - `avoid_opacity_misuse` - Use AnimatedOpacity when opacity uses variables [Info tier]
  - `prefer_clip_behavior` - Specify clipBehavior on Stack/Container for performance [Info tier]
  - `require_scroll_controller` - ListView.builder should have ScrollController [Info tier]
  - `prefer_positioned_directional` - Use PositionedDirectional for RTL support [Info tier]
  - `avoid_stack_overflow` - Stack children should use Positioned/Align [Info tier]
  - `require_form_validation` - TextFormField inside Form should have validator [Warning tier]

  **Testing Best Practices Rules (13)**:
  - `avoid_test_sleep` - Tests should use fakeAsync/pumpAndSettle, not sleep() [Warning tier]
  - `avoid_find_by_text` - Prefer find.byKey() for widget interactions [Info tier]
  - `require_test_keys` - Interactive widgets in tests should have Keys [Info tier]
  - `require_arrange_act_assert` - Tests should follow AAA pattern [Info tier]
  - `prefer_mock_navigator` - Navigator usage should be mocked for verification [Info tier]
  - `avoid_real_timer_in_widget_test` - Use fakeAsync instead of Timer [Warning tier]
  - `require_mock_verification` - Stubbed mocks should be verified [Info tier]
  - `prefer_matcher_over_equals` - Use matchers (isTrue, isNull, hasLength) [Info tier]
  - `prefer_test_wrapper` - Widget tests should wrap with MaterialApp [Info tier]
  - `require_screen_size_tests` - Responsive widgets should test multiple sizes [Info tier]
  - `avoid_stateful_test_setup` - setUp should not mutate shared state [Warning tier]
  - `prefer_mock_http` - Use MockClient instead of real HTTP [Warning tier]
  - `require_golden_test` - Visual tests should use golden comparison [Info tier]

### Changed

- `prefer_ignore_pointer` - Improved documentation explaining when to use AbsorbPointer vs IgnorePointer
- `require_disabled_state` - Clarified that Flutter buttons have default disabled styling; rule suggests customization
- `require_refresh_indicator` - Now only triggers for lists that appear to show remote data
- `avoid_find_by_text` - Now only warns when find.text() is used for interactions (tap/drag), not content verification

### Fixed

- `prefer_mock_http` - Consolidated duplicate InstanceCreationExpression registrations into single handler

## [1.4.1] - 2025-01-07

### Changed

- `prefer_boolean_prefixes`, `prefer_boolean_prefixes_for_locals`, `prefer_boolean_prefixes_for_params` - **Enhanced boolean naming validation**:
  - Now supports leading underscores (strips `_` prefix before validation)
  - Added 23 new action verb prefixes: `add`, `animate`, `apply`, `block`, `collapse`, `expand`, `filter`, `load`, `lock`, `log`, `merge`, `mute`, `pin`, `remove`, `reverse`, `save`, `send`, `sort`, `split`, `sync`, `track`, `trim`, `validate`, `wrap`
  - Added valid suffixes: `Active`, `Checked`, `Disabled`, `Enabled`, `Hidden`, `Loaded`, `Loading`, `Required`, `Selected`, `Valid`, `Visibility`, `Visible`
  - Added allowed exact names: `value` (Flutter Checkbox/Switch convention)
  - Examples now passing: `_deviceEnabled`, `sortAlphabetically`, `filterCountryHasContacts`, `applyScrollView`, `defaultHideIcons`

## [1.4.0] - 2025-01-07

### Added

- **4 new lint rules**:

  **Async Rules (1)**:
  - `prefer_async_callback` - Warns when `VoidCallback` is used for potentially async operations (onSubmit, onSave, onLoad, etc.). Discarded Futures hide exceptions. (quick-fix) [Professional tier]

  **Naming & Style Rules (2)**:
  - `prefer_boolean_prefixes_for_locals` - Local boolean variables should use is/has/can/should prefix [Comprehensive tier]
  - `prefer_boolean_prefixes_for_params` - Boolean parameters should use is/has/can/should prefix [Professional tier]

  **Security Rules (1)**:
  - `avoid_generic_key_in_url` - Stricter variant that catches generic `key=` and `auth=` URL parameters (higher false positive rate) [Insanity tier]

- **VS Code extension** - Optional status bar button for running custom_lint (see README for installation)

### Changed

- `prefer_boolean_prefixes` - **Reduced scope**: Now only checks class fields and top-level variables. Local variables and parameters are handled by the new separate rules for gradual adoption.

- `avoid_token_in_url` - Removed generic `auth` and `key` patterns to reduce false positives. These are now in `avoid_generic_key_in_url` for stricter codebases.

- `require_scroll_controller_dispose` - Now recognizes iteration-based disposal patterns:
  - `for (final c in _controllers) { c.dispose(); }` - for-in loop disposal
  - `for (final c in _controllers.values) { c.dispose(); }` - Map values disposal

- `require_database_close` - Fixed word boundary detection to avoid false positives on method names containing database keywords (e.g., `initIsarDatabase`)

**False positive reductions** in 4 rules:

- `avoid_commented_out_code` - Now skips annotation markers (TODO, FIXME, NOTE, HACK, BUG, OPTIMIZE, WARNING, CHANGED, REVIEW, DEPRECATED, IMPORTANT, MARK)

- `format_comment_formatting` - Consolidated annotation marker detection using single regex pattern

- `prefer_sentence_case_comments` - Now detects and skips commented-out code:
  - Dart keywords (return, if, for, while, class, import, etc.)
  - Code constructs (function calls, assignments, operators)
  - Code symbols (brackets, braces, increment/decrement, ternary)

- `prefer_doc_comments_over_regular` - Now skips:
  - Annotation markers (TODO, FIXME, NOTE, HACK, etc.)
  - Commented-out code (type declarations, control flow, imports)

### Fixed

- **Ignore comment handling for catch clauses** - Comments placed before the closing `}` of a try block now properly suppress warnings on the catch clause:
  ```dart
  try {
    // code
  // ignore: avoid_swallowing_exceptions
  } on Exception catch (e) {
    // empty
  }
  ```

- `avoid_unsafe_where_methods` - Removed debug print statements from quick fix

## [1.3.1] - 2025-01-06

### Fixed

- **License detection on pub.dev** - LICENSE file now uses LF line endings instead of CRLF, fixing the "(pending)" license display in the pub.dev sidebar
- **CI failures during publish** - Publish script now handles unpushed commits gracefully, ensuring code is formatted before push so CI passes on release commits

### Changed

- **Documentation cross-references** - All markdown files now use full GitHub URLs instead of relative paths for better discoverability on pub.dev:
  - README.md: Updated Documentation table and STYLISTIC.md references
  - STYLISTIC.md: Updated ROADMAP.md reference
  - ROADMAP.md: Updated CHANGELOG.md, CONTRIBUTING.md, and STYLISTIC.md references
  - CONTRIBUTING.md: Updated STYLISTIC.md reference
  - ENTERPRISE.md: Updated migration guide references

### Added

- **.gitattributes** - Enforces LF line endings for LICENSE file to prevent future license detection issues

## [1.3.0] - 2025-01-06

### Added

- **37 new lint rules** with quick-fixes where applicable:

  **Modern Dart 3.0+ Class Modifier Rules (4)**:
  - `avoid_unmarked_public_class` - Public classes should use `base`, `final`, `interface`, or `sealed` modifier
  - `prefer_final_class` - Non-extensible classes should be marked `final`
  - `prefer_interface_class` - Pure abstract contracts should use `interface class`
  - `prefer_base_class` - Abstract classes with shared implementation should use `base`

  **Modern Dart 3.0+ Pattern Rules (3)**:
  - `prefer_pattern_destructuring` - Use pattern destructuring instead of multiple `.$1`, `.$2` accesses
  - `prefer_when_guard_over_if` - Use `when` guards in switch cases instead of nested `if`
  - `prefer_wildcard_for_unused_param` - Use `_` for unused parameters (Dart 3.7+) (quick-fix)

  **Modern Flutter Widget Rules (5)**:
  - `avoid_material2_fallback` - Avoid `useMaterial3: false` (Material 3 is default since Flutter 3.16) (quick-fix)
  - `prefer_overlay_portal` - Use OverlayPortal for declarative overlays (Flutter 3.10+)
  - `prefer_carousel_view` - Use CarouselView for carousel patterns (Flutter 3.24+)
  - `prefer_search_anchor` - Use SearchAnchor for Material 3 search (Flutter 3.10+)
  - `prefer_tap_region_for_dismiss` - Use TapRegion for tap-outside-to-dismiss patterns (Flutter 3.10+)

  **Flutter Widget Rules (10)**:
  - `avoid_raw_keyboard_listener` - Use KeyboardListener instead of deprecated RawKeyboardListener (quick-fix)
  - `avoid_image_repeat` - Image.repeat is rarely needed; explicit ImageRepeat.noRepeat preferred (quick-fix)
  - `avoid_icon_size_override` - Use IconTheme instead of per-icon size
  - `prefer_inkwell_over_gesture` - InkWell provides material ripple feedback (quick-fix)
  - `avoid_fitted_box_for_text` - FittedBox can cause text scaling issues
  - `prefer_listview_builder` - Use ListView.builder for long/infinite lists
  - `avoid_opacity_animation` - Use AnimatedOpacity/FadeTransition instead of Opacity widget (quick-fix)
  - `avoid_sized_box_expand` - Use SizedBox.expand() constructor instead of double.infinity (quick-fix)
  - `prefer_selectable_text` - Use SelectableText for user-copyable content (quick-fix)
  - `prefer_spacing_over_sizedbox` - Use Row/Column/Wrap spacing parameter instead of SizedBox spacers (Flutter 3.10+)

  **Security Rules (3)**:
  - `avoid_token_in_url` - Tokens/API keys should be in headers, not URL query params
  - `avoid_clipboard_sensitive` - Don't copy passwords or tokens to clipboard
  - `avoid_storing_passwords` - Never store passwords in SharedPreferences; use flutter_secure_storage

  **Performance Rules (2)**:
  - `avoid_string_concatenation_loop` - Use StringBuffer for string building in loops (quick-fix)
  - `avoid_large_list_copy` - List.from() copies entire list; consider Iterable operations

- **20 new stylistic/opinionated rules** (not in any tier by default - enable individually):
  - `prefer_relative_imports` - Use relative imports for same-package files
  - `prefer_one_widget_per_file` - One widget class per file
  - `prefer_arrow_functions` - Use arrow syntax for simple functions
  - `prefer_all_named_parameters` - Use named parameters instead of positional
  - `prefer_trailing_comma_always` - Trailing commas on all multi-line structures
  - `prefer_private_underscore_prefix` - Underscore prefix for private members
  - `prefer_widget_methods_over_classes` - Helper methods instead of private widget classes
  - `prefer_explicit_types` - Explicit type annotations instead of `var`/`final`
  - `prefer_class_over_record_return` - Named classes instead of record return types
  - `prefer_inline_callbacks` - Inline callbacks instead of separate methods
  - `prefer_single_quotes` - Prefer single quotes for string literals (quick-fix)
  - `prefer_todo_format` - TODOs follow `TODO(author): description` format
  - `prefer_fixme_format` - FIXMEs follow `FIXME(author): description` format
  - `prefer_sentence_case_comments` - Comments start with capital letter (quick-fix)
  - `prefer_period_after_doc` - Doc comment sentences end with period (quick-fix)
  - `prefer_screaming_case_constants` - Constants in SCREAMING_SNAKE_CASE (quick-fix)
  - `prefer_descriptive_bool_names` - Boolean names use is/has/can/should prefix
  - `prefer_snake_case_files` - File names in snake_case.dart
  - `avoid_small_text` - Minimum 12sp text size for accessibility (quick-fix)
  - `prefer_doc_comments_over_regular` - Use `///` instead of `//` for member docs (quick-fix)

- **Quick fixes added to existing rules**:
  - `avoid_explicit_pattern_field_name` - Auto-convert `fieldName: fieldName` to `:fieldName` shorthand
  - `prefer_digit_separators` - Auto-add digit separators to large numbers (e.g., `1000000` → `1_000_000`)

- **SaropaLintRule base class enhancements** - All rules now use the enhanced base class with:
  - **Hyphenated ignore comments** - Both `// ignore: no_empty_block` and `// ignore: no-empty-block` formats work
  - **Context-aware file skipping** - Generated files (`*.g.dart`, `*.freezed.dart`), fixture files skipped by default
  - **Documentation URLs** - Each rule has `documentationUrl` and `hyphenatedName` getters
  - **Severity override support** - Configure `SaropaLintRule.severityOverrides` for project-level severity changes
- **Automatic file skipping** for:
  - Generated code: `*.g.dart`, `*.freezed.dart`, `*.gen.dart`, `*.gr.dart`, `*.config.dart`, `*.mocks.dart`
  - Fixture files: `fixture/**`, `fixtures/**`, `*_fixture.dart`
  - Optional: test files (`skipTestFiles`), example files (`skipExampleFiles`)

### Fixed

- `prefer_when_guard_over_if` - Removed incorrect handler for traditional `SwitchCase` which doesn't support `when` guards (only `SwitchPatternCase` does)

**Logic fixes across 5 rule files** to reduce false positives and improve accuracy:

- **async_rules.dart**:
  - `AvoidStreamToStringRule` - Now uses `staticType` instead of string matching to avoid false positives on variable names like "upstream"
  - `AvoidPassingAsyncWhenSyncExpectedRule` - Only flags async callbacks passed to methods that ignore Futures (`forEach`, `map`, etc.) instead of all async callbacks
  - `PreferAsyncAwaitRule` - Only flags `.then()` inside async functions where `await` could actually be used
  - `PreferCommentingFutureDelayedRule` - Simplified token loop logic to use reliable `precedingComments` check
  - `AvoidNestedStreamsAndFuturesRule` - No longer duplicates `AvoidNestedFuturesRule` for `Future<Future>` cases

- **control_flow_rules.dart**:
  - `AvoidNestedConditionalExpressionsRule` - Fixed double-reporting by only flagging outermost conditional
  - `AvoidUnnecessaryContinueRule` - Fixed parent check to correctly identify loop contexts
  - `AvoidIfWithManyBranchesRule` - Fixed else-if chain detection using `elseStatement` identity
  - `PreferReturningConditionalsRule` - No longer overlaps with `PreferReturningConditionRule`

- **security_rules.dart**:
  - `RequireSecureStorageRule` - Removed overly broad `'key'` pattern that matched `'selectedThemeKey'`
  - `AvoidLoggingSensitiveDataRule` - Changed `'pin'` to `'pincode'`/`'pin_code'` to avoid matching "spinning", "pinned"
  - `RequireCertificatePinningRule` - Fixed cascade expression detection logic
  - `AvoidEvalLikePatternsRule` - Removed `noSuchMethod` check (valid for mocking/proxying)

- **testing_best_practices_rules.dart**:
  - `AvoidRealNetworkCallsInTestsRule` - Removed `Uri.parse`/`Uri.https`/`Uri.http` from network patterns (URL construction, not network calls)
  - `AvoidVagueTestDescriptionsRule` - Relaxed minimum length from 10 to 5 chars
  - `AvoidProductionConfigInTestsRule` - Removed overly broad `'api.com'` and `'api.io'` patterns

- **type_safety_rules.dart**:
  - `RequireSafeJsonParsingRule` - Regex now matches any `map['key']`/`data['key']` patterns, not just `json['key']`

**Performance improvements**:

- **debug_rules.dart** - Moved `RegExp` patterns to `static final` class fields to avoid recompilation:
  - `AvoidUnguardedDebugRule` - Pre-compiled `_isDebugPattern` and `_debugSuffixPattern`
  - `PreferCommentingAnalyzerIgnoresRule` - Pre-compiled `_ignorePattern`, `_ignoreForFilePattern`, `_ignoreDirectivePattern`

- **naming_style_rules.dart** - `FormatCommentRule` - Pre-compiled `_lowercaseStartPattern`

### Changed

- **README** - Added "Automatic File Skipping" section documenting which files are skipped by default
- **README** - Added hyphenated ignore comment example in "Suppressing Warnings" section
- **ROADMAP** - Added section 5.0 "SaropaLintRule Base Class Enhancements" documenting implemented and planned features

## [1.2.0] - 2025-01-06

### Changed

- **README overhaul** - Expanded "Why saropa_lints?" section:
  - Added "Linting vs static analysis" explanation
  - Added concrete code examples of bugs it catches
  - Added comparison to enterprise tools (SonarQube, Coverity, Checkmarx)
  - Added regulatory context (European Accessibility Act, GitHub leaked secrets stats)
- **pub.dev compatibility** - Fixed all relative links to use absolute GitHub URLs:
  - Banner image now uses raw.githubusercontent.com
  - Migration guides, CONTRIBUTING.md, ENTERPRISE.md, LICENSE all link to GitHub
- **Accurate tier counts** - Corrected inflated rule counts across all documentation:
  - Essential: ~50 (was ~100)
  - Recommended: ~150 (was ~300)
  - Professional: ~250 (was ~600)
  - Comprehensive: ~400 (was ~800)
  - Insanity: ~475 (was 1000)
- **Tier descriptions** - Updated Recommended tier to highlight null safety and collection bounds checking
- **Package description** - Updated pub.dev description from "1,000+" to "500+" rules

## [1.1.19] - 2025-01-06

### Changed

- `avoid_unsafe_collection_methods` - Now recognizes collection-if guards:
  - `[if (list.isNotEmpty) list.first]` - guarded in collection literal
  - `{if (set.length > 0) set.first}` - guarded in set literal
  - `[if (list.isEmpty) 0 else list.first]` - inverted guard in else branch
- `require_value_notifier_dispose` - Now recognizes loop-based disposal patterns for collections of ValueNotifiers:
  - `for (final n in _notifiers) { n.dispose(); }` - for-in loop disposal
  - `_notifiers.forEach((n) => n.dispose())` - forEach disposal
  - Supports `List<ValueNotifier<T>>`, `Set<ValueNotifier<T>>`, `Iterable<ValueNotifier<T>>`
- `require_file_close_in_finally` - Reduced false positives by requiring file indicators (File, IOSink, RandomAccessFile) for generic `.open()` calls

### Fixed

- `avoid_null_assertion` - Added additional safe pattern detection to reduce false positives:
  - Null-coalescing assignment: `x ??= value; x!` - safe after `??=`
  - Negated null checks: `if (!(x == null)) { x! }`
  - Compound && conditions: `if (a && x != null) { x! }`
  - Compound || with early return: `if (a || x == null) return; x!`
  - Flutter async builder patterns: `if (snapshot.hasData) { snapshot.data! }`, `if (snapshot.hasError) { snapshot.error! }`
  - While loops: `while (x != null) { x! }`
  - For loops: `for (; x != null; ) { x! }`
- `avoid_undisposed_instances` - Fixed type annotation access for analyzer 8.x (`name2.lexeme`); now follows helper method calls to detect indirect disposal patterns
- `avoid_undisposed_instances` - Enhanced field extraction to handle parenthesized expressions and cascade expressions

## [1.1.18] - 2025-01-06

### Added

- `no_empty_block` - Added quick fix that inserts an explanatory comment inside the empty block
- `avoid_null_assertion` - Added quick fix that converts `x!.prop` to `x?.prop` in conditions, or adds HACK comment

### Changed

- `avoid_null_assertion` - Refactored null-check extension names into documented const sets (`_truthyNullCheckNames` for && patterns, `_falsyNullCheckNames` for || patterns) for maintainability
- `avoid_unsafe_collection_methods` - Now recognizes guarded access patterns and won't flag safe usage:
  - If statements: `if (list.isNotEmpty) { list.first }`, `if (list.length > 0) { ... }`
  - Ternaries: `list.isNotEmpty ? list.first : fallback`, `list.length > 1 ? list.last : fallback`
  - Inverted guards: `if (list.isEmpty) { } else { list.first }`
  - Quick fix now suggests `*OrNull` methods (firstOrNull, lastOrNull, singleOrNull) instead of adding HACK comments
- `require_future_error_handling` - Now uses actual type checking (`isDartAsyncFuture`) instead of method name heuristics. Added quick fix that adds `.catchError()` handler.

### Fixed

- `avoid_null_assertion` - Added support for inverted if-blocks (`if (x.isEmpty) { } else { x! }`) and numeric checks (`isPositive`, `isZeroOrNegative`, `isNegativeOrZero`, `isNegative`). Also added `isNotListNullOrEmpty`, `isNotNullOrZero`, `isNullOrZero`
- `avoid_undisposed_instances` - Now recognizes `disposeSafe()`, `cancelSafe()`, and `closeSafe()` as valid disposal methods
- `require_stream_controller_dispose` - Now recognizes `closeSafe()` as valid close method
- `require_value_notifier_dispose` - Now recognizes `disposeSafe()` as valid dispose method; only checks owned fields (with initializers), not parameters passed in
- `require_database_close` - Now recognizes `closeSafe()` and `disposeSafe()` as valid cleanup methods
- `require_http_client_close` - Now recognizes `closeSafe()` as valid close method
- `require_websocket_close` - Now recognizes `closeSafe()` as valid close method
- `require_platform_channel_cleanup` - Now recognizes `cancelSafe()` as valid cancel method
- `require_image_disposal` - Now recognizes `disposeSafe()` as valid dispose method

## [1.1.17] - 2025-01-06

### Added

- `require_timer_cancellation` - New dedicated rule for Timer and StreamSubscription fields that require `cancel()`. Separated from `require_dispose` for clearer semantics. Crashes can occur if uncancelled timers call setState after widget disposal.
- `nullify_after_dispose` - New rule that suggests setting nullable disposable fields to null after disposal (e.g., `_timer = null` after `_timer?.cancel()`). Helps garbage collection and prevents accidental reuse.

### Changed

- `require_dispose` - Removed Timer and StreamSubscription (now handled by `require_timer_cancellation`). Now focuses on controllers that use `dispose()` and streams that use `close()`.

### Fixed

- `require_animation_disposal` - Now only checks State classes, eliminating false positives on StatelessWidgets that receive AnimationControllers as constructor parameters (they don't own the controller, parent disposes it)
- `require_dispose` - Now follows helper method calls from dispose() to detect indirect disposal patterns like `_cancelTimer()` that internally call the disposal method
- `require_timer_cancellation` - Follows helper method calls from dispose() to detect indirect cancellation patterns

## [1.1.16] - 2025-01-05

### Changed

- Renamed `docs/` to `doc/guides/` to follow Dart/Pub package layout conventions

## [1.1.15] - 2025-01-05

### Fixed

- `require_dispose` - Fixed `disposeSafe` pattern matching (was `xSafe()`, now correctly matches `x.disposeSafe()`)
- `avoid_logging_sensitive_data` - Added safe pattern detection to avoid false positives on words like `oauth`, `authenticated`, `authorization`, `unauthorized`

### Changed

- README: Clarified that rules must use YAML list format (`- rule: value`) not map format
- README: Updated IDE integration section with realistic expectations and CLI recommendation

## [1.1.14] - 2025-01-05

### Fixed

- `avoid_null_assertion` - Added short-circuit evaluation detection to reduce false positives:
  - `x == null || x!.length` - safe due to || short-circuit
  - `x.isListNullOrEmpty || x!.length < 2` - extension method short-circuit
  - `x != null && x!.doSomething()` - safe due to && short-circuit
  - Added `isListNullOrEmpty`, `isNullOrEmpty`, `isNullOrBlank` to recognized null checks

## [1.1.13] - 2025-01-05

### Changed

- `avoid_null_assertion` - Now recognizes safe null assertion patterns to reduce false positives:
  - Safe ternaries: `x == null ? null : x!`, `x != null ? x! : default`
  - Safe if-blocks: `if (x != null) { use(x!) }`
  - After null-check extensions: `.isNotNullOrEmpty`, `.isNotNullOrBlank`, `.isNotEmpty`
- `dispose_controllers` - Now recognizes `disposeSafe()` as a valid dispose method

## [1.1.12] - 2025-01-05

### Fixed

- `avoid_hardcoded_credentials` - Improved pattern matching to reduce false positives
  - Added minimum length requirements: sk-/pk- tokens (20+), GitHub tokens (36+), Bearer (20+), Basic (10+)
  - More accurate character sets for Base64 encoding in Basic auth
  - End-of-string anchoring for Bearer/Basic tokens

## [1.1.11] - 2025-01-05

### Changed

- **Breaking**: New tier configuration system using Dart code instead of YAML includes
  - `custom_lint` doesn't follow `include:` directives, so tiers are now defined in Dart
  - Configure via `custom_lint: saropa_lints: tier: recommended` in analysis_options.yaml
  - Individual rules can still be overridden on top of tier selection
  - Tiers: essential, recommended, professional, comprehensive, insanity

### Added

- `lib/src/tiers.dart` with rule sets for each tier defined as Dart constants
- `getRulesForTier(String tier)` function for tier-based rule resolution

### Removed

- YAML-based tier configuration (include directives were not being followed by custom_lint)

## [1.1.10] - 2025-01-05

### Fixed

- Added `license: MIT` field to pubspec.yaml for proper pub.dev display

## [1.1.9] - 2025-01-05

### Added

- Quick fixes for 37+ lint rules (IDE code actions to resolve issues)
- `ROADMAP.md` with specifications for ~500 new rules to reach 1000 total
- `ENTERPRISE.md` with business value, adoption strategy, and professional services info
- "Why saropa_lints?" section in README explaining project motivation
- Contact emails: `lints@saropa.com` (README), `dev@saropa.com` (CONTRIBUTING), `enterprise@saropa.com` (ENTERPRISE)

### Changed

- README: Updated rule counts to reflect 1000-rule goal
- README: Tier table now shows target distribution (~100/~300/~600/~800/1000)
- README: Added migration guide links in Quick Start section
- Reorganized documentation structure
- `CONTRIBUTING.md`: Updated quick fix requirements documentation
- `ENTERPRISE.md`: Added migration FAQ with links to guides

### Removed

- `doc/PLAN_LINT_RULES_AND_TESTING.md` (replaced by `ROADMAP.md`)
- `doc/SAROPA_LINT_RULES_GUIDE.md` (replaced by `ENTERPRISE.md`)

## [0.1.8] - 2025-01-05

### Added

- Test infrastructure with unit tests (`test/`) and lint rule fixtures (`example/lib/`)
- Unit tests for plugin instantiation
- Lint rule test fixtures for `avoid_hardcoded_credentials`, `avoid_unsafe_collection_methods`, `avoid_unsafe_reduce`
- `TEST_PLAN.md` documenting testing strategy
- CI workflow for GitHub Actions (analyze, format, test)
- Style badge for projects using saropa_lints
- CI status badge in README
- Badge section in README with copy-paste markdown for users
- Migration guide for very_good_analysis users (`doc/guides/migration_from_vga.md`)

### Changed

- Publish script now runs unit tests and custom_lint tests before publishing
- README: More welcoming tone, clearer introduction
- README: Added link to VGA migration guide
- README: Added link to DCM migration guide
- Updated SECURITY.md for saropa_lints package (was templated for mobile app)
- Updated links.md with saropa_lints development resources
- Added `analysis_options.yaml` to exclude `example/` from main project analysis

### Fixed

- Doc reference warnings in rule comments (`[i]`, `[0]`, `[length-1]`)

## [0.1.7] - 2025-01-05

### Fixed

- **Critical**: `getLintRules()` now reads tier configuration from `custom_lint.yaml`
  - Previously ignored `configs` parameter and used hard-coded 25-rule list
  - Now respects rules enabled/disabled in tier YAML files (essential, recommended, etc.)
  - Supports `enable_all_lint_rules: true` to enable all 500+ rules

## [0.1.6] - 2025-01-05

### Fixed

- Updated for analyzer 8.x API (requires `>=8.0.0 <10.0.0`)
  - Reverted `ErrorSeverity` back to `DiagnosticSeverity`
  - Reverted `ErrorReporter` back to `DiagnosticReporter`
  - Reverted `NamedType.name2` back to `NamedType.name`
  - Updated `enclosingElement3` to `enclosingElement`

## [0.1.5] - 2025-01-05

### Fixed

- Fixed `MethodElement.enclosingElement3` error - `MethodElement` requires cast to `Element` for `enclosingElement3` access
- Expanded analyzer constraint to support version 9.x (`>=6.0.0 <10.0.0`)

## [0.1.4] - 2025-01-05

### Fixed

- **Breaking compatibility fix**: Updated all rule files for analyzer 7.x API changes
  - Migrated from `DiagnosticSeverity` to `ErrorSeverity` (31 files)
  - Migrated from `DiagnosticReporter` to `ErrorReporter` (31 files)
  - Updated `NamedType.name` to `NamedType.name2` for AST type access (12 files)
  - Updated `enclosingElement` to `enclosingElement3` (2 files)
  - Fixed `Element2`/`Element` type inference issue
- Suppressed TODO lint warnings in documentation examples

### Changed

- Now fully compatible with `analyzer ^7.5.0` and `custom_lint ^0.8.0`

## [0.1.3] - 2025-01-05

### Fixed

- Removed custom documentation URL so pub.dev uses its auto-generated API docs

## [0.1.2] - 2025-01-05

### Added

- New formatting lint rules:
  - `AvoidDigitSeparatorsRule` - Flag digit separators in numeric literals
  - `FormatCommentFormattingRule` - Enforce consistent comment formatting
  - `MemberOrderingFormattingRule` - Enforce class member ordering
  - `PreferSortedParametersRule` - Prefer sorted parameters in functions
- Export all rule classes for documentation generation
- Automated publish script for pub.dev releases

### Changed

- Renamed `ParametersOrderingRule` to `ParametersOrderingConventionRule`
- Updated README with accurate rule count (497 rules)
- Simplified README messaging and performance guidance

## [0.1.1] - 2024-12-27

### Fixed

- Improved documentation formatting and examples

## [0.1.0] - 2024-12-27

### Added

- Initial release with 475 lint rules
- 5 tier configuration files:
  - `essential.yaml` (~50 rules) - Crash prevention, memory leaks, security
  - `recommended.yaml` (~150 rules) - Performance, accessibility, testing basics
  - `professional.yaml` (~350 rules) - Architecture, documentation, comprehensive testing
  - `comprehensive.yaml` (~700 rules) - Full best practices
  - `insanity.yaml` (~1000 rules) - Every rule enabled
- Rule categories:
  - Accessibility (10 rules)
  - API & Network (7 rules)
  - Architecture (7 rules)
  - Async (20+ rules)
  - Class & Constructor (15+ rules)
  - Code Quality (20+ rules)
  - Collection (15+ rules)
  - Complexity (10+ rules)
  - Control Flow (15+ rules)
  - Debug (5+ rules)
  - Dependency Injection (8 rules)
  - Documentation (8 rules)
  - Equality (10+ rules)
  - Error Handling (8 rules)
  - Exception (10+ rules)
  - Flutter Widget (40+ rules)
  - Formatting (10+ rules)
  - Internationalization (8 rules)
  - Memory Management (7 rules)
  - Naming & Style (20+ rules)
  - Numeric Literal (5+ rules)
  - Performance (25 rules)
  - Record & Pattern (5+ rules)
  - Resource Management (7 rules)
  - Return (10+ rules)
  - Security (8 rules)
  - State Management (10 rules)
  - Structure (10+ rules)
  - Test (15+ rules)
  - Testing Best Practices (7 rules)
  - Type (15+ rules)
  - Type Safety (7 rules)
  - Unnecessary Code (15+ rules)

### Notes

- Built on `custom_lint_builder: ^0.8.0`
- Compatible with Dart SDK >=3.1.0 <4.0.0
- MIT licensed - free for any use
