# LSP Server Phase 0 — Fake Diagnostic Plumbing Test + Debug Panel

Standalone LSP server and VS Code debug panel added as a zero-risk plumbing gate
for the plugin-to-LSP migration. Phase 0 proves two LSP servers (Dart analyzer +
saropa) can coexist in the same VS Code Problems panel, delivering diagnostics,
squiggles, and quick fixes without the 6–8 GB RSS cost of the in-process analyzer
plugin's element model.

## Finish Report (2026-09-02)

### What changed

**Dart LSP server** (`bin/lsp_server.dart`): standalone JSON-RPC 2.0 server over
stdin/stdout with Content-Length framing. Publishes 4 hardcoded diagnostics
(Error/Warning/Info/Hint on lines 0–3) on `didOpen`/`didSave`, clears on
`didClose`. Quick fixes insert dismiss comments (proves TextEdit round-trip).
Pure Dart, zero dependencies.

**Debug panel** (`extension/src/debug/`): webview sidebar with engine status
cards (Analyzer Plugin, Scan Daemon, LSP Server). ON/OFF toggles, PID, rule
count, RSS display, 100-entry log ring buffer. Only LSP toggle is fully wired;
analyzer and daemon toggles are read-only (deferred). Theme-aware CSS, all
user-facing strings externalized through `l10n()`.

**Extension wiring** (`extension/src/extension.ts`): `SaropaLspClient` wraps
`vscode-languageclient` `LanguageClient` with start/stop/restart lifecycle. LSP
client starts on activation when enabled, reacts to setting changes. Two new
settings (`debug.enabled`, `lspServer.enabled`, both default true), 4 commands
(toggle debug panel, LSP start/stop/restart).

**Migration plan** (`plans/PLAN_lsp_server_migration.md`): architecture pivot from
`analysis_server_plugin` (in-process) to standalone LSP server, modeled on DCM's
architecture (350 MB standalone vs 4 GB in-process). Four phases: Phase 0 (fake
plumbing), Phase 1 (full rules), Phase 2 (extension integration), Phase 3
(remove plugin), Phase 4 (optimize).

### Also committed (from prior sessions)

- `usesTypeResolution` metadata added to 12 rule classes, with bidirectional
  integrity test.
- Audit report HTML extraction into `audit-report-script.ts` and
  `audit-report-styles.ts`.
- Config migration CLI hardening and `custom_overrides_core.dart`.
- Scan runner `rule_category_map.dart` and expanded tier index tests.
- Gap analysis document and archived plans.

### Bugs fixed during review

1. **stderr loss in audit CLI exit-code-2 path** — `stderrBuf` only held the
   trailing fragment after progress-line parsing; accumulated `stderrLines[]`
   now preserves complete lines for the error display.
2. **Double-resolve race in audit cancel path** — missing `canceled` guard in the
   child process `error` handler allowed a contradictory "spawn failed" toast on
   top of the "Audit canceled" message.

### Deferred

- `spawnAuditCli` exceeds 3-parameter and 50-line limits; `audit-command.ts`
  exceeds 200-line file limit. Pre-existing convention debt, needs dedicated
  refactor.
- Redundant `webview.options` double-set in `openAuditReport` (harmless but
  unclear abstraction boundary).
- Locale catalog regeneration (new debug panel + audit keys need NLLB/Qwen run).
- Phase 4 manual VS Code test (memory pressure thresholds, daemon suspension).

### Verification

- `tsc --noEmit` passes clean.
- `npm ci` succeeds with new `vscode-languageclient` dependency.
- `dart test` passes all affected tests (23/23): uses_type_resolution,
  rule_tier_index, write_config.
- Manual VS Code test pending (requires Extension Development Host).
