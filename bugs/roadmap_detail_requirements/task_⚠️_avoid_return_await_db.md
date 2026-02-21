# Task: `avoid_return_await_db`

## Summary
- **Rule Name**: `avoid_return_await_db`
- **Tier**: Recommended
- **Severity**: WARNING
- **Status**: Planned
- **Source**: ROADMAP.md §1.10 Database & Storage Rules — DB/IO Yield

## Problem Statement

When a function directly `return`s the result of a `await dbWrite(...)`, the calling code receives control back immediately after the write — there is no opportunity to insert a `yieldToUI()` before the next operation in the caller. The pattern:

```dart
return await db.insert(table, data);
```

Should instead be:
```dart
final result = await db.insert(table, data);
await yieldToUI();
return result;
```

This ensures the UI thread gets to process pending frame events between the database write and whatever the caller does next. The read-operations corollary (reads from DB) is excluded because reads don't acquire exclusive locks.

## Description (from ROADMAP)

> Returning directly from a database/IO write skips `yieldToUI()`. Save to variable, yield, then return. Read operations are excluded.

## Trigger Conditions

1. `return await dbWriteCall(...)` pattern (return statement with awaited db write)
2. The db write is in the list of write operations (same list as `require_yield_after_db_write`)
3. The function is NOT inside an isolate context

## Implementation Approach

### AST Visitor Pattern

```dart
context.registry.addReturnStatement((node) {
  final expr = node.expression;
  if (expr is! AwaitExpression) return;
  final inner = expr.expression;
  if (inner is! MethodInvocation) return;
  if (!_isDbWriteCall(inner)) return;
  if (_isInsideIsolate(node)) return;
  reporter.atNode(node, code);
});
```

### Detecting the Pattern

The rule catches:
```dart
return await isar.writeTxn(...);
return await box.put(key, value);
return await db.insert(table, data);
```

It does NOT catch (and should not):
```dart
return await db.query(table);   // read operation — excluded
return await box.get(key);       // read — excluded
```

## Code Examples

### Bad (Should trigger)
```dart
// Returns directly from write — no yield opportunity
Future<int> saveItem(Item item) async {
  return await db.insert('items', item.toMap());  // ← trigger
}

Future<void> updateCache(String key, dynamic value) async {
  return await box.put(key, value);  // ← trigger
}
```

### Good (Should NOT trigger)
```dart
// Proper pattern: save, yield, return ✓
Future<int> saveItem(Item item) async {
  final id = await db.insert('items', item.toMap());
  await yieldToUI();
  return id;
}

// Read operation — excluded ✓
Future<Item?> getItem(int id) async {
  return await db.query('items', where: 'id = ?', whereArgs: [id]);
}

// Write in isolate — no yield needed ✓
Future<void> batchMigrate(List<Item> items) async {
  return compute((List<Item> items) async {
    for (final item in items) {
      await db.insert('items', item.toMap());
    }
  }, items);
}
```

## Edge Cases & False Positives

| Scenario | Expected Behavior | Notes |
|---|---|---|
| `return await db.query(...)` | **Suppress** — read operations excluded | Check method name against reads list |
| `return await db.rawQuery(...)` | **Suppress** — read | |
| `return await db.insert(...)` at end of `compute()` body | **Suppress** — isolate context | |
| `return await db.insert(...)` where the return type is `void` | **Trigger** — even void writes should yield | The caller still runs after the write |
| `return await db.batch()..insert(...)..commit()` (cascade) | **Trigger on commit** | Complex cascade — best effort detection |
| Function that is itself called with `.then(...)` | **Trigger** — yielding is still needed | |
| Test files | **Suppress** | |

## Unit Tests

### Violations
1. `return await db.insert(...)` → 1 lint
2. `return await box.put(...)` → 1 lint
3. `return await isar.writeTxn(...)` → 1 lint

### Non-Violations
1. `return await db.query(...)` → no lint (read)
2. `final id = await db.insert(...); await yieldToUI(); return id;` → no lint
3. `return await db.insert(...)` inside `compute()` → no lint
4. Test file → no lint

## Quick Fix

Offer "Save to variable, add yield, then return":
```dart
// Before:
return await db.insert('items', data);

// After:
final _result = await db.insert('items', data);
await yieldToUI();
return _result;
```

## Notes & Issues

1. **Companion rules**: This is part of a trio with `require_yield_after_db_write` and `suggest_yield_after_db_read`. Implement all three together for consistency.
2. **The "save variable + yield" pattern is verbose** — some developers will find this annoying for simple cases. The INFO severity version (`suggest_yield_after_db_read`) allows opting out; the WARNING here suggests the write case is more important.
3. **`yieldToUI()` must be defined** — same caveat as `require_yield_after_db_write`. The fix should offer `await Future.microtask(() {})` as an alternative.
4. **Performance**: `addReturnStatement` fires on every return statement. The inner checks should be cheap (type check + method name check).
