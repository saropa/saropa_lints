# PROPOSAL: Flag Real Logic Inside a Mocktail/Mockito Mock Class

**Status: Open**

Created: 2026-09-02
Type: New rule (package-specific — depends on `mocktail` or `mockito`)
Related rules: none

---

## Summary

Add `avoid-implementation-in-mocks` (saropa id: `avoid_implementation_in_mocks`) to flag a class extending
`Mock` (mocktail) or implementing a `Mockito`-generated mock base that contains real method bodies with
control flow, computation, or state instead of relying purely on `when()`/stub configuration. A mock class
exists to be programmed per-test via stubbing; hardcoding behavior into overridden methods defeats the
purpose and produces brittle, hard-to-reconfigure test doubles.

**Closes gap:** `dart_code_metrics_presets` `avoid-implementation-in-mocks` / `avoid_implementation_in_mocks`
(Mocktail/Mockito preset). Implementing this proposal as specified fully closes this competitive gap — see
`plans/GAP_ANALYSIS.md` "Uncovered ecosystem packages" section.

---

## Motivation

Mock classes are meant to be behaviorally inert until a test configures them with `when(...).thenReturn(...)`
or similar. A developer who writes real conditional logic or business rules directly into an overridden
method on a `Mock` subclass has effectively hand-rolled a fake instead of using the mocking framework as
intended — the resulting test double silently diverges from what other tests expect a bare mock to do, and
changes to the "real" logic require editing test infrastructure instead of stub setup. `dart_code_metrics`'s
preset for Mocktail/Mockito is the prior art; saropa currently has zero rules recognizing either package.

---

## Detection / Behavior

### Should flag (bad code)

```dart
class MockUserRepository extends Mock implements UserRepository {
  @override
  Future<User> fetchUser(String id) async { // LINT — avoid_implementation_in_mocks: real logic in a Mock subclass; use when()/thenAnswer() stubbing instead
    if (id.isEmpty) throw ArgumentError('id required');
    return User(id: id, name: 'fallback');
  }
}
```

### Should pass (good code)

```dart
class MockUserRepository extends Mock implements UserRepository {} // OK — behavior configured per-test via when()

// test:
when(() => mockRepo.fetchUser(any())).thenAnswer((_) async => User(id: '1', name: 'Alice'));
```

---

## Proposed Tier

Tier: Comprehensive (package-dependent — see `mocktail`/`mockito` dependency note)
Justification: Only fires in test files where a class extends `Mock` or a generated Mockito base; testing-
hygiene concern rather than a universal Dart/Flutter correctness issue.

---

## Edge Cases

1. **An empty override that only calls `super.noSuchMethod(...)`** (Mockito codegen pattern) — should pass;
   this is the framework's own generated delegation, not hand-written logic.
2. **A trivial override returning a constant** (`@override String get name => 'mock';`) — needs discussion;
   arguably still bypasses stubbing, but a single constant-return getter is a common, low-risk convenience
   pattern some teams accept — consider a size/complexity threshold rather than any-body-at-all.
3. **Helper methods on the mock class that are NOT overrides of the mocked interface** (test-only utility
   methods added to the mock subclass) — should pass; only overridden interface members are in scope.
4. **Project does not depend on `mocktail` or `mockito`** — must not fire; gate on package presence like
   saropa's other ecosystem-specific rules.

---

## Alternatives Considered

- **Flag any override on a `Mock` subclass with a non-empty body, no threshold** — simpler to implement but
  risks false positives on the constant-getter pattern in Edge Case 2; recommend starting with a small
  statement-count threshold (e.g. >1 statement, or any `if`/loop/throw) rather than zero-tolerance.

---

## Decision

---

## Implementation Notes

---

## Commits
