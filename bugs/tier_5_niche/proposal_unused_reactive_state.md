# PROPOSAL: Flag an `Observable`/`Computed` Field That Is Never Read

**Status: Open**

Created: 2026-09-02
Type: New rule
Related rules: `unobserved_reactive_read_in_build`

---

## Summary

Add `unused_reactive_state` for the `all_observer` package: flag an `Observable<T>`/`Computed<T>` field that is written to (constructed and/or mutated) but never read anywhere in the enclosing class — dead reactive state that pays the subscription/notification cost for no consumer.

**Closes gap:** `all_observer_lint` `unused_reactive_state` (github.com/CriandoGames/all_observer_lint). Implementing this proposal as specified fully closes this competitive gap — see `plans/GAP_ANALYSIS.md` "all_observer_lint" section (0/20 coverage).

---

## Motivation

An `Observable` that nothing ever reads is worse than an unused plain field: the analyzer's built-in `unused_field` lint does not know to look inside reactive wrapper types, and the observable machinery keeps allocating change-notification infrastructure for a value nobody consumes. This is a maintenance-debt/dead-code class specific to reactive-state libraries that saropa has no visibility into today.

---

## Detection / Behavior

Flag a class field declared as `Observable<T>`/`Computed<T>` where no `.value` read (outside its own declaration/constructor initializer) exists anywhere in the class body, and the field is not exposed via a public getter used elsewhere.

### Should flag (bad code)

```dart
class SettingsStore {
  final darkMode = Observable(false); // LINT — never read anywhere

  void toggleDarkMode() {
    darkMode.value = !darkMode.value; // write-only, still unread by any consumer
  }
}
```

### Should pass (good code)

```dart
class SettingsStore {
  final darkMode = Observable(false);

  bool get isDark => darkMode.value; // OK — read via public getter

  void toggleDarkMode() {
    darkMode.value = !darkMode.value;
  }
}
```

---

## Proposed Tier

Tier: Comprehensive
Justification: Package-specific rule (`all_observer` dependency required); dead-state detection is a hygiene concern, not correctness-critical.

---

## Edge Cases

1. **Field exposed via a public getter that is itself unused project-wide** — should discuss; may need cross-file reasoning (saropa's cross-file analysis tooling) to fully resolve, otherwise ship as single-file heuristic that trusts any public getter as "used."
2. **Field only referenced inside `toString()`/debug logging** — should pass; that counts as a read.
3. **Field referenced only in test files** — should pass; tests are legitimate consumers.
4. **`all_observer` package not a project dependency** — rule should no-op entirely.

---

## Alternatives Considered

- **Rely on the Dart analyzer's built-in unused-field lint** — rejected; the built-in lint does not special-case `.value` mutation-only patterns and would not flag write-only `Observable` fields since the field itself IS referenced (just never read).

---

## Decision

---

## Implementation Notes

---

## Commits
