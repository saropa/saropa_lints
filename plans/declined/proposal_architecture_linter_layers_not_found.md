# PROPOSAL: Do Not Port `architecture_linter`'s Layers-Not-Found Diagnostic

**Status: Declined**

Created: 2026-09-02
Type: New rule
Related rules: none

---

## Summary

`architecture_linter`'s `architecture_linter_layers_not_found` fires when the tool's own
`architecture_linter.yaml` declares no `layers:` section (or an empty one) for it to enforce. It is a
diagnostic about the linter's own configuration completeness, not about a defect in the analyzed Dart code.

**Closes gap:** `architecture_linter` `architecture_linter_layers_not_found` (github.com/Iteo/architecture_linter).
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

- **Treat as a prerequisite check bundled with the `arch_*` config engine** (see
  `plans/tier_3_infrastructure/proposal_architecture_lints_enforcement_rules.md`) — considered, but that proposal's engine is
  no-op-by-default when unconfigured, so an explicit "you forgot to configure layers" nag is unnecessary
  noise rather than a defect signal; a project simply not using the feature is not an error state.

---

## Decision

Declined. This is a tool self-diagnostic about `architecture_linter`'s own config completeness, not a
code-quality rule against user Dart source. Per `plans/GAP_ANALYSIS.md` "architecture_linter" section, this
is one of 3 meta-diagnostics correctly excluded from HAVE/PARTIAL/GAP code-quality comparison.

---

## Implementation Notes

None — not implemented.

---

## Commits
