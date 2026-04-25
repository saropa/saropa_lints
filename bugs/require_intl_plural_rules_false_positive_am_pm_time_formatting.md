# BUG: `require_intl_plural_rules` false positive on AM/PM hour formatting

**Status: Fixed** (literal-only plural scan; see `CHANGELOG.md` 12.5.0)

Created: 2026-04-25  
Rule: `require_intl_plural_rules`  
Severity: False positive

---

## Attribution Evidence

- Rule defined in `lib/src/rules/ui/internationalization_rules.dart`:
  - `'require_intl_plural_rules'`
- Rule set exported in `lib/src/rules/all_rules.dart`:
  - `export 'ui/internationalization_rules.dart';`

---

## Reproducer (downstream)

`contacts/lib/components/country/timezone/availability_hour_wheel.dart`:

- function `_formatHour(int hour)` with AM/PM branch:
  - `if (hour == 0) return '12\nAM';`
  - `if (hour == 12) return '12\nPM';`
  - `return '$display\n${isPM ? 'PM' : 'AM'}';`

This is clock-format branching, not noun pluralization.

---

## Expected vs Actual

- **Expected:** No lint for fixed AM/PM formatting logic.
- **Actual:** Lint flags method as manual pluralization.

---

## Suspected Root Cause

Heuristic in `internationalization_rules.dart` appears broad:

- identifies `String` methods with an `int` param,
- checks `== 1` / `!= 1` comparison patterns,
- then checks generic plural-word regex.

This can overmatch time-display helpers and other non-plural quantity formatting.

---

## Suggested Fix

1. Tighten rule to detect pluralization intent, not any numeric branching.
2. Exclude common time-format markers (`AM`, `PM`) and non-count labels.
3. Add a fixture explicitly validating `_formatHour`-style methods as **OK**.

