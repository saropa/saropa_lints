# avoid_large_list_copy — False Positive on `.toList()` used as a map/set literal element value

- **Status:** Fixed
- **Created:** 2026-06-03
- **Rule:** `avoid_large_list_copy`
- **Rule class:** `AvoidLargeListCopyRule` (`lib/src/rules/core/performance_rules.dart:1877`)
- **Severity:** INFO
- **Rule version:** v4
- **Reported from:** `D:\src\contacts\lib\models\contact\contact_model.dart` (lines 1618, 1620, 1624)

## Summary

`_isToListRequired` (the structural-requirement exemption) recognizes `.toList()` results that are returned, assigned, passed as an argument, chained, cascaded, or `??`-fallback'd — but **not** a `.toList()` used as the value of a **map or set literal entry**. A lazy `Iterable` cannot be a JSON-encodable map value, so `key: x.map(...).toList()` in a `toJson()` map literal is structurally required, yet it is flagged.

## Attribution Evidence

```
$ grep -rln "'avoid_large_list_copy'" D:/src/saropa_lints/lib/src/rules/
lib/src/rules/core/performance_rules.dart
```
Not a rule definition in saropa_drift_advisor (only referenced in its analysis_options.yaml).

## Reproducer

```dart
Map<String, Object?> toJson(List<MyEnum>? items) => <String, Object?>{
  // OK — value must be a concrete List (jsonEncode rejects a lazy Iterable).
  // Currently FIRES (false positive).
  if (items != null) 'items': items.map((MyEnum e) => e.name).toList(), // LINT (should be OK)
};

// OK today — argument position is already exempt.
void sink(List<String> xs) {}
void good(List<MyEnum> items) => sink(items.map((e) => e.name).toList()); // OK
```

## Expected vs Actual

| Context of `.toList()` | Expected | Actual |
|---|---|---|
| map literal entry value (`key: x.map().toList()`) | OK | **LINT (FP)** |
| set literal element (`{x.map().toList()}`) | OK | **LINT (FP)** |
| argument / return / assignment | OK | OK |

## AST Context

```
SetOrMapLiteral
  elements: [ MapLiteralEntry
                key: ...
                value: MethodInvocation (.toList())   <-- flagged node's parent chain
            ]
```
`_isToListRequired` climbs through `ParenthesizedExpression` / `ConditionalExpression` / `NamedExpression`, then tests for `ReturnStatement`, `ExpressionFunctionBody`, `VariableDeclaration`, `AssignmentExpression`, `MethodInvocation` (as target), `ArgumentList`, `BinaryExpression(??)`. A `MapLiteralEntry` value (or a bare element of a set literal) matches none, so the method returns false.

## Root Cause

`performance_rules.dart` `_isToListRequired` (lines ~1952–2010) lacks a branch for collection-literal elements. A `.toList()` whose parent is a `MapLiteralEntry` (as the `.value`) or an element of a `SetOrMapLiteral` is structurally required — the literal needs a concrete `List` (a lazy `Iterable` is not JSON-encodable and is not a `List`).

## Suggested Fix

Add to `_isToListRequired`, after the existing parent checks:

```dart
// .toList() is a map entry value or a set/list literal element — the literal
// requires a concrete List (a lazy Iterable is not a List and is not
// JSON-encodable).
if (parent is MapLiteralEntry && parent.value == current) return true;
if (parent is SetOrMapLiteral || parent is ListLiteral) return true;
```

## Fixture Gap

The fixture has no map/set-literal-element case. Add a GOOD case: `'k': xs.map((e) => e.name).toList()` inside a returned map literal.

## Environment

- saropa_lints: 13.11.10 (contacts consumes `^13.11.9`)
- Dart SDK `>=3.10.7 <4.0.0`; Flutter `>=3.44.0`
- Native `analysis_server_plugin` (IDE only; `flutter analyze` CLI does not surface it)
- Triggering file: `D:\src\contacts\lib\models\contact\contact_model.dart`

## Finish Report (2026-06-03)

**This work will be reviewed by another AI.**

### Scope

(A) Dart lint rules / analyzer plugin. Touched `lib/src/rules/core/performance_rules.dart` (rule logic) and `example/lib/performance/avoid_large_list_copy_fixture.dart` (fixtures), plus `CHANGELOG.md`.

### Change

`_isToListRequired` in `AvoidLargeListCopyRule` gained two branches after the existing
property-access checks, matching the suggested fix in this report:

```dart
if (parent is MapLiteralEntry && parent.value == current) return true;
if (parent is SetOrMapLiteral || parent is ListLiteral) return true;
```

- `MapLiteralEntry` is guarded on `.value == current` so a `.toList()` used as a map KEY
  is not exempted by accident (it would still flag, correctly).
- `current` is the node after the existing wrapper-climb loop (parentheses / ternary /
  named-expression), so wrapped forms inside a literal are still recognized.
- No new imports needed — `MapLiteralEntry`, `SetOrMapLiteral`, `ListLiteral` come from the
  already-imported `package:analyzer` AST library.

### Verification

- Scan CLI on a standalone reproducer (`d:\tmp\allc_repro.dart`): `avoid_large_list_copy`
  fires only on the bare discarded `largeList.where(...).toList()` (true positive) and is
  silent on the map-entry value, set-literal element, and list-literal element cases.
- `dart test test/rules/core/performance_rules_test.dart` → All 99 tests passed. The two
  references to `avoid_large_list_copy` in that file are name/registration pins, unaffected.
- `dart analyze --fatal-infos lib/src/rules/core/performance_rules.dart` → No issues found.

### Fixtures added

`_good794k` (map-entry value), `_good794l` (set element), `_good794m` (list element) — all
GOOD cases. The existing `_bad794b` (bare discarded `.toList()`) remains the BAD anchor.

### Out of scope / not touched

`avoid_unnecessary_to_list` (a separate rule) still fires on these literal cases — that is a
different rule with a different threat model and was not part of this bug. The unrelated
staged workstream (`build_method_rules.dart` / `prefer_single_setstate`) is left untouched
and uncommitted.
