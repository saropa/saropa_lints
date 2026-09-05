# LSP Startup Noise Reduction and Workspace Scan Deferral

The LSP server's output channel was flooded with `didClose` messages on VS Code startup — one per file from the previous session — making the log unreadable. Additionally, the workspace scan started immediately after the analyzer warmed up, competing with VS Code's startup burst of didOpen/didClose notifications.

## Finish Report (2026-09-05)

### Changes

**didClose log level (bin/lsp_server.dart)**
- Changed `_log()` to `_logTrace()` for `textDocument/didClose` messages, matching the existing treatment of `textDocument/didChange`. The didClose handler's functional behavior (clearing diagnostics, removing from open-cache, dropping diagnostic cache) is unchanged — only the log verbosity is reduced.

**Workspace scan deferral (bin/lsp_server.dart)**
- Added `_workspaceScanDelaySecs` field (default: 5, clamped 0–60) read from `initializationOptions.workspaceScanDelay`.
- `_buildCollection()` now defers `_analyzeWorkspace()` via a stored `Timer` when the delay is >0, letting VS Code's startup message burst settle before the scan begins. The timer reference (`_workspaceScanTimer`) is stored so it can be canceled on shutdown or config change — a fire-and-forget `Future.delayed` would have run `_analyzeWorkspace` against a null `_collection` if the server restarted during the delay window.
- `_parseInitializationOptions()` parses both `int` and `double` JSON number types for the delay value.

**Extension client (extension/src/debug/saropaLspClient.ts)**
- Passes `workspaceScanDelay` from `saropaLints.lspServer.workspaceScanDelay` VS Code setting through to the LSP server's `initializationOptions`.

**VS Code settings schema (extension/package.json, package.nls.json)**
- Added `saropaLints.lspServer.workspaceScanDelay` setting: integer, default 5, min 0, max 60. NLS description string added.

### Not changed
- No test files affected — the LSP server has no unit test harness for its message handler.
- Locale catalogs not regenerated (publish-time gate).
