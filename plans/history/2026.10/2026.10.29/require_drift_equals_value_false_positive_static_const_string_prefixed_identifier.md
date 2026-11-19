# BUG: `require_drift_equals_value` — flags `.equals(ClassName.staticConstString)` because the argument looks like `Enum.member`

**Status: Open**

Created: 2026-10-29
Rule: `require_drift_equals_value`
File: `lib/src/rules/packages/drift_rules.dart` (class at line 2925)
Severity: False positive
Rule version: see diagnostic | Since: unknown | Updated: 17.0.1-beta.2

---

## Summary

The rule treats every `PrefixedIdentifier` whose prefix starts with an uppercase letter as an enum value. `ContactNameModel.displayUnnamed` is a `static const String`, so `.equals(...)` is correct and `.equalsValue(...)` does not exist for a plain text column.

---

## Attribution Evidence

```bash
grep -rn "'require_drift_equals_value'" lib/src/rules/
# lib/src/rules/packages/drift_rules.dart:2953:    'require_drift_equals_value',
```

**Rule class:** `RequireDriftEqualsValueRule` (`lib/src/rules/packages/drift_rules.dart:2925`)
**Diagnostic as seen in Problems panel:** `[require_drift_equals_value] .equals() called with an enum argument on a Drift column expression. ... {v1} (line 344, col 33)` (source: saropa_lints)

---

## Reproducer

Standalone shape (needs `package:drift`). Real code: `lib/database/drift_middleware/user_data/contact_load_first_io.dart` line 344 (`t.givenName.equals(ContactNameModel.displayUnnamed)`); constant declared at `lib/models/contact/contact_name_model.dart:90`.

```dart
import 'package:drift/drift.dart';

class Names extends Table {
  TextColumn get givenName => text().nullable()();
}

abstract final class NameModel {
  static const String displayUnnamed = 'Unnamed';
}

Expression<bool> unnamed(Names t) =>
    t.givenName.equals(NameModel.displayUnnamed); // LINT — but should NOT lint (String constant)
```

**Frequency:** Always for this pattern.

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | No diagnostic: the argument is a `String` constant, the raw SQL type |
| **Actual** | `[require_drift_equals_value]` on `equals` |

---

## AST Context

`MethodInvocation(equals)` > `ArgumentList` > `PrefixedIdentifier(prefix: NameModel, identifier: displayUnnamed)`. Enclosing: `FunctionExpression` > `ArgumentList` of `where(...)` > `CascadeSection` > `MethodInvocation(select)` in `DatabaseContactLoadFirstIO` (abstract final class).

---

## Root Cause

`drift_rules.dart` (lines 2976-2990): the check is `arg is PrefixedIdentifier` and `prefix[0].toUpperCase() == prefix[0]` and the prefix is not in `_nonEnumPrefixes` (a fixed list of type names: `String`, `DateTime`, ...). The rule never resolves the argument type, so a user class holding a `static const String` is treated as an enum. `usesTypeResolution` is not enabled for this rule.

---

## Why the code is correct

`ContactNameModel.displayUnnamed` is `static const String displayUnnamed = 'Unnamed'`. The column `givenName` is a plain text column with no TypeConverter. `.equals(String)` is the only valid call.

## Affected project locations

- `lib/database/drift_middleware/user_data/contact_load_first_io.dart:344`

---

## Suggested Fix

Resolve `arg.staticType`. Report only when the type is an enum (`InterfaceType.element is EnumElement`) or an `extension type` over an enum. Keep the prefix heuristic only as the fallback when the type is unresolved.

---

## Fixture Gap

- GOOD: `column.equals(Holder.someStringConst)` where the constant is `String`.
- GOOD: `column.equals(Holder.someIntConst)`.
- BAD: `column.equals(Status.active)` where `Status` is an enum and the column has a TypeConverter.

---

## Environment

- saropa_lints version: 17.0.1-beta.2 (installed, hosted); rule logic cross-checked against the repo source (17.0.1-beta.3)
- Dart SDK: Dart SDK version: 3.13.7 (stable) (Thu Oct 22 14:28:57 2026 -0700) on "macos_arm64"
- Triggering project: Saropa contacts app (`/Users/craighathaway/Documents/src/contacts`)

## Status 2026-10-29

Fixed in 17.0.1-beta.4 (see CHANGELOG).
