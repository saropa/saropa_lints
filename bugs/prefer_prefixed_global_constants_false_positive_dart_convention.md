# `prefer_prefixed_global_constants` false positive: Dart lowerCamelCase convention for constants

## Status: OPEN

## Summary

The `prefer_prefixed_global_constants` rule (v5) fires on global constants in `lib/datetime/date_constants.dart` that follow the **official Dart style guide** naming convention (`lowerCamelCase` without prefix). The rule demands a `k` prefix (e.g., `kMinMonth`, `kMaxMonth`), which is a C++/Objective-C convention inherited by the Flutter SDK for historical reasons. The official Effective Dart style guide explicitly mandates `lowerCamelCase` for constant names **without** any prefix. For a published Dart package, following the `k` prefix convention contradicts Dart community standards and would break API compatibility.

## Diagnostic Output

```
resource: /D:/src/saropa_dart_utils/lib/datetime/date_constants.dart
owner:    _generated_diagnostic_collection_name_#2
code:     prefer_prefixed_global_constants
severity: 2 (info)
message:  [prefer_prefixed_global_constants] Global constant must have a
          descriptive prefix. Global constants must be prefixed with 'k' or
          similar. {v5}
          Prefix the global constant with "k" (e.g., kMaxRetries) or use a
          longer descriptive name to distinguish it from local variables.
lines:    5, 8, 11, 14 (4 violations)
```

## Affected Source

File: `lib/datetime/date_constants.dart` — lines 4-20

```dart
/// Minimum valid month number (January).
const int minMonth = 1;

/// Maximum valid month number (December).
const int maxMonth = 12;

/// Maximum valid year in DateTime (9999).
const int maxYear = 9999;

/// Maximum valid hour (23 for 24-hour format, 0-23 range).
const int maxHour = 23;

/// Maximum valid minute or second (59 for 0-59 range).
const int maxMinuteOrSecond = 59;

/// Maximum valid millisecond or microsecond (999 for 0-999 range).
const int maxMillisecondOrMicrosecond = 999;
```

Additional constants in the same file that would also trigger:

```dart
/// Minimum number of days that exist in any month (February in non-leap years).
const int minDaysInAnyMonth = 28;

/// Days to add to safely reach next month (28 + 4 = 32 days > any month).
const int daysToAddToGetNextMonth = 4;

/// Number of days in February during a leap year.
const int daysInFebLeapYear = 29;

/// Modulo divisor for basic leap year check (divisible by 4).
const int leapYearModulo4 = 4;

/// Hour threshold for start of "day" time (after 7am).
const int dayStartHour = 7;

/// Hour threshold for end of "day" time (before 6pm/18:00).
const int dayEndHour = 18;
```

All of these constants follow the official Dart naming convention: `lowerCamelCase`, descriptive, and unambiguous.

## Root Cause

The rule enforces a `k` prefix convention on all top-level `const` declarations. This convention originates from:

1. **C++ coding style** — Google's C++ style guide uses `kConstantName`
2. **Objective-C conventions** — Apple's frameworks use `k` prefix for constants
3. **Flutter SDK historical usage** — Early Flutter code adopted `k` prefix from the C++ engine layer (e.g., `kToolbarHeight`, `kMinInteractiveDimension`)

However, the **official Dart style guide** (Effective Dart) explicitly contradicts this:

> **DO use lowerCamelCase for constant names.**
> In new code, use lowerCamelCase for constant variables, including enum values.
> — https://dart.dev/effective-dart/style#do-use-lowercamelcase-for-constant-names

The Dart team has been actively moving away from the `k` prefix convention. The `constant_identifier_names` core lint enforces `lowerCamelCase` without any prefix requirement. While `kMinMonth` would technically pass that lint (it is valid `lowerCamelCase`), the `k` prefix is not part of the Dart convention and is not used by any official Dart or Flutter package published after the convention change.

The rule has no mechanism to recognize that `lowerCamelCase` names like `minMonth`, `maxYear`, and `dayStartHour` are already descriptive and follow Dart conventions.

## Why This Is a False Positive

1. **Contradicts official Dart style** — Effective Dart says `lowerCamelCase` for constants. No mention of `k` prefix. The `k` prefix is not a Dart convention.

2. **Names are already descriptive** — `minMonth` clearly means "minimum month value." `maxHour` clearly means "maximum hour value." Adding `k` prefix (`kMinMonth`) adds no information and reduces readability for Dart developers.

3. **Breaking change for published packages** — Renaming `minMonth` to `kMinMonth` in a published package (`saropa_dart_utils` v1.0.6 on pub.dev) is a breaking API change that would require a major version bump and force all consumers to update their code.

4. **Conflicts with Dart ecosystem norms** — While `kMinMonth` technically passes the `constant_identifier_names` lint (it is valid `lowerCamelCase`), the `k` prefix convention is not used by any official Dart package, the Dart SDK, or the Effective Dart guide. Adopting it creates inconsistency with the broader Dart ecosystem.

5. **Flutter SDK is migrating away from `k` prefix** — The Flutter team has acknowledged that `k` prefix constants are a legacy pattern. New Flutter APIs use `lowerCamelCase` without prefix (e.g., `defaultTargetPlatform` not `kDefaultTargetPlatform`).

6. **All pub.dev packages follow `lowerCamelCase`** — Standard packages like `collection`, `meta`, `path`, and `http` use `lowerCamelCase` for constants without `k` prefix.

## Scope of Impact

Any Dart package or project that follows the official Effective Dart style guide for constant naming will trigger this rule on every top-level constant. This includes:

- All published Dart packages on pub.dev
- Projects that use `constant_identifier_names` lint (which enforces `lowerCamelCase`)
- Any codebase that follows Effective Dart conventions

Common constants that would be falsely flagged:

```dart
// All valid Dart constants — none use k prefix
const int maxRetries = 3;
const double defaultPadding = 8.0;
const String appName = 'MyApp';
const Duration animationDuration = Duration(milliseconds: 300);
const int minPasswordLength = 8;
const double goldenRatio = 1.618033988749895;
```

## Recommended Fix

### Approach A: Remove the rule entirely (recommended)

The `k` prefix convention is not part of the Dart language or its official style guide. Enforcing it contradicts Effective Dart and creates friction with the core `constant_identifier_names` lint. The rule should be removed or deprecated.

### Approach B: Only flag non-descriptive names

Instead of requiring a prefix, flag constants with genuinely ambiguous or too-short names:

```dart
// Only flag if the name is too short or non-descriptive
if (name.length < 3) {
  reporter.atNode(node, code);  // Flag: 'n', 'x', 'pi'
}
// Skip descriptive names
// 'minMonth', 'maxRetries', 'defaultPadding' — all clear
```

### Approach C: Make the rule opt-in only

If the `k` prefix convention is desired for specific codebases (e.g., Flutter SDK internal code), make it opt-in via configuration rather than enabled by default:

```yaml
# analysis_options.yaml — only for projects that want k prefix
saropa_lints:
  rules:
    prefer_prefixed_global_constants: true  # opt-in
```

### Approach D: Allow configurable prefix patterns

Let projects configure which prefix convention they use:

```yaml
saropa_lints:
  rules:
    prefer_prefixed_global_constants:
      prefix: 'k'  # or null for no prefix requirement
      min_name_length: 3  # only flag very short names
```

**Recommendation:** Approach A is best. The rule contradicts the official Dart style guide. If it must be kept, Approach B provides the right balance — flag genuinely ambiguous names without enforcing a non-Dart convention.

## Test Fixture Updates

### New GOOD cases (should NOT trigger)

```dart
// GOOD: Follows official Dart lowerCamelCase convention.
const int minMonth = 1;
const int maxMonth = 12;
const int maxRetries = 3;
const double defaultPadding = 8.0;
const String appName = 'MyApp';
const Duration animationDuration = Duration(milliseconds: 300);

// GOOD: Descriptive multi-word constant names.
const int maxMillisecondOrMicrosecond = 999;
const int daysToAddToGetNextMonth = 4;
const int defaultLeapYearCheckYear = 2000;
```

### Existing BAD cases (should still trigger if rule is kept)

```dart
// BAD: Non-descriptive single-character constant.
// expect_lint: prefer_prefixed_global_constants
const int n = 42;

// BAD: Ambiguous abbreviation.
// expect_lint: prefer_prefixed_global_constants
const int mx = 100;

// BAD: Single letter — impossible to understand without context.
// expect_lint: prefer_prefixed_global_constants
const double r = 3.14;
```

## Environment

- **saropa_lints version:** 5.0.0-beta.9 (rule version v5)
- **Dart SDK:** >=3.9.0 <4.0.0
- **Trigger project:** `D:\src\saropa_dart_utils` (published Dart utility package)
- **Trigger file:** `lib/datetime/date_constants.dart`
- **Trigger constants:** `minMonth`, `maxMonth`, `maxYear`, `maxHour` (lines 5, 8, 11, 14)
- **Naming convention used:** Official Effective Dart `lowerCamelCase`
- **Related core lint:** `constant_identifier_names` (enforces `lowerCamelCase` — `k` prefix is allowed but not required)

## Severity

Low — info-level diagnostic. The false positive recommends renaming constants to use a `k` prefix that contradicts the official Dart style guide. For a published package, following this advice would be a breaking API change. The rule erodes developer confidence because it flags code that follows best practices. Developers familiar with Effective Dart will recognize the `k` prefix recommendation as incorrect for Dart, potentially leading them to distrust other saropa_lints rules.
