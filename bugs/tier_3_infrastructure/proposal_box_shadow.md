# PROPOSAL: Flag Hardcoded `BoxShadow` Literals Instead of Design-System Elevation Tokens

**Status: Open**

Created: 2026-09-02
Type: New rule
Related rules: `avoid_hardcoded_colors` (same design-token-bypass pattern, applied to color), `proposal_box_constraints` (same design-token family, proposed in this same batch — see that file for the dimensional-constraint counterpart)

---

## Summary

Add `avoid_hardcoded_box_shadows` to flag `BoxShadow(...)` literals built from magic blur/spread/offset/color values instead of referencing named design-system elevation/shadow tokens.

**Closes gap:** design_system_lints `box-shadow` (pub.dev). Implementing this proposal as specified fully closes this competitive gap — see `plans/GAP_ANALYSIS.md`.

---

## Motivation

Shadow styling is one of the most visually inconsistent areas of a hand-rolled Flutter UI precisely because `BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 2))` "looks right" in isolation on every card, dialog, and floating button where a developer pastes it — but four slightly different `blurRadius`/`offset` combinations scattered across a codebase read as visually inconsistent elevation once placed side by side, and there is no single place to fix them when the design language's elevation scale changes. This is the same underlying defect the project's own `CLAUDE.md` already calls out for color ("raw hex where a token exists is a defect") and that `avoid_hardcoded_colors` already enforces for `Color`/`Colors.*` literals (`lib/src/rules/architecture/structure_rules.dart`, line ~2313) — `BoxShadow` bundles a color value with three more magic numbers (`blurRadius`, `spreadRadius`, `offset`), making it a strictly larger surface for the same class of drift. Material Design's own elevation system is defined as a small fixed set of named levels for exactly this reason: shadow values are a design decision, not a per-widget improvisation.

---

## Detection / Behavior

### Should flag (bad code)

```dart
Container(
  decoration: BoxDecoration(
    boxShadow: [
      BoxShadow(
        color: Colors.black26, // LINT — hardcoded color inside BoxShadow
        blurRadius: 8, // LINT — magic blur value, no elevation token
        offset: const Offset(0, 2), // LINT — magic offset value
      ),
    ],
  ),
)
```

### Should pass (good code)

```dart
Container(
  decoration: BoxDecoration(
    boxShadow: AppElevation.level2, // OK — named design-system elevation token
  ),
)
```

---

## Proposed Tier

Tier: Comprehensive
Justification: Design-system-token enforcement is inherently project-specific and only meaningful once a project has an elevation/shadow token system to point to — same reasoning as its sibling `avoid_hardcoded_box_constraints`. Not suitable for Essential/Recommended, where most projects (including those without a formal design system yet) would trip it unproductively.

---

## Edge Cases

1. **`BoxShadow()` with all-default arguments** (a no-op shadow — invisible, since default `blurRadius`/`spreadRadius`/`offset` render nothing meaningfully visible against a fully transparent default color) — should flag as a distinct, higher-confidence case: an all-default `BoxShadow()` is either dead code or a placeholder, similar to the zero-width `Border.all(width: 0)` case in the companion `border_all` proposal; correction message should suggest removing the entry rather than pointing at a token.
2. **`Colors.transparent` shadow color used deliberately to reserve layout space** (a known pattern for keeping widget bounds stable while visually hiding the shadow) — should pass on the color-literal check specifically, since `Colors.transparent` is a semantic sentinel like `double.infinity`, but the numeric `blurRadius`/`offset` literals in the same `BoxShadow` are still in scope for flagging.
3. **`BoxShadow` values sourced from `Theme.of(context).shadowColor` or an existing named elevation constant** — should pass; the rule only flags numeric/`Color(...)`/`Colors.*` literals, not references to theme or named constants.
4. **Third-party widget wrappers that require a raw `BoxShadow` argument with no way to pass a token type** (e.g. an external package's API expects `List<BoxShadow>` and the project's elevation tokens aren't typed as `BoxShadow`) — false positive risk; acceptable, matches how `avoid_hardcoded_colors` already handles third-party API boundaries — `// ignore:` with a one-line rationale is the documented escape hatch.
5. **Generated code (`.g.dart`, `.freezed.dart`) and test/fixture files under `example*/`** — should pass; standard generated-file and example-directory suppression applies.

---

## Alternatives Considered

- **Only flag the `color` argument, reusing `avoid_hardcoded_colors`'s logic unchanged, and leave blur/spread/offset alone** — rejected; the color-only subset would miss the more common real-world inconsistency (mismatched blur/offset across cards using the *same* nominal color), which is the specific gap this rule closes beyond what `avoid_hardcoded_colors` already covers via its existing `Color`/`Colors.*` detection elsewhere in the codebase.
- **Merge with `avoid_hardcoded_box_constraints` into one "avoid raw design values" rule** — rejected for the same reason given in that proposal's Alternatives Considered: `BoxShadow` and `BoxConstraints` have unrelated correction messages (elevation tokens vs. sizing tokens) and different constructors to inspect; a shared rule would blur both messages.

---

## Decision

---

## Implementation Notes

Candidate home: new addition near `AvoidHardcodedColorsRule` in `lib/src/rules/architecture/structure_rules.dart`, or alongside the sibling `avoid_hardcoded_box_constraints` in `lib/src/rules/widget/widget_layout_constraints_rules.dart` — either is defensible; prefer co-locating with `avoid_hardcoded_box_constraints` since both are part of the same design-token gap-closing batch and share the "numeric literal inside a styling constructor" detection shape. Reuse `AvoidHardcodedColorsRule`'s `Color`/`Colors.*` literal matcher for the `color:` argument, and add a parallel numeric-literal check for `blurRadius`/`spreadRadius`/`offset`.

---

## Commits
