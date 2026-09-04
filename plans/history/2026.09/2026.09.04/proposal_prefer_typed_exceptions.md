# PROPOSAL: Flag `throw 'string'`/`throw Exception('message')` — Use a Typed Exception Class

**Status: Implemented**

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

Approved with a narrower scope than originally drafted: this rule flags ONLY
bare-`String` throws (`throw 'text';`, `throw someStringVariable;`, `throw
buildMessage();` where the static type is `String`). The proposal's
Detection/Behavior section and "Should flag" example (line 37) originally
described this rule as also flagging `throw Exception(...)`/`throw
Error(...)`, but that case is already owned by the pre-existing
`avoid_generic_exceptions` rule (`lib/src/rules/flow/error_handling_rules.dart`,
`{v4}`). Flagging both cases here would double-report the same
`throw Exception(...)` call site under two different rule names, so the
scope was narrowed at implementation time rather than shipping a duplicate
diagnostic.

## Implementation Notes

- `PreferTypedExceptionsRule` (`lib/src/rules/flow/prefer_typed_exceptions_rules.dart`)
  handles two AST shapes: a `StringLiteral` thrown directly (no type
  resolution needed, also covers interpolated strings), and any other
  expression whose resolved `staticType.isDartCoreString` is true (covers
  `String`-typed variables and function calls). `Exception(...)`/`Error(...)`
  constructor calls are `InstanceCreationExpression` nodes, not
  `StringLiteral` and not `String`-typed, so they fall through untouched and
  are left to `avoid_generic_exceptions`.
- Doc comments on both rules now cross-reference each other
  (`prefer_typed_exceptions_rules.dart:19-22` and
  `error_handling_rules.dart`'s `AvoidGenericExceptionsRule` doc comment) so
  the scope split is discoverable from either rule.
- Test-file exemption (proposal Edge Case 3) is inherited, not overridden:
  the rule does not implement `testRelevance`, so it uses `SaropaLintRule`'s
  default `TestRelevance.never`. This is now pinned by an explicit test
  (`test/rules/flow/prefer_typed_exceptions_test.dart`) rather than left as
  an unverified assumption.
- Problem message length assertion in the test was tightened from
  `greaterThan(50)` to `greaterThan(200)` to match the project's Problem
  Message Requirement (CLAUDE.md) and actually guard against a future
  message-length regression.

---

## Commits

## Finish Report (2026-09-04)

### Issues

None identified. Core AST logic (`lib/src/rules/flow/prefer_typed_exceptions_rules.dart:96-115`) is correct for its declared scope: the `StringLiteral` branch (line 102) catches both plain and interpolated string literals without needing type resolution, and the `staticType.isDartCoreString` branch (line 111-113) catches non-literal String-typed expressions (variables, method calls). No false-negative was found within that scope, and no crash/exception path was found (both branches are null-safe: `staticType` is nullable and checked before use).

### Concerns

- **Test assertion weaker than the documented standard.** `test/rules/flow/prefer_typed_exceptions_test.dart:15` asserts `problemMessage.length, greaterThan(50)`, but the project's own Problem Message Requirement (CLAUDE.md) is >200 chars. The actual message is ~420 chars today, so it currently passes both thresholds, but the test as written would not catch a future edit that shrinks the message to, say, 100 chars. Recommend tightening to `greaterThan(200)`.
- **Proposal/implementation scope mismatch never reconciled in this doc.** The proposal's Detection/Behavior section (lines 25-40) and its "Should flag" example (line 37: `throw Exception('Age is unrealistic'); // LINT`) describe flagging both bare-`String` throws AND generic `Exception(...)`/`Error(...)` calls. The shipped rule deliberately narrows to bare-`String` only (see doc comment at `prefer_typed_exceptions_rules.dart:19-22`), delegating the `Exception(...)`/`Error(...)` case to the pre-existing `avoid_generic_exceptions` rule (`lib/src/rules/flow/error_handling_rules.dart:272`, already at `{v4}`) to avoid double-reporting the same violation under two rule names. This is the right call — verified: `avoid_generic_exceptions` already fires on `InstanceCreationExpression` throws (`error_handling_rules.dart:307`) — but the proposal's own "Decision" and "Implementation Notes" sections (lines 81-87) were left blank, so nothing in this document records that the scope was intentionally narrowed. A future reader skimming only the proposal would expect `throw Exception(...)` to be flagged by this rule and be confused when it isn't.
- **Edge Case 3 (test-file exemption, proposal line 70) was never explicitly verified against this rule**, per the proposal's own instruction to "verify against saropa's existing test-file exemption conventions before finalizing." It works out fine: `PreferTypedExceptionsRule` does not override `testRelevance`, so it inherits `SaropaLintRule`'s default `TestRelevance.never` (`lib/src/saropa_lint_rule.dart:2825-2832`), which skips test files automatically. But this is implicit inheritance, not a checked-off verification, and there's no fixture/test proving it.
- Unexercised (low-risk) type-resolution paths: a ternary mixing a string literal and a typed-exception branch (`throw cond ? 'a' : SomeException();`), and a `const`/top-level `String` value thrown directly, both hit the same `staticType.isDartCoreString` branch already covered by `validateVariable`/`validateBuiltMessage` in the fixture, so risk of an actual bug here is low.

### Opportunities

- `avoid_generic_exceptions`'s doc comment does not cross-reference `prefer_typed_exceptions` (only this rule's doc links back to that one, at lines 19-22). Adding the reverse link would make the scope split discoverable from either rule.
- No code duplication found — the `context.addThrowExpression` visitor hook and `requiredPatterns` prefilter pattern are reused consistently with the existing `avoid_generic_exceptions` rule; no further consolidation opportunity.

### Recommendations

1. **(Do first, trivial)** Tighten `test/rules/flow/prefer_typed_exceptions_test.dart:15` from `greaterThan(50)` to `greaterThan(200)` to match the documented Problem Message Requirement and make the test actually guard against message-length regression.
2. **(Documentation, low effort)** Fill in this proposal's "Decision" and "Implementation Notes" sections to record that the rule was intentionally scoped to bare-`String` throws only, with `Exception(...)`/`Error(...)` throws left to `avoid_generic_exceptions` — so the proposal stops disagreeing with the shipped code.
3. **(Optional)** Add one fixture case exercising the test-file exemption assumption (or at minimum a one-line note in the fixture file confirming `TestRelevance.never` is inherited, not overridden) so the proposal's Edge Case 3 has a recorded verification instead of an implicit default.
4. **(Optional, cosmetic)** Add a reverse doc-comment cross-reference from `avoid_generic_exceptions` to `prefer_typed_exceptions`.
