# Not Viable: `avoid_drift_multiple_auto_increment`

## Status: NOT VIABLE

## Proposed Rule
Warn when a Drift table has more than one `autoIncrement()` column.

## Why Not Viable
**SQLite enforces this constraint.** Defining multiple auto-increment columns in a single table produces a compile-time error from Drift's code generator. The generated code will not compile, so this issue is caught before any lint analysis runs.

## Category
Redundant — compiler/code-generator-enforced constraint.
