# Bug: `prefer_for_in` false positive on numeric counter loops

## Status: FIXED (v5)

## Summary

The rule fired on every `for (var i = 0; i < N; i++)` loop regardless of whether `N` was a `.length` property access. This caused false positives on pure numeric counter loops (literal bounds like `12`, variable bounds like `count`) where there is no collection to for-in over.

## Fix

Added a check in `runWithReporter` that the condition's right operand is a `.length` property access (via `PrefixedIdentifier` or `PropertyAccess`). Loops with literal, variable, or other non-`.length` upper bounds are now skipped.

## Files Changed

- `lib/src/rules/code_quality/code_quality_prefer_rules.dart` — added `.length` guard
- `example_core/lib/code_quality/prefer_for_in_fixture.dart` — added false positive test cases
- `test/code_quality_rules_test.dart` — added test coverage for skipped patterns

## Original Report Date: 2026-03-08
