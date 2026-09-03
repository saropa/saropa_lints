# PROPOSAL: Kebab-Case File Naming — DECLINED

**Status: Declined**

Created: 2026-09-02
Type: New rule
Related rules: none

---

## Summary

`jsdaddy_custom_lints` ships `file_naming_kebab_case`, requiring hyphen-separated filenames (`my-widget.dart`). This directly conflicts with Dart's own official `snake_case` file-naming convention (`my_widget.dart`), which saropa already enforces and which every Dart tool (`dart create`, `dart fix`, pub.dev conventions, the Dart Style Guide) assumes.

**Closes gap:** `jsdaddy_custom_lints` `file_naming_kebab_case`. This proposal documents the gap as reviewed and DECLINED — see `plans/GAP_ANALYSIS.md` "jsdaddy_custom_lints" gaps section, which flags it as "a deliberate house-style choice, not a broadly applicable one."

---

## Motivation

N/A — not being implemented. Documented for completeness of gap-analysis tracking so it isn't repeatedly re-surfaced as an open gap.

---

## Detection / Behavior

N/A.

---

## Proposed Tier

N/A — declined.

---

## Edge Cases

N/A.

---

## Alternatives Considered

- **Implement as an opt-in stylistic rule for teams that prefer kebab-case** — rejected; adopting it would put saropa in the position of actively contradicting the Dart language team's own style guide and every generator/tool in the ecosystem that assumes `snake_case`. A lint tool should not ship a rule that fights the platform's own convention, even opt-in.

---

## Decision

Declined. Conflicts with Dart's official `snake_case` file-naming convention; not implementing.

---

## Implementation Notes

N/A.

---

## Commits
