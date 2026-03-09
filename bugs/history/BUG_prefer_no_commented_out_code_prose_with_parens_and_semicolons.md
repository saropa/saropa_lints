# Bug: `prefer_no_commented_out_code` false positive on prose with parenthetical ranges and English semicolons

**Status:** Fixed

## Summary

`_hasStrongCodeIndicators` treated bare `()` presence and any `;` as "unambiguous code", bypassing the prose guard. This caused false positives on natural English prose that uses parenthetical notes (e.g., `(see docs)`, `(0.25×–4×)`) and clause-joining semicolons.

## Fix

Refined `_hasStrongCodeIndicators` in `comment_utils.dart`:

- **Removed** bare `content.contains(';')` — semicolons alone are not strong code indicators.
- **Replaced** `content.contains('(') && content.contains(')')` with `\w\(` regex — only matches when an identifier immediately precedes `(` (function calls like `foo()`), not prose parentheticals.
- **Added** control-flow keyword check (`if`, `for`, `while`, `switch`, `catch`, `try` + paren) to preserve detection of patterns like `for (int i in list)`.
- **Extracted** regex patterns as `static final` fields for performance.

## Test Coverage

- 6 new unit tests in `comment_utils_test.dart` for prose with parenthetical notes and semicolons.
- 5 new fixture entries in `prefer_no_commented_out_code_fixture.dart`.
- All 55 comment_utils tests pass, full suite (7959 tests) passes with zero regressions.

## Original Report Date

2026-03-08
