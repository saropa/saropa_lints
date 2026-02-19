# Task: `require_yield_after_db_write`

## Summary
- **Rule Name**: `require_yield_after_db_write`
- **Tier**: Recommended
- **Severity**: WARNING
- **Status**: Planned
- **Source**: ROADMAP.md §1.10 Database & Storage Rules — DB/IO Yield

## Problem Statement

Database write operations (Isar, Hive, sqflite, Drift) acquire exclusive write locks that can block the database reader. When performed on the main isolate, they may prevent the UI from processing pending frames. A `yieldToUI()` call (or equivalent: `await Future.microtask(() {})` or `SchedulerBinding.instance.scheduleFrame()`) after a write ensures the event loop processes pending UI events before the next operation.

This is particularly important in scenarios where:
- Multiple sequential writes occur (migrations, batch updates)
- A write is followed by a UI update that reads the new data
- The write is inside a `setState` callback

## Description (from ROADMAP)

> Database or I/O write without a following `yieldToUI()` call. Write operations acquire exclusive locks that block the UI thread.

## Trigger Conditions

1. Calls to database write methods (see list below) that are NOT followed by `await yieldToUI()`, `await Future.microtask(() {})`, or `await SchedulerBinding.instance.ensureVisualUpdate()`
2. Only in the main isolate context (not inside `compute()` or `Isolate.spawn()`)

### Database Write Methods to Detect
- **Isar**: `isar.writeTxn(...)`, `collection.put(...)`, `collection.putAll(...)`, `collection.delete(...)`, `collection.deleteAll(...)`, `collection.clear()`
- **Hive**: `box.put(...)`, `box.putAll(...)`, `box.delete(...)`, `box.deleteAll(...)`, `box.clear()`
- **sqflite**: `db.insert(...)`, `db.update(...)`, `db.delete(...)`, `db.execute(...)`, `db.rawInsert(...)`, `db.rawUpdate(...)`, `db.rawDelete(...)`, `db.batch()...commit()`
- **Drift**: `into(...).insert(...)`, `update(...).write(...)`, `delete(...).go()`

## Implementation Approach

### AST Visitor Pattern

```dart
context.registry.addMethodInvocation((node) {
  if (!_isDbWriteCall(node)) return;
  if (_isFollowedByYield(node)) return;
  if (_isInsideIsolate(node)) return;
  reporter.atNode(node, code);
});
```

`_isDbWriteCall`: check method name and receiver type against the write methods list.
`_isFollowedByYield`: check if the next statement (or part of the same expression chain) is `await yieldToUI()`.
`_isInsideIsolate`: walk parents for `Isolate.spawn`, `compute`, `Flutter.isolate`.

### Defining `yieldToUI()`
The project may define this as a utility function. Detect:
- Method named `yieldToUI` or `yieldFrame` or `yield_to_ui`
- `await Future.microtask(() {})`
- `await Future<void>.delayed(Duration.zero)`
- `await SchedulerBinding.instance.endOfFrame`

## Code Examples

### Bad (Should trigger)
```dart
// Write without yield
Future<void> saveItem(Item item) async {
  await isar.writeTxn(() async {
    await isar.items.put(item);  // ← trigger: no yieldToUI after
  });
  setState(() => _items.add(item));  // UI update right after
}

// Hive write
Future<void> cacheData(String key, dynamic value) async {
  await box.put(key, value);  // ← trigger
  updateUI();
}
```

### Good (Should NOT trigger)
```dart
// With yield ✓
Future<void> saveItem(Item item) async {
  await isar.writeTxn(() async {
    await isar.items.put(item);
  });
  await yieldToUI();  // ← yields to UI thread
  setState(() => _items.add(item));
}

// In isolate — yield not needed ✓
Future<void> migrationTask() async {
  await compute((db) async {
    await db.insert('items', data);  // in isolate, no UI thread
  }, database);
}
```

## Edge Cases & False Positives

| Scenario | Expected Behaviour | Notes |
|---|---|---|
| Write at end of function (no subsequent UI update) | **Still trigger** — the NEXT operation (unknown) may be UI | Conservative approach |
| Write inside `compute()` | **Suppress** — separate isolate, no UI thread | |
| Write in `onPressed` (one-shot, user-initiated) | **Trigger** — still good practice | Low frequency doesn't eliminate the need |
| `batch` operation (multiple writes) | **Trigger on the batch.commit()** | Batch commit is the actual write |
| Write followed by `return` | **Suppress** — no subsequent code to block | Return means no further UI operations |
| `yieldToUI` defined in a different way | **Detect by name** — `yieldToUI`, `yield_to_ui`, `yieldFrame` | |
| Test files | **Suppress** | |
| `Future.microtask` already present | **Suppress** | Count as yield |

## Unit Tests

### Violations
1. `isar.writeTxn(...)` not followed by `yieldToUI()` → 1 lint
2. `box.put(key, value)` not followed by yield → 1 lint
3. `db.insert(table, data)` not followed by yield → 1 lint

### Non-Violations
1. Write followed by `await yieldToUI()` → no lint
2. Write followed by `await Future.microtask(() {})` → no lint
3. Write inside `compute(...)` → no lint
4. Write as last statement in async function → no lint
5. Test file → no lint

## Quick Fix

Offer "Add `await yieldToUI()` after write":
```dart
// After:
await box.put(key, value);
await yieldToUI();
```

## Notes & Issues

1. **`yieldToUI()` must be defined in the project** — this rule assumes the project has a `yieldToUI()` utility function. If not, the quick fix should offer `await Future.microtask(() {})` instead.
2. **Companion rules**: `suggest_yield_after_db_read` and `avoid_return_await_db` in the same section should be implemented together for consistency.
3. **Isar v4 API changes** — Isar v4 changed the transaction API. Both v3 and v4 patterns should be detected.
4. **What exactly is `yieldToUI`?** — This is a project-specific utility. The rule's docs should clarify what qualifies as a yield. The detection should be broad (any of: named function, `Future.microtask`, `Future.delayed(Duration.zero)`, `SchedulerBinding.ensureVisualUpdate()`).
5. **Performance impact awareness**: If a write is inside a background operation (Flutter's `Isolate`), `yieldToUI()` is neither needed nor meaningful. The isolate check is important.
