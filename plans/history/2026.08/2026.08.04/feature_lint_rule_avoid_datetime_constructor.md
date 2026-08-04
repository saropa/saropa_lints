# FEATURE: `avoid_datetime_constructor` — DateTime constructor silently rolls over invalid dates

**Status: Fixed**

Created: 2026-08-04
Severity: High

---

## Summary

The `DateTime()` constructor silently accepts out-of-range month/day/hour values and rolls them over using arithmetic overflow. `DateTime(2026, 13, 1)` quietly produces `2027-01-01` with no error, warning, or exception. This is a correctness trap: the code compiles, runs, and returns a plausible-looking date that is wrong.

`DateTime.parse()` and `DateTime.tryParse()` do NOT have this problem — they reject invalid components (throw `FormatException` / return `null` respectively). The constructor is the only entry point that silently corrupts.

---

## Dart SDK behavior reference

```dart
// Constructor — SILENT rollover (the bug vector)
DateTime(2026, 13, 1)   // → 2027-01-01 00:00:00.000
DateTime(2026, 0, 1)    // → 2025-12-01 00:00:00.000
DateTime(2026, 1, 32)   // → 2026-02-01 00:00:00.000
DateTime(2026, 2, 29)   // → 2026-03-01 00:00:00.000  (not a leap year)
DateTime(2026, 1, 1, 25) // → 2026-01-02 01:00:00.000

// parse — THROWS FormatException
DateTime.parse('2026-13-01')  // FormatException

// tryParse — returns null
DateTime.tryParse('2026-13-01')  // null
```

This is documented Dart behavior, not a bug in the SDK. The constructor intentionally allows overflow arithmetic (like `DateTime(2026, 1, 0)` for "last day of previous month"). The problem is that code receiving user input or external data can silently produce wrong dates when the input is invalid.

---

## Proposed rule

**Rule name:** `avoid_datetime_constructor`

**What it flags:** Any direct call to the `DateTime()` or `DateTime.utc()` constructor.

**Why:** The constructor's silent rollover makes it impossible to detect invalid date components at the call site. Code that constructs dates from variables (user input, API responses, database values, computed fields) has no way to know the result silently wrapped.

**Recommended alternatives:**
- `DateTime.tryParse()` for string inputs (returns `null` on invalid)
- `DateTime.parse()` when invalid input should be an error (throws)
- A project-level validated factory that range-checks components before constructing
- `DateFormat.parseStrict()` from `package:intl` for locale-aware parsing with validation

**Acceptable uses (potential allowlist):**
- Compile-time constants with literal values that are visibly valid: `DateTime(2026, 1, 1)` — all literals, all in range. These could be allowed via a quick-fix `// ignore:` with rationale, or the rule could skip calls where every argument is an `IntegerLiteral` within valid ranges (month 1-12, day 1-28 conservatively or 1-31 liberally, hour 0-23, etc.)
- Intentional overflow arithmetic: `DateTime(year, month + 1, 0)` to get "last day of month" — a known Dart idiom. The rule should probably still flag these, with the `// ignore:` carrying the rationale.

---

## Fixture sketch

```dart
// LINT — variable arguments, rollover risk
final DateTime bad1 = DateTime(year, month, day);

// LINT — utc variant, same risk
final DateTime bad2 = DateTime.utc(year, month, day);

// LINT — literal but out of range
final DateTime bad3 = DateTime(2026, 13, 1);

// LINT (or allowlisted) — all literals, all in range
final DateTime maybe = DateTime(2026, 6, 15);

// OK — tryParse with null check
final DateTime? safe1 = DateTime.tryParse(dateString);

// OK — parse with try-catch
final DateTime safe2 = DateTime.parse(dateString);
```

---

## Priority

High. Silent data corruption in date handling can propagate through business logic (scheduling, age calculations, birthday tracking, event ordering) without any signal that something went wrong. The rollover produces a valid `DateTime` object, so downstream code has no way to detect the error after construction.
