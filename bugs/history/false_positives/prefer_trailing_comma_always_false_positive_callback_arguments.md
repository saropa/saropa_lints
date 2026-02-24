# False positive: `prefer_trailing_comma_always` — callback arguments

## Status: FIXED

## Problem

The rule flagged multi-line argument lists where the last argument was a callback/closure whose body spanned lines, suggesting awkward `},)` patterns. The `_isMultiLine` check didn't distinguish between arguments on separate lines vs. a callback body spanning lines.

## Fix

Skip reporting when the last argument (positional or named) is a `FunctionExpression`. Applied to argument lists, list literals, and set/map literals via `_lastArgIsCallback()` helper in `stylistic_rules.dart`.

## Files changed

- `lib/src/rules/stylistic_rules.dart` — added callback detection
- `example_style/lib/stylistic/prefer_trailing_comma_always_fixture.dart` — real test cases
