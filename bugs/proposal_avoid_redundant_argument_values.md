# PROPOSAL: Avoid Redundant Argument Values

**Status: Open**

Created: 2026-09-02

## Summary

Flags a call-site argument whose literal value is identical to the parameter's declared default value, since passing it is a no-op that adds noise without changing behavior.

## Existing Coverage

`AvoidPassingDefaultValuesRule` (`avoid_passing_default_values`, `lib/src/rules/code_quality/code_quality_avoid_rules.dart:3402`) already implements this exact behavior: it inspects `MethodInvocation` and `InstanceCreationExpression` argument lists and reports when an argument's value matches the parameter's default. **This proposal is a duplicate of an already-shipped rule** — no new rule should be added under this name; if a distinct name is wanted for discoverability, prefer aliasing/documenting `avoid_passing_default_values` rather than shipping a second rule with overlapping detection logic.

## Motivation

Explicitly passing a value equal to a parameter's default clutters call sites and creates a false signal that the value was deliberately chosen, when in fact it's just restating the default. If the library author later changes the default, call sites that redundantly pinned the old value silently stop tracking the new default — a maintenance trap.

## Detection / Behavior

See `AvoidPassingDefaultValuesRule` for the shipped implementation.

```dart
// BAD
void log(String message, {bool verbose = false}) { /* ... */ }
log('hi', verbose: false); // false is already the default

// GOOD
void log(String message, {bool verbose = false}) { /* ... */ }
log('hi');
```

## Quick Fix

Already implemented by `avoid_passing_default_values`: omit the redundant argument.

## Alternatives Considered

None — this proposal should be closed as a duplicate rather than implemented separately.
