# Bug: `require_yield_between_db_awaits` does not distinguish reads from writes

**Rule:** `require_yield_between_db_awaits`
**File:** `lib/src/rules/db_yield_rules.dart`
**Severity:** Design issue / false-positive generator
**Status:** OPEN
**Version:** saropa_lints 4.10.0

---

## Summary

The `require_yield_between_db_awaits` rule treats all database operations identically — reads (`findFirst`, `findAll`) and writes (`writeTxn`, `putAll`, `deleteAll`) both trigger the same WARNING demanding `await DelayUtils.yieldToUI()`. This is incorrect because reads and writes have fundamentally different locking and performance characteristics, and blindly yielding after every read introduces unnecessary latency and stale-data windows.

---

## Root Cause

The rule's `_matchesHeavyIoName` method uses a flat list of method names with no categorisation:

```dart
// Current: all lumped together
findAll, findFirst,          // reads
writeTxn, deleteAll, putAll, // writes
rawQuery,                    // read
rawInsert, rawUpdate, rawDelete, // writes
```

There is no concept of "read operation" vs "write operation" in the detection logic. The `_isDbRelatedAwait` method returns a single boolean — it cannot communicate _what kind_ of operation was matched, so the reporter cannot vary its severity or message.

---

## Why This Matters

### 1. Write transactions hold exclusive locks

Isar's `writeTxn` acquires an exclusive lock on the database. While the lock is held, no other write can proceed, and the UI thread is blocked if it tries to read. Yielding after a write releases the Dart event loop so the framework can paint and other operations can proceed. **This is the correct and important use case for the rule.**

### 2. Reads do NOT hold exclusive locks

`findFirst()` and `findAll()` are non-blocking reads in Isar. They do not acquire exclusive locks. The only cost is CPU-bound deserialization on the main isolate. For a `findFirst()` returning a single object, this cost is negligible. The rule currently warns on these with the same urgency as a write transaction.

### 3. Yielding after reads adds latency for no benefit

Each `await DelayUtils.yieldToUI()` is `Future.delayed(Duration.zero)` — it defers to the next microtask. In a method that does three sequential reads, the rule demands three yields, adding three frame-boundary delays to what could be a fast synchronous-feeling sequence.

### 4. Yielding after reads creates stale-data windows

Consider this pattern:

```dart
final ContactDBModel? contact = await isar.contactDBModels
    .filter()
    .saropaUUIDEqualTo(uuid)
    .findFirst();
await DelayUtils.yieldToUI(); // <-- rule demands this

// Another isolate or write could modify/delete the contact here

if (contact != null) {
  // Using potentially stale data
}
```

The yield between reading and using the result opens a window where another write transaction could invalidate the data. For writes this tradeoff is acceptable (you've already committed). For reads it's a net negative.

### 5. Bulk reads are the exception

`findAll()` on an unbounded collection _can_ block the UI during deserialization of thousands of objects. These genuinely benefit from a yield. But the rule cannot distinguish `findAll()` from `findFirst()` — both are flagged identically.

---

## Current Behavior (Incorrect)

All of these trigger the same WARNING:

```dart
// Write transaction — WARNING is correct and important
await isar.writeTxn(() => isar.contacts.putAll(contacts));
// ⚠️ require_yield_between_db_awaits

// Single read — WARNING is excessive
final Contact? c = await isar.contacts.filter().idEqualTo(id).findFirst();
// ⚠️ require_yield_between_db_awaits  (same severity, same message)

// Bulk read — WARNING is arguably correct
final List<Contact> all = await isar.contacts.findAll();
// ⚠️ require_yield_between_db_awaits  (same severity, same message)
```

---

## Expected Behavior

The rule should differentiate by operation type:

| Operation                | Examples                                                                                                  | Severity                                   | Rationale                                                   |
| ------------------------ | --------------------------------------------------------------------------------------------------------- | ------------------------------------------ | ----------------------------------------------------------- |
| **Write/Delete**         | `writeTxn`, `putAll`, `deleteAll`, `rawInsert`, `rawUpdate`, `rawDelete`, `writeAsString`, `writeAsBytes` | **WARNING**                                | Exclusive locks, must yield                                 |
| **Bulk Read**            | `findAll`, `rawQuery`, `readAsString`, `readAsBytes`, `readAsLines`, `loadJsonFromAsset`                  | **INFO**                                   | CPU-bound deserialization, yield is helpful but situational |
| **Single Read**          | `findFirst`                                                                                               | **None** or **INFO**                       | Fast, no lock, yield adds latency with no benefit           |
| **`db*` prefix methods** | `dbContactLoad`, `dbContactSaveList`                                                                      | Depends on suffix heuristic (see proposal) | Currently all WARNING                                       |

---

## Proposed Fix

### Option A: Split into two rules (recommended)

Create separate rules with distinct severities:

1. **`require_yield_after_db_write`** — WARNING
   Matches: `writeTxn`, `putAll`, `put`, `deleteAll`, `delete`, `rawInsert`, `rawUpdate`, `rawDelete`, `writeAsString`, `writeAsBytes`
   Quick fix: Insert `await DelayUtils.yieldToUI();`

2. **`suggest_yield_after_db_read`** — INFO
   Matches: `findAll`, `rawQuery`, `readAsString`, `readAsBytes`, `readAsLines`, `loadJsonFromAsset`
   Quick fix: Same, but as a suggestion not a warning
   Exclude: `findFirst` (too fast to matter)

**Benefits:**

- Teams can suppress the INFO rule in code that needs low-latency reads
- The WARNING on writes stays non-negotiable
- No behavior change for existing codebases that already yield everywhere

### Option B: Add severity tiers within the existing rule

Keep a single rule but vary severity based on the matched method:

```dart
// In _matchesHeavyIoName, return an enum instead of bool
enum DbOperationType { write, bulkRead, singleRead, unknown }

DbOperationType _classifyDbOperation(String name) {
  if (['writeTxn', 'putAll', 'deleteAll', 'rawInsert', 'rawUpdate', 'rawDelete',
       'writeAsString', 'writeAsBytes'].contains(name)) {
    return DbOperationType.write;
  }

  if (['findAll', 'rawQuery', 'readAsString', 'readAsBytes', 'readAsLines',
       'loadJsonFromAsset'].contains(name)) {
    return DbOperationType.bulkRead;
  }

  if (name == 'findFirst') {
    return DbOperationType.singleRead;
  }

  return DbOperationType.unknown;
}
```

Then adjust the reporter severity:

- `write` → WARNING
- `bulkRead` → INFO
- `singleRead` → skip (no lint)
- `unknown` (e.g. `db*` prefix) → INFO

### Option C: Heuristic for `db*` prefix methods

For methods matching the `db*` prefix pattern, the rule could use a secondary name heuristic:

| Substring in method name                                                   | Likely operation | Severity |
| -------------------------------------------------------------------------- | ---------------- | -------- |
| `Save`, `Add`, `Put`, `Delete`, `Remove`, `Update`, `Write`, `Insert`      | Write            | WARNING  |
| `Load`, `Get`, `Find`, `Read`, `Fetch`, `Query`, `Count`, `List`, `Stream` | Read             | INFO     |

Example:

- `dbContactSave()` → contains `Save` → WARNING
- `dbContactLoad()` → contains `Load` → INFO
- `dbContactDelete()` → contains `Delete` → WARNING

---

## Impact on `avoid_return_await_db`

The companion rule `avoid_return_await_db` has the same issue. A `return await findFirst()` is flagged with the same severity as `return await writeTxn(...)`. The same read/write distinction should apply — `return await findFirst()` is a perfectly reasonable pattern that does not need a yield.

---

## Impact on Existing Codebases

In the `contacts` project (`d:\src\contacts\`), there are ~250 `*_io.dart` files in `lib/database/isar_middleware/`. Current state:

- **Write operations**: Consistently followed by `yieldToUI()` — no change needed
- **`findFirst()` reads**: Inconsistently followed by `yieldToUI()` — the rule nags but developers ignore it because they know a single-object read doesn't need a yield
- **`findAll()` reads**: Sometimes followed by `yieldToUI()`, sometimes not — this inconsistency is the direct result of the rule not distinguishing severity

A split rule would let developers:

- Fix all write-related warnings (non-negotiable)
- Address bulk-read suggestions where appropriate
- Stop suppressing or ignoring warnings on trivial single reads

---

## Test Coverage

There are currently **no unit tests** for `require_yield_between_db_awaits` or `avoid_return_await_db`. Any fix should include tests covering:

1. Write operation → WARNING (flagged)
2. Bulk read operation → INFO (flagged at lower severity)
3. Single read (`findFirst`) → not flagged (or INFO)
4. `db*` prefix with write-like name → WARNING
5. `db*` prefix with read-like name → INFO
6. Operation followed by `yieldToUI()` → not flagged (all types)
7. Operation followed by `throw` → not flagged (all types)
8. `return await writeTxn(...)` → WARNING
9. `return await findFirst(...)` → not flagged (or INFO)

---

## References

- Rule implementation: `lib/src/rules/db_yield_rules.dart` (lines 1–442)
- `DelayUtils.yieldToUI()`: `Future.delayed(Duration.zero)` — yields to event loop
- Related resolved bug: `bugs/_history/yield description and quickfix.md`
- Consumer codebase: `d:\src\contacts\lib\database\isar_middleware\`
