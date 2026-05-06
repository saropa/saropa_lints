# Bug Report (resolved): `avoid_long_parameter_list` False Positive for `copyWith` and All-Optional Params

**Rule:** `avoid_long_parameter_list`  
**Date:** 2026-03-03  
**Status:** Fixed (2026-03-03)

## Summary

The rule reported on every function/method with more than 5 parameters with no exceptions for (1) methods named `copyWith` (standard Dart/Flutter immutable-update pattern) or (2) declarations where all parameters are optional (no required positional or required named). Those patterns are self-documenting and do not match the rule’s intent (avoid hard-to-call, combinatorial APIs), so reporting was a false positive.

## Fix

- **Option A:** Skip reporting when the method or function name is `copyWith`.
- **Option B:** Skip reporting when every parameter is optional (no `isRequiredPositional` or `isRequiredNamed`).

Implemented in `AvoidLongParameterListRule` (`lib/src/rules/structure_rules.dart`) via `_shouldSkipLongParameterList`. Fixture and tests updated; CHANGELOG and rule DartDoc updated.

## References

- Original report: (this file; content was in `bugs/BUG_REPORT_avoid_long_parameter_list_copyWith_false_positive.md` before move.)
- Related: `bugs/history/rule_bugs/avoid_long_parameter_list_ignore_not_respected.md` (ignore directive placement; different issue).
- Fixture: `example_core/lib/structure/avoid_long_parameter_list_fixture.dart`.
