# LSP Server Thread-Pool Exhaustion Crash

The standalone LSP server (`bin/lsp_server.dart`) crashed on startup when
connecting to large Dart projects. The Dart VM's OS thread pool was exhausted
by synchronous I/O calls (`lastModifiedSync`, `listSync`, `readAsStringSync`)
executed in bulk during the workspace scan and prewarm phases. The crash
surfaced as `Could not start thread dart:io ReadFile: 22` followed by a native
stack dump, which triggered vscode-languageclient's infinite restart loop.

## Finish Report (2026-09-05)

### Root Cause

Dart's blocking I/O functions each claim one OS thread from a fixed-size pool.
The workspace scan calls `File.lastModifiedSync()` for every Dart file in the
project to check mtimes for incremental scanning. The prewarm phase calls
`Directory.listSync(recursive: true)` to find a representative file. On a
project with hundreds of Dart files plus dependency overrides, these sync calls
— running concurrently with the `didClose` notification flood from VS Code —
exhausted the thread pool, and the VM could not allocate a thread for the
stdin socket reader.

### Changes

| File | Change |
|------|--------|
| `bin/lsp_server.dart` | Wrapped `main()` in `runZonedGuarded` for Dart-level unhandled async errors (does NOT catch native VM crashes — see comment in code) |
| `bin/lsp_server.dart` | Added `onError` handler to `stdin.listen` so socket read failures exit cleanly instead of crashing |
| `bin/lsp_server.dart` | Replaced `File.lastModifiedSync()` with batched `Future.wait(File.lastModified())` in `_analyzeWorkspace`, capped at 20 concurrent operations via `_maxConcurrentFileOps` |
| `bin/lsp_server.dart` | Replaced `Directory.listSync(recursive: true)` with `await for ... list(recursive: true)` in `_prewarm` |
| `bin/lsp_server.dart` | Replaced `File.readAsStringSync()` with `await File.readAsString()` in `_sourceChangeToWorkspaceEdit`, making the function `async` and updating its call site |
| `CHANGELOG.md` | Added fixed entry under 16.0.0-beta.3 |

### Not Changed

- `_readTierFromConfig` still uses `readAsStringSync` — called once during
  init for a single small YAML file, not a contributor to the thread-pool
  pressure.
- No unit tests added — the server binary has no existing test harness and the
  crash requires spawning the process under I/O pressure, which is
  integration-test scope.

### Hardening (post-reflection)

- `runZonedGuarded` comment updated to be honest: it catches Dart-level async
  errors only, not the native VM crash (exit code 0xC0000409 /
  STATUS_STACK_BUFFER_OVERRUN) that was the original symptom.
- Added `onError` handler on `stdin.listen` so socket-level read failures
  produce a clean `exit(1)` instead of an unhandled exception.
- Workspace scan mtime checks batched with `Future.wait` in chunks of 20
  (`_maxConcurrentFileOps`) — parallelizes disk I/O within a safe concurrency
  cap. Each batch runs 20 `lastModified()` calls concurrently, awaits them
  together, then starts the next batch. This prevents the Dart VM's I/O thread
  pool (~32 threads) from being overwhelmed even on projects with thousands of
  Dart files.
- Individual `lastModified()` failures within a batch are caught per-file
  instead of aborting the entire `Future.wait`. Files that vanish between the
  directory listing and the mtime check get an epoch timestamp so they're
  treated as "changed" and analysis catches the real error.
- Cancellation flag (`_workspaceScanCanceled`) checked between mtime batches
  and between analysis files. Set on `shutdown` and
  `workspace/didChangeConfiguration`, reset at each new scan start.

### Progressive scan with cancellation (post-reflection)

- Workspace scan now publishes diagnostics incrementally — each file's results
  appear in the Problems panel as soon as its analysis completes, not after the
  full scan finishes.
- Progress logged every 50 files (`workspace scan: N/M files (D diagnostics
  so far)`) so the Output channel shows the scan is alive on large projects.
- Cancellation produces a summary log line showing how many files were analyzed
  before the abort and how many diagnostics were published, so the user knows
  partial results are available.
