# PROPOSAL: DCM `add-static-field` Is a Code Assist, Not a Lint Rule Candidate

**Status: Open**

Created: 2026-09-02
Type: Tooling / Infrastructure

---

## Summary

DCM's `add-static-field` is a **code assist** (an IDE-invoked action that auto-generates a `static` field declaration, e.g. from a usage site with no matching field) — not a lint diagnostic that fires on existing code. saropa_lints has no code-assist system (only diagnostics + quick fixes that fire *in response to* a diagnostic), so this is out of scope for a normal rule proposal. This file records it as a low-priority future infrastructure idea only.

**Gap status:** DCM `add-static-field` is classified N/A/Declined — see Decision section below for why this does not need implementation to be considered resolved.

---

## Motivation

`plans/GAP_ANALYSIS.md` lists `add-static-field` under the "DCM proper" TRUE GAPS as a structural/code-quality gap. Investigating it against DCM's own documentation shows it is categorized as an **assist**, not a rule: assists are proactive code-generation actions a developer invokes manually from the IDE lightbulb menu with no associated diagnostic, distinct from DCM's "rules" (which do fire diagnostics, comparable to saropa's `SaropaLintRule`) and DCM's "quick fixes" (which repair an existing diagnostic, comparable to saropa's `DartFix`).

saropa_lints' entire fix mechanism is diagnostic-driven: `DartFix` subclasses attach to an `AnalysisError` produced by a rule (`node.sourceRange.intersects(analysisError.sourceRange)`, per `CLAUDE.md`'s rule-authoring steps). There is no "no diagnostic, just offer a code-generation action" entry point in the current architecture (`saropa-lints-architecture-contract` skill covers the registration/reporter pipeline; no assist layer exists there).

---

## Current Behavior

No equivalent exists. A developer who wants to add a static field to a class must type it manually; saropa_lints offers no lightbulb-triggered "generate static field" assist.

---

## Desired Behavior

Out of scope for this proposal. If saropa_lints ever builds a general code-assist framework (a lightbulb-menu action system independent of diagnostics — e.g. via `analyzer_plugin`'s `EditGetAssists` protocol handler, which is a different extension point than the `EditGetFixes` handler quick fixes currently use), `add-static-field`-style assists could be revisited as one candidate feature among several DCM assists (`add-copy-with` is a sibling example in the same gap list, under "Flutter widget/a11y gaps").

---

## Motivation for Infrastructure Change

None proposed at this time — this file exists to document the investigation outcome (rule vs. assist classification) so a future contributor doesn't re-investigate `add-static-field` as a candidate lint rule and hit the same "this isn't a diagnostic" dead end.

---

## Decision

**Declined as a rule proposal — reclassified as infrastructure research only, low priority.** `add-static-field` cannot be implemented as a `SaropaLintRule` because it has no trigger diagnostic; it requires an assist-framework extension point saropa_lints does not have. Do not attempt to force this into the existing rule/fix architecture (e.g. by inventing a fake "field is missing" diagnostic just to hang a fix off it) — that would be a diagnostic that fires on correct code, violating the "fixes must respond to a real problem" principle in `CLAUDE.md`. Revisit only if/when a general assist framework is built for unrelated reasons.

---

## Implementation Notes

None — no implementation planned.

---

## Commits
