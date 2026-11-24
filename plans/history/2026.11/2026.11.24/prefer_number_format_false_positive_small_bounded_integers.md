# BUG: `prefer_number_format` — Flags bounded small integers (day of month, minutes, hours, counts)

**Status: Open**

Created: 2026-11-23
Rule: `prefer_number_format`
File: `lib/src/rules/ui/internationalization_rules.dart` (line ~2358)
Severity: False positive
Rule version: v2 | saropa_lints 4.15.1 (downstream pubspec.lock)

---

## Summary

The rule reports any `int` interpolated into UI text. The rationale (grouping and decimal separators differ by locale) cannot apply to an integer that is structurally bounded below 1000: a day of month (1-31), an hour label (1-12), a slider value (15-30 minutes), or the length of a short list. Expected: no diagnostic for values with no grouping or decimal separator possible, or at least when the interpolation is a date/time component.

---

## Attribution Evidence

```bash
grep -rn "'prefer_number_format'" lib/src/rules/
# lib/src/rules/ui/internationalization_rules.dart:2358
```

---

## Reproducer

```dart
Widget build(BuildContext context, DateTime due, int syncMinutes) => Column(children: [
  Text('${due.day}'),                  // LINT, but should NOT lint: 1-31, no separator exists
  Text('Every $syncMinutes minutes'), // LINT, but should NOT lint: slider bounded 15-30
]);
```

**Frequency:** Always.

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | No diagnostic for `DateTime.day/hour/minute/month` or other ints with a bounded small range |
| **Actual** | `[prefer_number_format] Number displayed without locale formatting.` |

## Suggested Fix

Skip interpolations of `DateTime` component getters, and ints that come from a clamped/divisioned slider or a `.length` of a collection documented small.

Observed in jupiter-tablet `lib/ui/sheets.dart`, `lib/ui/settings_screen.dart`, `lib/ui/settings_pages.dart`.
