# Changelog

All notable changes to this project will be documented in this file.
The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

> **Looking for older changes?** \
> See [CHANGELOG_ARCHIVE.md](./CHANGELOG_ARCHIVE.md) for versions 0.1.0 through 3.4.0.

## [4.5.0] - 2026-01-21

### Added

- **New Dart CLI tool: `bin/init.dart`**
  - Generates `analysis_options.yaml` with explicit `- rule_name: true/false` for all 1668 rules
  - Supports tier selection: `--tier essential|recommended|professional|comprehensive|insanity` (or 1-5)
  - Supports `--stylistic` flag to include opinionated formatting rules
  - Supports `--dry-run` to preview output without writing
  - Creates a backup of the existing file before overwriting

### Changed

- **pubspec.yaml**
  - Added `executables` section exposing `init`, `baseline`, and `impact_report` commands

- **Documentation**
  - Updated `README.md` Quick Start to use the CLI tool
  - Updated "Using a tier", "Customizing rules", "Stylistic Rules", and "Performance" sections
  - Updated troubleshooting to recommend the CLI tool instead of workarounds
  - Updated `README_STYLISTIC.md` to use the CLI approach

### Usage

```bash
# Generate config for comprehensive tier (1618 rules) - recommended
dart run saropa_lints:init --tier comprehensive

# Generate config for essential tier (342 rules) - fastest
dart run saropa_lints:init --tier essential

# Include stylistic rules
dart run saropa_lints:init --tier comprehensive --stylistic

# Preview without writing
dart run saropa_lints:init --dry-run

# See all options
dart run saropa_lints:init --help
```

---

## [4.4.0] - 2026-01-21

### Added

**Split duplicate collection element detection into 3 separate rules** - The original `avoid_duplicate_collection_elements` rule has been replaced with three type-specific rules that can be suppressed independently:

- `avoid_duplicate_number_elements` - Detects duplicate numeric literals (int, double) in lists and sets. Can be suppressed for legitimate cases like `const daysInMonth = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]`.
- `avoid_duplicate_string_elements` - Detects duplicate string literals in lists and sets.
- `avoid_duplicate_object_elements` - Detects duplicate identifiers, booleans, and null literals in lists and sets.

All three rules include quick fixes to remove duplicate elements.

### Removed

- `avoid_duplicate_collection_elements` - Replaced by the three type-specific rules above. If you had this rule disabled in your configuration, update to disable the new rules individually.

### Fixed

**`avoid_variable_shadowing` false positives on sibling closures** - The rule was incorrectly flagging variables with the same name in sibling closures (like separate `test()` callbacks within a `group()`) as shadowing. These are independent scopes, not nested scopes, so they don't actually shadow each other. The rule now properly tracks scope boundaries:

```dart
// Previously flagged incorrectly - now OK
group('tests', () {
  test('A', () { final list = [1]; });  // Scope A
  test('B', () { final list = [2]; });  // Scope B - NOT shadowing
});

// Still correctly flagged - true shadowing
void outer() {
  final list = [1];
  void inner() {
    final list = [2];  // LINT: shadows outer 'list'
  }
}
```

## [4.3.0] - 2026-01-21

### Added

**2 new test-specific magic literal rules** - Test files legitimately use more literal values for test data, expected values, and test descriptions. The existing `no_magic_number` and `no_magic_string` rules now skip test files entirely, and two new test-specific variants provide appropriate enforcement for tests:

- `no_magic_number_in_tests` - Warns when magic numbers are used in test files. More relaxed than the production rule, allowing common test values like HTTP status codes (200, 404, 500), small integers (0-5, 10, 100, 1000), and common floats (0.5, 1.0, 10.0, 100.0). Still encourages named constants for domain-specific values like `29.99` in a product price test.
- `no_magic_string_in_tests` - Warns when magic strings are used in test files. More relaxed than the production rule, allowing common test values like single letters ('a', 'x', 'foo', 'bar') and automatically skipping test descriptions (first argument to `test()`, `group()`, `testWidgets()`, etc.). Still encourages named constants for meaningful test data like email addresses or URLs.

Both rules are in the comprehensive tier with INFO severity. They use `applicableFileTypes: {FileType.test}` to only run on test files.

### Changed

**Production code rules now skip test files** - `no_magic_number` and `no_magic_string` now have `skipTestFiles: true`, preventing false positives on legitimate test data like hex strings ('7FfFfFfFfFfFfFfF'), test descriptions, and expected values. Use the test-specific variants for appropriate enforcement in tests.

### Fixed

**`no_magic_string` and `no_magic_string_in_tests` now skip regex patterns** - The rules were flagging regex pattern strings as magic strings, even when passed directly to `RegExp()` constructors. The rules now detect and skip:
- Strings passed as arguments to `RegExp()` constructors
- Raw strings (`r'...'`) that contain regex-specific syntax (anchors `^`/`$`, quantifiers `+`/`*`/`?`, character classes `\d`/`\w`/`\s`, etc.)

This prevents false positives on legitimate regex patterns like `RegExp(r'0+$')` or `RegExp(r'\d{3}-\d{4}')`.

**`avoid_commented_out_code` and `capitalize_comment_start` false positives on prose comments** - These rules use shared heuristics to detect commented-out code vs prose comments. The previous pattern matched keywords at the start of comments too broadly, causing false positives on natural language sentences like `// null is before non-null` or `// return when the condition is met`. The detection patterns are now context-aware and only match keywords when they appear in actual code contexts:
- Control flow keywords (`if`, `for`, `while`) now require opening parens/braces: `if (` or `while {`
- Simple statements (`return`, `break`, `throw`) now require semicolons or specific literals
- Declarations (`final`, `const`, `var`) now require identifiers after them
- Literals (`null`, `true`, `false`) now require code punctuation (`;`, `,`, `)`) or standalone usage

This eliminates false positives while maintaining detection of actual commented-out code.

## [4.2.3] - 2026-01-20

### Added

**Progress reporting for large codebases** - Real-time feedback during CLI analysis showing files analyzed, elapsed time, and throughput. Reports every 25 files or every 3 seconds, whichever comes first. Output format: `[saropa_lints] Progress: 25 files analyzed (2s, 12.5 files/sec) - home_screen.dart`. Enabled by default, can be disabled via `--define=SAROPA_LINTS_PROGRESS=false`.

**2 new stylistic apostrophe rules** - complementary opposite rules for the existing apostrophe preferences:

- `prefer_doc_straight_apostrophe` - Warns when curly apostrophes (U+2019) are used in doc comments. Opposite of `prefer_doc_curly_apostrophe`. Quick fix replaces curly with straight apostrophes.
- `prefer_curly_apostrophe` - Warns when straight apostrophes are used in string literals instead of curly. Opposite of `prefer_straight_apostrophe`. Quick fix replaces contractions with typographic apostrophes.

Both rules are opinionated and not included in any tier by default. Enable them explicitly if your team prefers consistent apostrophe style.

### Fixed

**`avoid_sensitive_in_logs` false positives** - The rule was matching sensitive keywords (token, credential, session, etc.) in plain string literals, even when they were just descriptive text like `'Updating local token.'` or `'failed (null credential)'`. The rule now uses AST-based detection:

- **Plain string literals** (`SimpleStringLiteral`) → Always safe, no actual data being logged
- **String interpolation** → Only checks the interpolated expressions, not the literal text parts
- **Variable references** (`$password`) → Check if the variable name is sensitive
- **Property access** (`user.token`) → Check if the property name is sensitive
- **Conditionals** → Recursively check the branches, not the condition

**Quick fix added**: Comments out the sensitive log statement with `// SECURITY:` prefix.

**`require_subscription_status_check` false positives on similar identifiers** - The rule used simple substring matching to detect premium indicators like `isPro`, which caused false positives when identifiers contained these as substrings (e.g., `isProportional` falsely matched `isPro`). The rule now uses word boundary regex (`\b`) to match whole words only.

**`require_deep_link_fallback` false positives on utility getters** - The rule was incorrectly flagging utility getters that check URI state (e.g., `isNotUriNullOrEmpty`, `hasValidUri`, `isUriEmpty`) as if they were deep link handlers requiring fallback logic. The rule now skips getters that are clearly utility methods: those starting with `is`, `has`, `check`, `valid`, or ending with `empty`, `null`, or `nullable` (uses suffix matching for precision, so `handleEmptyDeepLink` would still be checked).

**`require_https_only` false positives on safe URL upgrades** - The rule was flagging `http://` strings even when used in safe replacement patterns like `url.replaceFirst('http://', 'https://')`. The rule now detects and allows these safe HTTP-to-HTTPS upgrade patterns using `replaceFirst`, `replaceAll`, or `replace` methods.

**`avoid_mixed_environments` false positives on conditional configs** - The rule was incorrectly flagging classes that use Flutter's mode constants (`kReleaseMode`, `kDebugMode`, `kProfileMode`) to conditionally set values. For example, this pattern was incorrectly flagged:

```dart
class AppModeSettings {
  static const AppModeEnum mode = kDebugMode
      ? AppModeEnum.debug
      : (kProfileMode ? AppModeEnum.profile : AppModeEnum.release);
}
```

The rule now detects fields with mode constant checks and marks them as "properly conditional", skipping both production and development indicator checks for those fields. Doc header enhanced with `[HEURISTIC]` tag and additional examples. Added `requiresClassDeclaration` override for performance.

### Changed

**Rule consolidation** - `avoid_sensitive_data_in_logs` (security_rules.dart) has been removed as a duplicate of `avoid_sensitive_in_logs` (debug_rules.dart). The canonical rule now:
- Has a config alias `avoid_sensitive_data_in_logs` for backwards compatibility
- Uses proper AST analysis instead of regex matching (more accurate)
- Has a quick fix to comment out sensitive log statements

If you had `avoid_sensitive_data_in_logs` in your config, it will continue to work via the alias.

**Shared utility for mode constant detection** - Extracted `usesFlutterModeConstants()` to `mode_constants_utils.dart` for detecting `kReleaseMode`, `kDebugMode`, and `kProfileMode` guards. Used by 5 rule files: config_rules.dart, debug_rules.dart, iap_rules.dart, isar_rules.dart, ios_rules.dart. This also fixed missing `kProfileMode` checks in iap_rules.dart and isar_rules.dart.

## [4.2.2] - 2026-01-19

### Fixed

**Critical bug fixes for rule execution** - Two bugs were causing rules to be silently skipped, resulting in "No issues found" or far fewer issues than expected:

1. **Throttle key missing rule name** - The analysis throttle used `path:contentHash` as a cache key, but didn't include the rule name. When rule A analyzed a file, rules B through Z would see the cache entry and skip the file thinking it was "just analyzed" within the 300ms throttle window. Now uses `path:contentHash:ruleName` so each rule has its own throttle.

2. **Rapid edit mode false triggering** - The adaptive tier switching feature (designed to show only essential rules during rapid IDE saves) was incorrectly triggering during CLI batch analysis. When `dart run custom_lint` ran 268 rules on a file, the edit counter hit 268 in under 2 seconds, triggering "rapid edit mode" and skipping non-essential rules. This check is now disabled for CLI runs.

**Impact**: These bugs affected all users on all platforms. Windows users were additionally affected by path normalization issues fixed in earlier commits.

## [4.2.1] - 2026-01-19

### Changed

- **Rule renamed**: `avoid_mutating_parameters` → `avoid_parameter_reassignment` (old name kept as deprecated alias in doc header). Tier changed from Recommended to Stylistic to reflect that reassignment is a style preference, not a correctness issue.
- **Heuristics improved** - `require_android_backup_rules` now uses word-boundary matching to avoid false positives on keys like "authentication_method"
- **File reorganization** - Consolidated v4.1.7 rules from separate `v417_*.dart` files into their appropriate category files:
  - Caching rules → `memory_management_rules.dart`
  - WebSocket reconnection → `api_network_rules.dart`
  - Currency code rule → `money_rules.dart`
  - Lazy singleton rule → `dependency_injection_rules.dart`
  - Performance rules → `performance_rules.dart`
  - Clipboard/encryption security → `security_rules.dart`
  - State management rules → `state_management_rules.dart`
  - Testing rules → `testing_best_practices_rules.dart`
  - Widget rules → `flutter_widget_rules.dart`

## [4.2.0] - 2026-01-19

### Added

**Config key aliases** - Rules can now define alternate config keys that users can use in `custom_lint.yaml`. This helps when rule names have prefixes (like `enforce_`) that users commonly omit:

```yaml
rules:
  # Both work now:
  - enforce_arguments_ordering: false # canonical name
  - arguments_ordering: false # alias
```

Added aliases for:

- `enforce_arguments_ordering` → `arguments_ordering`
- `enforce_member_ordering` → `member_ordering`
- `enforce_parameters_ordering` → `parameters_ordering`

**41 new lint rules** covering Android platform, in-app purchases, URL launching, permissions, connectivity, geolocation, SQLite, test file handling, and more:

#### Android Platform Rules (android_rules.dart) - 6 rules

- `require_android_permission_request` - Runtime permission not requested before using permission-gated API
- `avoid_android_task_affinity_default` - Multiple activities with default taskAffinity cause back stack issues
- `require_android_12_splash` - Flutter splash may cause double-splash on Android 12+
- `prefer_pending_intent_flags` - PendingIntent without FLAG_IMMUTABLE/FLAG_MUTABLE crashes on Android 12+
- `avoid_android_cleartext_traffic` - HTTP URLs blocked by default on Android 9+
- `require_android_backup_rules` - Sensitive data in SharedPreferences may be backed up

#### In-App Purchase Rules (iap_rules.dart) - 3 rules

- `avoid_purchase_in_sandbox_production` - Hardcoded IAP environment URL causes receipt validation failures
- `require_subscription_status_check` - Premium content shown without verifying subscription status
- `require_price_localization` - Hardcoded prices instead of store-provided localized prices

#### URL Launcher Rules (url_launcher_rules.dart) - 3 rules

- `require_url_launcher_can_launch_check` - launchUrl without canLaunchUrl check
- `avoid_url_launcher_simulator_tests` - URL launcher tests with tel:/mailto: fail on simulator
- `prefer_url_launcher_fallback` - launchUrl without fallback for unsupported schemes

#### Permission Rules (permission_rules.dart) - 3 rules

- `require_location_permission_rationale` - Location permission requested without showing rationale
- `require_camera_permission_check` - Camera initialized without permission check
- `prefer_image_cropping` - Profile image picked without cropping option

#### Connectivity Rules (connectivity_rules.dart) - 1 rule

- `require_connectivity_error_handling` - Connectivity check without error handling

#### Geolocator Rules (geolocator_rules.dart) - 1 rule

- `require_geolocator_battery_awareness` - High-accuracy continuous location tracking without battery consideration

#### SQLite Rules (sqflite_rules.dart) - 1 rule

- `avoid_sqflite_type_mismatch` - SQLite type may not match Dart type (bool vs INTEGER, DateTime vs TEXT)

#### Rules Added to Existing Files - 19 rules

- **firebase_rules.dart**: `require_firestore_index` - Firestore query requires composite index
- **notification_rules.dart**: `prefer_notification_grouping`, `avoid_notification_silent_failure`
- **hive_rules.dart**: `require_hive_migration_strategy`
- **async_rules.dart**: `avoid_stream_sync_events`, `avoid_sequential_awaits`
- **file_handling_rules.dart**: `prefer_streaming_for_large_files`, `require_file_path_sanitization`
- **error_handling_rules.dart**: `require_app_startup_error_handling`, `avoid_assert_in_production`
- **accessibility_rules.dart**: `prefer_focus_traversal_order`
- **ui_ux_rules.dart**: `avoid_loading_flash`
- **performance_rules.dart**: `avoid_animation_in_large_list`, `prefer_lazy_loading_images`
- **json_datetime_rules.dart**: `require_json_schema_validation`, `prefer_json_serializable`
- **forms_rules.dart**: `prefer_regex_validation`
- **package_specific_rules.dart**: `prefer_typed_prefs_wrapper`, `prefer_freezed_for_data_classes`

#### Test File Length Rules (structure_rules.dart) - 4 rules

Separate file length rules for test files with higher thresholds, allowing comprehensive test suites without triggering production file length warnings:

- `prefer_small_test_files` - Test files over 400 lines (insanity tier)
- `avoid_medium_test_files` - Test files over 600 lines (professional tier)
- `avoid_long_test_files` - Test files over 1000 lines (comprehensive tier)
- `avoid_very_long_test_files` - Test files over 2000 lines (recommended tier)

Production file length rules (`prefer_small_files`, `avoid_medium_files`, `avoid_long_files`, `avoid_very_long_files`) now skip test files automatically.

### Tier Assignments

- **Essential tier:** 14 rules (permissions, security, crashes)
- **Recommended tier:** 10 rules (best practices, UX improvements)
- **Professional tier:** 13 rules (architecture, performance, maintainability)

#### Parameter Safety Rules (code_quality_rules.dart) - 1 new rule + 1 renamed

- `avoid_parameter_mutation` **(NEW)** - Detects when parameter objects are mutated (caller's data modified). Essential tier.
- `avoid_parameter_reassignment` - Renamed from `avoid_mutating_parameters`. Detects parameter variable reassignment. Moved to Stylistic tier.

**Quick fix for `prefer_explicit_type_arguments`** - Adds explicit type arguments to empty collection literals and generic constructor calls.

**Conflicting rule detection** - Warns at analysis startup when mutually exclusive stylistic rules are both enabled:

- `avoid_inferrable_type_arguments` ↔ `prefer_explicit_type_arguments`
- `prefer_relative_imports` ↔ `always_use_package_imports`

**Stylistic rule tier changes** - Removed opposing stylistic rules from Comprehensive tier (now opt-in only):

- `avoid_inferrable_type_arguments` - conflicts with `prefer_explicit_type_arguments`
- `prefer_explicit_type_arguments` - conflicts with `avoid_inferrable_type_arguments`

### Changed

- **Rule renamed**: `avoid_mutating_parameters` → `avoid_parameter_reassignment` (old name kept as deprecated alias in doc header). Tier changed from Recommended to Stylistic to reflect that reassignment is a style preference, not a correctness issue.
- **Heuristics improved** - `require_android_backup_rules` now uses word-boundary matching to avoid false positives on keys like "authentication_method"

### Fixed

- **`function_always_returns_null` false positives on void functions** - The rule was incorrectly flagging void functions that use bare `return;` statements for early exit. Now correctly skips:
  - Functions with explicit `void` return type
  - Functions with `Future<void>` or `FutureOr<void>` return types (including type aliases via resolved type checking)
  - Functions with no explicit return type that only use bare `return;` statements (inferred void)

- **`capitalize_comment_start` code detection overhauled** - The previous regex pattern `[:\.\(\)\[\]\{\};,=>]` was too broad, matching ANY comment containing punctuation (periods, colons, commas). This caused massive false negatives where legitimate prose comments like `// this is important.` were incorrectly skipped as "code". The new pattern specifically detects:
  - Identifier followed by code punctuation: `foo.bar`, `x = 5`
  - Dart keywords at start: `return`, `if (`, `final x`
  - Function calls: `doSomething()`, `list.add(item)`
  - Statement terminators: ends with `;`
  - Annotations: `@override`
  - Arrow functions: `=>`
  - Block delimiters at boundaries: `{`, `}`

  **Quick fix added**: Capitalizes the first letter of the comment.

- **`avoid_commented_out_code` completely overhauled** - Moved from `debug_rules.dart` to `stylistic_rules.dart`. The rule now:
  - Reports at the **actual comment location** (previously reported at file start)
  - Reports **all instances** (previously only reported once per file)
  - Has a **quick fix** to delete the commented-out code
  - Uses shared `CommentPatterns` utility with `capitalize_comment_start`
  - **Tier changed**: Moved from Insanity tier to Stylistic tier (not enabled by default in any tier)

- **New shared utility: `comment_utils.dart`** - Extracted common comment detection patterns into `CommentPatterns` class used by both `capitalize_comment_start` and `avoid_commented_out_code`. This ensures consistent behavior between the two complementary rules.

### Improved

**`prefer_utc_for_storage` rule enhanced:**

- Added 6 new serialization patterns: `toJson`, `toMap`, `serialize`, `encode`, `cache`, `persist`
- Removed `toString()` from method check (reduces false positives from logging/debugging)
- Patterns moved to `static final` class member (compiled once at class load, not per invocation)
- Added comprehensive doc header with multiple BAD/GOOD examples
- **Quick fix added**: Inserts `.toUtc()` before the serialization call

**DX message quality for 60+ lint rules** - Added clear consequences to problem messages explaining _why_ issues matter. Messages now follow the pattern: "[What's wrong]. [Why it matters]." Extended short messages to meet 180-character minimum for critical/high impact rules.

#### Security Rules (11 rules)

- `avoid_sensitive_data_in_clipboard` - "Malicious apps can silently read clipboard contents, stealing passwords, tokens, or API keys"
- `require_certificate_pinning` - "Attackers on the same network can intercept and modify traffic"
- `avoid_generic_key_in_url` - "Exposes credentials in access logs and browser history"
- `avoid_jwt_decode_client` - "Attackers can manipulate decoded claims to bypass permissions"
- `require_logout_cleanup` - "Next user on shared device could access previous user data"
- `require_deep_link_validation` - "Malicious links can inject arbitrary data, leading to crashes or unauthorized access"
- `require_shared_prefs_null_handling` - "Common source of production crashes on first launch or after app updates"
- `require_url_validation` - "Attackers can make your app request internal network resources"
- `prefer_webview_javascript_disabled` - "Malicious scripts can steal data or execute arbitrary code"
- `avoid_unsafe_deserialization` - "Attackers can exploit this to corrupt state or trigger unexpected behavior"
- `avoid_notification_payload_sensitive` - "Anyone nearby can see passwords, tokens, or PII without unlocking"

#### Performance Rules (7 rules)

- `prefer_const_widgets` - "Wastes CPU cycles and battery, slowing down UI rendering"
- `avoid_widget_creation_in_loop` - "Causes jank and high memory usage for long lists"
- `avoid_calling_of_in_build` - "Adds unnecessary overhead that slows down frame rendering"
- `avoid_rebuild_on_scroll` - "Memory leaks and duplicate callbacks that compound over time"
- `avoid_shrinkwrap_in_scrollview` - "Forces all items to render immediately, causing jank"
- `avoid_text_span_in_build` - "Causes visible jank when scrolling or animating"
- `avoid_money_arithmetic_on_double` - "Users may be charged incorrect amounts or see wrong totals"

#### State Management Rules (7 rules)

- `avoid_bloc_in_bloc` - "Makes testing difficult and breaks unidirectional data flow"
- `avoid_static_state` - "Causes flaky tests, unexpected state retention, and hard-to-reproduce bugs"
- `require_bloc_manual_dispose` - "Memory leaks that accumulate over time, eventually crashing the app"
- `prefer_bloc_listener_for_side_effects` - "Causes duplicate navigation, multiple snackbars, or repeated API calls"
- `avoid_bloc_context_dependency` - "Makes Bloc untestable and can cause crashes when context is invalid"
- `avoid_provider_value_rebuild` - "Loses all state and causes infinite rebuild loops"
- `avoid_ref_watch_outside_build` - "Causes missed updates, stale data, and hard-to-debug state inconsistencies"

#### Notification Rules (3 rules)

- `avoid_notification_same_id` - "Users will miss important alerts and messages without any indication"
- `require_notification_initialize_per_platform` - "Users on unsupported platform will never receive notifications"
- `avoid_refresh_without_await` - "Spinner dismisses immediately while data is still loading"

#### Other Rules (7 rules)

- `avoid_image_picker_without_source` - "Users will see an empty dialog and be unable to select images"
- `avoid_unbounded_cache_growth` - "Eventually exhausts device memory and crashes the app"
- `require_websocket_reconnection` - "Users will see stale data or miss real-time updates"
- `require_sqflite_error_handling` - "Operations can fail due to disk full, corruption, or constraint violations"
- `require_avatar_fallback` - "Users will see a broken or blank avatar with no indication of the error"
- `require_image_error_fallback` - "Users see an ugly error state instead of a graceful fallback"
- `require_google_signin_error_handling` / `require_supabase_error_handling` - "Users will see unexpected crashes instead of friendly error messages"

#### Disposal & Memory Rules (10 rules)

- `require_stream_controller_close` - "Listeners accumulate in memory, eventually crashing the app"
- `require_video_player_controller_dispose` - "Video decoder stays active, audio continues, battery drains"
- `require_change_notifier_dispose` - "Disposed widgets remain referenced, crashes on notification"
- `require_receive_port_close` - "Isolate port stays open, memory leaks accumulate"
- `require_socket_close` - "TCP connection stays occupied, file descriptors leak"
- `require_lifecycle_observer` - "Timer drains battery and stale callbacks cause inconsistent state"
- `avoid_closure_memory_leak` - "StatefulWidget leaks memory, setState crashes on unmounted"
- `require_dispose_pattern` - "Controllers leak memory and crash when accessed after disposal"
- `require_hive_box_close` - "File handle stays open, database can't compact"
- `require_getx_permanent_cleanup` - "GetxController remains in memory forever"

#### Additional Security Rules (8 rules)

- `avoid_dynamic_sql` - "Attackers can read, modify, or delete database contents"
- `avoid_ignoring_ssl_errors` - "Man-in-the-middle attackers can intercept all HTTPS traffic"
- `avoid_user_controlled_urls` - "SSRF vulnerability allows attackers to access internal services"
- `require_apple_signin_nonce` - "Replay attacks allow impersonation of the user"
- `require_webview_ssl_error_handling` - "Invalid certificates silently accepted, credentials stolen"
- `prefer_secure_random_for_crypto` - "Predictable seed allows attackers to guess keys and tokens"
- `require_unique_iv_per_encryption` - "Same key+IV breaks confidentiality"
- `avoid_webview_file_access` - "Malicious content can read local files, exposing data"

#### Platform & Context Rules (6 rules)

- `avoid_mixed_environments` - "Debug APIs expose data, development endpoints corrupt production"
- `avoid_storing_context` - "Stored context crashes when widget disposed"
- `avoid_web_only_dependencies` - "Web-only imports crash on mobile and desktop"
- `avoid_future_tostring` - "Logs show useless output, debugging becomes impossible"
- `require_ios_callkit_integration` - "Calls fail to show, App Store rejection"
- `avoid_navigator_push_unnamed` - "Deep linking fails, users can't share screens"

#### Widget & State Rules (7 rules)

- `avoid_obs_outside_controller` - "Observables leak memory without lifecycle management"
- `pass_existing_future_to_future_builder` - "Duplicate network calls, slow UI with visible loading"
- `require_late_initialization_in_init_state` - "Objects recreated on every setState"
- `require_media_loading_state` - "Shows black rectangle or crashes"
- `list_all_equatable_fields` - "Equality checks fail silently"
- `require_openai_error_handling` - "Rate limits crash instead of graceful fallback"
- `prefer_value_listenable_builder` - "Full-widget rebuilds cause jank"

## [4.1.9] - 2026-01-18

### Changed

**Tier rebalancing** - Redistributed rules across tiers to match tier philosophy:

- **Essential**: Now strictly crash/security/memory-leak rules. Removed style preferences (`prefer_list_first`, `enforce_member_ordering`, `avoid_continue_statement`). Added crash-causing rules from Recommended (`require_getit_registration_order`, `require_default_config`, `avoid_builder_index_out_of_bounds`).

- **Stylistic**: Expanded with ordering/naming rules that were incorrectly in Essential/Recommended. Now 129 rules for formatting, ordering, and naming conventions.

- **Comprehensive**: Expanded from 5 to 51 rules. Added optimization hints and strict patterns from Professional (immutability patterns, type strictness, documentation extras, testing extras).

- **Insanity**: Expanded from 1 to 10 rules. Added pedantic rules like `avoid_object_creation_in_hot_loops`, `prefer_feature_folder_structure`, `avoid_returning_widgets`.

**Documentation**: Updated README tier table with detailed purpose, target user, and examples for each tier.

## [4.1.8] - 2026-01-18

### Added

**25 new lint rules** focusing on state management, performance, security, caching, testing, and widgets:

#### State Management Rules (v417_state_rules.dart)

- `avoid_riverpod_for_network_only` - `[HEURISTIC]` Riverpod just for network access is overkill
- `avoid_large_bloc` - `[HEURISTIC]` Blocs with too many event handlers (>7) need splitting
- `avoid_overengineered_bloc_states` - `[HEURISTIC]` Too many state subclasses; use single state
- `avoid_getx_static_context` - Get.offNamed/Get.dialog use untestable static context
- `avoid_tight_coupling_with_getx` - `[HEURISTIC]` Heavy GetX usage reduces testability

#### Performance Rules (v417_performance_rules.dart)

- `prefer_element_rebuild` - Conditional widget returns destroy Elements and state
- `require_isolate_for_heavy` - Heavy computation blocks UI (jsonDecode, encrypt)
- `avoid_finalizer_misuse` - Finalizers add GC overhead; prefer dispose()
- `avoid_json_in_main` - `[HEURISTIC]` jsonDecode in async context should use compute()

#### Security Rules (v417_security_rules.dart)

- `avoid_sensitive_data_in_clipboard` - `[HEURISTIC]` Clipboard accessible to other apps
- `require_clipboard_paste_validation` - Validate clipboard content before using
- `avoid_encryption_key_in_memory` - `[HEURISTIC]` Keys as fields can be extracted from dumps

#### Caching Rules (v417_caching_rules.dart)

- `require_cache_expiration` - `[HEURISTIC]` Caches without TTL serve stale data forever
- `avoid_unbounded_cache_growth` - `[HEURISTIC]` Caches without limits cause OOM
- `require_cache_key_uniqueness` - Cache keys need stable hashCode

#### Testing Rules (v417_testing_rules.dart)

- `require_dialog_tests` - Dialogs need pumpAndSettle after showing
- `prefer_fake_platform` - Platform widgets need fakes/mocks in tests
- `require_test_documentation` - `[HEURISTIC]` Complex tests (>15 lines) need comments

#### Widget Rules (v417_widget_rules.dart)

- `prefer_custom_single_child_layout` - Deep positioning nesting should use delegate
- `require_locale_for_text` - DateFormat/NumberFormat need explicit locale
- `require_dialog_barrier_consideration` - `[HEURISTIC]` Destructive dialogs need explicit barrierDismissible
- `prefer_feature_folder_structure` - `[HEURISTIC]` Type-based folders (/blocs/) should be feature-based

#### Misc Rules (v417_misc_rules.dart)

- `require_websocket_reconnection` - `[HEURISTIC]` WebSocket needs reconnection logic
- `require_currency_code_with_amount` - `[HEURISTIC]` Money amounts need currency field
- `prefer_lazy_singleton_registration` - `[HEURISTIC]` Expensive services should be lazy

### Tier Assignments

- **Essential tier:** 3 rules (websocket, clipboard security, cache limits)
- **Recommended tier:** 5 rules (dialog tests, clipboard validation, currency, cache TTL, dialog barrier)
- **Professional tier:** 11 rules (locale, state management, performance, security, caching)
- **Comprehensive tier:** 5 rules (folder structure, element rebuild, finalizer, platform fakes, test docs)
- **Insanity tier:** 1 rule (CustomSingleChildLayout preference)

### Changed

- **Shared utilities extracted** - Added `isInsideIsolate()` and `isInAsyncContext()` to `async_context_utils.dart` to reduce code duplication across performance rules
- **Performance file type filtering** - Added `applicableFileTypes` to `RequireDialogBarrierConsiderationRule` to skip non-widget files
- **Template updated** - Added all 25 new rules to `analysis_options_template.yaml` with proper categorization

## [4.1.7] - 2026-01-18

### Fixed

**Critical Windows compatibility bugs** that caused rules to not fire on Windows:

- **Cache key incomplete** - Rule filtering cache only checked `tier` and `enableAll`, ignoring individual rule overrides like `- always_fail_test_case: true`. Now includes hash of all rule configurations.

- **Windows path normalization** - File paths used as map keys without normalizing backslashes. On Windows, analyzer provides `d:\src\file.dart` but caches may store `d:/src/file.dart`. Added `normalizePath()` utility and fixed 15+ locations:
  - `IncrementalAnalysisTracker` - disk-persisted cache
  - `RuleBatchExecutor` - batch execution plan
  - `BaselineAwareEarlyExit` - baseline suppression
  - `FileContentCache` - content change detection
  - `FileTypeDetector` - file type classification
  - `ProjectContext.findProjectRoot()` - project detection

### Added

- `normalizePath()` utility function with documentation to prevent future path issues

## [4.1.6] - 2026-01-18

### Added

**14 new lint rules** focusing on logging, platform safety, JSON/API handling, and configuration:

#### Logging Rules (debug_rules.dart)

- `avoid_print_in_release` - print() executes in release builds; guard with kDebugMode
- `require_structured_logging` - Use structured logging instead of string concatenation
- `avoid_sensitive_in_logs` - Detect passwords, tokens, secrets in log calls

#### Platform Rules (platform_rules.dart)

- `require_platform_check` - Platform-specific APIs need Platform/kIsWeb guards
- `prefer_platform_io_conditional` - Platform.isX crashes on web; use kIsWeb first
- `avoid_web_only_dependencies` - dart:html and web-only imports crash on mobile
- `prefer_foundation_platform_check` - Use defaultTargetPlatform in widget code

#### JSON/API Rules (json_datetime_rules.dart)

- `require_date_format_specification` - DateTime.parse may fail on server dates
- `prefer_iso8601_dates` - Use ISO 8601 format for date serialization
- `avoid_optional_field_crash` - JSON field chaining needs null-aware operators
- `prefer_explicit_json_keys` - Use @JsonKey instead of manual mapping

#### Configuration Rules (config_rules.dart)

- `avoid_hardcoded_config` - Hardcoded URLs/keys should use environment variables
- `avoid_mixed_environments` - Don't mix production and development config

#### Lifecycle Rules (lifecycle_rules.dart)

- `require_late_initialization_in_init_state` - Late fields should init in initState(), not build()

### Tier Assignments

- **Essential tier:** 9 rules for critical safety (print in release, platform crashes, etc.)
- **Recommended tier:** 2 rules for best practices
- **Professional tier:** 3 rules for code quality

## [4.1.5] - 2026-01-18

### Added

**24 new lint rules** focusing on architecture, accessibility, navigation, and internationalization:

#### Dependency Injection Rules

- `avoid_di_in_widgets` - Widgets shouldn't directly use GetIt/service locators
- `prefer_abstraction_injection` - Inject abstract types, not concrete implementations

#### Accessibility Rules

- `prefer_large_touch_targets` - Touch targets should be at least 48dp for WCAG compliance
- `avoid_time_limits` - Short durations (< 5s) disadvantage users needing more time
- `require_drag_alternatives` - Provide button alternatives for drag gestures

#### Flutter Widget Rules

- `avoid_global_keys_in_state` - GlobalKey fields in StatefulWidget cause issues
- `avoid_static_route_config` - Static final router configs limit testability

#### State Management Rules

- `require_flutter_riverpod_not_riverpod` - Flutter apps need flutter_riverpod, not base riverpod
- `avoid_riverpod_navigation` - Navigation logic belongs in widgets, not providers

#### Firebase Rules

- `require_firebase_error_handling` - Firebase async calls need try-catch
- `avoid_firebase_realtime_in_build` - Don't start Firebase listeners in build method

#### Security Rules

- `require_secure_storage_error_handling` - Secure storage needs error handling
- `avoid_secure_storage_large_data` - Large data shouldn't use secure storage

#### Navigation Rules

- `avoid_navigator_context_issue` - Avoid GlobalKey.currentContext in navigation
- `require_pop_result_type` - Navigator.push should specify result type parameter
- `avoid_push_replacement_misuse` - Don't use pushReplacement for detail pages
- `avoid_nested_navigators_misuse` - Nested Navigators need WillPopScope/PopScope
- `require_deep_link_testing` - Routes should support deep links, not just object params

#### Internationalization Rules

- `avoid_string_concatenation_l10n` - String concatenation in Text breaks translations
- `prefer_intl_message_description` - Intl.message needs desc parameter for translators
- `avoid_hardcoded_locale_strings` - Don't hardcode strings that need localization

#### Async Rules

- `require_network_status_check` - Check connectivity before network requests
- `avoid_sync_on_every_change` - Debounce API calls in onChanged callbacks
- `require_pending_changes_indicator` - Notify users when changes haven't synced

### Tier Assignments

- **Recommended tier:** 14 rules for common best practices
- **Professional tier:** 11 rules for stricter architecture/quality standards

## [4.1.4] - 2026-01-18

### Added

**25 new lint rules** from ROADMAP star priorities:

#### Bloc/Cubit Rules

- `avoid_passing_bloc_to_bloc` - Detects Bloc depending on another Bloc (tight coupling)
- `avoid_passing_build_context_to_blocs` - Warns when BuildContext is passed to Bloc/Cubit
- `avoid_returning_value_from_cubit_methods` - Cubit methods should emit states, not return values
- `require_bloc_repository_injection` - Blocs should receive repositories via constructor injection
- `prefer_bloc_hydration` - Suggests HydratedBloc for persistent state instead of SharedPreferences

#### GetX Rules

- `avoid_getx_dialog_snackbar_in_controller` - UI dialogs shouldn't be called from controllers
- `require_getx_lazy_put` - Prefer lazyPut for efficient GetX dependency injection

#### Hive/SharedPreferences Rules

- `prefer_hive_lazy_box` - Use LazyBox for potentially large collections
- `avoid_hive_binary_storage` - Don't store large binary data in Hive
- `require_shared_prefs_prefix` - Set prefix to avoid key conflicts
- `prefer_shared_prefs_async_api` - Use SharedPreferencesAsync for new code
- `avoid_shared_prefs_in_isolate` - SharedPreferences doesn't work in isolates

#### Stream Rules

- `prefer_stream_distinct` - Add .distinct() before .listen() for UI streams
- `prefer_broadcast_stream` - Use broadcast streams when multiple listeners needed

#### Async/Build Rules

- `avoid_future_in_build` - Don't create Futures inside build() method
- `require_mounted_check_after_await` - Check mounted before setState after await
- `avoid_async_in_build` - Build methods must never be async
- `prefer_async_init_state` - Use Future field + FutureBuilder pattern

#### Widget Lifecycle Rules

- `require_widgets_binding_callback` - Wrap showDialog in addPostFrameCallback in initState

#### Navigation Rules

- `prefer_route_settings_name` - Include RouteSettings with name for debugging

#### Internationalization Rules

- `prefer_number_format` - Use NumberFormat for locale-aware number formatting
- `provide_correct_intl_args` - Intl.message args must match placeholders

#### Package-specific Rules

- `avoid_freezed_for_logic_classes` - Freezed is for data classes, not Blocs/Services

#### Disposal Rules

- `dispose_class_fields` - Classes with disposable fields need dispose/close methods

#### State Management Rules

- `prefer_change_notifier_proxy_provider` - Use ProxyProvider for dependent notifiers

### Tier Assignments

- **Essential tier:** avoid_shared_prefs_in_isolate, avoid_future_in_build, require_mounted_check_after_await, provide_correct_intl_args, dispose_class_fields, avoid_async_in_build
- **Recommended tier:** 17 rules covering best practices
- **Professional tier:** require_bloc_repository_injection, avoid_freezed_for_logic_classes

## [4.1.3] - 2026-01-14

- Migrated all single/double-word lint rules to three-word convention for clarity and discoverability. Notable migrations include:
  - `arguments_ordering` → `enforce_arguments_ordering`
  - `capitalize_comment` → `capitalize_comment_start`
  - `prefer_first_method_usage` → `prefer_list_first`
  - `prefer_last_method_usage` → `prefer_list_last`
  - `prefer_member_ordering` → `enforce_member_ordering`
  - `prefer_container_widget` → `prefer_single_container`
  - `prefer_pagination_pattern` → `prefer_api_pagination`
  - `prefer_contains_method_usage` → `prefer_list_contains`
  - `avoid_dynamic_typing` → `avoid_dynamic_type`
  - `avoid_substring_usage` → `avoid_string_substring`
  - `avoid_continue_statement` → `avoid_continue_statement`
  - `extend_equatable` → `require_extend_equatable`
  - `require_dispose_method` → `require_field_dispose`
  - `dispose_fields` → `dispose_widget_fields`
  - `parameters_ordering` → `enforce_parameters_ordering`
  - `format_comment` → `format_comment_style`
  - `max_imports` → `limit_max_imports`
  - `avoid_shadowing` → `avoid_variable_shadowing`
  - `prefer_selector` → `prefer_context_selector`
  - `dispose_providers` → `dispose_provider_instances`
  - `prefer_first` → `prefer_list_first`
  - `prefer_last` → `prefer_list_last`
  - `prefer_contains` → `prefer_list_contains`
  - `prefer_container` → `prefer_single_container`
  - `prefer_pagination` → `prefer_api_pagination`
  - `avoid_dynamic` → `avoid_dynamic_type`
  - `avoid_substring` → `avoid_string_substring`
  - `member_ordering` → `enforce_member_ordering`
  - `parameters_ordering` → `enforce_parameters_ordering`
  - `format_comment` → `format_comment_style`
  - `require_dispose` → `require_field_dispose`
  - `dispose_fields` → `dispose_widget_fields`
  - `avoid_continue` → `avoid_continue_statement`
  - `extend_equatable` → `require_extend_equatable`
  - `avoid_shadowing` → `avoid_variable_shadowing`

## [4.1.2] - 2026-01-13

### Fixed

- Removed a stray change log entry from the readme

## [4.1.1] - 2026-01-13

### Added

- **New Rule:** `avoid_cached_isar_stream` ([lib/src/rules/isar_rules.dart])
  - Detects and prevents caching of Isar query streams (must be created inline).
  - **Tier:** Professional
  - **Quick Fix:** Inlines offending Isar stream expressions at usage sites and removes the cached variable.
  - **Example:** [example/lib/isar/avoid_cached_isar_stream_fixture.dart]

### Tier Assignment for Previously Unassigned Rules

The following 6 rules, previously implemented but not assigned to any tier, are now included in the most appropriate tier sets in `lib/src/tiers.dart`:

- **Recommended Tier:**
  - `avoid_duplicate_test_assertions` (test quality)
  - `avoid_real_network_calls_in_tests` (test reliability)
  - `require_error_case_tests` (test completeness)
  - `require_test_isolation` (test reliability)
  - `prefer_where_or_null` (idiomatic Dart collections)
- **Professional Tier:**
  - `prefer_copy_with_for_state` (state management, immutability)

This ensures all implemented rules are available through tiered configuration and improves coverage for test and state management best practices.

### Rule Tier Assignment Audit

- Ran `scripts/audit_rules.py` to identify all implemented rules not assigned to any tier.
- Assigned the following rules to the most appropriate tier sets in `lib/src/tiers.dart`:
  - **Recommended:** `avoid_duplicate_test_assertions`, `avoid_real_network_calls_in_tests`, `require_error_case_tests`, `require_test_isolation`, `prefer_where_or_null`
  - **Professional:** `prefer_copy_with_for_state`
- All implemented rules are now available through tiered configuration. This ensures no orphaned rules and improves test and state management coverage.
- Updated changelog to document these assignments and maintain full transparency of tier coverage.

### Tier Set Maintenance

- Commented out unimplemented rules in all tier sets in `lib/src/tiers.dart` to ensure only implemented rules are active per tier.
- Confirmed all unimplemented rules are tracked in `ROADMAP.md` for future implementation.
- This change improves roadmap alignment and prevents accidental activation of unimplemented rules.
- Materially improve the message quality for all Critial rules

## [4.1.0] - 2026-01-12

### Tier Assignment Audit

**181 rules** previously unassigned to any tier are now properly categorized. These rules existed but were not included in tier configurations, meaning users weren't getting them unless explicitly enabled.

#### Essential Tier (+50 rules)

Critical and high-impact rules now included in the essential tier:

| Category                  | Rules Added                                                                                                                                                                                                                                                          |
| ------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Security**              | `avoid_deep_link_sensitive_params`, `avoid_path_traversal`, `avoid_webview_insecure_content`, `require_data_encryption`, `require_secure_password_field`, `prefer_html_escape`                                                                                       |
| **JSON/Type Safety**      | `avoid_dynamic_json_access`, `avoid_dynamic_json_chains`, `avoid_unrelated_type_casts`, `require_null_safe_json_access`                                                                                                                                              |
| **Platform Permissions**  | `avoid_platform_channel_on_web`, `require_image_picker_permission_android`, `require_image_picker_permission_ios`, `require_permission_manifest_android`, `require_permission_plist_ios`, `require_url_launcher_queries_android`, `require_url_launcher_schemes_ios` |
| **Memory/Resource Leaks** | `avoid_stream_subscription_in_field`, `avoid_websocket_memory_leak`, `prefer_dispose_before_new_instance`, `require_dispose_implementation`, `require_video_player_controller_dispose`                                                                               |
| **Widget Lifecycle**      | `check_mounted_after_async`, `avoid_ref_in_build_body`, `avoid_flashing_content`                                                                                                                                                                                     |
| **Animation**             | `avoid_animation_rebuild_waste`, `avoid_overlapping_animations`                                                                                                                                                                                                      |
| **Navigation**            | `prefer_maybe_pop`, `require_deep_link_fallback`, `require_stepper_validation`                                                                                                                                                                                       |
| **Firebase/Backend**      | `prefer_firebase_remote_config_defaults`, `require_background_message_handler`, `require_fcm_token_refresh_handler`                                                                                                                                                  |
| **Forms/WebView**         | `require_validator_return_null`, `avoid_image_picker_large_files`, `prefer_webview_javascript_disabled`, `require_webview_error_handling`, `require_webview_navigation_delegate`, `require_websocket_message_validation`                                             |
| **Data/Storage**          | `prefer_utc_for_storage`, `require_database_migration`, `require_enum_unknown_value`                                                                                                                                                                                 |
| **State/UI**              | `require_error_widget`, `require_feature_flag_default`, `require_immutable_bloc_state`, `require_map_idle_callback`, `require_media_loading_state`, `prefer_bloc_listener_for_side_effects`, `require_cors_handling`                                                 |

#### Recommended Tier (+83 rules)

Medium-impact rules for better code quality:

| Category                | Rules Added                                                                                                                                                                                                                                                                             |
| ----------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Widget Structure**    | `avoid_deep_widget_nesting`, `avoid_find_child_in_build`, `avoid_layout_builder_in_scrollable`, `avoid_nested_providers`, `avoid_opacity_misuse`, `avoid_shrink_wrap_in_scroll`, `avoid_unbounded_constraints`, `avoid_unconstrained_box_misuse`                                        |
| **Gesture/Input**       | `avoid_double_tap_submit`, `avoid_gesture_conflict`, `avoid_gesture_without_behavior`, `prefer_actions_and_shortcuts`, `prefer_cursor_for_buttons`, `require_disabled_state`, `require_drag_feedback`, `require_focus_indicator`, `require_hover_states`, `require_long_press_callback` |
| **Forms/Testing**       | `require_button_loading_state`, `require_form_validation`, `avoid_flaky_tests`, `avoid_real_timer_in_widget_test`, `avoid_stateful_test_setup`, `prefer_matcher_over_equals`, `prefer_mock_http`, `require_golden_test`, `require_mock_verification`                                    |
| **Performance**         | `avoid_hardcoded_layout_values`, `avoid_hardcoded_text_styles`, `avoid_large_images_in_memory`, `avoid_map_markers_in_build`, `avoid_stack_overflow`, `prefer_clip_behavior`, `prefer_deferred_loading_web`, `prefer_keep_alive`, `prefer_sliver_app_bar`, `prefer_sliver_list`         |
| **State Management**    | `avoid_late_context`, `prefer_cubit_for_simple_state`, `prefer_selector_over_consumer`, `require_bloc_consumer_when_both`                                                                                                                                                               |
| **Accessibility**       | `avoid_screenshot_sensitive`, `avoid_semantics_exclusion`, `prefer_merge_semantics`, `avoid_small_text`                                                                                                                                                                                 |
| **Database/Navigation** | `require_database_index`, `prefer_transaction_for_batch`, `prefer_typed_route_params`, `require_refresh_indicator`, `require_scroll_controller`, `require_scroll_physics`                                                                                                               |
| **Desktop/i18n**        | `require_menu_bar_for_desktop`, `require_window_close_confirmation`, `require_intl_locale_initialization`, `require_notification_timezone_awareness`                                                                                                                                    |

#### Comprehensive Tier (+48 rules)

Low-impact style and pattern rules:

- Code style: `avoid_digit_separators`, `avoid_nested_try_statements`, `avoid_type_casts`
- Documentation: `prefer_doc_comments_over_regular`, `prefer_error_suffix`, `prefer_exception_suffix`
- Patterns: `prefer_class_over_record_return`, `prefer_record_over_equatable`, `prefer_guard_clauses`
- Async: `prefer_async_only_when_awaiting`, `prefer_await_over_then`, `prefer_sync_over_async_where_possible`
- Testing: `prefer_expect_over_assert_in_tests`, `prefer_single_expectation_per_test`
- And 33 more...

#### Intentionally Untiered (81 rules)

Stylistic/opinionated rules remain untiered for team-specific configuration:

- Quote style: `prefer_single_quotes` vs `prefer_double_quotes`
- Import style: `prefer_relative_imports` vs `prefer_absolute_imports`
- Member ordering: `prefer_fields_before_methods` vs `prefer_methods_before_fields`
- Control flow: `prefer_ternary_over_if_null` vs `prefer_if_null_over_ternary`
- Debug rules: `always_fail`, `greeting`, `firebase_custom`

---

## [4.0.1] - 2026-01-12

### Testing Best Practices Rules

Activated 5 previously unregistered testing best practices rules:

| Rule                                  | Tier         | Description                                                              |
| ------------------------------------- | ------------ | ------------------------------------------------------------------------ |
| `prefer_test_find_by_key`             | Recommended  | Suggests `find.byKey()` over `find.byType()` for reliable widget testing |
| `prefer_setup_teardown`               | Recommended  | Detects duplicated test setup code (3+ occurrences)                      |
| `require_test_description_convention` | Recommended  | Ensures test names include descriptive words                             |
| `prefer_bloc_test_package`            | Professional | Suggests `blocTest()` when detecting Bloc testing patterns               |
| `prefer_mock_verify`                  | Professional | Warns when `when()` is used without `verify()`                           |

**Note:** `avoid_test_sleep` was already registered.

**Code cleanup:** Removed redundant test file path checks from these rules (file type filtering is handled by `applicableFileTypes`).

### DX Message Quality Improvements

Improved problem messages for 7 critical-impact rules to provide specific consequences instead of generic descriptions:

| Rule                                  | Improvement                                                     |
| ------------------------------------- | --------------------------------------------------------------- |
| `require_secure_storage`              | Now explains XML storage exposure enables credential extraction |
| `avoid_storing_sensitive_unencrypted` | Added backup extraction and identity theft consequence          |
| `check_mounted_after_async`           | Specifies State disposal during async gap                       |
| `avoid_stream_subscription_in_field`  | Clarifies callbacks fire after State disposal                   |
| `require_stream_subscription_cancel`  | Specifies State disposal context                                |
| `require_interval_timer_cancel`       | Specifies State disposal context                                |
| `avoid_dialog_context_after_async`    | Clarifies BuildContext deactivation during async gap            |

**Result**: Critical impact rules now at 100% DX compliance (40/40 passing).

### Documentation

- **PROFESSIONAL_SERVICES.md**: Rewrote professional services documentation with clearer service offerings and contact information

---

## [4.0.0] - 2026-01-12

### OWASP Compliance Mapping

Security rules are now mapped to **OWASP Mobile Top 10 (2024)** and **OWASP Top 10 (2021)** standards, transforming saropa_lints from a developer tool into a **security audit tool**.

#### Coverage

| OWASP Mobile        | Rules | OWASP Web                   | Rules |
| ------------------- | ----- | --------------------------- | ----- |
| M1 Credential Usage | 5+    | A01 Broken Access Control   | 4+    |
| M3 Authentication   | 5+    | A02 Cryptographic Failures  | 10+   |
| M4 Input Validation | 6+    | A03 Injection               | 6+    |
| M5 Communication    | 2+    | A05 Misconfiguration        | 4+    |
| M6 Privacy Controls | 5+    | A07 Authentication Failures | 8+    |
| M8 Misconfiguration | 4+    | A09 Logging Failures        | 2+    |
| M9 Data Storage     | 7+    |                             |       |
| M10 Cryptography    | 4+    |                             |       |

**Gaps**: M2 (Supply Chain), M7 (Binary Protection), and A06 (Outdated Components) require separate tooling — dependency scanners and build-time protections.

#### New Files

- `lib/src/owasp/owasp_category.dart` - `OwaspMobile` and `OwaspWeb` enums with category metadata
- `lib/src/owasp/owasp_mapping.dart` - Compliance reporting utilities
- `lib/src/owasp/owasp.dart` - Barrel export

#### API

Rules expose OWASP mappings via the `owasp` property:

```dart
final rule = AvoidHardcodedCredentialsRule();
print(rule.owasp); // Mobile: M1 | Web: A07

// Generate compliance report
final mappings = getAllSecurityRuleMappings();
final report = generateComplianceReport(mappings);
```

#### Modified Files

- `lib/src/saropa_lint_rule.dart` - Added `OwaspMapping? get owasp` to `SaropaLintRule` base class
- `lib/src/rules/security_rules.dart` - Added OWASP mappings to 41 security rules
- `lib/src/rules/crypto_rules.dart` - Added OWASP mappings to 4 cryptography rules
- `lib/saropa_lints.dart` - Export `OwaspMapping`, `OwaspMobile`, `OwaspWeb`

### Baseline Feature for Brownfield Projects

**The problem**: You want to adopt saropa_lints on an existing project, but running analysis shows 500+ violations in legacy code. You can't fix them all before your next sprint, but you want new code to be clean.

**The solution**: The baseline feature records existing violations and hides them. Old code is "baselined" (hidden), new code is still checked. You can adopt linting today without fixing legacy code first.

#### Quick Start

```bash
# Generate baseline - hides all current violations
dart run saropa_lints:baseline
```

This command creates `saropa_baseline.json` and updates your `analysis_options.yaml`. Old violations are hidden, new code is still checked.

#### Three Combinable Baseline Types

| Type           | Config           | Description                                         |
| -------------- | ---------------- | --------------------------------------------------- |
| **File-based** | `baseline.file`  | JSON file listing specific violations to ignore     |
| **Path-based** | `baseline.paths` | Glob patterns for directories (e.g., `lib/legacy/`) |
| **Date-based** | `baseline.date`  | Git blame - ignore code unchanged since a date      |

All three types are combinable - any match suppresses the violation.

#### Full Configuration

```yaml
custom_lint:
  saropa_lints:
    tier: recommended
    baseline:
      file: "saropa_baseline.json" # Specific violations
      date: "2025-01-15" # Code unchanged since this date
      paths: # Directories/patterns
        - "lib/legacy/"
        - "lib/deprecated/"
        - "**/generated/"
      only_impacts: [low, medium] # Only baseline these severities
```

#### CLI Commands

```bash
dart run saropa_lints:baseline              # Generate new baseline
dart run saropa_lints:baseline --update     # Refresh, remove fixed violations
dart run saropa_lints:baseline --dry-run    # Preview without changes
dart run saropa_lints:baseline --help       # See all options
```

#### New Files

- `lib/src/baseline/baseline_config.dart` - Configuration parsing
- `lib/src/baseline/baseline_file.dart` - JSON file handling
- `lib/src/baseline/baseline_paths.dart` - Glob pattern matching
- `lib/src/baseline/baseline_date.dart` - Git blame integration
- `lib/src/baseline/baseline_manager.dart` - Central orchestrator
- `bin/baseline.dart` - CLI tool

See [README.md](README.md#baseline-for-brownfield-projects) for full documentation.

### New Rules

#### OWASP Coverage Gap Rules

Five new rules to fill gaps in OWASP coverage:

| Rule                           | OWASP   | Severity | Description                                                                                |
| ------------------------------ | ------- | -------- | ------------------------------------------------------------------------------------------ |
| `avoid_ignoring_ssl_errors`    | M5, A05 | ERROR    | Detects `badCertificateCallback = (...) => true` that bypasses SSL validation              |
| `require_https_only`           | M5, A05 | WARNING  | Flags `http://` URLs (except localhost). Has quick fix to replace with HTTPS               |
| `avoid_unsafe_deserialization` | M4, A08 | WARNING  | Detects `jsonDecode` results used in dangerous operations without type validation          |
| `avoid_user_controlled_urls`   | M4, A10 | WARNING  | Flags user input (text controllers) passed directly to HTTP methods without URL validation |
| `require_catch_logging`        | M8, A09 | WARNING  | Catch blocks that silently swallow exceptions without logging or rethrowing                |

## [3.4.0] and Earlier

For details on the initial release and versions 0.1.0 through 3.4.0, please refer to [CHANGELOG_ARCHIVE.md](./CHANGELOG_ARCHIVE.md).
