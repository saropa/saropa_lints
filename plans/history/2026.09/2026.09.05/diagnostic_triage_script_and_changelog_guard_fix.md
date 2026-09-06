# Diagnostic triage script + changelog guard fix

Two infrastructure changes: a new triage script for bulk lint sweeps, and a
bug fix in the changelog version-drift guard.

## Finish Report (2026-09-05)

### Change 1: Diagnostic triage script (`scripts/triage_scan.py`)

**Problem:** Bulk lint sweeps in consumer projects produce 80–140 diagnostics
across 30+ files. Each sweep requires ~30 minutes of manual categorization to
separate app code from forked/dev code, identify bulk-fixable patterns, and
prioritize errors over warnings.

**Fix:** A standalone Python script that post-processes `dart run saropa_lints
scan --format json` output into five priority buckets:

1. Errors in app code (fix first)
2. Warnings from the same rule appearing ≥5 times (bulk mechanical fix)
3. Warnings requiring individual triage
4. Diagnostics in dev/debug directories (likely suppress)
5. Diagnostics in forked/vendored directories (suppress)

Configurable via `--suppress-dirs`, `--dev-dirs`, and `--bulk-threshold`.
Supports `--format json` for machine-readable output consumable by
downstream tools (CI steps, extension commands). Includes schema version
validation (warns on mismatch), friendly error messages for empty/invalid
stdin, and a Python 3.10+ version guard. No changes to the Dart analyzer
plugin.

### Change 2: Changelog guard hook fix (`scripts/hooks/changelog_guard.py`)

**Problem:** The changelog guard compared `extension/package.json`'s version
string against the last published git tag. VS Code extensions use a different
version scheme (e.g. `16.1.916`) that the publish script derives from the
semver tag, so this comparison always false-alarmed during beta cycles.

**Fix:** Removed the version-drift comparison for `package.json` (Guard 2)
while keeping `package.json` in the watched-file set so Guard 1 (multiple
unreleased CHANGELOG sections) still triggers on package.json edits.

**Code review catch:** An initial implementation removed `package.json` from
the watched set entirely, which would have silently disarmed Guard 1 for
commits touching only `package.json`. The removed-behavior auditor caught this;
the fix restores `package.json` to the watched set and only skips the
version comparison.

### Change 3: Changelog spelling fix

Pre-existing British spelling "cancelled" on line 82 of CHANGELOG.md corrected
to "canceled" (US English is enforced by the spelling guard hook).

### Files changed

- `scripts/triage_scan.py` — new file
- `scripts/hooks/changelog_guard.py` — removed package.json version check
- `CHANGELOG.md` — added triage script entry, fixed spelling
- `bugs/proposal_infra_diagnostic_triage_report.md` — archived to
  `plans/history/2026.09/2026.09.05/`
