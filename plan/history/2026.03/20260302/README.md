# bugs/history — grouped layout

Historical notes, resolved bugs, and planning docs for saropa_lints. Files are grouped by type:

| Subfolder | Contents |
|-----------|----------|
| **false_positives/** | Rule-specific false positive reports and reduction notes (e.g. `avoid_*_false_positive_*.md`, FP reviews). |
| **rule_bugs/** | Bugs in specific rules: severity/tier/docs/regression, ignore not respected, analyzer crashes, deduplication, quick fixes. |
| **issues/** | GitHub-issue-style notes (`issue_XXX_*.md`). |
| **migration/** | Analyzer/migration plans and migration-candidate notes (e.g. native plugin, framework deprecations). |
| **plans/** | Strategy and planning docs: drift support, file structure, roadmap, versioning, test coverage, tier/severity analysis. |
| **todos/** | Missing-rule / todo items (`todo_XXX_*.md`). |
| **releases/** | Release and CI notes (e.g. version tags, analyzer fixes). |
| **completed/** | One-off completed items (e.g. fixture/instantiation work). |

Existing subfolders:

- **roadmap/** — Task specs and summary docs; grouped by emoji prefix (see `roadmap/README.md`): `summary/`, `task_warning/` (⚠️), `task_info/` (ℹ️), `task_star/` (⭐), `task_octopus/` (🐙), `task/` (plain).
- **not_viable/** — not-viable rules (e.g. drift, framework_upgrade migration candidates).

## Summary (this reorganization)

- **false_positives/** — 2 files (remaining FP notes; 82 integrated files removed).
- **rule_bugs/** — 2 files (remaining rule-bug notes; 22 integrated files removed).
- **issues/** — (integrated issue docs removed.)
- **migration/** — (integrated migration docs removed.)
- **plans/** — 7 files (drift, file structure, roadmap native, versioning, test coverage, tier/severity).
- **todos/** — 4 files (missing iOS/platform rules).
- **releases/** — 2 files (v4.12.2 config, CI analyzer fixes).
- **completed/** — 1 file (unit test coverage fixtures/instantiation).
