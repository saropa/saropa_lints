# PROPOSAL: Flag Hardcoded Spacing/Sizing Literals Where a Design-System Token Exists

**Status: Open**

Created: 2026-09-02
Type: New rule
Related rules: `avoid_hardcoded_colors`, `use_design_system_item` (proposed)

---

## Summary

Add `use_design_system` to flag numeric spacing/sizing literals (`EdgeInsets.all(16)`, `SizedBox(height: 24)`, `BorderRadius.circular(8)`) where the project has declared a design-system spacing/radius token scale, and suggest the matching named token instead of the raw number.

**Closes gap:** `dart_code_linter` `use-design-system`. Implementing this proposal as specified fully closes this competitive gap — see `plans/GAP_ANALYSIS.md` Gap Theme 8 "Design-system token provenance" (the `edge_insets`/`radius`/`box_constraints` cluster).

---

## Motivation

saropa's `avoid_hardcoded_colors` proves the value of catching design-token drift for colors; the exact same drift happens with spacing and radius values, arguably more often, since developers reach for a raw pixel number ("that looks about right") far more casually than a raw hex color. Without this rule, a project's `AppSpacing.md` (8/16/24/32 scale) is unenforced — nothing stops `SizedBox(height: 17)` from creeping in next to the intended `SizedBox(height: AppSpacing.md)`.

---

## Detection / Behavior

Config declares a token scale as `{value: name}` pairs (e.g. `{8: 'AppSpacing.sm', 16: 'AppSpacing.md'}`). Flag a numeric literal argument to a configured set of spacing/sizing APIs (`EdgeInsets.all/only/symmetric`, `SizedBox`, `BorderRadius.circular`, `Gap`) whose value exactly matches a configured token value.

### Should flag (bad code)

```dart
const SizedBox(height: 16); // LINT — matches AppSpacing.md; use the token instead
```

### Should pass (good code)

```dart
const SizedBox(height: AppSpacing.md); // OK — uses the design-system token

const SizedBox(height: 17); // OK — not a value in the configured token scale, not this rule's concern
```

---

## Proposed Tier

Tier: Comprehensive
Justification: Opt-in, config-driven — requires a project to define its token scale before it fires, so it is inert (and safe) by default.

---

## Edge Cases

1. **No token scale configured** — should no-op entirely.
2. **A literal that coincidentally matches a token value but is semantically unrelated to spacing (e.g. a loop bound of `16`)** — the rule is scoped to arguments of the configured spacing/sizing APIs only, so this should not fire; verify the API allowlist is tight enough to avoid stray numeric coincidences elsewhere.
3. **Computed spacing (`AppSpacing.md * 2`)** — should pass; only literal numeric arguments are in scope, not expressions already referencing a token.
4. **`SizedBox.square(dimension: 16)`** — should flag identically to `width`/`height`, same token-matching logic.

---

## Alternatives Considered

- **Merge with the proposed `theme_data` rule into one "design-system token provenance" mega-rule** — rejected; `theme_data` is about object-level `ThemeData` duplication while this rule is about individual numeric-literal substitution — different AST shapes and different fix strategies (delete a Theme wrapper vs. replace one argument).

---

## Decision

---

## Implementation Notes

---

## Commits
