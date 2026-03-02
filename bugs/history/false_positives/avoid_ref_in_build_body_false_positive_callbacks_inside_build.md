# Bug Report: `avoid_ref_in_build_body` / `avoid_ref_read_inside_build` — False Positive on `ref.read()` Inside Callbacks Defined in `build()`

## Resolution

**Fixed in v5 (`avoid_ref_in_build_body`) and v3 (`avoid_ref_read_inside_build`).** Both rules now stop AST traversal at `FunctionExpression` boundaries. `ref.read()` inside any closure defined in `build()` (onPressed, onSelectionChanged, onSubmit, etc.) is no longer flagged. The duplicate visitor class was consolidated into a shared `_RefReadVisitor`.

---

## Diagnostic Reference

```json
[{
  "resource": "/D:/src/saropa_kykto/lib/features/settings/screens/settings_screen.dart",
  "owner": "_generated_diagnostic_collection_name_#0",
  "code": "avoid_ref_in_build_body",
  "severity": 8,
  "message": "[avoid_ref_in_build_body] Using ref.read() in build() does not trigger widget rebuilds when the provider changes, leading to stale UI, missed updates, and confusing bugs. This breaks the reactive model of Riverpod and can cause your app to display outdated information. {v4}\nUse ref.watch() for reactive updates in build(), or move ref.read() to a callback like onPressed to ensure the UI updates correctly.",
  "source": "dart",
  "startLineNumber": 53,
  "startColumn": 21,
  "endLineNumber": 54,
  "endColumn": 58,
  "origin": "extHost1"
},
{
  "resource": "/D:/src/saropa_kykto/lib/features/settings/screens/settings_screen.dart",
  "owner": "_generated_diagnostic_collection_name_#0",
  "code": "avoid_ref_read_inside_build",
  "severity": 4,
  "message": "[avoid_ref_read_inside_build] ref.read() called inside build() bypasses Riverpod reactivity. The widget will not rebuild when the provider state changes, resulting in stale data displayed to the user. This creates inconsistent UI state that fails silently and produces hard-to-diagnose rendering errors across dependent widgets. {v2}\nReplace ref.read() with ref.watch() inside build() to subscribe to provider changes and trigger automatic widget rebuilds on state updates.",
  "source": "dart",
  "startLineNumber": 53,
  "startColumn": 21,
  "endLineNumber": 54,
  "endColumn": 58,
  "origin": "extHost1"
},
{
  "resource": "/D:/src/saropa_kykto/lib/features/stream/screens/stream_screen.dart",
  "owner": "_generated_diagnostic_collection_name_#0",
  "code": "avoid_ref_in_build_body",
  "severity": 8,
  "message": "[avoid_ref_in_build_body] Using ref.read() in build() does not trigger widget rebuilds when the provider changes, leading to stale UI, missed updates, and confusing bugs. This breaks the reactive model of Riverpod and can cause your app to display outdated information. {v4}\nUse ref.watch() for reactive updates in build(), or move ref.read() to a callback like onPressed to ensure the UI updates correctly.",
  "source": "dart",
  "startLineNumber": 22,
  "startColumn": 13,
  "endLineNumber": 22,
  "endColumn": 48,
  "origin": "extHost1"
}]
```

---

## Summary

The `avoid_ref_in_build_body` (v4) and `avoid_ref_read_inside_build` (v2) rules flag `ref.read()` calls inside **event callbacks** (`onSelectionChanged`, `onSubmit`, `onPressed`, `onTap`) that happen to be defined inline within a `build()` method. These are false positives — `ref.read()` inside callbacks is the **recommended** Riverpod pattern. The rule's own fix suggestion even says "move ref.read() to a callback like onPressed" — but it then flags exactly that pattern when the callback is defined inline in `build()`.

---

## Severity

**False positive (ERROR severity for `avoid_ref_in_build_body`, WARNING for `avoid_ref_read_inside_build`)** — The flagged code follows the exact pattern recommended by Riverpod's official documentation and the rule's own fix suggestion. Changing `ref.read()` to `ref.watch()` inside these callbacks would be **incorrect** — it would create subscriptions inside event handlers that only fire once, which is the opposite of what Riverpod intends.

---

## Reproduction

### Example 1: `ref.read()` inside `onSelectionChanged` callback

**File:** `lib/features/settings/screens/settings_screen.dart`, line 53

```dart
class SettingsScreen extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);  // correct: watch for reactivity

    return SegmentedButton<ThemeMode>(
      selected: {themeMode},
      onSelectionChanged: (selection) {
        ref                                          // <-- FLAGGED
            .read(themeModeProvider.notifier)         // <-- FLAGGED
            .setThemeMode(selection.first);
      },
    );
  }
}
```

FLAGGED on lines 53-54. The `ref.read()` is inside the `onSelectionChanged` callback — a user-triggered event handler. This is the canonical Riverpod pattern: `ref.watch()` for reading state in the widget tree, `ref.read()` for one-shot actions in callbacks.

### Example 2: `ref.read()` inside `onSubmit` callback

**File:** `lib/features/stream/screens/stream_screen.dart`, line 22

```dart
class StreamScreen extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        ThoughtInputBar(
          onSubmit: (text) {
            ref.read(thoughtRepositoryProvider).addThought(text);  // <-- FLAGGED
          },
        ),
      ],
    );
  }
}
```

FLAGGED on line 22. The `ref.read()` is inside the `onSubmit` callback — it fires when the user submits text. Using `ref.watch()` here would be incorrect.

---

## Self-Contradictory Fix Suggestion

The rule's own message says:

> "Use ref.watch() for reactive updates in build(), **or move ref.read() to a callback like onPressed** to ensure the UI updates correctly."

The flagged code IS inside a callback (`onSelectionChanged`, `onSubmit`). The rule recommends exactly the pattern it then flags.

---

## Root Cause Analysis

Both rules use AST visitors that check whether `ref.read()` appears inside a method named `build`. They then flag it without checking whether the `ref.read()` call is:
1. **Directly in the `build()` body** (synchronous code that runs on every rebuild) — this IS a problem
2. **Inside a callback/closure** defined in `build()` but executed later on user interaction — this is **correct**

### AST Structure

For the `onSelectionChanged` example:

```
MethodDeclaration (build)
  └─ Block (build body)
      └─ ReturnStatement
          └─ InstanceCreationExpression (SegmentedButton)
              └─ ArgumentList
                  └─ NamedExpression (onSelectionChanged:)
                      └─ FunctionExpression ((selection) { ... })  ← callback boundary
                          └─ Block
                              └─ MethodInvocation (ref.read(...))  ← flagged
```

The `FunctionExpression` is the callback boundary. Code inside it does NOT execute during `build()` — it executes asynchronously when the user interacts with the widget. The rule should stop traversal at `FunctionExpression` nodes (or at least at those that are arguments to known callback-named parameters).

---

## Correct vs Incorrect Flagging

| Code Pattern | Currently Flagged | Should Be Flagged |
|---|---|---|
| `build() { ref.read(p); }` — direct in build body | Yes | **Yes** — should use `ref.watch()` |
| `build() { final x = ref.read(p); }` — direct in build body | Yes | **Yes** — should use `ref.watch()` |
| `build() { onPressed: () { ref.read(p); } }` — in callback | **Yes** | **No** — correct pattern |
| `build() { onSubmit: (v) { ref.read(p); } }` — in callback | **Yes** | **No** — correct pattern |
| `build() { onSelectionChanged: (s) { ref.read(p); } }` — in callback | **Yes** | **No** — correct pattern |
| `build() { onTap: () { ref.read(p); } }` — in callback | **Yes** | **No** — correct pattern |
| `build() { onDismissed: (_) { ref.read(p); } }` — in callback | **Yes** | **No** — correct pattern |

---

## Additional False Positive Patterns

Any `ref.read()` inside these common callback parameters will be incorrectly flagged when defined inline in `build()`:

```dart
// All of these are CORRECT Riverpod usage but would be FLAGGED:

ElevatedButton(
  onPressed: () {
    ref.read(myProvider.notifier).doSomething();  // FLAGGED
  },
)

TextField(
  onChanged: (value) {
    ref.read(searchProvider.notifier).setQuery(value);  // FLAGGED
  },
)

Dismissible(
  onDismissed: (_) {
    ref.read(listProvider.notifier).removeItem(item);  // FLAGGED
  },
)

GestureDetector(
  onTap: () {
    ref.read(navigationProvider.notifier).navigate(route);  // FLAGGED
  },
)
```

---

## Suggested Fix

**Option A (recommended): Stop traversal at `FunctionExpression` boundaries**

Same pattern as the `avoid_unnecessary_setstate` fix — override `visitFunctionExpression` to prevent recursion into callback bodies:

```dart
@override
void visitFunctionExpression(FunctionExpression node) {
  // Do not recurse into closures/callbacks defined in build().
  // ref.read() inside callbacks is the correct Riverpod pattern.
}
```

This is safe because:
- Direct `ref.read()` calls in the build body are at the top-level visitor scope and will still be found
- `ref.read()` inside any callback (onPressed, onTap, onSubmit, etc.) will be correctly skipped
- There is no legitimate reason to flag `ref.read()` inside a closure defined in `build()`

**Option B: Check if the enclosing `FunctionExpression` is a callback parameter**

More surgical approach — check if the `FunctionExpression` containing `ref.read()` is an argument to a named parameter matching common callback patterns (`on*`, `builder`, etc.):

```dart
bool _isInsideCallbackParameter(AstNode node) {
  AstNode? current = node;
  while (current != null) {
    if (current is FunctionExpression) {
      final parent = current.parent;
      if (parent is NamedExpression) {
        final paramName = parent.name.label.name;
        if (paramName.startsWith('on') || paramName == 'builder') {
          return true;
        }
      }
      return false;
    }
    current = current.parent;
  }
  return false;
}
```

Option A is simpler and safer — there is no case where `ref.read()` inside a closure in `build()` is wrong.

---

## Priority

**Critical** — Severity 8 (ERROR) on the most common Riverpod pattern. Every `ConsumerWidget` that has an interactive element (button, text field, dismissible, gesture detector) with an inline callback using `ref.read()` will trigger this false positive. The rule contradicts its own fix suggestion. This affects virtually every screen in a Riverpod app.

---

## Environment

- saropa_lints version: latest (v4 of `avoid_ref_in_build_body`, v2 of `avoid_ref_read_inside_build`)
- Dart SDK: 3.11+
- Framework: Flutter with Riverpod
- Project: saropa_kykto
