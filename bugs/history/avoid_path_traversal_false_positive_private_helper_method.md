# `avoid_path_traversal` False Positive on Private Helper Receiving Platform Path

## Status: RESOLVED

## Summary

`avoid_path_traversal` fires on `File()` constructors inside private helper methods that receive a trusted platform directory path as a parameter. The rule's `_isFromPlatformPathApi` heuristic only inspects the body of the **enclosing** function for platform API calls, but when the platform API (`getApplicationDocumentsDirectory`) is called in the **caller** and the result is passed to a private helper, the heuristic fails. The rule cannot see across function boundaries.

## Severity

**High** — The rule claims a "critical security risk" for code that has zero user-controlled input. This trains developers to ignore path traversal warnings or blanket-suppress with `// ignore:`, which defeats the purpose of the rule when real path traversal vulnerabilities exist.

## Reproducer

### Code that falsely triggers the warning

`lib/data/database/app_database.dart`:

```dart
static QueryExecutor _openConnection(String encryptionKey) {
  return LazyDatabase(() async {
    // ...
    final dbDir = await getApplicationDocumentsDirectory();  // ← trusted platform API
    final file = File('${dbDir.path}/kykto_encrypted.db');

    await _deleteOldUnencryptedDb(dbDir.path);  // ← passes platform path to helper
    // ...
  });
}

/// Deletes the old unencrypted database files from v0.1.0 pre-encryption
/// builds. Safe to remove this method after initial rollout.
static Future<void> _deleteOldUnencryptedDb(String dbDirPath) async {
  for (final suffix in ['', '-wal', '-shm']) {
    final oldFile = File('$dbDirPath/kykto_db.sqlite$suffix');  // ← FLAGGED
    if (await oldFile.exists()) {
      await oldFile.delete();
    }
  }
}
```

**Diagnostic produced:**
```
[avoid_path_traversal] File paths constructed from user input may allow
path traversal attacks (e.g., "../"), enabling access to sensitive files
outside the intended directory. This is a critical security risk. {v8}
```

**Why this is wrong:**

1. `dbDirPath` comes from `getApplicationDocumentsDirectory().path` — a Flutter platform API returning the OS-managed app documents directory. This is not user input.
2. `suffix` comes from a hardcoded literal list `['', '-wal', '-shm']`. This is not user input.
3. The filename `kykto_db.sqlite` is a hardcoded string literal.
4. `_deleteOldUnencryptedDb` is a **private static method** (`_` prefix) with exactly one call site in the same class, where the argument provably originates from `getApplicationDocumentsDirectory()`.
5. There is no code path through which user-controlled data can reach this `File()` constructor.

## Root Cause

### Location

`lib/src/rules/security_rules.dart` — `AvoidPathTraversalRule.runWithReporter()`, line ~3206.

### The detection logic step-by-step

```dart
context.addInstanceCreationExpression((InstanceCreationExpression node) {
  // 1. typeName = 'File' → passes ✓
  // 2. argSource = '$dbDirPath/kykto_db.sqlite$suffix' → contains '$' → passes ✓
  // 3. _getFunctionParameters(node) → returns parameters of _deleteOldUnencryptedDb:
  //    (String dbDirPath)
  // 4. 'dbDirPath' appears in argSource → usedParam = 'dbDirPath' ✓
  // 5. _isFromPlatformPathApi(node) → checks body of _deleteOldUnencryptedDb:
  //
  //    async {
  //      for (final suffix in ['', '-wal', '-shm']) {
  //        final oldFile = File('$dbDirPath/kykto_db.sqlite$suffix');
  //        if (await oldFile.exists()) { await oldFile.delete(); }
  //      }
  //    }
  //
  //    This body does NOT contain 'getApplicationDocumentsDirectory' or any
  //    other platform API name. The API call is in _openConnection(), the CALLER.
  //    → returns false ✗
  //
  // 6. _hasPathValidation(node) → body doesn't contain 'basename', 'isWithin',
  //    'sanitize', etc. → returns false ✗
  //
  // 7. Reports the node as a path traversal risk. FALSE POSITIVE.
});
```

### The fundamental problem

`_isFromPlatformPathApi` performs **intra-procedural analysis only** — it checks whether the current function's body calls a platform API. But when trusted paths are passed through helper methods (a standard code organization practice), the trust chain is broken. The rule sees a `String` parameter used in a `File()` constructor and has no way to know it came from a trusted source.

This is a common pattern: extract a reusable or logically separate operation into a private helper method, pass the directory path as a parameter. The rule punishes good code organization.

### Other code patterns that would falsely trigger

```dart
// Any private helper that receives a platform path
static Future<void> _cleanupTempFiles(String tempDirPath) async {
  final file = File('$tempDirPath/cache.tmp');  // FALSE POSITIVE
  // tempDirPath came from getTemporaryDirectory() in the caller
}

// Factory methods
static File _dbFile(String appDocsPath) {
  return File('$appDocsPath/app.db');  // FALSE POSITIVE
  // appDocsPath came from getApplicationDocumentsDirectory() in the caller
}

// Drift/database setup patterns (extremely common)
static LazyDatabase _open(String dbPath) {
  return LazyDatabase(() async {
    return NativeDatabase(File('$dbPath/drift.sqlite'));  // FALSE POSITIVE
  });
}
```

## Suggested Fix

### Approach A: Trace trust through private call sites (recommended)

For private methods (`_` prefix) with a small number of call sites, trace the actual argument expressions at each call site. If all call sites pass values derived from platform APIs, the parameter is trusted:

```dart
// Pseudocode for enhanced _isFromPlatformPathApi
bool _isFromPlatformPathApi(AstNode node) {
  // Existing: check enclosing function body
  final FunctionBody? body = node.thisOrAncestorOfType<FunctionBody>();
  if (body != null && _bodyContainsPlatformApi(body.toSource())) return true;

  // NEW: for private methods, check call sites in the same class
  final MethodDeclaration? method = node.thisOrAncestorOfType<MethodDeclaration>();
  if (method != null && method.name.lexeme.startsWith('_')) {
    final ClassDeclaration? classDecl = method.thisOrAncestorOfType<ClassDeclaration>();
    if (classDecl != null) {
      // Find all invocations of this private method within the class
      // Check if the corresponding argument at each call site originates
      // from a platform API in the caller's scope
    }
  }
  return false;
}
```

### Approach B: Recognize hardcoded-only path composition (simpler)

If the `File()` argument's interpolated parts consist entirely of:
- Parameters that match names like `*Dir*`, `*Path*`, `*Directory*` (heuristic for directory paths)
- String literals (hardcoded filenames)
- Loop variables from literal lists

...then the path is not constructed from "user input" in any meaningful sense. At minimum, skip when ALL non-literal interpolation parts come from parameters whose names strongly suggest directory paths AND the method is private.

### Approach C: Check caller context for direct callers in same compilation unit

Walk the compilation unit AST to find all `MethodInvocation` nodes that call the flagged method. For each call site, check whether the argument expression at the matching parameter position is derived from a platform API call. This is more expensive but precise.

## Environment

- **saropa_lints**: path dependency from `D:\src\saropa_lints`
- **Rule file**: `lib/src/rules/security_rules.dart` line 3175
- **Rule version**: v8
- **Test project**: `D:\src\saropa_kykto`
- **Triggered in**: `lib/data/database/app_database.dart:79`
- **Method flagged**: `_deleteOldUnencryptedDb` (private static, single call site)
- **Parameter origin**: `getApplicationDocumentsDirectory().path` (Flutter `path_provider` package)
