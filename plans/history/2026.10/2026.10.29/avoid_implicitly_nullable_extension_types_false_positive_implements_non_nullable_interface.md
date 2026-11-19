# BUG: `avoid_implicitly_nullable_extension_types` — False Positive: Extension Type That Implements a Non-Nullable Interface (`List<T>`)

**Status: Open**

Created: 2026-10-29
Rule: `avoid_implicitly_nullable_extension_types`
File: `lib/src/rules/data/type_rules.dart` (lines ~380-402, `runWithReporter`)
Severity: False positive
Rule version: v4 | Since: v0.1.4 | Updated: v4.13.0

---

## Summary

The rule reports every extension type whose `implements` clause does not literally name `Object`. An extension type that implements `List<ContactModel>` (or any other non-nullable interface) is already a subtype of `Object`, so the hazard the rule describes cannot occur. The check compares the interface name to the string `'Object'` and ignores every other non-nullable interface.

---

## Attribution Evidence

```bash
grep -rn "'avoid_implicitly_nullable_extension_types'" lib/src/rules/
# lib/src/rules/data/type_rules.dart:372:    'avoid_implicitly_nullable_extension_types',
```

**Emitter registration:** `lib/src/rules/data/type_rules.dart:372`
**Rule class:** `AvoidImplicitlyNullableExtensionTypesRule` (type_rules.dart:353), registered in `lib/saropa_lints.dart:482` (`AvoidImplicitlyNullableExtensionTypesRule.new`)
**Diagnostic `source` / `owner` as seen in Problems panel:** `saropa_lints` / `saropaLintsLsp`

---

## Reproducer

Standalone, compiles with `dart run` (Dart 3.13.7). Mirrors `lib/database/drift_middleware/user_data/contact_important_io.dart:147`, where `ContactModel` is the app's contact class.

```dart
class ContactModel {
  ContactModel(this.name);
  final String name;
}

/// A pool in ranked order. Same shape as the real `_RankedPool`.
// LINT at `_RankedPool` (147:16 in the real file) - but should NOT lint: it implements List<ContactModel>.
extension type _RankedPool(List<ContactModel> _list) implements List<ContactModel> {}

void main() {
  final _RankedPool pool = _RankedPool(<ContactModel>[ContactModel('a')]);

  // Compiles only because _RankedPool is a subtype of Object (List<ContactModel> <: Object).
  // An extension type that is NOT a subtype of Object would be rejected here.
  final Object asObject = pool;
  print(asObject);

  // The nullable form must be written out explicitly; the type itself never silently accepts null:
  // final _RankedPool bad = null; // compile error: Null is not a subtype of _RankedPool
  final _RankedPool? maybe = null;
  print(maybe);
}
```

**Frequency:** Always, for every extension type whose `implements` clause names something other than the identifier `Object` (for example `implements List<T>`, `implements String`, `implements num`).

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | No diagnostic: the extension type implements `List<ContactModel>`, so it is a subtype of `Object` and non-nullable |
| **Actual** | `[avoid_implicitly_nullable_extension_types] Extension type is implicitly nullable. Extension types that don't implement Object can be implicitly nullable, which may lead to unexpected behavior. {v4}` at `contact_important_io.dart` 147:16 (reported on the primary constructor type name token) |

---

## AST Context

```
CompilationUnit
  └─ ExtensionTypeDeclaration (_RankedPool)
      ├─ PrimaryConstructor (typeName token `_RankedPool`)   <- reporter.atToken(primaryCtor.typeName, code)
      └─ ImplementsClause
          └─ NamedType (List<ContactModel>)                   <- name.lexeme == 'List', not 'Object'
```

---

## Root Cause

`type_rules.dart:388-396` loops over `implementsClause.interfaces` and sets `implementsObject = true` only when `type.name.lexeme == 'Object'`. For `implements List<ContactModel>` the lexeme is `List`, so `implementsObject` stays false and line 398-401 (`if (!implementsObject) { ... reporter.atToken(primaryCtor.typeName, code); }`) fires. The check is purely textual. It never asks whether any implemented interface is itself a subtype of `Object` (every non-nullable class type is), which is the property the rule cares about.

---

## Why the code is correct

`_RankedPool` implements `List<ContactModel>`. `List<ContactModel>` is a non-nullable class type and a subtype of `Object`, so `_RankedPool` is a subtype of `Object` too and cannot hold `null`. The reproducer assigns it to `Object` to show this. Adding `implements Object` as a second interface adds no information.

---

## Affected project locations (saropa contacts app, scan of 2026-10-29)

- `lib/database/drift_middleware/user_data/contact_important_io.dart:147:16` (`_RankedPool`, implements `List<ContactModel>`)

---

## Suggested Fix

In `runWithReporter`, treat the extension type as safe when any interface in `implementsClause.interfaces` resolves to a non-nullable type (for example `type.type != null && type.type!.nullabilitySuffix == NullabilitySuffix.none`, or `typeSystem.isSubtypeOf(type.type, objectType)`), not only when the name is `Object`. Keep reporting when there is no `implements` clause, or when all implemented interfaces are themselves extension types that do not implement `Object`.

---

## Fixture Gap

The fixture for `avoid_implicitly_nullable_extension_types` should include:

1. `extension type UserId(int id) {}` - expect LINT (existing behavior)
2. `extension type UserId(int id) implements Object {}` - expect NO lint (exists)
3. `extension type Pool(List<int> _l) implements List<int> {}` - expect NO lint
4. `extension type Name(String s) implements String {}` - expect NO lint
5. `extension type Wrap(Pool p) implements Pool {}` where `Pool` is case 3 - expect NO lint (transitive)

---

## Environment

- saropa_lints version: 17.0.1-beta.2
- Dart SDK version: 3.13.7 (stable) (Thu Oct 22 14:28:57 2026 -0700) on "macos_arm64"
- custom_lint version: not used (analyzer plugin via VS Code extension)
- Triggering project/file: Saropa contacts app, `lib/database/drift_middleware/user_data/contact_important_io.dart:147`
