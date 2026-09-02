# PROPOSAL: Flag Functional Riverpod Provider's First Parameter Not Matching `Ref`

**Status: Open**

Created: 2026-09-02
Type: New rule (package-specific: `riverpod`)
Related rules: `notifier_build`, `notifier_extends` (same Riverpod-correctness family)

---

## Summary

Add `functional_ref` to flag a functional Riverpod provider (`@riverpod T myProvider(Ref ref, ...)` or the legacy `Provider((ref) => ...)` form) whose first parameter type does not match the `Ref` type Riverpod's code generator/runtime expects for that provider kind.

**Closes gap:** `riverpod_lint` `functional_ref`. Implementing this proposal as specified fully closes this competitive gap — see `plans/GAP_ANALYSIS.md` "riverpod" gaps section.

---

## Motivation

Riverpod's generator-based providers (`@riverpod`) generate a specific `Ref` subtype per provider (e.g. `MyProviderRef`) that carries provider-specific capabilities (auto-dispose, family arguments). A functional provider whose first parameter is typed as the wrong `Ref` variant (too generic, or mismatched for the provider's generated type) either fails to compile with a confusing generic-type error or silently loses type-specific capabilities if a compatible-but-wrong ref type is used.

---

## Detection / Behavior

### Should flag (bad code)

```dart
@riverpod
String greeting(Ref ref) { // LINT — first parameter should be the generated GreetingRef, not the generic Ref
  return 'Hello';
}
```

### Should pass (good code)

```dart
@riverpod
String greeting(GreetingRef ref) { // OK — matches the generator-expected Ref type
  return 'Hello';
}
```

---

## Proposed Tier

Tier: Professional
Justification: package-specific correctness rule for `riverpod`/`riverpod_generator`; a genuine, often confusing compile-time-adjacent bug class for a widely-used state-management package, warranting a higher tier than niche package rules.

---

## Edge Cases

1. **Legacy (non-generator) `Provider((ref) => ...)` using plain `Ref`** — should pass; the legacy manual-construction API legitimately uses the generic `Ref` type, only generator-based (`@riverpod`) functions have a specific generated `Ref` type to match.
2. **Provider function with zero parameters (invalid Riverpod usage regardless)** — out of scope for this rule; a different existing/other rule likely already covers "provider function missing ref parameter" as a structural requirement.
3. **`@riverpod` class-based (Notifier) providers** — out of scope; those are covered by `notifier_build`/`notifier_extends`, not `functional_ref`, which targets only the functional-provider form.
4. **Provider with a `Ref` parameter typed via a generic type alias that resolves correctly at the type-system level but isn't literally named `<ProviderName>Ref`** — should pass if the resolved type matches; check resolved static type equality, not source-text name matching, to avoid false positives on valid aliasing.

---

## Alternatives Considered

- **Rely on Dart's own generated-code compile error to surface this instead of a lint** — rejected; by the time `build_runner` surfaces the type mismatch, the error message is often generic/unhelpful, and a targeted lint gives immediate, actionable, in-editor feedback before running codegen.

---

## Decision

---

## Implementation Notes

Requires resolving the generator-expected `Ref` type name from the provider's annotation/name (`<ProviderName>Ref` convention) and comparing against the actual first-parameter static type; may need to hook into `riverpod_generator`'s naming convention directly rather than re-deriving it independently.

---

## Commits
