# PROPOSAL: Prefer `thenAnswer()` Over `thenReturn()` for Async Mocktail Stubs

**Status: Open**

Created: 2026-09-02
Type: New rule
Related rules: none

---

## Summary

Add `use_then_answer` to flag `when(...).thenReturn(someFuture)` in Mocktail/Mockito test stubs where the stubbed method returns a `Future`/`Stream`, and suggest `thenAnswer((_) async => value)` instead — `thenReturn` evaluates its argument eagerly at stub-setup time, which breaks stubs that should produce a fresh `Future` per invocation.

**Closes gap:** `dart_code_metrics_presets` `use-then-answer` and `flutter_skill_lints` `use_then_answer` — the same rule under two names from two independent sources. Implementing this proposal as specified fully closes this competitive gap — see `plans/GAP_ANALYSIS.md` "Uncovered ecosystem packages: Mocktail" gap theme and the `flutter_skill_lints` gap list.

---

## Motivation

`thenReturn(future)` captures one already-created `Future` instance and returns that same instance on every call — fine for a single call, but wrong when the stubbed method is invoked more than once (each call should get its own future/completion), and it silently masks the difference between "stub returns a completed future" and "stub returns a future that completes later." `thenAnswer((_) async => value)` builds a fresh future per invocation and is Mocktail's documented pattern for async stubs. This is a common real-world Flutter test-suite footgun independently flagged by two unrelated lint packages, and saropa has no Mocktail-specific coverage at all today.

---

## Detection / Behavior

Flag a `.thenReturn(...)` call on a Mocktail/Mockito `when(...)` chain where the stubbed member's declared return type is `Future<T>` or `Stream<T>`.

### Should flag (bad code)

```dart
when(() => mockRepo.fetchUser()).thenReturn(Future.value(testUser)); // LINT — use thenAnswer for async stubs
```

### Should pass (good code)

```dart
when(() => mockRepo.fetchUser()).thenAnswer((_) async => testUser); // OK

when(() => mockRepo.userId).thenReturn('u1'); // OK — synchronous getter, thenReturn is correct
```

---

## Proposed Tier

Tier: Comprehensive
Justification: Package-specific rule (`mocktail`/`mockito` dependency required), scoped to test files — appropriate for Comprehensive per the package-specific-rule convention.

---

## Edge Cases

1. **`thenReturn(Future.value(x))` vs. `thenReturn(someAlreadyAwaitedFuture)`** — should flag both; the eager-evaluation problem exists regardless of how the future was constructed.
2. **Stubbed member's return type not resolvable (dynamic mock without a typed interface)** — should pass; avoid false positives when static type information is unavailable.
3. **`thenReturn` on a synchronous `Future`-returning getter used only once in the whole suite** — still flag; correctness of the pattern doesn't depend on call count, and a second call site could be added later.
4. **Non-test file using Mocktail (unusual but possible, e.g. a shared test-utils package)** — should still flag; scope by import/API usage, not just file path.

---

## Alternatives Considered

- **Only flag `Future`, not `Stream`** — rejected; `Stream` stubs have the same eager-evaluation/single-instance problem, and both source packages' descriptions cover async return types generally.

---

## Decision

---

## Implementation Notes

---

## Commits
