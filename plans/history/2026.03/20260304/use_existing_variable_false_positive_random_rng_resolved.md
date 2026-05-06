# use_existing_variable — False positive when variables are assigned from Random (or RNG) calls — RESOLVED

**Rule:** `use_existing_variable`  
**File:** `lib/src/rules/code_quality/code_quality_variables_rules.dart` — `UseExistingVariableRule`  
**Status:** Resolved  
**Date:** 2026-03-04

## Resolution summary

The rule no longer reports duplicate variables when two (or more) variables in the same block have the same initializer **source** and that initializer uses `Random` or RNG-like APIs. Same source was incorrectly treated as same value; each call to `nextDouble()`, `nextInt()`, etc. yields a **different value**. The implementation now **explicitly** excludes initializers that:

- Use any type named `Random`, `RNG`, or `RandomNumberGenerator` from any library’s `Random` (constructor or instance methods `nextDouble()`, `nextInt()`, `nextBool()`, `next()`).
- Call well-known RNG method names (`nextDouble`, `nextInt`, `nextBool`, `next`) on a receiver whose static type has one of those names, or on a variable with a common RNG-like name (`rng`, `random`, `rand`, `rnd`).

Implementation: `_RandomPresenceVisitor`, `_expressionUsesRandomOrRng()`, `_isRngLikeType()`, and constants `_rngMethodNames`, `_rngReceiverNames`, `_rngTypeNames`. This check runs in addition to the existing “contains any invocation” exclusion. Fixture: `example_core/lib/code_quality/use_existing_variable_fixture.dart` — `_goodSameSourceWithRandom()`, `_goodSameSourceWithRandomInt()` must not trigger. Tests: `test/code_quality_rules_test.dart`, `test/false_positive_fixes_test.dart`. Rule DartDoc and CHANGELOG updated.

## References

- Original bug: `bugs/history/false_positives/use_existing_variable_false_positive_random_rng.md`
- Related resolution: `bugs/history/false_positives/use_existing_variable_tosource_false_positive_resolved.md` (same rule; generic “contains invocation” exclusion)
