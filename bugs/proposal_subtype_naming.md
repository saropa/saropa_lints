# PROPOSAL: Flag Class Names That Don't Reflect Their Base-Type Relationship

**Status: Open**

Created: 2026-09-02
Type: New rule
Related rules: none

---

## Summary

Add `subtype_naming` to flag a class that extends or implements a well-known base type (starting with `Exception`) whose own name does not carry a naming cue reflecting that relationship — e.g. a class `extends Exception` (or `implements Exception`) whose name doesn't end in `Exception`/`Error`/`Failure`.

**Closes gap:** essential_lints `subtype_naming` (github.com/FMorschel/essential_lints). Implementing this proposal as specified fully closes this competitive gap — see `plans/GAP_ANALYSIS.md`.

---

## Motivation

A class named `NetworkTimeout` that `extends Exception` reads, at the call site (`throw NetworkTimeout();`, `catch (e)` blocks, log output), as an ambiguous noun rather than an obviously-throwable type — a reader scanning a `catch` clause or a stack trace benefits from the name itself signaling "this is an exception type." essential_lints ships `subtype_naming` as a general base-type-naming convention; this proposal scopes saropa's initial implementation to its clearest, lowest-false-positive case — `Exception` subtypes — rather than attempting the full generality of the upstream rule (which may also cover `Error` subtypes and other base-type families) on first pass.

---

## Detection / Behavior

Flag a class declaration whose `extends` clause or `implements` clause includes `Exception` (directly, or `implements Exception` on a class that also implements other interfaces) where the class's own simple name does not end in `Exception`, `Error`, or `Failure`.

### Should flag (bad code)

```dart
// LINT — subtype_naming: extends Exception but name doesn't signal it.
class NetworkTimeout extends Exception {
  final String message;
  NetworkTimeout(this.message);
}
```

### Should pass (good code)

```dart
// OK — name ends in Exception.
class NetworkTimeoutException extends Exception {
  final String message;
  NetworkTimeoutException(this.message);
}

// OK — name ends in Failure, a recognized alternative convention
// (e.g. functional-error-handling codebases using Either<Failure, T>).
class NetworkTimeoutFailure implements Exception {
  final String message;
  NetworkTimeoutFailure(this.message);
}
```

---

## Proposed Tier

Tier: Comprehensive
Justification: Naming-convention rule with real false-positive risk if scope creeps beyond the `Exception` case (see Edge Cases) — appropriate for a deep style/consistency pass, not a default-on rule.

---

## Edge Cases

1. **Needs discussion — verify against upstream `essential_lints` source before implementing; semantics below are inferred from the rule name and general Dart-typing conventions, not confirmed against source.** The exact set of base types upstream covers (just `Exception`, or also `Error`, `StatelessWidget`/`StatefulWidget`, others) is unconfirmed.
2. **`Error` subtypes and widget base types (`StatelessWidget`/`StatefulWidget`) — likely too broad to flag reliably.** A class `extends StatelessWidget` whose name doesn't read as a "widget name" at all is a much fuzzier, subjective judgment (there's no fixed suffix convention like `*Widget` in idiomatic Flutter code — most widget classes are named for what they render, e.g. `LoginButton`, `ProfileCard`, with no suffix at all). Including this in v1 risks a high false-positive rate across ordinary, well-named widget classes. Recommend scoping the initial implementation to `Exception` only, and treating `Error`/widget-base-type coverage as a separate, future extension pending more confidence in the false-positive rate.
3. **Multiple interfaces where `Exception` is one of several (`class Foo implements Exception, Comparable<Foo>`)** — should still flag if the name doesn't end in the recognized suffixes; the rule cares about the `Exception` relationship regardless of what else is implemented.
4. **Abstract base exception classes meant to be extended further (`abstract class AppException implements Exception {}`)** — should pass; `AppException` ends in `Exception`.
5. **`Failure` as an accepted suffix** — included because functional-error-handling patterns (`Either<Failure, T>`) commonly name domain error types `*Failure` rather than `*Exception` while still implementing `Exception` for interop with `try`/`catch`. Confirm this is intentional scope, not an upstream deviation, when verifying against essential_lints source.

---

## Alternatives Considered

- **Cover `Error` subtypes in the same rule from day one** — rejected for v1 per the false-positive concern in Edge Case 2; revisit once `Exception`-only coverage is validated.
- **Cover widget base types (`StatelessWidget`/`StatefulWidget`)** — rejected outright as likely too broad/subjective for a reliable static rule; Flutter naming conventions don't consistently suffix widget class names.
- **Configurable suffix list via `analysis_options_custom.yaml`** — plausible follow-up if teams want project-specific suffixes beyond `Exception`/`Error`/`Failure`; not required for the initial fixed-suffix version.

---

## Decision

---

## Implementation Notes

---

## Commits
