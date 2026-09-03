# PROPOSAL: Declined — `prefer_async_callback` Conflicts with Saropa's Existing Position

**Status: Declined**

Created: 2026-09-02
Type: New rule (declined)
Related rules: `prefer_future_void_function_over_async_callback`

---

## Summary

awesome_lints ships `prefer_async_callback`, which recommends Flutter's `AsyncCallback` typedef (`Future<void> Function()`) over spelling out the function type explicitly. saropa_lints already ships the opposite rule, `prefer_future_void_function_over_async_callback`, which recommends spelling out `Future<void> Function()` explicitly instead of using the `AsyncCallback` typedef.

**Closes gap:** awesome_lints `prefer_async_callback`. This is a philosophical conflict, not an absence — see `plans/GAP_ANALYSIS.md` awesome_lints Gaps section.

---

## Motivation

Both positions are defensible style choices with no correctness difference — `AsyncCallback` is a convenience typedef that is exactly `Future<void> Function()`, so the two are interchangeable at the type level. saropa's existing rule reflects a deliberate house-style decision to prefer the explicit function-type signature (self-documenting at every call site, no need to know the Flutter-specific typedef, works identically in pure-Dart code that doesn't import `flutter/foundation.dart`).

Shipping `prefer_async_callback` alongside `prefer_future_void_function_over_async_callback` would mean saropa recommends two contradictory fixes for the same code shape, which is incoherent and would confuse users who enable both rules in the same tier.

---

## Detection / Behavior

Not applicable — declined.

---

## Proposed Tier

Not applicable — declined.

---

## Edge Cases

Not applicable — declined.

---

## Alternatives Considered

- **Ship both rules as mutually exclusive, letting the user pick one** — rejected. saropa's tier system does not currently support "pick exactly one of N rules" grouping, and maintaining two rules that actively fight each other adds cost with no reader benefit; a user who wants the `AsyncCallback` convention can simply disable saropa's existing rule via `analysis_options_custom.yaml` severity override, which is the standard mechanism for opting out of a house-style preference.
- **Replace saropa's existing rule with awesome_lints' position** — rejected without a maintainer-level style reversal; out of scope for this proposal.

---

## Decision

Declined. saropa_lints already takes the opposite, deliberate position via `prefer_future_void_function_over_async_callback`. No new rule.

---

## Implementation Notes

None — no code change.

---

## Commits
