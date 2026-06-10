# BUG: `avoid_collection_equality_checks` — Fires on a model whose type name starts with "Map"/"List"/"Set"

**Status: Open**

Created: 2026-06-10
Rule: `avoid_collection_equality_checks`
File: `lib/src/rules/data/collection_rules.dart` (line ~106)
Severity: False positive
Rule version: v5

---

## Summary

`_isCollectionType` decides "this is a collection" by `typeName.startsWith('Map' | 'List' | 'Set' | 'Iterable' | 'Queue' | 'LinkedList')`. Any user model whose class name begins with one of those words — e.g. `MapClusterModel`, `ListTileData`, `SetupConfig` — is misclassified as a collection, so a perfectly valid `==`/`!=` on two model references is flagged.

---

## Attribution Evidence

```bash
# Positive — rule IS defined here
grep -rn "'avoid_collection_equality_checks'" lib/src/rules/
# lib/src/rules/data/collection_rules.dart:64:    'avoid_collection_equality_checks',

# Negative — NOT in sibling repo
grep -rn "'avoid_collection_equality_checks'" ../saropa_drift_advisor/lib/
# 0 matches
```

**Emitter registration:** `lib/src/rules/data/collection_rules.dart:64`
**Rule class:** `AvoidCollectionEqualityChecksRule`
**Diagnostic `source` / `owner`:** `dart` / `_generated_diagnostic_collection_name_#5`

---

## Reproducer

```dart
class MapClusterModel {
  // ...
}

class Widget {
  MapClusterModel? cluster;

  void didUpdateWidget(Widget oldWidget) {
    // LINT (false positive): MapClusterModel is NOT a collection. This is a
    // reference comparison of two model objects, which is exactly what the
    // code intends — re-run work when the cluster reference changes.
    if (oldWidget.cluster != cluster) {
      doWork();
    }
  }
}
```

Real site: `D:\src\contacts\lib\components\map\map_info_widget.dart:48`
`if (oldWidget.cluster != widget.cluster)` where `cluster` is `MapClusterModel?`.

**Frequency:** Always, for any type whose display name starts with a collection keyword.

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | No diagnostic — `MapClusterModel` is a model class, not a `Map`. |
| **Actual** | `[avoid_collection_equality_checks] Comparing collections with == ...` reported at line 48. |

---

## AST Context

```
MethodDeclaration (didUpdateWidget)
  └─ Block
      └─ IfStatement
          └─ BinaryExpression (!=)          ← node reported here
              ├─ PrefixedIdentifier (oldWidget.cluster)  staticType = MapClusterModel?
              └─ PrefixedIdentifier (widget.cluster)     staticType = MapClusterModel?
```

---

## Root Cause

`collection_rules.dart:106-112`:

```dart
bool _isCollectionType(DartType? type) {
  if (type == null) return false;
  final String typeName = type.getDisplayString();
  return _collectionTypes.any(
    (String collection) => typeName.startsWith(collection),
  );
}
```

`_collectionTypes` includes `'Map'`, `'List'`, `'Set'`, `'Iterable'`, `'Queue'`, `'LinkedList'`. The membership test is `typeName.startsWith(collection)`, a **prefix string match on the display name**. `MapClusterModel` starts with `Map`, so the check returns true even though the static element is a plain class, not `dart:core` `Map`. Both operands resolve to `MapClusterModel?`, so both sides pass and the binary expression is reported.

The mechanism should be a resolved-type check, not a name prefix: test the element against the actual `dart:core` / `dart:collection` collection types (e.g. `type.isDartCoreList`, `type.isDartCoreMap`, `type.isDartCoreSet`, `type.isDartCoreIterable`, or `DartType.element` identity against the known collection classes), not `getDisplayString().startsWith(...)`.

---

## Suggested Fix

Replace the prefix-string match in `_isCollectionType` with a resolved-type check:

- Prefer `type.isDartCoreList` / `isDartCoreSet` / `isDartCoreMap` / `isDartCoreIterable` where available.
- For `Queue` / `LinkedList` (no `isDartCoreX` helper), compare `type.element` to the element resolved from `dart:collection`, or at minimum require an **exact** display-name match (`typeName == 'Queue'` / generic-aware `typeName.startsWith('Queue<')`) rather than a bare prefix.

A cheap interim guard that removes the bulk of false positives: require the prefix match to be followed by `<` or end-of-string (`Map<...>` / `List<...>` / `Set`), so `MapClusterModel` (followed by `C`) no longer matches.

---

## Fixture Gap

The fixture at `example*/lib/data/avoid_collection_equality_checks_fixture.dart` should include:

1. `MapClusterModel a; MapClusterModel b; if (a != b) {}` — expect **NO** lint (model type name starts with "Map").
2. `ListItemModel a == b` — expect **NO** lint (starts with "List").
3. `SetupOptions a == b` — expect **NO** lint (starts with "Set").
4. `List<int> a == b` — expect LINT (genuine collection).
5. `Map<String, int> a == b` — expect LINT (genuine collection).

---

## Environment

- saropa_lints version: ^13.12.2
- Dart SDK version: >=3.10.7 <4.0.0
- custom_lint version: native analyzer plugin (analysis_server_plugin), not custom_lint
- Triggering project/file: `D:\src\contacts\lib\components\map\map_info_widget.dart:48`
