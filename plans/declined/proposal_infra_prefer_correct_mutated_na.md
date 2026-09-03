# PROPOSAL: DCM `prefer-correct-mutated` — Declined, Requires a DCM-Specific Annotation Package

**Status: Declined**

Created: 2026-09-02
Type: Tooling / Infrastructure

---

## Summary

DCM's `prefer-correct-mutated` validates usage of DCM's own `@mutated` annotation (from the `dart_code_metrics`/DCM annotation package), which developers apply to a parameter to declare "this parameter is intentionally mutated by this function" — the rule then checks that the annotation is used correctly (e.g. the parameter really is mutated, or really isn't when unannotated). saropa_lints has no equivalent annotation or annotation-consuming framework, and introducing one would mean shipping a brand-new saropa-specific annotation package just to support a single rule — out of scope.

**Gap status:** DCM `prefer-correct-mutated` is classified N/A/Declined — see Decision section below for why this does not need implementation to be considered resolved.

---

## Motivation

`plans/GAP_ANALYSIS.md` lists `prefer-correct-mutated` under "DCM proper" TRUE GAPS, structural/code-quality group, already annotated "no `@mutated` annotation concept." Confirming: `@mutated` is a DCM package concept — it exists only because DCM ships a companion annotations package (`dart_code_metrics_annotations`-style) that projects must add as a dependency to use certain DCM rules. saropa_lints has no equivalent annotations package, and none of saropa's 2,383 existing rules depend on a project opting into a saropa-specific annotation.

Implementing `prefer-correct-mutated` faithfully would require:
1. Publishing a new saropa-specific annotations package (or adding annotation classes to the core `saropa_lints` package and requiring consumers to import them).
2. Getting downstream projects to actually adopt and apply the annotation across their mutated-parameter functions before the rule has anything to check.
3. Maintaining an annotation-consuming rule whose entire value depends on adoption of a bespoke annotation nobody currently uses.

This is a fundamentally different kind of investment than a normal AST-pattern rule — it's introducing a new public API surface and asking every consumer project to change their code to use it, not just adding a diagnostic that fires on existing code unmodified.

---

## Current Behavior

No equivalent exists. saropa_lints has no `@mutated`-style annotation and no rule consuming one.

---

## Desired Behavior

Out of scope. If saropa ever has independent reasons to ship a general saropa-specific annotations package (e.g. for other annotation-driven rules), `prefer-correct-mutated`-style validation could be revisited as one rule among several built on that shared package — but it should not be the rule that justifies creating the package.

---

## Alternatives Considered

- **Reuse an existing annotation from another package** (e.g. `meta`'s `@visibleForTesting`-style pattern) — rejected; no existing widely-used Dart package ships a `@mutated` parameter annotation with the semantics DCM's rule expects, so there's nothing to attach to without inventing one.
- **Detect "this parameter is mutated" purely structurally, without any annotation** (i.e. just flag in-place mutation of a parameter, annotation-free) — this is a *different*, simpler rule (arguably closer to "avoid mutating parameters" as a standalone check) and was not what DCM's `prefer-correct-mutated` does (it validates the annotation's correctness, not the mutation itself). Out of scope for this proposal; could be filed separately as its own rule idea if desired, without needing any new annotation package.

---

## Decision

**Declined.** `prefer-correct-mutated` depends on DCM's own `@mutated` annotation package, a DCM-specific concept saropa_lints has no equivalent for. Building the required annotation infrastructure is out of scope for a single rule — it would mean shipping a new public API and requiring consumer adoption before the rule has any value, a materially larger commitment than implementing a normal AST-pattern rule.

---

## Implementation Notes

None — no implementation planned.

---

## Commits
