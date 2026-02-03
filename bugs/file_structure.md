# File Structure Reorganization

Move package-specific and platform-specific rule files into dedicated subfolders
for better readability and maintenance.

## Current State

92 rule files live flat in `lib/src/rules/`. Two empty subdirectories
(`packages/`, `platforms/`) exist but are unused.

### Package-specific files (22)

Each covers rules for a third-party package:

| File | Package |
|------|---------|
| `bloc_rules.dart` | bloc |
| `dio_rules.dart` | dio |
| `equatable_rules.dart` | equatable |
| `firebase_rules.dart` | firebase |
| `flame_rules.dart` | flame |
| `flutter_hooks_rules.dart` | flutter_hooks |
| `freezed_rules.dart` | freezed |
| `geolocator_rules.dart` | geolocator |
| `get_it_rules.dart` | get_it |
| `getx_rules.dart` | getx |
| `graphql_rules.dart` | graphql |
| `hive_rules.dart` | hive |
| `isar_rules.dart` | isar |
| `provider_rules.dart` | provider |
| `riverpod_rules.dart` | riverpod |
| `shared_preferences_rules.dart` | shared_preferences |
| `sqflite_rules.dart` | sqflite |
| `supabase_rules.dart` | supabase |
| `url_launcher_rules.dart` | url_launcher |
| `workmanager_rules.dart` | workmanager |
| `package_specific_rules.dart` | misc (Google Sign-In, Apple Sign-In, Webview, etc.) |
| `db_yield_rules.dart` | database utilities |

### Platform-specific files

6 platforms defined in `tiers.dart` via `platformRuleSets`. Only 2 have
dedicated rule files today:

| Platform | Dedicated file | Rule set in `tiers.dart` |
|----------|---------------|--------------------------|
| iOS | `ios_rules.dart` | `iosPlatformRules` + `_applePlatformRules` |
| Android | `android_rules.dart` | `androidPlatformRules` |
| macOS | none | `macosPlatformRules` + `_applePlatformRules` + `_desktopPlatformRules` |
| Web | none | `webPlatformRules` |
| Windows | none | `windowsPlatformRules` (empty) + `_desktopPlatformRules` |
| Linux | none | `linuxPlatformRules` (empty) + `_desktopPlatformRules` |

macOS and Web have rules defined in their tier sets but those rules live in
other category files (no dedicated `macos_rules.dart` or `web_rules.dart`).
Windows and Linux tier sets are empty.

`platform_rules.dart` contains cross-platform detection rules
(`RequirePlatformCheckRule`, `PreferPlatformIoConditionalRule`, etc.) that are
not tied to a single platform and should stay in the general folder.

### General/category files (68)

Everything else: accessibility, animation, api_network, architecture, async,
state_management (9 generic rules), stylistic (base + 6 variants), etc.

## Target structure

```
lib/src/rules/
  all_rules.dart
  platforms/
    android_rules.dart
    ios_rules.dart
    macos_rules.dart             (new, needs new rules written)
    web_rules.dart               (new, needs new rules written)
  packages/
    bloc_rules.dart
    dio_rules.dart
    equatable_rules.dart
    firebase_rules.dart
    flame_rules.dart
    flutter_hooks_rules.dart
    geolocator_rules.dart
    get_it_rules.dart
    getx_rules.dart
    graphql_rules.dart
    hive_rules.dart
    isar_rules.dart
    package_specific_rules.dart
    provider_rules.dart
    qr_scanner_rules.dart
    riverpod_rules.dart
    shared_preferences_rules.dart
    sqflite_rules.dart
    supabase_rules.dart
    url_launcher_rules.dart
    workmanager_rules.dart
  accessibility_rules.dart
  animation_rules.dart
  api_network_rules.dart
  architecture_rules.dart
  async_rules.dart
  bluetooth_hardware_rules.dart
  build_method_rules.dart
  class_constructor_rules.dart
  code_quality_rules.dart
  collection_rules.dart
  complexity_rules.dart
  config_rules.dart
  connectivity_rules.dart
  context_rules.dart
  control_flow_rules.dart
  crypto_rules.dart
  db_yield_rules.dart
  debug_rules.dart
  dependency_injection_rules.dart
  dialog_snackbar_rules.dart
  disposal_rules.dart
  documentation_rules.dart
  equality_rules.dart
  error_handling_rules.dart
  exception_rules.dart
  file_handling_rules.dart
  formatting_rules.dart
  forms_rules.dart
  freezed_rules.dart
  iap_rules.dart
  image_rules.dart
  internationalization_rules.dart
  json_datetime_rules.dart
  lifecycle_rules.dart
  media_rules.dart
  memory_management_rules.dart
  money_rules.dart
  naming_style_rules.dart
  navigation_rules.dart
  notification_rules.dart
  numeric_literal_rules.dart
  performance_rules.dart
  permission_rules.dart
  platform_rules.dart
  record_pattern_rules.dart
  resource_management_rules.dart
  return_rules.dart
  scroll_rules.dart
  security_rules.dart
  state_management_rules.dart
  structure_rules.dart
  stylistic_additional_rules.dart
  stylistic_control_flow_rules.dart
  stylistic_error_testing_rules.dart
  stylistic_null_collection_rules.dart
  stylistic_rules.dart
  stylistic_whitespace_constructor_rules.dart
  stylistic_widget_rules.dart
  test_rules.dart
  testing_best_practices_rules.dart
  theming_rules.dart
  type_rules.dart
  type_safety_rules.dart
  ui_ux_rules.dart
  unnecessary_code_rules.dart
  widget_layout_rules.dart
  widget_lifecycle_rules.dart
  widget_patterns_rules.dart
```

## Files to update after moving

| File | Change |
|------|--------|
| `lib/src/rules/all_rules.dart` | Update export paths for moved files |
| `lib/src/tiers.dart` | No change (references rule names, not file paths) |
| `CODEBASE_INDEX.md` | Document new folder structure |
| `ROADMAP.md` | No change (references rule names, not file paths) |
| `test/` files | Update imports if any reference rule files directly |
