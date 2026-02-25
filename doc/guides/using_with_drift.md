# Using saropa_lints with Drift

This guide explains how saropa_lints enhances your Drift (SQLite) database development with 31 Drift-specific rules plus 7 shared database rules that catch data corruption, SQL injection, migration failures, resource leaks, and performance anti-patterns.

## Why This Matters

Drift is a type-safe, reactive SQLite wrapper for Dart/Flutter that uses code generation for table definitions, companions, and DAOs. But its power comes with subtle pitfalls — enum storage that silently corrupts data, foreign keys that are quietly ignored, raw SQL that opens injection vectors, and migration callbacks that behave differently than you'd expect.

Standard linters see valid Dart code. saropa_lints understands Drift's database semantics.

## What saropa_lints Catches

### Enum Storage Causes Data Corruption

This is the most critical Drift issue. When you store enums by ordinal index, schema changes silently corrupt existing data:

```dart
// BAD - data corruption when enum values are reordered
class PriorityConverter extends TypeConverter<Priority, int> {
  @override
  Priority fromSql(int fromDb) => Priority.values[fromDb];
  @override
  int toSql(Priority value) => value.index;  // DANGER!
}

enum Priority { low, medium, high }
```

**What goes wrong:**
1. User saves `Priority.medium` (stored as index `1`)
2. You add a new priority: `enum Priority { low, urgent, medium, high }`
3. Now `urgent` is index `1`, but existing data still has `1` stored
4. User's priority silently changes from medium to urgent

```dart
// GOOD - store by name, immune to reordering
class PriorityConverter extends TypeConverter<Priority, String> {
  @override
  Priority fromSql(String fromDb) =>
    Priority.values.firstWhere((e) => e.name == fromDb);
  @override
  String toSql(Priority value) => value.name;
}

// GOOD - store by explicit code, immune to reordering
enum Priority {
  low(0), medium(10), high(20), urgent(30);
  const Priority(this.code);
  final int code;
}
```

**Rule**: `avoid_drift_enum_index_reorder`

### SQL Injection via Raw Queries

Drift's typed API is inherently safe, but raw SQL methods (`customSelect`, `customStatement`, `customUpdate`, `customInsert`) accept SQL strings. String interpolation opens SQL injection vectors:

```dart
// BAD - SQL injection vulnerability
await customSelect("SELECT * FROM users WHERE name = '$userName'");

// GOOD - parameterized query
await customSelect(
  'SELECT * FROM users WHERE name = ?',
  variables: [Variable.withString(userName)],
);
```

**Rule**: `avoid_drift_raw_sql_interpolation`

### Accidental Bulk Update/Delete

`update(table)` or `delete(table)` without `.where()` affects ALL rows:

```dart
// BAD - deletes ALL rows in the table
await delete(todoItems).go();

// BAD - updates ALL rows
await update(users).write(companion);

// GOOD - targets specific rows
await (delete(todoItems)..where((t) => t.completed.equals(true))).go();
await (update(users)..where((u) => u.id.equals(id))).write(companion);
```

**Rule**: `avoid_drift_update_without_where`

### Foreign Keys Silently Ignored

SQLite does NOT enforce foreign keys by default. Without the pragma, all foreign key constraints in your table definitions are quietly ignored:

```dart
// BAD - foreign keys not enforced (missing PRAGMA in beforeOpen)
class AppDatabase extends _$AppDatabase {
  @override
  int get schemaVersion => 1;
  // No beforeOpen callback setting PRAGMA foreign_keys = ON!
}

// GOOD - enable foreign keys in beforeOpen
@override
MigrationStrategy get migration => MigrationStrategy(
  onCreate: (migrator) async => await migrator.createAll(),
  beforeOpen: (details) async {
    await customStatement('PRAGMA foreign_keys = ON');
  },
);
```

**Rule**: `require_drift_foreign_key_pragma`

### Unawaited Queries Escape Transactions

Inside `transaction(() async { ... })`, all queries must be awaited. Unawaited futures execute outside the transaction boundary, breaking atomicity:

```dart
// BAD - insert executes outside the transaction
await transaction(() async {
  into(todoItems).insert(companion);  // Missing await!
  await delete(categories).go();
});

// GOOD - all queries awaited
await transaction(() async {
  await into(todoItems).insert(companion);
  await delete(categories).go();
});
```

**Rule**: `require_await_in_drift_transaction`

### Database Connection Leaks

Drift database instances hold file handles, isolate connections, and stream tracking. Not closing them causes resource leaks:

```dart
// BAD - database never closed
class UserRepository {
  late final AppDatabase _db;

  void init() {
    _db = AppDatabase(NativeDatabase(File('app.db')));
  }
  // Missing close()!
}

// GOOD - proper lifecycle management
class UserRepository {
  late final AppDatabase _db;

  void init() {
    _db = AppDatabase(NativeDatabase(File('app.db')));
  }

  Future<void> dispose() async {
    await _db.close();
  }
}
```

**Rule**: `require_drift_database_close`

### SQL Logging in Production

`logStatements: true` prints ALL SQL including data values to the console — exposing sensitive information in production:

```dart
// BAD - logs SQL in production
NativeDatabase(file, logStatements: true);

// GOOD - only in debug mode
NativeDatabase(file, logStatements: kDebugMode);
```

**Rule**: `avoid_drift_log_statements_production`

### Value(null) vs Value.absent() Confusion

Drift's `Companion` classes use `Value<T>` wrappers where `Value(null)` means "set to NULL" and `Value.absent()` means "don't change". Confusing the two is one of the most common Drift mistakes:

```dart
// BAD - sets non-nullable 'title' to null => runtime crash
await (update(todoItems)..where((t) => t.id.equals(id)))
  .write(TodoItemsCompanion(title: Value(null)));

// GOOD - leave title unchanged, only update completed
await (update(todoItems)..where((t) => t.id.equals(id)))
  .write(TodoItemsCompanion(
    title: Value.absent(),
    completed: Value(true),
  ));
```

**Rule**: `avoid_drift_value_null_vs_absent`

### .equals() vs .equalsValue() with Type Converters

When a column uses a `TypeConverter`, `.equals()` expects the raw SQL value (e.g., an `int` or `String`). Passing the Dart enum type produces queries that silently return no results:

```dart
// BAD - silent query failure: passes enum where SQL type expected
// With intEnum columns, .equals() bypasses the converter
(select(users)..where((u) => u.status.equals(statusValue))).get();

// GOOD - equalsValue() applies the TypeConverter first
(select(users)..where((u) => u.status.equalsValue(Status.active))).get();
```

**Rule**: `require_drift_equals_value`

### High-Level Queries in Migrations

Drift's generated code expects the LATEST schema. During `onUpgrade`, the database is still on the OLD schema. Using `select()`, `update()`, etc. in migration callbacks causes runtime crashes:

```dart
// BAD - uses latest schema against old DB
MigrationStrategy(
  onUpgrade: (migrator, from, to) async {
    final old = await select(users).get();  // CRASH: column may not exist yet
  },
);

// GOOD - use raw SQL in migrations
MigrationStrategy(
  onUpgrade: (migrator, from, to) async {
    await customStatement('UPDATE users SET name = TRIM(name)');
  },
);
```

**Rule**: `avoid_drift_query_in_migration`

### Stream Queries That Never Update

`customSelect(...).watch()` without `readsFrom` creates a stream that returns the initial result and never updates, because Drift doesn't know which tables to watch:

```dart
// BAD - stream never updates
customSelect('SELECT * FROM users WHERE active = 1').watch();

// GOOD - Drift knows to update when users table changes
customSelect('SELECT * FROM users WHERE active = 1',
  readsFrom: {users},
).watch();
```

**Rule**: `require_drift_reads_from`

## Recommended Setup

### 1. Update pubspec.yaml

```yaml
dependencies:
  drift: ^2.20.0
  drift_flutter: ^0.2.0
  sqlite3_flutter_libs: ^0.5.0

dev_dependencies:
  custom_lint: ^0.8.0
  saropa_lints: ^6.0.2
  drift_dev: ^2.20.0
  build_runner: ^2.4.0
```

### 2. Generate configuration

```bash
# Generate analysis_options.yaml with recommended tier
dart run saropa_lints:init --tier recommended

# Or use essential tier for legacy projects
dart run saropa_lints:init --tier essential
```

This generates explicit rule configuration that works reliably with custom_lint.

### 3. Run the linter

```bash
dart run custom_lint
```

## Rule Summary

### Essential Tier (1 rule)

| Rule | Severity | What It Catches |
|------|----------|-----------------|
| `avoid_drift_enum_index_reorder` | ERROR | Enum TypeConverter using `.index` — data corruption on reorder |

### Recommended Tier (13 rules)

| Rule | Severity | What It Catches |
|------|----------|-----------------|
| `require_drift_database_close` | WARNING | Unclosed database connections leaking resources |
| `avoid_drift_update_without_where` | WARNING | `update()`/`delete()` without `.where()` affecting all rows |
| `require_await_in_drift_transaction` | WARNING | Unawaited queries escaping transaction boundaries |
| `require_drift_foreign_key_pragma` | WARNING | Missing `PRAGMA foreign_keys = ON` in `beforeOpen` |
| `avoid_drift_raw_sql_interpolation` | ERROR | String interpolation in `customSelect`/`customStatement` — SQL injection |
| `prefer_drift_batch_operations` | WARNING | Individual inserts in a loop instead of `batch()` |
| `require_drift_stream_cancel` | WARNING | Drift stream subscriptions not cancelled in `dispose()` |
| `avoid_drift_value_null_vs_absent` | WARNING | `Value(null)` when `Value.absent()` was likely intended |
| `require_drift_equals_value` | WARNING | `.equals()` with enum — should be `.equalsValue()` |
| `require_drift_read_table_or_null` | WARNING | `readTable()` after left join crashes on null rows |
| `require_drift_create_all_in_oncreate` | WARNING | Missing `createAll()` in `onCreate` callback |
| `avoid_isar_import_with_drift` | WARNING | Importing both Isar and Drift — incomplete migration |
| `require_drift_onupgrade_handler` | WARNING | `schemaVersion > 1` without `onUpgrade` handler |

### Professional Tier (10 rules)

| Rule | Severity | What It Catches |
|------|----------|-----------------|
| `avoid_drift_database_on_main_isolate` | INFO | `NativeDatabase` without background isolate — UI jank |
| `avoid_drift_log_statements_production` | WARNING | `logStatements: true` without debug guard — data exposure |
| `avoid_drift_get_single_without_unique` | INFO | `getSingle()`/`watchSingle()` without `.where()` — throws on multiple rows |
| `prefer_drift_use_columns_false` | INFO | Joined tables reading unnecessary columns |
| `avoid_drift_lazy_database` | INFO | `LazyDatabase` with isolates — breaks stream synchronization |
| `prefer_drift_isolate_sharing` | INFO | Multiple `NativeDatabase` instances on same file — breaks stream sync |
| `avoid_drift_validate_schema_production` | WARNING | Debug-only `validateDatabaseSchema()` call in production |
| `avoid_drift_replace_without_all_columns` | INFO | `replace()` instead of `write()` — unset columns reset to defaults |
| `avoid_drift_missing_updates_param` | INFO | `customUpdate` without `updates` parameter — streams won't refresh |
| `prefer_drift_foreign_key_declaration` | INFO | Foreign key column without `.references()` declaration |

### Comprehensive Tier (7 rules)

| Rule | Severity | What It Catches |
|------|----------|-----------------|
| `avoid_drift_query_in_migration` | WARNING | High-level query APIs in `onUpgrade` — schema mismatch crash |
| `require_drift_schema_version_bump` | INFO | Schema changes without incrementing `schemaVersion` |
| `avoid_drift_foreign_key_in_migration` | INFO | `PRAGMA foreign_keys` inside migration transaction — silently fails |
| `require_drift_reads_from` | INFO | `customSelect().watch()` without `readsFrom` — stream never updates |
| `avoid_drift_unsafe_web_storage` | INFO | `unsafeIndexedDb` / `WebDatabase` — not multi-tab safe |
| `avoid_drift_close_streams_in_tests` | INFO | `NativeDatabase.memory()` in tests without `closeStreamsSynchronously` |
| `avoid_drift_nullable_converter_mismatch` | INFO | `TypeConverter<Foo?, int?>` (both nullable) — almost always wrong |

### Shared Database Rules (7 rules)

These rules apply to all database packages including Drift. They activate at the Recommended tier:

| Rule | Severity | What It Catches |
|------|----------|-----------------|
| `avoid_database_in_build` | WARNING | Database queries inside `build()` methods |
| `require_database_migration` | WARNING | Missing migration strategy |
| `require_database_index` | INFO | Missing indexes on filtered columns |
| `prefer_transaction_for_batch` | WARNING | Multiple writes not wrapped in a transaction |
| `require_yield_after_db_write` | WARNING | Missing UI yield after database writes |
| `suggest_yield_after_db_read` | INFO | Consider yielding after bulk reads |
| `avoid_return_await_db` | INFO | Unnecessary `return await` on database calls |

## Safe Patterns

### Enum Storage: By Name

```dart
class PriorityConverter extends TypeConverter<Priority, String> {
  const PriorityConverter();

  @override
  Priority fromSql(String fromDb) =>
    Priority.values.firstWhere((e) => e.name == fromDb,
      orElse: () => Priority.medium);

  @override
  String toSql(Priority value) => value.name;
}
```

### Enum Storage: By Explicit Code

```dart
enum Priority {
  low(0), medium(10), high(20), urgent(30);
  const Priority(this.code);
  final int code;

  static Priority fromCode(int code) =>
    Priority.values.firstWhere((e) => e.code == code,
      orElse: () => Priority.medium);
}

class PriorityConverter extends TypeConverter<Priority, int> {
  const PriorityConverter();

  @override
  Priority fromSql(int fromDb) => Priority.fromCode(fromDb);

  @override
  int toSql(Priority value) => value.code;
}
```

### Database Lifecycle with Riverpod

```dart
final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase(driftDatabase(name: 'app'));
  ref.onDispose(() => db.close());
  return db;
});

final todosProvider = StreamProvider<List<TodoItem>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.select(db.todoItems).watch();
});
```

### Database Lifecycle with Bloc

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
    _sub?.cancel();
    return super.close();
  }
}
```

### Proper Migration Strategy

```dart
@DriftDatabase(tables: [TodoItems, Categories])
class AppDatabase extends _$AppDatabase {
  AppDatabase(QueryExecutor e) : super(e);

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (migrator) async {
      await migrator.createAll();
    },
    onUpgrade: (migrator, from, to) async {
      if (from < 2) {
        await migrator.addColumn(todoItems, todoItems.dueDate);
      }
      if (from < 3) {
        await migrator.createTable(categories);
      }
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );
}
```

### Batch Operations

```dart
// BAD - individual inserts in a loop (10-100x slower)
for (final companion in companions) {
  await into(todoItems).insert(companion);
}

// GOOD - single batch for bulk inserts
await batch((b) {
  b.insertAll(todoItems, companions);
});
```

### Background Database (Mobile)

```dart
// GOOD - runs SQLite on a background isolate
final db = AppDatabase(NativeDatabase.createInBackground(file));

// GOOD - drift_flutter handles isolation automatically
final db = AppDatabase(driftDatabase(name: 'app'));

// BAD - blocks the UI thread
final db = AppDatabase(NativeDatabase(file));
```

## Migration Considerations

### From Isar to Drift

If migrating from Isar, saropa_lints detects both packages being imported simultaneously (`avoid_isar_import_with_drift`) to flag incomplete migrations.

### Web Platform

For web targets, prefer `drift_flutter`'s `driftDatabase()` which automatically selects the best storage strategy. Avoid `unsafeIndexedDb` which is not safe for multiple browser tabs.

## Compatibility

- **saropa_lints version**: All Drift rules require saropa_lints v6.1.0+
- **Drift version**: All rules target Drift v2.0+ (the `drift` package, not legacy `moor`)
- **Drift analyzer plugin**: Both plugins coexist safely — Drift's plugin analyzes `.drift` SQL files while saropa_lints analyzes your Dart usage patterns
- **Generated code**: Generated `*.g.dart` and `*.drift.dart` files should be excluded via `analysis_options.yaml` to avoid false positives

## Contributing

Have ideas for more Drift rules? Found a pattern we should catch? Contributions are welcome!

See [CONTRIBUTING.md](https://github.com/saropa/saropa_lints/blob/main/CONTRIBUTING.md) for guidelines on adding new rules.

## Getting Help

- [GitHub Issues](https://github.com/saropa/saropa_lints/issues)
- [Full Documentation](https://pub.dev/packages/saropa_lints)
- [Drift Documentation](https://drift.simonbinder.eu/)

---

Questions about Drift rules? Open an issue - we're happy to help.
