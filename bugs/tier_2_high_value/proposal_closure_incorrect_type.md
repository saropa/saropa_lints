# PROPOSAL: Flag Closures Widened to `dynamic`/Broader Types by Context Loss

**Status: Open**

Created: 2026-09-02
Type: New rule
Related rules: `avoid_unsafe_cast` (`lib/src/rules/data/type_rules.dart`, related but distinct — that rule targets explicit `as` casts, not implicit closure-type widening)

---

## Summary

Add `closure_incorrect_type` to flag a closure literal whose parameter or return type is implicitly widened away from the specific function type its assignment/argument context implies — e.g. a closure assigned to a `var`/field/parameter typed as a broader function type (or `Function`/`dynamic`) than the signature the closure is actually used as, so Dart's type inference silently accepts a mismatched shape instead of erroring.

**Closes gap:** `essential_lints` `closure_incorrect_type` (github.com/FMorschel/essential_lints). Implementing this proposal as specified fully closes this competitive gap — see `plans/GAP_ANALYSIS.md` `essential_lints` section (HAVE: 9, PARTIAL: 5, GAP: 13).

---

## Motivation

Dart infers a closure literal's parameter and return types from its *immediate* assignment context (the "downwards inference" context type) at the point of declaration. Once that inference happens, the closure's static type is fixed — but if the surrounding declaration is typed more broadly than the closure actually needs (a field typed `Function`, a `dynamic` callback slot, or a generic `Function(dynamic)` collection element), Dart infers the closure's parameters as `dynamic` instead of the narrower type the call site actually passes. The bug surfaces later, often several calls away from the closure's declaration, as a runtime `TypeError` or — worse — a silent behavioral divergence (e.g. an `==` comparison against `dynamic` that never matches). `essential_lints` ships `closure_incorrect_type` specifically to catch this class of context-loss bug at declaration time, before the type information needed to diagnose it has been thrown away.

---

## Detection / Behavior

### Should flag (bad code)

```dart
class EventBus {
  // Field is typed as bare `Function`, so the closure below infers `dynamic`
  // parameters instead of the `String` the call site actually passes.
  Function? onMessage;

  void register() {
    onMessage = (String s) => s.length; // LINT — closure typed against a broader
                                         // `Function` context than its own signature
  }

  void emit(String s) {
    // onMessage!(s) still works today, but any refactor of the field's
    // declared type silently loses the compiler's ability to verify this call.
    onMessage?.call(s);
  }
}

// Collection typed with a wider element signature than the callback needs.
final List<bool Function(Object)> predicates = <bool Function(Object)>[
  (Object o) => o is String, // OK — matches declared element type
];

void addPredicate() {
  final dynamic Function(dynamic) widened = (String s) => s.isNotEmpty; // LINT
  // — assigned to a `dynamic Function(dynamic)` variable though the closure
  //   body only accepts/returns narrower types; a caller can now pass
  //   anything and the mismatch surfaces as a runtime crash, not a compile error.
}
```

### Should pass (good code)

```dart
class EventBus {
  // Field typed with the exact function signature the closure uses.
  void Function(String)? onMessage;

  void register() {
    onMessage = (String s) => print(s.length); // OK — declared and inferred types match
  }
}

final List<bool Function(Object)> predicates = <bool Function(Object)>[
  (Object o) => o is String, // OK
];
```

---

## Proposed Tier

Tier: Recommended
Justification: This is a genuine correctness gap — Dart's type system's inability to catch the mismatch is exactly the hole DCM/`essential_lints` prior art documents — but it requires resolving both the closure's own inferred signature and the surrounding declared context type, so it needs full type resolution rather than pure AST shape-matching. That places it above Essential (which favors near-zero-false-positive syntactic checks) but well within mainstream applicability, since `Function`/`dynamic`-typed callback slots are a common pattern across callback-heavy Flutter/Dart code (event buses, `VoidCallback`-adjacent APIs, plugin registration).

---

## Edge Cases

1. **Closure assigned to a variable with no declared type (`var`/`final` with inference)** — should pass; Dart infers the variable's type *from* the closure here, so there is no broader context to lose information against.
2. **Closure passed directly as a function argument whose parameter type exactly matches the closure's own inferred signature** — should pass; this is the normal, safe case (e.g. `list.where((Item i) => i.active)` where `where` expects `bool Function(Item)`).
3. **Closure assigned to a field/variable declared as `dynamic` explicitly, where the codebase clearly intends dynamic dispatch (e.g. a plugin registry storing heterogeneous callbacks)** — flag by default; the pattern is still a latent bug even when "intentional," but document as a likely source of legitimate suppressions via `// ignore:` for plugin/registry code.
4. **Closure with an explicitly declared parameter type that is intentionally broader than needed** (e.g. `(Object o) => ...` used defensively) — should pass; an explicit, deliberate type annotation on the closure itself is not "incorrect," only the *unannotated*-and-then-inferred-broader case is the target.
5. **Nested closures (a closure returning another closure)** — apply the check independently at each closure boundary; only the outer widening context matters for each respective closure literal.

---

## Alternatives Considered

- **Flag every closure assigned to a `Function`/`dynamic`-typed slot unconditionally, regardless of whether a narrower type was inferable** — rejected; this would fire even when the closure's own parameters are already declared explicitly and correctly (edge case 4), producing noise on defensive/generic code without a real bug present.
- **Limit detection to `Function` fields only (skip local variables and generic collection elements)** — considered for a smaller first cut, but rejected because the `List<Function>` / generic-collection case (the second bad example above) is at least as common a source of this bug in practice as bare fields, and `essential_lints`' own scope is not field-only.

---

## Decision

---

## Implementation Notes

Requires resolving the closure literal's `staticType` (a `FunctionType`) against the declared type of its assignment target (field/variable/parameter declaration, or the element type of a collection literal) and comparing parameter/return types structurally — flag when the declared context type is `Function`, `dynamic`, or a `FunctionType` whose parameter/return types are strictly broader (assignable-from but not equal) than the closure's own inferred or declared signature. Candidate home: `lib/src/rules/data/type_rules.dart`, alongside the existing type-mismatch/cast rules — reuse that file's established `DartType` comparison helpers rather than writing new ones.

---

## Commits
