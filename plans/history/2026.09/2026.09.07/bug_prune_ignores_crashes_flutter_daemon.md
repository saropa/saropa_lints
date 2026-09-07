# Bug: "Prune ignores" crashes the Flutter daemon

**Status:** Fixed
**Severity:** High — crashes an unrelated process
**Reported:** 2026-09-07
**Fixed:** 2026-09-07

## Problem

Running "Prune ignores" from the sidebar triggers:

> The Flutter Daemon has terminated. Please review the log and file an issue on GitHub.

## Root cause

The command (`saropaLints.findAndFixStaleIgnores` in `stale-ignore-commands.ts:103`) spawns
`dart run saropa_lints:scan` via `runInWorkspaceAsync()`. This:

1. Runs `dart run`, which acquires `.dart_tool/` locks and may trigger JIT compilation.
2. Competes for the same SDK resources the Flutter daemon uses.
3. On Windows, spawns via `shell: true` (cmd.exe wrapper), adding process tree complexity.

The error message comes from the **Dart/Flutter VS Code extension** (not Saropa Lints) when its
long-lived `flutter daemon` process exits unexpectedly.

## Possible fixes

- Use the LSP server or live diagnostics instead of spawning `dart run`.
- Queue the scan to wait until the Flutter daemon is idle.
- At minimum, warn the user that running this while Flutter is active may interrupt it.

## Fix applied

- Added `shell` and `env` options to `runInWorkspaceAsync()` in `setup.ts`.
- Stale-ignore scan/fix commands now pass `shell: false`, spawning `dart.exe` directly
  instead of via `cmd.exe`. This eliminates the intermediate shell process that added
  process-tree complexity and SDK resource contention on Windows.
- `DART_SUPPRESS_ANALYTICS=true` is passed to the child environment, reducing SDK
  side-effects during the scan.
- `killProcessTree()` still handles cancellation via `taskkill /T /F` on Windows — the
  `dart run` process may spawn its own children (JIT compiler, kernel worker) that need
  tree-kill even without the cmd.exe wrapper.

### Residual risk

If the daemon crash was caused purely by `.dart_tool/` lock contention (cause #1) rather
than process-tree complexity (cause #3), this fix mitigates but may not fully eliminate
the issue. A definitive fix would replace `dart run` with LSP-based diagnostics, avoiding
the CLI spawn entirely. That is tracked as a future improvement.

## Files

- `extension/src/stale-ignore-commands.ts` — command implementation
- `extension/src/setup.ts:292` — `runInWorkspaceAsync()` spawn logic
- `extension/src/setup.ts:236` — `killProcessTree()` with `taskkill /T /F`

## Finish Report (2026-09-07)

### Defect

The "Prune ignores" sidebar action spawned `dart run saropa_lints:scan` through
`runInWorkspaceAsync()` with `shell: true`, which on Windows wraps the command in a
`cmd.exe` child process. The resulting process tree competed for Dart SDK resources
(`.dart_tool/` locks, JIT compilation) with the Flutter daemon maintained by the
Dart/Flutter VS Code extension, causing the daemon to terminate unexpectedly.

### Fix

Extended `runInWorkspaceAsync()` with optional `shell` (boolean) and `env`
(key-value pairs) parameters. Both stale-ignore CLI invocations (`runFindScan` and
`runFixScan`) now pass `shell: false` to spawn `dart.exe` directly — eliminating the
`cmd.exe` intermediary — and `DART_SUPPRESS_ANALYTICS=true` to suppress analytics
side-effects. All existing callers are unaffected (default `shell: true` preserved).

An ENOENT fallback was added: when `shell: false` fails because the command isn't
found (e.g. `dart` resolves to `dart.bat` on a legacy Windows SDK install, and
`CreateProcessW` can't execute `.bat` files without a shell), the function retries
once with `shell: true`. This keeps `shell: false` as the preferred path while
degrading gracefully on older SDK installations.

### Verification

- `npx tsc --noEmit -p .` — clean.
- `npx tsc -p tsconfig.test.json` — clean.
- `npx mocha` on `staleIgnoreCommands.test.js` and `runInWorkspaceAsyncCancellation.test.js` — 17/17 passing.
- Extension Development Host (F5) verification is required — this change is **unverified** at the visual/process level.

### Residual risk

The ENOENT fallback handles legacy SDK installs that only expose `dart.bat`. If
`.dart_tool/` lock contention (not process-tree complexity) was the true root cause,
the daemon crash may recur — the definitive fix is replacing the CLI spawn with
LSP-based diagnostics.
