# `check_mounted_after_async` False Positive on Guard Clause Pattern

## Status: CONFIRMED BUG

## Summary

`check_mounted_after_async` fires on `setState()` calls that are correctly guarded by a preceding `if (!mounted) return;` guard clause. The rule's `_hasMountedGuard()` method only recognizes the **wrapping** pattern (`if (mounted) { setState(...) }`) but not the semantically equivalent **early-return guard** pattern (`if (!mounted) return; setState(...);`).

## Severity

**High** — This is a common and idiomatic Flutter pattern. Developers who follow the recommended guard clause style will see false warnings on every guarded `setState()`, training them to ignore legitimate warnings or add unnecessary `// ignore:` comments.

## Reproducer

### Code that falsely triggers the warning

```dart
// Inside a State<T> subclass
Timer(const Duration(milliseconds: 300), () async {
  if (!mounted) return;  // guard #1

  await someAsyncOperation();

  if (!mounted) return;  // guard #2 — correctly guards setState below

  setState(() {           // ← FALSE POSITIVE here
    _isReordering = false;
  });
});
```

**Diagnostic produced:**

```
[check_mounted_after_async] setState() after await without mounted check.
State may be disposed during async gap, causing "setState() called after dispose()" crash.
Add if (mounted) { setState(...) } after the await.
```

### Real-world file

`lib/components/contact/detail_panels/email/email_panel.dart` lines 120-141:

```dart
_reorderLockTimer = Timer(const Duration(milliseconds: 300), () async {
  if (!mounted) return;                          // line 121

  await DatabaseContactIO.dbContactUpdateWithActivity(  // line 124
    contact: widget.contact,
    activityType: ActivityType.EmailSortOrderChanged,
    differences: <(JsonDifferenceType, String)>[
      (
        JsonDifferenceType.Difference,
        'Email reordered: position $oldIndex → $adjustedNewIndex',
      ),
    ],
  );

  if (!mounted) return;                          // line 135

  // Release lock - allow normal rebuilds now
  setState(() {                                  // line 138 ← flagged
    _isReordering = false;
  });
});
```

### Code that correctly passes (for comparison)

```dart
await someAsyncOperation();

if (mounted) {
  setState(() {  // No warning — setState is INSIDE the IfStatement body
    _data = result;
  });
}
```

## Root Cause

### Location

`lib/src/rules/async_rules.dart` — `_hasMountedGuard()` method (lines 1795-1808).

### The buggy code

```dart
bool _hasMountedGuard(FunctionBody body, AstNode target) {
  // Check if the target is inside an if statement checking mounted
  AstNode? current = target.parent;
  while (current != null && current != body) {
    if (current is IfStatement) {
      final String condition = current.expression.toSource();
      if (condition.contains('mounted')) {
        return true;
      }
    }
    current = current.parent;
  }

  return false;
}
```

### Why it fails

The method walks **up** the AST parent chain from `setState` looking for an **ancestor** `IfStatement` that mentions `mounted`. This only matches the wrapping pattern where `setState` is physically inside the `if` body:

```
IfStatement (condition: "mounted")      ← ancestor of setState ✓
  Block
    ExpressionStatement
      MethodInvocation: setState(...)   ← target
```

But the guard clause pattern has a **flat sibling structure**:

```
Block
  IfStatement: if (!mounted) return;    ← sibling, NOT ancestor of setState ✗
  ExpressionStatement
    MethodInvocation: setState(...)      ← target
```

The `if (!mounted) return;` is a **preceding sibling** in the same `Block`, not a **parent** of `setState`. The parent-walk never encounters it.

### Why the guard clause is safe

After `if (!mounted) return;`, all subsequent statements in the same block can **only execute when `mounted` is true**. The early return guarantees this. It is semantically identical to:

```dart
if (mounted) {
  setState(() { ... });
}
```

Both patterns are recommended in Flutter documentation and are equally safe.

## Affected Patterns (Not Exhaustive)

The rule will false-positive on ALL of these idiomatic patterns:

### 1. Simple guard + setState

```dart
Future<void> _load() async {
  final data = await fetchData();
  if (!mounted) return;
  setState(() => _data = data);  // FALSE POSITIVE
}
```

### 2. Multiple awaits with guard before setState

```dart
Future<void> _init() async {
  await stepOne();
  await stepTwo();
  if (!mounted) return;
  setState(() => _ready = true);  // FALSE POSITIVE
}
```

### 3. Guard inside Timer/callback async closure

```dart
Timer(duration, () async {
  if (!mounted) return;
  await doWork();
  if (!mounted) return;
  setState(() => _done = true);  // FALSE POSITIVE
});
```

### 4. Guard using `context.mounted` (BuildContext version)

```dart
Future<void> _load() async {
  await fetchData();
  if (!context.mounted) return;
  setState(() => _data = data);  // FALSE POSITIVE (if context.mounted is checked)
}
```

## Suggested Fix

`_hasMountedGuard()` should also check for **preceding sibling statements** in the same `Block` that are guard clauses returning early when `!mounted`. Specifically:

1. From `setState`, walk up to find the containing `Block`.
2. Find the index of the statement containing `setState` within that block.
3. Walk **backwards** through preceding sibling statements.
4. If any preceding sibling is an `IfStatement` whose:
   - condition contains `mounted`, AND
   - then-branch is a `return`/`throw` statement (or a block containing only `return`/`throw`)

   → then the guard is valid and `_hasMountedGuard` should return `true`.

### Pseudocode

```dart
bool _hasMountedGuard(FunctionBody body, AstNode target) {
  // EXISTING: Check ancestor IfStatements (wrapping pattern)
  AstNode? current = target.parent;
  while (current != null && current != body) {
    if (current is IfStatement) {
      final String condition = current.expression.toSource();
      if (condition.contains('mounted')) {
        return true;
      }
    }
    current = current.parent;
  }

  // NEW: Check preceding sibling guard clauses (early-return pattern)
  final Block? block = _findContainingBlock(target);
  if (block != null) {
    final int targetIndex = _findStatementIndex(block, target);
    for (int i = targetIndex - 1; i >= 0; i--) {
      final Statement stmt = block.statements[i];
      if (stmt is IfStatement) {
        final String condition = stmt.expression.toSource();
        if (condition.contains('mounted') && _isEarlyExit(stmt.thenStatement)) {
          return true;
        }
      }
      // If we hit another await between the guard and setState,
      // the guard is no longer valid for this setState
      if (_containsAwait(stmt)) break;
    }
  }

  return false;
}

/// Check if the statement is an early exit (return/throw)
bool _isEarlyExit(Statement stmt) {
  if (stmt is ReturnStatement) return true;
  if (stmt is ExpressionStatement && stmt.expression is ThrowExpression) return true;
  if (stmt is Block && stmt.statements.length == 1) {
    return _isEarlyExit(stmt.statements.first);
  }

  return false;
}
```

### Critical edge case

The backward walk must **stop at any intervening `await`** between the guard and the `setState`. Consider:

```dart
if (!mounted) return;   // guard
await moreWork();       // ← new async gap after the guard!
setState(() {});        // NOT safe — should still warn
```

This is correctly handled by breaking out of the backward walk when an `await` is found between the guard clause and the target.

## Additional Note: `require_mounted_check_after_await` Rule

The newer `require_mounted_check_after_await` rule (lines 3956-4048) uses a different strategy with sequential `_sawAwait`/`_hasMountedCheck` flags in `_MountedCheckVisitor`. That rule's `visitIfStatement` sets `_hasMountedCheck = true` when visiting ANY `IfStatement` containing `mounted` (including guard clauses), so it likely does NOT have this same bug. However, both rules should be checked and kept consistent.

## Environment

- **saropa_lints**: path dependency from `D:\src\saropa_lints`
- **Rule file**: `lib/src/rules/async_rules.dart` lines 1718-1809
- **Test project**: `D:\src\contacts`
- **Triggered in**: `lib/components/contact/detail_panels/email/email_panel.dart:138`
- **Dart SDK**: 3.10.8
- **custom_lint**: 0.8.1
