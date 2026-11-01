# BUG: `require_timezone_display` — Flags `DateFormat.jm/Hm(...).format(dt)` where the intent is the user's local time of day

**Status: Fixed**

Created: 2026-10-31
Rule: `require_timezone_display`
File: `lib/src/rules/data/json_datetime_rules.dart` (line ~1735)
Severity: False positive
Rule version: unknown | Since: unknown | Updated: unknown

---

## Summary

Flags `DateFormat.jm/Hm(...).format(dt)` where the intent is the user's local time of day. In a downstream app review, 5 of 5 reported sites for this rule were judged false positives.

---

## Attribution Evidence

```bash
grep -rn "'require_timezone_display'" lib/src/rules/
# lib/src/rules/data/json_datetime_rules.dart:1735:    'require_timezone_display',
```

**Emitter registration:** `lib/src/rules/data/json_datetime_rules.dart:1735`
**Diagnostic `source` as seen in Problems panel:** `saropa_lints`
Negative sibling-repo grep: not needed, the label is unambiguous.

---

## Reproducer

```dart
String timeDisplay(DateTime local) {
  return DateFormat.jm(locale).format(local); // LINT — but should NOT lint: user-facing local time
}
```

**Real sites reviewed (Saropa Contacts app):** lib/utils/primitive/date_time/date_formatting.dart:391,394,397,400,403 (twelveHourAMPM, 24-hour, with seconds variants).

**Frequency:** Always, for the pattern shown.

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | No diagnostic: the code is correct |
| **Actual** | `[require_timezone_display]` reported at each site above |

---

## Root Cause

The rule wants a zone suffix on every formatted time. For a time shown on the user's own device, a zone name adds noise. The rule does not distinguish local DateTime from `isUtc == true`.

---

## Suggested Fix

Report only when the receiver is known UTC (`.toUtc()`, `DateTime.utc`, `isUtc`) or when the value is a stored timestamp from another zone. Skip local `DateTime.now()`-derived values and formats that are time-of-day only.

---

## Fixture Gap

The fixture for `require_timezone_display` should add an expect-NO-lint case for each pattern in the reproducer, plus a near-miss expect-LINT case where the guard is missing.

---

## Environment

- saropa_lints version: current at time of filing (consumer: Saropa Contacts app)
- Dart SDK version: current stable

## Resolution

Fixed in `lib/src/rules/data/json_datetime_rules.dart`: the rule skips a `DateFormat` that is immediately applied with `.format(value)` unless the argument source mentions UTC (`.toUtc()`, `DateTime.utc`, `isUtc`). Stored or returned formatters are still flagged. Fixture cases added (local jm/Hm/Hms good; UTC and stored formatter bad) and verified with `dart run saropa_lints:scan --tier comprehensive --resolve` on a scratch copy: only the two bad cases fired.
