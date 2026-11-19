# BUG: `prefer_drift_batch_operations` — flags `batch.insert()` that is already inside `db.batch((Batch batch) { ... })`

**Status: Open**

Created: 2026-10-29
Rule: `prefer_drift_batch_operations`
File: `lib/src/rules/packages/drift_rules.dart` (line ~1407 class, ~1423 code, `_isInsideLoop` ~1456)
Severity: False positive
Rule version: v1 | Since: v5.1.0 | Updated: v5.1.0

---

## Summary

The rule reports `batch.insert(...)` as an "individual insert inside a loop" when the call is the `Batch.insert` method of drift's `Batch` object, inside a `for` loop, inside the callback of `db.batch(...)`. That code IS the batch API the rule recommends. The rule matches only on the method name `insert` and never checks the receiver type.

---

## Attribution Evidence

```bash
# Positive — rule IS defined here
grep -rn "'prefer_drift_batch_operations'" lib/src/rules/
# lib/src/rules/packages/drift_rules.dart:1423:    'prefer_drift_batch_operations',

# Negative — sibling repo (../saropa_drift_advisor) is not checked out on this machine, so the
# negative grep cannot be run. The diagnostic text below is byte-identical to the LintCode
# message in this repo, plus the `{vN}` suffix, which is the attribution evidence.
```

**Emitter registration:** `lib/src/rules/packages/drift_rules.dart:1423` (LintCode), registered at `lib/saropa_lints.dart:1624` (`PreferDriftBatchOperationsRule.new`)
**Rule class:** `PreferDriftBatchOperationsRule` (`drift_rules.dart:1407`)
**Diagnostic `source` / `owner` as seen in Problems panel:** `source: saropa_lints`, `owner: saropaLintsLsp`

---

## Reproducer

Compiles standalone against `package:drift` (verified with `dart compile kernel` using the contacts app's package config; no code generation needed).

```dart
import 'package:drift/drift.dart';

Future<void> upsertAll(
  GeneratedDatabase db,
  TableInfo<Table, dynamic> table,
  List<Insertable<dynamic>> rows,
) async {
  await db.batch((Batch batch) {
    for (final Insertable<dynamic> row in rows) {
      batch.insert(table, row); // LINT — but should NOT lint (false positive)
    }
  });
}

void main() {}
```

Real source it was copied from (same shape, with `onConflict`):
`/Users/craighathaway/Documents/src/contacts/lib/database/drift_middleware/user_data/contact_points_drift_io.dart:330-332`

```dart
await db.batch((Batch batch) {
  for (final ContactPointDBModel item in models) {
    batch.insert(
      db.contactPoints,
      _toCompanionInsert(item),
      onConflict: DoUpdate<$ContactPointsTable, ContactPointsDriftModel>.withExcluded(...),
    );
  }
});
```

**Frequency:** Always, for every `batch.insert` / `batch.insertOnConflictUpdate` / `batch.write` in a loop in a file that imports `package:drift`.

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | No diagnostic. The call is `Batch.insert`, queued into one batch. |
| **Actual** | `[prefer_drift_batch_operations] Individual Drift insert() or write() call detected inside a loop. This is dramatically slower than using batch((b) { b.insertAll(...); }). Batches prepare SQL once and reuse it, providing 10-100x speedup for large datasets. {v1}` at `contact_points_drift_io.dart` 332:17-332:23 (the `insert` token) |

---

## AST Context

```
ClassDeclaration (DatabaseContactPointsDriftIO)
  └─ MethodDeclaration (static dbContactPointsPutAll)
      └─ BlockFunctionBody → Block → TryStatement → Block
          └─ ExpressionStatement
              └─ AwaitExpression
                  └─ MethodInvocation (db.batch)
                      └─ ArgumentList
                          └─ FunctionExpression ((Batch batch) {...})
                              └─ BlockFunctionBody → Block
                                  └─ ForStatement (for (final ContactPointDBModel item in models))
                                      └─ Block
                                          └─ ExpressionStatement
                                              └─ MethodInvocation (batch.insert)  ← node.methodName reported
```

---

## Root Cause

`lib/src/rules/packages/drift_rules.dart`, `PreferDriftBatchOperationsRule.runWithReporter` (~line 1449-1461):

```dart
context.addMethodInvocation((MethodInvocation node) {
  if (!_insertMethods.contains(node.methodName.name)) return;   // {'insert','insertOnConflictUpdate','write'}
  if (!fileImportsPackage(node, PackageImports.drift)) return;
  if (_isInsideLoop(node)) { reporter.atNode(node.methodName); }
});
```

1. The only receiver-independent filters are the method name (`insert`) and "file imports drift". `Batch.insert` has the same name as `InsertStatement`/`TableInfo` inserts, so it passes.
2. `_isInsideLoop` (~line 1465) walks parents. It finds the `ForStatement` first and returns `true`. It never reaches the `FunctionExpression` boundary of the `db.batch(...)` callback, and it never asks what the receiver is.
3. There is no check on `node.realTarget?.staticType` (drift `Batch`) and no check that an ancestor `MethodInvocation` is `.batch(...)`.

---

## Why the code is correct

`batch.insert(table, companion, onConflict: ...)` is `Batch.insert` from `package:drift`. It does not run SQL. It appends one entry to the batch, and the whole batch is sent in one transaction when the `db.batch` callback returns. This is the pattern the rule's own correction message recommends ("Use batch operations: await batch((b) { b.insertAll(table, companions); });"). `insertAll` does not support per-row `onConflict: DoUpdate(...)` with a per-row companion, so a loop of `batch.insert` is the correct form for upserts.

---

## Affected Locations (contacts app)

Line numbers as reported by the diagnostics (the files have had small unrelated edits since):

| File | Line:col |
|---|---|
| `/Users/craighathaway/Documents/src/contacts/lib/database/drift_middleware/user_data/contact_group_drift_io.dart` | 525:19 (in `dbContactGroupPutAll`) |
| `/Users/craighathaway/Documents/src/contacts/lib/database/drift_middleware/user_data/contact_points_drift_io.dart` | 332:17 (in `dbContactPointsPutAll`) |
| `/Users/craighathaway/Documents/src/contacts/lib/database/drift_middleware/user_data/user_preference_save_drift_io.dart` | 263:17 (in `dbUserPreferenceSaveListByTypes`) |
| `/Users/craighathaway/Documents/src/contacts/lib/database/drift_middleware/user_data/contact_google_snapshot_drift_io.dart` | 74:17 (in `dbGoogleSnapshotsUpsertBatch`) |
| `/Users/craighathaway/Documents/src/contacts/lib/database/drift_middleware/user_data/connection_drift_io.dart` | 294:19 |
| `/Users/craighathaway/Documents/src/contacts/lib/database/drift_middleware/user_data/contact_drift_io.dart` | 818:21 (`batch.insert` in `dbContactPutAll`), 891:13 and 904:13 (`b.insert` in `_rebuildLookupRowsFor`) |

---

## Suggested Fix

In `PreferDriftBatchOperationsRule.runWithReporter`, skip the node when it is a `Batch` method:

1. Resolve `node.realTarget?.staticType`; return when its element name is `Batch` and it comes from `package:drift`.
2. Syntactic fallback (no type resolution): return when `_isInsideLoop` crosses, or sits inside, a `FunctionExpression` that is an argument to a `MethodInvocation` named `batch`. In `_isInsideLoop`, check the enclosing `.batch(...)` callback before returning `true` for the `ForStatement`.

---

## Fixture Gap

The fixture for `prefer_drift_batch_operations` should include:

1. `for (final r in rows) { await db.into(table).insert(r); }` — expect LINT
2. `for (final r in rows) { await db.into(table).insertOnConflictUpdate(r); }` — expect LINT
3. `await db.batch((Batch batch) { for (final r in rows) { batch.insert(table, r); } });` — expect NO lint
4. Same as 3 with `onConflict: DoUpdate(...)` — expect NO lint
5. `await db.batch((b) { for (final r in rows) { b.insertOnConflictUpdate(table, r); } });` — expect NO lint

---

## Environment

- saropa_lints version: 17.0.1-beta.2
- Dart SDK version: 3.13.7 (stable) (Thu Oct 22 14:28:57 2026 -0700) on "macos_arm64"
- custom_lint version: not used (diagnostic delivered by the `saropaLintsLsp` owner in VS Code, `source: saropa_lints`)
- Triggering project/file: `/Users/craighathaway/Documents/src/contacts` (Flutter app `saropa`); files listed under Affected Locations

---

## Additional affected location (appended 2026-10-29)

- `/Users/craighathaway/Documents/src/contacts/lib/database/drift_middleware/user_data/activity_write_drift_io.dart:63` (diagnostic 63:17-63:23): `batch.insert(db.activities, ...)` in a `for` loop inside `await db.batch((Batch batch) { ... })`. Same cause (`_isInsideLoop` finds the `ForStatement` before the `Batch` callback boundary; the call target type `Batch` is never checked).
