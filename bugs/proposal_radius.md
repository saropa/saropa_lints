# PROPOSAL: Flag Inline Radius Literals Not Traced to a Design-System Token Source

**Status: Open**

Created: 2026-09-02
Type: New rule
Related rules: none (part of a broader "design-system token provenance" gap theme — sibling rules `edge_insets`, `box_shadow`, `theme_data`, `box_constraints`, `text_style` are separate proposals; do not duplicate them here)

---

## Summary

Add `radius` to flag a `Radius.circular(...)`, `BorderRadius.circular(...)`, or `BorderRadius.all(Radius.circular(...))` call in widget code whose numeric argument is a literal rather than a reference back to a static member of a project-designated design-system token class (marked with a project-defined `@designSystem` annotation). Unlike a "hardcoded wrong value" check, this rule flags every inline literal regardless of its numeric value — the point is provenance and traceability back to a single source of truth for design tokens, not correctness of any individual number.

**Closes gap:** design_system_lints `radius` (github.com/pattobrien/design_system_lints, Sidecar framework, defunct since 2022; ported here as a native AST rule). Implementing this proposal as specified fully closes this competitive gap — see `plans/GAP_ANALYSIS.md`.

---

## Motivation

Design systems typically define a small, fixed vocabulary of corner-radius values (e.g. `4`, `8`, `12`, `16` mapped to semantic names like `AppRadii.cardRadius`, `AppRadii.buttonRadius`) so that visual consistency is centrally controlled and themeable. Once a project has such a token class, every `BorderRadius.circular(12)` written inline in widget code is a missed opportunity: even if `12` happens to match the intended `cardRadius` value today, the connection back to the design system is invisible to both the reader and any future refactor — renaming or retheming `cardRadius` to `14` will not touch this call site, silently drifting it out of sync. This generalizes saropa's existing `avoid_hardcoded_colors` rule (which checks specifically against `Theme.of(context)` color tokens) to an arbitrary, project-annotated token source — any project convention marked `@designSystem`, not just Flutter's built-in `ThemeData`. The source package's mechanism (a `@designSystem`-annotated class as the canonical token source) is the harder, architecturally novel part of this proposal: it requires annotation-provenance tracing that saropa_lints does not currently have a general capability for.

---

## Detection / Behavior

Given a project class annotated `@designSystem` (e.g. `@designSystem class AppRadii { static const cardRadius = Radius.circular(12); }`), flag any `Radius.circular(...)`, `BorderRadius.circular(...)`, or `BorderRadius.all(Radius.circular(...))` expression in widget code whose argument is a numeric literal, UNLESS the entire expression is itself a reference to (or is constructed from) a static member of the `@designSystem`-annotated class.

### Should flag (bad code)

```dart
class ProductCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12), // LINT — inline radius literal, not traced to AppRadii
      ),
    );
  }
}
```

### Should pass (good code)

```dart
@designSystem
class AppRadii {
  static const cardRadius = Radius.circular(12); // canonical source
}

class ProductCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.all(AppRadii.cardRadius), // OK — traced to the design-system source
      ),
    );
  }
}
```

---

## Proposed Tier

Tier: Pedantic
Justification: Depends on a project explicitly adopting a `@designSystem`-annotated token class — an opt-in architectural convention, not a universal Flutter pattern. Even among projects with design systems, most centralize colors (`Theme.of(context)`, already covered by `avoid_hardcoded_colors`) well before centralizing radii; this is a deeper, more demanding discipline. Pedantic matches the rule's niche applicability and its reliance on unproven annotation-provenance infrastructure.

---

## Edge Cases

1. **`Radius.circular(0)` / `BorderRadius.zero`** — should pass; zero-radius (square corners) is a structural default, not a design token choice, and flagging it would be pure noise. `BorderRadius.zero` as a named constant should always pass regardless of design-system configuration.
2. **No `@designSystem`-annotated class exists in the project** — rule is a no-op; never flags anything without a configured token source.
3. **A radius literal used inside the `@designSystem`-annotated class itself** (the token definition line) — must not flag; this is the canonical source, not a consumer.
4. **A radius value derived via arithmetic from a token** (`AppRadii.cardRadius * 2`, or `Radius.circular(AppRadii.baseUnit * 3)`) — should pass if the *base* value traces to the token class, even though the final expression is not a direct reference; treat any expression whose leaf numeric identifiers all resolve to `@designSystem` members as traced.
5. **A radius value passed as a widget's constructor parameter from a caller who DID use the token, but the receiving widget itself just forwards a `double radius` parameter through to `BorderRadius.circular(radius)`** — should pass at the receiving widget (it has no visibility into caller provenance); this is a known precision boundary of the rule, not a bug — document it as an accepted false-negative in Edge Cases rather than attempting cross-widget-boundary provenance tracing.
6. **Multiple classes annotated `@designSystem` in the same project** (e.g. one per design variant/brand) — should treat references to static members of ANY `@designSystem`-annotated class as traced; flag only literals matching none of them.

---

## Alternatives Considered

- **Generalize immediately to a config-driven "any annotation name, any literal-producing static-const source" engine covering all of `edge_insets`/`box_shadow`/`theme_data`/`box_constraints`/`text_style`/`radius` at once** — rejected as the initial scope; building the annotation-provenance-tracing capability once and proving it out on the single narrowest case (`radius`, one primitive numeric argument) de-risks the harder general capability before committing to six rules built on the same untested mechanism. Sibling proposals should reference this rule's Implementation Notes once the provenance-tracing capability exists.
- **Match against a fixed value list instead of an annotated class** (project declares `allowed_radii: [4, 8, 12, 16]` in config, no class/annotation needed) — considered as a simpler fallback needing no new provenance-tracing capability, but rejected as the primary design; it collapses to a "magic number" check that loses the traceability benefit (a literal `12` matching the allow-list still can't be safely renamed/retheme in one place) that is the entire point of the source package's design. Could be offered as a lower-effort interim variant if annotation tracing proves too costly to build.

---

## Decision

---

## Implementation Notes

**Open implementation question:** saropa_lints does not currently have a general "trace this expression back to a member of an annotated class" capability. Building `radius` requires: (1) locating all classes annotated `@designSystem` in the current analysis context (single-project scope is likely sufficient — cross-package token sources are out of scope for v1); (2) resolving whether a given expression's element (for a `PrefixedIdentifier`/`PropertyAccess` like `AppRadii.cardRadius`) belongs to one of those classes; (3) handling the arithmetic-composition case (edge case 4) by recursively checking that all literal leaves of a numeric expression trace back to an annotated member, not just the outermost expression. This provenance-tracing capability, once built, is reusable by the sibling `edge_insets`/`box_shadow`/`theme_data`/`box_constraints`/`text_style` proposals — recommend building and validating it here first as the narrowest case before extending to the others.

---

## Commits
