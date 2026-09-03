# PROPOSAL: Flag Duplicate `context_plus` `context.use()` Calls Missing a Disambiguating Key

**Status: Open**

Created: 2026-09-02
Type: New rule
Related rules: `context_ref_reassignment` (`context_plus_lint` companion proposal, same source package — see `bugs/proposal_context_ref_reassignment.md`)

---

## Summary

Add `context_use_unique_key` to flag a second `context.use()`/context-scoped-ref call within the same `build()` method whose (return type, `key`) combination duplicates an earlier call in that build without a distinguishing `key` argument — the `context_plus` package needs a unique key to tell apart multiple independent state instances of the same type requested from the same widget, and an omitted or duplicate key causes it to conflate what should be two separate pieces of state into one.

**Closes gap:** `context_plus_lint` `context_use_unique_key` (github.com/s0nerik/context_plus, packages/context_plus_lint). Implementing this proposal as specified fully closes this competitive gap — see `plans/GAP_ANALYSIS.md` `context_plus_lint` section (HAVE: 0, PARTIAL: 0, GAP: 4).

---

## Motivation

`context_plus`'s `context.use<T>()` identifies which stored value to hand back by a combination of the requesting context and the requested type `T` — when a `key` parameter is available (as it is for exactly this reason), it becomes part of that identity so a widget can hold several independent instances of the same type. If a widget calls `context.use<AnimationController>()` twice to manage two logically distinct controllers but never supplies a `key` to either call, `context_plus` has no way to distinguish them: the second call either returns the SAME instance as the first (silently merging two states the developer believed were independent) or overwrites the first's registration outright, depending on internal implementation details the caller shouldn't need to know to get correct behavior. This is precisely the kind of "compiles fine, runs fine at first glance, breaks under specific interaction patterns" bug that a static check is well suited to catch, since the fix (adding a distinguishing `key`) is mechanical once the duplicate is pointed out.

---

## Detection / Behavior

### Should flag (bad code)

```dart
class DualAnimationWidget extends StatelessWidget {
  const DualAnimationWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final fadeController = context.use<AnimationController>(); // first use
    final slideController = context.use<AnimationController>(); // LINT — same
      // return type as `fadeController`'s call, no `key` on either call to
      // disambiguate; context_plus cannot tell these two requests apart
    return SlideTransition(
      position: Tween<Offset>(begin: Offset.zero, end: const Offset(1, 0))
          .animate(slideController),
      child: FadeTransition(opacity: fadeController, child: const Placeholder()),
    );
  }
}
```

### Should pass (good code)

```dart
class DualAnimationWidget extends StatelessWidget {
  const DualAnimationWidget({super.key});

  @override
  Widget build(BuildContext context) {
    // OK — distinct keys disambiguate the two same-typed requests.
    final fadeController = context.use<AnimationController>(key: 'fade');
    final slideController = context.use<AnimationController>(key: 'slide');
    return SlideTransition(
      position: Tween<Offset>(begin: Offset.zero, end: const Offset(1, 0))
          .animate(slideController),
      child: FadeTransition(opacity: fadeController, child: const Placeholder()),
    );
  }

  // OK — a single call to a given type within this build needs no key at all.
  Widget buildSingle(BuildContext context) {
    final controller = context.use<AnimationController>();
    return FadeTransition(opacity: controller, child: const Placeholder());
  }
}
```

---

## Proposed Tier

Tier: Comprehensive (or Pedantic)
Justification: This rule only fires on projects depending on the `context_plus` package and specifically on widgets that call `context.use<T>()` more than once for the same type — a narrow, package-specific pattern. Matches the tier recommended for the companion rule `context_ref_reassignment` and saropa's existing placement for other niche package-specific checks.

---

## Edge Cases

1. **Two `context.use<T>()` calls with the same `T` but DIFFERENT, non-empty `key` values** — should pass; distinct keys are exactly the disambiguation mechanism the package provides.
2. **Two `context.use<T>()` calls with the same `T` and the SAME literal `key` value** (a copy-paste mistake, e.g. both calls pass `key: 'controller'`) — should flag; a duplicate key is functionally equivalent to no key at all for disambiguation purposes.
3. **Two `context.use<T>()` calls with DIFFERENT type arguments `T`** (e.g. one `AnimationController`, one `ScrollController`) — should pass; different types are already disambiguated by the type system, no key is needed.
4. **A single `context.use<T>()` call anywhere in the build (no duplicate of that type at all)** — should pass; the key requirement only exists once there are multiple same-typed requests to tell apart.
5. **Duplicate same-typed calls split across a helper method called from `build()`, rather than both calls being lexically inside `build()` itself** — false negative, acceptable for a first version; AST-only per-method analysis cannot see across method-call boundaries without whole-program call-graph resolution, consistent with how other saropa build-method-scoped rules limit their scope to a single method body.
6. **`key` argument passed as a non-literal expression (a variable or computed value) rather than a string/const literal** — should pass without attempting to prove uniqueness; the rule can only reliably compare literal key values, so a dynamically computed key is assumed intentional and correctly disambiguating (avoids false positives from over-eager literal-matching).

---

## Alternatives Considered

- **Require a `key` on every `context.use<T>()` call unconditionally, even when a type is only requested once** — rejected; this is a stricter rule than the one `context_plus_lint` actually ships (which is a "you HAVE two same-typed requests, so pick keys" check, not a blanket key-always-required rule) and would generate needless friction on the overwhelmingly common single-use case.
- **Attempt to prove key uniqueness across non-literal/computed key expressions** — rejected for a first version; without evaluating arbitrary expressions, the rule cannot reliably determine whether two computed keys are actually distinct, so it should stay conservative and only flag missing-key or identical-literal-key duplicates (edge cases 2 and the base case), leaving computed keys unflagged rather than risk false positives.

---

## Decision

---

## Implementation Notes

Package-specific — targets `context_plus`'s `context.use<T>()` extension method (verify the exact method/extension name and `key` parameter signature against the current `context_plus` API before implementation). No existing rule file covers `context_plus`; a grep of `lib/src/rules/packages/` finds no `context_plus_rules.dart`. This rule should live alongside `context_ref_reassignment` in a new `lib/src/rules/packages/context_plus_rules.dart` file. Detection: within each `build()` method body (or any method, scoped per-method), collect all `context.use<T>()` invocation expressions, group by resolved type argument `T`, and within each group with more than one call, flag any call whose `key` argument is absent or whose literal `key` value duplicates another call's literal `key` value in the same group. Share the standard `ProjectContext` dependency-detection gate with the sibling rule.

---

## Commits
