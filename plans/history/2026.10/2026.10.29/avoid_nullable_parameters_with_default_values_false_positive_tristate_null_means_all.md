# BUG: `avoid_nullable_parameters_with_default_values` — flags `bool? isHidden = false` where `null` is a distinct, meaningful "no filter" value

**Status: Open**

Created: 2026-10-29
Rule: `avoid_nullable_parameters_with_default_values`
File: `lib/src/rules/data/type_rules.dart` (class ~865, code ~884, `runWithReporter` ~900)
Severity: False positive
Rule version: v5 | Since: see rule dartdoc | Updated: see rule dartdoc

---

## Summary

The rule assumes a nullable parameter with a non-null default can drop the `?`. That is false when the body gives `null` its own meaning. `bool? isHidden = false` is a tri-state filter: `true` = only hidden rows, `false` (default) = only visible rows, `null` = all rows. Callers pass `isHidden: null` explicitly to get every row. Dropping the `?` would remove the "all rows" option.

---

## Attribution Evidence

```bash
# Positive — rule IS defined here
grep -rn "'avoid_nullable_parameters_with_default_values'" lib/src/rules/
# lib/src/rules/data/type_rules.dart:884:    'avoid_nullable_parameters_with_default_values',

# Negative — sibling repo (../saropa_drift_advisor) is not checked out on this machine, so the
# negative grep cannot be run. The diagnostic text below is byte-identical to the LintCode
# message in this repo, plus the `{vN}` suffix, which is the attribution evidence.
```

**Emitter registration:** `lib/src/rules/data/type_rules.dart:884`; registered at `lib/saropa_lints.dart:487` (`AvoidNullableParametersWithDefaultValuesRule.new`)
**Rule class:** `AvoidNullableParametersWithDefaultValuesRule` (`type_rules.dart:865`)
**Diagnostic `source` / `owner` as seen in Problems panel:** `source: saropa_lints`, `owner: saropaLintsLsp`

---

## Reproducer

Compiles standalone (plain Dart). Copied in shape from
`/Users/craighathaway/Documents/src/contacts/lib/database/drift_middleware/user_data/contact_group_drift_io.dart:141-172` (`dbContactGroupLoadCount`) and `:322-358`.

```dart
Future<String> buildWhere({bool? isHidden = false}) async { // LINT — but should NOT lint (false positive)
  if (isHidden == true) {
    return 'hidden = 1';
  } else if (isHidden == false) {
    return 'hidden = 0';
  }
  // isHidden == null -> no WHERE clause, count all rows
  return '1 = 1';
}

Future<void> main() async {
  await buildWhere(); // default: visible only
  await buildWhere(isHidden: null); // explicit: all rows
  await buildWhere(isHidden: true); // hidden only
}
```

Real call sites that pass `null` on purpose: `contact_group_drift_io.dart:1054`, `:1333`, `:1381`, `:1501` (`isHidden: null` with the comment "find ALL groups (including hidden) to avoid creating duplicates").

**Frequency:** Always, for any `T? p = nonNullDefault` parameter.

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | No diagnostic when the body distinguishes `p == null` from the default. |
| **Actual** | `[avoid_nullable_parameters_with_default_values] Parameter with default value must not be nullable. If a parameter has a default value, it doesn't need to be nullable. Quick fix available: Adds a comment to flag for manual review. {v5}` at `contact_group_drift_io.dart` 141:5-141:10 (the `bool?` type annotation) |

---

## AST Context

```
ClassDeclaration (DatabaseContactGroupDriftIO)
  └─ MethodDeclaration (static dbContactGroupLoadCount)
      └─ FormalParameterList
          └─ DefaultFormalParameter (named, optional)
              └─ RegularFormalParameter (isHidden)
                  ├─ NamedType (bool?)  ← reporter.atNode(typeAnnotation)
                  └─ defaultClause: BooleanLiteral (false)
```

---

## Root Cause

`type_rules.dart` `runWithReporter` (~901-918):

```dart
context.addRegularFormalParameter((RegularFormalParameter node) {
  final Expression? defaultValue = node.defaultClause?.value;
  if (defaultValue == null) return;
  if (defaultValue is NullLiteral) return;                       // skip `= null`
  if (node.functionTypedSuffix != null) return;
  final TypeAnnotation? typeAnnotation = node.type;
  if (typeAnnotation is NamedType && typeAnnotation.question != null) {
    reporter.atNode(typeAnnotation);                             // <-- no look at the body
  }
});
```

The check is purely syntactic on the signature. It never looks at the function body, so it cannot tell a redundant `?` from a deliberate `null` state. The rule already treats the `= null` default as intentional.

---

## Why the code is correct

The parameter is a tri-state filter (`true` / `false` / `null`). The body branches on `isHidden == true`, `isHidden == false`, and the fall-through `null` case (comment in source: `// isHidden == null → no WHERE → count all rows`). The default `false` keeps the common call (visible rows only) short. Removing the `?` makes "all rows" unreachable and changes query results for callers that pass `isHidden: null`.

---

## Affected Locations (contacts app)

Line numbers as reported by the diagnostics:

| File | Line:col |
|---|---|
| `/Users/craighathaway/Documents/src/contacts/lib/database/drift_middleware/user_data/contact_group_drift_io.dart` | 141:5, 323:5, 2060:5 |

---

## Suggested Fix

When the parameter is a named or positional `RegularFormalParameter` with a nullable type, scan the enclosing function body for a use that treats it as nullable: `param == null`, `param != null`, `param?.`, `param ?? x`, a null-aware spread, or passing it to another call whose parameter type is nullable. If any such use exists, do not report. If the parameter is only read (`return isHidden`), keep reporting.

---

## Fixture Gap

1. `void f({int? count = 5}) { print(count); }` — expect LINT (body never tests null; unchanged)
2. `void f({bool? isHidden = false}) { if (isHidden == null) { ... } }` — expect NO lint (new)
3. `void f({bool? isHidden = false}) { if (isHidden == true) {...} else if (isHidden == false) {...} }` — expect NO lint when the fall-through is documented/handled; at minimum expect NO lint when passed on to another `bool?` parameter (the real code forwards it as `isHidden: isHidden` at `contact_group_drift_io.dart:193`)
4. `void f({String? s = null}) {}` — expect NO lint (unchanged)

---

## Environment

- saropa_lints version: 17.0.1-beta.2
- Dart SDK version: 3.13.7 (stable) (Thu Oct 22 14:28:57 2026 -0700) on "macos_arm64"
- custom_lint version: not used (diagnostic delivered by the `saropaLintsLsp` owner in VS Code, `source: saropa_lints`)
- Triggering project/file: `/Users/craighathaway/Documents/src/contacts` (Flutter app `saropa`); files listed under Affected Locations

---

## Additional affected locations (appended 2026-10-29)

Same rule, same tri-state pattern (explicit `null` is a distinct value from the non-null default). Evidence that `null` is passed or branched on:

- `/Users/craighathaway/Documents/src/contacts/lib/database/drift_middleware/event_data/contact_event_range_check.dart:23` (`bool? ignoreUnixEpochDate = false`; body line 46 `ignoreUnixEpochDate ??= ...` reads the user preference when null) and `:24` (`bool? isHidden = false`; body line 35 `if (isHidden != null)`; null = both hidden and visible). Project tests pass `isHidden: null` explicitly: `test/database/drift_middleware/event_data/contact_event_range_check_new_year_test.dart` lines 17, 37, 52, 67, 84, 92.
- `/Users/craighathaway/Documents/src/contacts/lib/database/drift_middleware/event_data/contact_event_io.dart:331` (`List<ContactDataSource>? excludeContactSources = const [Coach]`; null = exclude nothing; `event_range_io.dart:692` forwards a possibly-null `options.excludeContactSources`) and `:338` (`bool? isHidden = false`, forwarded to `isEventInRange`).
- Suggested rule exemption: skip a parameter when the enclosing body contains `p == null`, `p != null`, `p ?? x`, `p ??= x` or `p?.member`.
