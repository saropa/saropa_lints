# BUG: `avoid_nullable_parameters_with_default_values` — flags a nullable parameter that is only forwarded to a callee

**Status: Fixed**

Created: 2026-10-31
Rule: `avoid_nullable_parameters_with_default_values`
File: `lib/src/rules/data/type_rules.dart` (`_bodyComparesToNull`, line ~940)
Severity: False positive
Rule version: v5 | Since: unknown | Updated: 17.0.1-beta.6

---

## Summary

A parameter `T? x = default` that the body forwards unchanged to another function is flagged. The callee (or an explicit `null` from the caller) gives `null` its meaning, so the `?` is required. The body never compares to `null`, so the tri-state exemption does not apply.

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
void load({
  List<int>? excludeSources = const <int>[0], // LINT — should NOT lint
  bool? isHidden = false, // LINT — should NOT lint
}) {
  query(excludeSources: excludeSources, isHidden: isHidden);
}

// Callee accepts null: null = "exclude nothing" / "no hidden filter".
void query({List<int>? excludeSources, bool? isHidden}) {}

// Caller passes null explicitly to override the default.
void caller(List<int>? fromOptions) => load(excludeSources: fromOptions);
```

Real sites: `contacts` app, `lib/database/drift_middleware/event_data/contact_event_io.dart:333` (`excludeContactSources`) and `:340` (`isHidden`). The first is forwarded into `ContactFilters(excludeDataSources: ...)`. The second is forwarded into `isEventInRange(isHidden: ...)`.

**Frequency:** Always, for parameters used only as a pass-through.

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | No diagnostic when the parameter is passed as an argument to another call whose matching parameter is nullable. |
| **Actual** | `[avoid_nullable_parameters_with_default_values]` at the `?` type |

---

## Root Cause

`_bodyComparesToNull` only looks for `x == null` / `x != null`. A forwarded `x` has no comparison, so the rule reports.

---

## Suggested Fix

Exempt the parameter when the body passes it directly as a named or positional argument and the resolved target parameter type is nullable (`ParameterElement.type` nullability via `argument.correspondingParameter`). Removing the `?` in that case would force callers to stop passing `null`, which breaks callers such as `load(excludeSources: fromOptions)` above.

Add fixture cases to `example/lib/type/avoid_nullable_parameters_with_default_values_fixture.dart` and a test in `test/rules/data/type_rules_test.dart`.

---

## Resolution

`_NullCompareFinder` in `lib/src/rules/data/type_rules.dart` now overrides `visitArgumentList`: when the parameter is passed directly as an argument and `Argument.correspondingParameter` has a nullable type, the tri-state exemption applies. Fixture cases added (good pass-through; bad forwarded with `!`; bad not forwarded). Verified with `dart run saropa_lints:scan --resolve` on a copy of the fixture: only the BAD cases fire.
