# Fix: runAnalysisForFiles sync blocking

`runAnalysisForFiles` in `extension/src/setup.ts` used the synchronous `runInWorkspace()` wrapper
(`spawnSync`) to shell out to `dart analyze`, blocking the extension host event loop for the entire
analysis duration. The full-workspace `runAnalysis` already used the async `runInWorkspaceAsync`
variant; the per-file path did not.

## Finish Report (2026-09-07)

### Changes

1. **`runAnalysisForFiles` converted from sync to async** — the inner `doRun` closure now calls
   `runInWorkspaceAsync` instead of `runInWorkspace`. Handles the `cancelled` result branch with
   a log entry and early return.

2. **Cancellation token plumbed through callers** — `runAnalysisForFiles` now accepts an optional
   `token` in its options bag. The two internal callers (`runAnalysis` open-editors path and
   `runAnalysisAfterConfigChangeScoped`) forward their existing cancellation tokens so a parent
   Cancel button or supersede CTS can kill the per-file child process. The public API surface
   (`api.ts`) is unchanged.

3. **Progress notification made cancellable** — the `showProgress: true` path now passes
   `cancellable: true` and wires the UI Cancel button token into `doRun`, matching the
   full-workspace pattern.

4. **Return type enriched to `{ ok, cancelled }`** — `runAnalysisForFiles` now returns a structured
   result so callers can distinguish "analysis found issues" from "user cancelled". The
   `runAnalysis` open-editors path skips `awaitFreshViolations` and the post-analysis popup on
   cancellation. `runAnalysisAfterConfigChangeScoped` propagates cancellation to its caller
   (`runEnable`) so a cancelled per-file run is not treated as a successful completion. The
   public API binding in `extension.ts` extracts `.ok` to preserve the `Promise<boolean>` contract.

5. **Test updated** — `runAnalysisEnabledGate.test.ts` now asserts both `.ok` and `.cancelled`
   fields on the returned result object.

### Not changed

- The full-workspace `runAnalysis` path was already async — no change needed.
- The synchronous `runInWorkspace` function is retained; other callers in `cross-file-commands.ts`
  and `setup.ts` line ~1848 still use it.
- The bug report's larger suggestion (migrate from `dart analyze` CLI to `liveDiagnosticsModel` or
  `SaropaLspClient`) is a separate architectural change, noted in the bug file as remaining work.

### Verification

- `npx tsc --noEmit -p .` — clean (errors in `extension.ts` and `sectionedSidebar.ts` are
  pre-existing from other uncommitted changes, not from this fix).
- `npx tsc -p tsconfig.test.json --noEmit` — same pre-existing errors only.
- `runAnalysisEnabledGate.test.ts` — assertions updated to pin new return shape.
