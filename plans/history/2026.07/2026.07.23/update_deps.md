# Bug: Dependabot PR #271 closed without merge -- js-yaml bump

**Ref:** https://github.com/saropa/saropa_lints/pull/271
**Status:** Fixed
**Severity:** Low -- dev dependency only

## Problem

Dependabot PR to bump `js-yaml` from 4.1.1 to 4.3.0 in `extension/` was closed without merging. It had been blocked by workflow approval and a merge conflict in `analysis_options.yaml`.

## Resolution

js-yaml is a transitive dependency (via mocha `^4.1.0` spec), not a direct project dependency. The lock file already resolves to 4.3.0, so the bump occurred naturally during a subsequent `npm install`. Dependabot PR was superseded.

## Finish Report (2026-07-23)

Investigation confirmed js-yaml is not listed in `extension/package.json` — it enters the dependency graph transitively through mocha's `^4.1.0` range. `extension/package-lock.json` already resolves to 4.3.0 (line 2168), making the Dependabot PR moot. Bug report updated with accurate resolution, marked Fixed, and archived from `bugs/` to `plans/history/2026.07/2026.07.23/`.

### Hardening (2026-07-23)

All five handoff reflection items verified:

1. **Semver range**: mocha's `^4.1.0` allows 4.x ≥ 4.1.0; 4.3.0 is latest in range (5.x exists but excluded by caret). Lock file stable.
2. **Dangling references**: only one reference to `bugs/update_deps.md` — in `bug-report-cleanup.md`, which already notes the archival.
3. **PR #271 state**: confirmed CLOSED via `gh pr view` (closedAt 2026-07-23T21:21:00Z). Already has 2 comments; no additional comment needed.
4. **js-yaml 4.3.0 breaking changes**: none within 4.x (semver guarantee). Latest is 4.3.0.
5. **CHANGELOG breaking entry**: uncommitted working-tree change from parallel `require_dio_factory` rename work, not from this task.

Added `get_dangling_bug_references()` to `scripts/modules/_audit_checks.py` — scans active docs for `bugs/<name>.md` paths pointing to deleted/archived files. Wired into `run_full_audit()` in `_audit.py` as a `_WARN`-level check. Skips `plans/history/` (frozen records). Found 3 genuine dangling references in active documents on first run.
