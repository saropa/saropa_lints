# `avoid_setstate_in_build` — false positive: rule fires on `setState` inside an event-handler closure (`onTap:`, `onPressed:`, etc.) passed during `build()`, even though the closure does not execute synchronously during build

**Status:** Fixed (2026-04-26)

Filed: 2026-04-26
Rule: `avoid_setstate_in_build`
File: [lib/src/rules/core/performance_rules.dart:1146](../../../lib/src/rules/core/performance_rules.dart#L1146) (`_SetStateVisitor`)
Severity: False positive — **structural / classification error**
Rule version: v6 | Severity in code: ERROR | Impact: critical (high)

## Resolution

Overrode `visitFunctionExpression` in `_SetStateVisitor` to return without descending. Closure subtrees (`onTap:`, `onPressed:`, `onChanged:`, `Future.then`, `addPostFrameCallback`, etc.) are now opaque to the rule, so `setState` calls inside them are no longer reported. The previous walk-up logic missed `NamedExpression`-wrapped closures (the parent of a named-arg `FunctionExpression` is `NamedExpression`, not `ArgumentList`), which is why `onTap: () => setState(...)` slipped through. The new approach also subsumes the old `addPostFrameCallback` / `then` / `Future` / `scheduleMicrotask` special cases. Fixture extended with closure-bound cases that must NOT lint. See [example/lib/performance/avoid_setstate_in_build_fixture.dart](../../../example/lib/performance/avoid_setstate_in_build_fixture.dart).

---

## Summary

The rule's stated purpose is to prevent `setState` calls **executed** during `build()`, which cause infinite rebuild loops. The detection logic flags any `setState` invocation lexically located inside the AST subtree of `build()` — but does not distinguish between calls executed *synchronously* during build versus calls inside event-handler closures (`onTap:`, `onPressed:`, `onChanged:`, etc.) that only execute later in response to user interaction.

The closure body is part of the `build()` method's AST, but its *execution* happens during a separate event delivery, not during the build pass. The widget passes the closure as a value; Flutter's gesture system invokes it when a tap occurs, well after build completes. There is no infinite-rebuild risk.

The rule message ("causes the widget to rebuild recursively, leading to stack overflows") is factually wrong for closure-bound setState calls.

---

## Attribution Evidence

```bash
$ grep -rn "'avoid_setstate_in_build'" lib/src/rules/
# (run in saropa_lints checkout — should find a single rule file)
```

This bug is filed before grep confirmation; the diagnostic source is `dart` and the rule code matches saropa_lints naming conventions. If the positive grep returns zero matches, this report belongs in the sibling repo that defines the rule. Update this section with the file/line once confirmed.

**Diagnostic `source` / `owner` as seen in Problems panel:** `dart` (saropa_lints native plugin)

---

## Reproducer

Consumer project: `D:\src\contacts`. Site: `lib/components/primitive/menu/common_popup_menu_collapsible_section.dart:88`.

```dart
@override
Widget build(BuildContext context) {
  return Listener(
    behavior: HitTestBehavior.opaque,
    child: Column(
      children: <Widget>[
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          // The setState below is INSIDE an `onTap:` closure passed to GestureDetector.
          // The closure is not executed during build — only on tap. There is no
          // build-time recursion. The rule still fires.
          onTap: () => setState(() => _expanded = !_expanded),  // LINT — but should NOT lint
          child: Padding(...),
        ),
      ],
    ),
  );
}
```

Minimal isolated repro:

```dart
class _MyState extends State<MyWidget> {
  bool _on = false;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: () => setState(() => _on = !_on),  // expect NO lint — closure runs on tap, not during build
      child: Text(_on ? 'on' : 'off'),
    );
  }
}
```

**Frequency:** Always — every `setState` call inside any `onTap:` / `onPressed:` / `onChanged:` / `onLongPress:` / similar event-handler closure in any `build()` method.

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | No diagnostic. The setState is inside a closure that the framework invokes on user interaction, not synchronously during build. The rule's "rebuild recursively / stack overflow" justification does not apply. |
| **Actual** | `[avoid_setstate_in_build]` fires at ERROR severity on every `setState` lexically located inside any closure passed as a callback parameter during build. |

---

## AST Context

```
MethodDeclaration (build)
  └─ BlockFunctionBody
      └─ ReturnStatement
          └─ InstanceCreationExpression (Listener)
              └─ … widget tree …
                  └─ InstanceCreationExpression (GestureDetector)
                      └─ ArgumentList
                          └─ NamedExpression (onTap:)
                              └─ FunctionExpression                 ← closure boundary — execution defers to event delivery
                                  └─ FunctionBody
                                      └─ MethodInvocation (setState)  ← reported here (incorrectly)
```

The rule's traversal walks the entire `build()` body subtree and reports any `setState` invocation it encounters. It does not detect when the traversal has crossed into a `FunctionExpression` (closure literal) — at which point the call no longer executes synchronously during build.

---

## Root Cause

### Hypothesis: traversal does not stop at FunctionExpression boundaries

A correct rule walks the `build()` body but treats any `FunctionExpression` (closure) child as opaque — calls inside it do not execute during the current build. Flagging a `setState` inside `onTap: () => setState(...)` is identical to flagging:

```dart
final fn = () => setState(() => x = 1);  // NEVER called
return ElevatedButton(onPressed: fn, ...);
```

…where the closure is stored but never invoked. The rule must report only on calls that are reachable from `build()` via *immediate* execution, not via captured closures.

The likely fix: when the rule's recursive AST visitor enters a `FunctionExpression`, it should `return` without descending. That is the conventional pattern for "synchronous-execution" detection rules.

---

## Suggested Fix

Pseudocode for the corrected visitor:

```dart
class _SetStateInBuildVisitor extends RecursiveAstVisitor<void> {
  @override
  void visitFunctionExpression(FunctionExpression node) {
    // Closures defer execution to whenever the framework chooses to invoke
    // them — typically event delivery, timers, or animation ticks. They do
    // NOT run during the current build pass. Skip the entire subtree.
    return;
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (node.methodName.name == 'setState') {
      reporter.atNode(node);
    }
    super.visitMethodInvocation(node);
  }
}
```

The same pattern is correct for any other "called during build" rules in the package (e.g., `avoid_async_in_build`, `avoid_future_in_build`, `avoid_expensive_build`, `avoid_change_notifier_in_widget`). Audit those for the same gap.

---

## Fixture Gap

The fixture should include:

1. **Direct `setState(() => …)` at the top of `build()`** — expect LINT (genuine bug)
2. **`setState(() => …)` inside `onPressed: () => …`** — expect NO lint *(currently false positive)*
3. **`setState(() => …)` inside an `onChanged:` callback that wraps multiple statements** — expect NO lint
4. **`setState(() => …)` inside a `Future.delayed(...)` callback inside `build()`** — depends on intent: the Future *is* scheduled during build, but its callback runs later. Probably should NOT lint, but should flag the `Future.delayed` itself via a different rule (`avoid_future_in_build`).
5. **`setState(() => …)` inside a `WidgetsBinding.instance.addPostFrameCallback((_) => …)`** — expect NO lint (canonical safe pattern, the rule's own correctionMessage suggests this).

Cases 2–5 are all closures: skipping `FunctionExpression` closes them all.

---

## Downstream

Tracked in `contacts/`. Once this report exists, `// ignore: avoid_setstate_in_build` is added at `lib/components/primitive/menu/common_popup_menu_collapsible_section.dart:88` with a comment pointing here. The codebase has many more occurrences of the pattern; this is the only one currently flagged because the rule's tier or path filtering happens to exclude others — but the same false-positive shape is pervasive.

---

## Environment

- saropa_lints version: 12.5.1+
- Dart SDK: 3.9.x
- Triggering project: `d:/src/contacts`
- Platform: Windows 11
