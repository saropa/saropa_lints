# PROPOSAL: Flag Any Multi-Child Widget Given Only One Child

**Status: Open**

Created: 2026-09-02
Type: New rule
Related rules: `avoid_single_child_in_flex` (proposed — narrower Flex-only subset of this rule; see Alternatives Considered for the recommended relationship)

---

## Summary

Add `avoid_single_child_in_multi_child_widgets` to flag any widget from Flutter's multi-child widget family — `Row`, `Column`, `Flex`, `Stack`, `Wrap`, `ListView(children: ...)`, `Column`-adjacent layout widgets, etc. — that is constructed with exactly one child. This generalizes the narrower Flex-only check to the whole family of widgets whose entire purpose is arranging *multiple* children.

**Closes gap:** many_lints `avoid_single_child_in_multi_child_widgets` (github.com/Nikoro/many_lints). Implementing this proposal as specified fully closes this competitive gap — see `plans/GAP_ANALYSIS.md` many_lints section, "Remaining non-themed gaps" list: "`avoid_single_child_in_multi_child_widgets`."

---

## Motivation

The single-child-flex problem (see the narrower `avoid_single_child_in_flex` proposal) is one instance of a broader pattern: any widget whose API shape is `children: List<Widget>` — `Stack`, `Wrap`, `ListView(children: ...)`, `GridView(children: ...)`, `Column`/`Row`/`Flex` — provides zero layout benefit over a direct child or a purpose-built single-child widget when the list has exactly one element. `Stack` with one child never needs z-ordering; `Wrap` with one child never wraps; `ListView(children: [oneWidget])` builds an entire scrollable/sliver machinery for content that doesn't scroll. This is a broader, more general version of the Flex-specific check, and many_lints ships it as the umbrella rule rather than splitting it by widget family.

---

## Detection / Behavior

### Should flag (bad code)

```dart
Widget build(BuildContext context) {
  return Stack( // LINT — Stack with exactly one child has no stacking to do
    children: [
      Image.asset('background.png'),
    ],
  );
}

Widget build(BuildContext context) {
  return ListView( // LINT — ListView with one child needs no scrolling/sliver machinery
    children: [
      const Text('Only item'),
    ],
  );
}
```

### Should pass (good code)

```dart
Widget build(BuildContext context) {
  return Image.asset('background.png'); // OK — no wrapping multi-child widget needed
}

Widget build(BuildContext context) {
  return const Text('Only item'); // OK — a static single item doesn't need a scroll view
}
```

---

## Proposed Tier

Tier: Comprehensive
Justification: Same rationale as the narrower Flex-only rule — a readability/micro-perf cleanup with no correctness risk, appropriate for an opt-in deep-pass tier rather than default-on Essential/Recommended.

---

## Edge Cases

1. **`ListView`/`GridView` built with `.builder()`/`itemCount`** — should pass; the item count is dynamic/runtime-determined and cannot be statically proven to always be one, unlike a literal `children: [...]` list.
2. **`Stack` with one child plus `Positioned` siblings that are conditionally omitted** — same reasoning as the Flex proposal's Edge Case 3: only flag when the AST-level children list literal statically contains exactly one element; conditional (`if`) elements in the list make the true count unprovable, so pass.
3. **`Wrap`/`Stack`/`ListView` single child wrapped in a widget that depends on stack-positioning semantics** (e.g. a lone `Positioned` inside `Stack`) — should pass; `Positioned` only has meaning inside a `Stack`, so a `Stack` containing a single `Positioned` child is doing real work (anchoring) that a direct-child replacement cannot express.
4. **Overlap with the narrower `avoid_single_child_in_flex` rule for `Row`/`Column`/`Flex` cases** — see Alternatives Considered; the two rules must not both fire on the same node if both are enabled simultaneously, or a project running both tiers gets duplicate diagnostics on every `Column`/`Row` single-child case.

---

## Alternatives Considered

- **Ship only this broader rule and skip the narrower `avoid_single_child_in_flex`** — considered, since this rule is a strict superset in scope (it already covers `Row`/`Column`/`Flex` as members of the multi-child family). Rejected as the sole implementation because the two rules are cited from two different upstream packages (pyramid_lint vs. many_lints) with two different rule names in `plans/GAP_ANALYSIS.md`, and a project comparing saropa's coverage against either specific package by name expects to find a matching rule name. **Recommended resolution:** implement this rule to cover only the non-Flex multi-child widgets (`Stack`, `Wrap`, `ListView(children:)`, `GridView(children:)`, `Column`-external families), and have it explicitly exclude `Row`/`Column`/`Flex`, deferring those to `avoid_single_child_in_flex`. This avoids double-flagging while still closing both named gaps under their expected rule names.
- **Implement `avoid_single_child_in_flex` as a thin wrapper/alias that also fires this rule's code** — rejected; two separate `LintCode`s with distinct rule names are needed regardless (each gap is tracked by exact rule name in `GAP_ANALYSIS.md`), so sharing one detection function across two rule classes (excluding Flex types from this one) is simpler and avoids any code-emission ambiguity.

---

## Decision

---

## Implementation Notes

Candidate home: same file as the Flex-only proposal, `lib/src/rules/widget/widget_layout_flex_scroll_rules.dart`, as a sibling rule class. Given the recommended non-overlapping split in Alternatives Considered, this rule's constructor-name match set should explicitly be `{Stack, Wrap, ListView, GridView, ...}` and explicitly exclude `Row`/`Column`/`Flex` (owned by `avoid_single_child_in_flex`) to keep the two rules' fire conditions disjoint.

---

## Commits
