# Implemented: Scan Public API, File-List Support, Tier Override

**Plan:** [plan_scan_public_api_file_list_tier.md](plan_scan_public_api_file_list_tier.md)  
**Completed:** 2026-03-19

## Summary

All four plan sections were implemented and are backward-compatible.

1. **Public API** — `lib/scan.dart` exports `ScanRunner`, `ScanConfig`, `ScanDiagnostic`, `loadScanConfig`, `ScanMessageSink`, `scanDiagnosticsToJson`, `scanDiagnosticsToJsonString`. README documents programmatic usage.
2. **File-list support** — `ScanRunner(dartFiles: [...], applyExclusionsToFileList: true)`. CLI: `--files <path>...` and `--files-from-stdin` (reads all lines until EOF). Relative paths resolved against `targetPath`.
3. **Tier override** — `ScanRunner(tier: 'essential'|...)`. CLI: `--tier <name>`. Unknown tier returns null / exit 2 with clear message. Uses `tierOrder` from `cli_args.dart` for validation.
4. **JSON output** — `--format json` to stdout; `scanDiagnosticsToJson` / `scanDiagnosticsToJsonString` in API. Schema uses constants in `scan_json.dart` (version, diagnostics, summary with totalCount, byFile, byRule).

**Fix during review:** `--files-from-stdin` now reads all lines from stdin (loop until `readLineSync()` returns null), not just the first line.

**Files changed:** `lib/scan.dart` (new), `lib/src/scan/scan_runner.dart`, `lib/src/scan/scan_json.dart` (new), `bin/scan.dart`, README.md, CHANGELOG.md. No new unit tests (plan suggested manual/CI verification).
