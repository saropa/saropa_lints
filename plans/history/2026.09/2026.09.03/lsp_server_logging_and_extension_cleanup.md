# LSP Server Logging and Extension Cleanup

The inert LSP server (`bin/lsp_server.dart`) silently swallowed most editor
notifications, making it impossible to verify message flow during Phase 0
testing. The extension's LSP activation block also carried stale Phase 0
comments referencing removed test diagnostics.

## Finish Report (2026-09-03)

### Changes

**`bin/lsp_server.dart`** — Added two-level logging to every `_handleMessage`
switch case. `_log()` emits lifecycle and document events (initialize,
didOpen, didSave, didClose, setTrace, didChangeConfiguration, shutdown,
exit, unknown requests). `_logTrace()` emits high-frequency messages
(didChange, codeAction, cancelRequest, unknown notifications) with a
`[trace]` prefix so Phase 1 can gate them behind `$/setTrace`. Added
`_uri()` helper to extract `textDocument.uri` from params.

**`extension/src/extension.ts`** — Updated LSP activation block comments
to reflect Phase 0 current state (no longer references removed test
diagnostics). Minor whitespace cleanup (removed blank lines between
client creation and `start()` call).

**`.vscode/launch.json`** (gitignored) — Added `--folder-uri` pointing
to `example/` so F5 opens a project with a local path dependency on
saropa_lints instead of restoring the previous workspace. Fixed
`outFiles` path from `out/` to `dist/` (esbuild output location).

### Verification

LSP server confirmed running in Extension Development Host via the
Saropa Lints sidebar debug panel (Status: running, Rules: 4). Note:
diagnostics visible in the test were from the published package version
(workspace pointed at `saropa_kykto`), not the local development copy.
The `--folder-uri` fix ensures future F5 launches use `example/` which
has the local path dependency.
