# Implemented: Scan Public API, File-List Support, Tier Override

**Plan:** [plan_scan_public_api_file_list_tier.md](plan_scan_public_api_file_list_tier.md)  
**Completed:** 2026-03-19

## Summary

All four plan sections were implemented and are backward-compatible.

1. **Public API** — `lib/scan.dart` exports `ScanRunner`, `ScanConfig`, `ScanDiagnostic`, `loadScanConfig`, `ScanMessageSink`, `scanDiagnosticsToJson`, `scanDiagnosticsToJsonString`. README documents programmatic usage.
2. **File-list support** — `ScanRunner(dartFiles: [...], applyExclusionsToFileList: true)`. CLI: `--files <path>...` and `--files-from-stdin` (reads all lines until EOF). Relative paths resolved against `targetPath`.
3. **Tier override** — `ScanRunner(tier: 'essential'|...)`. CLI: `--tier <name>`. Unknown tier or `--tier` with no value returns null / exit 2 with clear message. Uses `tierOrder` from `cli_args.dart` for validation.
4. **JSON output** — `--format json` to stdout; `scanDiagnosticsToJson` / `scanDiagnosticsToJsonString` in API. The documented schema in the README is the contract for consumers; key names are implemented via internal constants in `scan_json.dart` (version, diagnostics, summary with totalCount, byFile, byRule) and are not exported.

**Fix during review:** `--files-from-stdin` now reads all lines from stdin (loop until `readLineSync()` returns null), not just the first line.

**Files changed:** `lib/scan.dart` (new), `lib/src/scan/scan_runner.dart`, `lib/src/scan/scan_json.dart` (new), `lib/src/scan/scan_cli_args.dart` (new, parser extracted for testing), `bin/scan.dart`, README.md, CHANGELOG.md.

**Later (2026-03-19):** Future work done. (1) CLI parser extracted to `lib/src/scan/scan_cli_args.dart` (`parseScanArgs`, `ScanCliArgs`, `ScanParseResult`). (2) `--tier` with no value now returns invalid and CLI exits 2 with message. (3) Unit tests: `test/scan_cli_args_test.dart` (parseScanArgs + process test for `--tier` exit 2), `test/scan_runner_test.dart` (ScanRunner with tier, invalid tier, dartFiles).

---

## Review (for AI reviewer)

- **Logic:** Rule set from tier (validated via `tierOrder`) or config; file list from `dartFiles` (with optional exclusions) or directory discovery. Exit codes and null return documented and consistent.
- **Race conditions:** None; single-threaded sync I/O.
- **Modularity:** CLI parsing in `scan_cli_args.dart` (testable); runner, config, diagnostic, JSON in separate files; `bin/scan.dart` thin.
- **Duplication:** Minimal; byFile/byRule aggregation in report vs JSON are separate concerns (report vs API).
- **Performance:** Progress every 10 files; file discovery and scan are sequential (acceptable for CLI).
- **User messages:** Clear ("Unknown tier: 'x'. Valid tiers: ...", "--tier requires a value", etc.).
- **Recursion:** None.
- **Comments:** File/class/method docs and key logic commented per project standards.
- **Tests:** `scan_cli_args_test.dart` (parseScanArgs cases + process exit 2); `scan_runner_test.dart` (tier, invalid tier, dartFiles, messageSink).
- **Framework:** Uses analyzer, path; follows existing saropa_lints patterns. No animations/UI (CLI only); progress line suffices.
