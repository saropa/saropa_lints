# PROPOSAL: Prefer `Gap()` Widget Over `SizedBox()` for Flex-Child Spacing

**Status: Open**

Created: 2026-09-02
Type: New rule
Related rules: `prefer_sized_box_for_whitespace`, `prefer_sized_box_square`

---

## Summary

Add `use_gap` to flag a bare `SizedBox(width: ...)`/`SizedBox(height: ...)` used purely as spacing between siblings inside a `Row`/`Column`/`Wrap`'s `children` list, and suggest the `gap` package's `Gap(...)` widget instead — `Gap` collapses adjacent spacers automatically and reads more explicitly as "spacing," not "a sized box that happens to have no child."

**Closes gap:** `many_lints` `use_gap`. Implementing this proposal as specified fully closes this competitive gap — see `plans/GAP_ANALYSIS.md` "Miscellaneous single-rule gaps" theme and the `many_lints` non-themed remaining-gaps list.

---

## Motivation

saropa already has `prefer_sized_box_for_whitespace` (Container → SizedBox) and `prefer_sized_box_square`, so the project clearly cares about spacing-widget hygiene — this rule is the next natural step for teams that have adopted the `gap` package. `Gap` widgets automatically collapse when adjacent to another `Gap` or at a flex boundary (avoiding accidental double-spacing when children are conditionally omitted), which a childless `SizedBox` cannot do.

---

## Detection / Behavior

Flag a `SizedBox(width: ..., child: null)` (no `child` argument, or `child` omitted) that appears directly as an element of a `Row`/`Column`/`Wrap`'s `children:` list, only when the project depends on the `gap` package (package-specific rule).

### Should flag (bad code)

```dart
Column(
  children: [
    const Text('Title'),
    const SizedBox(height: 12), // LINT — use Gap(12) for flex-child spacing
    const Text('Subtitle'),
  ],
);
```

### Should pass (good code)

```dart
Column(
  children: [
    const Text('Title'),
    const Gap(12), // OK
    const Text('Subtitle'),
  ],
);
```

---

## Proposed Tier

Tier: Comprehensive
Justification: Package-specific rule (`gap` dependency required) and a pure style preference — appropriate for Comprehensive per the package-specific-rule convention.

---

## Edge Cases

1. **`SizedBox` used for actual sizing (constrains an image/icon), not spacing** — should pass; only childless `SizedBox`es directly inside a flex `children:` list are in scope.
2. **`SizedBox.shrink()` used as a spacer** — should discuss; `SizedBox.shrink()` has different semantics (zero-size collapse) and may be an intentional no-op placeholder rather than spacing — likely exempt.
3. **`gap` package not a project dependency** — rule should no-op entirely.
4. **`SizedBox` inside `Wrap.children` where `Wrap` already has a `spacing`/`runSpacing` property configured** — should still flag; a manual spacer combined with `Wrap.spacing` is itself a double-spacing bug worth separate attention, but this rule's scope is the substitution suggestion regardless.

---

## Alternatives Considered

- **Auto-fix that rewrites `SizedBox` to `Gap` in place** — deferred to implementation; straightforward mechanical rewrite once the rule fires (drop `child:`, rename constructor, keep the single numeric argument), a good candidate for the initial quick fix.

---

## Decision

---

## Implementation Notes

---

## Commits
