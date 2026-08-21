# Scan CLI stderr routing + --json-file-path (#310)

The scan CLI's `--format json` output was corrupted by informational progress
messages ("Loaded N rules…", "Scanning N files…") printed to stdout before the
JSON payload. Redirecting stdout to a file produced invalid JSON, breaking
automation harnesses that consume the scan result programmatically.

## Finish Report (2026-08-20)

**Root cause:** `ScanRunner._prepare()` routed all informational messages
through `_out()`, which writes to stdout when no `messageSink` is configured.
The JSON payload also goes to stdout (via `print()` in `bin/scan.dart`),
so the two streams collided.

**Fix 1 — stderr routing:** Changed every `_out()` call in `_prepare()`,
`_resolveRuleNames()`, `_loadRulesFromConfig()`, and `_stopSentinelHit()` to
`_err()`, which writes to stderr. The `messageSink` path (used by the scan
daemon and tests) is unchanged — both methods delegate to the sink when set.

**Fix 2 — `_out()` → `_debugOut()` rename:** The sole remaining stdout method
was renamed to `_debugOut()` with a doc comment stating it is reserved for
`--debug-rule` trace output. Prevents future contributors from accidentally
routing progress messages through it.

**Fix 3 — trailing `\n` removal:** The "Scanning N files…\n" message had a
trailing newline to separate it from the (formerly stdout) JSON. Now that the
message is on stderr, the extra newline is unnecessary and was removed.

**Fix 4 — `--json-file-path` flag:** New CLI argument writes JSON output
directly to a named file instead of stdout. Implies `--format json`. Added to
`ScanCliArgs`, `parseScanArgs()`, `bin/scan.dart` (via `_writeJson()` helper),
and the `--help` text. 5 unit tests added for parsing.

**Test impact:** All 5 `--json-file-path` parser tests pass. Existing tests
unaffected (use `messageSink`). 2 pre-existing process-level test failures
(exit code 255 vs 2 when shelling out to `dart run`) are unrelated.

**Files changed:**
- `lib/src/scan/scan_runner.dart` — `_out()` → `_err()` for all non-debug
  messages; `_out()` renamed to `_debugOut()` with doc; trailing `\n` removed
- `lib/src/scan/scan_cli_args.dart` — `jsonFilePath` field + `--json-file-path`
  parser branch
- `bin/scan.dart` — `_writeJson()` helper for file vs stdout output;
  `--json-file-path` in help text
- `test/scan/scan_cli_args_test.dart` — 5 tests for `--json-file-path` parsing
- `CHANGELOG.md` — `[Unreleased]` entries for #310 (Fixed + Added)
