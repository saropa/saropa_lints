# PROPOSAL: Flag Reassignment of a `context_plus` `Ref` After Its Initial Binding

**Status: Open**

Created: 2026-09-02
Type: New rule
Related rules: `context_use_unique_key` (`context_plus_lint` companion proposal, same source package — see `bugs/tier_5_niche/proposal_context_use_unique_key.md`)

---

## Summary

Add `context_ref_reassignment` to flag binding the same `context_plus` `Ref<T>` instance more than once inside a single `build()` method (or otherwise reassigning a `Ref`-typed variable/field after its initial binding), since `context_plus` `Ref`s are designed to be bound exactly once via `context.use()`/`ref.bind(context)` and the package's lifecycle/disposal guarantees are keyed to that single binding point.

**Closes gap:** `context_plus_lint` `context_ref_reassignment` (github.com/s0nerik/context_plus, packages/context_plus_lint). Implementing this proposal as specified fully closes this competitive gap — see `plans/GAP_ANALYSIS.md` `context_plus_lint` section (HAVE: 0, PARTIAL: 0, GAP: 4).

---

## Motivation

`context_plus` provides `Ref<T>` as a widget-scoped handle that ties a value's creation, retrieval, and disposal to a specific `BuildContext`'s lifecycle — the package's entire value proposition is that binding a `Ref` once, at a stable point in `build()`, gives Flutter-hooks-like ergonomics (`context.use()`) without the caller having to manually manage a `State` object. Binding the same `Ref` a second time inside the same build — whether through a literal duplicate call, a conditional branch that re-executes the bind, or an explicit reassignment of the variable holding the `Ref` — breaks that single-binding contract: the package's internal bookkeeping (which context "owns" the ref, when to dispose the underlying value) is keyed to the first bind, and a second bind can either silently no-op, throw, or — worst case — cause the underlying resource to be disposed and recreated mid-build, producing state loss that looks like an unrelated bug several frames later. `context_plus_lint` ships this exact rule as prior art because the mistake is easy to make and hard to trace back to its source once symptoms appear.

---

## Detection / Behavior

### Should flag (bad code)

```dart
class CounterWidget extends StatelessWidget {
  const CounterWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final counterRef = Ref<int>();
    counterRef.bind(context, () => 0);
    counterRef.bind(context, () => 0); // LINT — same Ref bound a second time
                                        // in this build; the lifecycle
                                        // guarantee assumes exactly one bind
    return Text('${counterRef.value}');
  }
}

class ToggleWidget extends StatelessWidget {
  const ToggleWidget({super.key, required this.showAlt});
  final bool showAlt;

  @override
  Widget build(BuildContext context) {
    var stateRef = Ref<bool>();
    stateRef.bind(context, () => false);
    if (showAlt) {
      stateRef = Ref<bool>(); // LINT — reassigning the Ref-typed variable
                              // after its initial binding
      stateRef.bind(context, () => true);
    }
    return Text('${stateRef.value}');
  }
}
```

### Should pass (good code)

```dart
class CounterWidget extends StatelessWidget {
  const CounterWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final counterRef = Ref<int>();
    counterRef.bind(context, () => 0); // OK — bound exactly once
    return Text('${counterRef.value}');
  }
}
```

---

## Proposed Tier

Tier: Comprehensive (or Pedantic)
Justification: This rule only fires on projects depending on the `context_plus` package — the vast majority of saropa_lints consumers (GetX, Riverpod, Bloc, Provider, plain `InheritedWidget`) never construct a `Ref` at all. Package-specific rules with a narrow install base belong in Comprehensive/Pedantic, matching saropa's existing placement for other niche package-specific checks (e.g. `qr_scanner_rules.dart`).

---

## Edge Cases

1. **`Ref` declared as a top-level `final`/`static final` and bound exactly once** — should pass; this is `context_plus`'s documented canonical usage pattern (also the subject of the separate, not-yet-proposed `wrong_ref_declaration` gap).
2. **`Ref` bound conditionally in an `if`/`else` where only one branch can execute per build** — needs discussion; a single call to `.bind()` still only happens once per actual build execution, so a purely AST-shape "count calls" check would false-positive here. The rule should track reachability (mutually exclusive branches don't both execute) rather than raw call-site count, or explicitly document this as a known false-positive class if reachability analysis is out of scope for a first version.
3. **`Ref` bound inside a loop** (`for (final id in ids) { ref.bind(context, ...); }`) — should flag; a loop trivially produces more than one bind call against the same `Ref` instance regardless of reachability analysis.
4. **Reassigning a `Ref`-typed variable to a BRAND NEW `Ref()` instance rather than rebinding the same instance** — should still flag per the second bad example; even though it's technically a "new Ref," the reassignment pattern is the anti-pattern `context_plus` warns against — the variable is meant to hold one stable `Ref` for the widget's lifetime.
5. **`Ref.bind()` called once per build, but the containing widget itself rebuilds many times** (normal Flutter behavior) — should pass; each `build()` invocation is expected to call `.bind()` exactly once, and `context_plus` handles the idempotent-across-rebuilds case internally. The rule only targets multiple binds WITHIN one `build()` call's source, not across separate build invocations.

---

## Alternatives Considered

- **Only flag literal duplicate `.bind()` calls on the same variable, skip variable-reassignment detection** — considered as a narrower, lower-false-positive-risk first cut, but rejected because the gap analysis describes the rule as "binding the same Ref instance more than once," and variable reassignment to a fresh `Ref()` is functionally the same anti-pattern from the package's perspective (a widget meant to hold one stable ref across its lifetime now holds two).
- **Resolve full control-flow reachability to eliminate the mutually-exclusive-branch false positive (edge case 2)** — deferred to implementation; flagging conservatively (any syntactic second `.bind()` call regardless of branch) is the simpler first cut, with reachability analysis as a documented follow-up if false positives prove common in practice.

---

## Decision

---

## Implementation Notes

Package-specific — targets `context_plus`'s `Ref<T>` type and its `.bind()` method (or `context.use()` shorthand, depending on the package's exact API surface — verify against the current `context_plus` API before implementation, as the gap analysis description is based on the upstream lint's stated behavior, not a direct read of the package source). No existing rule file covers `context_plus`; a grep of `lib/src/rules/packages/` finds no `context_plus_rules.dart`. This rule should live alongside `context_use_unique_key` in a new `lib/src/rules/packages/context_plus_rules.dart` file, sharing a `Ref`-type-resolution helper and the standard `ProjectContext` dependency-detection gate (skip scanning when the target project doesn't depend on `context_plus`) established by other package-specific rule files.

---

## Commits
