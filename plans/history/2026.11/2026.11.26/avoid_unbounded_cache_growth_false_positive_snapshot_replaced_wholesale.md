# BUG: `avoid_unbounded_cache_growth` — fires on a snapshot map that is only ever replaced whole

**Status: Fixed**

Created: 2026-11-26
Rule: `avoid_unbounded_cache_growth`
File: `lib/src/rules/resources/memory_management_rules.dart` (line ~1448)
Severity: False positive
Rule version: v4 | Since: v4.1.8 | Updated: v13.12.6

---

## Summary

A cache whose map field is rebuilt from the authoritative list and assigned in one step cannot accumulate entries, but is reported as unbounded.

---

## Attribution Evidence

```bash
grep -rn "'avoid_unbounded_cache_growth'" lib/src/rules/
# lib/src/rules/resources/memory_management_rules.dart:1437:    'avoid_unbounded_cache_growth',
```

**Emitter registration:** `lib/src/rules/resources/memory_management_rules.dart:1437`
**Rule class:** `AvoidUnboundedCacheGrowthRule` — registered in `lib/saropa_lints.dart:2205`
**Diagnostic `source` / `owner` as seen in Problems panel:** `saropa_lints`

---

## Reproducer

Derived from reading the rule source. Not executed.

```dart
class Row {
  Row(this.id);
  final String id;
}

class LinkCache { // LINT — but should NOT lint
  static Map<String, Row> _byId = <String, Row>{};

  static void replace(List<Row> serverRows) {
    final Map<String, Row> next = <String, Row>{};
    for (final Row r in serverRows) {
      next[r.id] = r; // writes a local, not the field
    }
    _byId = next; // old entries are dropped
  }

  static Row? forId(String id) => _byId[id];
}
```

**Frequency:** Always

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | No diagnostic |
| **Actual** | `[avoid_unbounded_cache_growth]` reported on the line marked LINT |

---

## AST Context

```
ClassDeclaration (LinkCache)  ← reported
  ├─ FieldDeclaration (Map<String, Row> _byId)
  └─ MethodDeclaration (replace)
```

---

## Root Cause

`_hasMutationPatterns` (line ~1587) is a text scan of the class for `] =`. It matches the index assignment into the local `next`. Nothing checks whether the Map *field* is ever index-assigned or `addAll`ed, as opposed to only reassigned.

---

## Suggested Fix

Walk the AST: treat the field as growable only when an index assignment, `addAll`, `putIfAbsent` or `update` targets the field itself. A field written only by plain reassignment to a freshly built map is exempt.

---

## Fixture Gap

1. Field replaced by a freshly built local map — expect NO lint
2. `_byId[key] = value` on the field — expect LINT

---

## Environment

- saropa_lints version: 17.9.1 (rule source read at this version)
- Dart SDK version: not recorded
- Triggering project/file: a private Flutter app

---

## Finish Report (2026-11-26)

**Fix** (`lib/src/rules/resources/memory_management_rules.dart`, rule version v5): a class is exempt when every collection field is private, is only read by key, size or null check, and is otherwise only set to `null` or replaced by a freshly built collection. A rebuild that reads any stored collection (directly or through functions, methods and getters declared in the same file), any per-key write, alias, argument or return, collection-valued maps, `part` files and unresolved elements keep the diagnostic.

**Review fix:** `MapView` / `UnmodifiableMapView` construction counted as a fresh collection although it aliases the argument; view constructors are now rejected, with a regression case.

**Limits:**
- The exemption needs resolved elements; without them the report stays.
- A snapshot that exposes `values` or `entries` is still reported.
- A rebuild that draws from accumulating state through a helper declared in another file, or from a collection its caller accumulated and passed in, is not detected, nor is a local that a closure keeps writing after it was assigned to the field.

Tests: `dart test test/rules/resources/cache_snapshot_wholesale_replace_fp_test.dart test/rules/resources/cache_snapshot_replace_fp_test.dart test/rules/resources/memory_management_rules_test.dart` - passed.
