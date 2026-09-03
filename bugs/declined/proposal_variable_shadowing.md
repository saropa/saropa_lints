# PROPOSAL: `variable_shadowing` — Already Closed by `avoid_variable_shadowing`

**Status: Closed (no action needed)**

Created: 2026-09-02
Type: Gap-analysis correction
Related rules: `avoid_variable_shadowing` (existing)

---

## Summary

`essential_lints`' `variable_shadowing` names the same detection as saropa's existing `avoid_variable_shadowing` rule (`lib/src/rules/core/class_constructor_rules.dart:418`, DartDoc-documented `Alias: avoid_shadowing`) — flagging any declaration that shadows a declaration from an enclosing scope. No new rule is needed; this file exists only to record that the gap-analysis entry is a name-collision false gap, not a real one.

**Closes gap:** `essential_lints` `variable_shadowing` (source list under `plans/GAP_ANALYSIS.md` line ~972). Already fully closed by the existing `avoid_variable_shadowing` rule — no implementation required.

---

## Motivation

`GAP_ANALYSIS.md` lists `variable_shadowing` as a gap in the same line as `standard_comment_style`, `subtype_annotating`, `subtype_naming` — a batch of `essential_lints` names that were not individually cross-checked against saropa's existing rule set at the time the gap list was compiled. On inspection, saropa's `avoid_variable_shadowing` already flags exactly this pattern (general declaration-shadows-enclosing-scope, `severity: INFO`), so this is the same false-gap class the doc itself calls out elsewhere for `avoid_returning_widgets`/`avoid_similar_names` — a same-named-rule collision, just resolved the opposite direction (this one IS actually covered).

---

## Detection / Behavior

N/A — no new detection logic proposed. Existing `avoid_variable_shadowing` behavior stands.

### Should flag (bad code)

```dart
int total = 0;

void process() {
  int total = 10; // Already flagged by existing avoid_variable_shadowing
}
```

### Should pass (good code)

```dart
int total = 0;

void process() {
  int runningTotal = 10; // OK — distinct name, no shadowing
}
```

---

## Proposed Tier

Tier: N/A — no new rule.
Justification: Existing rule (`avoid_variable_shadowing`) already covers this at its current tier placement.

---

## Edge Cases

N/A.

---

## Alternatives Considered

N/A.

---

## Decision

Recommend marking this entry in `plans/GAP_ANALYSIS.md` as HAVE (via `avoid_variable_shadowing`) rather than GAP, on the next pass over the `essential_lints` source list.

---

## Implementation Notes

---

## Commits
