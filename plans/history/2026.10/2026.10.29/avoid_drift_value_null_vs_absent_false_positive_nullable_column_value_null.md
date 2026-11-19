# BUG: `avoid_drift_value_null_vs_absent` — `Value<String?>(null)` on a nullable column is flagged

**Status: Open**

Created: 2026-10-29
Rule: `avoid_drift_value_null_vs_absent`
File: `lib/src/rules/packages/drift_rules.dart` (line ~2799)
Severity: False positive
Rule version: v1 | Since: unknown | Updated: 17.0.1-beta.2

---

## Summary

The rule flags every `Value(null)` without checking whether the target column is nullable. Writing `Value<String?>(null)` to a nullable column is the correct way to set it to SQL NULL (`Value.absent()` would leave it unchanged, which is a different operation). The rule even documents "ensure the column is nullable" but never checks it.

---

## Attribution Evidence

```bash
grep -rn "'avoid_drift_value_null_vs_absent'" lib/src/rules/
lib/src/rules/packages/drift_rules.dart:2799:    'avoid_drift_value_null_vs_absent',
```

Negative grep not applicable: no sibling analyzer repo is checked out beside this one that defines this code; the rule is only defined here.

**Emitter registration:** `lib/src/rules/packages/drift_rules.dart:2799`
**Rule class:** `AvoidDriftValueNullVsAbsentRule` — registered in `1639:  AvoidDriftValueNullVsAbsentRule.new,`
**Diagnostic `source` / `owner` as seen in Problems panel:** `saropa_lints` / `saropaLintsLsp`

---

## Reproducer

Standalone. Copied from the real project source (path and lines below) with project-specific types replaced by the real package types where one exists.

Project source: `lib/database/drift_middleware/user_data/contact_drift_io.dart` lines 1120-1124 (`_restoreSecondariesOfDeletedPrimaries`); column declared at `lib/database/drift/tables/user_data/contact_table.dart:135` as `TextColumn get primaryContactUUID => text().named('primary_contact_u_u_i_d').nullable()();`.

```dart
import 'package:drift/drift.dart';

// Mirrors the project's ContactsCompanion: a nullable text column.
class ContactsCompanion {
  const ContactsCompanion({this.primaryContactUUID = const Value<String?>.absent()});
  final Value<String?> primaryContactUUID;
}

// Unlink every secondary: set the NULLABLE column to NULL on purpose.
const ContactsCompanion unlink =
    ContactsCompanion(primaryContactUUID: Value<String?>(null)); // LINT -- but should NOT lint
```

**Frequency:** Always for this pattern.

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | No diagnostic (code is correct) |
| **Actual** | `[avoid_drift_value_null_vs_absent] Value(null) used in a Drift Companion. This sets the column to NULL, which crashes on non-nullable columns. If you meant "leave this column unchanged", use Value.absent() instead. Review whether null or absent is the correct intent for this column. {v1}` reported at 1123:51-1123:71 of contact_drift_io.dart (the whole `Value<String?>(null)` expression) |

---

## AST Context

```
MethodDeclaration (_restoreSecondariesOfDeletedPrimaries)
  └─ BlockFunctionBody > Block
      └─ ExpressionStatement > AwaitExpression
          └─ MethodInvocation (.write)
              └─ ArgumentList
                  └─ InstanceCreationExpression (const ContactsCompanion)
                      └─ ArgumentList > NamedExpression (primaryContactUUID)
                          └─ InstanceCreationExpression (Value<String?>(null))  <- reported
```

---

## Root Cause

`drift_rules.dart:2812-2829`: `context.addInstanceCreationExpression` -> `typeName == 'Value'` (2815) -> `fileImportsPackage(node, PackageImports.drift)` (2816) -> `args.length == 1` (2819) -> `args.first is NullLiteral` (2825) -> `reporter.atNode(node)`. The explicit type argument `String?` (the `Value<String?>` generic, `node.constructorName.type.typeArguments`) and the static type `Value<String?>` are never inspected. A nullable type argument already proves the column accepts NULL.

### Why the code is correct

`Value<String?>(null)` can only be passed to a `Value<String?>` parameter, i.e. a nullable column. Setting it NULL is the intent: the secondaries must be unlinked from a primary that is being deleted. `Value.absent()` would leave the stale link in place.

---

## Affected project locations (project: contacts, line numbers before the session's other edits)

- `lib/database/drift_middleware/user_data/contact_drift_io.dart:1123`

---

## Suggested Fix

Return early when the `Value` type argument is nullable: `node.staticType` is `Value<T>` with `T.nullabilitySuffix == NullabilitySuffix.question` (or the explicit `typeArguments` is a nullable `NamedType`). Keep reporting `Value(null)` / `Value<String>(null)` (the latter does not compile) where `T` is non-nullable or inferred as `Null`.

---

## Fixture Gap

The fixture for `avoid_drift_value_null_vs_absent` should include:

1. `const Value<String?>(null)` -- expect NO lint
2. `const Value(null)` passed to a `Value<String?>` parameter (inferred `Value<String?>`) -- expect NO lint
3. `Value<int>(null)` is a compile error; `Value(null)` with inferred `Value<Null>` into a non-nullable context -- expect LINT

---

## Changes Made

None yet.

---

## Tests Added

None yet.

---

## Commits

None yet.

---

## Environment

- saropa_lints version: 17.0.1-beta.2
- Dart SDK version: 3.13.7 (stable) (Thu Oct 22 14:28:57 2026 -0700) on "macos_arm64"
- custom_lint version: not used (analyzer plugin via saropaLintsLsp)
- Triggering project/file: /Users/craighathaway/Documents/src/contacts — lib/database/drift_middleware/user_data/contact_drift_io.dart:1123

---

## Additional affected location (appended 2026-10-29)

- `/Users/craighathaway/Documents/src/contacts/lib/database/drift_middleware/user_data/checklist_instance_drift_io.dart:170` (diagnostic 170:30-170:58): `completedAt: const Value<DateTime?>(null)` inside a `DoUpdate` companion. The type argument `DateTime?` is written explicitly, so the nullable column is provable from the node itself (`node.constructorName.type.typeArguments`), without resolving the column.
- Fixture: `const Value<DateTime?>(null)` — expect NO lint.
