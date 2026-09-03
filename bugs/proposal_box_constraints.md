# PROPOSAL: Flag Hardcoded `BoxConstraints` Literals Instead of Design-System Tokens

**Status: Open**

Created: 2026-09-02
Type: New rule
Related rules: `avoid_hardcoded_colors` (same design-token-bypass pattern, applied to color instead of dimension values), `proposal_box_shadow` (same design-token family, proposed in this same batch — see that file for the elevation/shadow counterpart)

---

## Summary

Add `avoid_hardcoded_box_constraints` to flag `BoxConstraints(...)` literals built from magic numbers (`BoxConstraints(minWidth: 320, maxHeight: 480)`) in widget code, instead of referencing named design-system constants/tokens for min/max width/height constraints.

**Closes gap:** design_system_lints `box-constraints` (pub.dev). Implementing this proposal as specified fully closes this competitive gap — see `plans/GAP_ANALYSIS.md`.

---

## Motivation

The project's own `CLAUDE.md` states the exact principle this rule enforces: "Use the design system — raw hex where a token exists is a defect." `saropa_lints` already applies that principle to color via `avoid_hardcoded_colors` (`lib/src/rules/architecture/structure_rules.dart`, line ~2313), which flags color literals that bypass `Theme.of(context).colorScheme`. Dimensional constraints suffer the identical problem: a `BoxConstraints(maxWidth: 600)` scattered across a dozen widgets is a duplicated magic number with no discoverable name, and when the design system's breakpoint or minimum-tap-target value changes, every hardcoded occurrence must be found and edited individually instead of updating one token. Unlike color (which degrades visibly under dark mode if hardcoded), constraint magic numbers degrade silently — they simply drift out of sync with the rest of the app's spacing/sizing scale over time, producing inconsistent card widths, dialog sizes, and touch targets that no single design review catches because each hardcoded value looks locally reasonable.

---

## Detection / Behavior

### Should flag (bad code)

```dart
ConstrainedBox(
  constraints: const BoxConstraints(
    maxWidth: 600, // LINT — magic number, no design-system token
    minHeight: 48,
  ),
  child: form,
)
```

### Should pass (good code)

```dart
ConstrainedBox(
  constraints: const BoxConstraints(
    maxWidth: AppBreakpoints.dialogMaxWidth, // OK — named design-system token
    minHeight: AppSizes.minTapTarget,
  ),
  child: form,
)
```

---

## Proposed Tier

Tier: Comprehensive
Justification: Design-system-token enforcement is inherently project-specific — it depends on the project actually having a token/constants system to reference, so it cannot be a universal Essential/Recommended check. Matches saropa's placement for other design-token-bypass rules; teams without an established design-token layer would find this rule perpetually noisy at a lower tier.

---

## Edge Cases

1. **`BoxConstraints.tight(Size(...))` / `.expand()` / `.loose(...)` factory constructors with no magic numbers** (e.g. `BoxConstraints.expand()`) — should pass; only the numeric-literal-bearing named constructor form is in scope.
2. **`double.infinity` as a constraint value** — should pass; `double.infinity` is a semantic sentinel ("unbounded"), not a magic design value, and is already the idiomatic way to express "no limit."
3. **A single `0` or `0.0` literal** (e.g. `BoxConstraints(minWidth: 0)`) — should pass; zero is the natural/default lower bound, not a design decision requiring a named token.
4. **Constant defined once and reused, but as a raw local `const` rather than a project-wide design-system class** (e.g. `const _kCardWidth = 600;` at the top of the file, then `BoxConstraints(maxWidth: _kCardWidth)`) — needs discussion; this is better than an inline literal (single source of truth within the file) but still bypasses the *shared* design system. Default to flagging the original inline-literal form only, and treat file-local named constants as a lesser but acceptable pattern (do not require every constraint value to reach all the way to a global token) to avoid being overly strict on small/leaf widgets.
5. **Generated code (`.g.dart`, `.freezed.dart`) and test/fixture files under `example*/`** — should pass; standard generated-file and example-directory suppression applies.

---

## Alternatives Considered

- **Detect via a configurable allowlist of "known design-system class names"** (e.g. only flag when the project has a detectable `AppSizes`/`DesignTokens` class and the literal doesn't reference it) — considered as the more precise approach but deferred for the initial version in favor of the simpler "any numeric literal in a `BoxConstraints(...)` constructor is flagged, named-constant references are not" heuristic, matching how `avoid_hardcoded_colors` already operates (flagging `Color(0x...)`/`Colors.*` literals rather than requiring knowledge of the project's specific theme class names).
- **Fold this into a single, broader "avoid magic numbers in widget properties" rule** covering `BoxConstraints`, `EdgeInsets`, `BorderRadius`, etc. all at once — rejected; each of these already has (or, per this batch, will have) its own targeted rule with its own correction message and edge cases, and a single mega-rule would blur those distinct messages and make individual opt-out per construct impossible.

---

## Decision

---

## Implementation Notes

Candidate home: `lib/src/rules/widget/widget_layout_constraints_rules.dart` (the file already houses the sibling `avoid_border_all` and future constraint-related rules such as `AvoidUnboundedConstraintsRule`) — reuse `AvoidHardcodedColorsRule`'s literal-vs-named-reference detection pattern (`lib/src/rules/architecture/structure_rules.dart`, line ~2342 onward) adapted from `Color`/`Colors.*` expressions to numeric literals inside `BoxConstraints(...)` named-argument lists, with the zero/`double.infinity` exclusions from Edge Cases 2-3 applied before reporting.

---

## Commits
