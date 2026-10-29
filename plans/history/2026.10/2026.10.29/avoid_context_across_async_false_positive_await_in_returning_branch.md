# BUG: `avoid_context_across_async` — Await inside an early-returning `if` branch puts later statements in the "danger zone"

**Status: Open**

Created: 2026-10-29
Rule: `avoid_context_across_async`
File: `lib/src/rules/core/context_rules.dart` (line ~251)
Severity: False positive
Rule version: v7 | Since: unknown | Updated: 17.0.1-beta.2

---

## Summary

`_checkAsyncBody` scans the statements of a block linearly. Any statement that contains an `await` (including an `if` whose then-branch is `return await x;`) sets `seenAwait`, so a later context use is reported even though that path can never execute after the await.

---

## Attribution Evidence

```bash
grep -rn "'avoid_context_across_async'" lib/src/rules/
lib/src/rules/core/context_rules.dart:251:    'avoid_context_across_async',
```

Negative grep not applicable: no sibling analyzer repo is checked out beside this one that defines this code; the rule is only defined here.

**Emitter registration:** `lib/src/rules/core/context_rules.dart:251`
**Rule class:** `AvoidContextAcrossAsyncRule` — registered in `250:  AvoidContextAcrossAsyncRule.new,`
**Diagnostic `source` / `owner` as seen in Problems panel:** `saropa_lints` / `saropaLintsLsp`

---

## Reproducer

Standalone. Copied from the real project source (path and lines below) with project-specific types replaced by the real package types where one exists.

Project source: `lib/utils/system/system_commands/run_command_user_type.dart` lines 38-79 (`RunUserTypeCommands.processCommandUserType`); the context use is at line 74.

```dart
import 'package:flutter/widgets.dart';

Future<bool> setAccountStandard() async => true;
void failedToast(BuildContext context) {}

class RunCommands {
  static Future<bool> process(BuildContext context, String? code) async {
    try {
      if (code == 'off') {
        return await setAccountStandard(); // the only await; this branch returns
      }
      // No await can have run on any path that reaches this line.
      failedToast(context); // LINT (both rules) -- but should NOT lint
      return false;
    } on Object {
      return false;
    }
  }
}
```

**Frequency:** Always for this pattern.

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | No diagnostic (code is correct) |
| **Actual** | `[avoid_context_across_async] BuildContext used after await crashes if widget was disposed during the async gap. Check mounted first. {v7}` reported at 74:62-74:69 of run_command_user_type.dart |

---

## AST Context

```
ClassDeclaration (RunUserTypeCommands)
  └─ MethodDeclaration (static processCommandUserType)
      └─ BlockFunctionBody > Block
          └─ TryStatement > Block
              ├─ IfStatement (firstCode in Off commands)
              │   └─ Block > ReturnStatement > AwaitExpression   <- containsAwait(statement) == true
              └─ ExpressionStatement
                  └─ MethodInvocation (genericSystemCommandFailedToast)
                      └─ ArgumentList > SimpleIdentifier (context)   <- reported
```

---

## Root Cause

`context_rules.dart:259-278` registers `addMethodDeclaration`; `_checkAsyncBody` (line 290) iterates `block.statements`. A `TryStatement` is handled by `_checkTryBody` (line 296-300 -> body scanned recursively). Inside that body, line 313 `if (containsAwait(statement))` is true for the `IfStatement` because its then-branch contains `return await ...`; line 314-316 set `seenAwait = true` and `continue`. The next statement (`failedToast(context)`) then reaches line 338-340 (`seenAwait && !hasGuard` -> `_reportContextUsage`). The scan has no notion that the statement with the await always returns.

### Why the code is correct

The only `await` is in `return await UserAccountUtils.setAccountStandard();`, inside an `if` block that returns. Control flow cannot reach `genericSystemCommandFailedToast(context)` after that await, so the BuildContext is used on the same synchronous path as the method entry. The `return await` is deliberate: inside `try` it makes the `catch` handle failures of the future.

---

## Affected project locations (project: contacts, line numbers before the session's other edits)

- `lib/utils/system/system_commands/run_command_user_type.dart:74`

---

## Suggested Fix

Replace the linear "any statement containing await sets seenAwait" scan with a control-flow-aware one: a nested statement (`IfStatement` branch, `switch` case) whose block ends in `return`/`throw` must not set `seenAwait` for the statements after the `if`. Minimum viable: when the statement is an `IfStatement` without `else` whose then-branch always completes abruptly (`return`/`throw`) and the await is inside that branch, do not enter the danger zone.

---

## Fixture Gap

The fixture for `avoid_context_across_async` should include:

1. `if (c) { return await f(); } use(context);` -- expect NO lint
2. `await f(); use(context);` -- expect LINT
3. `if (c) { await f(); } use(context);` -- expect LINT (await can precede the use)
4. `await f(); if (!context.mounted) return; use(context);` -- expect NO lint (existing)

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
- Triggering project/file: /Users/craighathaway/Documents/src/contacts — lib/utils/system/system_commands/run_command_user_type.dart:74
