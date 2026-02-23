# Bug Report: `require_number_format_locale` — False Positive When Device Default Locale Is Intentional

## Diagnostic Reference

```json
[{
  "resource": "/D:/src/contacts/lib/components/country/capital_city/capital_city_widget.dart",
  "owner": "_generated_diagnostic_collection_name_#2",
  "code": "require_number_format_locale",
  "severity": 4,
  "message": "[require_number_format_locale] NumberFormat without explicit locale. 1,234.56 vs 1.234,56 varies by device. Consequence: Numbers may be formatted incorrectly for users in different locales, leading to misinterpretation. {v2}\nPass a locale to NumberFormat (e.g., NumberFormat.decimalPattern(locale)) so numbers display correctly for every user.",
  "source": "dart",
  "startLineNumber": 88,
  "startColumn": 45,
  "endLineNumber": 88,
  "endColumn": 74,
  "modelVersionId": 1,
  "origin": "extHost1"
}]
```

---

## Summary

The `require_number_format_locale` rule flags every `NumberFormat` constructor that lacks an explicit `locale` parameter. However, when the developer **intentionally** wants the user's device locale — which is exactly what the parameterless constructor provides — the warning is a false positive. The rule cannot distinguish between "developer forgot to specify a locale" and "developer deliberately chose the device default locale."

---

## The False Positive Scenario

### Real-World Example: Geographic Statistics Display

`lib/components/country/capital_city/capital_city_widget.dart`

```dart
// Line 88-89
final NumberFormat numberFormat = NumberFormat.decimalPattern();

// Used to format population, area, and elevation:
textValue: numberFormat.format(city.population),       // e.g., "8,336,817" or "8.336.817"
textValue: '${numberFormat.format(city.areaKm2)} km²', // e.g., "1,485 km²" or "1.485 km²"
textValue: '${numberFormat.format(city.elevationMeters)} m', // e.g., "10 m"
```

This widget displays geographic statistics for capital cities (population, area, elevation). These are **general-purpose numeric values** — not currency, not API data, not values that need to match a specific format. The correct behavior is to format them according to the user's device locale:

- A French user should see `8 336 817` (French grouping convention)
- A German user should see `8.336.817` (German grouping convention)
- A US user should see `8,336,817` (US grouping convention)

The parameterless `NumberFormat.decimalPattern()` does exactly this — it uses `Intl.defaultLocale`, which falls back to the device's locale. **This is the correct and intended behavior.**

### Second Real-World Example: Animated Counter

`lib/components/primitive/animation/animated_count.dart`

```dart
// Line 98
(widget.numberFormat ?? NumberFormat.decimalPattern()).format(_animation.value)
```

Here `NumberFormat.decimalPattern()` is the fallback when no explicit formatter is provided. The animated count widget is a generic UI component that should respect the user's locale by default.

---

## Why the Current Rule Is Wrong Here

The rule's problem message says:

> "Numbers may be formatted incorrectly for users in different locales, leading to misinterpretation."

But the parameterless `NumberFormat.decimalPattern()` **already adapts to the user's locale**. It's not "incorrectly formatted" — it's correctly formatted for the device locale. The rule assumes that locale-adaptive behavior is a bug, when in many cases it's the desired feature.

### When explicit locale IS needed

The rule is correct to flag cases where a **specific, deterministic** format is required:

- Serialization / deserialization (must be consistent: use `'en_US'`)
- API payloads (must match server expectations)
- File formats (CSV, logs — must use a fixed locale)
- Unit tests (must produce predictable output)

### When device locale IS correct

The rule is a false positive when the number is displayed to the user and should adapt to their preferences:

- Population, area, elevation, distance (geographic stats)
- Counts, quantities, scores (general UI display)
- Any read-only display value where the user's locale convention is preferred
- Default/fallback formatters in generic UI components

---

## Root Cause Analysis

The `RequireNumberFormatLocaleRule` in `internationalization_rules.dart` (line 1438-1523) performs a purely syntactic check:

1. For `NumberFormat(pattern)` constructors: flags if `< 2` arguments (line 1471)
2. For factory methods like `.decimalPattern()`: flags if no `locale:` named parameter and no positional argument (lines 1498-1516)

There is **no semantic analysis** to determine whether the device default locale is intentional. The rule treats every missing locale as an error, but the `intl` package intentionally provides parameterless constructors as a convenience for the common case of "use the device locale."

---

## Suggested Fixes

### Option A: Support a Sentinel Locale Value (Recommended)

Allow developers to explicitly acknowledge the device locale choice without silencing the entire rule:

```dart
// Currently flagged — no way to express "I mean the default locale"
final NumberFormat numberFormat = NumberFormat.decimalPattern();

// Proposed: allow Intl.defaultLocale or similar sentinel to satisfy the rule
final NumberFormat numberFormat = NumberFormat.decimalPattern(Intl.defaultLocale);
```

The rule could recognize `Intl.defaultLocale`, `Intl.systemLocale`, or `Platform.localeName` as valid locale values, treating them as an explicit acknowledgment that device-locale behavior is intended.

### Option B: Don't Flag Inside UI Display Contexts

If the `NumberFormat` is used inside a `build()` method (or a `builder:` callback) and the result is passed to a widget's text parameter, the developer is almost certainly formatting for display and device-locale is appropriate. The rule could skip these contexts.

### Option C: Add a Quick Fix for "Use Device Locale"

Rather than changing the rule's detection logic, provide a quick fix that inserts `Intl.defaultLocale`:

```dart
// Before (flagged)
NumberFormat.decimalPattern()

// After quick fix: "Use device locale explicitly"
NumberFormat.decimalPattern(Intl.defaultLocale)
```

This satisfies the rule while documenting intent, without requiring an `// ignore` comment.

### Option D: Lower Severity for Parameterless Display Methods

Methods like `decimalPattern()`, `percentPattern()`, and `compact()` are overwhelmingly used for display purposes where device locale is correct. Consider lowering their severity to `INFO` (hint) rather than `WARNING`, while keeping `currency()` and `simpleCurrency()` at `WARNING` since currency formatting errors have higher financial consequences.

---

## Patterns That Should Be Recognized as Safe

| Pattern | Currently Flagged | Should Be Flagged |
|---|---|---|
| `NumberFormat.decimalPattern()` | **Yes** | **Context-dependent** |
| `NumberFormat.decimalPattern(Intl.defaultLocale)` | No | No |
| `NumberFormat.decimalPattern('en_US')` | No | No |
| `NumberFormat.compact()` | **Yes** | **Context-dependent** |
| `NumberFormat.currency()` | **Yes** | Yes (currency needs explicit locale) |
| `NumberFormat('#,###')` | **Yes** | Yes (raw pattern is ambiguous) |

---

## Current Workaround

Developers must add `// ignore: require_number_format_locale` with a comment explaining why the device locale is intentional:

```dart
// Device locale is intentionally used — geographic stats adapt to user's region
// ignore: require_number_format_locale
final NumberFormat numberFormat = NumberFormat.decimalPattern();
```

This works but has drawbacks:
- Suppresses the entire rule, so future changes that genuinely need a locale won't be caught
- Adds visual noise for correct code
- The `// ignore` pattern scales poorly across a codebase

---

## Affected Files

| File | Line | What |
|---|---|---|
| `lib/src/rules/internationalization_rules.dart` | 1438-1523 | `RequireNumberFormatLocaleRule` — no semantic context for intentional device-locale usage |
| `lib/src/rules/internationalization_rules.dart` | 1498-1516 | Locale detection — could recognize `Intl.defaultLocale` as valid |
| `lib/src/rules/internationalization_rules.dart` | 1447-1454 | `_code` — problem message assumes missing locale is always wrong |

## Priority

**Medium** — The rule is valuable for catching genuine locale omissions (especially in currency and serialization contexts), but the false positive on display-oriented formatting is common enough to erode trust. The `intl` package itself documents the parameterless constructors as the idiomatic way to use the device locale, so flagging them unconditionally contradicts the library's own API design.
