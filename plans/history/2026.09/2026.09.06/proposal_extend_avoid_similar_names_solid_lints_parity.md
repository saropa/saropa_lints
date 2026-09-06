# PROPOSAL: New Rule for Confusable Identifier Names (solid_lints Parity — Distinct from Existing `avoid_similar_names`)

**Status: Open**

Created: 2026-09-02
Type: New rule
Related rules: `avoid_similar_names` (name collision only — different check, see below)

---

## Summary

Add a new rule, tentatively named `avoid_confusable_identifier_names`, to flag identifiers in the same scope whose names differ by only a character or two in a way that invites mix-ups at the use site — e.g. `userId` vs `usrId`, `data1`/`data2`, `item` vs `items`. This is solid_lints' `avoid_similar_names` behavior, but saropa_lints **already has a rule literally named `avoid_similar_names`** doing something unrelated (flagging enum-indexed `Map` literals missing enum values — see `lib/src/rules/code_quality/code_quality_avoid_rules.dart:2584`, `AvoidSimilarNamesRule`), so the solid_lints-equivalent behavior must ship under a different rule name to avoid a name collision with an already-published, differently-scoped rule.

**Closes gap:** solid_lints `avoid_similar_names` (github.com/solid-software/solid_lints). Implementing this proposal as specified fully closes this competitive gap — see `plans/GAP_ANALYSIS.md` `solid_lints` section, which explicitly notes: "two name-collision false-HAVEs reclassified to GAP after reading actual doc content: ... `avoid_similar_names` (same — saropa's same-named rule is actually about enum-indexed Map literals)."

---

## Motivation

Near-identical identifier names in the same scope are a well-documented source of copy-paste and typo bugs: a reviewer skimming `usrId` next to `userId` sees two names that look correct at a glance, and the wrong one being used compiles cleanly and often passes tests if both variables happen to hold plausible values. solid_lints ships this as a dedicated rule because it catches a distinct class of bug from saropa's existing `avoid_similar_names` (missing enum keys in a `Map` literal) — the two rules solve unrelated problems that happen to share a name in a different package's rule set. Closing this gap under the existing name would silently change the meaning of an already-published saropa_lints rule out from under any project that has `avoid_similar_names` enabled or explicitly configured today, which is a breaking behavior change disguised as a bug fix.

---

## Detection / Behavior

### Should flag (bad code)

```dart
void processOrder(String userId) {
  final String usrId = normalize(userId); // LINT — 'usrId' vs 'userId' differ by one character, invites confusion
  submit(usrId);
}

void handleBatch(List<Item> data1, List<Item> data2) { // LINT — non-descriptive, index-suffixed near-duplicates
  merge(data1, data2);
}
```

### Should pass (good code)

```dart
void processOrder(String rawUserId) {
  final String normalizedUserId = normalize(rawUserId); // OK — names are visually distinct and descriptive
  submit(normalizedUserId);
}

void handleBatch(List<Item> pendingItems, List<Item> processedItems) { // OK — distinct, descriptive names
  merge(pendingItems, processedItems);
}
```

---

## Proposed Tier

Tier: Comprehensive
Justification: Style/readability check with no correctness impact and real false-positive risk on legitimately similar short names (`x`/`y`, `from`/`to`) — matches where saropa places other "readability smell" rules rather than Essential/Recommended, and gives it a straightforward suppression path (`// ignore:`) if it fires on an intentionally-similar pair.

---

## Edge Cases

1. **Conventional short-name pairs** (`x`/`y`, `i`/`j`, `from`/`to`, `min`/`max`) — should pass; these are established idioms, not accidental near-duplicates. The existing `AvoidSimilarNamesRule._areTooSimilar` logic in `code_quality_avoid_rules.dart` already has a length-difference guard (`>2` chars skip) worth reusing/adapting, but needs an additional allowlist for common paired-name idioms to avoid noise this new rule would otherwise generate on nearly every loop.
2. **Parameters vs. local variables in different scopes** (e.g. a similarly-named local shadowing/echoing a field) — should flag only within the same lexical scope (same block/parameter list), consistent with solid_lints' stated scope and with how saropa's existing enum-Map rule already scopes to a single `Block`.
3. **Case-only differences** (`userId` vs `userID`) — should flag; this is the single most dangerous case since both compile and both read as "the same word" to a skimming reviewer.
4. **Generated code / records with positional-looking field names** (`$1`, `$2`) — should pass; not user-authored identifiers.

---

## Alternatives Considered

- **Rename the existing enum-Map rule and reuse `avoid_similar_names` for the solid_lints behavior** — rejected; renaming an existing, published rule is a breaking change for any project with `avoid_similar_names` in its `analysis_options_custom.yaml` overrides or baseline, and CLAUDE.md prohibits unrequested restructuring. Out of scope for a new-rule proposal.
- **Ship the solid_lints behavior as an extension of the existing `AvoidSimilarNamesRule` class (one rule, two detection modes)** — rejected; the two checks operate on entirely different AST shapes (enum-indexed `Map` literal completeness vs. identifier-pair edit-distance across a scope) and conflating them under one `LintCode` would produce a confusing, dual-purpose problem message that fails the ">200 chars, single clear issue" message requirement.
- **Name it `avoid_similar_variable_names`** (closer to the solid_lints name) — considered but `avoid_confusable_identifier_names` was preferred as the proposed name because it more precisely describes the failure mode (visual/character confusability, not merely "similarity") and doesn't invite the same near-miss confusion with the existing `avoid_similar_names` that a `avoid_similar_*` sibling name would.

---

## Decision

---

## Implementation Notes

Candidate home: `lib/src/rules/code_quality/code_quality_avoid_rules.dart`, adjacent to (but as a fully separate class from) `AvoidSimilarNamesRule` at line ~2584 — reuse its `_areTooSimilar`/`_VariableCollector` scaffolding as a starting point for the edit-distance/confusable-character comparison, but do not extend or modify `AvoidSimilarNamesRule` itself. Register the new rule name (`avoid_confusable_identifier_names`, or whichever final name is chosen) separately in `lib/saropa_lints.dart` `_allRuleFactories` and `lib/src/tiers.dart` — it must not collide with the existing `'avoid_similar_names'` tier-set entry.

---

## Commits
