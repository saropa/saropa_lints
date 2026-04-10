/// Barrel export for all lint rules organized by category.
///
/// **Required:** Every new rule must be exported here and listed in
/// `lib/saropa_lints.dart` [_allRuleFactories] and in `tiers.dart` in the
/// appropriate tier set. Missing export = rule never runs.
library;

// Architecture
export 'architecture/architecture_rules.dart';
export 'architecture/dependency_injection_rules.dart';
export 'architecture/disposal_rules.dart';
export 'architecture/lifecycle_rules.dart';
export 'architecture/structure_rules.dart';
export 'architecture/compile_time_syntax_rules.dart';

// Commerce
export 'commerce/iap_rules.dart';

// Code quality
export 'code_quality/code_quality_avoid_rules.dart';
export 'code_quality/code_quality_control_flow_rules.dart';
export 'code_quality/code_quality_prefer_rules.dart';
export 'code_quality/code_quality_variables_rules.dart';
export 'code_quality/complexity_rules.dart';
export 'code_quality/unnecessary_code_rules.dart';

// Config
export 'config/config_rules.dart';
export 'config/dart_sdk_3_removal_rules.dart';
export 'config/dart_sdk_34_deprecation_rules.dart';
export 'config/flutter_sdk_migration_rules.dart';
export 'config/migration_rules.dart';
export 'config/sdk_migration_batch2_rules.dart';
export 'config/platform_rules.dart';

// Core (async, context, naming, state, docs, performance)
export 'core/async_rules.dart';
export 'core/class_constructor_rules.dart';
export 'core/context_rules.dart';
export 'core/documentation_rules.dart';
export 'core/naming_style_rules.dart';
export 'core/performance_rules.dart';
export 'core/state_management_rules.dart';

// Data / types
export 'data/collection_rules.dart';
export 'data/equality_rules.dart';
export 'data/json_datetime_rules.dart';
export 'data/money_rules.dart';
export 'data/numeric_literal_rules.dart';
export 'data/record_pattern_rules.dart';
export 'data/type_rules.dart';
export 'data/type_safety_rules.dart';

// Flow (control flow, return, exceptions, errors)
export 'flow/control_flow_rules.dart';
export 'flow/error_handling_rules.dart';
export 'flow/exception_rules.dart';
export 'flow/return_rules.dart';

// Codegen
export 'codegen/freezed_rules.dart';

// Hardware
export 'hardware/bluetooth_hardware_rules.dart';

// Media
export 'media/image_rules.dart';
export 'media/media_rules.dart';

// Network
export 'network/api_network_rules.dart';
export 'network/connectivity_rules.dart';

// Resources
export 'resources/db_yield_rules.dart';
export 'resources/file_handling_rules.dart';
export 'resources/memory_management_rules.dart';
export 'resources/resource_management_rules.dart';

// Security
export 'security/crypto_rules.dart';
export 'security/permission_rules.dart';
export 'security/security_auth_storage_rules.dart';
export 'security/security_network_input_rules.dart';

// Stylistic
export 'stylistic/formatting_rules.dart';
export 'stylistic/stylistic_additional_rules.dart';
export 'stylistic/stylistic_control_flow_rules.dart';
export 'stylistic/stylistic_error_testing_rules.dart';
export 'stylistic/stylistic_null_collection_rules.dart';
export 'stylistic/stylistic_rules.dart';
export 'stylistic/stylistic_whitespace_constructor_rules.dart';
export 'stylistic/stylistic_widget_rules.dart';

// Testing
export 'testing/debug_rules.dart';
export 'testing/test_rules.dart';
export 'testing/testing_best_practices_rules.dart';

// UI (accessibility, animation, i18n, navigation, notification)
export 'ui/accessibility_rules.dart';
export 'ui/animation_rules.dart';
export 'ui/internationalization_rules.dart';
export 'ui/navigation_rules.dart';
export 'ui/notification_rules.dart';

// Widget / UI
export 'widget/build_method_rules.dart';
export 'widget/dialog_snackbar_rules.dart';
export 'widget/forms_rules.dart';
export 'widget/scroll_rules.dart';
export 'widget/theming_rules.dart';
export 'widget/ui_ux_rules.dart';
export 'widget/widget_layout_constraints_rules.dart';
export 'widget/widget_layout_flex_scroll_rules.dart';
export 'widget/widget_lifecycle_rules.dart';
export 'widget/flutter_migration_widget_rules.dart';
export 'widget/image_filter_quality_migration_rules.dart';
export 'widget/widget_patterns_avoid_prefer_rules.dart';
export 'widget/widget_patterns_require_rules.dart';
export 'widget/widget_patterns_ux_rules.dart';

// Platform-specific rule files
export 'platforms/android_rules.dart';
export 'platforms/ios_capabilities_permissions_rules.dart';
export 'platforms/ios_platform_lifecycle_rules.dart';
export 'platforms/ios_ui_security_rules.dart';
export 'platforms/linux_rules.dart';
export 'platforms/macos_rules.dart';
export 'platforms/web_rules.dart';
export 'platforms/windows_rules.dart';

// Package-specific rule files
export 'packages/bloc_rules.dart';
export 'packages/dio_rules.dart';
export 'packages/drift_rules.dart';
export 'packages/equatable_rules.dart';
export 'packages/firebase_rules.dart';
export 'packages/flame_rules.dart';
export 'packages/flutter_hooks_rules.dart';
export 'packages/geolocator_rules.dart';
export 'packages/get_it_rules.dart';
export 'packages/getx_rules.dart';
export 'packages/graphql_rules.dart';
export 'packages/hive_rules.dart';
export 'packages/isar_rules.dart';
export 'packages/package_specific_rules.dart';
export 'packages/provider_rules.dart';
export 'packages/qr_scanner_rules.dart';
export 'packages/riverpod_rules.dart';
export 'packages/shared_preferences_rules.dart';
export 'packages/sqflite_rules.dart';
export 'packages/supabase_rules.dart';
export 'packages/auto_route_rules.dart';
export 'packages/url_launcher_rules.dart';
export 'packages/rxdart_rules.dart';
export 'packages/workmanager_rules.dart';
