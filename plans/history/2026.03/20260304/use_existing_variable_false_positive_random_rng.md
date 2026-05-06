# Bug report: use_existing_variable — False positive when variables are assigned from Random (or RNG) calls

**Rule:** `use_existing_variable`  
**File:** `lib/src/rules/code_quality/code_quality_variables_rules.dart` — `UseExistingVariableRule`  
**Status:** Resolved  
**Date:** 2026-03-04

**Resolution summary:** The rule reported duplicates when two variables had the same initializer source but that initializer used Random or RNG (e.g. `rng.nextDouble()`). Each call yields a different value, so this was a false positive. Fixed by explicitly excluding initializers that use any type named Random/RNG/RandomNumberGenerator (from any library) or RNG-like receiver names calling nextDouble/nextInt/nextBool/next. See [use_existing_variable_false_positive_random_rng_resolved.md](use_existing_variable_false_positive_random_rng_resolved.md).

---

## Summary

The rule reported "New variable created with the same value as an existing in-scope variable" when two variables had **syntactically identical** initializers that called Random (or similar RNG) methods. Each call produces a **different value**, so the variables are not duplicates. The implementation now excludes such initializers from duplicate detection (via `_RandomPresenceVisitor` and `_isRngLikeType()`).

---

## Reproduction (archived)

### Code that triggered the false positive

```dart
final rng = math.Random(42);
for (var i = 0; i < 8; i++) {
  final x = 0.2 + rng.nextDouble() * 0.6;
  final y = 0.2 + rng.nextDouble() * 0.6;  // Was falsely reported as duplicate of x
}
```

### Acceptance criteria (all met)

- [x] No report when same initializer source uses Random or RNG.
- [x] Explicit Random/RNG detection (any type named Random/RNG/RandomNumberGenerator or receiver names rng/random/rand/rnd).
- [x] Fixture and tests added; CHANGELOG and rule docs updated.
