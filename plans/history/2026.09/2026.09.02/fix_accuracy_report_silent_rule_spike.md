# Fix: accuracy_report showing 93% of rules as silent

The `bin/accuracy_report.dart` CLI was reporting 1457/1559 rules (93.5%) as
silent — roughly double the established baseline of ~640. The root cause was the
`ProgressTracker` IDE cap (`_maxIssues = 500`) silently dropping non-ERROR
diagnostics after 500 issues before they reached the `RecordingDiagnosticListener`
used by the accuracy matcher.

## Root cause

`SaropaDiagnosticReporter._isCappedFromProblemsTab()` gates
`_rule.reportAtNode()` and `_rule.reportAtOffset()` when
`ProgressTracker.isLimitReached` is true and severity is not ERROR. The cap
exists to keep the IDE Problems tab manageable, but the accuracy report runs a
full batch scan that emits ~200k diagnostics — exceeding the 500 cap almost
immediately and silencing every subsequent non-ERROR rule.

## Fix

### Phase 1 (commit `67ed0562`)
Added `ProgressTracker.setMaxIssues(0)` directly in `bin/accuracy_report.dart`
before the scan call. Verified fix: 93.5% silent → 41.1% (matches baseline).

### Phase 2 (hardening)
Encapsulated the cap-disable into `ScanRunner` itself via a new
`disableIssueCap` constructor parameter. This prevents future CLI consumers
from needing to know about `ProgressTracker` internals. Applied to both
`accuracy_report.dart` and `audit.dart` (which had the same latent bug —
all rules enabled but diagnostics silently capped at 500).

The `scan.dart` CLI and `scan_daemon.dart` intentionally retain the default
cap — the 500-issue limit is correct for IDE-facing output.

## Files changed

- `lib/src/scan/scan_runner.dart` — added `disableIssueCap` parameter,
  applied in `runResolved()` and `runResolvedWithCollection()`
- `bin/accuracy_report.dart` — replaced direct `ProgressTracker.setMaxIssues(0)`
  with `disableIssueCap: true` on `ScanRunner`; removed unused `ProgressTracker`
  import
- `bin/audit.dart` — added `disableIssueCap: true` to `ScanRunner` constructor
  (fixes latent same bug)
- `CHANGELOG.md` — updated Fixed entry

## Verification

- Full scan WITHOUT fix: 2,892 diagnostics returned, 1457/1559 silent (93.5%)
- Full scan WITH fix: 200,752 diagnostics returned, 640/1559 silent (41.1%)
  — matches pre-regression baseline
- `setMaxIssues(0)` confirmed safe: line 439 guards with `_maxIssues > 0`
  before limit comparison, so 0 = unlimited with no division-by-zero risk
- `ScanRunner` does not call config loaders that could overwrite the cap

## Ruled out during investigation

- Path canonicalization mismatch (both paths canonicalize identically on Windows)
- `_isExcluded('/example')` (doesn't match relative paths)
- `RuntimeTierCap` (CLI has no default cap)
- `_wrapCallback` gates / `enabledRules` config wipe
- `skipExampleFiles` default
- `FileBudgetTracker` (not armed in CLI)
- RSS limit early termination (separate mechanism)
