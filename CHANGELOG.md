# Changelog

All notable changes to this project will be documented in this file.
The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

> **Looking for older changes?**  \
> See [CHANGELOG_ARCHIVE.md](./CHANGELOG_ARCHIVE.md) for versions 0.1.0 through 1.6.0.

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
