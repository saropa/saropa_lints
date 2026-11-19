# BUG: `move_variable_closer_to_its_usage` — Variable initialized from an awaited database write is flagged although moving it reorders the writes

**Status: Open**

Created: 2026-10-29
Rule: `move_variable_closer_to_its_usage`
File: `lib/src/rules/code_quality/code_quality_variables_rules.dart` (line ~2450)
Severity: False positive
Rule version: v9 | Since: unknown | Updated: 17.0.1-beta.2

---

## Summary

The declaration `final int deleted = await (db.delete(...)).go();` is flagged because the first use (`return deleted;`) is three statements later. The initializer is an awaited side-effecting write; moving the declaration down moves the write after the other deletes in the same transaction. The rule only protects an awaiting initializer when the declaration is directly in a `try` block with a handler.

---

## Attribution Evidence

```bash
grep -rn "'move_variable_closer_to_its_usage'" lib/src/rules/
lib/src/rules/code_quality/code_quality_variables_rules.dart:2450:    'move_variable_closer_to_its_usage',
```

Negative grep not applicable: no sibling analyzer repo is checked out beside this one that defines this code; the rule is only defined here.

**Emitter registration:** `lib/src/rules/code_quality/code_quality_variables_rules.dart:2450`
**Rule class:** `MoveVariableCloserToUsageRule` — registered in `715:  MoveVariableCloserToUsageRule.new,`
**Diagnostic `source` / `owner` as seen in Problems panel:** `saropa_lints` / `saropaLintsLsp`

---

## Reproducer

Standalone. Copied from the real project source (path and lines below) with project-specific types replaced by the real package types where one exists.

Project source: `lib/database/drift_middleware/user_data/contact_drift_io.dart` lines 1182-1210 (`dbContactDeleteAll`, inside `db.transaction<int>(() async { ... })`).

```dart
Future<int> deleteRows(String table) async => 1;

Future<int> inTransaction(Future<int> Function() body) => body();

Future<int> wipe() => inTransaction(() async {
  final int deleted = await deleteRows('contacts'); // LINT -- but should NOT lint
  await deleteRows('email_lookups');
  await deleteRows('phone_lookups');
  await deleteRows('coaching_sessions');
  return deleted;
});
```

**Frequency:** Always for this pattern.

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | No diagnostic (code is correct) |
| **Actual** | `[move_variable_closer_to_its_usage] Variable declared far from its first use, with several unrelated statements in between. This forces readers to hold the variable in memory while reading irrelevant code, reducing comprehension and increasing the risk of accidental reuse or shadowing. {v9}` reported at 1183:19-1183:26 of contact_drift_io.dart (the variable name `deleted`) |

---

## AST Context

```
MethodDeclaration (dbContactDeleteAll)
  └─ BlockFunctionBody > Block
      └─ TryStatement > Block
          └─ VariableDeclarationStatement (final int count = await db.transaction<int>(...))
              └─ AwaitExpression > MethodInvocation (db.transaction)
                  └─ ArgumentList > FunctionExpression (() async {...})
                      └─ BlockFunctionBody > Block   <- the block scanned by addBlock
                          ├─ VariableDeclarationStatement
                          │   └─ VariableDeclaration (deleted)   <- reporter.atToken(entry.value.name)
                          ├─ ExpressionStatement (await ...go())  x3
                          └─ ReturnStatement (return deleted)
```

---

## Root Cause

`code_quality_variables_rules.dart:2555-2631` (`_canMoveCloser`). The only guard for an initializer that contains `await` (line 2578-2584) is `_isDirectTryBodyWithHandler(declStatement)` (defined at 2669), which requires the declaration to sit directly in the `try` block. Here the declaration sits in the block of a closure passed to `db.transaction`, so the guard is false and the count of 3 intervening statements (line 2631, `interveningCount >= _minInterveningStatements`) fires the rule. The rule treats the awaited initializer as freely movable although a `.go()` delete is a side effect whose order relative to the later deletes would change.

### Why the code is correct

The first statement deletes the contacts and returns the row count; the next statements delete dependent rows in the same transaction. Moving `final int deleted = await ...` after them changes the write order (foreign-key cascades and the lookup mirror rows depend on it). Keeping the order and the returned count is the intent.

---

## Affected project locations (project: contacts, line numbers before the session's other edits)

- `lib/database/drift_middleware/user_data/contact_drift_io.dart:1183`

---

## Suggested Fix

Extend the guard at lines 2578-2584: return false whenever `decl.initializer` contains an `await` (or any `MethodInvocation` with side effects such as `.go()`, `.write()`, `.insert()`), not only when directly inside a `try` with a handler. An awaited initializer is an ordered side effect; relocating it is never behavior-preserving.

---

## Fixture Gap

The fixture for `move_variable_closer_to_its_usage` should include:

1. awaited initializer, 3 intervening awaited statements, use at the end (any enclosing block) -- expect NO lint
2. pure initializer (`final int n = items.length;`), 3 unrelated statements, use at the end -- expect LINT
3. awaited initializer directly in a `try` with a handler -- expect NO lint (existing behavior)

---

## Changes Made

None yet.

---

## Tests Added

None yet.

---

## Commits

None yet.

---

## Environment

- saropa_lints version: 17.0.1-beta.2
- Dart SDK version: 3.13.7 (stable) (Thu Oct 22 14:28:57 2026 -0700) on "macos_arm64"
- custom_lint version: not used (analyzer plugin via saropaLintsLsp)
- Triggering project/file: /Users/craighathaway/Documents/src/contacts — lib/database/drift_middleware/user_data/contact_drift_io.dart:1183
