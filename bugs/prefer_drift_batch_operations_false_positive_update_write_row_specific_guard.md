# BUG: `prefer_drift_batch_operations` — flags `UpdateStatement.write` (per-row guarded UPDATE) in a loop

**Status: Open**

Created: 2026-10-29
Rule: `prefer_drift_batch_operations`
File: `lib/src/rules/packages/drift_rules.dart` (line ~1423; `_insertMethods` ~1434)
Severity: False positive
Rule version: v1 | Since: unknown | Updated: 17.0.1-beta.2

---

## Summary

`write` is in the rule's `_insertMethods` set, so `(db.update(t)..where(...)).write(companion)` in a loop is reported with the message "Individual Drift insert() or write() call ... use b.insertAll". An UPDATE with a per-row `WHERE` (and a row-count the code needs) cannot be turned into `insertAll`; the suggested remedy does not apply to it.

---

## Attribution Evidence

```bash
grep -rn "'prefer_drift_batch_operations'" lib/src/rules/
# lib/src/rules/packages/drift_rules.dart:1423:    'prefer_drift_batch_operations',
```

**Emitter registration:** `lib/src/rules/packages/drift_rules.dart:1423`
**Rule class:** `PreferDriftBatchOperationsRule` (drift_rules.dart:1407) — registered in `lib/saropa_lints.dart:1624`
**Diagnostic `source` / `owner`:** `saropa_lints` / `saropaLintsLsp`

---

## Reproducer

Copied from `lib/database/drift_middleware/user_data/contact_avatar_drift_io.dart` lines 1170-1200 (inside a `for` loop over oversized avatar rows):

```dart
import 'dart:typed_data';
import 'package:drift/drift.dart';

class ContactAvatars extends Table {
  IntColumn get id => integer().autoIncrement()();
  BlobColumn get image => blob()();
  BlobColumn get imageThumbnail => blob().nullable()();
  TextColumn get contactSaropaUUID => text().unique()();
}

// `db` is the Drift database; `$ContactAvatarsTable` is the generated table class.
Future<int> shrinkOversized(
  AppDatabase db,
  Map<String, Uint8List> fullByUuid,
  int oversizedBytes,
) async {
  int rewritten = 0;
  for (final MapEntry<String, Uint8List> e in fullByUuid.entries) {
    final int updated =
        await (db.update(db.contactAvatars)..where(
              ($ContactAvatarsTable t) =>
                  t.contactSaropaUUID.equals(e.key) &
                  CustomExpression<bool>('LENGTH(image) > $oversizedBytes'),
            ))
            .write(                                      // LINT — but should NOT lint
              ContactAvatarsCompanion(image: Value<Uint8List>(e.value)),
            );
    if (updated == 0) continue;   // the affected-row count drives later logic
    rewritten++;
  }
  return rewritten;
}
```

**Frequency:** Always for `.write(...)` on an `UpdateStatement` in a loop (file imports drift).

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | No diagnostic: UPDATE with per-row WHERE and a consumed row count; `insertAll` is not applicable |
| **Actual** | `[prefer_drift_batch_operations] Individual Drift insert() or write() call detected inside a loop. ...` at `contact_avatar_drift_io.dart` 1185:18-1185:23 (line 1175 col 18 before a later edit) |

---

## AST Context

```
MethodDeclaration (rewriteOversizedAvatarRows)
  └─ Block
      └─ ForStatement
          └─ Block
              └─ VariableDeclarationStatement (final int updated)
                  └─ AwaitExpression
                      └─ MethodInvocation (.write)   <- reported at methodName
                          target: ParenthesizedExpression (db.update(...)..where(...))
```

---

## Root Cause

`drift_rules.dart:1434` `_insertMethods = {insert, insertOnConflictUpdate, write}`. At line 1446 only the method NAME is tested. `write` is `UpdateStatement.write` (also `InsertStatement`-less); the receiver's static type (`UpdateStatement<...>`) is never checked. `_isInsideLoop` (line 1457) then returns true for the enclosing `ForStatement`.

---

## Why the code is correct

- The statement is an UPDATE, not an insert. There is no list of rows to give `insertAll`.
- The WHERE differs per row (UUID) and includes a guard (`LENGTH(image) > N`) that makes a stale rewrite match zero rows. The returned count is consumed (`if (updated == 0) continue;`) to decide whether to touch the in-memory cache. `Batch.update` returns nothing, so batching would lose that.

---

## Affected project locations

- `lib/database/drift_middleware/user_data/contact_avatar_drift_io.dart:1185`
- `lib/database/drift_middleware/user_data/contact_section_sort_io.dart:137:20` (`.write(_companionFor(status, entry.value))` per row inside `db.transaction`; the caller needs the real affected-row count, which `Batch` cannot return)

---

## Suggested Fix

In `PreferDriftBatchOperationsRule`: only report `write` when the receiver type is an insert statement (or when the name is `insert`/`insertOnConflictUpdate`). Skip when the receiver static type element name is `UpdateStatement`, or when the invocation's result is used (assigned / awaited into a variable).

---

## Fixture Cases

```dart
// expect LINT
Future<void> bad(AppDatabase db, List<TodoItemsCompanion> xs) async {
  for (final x in xs) { await db.into(db.todoItems).insert(x); } // LINT
}

// expect NO lint: UPDATE with consumed row count
Future<void> good(AppDatabase db, List<int> ids) async {
  for (final id in ids) {
    final int n = await (db.update(db.todoItems)..where((t) => t.id.equals(id)))
        .write(const TodoItemsCompanion(done: Value(true))); // NO LINT
    if (n == 0) continue;
  }
}
```

---

## Environment

- saropa_lints version: 17.0.1-beta.2
- Dart SDK version: 3.13.7 (stable) (Thu Oct 22 14:28:57 2026 -0700) on "macos_arm64"
- Triggering project/file: `/Users/craighathaway/Documents/src/contacts/lib/database/drift_middleware/user_data/contact_avatar_drift_io.dart`
