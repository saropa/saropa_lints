# PROPOSAL: Extend `avoid_keywords_in_wildcard_pattern` to a General Wildcard-Misuse Check

**Status: Open**

Created: 2026-09-02
Type: New rule
Related rules: `avoid_keywords_in_wildcard_pattern`

---

## Summary

Extend `avoid_keywords_in_wildcard_pattern` beyond its current keyword-only check to also flag wildcard (`_`) pattern bindings used where the discarded value is subsequently needed or where a named binding would materially improve readability, matching DCM's broader `avoid-misused-wildcard-pattern`.

**Closes gap:** DCM `avoid-misused-wildcard-pattern` (dcm.dev) — currently PARTIAL via saropa's `avoid_keywords_in_wildcard_pattern`. Implementing this proposal as specified fully closes this competitive gap — see `plans/GAP_ANALYSIS.md` "DCM proper" PARTIAL matches table.

---

## Motivation

`AvoidKeywordsInWildcardPatternRule` (`lib/src/rules/data/record_pattern_rules.dart:370`, code `avoid_keywords_in_wildcard_pattern`) only checks whether a pattern variable's name collides with a reserved Dart keyword:

```dart
static const Set<String> _keywords = <String>{
  'abstract', 'as', 'assert', ... // keyword list
};
```

It never inspects whether `_` (the actual wildcard token) is *misused* — for example, when a record/object destructuring pattern discards a field with `_` but that same value is then reconstructed or looked up again immediately after in the same case body (defeating the purpose of destructuring), or when a switch case uses `_` for every positional element of a multi-field pattern, making the case unreadable ("what is even being matched here?"). DCM's `avoid-misused-wildcard-pattern` targets this general class of "wildcard used where it hides information the reader needs" — a distinct, broader problem from "the binding name happens to be a keyword."

---

## Detection / Behavior

### Should flag (bad code)

```dart
switch (record) {
  case (int _, String name): // LINT — wildcard for first field, but code re-derives it below
    print(record.$1); // re-reads the exact value the wildcard just discarded
}

switch (shape) {
  case Circle(radius: _, color: _): // LINT — every field wildcarded; case conveys no match intent
    handleCircle();
}
```

### Should pass (good code)

```dart
switch (record) {
  case (int _, String name): // OK — first field genuinely unused afterward
    print(name);
}

switch (shape) {
  case Circle(radius: final r, color: final c): // OK — fields bound and used meaningfully
    handleCircle(r, c);
}
```

---

## Proposed Tier

Tier: Recommended (unchanged — same tier as `avoid_keywords_in_wildcard_pattern`, see `lib/src/tiers.dart:1606`)
Justification: Same "pattern-matching readability" category and rule cost as the existing keyword check; no new severity class introduced.

---

## Edge Cases

1. **Wildcard for a field the case body never references** — should pass; this is the *correct* use of `_`, not a misuse.
2. **Wildcard reused where the destructured value is accessed via the original scrutinee expression** (`record.$1` after `case (_, name)`) — should flag; the wildcard promised the value was unneeded, but the code contradicts that.
3. **Single-field record/pattern with `_`** — should pass by default; a lone wildcard in a one-element pattern rarely indicates a readability problem and flagging it would be noisy for common "I only care whether it matched" idioms.
4. **Nested patterns** — recurse into nested object/record patterns so a wildcard buried two levels deep is still checked.
5. **`_` used as a genuinely unused function parameter (not a pattern)** — out of scope; this proposal only extends pattern-matching contexts (`case`, switch patterns, destructuring), not ordinary parameter lists.

---

## Alternatives Considered

- **Separate new rule** (`avoid_misused_wildcard_pattern`): considered, since the detection logic (scanning case-body usage of a scrutinee) is structurally different from the existing keyword-name check (a static string-set lookup). However, both rules examine the same AST surface (wildcard patterns in `SwitchPatternCase`/`CaseClause`) and share the same problem domain ("wildcard pattern hygiene"), so extending keeps a single rule id for users to enable/configure for all wildcard-pattern concerns, consistent with how `avoid_keywords_in_wildcard_pattern` is already scoped narrowly within that domain rather than as a general naming rule.

---

## Decision

<!-- Fill in when the proposal is accepted or declined -->

---

## Implementation Notes

Add a second check inside `AvoidKeywordsInWildcardPatternRule.runWithReporter` (`lib/src/rules/data/record_pattern_rules.dart`, near line 380 onward where the wildcard/keyword visitor is registered) that, for each `WildcardPattern` found within a `SwitchPatternCase`, walks the case body for `PropertyAccess`/`PrefixedIdentifier` reads against the same scrutinee expression's field, and separately counts total wildcard fields vs. total fields per object/record pattern to flag "all wildcards" cases. Reference: `lib/src/rules/data/record_pattern_rules.dart:370`.

---

## Commits

<!-- Add commit hashes as implementation lands -->
