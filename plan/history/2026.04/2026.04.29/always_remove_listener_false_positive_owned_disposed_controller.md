# BUG: `always_remove_listener` — Listener On Owned-And-Disposed Controller Wrongly Flagged

**Status: Fixed**

Created: 2026-04-29
Rule: `always_remove_listener`
File: `lib/src/rules/widget/widget_lifecycle_rules.dart` (line ~2276)
Severity: False positive
Rule version: v4 | Since: ? | Updated: 2026-04-29

---

## Summary

The rule fires on `controller.addListener(...)` even when `controller` is a field of the same `State` and is explicitly disposed in `dispose()`. Disposing a `ChangeNotifier`/`AnimationController`/`Listenable` clears its listener list as part of teardown — there is no orphaned-listener leak. The rule never inspects whether the listener target is owned-and-disposed by the same `State`, so it FPs on a very common idiom.

---

## Attribution Evidence

```bash
# Positive
grep -rn "'always_remove_listener'" lib/src/rules/
# lib/src/rules/widget/widget_lifecycle_rules.dart:2296:    'always_remove_listener',

# Negative
grep -rn "'always_remove_listener'" ../saropa_drift_advisor/lib/src/ ../saropa_drift_advisor/extension/src/
# 0 matches
```

**Emitter registration:** `lib/src/rules/widget/widget_lifecycle_rules.dart:2296`
**Rule class:** `AlwaysRemoveListenerRule` — registered in `lib/src/rules/all_rules.dart`
**Diagnostic `source` / `owner`:** `dart`

---

## Reproducer

Real source: `d:/src/contacts/lib/components/primitive/refresh/src/pull_to_refresh_widget.dart` line 81 (after the SingleTickerProviderStateMixin edit).

```dart
class _State extends State<MyWidget> with SingleTickerProviderStateMixin {
  late final AnimationController _animationController;
  late final IndicatorController _controller;

  @override
  void initState() {
    super.initState();
    _controller = IndicatorController();
    _animationController = AnimationController(vsync: this)
      // LINT — but should NOT lint. _animationController is disposed below;
      // AnimationController.dispose() clears its listener list automatically.
      ..addListener(() => _controller.setValue(_animationController.value));
  }

  @override
  void dispose() {
    _animationController.dispose();  // <-- this disposes the listener target
    _controller.dispose();
    super.dispose();
  }
}
```

**Frequency:** Always — fires whenever `addListener` is called in `initState` on a State-owned field that is disposed in `dispose()`.

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | No diagnostic when the listener target is itself disposed in `dispose()`. Disposing `AnimationController`/`ChangeNotifier`/`ValueNotifier` clears listeners. No leak possible. |
| **Actual** | `[always_remove_listener] Listener added via addListener() but no matching removeListener() call found in dispose().` reported on the `addListener(...)` call. |

---

## AST Context

```
ClassDeclaration (_State extends State<MyWidget>)
  └─ MethodDeclaration (initState)
      └─ Block
          └─ ExpressionStatement
              └─ AssignmentExpression
                  └─ rhs: CascadeExpression
                      └─ MethodInvocation (addListener)  ← reported here
                          └─ realTarget: SimpleIdentifier (cascade target)
  └─ MethodDeclaration (dispose)
      └─ Block
          └─ ExpressionStatement
              └─ MethodInvocation (_animationController.dispose)
```

---

## Root Cause

In `_NestedScrollableVisitor` ... wait — wrong rule. Looking at `_AddListenerFinder` and `_RemoveListenerFinder` (lines 2378–2412):

The rule pairs `addListener(callback)` calls in `initState` with `removeListener(callback)` calls in `dispose`. It compares by `target.toSource()` and `args.first.toSource()`. There is no check for whether the target is itself disposed, no check for cascade-on-controller-being-stored, and no check for the framework's auto-cleanup contract (`AnimationController.dispose()` clears listeners; `ChangeNotifier.dispose()` does too via `removeListener` of every listener).

### Hypothesis A — Add disposal-check escape

If the `addListener` target's source string also appears in a `MethodInvocation` named `dispose` inside the `dispose()` body, treat the listener as auto-cleaned and do not report. This catches:

- `_animationController..addListener(...)` paired with `_animationController.dispose()`
- `_controller.addListener(...)` paired with `_controller.dispose()`

A targeted fix that does not require type resolution.

### Hypothesis B — Use static type information

Resolve `realTarget?.staticType`. If the type is `AnimationController`, `ChangeNotifier` (and subclasses), or any class that implements `Listenable` and has a `dispose` method, and that target is disposed in `dispose()`, exempt.

Hypothesis A is cheaper and covers the dominant pattern.

---

## Suggested Fix

In `lib/src/rules/widget/widget_lifecycle_rules.dart`:

1. Inside `_RemoveListenerFinder` add a sibling `_DisposeFinder` that records `target.toSource()` for every `MethodInvocation` named `dispose` in the `dispose()` body.
2. In the loop "Check if each added listener has a corresponding remove" (lines 2357–2366), before reporting, also check whether `added.target` appears in the disposed-targets set. If so, skip reporting (the controller's disposal cleans up its listeners).

```dart
// Find disposal calls in dispose()
final Set<String> disposedTargets = <String>{};
if (disposeBody != null) {
  disposeBody.visitChildren(
    _DisposeFinder((String target) => disposedTargets.add(target)),
  );
}

for (final _ListenerInfo added in addedListeners) {
  final bool hasRemove = removedListeners.any((removed) =>
      removed.target == added.target && removed.callback == added.callback);
  // NEW — listener target is itself disposed; framework auto-cleans
  final bool targetIsDisposed = disposedTargets.contains(added.target);
  if (!hasRemove && !targetIsDisposed && added.node != null) {
    reporter.atNode(added.node!, code);
  }
}
```

Bump rule version to v4. Update the rule docstring with a "Not flagged" section listing the disposal-cleanup case.

---

## Fixture Gap

`example*/lib/widget/always_remove_listener_fixture.dart` should include:

1. `addListener` in initState + matching `removeListener` in dispose — expect NO lint (already covered)
2. `addListener` in initState + NO `removeListener` AND target NOT disposed — expect LINT (regression check)
3. `addListener` in initState + target's `.dispose()` called in dispose() — expect NO lint (NEW; the auto-cleanup case)
4. Cascade form `controller..addListener(...)` + `controller.dispose()` in dispose — expect NO lint (NEW)
5. `addListener` on a target stored in a getter (not a field) but disposed by name — edge case, document expected behavior

---

## Changes Made

- `AlwaysRemoveListenerRule` v4: collect `.dispose()` targets in `dispose()` and skip the diagnostic when the `addListener` target (or cascade assignment alias) is disposed, since Flutter listenables clear listeners on dispose.
- Pair `removeListener` with `addListener` when the cascade assignee matches the remove target (same callback).
- Docstring: “Not flagged” when the listenable is disposed in `dispose()`.
- Fixture: real `State` classes for BAD, removeListener GOOD, dispose GOOD, cascade GOOD.

---

## Tests Added

- `test/always_remove_listener_rule_test.dart` — registration, fixture `expect_lint` contract, `{v4}` in problem message.

---

## Commits

<!-- Fill in when fix lands. -->

---

## Environment

- saropa_lints version: 12.8.4
- Dart SDK version: Flutter 3.x channel
- custom_lint version: native analyzer plugin (no custom_lint)
- Triggering project/file: `d:/src/contacts/lib/components/primitive/refresh/src/pull_to_refresh_widget.dart` (line 81 after recent edits)
