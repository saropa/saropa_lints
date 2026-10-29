# BUG: `prefer_transaction_for_batch` — False Positive: Mutually Exclusive Write Branches Counted as Sequential Writes

**Status: Open**

Created: 2026-10-29
Rule: `prefer_transaction_for_batch`
File: `lib/src/rules/packages/firebase_rules.dart` (line ~795, `_DatabaseWriteCounter` ~839)
Severity: False positive
Rule version: v3 | Since: unknown | Updated: 17.0.1-beta.2

---

## Summary

The rule counts every `add/delete/insert/put/set/update` call in a method body and reports at 3 or more. It does not consider control flow. A method that does one write per path (delete, or update, or insert, each followed by `return`) is flagged as "multiple sequential database writes". The rule also lives in the Firebase file but fires on Drift calls.

---

## Attribution Evidence

```bash
grep -rn "'prefer_transaction_for_batch'" lib/src/rules/
# lib/src/rules/packages/firebase_rules.dart:814:    'prefer_transaction_for_batch',
```

**Emitter registration:** `lib/src/rules/packages/firebase_rules.dart:814`
**Rule class:** `PreferTransactionForBatchRule` (firebase_rules.dart:795), registered in `lib/saropa_lints.dart:1395`
**Diagnostic `source` / `owner` as seen in Problems panel:** `saropa_lints` / `saropaLintsLsp`

---

## Reproducer

Mirrors `lib/database/drift_middleware/user_data/ui_state_drift_io.dart:184-228` (`writeStringList`). Standalone shape with Drift (`drift: ^2`, a table `Prefs` with `id`, `name`, `value`):

```dart
import 'package:drift/drift.dart';

class Prefs extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get value => text()();
}

@DriftDatabase(tables: <Type>[Prefs])
class AppDatabase extends GeneratedDatabase {
  AppDatabase(super.e);
  @override
  int get schemaVersion => 1;
  @override
  Iterable<TableInfo<Table, dynamic>> get allTables => <TableInfo<Table, dynamic>>[];
}

// LINT, but should NOT lint: exactly one write runs per call.
Future<void> writeValue(AppDatabase db, String name, String? value, int? existingId) async {
  if (value == null) {
    if (existingId != null) {
      await (db.delete(db.prefs)..where((t) => t.id.equals(existingId))).go(); // write 1 (this path only)
    }
    return;
  }
  if (existingId != null) {
    await (db.update(db.prefs)..where((t) => t.id.equals(existingId)))
        .write(PrefsCompanion(value: Value<String>(value))); // write 2 (this path only)
    return;
  }
  await db.into(db.prefs).insert(PrefsCompanion.insert(name: name, value: value)); // write 3 (this path only)
}
```

(Generated `$PrefsTable` / `PrefsCompanion` need `build_runner`; the AST shape is what matters. The real project code is the cited file.)

**Frequency:** Any method with 3 or more write calls spread over `if`/`return` branches.

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | No diagnostic: each execution path performs one write |
| **Actual** | `[prefer_transaction_for_batch] Multiple sequential database writes. Use transaction for atomicity. Individual writes are slower and can leave data inconsistent. Use transactions or batch writes for multiple related changes. {v3}` at 184:3 of `ui_state_drift_io.dart` (method `writeStringList`) |

---

## AST Context

```
ClassDeclaration (UiStateDriftIO)
  └─ MethodDeclaration (writeStringList)        <- node reported (context.addMethodDeclaration)
      └─ BlockFunctionBody
          └─ TryStatement
              └─ Block
                  ├─ IfStatement (value.isEmpty) -> Block -> MethodInvocation .delete   (count 1)
                  ├─ IfStatement (existing != null) -> Block -> MethodInvocation .update (count 2)
                  └─ ExpressionStatement -> MethodInvocation .insert                      (count 3)
```

---

## Root Cause

`firebase_rules.dart:826-831`: the rule visits the whole method body with `_DatabaseWriteCounter` and reports when `counter.hasTransaction || counter.writeCount < 3` is false. `_DatabaseWriteCounter` (839+) extends `RecursiveAstVisitor` and increments `writeCount` in `_countIfDatabaseTarget` (902-914) for every `MethodInvocation` named in `_writeMethodNames` whose target type is not in `_safeCollectionTypes`.

- `db.delete(...)` target `AppDatabase`, count 1.
- `db.update(...)` target `AppDatabase`, count 2.
- `db.into(...).insert(...)` target `InsertStatement`, count 3.

The visitor has no notion of branches. Writes in separate `if` blocks that each end in `return` are counted as if run one after another. Also, `delete` and `update` on a Drift database are statement builders; the write happens at `.go()` / `.write()`.

---

## Why the code is correct

Each path does at most one write: empty list deletes the row and returns; changed value updates and returns; new value inserts. A transaction around a single statement adds nothing. There is no multi-write atomicity gap to protect.

---

## Affected project locations (scan of 2026-10-29)

- `lib/database/drift_middleware/user_data/ui_state_drift_io.dart:184:3` (`writeStringList`)

---

## Suggested Fix

Count writes along a single path: when a write is inside an `if`/`else`/`switch` branch that ends in `return`/`throw`, do not add it to the total of statements after that branch; report only if some single path holds 3 or more. Simpler variant: take the maximum count over branches of an `if`/`else`/`switch` instead of the sum, and treat a branch ending in an early exit as exclusive with the code after it. Also consider limiting the rule to Firebase/Firestore targets, since it lives in `firebase_rules.dart`.

---

## Fixture Gap

The fixture should include:

1. Three writes in sequence, no transaction — expect LINT
2. Three writes each in separate `if` branch ending in `return` — expect NO lint
3. `if (a) { x.update(); } else { x.insert(); }` plus one more write after — expect NO lint when max path < 3
4. Three writes inside `db.transaction(() async { ... })` — expect NO lint (exists)

---

## Environment

- saropa_lints version: 17.0.1-beta.2
- Dart SDK version: 3.13.7 (stable) (Thu Oct 22 14:28:57 2026 -0700) on "macos_arm64"
- custom_lint version: not used (analyzer plugin via VS Code extension)
- Triggering project/file: Saropa contacts app, `lib/database/drift_middleware/user_data/ui_state_drift_io.dart:184`
