# BUG: `avoid_unsafe_collection_methods` — False Positive: `.first` Guarded by `isNotEmpty &&` in the Same Condition

**Status: Open**

Created: 2026-10-29
Rule: `avoid_unsafe_collection_methods`
File: `lib/src/rules/data/collection_rules.dart` (lines ~482-514 `PrefixedIdentifier` handler, ~642-733 guard helpers)
Severity: False positive
Rule version: v10 | Since: unknown | Updated: 17.0.1-beta.2

---

## Summary

`list.isNotEmpty && f(list.first)` is a complete guard: `&&` evaluates the right operand only when the left is true. The rule only recognizes a guard when the access sits in the `then` branch of an `if`, ternary or collection-if. It does not treat the right operand of `&&` (or the right operand of `||` after `isEmpty ||`) as guarded.

---

## Attribution Evidence

```bash
grep -rn "'avoid_unsafe_collection_methods'" lib/src/rules/
# lib/src/rules/data/collection_rules.dart:430:    'avoid_unsafe_collection_methods',
```

**Emitter registration:** `lib/src/rules/data/collection_rules.dart:430`
**Rule class:** `AvoidUnsafeCollectionMethodsRule` (collection_rules.dart:410), registered in `lib/saropa_lints.dart:373` (`AvoidUnsafeCollectionMethodsRule.new`)
**Diagnostic `source` / `owner` as seen in Problems panel:** `saropa_lints` / `saropaLintsLsp`

---

## Reproducer

Standalone, compiles with `dart run`. Copied from `lib/database/file_backup/import/vcard_import_name_resolver.dart:34-39` (`ContactNameModel` reduced to what the snippet needs).

```dart
class ContactNameModel {
  ContactNameModel({this.nicknames});
  List<String>? nicknames;
}

bool _sameText(String a, String b) => a.trim().toLowerCase() == b.trim().toLowerCase();

ContactNameModel? resolveFromFn(String fn, List<String> nicknames) {
  // LINT at `nicknames.first` (36:43 in the real file) - but should NOT lint:
  // the right operand of && only runs when nicknames.isNotEmpty is true.
  if (nicknames.isNotEmpty && _sameText(nicknames.first, fn)) {
    return ContactNameModel(nicknames: nicknames);
  }
  return null;
}

void main() {
  print(resolveFromFn('Bob', <String>['bob'])?.nicknames);
  print(resolveFromFn('Bob', <String>[])?.nicknames); // no StateError: the guard short-circuits
}
```

**Frequency:** Always, when the `.first`/`.last`/`.single` access is inside the same condition expression as the guard (right operand of `&&`, or right operand of `isEmpty ||`) rather than in the `then` branch.

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | No diagnostic: the access is only evaluated when the collection is non-empty |
| **Actual** | `[avoid_unsafe_collection_methods] Calling .first, .last, or .single on an empty collection throws a StateError at runtime, crashing the app. ... {v10}` at `vcard_import_name_resolver.dart` 36:43 |

---

## AST Context

```
MethodDeclaration (_resolveFromFn)
  └─ BlockFunctionBody > Block
      └─ IfStatement
          ├─ expression: BinaryExpression (&&)
          │   ├─ leftOperand: PrefixedIdentifier (nicknames.isNotEmpty)      <- the guard
          │   └─ rightOperand: MethodInvocation (_sameText)
          │       └─ ArgumentList
          │           └─ PrefixedIdentifier (nicknames.first)               <- node reported (prefix `nicknames`, identifier `first`)
          └─ thenStatement: Block
```

---

## Root Cause

The `PrefixedIdentifier` handler (collection_rules.dart:~482-514) calls `_isGuardedAccess(node, collectionName)` (line ~642). That calls `_isGuardedByTernary` (~662), `_isGuardedByIfStatement` (~685) and `_isGuardedByCollectionIf` (~710). Each walks up to the enclosing `ConditionalExpression` / `IfStatement` / `IfElement` and then requires `_isDescendantOf(node, current.thenStatement)` (or `thenExpression` / `thenElement`). The flagged node is inside `current.expression` (the condition), not inside `thenStatement`, so the test fails. `_isValidGuardCondition` (~735) does split `a && b`, but only to decide whether the condition guards a node in the then-branch. No helper looks at a `BinaryExpression` with `&&` / `||` as an ancestor of the access. `_isCollectionGuardedByEarlyReturn` and `_isGuardedByEnclosingLoop` do not apply either. The result is a diagnostic on code that cannot throw.

---

## Why the code is correct

Dart evaluates `a && b` left to right and skips `b` when `a` is false. With `a = nicknames.isNotEmpty`, `nicknames.first` is only reached when the list has at least one element. The reproducer's second call (`<String>[]`) returns null and never throws.

---

## Affected project locations (saropa contacts app, scan of 2026-10-29)

- `lib/database/file_backup/import/vcard_import_name_resolver.dart:36:43` (`nicknames.first` after `nicknames.isNotEmpty &&`)

---

## Suggested Fix

Add `_isGuardedByShortCircuit(node, collectionName)` to `_isGuardedAccess`. Walk up from the access. For each ancestor `BinaryExpression` with operator `&&` where the access is a descendant of `rightOperand`, return true if `_isValidGuardCondition(leftOperand, collectionName)`. For operator `||`, return true if the access is a descendant of `rightOperand` and `_isInvertedGuardCondition(leftOperand, collectionName)` (for example `list.isEmpty || list.first == x`). Stop the walk at a `FunctionBody` boundary.

---

## Fixture Gap

The fixture for `avoid_unsafe_collection_methods` should include:

1. `if (list.isNotEmpty && f(list.first)) {}` - expect NO lint
2. `final ok = list.isNotEmpty && list.first == 'x';` - expect NO lint
3. `if (list.isEmpty || list.first == 'x') {}` - expect NO lint
4. `if (other.isNotEmpty && f(list.first)) {}` (guard on a different collection) - expect LINT
5. `if (f(list.first) && list.isNotEmpty) {}` (guard on the wrong side) - expect LINT

---

## Environment

- saropa_lints version: 17.0.1-beta.2
- Dart SDK version: 3.13.7 (stable) (Thu Oct 22 14:28:57 2026 -0700) on "macos_arm64"
- custom_lint version: not used (analyzer plugin via VS Code extension)
- Triggering project/file: Saropa contacts app, `lib/database/file_backup/import/vcard_import_name_resolver.dart:36`
