# Bug Report Cleanup: Dio Singleton + Dependabot js-yaml

Two bug reports in `bugs/` were malformed: one used the retired `custom_lint_builder` API in code examples and lacked standard metadata; the other was raw paste from the GitHub PR page with no actionable structure.

## Finish Report (2026-07-23)

### Changes

1. **`bugs/require_dio_singleton_vs_avoid_singleton_pattern.md`** — Rewrote from verbose analysis-document into a structured bug report. Removed code examples referencing the retired `custom_lint_builder` API (`DartLintRule`, `CustomLintResolver`, `ErrorReporter`, `CustomLintContext`). Added correct API references (`SaropaLintRule`, `SaropaDiagnosticReporter`). Preserved the core analysis: `require_dio_singleton` enforces static singletons while `avoid_singleton_pattern` penalizes them; the former is architecturally wrong for resource-holding types like `Dio`. Added concrete AST edge cases (static getters, late init, global caching functions) and linked to the actual rule source files.

2. **`bugs/update_deps.md`** — Replaced raw GitHub PR paste with a proper bug report identifying the two blockers (workflow approval + `analysis_options.yaml` merge conflict) and resolution steps. PR #271 is Dependabot bumping `js-yaml` 4.1.1 to 4.3.0 in `extension/`.

3. **`CHANGELOG.md`** — Added `[Unreleased]` section with Maintenance entries for both bug report changes.

### Not Changed

- No Dart code, no rules, no tests, no extension code modified.
- `locale_coverage.json` timestamp change was pre-existing and not staged.
