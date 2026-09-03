# PROPOSAL: Flag Manual Reimplementation of Built-In Flutter Widgets

**Status: Open**

Created: 2026-09-02
Type: New rule
Related rules: none (no existing `saropa_lints` rule pattern-matches widget subtrees against known built-in widget shapes)

---

## Summary

Add a narrowly-scoped rule that flags a small, high-confidence set of manual reimplementations of built-in Flutter widgets — starting with a fixed-color, fixed-thickness `Container`/`SizedBox` used as a line divider (reimplementing `Divider`/`VerticalDivider`) and an empty fixed-size `SizedBox`/`Container` used purely for spacing between siblings in a `Column`/`Row` where `SizedBox(height: ...)`/`SizedBox(width: ...)` is already the idiomatic choice being circumvented by an unnecessarily heavier `Container`.

**Closes gap:** DCM `use-existing-widget` (dcm.dev). Implementing this proposal as specified fully closes this competitive gap — see `plans/GAP_ANALYSIS.md` "DCM proper" TRUE GAPS section.

---

## Motivation

Hand-rolling a `Container` with a fixed height and background color to act as a divider line, or using a `Container` purely for empty spacing where a `SizedBox` would do, is a recurring pattern in codebases that grew without close review — it produces heavier widgets (a `Container` carries `Decoration`, padding/margin, alignment, and constraint-resolution logic that `Divider`/`SizedBox` skip), loses the built-in widget's theme-awareness (`Divider` reads `DividerThemeData` for color/thickness/indent by default; a hand-rolled `Container` hardcodes a color that silently drifts from the app's theme when the design system changes), and adds unnecessary code for something the framework already provides as a one-line, well-tested primitive.

DCM (dcm.dev) ships `use-existing-widget` as a broad heuristic rule covering many built-in-widget reimplementation patterns. `saropa_lints` has no equivalent rule at any scope — this proposal deliberately narrows the initial implementation to the two highest-confidence, easiest-to-detect-precisely cases (divider-shaped `Container`, spacer-shaped `Container`) rather than attempting DCM's full breadth in one rule.

---

## Detection / Behavior

**Divider case:** flag a `Container`/`DecoratedBox` that is a direct child of a `Column` or `Row` (i.e. used as a widget-list item alongside siblings, not as a general-purpose layout box) where: the container has `decoration: BoxDecoration(color: ...)` (or a plain `color:` argument) AND exactly one of `height`/`width` is set to a value ≤ 4 logical pixels (the other dimension unset or `double.infinity`) AND no `child` is set — the classic "thin colored bar" divider shape.

**Spacer case:** flag a `Container` that is a direct child of a `Column`/`Row`, has no `child`, no `decoration`/`color`, no `padding`/`margin`/`alignment`/`constraints`, and only a `height` (in a `Column`) or `width` (in a `Row`) set — i.e. every argument the `Container` sets is one that `SizedBox` also supports, and none of the arguments unique to `Container` (decoration, padding, alignment) are used, meaning `SizedBox` is a strictly equivalent, lighter replacement.

### Should flag (bad code)

```dart
Column(
  children: [
    const Text('Section A'),
    Container(height: 1, color: Colors.grey), // LINT — reimplements Divider
    const Text('Section B'),
    Container(height: 16), // LINT — reimplements SizedBox(height: 16)
    const Text('Section C'),
  ],
)
```

### Should pass (good code)

```dart
Column(
  children: [
    const Text('Section A'),
    const Divider(height: 1, color: Colors.grey), // OK — built-in, theme-aware
    const Text('Section B'),
    const SizedBox(height: 16), // OK — idiomatic spacer
    const Text('Section C'),
  ],
)

// Not flagged: this Container carries padding + a border, which SizedBox
// and Divider cannot express — it is not a reimplementation, it is a
// genuinely custom decorated box.
Container(
  height: 40,
  padding: const EdgeInsets.symmetric(horizontal: 8),
  decoration: BoxDecoration(border: Border.all(color: Colors.grey)),
  child: const Text('Custom banner'),
)
```

---

## Proposed Tier

Tier: Pedantic
Justification: the detection is intentionally heuristic and shape-based (a `Container` matching a specific argument fingerprint), not a semantic guarantee that the developer's intent was "reimplement a built-in widget" — there is a real, if narrow, risk of a false positive on a `Container` that happens to match the shape today but is expected to grow a `decoration`/`child` soon. Pedantic keeps this available for teams doing deep code-quality passes without imposing a heuristic-shape match on the default tiers. Both sub-checks should ship together but may be split into separate rules later if one proves substantially higher-confidence than the other.

---

## Edge Cases

1. **`Container` with only `color:` and no size at all** (fills available space with a solid color, used as a background panel, not a divider or spacer) — should pass; the divider-shape check specifically requires a thin (≤4px) fixed dimension, and the spacer-shape check requires no `color`/`decoration` at all, so a plain full-size colored `Container` matches neither fingerprint.
2. **`Container` inside a `Stack` or as a `GridView` item** — out of scope; both sub-checks require the `Container` be a direct child of `Column`/`Row`, since the divider/spacer-between-siblings interpretation only makes sense in a linear layout.
3. **Animated/conditional height** (`Container(height: isCompact ? 1 : 8, color: Colors.grey)`) — the divider-shape check should only match a `height`/`width` argument that is a compile-time-constant literal ≤ 4; a computed/conditional expression should not be evaluated and should pass, since the rule cannot safely assert the reimplementation shape without knowing the runtime value.
4. **Broader "use existing widget" cases from DCM's full scope** (e.g. hand-rolled `AspectRatio`, `Center`, `Padding` reimplementations via raw `Align`/positioning math) — explicitly out of scope for this proposal; DCM's rule is a broad heuristic family and detecting it well requires per-widget-shape fingerprints built up incrementally. This proposal is scoped to the two highest-confidence cases (`Divider`, `SizedBox`) as a first slice; expanding to more built-in widgets (`Spacer`, `AspectRatio`) should be follow-up proposals once this narrower rule's false-positive rate is measured in real codebases.

---

## Alternatives Considered

- **Implement DCM's full breadth in one rule from the start** — rejected; `use-existing-widget` is explicitly the broadest, most heuristic rule in the DCM gap list, and attempting full parity in one PR risks either shipping a high-false-positive rule or silently under-detecting most of DCM's actual coverage while claiming full parity. Shipping the two highest-confidence shapes first, then expanding based on measured accuracy, is safer for a rule class this heuristic.
- **Detect via widget subtree diffing against a "canonical `Divider`/`SizedBox` render output" rather than argument-shape fingerprinting** — infeasible at the AST/static-analysis level without running the widget tree; argument-shape fingerprinting is the only feasible static approach and is what DCM itself uses.

---

## Decision

---

## Implementation Notes

---

## Commits
