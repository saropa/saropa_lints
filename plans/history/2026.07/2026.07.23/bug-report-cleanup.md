# Bug Report Cleanup: Dio Singleton + Dependabot js-yaml

Two bug reports in `bugs/` needed revision: one used the retired `custom_lint_builder` API in code examples and overstated the rule contradiction; the other was unstructured notes from the GitHub PR page.

## Finish Report (2026-07-23)

### Changes

1. **`bugs/require_dio_singleton_vs_avoid_singleton_pattern.md`** — Restructured into an actionable bug report. Removed code examples referencing the retired `custom_lint_builder` API (`DartLintRule`, `CustomLintResolver`, `ErrorReporter`, `CustomLintContext`). Added correct API references (`SaropaLintRule`, `SaropaDiagnosticReporter`). Clarified the contradiction: `avoid_singleton_pattern` requires the full GoF singleton (static instance + factory constructor + private constructor), so a bare `static final Dio` field does not trigger it directly — the conflict is architectural, not a direct rule collision. `require_dio_singleton` steers toward an anti-pattern that, fully implemented, triggers `avoid_singleton_pattern`. Added AST edge cases and linked to actual rule source files.

2. **`bugs/update_deps.md`** — Structured as a proper bug report. Updated status to Closed (unmerged) after verifying PR #271 state via `gh pr view`. Later confirmed js-yaml already at 4.3.0 in lock file (transitive via mocha); marked Fixed and archived to `plans/history/2026.07/2026.07.23/`.

3. **`CHANGELOG.md`** — Added `[Unreleased]` section with Maintenance entries.

### Verified During Hardening

- `require_dio_singleton` rule confirmed at `dio_rules.dart:620` — flags inline `Dio()`, accepts `static final` (GOOD example at line 616-618).
- `avoid_singleton_pattern` rule confirmed at `architecture_rules.dart:611` — requires all three GoF elements, not just a static field.
- PR #271 confirmed CLOSED (not merged) via GitHub API.
- Both rule file paths in the bug report are correct and current.

### Not Changed

- No Dart code, no rules, no tests, no extension code modified.
