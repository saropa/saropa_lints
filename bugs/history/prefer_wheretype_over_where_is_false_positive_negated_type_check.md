# `prefer_wheretype_over_where_is` false positive on negated `is!` type checks

## Status: FIXED (v4.14.5)

## Summary

The rule fired on `.where((e) => e is! T)` (negated type check), but `whereType<T>()` only filters *for* a type — there is no Dart equivalent for exclusion. The auto-fix would also produce semantically incorrect code by replacing exclusion with inclusion.

## Root Cause

`IsExpression` AST node represents both `is` and `is!`. The rule never checked `expr.notOperator` to distinguish them.

## Fix

Added `if (expr.notOperator != null) return;` guard in both the lint visitor and the auto-fix in `lib/src/rules/stylistic_null_collection_rules.dart`.
