# Not Viable: `require_drift_table_column_trailing_parens`

## Status: NOT VIABLE

## Proposed Rule
Warn when a Drift table column definition is missing the trailing `()` terminator.

## Why Not Viable
**Compiler already catches this.** Each Drift column definition must end with `()` (e.g., `integer().autoIncrement()()`). Omitting the trailing parentheses produces a compile-time error — the code simply won't build. A lint rule would be redundant since the Dart compiler provides the error before any analysis runs.

## Category
Redundant — compiler-enforced constraint.
