# PROPOSAL: Flag `Row`/`Column`/`Flex` Widgets With Exactly One Child

**Status: Duplicate — already implemented as `AvoidSingleChildColumnRowRule` (`avoid_single_child_column_row`) in `lib/src/rules/widget/widget_layout_flex_scroll_rules.dart`**

Created: 2026-09-02
Type: New rule
Related rules: `avoid_single_child_in_multi_child_widgets` (proposed — broader superset, see that proposal's Alternatives Considered for the relationship between the two)

---

## Summary

Add `avoid_single_child_in_flex` to flag a `Row`, `Column`, or `Flex` widget whose `children` list contains exactly one element. A flex container with a single child provides no layout benefit over using the child directly (or wrapping it in a purpose-built widget like `Center`, `Align`, or `Padding`), and adds an unnecessary `RenderFlex` layout pass on every frame.

**Closes gap:** pyramid_lint `avoid_single_child_in_flex` (github.com/charlescyt/pyramid_lint). Implementing this proposal as specified fully closes this competitive gap — see `plans/GAP_ANALYSIS.md` line ~408, listed as a non-themed pyramid_lint gap: "`avoid_single_child_in_flex` (Row/Column/Flex with exactly one child — pyramid_lint)."

---

## Motivation

`Row`/`Column`/`Flex` exist to lay out *multiple* children along a main axis with alignment, spacing, and flex-factor distribution. When a flex widget is given exactly one child, none of that machinery does anything useful — the single child renders at whatever size/alignment a single-child widget (`Center`, `Align`, `Padding`, `SizedBox`, or nothing at all) would produce more cheaply and more clearly. This pattern is common after refactors that remove sibling widgets but leave the wrapping `Column` behind, or from developers reaching for `Column` out of habit when they need alignment. saropa_lints already has related layout-cost coverage in `widget_layout_flex_scroll_rules.dart` and `widget_layout_constraints_rules.dart` (e.g. `avoid_unbounded_constraints`, `avoid_singlechildscrollview_with_column`) but no existing check for single-child flex containers specifically.

---

## Detection / Behavior

### Should flag (bad code)

```dart
Widget build(BuildContext context) {
  return Column( // LINT — Column with exactly one child adds a needless layout pass
    children: [
      Text('Only child'),
    ],
  );
}
```

### Should pass (good code)

```dart
Widget build(BuildContext context) {
  return const Text('Only child'); // OK — no wrapping flex widget needed

  // Or, if centering/padding is actually required:
  // return const Center(child: Text('Only child')); // OK
}
```

---

## Proposed Tier

Tier: Comprehensive
Justification: Purely a micro-optimization/readability cleanup with zero correctness impact — a single extra `RenderFlex` is cheap in absolute terms, so this belongs alongside saropa's other opt-in layout-hygiene checks rather than Essential/Recommended where only functional or accessibility risks warrant default-on placement.

---

## Edge Cases

1. **`Row`/`Column` with `mainAxisAlignment`/`crossAxisAlignment` set to a non-default value** — should still flag; a single child has no "main axis" of siblings to align, so even a customized alignment property provides no observable effect with one child (the child already fills/centers per its own constraints).
2. **Single child wrapped in `Expanded`/`Flexible`** — should pass; `Expanded`/`Flexible` inside a flex parent changes how the child receives constraints (bounded vs. unbounded main-axis sizing) in a way a single-child replacement widget cannot replicate, so the flex wrapper is doing real work here.
3. **Children list built conditionally** (e.g. `children: [if (cond) WidgetA(), if (!cond) WidgetB()]`, statically always producing exactly one element) — should pass; AST-only analysis cannot prove the list always resolves to one element without evaluating `cond`, and flagging would risk false positives on lists that are two-or-more in the general case.
4. **`Row`/`Column` with a single child plus `SizedBox.shrink()`/empty spacer siblings** — should pass; more than one AST-level child element exists even if one is visually inert, and disambiguating "meaningfully empty" siblings from real content is out of scope (avoids false positives on legitimate spacer patterns).
5. **Custom subclasses of `Flex`** — should pass unless the subclass is a known Flutter core type; detecting arbitrary custom `Flex` subclasses would need type resolution beyond simple constructor-name matching and risks false positives on unrelated custom widgets that happen to share a constructor shape.

---

## Alternatives Considered

- **Fold this directly into the broader `avoid_single_child_in_multi_child_widgets` proposal instead of a separate rule** — considered, since pyramid_lint's Flex-only check is a strict subset of many_lints' broader multi-child check. Kept as a separate, narrower proposal because pyramid_lint and many_lints are two independently-cited gap sources with different scopes, and a project may want the narrower Flex-only check without opting into the broader (and noisier) `ListView`/`Stack`/`Wrap` coverage. See the broader proposal's Alternatives Considered for the final relationship recommendation.
- **Auto-fix that unwraps the flex widget** — worth pursuing once the base detection ships; unwrapping is mostly mechanical (replace `Column(children: [child])` with `child`, preserving any `Expanded`/`Flexible`-exempted cases per Edge Case 2) but deferred from this proposal to keep the initial scope to detection only.

---

## Decision

---

## Implementation Notes

Candidate home: `lib/src/rules/widget/widget_layout_flex_scroll_rules.dart`, alongside the existing flex-related checks (`avoid_unbounded_constraints` in the sibling `widget_layout_constraints_rules.dart`, `avoid_singlechildscrollview_with_column`). Detection: match `InstanceCreationExpression` for `Row`/`Column`/`Flex` constructors, inspect the `children:` named argument's `ListLiteral` for exactly one non-spread element, and check that element is not `Expanded`/`Flexible` per Edge Case 2.

---

## Commits
