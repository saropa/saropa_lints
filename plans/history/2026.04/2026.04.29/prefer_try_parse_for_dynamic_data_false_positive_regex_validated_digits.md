# BUG: `prefer_try_parse_for_dynamic_data` — Fires on Regex-Validated Digit-Only Input

**Status: Fixed**

Created: 2026-04-29  
Archived: 2026-04-29  
Rule: `prefer_try_parse_for_dynamic_data`

---

## Summary

`prefer_try_parse_for_dynamic_data` previously flagged all `*.parse(...)` calls outside `try/catch`, including inputs that were already statically safe (valid literals, digit-only regex captures, and digit-only regex-guarded substrings).

## Root Cause

The rule only checked:
- parse target type (`int`, `double`, `num`, `BigInt`, `Uri`)
- lexical ancestry for `TryStatement`

It did not inspect argument provenance/safety, which caused false positives.

## Implemented Fix

`PreferTryParseForDynamicDataRule` now suppresses diagnostics when argument safety is provable:

- parseable string literals for the target parse type
- `RegExpMatch` capture reads (`rx[index]`, `rx.group(index)`) with digit-only capture-group patterns
- `substring(...)` expressions guarded in the same block by `!regex.hasMatch(token)` + `continue`/`return`, where the regex is digit-only

## Tests Added

- Expanded fixture:
  - `example/lib/json_datetime/prefer_try_parse_for_dynamic_data_fixture.dart`
  - includes BAD dynamic/invalid cases and GOOD provably-safe cases
- Added integration regression:
  - `test/fixture_lint_integration_test.dart`
  - `prefer_try_parse_for_dynamic_data skips provably safe regex/literal inputs`

## Validation

- `dart test test/fixture_lint_integration_test.dart` ✅
- `dart test test/json_datetime_rules_test.dart` ✅

