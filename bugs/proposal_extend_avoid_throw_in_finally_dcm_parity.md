# PROPOSAL: Extend `avoid_throw_in_finally` with an Opt-In Blanket "Avoid Throw" Check

**Status: Open**

Created: 2026-09-02
Type: New rule
Related rules: `avoid_throw_in_finally`

---

## Summary

Extend the `avoid_throw_in_finally` rule family with an additional, separately gated check that flags any `throw` statement/expression outside the already-covered `finally`-block case, encouraging `Result`/`Either`-style error values instead — matching DCM's blanket `avoid-throw`.

**Closes gap:** DCM `avoid-throw` (dcm.dev) — currently PARTIAL via saropa's `avoid_throw_in_finally`. Implementing this proposal as specified fully closes this competitive gap — see `plans/GAP_ANALYSIS.md` "DCM proper" PARTIAL matches table.

---

## Motivation

`AvoidThrowInFinallyRule` (`lib/src/rules/architecture/structure_rules.dart:2719`, code `avoid_throw_in_finally`) is narrowly scoped:

```dart
context.addTryStatement((TryStatement node) {
  final Block? finallyBlock = node.finallyBlock;
  if (finallyBlock == null) return;
  finallyBlock.visitChildren(
    _ThrowFinder((ThrowExpression throwExpr) {
      reporter.atNode(throwExpr);
    }),
  );
});
```

It only visits `ThrowExpression`s that are lexically inside a `finally` block, where the specific harm is "silently replaces the original exception." A grep of `avoid_throw*` across `lib/src/rules/` shows every sibling rule (`avoid_throw_in_finally`, and others matched under `avoid_throw`) is similarly scoped to one specific throw *context* (finally blocks, constructors, getters, etc. — see `lib/src/rules/flow/exception_rules.dart`). None of them implement DCM's `avoid-throw`, which is a blanket, opt-in style rule: *any* `throw` anywhere in the codebase is flagged, on the theory that exceptions for control flow are an anti-pattern in codebases that use `Result<T, E>`/`Either<L, R>` return types instead. This is a fundamentally different, much broader, and much more opinionated rule than any of the existing context-specific throw checks.

---

## Detection / Behavior

### Should flag (bad code, when the new blanket check is enabled)

```dart
User parseUser(Map<String, dynamic> json) {
  if (json['id'] == null) {
    throw FormatException('missing id'); // LINT — throw used for expected/recoverable failure
  }
  return User(json['id']);
}
```

### Should pass (good code)

```dart
Result<User, FormatException> parseUser(Map<String, dynamic> json) {
  if (json['id'] == null) {
    return Failure(FormatException('missing id')); // OK — error surfaced as a value
  }
  return Success(User(json['id']));
}
```

```dart
try {
  doSomething();
} finally {
  throw Exception('cleanup failed'); // Still LINT under existing avoid_throw_in_finally
}
```

---

## Proposed Tier

Tier: Stylistic (opt-in, no default tier) — **change from the existing rule's Essential tier** (`lib/src/tiers.dart:378`).
Justification: `avoid_throw_in_finally` is Essential because it is a narrow, always-correct bug pattern (finally-block throws always hide the original exception, with no legitimate counter-use). A blanket "never throw" check is the opposite: it is a project-wide architectural style choice (adopt `Result`/`Either` everywhere) that conflicts with idiomatic Dart/Flutter code, which throws routinely (`ArgumentError`, `StateError`, framework-level assertions). Enabling it by default at any of the numeric tiers would produce thousands of diagnostics in any codebase that has not already adopted a `Result` type discipline. It belongs in `stylisticRules`, consistent with how other "opinionated, conflicts-with-idiomatic-code" rules are already parked there (see the extensive `moved to stylisticRules (opinionated)` comments throughout `lib/src/tiers.dart`).

---

## Edge Cases

1. **`throw` inside a `catch` block re-throwing after logging** — should still flag under the blanket rule (that is the point — DCM's rule has no context carve-outs), but the correction message should explicitly acknowledge this is a deliberate trade-off and suggest the `Result`-mapping alternative rather than implying the code is wrong.
2. **`throw` inside test files (`test/`)** — should pass; `expect(() => fn(), throwsA(...))` patterns and test helper functions routinely throw intentionally as part of verifying error paths.
3. **`throw` inside a constructor's assertion/validation logic** — should flag like any other throw; constructors are common places DCM users want to migrate to factory methods returning `Result`.
4. **Rethrow (`rethrow` statement, not `ThrowExpression`)** — should be treated identically to `throw` for this blanket check, since it has the same "exception-based control flow" characteristic DCM targets.
5. **Existing `avoid_throw_in_finally` and sibling context-specific rules** — must continue to fire independently and at their current tiers; this proposal adds a new, separately configurable check, it does not replace or subsume them.

---

## Alternatives Considered

- **Separate new rule** (`avoid_throw`): considered as the cleaner option given the tier mismatch (Essential vs. Stylistic) and the very different nature of the check (blanket vs. context-specific). However, keeping it under the `avoid_throw_in_finally` rule family (as an additional check/rule id documented and registered alongside the finally-specific one, in the same source file and section) keeps all "avoid throw"-flavored rules discoverable together in `ROADMAP.md` and the rule browser, and lets users who search for "avoid throw" find both the narrow always-on check and the broad opt-in one in one place. Either grouping is workable; this proposal recommends co-locating them as a new rule class in the same file, registered as its own rule id (`avoid_throw`) rather than folding into the existing rule's `runWithReporter`, since the tier and detection logic are unrelated enough that sharing one rule id/config toggle would be confusing.

---

## Decision

<!-- Fill in when the proposal is accepted or declined -->

---

## Implementation Notes

Add a new `AvoidThrowRule` class in `lib/src/rules/architecture/structure_rules.dart` near `AvoidThrowInFinallyRule` (line 2719), reusing the `_ThrowFinder` visitor pattern already defined there but registering it at the compilation-unit or function-body level (not scoped to `TryStatement.finallyBlock`), with a `test/`-path skip consistent with `ProjectContext.isTestFile`. Register the new rule id `avoid_throw` in `all_rules.dart` and add it to `stylisticRules` in `tiers.dart`.

---

## Commits

<!-- Add commit hashes as implementation lands -->
