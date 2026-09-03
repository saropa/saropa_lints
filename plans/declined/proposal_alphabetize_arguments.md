# PROPOSAL: Alphabetize Named Arguments in Call Sites

**Status: Declined**

Created: 2026-09-02
Type: New rule (philosophical conflict)
Related rules: `none`

---

## Summary

`essential_lints` ships `alphabetize_arguments`, requiring named arguments at a call site to appear in alphabetical order. saropa_lints declines to adopt this rule: it conflicts with saropa's existing argument-ordering conventions, which favor grouping arguments by semantic relevance (required-first, then logically related groups, e.g. `key`/`child` last for widget constructors) over pure alphabetical sort.

**Closes gap:** `essential_lints` `alphabetize_arguments` (pub.dev). This gap is intentionally NOT closed — see Decision below.

---

## Motivation

Alphabetical argument ordering optimizes for "can I find this argument by scanning A-Z" at the cost of "does the call site read as a coherent sentence." saropa_lints' existing style (and Flutter/Dart community convention generally) keeps `key:` and `child:`/`children:` last regardless of alphabet, and groups semantically related named arguments together (e.g. `width:`/`height:` adjacent, not split alphabetically by `color:`). Enforcing alphabetical order would fight this convention on every widget constructor call in the codebase and in every fixture/example file already checked in.

---

## Detection / Behavior

Not implemented — rule declined.

---

## Proposed Tier

N/A — declined.

---

## Edge Cases

N/A — declined.

---

## Alternatives Considered

- **Adopt alphabetical ordering only for non-widget function calls** (plain Dart functions/constructors, excluding Flutter widget constructors) — considered but rejected; still conflicts with saropa's "required args first, `key`/`child` last" convention used across all constructors, not just widgets, and would require a widget-detection carve-out that adds maintenance cost for a rule the team does not want enforced anywhere.

---

## Decision

Declined. saropa_lints' existing named-argument ordering convention (semantic grouping, `key`/`child` last) is deliberate and predates this proposal; alphabetical ordering is the opposite convention and would require a large, low-value rewrite of existing call sites with no readability benefit under saropa's own style. See `feedback_understand_before_questioning_architecture.md` — the existing convention is intentional, not an oversight.

---

## Implementation Notes

N/A — declined.

---

## Commits
