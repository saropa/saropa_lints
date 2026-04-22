# BUG: Missing rule — `avoid_drift_insert_missing_conflict_target` for UNIQUE-indexed Drift tables

**Status: Fix Ready**

<!-- Status values: Open → Investigating → Fix Ready → Closed -->

Created: 2026-04-22
Implemented: 2026-04-22
Rule: `avoid_drift_insert_missing_conflict_target`
File: [lib/src/rules/packages/drift_rules.dart](../lib/src/rules/packages/drift_rules.dart)
Severity: ERROR (Essential tier)
Rule version: v1 | Since: v12.3.4 | Updated: v12.3.4

---

## Summary

Drift tables that declare `@TableIndex(..., unique: true)` on a non-primary-key
column are hazardous for any `batch.insert(...)` / `into(table).insert(...)`
that omits an explicit `onConflict: DoUpdate(..., target: [uniqueCol])`. Without
the target, SQLite falls back to `ON CONFLICT("id")` — the primary key — and
misses the real UNIQUE constraint. The insert succeeds for new rows and raises
`SqliteException(2067): UNIQUE constraint failed` the moment the UUID (or other
unique column) already exists, either because a prior import left it on disk or
because the same value appears twice in one batch.

The symptom in production: a menu-triggered batch import crashes with
`DriftRemoteException(SqliteException(2067))` mid-way through. The caller's
surrounding `try/catch` pauses on `debugger()` inside `debugException`, freezing
the main isolate silently — the app hangs on splash with zero Dart output.

A lint rule is needed because this hazard is invisible at the call site:
the table's `@TableIndex(unique: true)` is declared in a separate file from
the IO method that inserts into it, so reviewers routinely miss it.

---

## Reproducer

Two-file reproducer. File 1 declares the table with a UNIQUE index on a
non-PK column. File 2 writes to it without a conflict target.

```dart
// lib/database/drift/tables/contact_points_table.dart
import 'package:drift/drift.dart';

@DataClassName('ContactPointsDriftModel')
@TableIndex(
  name: 'idx_contact_points_saropa_uuid',
  columns: <Symbol>{#contactSaropaUUID},
  unique: true, // <-- the hazard marker
)
class ContactPoints extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get contactSaropaUUID => text()();
  IntColumn get points => integer()();
  DateTimeColumn get createdAt => dateTime()();
}
```

```dart
// lib/database/io/contact_points_io.dart
Future<void> putAll(AppDatabase db, List<ContactPointsCompanion> rows) async {
  await db.batch((Batch batch) {
    for (final row in rows) {
      // LINT — missing onConflict target on UNIQUE-indexed table
      batch.insert(db.contactPoints, row);

      // ALSO LINT — .insertOnConflictUpdate defaults to ON CONFLICT("id"),
      // which is the PK, not the UNIQUE index column. Still raises 2067.
      // batch.insertOnConflictUpdate(db.contactPoints, row);
    }
  });
}

Future<int> putOne(AppDatabase db, ContactPointsCompanion row) async {
  // LINT — single-row insert has the same hazard
  return db.into(db.contactPoints).insert(row);
}

Future<int> putCorrect(AppDatabase db, ContactPointsCompanion row) async {
  // OK — explicit target matches the UNIQUE index column
  return db.into(db.contactPoints).insert(
    row,
    onConflict: DoUpdate<$ContactPointsTable, ContactPointsDriftModel>(
      ($ContactPointsTable _) => row,
      target: <Column<Object>>[db.contactPoints.contactSaropaUUID],
    ),
  );
}
```

**Frequency:** Always — fires whenever the table carries a UNIQUE @TableIndex
on a non-PK column and the insert omits a `target:` that includes that column.

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | Diagnostic at the `batch.insert(...)` / `.insert(...)` call: "Table `ContactPoints` has a UNIQUE index on `contactSaropaUUID`. The insert must pass `onConflict: DoUpdate(target: [db.contactPoints.contactSaropaUUID])` or SQLite falls back to ON CONFLICT(id) and raises 2067 on duplicate UUID." |
| **Actual** | No diagnostic — rule does not exist. The bug only surfaces at runtime, typically during a static-data import where the duplicate value appears in the batch. |

Real-world example this rule would have caught in the consuming project
(Saropa contacts app):

- Site of production crash — `dbContactPointsPutAll` — did raw
  `batch.insert(db.contactPoints, _toCompanionInsert(item))` with no
  `onConflict:`. Table has `@TableIndex(unique: true)` on
  `contactSaropaUUID`. Crashed during "Importing Demo Companions".
- Same hazard found in three sibling IO files that had not yet crashed:
  `contact_group_drift_io.dart`, `family_group_drift_io.dart`,
  `organization_drift_io.dart`. All four tables carry a UNIQUE UUID
  index; all four IO methods did `batch.insert(...)` with no conflict
  target. Fixed reactively — the lint rule would have caught all four
  at write time.

---

## AST Context

The rule registers on `MethodInvocation` and filters to Drift insert calls.
There are three method-name shapes to cover (all three are equally
dangerous on a UNIQUE-indexed table):

```
MethodInvocation                              ← node reported here
  ├─ SimpleIdentifier (methodName)
  │    one of: insert / insertOnConflictUpdate / insertAll
  ├─ target chain:
  │    batch.insert(...)
  │      └─ SimpleIdentifier (batch)            type: Batch
  │    db.into(tbl).insert(...)
  │      └─ MethodInvocation (.into(tbl))       returns InsertStatement<T, R>
  │    db.<table>.insertOnConflictUpdate(...)
  │      └─ PropertyAccess (db.<table>)         type: $XxxTable
  └─ ArgumentList
       ├─ Expression (table argument, when present)
       └─ NamedExpression? (onConflict: ...)    ← the required-when-unique argument
```

The rule must:

1. Identify the `$XxxTable` Drift table class targeted by the insert.
2. Walk that class's annotations for `@TableIndex(..., unique: true)`
   with non-PK columns.
3. If at least one such annotation exists, require the `onConflict:`
   argument to be present, be a `DoUpdate` (or `DoUpdate.withExcluded`),
   and have its `target:` list include at least one of the UNIQUE index
   columns. Anything else is a lint.

---

## Root Cause

No rule registered for this hazard. Existing `drift_rules.dart` covers
`avoid_drift_update_without_where`, `avoid_drift_get_single_without_unique`,
and `prefer_drift_batch_operations` — related UNIQUE/write safety rules —
but nothing that cross-references a table's `@TableIndex(unique: true)`
annotation against the insert call's conflict target.

### Hypothesis A: add as a new rule in `drift_rules.dart`

Fits the existing file's topic (Drift write safety) and tier placement.
Needs a lightweight AST walk to resolve the table class declaration from
the `MethodInvocation` target, then read its `@TableIndex` annotations.

### Hypothesis B: split into two rules

- `avoid_drift_insert_missing_conflict_target` — insert missing `onConflict:`
  entirely.
- `avoid_drift_insert_wrong_conflict_target` — `onConflict:` present but
  `target:` does not reference a UNIQUE index column.

Splitting gives clearer diagnostic messages. The second variant is
especially valuable because `insertOnConflictUpdate` *looks* safe but
defaults to ON CONFLICT(id), which silently misses the UUID UNIQUE.

---

## Suggested Fix

Add one rule (or the two-rule split per Hypothesis B) in
`lib/src/rules/packages/drift_rules.dart` after the existing
`avoid_drift_update_without_where` rule (same file, same topic group).

Detection outline:

1. Register `MethodInvocation`.
2. Filter to method names `insert`, `insertOnConflictUpdate`, `insertAll`
   where the receiver type is a Drift `Batch`, `InsertStatement`, or
   `TableInfo` subclass (resolve via `staticType`).
3. Resolve the target table class — either the first positional argument
   (for `batch.insert(table, row)`) or the receiver chain (for
   `db.xxx.insertOnConflictUpdate(row)`).
4. Walk the table class's metadata for `@TableIndex(..., unique: true)`
   and collect the Symbol set in the `columns:` argument.
5. Exclude UNIQUE indexes whose columns are exactly the PK (Drift default
   PK conflict handling is safe there).
6. If any non-PK UNIQUE index exists, require either:
   - An `onConflict:` named argument present AND expressed as
     `DoUpdate<...>(...)` or `DoUpdate<...>.withExcluded(...)` AND the
     `target:` list references at least one of the UNIQUE index columns
     via the `db.<table>.<column>` getter (name match on the column).
   - OR a `mode:` argument of `InsertMode.replace` (explicit REPLACE
     semantics — currently rare in this codebase but worth whitelisting).

`insertOnConflictUpdate` without an explicit target should ALWAYS lint on
a non-PK UNIQUE-indexed table — that's the silent-miss case.

Severity: `ERROR` (matches `avoid_drift_enum_index_reorder` — same class
of "silent data corruption / runtime crash" hazard).

---

## Fixture Gap

The fixture at `example*/lib/packages/drift_insert_conflict_target_fixture.dart`
(new file) should include:

1. **UNIQUE on non-PK, raw `batch.insert` with no onConflict** —
   expect LINT.
2. **UNIQUE on non-PK, `batch.insert` with `onConflict: DoUpdate(target: [uniqueCol])`** —
   expect NO lint.
3. **UNIQUE on non-PK, `batch.insert` with `onConflict: DoUpdate.withExcluded(target: [uniqueCol])`** —
   expect NO lint.
4. **UNIQUE on non-PK, `batch.insert` with `onConflict: DoUpdate(target: [wrongCol])`** —
   expect LINT (target does not reference the UNIQUE index column).
5. **UNIQUE on non-PK, `db.into(table).insert(row)` no onConflict** —
   expect LINT.
6. **UNIQUE on non-PK, `db.<table>.insertOnConflictUpdate(row)`** —
   expect LINT (defaults to ON CONFLICT(id), misses the UNIQUE).
7. **No UNIQUE @TableIndex at all, raw `batch.insert`** —
   expect NO lint (PK auto-increment is safe).
8. **Only PK UNIQUE (via `.customConstraint("UNIQUE")` on `id`)** —
   expect NO lint.
9. **Two UNIQUE indexes, `target:` references only one** —
   expect NO lint (any one match is sufficient for the rule to be
   satisfied; picking which UNIQUE to target is the caller's choice).
10. **`batch.insertAll(table, rows)` on UNIQUE-indexed table** —
    expect LINT (bulk variant has the same hazard).
11. **`into(table).insert(row, mode: InsertMode.replace)`** —
    expect NO lint (REPLACE is explicit conflict handling).
12. **Generated `.g.dart` file with the pattern** —
    expect NO lint (generated code exemption — same as existing rules).

---

## Changes Made

Implemented Hypothesis A (single rule in existing `drift_rules.dart`). The
rule fires on the insert call regardless of which `onConflict:` flavor is
missing — the diagnostic message distinguishes the cases in its
correctionMessage, which keeps the surface area small and avoids a second
rule whose fixture set would be 90% the same.

### File 1: `lib/src/rules/packages/drift_rules.dart`

Added `AvoidDriftInsertMissingConflictTargetRule` (ERROR severity,
`LintImpact.critical`, `RuleCost.medium`) immediately after
`_getFullChainSource`, the helper shared with `AvoidDriftUpdateWithoutWhereRule`.
The implementation:

1. Gates on `context.filePath` — `.g.dart` generated files skip analysis.
2. Registers `addMethodInvocation` and filters method names to `insert`,
   `insertAll`, `insertOnConflictUpdate`.
3. Walks the current compilation unit (`CompilationUnit.declarations`) for
   `class X extends Table` declarations, reading their `@TableIndex` metadata
   into a `className → Set<uniqueCol>` map. Excludes UNIQUE-on-PK (where
   Drift's default conflict handling is already safe).
4. Extracts the table identifier from the insert call — first positional
   arg for `batch.insert(table, row)` / `batch.insertAll(...)`, receiver
   chain for `db.<table>.insertOnConflictUpdate(...)` and
   `db.into(<table>).insert(...)`.
5. Resolves the identifier through Drift's lower-first getter convention
   (`ContactPoints` → `db.contactPoints`).
6. `insertOnConflictUpdate` is ALWAYS flagged against a UNIQUE non-PK table
   — the method defaults to `ON CONFLICT("id")` and has no parameter to
   override the target.
7. `insert` / `insertAll` require one of:
   - `onConflict: DoUpdate((_) => row, target: [<UNIQUE col>])` — matched
     via `InstanceCreationExpression` / `MethodInvocation` inspection
     against a column name in the UNIQUE set.
   - `onConflict: DoUpdate.withExcluded(...)` — same matching.
   - `mode: InsertMode.replace` — explicit REPLACE is acceptable.

Supporting helpers (`_collectUniqueIndexedTables`, `_readUniqueIndexColumns`,
`_parseSymbolSet`, `_collectPrimaryKeyColumns`, `_extractTargetTableIdentifier`,
`_identifierOfTableExpr`, `_resolveUniqueColumns`, `_hasMatchingConflictTarget`,
`_targetSetContainsAny`, `_hasReplaceMode`, `_namedArg`, `_namedArgFromArgList`,
`_setEquals`, `_extendsDriftTable`) are private top-level functions in the
same file, matching the `_getFullChainSource` / `_findEnclosingClass`
pattern already established in `drift_rules.dart`.

### File 2: `lib/saropa_lints.dart`

Added `AvoidDriftInsertMissingConflictTargetRule.new` to `_allRuleFactories`
immediately after `AvoidDriftUpdateWithoutWhereRule.new`.

### File 3: `lib/src/tiers.dart`

- Added `'avoid_drift_insert_missing_conflict_target'` to `essentialRules`
  (alongside `avoid_drift_enum_index_reorder`, matching the ERROR severity
  and the same class of "silent data corruption / runtime crash" hazard).
- Added to `driftPackageRules` for package-based filtering.

### Known Limitation (documented)

Same-compilation-unit detection only. When the `@TableIndex(unique: true)`
table class is in a different Dart file from the insert call — which is the
typical multi-file Drift setup in the Saropa contacts repo — the rule does
not fire. This is a deliberate conservative choice: cross-file element
resolution through the generated `$XxxTable` getter is tractable but would
widen the rule's blast radius for false positives during its first release.
Tracking as a follow-up in the rule's DartDoc; consumers who want coverage
today can co-locate the `@TableIndex` table with the IO method, or wait for
a follow-up rule version that walks `staticType.element` up to the original
table class declaration.

---

## Tests Added

- [example_packages/lib/drift/avoid_drift_insert_missing_conflict_target_fixture.dart](../example_packages/lib/drift/avoid_drift_insert_missing_conflict_target_fixture.dart)
  — stub fixture matching the pattern of sibling `drift_rules` fixtures.
  End-to-end triggering requires real Drift framework types and is exercised
  in the consuming Saropa contacts project; rule-instantiation coverage is
  in the unit test below.
- [test/drift_rules_test.dart](../test/drift_rules_test.dart) gains:
  - `AvoidDriftInsertMissingConflictTargetRule` rule-instantiation case
    (name, problem-message prefix, correction message, length guard).
  - `'avoid_drift_insert_missing_conflict_target'` in the fixture-verification
    list so a missing fixture file is caught by CI.
  - A new `group('avoid_drift_insert_missing_conflict_target', ...)` under
    `Drift - Essential Rules` with eight descriptive test cases covering
    the ERROR severity / `LintImpact.critical` assertion, each of the six
    bad / good patterns in the Fixture Gap (batch.insert, DoUpdate match,
    withExcluded match, insertOnConflictUpdate silent-miss, InsertMode.replace,
    no-UNIQUE-index table, UNIQUE-on-PK), and the `.g.dart` exemption.

---

## Commits

<!-- Add commit hashes as fixes land. -->

---

## Environment

- saropa_lints version: current `main` (rule does not exist in any released version)
- Dart SDK version: 3.x
- custom_lint version: (matches pinned in saropa_lints pubspec)
- Triggering project/file: Saropa contacts app — `D:\src\contacts\lib\database\drift_middleware\user_data\contact_points_drift_io.dart` (`dbContactPointsPutAll`, pre-fix revision). Same hazard pattern was simultaneously found in:
  - `lib/database/drift_middleware/user_data/contact_group_drift_io.dart`
    (`dbContactGroupPut`, `dbContactGroupPutAll`)
  - `lib/database/drift_middleware/user_data/family_group_drift_io.dart`
    (`dbFamilyGroupPut`, `dbFamilyGroupPutAll`)
  - `lib/database/drift_middleware/user_data/organization_drift_io.dart`
    (`dbOrganizationPut`, `dbOrganizationPutAll`)

  All four IO methods did `batch.insert(tbl, companion)` with no
  `onConflict:`, against tables that each declare a `@TableIndex(unique: true)`
  on their respective `*SaropaUUID` column. `contact_points` crashed first
  because its import path (static Demo Companions) hit the duplicate-UUID
  branch; the other three were latent and found by audit.
