# PROPOSAL: Prefer `Padding` Over Margin-Only `Container`

**Status: Open**

Created: 2026-09-02
Type: New rule
Related rules: `prefer_sized_box_for_whitespace`

---

## Summary

Add `use_padding` to flag a `Container` used solely for its `margin:` (plus optionally `key:` and `child:`, with no other decoration/color/constraint arguments) and suggest wrapping the child in `Padding(padding: ..., child: ...)` instead — a lighter single-purpose widget with no `DecoratedBox`/`ConstrainedBox` intermediate allocations.

**Closes gap:** `leancode_lint` `use_padding` (`Container(margin:, [key], [child])` only → `Padding`). Implementing this proposal as specified fully closes this competitive gap — see `plans/GAP_ANALYSIS.md` `leancode_lint` gap list.

---

## Motivation

saropa's `prefer_sized_box_for_whitespace` already establishes the precedent that a `Container` used for a single narrow purpose should collapse to the lighter dedicated widget — this rule is the direct sibling for margin-only `Container`s, which build an unnecessary `DecoratedBox`/`ConstrainedBox`/`Padding` chain internally just to apply outer spacing.

---

## Detection / Behavior

Flag a `Container(...)` `InstanceCreationExpression` whose only named arguments (besides `child`/`key`) are `margin:`.

### Should flag (bad code)

```dart
Container(
  margin: const EdgeInsets.all(8),
  child: const Text('Hi'), // LINT — margin-only Container, use Padding instead
);
```

### Should pass (good code)

```dart
Padding(
  padding: const EdgeInsets.all(8),
  child: const Text('Hi'), // OK
);

Container(
  margin: const EdgeInsets.all(8),
  color: Colors.red, // OK — has other decoration, Container is appropriate
  child: const Text('Hi'),
);
```

---

## Proposed Tier

Tier: Recommended
Justification: Matches the existing `prefer_sized_box_for_whitespace` placement — a performance/simplicity rule with a purely mechanical, low-false-positive detection shape.

---

## Edge Cases

1. **`Container` with `margin:` and `padding:` both set, no other decoration** — should discuss; that combination still can't collapse to a single `Padding` (needs two nested `Padding`s), so v1 should likely exempt this combination rather than suggest an incomplete fix.
2. **`Container` with `margin:` and `constraints:`/`width:`/`height:`** — should pass; those arguments require `Container`'s (or `ConstrainedBox`'s) behavior, not just spacing.
3. **`Container()` with only `key:` and `child:`, no `margin:` at all** — out of scope for this rule; that's a different "unnecessary Container" pattern, not this one.

---

## Alternatives Considered

- **Combine with `prefer_sized_box_for_whitespace` into one general "unnecessary Container" rule** — rejected; each targets a different single-purpose replacement (`SizedBox` vs. `Padding`) with different argument-shape preconditions, better kept as separate, independently testable rules.

---

## Decision

---

## Implementation Notes

---

## Commits
