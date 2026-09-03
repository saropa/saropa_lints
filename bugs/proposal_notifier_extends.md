# PROPOSAL: Flag `@riverpod` Classes Not Extending Their Generated Base Class

**Status: Open**

Created: 2026-09-02
Type: New rule
Related rules: `notifier_build`

---

## Summary

Add `notifier_extends` to flag a class annotated `@riverpod` (via `riverpod_generator`) that does not `extends` its generated base class `_$ClassName`. Riverpod's code generator produces `_$ClassName` with the wiring (`ref`, provider registration, `state` plumbing) that the hand-written class must inherit — omitting `extends` compiles only when the class happens not to use any generated member yet, and breaks the moment it does.

**Closes gap:** `riverpod_lint` `notifier_extends` (pub.dev). Implementing this proposal as specified fully closes this competitive gap — see `plans/GAP_ANALYSIS.md`.

---

## Motivation

`riverpod_generator` relies on inheritance, not composition, to inject `ref` and the provider plumbing into a notifier class. A class that forgets `extends _$ClassName` is a silent trap: it may build fine until the first `ref.watch`/`ref.read` call is added, at which point the class fails to compile with an error that doesn't obviously point back to the missing `extends`. Catching this at the point the class is declared removes an entire category of Riverpod-codegen confusion.

---

## Detection / Behavior

### Should flag (bad code)

```dart
@riverpod
class Counter { // LINT — @riverpod class must extend its generated base class `_$Counter`
  int build() => 0;
}
```

### Should pass (good code)

```dart
@riverpod
class Counter extends _$Counter { // OK — extends the generated base class
  @override
  int build() => 0;
}
```

---

## Proposed Tier

Tier: Comprehensive
Justification: package-specific to `riverpod_generator`'s codegen contract; requires the `riverpod_annotation`/`riverpod_generator` dependency.

---

## Edge Cases

1. **Class extends an unrelated base class instead of `_$ClassName`** — should flag the same way; any extends clause other than the generated base class violates the contract.
2. **Functional (non-class) `@riverpod` providers (`@riverpod String greeting(Ref ref) => ...`)** — should pass; the extends requirement applies only to the class-based `Notifier`/`AsyncNotifier` form.
3. **Generated file itself (`*.g.dart`) referencing `_$ClassName`** — should pass; standard generated-file suppression applies, and the rule targets the hand-written source file.
4. **Class annotated `@riverpod` but generator hasn't run yet (`_$ClassName` doesn't exist)** — should still flag the missing `extends` textually; the rule checks syntax, not whether the generated symbol currently resolves.

---

## Alternatives Considered

- **Rely on the analyzer's own "extends a type that doesn't exist" error once codegen runs** — rejected as the sole safety net; that error only appears after running `build_runner`, whereas this rule catches the mistake immediately while editing.

---

## Decision

---

## Implementation Notes

---

## Commits
