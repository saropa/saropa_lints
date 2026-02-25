# Drift (SQLite) — Comprehensive Research & Implementation Document

Complete knowledge base for adding Drift database lint rules to saropa_lints. Contains all research findings, API surface analysis, common pitfalls, proposed rules with detection strategies, edge cases, open questions, and implementation notes.

---

## Table of Contents

1. [What is Drift?](#1-what-is-drift)
2. [Package Ecosystem](#2-package-ecosystem)
3. [Core API Surface](#3-core-api-surface)
4. [Common Mistakes & Pitfalls](#4-common-mistakes--pitfalls)
5. [Performance Anti-Patterns](#5-performance-anti-patterns)
6. [Security Concerns](#6-security-concerns)
7. [Resource Management](#7-resource-management)
8. [Web Platform Considerations](#8-web-platform-considerations)
9. [Migration System Deep Dive](#9-migration-system-deep-dive)
10. [Type Safety & Converters](#10-type-safety--converters)
11. [Reactive Queries & Streams](#11-reactive-queries--streams)
12. [Transaction Patterns](#12-transaction-patterns)
13. [DAO Patterns](#13-dao-patterns)
14. [Testing Patterns](#14-testing-patterns)
15. [Current Project State](#15-current-project-state)
16. [Shared Database Rules Gap Analysis](#16-shared-database-rules-gap-analysis) _(NEW)_
17. [Proposed Rules (21 rules)](#17-proposed-rules-21-rules)
18. [Additional Rule Candidates](#18-additional-rule-candidates) _(NEW)_
19. [Detection Strategy](#19-detection-strategy)
20. [Files to Create / Modify](#20-files-to-create--modify)
21. [Implementation Notes](#21-implementation-notes)
22. [Priority Scoring & Effort Estimates](#22-priority-scoring--effort-estimates) _(NEW)_
23. [Updating db_yield_rules.dart for Drift](#23-updating-db_yield_rulesdart-for-drift) _(NEW)_
24. [Risk Assessment & Confidence Levels](#24-risk-assessment--confidence-levels)
25. [Open Questions & Decisions](#25-open-questions--decisions)
26. [Rules We Considered But Rejected](#26-rules-we-considered-but-rejected)
27. [Drift Version History & Compatibility](#27-drift-version-history--compatibility) _(NEW)_
28. [Generated Code Interaction](#28-generated-code-interaction) _(NEW)_
29. [Cross-Package Integration Patterns](#29-cross-package-integration-patterns) _(NEW)_
30. [Sample Fixture Code](#30-sample-fixture-code) _(NEW)_
31. [Unresolved Risks & Validation Gaps](#31-unresolved-risks--validation-gaps) _(NEW)_
32. [Comparison with Isar/Hive Rules](#32-comparison-with-isarhive-rules)
33. [References](#33-references)

---

## 1. What is Drift?

Drift (formerly **moor**, renamed for inclusivity) is a type-safe, reactive SQLite wrapper for Dart/Flutter. It uses code generation (`build_runner`) to create type-safe table definitions, companions (partial-row classes), and DAOs.

**Key differentiators from Isar/Hive:**

- Full SQL database (not NoSQL / key-value)
- Code generation for type safety (`*.g.dart` or `*.drift.dart`)
- Explicit schema migrations with versioning
- Raw SQL support alongside typed APIs
- Reactive stream queries with table-level invalidation
- Foreign key support (requires manual PRAGMA)
- DAO pattern built into the framework
- Full web support (OPFS, IndexedDB, sql.js)
- Isolate-based background processing

**Historical note:** The old packages `moor`, `moor_flutter`, and `moor_generator` are discontinued. Any references to "moor" in existing code should be treated as legacy Drift.

---

## 2. Package Ecosystem

| Package                  | Purpose                                                                                           | Required?                      |
| ------------------------ | ------------------------------------------------------------------------------------------------- | ------------------------------ |
| `drift`                  | Core persistence library with type-safe queries and reactive streams                              | Yes                            |
| `drift_dev`              | Code generator / compiler for tables, databases, DAOs; includes SQL IDE for Dart analyzer         | Dev dependency                 |
| `drift_flutter`          | Platform utility — provides `driftDatabase()` helper that selects the right executor per platform | Recommended                    |
| `drift_sqflite`          | Flutter-only executor implementation using the `sqflite` package                                  | Alternative to `drift_flutter` |
| `sqlite3`                | Low-level SQLite3 bindings used by `NativeDatabase`                                               | Transitive                     |
| `sqlite3_flutter_libs`   | Bundled SQLite3 native libraries for Flutter                                                      | Required for mobile/desktop    |
| `sqlcipher_flutter_libs` | SQLCipher (AES-256 encrypted SQLite) native libraries                                             | Optional, for encryption       |

**Package detection for lint rules**: Check for `drift` in `pubspec.yaml` dependencies. The `drift_dev` package alone (dev dependency only) doesn't indicate Drift usage in app code.

**Typical pubspec.yaml:**

```yaml
dependencies:
  drift: ^2.20.0
  drift_flutter: ^0.2.0
  sqlite3_flutter_libs: ^0.5.0

dev_dependencies:
  drift_dev: ^2.20.0
  build_runner: ^2.4.0
```

---

## 3. Core API Surface

### Database Class

```dart
// User defines this class
@DriftDatabase(tables: [TodoItems, Categories], daos: [TodosDao])
class AppDatabase extends _$AppDatabase {
  AppDatabase(QueryExecutor e) : super(e);

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (migrator) async { await migrator.createAll(); },
    onUpgrade: (migrator, from, to) async { ... },
    beforeOpen: (details) async { ... },
  );
}
```

- Extends `_$AppDatabase` (generated superclass)
- Must override `schemaVersion` getter
- Optionally overrides `migration` getter for `MigrationStrategy`
- `MigrationStrategy` has three callbacks: `onCreate`, `onUpgrade`, `beforeOpen`

### Table Definitions

```dart
class TodoItems extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get title => text().withLength(min: 6, max: 32)();
  TextColumn get content => text().named('body')();
  IntColumn get category => integer().nullable().references(Categories, #id)();
  BoolColumn get completed => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}
```

**Critical pattern**: Each column definition MUST end with an extra pair of parentheses `()` — the final `()` is the builder terminator. This is a common source of confusion.

**Column types:**

- `integer()` → int
- `int64()` → BigInt (for JS compatibility)
- `text()` → String
- `boolean()` → bool (stored as 0/1 in SQLite)
- `real()` → double
- `blob()` → Uint8List
- `dateTime()` → DateTime (Unix timestamps by default, ISO-8601 strings optional)

**Column modifiers:**

- `.nullable()` → allows null (non-nullable by default)
- `.withDefault(Constant(value))` → SQL-level default (requires migration on change)
- `.clientDefault(() => value)` → Dart-level default (computed at insert time, NOT in DB)
- `.autoIncrement()` → auto-incrementing primary key (only one per table)
- `.withLength(min: n, max: m)` → text length constraints
- `.named('column_name')` → override SQL column name
- `.references(OtherTable, #column)` → foreign key reference
- `.customConstraint('SQL CONSTRAINT')` → raw SQL constraint (OVERRIDES NOT NULL)
- `.map(typeConverter)` → apply type converter

### Companions (Insert/Update Objects)

Generated `*Companion` classes use `Value<T>` wrappers:

- `Value(data)` → set to this value
- `Value.absent()` → leave unchanged (for updates) or use default (for inserts)
- This design distinguishes "set to null" from "don't change" — important for nullable columns

```dart
await into(todoItems).insert(TodoItemsCompanion(
  title: Value('Buy groceries'),
  completed: Value.absent(), // Use default (false)
));

await (update(todoItems)..where((t) => t.id.equals(1)))
  .write(TodoItemsCompanion(
    completed: Value(true), // Only update this column
  ));
```

### Query APIs

**Typed Dart API (safe):**

```dart
// Select
select(todoItems).get(); // List<TodoItem>
select(todoItems).watch(); // Stream<List<TodoItem>>
(select(todoItems)..where((t) => t.completed.equals(true))).get();

// Insert
into(todoItems).insert(companion);
into(todoItems).insertOnConflictUpdate(companion);

// Update
(update(todoItems)..where((t) => t.id.equals(id))).write(companion);

// Delete
(delete(todoItems)..where((t) => t.id.equals(id))).go();

// Joins
select(todoItems).join([
  leftOuterJoin(categories, categories.id.equalsExp(todoItems.category)),
]);
```

**Raw SQL API (UNSAFE if misused):**

```dart
customSelect('SELECT * FROM todo_items WHERE id = ?',
  variables: [Variable.withInt(id)],
  readsFrom: {todoItems},
).get();

customStatement('CREATE INDEX idx_name ON users(name)');

customUpdate('UPDATE users SET name = ? WHERE id = ?',
  variables: [Variable.withString(name), Variable.withInt(id)],
  updates: {users},
);
```

### Transactions

```dart
await transaction(() async {
  await into(todoItems).insert(companion1);
  await (update(categories)..where((c) => c.id.equals(catId)))
    .write(companion2);
  // Committed atomically when this callback completes
});
```

### Batches

```dart
await batch((b) {
  b.insertAll(todoItems, companions); // Efficient bulk insert
  b.deleteWhere(todoItems, (t) => t.completed.equals(true));
  b.update(categories, CategoriesCompanion(description: Value('updated')));
});
```

### Stream Queries

```dart
// Watch queries — re-execute on table changes
select(todoItems).watch(); // Stream<List<TodoItem>>
(select(todoItems)..where((t) => t.id.equals(1))).watchSingle(); // Stream<TodoItem>
(select(todoItems)..where((t) => t.id.equals(1))).watchSingleOrNull(); // Stream<TodoItem?>

// Manual invalidation (for external changes)
notifyUpdates({TableUpdate.onTable(todoItems, kind: UpdateKind.insert)});

// Listen to table changes directly
tableUpdates(TableUpdateQuery.onTable(todoItems)).listen((updates) { ... });
```

**Stream invalidation is TABLE-LEVEL, not row-level**: Any insert/update/delete on a table triggers ALL streams watching that table to re-execute. This means streams "generally update more often than they have to" (Drift docs).

---

## 4. Common Mistakes & Pitfalls

### Table Definition Mistakes

1. **Forgetting trailing `()`**: Each column must end with `()` — the final `()` is the builder terminator
   - `integer().autoIncrement()()` — correct
   - `integer().autoIncrement()` — WRONG, won't compile

2. **Mixing `customConstraint()` with other constraints**: `customConstraint()` OVERRIDES the `NOT NULL` constraint. Columns with custom constraints need explicit `NOT NULL` in the custom constraint string if desired.

3. **Foreign keys not enforced by default**: SQLite requires `PRAGMA foreign_keys = ON`, which must be set in `beforeOpen` callback, NOT inside a transaction.

4. **`autoIncrement()` on multiple columns**: Not allowed — only one auto-increment column per table.

5. **`clientDefault` vs `withDefault`**:
   - `clientDefault(() => value)` computes in Dart — values are NOT applied when interacting with DB outside Drift
   - `withDefault(Constant(value))` is a schema-level default — requires migration on change
   - Using `clientDefault` for timestamps means the timestamp is when Dart runs, not when SQL executes

### Query Mistakes

1. **`getSingle()` / `watchSingle()` on multi-row queries**: Throws `StateError` with stack trace. Must guarantee exactly one row (e.g., via primary key filter).

2. **`update()` or `delete()` without `where()` clause**: Affects ALL rows in the table. Drift docs explicitly warn about this.

3. **Multiple SQL statements in single call**: `NativeDatabase` throws exception. Previous versions silently ignored trailing statements.

4. **Not awaiting queries inside transactions**: Transaction completes when callback returns — unawaited futures execute outside the transaction boundary.

5. **Creating `UpdateStatement` outside transaction, writing inside**: Can cause deadlocks (fixed in recent Drift versions but still an anti-pattern).

### Code Generation Issues

1. **Name collisions**: When imported classes share names with generated classes. Solution: enable modular code generation (generates `*.drift.dart` instead of `*.g.dart`).

2. **Lints in `.g.dart` files**: Must be suppressed via `analysis_options.yaml` exclusion patterns. Our project already handles this — `.drift.dart` is in the `_generatedFileSuffixes` list in `stylistic_rules.dart`.

3. **Not running `build_runner` after changes**: Generated code becomes stale, leading to compile errors. This is a workflow issue, not detectable by lint rules.

---

## 5. Performance Anti-Patterns

### Unbatched Bulk Operations

Individual inserts in a loop instead of `batch((b) { b.insertAll(...); })`. Batches prepare SQL statements once and reuse them.

**Magnitude**: Can be 10-100x slower without batching for large datasets.

### Missing Indexes

Tables without indexes on frequently queried columns cause full table scans. Use `@TableIndex` annotation or `CREATE INDEX` in `.drift` files.

### Running Database on UI Isolate

SQLite runs statements synchronously, blocking the thread. On mobile, this causes dropped frames and UI jank.

**Solutions:**

- `NativeDatabase.createInBackground()` — automatic background isolate
- `DriftIsolate` — manual isolate control
- `driftDatabase()` from `drift_flutter` — handles platform selection automatically

### Overly Broad Stream Queries

Drift's stream invalidation is table-level. Streams that return many rows or are computationally expensive re-execute on every table change. Keep watched queries lightweight.

### N+1 Query Pattern

Fetching a list of items, then querying related data one-by-one in a loop. Use joins instead:

```dart
select(items).join([leftOuterJoin(categories, ...)]);
```

### Not Using `useColumns: false` on Irrelevant Joins

When you join a table only for filtering/aggregation but don't need its columns, set `useColumns: false` to avoid unnecessary column reading overhead.

---

## 6. Security Concerns

### SQL Injection via Raw Queries

Drift's typed API is inherently safe. However, `customSelect`, `customStatement`, and `customUpdate` accept raw SQL strings.

**ALWAYS use parameterized queries** via the `variables` parameter with `Variable.withInt()`, `Variable.withString()`, etc. NEVER use string interpolation.

```dart
// VULNERABLE
customSelect('SELECT * FROM users WHERE name = "$input"');

// SAFE
customSelect('SELECT * FROM users WHERE name = ?',
  variables: [Variable.withString(input)]);
```

**OWASP mapping**: A03:2021-Injection

### Encryption

- Drift supports SQLCipher for AES-256 encryption via `sqlcipher_flutter_libs`
- Set key via `PRAGMA key = 'passphrase';` in the `setup` parameter of `NativeDatabase`
- **Critical**: SQLCipher and regular SQLite3 libraries can conflict. Use `PRAGMA cipher_version;` to verify the encrypted variant loaded correctly.
- When migrating unencrypted to encrypted: use `sqlcipher_export` function, preserve `user_version` pragma

### Sensitive Data in Logs

`logStatements: true` will print ALL SQL including data values. Must be disabled in production.

```dart
// BAD
NativeDatabase(file, logStatements: true); // Logs "INSERT INTO users VALUES ('John', 'secret@email.com')"

// GOOD
NativeDatabase(file, logStatements: kDebugMode);
```

### Database File Access

SQLite files stored in `getApplicationDocumentsDirectory()` by default. On Android, app data can be backed up, potentially exposing unencrypted databases. On iOS, files in Documents directory are included in iCloud backup unless explicitly excluded.

---

## 7. Resource Management

### Database Closing

- **Must call `db.close()`** to release file handles, isolate connections, and stream tracking
- For Provider/Riverpod: close in `dispose` callback
- For isolate-based databases: `DriftIsolate.shutdownAll()` closes isolate and all clients
- With `singleClientMode: true` on `connect()`: closing the single connection terminates the isolate
- With `drift_flutter` dedicated isolate mode: the isolate stops only when ALL attached databases are explicitly closed

### Stream Subscription Leaks

- Drift stream queries that are subscribed but never canceled cause memory leaks
- They are tracked in an internal map and only removed on `.cancel()`
- Always cancel stream subscriptions in `dispose()`
- In widget tests: use `closeStreamsSynchronously: true` on `DatabaseConnection`

### Multiple Database Instances

- Opening multiple independent Drift instances on the same file breaks stream synchronization
- Streams only update when changes go through the same database instance
- Without sharing: set WAL journal mode and `busy_timeout` pragma to mitigate write locks
- Use `drift_flutter` with `shareAcrossIsolates: true` or maintain a singleton instance

---

## 8. Web Platform Considerations

### Storage Strategy Hierarchy (automatic selection by drift_flutter)

1. **opfsShared** — Origin-private filesystem via shared workers (Firefox only as of 2025)
2. **opfsLocks** — Origin-private filesystem (requires COOP/COEP headers)
3. **sharedIndexedDb** — IndexedDB with shared worker synchronization
4. **unsafeIndexedDb** — IndexedDB without cross-tab coordination (UNSAFE for multi-tab)
5. **inMemory** — Fallback when no persistence available

### Key Limitations

- **Multi-tab safety**: `unsafeIndexedDb` mode is NOT safe for multiple tabs — data races can occur
- **COOP/COEP headers required for OPFS**: `Cross-Origin-Opener-Policy: same-origin` and `Cross-Origin-Embedder-Policy: require-corp` or `credentialless` — these conflict with some auth packages (Google Auth, Firebase Auth popups)
- **Safari limitations**: No FileSystem Access API support; slightly slower performance
- **Chrome Android without headers**: "Limited (not with multiple tabs)" — data races possible
- **sql.js approach (legacy)**: Exports entire database as blob after each write — extremely inefficient, not recommended
- **IndexedDB async mismatch**: SQLite expects synchronous filesystem, IndexedDB is async; in-memory caching with eventual writes means data can be lost if tab crashes

### Setup Requirements for Web

- Web directory must contain `sqlite3.wasm` (served with `Content-Type: application/wasm`)
- Must also contain `drift_worker.dart.js` (compiled Dart worker)
- Server must set appropriate CORS and COOP/COEP headers for OPFS mode

---

## 9. Migration System Deep Dive

### How Migrations Work

1. Database class overrides `schemaVersion` getter (integer)
2. On open, Drift compares stored version to declared version
3. If stored < declared: `onUpgrade(migrator, from, to)` fires
4. If new database: `onCreate(migrator)` fires
5. After migration: `beforeOpen(details)` always fires

### Migration Strategy

```dart
@override
MigrationStrategy get migration => MigrationStrategy(
  onCreate: (migrator) async {
    await migrator.createAll(); // Creates all tables from current schema
  },
  onUpgrade: (migrator, from, to) async {
    // Incremental version checks
    if (from < 2) {
      await migrator.addColumn(users, users.email);
    }
    if (from < 3) {
      await migrator.createTable(sessions);
    }
  },
  beforeOpen: (details) async {
    // Runs AFTER migration, before any queries
    await customStatement('PRAGMA foreign_keys = ON');
  },
);
```

### Critical Migration Mistakes

1. **Not bumping `schemaVersion`**: `onUpgrade` callback won't trigger if version stays the same. Code generation expects new columns but SQLite still has old schema → runtime crash.

2. **Using high-level query APIs inside migration callbacks**: Drift generates code expecting the LATEST schema. During migration, the DB is still on the OLD schema. Using `select(users)` in `onUpgrade` when you just added a column to `users` will fail.
   - **Must use raw SQL**: `customStatement('ALTER TABLE users ADD COLUMN email TEXT')` or `migrator.addColumn()`

3. **Deleting schema JSON files**: Drift's `make-migrations` command requires ALL JSON schema definitions for ALL versions to generate migration code.

4. **Running foreign key pragma inside migration transaction**: Pragmas like `foreign_keys` cannot be changed inside transactions. Migration callbacks run inside transactions. Setting this in `onUpgrade` silently fails.
   - **Must use `beforeOpen`**: This runs after the migration transaction completes.

5. **Database downgrades**: Unsupported and will throw an error with step-by-step migrations. Previous versions caused silent `user_version` corruption.

### Best Practices for Migrations

- Use `make-migrations` command (`dart run drift_dev make-migrations`) for automated step-by-step generation
- Export schema JSON snapshots before modifying tables
- Test migrations with generated test files
- During active development: delete app and reinstall rather than writing migrations
- Use incremental version checks: `if (from < 2) { ... } if (from < 3) { ... }`
- Disable foreign keys during complex migrations: `PRAGMA foreign_keys = OFF` in custom statement, re-enable in `beforeOpen`

---

## 10. Type Safety & Converters

### Built-in Column Types

| Dart Type   | Column Builder | SQLite Storage                    |
| ----------- | -------------- | --------------------------------- |
| `int`       | `integer()`    | INTEGER                           |
| `BigInt`    | `int64()`      | INTEGER (safe for JS)             |
| `String`    | `text()`       | TEXT                              |
| `bool`      | `boolean()`    | INTEGER (0/1)                     |
| `double`    | `real()`       | REAL                              |
| `Uint8List` | `blob()`       | BLOB                              |
| `DateTime`  | `dateTime()`   | INTEGER (unix) or TEXT (ISO-8601) |

### DateTime Storage Mode

By default, `dateTime()` stores as Unix timestamps (integers). Can be changed to ISO-8601 text via build option `store_date_time_values_as_text: true` in `build.yaml`. Mixing modes causes data corruption.

### Type Converters

```dart
// Base class
abstract class TypeConverter<DartType, SqlType> {
  DartType fromSql(SqlType fromDb);
  SqlType toSql(DartType value);
}

// V2 mixin (prevents double-encoding in JSON)
mixin JsonTypeConverter2<DartType, SqlType, JsonType> on TypeConverter<DartType, SqlType> {
  DartType fromJson(JsonType json);
  JsonType toJson(DartType value);
}
```

### Enum Converter Pitfall (CRITICAL)

Adding enum values mid-sequence shifts indices, corrupting existing data. Renaming enum values breaks text-based lookups.

```dart
// DANGEROUS: enum by index
enum Priority { low, medium, high }
// If you add: enum Priority { low, urgent, medium, high }
// Old "medium" data (index 1) now reads as "urgent"

// Mitigation strategies:
// 1. Store by name (String) — immune to reordering
// 2. Store by explicit code — immune to reordering
// 3. ONLY add new values at the END — fragile, easy to forget
```

### Nullable Converter Issues

- `TypeConverter<Foo?, int?>` can NO LONGER be applied to non-nullable columns (enforced since v2)
- Use `NullAwareTypeConverter` utility for safely handling nullable values
- Separate type params for SQL and JSON via `JsonTypeConverter2` mixin

### SQL Expressions Bypass Converters

When using `Expression`-based filtering with type converters:

- `column.equals(sqlValue)` → does NOT apply converter (expects raw SQL value)
- `column.equalsValue(dartValue)` → DOES apply converter (converts to SQL first)
- Forgetting to use `equalsValue()` causes queries that never match

---

## 11. Reactive Queries & Streams

### How Stream Invalidation Works

1. Drift tracks which tables each stream reads from
2. Any insert/update/delete through Drift APIs triggers re-execution of dependent streams
3. Invalidation is **table-level, not row-level** — streams update more often than necessary
4. External database changes (outside Drift APIs) do NOT trigger stream updates
5. Use `notifyUpdates()` to manually trigger invalidation for external changes

### Stream Behavior

- All streams emit an initial snapshot immediately upon subscription
- No need to combine `.get()` with `.watch()` — the stream gives you the initial value
- `watchSingle()` throws if query returns 0 or >1 rows
- `watchSingleOrNull()` returns null for empty results, throws for >1
- Stream debouncing uses timers internally → causes issues in widget tests

### Custom Stream Queries

```dart
// IMPORTANT: readsFrom parameter
customSelect('SELECT * FROM users WHERE active = 1',
  readsFrom: {users}, // Without this, stream NEVER updates
).watch();
```

Without `readsFrom`, Drift doesn't know which tables the custom query reads from, so it can never invalidate the stream. The stream will return the initial result and never update.

### Manual Stream Control

```dart
// Trigger manual update notification
notifyUpdates({TableUpdate.onTable(todoItems, kind: UpdateKind.insert)});

// Listen to table changes directly (lower level)
tableUpdates(TableUpdateQuery.onTable(todoItems, limitUpdateKind: UpdateKind.update))
  .listen((updates) { ... });
```

---

## 12. Transaction Patterns

### Correct Pattern

```dart
Future<void> deleteCategory(Category category) {
  return transaction(() async {
    // All queries MUST be awaited
    await (update(todoItems)
      ..where((row) => row.category.equals(category.id)))
      .write(const TodoItemsCompanion(category: Value(null)));
    await delete(categories).delete(category);
  });
}
```

### Common Transaction Mistakes

1. **Not awaiting queries**: Transaction commits when callback returns. Unawaited queries execute outside the transaction boundary — they may fail or lose atomicity.

2. **Creating UpdateStatement outside transaction, writing inside**: Can cause deadlocks (fixed in recent versions but still anti-pattern).

   ```dart
   // BAD
   final stmt = update(users)..where((u) => u.id.equals(1));
   await transaction(() async {
     await stmt.write(companion); // Statement was created outside transaction
   });
   ```

3. **Nested transaction behavior**: Since Drift 2.0, nested transactions use savepoints — writes in nested transactions are isolated until successful completion. Failed nested transactions revert while outer can continue.

4. **Accessing transaction after close**: Drift has runtime checks that throw exceptions for this misuse.

### Nested Transactions (since Drift 2.0)

- Supported on NativeDatabase, WasmDatabase, WebDatabase, SqfliteDatabase
- Writes in nested transactions are isolated until successful completion
- Failed nested transactions revert; outer transaction can catch and continue
- Previous versions (2.18-2.20.3) had deadlock issues with nested transactions — resolved in later versions

---

## 13. DAO Patterns

### Structure

```dart
@DriftAccessor(tables: [TodoItems, Categories])
class TodosDao extends DatabaseAccessor<AppDatabase> with _$TodosDaoMixin {
  TodosDao(super.attachedDatabase);

  Future<List<TodoItem>> getAllTodos() => select(todoItems).get();
  Stream<List<TodoItem>> watchAllTodos() => select(todoItems).watch();
  Future<int> insertTodo(TodoItemsCompanion companion) =>
    into(todoItems).insert(companion);
}
```

### Registration

```dart
@DriftDatabase(tables: [TodoItems, Categories], daos: [TodosDao])
class AppDatabase extends _$AppDatabase { ... }
```

- DAOs get their own generated getter on the database class
- Use `@DriftAccessor(tables: [...])` to declare which tables the DAO accesses
- Keep DAOs small and single-responsibility

### DAO Best Practices

- Each DAO should handle one domain area (auth, todos, settings)
- DAOs access tables through the mixin, not by importing the database class
- Expose typed methods, not raw queries
- Use named constructors for complex queries
- Stream methods should use `.watch()` for reactivity

---

## 14. Testing Patterns

### In-Memory Database

```dart
late AppDatabase db;

setUp(() {
  db = AppDatabase(NativeDatabase.memory());
});

tearDown(() async {
  await db.close();
});
```

### Critical for Widget Tests

```dart
// MUST use closeStreamsSynchronously to avoid timer leaks
db = AppDatabase(
  DatabaseConnection(
    NativeDatabase.memory(),
    closeStreamsSynchronously: true,
  ),
);
```

Without `closeStreamsSynchronously: true`, stream debouncing timers persist after test completion, causing "A Timer is still pending even after the widget was disposed" failures.

### Stream Testing

```dart
test('stream emits updates', () async {
  final stream = db.todosDao.watchAllTodos();
  expectLater(stream, emitsInOrder([isEmpty, hasLength(1)]));
  await db.todosDao.insertTodo(companion);
});
```

### Migration Testing

- Use `dart run drift_dev make-migrations` to generate test files
- Schema snapshots in JSON format verify migrations between all version pairs
- Requires SQLite installed on the development machine
- Generated tests verify: table creation, column additions, data preservation

---

## 15. Current Project State

### Existing Database Support

| Package | Rules                       | Status              |
| ------- | --------------------------- | ------------------- |
| Isar    | 21 specific + 7 shared = 28 | Fully implemented   |
| Hive    | 21 specific + 7 shared = 28 | Fully implemented   |
| sqflite | 2 specific + 7 shared = 9   | Minimal             |
| Drift   | 0 specific + 0 shared = 0   | **Not implemented** |

### Shared Database Rules (applied to ALL database packages)

```dart
const Set<String> _databaseSharedRules = <String>{
  'avoid_database_in_build',      // Don't query DB in build methods
  'require_database_migration',   // Require migration strategy
  'require_database_index',       // Suggest indexes for queries
  'prefer_transaction_for_batch', // Use transactions for multiple writes
  'require_yield_after_db_write', // Yield to UI after DB writes
  'suggest_yield_after_db_read',  // Consider yielding after bulk reads
  'avoid_return_await_db',        // Don't return await on DB calls
};
```

### Existing Drift References in Codebase

1. **ROADMAP.md line 136**: `#### Local Database (Hive/Isar/Drift)` — section header
2. **stylistic_rules.dart**: `.drift.dart` in `_generatedFileSuffixes` list (already excluded from linting)
3. **Task files**: Drift mentioned as context in several roadmap tasks:
   - `task_⚠️_prefer_sqflite_encryption.md`: "drift also supports encryption via drift_sqflite"
   - `task_⚠️_require_yield_after_db_write.md`: Lists Drift write methods
   - `task_⚠️_require_conflict_resolution_strategy.md`: Drift as offline-first trigger
4. **db_yield_rules.dart**: Already detects some Drift-like patterns heuristically (method names like `rawInsert`, `rawUpdate`, `rawDelete`)

### Package Registration Infrastructure

The `tiers.dart` file has the `packageRuleSets` map and `allPackages` list that needs a `'drift'` entry. The pattern is:

```dart
// In packageRuleSets getter:
'drift': driftPackageRules.union(_databaseSharedRules),

// In allPackages list:
'drift',
```

---

## 16. Shared Database Rules Gap Analysis

The project has 7 shared database rules (`_databaseSharedRules` in `tiers.dart`) that are unioned into every database package's rule set. These are supposed to apply to Drift too — but **most of them don't actually detect Drift patterns**.

### Rule-by-Rule Analysis

#### `require_yield_after_db_write` — PARTIAL Drift Support

**What it detects**: Awaited database write calls not followed by `yieldToUI()`.

**How it detects**: Uses explicit method name sets + heuristic keyword matching + known IO targets.

**Explicit write methods recognized** (from `db_yield_rules.dart` line 71):

```
writeTxn, deleteAll, putAll, rawInsert, rawUpdate, rawDelete, writeAsString, writeAsBytes
```

**Known IO targets** (line 172):

```
isar, database, db, box, store, collection
```

**Drift write patterns it MISSES**:

- `await into(todoItems).insert(companion)` — `into` is not a write method, and the chain `into().insert()` doesn't match
- `await (update(users)..where(...)).write(companion)` — `write` is in the keyword list but `update()` creates a builder, not an IO call
- `await batch((b) { b.insertAll(...); })` — `batch` is not in any list
- `await transaction(() async { ... })` — `transaction` is not recognized
- `await customUpdate('UPDATE ...')` — `customUpdate` is not in the explicit list (but `update` keyword would match via heuristic)

**Drift write patterns it CATCHES** (via heuristic):

- `await db.saveUser(user)` — matches `db` target + `save` keyword
- `await database.insertRecord(record)` — matches `database` target + `insert` keyword

**Verdict**: Works for wrapper methods that follow naming conventions (e.g., `db.saveUser()`), but misses Drift's native fluent API entirely.

#### `suggest_yield_after_db_read` — PARTIAL Drift Support

**Explicit bulk read methods**: `findAll, rawQuery, readAsString, readAsBytes, readAsLines, loadJsonFromAsset`

**Drift read patterns it MISSES**:

- `await select(users).get()` — `get` is in keyword list but `select` creates a builder
- `await customSelect('SELECT ...').get()` — `customSelect` not recognized as IO target
- `select(users).watch()` — streaming, not awaited at all

**Drift read patterns it CATCHES** (via heuristic):

- `await db.fetchAllUsers()` — matches `db` target + `fetch` keyword
- `await database.getSettings()` — matches `database` target + `get` keyword

#### `avoid_return_await_db` — PARTIAL Drift Support

Same detection as above — only catches Drift patterns when using wrapper methods with recognized target names and keyword-containing method names.

#### `avoid_database_in_build` — PARTIAL Drift Support

**Located in**: `firebase_rules.dart` lines 97-220

**Detection**: Looks for method chains containing patterns from `_databasePatterns`:

```
collection, collectionGroup, rawQuery, query, database, firestore
```

...followed by `.get()` or `.snapshots()` inside `FutureBuilder`/`StreamBuilder` in `build()` methods.

**Drift patterns it MISSES**:

- `.watch()` — only checks for `.get()` and `.snapshots()`
- `customSelect(...)` chains — no pattern match for `customSelect`
- Drift accessor names like `.todoItems`, `.users` — not in pattern set
- `select(table)` — not in pattern set

**Drift patterns it CATCHES**:

- `db.rawQuery('SELECT ...')` inside FutureBuilder — matches `rawQuery` pattern

#### `require_database_migration` — NO Drift Support

**Located in**: `firebase_rules.dart` lines 400-502

**How it works**: Checks for `@HiveType` classes with ≥5 `@HiveField` annotations, or `@collection`/`@Collection` Isar classes, lacking version/migration keywords in source.

**Drift**: Completely missed. Drift tables extend `Table` (no annotations). Drift migrations use `MigrationStrategy` (code-based, not annotation-based). This rule has zero Drift detection capability.

#### `require_database_index` — NO Drift Support

**Located in**: `firebase_rules.dart` lines 504-609

**How it works**: Looks for `filter`, `where`, `query`, `find` methods containing filter patterns like `EqualTo`, `GreaterThan`. Suggests `@Index()` annotation.

**Drift**: Drift indexes are defined in schema builders or `.drift` SQL files, not via `@Index()` annotations. Drift's where clauses use `.equals()`, `.isBiggerThan()`, etc. — different from the patterns this rule looks for. The `@Index()` suggestion in the correction message is wrong for Drift.

#### `prefer_transaction_for_batch` — UNKNOWN Drift Support

Needs investigation. Likely uses heuristic detection of multiple sequential write calls that should be wrapped in a transaction.

### Summary: Shared Rules Effectiveness for Drift

| Shared Rule                    | Drift Support | Issue                                                      |
| ------------------------------ | ------------- | ---------------------------------------------------------- |
| `require_yield_after_db_write` | ⚠️ Partial    | Misses Drift's fluent builder API; catches wrapper methods |
| `suggest_yield_after_db_read`  | ⚠️ Partial    | Same — fluent API invisible                                |
| `avoid_return_await_db`        | ⚠️ Partial    | Same                                                       |
| `avoid_database_in_build`      | ⚠️ Partial    | Misses `.watch()`, Drift-specific accessors                |
| `require_database_migration`   | ❌ None       | Hardcoded for Hive/Isar annotations                        |
| `require_database_index`       | ❌ None       | Assumes `@Index()` annotations                             |
| `prefer_transaction_for_batch` | ❓ Unknown    | Needs investigation                                        |

### Impact

The claim "28 effective rules (21 Drift-specific + 7 shared)" is **misleading**. In practice, only 2-3 shared rules will fire for Drift code, and only when developers use wrapper methods with conventional naming (e.g., `db.saveUser()`) rather than Drift's native fluent API.

### Recommended Actions

1. **Add Drift methods to `db_yield_rules.dart`** — Add `transaction`, `batch`, `customSelect`, `customUpdate`, `customStatement` to the explicit method lists. This is low-effort, high-impact.
2. **Add `.watch()` to `avoid_database_in_build`** — Currently only checks `.get()` and `.snapshots()`.
3. **Accept limitations** — `require_database_migration` and `require_database_index` can't easily be extended for Drift; rely on Drift-specific rules instead.
4. **Update documentation** — Be honest about effective rule count.

---

## 17. Proposed Rules (21 rules)

### Tier Distribution

| Tier          | Count  | Focus                                         |
| ------------- | ------ | --------------------------------------------- |
| Essential     | 1      | Data corruption prevention                    |
| Recommended   | 7      | Runtime safety, security, resource management |
| Professional  | 6      | Performance, platform, query efficiency       |
| Comprehensive | 7      | Schema safety, advanced patterns, edge cases  |
| **Total**     | **21** | + 7 shared = **28 effective rules**           |

---

### ESSENTIAL TIER (1 rule)

#### Rule 1: `avoid_drift_enum_index_reorder`

**Severity**: ERROR
**Impact**: high
**Cost**: medium
**OWASP**: N/A (data integrity)

**Problem**: Drift's `intEnum` type converter and custom `TypeConverter<EnumType, int>` classes that use `.index` store enums by their ordinal position. If enum values are reordered or new values are inserted before existing ones, all persisted data silently maps to wrong enum values. This is the same class of bug as Isar's enum corruption — the #1 most dangerous database anti-pattern.

**Detection strategy**:

1. Find classes extending `TypeConverter` where the SQL type is `int`
2. Check if `toSql` method body contains `.index` on the first type parameter
3. Also find `intEnum<T>()` column definitions (built-in enum converter)
4. Flag `EnumType.values[fromDb]` in `fromSql` methods (index-based lookup)

**AST patterns to detect**:

- `class Foo extends TypeConverter<MyEnum, int>` where `toSql` returns `.index`
- `intEnum<MyEnum>()` column builder call
- `MyEnum.values[variable]` in TypeConverter subclass

**False positive risks**:

- Enums with explicit integer values stored via `.code` property (not `.index`) — should NOT flag
- `textEnum<MyEnum>()` — stores by name, safe — should NOT flag

**Bad**:

```dart
class PriorityConverter extends TypeConverter<Priority, int> {
  @override
  Priority fromSql(int fromDb) => Priority.values[fromDb];
  @override
  int toSql(Priority value) => value.index;
}
```

**Good**:

```dart
// By name (immune to reordering)
class PriorityConverter extends TypeConverter<Priority, String> {
  @override
  Priority fromSql(String fromDb) =>
    Priority.values.firstWhere((e) => e.name == fromDb);
  @override
  String toSql(Priority value) => value.name;
}

// By explicit code (immune to reordering)
enum Priority {
  low(0), medium(10), high(20), urgent(30);
  const Priority(this.code);
  final int code;
}
class PriorityConverter extends TypeConverter<Priority, int> {
  @override
  Priority fromSql(int fromDb) => Priority.values.firstWhere((e) => e.code == fromDb);
  @override
  int toSql(Priority value) => value.code;
}
```

**Edge cases**:

- What if `toSql` calls a helper method that returns `.index`? (Hard to trace through function calls — accept false negative)
- What if the enum has `@Deprecated` values that are never removed? (Still dangerous)
- What about Drift's built-in `textEnum<T>()` converter? (Safe, don't flag)

---

### RECOMMENDED TIER (7 rules)

#### Rule 2: `require_drift_database_close`

**Severity**: WARNING
**Impact**: high
**Cost**: medium

**Problem**: Drift database instances hold file handles, isolate connections, and stream query tracking. Not calling `.close()` causes resource leaks, prevents database reopening, and can corrupt data if the process exits during a write.

**Detection strategy**:

1. Find class fields whose type name matches common Drift database patterns: ends with `Database`, or initializer calls `driftDatabase()` / `NativeDatabase` / `WasmDatabase`
2. Check if the enclosing class has a `dispose()` method that calls `.close()` on the database field
3. Only flag in widget-like classes (classes with `dispose` methods or extending `State`)

**AST patterns to detect**:

- Field declaration where type name contains `Database` (heuristic) or initializer contains `NativeDatabase`, `WasmDatabase`, `driftDatabase`
- Check class members for `dispose` method
- Check dispose body for `fieldName.close()` or `fieldName?.close()`

**False positive risks**:

- Non-Drift classes that happen to have `Database` in their name
- Databases managed by a DI container (GetIt, Riverpod) that handles lifecycle elsewhere
- Singleton patterns where close is called from a different class

**Mitigation**: Only flag in classes that have a `dispose` method (State classes, Controller classes) to limit scope.

---

#### Rule 3: `avoid_drift_update_without_where`

**Severity**: WARNING
**Impact**: critical
**Cost**: low

**Problem**: `update(table)` or `delete(table)` without `.where()` affects ALL rows. Drift docs explicitly warn about this.

**Detection strategy**:

1. Find `MethodInvocation` where method is `go` (terminal for delete) or `write` (terminal for update)
2. Walk the method chain backward (via `target` property) to find the originating `update(table)` or `delete(table)` call
3. Check if `.where()` appears anywhere in the chain
4. If no `.where()` found, flag

**AST patterns**:

- `delete(table).go()` — no where clause
- `(update(table)..write(companion))` — cascade without where
- `update(table).replace(row)` — `replace` is intentionally whole-table, might be OK?

**False positive risks**:

- `replace()` method intentionally replaces a single row by primary key — should NOT flag
- `deleteAll()` is an intentional "delete everything" — might be intentional
- `customUpdate` / `customStatement` with DELETE/UPDATE — handled by different rule

**Edge cases**:

- Cascade notation `..where()..write()` vs chained `.where().write()`
- What if `where` is called conditionally? (Hard to detect statically)

---

#### Rule 4: `require_await_in_drift_transaction`

**Severity**: WARNING
**Impact**: high
**Cost**: medium

**Problem**: Inside `transaction(() async { ... })`, all queries must be awaited. Unawaited futures execute outside the transaction boundary.

**Detection strategy**:

1. Find `MethodInvocation` where method name is `transaction`
2. Get the callback argument (first positional, should be `FunctionExpression`)
3. Inside the callback body, find `ExpressionStatement` nodes containing `MethodInvocation` for known Drift query methods (`insert`, `write`, `go`, `get`, `getSingle`, `delete`)
4. Check if the expression is preceded by `await` keyword
5. Flag if not awaited

**AST patterns**:

- `transaction(() async { into(table).insert(c); })` — missing await on insert
- `transaction(() async { update(table).write(c); })` — missing await on write

**False positive risks**:

- Intentionally fire-and-forget operations inside transactions (rare but possible)
- Methods that don't return Future (synchronous operations)
- `.then()` chains (technically awaited differently)

**Implementation note**: The existing `avoid_unawaited_futures` rule (if it exists in the project) may partially overlap. Check if this is already covered by the generic async rules.

---

#### Rule 5: `require_drift_foreign_key_pragma`

**Severity**: WARNING
**Impact**: high
**Cost**: medium

**Problem**: SQLite does NOT enforce foreign keys by default. Without `PRAGMA foreign_keys = ON`, all foreign key constraints declared in table definitions are silently ignored.

**Detection strategy**:

1. Find classes whose superclass name starts with `_$` (Drift generated superclass pattern)
2. Check if the class has a `migration` getter that returns `MigrationStrategy`
3. Check if `MigrationStrategy` has a `beforeOpen` callback
4. Check if the `beforeOpen` callback body contains `foreign_keys`
5. Flag if no foreign key pragma found

**AST patterns**:

- Class extending `_$AppDatabase` without `migration` getter → flag
- Class with `migration` getter but no `beforeOpen` → flag
- Class with `beforeOpen` that doesn't set `foreign_keys` → flag

**False positive risks**:

- Projects that intentionally don't use foreign keys (rare)
- Projects that set foreign keys in a base class or mixin
- Tables without any foreign key references (pragma is unnecessary)

**Edge case**: Should we only flag when tables have `.references()` columns? That would be more accurate but harder to detect cross-file.

---

#### Rule 6: `avoid_drift_raw_sql_interpolation`

**Severity**: ERROR
**Impact**: critical
**Cost**: low
**OWASP**: A03:2021-Injection

**Problem**: SQL injection. String interpolation in `customSelect`, `customStatement`, `customUpdate` allows arbitrary SQL execution.

**Detection strategy**:

1. Find `MethodInvocation` where method name is `customSelect`, `customStatement`, or `customUpdate`
2. Check the first positional argument
3. If it's a `StringInterpolation` node (contains `$variable` or `${expression}`), flag
4. Also check for string concatenation: `'SELECT * FROM ' + tableName`

**AST patterns**:

- `customSelect('SELECT * FROM users WHERE id = $id')` — interpolation
- `customSelect('SELECT * FROM users WHERE name = "$name"')` — interpolation in quotes
- `customStatement('DROP TABLE ' + tableName)` — concatenation

**False positive risks**:

- Interpolation of table/column NAMES (not values) — still technically dangerous
- Constants interpolated (e.g., `'SELECT * FROM $tableName'` where tableName is const) — less risky but still bad practice
- Template strings used for readability with hardcoded values (no user input)

**Decision**: Flag ALL interpolation in raw SQL methods. Even "safe" interpolation of constants is a bad pattern that can be copy-pasted into unsafe contexts.

---

#### Rule 7: `prefer_drift_batch_operations`

**Severity**: WARNING
**Impact**: medium
**Cost**: low

**Problem**: Individual `into(table).insert()` calls in a loop are dramatically slower than `batch((b) { b.insertAll(...); })`.

**Detection strategy**:

1. Find `MethodInvocation` where method is `insert` and target chain includes `into(...)`
2. Check if inside a `ForStatement`, `ForElement`, `ForEachParts`, or `.forEach()` callback
3. Flag if found inside a loop

**AST patterns**:

- `for (final item in items) { await into(table).insert(item); }`
- `items.forEach((item) { into(table).insert(item); })`
- `for (var i = 0; i < n; i++) { await into(table).insert(items[i]); }`

**False positive risks**:

- Loop that inserts into DIFFERENT tables on each iteration (might be intentional)
- Loops with <3 iterations (batch overhead not worth it)
- `insertOnConflictUpdate` in loop (batch supports this too, but pattern is different)

---

#### Rule 8: `require_drift_stream_cancel`

**Severity**: WARNING
**Impact**: high
**Cost**: medium

**Problem**: Drift stream queries tracked internally. Uncancelled subscriptions leak memory and re-execute on every table change.

**Detection strategy**:

1. Find `MethodInvocation` where method is `listen`
2. Check if target chain contains `.watch()`, `.watchSingle()`, or `.watchSingleOrNull()`
3. Check if result is assigned to a field (stored subscription)
4. Check if enclosing class has `dispose()` that calls `.cancel()` on that field

**Implementation note**: This overlaps significantly with the existing `require_stream_subscription_cancel` or similar disposal rules. Check if existing rules already cover this pattern. If so, this rule might not be needed as a Drift-specific rule.

---

### PROFESSIONAL TIER (6 rules)

#### Rule 9: `avoid_drift_database_on_main_isolate`

**Severity**: INFO
**Impact**: medium
**Cost**: low

**Problem**: SQLite blocks the current isolate. On mobile, this causes UI jank.

**Detection strategy**:

1. Find `InstanceCreationExpression` for `NativeDatabase`
2. Check if it's the basic constructor (not `.createInBackground()` or `.createBackgroundConnection()`)
3. Skip if in test files
4. Flag

**False positive risks**:

- Desktop apps where main isolate blocking is acceptable
- Very simple databases with tiny queries
- Already using `drift_flutter`'s `driftDatabase()` which handles isolation internally

---

#### Rule 10: `avoid_drift_log_statements_production`

**Severity**: WARNING
**Impact**: high
**Cost**: low

**Problem**: `logStatements: true` leaks SQL + data values in production logs.

**Detection strategy**:

1. Find `NamedExpression` where `name.label.name == 'logStatements'`
2. Check if value is `BooleanLiteral(true)`
3. Check if NOT inside `kDebugMode` / `kProfileMode` guard (use `usesFlutterModeConstants` utility)
4. Flag if `true` without debug guard

**Implementation note**: This pattern is identical to `require_isar_inspector_debug_only`. Use the same `mode_constants_utils.dart` utility.

---

#### Rule 11: `avoid_drift_get_single_without_unique`

**Severity**: INFO
**Impact**: medium
**Cost**: medium

**Problem**: `getSingle()` / `watchSingle()` throw if query returns 0 or >1 rows.

**Detection strategy**:

1. Find `MethodInvocation` for `getSingle` or `watchSingle`
2. Walk target chain to check for `.where()` clause
3. If no `.where()` at all, flag (very likely to return multiple rows)
4. If `.where()` exists but doesn't filter by `id` or unique column, consider flagging (heuristic)

**Decision**: Start with the simpler version — only flag when NO `.where()` is present. Detecting whether the where clause guarantees uniqueness is too complex for v1.

---

#### Rule 12: `prefer_drift_use_columns_false`

**Severity**: INFO
**Impact**: low
**Cost**: medium

**Problem**: Joined tables read all columns by default even when not needed.

**Detection difficulty**: HIGH. Would need to trace:

1. Which tables are joined
2. Which table columns are actually read in the result mapping
3. Whether `useColumns: false` is already set

**Decision**: This might be too complex for reliable static analysis. Consider deferring to a later version or implementing a simplified version that only flags joins without `useColumns` parameter at all (letting the developer decide).

---

#### Rule 13: `avoid_drift_lazy_database`

**Severity**: INFO
**Impact**: medium
**Cost**: low

**Problem**: `LazyDatabase` loses stream synchronization with isolates.

**Detection strategy**:

1. Find `InstanceCreationExpression` for `LazyDatabase`
2. Check if the callback body references `DriftIsolate`, `Isolate`, or `compute`
3. Flag if isolate usage detected inside LazyDatabase

**False positive risks**:

- `LazyDatabase` used without isolates (perfectly fine, no flag needed)
- The fix (`DatabaseConnection.delayed`) may not always be a drop-in replacement

---

#### Rule 14: `prefer_drift_isolate_sharing`

**Severity**: INFO
**Impact**: medium
**Cost**: medium

**Problem**: Multiple independent database instances on same file break stream sync.

**Detection strategy**:

1. Find `NativeDatabase(File('path'))` calls
2. Check if the same string path appears in multiple locations
3. Flag if duplicate path found without singleton pattern

**Detection difficulty**: MEDIUM. Cross-expression analysis within a file is feasible. Cross-file analysis is much harder.

---

### COMPREHENSIVE TIER (7 rules)

#### Rule 15: `avoid_drift_query_in_migration`

**Severity**: WARNING
**Impact**: high
**Cost**: medium

**Problem**: High-level query APIs inside `onUpgrade` use latest schema, but DB is still on old schema during migration.

**Detection strategy**:

1. Find the `onUpgrade` callback in `MigrationStrategy`
2. Inside that callback, find `MethodInvocation` for `select`, `update`, `delete`, `into`
3. Flag each one

**AST patterns**:

- `MigrationStrategy(onUpgrade: (m, from, to) async { await select(users).get(); })`
- Named expression `onUpgrade:` → function body → method invocations

**False positive risks**:

- `customSelect` and `customStatement` are safe in migrations (raw SQL, not generated)
- `migrator.createTable()`, `migrator.addColumn()` etc. are safe (designed for migrations)

---

#### Rule 16: `require_drift_schema_version_bump`

**Severity**: INFO
**Impact**: medium
**Cost**: high

**Detection difficulty**: VERY HIGH. Would need to compare current table definitions against the schema version to determine if changes were made without bumping.

**Simplified approach**: Flag `schemaVersion => 1` when the database has >2 tables (suggesting it's not a fresh project). This is a very rough heuristic.

**Decision**: Implement as a simple "informational" rule with high false positive tolerance, or defer entirely.

---

#### Rule 17: `avoid_drift_foreign_key_in_migration`

**Severity**: INFO
**Impact**: medium
**Cost**: low

**Problem**: `PRAGMA foreign_keys` silently fails inside migration transactions.

**Detection strategy**:

1. Inside `onUpgrade` or `onCreate` callbacks
2. Find `customStatement` calls
3. Check if string argument contains `foreign_keys`
4. Flag

**Straightforward detection** — similar to rule 5 but inverse (detecting the WRONG location).

---

#### Rule 18: `require_drift_reads_from`

**Severity**: INFO
**Impact**: medium
**Cost**: low

**Problem**: `customSelect(...).watch()` without `readsFrom` → stream never updates.

**Detection strategy**:

1. Find `.watch()` or `.watchSingle()` calls
2. Check if target is result of `customSelect`
3. Check if `customSelect` call has `readsFrom` named parameter
4. Flag if missing

**Good detection confidence** — clear AST pattern.

---

#### Rule 19: `avoid_drift_unsafe_web_storage`

**Severity**: INFO
**Impact**: medium
**Cost**: low

**Problem**: `unsafeIndexedDb` and `WebDatabase` without shared workers are not multi-tab safe.

**Detection strategy**:

1. Find references to `unsafeIndexedDb` identifier
2. Find `WebDatabase(...)` constructor calls
3. Flag

**False positive risks**:

- Apps that explicitly only support single-tab usage
- Server-side Dart where multi-tab isn't relevant

---

#### Rule 20: `avoid_drift_close_streams_in_tests`

**Severity**: INFO
**Impact**: low
**Cost**: low

**Problem**: Missing `closeStreamsSynchronously: true` causes timer leaks in tests.

**Detection strategy**:

1. Only in test files (`_test.dart` suffix)
2. Find `NativeDatabase.memory()` calls
3. Check if wrapped in `DatabaseConnection(...)` with `closeStreamsSynchronously: true`
4. Flag if direct `NativeDatabase.memory()` without the wrapper

---

#### Rule 21: `avoid_drift_nullable_converter_mismatch`

**Severity**: INFO
**Impact**: medium
**Cost**: medium

**Problem**: `TypeConverter<Foo?, int?>` (both nullable) applied to non-nullable column.

**Detection strategy** (simplified):

1. Find classes extending `TypeConverter`
2. Check if BOTH type parameters end with `?` (nullable)
3. Flag — this pattern is almost always wrong

**Full detection** would require tracing usage sites where converter is applied to columns, which is cross-expression analysis. The simplified version catches the most common mistake.

---

## 18. Additional Rule Candidates

Rules we identified during gap analysis that aren't in the original 21 but have strong justification. These could be added in a second pass or used to replace lower-confidence rules.

### `avoid_drift_value_null_vs_absent`

**Severity**: WARNING | **Impact**: high | **Cost**: medium

**Problem**: Drift's `Companion` classes use `Value<T>` wrappers. `Value(null)` means "set this column to NULL". `Value.absent()` means "don't touch this column". Confusing the two causes:

- `Value(null)` on a non-nullable column → runtime crash
- `Value.absent()` when you meant to clear a value → data not updated
- `Value(null)` in an insert → null violation if column has no default

This is one of the most common Drift mistakes in StackOverflow questions.

**Detection strategy**:

1. Find `InstanceCreationExpression` for `Value` with `null` argument: `Value(null)` or `Value<String>(null)`
2. If the column is non-nullable (hard to determine statically), flag
3. Simpler heuristic: flag `Value(null)` and suggest reviewing whether `Value.absent()` was intended

**Bad**:

```dart
// Tries to set non-nullable 'title' to null → runtime crash
await (update(todoItems)..where((t) => t.id.equals(id)))
  .write(TodoItemsCompanion(title: Value(null)));
```

**Good**:

```dart
// Don't touch title, only update 'completed'
await (update(todoItems)..where((t) => t.id.equals(id)))
  .write(TodoItemsCompanion(
    title: Value.absent(),  // Leave unchanged
    completed: Value(true),
  ));
```

**Confidence**: Medium — hard to distinguish intentional `Value(null)` on nullable columns from mistakes on non-nullable columns without type resolution.

---

### `require_drift_equals_value`

**Severity**: WARNING | **Impact**: high | **Cost**: low

**Problem**: When a column uses a `TypeConverter`, the `.equals()` method expects the raw SQL value (not the Dart type). You must use `.equalsValue()` to apply the converter automatically. Using `.equals()` with the Dart value produces queries that never match — a silent, hard-to-debug failure.

**Detection strategy**:

1. Find `.equals(value)` calls on Drift column expressions
2. Check if the column has a `.map(converter)` modifier (hard without type resolution)
3. Simpler heuristic: flag `.equals()` when the argument is an enum value (enums almost always use converters)

**Bad**:

```dart
// SILENTLY FAILS: Status.active is a Dart enum, not the SQL int
(select(users)..where((u) => u.status.equals(Status.active))).get();
// Generates: WHERE status = 'Status.active' (wrong!)
```

**Good**:

```dart
// equalsValue() runs the TypeConverter first
(select(users)..where((u) => u.status.equalsValue(Status.active))).get();
// Generates: WHERE status = 1 (correct!)
```

**Confidence**: Medium — detecting which columns have converters is hard without full type resolution. The enum heuristic catches the most common case.

---

### `avoid_drift_replace_without_all_columns`

**Severity**: INFO | **Impact**: medium | **Cost**: medium

**Problem**: `replace()` replaces the ENTIRE row. Any column not specified in the companion becomes its default value (or null for nullable columns). Developers often confuse `replace()` with `write()` (which only updates specified columns), causing unexpected data loss.

**Detection strategy**:

1. Find `.replace(companion)` method calls on Drift update builders
2. This is primarily a documentation/awareness rule — hard to detect misuse statically
3. Could flag `replace()` calls and suggest verifying all columns are set, or suggest using `write()` instead

**Bad**:

```dart
// LOSES DATA: email, avatar, etc. become null/default
await (update(users)..where((u) => u.id.equals(id)))
  .replace(UsersCompanion(name: Value('New Name')));
// Only name is set; all other columns reset!
```

**Good**:

```dart
// Only updates name, leaves everything else untouched
await (update(users)..where((u) => u.id.equals(id)))
  .write(UsersCompanion(name: Value('New Name')));
```

**Confidence**: Low — hard to determine if `replace()` is intentional without understanding the developer's intent. Consider as INFO only.

---

### `avoid_drift_concurrent_write_contention`

**Severity**: INFO | **Impact**: medium | **Cost**: medium

**Problem**: SQLite allows only one writer at a time. Without WAL mode and `busy_timeout`, concurrent writes from multiple isolates or database instances cause `SQLITE_BUSY` errors. Drift's default `NativeDatabase` doesn't set these pragmas automatically.

**Detection strategy**:

1. Find `NativeDatabase` constructors
2. Check if the `setup` callback sets `PRAGMA journal_mode = WAL` and `PRAGMA busy_timeout`
3. Only flag when `DriftIsolate` or `Isolate.spawn` is also used in the project (suggesting concurrent access)

**Bad**:

```dart
// No WAL mode + multiple isolates = SQLITE_BUSY errors
final db1 = NativeDatabase(File('app.db'));
final db2 = NativeDatabase(File('app.db')); // Different isolate
```

**Good**:

```dart
NativeDatabase(File('app.db'), setup: (db) {
  db.execute('PRAGMA journal_mode = WAL');
  db.execute('PRAGMA busy_timeout = 5000');
});
```

**Confidence**: Low — multi-isolate detection is cross-file analysis. Consider deferring.

---

### `avoid_drift_fts_without_rebuild`

**Severity**: INFO | **Impact**: low | **Cost**: medium

**Problem**: Drift supports FTS3/FTS5 (Full-Text Search) virtual tables. FTS indexes must be rebuilt after bulk operations or migrations. Forgetting to rebuild causes stale search results.

**Detection strategy**: Find FTS table definitions (heuristic: table names containing `Fts` or `Search`, or `CREATE VIRTUAL TABLE` in `.drift` files). Flag if no `rebuild` command is found in migration callbacks.

**Confidence**: Low — FTS usage is rare and hard to detect reliably. Consider deferring.

---

### `require_drift_error_handling`

**Severity**: INFO | **Impact**: medium | **Cost**: medium

**Problem**: Database operations can throw (`SqliteException`, `StateError` from `getSingle()`, etc.). Unhandled exceptions crash the app. Critical database operations should have try/catch with appropriate error recovery.

**Detection strategy**: Find `await db.transaction(...)`, `await db.customStatement(...)` etc. without enclosing try/catch.

**Confidence**: Low — not every database call needs try/catch (some are in already-guarded contexts). Too many false positives to be useful. Consider as opt-in/pedantic only.

---

### Summary: Additional Rule Candidates

| Rule                                      | Tier          | Confidence | Recommendation                            |
| ----------------------------------------- | ------------- | ---------- | ----------------------------------------- |
| `avoid_drift_value_null_vs_absent`        | Recommended   | Medium     | **Add to main 21** — very common mistake  |
| `require_drift_equals_value`              | Recommended   | Medium     | **Add to main 21** — silent query failure |
| `avoid_drift_replace_without_all_columns` | Professional  | Low        | Defer — hard to detect intent             |
| `avoid_drift_concurrent_write_contention` | Comprehensive | Low        | Defer — cross-file analysis needed        |
| `avoid_drift_fts_without_rebuild`         | Comprehensive | Low        | Defer — rare usage                        |
| `require_drift_error_handling`            | Pedantic      | Low        | Defer — too many false positives          |

**Recommendation**: Add `avoid_drift_value_null_vs_absent` and `require_drift_equals_value` to the main rule set (bringing total to 23), or swap out the two lowest-confidence existing rules (12: `prefer_drift_use_columns_false` and 16: `require_drift_schema_version_bump`).

---

## 19. Detection Strategy

### Heuristic Approach (matching existing patterns)

Since Drift is an optional dependency (not in saropa_lints' own deps), rules use method name + context heuristics rather than full type resolution. This matches the approach used for all 21 Isar rules, 21 Hive rules, and other package-specific rules.

### Import Confirmation

Many rules should additionally check for `import 'package:drift/drift.dart'` or `import 'package:drift/native.dart'` to reduce false positives from similarly-named methods in non-Drift code. This is especially important for generic method names like `transaction`, `select`, `update`, `delete`, `watch`.

**Utility function needed:**

```dart
bool _hasDriftImport(CompilationUnit unit) {
  for (final directive in unit.directives) {
    if (directive is ImportDirective) {
      final uri = directive.uri.stringValue ?? '';
      if (uri.startsWith('package:drift/')) return true;
    }
  }
  return false;
}
```

### Key Detection Heuristics

| Pattern          | What to Look For                                        | Confidence                  |
| ---------------- | ------------------------------------------------------- | --------------------------- |
| Database class   | Superclass starts with `_$`, has `schemaVersion` getter | High                        |
| Table class      | Extends `Table`, has column builder methods             | High                        |
| DAO class        | Extends `DatabaseAccessor`, has `@DriftAccessor`        | High                        |
| Transaction      | `transaction(() async { ... })` method call             | Medium (generic name)       |
| Raw SQL          | `customSelect`, `customStatement`, `customUpdate`       | High (unique names)         |
| Stream query     | `.watch()`, `.watchSingle()` on select result           | Medium (could be non-Drift) |
| Migration        | `MigrationStrategy`, `onUpgrade`, `beforeOpen`          | High (unique names)         |
| Type converter   | Class extending `TypeConverter` with `fromSql`/`toSql`  | High                        |
| Batch            | `batch((b) { ... })` method call                        | Medium (generic name)       |
| `NativeDatabase` | Constructor calls                                       | High (unique name)          |
| `LazyDatabase`   | Constructor calls                                       | High (unique name)          |
| `WebDatabase`    | Constructor calls                                       | High (unique name)          |

### Import-Gated Rules

These rules MUST check for Drift import before flagging (method names too generic):

- `require_await_in_drift_transaction` — `transaction` is a common method name
- `avoid_drift_update_without_where` — `update`, `delete`, `write` are generic
- `prefer_drift_batch_operations` — `insert` is generic
- `avoid_drift_get_single_without_unique` — `getSingle` is generic

These rules DON'T need import check (method names are Drift-specific):

- `avoid_drift_raw_sql_interpolation` — `customSelect` etc. are unique
- `avoid_drift_database_on_main_isolate` — `NativeDatabase` is unique
- `avoid_drift_lazy_database` — `LazyDatabase` is unique

---

## 20. Files to Create / Modify

### New Files

| File                                      | Purpose                   | Estimated Size |
| ----------------------------------------- | ------------------------- | -------------- |
| `lib/src/rules/packages/drift_rules.dart` | All 21 Drift rule classes | ~1,700 lines   |
| `doc/guides/using_with_drift.md`          | End-user guide            | ~300 lines     |

### Modified Files

| File                           | Change                                                                                  | Lines Added |
| ------------------------------ | --------------------------------------------------------------------------------------- | ----------- |
| `lib/src/rules/all_rules.dart` | Add `export 'packages/drift_rules.dart';`                                               | 1           |
| `lib/saropa_lints.dart`        | Add 21 rule factories to `_allRuleFactories`                                            | 21          |
| `lib/src/tiers.dart`           | Add `driftPackageRules` set, tier entries, `packageRuleSets` entry, `allPackages` entry | ~40         |
| `ROADMAP.md`                   | Add 21 rules under "Local Database" section                                             | ~25         |
| `CHANGELOG.md`                 | Add entry under `[Unreleased]`                                                          | ~5          |

### Future Test Files

| File                                                  | Purpose                       |
| ----------------------------------------------------- | ----------------------------- |
| `test/drift_rules_test.dart`                          | Unit tests for all 21 rules   |
| `example_packages/lib/drift/`                         | Test fixture directory        |
| `example_packages/lib/drift/drift_rules_fixture.dart` | Bad/good examples for testing |

---

## 21. Implementation Notes

### Registration Checklist (per rule)

Three registration steps are required for EVERY rule (missing any = test failure):

1. **Rule class** in `lib/src/rules/packages/drift_rules.dart`
2. **Factory** in `_allRuleFactories` list in `lib/saropa_lints.dart` (~line 157+) — add `MyRuleClass.new`
3. **Tier assignment** in `lib/src/tiers.dart` — add `'rule_name'` to correct tier set

### Package Infrastructure (one-time setup)

4. Add `driftPackageRules` constant set in `tiers.dart` (after `sqflitePackageRules`)
5. Add `'drift': driftPackageRules.union(_databaseSharedRules)` to `packageRuleSets` getter
6. Add `'drift'` to `allPackages` list
7. Add `export 'packages/drift_rules.dart';` to `all_rules.dart`

### Rule Class Pattern

Every rule follows this exact structure:

```dart
class AvoidDriftFooRule extends SaropaLintRule {
  AvoidDriftFooRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.{critical|high|medium|low};

  @override
  RuleCost get cost => RuleCost.{low|medium|high};

  // Optional: restrict to widget files only
  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    'avoid_drift_foo',  // Must match tier entry exactly
    '[avoid_drift_foo] Problem message >200 chars describing what goes wrong and why it matters. Include consequences. {v1}',
    correctionMessage: 'How to fix this issue.',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      // Detection logic
      if (condition) {
        reporter.atNode(node.methodName, code);
      }
    });
  }
}
```

### Key requirements:

- Problem message starts with `[rule_name]` prefix
- Problem message >200 characters total
- Problem message ends with `{v1}` version tag
- `correctionMessage` is required
- `impact` and `cost` overrides are required
- Use `runWithReporter` (not `run`)
- Use `SaropaDiagnosticReporter` and `SaropaContext` (not `ErrorReporter` and `CustomLintContext`)

### Registry Methods Available

- `context.addMethodInvocation((MethodInvocation node) { ... })` — for method calls
- `context.addClassDeclaration((ClassDeclaration node) { ... })` — for class definitions
- `context.addFieldDeclaration((FieldDeclaration node) { ... })` — for fields
- `context.addInstanceCreationExpression((InstanceCreationExpression node) { ... })` — for constructors
- `context.addPropertyAccess((PropertyAccess node) { ... })` — for property access
- `context.addVariableDeclaration((VariableDeclaration node) { ... })` — for variables

### Batch Implementation Strategy

Since this is ~1,700 lines, implement in batches:

**Batch 1** (highest value): Rules 1-8 (Essential + Recommended)

- Core data safety, SQL injection, resource management

**Batch 2**: Rules 9-14 (Professional)

- Performance, platform, query patterns

**Batch 3**: Rules 15-21 (Comprehensive)

- Migration safety, web, testing, type converters

**Batch 4**: Documentation & tests

- `using_with_drift.md`, ROADMAP, CHANGELOG, test fixtures

---

## 22. Priority Scoring & Effort Estimates

### Priority Scoring

Each rule scored on three axes (1-5 each, max 15):

- **Value**: How much does this rule prevent real bugs? (5 = prevents data loss/security breach)
- **Confidence**: How reliably can we detect the pattern? (5 = unambiguous AST match)
- **Effort**: How easy is implementation? (5 = <50 lines, clear pattern; 1 = >150 lines, complex analysis)

| #   | Rule                                      | Value | Confidence | Effort | **Total** | Est. Lines |
| --- | ----------------------------------------- | ----- | ---------- | ------ | --------- | ---------- |
| 1   | `avoid_drift_enum_index_reorder`          | 5     | 4          | 3      | **12**    | ~80        |
| 6   | `avoid_drift_raw_sql_interpolation`       | 5     | 5          | 5      | **15**    | ~30        |
| 3   | `avoid_drift_update_without_where`        | 5     | 4          | 3      | **12**    | ~60        |
| 4   | `require_await_in_drift_transaction`      | 4     | 4          | 3      | **11**    | ~70        |
| 10  | `avoid_drift_log_statements_production`   | 4     | 5          | 5      | **14**    | ~30        |
| 7   | `prefer_drift_batch_operations`           | 3     | 4          | 5      | **12**    | ~30        |
| 2   | `require_drift_database_close`            | 4     | 3          | 3      | **10**    | ~70        |
| 8   | `require_drift_stream_cancel`             | 4     | 3          | 3      | **10**    | ~70        |
| 5   | `require_drift_foreign_key_pragma`        | 4     | 3          | 3      | **10**    | ~80        |
| 18  | `require_drift_reads_from`                | 3     | 4          | 4      | **11**    | ~40        |
| 15  | `avoid_drift_query_in_migration`          | 4     | 4          | 3      | **11**    | ~60        |
| 17  | `avoid_drift_foreign_key_in_migration`    | 3     | 4          | 5      | **12**    | ~30        |
| 9   | `avoid_drift_database_on_main_isolate`    | 3     | 4          | 4      | **11**    | ~40        |
| 20  | `avoid_drift_close_streams_in_tests`      | 2     | 4          | 5      | **11**    | ~30        |
| 13  | `avoid_drift_lazy_database`               | 3     | 3          | 4      | **10**    | ~40        |
| 11  | `avoid_drift_get_single_without_unique`   | 3     | 3          | 3      | **9**     | ~50        |
| 21  | `avoid_drift_nullable_converter_mismatch` | 3     | 3          | 3      | **9**     | ~50        |
| 19  | `avoid_drift_unsafe_web_storage`          | 2     | 3          | 4      | **9**     | ~30        |
| 14  | `prefer_drift_isolate_sharing`            | 3     | 2          | 2      | **7**     | ~80        |
| 12  | `prefer_drift_use_columns_false`          | 2     | 2          | 2      | **6**     | ~100       |
| 16  | `require_drift_schema_version_bump`       | 3     | 1          | 1      | **5**     | ~120       |

### Recommended Implementation Order (by priority score)

**Phase 1 — Highest value, easiest wins** (score ≥12):

1. `avoid_drift_raw_sql_interpolation` (15) — 30 lines, trivial detection
2. `avoid_drift_log_statements_production` (14) — 30 lines, identical to Isar inspector pattern
3. `avoid_drift_enum_index_reorder` (12) — 80 lines, clear pattern
4. `avoid_drift_update_without_where` (12) — 60 lines
5. `prefer_drift_batch_operations` (12) — 30 lines
6. `avoid_drift_foreign_key_in_migration` (12) — 30 lines

**Phase 2 — Strong value** (score 10-11): 7. `require_await_in_drift_transaction` (11) — 70 lines 8. `require_drift_reads_from` (11) — 40 lines 9. `avoid_drift_query_in_migration` (11) — 60 lines 10. `avoid_drift_database_on_main_isolate` (11) — 40 lines 11. `avoid_drift_close_streams_in_tests` (11) — 30 lines 12. `require_drift_database_close` (10) — 70 lines 13. `require_drift_stream_cancel` (10) — 70 lines 14. `require_drift_foreign_key_pragma` (10) — 80 lines 15. `avoid_drift_lazy_database` (10) — 40 lines

**Phase 3 — Lower confidence / niche** (score <10): 16. `avoid_drift_get_single_without_unique` (9) — 50 lines 17. `avoid_drift_nullable_converter_mismatch` (9) — 50 lines 18. `avoid_drift_unsafe_web_storage` (9) — 30 lines 19. `prefer_drift_isolate_sharing` (7) — 80 lines 20. `prefer_drift_use_columns_false` (6) — 100 lines 21. `require_drift_schema_version_bump` (5) — 120 lines

### Total Estimated Lines

- Phase 1: ~250 lines (6 rules)
- Phase 2: ~500 lines (9 rules)
- Phase 3: ~460 lines (6 rules)
- **Total**: ~1,210 lines of rule code + ~200 lines of boilerplate/imports = ~1,400 lines

### If Time-Constrained

If we can only ship 10 rules initially, take the top 10 by priority score:

1. `avoid_drift_raw_sql_interpolation` (15)
2. `avoid_drift_log_statements_production` (14)
3. `avoid_drift_enum_index_reorder` (12)
4. `avoid_drift_update_without_where` (12)
5. `prefer_drift_batch_operations` (12)
6. `avoid_drift_foreign_key_in_migration` (12)
7. `require_await_in_drift_transaction` (11)
8. `require_drift_reads_from` (11)
9. `avoid_drift_query_in_migration` (11)
10. `avoid_drift_database_on_main_isolate` (11)

This covers: SQL injection, data corruption, production logging, bulk operations, migration safety, transaction safety, stream invalidation, and performance — the highest-impact categories.

---

## 23. Updating db_yield_rules.dart for Drift

### Why This Matters

The `db_yield_rules.dart` file provides 3 shared rules that apply to ALL database packages. Currently, these rules barely detect Drift patterns because Drift's fluent builder API doesn't match the explicit method name lists or known IO targets.

**Fixing this is arguably higher-impact than some of the Drift-specific rules**, because these shared rules fire for every database package and the `yieldToUI()` pattern is critical for preventing UI jank on mobile.

### Specific Changes Needed

#### 1. Add Drift write methods to `_writeMethods` set (line 71)

```dart
const Set<String> _writeMethods = {
  // Isar
  'writeTxn', 'deleteAll', 'putAll',
  // sqflite
  'rawInsert', 'rawUpdate', 'rawDelete',
  // Drift (add these)
  'transaction', 'batch', 'customUpdate', 'customStatement',
  // File I/O
  'writeAsString', 'writeAsBytes',
};
```

**Note**: `transaction` and `batch` are Drift wrapper methods that contain writes. The individual methods inside (`insert`, `write`, `go`) are harder to detect in the chain.

#### 2. Add Drift read methods to `_bulkReadMethods` set (line 80)

```dart
const Set<String> _bulkReadMethods = {
  // Isar
  'findAll',
  // sqflite
  'rawQuery',
  // Drift (add these)
  'customSelect',
  // File / asset I/O
  'readAsString', 'readAsBytes', 'readAsLines', 'loadJsonFromAsset',
};
```

**Note**: Drift's `select(table).get()` chain is hard to add here because `get()` is too generic. `customSelect` is the Drift-specific read method that can be safely added.

#### 3. Add Drift IO targets to `_knownIoTargets` set (line 172)

```dart
const Set<String> _knownIoTargets = {
  'isar',
  'database',
  'db',
  'box',
  'store',
  'collection',
  // Drift (add these)
  'drift',
  'appDatabase',
  'todosDao',  // too specific?
};
```

**Problem**: Drift database instances are user-named (e.g., `AppDatabase`, `MyDb`, `TodosDao`). We can't enumerate all possible names. The existing `database` and `db` targets will catch common naming conventions, but `appDatabase` or `todosDao` won't match.

**Better approach**: Instead of adding Drift-specific target names, improve the heuristic to detect Drift builder chains. When the target is `into(table)`, `select(table)`, `update(table)`, or `delete(table)` — these are almost certainly Drift operations.

#### 4. Add chain-aware detection

The current detection walks up through `.target` properties but only checks the root target against `_knownIoTargets`. For Drift's chained calls like `db.into(todoItems).insert(companion)`, the detection already works IF the root is `db`. But for `into(todoItems).insert(companion)` without a named target, it doesn't.

**Proposed addition**: Check if the immediate method target is one of Drift's builder-creating methods:

```dart
const Set<String> _driftBuilderMethods = {
  'into', 'select', 'selectOnly', 'update', 'delete',
  'customSelect', 'customUpdate', 'customStatement',
};
```

If the target of `insert`/`get`/`write`/`go` is a call to one of these builder methods, classify the operation.

### Effort Estimate

- Adding method names to existing sets: ~5 lines changed, 10 minutes
- Adding chain-aware detection: ~20 lines new code, 30 minutes
- Testing: Need to verify no false positives on non-Drift code

### Risk

Low — changes to `_writeMethods` and `_bulkReadMethods` are additive. `transaction` and `batch` are somewhat generic names, but the rule also requires:

1. The method is awaited
2. The method is NOT followed by `yieldToUI()`
3. The target is a known IO target OR matches `db*` prefix

So false positives are limited to non-Drift code that calls `await transaction(...)` on a `db*`-prefixed variable — unlikely outside database contexts.

---

## 24. Risk Assessment & Confidence Levels

### High Confidence Rules (clear AST patterns)

| Rule                                        | Why High Confidence                                                |
| ------------------------------------------- | ------------------------------------------------------------------ |
| 1: `avoid_drift_enum_index_reorder`         | Clear pattern: TypeConverter + `.index`                            |
| 3: `avoid_drift_update_without_where`       | Clear pattern: update/delete chain without where                   |
| 6: `avoid_drift_raw_sql_interpolation`      | Clear pattern: StringInterpolation in customSelect args            |
| 7: `prefer_drift_batch_operations`          | Clear pattern: insert inside for loop                              |
| 10: `avoid_drift_log_statements_production` | Clear pattern: `logStatements: true`                               |
| 15: `avoid_drift_query_in_migration`        | Clear pattern: select/update in onUpgrade callback                 |
| 17: `avoid_drift_foreign_key_in_migration`  | Clear pattern: customStatement('PRAGMA foreign_keys') in onUpgrade |
| 18: `require_drift_reads_from`              | Clear pattern: customSelect.watch() without readsFrom              |
| 20: `avoid_drift_close_streams_in_tests`    | Clear pattern: NativeDatabase.memory() in test file                |

### Medium Confidence Rules (heuristic matching)

| Rule                                          | Challenge                                                |
| --------------------------------------------- | -------------------------------------------------------- |
| 2: `require_drift_database_close`             | Heuristic: field type name containing "Database"         |
| 4: `require_await_in_drift_transaction`       | Generic method name "transaction" needs import check     |
| 5: `require_drift_foreign_key_pragma`         | Need to find database class and check migration strategy |
| 8: `require_drift_stream_cancel`              | May overlap with existing stream disposal rules          |
| 9: `avoid_drift_database_on_main_isolate`     | May not be wrong for desktop apps                        |
| 11: `avoid_drift_get_single_without_unique`   | Hard to determine if where clause guarantees uniqueness  |
| 13: `avoid_drift_lazy_database`               | Need to detect isolate usage in LazyDatabase callback    |
| 14: `prefer_drift_isolate_sharing`            | Cross-expression path comparison                         |
| 19: `avoid_drift_unsafe_web_storage`          | Limited detection surface                                |
| 21: `avoid_drift_nullable_converter_mismatch` | Simplified heuristic only                                |

### Lower Confidence Rules (complex detection)

| Rule                                    | Challenge                                                        |
| --------------------------------------- | ---------------------------------------------------------------- |
| 12: `prefer_drift_use_columns_false`    | Need cross-expression analysis of column usage in result mapping |
| 16: `require_drift_schema_version_bump` | Need change tracking / multi-version comparison                  |

---

## 25. Open Questions & Decisions

### Q1: Should Drift rules require import confirmation?

**Context**: Method names like `transaction`, `select`, `update`, `delete`, `watch` are extremely generic. Without checking for `import 'package:drift/drift.dart'`, we'll flag non-Drift code.

**Recommendation**: YES — check for Drift import for rules that use generic method names. Rules using Drift-specific names (`customSelect`, `NativeDatabase`, `LazyDatabase`, `MigrationStrategy`) don't need it.

**Note**: The Isar rules use a mix — some check for Isar-specific types (`Isar` type), others use heuristics (method names like `writeTxn`).

### Q2: How to handle overlap with existing rules?

**Context**: Several proposed rules overlap with existing generic rules:

- `require_drift_stream_cancel` overlaps with stream subscription disposal rules
- `require_drift_database_close` overlaps with `require_dispose`
- `require_await_in_drift_transaction` may overlap with generic unawaited-future rules

**Options**:

1. Implement all Drift-specific rules anyway (more specific messages, better developer experience)
2. Skip overlapping rules and rely on generic versions
3. Implement Drift-specific rules that ADD to generic detection (e.g., check for `.watch().listen()` specifically)

**Recommendation**: Option 1 — implement Drift-specific rules with Drift-specific error messages and correction advice. The generic rules may not fire for the specific Drift patterns, and Drift-specific advice is more actionable.

### Q3: Should we detect moor (legacy) as well?

**Context**: Drift was formerly called "moor". Some projects may still use `import 'package:moor/moor.dart'`.

**Recommendation**: NO — moor is discontinued and deprecated. Don't add complexity for a legacy package. If someone is still using moor, they should migrate to drift first.

### Q4: What about `.drift` SQL files?

**Context**: Drift supports defining tables and queries in `.drift` files (SQL-first approach). These are compiled by `drift_dev`.

**Decision**: Our rules analyze Dart code, not `.drift` files. We can't lint `.drift` files with the analyzer infrastructure. This is a limitation, not a blocker.

### Q5: How to handle `drift_flutter` vs `drift_sqflite` vs raw `NativeDatabase`?

**Context**: Different executors have different patterns:

- `drift_flutter`: `driftDatabase(name: 'app')` — handles isolation automatically
- `drift_sqflite`: `SqfliteQueryExecutor(...)` — uses sqflite under the hood
- Raw: `NativeDatabase(File('path'))` — manual setup

**Decision**: Rules should work regardless of executor. Focus on the database class and query patterns, not the executor choice. Exception: `avoid_drift_database_on_main_isolate` specifically targets `NativeDatabase` without `createInBackground`.

### Q6: Tier assignment for SQL injection rule?

**Context**: SQL injection (`avoid_drift_raw_sql_interpolation`) is a security vulnerability. Should it be Essential or Recommended?

**Decision**: Recommended (not Essential). Essential tier is reserved for data corruption that happens silently without any security context. SQL injection requires a specific attack vector and is a security concern, fitting the Recommended tier's "runtime crashes, resource leaks, critical patterns" scope. Severity is ERROR though.

### Q7: Should `avoid_drift_update_without_where` distinguish between update and delete?

**Context**: `delete(table).go()` without where deletes ALL rows (catastrophic). `update(table).write(companion)` without where updates ALL rows (bad but maybe recoverable).

**Decision**: Flag both with the same rule. Both are dangerous. If needed, we can split into two rules later.

### Q8: Should we implement quick fixes?

**Context**: Isar rules have 1 quick fix (`AddTryCatchTodoFix`). Adding quick fixes is valuable but adds implementation complexity.

**Recommended quick fixes (if any)**:

- Rule 6: Replace string interpolation with `Variable` parameters
- Rule 10: Replace `true` with `kDebugMode`
- Rule 18: Add `readsFrom: {}` parameter stub

**Decision**: Defer quick fixes to a follow-up batch. Get the detection rules working first.

---

## 26. Rules We Considered But Rejected

### `require_drift_table_column_trailing_parens`

**Reason for rejection**: This is a compile-time error — if you forget the trailing `()`, the code won't compile. No need for a lint rule for something the compiler catches.

### `avoid_drift_client_default_for_timestamps`

**Reason for rejection**: `clientDefault(() => DateTime.now())` vs `withDefault(currentDateAndTime)` is a design choice, not a bug. Both are valid depending on whether you want the timestamp computed in Dart or SQL.

### `require_drift_build_runner`

**Reason for rejection**: This is a workflow/tooling concern, not a code pattern. Can't detect "you forgot to run build_runner" statically.

### `avoid_drift_multiple_auto_increment`

**Reason for rejection**: SQLite enforces this — you'll get a compile error. No need for lint rule.

### `prefer_drift_modular_generation`

**Reason for rejection**: `*.g.dart` vs `*.drift.dart` is a project preference, not a bug. Modular generation solves name collision issues but adds complexity.

### `require_drift_wal_mode`

**Reason for rejection**: WAL (Write-Ahead Logging) is a performance optimization that's usually set up once at the database level. Not a common source of bugs. Also, `drift_flutter` handles this automatically.

### `avoid_drift_downgrade`

**Reason for rejection**: Drift already throws an error on downgrades (since recent versions). No need to duplicate this check.

### `require_drift_migration_test`

**Reason for rejection**: Can't detect the absence of test files from within a lint rule that analyzes source code.

### `avoid_drift_custom_constraint_without_not_null`

**Reason for rejection**: Too niche. `customConstraint()` is used by advanced users who understand they're overriding NOT NULL. Flagging it would annoy power users without helping beginners.

---

## 27. Drift Version History & Compatibility

### Key Version Milestones

| Version     | Feature                                                | Impact on Rules                                                       |
| ----------- | ------------------------------------------------------ | --------------------------------------------------------------------- |
| 1.0 (moor)  | Initial release as "moor"                              | Legacy — don't support                                                |
| 2.0 (drift) | Renamed to "drift"; nested transactions via savepoints | Rule 4 (transaction await) applies; nested transactions now supported |
| 2.1         | `DatabaseConnection.delayed` added                     | Rule 13 (LazyDatabase) has a fix target                               |
| 2.5         | Modular code generation (`*.drift.dart`)               | Our stylistic_rules.dart already excludes these                       |
| 2.8         | `NativeDatabase.createInBackground()`                  | Rule 9 (main isolate) has a fix target                                |
| 2.12        | `drift_flutter` package introduced                     | Alternative to manual NativeDatabase setup                            |
| 2.14        | Step-by-step migrations via `make-migrations`          | Rule 16 (schema version bump) — tooling exists                        |
| 2.16        | `closeStreamsSynchronously` added                      | Rule 20 (test streams) has a fix target                               |
| 2.18        | Nested transaction deadlock issues                     | Fixed in 2.20.3 — our rules don't need to worry                       |
| 2.20        | `NullAwareTypeConverter` added                         | Rule 21 (nullable converter) — migration path exists                  |
| 2.20+       | Web OPFS support stabilized                            | Rule 19 (unsafe web storage) — modern alternatives exist              |

### Minimum Drift Version for Rules

All proposed rules target Drift v2.0+ (the "drift" package, not legacy "moor"). We assume:

- Type converters exist (v1.0+)
- `MigrationStrategy` with `beforeOpen` (v1.0+)
- `customSelect`/`customStatement` (v1.0+)
- `NativeDatabase.createInBackground()` (v2.8+, but rule works for all versions — just flags the old pattern)

### Breaking Changes We Should Know About

1. **Dart 3.0 requirement** (Drift 2.14+): Records, patterns, class modifiers
2. **Nullable TypeConverter enforcement** (Drift 2.0): `TypeConverter<Foo?, int?>` can no longer be applied to non-nullable columns
3. **Database downgrade throws** (recent versions): Previously caused silent corruption; now throws

---

## 28. Generated Code Interaction

### Will Our Rules Lint Generated Files?

Drift generates two types of files:

- `*.g.dart` — default mode (build_runner standard)
- `*.drift.dart` — modular mode

**Current project handling**:

- `stylistic_rules.dart` lists `.drift.dart` in `_generatedFileSuffixes` (already excluded from stylistic linting)
- `*.g.dart` files are typically excluded via `analysis_options.yaml`

**Risk**: If generated files are NOT excluded from analysis, our Drift rules could fire on generated code (false positives). For example:

- `avoid_drift_enum_index_reorder` could flag generated TypeConverter implementations
- `require_drift_foreign_key_pragma` could flag generated database classes

**Mitigation strategies**:

1. **Check file suffix**: Skip files ending in `.g.dart` or `.drift.dart`
2. **Check for generated comment**: Look for `// GENERATED CODE - DO NOT MODIFY BY HAND` header
3. **Rely on existing exclusions**: The `analysis_options.yaml` exclude list should already handle this

**Recommendation**: Add a check to the drift_rules.dart file header comment noting that generated files should be excluded. Consider adding a utility check if not already available in the project.

### Drift's Own Analyzer Plugin

Drift ships a custom analyzer plugin via `drift_dev` that provides:

- Compile-time validation of `.drift` SQL files
- Type checking for SQL expressions
- Migration generation

**Conflict risk**: LOW. Drift's plugin operates on `.drift` files and generated code. Our rules operate on user-written Dart code. They analyze different things and shouldn't conflict. However, if both plugins flag the same pattern (unlikely), the user sees duplicate warnings.

---

## 29. Cross-Package Integration Patterns

Drift is often used alongside state management and DI packages. Common patterns that affect rule behavior:

### Drift + Riverpod

```dart
// Common pattern: Database as a provider
final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase(driftDatabase(name: 'app'));
  ref.onDispose(() => db.close()); // Close handled by Riverpod
  return db;
});

// Stream queries exposed as StreamProvider
final todosProvider = StreamProvider<List<TodoItem>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.select(db.todoItems).watch(); // Stream auto-managed by Riverpod
});
```

**Impact on rules**:

- `require_drift_database_close` — might false-positive since close is in `ref.onDispose`, not a `dispose()` method
- `require_drift_stream_cancel` — Riverpod auto-cancels streams in `StreamProvider`, no manual cancel needed

### Drift + Bloc

```dart
class TodosBloc extends Bloc<TodosEvent, TodosState> {
  final AppDatabase _db;
  StreamSubscription? _sub;

  TodosBloc(this._db) : super(TodosLoading()) {
    _sub = _db.select(_db.todoItems).watch().listen((todos) {
      add(TodosLoaded(todos));
    });
  }

  @override
  Future<void> close() {
    _sub?.cancel(); // Cancel in close(), not dispose()
    return super.close();
  }
}
```

**Impact on rules**:

- `require_drift_stream_cancel` — should check `close()` method too, not just `dispose()`
- `require_drift_database_close` — Blocs use `close()` not `dispose()`

### Drift + GetIt (Service Locator)

```dart
// Registration
GetIt.I.registerLazySingleton<AppDatabase>(
  () => AppDatabase(driftDatabase(name: 'app')),
  dispose: (db) => db.close(), // Close handled by GetIt
);
```

**Impact on rules**:

- `require_drift_database_close` — close handled externally by GetIt
- `prefer_drift_isolate_sharing` — GetIt singleton ensures single instance

### Key Insight

Many Drift lifecycle patterns are managed by DI/state management frameworks. Rules that check for `dispose()` will miss `close()` (Bloc), `ref.onDispose()` (Riverpod), and external `dispose:` callbacks (GetIt). This means `require_drift_database_close` and `require_drift_stream_cancel` will have false positives in DI-managed apps.

**Mitigation**: Make these rules INFO severity (not WARNING) and mention DI patterns in the correction message. Or add detection for common DI disposal patterns (`ref.onDispose`, `registerLazySingleton(..., dispose:)`).

---

## 30. Sample Fixture Code

Test fixture examples ready for implementation. These go in `example_packages/lib/drift/`.

### drift_rules_fixture.dart

```dart
// ignore_for_file: unused_local_variable, avoid_print

// ============================================================
// IMPORTS (for drift import detection)
// ============================================================
// In real code: import 'package:drift/drift.dart';
// In fixture: we simulate Drift patterns without the actual import

// ============================================================
// Rule 1: avoid_drift_enum_index_reorder
// ============================================================

enum Priority { low, medium, high }

// LINT: Stores enum by index — reordering corrupts data
class BadPriorityConverter {
  Priority fromSql(int fromDb) => Priority.values[fromDb];
  int toSql(Priority value) => value.index; // LINT
}

// OK: Stores enum by name — immune to reordering
class GoodPriorityConverter {
  Priority fromSql(String fromDb) =>
      Priority.values.firstWhere((e) => e.name == fromDb);
  String toSql(Priority value) => value.name;
}

// ============================================================
// Rule 3: avoid_drift_update_without_where
// ============================================================

void badUpdateNoWhere(dynamic db) async {
  // LINT: Deletes ALL rows
  // await delete(todoItems).go();

  // LINT: Updates ALL rows
  // await update(users).write(companion);
}

void goodUpdateWithWhere(dynamic db) async {
  // OK: Targets specific rows
  // await (delete(todoItems)..where((t) => t.completed.equals(true))).go();
}

// ============================================================
// Rule 6: avoid_drift_raw_sql_interpolation
// ============================================================

void badSqlInterpolation(dynamic db, String userName) async {
  // LINT: SQL injection vulnerability
  // await db.customSelect('SELECT * FROM users WHERE name = "$userName"');
}

void goodParameterizedSql(dynamic db, String userName) async {
  // OK: Parameterized query
  // await db.customSelect(
  //   'SELECT * FROM users WHERE name = ?',
  //   variables: [Variable.withString(userName)],
  // );
}

// ============================================================
// Rule 7: prefer_drift_batch_operations
// ============================================================

void badInsertInLoop(dynamic db, List<dynamic> todos) async {
  // LINT: Individual inserts in loop
  for (final todo in todos) {
    // await into(todoItems).insert(todo);
  }
}

void goodBatchInsert(dynamic db, List<dynamic> todos) async {
  // OK: Batch operation
  // await batch((b) { b.insertAll(todoItems, todos); });
}

// ============================================================
// Rule 10: avoid_drift_log_statements_production
// ============================================================

void badLogStatements() {
  // LINT: Logs SQL in production
  // NativeDatabase(file, logStatements: true);
}

void goodLogStatements() {
  // OK: Only logs in debug
  // NativeDatabase(file, logStatements: kDebugMode);
}

// ============================================================
// Rule 15: avoid_drift_query_in_migration
// ============================================================

// LINT: High-level queries in migration use latest schema
// MigrationStrategy(
//   onUpgrade: (migrator, from, to) async {
//     final old = await select(users).get(); // LINT
//   },
// );

// OK: Raw SQL in migration
// MigrationStrategy(
//   onUpgrade: (migrator, from, to) async {
//     await customStatement('UPDATE users SET name = TRIM(name)');
//   },
// );

// ============================================================
// Rule 17: avoid_drift_foreign_key_in_migration
// ============================================================

// LINT: Foreign key pragma inside migration transaction
// MigrationStrategy(
//   onUpgrade: (migrator, from, to) async {
//     await customStatement('PRAGMA foreign_keys = ON'); // LINT
//   },
// );

// OK: Foreign key pragma in beforeOpen
// MigrationStrategy(
//   beforeOpen: (details) async {
//     await customStatement('PRAGMA foreign_keys = ON');
//   },
// );

// ============================================================
// Rule 18: require_drift_reads_from
// ============================================================

// LINT: Custom select watched without readsFrom
// customSelect('SELECT * FROM users WHERE active = 1')
//   .watch(); // LINT: stream never updates

// OK: readsFrom specified
// customSelect('SELECT * FROM users WHERE active = 1',
//   readsFrom: {users},
// ).watch();
```

**Note**: These fixtures are pseudo-code because we can't import `package:drift` as a dependency. The actual fixture will need to simulate the patterns using mock classes or comment-based annotations. This matches how Isar fixtures work — they test the AST pattern matching without requiring the actual package.

---

## 31. Unresolved Risks & Validation Gaps

### No Real-World Validation

**Risk**: ALL 21 proposed detection strategies are theoretical. We've designed them based on API documentation, common mistakes, and AST analysis patterns — but zero rules have been tested against actual Drift codebases.

**What could go wrong**:

- False positives on patterns we didn't anticipate
- False negatives on variations of the patterns we described
- AST structure differences from what we assumed (e.g., cascade notation `..\` vs chained `.`)
- Import detection failing for re-exported Drift types
- Generated code triggering rules unexpectedly

**Mitigation**:

1. Start with the highest-confidence rules (score 4-5 in confidence column)
2. Test each rule against 2-3 real Drift projects before publishing
3. Use INFO severity for uncertain rules (can be upgraded later)
4. Ship in beta first with opt-in activation

### Drift's Analyzer Plugin Conflict

**Risk**: Drift ships its own analyzer plugin (`drift_dev`). If both our plugin and Drift's plugin analyze the same file, there could be:

- Performance impact (double analysis)
- Conflicting suggestions
- Duplicate warnings

**Assessment**: LOW risk. Drift's plugin focuses on `.drift` SQL files and generated code validation, not code pattern linting. Our rules focus on usage patterns in user-written Dart. The overlap surface is minimal.

**Mitigation**: Document in `using_with_drift.md` that both plugins coexist safely.

### Fixture Limitations

**Risk**: We can't add `drift` as a dependency to the project (it would bloat the package and create version conflicts). This means:

- Test fixtures can't use real Drift types
- We can't do static type resolution on Drift-specific types (e.g., `GeneratedDatabase`, `TypeConverter<A, B>`)
- All detection MUST be heuristic (string matching, method names, structural patterns)

**Assessment**: This is the same constraint as Isar and Hive rules, which work fine with heuristic detection. Not a blocker, but limits detection accuracy.

### False Positive Risk from Generic Method Names

**Risk**: Drift uses generic method names that appear in non-Drift code:

- `transaction()` — used by many database/ORM packages
- `select()` — used by Flutter's SelectableText, SQL packages, etc.
- `update()` — used everywhere
- `delete()` — used everywhere
- `watch()` — used by file watchers, Riverpod, etc.
- `batch()` — used by other batch processing contexts
- `insert()` — used by List, Map, etc.

**Assessment**: MEDIUM risk. Without import gating, these rules will fire on non-Drift code.

**Mitigation**: REQUIRE Drift import check for rules using generic names. This is non-negotiable for rules 3, 4, 7, 8, 11, 15, 17.

### Drift API Evolution

**Risk**: Drift is actively developed by Simon Binder. API changes in future versions could:

- Rename methods (unlikely for stable APIs)
- Add new patterns we should detect
- Fix issues we're warning about (making our rules outdated)

**Assessment**: LOW risk for stable APIs (customSelect, transaction, etc.). MEDIUM risk for newer features (OPFS, step-by-step migrations).

**Mitigation**: Version the rules (`{v1}` tag). Review Drift changelog with each saropa_lints release.

### Adoption Data Gap

We have no data on how many saropa_lints users use Drift. If adoption is low, the implementation effort (21 rules, ~1,400 lines) may not be justified.

**Available signals**:

- Drift has 1,700+ pub.dev likes (as of 2025), making it one of the top 3 Flutter database packages
- The ROADMAP already lists Drift alongside Isar/Hive, suggesting user demand
- Drift is the primary choice for projects that need SQL (not NoSQL)

**Recommendation**: Proceed with implementation — Drift's popularity justifies the investment, and the 21-rule scope matches Isar/Hive for consistent package support.

---

## 32. Comparison with Isar/Hive Rules

### Structural Comparison

| Aspect        | Isar              | Hive              | Drift              |
| ------------- | ----------------- | ----------------- | ------------------ |
| Rule count    | 21                | 21                | 21 (proposed)      |
| Essential     | 1                 | 1                 | 1                  |
| Recommended   | 7                 | 7                 | 7                  |
| Professional  | 5                 | 6                 | 6                  |
| Comprehensive | 8                 | 7                 | 7                  |
| File          | `isar_rules.dart` | `hive_rules.dart` | `drift_rules.dart` |
| ~Lines        | 1,745             | ~1,700            | ~1,700 (est)       |

### Conceptual Comparison

| Concept            | Isar                                         | Drift                                                        |
| ------------------ | -------------------------------------------- | ------------------------------------------------------------ |
| Enum corruption    | `avoid_isar_enum_field` (stored by index)    | `avoid_drift_enum_index_reorder` (TypeConverter with .index) |
| DB close           | `require_isar_close_on_dispose`              | `require_drift_database_close`                               |
| Batch writes       | `prefer_isar_batch_operations` (put→putAll)  | `prefer_drift_batch_operations` (insert→batch)               |
| Transaction safety | `avoid_isar_transaction_nesting` (deadlocks) | `require_await_in_drift_transaction` (unawaited queries)     |
| Debug in prod      | `require_isar_inspector_debug_only`          | `avoid_drift_log_statements_production`                      |
| Clear/delete all   | `avoid_isar_clear_in_production`             | `avoid_drift_update_without_where`                           |
| Stream safety      | `avoid_cached_isar_stream`                   | `require_drift_stream_cancel`                                |
| Web limitations    | `avoid_isar_web_limitations`                 | `avoid_drift_unsafe_web_storage`                             |
| SQL injection      | N/A (NoSQL, no raw queries)                  | `avoid_drift_raw_sql_interpolation`                          |
| Migration          | N/A (auto-migration)                         | Rules 5, 15, 16, 17 (explicit migrations)                    |
| Foreign keys       | N/A (NoSQL, uses links)                      | Rules 5, 17 (PRAGMA enforcement)                             |
| Isolates           | N/A                                          | Rules 9, 13, 14 (background processing)                      |
| Type converters    | N/A (built-in serialization)                 | Rules 1, 21 (custom converters)                              |
| Query safety       | `avoid_isar_float_equality_queries`          | `avoid_drift_get_single_without_unique`                      |
| Index optimization | `prefer_isar_index_for_queries`              | Covered by shared `require_database_index`                   |
| Links/relations    | `require_isar_links_load`                    | N/A (SQL joins, not lazy links)                              |

### Key Differences

1. **SQL injection** — Drift has raw SQL APIs; Isar doesn't. This is a unique Drift concern.
2. **Explicit migrations** — Drift requires manual version management; Isar auto-migrates. Rules 5, 15-17 have no Isar equivalent.
3. **Foreign key enforcement** — SQL-specific. Isar uses links (lazy-loaded references), not foreign keys.
4. **Isolate architecture** — Drift has more complex isolate support (`DriftIsolate`, `LazyDatabase` vs `DatabaseConnection.delayed`). Isar runs on main isolate by default.
5. **Type converters** — Drift uses explicit `TypeConverter` classes; Isar auto-serializes. The converter pattern introduces its own bugs.
6. **No collection/annotation rules** — Drift uses SQL tables (generated from `extends Table`), not `@collection` / `@embedded` annotations.

---

## 33. References

### Official Documentation

- [Drift official docs](https://drift.simonbinder.eu/)
- [Drift setup guide](https://drift.simonbinder.eu/setup/)
- [Drift tables](https://drift.simonbinder.eu/dart_api/tables/)
- [Drift reads & selects](https://drift.simonbinder.eu/dart_api/select/)
- [Drift writes (insert/update/delete)](https://drift.simonbinder.eu/dart_api/writes/)
- [Drift stream queries](https://drift.simonbinder.eu/dart_api/streams/)
- [Drift transactions](https://drift.simonbinder.eu/dart_api/transactions/)
- [Drift DAOs](https://drift.simonbinder.eu/dart_api/daos/)
- [Drift custom queries](https://drift.simonbinder.eu/sql_api/custom_queries/)
- [Drift migrations](https://drift.simonbinder.eu/migrations/)
- [Drift migration testing](https://drift.simonbinder.eu/migrations/tests/)
- [Drift type converters](https://drift.simonbinder.eu/type_converters/)
- [Drift web platform](https://drift.simonbinder.eu/platforms/web/)
- [Drift isolates](https://drift.simonbinder.eu/isolates/)
- [Drift encryption](https://drift.simonbinder.eu/platforms/encryption/)
- [Drift testing](https://drift.simonbinder.eu/testing/)
- [Drift generation options](https://drift.simonbinder.eu/generation_options/)
- [Drift modular code gen](https://drift.simonbinder.eu/generation_options/modular/)
- [Drift FAQ](https://drift.simonbinder.eu/faq/)

### Package Pages

- [drift on pub.dev](https://pub.dev/packages/drift)
- [drift_dev on pub.dev](https://pub.dev/packages/drift_dev)
- [drift_flutter on pub.dev](https://pub.dev/packages/drift_flutter)
- [drift_sqflite on pub.dev](https://pub.dev/packages/drift_sqflite)

### Source Code

- [Drift GitHub repository](https://github.com/simolus3/drift)
- [Nested transaction deadlock issue #3260](https://github.com/simolus3/drift/issues/3260)
- [Database locks during batch insert issue #245](https://github.com/simolus3/drift/issues/245)
- [Multiple database instances issue #488](https://github.com/simolus3/drift/issues/488)

### Community Articles

- [Drift Deep Dive: Optimizing Performance (Medium)](https://medium.com/@teesil2000z/drift-database-deep-dive-optimizing-performance-for-flutter-on-web-and-mobile-f7b9663d49fa)
- [Drift reactive database overview (Medium)](https://medium.com/@rishad2002/drift-a-reactive-database-library-for-flutter-and-dart-powered-by-sqlite-99943ce84509)
- [Testing Drift database (Medium)](https://chegebrian.medium.com/testing-drift-database-in-flutter-978c3eb620dd)
- [Unit-Testing Drift DAOs (Medium)](https://chegebrian.medium.com/unit-testing-drift-database-daos-a71fc08b0091)
