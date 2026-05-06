# Bug Report: `check_mounted_after_async` — False Positives on Early-Return Guards and Static Methods

## Diagnostic Reference

```json
[
  {
    "resource": "/D:/src/contacts/lib/components/device_home_screen_widget/quick_launch_menu_utils.dart",
    "owner": "_generated_diagnostic_collection_name_#2",
    "code": "check_mounted_after_async",
    "severity": 4,
    "message": "[check_mounted_after_async] setState() after await without mounted check. State may be disposed during async gap, causing \"setState() called after dispose()\" crash. {v4}\nAdd if (mounted) { setState(...) } after the await.",
    "source": "dart",
    "startLineNumber": 259,
    "startColumn": 17,
    "endLineNumber": 274,
    "endColumn": 12,
    "origin": "extHost1"
  }
]
```

---

## Summary

The `check_mounted_after_async` rule (async_rules.dart:1760) produces false positives in at least three scenarios. The root cause is that `_hasMountedGuard()` only recognizes the **wrapping-if** pattern but not the **early-return guard** pattern, and the rule fires on `showDialog` calls in **static methods** that have no `State` lifecycle at all.

---

## Problem 1: Early-Return Guard Not Recognized

The rule's `_hasMountedGuard()` method (async_rules.dart:1837) walks **up** the AST looking for an enclosing `IfStatement` whose condition contains `"mounted"`. This finds the wrapping pattern:

```dart
// Recognized by _hasMountedGuard — target is INSIDE the if-block
if (mounted) {
  setState(() { ... });
}
```

But it does **not** find the early-return guard pattern, which is equally valid and arguably more common in Flutter:

```dart
// NOT recognized — guard is a SIBLING, not an ANCESTOR in the AST
if (!context.mounted) return;

setState(() { ... });  // <-- flagged as violation
```

In the early-return pattern, the `setState` is NOT inside the `IfStatement` node — it's a subsequent sibling statement in the same `Block`. Walking up the parent chain from `setState` will never encounter the guard's `IfStatement` because they are siblings, not parent-child.

### Real-World Example 1: Static utility with `context.mounted` guard

`lib/components/device_home_screen_widget/quick_launch_menu_utils.dart`

```dart
// Line 252-275
final List<String> currentUUIDs = await QuickLaunchOrderService.getQuickLaunchContactUUIDs(
  contactStatus: contactStatus,
);

if (!context.mounted) return;  // <-- mounted guard (line 256)

if (currentUUIDs.length >= maxQuickLaunchContacts) {
  await showDialog<void>(       // <-- FLAGGED (line 259), but safe
    context: context,
    builder: (BuildContext context) => AlertDialog(
      title: const Text('Quick Launch Full'),
      content: Text('Quick Launch can hold up to $maxQuickLaunchContacts contacts...'),
      actions: <Widget>[
        CommonButton(
          text: 'OK',
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    ),
  );
  return;
}
```

The `if (!context.mounted) return;` at line 256 guarantees `context` is still valid at line 259. There is no code path that reaches `showDialog` without passing the guard.

### Real-World Example 2: Timer callback with `mounted` guard

`lib/components/contact/detail_panels/phone/phone_panel.dart`

```dart
_reorderLockTimer = Timer(const Duration(milliseconds: 300), () async {
  if (!mounted) return;  // <-- early-return guard

  await DatabaseContactIO.dbContactUpdateWithActivity(
    contact: widget.contact,
    activityType: ActivityType.PhoneSortOrderChanged,
    differences: /* ... */,
  );

  if (!mounted) return;  // <-- second guard after await

  setState(() {           // <-- was FLAGGED, despite mounted guard above
    _isReordering = false;
  });
});
```

Both guards use the early-return pattern. The `setState` at the bottom is unreachable if `mounted` is false, but the rule doesn't see it because `_hasMountedGuard` only checks ancestors, not preceding siblings.

---

## Problem 2: Static Methods Have No State Lifecycle

The flagged code in `QuickLaunchMenuUtils` is inside a **static method** on a utility class with a private constructor:

```dart
class QuickLaunchMenuUtils {
  QuickLaunchMenuUtils._();

  static Future<void> showQuickLaunchBottomSheet({
    required BuildContext context,
    // ...
  }) async {
    // ...
    await showDialog<void>(context: context, ...);  // <-- flagged
  }
}
```

This class is **not** a `State` subclass. There is no `mounted` property. There is no `dispose()` lifecycle. The `context` parameter is a `BuildContext` passed in by the caller — the only valid check is `context.mounted`, which IS present at line 256.

The rule's problem message says _"State may be disposed during async gap, causing 'setState() called after dispose()' crash"_ — but there is no `State` here and no `setState` is being called. The flagged call is `showDialog`, which is a top-level Flutter function, not a `State` method.

---

## Problem 3: Safe setState Wrappers Not Recognized

Many codebases wrap `setState` in a safe helper that includes the mounted check internally:

```dart
// Common pattern in the contacts codebase
void _setStateSafe([VoidCallback? callback]) {
  if (!mounted) return;
  setState(() => callback?.call());
}

// Also: SafeSetStateMixin provides setStateSafe()
```

Calls to `_setStateSafe()` or `setStateSafe()` are safe by construction, but the rule would still flag `setState()` if used directly after an await. The workaround (switching to `_setStateSafe`) silences the lint, but only because the rule doesn't recognize `_setStateSafe` as a target method — not because of any semantic analysis.

This isn't a direct bug (the rule doesn't flag `_setStateSafe`), but it means the rule is inconsistent: the same code with the same safety is flagged or not depending on naming.

---

## Root Cause Analysis

The `_hasMountedGuard()` implementation at async_rules.dart:1837:

```dart
bool _hasMountedGuard(FunctionBody body, AstNode target) {
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

This only walks **up** the AST from the target to the function body, looking for an enclosing `IfStatement`. It needs to also check for **preceding** `IfStatement` siblings in the same block that:

1. Have a condition containing `mounted` (either `mounted`, `!mounted`, `context.mounted`, `!context.mounted`)
2. Contain a `return`, `throw`, or `break` statement in their body (i.e., they are an early-exit guard)

---

## Suggested Fix

Extend `_hasMountedGuard()` to also scan **preceding statements** in the same block for early-return guards:

```dart
bool _hasMountedGuard(FunctionBody body, AstNode target) {
  // Existing check: is the target INSIDE an if-mounted block?
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

  // New check: is there an early-return guard BEFORE the target in the same block?
  final Block? block = _findEnclosingBlock(target);
  if (block != null) {
    for (final Statement statement in block.statements) {
      // Stop when we reach the target's statement
      if (statement.offset >= target.offset) break;

      if (statement is IfStatement) {
        final String condition = statement.expression.toSource();
        if (condition.contains('mounted') && _containsEarlyExit(statement.thenStatement)) {
          // Check if there's an await between this guard and the target
          // If so, the guard doesn't cover the target
          if (!_hasAwaitBetween(block, statement.end, target.offset)) {
            return true;
          }
        }
      }
    }
  }

  return false;
}

/// Returns true if the statement contains a return, throw, or break.
bool _containsEarlyExit(Statement statement) {
  if (statement is ReturnStatement) return true;
  if (statement is ExpressionStatement && statement.expression is ThrowExpression) return true;
  if (statement is Block) {
    return statement.statements.any((Statement s) =>
        s is ReturnStatement ||
        (s is ExpressionStatement && s.expression is ThrowExpression));
  }

  return false;
}
```

Additionally, consider **not flagging** calls inside static methods of non-State classes, since:

- There is no `State` lifecycle to dispose
- The message about `setState() called after dispose()` is misleading
- The developer is already using `context.mounted` which is the correct check for passed-in contexts

---

## Patterns That Should Be Recognized as Safe

| Pattern                                                                 | Currently Recognized | Should Be Recognized |
| ----------------------------------------------------------------------- | -------------------- | -------------------- |
| `if (mounted) { setState(...); }`                                       | Yes                  | Yes                  |
| `if (context.mounted) { setState(...); }`                               | Yes                  | Yes                  |
| `if (!mounted) return; setState(...);`                                  | **No**               | **Yes**              |
| `if (!context.mounted) return; setState(...);`                          | **No**               | **Yes**              |
| `if (!mounted) return; await ...; if (!mounted) return; setState(...);` | **No**               | **Yes**              |
| Static method with `context.mounted` guard before `showDialog`          | **No**               | **Yes**              |

---

## Affected Files

| File                             | Line      | What                                                                                                |
| -------------------------------- | --------- | --------------------------------------------------------------------------------------------------- |
| `lib/src/rules/async_rules.dart` | 1837-1850 | `_hasMountedGuard()` — needs early-return guard detection                                           |
| `lib/src/rules/async_rules.dart` | 1784-1793 | Method name filter — consider skipping for static non-State methods                                 |
| `lib/src/rules/async_rules.dart` | 1769-1776 | `_code` — problem message assumes `State.setState()`, misleading for `showDialog` in static methods |

## Priority

**High** — The rule is critical (prevents real crashes), but these false positives force developers to either suppress the rule with `// ignore` comments or refactor working code unnecessarily. The early-return guard pattern (`if (!mounted) return;`) is the officially recommended Flutter pattern and is arguably more common than the wrapping-if pattern. Not recognizing it undermines trust in the rule.
