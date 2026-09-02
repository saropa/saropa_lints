# PROPOSAL: Do Not Port `architecture_linter`'s Config-File-Error Diagnostic

**Status: Declined**

Created: 2026-09-02
Type: New rule
Related rules: none

---

## Summary

`architecture_linter`'s `architecture_linter_config_file_error` is emitted by the tool itself when its own
`architecture_linter.yaml` config file is missing, malformed, or unparsable. It is not a code-quality lint
against the analyzed project's Dart source — it is a diagnostic about the linter's own configuration state.

**Closes gap:** `architecture_linter` `architecture_linter_config_file_error` (github.com/Iteo/architecture_linter).
This gap is intentionally NOT closed — see Decision below.

---

## Motivation

n/a — declined before a motivation for adoption was developed.

---

## Detection / Behavior

n/a.

---

## Proposed Tier

n/a.

---

## Edge Cases

n/a.

---

## Alternatives Considered

- **Port as a saropa config-validation diagnostic** for saropa's own `analysis_options_custom.yaml` — rejected
  as out of scope for this proposal; saropa already has its own config-loading error handling and this is a
  1:1 tool-internals port request, not a code-quality rule request. If saropa's config loader needs better
  error surfacing, that is a separate engineering task tracked outside `bugs/proposal_*`.

---

## Decision

Declined. This is a tool self-diagnostic — it reports on `architecture_linter`'s own config file, not on the
Dart code being analyzed. It has no code-quality meaning to port: a saropa user's project either has valid
saropa config or it doesn't, and that is already saropa's own concern, not a lint rule against user code.
Per `plans/GAP_ANALYSIS.md` "architecture_linter" section, this is one of 3 meta-diagnostics correctly
excluded from HAVE/PARTIAL/GAP code-quality comparison.

---

## Implementation Notes

None — not implemented.

---

## Commits
