# BUG: `avoid_context_after_await_in_static` — Await inside an early-returning `if` branch puts later statements in the "danger zone" (static methods)

**Status: Open**

Created: 2026-10-29
Rule: `avoid_context_after_await_in_static`
File: `lib/src/rules/core/context_rules.dart` (line ~500)
Severity: False positive
Rule version: v5 | Since: unknown | Updated: 17.0.1-beta.2

---

## Summary

`checkAsyncStaticBody` has the same linear scan as `avoid_context_across_async`: an `if` whose then-branch is `return await x;` sets `seenAwait`, so a later context use in the same try body is reported.

---

## Attribution Evidence

```bash
grep -rn "'avoid_context_after_await_in_static'" lib/src/rules/
lib/src/rules/core/context_rules.dart:500:    'avoid_context_after_await_in_static',
```

Negative grep not applicable: no sibling analyzer repo is checked out beside this one that defines this code; the rule is only defined here.

**Emitter registration:** `lib/src/rules/core/context_rules.dart:500`
**Rule class:** `AvoidContextAfterAwaitInStaticRule` — registered in `251:  AvoidContextAfterAwaitInStaticRule.new,`
**Diagnostic `source` / `owner` as seen in Problems panel:** `saropa_lints` / `saropaLintsLsp`

---

## Reproducer

Standalone. Copied from the real project source (path and lines below) with project-specific types replaced by the real package types where one exists.

Project source: `lib/utils/system/system_commands/run_command_user_type.dart` lines 38-79 (`RunUserTypeCommands.processCommandUserType`, `static`); the context use is at line 74.

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
| **Actual** | `[avoid_context_after_await_in_static] BuildContext used after await in static method. Context may be invalid after async gap. {v5}` reported at 74:62-74:69 of run_command_user_type.dart |

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

`context_rules.dart:520-545` (`runWithReporter`) calls `checkAsyncStaticBody` (static method starting at line 550). Line 574 `if (containsAwait(statement))` is true for the `IfStatement` containing `return await ...`; lines 575-577 set `seenAwait = true`; the following statement is reported at the `seenAwait && !hasGuard` branch (lines ~596-603 `_reportContextUsageInStatic`). Same missing control-flow reasoning as `avoid_context_across_async` (context_rules.dart:313).

### Why the code is correct

The only `await` is in `return await UserAccountUtils.setAccountStandard();`, inside an `if` block that returns. Control flow cannot reach `genericSystemCommandFailedToast(context)` after that await, so the BuildContext is used on the same synchronous path as the method entry. The `return await` is deliberate: inside `try` it makes the `catch` handle failures of the future.

---

## Affected project locations (project: contacts, line numbers before the session's other edits)

- `lib/utils/system/system_commands/run_command_user_type.dart:74`

---

## Suggested Fix

Replace the linear "any statement containing await sets seenAwait" scan with a control-flow-aware one: a nested statement (`IfStatement` branch, `switch` case) whose block ends in `return`/`throw` must not set `seenAwait` for the statements after the `if`. Minimum viable: when the statement is an `IfStatement` without `else` whose then-branch always completes abruptly (`return`/`throw`) and the await is inside that branch, do not enter the danger zone. Share the fix with `AvoidContextAcrossAsyncRule._checkAsyncBody` and `AvoidContextInAsyncStaticRule`, which reuses `checkAsyncStaticBody`.

---

## Fixture Gap

The fixture for `avoid_context_after_await_in_static` should include:

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
