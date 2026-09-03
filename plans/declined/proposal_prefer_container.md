# PROPOSAL: Declined — `prefer_container` Already Implemented

**Status: Declined (already covered)**

Created: 2026-09-02
Type: New rule (declined — duplicate)
Related rules: `PreferContainerRule` (`lib/src/rules/widget/build_method_rules.dart`)

---

## Summary

awesome_lints, many_lints, and flutter_skill_lints all independently ship a `prefer_container` rule (collapse 3+ nested single-purpose widgets — `Padding`/`Align`/`ColoredBox`/`DecoratedBox`/etc. — into one `Container`). saropa_lints already implements this as `PreferContainerRule` in `lib/src/rules/widget/build_method_rules.dart`.

**Closes gap:** awesome_lints / many_lints / flutter_skill_lints `prefer_container` (Gap Theme 14, triple-repeated across three packages). Already closed — no action required. See `plans/GAP_ANALYSIS.md`.

---

## Motivation

Not applicable — this is a confirmation that no gap exists, not a new-rule proposal.

---

## Detection / Behavior

Not applicable — see `PreferContainerRule` for current implementation behavior.

---

## Proposed Tier

Not applicable.

---

## Edge Cases

Not applicable.

---

## Alternatives Considered

Not applicable.

---

## Decision

Declined as a distinct proposal — already implemented as `PreferContainerRule`. This file exists only to close out the gap-analysis line item and prevent duplicate future proposals for the same rule id across the three source packages that raised it.

---

## Implementation Notes

None — no code change. If a future audit finds `PreferContainerRule`'s detection narrower than one of the three upstream implementations (e.g. missing a specific collapsible-widget type), file that as a targeted enhancement bug against the existing rule, not a new proposal.

---

## Commits
