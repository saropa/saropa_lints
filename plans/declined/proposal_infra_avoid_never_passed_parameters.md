# PROPOSAL: DCM `avoid-never-passed-parameters` Requires Whole-Program Call-Site Analysis

**Status: Declined**

Created: 2026-09-02
Type: Tooling / Infrastructure

---

## Summary

DCM's `avoid-never-passed-parameters` flags a function/method parameter that no caller anywhere in the project ever supplies a non-default argument for — i.e. it is effectively dead because every call site relies on the default value. Detecting this correctly requires enumerating **every call site of every function across the whole program**, which is architecturally different from saropa_lints' current per-file AST rule model (a single-file visitor pass with no persistent cross-file call graph). This file records it as a research/infrastructure item, not a simple new rule.

**Gap status:** DCM `avoid-never-passed-parameters` is classified N/A/Declined — see Decision section below for why this does not need implementation to be considered resolved.

---

## Motivation

`plans/GAP_ANALYSIS.md` lists `avoid-never-passed-parameters` under "DCM proper" TRUE GAPS, structural/code-quality group, annotated "no cross-file call-site analysis." Confirming: a per-file `SaropaLintRule` visitor sees one file's AST at a time. To determine that parameter `p` of function `f` is "never passed," the rule would need to:

1. Locate every `MethodInvocation`/`FunctionExpressionInvocation` of `f` across the entire project (not just the current file).
2. Resolve each call's argument list against `f`'s parameter list, accounting for positional/named parameters, `Function.apply`, tear-offs, and dynamic dispatch through interfaces.
3. Aggregate across all call sites to conclude "in zero of them was `p` supplied."

This is the same category of whole-program analysis flagged as out of scope for a per-file rule in the codebase's own evaluation criteria (`bugs/ISSUE_REPORT_GUIDE.md`: "Is the detection feasible at the AST level, or does it require whole-program analysis?").

---

## Current Behavior

No equivalent exists. No cross-file call-graph infrastructure currently tracks "which parameters are ever supplied at any call site."

---

## Desired Behavior

Out of scope for a straightforward rule proposal. A future version could be feasible if/when saropa_lints builds general call-graph infrastructure (already partially present for cross-file checks like unused-file detection — see `ProjectContext` and `saropa-lints-diagnostics-and-tooling`), but even then this specific check carries a distinct false-positive risk: **public API parameters** (exported class methods, package-public functions) can legitimately be passed by *downstream consumers outside the analyzed project*, which a project-local call graph cannot see. Flagging those would be a false positive against library authors' intentionally-unused-so-far extension points. Any future implementation would need to exclude public API surfaces (or require an explicit opt-in for library-internal-only code) to avoid this.

---

## Motivation for Infrastructure Change

Recorded as a research/infra candidate only. Building a project-wide call graph is a meaningfully larger investment than a typical new rule (comparable in scope to the existing cross-file unused-file/circular-dependency tooling) and should be evaluated against other roadmap priorities before committing, not queued as a routine "add a rule" task.

---

## Decision

**Declined as a rule proposal — reclassified as infrastructure research only.** Requires whole-program call-site analysis architecturally distinct from saropa's per-file rule model, plus a nontrivial public-API false-positive risk that has no clean per-file mitigation. Revisit only alongside a broader call-graph infrastructure investment, and scope any future implementation to library-internal (non-exported) declarations only.

---

## Implementation Notes

None — no implementation planned at this time.

---

## Commits
