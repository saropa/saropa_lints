# PROPOSAL: Extend `avoid_ref_watch_outside_build` to Cover Provider's `context.watch()`

**Status: Open**

Created: 2026-09-02
Type: New rule
Related rules: `avoid_ref_watch_outside_build`

---

## Summary

Extend `avoid_ref_watch_outside_build` to also flag `context.watch<T>()` (from `package:provider`) called outside `build()`, matching DCM's `avoid-watch-outside-build`, which covers both Riverpod's `ref.watch()` and Provider's `context.watch()`.

**Closes gap:** DCM `avoid-watch-outside-build` (dcm.dev) — currently PARTIAL via saropa's `avoid_ref_watch_outside_build`. Implementing this proposal as specified fully closes this competitive gap — see `plans/GAP_ANALYSIS.md` "DCM proper" PARTIAL matches table.

---

## Motivation

`lib/src/rules/packages/riverpod_rules.dart:133-234` implements `AvoidRefWatchOutsideBuildRule`, which registers `context.addMethodInvocation` and only matches `MethodInvocation` nodes named `watch` whose target is a `SimpleIdentifier` named `ref`:

```dart
context.addMethodInvocation((MethodInvocation node) {
  if (node.methodName.name == 'watch') {
    final Expression? target = node.target;
    if (target is SimpleIdentifier && target.name == 'ref') {
      if (!_isInReactiveContext(node)) {
        reporter.atNode(node);
      }
    }
  }
});
```

`Set<FileType>? get applicableFileTypes => {FileType.provider};` currently gates this to files that already import Riverpod — despite the getter name coincidentally reading `provider`, it does not gate on `package:provider`. `package:provider`'s `context.watch<T>()` has the exact same lifecycle hazard as `ref.watch()`: it registers `InheritedWidget` dependencies through `BuildContext.dependOnInheritedWidgetOfExactType`, which is only valid during `build()`. Calling it in `initState()`, a callback, or a plain method throws `FlutterError: dependOnInheritedWidgetOfExactType() was called before ... build()` at runtime, or silently fails to subscribe. Saropa already supports the Provider package (`providerPackageRules` in `lib/src/tiers.dart:3714`) but this specific hazard is invisible to Provider-only projects that never touch Riverpod.

## Detection / Behavior

### Should flag (bad code)

```dart
class _MyWidgetState extends State<MyWidget> {
  @override
  void initState() {
    super.initState();
    // context.watch() outside build() — dependOnInheritedWidgetOfExactType
    // throws or silently fails to subscribe here.
    final count = context.watch<Counter>().value; // LINT
  }

  void _onPressed() {
    final count = context.watch<Counter>().value; // LINT — inside a callback
  }
}
```

### Should pass (good code)

```dart
class _MyWidgetState extends State<MyWidget> {
  @override
  Widget build(BuildContext context) {
    final count = context.watch<Counter>().value; // OK — inside build()
    return Text('$count');
  }

  void _onPressed(BuildContext context) {
    // OK — context.read() is correct in a callback, not watch()
    context.read<Counter>().increment();
  }
}
```

## Proposed Tier

Tier: Essential

Justification: keep parity with the existing rule's tier — `avoid_ref_watch_outside_build` is in `essentialRules` (`lib/src/tiers.dart` line 456). This is a widening of an existing Essential-tier rule's detection surface, not a new independent rule; splitting it into a different tier would create an inconsistent experience between the Riverpod and Provider variants of the same hazard.

## Edge Cases

1. **`context.watch()` inside a Riverpod `Consumer.builder` or Provider's `Consumer<T>` builder callback** — should pass; these builder callbacks are effectively build-phase and Provider's own `Consumer` widget is designed for exactly this use.
2. **`context.watch()` inside a `Selector<T, S>` builder** — should pass, same reasoning as `Consumer`.
3. **Custom extension methods named `watch` unrelated to Provider** (e.g. a user-defined `FooContext.watch()`) — must not be flagged; gate on `target.staticType` resolving to `BuildContext` (or an extension on it), not just the identifier name `context`, to avoid false positives on unrelated `.watch()` calls.
4. **`context.watch<T>()` inside `didChangeDependencies()`** — should pass; this lifecycle method runs during the same build-adjacent phase where `dependOnInheritedWidgetOfExactType` is valid, matching Flutter's own guidance.
5. **Nested closures inside `build()`** (e.g. `onPressed: () => context.watch<T>()`) — should still flag, mirroring the existing `_RefReadVisitor.visitFunctionExpression` override in the read-side rule that deliberately does NOT skip closures for `watch` semantics (the existing watch rule does no such skip already; preserve that).

## Alternatives Considered

- **New standalone rule** (`avoid_context_watch_outside_build`) instead of extending — rejected because it duplicates the "is this inside `build()`, a builder callback, or a reactive context" walk already implemented in `_isInReactiveContext`/`_providerConstructors`, and DCM itself treats Riverpod's `ref.watch` and Provider's `context.watch` as the *same* rule (`avoid-watch-outside-build`), not two rules — matching that keeps saropa's rule taxonomy aligned with the competitor being closed against.
- **Gate purely on `applicableFileTypes`** by adding `FileType.provider` semantics for real (currently misnamed to mean Riverpod) — insufficient alone; the visitor's target-name/type check must also change from `ref` to accept `context` typed as `BuildContext`.

---

## Decision

---

## Implementation Notes

Add a second detection branch to `AvoidRefWatchOutsideBuildRule.runWithReporter` in `lib/src/rules/packages/riverpod_rules.dart` (or split into a shared helper consumed by both a Riverpod- and Provider-specific check) that matches `MethodInvocation` named `watch` whose target's static type is `BuildContext`. Reuse `_isInReactiveContext` for the build-method check; extend it to also recognize `Consumer`/`Selector` builder callbacks as reactive contexts for the Provider case.

---

## Commits
