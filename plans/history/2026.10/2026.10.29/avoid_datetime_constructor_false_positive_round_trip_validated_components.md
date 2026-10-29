# BUG: `avoid_datetime_constructor` — Constructor Result Validated By Component Round-Trip

**Status: Open**

Created: 2026-10-29
Rule: `avoid_datetime_constructor`
File: `lib/src/rules/data/json_datetime_rules.dart (line ~1975)`
Severity: False positive

---

## Summary

The rule's own correction text says to "validate ranges" or verify `date.month == month && date.day == day` after construction. Code that does exactly that (assigns the result to a local and returns `null` when any component changed) is still reported by `avoid_datetime_constructor`. The sibling rule `avoid_datetime_constructor_unvalidated` (same file, line ~2261) correctly accepts this form; the primary rule has no equivalent exemption.

---

## Attribution Evidence

```bash
grep -rn "'avoid_datetime_constructor'" lib/src/rules/
# lib/src/rules/data/json_datetime_rules.dart:2013:    'avoid_datetime_constructor',
# lib/src/rules/data/json_datetime_rules.dart:2261:    'avoid_datetime_constructor',   (the _unvalidated rule reuses the id in a second LintCode)
# class AvoidDateTimeConstructorRule (json_datetime_rules.dart:1975)
```

---

## Reproducer

```dart
// Standalone, compiles with plain `dart`.
DateTime? birthdayDate(int? year, int? month, int? day) {
  if (year == null || month == null || day == null) return null;
  final DateTime date = DateTime(year, month, day); // LINT - should NOT lint
  // DateTime rolls out-of-range parts over (month 13, Feb 31); a changed part means bad input.
  if (date.year != year || date.month != month || date.day != day) return null;
  return date;
}

void main() => print(birthdayDate(2026, 2, 31)); // null
```
Project source: `lib/utils/organization/job_start_date_note.dart:31-39` (`JobStartDateNote.birthdayDate`). Before the validation was added the same line (34:12-38, `return DateTime(year, month, day);`) was reported by both rules; after adding the round-trip check only `avoid_datetime_constructor` can still report it.

**Frequency:** Always for component-based construction followed by a round-trip check.

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | No diagnostic when the next statements compare `date.year/month/day` to the inputs and bail out on mismatch |
| **Actual** | `[avoid_datetime_constructor] The DateTime constructor silently rolls over out-of-range values ...` at 34:12-38 (original unvalidated form; the round-trip form is still reported by this rule) |

---

## AST Context

```
MethodDeclaration (birthdayDate)
  └─ BlockFunctionBody
      └─ Block
          ├─ IfStatement (null guard)
          ├─ VariableDeclarationStatement
          │   └─ VariableDeclaration (date)
          │       └─ InstanceCreationExpression (DateTime(year, month, day))  <- reported
          ├─ IfStatement (date.year != year || date.month != month || date.day != day) return null
          └─ ReturnStatement (date)
```

---

## Root Cause

`runWithReporter` (json_datetime_rules.dart:2033-2052) reports every `DateTime` / `DateTime.utc` creation unless (1) `allLiteralsInRange(args)` (line 2044: all integer literals in range) or (2) `componentsFromValidDateTime(args)` (line 2049: components read from another DateTime). Neither looks at the statements after the construction. `AvoidDateTimeConstructorUnvalidatedRule` avoids this for the assigned-to-local case through `_isConsumedInline` (line ~2326), but the primary rule has no such step, so the validated code remains reported although the rule message and correction both describe validation as the cure.

---

## Why the Code Is Correct

The constructor result is held in a local, and every component is compared with its input before the value is used. Out-of-range input is rejected, so no silently wrong date can escape.

---

## Affected Project Locations

`lib/utils/organization/job_start_date_note.dart` line 34 (after fix, the `DateTime(year, month, day)` declaration). Same idiom exists wherever the project validates after construction (for example `lib/service/notification/events_notification_service.dart`, `parseMergedDay`).

---

## Suggested Fix

When the creation is the initializer of a local variable declaration, scan the following statements of the same block for an `IfStatement` whose condition compares at least two of `.year`, `.month`, `.day` of that local with other expressions (`!=`) and whose then-branch is `return`/`throw`/`continue`. Treat that as validated and skip.

---

## Fixture Cases

```dart
// LINT expected (consumed without check)
DateTime a(int y, int m, int d) => DateTime(y, m, d);

// OK expected (round-trip validated)
DateTime? b(int y, int m, int d) {
  final DateTime date = DateTime(y, m, d);
  if (date.year != y || date.month != m || date.day != d) return null;
  return date;
}
```

---

## Environment

- saropa_lints: 17.0.1-beta.2 (installed in the downstream project); rule line numbers below read from the local checkout (pubspec 17.0.1-beta.3), where the cited logic is unchanged.
- Dart SDK version: 3.13.7 (stable) (Thu Oct 22 14:28:57 2026 -0700) on "macos_arm64"
- Downstream project: Saropa Contacts (`/Users/craighathaway/Documents/src/contacts`), Flutter app.
- Diagnostic `source` / `owner` in Problems panel: `saropa_lints` / `saropaLintsLsp`

## Status 2026-10-29

Fixed in 17.0.1-beta.4 (see CHANGELOG).
