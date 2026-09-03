# PROPOSAL: Do Not Port `architecture_linter`'s Banned-Imports-Not-Found Diagnostic

**Status: Declined**

Created: 2026-09-02
Type: New rule
Related rules: `avoid_banned_imports` (saropa's existing banned-import proposal covers the actual
enforcement mechanism; this rule is only the tool's own config-completeness nag)

---

## Summary

`architecture_linter`'s `architecture_linter_banned_imports_not_found` fires when the tool's own
`architecture_linter.yaml` declares no `bannedImports:` section for it to enforce. It is a diagnostic about
the linter's own configuration completeness, not about a defect found in the analyzed Dart code.

**Closes gap:** `architecture_linter` `architecture_linter_banned_imports_not_found`
(github.com/Iteo/architecture_linter). This gap is intentionally NOT closed — see Decision below.

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

- **Bundle as a companion nag for saropa's `avoid_banned_imports`** — considered, but `avoid_banned_imports`
  is opt-in/config-gated like the rest of saropa's config-driven rules; a project not configuring it is not
  an error, it's the rule simply not being used. Nagging about an unused opt-in feature is noise, not signal.

---

## Decision

Declined. This is a tool self-diagnostic about `architecture_linter`'s own config completeness, not a
code-quality rule against user Dart source. Per `plans/GAP_ANALYSIS.md` "architecture_linter" section, this
is one of 3 meta-diagnostics correctly excluded from HAVE/PARTIAL/GAP code-quality comparison. The actual
enforcement mechanism (banning specific imports) is already tracked separately in
`bugs/tier_3_infrastructure/proposal_avoid_banned_imports.md`.

---

## Implementation Notes

None — not implemented.

---

## Commits
