# Changelog

All notable changes to this project will be documented in this file.
The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

> **Looking for older changes?** \
> See [CHANGELOG_ARCHIVE.md](./CHANGELOG_ARCHIVE.md) for versions 0.1.0 through 4.2.0.

## [4.5.3] - 2026-01-22

### Fixed

- Moved `json2yaml` and added `yaml` to main dependencies in pubspec.yaml to satisfy pub.dev requirements for CLI tools in `bin/`.
  This fixes publishing errors and allows versions above 4.5.0 to be published to pub.dev.

## [4.5.2] - 2026-01-22

### Changed

- **Major improvements to lint rule messages:**
  - All critical and high-impact rules now have detailed, actionable `problemMessage` and `correctionMessage` fields.
  - Messages now clearly explain the risk, impact, and how to fix each violation, following accessibility and best-practice standards.
  - The following files were updated with improved messages for many rules:
    - `debug_rules.dart`
    - `disposal_rules.dart`
    - `equatable_rules.dart`
    - `file_handling_rules.dart`
    - `hive_rules.dart`
    - `internationalization_rules.dart`
    - `json_datetime_rules.dart`
    - `memory_management_rules.dart`
    - `security_rules.dart`
    - `type_safety_rules.dart`
  - Notable rules improved: `avoid_sensitive_in_logs`, `require_page_controller_dispose`, `avoid_websocket_memory_leak`, `avoid_mutable_field_in_equatable`, `require_sqflite_whereargs`, `avoid_hive_field_index_reuse`, `require_intl_args_match`, `prefer_try_parse_for_dynamic_data`, `require_image_disposal`, `avoid_expando_circular_references`, `avoid_path_traversal`, `require_null_safe_json_access`, and others.
  - Many rules now provide context-specific examples and describe the consequences of ignoring the lint.

- **Stylistic tier now includes both type argument rules:**
  - `avoid_inferrable_type_arguments` and `prefer_explicit_type_arguments` have been added to the `stylisticRules` set in `tiers.dart`.
  - Both rules are now included when the stylistic tier is enabled, but remain mutually exclusive in effect (enabling both will cause conflicting lints).
  - This change makes it easier to opt into either style preference via the `--stylistic` flag or tier selection, but users should only enable one of the two in their configuration to avoid conflicts.

## [4.5.1] - 2026-01-22

### Package Dependancies

- Ensure custom_lint and custom_lint_builder use the same version in pubspec.yaml to avoid compatibility issues. If you downgrade, set both to the same version (e.g., ^0.8.0).
- Upgraded dev dependencies: test to v1.29.0 and json2yaml to v3.0.1.

### Changed

- **CLI tool (bin/init.dart) improvements:**
  - Added `--no-pager` flag to print the full dry-run preview without pausing (useful for CI/non-interactive environments).
  - Dry-run pagination is now automatically skipped if stdin is not a terminal.
  - YAML parse errors in existing analysis_options.yaml are now caught and reported, with a fallback to a fresh config if needed.
  - Added and improved code comments throughout for clarity and maintainability.
  - Help output now documents the new flag and behaviors.

- Migrated rules 4.2.0 and below to [CHANGELOG_ARCHIVE.md](./CHANGELOG_ARCHIVE.md)

#### File Length Rules Renamed (structure_rules.dart)

All file length rules have been renamed to include `_length` for clarity and consistency:

**Production file length rules:**

- `prefer_small_files` → `prefer_small_length_files` (insanity tier, >200 lines)
- `avoid_medium_files` → `avoid_medium_length_files` (professional tier, >300 lines)
- `avoid_long_files` → `avoid_long_length_files` (comprehensive tier, >500 lines)
- `avoid_very_long_files` → `avoid_very_long_length_files` (recommended tier, >1000 lines)

**Test file length rules:**

- `prefer_small_test_files` → `prefer_small_length_test_files` (insanity tier, >400 lines)
- `avoid_medium_test_files` → `avoid_medium_length_test_files` (professional tier, >600 lines)
- `avoid_long_test_files` → `avoid_long_length_test_files` (comprehensive tier, >1000 lines)
- `avoid_very_long_test_files` → `avoid_very_long_length_test_files` (recommended tier, >2000 lines)

Production file length rules now skip test files automatically.

**Explanation:**
Production file length rules (such as `prefer_small_length_files`, `avoid_medium_length_files`, etc.) now automatically exclude test files from their checks. This prevents false positives on large test files and means you no longer need to manually disable these rules for test files in your configuration. Only production (non-test) Dart files are checked for file length limits by these rules.

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

**Production code rules now skip test files** - `no_magic_number` and `no_magic_string` now have `skipTestFiles: true`, preventing false positives on legitimate test data like hex strings ('7FfFfFfFfFfFfFf'), test descriptions, and expected values. Use the test-specific variants for appropriate enforcement in tests.

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

## [4.2.0] and Earlier

For details on the initial release and versions 0.1.0 through 4.2.0, please refer to [CHANGELOG_ARCHIVE.md](./CHANGELOG_ARCHIVE.md).
