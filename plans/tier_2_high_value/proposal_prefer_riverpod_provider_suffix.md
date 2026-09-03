# PROPOSAL: Require `Provider` Suffix on Top-Level Provider Variables

**Status: Open**

Created: 2026-09-02
Type: New rule
Related rules: `prefer_correct_provider_file_name`, `prefer_riverpod_notifier_suffix`

---

## Summary

Flag a top-level Riverpod provider variable (`Provider`, `StateProvider`, `FutureProvider`, `StreamProvider`, `NotifierProvider`, or an `@riverpod`-generated provider) whose name doesn't end in `Provider`.

**Closes gap:** DCM `prefer-riverpod-provider-suffix` (dcm.dev). Implementing this proposal as specified fully closes this competitive gap — see `plans/GAP_ANALYSIS.md` "DCM proper" TRUE GAPS section.

---

## Motivation

The `Provider` suffix is the single most consistent Riverpod convention across the ecosystem (`riverpod_generator`, official docs, community codebases): `userRepositoryProvider`, `cartTotalProvider`. Dropping the suffix (`userRepository`, `cartTotal`) makes a top-level variable indistinguishable from a plain constant or getter at the call site — `ref.watch(userRepository)` reads ambiguously compared to `ref.watch(userRepositoryProvider)`, and IDE autocomplete/search for "Provider" no longer surfaces it. This is the variable-naming counterpart to `prefer_riverpod_notifier_suffix` and is unrelated to any existing saropa rule (confirmed by grep — zero matches for `prefer_riverpod_provider_suffix` in `lib/src/rules/`).

---

## Detection / Behavior

### Should flag (bad code)

```dart
final userRepository = Provider<UserRepository>((ref) { // LINT — should end in "Provider"
  return UserRepository(ref.watch(apiClient));
});
```

```dart
final cartTotal = Provider<double>((ref) { // LINT
  return ref.watch(cartProvider).items.fold(0.0, (sum, i) => sum + i.price);
});
```

### Should pass (good code)

```dart
final userRepositoryProvider = Provider<UserRepository>((ref) { // OK
  return UserRepository(ref.watch(apiClientProvider));
});
```

```dart
final cartTotalProvider = Provider<double>((ref) { // OK
  return ref.watch(cartProvider).items.fold(0.0, (sum, i) => sum + i.price);
});
```

---

## Proposed Tier

Tier: Comprehensive
Justification: Naming convention, no runtime effect — same tier as the other Riverpod naming/structure proposals in this batch, for consistency across the group.

---

## Edge Cases

1. **`@riverpod` code-generation annotation on a top-level function** — the generator itself appends `Provider` to the generated variable name derived from the function name (e.g. `@riverpod String greeting(Ref ref) => 'hi';` generates `greetingProvider`); the rule should check the *function* name doesn't already end in redundant `Provider` (e.g. flag `greetingProviderFunction` naming confusion) but should NOT require the hand-written function itself to carry the suffix, since the generator adds it — this needs explicit scoping to avoid conflicting with `riverpod_generator`'s own convention. Recommend scoping the initial implementation to non-generated (`Provider<T>(...)`-style) top-level variables only, and treating `@riverpod`-annotated functions as a documented exclusion rather than guessing at generated output.
2. **Private top-level providers (`_internalCacheProvider`)** — should still flag if missing the suffix (`_internalCache`); privacy doesn't exempt the naming convention.
3. **`late final` top-level provider variables** — should pass through the same check as `final`; `late` doesn't change the naming expectation.
4. **A `Provider`-typed field on a class (not top-level)** — should discuss/pass for v1; DCM's rule targets top-level provider declarations specifically (matching Riverpod's actual usage pattern, since providers are almost always top-level `final` globals), so class fields are out of scope for the initial implementation.
5. **Providers created via a factory function returning a `Provider<T>` where the call site variable is what's named, not the factory** — should flag on the variable holding the `Provider` instance, not the factory function's own name.

---

## Alternatives Considered

- **Configurable suffix** — same reasoning as `prefer_riverpod_notifier_suffix`: deferred to a follow-up rather than blocking initial gap closure.
- **Detect by type (`is Provider` via static type) instead of matching against `ProviderBase` subtypes textually** — preferred where `usesTypeResolution` is available, consistent with saropa's existing convention of preferring type checks over string matching (per `CLAUDE.md` "Type checking over string matching"); implementation should resolve the declared/inferred type against Riverpod's `ProviderBase`/`Refreshable` hierarchy rather than pattern-matching the RHS expression's constructor name, to correctly catch `@riverpod`-generated variables and aliased imports alike.
