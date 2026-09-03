# PROPOSAL: Fix Silent No-Op `use_closest_build_context` Rule (solid_lints `use_nearest_context` Parity)

**Status: Open**

Created: 2026-09-02
Type: Bug fix / existing rule
Related rules: `use_closest_build_context` (existing, broken)

---

## Summary

`UseClosestBuildContextRule` (`lib/src/rules/core/context_rules.dart:1483`, lint code `use_closest_build_context`) is already registered with a real `LintCode` and presumably wired into `all_rules.dart`/`tiers.dart`, but its `runWithReporter` body is an empty `{}` — it never actually visits anything and silently never fires. This proposal is to implement the missing body so the rule matches solid_lints' `use_nearest_context` behavior: flag use of an outer/ancestor `BuildContext` inside a widget subtree where a closer, more-local `BuildContext` is available (e.g. inside a `Builder`, a list-item `itemBuilder`, or a nested widget's own `build(context)`).

**Closes gap:** `solid_lints` `use_nearest_context` (github.com/solid-software/solid_lints). Implementing this proposal as specified fully closes this competitive gap — see `plans/GAP_ANALYSIS.md` `solid_lints` section: "Bug found in saropa_lints itself... `use_closest_build_context`... registered with a real `LintCode` but its `runWithReporter` body is empty (`{}`) — a silent no-op" and the `use_nearest_context` gap-list entry noting it "corresponds to the empty-stub bug above."

---

## Motivation

Using a stale outer `BuildContext` instead of the nearest one available is a classic Flutter footgun: `Theme.of(context)`/`MediaQuery.of(context)`/`Scaffold.of(context)` resolve relative to the position in the widget tree of the `context` passed in, so using the parent's context inside a `Builder`/`itemBuilder`/nested `build()` returns the WRONG ancestor's data (or throws `Scaffold.of() called with a context that does not contain a Scaffold`). This is exactly the class of bug a lint rule should catch — and saropa already has the rule *registered* and *shipping a lint code*, just not actually running, which is worse than not having the rule at all (it gives false confidence that the check exists).

---

## Detection / Behavior

### Should flag (bad code)

```dart
class ItemList extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemBuilder: (itemContext, index) {
        return Text(
          Theme.of(context).textTheme.bodyLarge!.fontSize.toString(), // LINT — should use itemContext, the nearer context
        );
      },
    );
  }
}
```

### Should pass (good code)

```dart
class ItemList extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemBuilder: (itemContext, index) {
        return Text(
          Theme.of(itemContext).textTheme.bodyLarge!.fontSize.toString(), // OK — nearest context used
        );
      },
    );
  }
}
```

---

## Proposed Tier

Tier: Recommended
Justification: Correctness risk (wrong ancestor resolution, potential runtime exceptions from `Scaffold.of`/`Theme.of` mismatches) — matches saropa's placement for other `BuildContext`-misuse rules.

---

## Edge Cases

1. **Only one `BuildContext` in scope (no nested builder/nested `build()`)** — should pass; nothing to compare against.
2. **Outer `context` deliberately used because the nearer context does not yet contain the required inherited widget (e.g. `Scaffold.of` needed before a `Scaffold` descendant exists)** — needs discussion; may require an escape hatch, since "nearest" isn't always "correct" when the target ancestor widget sits above the inner builder's position.
3. **`context` captured in a closure and used asynchronously after the nearer builder context is already gone** — out of scope for this rule; that's `use_build_context_synchronously`'s territory, not nearest-context selection.
4. **Multiple nested builders each introducing their own context** — should always suggest the innermost available context relative to the usage site, not just "any context closer than the outermost."

---

## Alternatives Considered

- **Delete the dead rule instead of implementing it** — rejected; the underlying check is valuable (confirmed by solid_lints shipping the same rule) and a `LintCode`/tier entry already exists, so implementing is less wasted work than removing and potentially re-adding later.

---

## Decision

---

## Implementation Notes

- Existing stub location: `lib/src/rules/core/context_rules.dart:1483`, class `UseClosestBuildContextRule`. Verify its current `LintCode` message/correction text before rewriting — reuse if still accurate, update if the original author's placeholder text doesn't match the finished implementation.
- Confirm registration status in `lib/saropa_lints.dart` (`_allRuleFactories`) and tier assignment in `lib/src/tiers.dart` are already correct (per the gap-analysis note, they appear to be) — only the visitor body needs work.

---

## Commits
