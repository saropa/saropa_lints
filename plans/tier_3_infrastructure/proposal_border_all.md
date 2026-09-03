# PROPOSAL: Flag `Border.all()` Used to Style Only a Single Side

**Status: Open**

Created: 2026-09-02
Type: New rule
Related rules: `avoid_border_all` (existing, unconditional — see Alternatives Considered for how this proposal differs and avoids duplicate firing)

---

## Summary

Add a new rule (proposed id `avoid_border_all_single_side`) that flags `Border.all(...)` when the surrounding code only visually needs one side styled — e.g. a top divider, a bottom underline, or a left accent bar — because `Border.all()` unconditionally paints and lays out all four `BorderSide`s even when three of them are indistinguishable from "no border" only by coincidence of context, not by an explicit zero-width/transparent side.

**Closes gap:** essential_lints `border-all` (pub.dev). Implementing this proposal as specified fully closes this competitive gap — see `plans/GAP_ANALYSIS.md`.

---

## Motivation

`Border.all()` is the reflexive choice whenever a developer wants "a border," even when the actual design need is a single edge — a divider under a list tile, an accent stripe on a card's leading edge, an underline on a focused text field. Using `Border.all()` for these cases means the renderer computes and paints four `BorderSide`s per frame instead of one, and — more importantly for maintainability — it obscures intent: a reader sees `Border.all(color: Colors.grey, width: 1)` and cannot tell from the constructor call alone whether all four sides are a deliberate design decision or an accident of reaching for the most familiar constructor. `saropa_lints` already ships `avoid_border_all` (`lib/src/rules/widget/widget_layout_constraints_rules.dart`), which unconditionally flags every `Border.all(...)` call and suggests `Border.fromBorderSide(...)` — but that rule fires identically whether all four sides are genuinely wanted or not, so it does not by itself close the essential_lints gap, which is specifically about the single-side misuse case (a stricter, more targeted signal than "you used this constructor at all").

---

## Detection / Behavior

### Should flag (bad code)

```dart
Container(
  decoration: BoxDecoration(
    border: Border.all(color: Colors.grey.shade300, width: 1), // LINT — only used as a bottom divider in this widget
  ),
  child: const ListTile(title: Text('Row')),
)
```

```dart
// The surrounding layout makes three sides invisible: the widget sits flush
// against its parent's left/right/top edges inside a ClipRect, so only the
// bottom edge is ever visible — Border.all() still pays for all four sides.
Padding(
  padding: EdgeInsets.zero,
  child: DecoratedBox(
    decoration: BoxDecoration(
      border: Border.all(color: theme.dividerColor), // LINT
    ),
    child: header,
  ),
)
```

### Should pass (good code)

```dart
Container(
  decoration: BoxDecoration(
    border: Border(
      bottom: BorderSide(color: Colors.grey.shade300, width: 1), // OK — only the needed side
    ),
  ),
  child: const ListTile(title: Text('Row')),
)
```

```dart
Container(
  decoration: BoxDecoration(
    border: Border.all(color: Colors.grey.shade300, width: 1), // OK — genuinely a full outline (e.g. a card/chip)
  ),
  child: const Text('Card'),
)
```

---

## Proposed Tier

Tier: Comprehensive
Justification: This is a design-intent/efficiency heuristic, not a correctness bug — `Border.all()` on a single-visible-side widget still renders correctly, it is only wasteful and less self-documenting. Matches saropa's placement for other layout-efficiency style rules (alongside the existing `avoid_border_all`) rather than Essential/Recommended, since detecting "only one side is visually relevant" requires inference about surrounding layout that the AST-only check cannot fully verify and would otherwise create false positives at a stricter tier.

---

## Edge Cases

1. **`Border.all()` inside a widget explicitly named/described as an outline, card, chip, or badge** (e.g. `OutlinedButton`, `Card`, `Chip` styling, or a `BoxDecoration` alongside a fully-rounded `borderRadius`) — should pass; a fully-rounded border strongly implies all four sides are intentional, since a single-side border cannot combine with a full corner radius the way an outline can.
2. **`Border.all()` where the call site cannot be statically proven to need only one side** (the common case — most `Border.all()` calls in ordinary containers) — should NOT be flagged by static heuristics alone; detection must be scoped to statically-verifiable signals (see Detection notes below), not speculative "maybe you only need one side" guessing, to avoid drowning real full-outline usages in noise.
3. **`Border.all()` combined with a zero `width`** (`Border.all(width: 0)`) — should flag as a distinct, higher-confidence case: a zero-width border is a no-op on every side, so the call is either dead code or a placeholder that should be removed entirely; correction message should suggest removing the `border:` property rather than switching to `Border.fromBorderSide`.
4. **Dynamic side selection via ternary/variable** (`Border.all(color: isTop ? Colors.red : Colors.transparent)`) — should pass; the color is not statically a constant single-side pattern, and rewriting this into a `Border(...)` per-side constructor would require conditional logic the static rule cannot safely synthesize.
5. **Generated code (`.g.dart`, `.freezed.dart`)** — should pass; standard generated-file suppression applies.

---

## Alternatives Considered

- **Extend the existing `avoid_border_all` rule instead of adding a new one** — considered, since both rules trigger on the same `Border.all(...)` call site; rejected for the initial proposal because `avoid_border_all`'s existing message ("prefer `Border.fromBorderSide` for const borders") is a *stylistic* constructor preference that fires unconditionally, while this proposal's gap-closing signal is a *design-intent* heuristic (single-side usage, or the width-0 no-op case) that only sometimes applies — conflating the two would either weaken the existing rule's unconditional message or force a shared rule to carry two unrelated correction messages. If approved, the two rules should be reconciled at implementation time (e.g. this proposal's single-side/no-op detection could become an additional, higher-severity `correctionMessage` branch on `avoid_border_all` rather than a second always-competing rule) to avoid double-firing.
- **Flag purely on "only one side has a non-default value" via full symbolic evaluation of the resulting `BoxDecoration`'s paint** — rejected as infeasible for a static AST rule; the proposal instead scopes to the two statically-verifiable signals in Edge Cases 1 and 3 (fully-rounded-radius exclusion, zero-width no-op detection) rather than attempting to prove layout-level single-side visibility, which would require whole-widget-tree analysis beyond this package's AST-only scope.

---

## Decision

---

## Implementation Notes

Candidate home: `lib/src/rules/widget/widget_layout_constraints_rules.dart`, immediately adjacent to the existing `AvoidBorderAllRule` (line ~762) — share its `Border.all` `MethodInvocation` detection (`target.name == 'Border' && node.methodName.name == 'all'`) as a base, then layer the width-0 and full-radius-exclusion checks on top. Given the overlap with `avoid_border_all` noted in Alternatives Considered, review during implementation whether this should ship as a separate rule id or as a refinement of the existing one before adding it to `all_rules.dart`/`tiers.dart`.

---

## Commits
