# BUG: `require_cache_expiration` — False Positive: Event-Invalidated Snapshot Cache

**Status: Open**

Created: 2026-10-29
Rule: `require_cache_expiration`
File: `lib/src/rules/resources/memory_management_rules.dart` (line ~1248)
Severity: False positive
Rule version: see message | Since: unknown | Updated: 17.0.1-beta.2

---

## Summary

The rule flags a database-snapshot cache that is invalidated explicitly (assigned `null`, then rebuilt from the table) as "serving stale data indefinitely". The class has an explicit invalidation path, but the rule only recognizes time words and `.clear()`/`.remove(`.

---

## Attribution Evidence

```bash
grep -rn "'require_cache_expiration'" lib/src/rules/
# lib/src/rules/resources/memory_management_rules.dart:1267:    'require_cache_expiration',
```

**Emitter registration:** `lib/src/rules/resources/memory_management_rules.dart:1267`
**Rule class:** `RequireCacheExpirationRule` (memory_management_rules.dart:1248), registered in `lib/saropa_lints.dart` (`RequireCacheExpirationRule.new`, lines 2203-2204)
**Diagnostic `source` / `owner` as seen in Problems panel:** `saropa_lints` / `saropaLintsLsp`

---

## Reproducer

```dart
import 'dart:async';

class Row {
  Row(this.uuid, this.email);
  final String uuid;
  final String email;
}

// Mirrors lib/database/drift_middleware/user_data/connection_cache_drift_io.dart:19-110.
// The cache is a snapshot of one database table: built wholesale, replaced wholesale,
// invalidated by assigning null. Its size is the row count of that table.
abstract final class ConnectionCache { // LINT on this line, but should NOT lint
  static Map<String, Row>? _byUuid;
  static Map<String, Row>? _byEmail;

  static Future<void> preWarm(List<Row> rows) async {
    final Map<String, Row> byUuid = <String, Row>{};
    final Map<String, Row> byEmail = <String, Row>{};
    for (final Row row in rows) {
      byUuid[row.uuid] = row;
      byEmail[row.email.toLowerCase()] = row;
    }
    _byUuid = byUuid;   // whole map replaced, never appended to across warms
    _byEmail = byEmail;
  }

  static void invalidate(List<Row> rows) {
    _byUuid = null;     // invalidation by null assignment
    _byEmail = null;
    unawaited(preWarm(rows));
  }

  static Row? lookup(String uuid) => _byUuid?[uuid];
}
```

**Frequency:** Always, for a Map-holding class whose name contains "cache" and which invalidates by `= null` and rebuilds wholesale.

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | No diagnostic: the Map cannot grow past the table it mirrors |
| **Actual** | `require_cache_expiration` reported at the class declaration, `connection_cache_drift_io.dart` 19:1 (`abstract final class DatabaseConnectionCacheDriftIO`) |

---

## AST Context

```
CompilationUnit
  └─ ClassDeclaration (DatabaseConnectionCacheDriftIO)   <- node reported (reporter.atNode(node))
      ├─ FieldDeclaration (static Map<String, ConnectionDBModel>? _connectionCacheByUUID)
      ├─ FieldDeclaration (static Map<String, ConnectionDBModel>? _connectionCacheByEmail)
      └─ MethodDeclaration (preWarmConnectionCache / clearConnectionCache / connectionStatusFor)
```

---

## Root Cause

`memory_management_rules.dart:1276-1331` (`runWithReporter` of `RequireCacheExpirationRule`) reports when:

- class name contains "cache" (1280).
- `_isContentAddressedCacheKey(classSource)` false (1296).
- `_fileHasExplicitCacheClear(node)` false (1306): only `.clear()` / `.remove(` calls on a Map field count. This class invalidates with `_connectionCacheByUUID = null` in `clearConnectionCache()` (called by every connection write), which is an assignment, not a method call.
- `hasExpiration` false (1309-1315): the class text has none of `expire`, `ttl`, `duration`, `timestamp`, `isvalid`, `isstale`.
- `_hasMapCacheField` true (1319): two `Map<` fields.
- `_cacheSourceIsBounded` false (1329): no size-limit words.

The "serves stale data" premise does not hold for a cache that is invalidated by the code that writes the underlying table; time-based expiry would only add needless re-queries.

---

## Why the code is correct

Staleness is handled by event, not by time. Every connection write calls `clearConnectionCache()`, which nulls both maps and re-warms them from the database, then bumps a `ValueNotifier` so widgets rebuild. A TTL would add reloads without making the data more correct.

---

## Affected project locations (scan of 2026-10-29)

- `lib/database/drift_middleware/user_data/connection_cache_drift_io.dart:19:1` (both `avoid_unbounded_cache_growth` and `require_cache_expiration` fire here)

---

## Suggested Fix

Add a second exemption to `_fileHasExplicitCacheClear` (or a sibling helper used by both cache rules): treat an assignment to a cache Map field of `null`, of a fresh map literal, or of another map (`_cache = <K, V>{}`, `_cache = null`, `_cache = rebuilt`) as explicit invalidation, the same as `.clear()`. A field that is reassigned wholesale cannot accumulate entries across rebuilds. The existing visitor `_CacheClearVisitor` only looks at `visitMethodInvocation` for `clear` and `remove`; add `visitAssignmentExpression` for the tracked field names.

---

## Fixture Gap

1. Map cache invalidated by `= null` in a method that is called on writes — expect NO lint
2. Map cache with neither expiry words, clear/remove, nor null/replace invalidation — expect LINT
3. Map cache with `.clear()` elsewhere in the file — expect NO lint (exists)

---

## Environment

- saropa_lints version: 17.0.1-beta.2
- Dart SDK version: 3.13.7 (stable) (Thu Oct 22 14:28:57 2026 -0700) on "macos_arm64"
- custom_lint version: not used (analyzer plugin via VS Code extension)
- Triggering project/file: Saropa contacts app, `lib/database/drift_middleware/user_data/connection_cache_drift_io.dart:19`
