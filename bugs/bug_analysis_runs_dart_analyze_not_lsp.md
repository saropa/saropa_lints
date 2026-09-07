# Bug: "Run analysis" spawns `dart analyze` instead of using LSP

**Status:** Fixed (partial)
**Severity:** Performance
**Reported:** 2026-09-07
**Fixed:** 2026-09-07

## Problem

The sidebar "Run analysis" action (`saropaLints.runAnalysis`) spawns `dart analyze` as a child
process every time. The per-file path (`runAnalysisForFiles` in `setup.ts:1635`) uses `spawnSync()`
which blocks the extension host entirely.

The extension already has two zero-cost alternatives that go unused:

1. **`SaropaLspClient`** (`debug/saropaLspClient.ts`) — a persistent LSP server via
   `dart run saropa_lints:lsp_server`, already wired up in `extension.ts:1548+`.
2. **`liveDiagnosticsModel.ts`** — reads live VS Code diagnostics via
   `vscode.languages.getDiagnostics()` at zero cost (the Dart Analysis Server already produced
   them).

## User impact

Analysis takes tens of seconds on large projects. The progress notification ("Running analysis")
gives no indication it's shelling out to a cold `dart analyze` instead of reading existing data.

## Files

- `extension/src/setup.ts` — `runAnalysis()` at line ~1504, `runInWorkspaceAsync()` at line ~292
- `extension/src/debug/saropaLspClient.ts` — existing LSP client
- `extension/src/liveDiagnosticsModel.ts` — existing live diagnostics reader
- `extension/src/extension.ts:1964` — command registration

## Fix applied

**`runAnalysisForFiles` converted from sync to async** — replaced the `runInWorkspace()` /
`spawnSync()` call with `runInWorkspaceAsync()`, matching the pattern the full-workspace
`runAnalysis` already uses. The extension host is no longer blocked during per-file analysis.
The `showProgress: true` path is now cancellable.

## Remaining: LSP / live-diagnostics migration

The full-workspace `runAnalysis` still shells out to `dart analyze`. Migrating to
`liveDiagnosticsModel` (zero-cost read of existing diagnostics) or `SaropaLspClient` (persistent
LSP server) would eliminate the cold `dart analyze` entirely, but that is an architectural change
that affects the data flow for violations.json, the post-analysis popup, and the report log.
Tracked separately.
