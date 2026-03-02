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

`platform_rules.dart` contains cross-platform detection rules
(`RequirePlatformCheckRule`, `PreferPlatformIoConditionalRule`, etc.) that are
not tied to a single platform and should stay in the general folder.

#### macOS rules (15) — extract from `ios_rules.dart`

All 15 macOS rule classes currently live in `ios_rules.dart`. No helper classes.

| Class | Line |
|-------|------|
| `PreferMacosMenuBarIntegrationRule` | 908 |
| `PreferMacosKeyboardShortcutsRule` | 1008 |
| `RequireMacosWindowSizeConstraintsRule` | 1102 |
| `RequireMacosFileAccessIntentRule` | 3568 |
| `AvoidMacosDeprecatedSecurityApisRule` | 3649 |
| `RequireMacosHardenedRuntimeRule` | 4191 |
| `AvoidMacosCatalystUnsupportedApisRule` | 4296 |
| `RequireMacosWindowRestorationRule` | 6121 |
| `AvoidMacosFullDiskAccessRule` | 6355 |
| `RequireMacosSandboxEntitlementsRule` | 6703 |
| `RequireMacosSandboxExceptionsRule` | 8579 |
| `AvoidMacosHardenedRuntimeViolationsRule` | 8666 |
| `RequireMacosAppTransportSecurityRule` | 8738 |
| `RequireMacosNotarizationReadyRule` | 8811 |
| `RequireMacosEntitlementsRule` | 8890 |

#### Web rules (6 web-specific) — extract from scattered files

Only the web-specific rules move. Shared rules (accessibility, package-specific)
stay in their current category files.

| Class | Current file | Line |
|-------|-------------|------|
| `AvoidPlatformChannelOnWebRule` | `performance_rules.dart` | 2970 |
| `RequireCorsHandlingRule` | `performance_rules.dart` | 3057 |
| `PreferDeferredLoadingWebRule` | `performance_rules.dart` | 3136 |
| `AvoidWebOnlyDependenciesRule` | `platform_rules.dart` | 237 |
| `PreferUrlStrategyForWebRule` | `widget_patterns_rules.dart` | 6423 |
| `RequireWebRendererAwarenessRule` | `widget_patterns_rules.dart` | 7055 |

Rules in `webPlatformRules` that stay in their current files:

| Rule | Current file | Reason |
|------|-------------|--------|
| `avoid_secure_storage_on_web` | `firebase_rules.dart` | Firebase-specific |
| `avoid_isar_web_limitations` | `isar_rules.dart` | Isar-specific |
| `avoid_gesture_only_interactions` | `accessibility_rules.dart` | shared with `_desktopPlatformRules` |
| `avoid_hover_only` | `accessibility_rules.dart` | shared with `_desktopPlatformRules` |
| `require_focus_indicator` | `accessibility_rules.dart` | shared with `_desktopPlatformRules` |

#### Windows and Linux — empty placeholders

`windowsPlatformRules` and `linuxPlatformRules` are empty in `tiers.dart`.
Desktop-shared rules (`_desktopPlatformRules`) stay in their current category
files. Create empty placeholder files matching the pattern of other platform
files.

#### Desktop shared rules (`_desktopPlatformRules`) — stay in current files

These apply to macOS, Windows, and Linux via `_desktopPlatformRules` in
`tiers.dart`. They stay in their category files.

| Rule | Current file | Line |
|------|-------------|------|
| `require_menu_bar_for_desktop` | `performance_rules.dart` | 3227 |
| `require_window_close_confirmation` | `performance_rules.dart` | 3311 |
| `prefer_native_file_dialogs` | `performance_rules.dart` | 3391 |
| `require_window_size_constraints` | `widget_patterns_rules.dart` | 6514 |
| `avoid_touch_only_gestures` | `architecture_rules.dart` | 634 |
| `avoid_gesture_only_interactions` | `accessibility_rules.dart` | 444 |
| `require_focus_indicator` | `accessibility_rules.dart` | 2511 |
| `avoid_hover_only` | `accessibility_rules.dart` | 1695 |

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
    linux_rules.dart             (new, empty placeholder)
    macos_rules.dart             (new, extract 15 rules from ios_rules.dart)
    web_rules.dart               (new, extract 6 rules from 4 files)
    windows_rules.dart           (new, empty placeholder)
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
