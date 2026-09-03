# PROPOSAL: Flag Redundant `Semantics(button: true)` Wrapper on a Primitive Button

**Status: Open**

Created: 2026-09-02
Type: New rule
Related rules: `none`

---

## Summary

Add `avoid_redundant_semantics_button_flag` to flag a `Semantics(button: true, ...)` wrapper placed directly around a widget that is already a Material/Cupertino button primitive (`ElevatedButton`, `TextButton`, `OutlinedButton`, `IconButton`, `CupertinoButton`, `InkWell`/`GestureDetector` already carrying `Semantics` via a button ancestor). These primitives already merge `button: true` into their own semantics node, so the extra wrapper is dead configuration and, in some tree shapes, can create a duplicate or conflicting semantics node.

**Closes gap:** `flutter_a11y_lints` `A05` (pub.dev). Implementing this proposal as specified fully closes this competitive gap — see `plans/GAP_ANALYSIS.md`.

---

## Motivation

Developers unfamiliar with the button widgets' built-in semantics sometimes wrap them defensively in `Semantics(button: true)`, assuming it is required for screen-reader support. It is not — Flutter's button primitives already report `button: true` in their `SemanticsNode`. The redundant wrapper adds noise, and in the worst case (mismatched `label:`/`onTapHint:`) can produce an accessibility tree with two overlapping button semantics nodes, which some screen readers announce twice. `flutter_a11y_lints` ships this check as `A21` — sorry, `A05` — as a mechanical "unwrap" detector.

---

## Detection / Behavior

Flag a `Semantics(...)` widget whose `child:` argument is (directly, ignoring pure layout wrappers like `Padding`/`SizedBox`) one of the known button primitives, when the `Semantics` call sets `button: true`.

### Should flag (bad code)

```dart
Semantics(
  button: true, // LINT — ElevatedButton already reports button: true
  child: ElevatedButton(
    onPressed: _save,
    child: const Text('Save'),
  ),
);
```

### Should pass (good code)

```dart
ElevatedButton(
  onPressed: _save,
  child: const Text('Save'), // OK — no wrapper needed
);

// OK — Semantics wrapping a non-button widget to grant button role legitimately.
Semantics(
  button: true,
  onTap: _save,
  child: Container(
    decoration: const BoxDecoration(color: Colors.blue),
    child: const Text('Save'),
  ),
);
```

---

## Proposed Tier

Tier: Recommended
Justification: Dead/redundant accessibility configuration with a mechanical unwrap fix; safe once scoped to the known button-primitive widget list.

---

## Edge Cases

1. **`Semantics(button: true)` wrapping a custom widget that internally renders one of the primitives, several layers down** — should pass; the rule only inspects the direct/near-direct child, not transitive descendants, to avoid false positives on opaque custom widgets.
2. **`Semantics` also sets other meaningful fields (`label:`, `hint:`, `onTapHint:`) alongside `button: true`** — should flag only the redundant `button: true` argument via quick fix removing that one named argument, keeping the rest of the wrapper if other fields are present.
3. **`Semantics(button: true)` around `InkWell`/`GestureDetector`** — should pass; these are not button primitives and legitimately need the explicit role.
4. **`CupertinoButton`** — should flag same as Material buttons; already reports `button: true`.

---

## Alternatives Considered

- **Flag any `Semantics(button: true)` regardless of child** — rejected; too broad, would flag legitimate uses on non-button widgets like `InkWell`.

---

## Decision

---

## Implementation Notes

---

## Commits
