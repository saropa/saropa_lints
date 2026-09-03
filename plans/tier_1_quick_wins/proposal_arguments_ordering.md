# PROPOSAL: Flag Named Arguments Passed Out of Declaration Order

**Status: Duplicate** — already exists as `prefer_arguments_ordering` (alias `arguments_ordering`) in `stylistic_rules.dart`

Created: 2026-09-02
Type: New rule
Related rules: none

---

## Summary

Add `arguments_ordering` to flag call-site named arguments passed in an order that does not match the
order the corresponding parameters were declared in the target function/constructor signature. Consistent
call-site ordering makes diffs smaller and call sites easier to scan against the declaration.

**Closes gap:** `awesome_lints` `arguments_ordering` (github.com/LucasXu0/awesome_lints). Implementing this
proposal as specified fully closes this competitive gap — see `plans/GAP_ANALYSIS.md`.

---

## Motivation

When a constructor or function has many named parameters, callers often add new ones at the end of the
argument list regardless of where the parameter sits in the declaration, which makes multi-arg call sites
drift out of sync with the signature over time and makes diffs noisier than necessary (an inserted argument
in the "wrong" position reads as a reorder of unrelated lines). `awesome_lints` ships this as
`arguments_ordering`; `dart_code_linter`'s `arguments-ordering` covers the same idea but sorts by
declaration order specifically (already tracked as PARTIAL against a saropa alphabetical variant) — this
proposal targets the declaration-order variant to close the exact gap.

---

## Detection / Behavior

### Should flag (bad code)

```dart
class UserProfile {
  const UserProfile({required this.name, required this.age, required this.email});
  final String name;
  final int age;
  final String email;
}

final profile = UserProfile(
  email: 'a@b.com', // LINT — arguments_ordering: 'email' declared after 'age', passed before it
  name: 'Alice',
  age: 30,
);
```

### Should pass (good code)

```dart
final profile = UserProfile(
  name: 'Alice', // OK — matches declaration order
  age: 30,
  email: 'a@b.com',
);
```

---

## Proposed Tier

Tier: Stylistic (opt-in, no default tier)
Justification: Pure call-site formatting convention with no correctness or readability-safety implication;
matches saropa's existing placement for other argument/parameter-ordering style rules, which live outside
the default tier ladder.

---

## Edge Cases

1. **Positional arguments mixed with named arguments** — should pass for the positional portion; only the
   relative order of named arguments is checked.
2. **A call passing only a subset of the declared named parameters** — should still flag if the passed subset
   is internally out of order relative to their own declaration positions, ignoring the parameters that were
   omitted.
3. **Cascade or multi-line calls where `dart format` already reflows argument lines** — should flag based on
   AST argument order, not source line order, so formatter output doesn't mask a violation.
4. **Calls to external SDK/package constructors the project doesn't control** (e.g. `MaterialApp(...)`) —
   should still flag; ordering discipline is about the call site's own readability, independent of who owns
   the declaration.

---

## Alternatives Considered

- **Alphabetical ordering** (saropa's existing informal convention referenced in `plans/GAP_ANALYSIS.md`
  `dart_code_linter` Partial notes) — rejected as the target for this specific gap-closing proposal since the
  cited source rule is declaration-order; an alphabetical variant may already exist or be a separate proposal.
- **Auto-fix that reorders arguments** — plausible follow-up; deferred from this proposal since reordering
  named arguments safely requires preserving any side-effecting expressions' evaluation order, which Dart
  guarantees is left-to-right in source order — a quick fix must recompute expressions in original evaluation
  order after the textual reorder, not just move tokens.

---

## Decision

---

## Implementation Notes

---

## Commits
