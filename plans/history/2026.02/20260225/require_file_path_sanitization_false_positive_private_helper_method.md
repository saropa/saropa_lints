# `require_file_path_sanitization` False Positive on Private Helper Receiving Platform Path

## Status: RESOLVED

## Summary

`require_file_path_sanitization` fires on `File()` constructors inside private helper methods that receive a trusted platform directory path as a parameter. The rule's `_isFromPlatformPathApi` heuristic only inspects the body of the **enclosing** function for platform API calls. When the platform API is called in the **caller** and the result is passed to a private helper, the heuristic fails — identical root cause to the sibling `avoid_path_traversal` false positive (see `avoid_path_traversal_false_positive_private_helper_method.md`).

## Severity

**High** — The diagnostic says "Path traversal attack possible with ../" for a code path where every component is either hardcoded or platform-provided. Combined with the simultaneous `avoid_path_traversal` warning on the same line, the developer sees two security warnings on provably safe code, accelerating warning fatigue.

## Reproducer

### Code that falsely triggers the warning

`lib/data/database/app_database.dart`:

```dart
static QueryExecutor _openConnection(String encryptionKey) {
  return LazyDatabase(() async {
    // ...
    final dbDir = await getApplicationDocumentsDirectory();  // ← trusted platform API
    // ...
    await _deleteOldUnencryptedDb(dbDir.path);  // ← passes dbDir.path to helper
    // ...
  });
}

static Future<void> _deleteOldUnencryptedDb(String dbDirPath) async {
  for (final suffix in ['', '-wal', '-shm']) {          // ← hardcoded literal list
    final oldFile = File('$dbDirPath/kykto_db.sqlite$suffix');  // ← FLAGGED (line 79)
    if (await oldFile.exists()) {
      await oldFile.delete();
    }
  }
}
```

**Diagnostic produced:**
```
[require_file_path_sanitization] File path constructed from parameter
without sanitization. Path traversal attack possible with ../ {v3}
```

**Why this is wrong:**

1. `dbDirPath` originates from `getApplicationDocumentsDirectory().path` at the single call site — a trusted Flutter platform API, not user input.
2. `suffix` is a loop variable iterating over the literal list `['', '-wal', '-shm']` — not a parameter and not user-controlled.
3. The filename `kykto_db.sqlite` is a hardcoded string literal.
4. `_deleteOldUnencryptedDb` is private (`_` prefix) with exactly one call site in the same class. No external code can call it with arbitrary input.
5. The rule's own documentation example shows a function that takes a user-provided `filename` — the parameter in the reproducer is a **directory path from a platform API**, which is a fundamentally different trust level.

## Root Cause

### Location

`lib/src/rules/file_handling_rules.dart` — `RequireFilePathSanitizationRule._checkForUnsanitizedPath()`, line ~1647.

### The detection logic step-by-step

```dart
void _checkForUnsanitizedPath(node, pathSource, reporter, context) {
  // 1. Gets the function body of _deleteOldUnencryptedDb
  final FunctionBody? body = node.thisOrAncestorOfType<FunctionBody>();
  final String bodySource = body.toSource();

  // 2. Checks for sanitization patterns in the body:
  //    'basename', 'isWithin', 'normalize', 'sanitize', 'replaceAll', '..'
  //    → None found. ✗

  // 3. _isFromPlatformPathApi(bodySource) → searches for platform API names
  //    in the body of _deleteOldUnencryptedDb:
  //
  //    "async { for (final suffix in ['', '-wal', '-shm']) {
  //      final oldFile = File('$dbDirPath/kykto_db.sqlite$suffix');
  //      if (await oldFile.exists()) { await oldFile.delete(); } } }"
  //
  //    This body does NOT contain 'getApplicationDocumentsDirectory'.
  //    The API call is in _openConnection(), the CALLER.
  //    → returns false ✗

  // 4. Gets function parameters: (String dbDirPath)
  //    Checks if 'dbDirPath' appears in pathSource
  //    '$dbDirPath/kykto_db.sqlite$suffix' contains 'dbDirPath'
  //    → reports the node. FALSE POSITIVE.
}
```

### The fundamental problem

Same as `avoid_path_traversal`: **intra-procedural analysis cannot trace trust across function boundaries**. The rule's `_isFromPlatformPathApi` checks whether the enclosing function body contains a platform API call, but the platform API call is in the caller. Extracting logic into a private helper method — a standard refactoring practice — breaks the trust chain.

### Difference from the rule's own "BAD" example

The rule's documentation example shows:
```dart
Future<File> getUserFile(String filename) async {
  final dir = await getApplicationDocumentsDirectory();
  return File('${dir.path}/$filename');  // User could pass '../../../etc/passwd'!
}
```

This is a **public** method with a parameter named `filename` that is clearly user-provided input, and the platform API call is in the **same** function body (so `_isFromPlatformPathApi` would actually catch this case if the check ran before the parameter check — but the parameter `filename` represents untrusted user content).

The flagged code is fundamentally different:
- **Private** method (`_` prefix), not part of any public API
- Parameter is a **directory path**, not a user-provided filename
- Parameter value provably comes from a platform API at the single call site
- No user-controlled data enters the path composition at any point

## Suggested Fix

### Approach A: Inter-procedural trust for private methods (recommended)

For private methods with a single call site (or few call sites) in the same compilation unit, trace the actual argument at the call site. If the argument is derived from a platform API result, suppress the warning:

```dart
void _checkForUnsanitizedPath(node, pathSource, reporter, context) {
  // ... existing checks ...

  // NEW: For private methods, check if the parameter's actual value
  // at call sites originates from a platform API
  final MethodDeclaration? method = node.thisOrAncestorOfType<MethodDeclaration>();
  if (method != null && method.name.lexeme.startsWith('_')) {
    if (_paramOriginatesFromPlatformApi(method, paramName, context)) return;
  }

  reporter.atNode(node);
}
```

### Approach B: Shared heuristic with `avoid_path_traversal`

Both rules have independent but identical `_platformPathApis` sets and `_isFromPlatformPathApi` methods. Extract the inter-procedural trust check into a shared utility (similar to `target_matcher_utils.dart`) so both rules benefit from the same fix:

```dart
// In a shared utility file
bool isParameterFromTrustedPlatformApi(
  AstNode node,
  String paramName,
  CompilationUnit unit,
) {
  // 1. Check enclosing function body (existing behavior)
  // 2. If enclosing method is private, find call sites in same unit
  // 3. At each call site, check if the argument at the matching position
  //    is derived from a _platformPathApis call
}
```

This avoids duplicating the fix in two rule files and keeps them consistent.

### Approach C: Suppress when all interpolated parts are trusted

If a `File()` path's interpolated expressions consist entirely of:
- Function/method parameters (not proven untrusted)
- Loop variables from literal collections
- String literals

...and the enclosing method is private, the risk of user-controlled path traversal is negligible. Suppress at INFO severity at most, not WARNING.

## Related

- Sibling report: `avoid_path_traversal_false_positive_private_helper_method.md` (same code, same root cause, different rule)
- Both rules share identical `_platformPathApis` sets — a fix should be applied to both simultaneously

## Environment

- **saropa_lints**: path dependency from `D:\src\saropa_lints`
- **Rule file**: `lib/src/rules/file_handling_rules.dart` line 1590
- **Rule version**: v3
- **Test project**: `D:\src\saropa_kykto`
- **Triggered in**: `lib/data/database/app_database.dart:79`
- **Method flagged**: `_deleteOldUnencryptedDb` (private static, single call site)
- **Parameter origin**: `getApplicationDocumentsDirectory().path` (Flutter `path_provider` package)
