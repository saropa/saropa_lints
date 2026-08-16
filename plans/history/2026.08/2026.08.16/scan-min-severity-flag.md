# scan --min-severity / --max-severity flags

The `scan` CLI had no mechanism to filter diagnostics by severity level — all INFO, WARNING, and ERROR diagnostics were always emitted to stdout and the report file, which created excessive noise for AI agents consuming scan output (GitHub issue #299).

## Solution

Added `--min-severity <info|warning|error>` and `--max-severity <info|warning|error>` flags to `dart run saropa_lints:scan`. Together they define a severity window:

- `--min-severity warning` — excludes INFO, shows only WARNING and ERROR
- `--max-severity warning` — excludes ERROR, shows only INFO and WARNING
- Both together — shows only the requested band

When all diagnostics fall outside the window, a distinct message reports how many were suppressed (distinguishing "all filtered" from "genuinely clean"). Unrecognized severity values from diagnostics emit a stderr warning before being excluded, guarding against silent data loss if the analyzer adds new severity levels.

## Files Changed

- `lib/src/scan/scan_cli_args.dart` — `minSeverity`/`maxSeverity` fields, parsing with validation, updated library doc
- `bin/scan.dart` — post-scan filtering via `_severityRank`/`_meetsMinSeverity`, unrecognized-severity warning, threshold-aware "no issues" message, help text update
- `test/scan/scan_cli_args_test.dart` — 14 new tests (12 unit, 2 integration/process)
- `CHANGELOG.md` — [15.0.3] entry

## Finish Report (2026-08-16)

The implementation follows the existing CLI arg-parsing pattern (`--tier`, `--debug-rule`): values are parsed and validated in `scan_cli_args.dart`, filtering is applied in the binary after the scan completes. The severity rank comparison uses a simple integer map (`ERROR=3, WARNING=2, INFO=1, _=0`) with a documented fallback for the analyzer's theoretical NONE severity.

A `_knownSeverities` set enables a stderr warning when an unrecognized severity is encountered — this guards against a future analyzer change silently dropping diagnostics through the rank-0 fallback without any user-visible signal.

Exit code semantics are preserved: exit 0 when no diagnostics survive the filter (with a descriptive message when filtering hid real issues), exit 1 when diagnostics remain, exit 2 on invalid arguments.
