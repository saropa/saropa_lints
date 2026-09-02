# PROPOSAL: Flag Composite Control With Multiple Focusable Descendants (Should Present a Single Semantic Role)

**Status: Open**

Created: 2026-09-02
Type: New rule
Related rules: `a07_require_semantics_exclude_semantics_with_label` (if implemented, otherwise `none`)

---

## Summary

Add `avoid_composite_control_multiple_focus_targets` to flag a custom composite widget (e.g. a card, list tile, or row wrapped in a single tappable `InkWell`/`GestureDetector`) that contains two or more independently-focusable/actionable descendants (nested `IconButton`, `Checkbox`, `TextButton`, etc.) without merging them into one semantic node via `MergeSemantics` or an explicit single-role `Semantics` wrapper. Screen-reader and switch-access users then have to tab through multiple redundant stops for what sighted users perceive as one control.

**Closes gap:** `flutter_a11y_lints` `A13` (pub.dev). Implementing this proposal as specified fully closes this competitive gap — see `plans/GAP_ANALYSIS.md`.

---

## Motivation

A tappable card that visually reads as "one thing you can tap" but internally nests a delete `IconButton` and a favorite `IconButton` alongside the row's own `InkWell` forces assistive-tech users to navigate through 3+ separate focus stops to do what a sighted user does in one gesture. This is a very common Flutter composition pattern (list rows, cards, tiles) and a very common accessibility miss. `flutter_a11y_lints`' `A13` is prior art for statically flagging composite controls with multiple focusable descendants that lack `MergeSemantics`.

---

## Detection / Behavior

Flag a widget subtree rooted at an interactive container (`InkWell`, `GestureDetector`, `Card` with `onTap`, `ListTile`) that contains 2 or more descendant widgets which are independently focusable/actionable (`IconButton`, `Checkbox`, `Switch`, `TextButton`, nested `GestureDetector`/`InkWell`), when no `MergeSemantics` ancestor wraps the subtree and no explicit `Semantics(container: true, ...)` collapses it into one role.

### Should flag (bad code)

```dart
InkWell(
  onTap: _openDetail, // LINT — row + trailing IconButton are two separate focus stops
  child: Row(
    children: [
      Expanded(child: Text(title)),
      IconButton(icon: const Icon(Icons.favorite), onPressed: _toggleFavorite),
    ],
  ),
);
```

### Should pass (good code)

```dart
MergeSemantics(
  child: InkWell(
    onTap: _openDetail, // OK — merged into a single semantic node
    child: Row(
      children: [
        Expanded(child: Text(title)),
        IconButton(icon: const Icon(Icons.favorite), onPressed: _toggleFavorite),
      ],
    ),
  ),
);
```

---

## Proposed Tier

Tier: Comprehensive
Justification: High-value but structurally heuristic (AST descent to count focusable descendants across intermediate layout widgets); Comprehensive fits saropa's placement for accessibility rules requiring deeper traversal with real false-positive risk on genuinely-intended multi-focus rows.

---

## Edge Cases

1. **Row genuinely intended to have two independent actions** (e.g. a list tile with both "tap row to view" and "tap trailing checkbox to select", where both actions are meaningfully distinct) — should pass or be suppressible; `MergeSemantics` is not always the correct answer, so the message should explain the alternative (explicit separate but well-labeled semantics) rather than mandate merging unconditionally.
2. **Only one focusable descendant** (the container itself is the only actionable target) — should pass; the rule requires 2+.
3. **`MergeSemantics` present anywhere in the subtree, even partial** — should pass; do not require it to wrap the exact outermost container as long as it covers the composite region.
4. **Composite control is a custom widget class, not inline** — should still flag by inspecting the `build()` method's returned tree the same way as inline code.

---

## Alternatives Considered

- **Mandate `MergeSemantics` as the only accepted fix** — rejected; some composite controls should legitimately expose multiple distinct roles (e.g. a dismissible list item with row-tap AND a trailing delete action are sometimes intentionally separate). The rule flags the pattern; the correction message offers `MergeSemantics` as the common fix but does not force it via autofix.

---

## Decision

---

## Implementation Notes

---

## Commits
