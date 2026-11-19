# BUG: `avoid_nullable_parameters_with_default_values` — flags `bool? x = false` when the body uses `x ??= ...`

**Status: Fixed**

Created: 2026-10-31
Rule: `avoid_nullable_parameters_with_default_values`
File: `lib/src/rules/data/type_rules.dart` (`_NullCompareFinder`, line ~975)
Severity: False positive
Rule version: v5 | Since: unknown | Updated: 17.0.1-beta.6

---

## Summary

The tri-state exemption only detects `x == null` and `x != null`. A body that resolves `null` with `x ??= <fallback>` is also tri-state (null = "use the fallback", default = a fixed value) but is still flagged.

---

## Attribution Evidence

```bash
grep -rn "'avoid_nullable_parameters_with_default_values'" lib/src/rules/
# Expected: lib/src/rules/data/type_rules.dart:908
```

**Rule class:** `AvoidNullableParametersWithDefaultValuesRule`
**Diagnostic `source` / `owner` as seen in Problems panel:** `saropa_lints` / `saropaLintsLsp3`

---

## Reproducer

```dart
bool isEnabled({
  bool? ignoreEpoch = false, // LINT — should NOT lint
}) {
  ignoreEpoch ??= readUserPreference(); // null = use the user preference
  return !ignoreEpoch;
}
```

Real site: `contacts` app, `lib/database/drift_middleware/event_data/contact_event_range_check.dart:23`, parameter `ignoreUnixEpochDate`.

**Frequency:** Always

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | No diagnostic. `null` is a distinct input and the body acts on it. |
| **Actual** | `[avoid_nullable_parameters_with_default_values]` at the `bool?` type |

---

## Root Cause

`_NullCompareFinder` overrides only `visitBinaryExpression` and checks `==` / `!=`. `x ??= y` is an `AssignmentExpression` with operator `??=`. `x ?? y` is a `BinaryExpression` with operator `??`, also not matched.

---

## Suggested Fix

In `_NullCompareFinder`:

- Add `visitAssignmentExpression`: set `found` when the operator is `??=` and the left side is `SimpleIdentifier(name)`.
- In `visitBinaryExpression`: also set `found` for operator `??` with the left operand `SimpleIdentifier(name)`.

Add fixture cases to `example/lib/type/avoid_nullable_parameters_with_default_values_fixture.dart` and a test in `test/rules/data/type_rules_test.dart`.

---

## Resolution

`_NullCompareFinder` in `lib/src/rules/data/type_rules.dart` now treats `x ??= y` (AssignmentExpression) and `x ?? y` (BinaryExpression, left operand `x`) as null handling, so the tri-state exemption applies. Fixture cases added to `example/lib/type/avoid_nullable_parameters_with_default_values_fixture.dart` (good `??=`, good `??`, bad no null handling); the existing tri-state good case now includes an `== null` branch so it genuinely matches the exemption. Verified with `dart run saropa_lints:scan` on a copy of the fixture: only the two BAD cases fire.
