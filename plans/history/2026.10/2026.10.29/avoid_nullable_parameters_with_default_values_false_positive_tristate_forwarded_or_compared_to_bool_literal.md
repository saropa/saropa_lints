# BUG: `avoid_nullable_parameters_with_default_values` — flags a tri-state `bool? x = false` that is forwarded to a callee or compared only with `true` / `false`

**Status: Open**

Created: 2026-10-29
Rule: `avoid_nullable_parameters_with_default_values`
File: `lib/src/rules/data/type_rules.dart` (class 889, code 908, `runWithReporter` ~920-940, `_bodyComparesToNull` 944)
Severity: False positive
Rule version: v5 | Since: see rule dartdoc | Updated: 17.0.1-beta.2 (installed); the repo source already has `_bodyComparesToNull`

Related (closed, narrower case): `plans/history/2026.10/2026.10.29/avoid_nullable_parameters_with_default_values_false_positive_tristate_null_means_all.md`.

---

## Summary

The repo source exempts a nullable parameter with a non-null default only when the function body contains `name == null` or `name != null` (`_bodyComparesToNull`, line 944). Two tri-state shapes remain flagged although `null` is a distinct, meaningful value:

1. **Forwarded:** the function passes the parameter on unchanged (`isHidden: isHidden`) to a callee that treats `null` as "no filter". The callee holds the null test, so the forwarding body has none.
2. **Compared to bool literals only:** the body tests `x == true` and `x == false`. `null` falls through both branches and means "no filter". No `x == null` is written.

Dropping the `?` removes the "all rows" option, because callers pass `isHidden: null` explicitly.

---

## Attribution Evidence

```bash
# Positive — rule IS defined here
grep -rn "'avoid_nullable_parameters_with_default_values'" lib/src/rules/
# lib/src/rules/data/type_rules.dart:908:    'avoid_nullable_parameters_with_default_values',
```

**Emitter registration:** `lib/src/rules/data/type_rules.dart:908`
**Rule class:** `AvoidNullableParametersWithDefaultValuesRule` (`type_rules.dart:889`), registered in `lib/saropa_lints.dart`
**Diagnostic `source` / `owner` as seen in Problems panel:** `source: saropa_lints`, `owner: saropaLintsLsp`

---

## Reproducer

Standalone plain Dart. Verified to compile and run; it prints `[1, 2, 3, 4]` and `4`, which proves `null` selects all rows.

```dart
// Real code: /Users/craighathaway/Documents/src/contacts/lib/database/drift_middleware/user_data/organization_drift_io.dart:382 (dbOrganizationLoadList)
// and :773 (forwarding wrapper).
Future<List<int>> loadRows({bool? isHidden = false}) async { // LINT — should NOT lint (null = all rows)
  const List<int> rows = <int>[1, 2, 3, 4];
  if (isHidden == true) {
    return rows.where((int r) => r.isOdd).toList();
  } else if (isHidden == false) {
    return rows.where((int r) => r.isEven).toList();
  }
  return rows;
}

Future<int> countRows({bool? isHidden = false}) async { // LINT — should NOT lint (forwarded)
  final List<int> rows = await loadRows(isHidden: isHidden);
  return rows.length;
}

Future<void> main() async {
  print(await loadRows(isHidden: null)); // [1, 2, 3, 4]
  print(await countRows(isHidden: null)); // 4
}
```

**Frequency:** Always for these two shapes.

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | No diagnostic: `null` is a third state that callers use |
| **Actual** | `[avoid_nullable_parameters_with_default_values] Parameter with default value must not be nullable. ...` at `389:5-389:10` (the `bool?` token) in the original file position of `dbOrganizationLoadList`; same message for each forwarder listed below |

---

## AST Context

```
ClassDeclaration (DatabaseOrganizationDriftIO)
  └─ MethodDeclaration (dbOrganizationLoadList)
      └─ FormalParameterList
          └─ RegularFormalParameter (isHidden)  defaultClause: BooleanLiteral(false)
              └─ NamedType (bool?)  ← node reported here (reporter.atNode(typeAnnotation), type_rules.dart:937)
```

---

## Root Cause

`runWithReporter` (`type_rules.dart` ~920-938):

1. `defaultValue` is `false`, not a `NullLiteral`, so the rule continues.
2. `typeAnnotation is NamedType && typeAnnotation.question != null` is true.
3. `_bodyComparesToNull(node)` (line 944) runs `_NullCompareFinder`, which sets `found` only in `visitBinaryExpression` for `==` / `!=` with one side a `SimpleIdentifier` named like the parameter and the other side a `NullLiteral`.
4. Shape 1 has no binary expression on the parameter (it is an argument). Shape 2 has binary expressions, but the other operand is a `BooleanLiteral`. `found` stays false, so line 937 reports.

The finder looks for the null test in the function itself. It does not follow the value into a callee, and it does not treat "compared with both `true` and `false`" as proof that a third state exists.

---

## Why the code is correct

- Callers pass `isHidden: null` on purpose (`organization_extensions_io.dart:48`, `:377`, `:392`; `family_group_drift_io.dart:716`, `:820`, `:970`) to load hidden and visible rows together, for duplicate checks.
- With `bool isHidden = false`, those calls would not compile or would silently lose the all-rows option.
- The forwarders must keep the `?` so the callee receives the caller's `null` unchanged.

---

## Affected project locations

- `lib/database/drift_middleware/user_data/organization_drift_io.dart:382` (`dbOrganizationLoadList`, compares to `true` / `false` only)
- `lib/database/drift_middleware/user_data/organization_drift_io.dart:773`, `:814`, `:839`, `:893` (forwarders to `dbOrganizationCount` / `dbOrganizationLoadList`)
- `lib/database/drift_middleware/user_data/family_group_drift_io.dart:273` (compares to `true` / `false` only)
- `lib/database/drift_middleware/user_data/family_group_drift_io.dart:1171`, `:1212`, `:1248` (forwarders)

Not affected after the repo fix: `organization_drift_io.dart:235` and `organization_extensions_io.dart:520`, `family_group_drift_io.dart:135` (their bodies contain `isHidden == null` / `!= null`).

---

## Suggested Fix

Extend `_bodyComparesToNull` (line 944) to also return true when, inside the body, the parameter is:

- an argument of an invocation (positional, or `name: param` in a `NamedExpression`) whose parameter in the resolved callee is itself nullable; or
- compared with `== true` AND `== false` (both literals present), which proves a third state.

The first rule needs `usesTypeResolution` (already true). Skip the exemption when the callee's parameter is non-nullable, because that code would not compile.

---

## Fixture Gap

`example*/lib/data/avoid_nullable_parameters_with_default_values_fixture.dart` should include:

1. `Future<int> f({bool? x = false}) async => x == true ? 1 : x == false ? 2 : 3;` — expect NO lint.
2. `Future<int> g({bool? x = false}) => f(x: x);` where `f` takes `bool? x` — expect NO lint.
3. `int h({bool? x = false}) => x == true ? 1 : 2;` (only one literal compared, no third state) — expect LINT.
4. `int k({bool? x = false}) => nonNullable(x ?? false);` — expect LINT.

---

## Environment

- saropa_lints version: 17.0.1-beta.2 (installed in `~/.pub-cache`); repo source `17.0.1-beta.3` carries `_bodyComparesToNull`
- Dart SDK version: Dart SDK version: 3.13.7 (stable) (Thu Oct 22 14:28:57 2026 -0700) on "macos_arm64"
- Triggering project: Saropa contacts app (`/Users/craighathaway/Documents/src/contacts`)

## Status 2026-10-29

Fixed in 17.0.1-beta.3 (see CHANGELOG).
