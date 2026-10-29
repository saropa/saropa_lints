# BUG: `avoid_ignoring_return_values` — Flags a call whose return type is `Never` (`Error.throwWithStackTrace`)

**Status: Open**

Created: 2026-10-29
Rule: `avoid_ignoring_return_values`
File: `lib/src/rules/code_quality/code_quality_avoid_rules.dart` (line ~4282)
Severity: False positive
Rule version: v2 | Since: see rule dartdoc | Updated: see rule dartdoc

---

## Summary

The rule reports a call whose static return type is `Never` (for example `Error.throwWithStackTrace(...)`) as an ignored return value. A `Never` call cannot produce a value, so nothing is ignored.

---

## Attribution Evidence

```bash
# Positive — rule IS defined here
grep -rn "'avoid_ignoring_return_values'" lib/src/rules/
# Actual output: lib/src/rules/code_quality/code_quality_avoid_rules.dart:4282:    'avoid_ignoring_return_values',
```

**Emitter registration:** `lib/src/rules/code_quality/code_quality_avoid_rules.dart:4282`
**Rule class:** `AvoidIgnoringReturnValuesRule` — registered in `lib/saropa_lints.dart:2612`
**Diagnostic `source` / `owner` as seen in Problems panel:** `saropa_lints` / `saropaLintsLsp`
Negative grep not needed: the diagnostic source is `saropa_lints` and the code matches only this repo.

---

## Reproducer

Copied from `lib/database/file_backup/encryption/backup_key_store.dart` lines 80-87 and 133-152 of the `contacts` project (simplified only by removing the Keychain / Block Store plugin calls).

```dart
import 'dart:async';
import 'dart:typed_data';

class BackupKeyStoreException implements Exception {
  const BackupKeyStoreException(this.message, {this.unsupported = false});
  final String message;
  final bool unsupported;
}

class IosKeychainBackupKeyStore {
  Future<Uint8List?> read(String name) async {
    try {
      await Future<void>.delayed(Duration.zero); // stands in for FlutterSecureStorage.read
      return null;
    } on Object catch (error, stack) {
      // LINT (false positive): [avoid_ignoring_return_values] at 12:7-96
      // `Error.throwWithStackTrace` has static return type `Never`; it cannot return.
      Error.throwWithStackTrace(BackupKeyStoreException('Keychain read failed: $error'), stack);
    }
  }
}

void main() {}
```

`dart analyze` on this file reports no compile error: the function body ends in a `Never`-typed call, so no `return` is needed. The `saropa_lints` diagnostic is the only report.

**Frequency:** Always for this pattern.

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | No diagnostic (code is correct) |
| **Actual** | `[avoid_ignoring_return_values] Return value of this invocation is ignored. Discarding return values can hide bugs where an important result (a Future, a boolean success flag, or a parsed value) is silently lost. Assign the result to a variable or remove the call if it is truly unnecessary. {v2}` reported at `backup_key_store.dart` 85:7-85:96, 94:7-94:97, 122:7 (multi-line call to 122:8 end of range), 145:7 |

---

## AST Context

```
MethodDeclaration (IosKeychainBackupKeyStore.read)
  └─ BlockFunctionBody (async)
      └─ Block
          └─ TryStatement
              └─ CatchClause (on Object catch (error, stack))
                  └─ Block
                      └─ ExpressionStatement
                          └─ MethodInvocation (Error.throwWithStackTrace)  <- node reported here (reporter.atNode(expression))
```

---

## Root Cause

In `AvoidIgnoringReturnValuesRule.runWithReporter` (`code_quality_avoid_rules.dart` ~4350-4459) every `ExpressionStatement` whose expression is a `MethodInvocation` is checked. The static type of the invocation is read at ~4375 (`returnType = expression.staticType`). The only "no meaningful value" exclusions are at lines 4445-4447:

```dart
if (returnType == null || returnType is VoidType) return;
if (returnType is DynamicType) return;
if (returnType.isDartCoreNull) return;
```

`Error.throwWithStackTrace` is declared `static Never throwWithStackTrace(Object error, StackTrace stackTrace)`. Its static type is `NeverType`, which is none of `VoidType`, `DynamicType` or Null. Execution falls through to `reporter.atNode(expression)` at line 4458.

### Why the code is correct

A call typed `Never` never returns normally, so there is no return value that could be ignored. The rule's own message ("Assign the result to a variable") cannot be satisfied: assigning a `Never` result produces unreachable code, and the project lint `dead_code` would then flag the next line. `Error.throwWithStackTrace` is also the remedy another saropa_lints rule (`avoid_throw_in_catch_block`) recommends for rethrowing a wrapped error with the original stack trace.

### All affected project locations (project `contacts`, line numbers as reported by the diagnostics)

- /Users/craighathaway/Documents/src/contacts/lib/database/file_backup/encryption/backup_key_store.dart:85
- /Users/craighathaway/Documents/src/contacts/lib/database/file_backup/encryption/backup_key_store.dart:94
- /Users/craighathaway/Documents/src/contacts/lib/database/file_backup/encryption/backup_key_store.dart:122
- /Users/craighathaway/Documents/src/contacts/lib/database/file_backup/encryption/backup_key_store.dart:145

---

## Suggested Fix

In `code_quality_avoid_rules.dart` after line 4447 add:

```dart
if (returnType is NeverType) return;
```

(`NeverType` is exported by `package:analyzer/dart/element/type.dart`, already imported for `VoidType`/`DynamicType`.)

---

## Fixture Gap

The fixture for `avoid_ignoring_return_values` should include:

1. `Error.throwWithStackTrace(e, s);` inside a catch block — expect NO lint.
2. `exit(1);` (`dart:io`, returns `Never`) as a statement — expect NO lint.
3. A user function `Never fail() => throw StateError('x');` called as `fail();` — expect NO lint.
4. `int.parse('42');` as a statement — expect LINT (unchanged).
5. `list.map((e) => e * 2);` as a statement — expect LINT (unchanged).

---

## Changes Made

<!-- Fill in when a fix is written. -->

---

## Tests Added

<!-- Fill in when a fix is written. -->

---

## Commits

<!-- Add commit hashes as fixes land. -->

---

## Environment

- saropa_lints version: 17.0.1-beta.2
- Dart SDK version: 3.13.7 (stable) (Thu Oct 22 14:28:57 2026 -0700) on "macos_arm64"
- custom_lint version: not used (analyzer-plugin diagnostics via the VS Code extension, source `saropa_lints`, owner `saropaLintsLsp`)
- Triggering project: /Users/craighathaway/Documents/src/contacts (Flutter app, package `saropa`)
