# PROPOSAL: Require DartDoc on Test Fake/Mock Constructor Parameters

**Status: Open**

Created: 2026-09-02
Type: New rule
Related rules: `document_enum` (proposed alongside), `document_interface` (proposed alongside)

---

## Summary

Add `document_fake_parameters` to flag constructor parameters on hand-written test fakes/stubs (classes named `Fake*`, `Mock*`, `Stub*`, or implementing a `Fake` marker) that lack a DartDoc comment explaining what behavior the parameter controls.

**Closes gap:** `ripplearc_linter` `document_fake_parameters`. Implementing this proposal as specified fully closes this competitive gap — see `plans/GAP_ANALYSIS.md` "Documentation conventions" section.

---

## Motivation

Fake/stub classes in test suites accumulate configuration parameters over time (`returnError`, `delayMs`, `throwOnSecondCall`) that control subtle test-double behavior. Without a doc comment on each parameter, other engineers reusing the fake have to read its implementation to understand what a given flag actually does, which defeats the purpose of having a reusable test double.

---

## Detection / Behavior

### Should flag (bad code)

```dart
class FakeUserRepository implements UserRepository {
  FakeUserRepository({
    this.shouldThrow = false, // LINT — fake constructor parameter missing DartDoc
  });

  final bool shouldThrow;
}
```

### Should pass (good code)

```dart
class FakeUserRepository implements UserRepository {
  FakeUserRepository({
    /// When true, every repository call throws [UserRepositoryException]
    /// instead of returning data — used to test error-handling paths.
    this.shouldThrow = false,
  });

  final bool shouldThrow;
}
```

---

## Proposed Tier

Tier: Pedantic
Justification: test-infrastructure documentation completeness rule; niche and only relevant to codebases with hand-rolled fakes, opt-in-depth tier.

---

## Edge Cases

1. **Fake class with zero constructor parameters** — should pass trivially; nothing to document.
2. **Mockito-generated `MockX` classes (`.mocks.dart`)** — should pass; generated-file suppression applies, and Mockito mocks don't take hand-written constructor parameters anyway.
3. **Parameter name that is self-explanatory (`id`, `name`)** — should flag anyway for consistency, matching the "always require" precedent from `document_enum`.
4. **Fake class outside `test/` directory (e.g. shared in `lib/src/testing/`)** — should still flag; classification is by naming convention (`Fake*`/implements a fake), not by directory.

---

## Alternatives Considered

- **Scope to only `test/` directory files** — rejected; some projects export shared fakes from `lib/` for use across packages, and the naming-convention check is a more reliable signal than path.

---

## Decision

---

## Implementation Notes

Needs a `Fake`/`Mock`/`Stub` naming-convention or interface-marker detector; reuse if saropa already has fake/mock classification logic elsewhere (check test-hygiene rules in `lib/src/rules/` first).

---

## Commits
