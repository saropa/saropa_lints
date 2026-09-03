# PROPOSAL: Prefer `IconButton.tooltip` Over Wrapping With `Tooltip`

**Status: Open**

Created: 2026-09-02
Type: New rule
Related rules: `none`

---

## Summary

Add `prefer_icon_button_tooltip_property` to flag `Tooltip(message: ..., child: IconButton(...))` and suggest using `IconButton`'s own `tooltip:` parameter instead. `IconButton.tooltip` is the built-in, semantics-aware path (it also feeds the button's accessible label); a separate `Tooltip` wrapper is redundant, adds an extra widget/semantics node, and can desynchronize from the button's actual accessible name.

**Closes gap:** `flutter_a11y_lints` `A21` (pub.dev). Implementing this proposal as specified fully closes this competitive gap — see `plans/GAP_ANALYSIS.md`.

---

## Motivation

`IconButton` ships a first-class `tooltip:` parameter specifically so authors don't need to hand-wire a `Tooltip` widget; when `tooltip:` is used, Flutter also uses that string as the button's semantic label if no explicit `Semantics`/`semanticLabel` is otherwise supplied. Wrapping in `Tooltip(...)` manually bypasses this integration, risks the tooltip text and the semantic label drifting apart, and adds an unnecessary widget. `flutter_a11y_lints`' `A21` is prior art for catching this common but avoidable pattern.

---

## Detection / Behavior

Flag a `Tooltip(...)` widget whose `child:` is directly an `IconButton(...)` (ignoring `tooltip:` not already being set on the inner `IconButton`).

### Should flag (bad code)

```dart
Tooltip(
  message: 'Delete', // LINT — use IconButton.tooltip instead
  child: IconButton(
    icon: const Icon(Icons.delete),
    onPressed: _delete,
  ),
);
```

### Should pass (good code)

```dart
IconButton(
  icon: const Icon(Icons.delete),
  tooltip: 'Delete', // OK — built-in tooltip integration
  onPressed: _delete,
);
```

---

## Proposed Tier

Tier: Recommended
Justification: Mechanical, low-risk simplification with a clear autofix (hoist `message:` into `tooltip:`, unwrap `Tooltip`); no meaningful false-positive surface.

---

## Edge Cases

1. **`Tooltip` wraps `IconButton` plus additional configuration** (`waitDuration:`, `preferBelow:`) that `IconButton.tooltip` cannot express — should pass or downgrade to a suggestion-only message; the plain-`message:` case is the only fully mechanical fix.
2. **`IconButton` already has its own `tooltip:` set, and is additionally wrapped in `Tooltip`** — should flag as doubly redundant; correction message should note both are present.
3. **`Tooltip` wraps a widget other than `IconButton`** (`ElevatedButton`, custom widget) — should pass; only `IconButton` has the dedicated `tooltip:` shortcut.
4. **`Tooltip` wraps `IconButton` indirectly through a `Padding`/`SizedBox`** — should pass (out of scope); only the direct-child case is unambiguous enough for a mechanical fix.

---

## Alternatives Considered

- **Extend to `Tooltip` wrapping any button-like widget** — rejected for the initial rule; only `IconButton` has a built-in `tooltip:` shortcut, so extending scope would require a manual (non-autofix) suggestion for other widgets, diluting the rule's precision.

---

## Decision

---

## Implementation Notes

---

## Commits
