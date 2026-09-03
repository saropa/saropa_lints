# PROPOSAL: Flag Invalid History Limit Configuration on Observer Constructors

**Status: Open**

Created: 2026-09-02
Type: New rule
Related rules: none

---

## Summary

Add `invalid_history_limit` to flag a non-positive or otherwise invalid `historyLimit`/`limit` argument passed to an observer-style constructor (e.g. a navigation/state history observer) — `0`, negative literals, or a value statically known to be invalid at the call site.

**Closes gap:** `all_observer_lint` `invalid_history_limit` (pub.dev). Implementing this proposal as specified fully closes this competitive gap — see `plans/GAP_ANALYSIS.md`.

---

## Motivation

History-tracking observers (navigation stacks, undo/redo, state-change logs) accept a bound on how many entries to retain. A limit of `0` or a negative number is either a silent no-op (nothing ever retained) or a runtime `ArgumentError`/`RangeError` depending on the implementation — either way it's a configuration mistake the analyzer can catch at the call site instead of at runtime.

---

## Detection / Behavior

Flag a constructor invocation matching the observer's `historyLimit:`/`limit:` named parameter when the argument is an integer literal `<= 0`, or a compile-time constant expression that evaluates to `<= 0`.

### Should flag (bad code)

```dart
final observer = HistoryObserver(historyLimit: 0); // LINT — a limit of 0 retains no history, defeating the observer's purpose
final observer2 = HistoryObserver(historyLimit: -5); // LINT — negative limit is invalid
```

### Should pass (good code)

```dart
final observer = HistoryObserver(historyLimit: 50); // OK — positive, meaningful limit
```

---

## Proposed Tier

Tier: Professional
Justification: Package-specific runtime-error/no-op prevention rule for a configuration value; parallels other saropa rules that validate constructor argument ranges.

---

## Edge Cases

1. **Limit passed as a non-literal expression (e.g. a config field)** — cannot be statically evaluated; should pass (no false positive on dynamic values), unless it resolves as a compile-time constant.
2. **Limit of exactly `1`** — should pass; retaining a single entry is a valid, if minimal, configuration.
3. **`historyLimit: null` where the parameter is nullable and means "unlimited"** — should pass; `null`/unset is a distinct, valid "no limit" case, not an invalid one.
4. **Double literal instead of int (e.g. `historyLimit: 10.0`)** — out of scope for this rule; a type-mismatch would already be caught by the analyzer's own type checking if the parameter is typed `int`.

---

## Alternatives Considered

---

## Decision

---

## Implementation Notes

---

## Commits
