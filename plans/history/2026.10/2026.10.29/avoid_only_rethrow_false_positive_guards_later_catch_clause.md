# BUG: `avoid_only_rethrow` — Flags `on SpecificException { rethrow; }` that shields the exception from a later broader catch clause

**Status: Open**

Created: 2026-10-29
Rule: `avoid_only_rethrow`
File: `lib/src/rules/flow/exception_rules.dart` (line ~118)
Severity: False positive
Rule version: v4 | Since: see rule dartdoc | Updated: see rule dartdoc

---

## Summary

The rule reports an `on SpecificType { rethrow; }` clause that precedes a broader catch clause in the same `try`. Removing it changes which clause handles the exception, so it is not dead code.

---

## Attribution Evidence

```bash
# Positive — rule IS defined here
grep -rn "'avoid_only_rethrow'" lib/src/rules/
# Actual output: lib/src/rules/flow/exception_rules.dart:118:    'avoid_only_rethrow',
```

**Emitter registration:** `lib/src/rules/flow/exception_rules.dart:118`
**Rule class:** `AvoidOnlyRethrowRule` — registered in `lib/saropa_lints.dart:260`
**Diagnostic `source` / `owner` as seen in Problems panel:** `saropa_lints` / `saropaLintsLsp`
Negative grep not needed: the diagnostic source is `saropa_lints` and the code matches only this repo.

---

## Reproducer

Copied from `lib/database/file_backup/encryption/backup_key_store.dart:132-152` of the `contacts` project (plugin call replaced by a plain future).

```dart
import 'dart:async';

class BackupKeyStoreException implements Exception {
  const BackupKeyStoreException(this.message, {this.unsupported = false});
  final String message;
  final bool unsupported;
}

bool _isUnsupported(Object error) => error is TimeoutException;

Future<bool> _save() => Future<bool>.value(false);

Future<void> write() async {
  try {
    final bool saved = await _save().timeout(const Duration(seconds: 15));
    if (!saved) {
      throw const BackupKeyStoreException('Block Store refused the write');
    }
  } on BackupKeyStoreException {
    rethrow; // LINT (false positive): [avoid_only_rethrow] at 20:5-22:5 (the whole catch clause)
  } on Object catch (error, stack) {
    Error.throwWithStackTrace(
      BackupKeyStoreException(
        'Block Store write failed: $error',
        unsupported: _isUnsupported(error),
      ),
      stack,
    );
  }
}

void main() {}
```

Deleting the flagged clause changes behavior: the `BackupKeyStoreException` thrown on the `!saved` branch would then be caught by `on Object` and re-wrapped in a second `BackupKeyStoreException` ("Block Store write failed: ...") with `unsupported` computed from the wrong error.

**Frequency:** Always for this pattern.

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | No diagnostic (code is correct) |
| **Actual** | `[avoid_only_rethrow] Catch-rethrow with no handling is dead code that adds nesting and complexity without providing any value. {v4}` reported at `backup_key_store.dart` 142:7 to 144:7 (the `on BackupKeyStoreException { rethrow; }` clause) |

---

## AST Context

```
MethodDeclaration (write)
  └─ BlockFunctionBody (async)
      └─ Block
          └─ TryStatement
              ├─ Block (try body)
              ├─ CatchClause (on BackupKeyStoreException)   <- node reported here (reporter.atNode(node))
              │   └─ Block
              │       └─ ExpressionStatement (RethrowExpression)
              └─ CatchClause (on Object catch (error, stack))   <- later sibling the first clause protects
```

---

## Root Cause

`runWithReporter` (`exception_rules.dart` ~130-141) visits every `CatchClause`. It reports when the body has exactly one statement and that statement is a `RethrowExpression` (the condition at line 134-135: `body.statements.length == 1` and `statement.expression is RethrowExpression`). It does not look at `node.parent` (the `TryStatement`) to see whether another catch clause follows. The class dartdoc example is a try with a single catch, where removal is safe; with several clauses Dart picks the FIRST matching clause, so an earlier `rethrow` clause is the only way to exempt a type from a later broader clause.

### Why the code is correct

Dart evaluates catch clauses in order and runs only the first match. `on BackupKeyStoreException { rethrow; }` exists to stop `on Object catch` from wrapping an already-wrapped exception. Removing it changes the thrown type chain and the `unsupported` flag, so it is not dead code. The pattern (specific type rethrown ahead of a catch-all that wraps) is a common idiom.

### All affected project locations (project `contacts`, line numbers as reported by the diagnostics)

- /Users/craighathaway/Documents/src/contacts/lib/database/file_backup/encryption/backup_key_store.dart:142

---

## Suggested Fix

In the `addCatchClause` callback, after confirming the body is a single `rethrow`, look at `node.parent`: if it is a `TryStatement` and the catch clause is NOT the last element of `tryStatement.catchClauses` (or a later clause's exception type is a supertype of this clause's type, or the later clause has no `on` type), return without reporting.

---

## Fixture Gap

The fixture for `avoid_only_rethrow` should include:

1. `try {} on FormatException { rethrow; } on Object catch (e) { log(e); }` — expect NO lint.
2. `try {} catch (e) { rethrow; }` (single clause) — expect LINT.
3. `try {} on FormatException { rethrow; } on StateError catch (e) { log(e); }` (later clause is unrelated type) — expect LINT.
4. `try {} on FormatException catch (e) { rethrow; } finally { cleanup(); }` — expect LINT (single clause; finally does not shield).

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
