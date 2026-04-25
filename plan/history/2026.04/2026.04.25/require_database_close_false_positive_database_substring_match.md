# BUG: `require_database_close` — fires on methods that merely contain the substring `Database(` (regex over-matches identifiers)

**Status: Fixed (implemented)**

Created: 2026-04-25
Rule: `require_database_close`
File: `lib/src/rules/resources/resource_management_rules.dart` (line ~174)
Severity: False positive
Rule version: v6 | Since: unknown | Updated: unknown

---

## Summary

The detector's "open" pattern is a regex —
`r'openDatabase\s*\(|Database\s*\(|SqliteDatabase\s*\('` — applied to the
method body's raw source text. The middle alternative `Database\s*\(` matches
ANY identifier ending in `Database(`, e.g.
`processCommandDatabase(...)`, `initIsarDatabase(...)`,
`SyncDatabase(...)`, `_helperDatabase(...)`. That is — every method whose body
calls a method whose name happens to end in `Database(` is flagged as
"opens a DB but never closes one", even when no DB connection is opened.

---

## Attribution Evidence

```bash
# Positive — rule IS defined here
grep -rn "'require_database_close'" lib/src/rules/
# lib/src/rules/resources/resource_management_rules.dart:163:    'require_database_close',
```

**Emitter registration:** `lib/src/rules/resources/resource_management_rules.dart:163`
**Diagnostic `source` / `owner` as seen in Problems panel:** `saropa_lints`

---

## Reproducer

### Case 1 — dispatcher with no DB open/close

```dart
abstract final class CommandDispatcher {
  // LINT — but should NOT lint
  // Body contains 'processCommandDatabase(' which the regex captures via
  // its `Database\s*\(` alternative. This method doesn't open a database;
  // it routes a command to a sub-handler.
  static Future<bool> processCommandType({
    required String commandType,
    required String commandText,
  }) async {
    switch (commandType) {
      case 'database':
        return RunDatabaseCommands.processCommandDatabase(commandText);
      case 'screen':
        return RunScreenCommands.processCommandScreen(commandText);
    }
    return false;
  }
}

abstract final class RunDatabaseCommands {
  static Future<bool> processCommandDatabase(String code) async => true;
}
```

### Case 2 — re-init helper with no DB open/close

```dart
abstract final class IsarConfig {
  static Future<bool> initIsarDatabase({required String caller}) async => true;
}

class AppLifecycle {
  // LINT — but should NOT lint
  // Body calls `IsarConfig.initIsarDatabase(...)`; substring `Database(` is
  // present, so the regex flags this method even though no Database(...) /
  // openDatabase(...) / SqliteDatabase(...) constructor is invoked here.
  Future<void> handleResumed() async {
    await IsarConfig.initIsarDatabase(caller: 'resume');
  }
}
```

**Frequency:** Always — every method whose body contains any
`*Database(` substring (method calls, factory invocations, generic-typed
expressions) is flagged regardless of whether a DB connection is opened.

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | No diagnostic — these methods do not open a DB connection |
| **Actual** | `[require_database_close] Unclosed database connection leaks resources...` reported on the entire `MethodDeclaration` |

---

## AST Context

Detector currently operates on `body.toSource()` text, not AST. It does not
walk `MethodInvocation` / `InstanceCreationExpression` nodes — so the
"is this an actual constructor of `Database` / `SqliteDatabase`" question
is never asked.

---

## Root Cause

Regex `Database\s*\(` in `_dbOpenInvocationOnly`
(`resource_management_rules.dart:174-176`) is unanchored, so it matches
inside any longer identifier (suffix match):

```dart
static final RegExp _dbOpenInvocationOnly = RegExp(
  r'openDatabase\s*\(|Database\s*\(|SqliteDatabase\s*\(',
);
```

Substrings that match unintentionally (real-world examples):

- `processCommandDatabase(` (project dispatcher pattern)
- `initIsarDatabase(`, `initDriftDatabase(` (config init helpers)
- `closeIsarDatabase(`, `resetDatabase(` (lifecycle helpers — ironic, since these CLOSE the DB)
- `MockDatabase(` (test factories)
- `SyncDatabase(`, `MyAppDatabase(` (any subclass / wrapper class name ending in `Database`)

The intent is "true `Database(...)` constructor, not a method ending in the
word Database". Word-boundary anchoring would fix the ambiguity.

---

## Suggested Fix

### Option A — anchor with a word boundary

Replace the middle alternative so it only matches when `Database` is preceded
by a non-identifier character:

```dart
static final RegExp _dbOpenInvocationOnly = RegExp(
  r'(?<![A-Za-z0-9_])Database\s*\(|openDatabase\s*\(|SqliteDatabase\s*\(',
);
```

This still matches `Database(...)` standalone but rejects `XxxDatabase(`.

### Option B — replace regex with an AST visitor

Walk `InstanceCreationExpression` nodes and check
`node.constructorName.type.name.lexeme == 'Database'` (and similarly for
`SqliteDatabase`). For `MethodInvocation`, check `node.methodName.name == 'openDatabase'`.
This is the project's stated preference (see `BUG_REPORT_GUIDE.md` —
"String matching for types — `name.contains('Stream')` matches `upstream`").

Option B is the durable fix; Option A is the lower-risk hot-patch.

---

## Resolution

Implemented via AST-based detection in `lib/src/rules/resources/resource_management_rules.dart`:

- Replaced `_dbOpenInvocationOnly` regex matching against `body.toSource()`.
- Added `_DatabaseOpenInvocationVisitor` that only marks methods as DB-opening when it sees:
  - `MethodInvocation` with method name `openDatabase`, or
  - `InstanceCreationExpression` with constructor type `Database` / `SqliteDatabase`.

This removes substring false positives such as `processCommandDatabase(...)` and `initIsarDatabase(...)` while preserving true positives for real open calls.

Fixture coverage extended in `example/lib/resource_management/require_database_close_fixture.dart` with non-lint cases for:

- helper method call `processCommandDatabase(...)`
- helper class construction `SyncDatabase(...)`

---

## Fixture Gap

The fixture should add cases that name-collide with the substring:

1. `processCommandDatabase(...)` invocation — expect NO lint.
2. `initIsarDatabase(...)` / `initDriftDatabase(...)` — expect NO lint.
3. `MockDatabase(...)` constructor in a test — expect NO lint (or expect
   based on file-type rules).
4. Subclass `class AppDatabase extends GeneratedDatabase` constructed with
   `AppDatabase(...)` — expect LINT (this IS a database, even though the
   class name has a prefix).
5. Bare `Database(...)` constructor — expect LINT (the genuine case).

---

## Environment

- saropa_lints version: see `pubspec.yaml`
- Triggering project: `D:/src/contacts`
- Triggering files:
  - `lib/utils/system/system_commands/run_system_command.dart` (`processCommandType` ~L283)
  - `lib/views/main_material_app.dart` (`_handleAppResumedAsync` ~L259)
