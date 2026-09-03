# PROPOSAL: Avoid FutureOr Return Type

**Status: Open**

Created: 2026-09-02

**Closes gap:** `flutter_skill_lints` `avoid_futureor_return_type` (pub.dev). Implementing this rule closes this competitive gap — see `plans/GAP_ANALYSIS.md`.

## Summary

Flags functions that declare `FutureOr<T>` as their return type, which forces callers into runtime type-checking (`is Future`) branches.

## Existing Coverage

Saropa already has `prefer_unwrapping_future_or` (`code_quality_prefer_rules.dart`) which flags `FutureOr` usage requiring manual type checking. This proposal may be closeable by extending that rule's scope to cover return-type declarations specifically, or by confirming it already does.

## Detection / Behavior

```dart
// Bad
FutureOr<int> getValue() => 42;

// Good
Future<int> getValue() async => 42;
int getValueSync() => 42;
```

## Quick Fix

Split into two overloads or pick one concrete return type (sync or async).

## Alternatives Considered

- Closing as HAVE if `prefer_unwrapping_future_or` already covers this pattern — verify before implementing.
