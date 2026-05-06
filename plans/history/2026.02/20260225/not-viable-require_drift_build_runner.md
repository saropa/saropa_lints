# Not Viable: `require_drift_build_runner`

## Status: NOT VIABLE

## Proposed Rule
Warn when Drift-generated code (`.g.dart` / `.drift.dart`) is stale or missing.

## Why Not Viable
**Workflow/tooling concern, not a code pattern.** Lint rules analyze source code at rest — they cannot detect whether `build_runner` has been run recently or whether generated files are stale. The generated files either exist (and analysis proceeds) or don't (and compilation fails). There is no AST-level signal that indicates staleness.

## Category
Undetectable — requires build system state, not source analysis.
