# PROPOSAL: Require Named Arguments at Call Sites With Ambiguous Positional Parameters

**Status: Open**

Created: 2026-09-02
Type: New rule
Related rules: `none`

---

## Summary

Add `always_specify_parameter_names` to flag call sites that pass multiple positional arguments of the same static type (e.g. two `String`/`int`/`bool` positional parameters in a row) without using named arguments, where the callee's declaration exposes those parameters as optional-positional or where the call site is otherwise easy to misread (e.g. `Duration(10, 5)`-shaped calls). This targets the classic "which argument is which" bug class where two adjacent same-typed positional arguments can be silently swapped without any compiler error.

**Closes gap:** `pyramid_lint` `always_specify_parameter_names` (pub.dev). Implementing this proposal as specified fully closes this competitive gap — see `plans/GAP_ANALYSIS.md`.

---

## Motivation

When a function/constructor has two or more consecutive positional parameters of the same type, swapping them at a call site compiles cleanly and silently produces wrong behavior — the classic `createUser('Smith', 'John')` vs `createUser('John', 'Smith')` bug. Named arguments make the call self-documenting and immune to accidental swaps. `pyramid_lint` ships this as a general-purpose readability/safety rule; it complements saropa's existing constructor/parameter-count rules but targets call-site clarity specifically, not declaration shape.

---

## Detection / Behavior

Flag an invocation (function call, constructor call, method call) that passes 2 or more consecutive positional arguments whose static types are identical (or both assignable to a shared "confusable" primitive type like `String`/`int`/`num`/`bool`), where none of those arguments are passed as named arguments and the callee declares them as available for named-style disambiguation (i.e. not `required` strictly-positional-only params from an external SDK the caller cannot change usage for, though the call-site check applies regardless of declaration — flag the ambiguous call shape itself).

### Should flag (bad code)

```dart
void createUser(String firstName, String lastName) { /* ... */ }

void main() {
  createUser('Smith', 'John'); // LINT — two adjacent String args, easy to swap silently
}
```

### Should pass (good code)

```dart
void createUser({required String firstName, required String lastName}) { /* ... */ }

void main() {
  createUser(firstName: 'John', lastName: 'Smith'); // OK — named, unambiguous
}
```

---

## Proposed Tier

Tier: Professional
Justification: Real bug-prevention value but requires the codebase to have already adopted named-parameter-friendly APIs; flagging calls into external/SDK APIs with fixed positional signatures (that the caller cannot change to named) would be noisy, so this fits Professional rather than a default-on Essential/Recommended tier.

---

## Edge Cases

1. **Positional parameters of different types adjacent to each other** (`String`, then `int`) — should pass; the swap-confusion risk requires same/confusable types.
2. **Call into a third-party/SDK API whose parameters are strictly positional (not nameable)** — should pass; the rule cannot demand named arguments the callee doesn't support. Detection must resolve the callee's declared parameter kind, not just the call site's syntax.
3. **Single positional argument, or non-adjacent same-typed arguments separated by a differently-typed one** — should pass; only genuinely adjacent same/confusable-typed pairs create the swap risk.
4. **Widely-used constructors already idiomatically positional by Dart convention** (e.g. `Duration(seconds: 5)` already uses named; `Offset(dx, dy)`, `Point(x, y)` are conventionally positional pairs where swap risk is understood/accepted by the ecosystem) — needs discussion; likely requires an allowlist of well-known positional-pair constructors (`Offset`, `Point`, `Size`) to avoid flagging idiomatic Dart/Flutter code.

---

## Alternatives Considered

- **Flag based purely on parameter count (2+) regardless of type match** — rejected; too broad, would flag legitimate calls like `max(a, b)` where positional order is the entire point and type-matching is expected, not a smell.

---

## Decision

---

## Implementation Notes

---

## Commits
