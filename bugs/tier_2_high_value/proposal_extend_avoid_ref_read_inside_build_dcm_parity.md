# PROPOSAL: Extend `avoid_ref_read_inside_build` to Cover Provider's `context.read()`

**Status: Open**

Created: 2026-09-02
Type: New rule
Related rules: `avoid_ref_read_inside_build`

---

## Summary

Extend `avoid_ref_read_inside_build` to also flag `context.read<T>()` (from `package:provider`) called inside `build()`, matching DCM's `avoid-read-inside-build`, which covers both Riverpod's `ref.read()` and Provider's `context.read()`.

**Closes gap:** DCM `avoid-read-inside-build` (dcm.dev) — currently PARTIAL via saropa's `avoid_ref_read_inside_build`. Implementing this proposal as specified fully closes this competitive gap — see `plans/GAP_ANALYSIS.md` "DCM proper" PARTIAL matches table.

---

## Motivation

`lib/src/rules/packages/riverpod_rules.dart:43-106` implements `AvoidRefReadInsideBuildRule`. Its detection is a `_RefReadVisitor` walked from every `build()` method body:

```dart
@override
void visitMethodInvocation(MethodInvocation node) {
  if (node.methodName.name == 'read') {
    final Expression? target = node.target;
    if (target is SimpleIdentifier && target.name == 'ref') {
      reporter.atNode(node);
    }
  }
  super.visitMethodInvocation(node);
}

@override
void visitFunctionExpression(FunctionExpression node) {
  // Do not recurse into closures/callbacks defined in build().
}
```

Provider's `context.read<T>()` has the identical non-reactive-read hazard: it reads the current value without subscribing, so a widget that calls `context.read<T>()` directly inside `build()` (rather than `context.watch<T>()`) will not rebuild when `T` changes, producing stale UI exactly like the Riverpod case this rule already documents. Saropa supports Provider (`providerPackageRules`, `lib/src/tiers.dart:3714`) but this specific "read-not-watch-in-build" hazard has no coverage for Provider-only projects.

## Detection / Behavior

### Should flag (bad code)

```dart
class MyWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // context.read() does not subscribe — widget won't rebuild on change.
    final value = context.read<Counter>().value; // LINT
    return Text('$value');
  }
}
```

### Should pass (good code)

```dart
class MyWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final value = context.watch<Counter>().value; // OK — subscribes
    return Text('$value');
  }

  void _onPressed(BuildContext context) {
    // OK — context.read() inside a callback, not build(), is correct
    context.read<Counter>().increment();
  }
}
```

## Proposed Tier

Tier: Essential

Justification: keep parity with the existing rule's tier — `avoid_ref_read_inside_build` is in `essentialRules` (`lib/src/tiers.dart` line 455). This widens an existing Essential-tier rule; a separate tier for the Provider variant of the same hazard would fragment user-facing severity for what is functionally one lint intent.

## Edge Cases

1. **`context.read()` inside a closure/callback within `build()`** (`onPressed: () => context.read<T>()...`) — should pass. The existing rule already excludes closures via the `visitFunctionExpression` override that skips recursion into `FunctionExpression` bodies; the Provider-side check must apply the same exclusion.
2. **`context.read<T>()` used only to call a method with no reactive dependency** (e.g. `context.read<AnalyticsService>().logEvent(...)`) inside `build()` at the top level — still a real anti-pattern per DCM's rule (side-effecting reads belong in callbacks/`initState`, not `build()`), so still flagged; not an exemption.
3. **User-defined extension named `read` unrelated to Provider** — must gate on `target.staticType` resolving to `BuildContext`, not string-match the identifier `context`, mirroring the type-safety concern raised for the sibling `avoid-watch-outside-build` proposal.
4. **`context.read<T>()` inside `didChangeDependencies()` or `initState()`** — should pass; these are the intended call sites for non-reactive reads.

## Alternatives Considered

- **New standalone rule** (`avoid_context_read_inside_build`) — rejected for the same reason given in the sibling `avoid_ref_watch_outside_build` proposal: DCM treats the Riverpod and Provider variants as one rule (`avoid-read-inside-build`), and the detection logic (closures excluded, build-method gate) is already shared infrastructure in this file.
- **Rely on `flutter_lints`' generic `use_build_context_synchronously`** — does not detect this pattern; that rule targets `BuildContext` used after an `await`, a different hazard entirely.

---

## Decision

---

## Implementation Notes

Add a second detection branch to `AvoidRefReadInsideBuildRule.runWithReporter` (or a shared Provider/Riverpod dispatch) matching `MethodInvocation` named `read` whose target's static type is `BuildContext`. Reuse the existing `_RefReadVisitor.visitFunctionExpression` closure-skip behavior unchanged.

---

## Commits
