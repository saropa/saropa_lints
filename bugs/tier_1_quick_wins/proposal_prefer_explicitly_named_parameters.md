# PROPOSAL: Flag Positional Boolean/Ambiguous Arguments — Prefer Named Parameters

**Status: Open**

Created: 2026-09-02
Type: New rule
Related rules: `prefer_named_parameters`

---

## Summary

Add `prefer_explicitly_named_parameters` to flag a call site passing 2+ consecutive positional arguments of the same type (most commonly `bool`) to a function/constructor, where the call site reads ambiguously without hovering to see parameter names (e.g. `Widget(true, false, true)`), recommending the declaration expose those parameters as named instead.

**Closes gap:** essential_lints `prefer_explicitly_named_parameters`. Implementing this proposal as specified fully closes this competitive gap — see `plans/GAP_ANALYSIS.md` essential_lints Gaps section.

---

## Motivation

A call site like `createUser(true, false, true)` is unreadable without an IDE tooltip or jumping to the declaration — the reader cannot tell which flag is which without external help. Named parameters (`createUser(isActive: true, isAdmin: false, sendWelcomeEmail: true)`) make every call site self-documenting. This complements saropa's existing `prefer_named_parameters`, which targets excess positional-parameter *count*; this rule targets the specific "same-type positional arguments in a row" ambiguity, which is a readability hazard even when the total parameter count is small (e.g. exactly 2 booleans).

---

## Detection / Behavior

Flag a function/constructor invocation with 2 or more consecutive positional arguments of the same static type (`bool` primarily, also `int`/`String` literals of the same type back-to-back), at a declaration the author controls (i.e. not a third-party SDK signature that cannot be changed).

### Should flag (bad code)

```dart
void configure(bool enabled, bool verbose) { /* ... */ }

void main() {
  configure(true, false); // LINT — ambiguous positional booleans; declare enabled/verbose as named
}
```

### Should pass (good code)

```dart
void configure({required bool enabled, required bool verbose}) { /* ... */ }

void main() {
  configure(enabled: true, verbose: false); // OK — self-documenting at the call site
}
```

---

## Proposed Tier

Tier: Comprehensive
Justification: readability rule with real but non-critical impact (an IDE parameter hint mitigates most of the risk); matches saropa's placement for other call-site-clarity style rules.

---

## Edge Cases

1. **Single positional boolean argument (not 2+ in a row)** — should pass; the ambiguity this rule targets requires at least two same-typed arguments where order could plausibly be swapped by mistake.
2. **Positional arguments of different types in a row (`String`, then `bool`)** — should pass; type mismatch already gives some protection against accidental swap (compiler would catch it), so only same-type sequences are flagged.
3. **Third-party/SDK function signature the author cannot change (e.g. `Positioned(left, top, right, bottom, child)`)** — should pass at the call site; the rule can only meaningfully fire at the *declaration*, since call sites of unowned APIs cannot be fixed by the project.
4. **Named-and-positional mixed signature where only the tail is positional** — should flag only the positional same-typed run.

---

## Alternatives Considered

- **Flag at call sites regardless of who owns the declaration** — rejected; the fix (making the parameter named) is only actionable when the project controls the declaration, so scoping to project-owned declarations avoids unfixable noise on SDK/package calls.

---

## Decision

---

## Implementation Notes

---

## Commits
