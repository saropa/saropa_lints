# Scan CLI: --fail-on flag

The scan CLI (`dart run saropa_lints:scan`) lacked a mechanism to decouple exit
code severity gating from display filtering. CI pipelines that wanted to see all
diagnostics but only fail on errors had no way to express that intent.

## Changes

### `lib/src/scan/scan_cli_args.dart`
- Added `failOn` field (nullable `String`) to `ScanCliArgs` data class.
- Added `failOnCount` field (nullable `int`) — count threshold for `--fail-on`.
- Added `--fail-on` parsing block: validates INFO/WARNING/ERROR, rejects invalid
  or missing values. Same pattern as `--min-severity`.
- Added `--fail-on-count` parsing block: validates non-negative integer.

### `bin/scan.dart`
- Added `_computeExitCode()` pure helper: when `failOn` is set, counts
  diagnostics in the FULL list at or above the threshold severity; exits 1 only
  when count exceeds `failOnCount` (default 0, i.e. any match). Without
  `failOn`, preserves the existing `filtered.isEmpty ? 0 : 1` behavior.
- Replaced three hardcoded `exit(0)`/`exit(1)` calls with `exit(exitCode)`.
- Added explanatory message when `--fail-on` causes exit 1 but `filtered` is
  empty, so automation does not see contradictory "No issues" + exit 1 signals.
- Added `failOn` metadata object to JSON output when `--fail-on` is active,
  with `threshold`, `thresholdMet`, and optional `countBaseline` fields.
- Updated exit-code doc comment, help text, and examples.

### `lib/src/scan/scan_json.dart`
- Added optional `failOn` named parameter to `scanDiagnosticsToJson()` and
  `scanDiagnosticsToJsonString()` — backward-compatible (null default).

### `test/scan/scan_cli_args_test.dart`
- `--fail-on`: 6 parse-level + 6 process-level tests (exit 0 on no errors,
  exit 1 on any diagnostic, decoupling proof, invalid value, --max-severity
  combo, --fail-on-count baseline).
- `--fail-on-count`: 6 parse-level tests (valid integer, zero, negative,
  non-integer, no value, null default).

### `CHANGELOG.md`
- Updated entry under `### Added` for `--fail-on` (#309) to include
  `--fail-on-count` and JSON metadata.

## Design decisions
- `--fail-on` checks the full diagnostic list, not the filtered list. This is
  the entire point: display filtering and exit code are independent concerns.
- `--fail-on-count` uses "exceeds" semantics (`count > threshold`), not
  "meets" — so `--fail-on-count 5` tolerates exactly 5 matching diagnostics
  and fails on the 6th. This matches the CI baseline use case.
- `--fail-on-count` without `--fail-on` is silently ignored (the `failOn !=
  null` guard wraps both). No error, no special handling needed.
- Severity vocabulary matches `--min-severity` (info/warning/error) for
  consistency.
- Default for both flags is null (no change to existing behavior).

## Finish Report (2026-08-21)

The `--fail-on` and `--fail-on-count` flags are complete. All 72 scan CLI tests
pass, including 12 `--fail-on` tests (6 parse + 6 process) and 6
`--fail-on-count` parse tests plus 1 process test. A deep review identified and
addressed three hardening gaps: contradictory stdout/exit-code signals when
`--fail-on` triggers on filtered-out diagnostics, a stub test that silently
early-returned instead of asserting, and a missing decoupling proof test. JSON
output now includes a `failOn` metadata object when the flag is active so
machine consumers can distinguish "no diagnostics matched the display filter"
from "the threshold was not met."
