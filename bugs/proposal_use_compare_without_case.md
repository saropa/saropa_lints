# PROPOSAL: Suggest Case-Insensitive Comparison Helper for String Equality

**Status: Open**

Created: 2026-09-02
Type: New rule
Related rules: `avoid_case_sensitive_path_comparison` (file-path-scoped equivalent)

---

## Summary

Add `use_compare_without_case` to flag `==`/`!=` comparisons between two `String` expressions where at least one side is derived from user input, config, or an external source (heuristically: not a `const`/literal-only comparison), and suggest a case-insensitive comparison helper (e.g. `.toLowerCase() ==` or a `compareWithoutCase()` extension) instead.

**Closes gap:** `flutter_custom_lints` `use-compare-without-case`. Implementing this proposal as specified fully closes this competitive gap — see `plans/GAP_ANALYSIS.md` "Miscellaneous single-rule gaps" theme, which explicitly notes saropa's `avoid_case_sensitive_path_comparison` is scoped to file paths only, not general strings.

---

## Motivation

saropa's existing `avoid_case_sensitive_path_comparison` catches this exact bug class but only for filesystem paths — a narrow slice of where case-sensitivity bugs actually bite (locale-inconsistent OS behavior). The far more common real-world case is comparing user-typed input (email addresses, search queries, enum-like string flags from an API) with `==`, which silently fails whenever casing differs, e.g. rejecting `"Admin"` when the stored role is `"admin"`.

---

## Detection / Behavior

Flag a `==`/`!=` `BinaryExpression` where both operands are statically typed `String`, at least one operand is not a compile-time constant, and neither operand is already wrapped in `.toLowerCase()`/`.toUpperCase()`/a case-normalizing call.

### Should flag (bad code)

```dart
bool isAdmin(String role) {
  return role == 'admin'; // LINT — case-sensitive comparison of external input
}
```

### Should pass (good code)

```dart
bool isAdmin(String role) {
  return role.toLowerCase() == 'admin'; // OK — normalized before comparison
}

const kEnvProd = 'production';
bool isProd(String env) => env == kEnvProd; // OK — both sides are internal constants under our own control
```

---

## Proposed Tier

Tier: Pedantic
Justification: High false-positive risk against intentionally case-sensitive comparisons (enum-like internal constants, IDs, hashes) — needs to start opt-in and graduate only after real-world tuning.

---

## Edge Cases

1. **Comparison against an internal enum-like constant string (e.g. a route name)** — should pass under the "both sides constant" exemption; case sensitivity is intentional and correct there.
2. **Comparison inside a `switch` statement's `case` clauses** — should discuss; `switch` on string literals is a common, usually-intentional exact-match pattern and may need blanket exemption to avoid noise.
3. **`.compareTo(other) == 0`** — should flag identically to `==`; same case-sensitivity bug, different syntax.
4. **String comparison of already-`.toLowerCase()`-normalized values on both sides** — should pass; the rule's job is done.

---

## Alternatives Considered

- **Extend `avoid_case_sensitive_path_comparison` to cover all strings instead of a new rule** — rejected; the path-specific rule's heuristics (path-shaped values, path APIs) are much lower false-positive-risk than general string comparison, so keeping them separate lets each be tuned independently.

---

## Decision

---

## Implementation Notes

---

## Commits
