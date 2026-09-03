# PROPOSAL: Flag `throw 'string'`/`throw Exception('message')` — Use a Typed Exception Class

**Status: Open**

Created: 2026-09-02
Type: New rule
Related rules: none

---

## Summary

Add `prefer_typed_exceptions` to flag `throw` statements whose thrown expression is a raw `String` literal or a generic `Exception(...)`/`Error(...)` constructor call, recommending a project-defined, purpose-specific `Exception` subclass instead — so callers can `catch (e) { if (e is MySpecificException) ... }` rather than pattern-matching on message text.

**Closes gap:** many_lints `prefer_typed_exceptions`. Implementing this proposal as specified fully closes this competitive gap — see `plans/GAP_ANALYSIS.md` many_lints non-themed gaps.

---

## Motivation

`throw 'Something went wrong';` throws a bare `String`, which is legal in Dart but cannot be caught selectively by type (`catch (e) { ... }` sees an `Object`, and any `on String catch` is unusual and fragile) — every catch site is forced to either catch everything or inspect message text, which breaks the moment the message wording changes. `throw Exception('...')` is only marginally better: it's catchable as `Exception`, but every generic exception in the codebase collapses to the same type, so a caller still cannot distinguish "network failure" from "validation failure" without string-matching the message. A project-defined exception subclass (`class NetworkException implements Exception { ... }`) gives callers a real type to branch on.

---

## Detection / Behavior

Flag any `ThrowExpression`/`throw` statement whose thrown value is: (a) a `String` literal or `StringLiteral`-typed expression, or (b) an unqualified `Exception(...)`/`Error(...)` SDK constructor call (not a subclass — flagging every `Exception` subtype would defeat the rule's own purpose).

### Should flag (bad code)

```dart
void validate(int age) {
  if (age < 0) {
    throw 'Age cannot be negative'; // LINT — throwing a raw String; define a typed exception
  }
  if (age > 150) {
    throw Exception('Age is unrealistic'); // LINT — generic Exception; define a typed exception
  }
}
```

### Should pass (good code)

```dart
class InvalidAgeException implements Exception {
  const InvalidAgeException(this.message);
  final String message;
}

void validate(int age) {
  if (age < 0) {
    throw const InvalidAgeException('Age cannot be negative'); // OK
  }
}
```

---

## Proposed Tier

Tier: Comprehensive
Justification: architectural-hygiene rule with real long-term maintainability value but no immediate correctness bug in the flagged code itself; requires the project to author a new exception class per call site rather than offering a purely mechanical rewrite, so it sits above Pedantic but below Essential/Recommended's bug-catching bar.

---

## Edge Cases

1. **`throw ArgumentError(...)`/`throw StateError(...)`/`throw RangeError(...)` (SDK-specific `Error` subclasses, not the bare `Exception`/`Error` base)** — should pass; these are already meaningfully typed and catchable by their specific class, unlike the raw base types this rule targets.
2. **`throw Exception(e)` where `e` is itself a caught, already-typed exception being rethrown/wrapped** — should still flag the outer `Exception(...)` wrap, since it still collapses the type information; recommend `rethrow` or wrapping in a typed exception that carries the original as a `cause` field instead.
3. **Test files throwing a raw `String`/`Exception` to simulate a failure for a test case** — should pass; test-file exemption is consistent with saropa's general test-scope leniency for developer-diagnostic patterns (verify against saropa's existing test-file exemption conventions before finalizing).
4. **A rethrow of a caught exception (`rethrow;`) — not a new `throw` at all** — not applicable; the rule only inspects `throw <expr>`, and `rethrow` has no expression to inspect.

---

## Alternatives Considered

- **Quick fix that auto-generates a new exception class** — deferred; naming a new exception class meaningfully requires understanding the failure domain, which is not something a mechanical fix can infer safely. Flag now, consider fix tooling later.

---

## Decision

---

## Implementation Notes

---

## Commits
