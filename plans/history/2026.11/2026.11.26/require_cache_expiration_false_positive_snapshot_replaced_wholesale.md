# BUG: `require_cache_expiration` — demands a TTL on a server snapshot that is replaced whole

**Status: Fixed**

Created: 2026-11-26
Rule: `require_cache_expiration`
File: `lib/src/rules/resources/memory_management_rules.dart` (line ~1294)
Severity: False positive
Rule version: v3 | Since: v4.1.8 | Updated: v13.12.6

---

## Summary

A map that mirrors a server list and is replaced on every sync is reported for lacking expiration. A TTL would drop entries that are still valid.

---

## Attribution Evidence

```bash
grep -rn "'require_cache_expiration'" lib/src/rules/
# lib/src/rules/resources/memory_management_rules.dart:1282:    'require_cache_expiration',
```

**Emitter registration:** `lib/src/rules/resources/memory_management_rules.dart:1282`
**Rule class:** `RequireCacheExpirationRule` — registered in `lib/saropa_lints.dart:2204`
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

  /// Called after each sync with the complete server list.
  static void replace(List<Row> serverRows) {
    _byId = <String, Row>{for (final Row r in serverRows) r.id: r};
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
| **Actual** | `[require_cache_expiration]` reported on the line marked LINT |

---

## AST Context

```
ClassDeclaration (LinkCache)  ← reported
  ├─ FieldDeclaration (Map<String, Row> _byId)
  └─ MethodDeclaration (replace)
```

---

## Root Cause

Lines ~1323-1346 report any cache-named class with a Map field unless the source contains an expiry word or a bound. Whole-map replacement, which is the invalidation here, is not recognized. The message also asserts memory growth, which a replaced snapshot does not have.

---

## Suggested Fix

Exempt a class whose Map fields are written only by plain reassignment from a method that rebuilds them from its argument (no per-key writes on the field).

---

## Fixture Gap

1. Snapshot replaced whole — expect NO lint
2. Per-key lazy fill with no TTL — expect LINT

---

## Environment

- saropa_lints version: 17.9.1 (rule source read at this version)
- Dart SDK version: not recorded
- Triggering project/file: a private Flutter app

---

## Finish Report (2026-11-26)

**Fix** (`lib/src/rules/resources/memory_management_rules.dart`, rule version v4): a class is exempt when every collection field is private, is only read by key, size or null check, and is otherwise only set to `null` or replaced by a freshly built collection. A rebuild that reads any stored collection (directly or through functions, methods and getters declared in the same file), any per-key write, alias, argument or return, collection-valued maps, `part` files and unresolved elements keep the diagnostic.

**Review fix:** `MapView` / `UnmodifiableMapView` construction counted as a fresh collection although it aliases the argument; view constructors are now rejected, with a regression case.

**Limits:**
- The exemption needs resolved elements; without them the report stays.
- A snapshot that exposes `values` or `entries` is still reported.
- A rebuild that draws from accumulating state through a helper declared in another file, or from a collection its caller accumulated and passed in, is not detected, nor is a local that a closure keeps writing after it was assigned to the field.

The example fixture's `.clear()` case uses its own field name, so it no longer exempts the BAD cases; a unit test checks the fixture's markers.

Tests: `dart test test/rules/resources/cache_snapshot_wholesale_replace_fp_test.dart test/rules/resources/cache_snapshot_replace_fp_test.dart test/rules/resources/memory_management_rules_test.dart` - passed.
