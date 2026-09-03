# PROPOSAL: Flag Parameters Reassigned to a Local Alias Without Transformation

**Status: Open**

Created: 2026-09-02
Type: New rule
Related rules: none

---

## Summary

Add `avoid_parameter_aliases` to flag a function/method body that immediately assigns a parameter's value to a new local variable under a different name with no transformation applied — for example `final n = name;` at the top of a function that then uses `n` everywhere instead of `name` — a pattern that adds an extra name for a reader to track for no behavioral benefit.

**Closes gap:** flutter_skill_lints `avoid_parameter_aliases`. Implementing this proposal as specified fully closes this competitive gap — see `plans/GAP_ANALYSIS.md`.

---

## Motivation

Aliasing a parameter under a shorter or differently-cased local name is pure renaming disguised as a local variable declaration. It doubles the number of names in scope that refer to the same value, forces a reader to mentally substitute one for the other throughout the function body, and offers no benefit that a consistent parameter name at the call site wouldn't already provide.

---

## Detection / Behavior

Flag a local variable declaration whose initializer is exactly a parameter reference (an identifier matching a parameter of the enclosing function/method, unmodified — no method call, no arithmetic, no null-coalescing default), where the local variable is then used throughout the rest of the function body in place of the parameter.

### Should flag (bad code)

```dart
void greet(String userName) {
  final n = userName; // LINT — n is a pure alias of userName, adds nothing
  print('Hello, $n!');
  print('Welcome, $n!');
}
```

### Should pass (good code)

```dart
void greet(String userName) {
  print('Hello, $userName!'); // OK — no alias, use the parameter directly
  print('Welcome, $userName!');
}

void greetNormalized(String userName) {
  final trimmed = userName.trim(); // OK — genuine transformation, not a pure alias
  print('Hello, $trimmed!');
}
```

---

## Proposed Tier

Tier: Comprehensive
Justification: Pure readability/naming style rule with no correctness impact; appropriate for a deep code-quality pass rather than default-on.

---

## Edge Cases

1. **Alias created to satisfy a promotion requirement (`final user = widget.user;` before a null-check that the analyzer can't promote through `widget.user` directly)** — should pass; this is a legitimate, analyzer-required pattern, not a stylistic alias, and must be excluded to avoid false positives on very common Flutter code.
2. **Parameter reassigned to a `final` local with an added default (`final n = userName ?? 'Guest';`)** — should pass; the `??` is a transformation.
3. **Alias is a `late` mutable local reassigned later in the function to a different value** — should pass; it's not a pure alias if the local's value later diverges from the parameter's.
4. **Alias created purely to shadow a longer nested-property access (`widget.controller.text`) for repeated use** — needs discussion; this differs from a bare-parameter alias (it shortens a chain, not renames a single identifier) — consider scoping the rule strictly to single-identifier parameter-to-parameter aliasing and leaving property-chain shortening out of scope.

---

## Alternatives Considered

- **Also flag field aliasing (`this.foo` reassigned to a local `foo` under a different name)** — deferred; the parameter case is both the more common and more clear-cut instance of the pattern; field aliasing can be considered as a follow-up extension.

---

## Decision

---

## Implementation Notes

---

## Commits
