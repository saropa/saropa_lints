# BUG: Infrastructure — Diagnostics go stale after code fix or `// ignore:` addition

**Status: Fixed**

Created: 2026-09-05
Fixed: 2026-09-06
Rule: ALL rules (infrastructure-level)
Severity: Critical — blocks the entire fix-verify loop; developers must reload
VS Code to see whether a fix worked
Rule version: N/A (infrastructure)

---

## Summary

After adding an `// ignore:` directive or fixing flagged code, saropa_lints
diagnostics did NOT clear from VS Code's Problems panel. "Dart: Restart Analysis
Server" did not help. Only "Developer: Reload Window" (full VS Code reload)
cleared stale diagnostics.

---

## Root Causes and Fixes

### Root cause 1: Scan CLI ignored `// ignore:` directives

The scan CLI (`bin/scan.dart`, `bin/scan_daemon.dart`) had no code to suppress
diagnostics matching `// ignore:` or `// ignore_for_file:` directives. The
in-process plugin (Channel 1, ~200 light-lane rules) inherited the Dart
analyzer's native ignore handling, but the scan-on-save channel (Channel 2,
~2100+ rules) re-reported every diagnostic regardless of ignore directives.

**Fix:** Added `filterIgnoredDiagnostics()` to `lib/src/scan/stale_ignore_detector.dart`.
Both `bin/scan.dart` and `bin/scan_daemon.dart` now call it before emitting
results, suppressing diagnostics that match `// ignore:` (line-level) and
`// ignore_for_file:` (file-level) directives.

### Root cause 2: "Restart Analysis Server" left scan-on-save diagnostics intact

"Dart: Restart Analysis Server" kills and restarts the Dart analysis server
(Channel 1) but did NOT touch the scan-on-save `DiagnosticCollection` (Channel
2). Channel 2 diagnostics persisted until the next save triggered a rescan.

**Fix:** `restartDartAnalysisServer()` in `extension/src/setup.ts` now also
executes `saropaLints.scanOnSave.clearAndRescan`, which clears the scan-on-save
DiagnosticCollection and rescans open editors. The command is registered in
`extension/src/extension.ts` and backed by `ScanOnSaveController.clearAndRescan()`.

### Code-fix case: already handled

When the user fixes code and saves, the scan-on-save controller re-scans the
file. The fixed code no longer triggers the rule, so the diagnostic is removed
from the DiagnosticCollection. This path was already correct — the only
persistence was caused by root causes 1 and 2 above.

---

## Files Changed

- `lib/src/scan/stale_ignore_detector.dart` — added `filterIgnoredDiagnostics()`
- `lib/scan.dart` — exported `filterIgnoredDiagnostics`
- `bin/scan.dart` — calls `filterIgnoredDiagnostics` before severity filter/output
- `bin/scan_daemon.dart` — calls `filterIgnoredDiagnostics` before JSON output
- `extension/src/scanOnSave/scanOnSaveController.ts` — added `clearAndRescan()`
- `extension/src/extension.ts` — registered `saropaLints.scanOnSave.clearAndRescan` command
- `extension/src/setup.ts` — `restartDartAnalysisServer()` now also clears scan-on-save diagnostics
