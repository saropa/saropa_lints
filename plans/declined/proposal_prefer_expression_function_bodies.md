# PROPOSAL: Prefer Expression Function Bodies

**Status: Declined**

Created: 2026-09-02

## Summary

Flags a function/method with a block body (`{ ... }`) containing only a single `return` statement, which should be rewritten as an expression body (`=> ...`).

## Existing Coverage

`PreferArrowFunctionsRule` (`prefer_arrow_functions`, `lib/src/rules/stylistic/stylistic_rules.dart:299`) already implements this exact behavior for function declarations and method bodies with a single return statement, including the identical example pair (`{ return a + b; }` → `=> a + b;`). `PreferExpressionBodyGettersRule` (same file, line 410) covers the getter-specific variant. **This proposal is a duplicate of the already-shipped `prefer_arrow_functions`** — no new rule should be added under this name.

## Motivation

A single-statement `return` body wrapped in braces is more verbose than necessary and obscures that the function is a pure, single-expression computation. Arrow syntax is the idiomatic Dart style for such functions.

## Detection / Behavior

See `PreferArrowFunctionsRule` for the shipped implementation.

```dart
// BAD
int add(int a, int b) { return a + b; }

// GOOD
int add(int a, int b) => a + b;
```

## Quick Fix

Already implemented by `prefer_arrow_functions`: convert the block body to `=> expression;`.

## Alternatives Considered

None — this proposal should be closed as a duplicate rather than implemented separately.
