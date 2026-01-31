# Changelog

All notable changes to this project will be documented in this file.
The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).
Dates are not included in version headers — [pub.dev](https://pub.dev/packages/saropa_lints/changelog) displays publish dates separately.

> **Looking for older changes?** \
> See [CHANGELOG_ARCHIVE.md](./CHANGELOG_ARCHIVE.md) for versions 0.1.0 through 4.6.2.

** See the current published changelog: [saropa_lints/changelog](https://pub.dev/packages/saropa_lints/changelog)

---
## [4.9.5] - Current

### Added

- **Platform configuration in `analysis_options_custom.yaml`**: New `platforms:` section lets you disable lint rules for platforms your project doesn't target. Only `ios` and `android` are enabled by default — enable `macos`, `web`, `windows`, or `linux` if your project targets those platforms. Rules shared across multiple platforms (e.g., Apple Sign In applies to both iOS and macOS) stay enabled as long as at least one of their platforms is active. User overrides still take precedence over platform filtering.

- **Platform migration for existing configs**: Running `dart run saropa_lints:init` on projects with an existing `analysis_options_custom.yaml` automatically adds the `platforms:` section if missing, without disturbing existing settings.

### Removed

- **Removed rule: `prefer_const_child_widgets`**: Redundant. When the parent widget is `const`, Dart's const context propagation already makes all children implicitly `const` — there is no additional performance benefit. When the parent is non-const, the built-in `prefer_const_literals_to_create_immutables` lint already covers the same case.

### Fixed

- **`init` created backup files even when nothing changed**: Running `dart run saropa_lints:init` repeatedly created a timestamped `.bak` file on every invocation, even when the output content was identical. Backups are now only created when the file content has actually changed.

- **Plugin tier logging always showed `essential`**: The `getLintRules()` log message reported `tier: essential` regardless of the actual tier configured via `dart run saropa_lints:init`. The plugin read tier from a YAML key that the init command never wrote, so it always fell back to `essential`. Now infers the effective tier by comparing the final enabled rule set against each tier's definition, reporting the correct tier (e.g., `tier: professional`).

- **`// ignore_for_file:` directives now respected**: File-level ignore directives were not being checked by custom lint rules. Rules still fired even when `// ignore_for_file: rule_name` was present. The check now runs once per rule per file before any AST callbacks, efficiently skipping the entire rule when the file opts out. Supports both underscore (`rule_name`) and hyphen (`rule-name`) formats.

- **Unresolvable rules now reported**: Rules defined in tier configurations or explicit YAML overrides but missing from the rule factory registry are now logged as warnings during plugin initialization. This makes the rule count mismatch between `init` and the plugin visible (e.g., `WARNING: 18 rule(s) could not be resolved`).

- **`require_isar_nullable_field` false positive on static fields**: The rule incorrectly flagged `static` fields in `@collection` classes. Static fields are not persisted by Isar and should be skipped.

### Improved

- **DX message quality for widget_patterns_rules**: Expanded `problemMessage` and `correctionMessage` text for all 87 rules in `widget_patterns_rules.dart`. Messages now explain consequences, remove vague language ("Avoid", "Consider", "best practices"), and meet minimum length thresholds for the DX audit.

- **DX message quality for code_quality_rules**: Expanded `problemMessage` and `correctionMessage` text for all 87 rules with DX issues in `code_quality_rules.dart`. Removes "Avoid" prefixes, fixes vague language, explains consequences, and brings messages above minimum length thresholds.

- **DX message quality for control_flow_rules**: Expanded `problemMessage` and `correctionMessage` text for 13 rules in `control_flow_rules.dart`. Removes "Avoid" prefixes, explains consequences of control flow anti-patterns, and meets minimum message length thresholds.

- **`prefer_spacing_over_sizedbox` rule rewritten**: Now detects the alternating `[content, spacer, content, ...]` pattern in Row/Column children instead of just counting SizedBox widgets. Also detects `Spacer()` widgets, removed false `Wrap` support, and added a quick fix that inserts the `spacing` parameter and removes spacer children.

### Changed

- **`init` skips writing unchanged `analysis_options.yaml`**: Running `dart run saropa_lints:init` with the same tier and options no longer overwrites the file if the content is identical. Shows `✓ No changes needed` instead.

- **Plugin version now read dynamically from `pubspec.yaml`**: The version in `createPlugin()` was hardcoded at `4.8.0` and never updated. Replaced with a lazy resolver that reads the actual version from `pubspec.yaml` via `.dart_tool/package_config.json` at runtime. Works for both path dependencies and pub cache installs. The version string never needs manual updates again.

### Added

- **New rule: `avoid_ignore_trailing_comment`** (Recommended tier, WARNING): Warns when `// ignore:` or `// ignore_for_file:` directives have trailing text after the rule names — either a `//` comment or a ` - ` explanation. The `custom_lint_builder` framework uses exact string matching on rule codes, so any trailing text silently breaks suppression. Quick fix moves the text to a `//` comment on the line above the directive.

- **New rule: `prefer_positive_conditions`** (Stylistic, INFO): Warns when an if/else or ternary uses a negative condition (`!expr` or `!=`) that can be flipped to a positive form with branches swapped. Only flags straightforward cases — skips compound conditions, else-if chains, and complex negations. Quick fix available to invert the condition and swap both branches.

- **New rule: `prefer_positive_conditions_first`** (Stylistic, INFO): Warns when guard clauses use negated conditions (`== null`, `!expr`) with early returns, pushing the happy path deeper into the function. Suggests restructuring to place the positive condition first. Opinionated — not included in any tier by default.

- **New rule: `missing_use_result_annotation`** (Comprehensive tier, INFO): Warns when a function returns a value without `@useResult` annotation. Callers may accidentally ignore the return value, leading to missed error handling or lost data transformations.

- **VS Code extension: Scan file or folder**: Right-click any `.dart` file or folder in the Explorer sidebar and select "Scan with Saropa Lints" to instantly see all diagnostics for that path. Uses diagnostics already computed by the Dart analysis server — no re-scanning required.

- **Quick fixes for 7 stylistic widget rules**: Added one-click fixes for `prefer_sizedbox_over_container`, `prefer_container_over_sizedbox`, `prefer_borderradius_circular`, `prefer_expanded_over_flexible`, `prefer_flexible_over_expanded`, `prefer_edgeinsets_symmetric`, and `prefer_edgeinsets_only`. Each fix handles const preservation and argument reordering.

---
## [4.9.4]

### Changed

    Strict Isar migration safety: Replaced require_isar_non_nullable_migration with require_isar_nullable_field. The previous rule allowed non-nullable fields if they had default values, but Isar bypasses constructors/initializers during hydration, leading to crashes on legacy data. The new rule mandates that all fields in @collection classes (except Id) must be nullable (String?) to strictly prevent TypeError during version upgrades.

### Added

    Auto-fix for Isar fields: Added dart fix support for the new require_isar_nullable_field rule to automatically append ? to non-nullable fields in Isar collections.

---
## [4.9.3]

### Fixed

- **Progress bar terminal compatibility**: Use stdout with space-overwrite approach instead of ANSI escape codes for broader terminal support. Added clear labels (`Files:`, `Issues:`, `ETA:`) to progress output for clarity.

- **Version detection when run from other projects**: Fixed `init` command showing "vunknown" when run via `dart run saropa_lints:init` from dependent projects. Now correctly reads version from package location found in `package_config.json`.

- **Full filenames in progress**: Removed truncation of long filenames in progress display.

---
## [4.9.2]

### Added

- **Dynamic version detection in init**: The `init` command now reads the version from `pubspec.yaml` at runtime instead of using a hardcoded constant. Also displays the package source (local path vs pub.dev) to help diagnose version mismatches.

### Changed

- **Full problem messages in generated config**: The `init` command now outputs complete rule descriptions in `analysis_options.yaml` comments instead of truncating at 60 characters. This improves searchability when looking for specific rule behaviors.

---
## [4.9.1]

### Added

- **In-place progress bar with colors**: Terminal output now shows a visual progress bar (`████████░░░░`) that updates in-place instead of scrolling thousands of lines. Includes color coding (green for progress, red/yellow for issues, cyan for file counts), ETA display, and current file indicator. Cross-platform color detection for Windows Terminal, ConEmu, and Unix terminals. Disable with `SAROPA_LINTS_PROGRESS=false`.

- **Issue limit for large codebases**: New `max_issues` setting (default: 1000) stops running WARNING/INFO rules after the limit is reached, providing real speedup on legacy projects. ERROR-severity rules always run regardless of limit. Configure in `analysis_options_custom.yaml`:
  ```yaml
  max_issues: 500  # Or 0 for unlimited
  ```
  The init command now generates this file automatically with sensible defaults.

### Changed

- **Summary output reduced**: Final summary now shows top 5 files/rules instead of 10, with color-coded severity indicators and slow file tracking (files taking >2s are reported at the end instead of interrupting progress).

---
## [4.9.0]

### Added

- **Automatic ignore quick fixes for all rules**: Every rule extending `SaropaLintRule` now automatically provides two quick fixes: "Ignore 'rule_name' for this line" (inserts `// ignore: rule_name` above the violation with matching indentation) and "Ignore 'rule_name' for this file" (inserts `// ignore_for_file: rule_name` after header comments). This enables one-click suppression for any lint violation. Rules can disable this via `includeIgnoreFixes => false` for critical security rules. New `customFixes` getter allows rules to provide specific fixes while retaining ignore fixes. Insertion logic respects existing ignore_for_file comments (groups them together) and copyright/license headers (inserts after, not before).

- **Quick fixes for 26 additional rules**: Added automated quick fix support for frequently triggered rules to enable one-click corrections. Stylistic: `prefer_if_null_over_ternary` (replaces `x != null ? x : d` → `x ?? d`), `prefer_ternary_over_if_null` (replaces `x ?? d` → `x != null ? x : d`), `prefer_where_type_over_where_is` (replaces `.where((e) => e is T)` → `.whereType<T>()`), `prefer_nullable_over_late` (replaces `late Type` → `Type?`), `prefer_rethrow_over_throw_e` (replaces `throw e;` → `rethrow;`). Image: `prefer_image_size_constraints` (adds `cacheWidth`/`cacheHeight`), `require_cached_image_dimensions` (adds `memCacheWidth`/`memCacheHeight`), `prefer_cached_image_fade_animation` (adds `fadeInDuration`), `prefer_image_picker_request_full_metadata` (adds `requestFullMetadata: false`), `avoid_image_picker_large_files` (adds `imageQuality: 85`), `require_image_cache_dimensions` (adds `cacheWidth`/`cacheHeight`). Dependency Injection: `avoid_singleton_for_scoped_dependencies` (changes to `registerFactory` with factory wrapper), `require_typed_di_registration` (adds `<Type>` generic parameter), `avoid_functions_in_register_singleton` (changes to `registerLazySingleton`), `prefer_lazy_singleton_registration` (changes to `registerLazySingleton` with factory wrapper). Class/Constructor: `prefer_const_string_list` (adds `const` keyword), `prefer_declaring_const_constructor` (adds `const` keyword), `prefer_final_class` (adds `final` modifier), `prefer_interface_class` (adds `interface` modifier), `prefer_base_class` (adds `base` modifier). Scroll/List: `avoid_refresh_without_await` (adds `async` keyword), `prefer_item_extent` (adds `itemExtent` parameter), `prefer_prototype_item` (adds `prototypeItem` parameter), `require_key_for_reorderable` (adds `key` parameter), `require_add_automatic_keep_alives_off` (adds `addAutomaticKeepAlives: false`). Control Flow: `prefer_async_only_when_awaiting` (removes unnecessary `async` keyword). All fixes include comprehensive documentation and preserve code formatting.

### Changed

- **DX message quality improvements for 25 medium/low priority rules**: Improved lint message clarity by replacing vague language with specific, actionable problem descriptions. Changes include: (1) Replaced "better performance" with quantified impacts (e.g., "reduces throughput by 10-100x", "causes full table scan", "recalculates layout on every scroll"), (2) Replaced "consider X" suggestions with direct problem statements (e.g., "loads all entries into memory at once", "collects EXIF metadata by default", "prevents garbage collection under memory pressure"), (3) Replaced "should be/have" with consequence explanations (e.g., "shows blank space during load", "locks out users with damaged sensors", "slow code review and refactoring"). Affected rules: `prefer_sqflite_batch`, `require_database_index`, `prefer_firestore_batch_write`, `prefer_marker_clustering`, `prefer_item_extent`, `prefer_lazy_box_for_large`, `prefer_hive_value_listenable`, `prefer_image_size_constraints`, `require_image_loading_placeholder`, `prefer_image_picker_request_full_metadata`, `prefer_weak_references_for_cache`, `prefer_wildcard_for_unused_param`, `require_svg_error_handler`, `prefer_deferred_loading_web`, `require_menu_bar_for_desktop`, `move_records_to_typedefs`, `prefer_sorted_pattern_fields`, `prefer_simpler_patterns_null_check`, `prefer_sorted_record_fields`, `prefer_immutable_provider_arguments`, `prefer_prototype_item`, `require_biometric_fallback`, `prefer_data_masking`, `avoid_screenshot_sensitive`, `prefer_notifier_over_state`.
- **Audit report organization improved**: Refactored audit scripts to reduce repetition and improve report readability.

---
## [4.8.8]

### Added

- **Quick fixes for 9 rules**: Added automated quick fix support for frequently triggered rules to enable one-click corrections. Internationalization: `require_directional_widgets` (converts `EdgeInsets.only(left: x)` → `EdgeInsetsDirectional.only(start: x)` for RTL support), `prefer_intl_name` (adds `name` parameter to `Intl.message()`), `prefer_providing_intl_description` (adds `desc` parameter with TODO), `prefer_providing_intl_examples` (adds `examples` parameter). Stylistic: `prefer_double_quotes` (converts single quotes to double quotes), `prefer_object_over_dynamic` (replaces `dynamic` → `Object?`), `prefer_dynamic_over_object` (replaces `Object?` → `dynamic`). Hive: `prefer_hive_lazy_box` (converts `Hive.openBox()` → `Hive.openLazyBox()` for large collections). Logging: `prefer_logger_over_print` (replaces `print()` → `log()` from dart:developer). All fixes include comprehensive documentation and preserve code formatting.

### Changed

- **Widget rules refactored into 3 focused files**: Split the 18,953-line `flutter_widget_rules.dart` into three thematic categories for improved maintainability and discoverability: `widget_lifecycle_rules.dart` (34 rules for State management, dispose, setState patterns), `widget_layout_rules.dart` (65 rules for layout structure, constraints, rendering), and `widget_patterns_rules.dart` (103 rules for best practices, accessibility, themes, platform-specific patterns). All 202 rules remain functionally identical with no breaking changes. This is a pure code reorganization with no logic modifications.
- **README badges upgraded**: Replaced static badges with dynamic, auto-updating badges organized into logical groups (CI/CD, pub.dev metrics, GitHub activity, technical info). Added popularity, likes, stars, forks, last commit, issues count, Dart SDK version, and Flutter platform badges with appropriate logos. The pub version badge now auto-updates from pub.dev, eliminating the need for manual version updates in documentation.
- **DX message quality improvements for 24 critical/high impact rules**: Achieved 100% pass rate (293/293 high, 61/61 critical) for developer experience message quality audit. Fixed missing consequences (added security/accessibility impact statements), expanded too-short messages to meet 180+ character requirement (added specific failure scenarios and technical details), replaced generic terms with specific types (e.g., "controller" → "animation controller", "widget" → "StatefulWidget", "resource" → "memory and processing resources"), and enhanced correction messages to meet 80+ character requirement with actionable guidance. Affected rules: `avoid_deep_link_sensitive_params`, `avoid_color_only_indicators`, `require_cached_image_dimensions`, `avoid_image_picker_large_files`, `require_notification_initialize_per_platform`, `avoid_unsafe_deserialization`, `require_image_semantics`, `require_vsync_mixin`, `avoid_unassigned_stream_subscriptions`, `avoid_obs_outside_controller`, `require_key_for_collection`, `require_workmanager_constraints`, `prefer_riverpod_auto_dispose`, `require_test_widget_pump`, `avoid_notification_payload_sensitive`, `require_url_validation`, `avoid_bloc_context_dependency`, `avoid_provider_value_rebuild`, `avoid_riverpod_notifier_in_build`, `avoid_bloc_business_logic_in_ui`, `require_mock_http_client`, `avoid_dynamic_json_access`, `require_enum_unknown_value`, `avoid_future_tostring`.

---
## [4.8.7]

### Fixed

- **`avoid_context_across_async` and `avoid_context_after_await_in_static` false positives on mounted ternary guards**: Fixed two issues where safe mounted guard patterns were incorrectly flagged: (1) Ternary guards in catch blocks (`context.mounted ? context : null`) were not detected due to premature AST traversal termination at statement boundaries. (2) Nullable-safe mounted checks (`context?.mounted ?? false ? context : null`) were not recognized. Both patterns now correctly suppress violations.
- **Trailing ignore comments now work for all rules**: Fixed critical bug in `IgnoreUtils._checkTokenCommentsOnLine()` where trailing `// ignore:` comments (same-line format: `final x = y; // ignore: rule_name`) were not detected. Root cause: the function checked if the token was past the target line before examining the token's preceding comments, causing it to miss trailing comments attached to the next line's first token (a common Dart tokenization pattern). The fix reorders the logic to examine comments first, then check token position. Also added statement-level trailing comment detection for cases where the comment is at the end of a statement rather than immediately after the expression. Now properly detects both leading (`// ignore:` on preceding line) and trailing (`// ignore:` on same line) ignore patterns for all rule name formats (underscores and hyphens). Affects all 1677 saropa_lints rules.

---
## [4.8.6]

### Added

- **`TestRelevance` enum**: New three-value enum (`never`, `always`, `testOnly`) for granular control over whether lint rules run on test files. Rules can now declare their test file relationship explicitly instead of using a boolean flag.

### Changed

- **Rules now skip test files by default**: The default `testRelevance` is `TestRelevance.never`, meaning ~1600 production-focused rules no longer fire on test files. This eliminates thousands of irrelevant violations (e.g., `prefer_matcher_over_equals`, `move_variable_closer_to_its_usage`, `no_empty_string`) that were flooding test code. Rules that should run on tests can override `testRelevance => TestRelevance.always`.
- **Backwards-compatible auto-detection**: Rules using `applicableFileTypes => {FileType.test}` are automatically treated as `TestRelevance.testOnly` with no code changes required.
- **DX message quality improvements for 25 rules**: Expanded `problemMessage` text for rules that were below the 180-character minimum or lacked a clear consequence. Each message now explains both the problem and its real-world impact (e.g., memory leaks, crashes, stale UI). Affected rules: `prefer_consumer_widget`, `avoid_bloc_in_bloc`, `avoid_change_notifier_in_widget`, `require_provider_dispose`, `require_error_handling_in_async`, `require_getx_controller_dispose`, `dispose_provider_instances`, `avoid_getx_rx_inside_build`, `avoid_mutable_rx_variables`, `dispose_provided_instances`, `avoid_listen_in_async`, `avoid_equatable_mutable_collections`, `avoid_static_state`, `avoid_provider_in_init_state`, `require_bloc_manual_dispose`, `prefer_bloc_listener_for_side_effects`, `avoid_bloc_context_dependency`, `avoid_provider_value_rebuild`, `avoid_riverpod_notifier_in_build`, `avoid_bloc_business_logic_in_ui`, `require_mock_http_client`, `avoid_dynamic_json_access`, `require_enum_unknown_value`, `require_image_semantics`, `require_badge_semantics`.

### Fixed

- **`avoid_isar_clear_in_production` false positive on non-Isar types**: The rule previously flagged every `.clear()` call regardless of receiver type, producing ERROR-severity false positives on `Map.clear()`, `List.clear()`, `Set.clear()`, `TextEditingController.clear()`, and any other class with a `clear()` method. Now uses static type checking to verify the receiver is an `Isar` instance before reporting.
- **`require_error_case_tests` false positives**: Expanded test name keyword detection to recognize boundary/defensive test patterns (`null`, `empty`, `boundary`, `edge`, `negative`, `fallback`, `missing`) in addition to error keywords. Updated correction message to acknowledge that test files for pure enums, defensive try/catch code, and non-nullable extension methods legitimately have no error-throwing paths.
- **`prefer_setup_teardown` false positive on independent locals**: The rule no longer flags repeated primitive variable declarations (`int count = 0`, `const int iterations = 1000`) as duplicated setup code. Simple literal initializations and const declarations are now excluded from the setup signature comparison, so only meaningful setup (object construction, service initialization) triggers the suggestion.
- **`require_change_notifier_dispose` false positives**: Fixed three categories of false positive: (1) Fields not owned by the class (e.g., controllers received from `Autocomplete` callbacks) are no longer flagged — the rule now uses `_findOwnedFieldsOfType` ownership detection consistent with sibling disposal rules. (2) Generic container types like `Map<K, ScrollController>` no longer match via substring — exact type matching is now used. (3) Extension method disposal wrappers (e.g., `.disposeSafe()`) are now recognized as valid disposal patterns by all disposal rules.

### Deprecated

- **`skipTestFiles` getter**: Replaced by `testRelevance`. The old boolean getter still compiles but is marked `@Deprecated`. Migration: `skipTestFiles => true` is now the default; `skipTestFiles => false` becomes `testRelevance => TestRelevance.always`.

---
## [4.8.5]

### Added

- **`TestRelevance` enum**: New three-value enum (`never`, `always`, `testOnly`) for granular control over whether lint rules run on test files. Rules can now declare their test file relationship explicitly instead of using a boolean flag.

### Changed

- **Rules now skip test files by default**: The default `testRelevance` is `TestRelevance.never`, meaning ~1600 production-focused rules no longer fire on test files. This eliminates thousands of irrelevant violations (e.g., `prefer_matcher_over_equals`, `move_variable_closer_to_its_usage`, `no_empty_string`) that were flooding test code. Rules that should run on tests can override `testRelevance => TestRelevance.always`.
- **Backwards-compatible auto-detection**: Rules using `applicableFileTypes => {FileType.test}` are automatically treated as `TestRelevance.testOnly` with no code changes required.
- **DX message quality improvements for 25 rules**: Expanded `problemMessage` text for rules that were below the 180-character minimum or lacked a clear consequence. Each message now explains both the problem and its real-world impact (e.g., memory leaks, crashes, stale UI). Affected rules: `prefer_consumer_widget`, `avoid_bloc_in_bloc`, `avoid_change_notifier_in_widget`, `require_provider_dispose`, `require_error_handling_in_async`, `require_getx_controller_dispose`, `dispose_provider_instances`, `avoid_getx_rx_inside_build`, `avoid_mutable_rx_variables`, `dispose_provided_instances`, `avoid_listen_in_async`, `avoid_equatable_mutable_collections`, `avoid_static_state`, `avoid_provider_in_init_state`, `require_bloc_manual_dispose`, `prefer_bloc_listener_for_side_effects`, `avoid_bloc_context_dependency`, `avoid_provider_value_rebuild`, `avoid_riverpod_notifier_in_build`, `avoid_bloc_business_logic_in_ui`, `require_mock_http_client`, `avoid_dynamic_json_access`, `require_enum_unknown_value`, `require_image_semantics`, `require_badge_semantics`.

### Fixed

- **`avoid_isar_clear_in_production` false positive on non-Isar types**: The rule previously flagged every `.clear()` call regardless of receiver type, producing ERROR-severity false positives on `Map.clear()`, `List.clear()`, `Set.clear()`, `TextEditingController.clear()`, and any other class with a `clear()` method. Now uses static type checking to verify the receiver is an `Isar` instance before reporting.
- **`require_error_case_tests` false positives**: Expanded test name keyword detection to recognize boundary/defensive test patterns (`null`, `empty`, `boundary`, `edge`, `negative`, `fallback`, `missing`) in addition to error keywords. Updated correction message to acknowledge that test files for pure enums, defensive try/catch code, and non-nullable extension methods legitimately have no error-throwing paths.
- **`prefer_setup_teardown` false positive on independent locals**: The rule no longer flags repeated primitive variable declarations (`int count = 0`, `const int iterations = 1000`) as duplicated setup code. Simple literal initializations and const declarations are now excluded from the setup signature comparison, so only meaningful setup (object construction, service initialization) triggers the suggestion.
- **`require_change_notifier_dispose` false positives**: Fixed three categories of false positive: (1) Fields not owned by the class (e.g., controllers received from `Autocomplete` callbacks) are no longer flagged — the rule now uses `_findOwnedFieldsOfType` ownership detection consistent with sibling disposal rules. (2) Generic container types like `Map<K, ScrollController>` no longer match via substring — exact type matching is now used. (3) Extension method disposal wrappers (e.g., `.disposeSafe()`) are now recognized as valid disposal patterns by all disposal rules.

### Deprecated

- **`skipTestFiles` getter**: Replaced by `testRelevance`. The old boolean getter still compiles but is marked `@Deprecated`. Migration: `skipTestFiles => true` is now the default; `skipTestFiles => false` becomes `testRelevance => TestRelevance.always`.

---
## [4.8.4]

### Added

- **Test coverage top offenders report**: The publish workflow's test coverage summary now lists the 10 worst categories ranked by untested rule count, color-coded by severity.
- **File health top offenders**: The "Files needing quick fixes" audit section now lists the top 5 worst files sorted by fix coverage, showing fixes/rules and percentage.
- **Doc reference auto-fix in publish pipeline**: The `--fix-docs` flag and Step 6 analysis now detect and auto-fix unresolvable `[reference]` patterns in DartDoc comments (OWASP codes, file names, snake_case rule names) alongside the existing angle bracket fixer.

### Changed

- **Improved DX messages for 58 high-impact rules**: Expanded `problemMessage` and `correctionMessage` text across `navigation_rules`, `notification_rules`, `package_specific_rules`, `performance_rules`, `platform_rules`, `qr_scanner_rules`, `resource_management_rules`, `riverpod_rules`, `scroll_rules`, `security_rules`, and `state_management_rules` to explain user-facing consequences and provide more specific fix guidance. Each problem message now meets the 180-character minimum with clear issue/consequence/impact structure; each correction message meets the 80-character minimum with actionable fix guidance.
- **DX audit: relaxed vague language check for low-impact rules**: The `_audit_dx.py` scoring module no longer penalises advisory phrasing ("consider", "prefer", etc.) in low-impact rules, since suggestive language is appropriate for rules that are informational by nature.

### Fixed

- **20 unresolved doc reference warnings**: Escaped non-symbol references in DartDoc comments (OWASP codes, rule names, Flutter widget names, file names) that `dart doc` could not resolve, eliminating all documentation generation warnings.
- **Publish script commit step**: "No changes to commit" message now shows as success (green) instead of warning (yellow), since it is not an error condition.
- **Publish script Step 9**: Suppressed spurious Windows `nul` path warning in pre-publish validation output.
- **ROADMAP near-match false positives**: `_test` variant rules are now excluded from near-match detection, matching the existing duplicate exclusion logic.

### Removed

- **`doc/flutter_widget_rules_full_table.md`**: Obsolete split-plan document that was no longer referenced.

## [4.8.3]

### Added

- **`avoid_dynamic_code_loading`** (Essential, ERROR): Detects runtime code loading via `Isolate.spawnUri()` and package management commands in `Process.run()`/`Process.start()`. OWASP M2 (Supply Chain Security).
- **`avoid_unverified_native_library`** (Essential, ERROR): Detects `DynamicLibrary.open()` with dynamic or absolute paths that bypass package verification. OWASP M2 (Supply Chain Security).
- **`avoid_hardcoded_signing_config`** (Recommended, WARNING): Detects hardcoded keystore paths, signing aliases, and configuration strings extractable from compiled binaries. OWASP M7 (Binary Protections).
- **OWASP Mobile coverage**: 8/10 → 10/10 (100%). Added M2 and M7 coverage; also mapped `avoid_eval_like_patterns` to M7.

### Fixed

- **141 orphan rules restored**: Rules that were implemented but never registered in `_allRuleFactories` or assigned to tiers are now fully active. Includes rules for Bloc, GetX, Isar, Dio, Riverpod, image_picker, permissions, notifications, WebView, and more. Critical-impact rules assigned to recommended tier, high to professional, medium/low to comprehensive.
- **9 GetX rules unhidden**: Removed `hide` directives in `all_rules.dart` that blocked GetX rules from export.
- **3 opinionated rules registered**: `prefer_early_return`, `prefer_mutable_collections`, and `prefer_record_over_equatable` moved from dead code to stylistic tier.
- **`format_comment_style` moved to insanity tier**: Previously in professional tier, now correctly placed as documentation pedantry.
- **Pre-publish audit script bugs fixed**: `_code\s*=` regex now matches variant field names (`_codeField`, `_codeMethod`), eliminating phantom rule false positives. Opinionated prefer_* detection uses class-scoped search instead of backward search, preventing cross-class name resolution errors.

### Changed

- **Improved DX message quality for 25 critical/high-impact lint rules**: Expanded problem messages to clearly explain the detected issue, its real-world consequence, and the user impact. Expanded correction messages with specific, actionable fix guidance. Affected rules span forms, navigation, memory management, images, Riverpod, GetX, lifecycle, Firebase, JSON, and API categories.
- **Critical DX pass rate**: 98.3% → 100% (60/60 rules passing)
- **High DX pass rate**: 34.8% → 42.7% (+23 additional rules passing)
- **Audit scripts refactored**: `_audit.py` split into `_audit_checks.py` (extraction/display) and `_audit_dx.py` (DX quality analysis) for maintainability.

## [4.8.2]

### Added

- **`require_https_only_test` rule**: New test-file variant of `require_https_only` at INFO severity (Professional tier). The production rule now skips test files, and the test variant covers them independently so teams can disable HTTP URL linting in tests without affecting production enforcement.
- **`avoid_hardcoded_config_test` rule**: New test-file variant of `avoid_hardcoded_config` at INFO severity (Professional tier). Hardcoded URLs and keys in test files are typically test fixture data; this rule surfaces them at reduced severity for awareness without blocking.
- **`require_deep_link_fallback` test fixture**: Added coverage for lazy-loading getters that use utility class methods (e.g., `_uri ??= UrlUtils.getSecureUri(url)`) to prevent false positives.

### Changed

- **98 opinionated rules moved to stylistic tier**: Rules that are subjective or conflict with each other are now opt-in only via `--stylistic` flag, not enabled by default in any tier. This includes member ordering, argument ordering, naming conventions, and similar stylistic preferences.
- **8 stylistic rules renamed for consistency**: All stylistic rules now use `prefer_` prefix:
  - `always_fail_test_case` → `prefer_fail_test_case`
  - `enforce_member_ordering` → `prefer_member_ordering`
  - `enforce_arguments_ordering` → `prefer_arguments_ordering`
  - `capitalize_comment_start` → `prefer_capitalized_comment_start`
  - `avoid_continue_statement` → `prefer_no_continue_statement`
  - `avoid_getter_prefix` → `prefer_no_getter_prefix`
  - `avoid_commented_out_code` → `prefer_no_commented_out_code`
  - `avoid_inferrable_type_arguments` → `prefer_inferred_type_arguments`
  - Old names preserved as `configAliases` for backwards compatibility.
- **Conflicting member-ordering rules moved to stylistic tier**: `prefer_static_members_first`, `prefer_instance_members_first`, `prefer_public_members_first`, `prefer_private_members_first` now require explicit opt-in since they conflict in pairs.
- **Tier assignment: single source of truth**: `tiers.dart` is now the sole authority for rule tier assignments. Removed the `RuleTier get tier` getter from `SaropaLintRule` and the legacy two-phase fallback in `bin/init.dart`. The init script now reads tier assignments exclusively from `tiers.dart` sets.
- **Unified CLI entry point**: Added `bin/saropa_lints.dart` as a dispatcher supporting `init`, `baseline`, and `impact-report` subcommands.
- **Progress tracking improvements**: `ProgressTracker` now derives project root from the first analyzed file path instead of using `.` (which fails in plugin mode). Shows enabled rule count instead of misleading file percentage.

### Fixed

- **`avoid_context_after_await_in_static` false positives in try-catch**: The rule now recurses into try, catch, and finally blocks instead of skipping the entire `TryStatement`. Mounted guards and ternary patterns inside try-catch are correctly recognized.
- **`avoid_context_across_async` false positives in try-catch**: Same try-catch recursion fix applied to the non-static context rule.
- **`avoid_storing_context` false positives on function type fields**: Fields declaring callback signatures (e.g., `void Function(BuildContext)`) no longer trigger the rule. Only actual `BuildContext` storage is flagged.
- **`avoid_expanded_outside_flex` false positives**: Three scenarios fixed:
  - `Expanded` inside `List.generate()` or `.map()` callbacks within helper methods is now trusted.
  - Expression-body helper methods (e.g., `List<Widget> _items() => [Expanded(...)]`) are now trusted.
  - Top-level `FunctionDeclaration` boundaries are now recognized.
- **`avoid_builder_index_out_of_bounds` false positives with `itemCount`**: Lists whose bounds are guaranteed by `itemCount: list.length` are no longer flagged.
- **`avoid_long_running_isolates` false positive on `Isolate.run`**: `Isolate.run()` is now correctly classified as short-lived (like `compute()`), not as a persistent isolate like `Isolate.spawn()`. Context window expanded from 200 to 500 chars. Added fire-and-forget and never-block awareness keywords.
- **`require_immutable_bloc_state` false positives on non-BLoC classes**: Skip indirect Flutter State subclasses (`PopupMenuItemState`, `FormFieldState`, `AnimatedWidgetBaseState`, `ScrollableState`, `RefreshIndicatorState`) and `StatefulWidget`/`StatelessWidget` subclasses using "State" as a domain term.
- **`require_cache_key_determinism` false positive on metadata parameters**: Common metadata parameter names (`createdAt`, `updatedAt`, `timestamp`, `expiresAt`, `ttl`, etc.) are now excluded from determinism checks. Diagnostics now report at the specific offending argument instead of the entire variable declaration. Extracted shared `_checkArgumentList` helper to reduce duplication.

---
## [4.8.1]

### Added

- **`avoid_uncaught_future_errors` quick fix**: New "Add // ignore: comment" quick fix for cases where the called method handles errors internally but is defined in a different file. The rule cannot detect cross-file try-catch, so this fix provides a convenient workaround.

### Changed

- **`avoid_builder_index_out_of_bounds` documentation**: Added note clarifying the rule's limitation with synchronized lists. The rule cannot detect cross-method relationships like `List.generate(otherList.length, ...)`, so explicit bounds checks or ignore comments are recommended for multiple lists of the same length.
- **`avoid_uncaught_future_errors` documentation**: Added "Limitation: Cross-file analysis" section explaining that the rule can only detect try-catch in functions defined in the same file.

### Fixed

- **`require_deep_link_fallback` false positives**: Fixed three false positive scenarios:
  - `return null;` statements now recognized as valid fallback patterns
  - Ternary expressions with null fallback (e.g., `condition ? value : null`) now recognized
  - Methods returning `String?` or `Uri?` are now skipped as they are URL parsers/converters, not deep link handlers

---
## [4.8.0]

### Changed

- **Lazy rule loading for reduced memory usage**: Rules are now instantiated on-demand instead of at compile time. Previously, all 1500+ rules were created as a `const List<LintRule>`, consuming ~4GB of memory regardless of which tier was selected. Now only rules needed for the selected tier are created. For essential tier (~250 rules), this reduces memory usage significantly and eliminates OOM crashes on resource-constrained systems.
  - Rule list changed from `const List<LintRule>` to `final List<LintRule Function()>` factories
  - Factory map built lazily on first access
  - No generated files required - stays in sync automatically when rules are added/removed

---
## [4.7.6]

### Fixed

- **`require_ios_permission_description` false positive on ImagePicker constructor**: Fixed false positives where the rule required both `NSPhotoLibraryUsageDescription` AND `NSCameraUsageDescription` when only `ImagePicker()` was instantiated, before any method was called. The rule now uses smart method-level detection:
  - `ImagePicker()` constructor alone → no warning
  - `picker.pickImage(source: ImageSource.gallery)` → requires only `NSPhotoLibraryUsageDescription`
  - `picker.pickImage(source: ImageSource.camera)` → requires only `NSCameraUsageDescription`
  - `picker.pickImage(source: variable)` → requires both (can't determine statically)

---
## [4.7.5]

### Added

- **Mid-chain ignore comments**: `// ignore:` comments now work when placed before the method or property name in chained calls. Previously, ignore comments had to be placed before the entire statement. Now both formats work:
  ```dart
  // Before (still works):
  // ignore: rule_name
  object.method();

  // Now also works:
  object
      // ignore: rule_name
      .method();
  ```

---
## [4.7.4]

### Added

- **Quick fix for `avoid_unbounded_cache_growth`**: New quick fix adds a `static const int maxSize = 100;` field to cache classes. Developers need to manually add eviction logic in mutation methods.

### Fixed

- **`avoid_unbounded_cache_growth` static regex patterns**: Improved performance by making regex patterns (`_limitPattern`, `_mutationMethodPattern`, `_mapKeyPattern`) static class fields instead of creating them on each method call.
- **`avoid_overlapping_animations` false positives on different-axis SizeTransitions**: Fixed false positives when nesting `SizeTransition` widgets with different axes. `SizeTransition(axis: Axis.vertical)` animates height while `SizeTransition(axis: Axis.horizontal)` animates width - these are independent properties and should not conflict. The rule now distinguishes `size_vertical` from `size_horizontal` based on the `axis` parameter.
- **`avoid_unbounded_cache_growth` false positives on enum-keyed maps**: Fixed false positives on caches that use enum keys (e.g., `Map<PanelEnum, Widget>`). Enum-keyed maps are inherently bounded by the number of enum values and cannot grow indefinitely. Also added detection for immutable caches (read-only maps with no mutation methods like `add`, `set`, or index assignment).
- **`require_stream_controller_close` false positives on helper classes**: Fixed false positives on helper/wrapper classes that have a `close()` method instead of `dispose()`. Classes like `CustomStreamController` with a `close()` method that properly closes the internal StreamController are no longer flagged. The rule now checks both `dispose()` and `close()` methods for cleanup calls.
- **`avoid_unbounded_cache_growth` false positives on database models**: Fixed false positives on Isar (`@collection`), Hive (`@HiveType`), and Floor (`@Entity`) database models that have "cache" in the class name. These ORM models use disk-based storage with external cleanup, not in-memory Map caching. Also improved detection to only flag actual Map field declarations, not `toMap()` serialization method return types.
- **`avoid_path_traversal` false positives on trusted system paths**: Fixed false positives when file paths are constructed using trusted system APIs (e.g., `path_provider`, platform MethodChannels) combined with hardcoded constants. The rule now only flags paths containing function parameters (actual user input), not paths using private fields, constants, or system API returns like `getApplicationDocumentsDirectory()`.
- **`require_deep_link_fallback` false positives on URI getters**: Fixed false positives on simple URI getter and converter methods that are not deep link handlers. Now skips: lazy-loading patterns (`_uri ??= parseUri(url)`), method invocations on fields (`url.toUri()`), and null-aware property access (`url?.uri`).
- **`require_stream_controller_dispose` false positive with typed StreamControllers**: Fixed false positives when `StreamController<T>` has a concrete type parameter (e.g., `StreamController<String>`, `StreamController<(double, double)>`). The type classification logic incorrectly treated these as wrapper types. Also fixed wrapper types to accept both `.close()` and `.dispose()` methods.
- **`avoid_expanded_outside_flex` false positive in helper methods**: Fixed false positives when `Expanded`/`Flexible` is created inside helper methods that return `List<Widget>`, or inside collection builders like `List.generate()` and `.map()`. These patterns are now trusted since the widgets typically end up inside Flex parents at runtime.
- **`avoid_flashing_content` false positives on non-repeating animations**: Fixed false positives where the rule flagged all `AnimationController` instances with `duration < 333ms`, regardless of whether the animation actually repeats. Per WCAG 2.3.1, a "flash" requires alternating between states, so only `.repeat()` cascades now trigger the rule. Single-direction animations (`.forward()`, `.reverse()`, `.animateTo()`) are no longer flagged.

### Added

- **Quick fix for `avoid_flashing_content`**: New quick fix increases animation duration to 333ms (minimum WCAG 2.3.1 compliant threshold).
- **Quick fix for `require_stream_controller_close`**: New quick fix adds `controller.close()` call to the dispose/close method.

---
## [4.7.3]

### Added

- **Interactive analysis prompt**: After init completes, prompts user "🔍 Run analysis now? [y/N]" to optionally run `dart run custom_lint` immediately.

### Fixed

- **Progress tracking: misleading percentages**: Fixed bug where progress would show constantly recalibrating percentages (e.g., "130/149 (87%)") when file discovery failed. Now shows simple file count ("X files") when accurate totals aren't available.

- **Progress tracking: rule name prefix spam**: Fixed progress output being prefixed with rule name (e.g., `[require_ios_privacy_manifest]`) for every update. Progress now uses stderr to avoid custom_lint's automatic rule tagging.

---
## [4.7.2]

### Added

- **Custom overrides file**: New `analysis_options_custom.yaml` file for rule customizations that survive `--reset`. Place rule overrides in this file to always apply them regardless of tier or reset.

- **Timestamped backups**: Backup files now include datetime stamp (`yyyymmdd_hhmmss_filename.bak`) for history tracking.

- **Enhanced debugging**: Added version number, file paths, and file size to init script output.

- **Detailed log files**: Init script now writes detailed logs to `reports/yyyymmdd_hhmmss_saropa_lints_init.log` for history and debugging.

### Fixed

- **Init script: false "user customizations" count**: Fixed bug where switching tiers would incorrectly count all tier-changed rules as "user customizations". Now only rules explicitly in the USER CUSTOMIZATIONS section are preserved. Added warning when >50 customizations detected (suggests using `--reset` to fix corrupted config).

---
## [4.7.0]

### Added

- **Single source of truth for rule tiers**: Rules now declare their tier directly in the rule class via `RuleTier get tier` getter. The init script reads tier from rule classes with fallback to legacy `tiers.dart` for backwards compatibility.

- **Enhanced init script output**:
  - Cross-platform ANSI color support (Windows Terminal, ConEmu, macOS, Linux)
  - Rules organized by tier with visual tier headers
  - Problem message comments next to every rule in YAML
  - Stylistic rules in dedicated section
  - Summary with counts by tier and severity
  - Massive ASCII art section headers for easy navigation

- **Progress tracking with ETA**:
  - File discovery at startup for accurate progress percentage
  - Rolling average for stable ETA calculation
  - Slow file detection (files taking >5 seconds)
  - Violation count tracking
  - Recalibration when more files found than expected

### Fixed

- **`prefer_small_length_files` and `prefer_small_length_test_files` tier misassignment**: Fixed bug where these insanity-tier rules were incorrectly enabled in comprehensive tier. Rules now correctly have `tier => RuleTier.insanity` override.

---

## [4.6.2] and Earlier

For details on the initial release and versions 0.1.0 through 4.6.2, please refer to [CHANGELOG_ARCHIVE.md](./CHANGELOG_ARCHIVE.md).
