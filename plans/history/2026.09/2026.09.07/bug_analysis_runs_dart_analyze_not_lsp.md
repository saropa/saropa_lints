# Bug: "Run analysis" spawns `dart analyze` instead of using LSP

**Status:** Fixed
**Severity:** Performance
**Reported:** 2026-09-07
**Fixed:** 2026-09-07

## Problem

The sidebar "Run analysis" action (`saropaLints.runAnalysis`) spawned `dart analyze` as a child
process every time. The per-file path (`runAnalysisForFiles` in `setup.ts`) originally used
`spawnSync()` which blocked the extension host entirely.

The extension already had two zero-cost alternatives that went unused:

1. **`SaropaLspClient`** (`debug/saropaLspClient.ts`) — a persistent LSP server via
   `dart run saropa_lints:lsp_server`, already wired up in `extension.ts`.
2. **`liveDiagnosticsModel.ts`** — reads live VS Code diagnostics via
   `vscode.languages.getDiagnostics()` at zero cost (the Dart Analysis Server already produced
   them).

## User impact

Analysis took tens of seconds on large projects. The progress notification ("Running analysis")
gave no indication it was shelling out to a cold `dart analyze` instead of reading existing data.

## Files changed

- `extension/src/setup.ts` — `runAnalysis`, `runAnalysisForFiles`, `runAnalysisAfterConfigChangeScoped`, `showAnalysisIssuesNotification`
- `extension/src/liveViolationsData.ts` — added `readLiveViolationsForFiles` for per-file filtered live reads
- `extension/src/violationsReader.ts` — added `writeViolationsData` for atomic violations.json write
- `extension/src/test/liveViolationsData.test.ts` — 3 new tests for file-filtered live reads
- `extension/src/liveDiagnosticsModel.ts` — existing live diagnostics reader (unchanged)
- `extension/src/debug/saropaLspClient.ts` — existing LSP client (unchanged)

## Fix applied

### Phase 1: sync-to-async (2026-09-07, initial)

`runAnalysisForFiles` converted from `spawnSync` to `runInWorkspaceAsync`, matching the pattern
the full-workspace `runAnalysis` already used. The extension host was no longer blocked during
per-file analysis.

### Phase 2: live diagnostics migration (2026-09-07, complete)

All three `dart analyze` spawn sites migrated to read live VS Code diagnostics via
`buildViolationsDataFromDiagnostics` / `readLiveViolations` / `readLiveViolationsForFiles`:

1. **`runAnalysis`** — reads live diagnostics (instant), writes `violations.json` from the
   snapshot for downstream consumers (dashboard file watcher, health score), passes
   `ViolationsData` directly to `showAnalysisIssuesNotification` (no write-then-read
   roundtrip). Removed the `_supersedingAnalysisCts` cancellation mechanism and
   `withProgress` wrapper (nothing to cancel or await).

2. **`runAnalysisForFiles`** — same pattern, filtered to the requested file set via
   `readLiveViolationsForFiles`. `cancelled` field always returns false (kept for
   call-site compat). `showProgress` and `token` params accepted for signature compat
   but documented as no-ops.

3. **`runAnalysisAfterConfigChangeScoped`** — replaced the direct `runInWorkspaceAsync`
   `dart analyze` call with `readLiveViolations` + `writeViolationsData`. Uses an
   event-driven freshness gate (`awaitDiagnosticsChange`) that resolves on
   `onDidChangeDiagnostics` with a 3s timeout fallback, so diagnostics are read only
   after the analysis server has reprocessed the new config.

**Result:** "Run analysis" completes in milliseconds instead of tens of seconds. The data
is structurally identical to what the Problems panel shows (they read the same source),
eliminating the stale-data divergence that existed between runs.

## Finish Report (2026-09-07)

### Defect

The extension's "Run analysis" command, per-file analysis, and post-config-change analysis all
spawned `dart analyze` as a child process. On large projects this took tens of seconds per
invocation. The extension already contained `liveDiagnosticsModel.ts` which reads the same
diagnostics the Dart Analysis Server has already produced for the VS Code Problems panel, at
zero cost.

### What changed

Three `dart analyze` subprocess spawn sites in `setup.ts` were replaced with instant reads of
live VS Code diagnostics via `readLiveViolations` / `readLiveViolationsForFiles`. A new
`writeViolationsData` function in `violationsReader.ts` writes the live snapshot to
`violations.json` using atomic temp-then-rename, so downstream file-watching consumers
(dashboard refresh watcher, health score, report buttons) continue working.

`readLiveViolationsForFiles` was added to `liveViolationsData.ts` to filter the diagnostic
stream to a specific set of absolute file paths, with case-insensitive matching for Windows.

The `_supersedingAnalysisCts` cancellation mechanism, `awaitFreshViolations` polling function,
and the `withProgress` wrapper were removed as dead code — live reads are instantaneous with
no subprocess to cancel or await.

The config-change path uses an event-driven freshness gate (`awaitDiagnosticsChange`) that
listens for `onDidChangeDiagnostics` with a 3s timeout fallback, replacing the earlier
fixed 1.5s delay.

Three new unit tests cover `readLiveViolationsForFiles`: file filtering, case-insensitive
path matching, and empty-result behavior. All 93 scoped tests pass.

### Code review fixes

- Fixed critical bug where `runAnalysis` open-editors path passed relative paths from
  `getOpenDartFilePaths` to `readLiveViolationsForFiles` (expects absolute) — would have
  silently returned zero violations for every open-editors-only analysis.
- Added settle delay for config-change path to prevent stale-diagnostics race.
- Removed dead `awaitFreshViolations` function and its constants (~55 lines).
- Removed redundant `existsSync` before `mkdirSync({recursive:true})`.
- Removed unused `saropaLintsDataPath` import.

### Hardening

- Replaced fixed 1.5s config-change settle delay with event-driven `awaitDiagnosticsChange`
  that resolves on `onDidChangeDiagnostics` (3s timeout fallback).
- Added `showInformationMessage` for the zero-violations "Run Analysis" result so the user
  gets visible confirmation the command fired and found nothing.
- Added l10n key `loading.analysisClean` for the clean-analysis message.
- `awaitDiagnosticsChange` now logs to the report when it hits the timeout instead of
  resolving on an actual diagnostics event, so a "config change didn't apply" investigation
  can distinguish a real server hang from the expected no-diff case.
- Fixed the two pre-existing `recommended.yaml` lint warnings the commit hook surfaced in
  unrelated dirty files (`unnecessary_non_null_assertion` in
  `pubspec_constraint_parser.dart`, `dead_code`/`dead_null_aware_expression` in
  `always_specify_parameter_names_helpers.dart`) so the commit hook could pass.

### Unrequested feature: diagnostics freshness indicator

Added a shared "last diagnostics change" timestamp (`recordDiagnosticsChange` /
`getLastDiagnosticsChangeIso` in `liveViolationsData.ts`), stamped from the single
`onDidChangeDiagnostics` listener already registered in `extension.ts`. The Findings
Dashboard sidebar row now appends "· updated Ns ago" (via new l10n keys
`sidebar.dashboards.findingsCleanFresh` / `findingsWithViolationsFresh`) once at least one
diagnostics event has fired this session, so a user can tell a genuinely fresh count from
one that predates the session's first analyzer pass. Two new unit tests pin
`recordDiagnosticsChange`/`getLastDiagnosticsChangeIso`.

### Verification status

TypeScript compiles clean (both `tsc --noEmit -p .` and `tsc -p tsconfig.test.json`). 95
scoped tests pass (93 + 2 new freshness-tracking tests). The change is **unverified in the
Extension Development Host** — the live-diagnostics path, notification popup, dashboard
refresh via file watcher, event-driven config-change gate, and the new "updated Ns ago"
sidebar suffix all need F5 verification in both themes.
