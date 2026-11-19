# BUG: `avoid_nested_assignments` — Flags the idiomatic grouping pattern `(map[key] ??= <T>[]).add(item)`

**Status: Fixed**

Created: 2026-10-31
Rule: `avoid_nested_assignments`
File: `lib/src/rules/flow/control_flow_rules.dart` (line ~909)
Severity: False positive
Rule version: unknown | Since: unknown | Updated: unknown

---

## Summary

Flags the idiomatic grouping pattern `(map[key] ??= <T>[]).add(item)`. In a downstream app review, 8 of 15 reported sites for this rule were judged false positives.

---

## Attribution Evidence

```bash
grep -rn "'avoid_nested_assignments'" lib/src/rules/
# lib/src/rules/flow/control_flow_rules.dart:909:    'avoid_nested_assignments',
```

**Emitter registration:** `lib/src/rules/flow/control_flow_rules.dart:909`
**Diagnostic `source` as seen in Problems panel:** `saropa_lints`
Negative sibling-repo grep: not needed, the label is unambiguous.

---

## Reproducer

```dart
Map<String, List<int>> group(List<int> items, String Function(int) key) {
  final Map<String, List<int>> grouped = <String, List<int>>{};
  for (final int item in items) {
    (grouped[key(item)] ??= <int>[]).add(item); // LINT — but should NOT lint
  }
  return grouped;
}
```

**Real sites reviewed (Saropa Contacts app):** lib/utils/native_phone_import/native_import_rulings.dart:207; lib/utils/contact_group/contact_group_dynamic_io.dart:70,74,78,82; lib/database/drift_middleware/user_data/success_card_activity_count_drift_io.dart:114; edit_protection_stored_links.dart:27.

**Frequency:** Always, for the pattern shown.

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | No diagnostic: the code is correct |
| **Actual** | `[avoid_nested_assignments]` reported at each site above |

---

## Root Cause

The rule treats any assignment expression nested inside another expression as a hazard. A parenthesized `??=` used as the target of a method call is a well-known single-evaluation idiom; the alternative needs a second map lookup.

---

## Suggested Fix

Exempt a `??=` AssignmentExpression that is the parenthesized target of a MethodInvocation/PropertyAccess/IndexExpression and whose left side is an IndexExpression.

---

## Fixture Gap

The fixture for `avoid_nested_assignments` should add an expect-NO-lint case for each pattern in the reproducer, plus a near-miss expect-LINT case where the guard is missing.

---

## Environment

- saropa_lints version: current at time of filing (consumer: Saropa Contacts app)
- Dart SDK version: current stable

## Resolution

Fixed in `AvoidNestedAssignmentsRule` (`lib/src/rules/flow/control_flow_rules.dart`): a `??=` whose left side is an `IndexExpression`, wrapped in parentheses and used as the target of a method call, property access or index, is skipped. Fixture `example/lib/control_flow/avoid_nested_assignments_fixture.dart` gains good cases and near-miss bad cases (plain `=`, `??=` on a variable, `=` on an index). Verified with `dart run saropa_lints:scan` on a scratch copy: exactly the 4 expected diagnostics (1 original + 3 near-misses), none on the idiom.
