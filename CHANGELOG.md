# Changelog

All notable changes to this project will be documented in this file.
The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

> **Looking for older changes?**  \
> See [CHANGELOG_ARCHIVE.md](./CHANGELOG_ARCHIVE.md) for versions 0.1.0 through 1.8.2.

## [2.4.1] - 2026-01-11

### Changed

-- Minor doc header escaping of `Provider.of<T>(context)`

## [2.4.0] - 2026-01-11

### Added

#### Apple Platform Rules (104 rules)

This release adds comprehensive iOS and macOS platform rules to help Flutter developers build apps that pass App Store review, handle platform requirements correctly, and provide native user experiences.

See the [Apple Platform Rules Guide](https://github.com/saropa/saropa_lints/blob/main/doc/guides/apple_platform_rules.md) for detailed documentation.

**iOS Core Rules (14 rules)**
- **`prefer_ios_safe_area`**: Warns when Scaffold body doesn't use SafeArea. Content may be hidden by iOS notch or Dynamic Island. (INFO)
- **`avoid_ios_hardcoded_status_bar`**: Warns when hardcoded status bar heights (20, 44, 47, 59) are used. Use MediaQuery.padding.top instead. (WARNING)
- **`prefer_ios_haptic_feedback`**: Suggests adding haptic feedback for important button interactions on iOS devices. (INFO)
- **`require_ios_platform_check`**: Warns when iOS-specific MethodChannel calls lack Platform.isIOS guard. (WARNING)
- **`avoid_ios_background_fetch_abuse`**: Warns when Future.delayed exceeds iOS 30-second background limit. (WARNING)
- **`require_apple_sign_in`**: Warns when apps use third-party login without Sign in with Apple. App Store rejection per Guidelines 4.8. (ERROR)
- **`require_ios_background_mode`**: Reminds to add iOS background capabilities when using background task APIs. (INFO)
- **`avoid_ios_13_deprecations`**: Warns when deprecated iOS 13+ APIs (UIWebView, UIAlertView) are detected. (WARNING)
- **`avoid_ios_simulator_only_code`**: Warns when iOS Simulator-only patterns are detected in production code. (WARNING)
- **`require_ios_minimum_version_check`**: Warns when iOS version-specific APIs are used without version checks. (INFO)
- **`avoid_ios_deprecated_uikit`**: Warns when deprecated UIKit APIs are used in platform channel code. (WARNING)
- **`require_ios_dynamic_island_safe_zones`**: Warns when fixed top padding doesn't account for Dynamic Island. (WARNING)
- **`require_ios_deployment_target_consistency`**: Warns when iOS 15+ APIs are used without version checks. (WARNING)
- **`require_ios_scene_delegate_awareness`**: Suggests using Flutter's unified lifecycle handler for iOS 13+ Scene Delegate. (INFO)

**App Store Review Rules (12 rules)**
- **`require_ios_app_tracking_transparency`**: Warns when ad SDKs are used without ATT implementation. Required for iOS 14.5+. (ERROR)
- **`require_ios_face_id_usage_description`**: Warns when biometric auth is used without NSFaceIDUsageDescription. (WARNING)
- **`require_ios_photo_library_add_usage`**: Warns when photo saving APIs lack NSPhotoLibraryAddUsageDescription. (WARNING)
- **`avoid_ios_in_app_browser_for_auth`**: Warns when OAuth is loaded in WebView. Google/Apple block this for security. (ERROR)
- **`require_ios_app_review_prompt_timing`**: Warns when app review is requested too early. (WARNING)
- **`require_ios_review_prompt_frequency`**: Reminds about Apple's 3x per year limit on StoreKit review prompts. (INFO)
- **`require_ios_receipt_validation`**: Warns when in-app purchases lack server-side receipt validation. (WARNING)
- **`require_ios_age_rating_consideration`**: Reminds to verify App Store age rating for WebViews or user-generated content. (INFO)
- **`avoid_ios_misleading_push_notifications`**: Warns when push notification content may violate Apple's guidelines. (INFO)
- **`require_ios_permission_description`**: Warns when permission-requiring APIs lack Info.plist usage descriptions. (WARNING)
- **`require_ios_privacy_manifest`**: Warns when APIs requiring iOS 17+ Privacy Manifest entries are used. (WARNING)
- **`require_https_for_ios`**: Warns when HTTP URLs are used that will be blocked by App Transport Security. (WARNING)

**Security & Authentication Rules (8 rules)**
- **`require_ios_keychain_accessibility`**: Suggests specifying iOS Keychain accessibility level for secure storage. (INFO)
- **`require_ios_keychain_sync_awareness`**: Warns when sensitive keys may sync via iCloud Keychain. (INFO)
- **`require_ios_keychain_for_credentials`**: Warns when credentials are stored in SharedPreferences instead of Keychain. (ERROR)
- **`require_ios_certificate_pinning`**: Suggests SSL certificate pinning for sensitive API endpoints. (INFO)
- **`require_ios_biometric_fallback`**: Reminds to provide fallback authentication for devices without biometrics. (INFO)
- **`require_ios_healthkit_authorization`**: Warns when HealthKit data is accessed without authorization request. (WARNING)
- **`avoid_ios_hardcoded_bundle_id`**: Warns when bundle IDs are hardcoded instead of from configuration. (INFO)
- **`avoid_ios_debug_code_in_release`**: Warns when debug logging may be included in release builds. (INFO)

**Platform Integration Rules (14 rules)**
- **`require_ios_push_notification_capability`**: Reminds to enable Push Notifications capability in Xcode. (INFO)
- **`require_ios_background_audio_capability`**: Reminds to enable Background Modes > Audio capability. (INFO)
- **`require_ios_background_refresh_declaration`**: Reminds about UIBackgroundModes "fetch" in Info.plist. (INFO)
- **`require_ios_app_group_capability`**: Reminds about App Groups capability for extension data sharing. (INFO)
- **`require_ios_siri_intent_definition`**: Reminds about Intent Definition file for Siri Shortcuts. (INFO)
- **`require_ios_widget_extension_capability`**: Reminds about Widget Extension target for Home Screen widgets. (INFO)
- **`require_ios_live_activities_setup`**: Reminds about ActivityKit and Widget Extension setup. (INFO)
- **`require_ios_carplay_setup`**: Reminds about CarPlay entitlement requirements. (INFO)
- **`require_ios_callkit_integration`**: Warns when VoIP call handling lacks CallKit integration. (WARNING)
- **`require_ios_nfc_capability_check`**: Warns when NFC is used without capability check. (WARNING)
- **`require_ios_method_channel_cleanup`**: Warns when MethodChannel handler lacks cleanup in dispose(). (WARNING)
- **`avoid_ios_force_unwrap_in_callbacks`**: Warns when force unwrap is used on MethodChannel results. (WARNING)
- **`require_method_channel_error_handling`**: Warns when MethodChannel.invokeMethod lacks try-catch. (WARNING)
- **`prefer_ios_app_intents_framework`**: Suggests migrating from legacy SiriKit to App Intents framework. (INFO)

**Device & Hardware Rules (8 rules)**
- **`avoid_ios_hardcoded_device_model`**: Warns when device model names are hardcoded. Breaks on new devices. (WARNING)
- **`require_ios_orientation_handling`**: Reminds to configure UISupportedInterfaceOrientations. (INFO)
- **`require_ios_photo_library_limited_access`**: Warns when photo library access may not handle iOS 14+ limited access. (INFO)
- **`avoid_ios_continuous_location_tracking`**: Warns when continuous location tracking uses high accuracy. (INFO)
- **`require_ios_lifecycle_handling`**: Warns when Timer.periodic or subscriptions lack lifecycle handling. (INFO)
- **`require_ios_promotion_display_support`**: Warns when manual frame timing may not adapt to ProMotion 120Hz. (INFO)
- **`require_ios_pasteboard_privacy_handling`**: Warns when clipboard access may trigger iOS 16+ privacy notification. (INFO)
- **`prefer_ios_storekit2`**: Suggests evaluating StoreKit 2 for new IAP implementations. (INFO)

**Data & Storage Rules (6 rules)**
- **`require_ios_database_conflict_resolution`**: Reminds to implement conflict resolution for cloud-synced databases. (INFO)
- **`require_ios_icloud_kvstore_limitations`**: Reminds about iCloud Key-Value Storage 1 MB and 1024 key limits. (INFO)
- **`require_ios_share_sheet_uti_declaration`**: Reminds about UTI declarations for custom file type sharing. (INFO)
- **`require_ios_app_clip_size_limit`**: Warns about App Clip 10 MB size limit. (INFO)
- **`require_ios_ats_exception_documentation`**: Suggests documenting ATS exceptions when HTTP URLs are used. (INFO)
- **`require_ios_local_notification_permission`**: Warns when local notifications are scheduled without permission request. (WARNING)

**Deep Linking Rules (2 rules)**
- **`require_universal_link_validation`**: Reminds to validate iOS Universal Links server configuration. (INFO)
- **`require_ios_universal_links_domain_matching`**: Reminds to verify apple-app-site-association paths match. (INFO)

**macOS Platform Rules (12 rules)**
- **`prefer_macos_menu_bar_integration`**: Suggests using PlatformMenuBar for native macOS menu integration. (INFO)
- **`prefer_macos_keyboard_shortcuts`**: Suggests implementing standard macOS keyboard shortcuts. (INFO)
- **`require_macos_window_size_constraints`**: Warns when macOS apps lack window size constraints. (INFO)
- **`require_macos_window_restoration`**: Suggests implementing window state restoration for better UX. (INFO)
- **`require_macos_file_access_intent`**: Warns when direct file paths are used in sandboxed apps. (INFO)
- **`require_macos_hardened_runtime`**: Warns when operations may require Hardened Runtime entitlements. (INFO)
- **`require_macos_sandbox_entitlements`**: Warns when features require macOS sandbox entitlements. (WARNING)
- **`avoid_macos_deprecated_security_apis`**: Warns when deprecated macOS Security framework APIs are used. (WARNING)
- **`avoid_macos_catalyst_unsupported_apis`**: Warns when APIs unavailable on Mac Catalyst are used. (WARNING)
- **`avoid_macos_full_disk_access`**: Warns when protected paths are accessed directly. (WARNING)
- **`prefer_cupertino_for_ios`**: Suggests Cupertino widgets over Material widgets in Platform.isIOS blocks. (INFO)
- **`require_ios_accessibility_labels`**: Warns when interactive widgets lack Semantics wrapper for VoiceOver. (INFO)

**Background Processing Rules (5 rules)**
- **`avoid_long_running_isolates`**: Warns when Dart isolates perform long operations. iOS terminates isolates after 30 seconds in background. (WARNING)
- **`require_workmanager_for_background`**: Warns when Timer.periodic is used without workmanager. Dart isolates die when app backgrounds. (WARNING)
- **`require_notification_for_long_tasks`**: Warns when long-running tasks may run in background without progress notification. (WARNING)
- **`prefer_background_sync`**: Suggests using BGTaskScheduler for data synchronization instead of manual polling. (INFO)
- **`require_sync_error_recovery`**: Warns when data sync operations don't implement retry/recovery for failed syncs. (WARNING)

**Notification Rules (2 rules)**
- **`prefer_delayed_permission_prompt`**: Warns when permission requests occur in initState. Show context before requesting. (WARNING)
- **`avoid_notification_spam`**: Warns when notifications may be sent in loops or without proper batching. (WARNING)

**In-App Purchase Rules (3 rules)**
- **`require_purchase_verification`**: Warns when purchases lack server-side receipt verification. Prevents IAP fraud. (ERROR)
- **`require_purchase_restoration`**: Warns when IAP implementation lacks restorePurchases. App Store requires restore functionality. (ERROR)
- **`prefer_revenuecat`**: Suggests RevenueCat for complex IAP implementations over manual StoreKit handling. (INFO)

**iOS Platform Enhancement Rules (16 rules)**
- **`avoid_ios_wifi_only_assumption`**: Warns when large downloads don't check connectivity. Users may incur cellular charges. (WARNING)
- **`require_ios_low_power_mode_handling`**: Warns when apps don't adapt behavior for Low Power Mode. (WARNING)
- **`require_ios_accessibility_large_text`**: Warns when fixed text sizes don't support Dynamic Type. (WARNING)
- **`prefer_ios_context_menu`**: Suggests CupertinoContextMenu for long-press context menus on iOS. (INFO)
- **`require_ios_quick_note_awareness`**: Warns when NSUserActivity isn't used. Content may be inaccessible in Quick Note. (INFO)
- **`avoid_ios_hardcoded_keyboard_height`**: Warns when keyboard heights are hardcoded. Use MediaQuery.viewInsets.bottom. (WARNING)
- **`require_ios_multitasking_support`**: Warns when iPad apps may not handle Split View or Slide Over correctly. (WARNING)
- **`prefer_ios_spotlight_indexing`**: Suggests implementing Core Spotlight indexing for searchable content. (INFO)
- **`require_ios_data_protection`**: Warns when sensitive files don't specify FileProtection attributes. (WARNING)
- **`avoid_ios_battery_drain_patterns`**: Warns when code patterns may cause excessive battery drain. (WARNING)
- **`require_ios_entitlements`**: Reminds to add iOS entitlements when using capabilities like Push, iCloud, etc. (INFO)
- **`require_ios_launch_storyboard`**: Reminds that Launch Storyboard is required for App Store submission. (INFO)
- **`require_ios_version_check`**: Warns when iOS version-specific APIs are used without @available checks. (INFO)
- **`require_ios_focus_mode_awareness`**: Suggests setting appropriate interruptionLevel for notifications during Focus Mode. (INFO)
- **`prefer_ios_handoff_support`**: Suggests implementing NSUserActivity for Handoff and Continuity features. (INFO)
- **`require_ios_voiceover_gesture_compatibility`**: Warns when custom gestures may conflict with VoiceOver gestures. (INFO)

**macOS Platform Enhancement Rules (5 rules)**
- **`require_macos_sandbox_exceptions`**: Warns when macOS apps may need sandbox exception entitlements. (WARNING)
- **`avoid_macos_hardened_runtime_violations`**: Warns when code may violate Hardened Runtime requirements. (WARNING)
- **`require_macos_app_transport_security`**: Warns when HTTP URLs may be blocked by macOS App Transport Security. (WARNING)
- **`require_macos_notarization_ready`**: Reminds to verify notarization requirements before distribution. (WARNING)
- **`require_macos_entitlements`**: Reminds to add macOS entitlements when using capabilities. (INFO)

### Changed

- **`avoid_catch_all`**: Simplified to only flag bare `catch` blocks (without `on` clause). The `on Exception catch` detection has been moved to a new separate rule. **Quick fix available:** Adds `on Object` before bare catch.

#### New Error Handling Rule (1 rule)

- **`avoid_catch_exception_alone`**: Warns when `on Exception catch` is used without an `on Object catch` fallback. `on Exception catch` only catches `Exception` subclasses, silently missing all `Error` types (StateError, TypeError, RangeError, etc.) which crash without logging! Allowed if paired with `on Object catch` in the same try statement. **Quick fix available:** Changes `Exception` to `Object`. (WARNING)

#### BuildContext Safety Rules - Tiered Static Method Rules (2 new rules)

The original `avoid_context_in_static_methods` rule has been refined into a tiered system for different strictness levels:

- **`avoid_context_after_await_in_static`** (Essential/ERROR): Warns when BuildContext is used AFTER an await expression in async static methods. This is the truly dangerous case - the widget may have disposed during the async gap, making the context invalid and causing crashes.

- **`avoid_context_in_async_static`** (Recommended/WARNING): Warns when ANY async static method has a BuildContext parameter. Even if context is used before the first await, this pattern is risky and encourages unsafe additions later. **Quick fix available:** Adds `bool Function() isMounted` parameter.

- **`avoid_context_in_static_methods`** (Comprehensive/INFO): Now only warns for SYNC static methods with BuildContext. Async methods are handled by the more specific rules above. Sync methods are generally safe but the pattern is still discouraged.

**Migration:**
- Essential tier users get only the critical `avoid_context_after_await_in_static` rule (ERROR)
- Recommended tier users also get `avoid_context_in_async_static` (WARNING)
- Comprehensive tier users get all three including the INFO-level sync method rule

### Fixed

- **pubspec.yaml**: Shortened package description to comply with pub.dev 180-character limit
- **`require_rethrow_preserve_stack`**: Fixed type comparison error where `Token` was compared to `String`. Now correctly uses `.lexeme` to extract the exception parameter name
- **`avoid_yield_in_on_event`**: Fixed doc comment where `on<Event>` angle brackets were being interpreted as HTML. Wrapped in backticks for proper escaping

## [2.3.11] - 2026-01-11

### Changed

- **`audit_rules.py`**: Now counts and displays the number of quick fixes (DartFix classes) in the statistics output

### Added

#### Test Rules (2 rules)
- **`require_test_widget_pump`**: Warns when widget test interactions (tap, enterText, drag) are not followed by pump() or pumpAndSettle(). Events may not be processed. (ERROR)
- **`require_integration_test_timeout`**: Warns when integration tests don't have a timeout. Long tests can hang CI indefinitely. (WARNING)

#### Hive Database Rules (4 rules)
- **`require_hive_field_default_value`**: Warns when @HiveField on nullable fields lacks defaultValue. Existing data may fail to load after schema changes. (WARNING)
- **`require_hive_adapter_registration_order`**: Warns when Hive.openBox is called before registering adapters. Will cause runtime crash. (ERROR)
- **`require_hive_nested_object_adapter`**: Warns when @HiveField contains custom types without @HiveType annotation. (ERROR)
- **`avoid_hive_box_name_collision`**: Warns when generic Hive box names are used that may cause collisions. (WARNING)

#### Security Rules (2 rules)
- **`avoid_api_key_in_code`**: Warns when API keys appear hardcoded in source code. Keys can be extracted from builds. (ERROR)
- **`avoid_storing_sensitive_unencrypted`**: Warns when sensitive data (tokens, passwords) is stored in unencrypted storage. (ERROR)

#### State Management Rules (3 rules)
- **`avoid_riverpod_notifier_in_build`**: Warns when Notifiers are instantiated in build methods. State is lost on rebuild. (WARNING)
- **`require_riverpod_async_value_guard`**: Suggests using AsyncValue.guard over try-catch in Riverpod providers. (WARNING)
- **`avoid_bloc_business_logic_in_ui`**: Warns when UI code (Navigator, showDialog) is used inside Bloc classes. (WARNING)

#### Navigation Rules (2 rules)
- **`require_url_launcher_encoding`**: Warns when URL strings with interpolation may have unencoded characters. (WARNING)
- **`avoid_nested_routes_without_parent`**: Warns when navigating to deeply nested routes without ensuring parent routes are in stack. (WARNING)

#### Equatable Rules (1 rule)
- **`require_copy_with_null_handling`**: Warns when copyWith methods use ?? operator and can't set nullable fields to null. (WARNING)

#### Internationalization Rules (2 rules)
- **`require_intl_args_match`**: Warns when Intl.message args don't match placeholders in the message. (ERROR)
- **`avoid_string_concatenation_for_l10n`**: Warns when string concatenation is used in Text widgets, breaking l10n word order. (WARNING)

#### Performance Rules (3 rules)
- **`avoid_blocking_database_ui`**: Warns when database operations are performed in build method. Causes UI jank. (WARNING)
- **`avoid_money_arithmetic_on_double`**: Warns when arithmetic is performed on double for money values. Precision issues. (WARNING)
- **`avoid_rebuild_on_scroll`**: Warns when scroll listeners are added in build method. Causes memory leaks. (WARNING)

#### Error Handling Rules (3 rules)
- **`avoid_exception_in_constructor`**: Warns when exceptions are thrown in constructors. Use factory methods instead. (WARNING)
- **`require_cache_key_determinism`**: Warns when cache keys use non-deterministic values like DateTime.now(). (ERROR)
- **`require_permission_permanent_denial_handling`**: Warns when permission requests don't handle permanent denial with settings redirect. (WARNING)

#### Dependency Injection Rules (2 rules)
- **`require_getit_registration_order`**: Warns when GetIt registration order may cause unresolved dependencies. (WARNING)
- **`require_default_config`**: Warns when config/env access doesn't provide default values for missing values. (WARNING)

#### Widget Rules (1 rule)
- **`avoid_builder_index_out_of_bounds`**: Warns when itemBuilder accesses list without bounds check. Index may be out of bounds if list changes. (WARNING)

## [2.3.10] - 2026-01-11

### Added

#### BuildContext Safety Rules (3 rules)
- **`avoid_storing_context`**: Warns when BuildContext is stored in a field. Context may become invalid after widget disposal, causing crashes. (ERROR)
- **`avoid_context_across_async`**: Warns when BuildContext is used after an await without checking `mounted`. Widget may be disposed during async operation. (ERROR)
- **`avoid_context_in_static_methods`**: Warns when BuildContext is passed to static methods. Static methods cannot check `mounted` state. (ERROR)

#### Test Rules (2 rules)
- **`avoid_test_print_statements`**: Warns when print() is used in test files. Use expect() assertions or proper test logging instead. (WARNING)
- **`require_mock_http_client`**: Warns when real HTTP clients are used in test files. Mock HTTP calls to ensure reliable, fast tests. (ERROR)

#### Async Rules (2 rules)
- **`avoid_future_then_in_async`**: Warns when .then() is used inside an async function. Use await for cleaner, more readable code. (WARNING)
- **`avoid_unawaited_future`**: Warns when a Future is returned without being awaited in an async function. May cause silent failures. (ERROR)

#### Forms Rules (3 rules)
- **`require_text_input_type`**: Warns when TextField lacks keyboardType. Set appropriate keyboard for better UX (email, phone, number). (INFO)
- **`prefer_text_input_action`**: Warns when TextField lacks textInputAction. Set action for better keyboard UX (next, done, search). (INFO)
- **`require_form_key_in_stateful_widget`**: Warns when GlobalKey<FormState> is created inside build(). Create keys in initState or as class fields. (ERROR)

#### API/Network Rules (2 rules)
- **`prefer_timeout_on_requests`**: Warns when HTTP requests lack timeout. Add timeout to prevent hanging requests. (WARNING)
- **`prefer_dio_over_http`**: Suggests using Dio over http package for better features like interceptors, cancellation, retries. (INFO)

#### Error Handling Rules (1 rule)
- **`avoid_catch_all`**: Warns when catch block has no exception type. Catch specific exceptions for proper error handling. (ERROR)

#### State Management Rules (2 rules)
- **`avoid_bloc_context_dependency`**: Warns when BuildContext is passed to Bloc constructor. Bloc should not depend on widget lifecycle. (ERROR)
- **`avoid_provider_value_rebuild`**: Warns when Provider.value() creates instance inline. Create instance outside to avoid rebuilds. (WARNING)

#### Lifecycle Rules (1 rule)
- **`require_did_update_widget_check`**: Warns when didUpdateWidget doesn't check if widget properties changed. May cause unnecessary updates. (WARNING)

#### Equatable Rules (1 rule)
- **`require_equatable_copy_with`**: Suggests adding copyWith() method to Equatable classes for immutable updates. (INFO)

#### Notification Rules (1 rule)
- **`avoid_notification_same_id`**: Warns when notifications use same hardcoded ID. Use unique IDs to avoid overwriting. (WARNING)

#### Internationalization Rules (1 rule)
- **`require_intl_plural_rules`**: Warns when Intl.plural() is missing required forms (zero, one, other). Incomplete forms cause i18n issues. (ERROR)

#### Image Rules (2 rules)
- **`prefer_cached_image_cache_manager`**: Suggests providing custom CacheManager to CachedNetworkImage for better cache control. (INFO)
- **`require_image_cache_dimensions`**: Warns when CachedNetworkImage lacks memCacheWidth/Height. Set dimensions to reduce memory usage. (WARNING)

#### Navigation Rules (2 rules)
- **`prefer_url_launcher_uri_over_string`**: Suggests using launchUrl(Uri) over launch(String) for type safety. (INFO)
- **`avoid_go_router_push_replacement_confusion`**: Warns when pushReplacement is used where go() or push() may be intended. (WARNING)

#### Flutter Widget Rules (2 rules)
- **`avoid_stack_without_positioned`**: Warns when Stack has children without Positioned wrapper. Non-positioned children overlay each other. (WARNING)
- **`avoid_expanded_outside_flex`**: Warns when Expanded/Flexible is used outside Row, Column, or Flex. Will cause runtime error. (ERROR)

## [2.3.9] - 2026-01-11

### Added

#### Internationalization Rules (4 rules)
- **`require_intl_date_format_locale`**: Warns when DateFormat is used without explicit locale parameter. Format varies by device/platform.
- **`require_number_format_locale`**: Warns when NumberFormat is used without explicit locale parameter. Decimal separators vary by locale (1,234.56 vs 1.234,56).
- **`avoid_manual_date_formatting`**: Warns when dates are formatted manually using DateTime properties instead of DateFormat.
- **`require_intl_currency_format`**: Warns when currency values are formatted manually with symbols like $, €, £ instead of NumberFormat.currency.

#### Equatable Rules (1 rule)
- **`avoid_mutable_field_in_equatable`**: Warns when Equatable class has non-final fields. Mutable fields break equality contracts. (ERROR)

#### Error Handling Rules (1 rule)
- **`avoid_print_error`**: Warns when print() is used for error logging in catch blocks. Use proper logging frameworks in production.

#### Collection/Widget Rules (1 rule)
- **`require_key_for_collection`**: Warns when widgets in ListView.builder, GridView.builder lack a Key parameter. May cause inefficient rebuilds or state loss.

#### Database Rules (2 rules)
- **`avoid_hive_field_index_reuse`**: Warns when @HiveField indices are duplicated within a class. Data corruption will occur. (ERROR)
- **`avoid_sqflite_reserved_words`**: Warns when SQLite reserved words (ORDER, GROUP, SELECT, etc.) are used as column names without escaping.

## [2.3.8] - 2026-01-11

### Fixed

- **`require_sse_subscription_cancel`**: Fixed false positives for field names like `addressesFuture` or `hasSearched` that contain "sse" substring. Now uses word-boundary regex `(^|_)sse($|_|[A-Z])` on the original (case-preserved) field name to correctly detect camelCase patterns like `sseClient` while avoiding false matches.
- **`avoid_shrink_wrap_expensive`**: No longer warns when `physics: NeverScrollableScrollPhysics()` is used. This is an intentional pattern for nested non-scrolling lists inside another scrollable.
- **`avoid_redirect_injection`**: Fixed false positives for object property access like `item.destination`. Now uses AST node type checking (`PropertyAccess`, `PrefixedIdentifier`) to skip property access patterns, and checks for custom object types when type info is available.
- **`use_setstate_synchronously`**: Fixed false positives in async lambda callbacks. Now skips nested `FunctionExpression` nodes (they have their own async context) and checks for ancestor mounted guards before reporting.

### Changed

- **Formatting**: Applied consistent code formatting to api_network_rules.dart (cosmetic only, no behavior change)

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

## [1.8.2] and Earlier
For details on the initial release and versions 0.1.0 through 1.6.0, please refer to [CHANGELOG_ARCHIVE.md](./CHANGELOG_ARCHIVE.md).
