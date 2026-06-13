# Publish dependency-import gate

Two consecutive releases (v13.12.6 and v13.12.7) failed at the pub.dev publish
step because eight rule files under `lib/` import `package:meta/meta.dart`
while `meta` was only a transitive dependency, never declared under pubspec
`dependencies`. `dart pub publish` rejects a package that imports a package it
does not directly depend on (7 errors, exit 65/66), but that rejection only
occurs on the tag-triggered GitHub Actions publish job — after the version tag
has already been pushed and burned. No earlier gate caught it: `lib/**` is in
`analyzer.exclude` (plugin dogfooding), so no `dart analyze` run inspects lib/
imports, and the exit code of `dart pub publish --dry-run` for a missing
dependency differs by Dart SDK version (a non-fatal warning on 3.10.x/3.12.1, a
hard rejection on the publish job's `stable` SDK). The release pipeline could
therefore tag and push a build that pub.dev would refuse.

## Finish Report (2026-06-13)

### 1. Critical Note

This work will be reviewed by another AI.

### 2. Scope

**(C) docs/scripts only** — release tooling (`scripts/`), CI workflow
(`.github/workflows/ci.yml`), the package manifest (`pubspec.yaml` /
`pubspec.lock`), and `CHANGELOG.md`. No Dart lint rules, analyzer plugin code,
`tiers.dart`, `example/`, or `analysis_options*.yaml` were touched.

### 3. Deep Review

- **Logic & Safety**: The import scan bounds matching to each file's directive
  header — Dart grammar requires all `import`/`export`/`part` directives to
  precede the first declaration, so scanning stops at the first non-directive,
  non-comment, non-blank line. This excludes the thousands of `package:` URIs
  embedded in rule detection patterns and Bad/Good DartDoc examples inside rule
  bodies, which would otherwise produce massive false positives. Verified
  against the live tree: zero false positives, and the simulated
  meta-undeclared case reproduces exactly the 7 files `dart pub publish`
  flagged (the 8th grep hit is a `meta` reference inside a string and is
  correctly ignored — matching pub's own behavior).
- **Architecture & Adherence**: A single source of truth,
  `get_dependency_import_status` in `scripts/modules/_audit_checks.py`, backs
  both the release-audit gate (`_audit.py`) and the standalone CI script
  (`scripts/check_dependency_imports.py`). The audit wiring mirrors the
  existing `get_contains_audit_status` / stub-guard pattern: a status function
  returns data, `run_audit` builds the pass/fail check tuple and sets a blocking
  flag on `AuditResult`. The CI script reuses publish.py's `sys.path` bootstrap.
- **Linter-Specific Integrity**: Not applicable — no rules, tiers, impacts, or
  quick fixes changed.
- **Performance**: The scan reads each `lib/` and `bin/` Dart file once and
  stops at the header boundary, so most of each file is never read. Runs in
  well under a second on the full tree.
- **Documentation Quality**: Every new function carries a doc header naming the
  failure mode it prevents (the v13.12.6/.7 tag burn), why the header bound
  exists, and why dev_dependencies are excluded. The pubspec `meta` entry
  documents why the constraint is `^1.18.0` and not `^1.18.3`.
- **Refactoring**: None beyond scope.

### 4. Testing Validation

**A. Existing-test audit.** Grepped `scripts/modules/tests/` and `test/` for the
changed symbols (`get_dependency_import_status`, `has_blocking_issues`,
`get_contains_audit_status`, `dependency_imports_ok`, `AuditResult`,
`check_dependency_imports`). The only match is the newly added
`test_dependency_imports.py`. No pre-existing test pinned `AuditResult` or the
audit blocking property, so no existing assertions needed updating.

**B. New tests.** `scripts/modules/tests/test_dependency_imports.py` — 5 cases:
declared imports pass; an undeclared import is flagged with its file; a
`package:` URI inside a string literal is NOT treated as an import (the
false-positive guard); a dev_dependency does not satisfy a shipped import; the
package's own name is allowed. Auto-discovered by the CI `test` job's existing
`python -m unittest discover` step.

Command run: `python -m unittest scripts.modules.tests.test_dependency_imports`
→ **5 passed**. Module compile-check on `_audit.py` and `_audit_checks.py` →
both compile. Standalone `python scripts/check_dependency_imports.py` → exit 0,
clean. CI run 27455501182 executed the new "Verify dependency-import
consistency" step on the runner (Dart 3.10.8) → printed the OK line, whole run
green.

### 5. Extension Localization

SKIPPED [A/C-NOT-IN-SCOPE] — no `extension/` user-facing code changed.

### 6. Project Maintenance & Tracking

- CHANGELOG: `[Unreleased]` Maintenance block describes the pre-tag audit gate
  and the CI gate. The `meta` declaration itself is recorded under the
  now-published `[13.12.7]` Maintenance block.
- README verified — no updates needed (no rule/fix counts changed).
- `pubspec.yaml` / `pubspec.lock`: `meta: ^1.18.0` added as a direct dependency
  (was transitive); committed.
- Roadmap: SKIPPED — no lint entries completed.
- Bug archival: No bug archive — task did not close a `bugs/*.md` file.

### 7. Persist Finish Report

Finish report saved: plans/history/2026.06/2026.06.13/publish_dependency_import_gate.md

### Files changed (across the session's commits)

- `pubspec.yaml`, `pubspec.lock` — declare `meta` as a direct dependency
  (commit eb01dc57).
- `scripts/modules/_audit_checks.py` — `get_dependency_import_status` plus the
  `_imported_packages_in_header` and `_declared_dependencies` helpers.
- `scripts/modules/_audit.py` — wire the check into `run_audit`; add the
  blocking `dependency_imports_ok` field to `AuditResult.has_blocking_issues`.
- `scripts/modules/tests/test_dependency_imports.py` — new regression tests.
- `scripts/check_dependency_imports.py` — standalone CLI wrapper.
- `.github/workflows/ci.yml` — add `setup-python` + a "Verify dependency-import
  consistency" step to the `analyze` job.
- `CHANGELOG.md` — `[Unreleased]` Maintenance entries.

### Outstanding work

None. The release pipeline now fails before tagging on an undeclared
dependency, and CI fails the same condition at merge time. v13.12.7 is live on
pub.dev.
