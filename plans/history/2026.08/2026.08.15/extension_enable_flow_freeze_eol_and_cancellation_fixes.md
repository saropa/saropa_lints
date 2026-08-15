# Extension enable-flow freeze, mixed-EOL restore, and cancellation-propagation fixes

Three defects in the VS Code extension's setup flow (`extension/src/setup.ts`) allowed the editor to freeze indefinitely during "Enabling Saropa Lints," caused "Re-enable Plugin" to falsely report nothing to restore on files with mixed line endings, and let a canceled enable operation silently report success. All three are fixed.

## Defect 1 — synchronous spawn froze the editor during Enable

`runEnable` invoked `pub get`, the config write, and the analysis pass synchronously via a blocking `spawnSync`-based helper, holding the extension host thread for the full duration of each step on larger projects. The flow now runs these steps asynchronously under a cancellable `vscode.window.withProgress` notification, so the editor UI remains responsive and the user can cancel mid-flow.

## Defect 2 — mixed CRLF/LF line endings broke plugin-block restoration

`disablePluginsIntegration.ts`'s block-restore logic split file content on a single guessed EOL sequence (`content.split(guessedEol)`). On a file with genuinely mixed CRLF and LF line endings — which `analysis_options.yaml` can accumulate through different editors/tools writing to it over time — this split corrupted line boundaries, and `restorePluginsIntegration` returned `false` even though a valid disabled `plugins:` block was present, surfacing as "Re-enable Plugin: nothing to restore."

Fix: replaced the single-split approach with `splitLinesPreservingEol`/`normalizeInteriorEols`/`joinEolLines`, which tolerate mixed endings per-line instead of assuming one endings-style for the whole file.

A deep-review subagent additionally found, and confirmed via a standalone repro against the session's synthetic mixed-EOL fixture, that the pre-fix logic's `findPluginsBlock` — shared by both the restore path and the toggle-off ("Turn Off Lint Integration") path — was fed through the same broken split. So the toggle-off path could also silently no-op on a mixed-EOL file under the old code, not only the restore path. This was not directly observed against the user's real file (the original real-world evidence came from a different code path — the Dart-side `write_config` writer generating an already-disabled block directly), only proven against the synthetic fixture. The shipped fix covers both directions regardless, since both paths route through the same corrected split/join functions.

## Defect 3 — canceling Enable's final analysis step still reported success

`runAnalysisAfterConfigChangeScoped` caught `analysisResult.canceled` internally, logged it, and returned `void`. Back in `runEnable`, `success = true` executed unconditionally after that call regardless of whether the last step was actually canceled — so clicking Cancel during the final `dart analyze` step of "Enable" still reported success and flipped `saropaLints.enabled = true` as if the flow had completed normally.

Fix: `runAnalysisAfterConfigChangeScoped`'s return type changed from `Promise<void>` to `Promise<{ canceled: boolean }>`, with every return branch reporting its cancellation state. `runEnable` now destructures `{ canceled: analysisCanceled }` and, if true, logs the cancellation, flushes the report, and returns early without setting `success = true`. `applyTierChange`, the only other caller, ignores the return value and is unaffected (it never passes a cancellation token, so `canceled` is always `false` there).

## Regression coverage added for Defect 3

`runEnable` itself has no unit-test harness — it is a `vscode.window.withProgress`-wrapped flow with no injection seam for the `dart`/`flutter` child process, and this codebase's convention is to leave real process-spawning paths to manual Extension Development Host verification rather than unit tests (see `scanDaemonClient.test.ts`). Building a full `runEnable` harness was judged disproportionate to the fix.

Instead, a new test file, `extension/src/test/runInWorkspaceAsyncCancellation.test.ts`, pins the lower-level mechanism the whole cancellation chain depends on: `runInWorkspaceAsync`'s `cancelled` flag. It spawns a trivial Node child process (a temp script file, not `dart`/`flutter`) and asserts `cancelled: true` when a fake `CancellationToken` fires mid-run, and `cancelled: false` when the process exits cleanly first. This is the piece `runAnalysisAfterConfigChangeScoped` and `runEnable` both rely on to distinguish "canceled" from "succeeded" — no test of it existed before this change. `tsconfig.test.json`'s explicit `include` list was extended with the new file and its two dependencies (`src/setup.ts`, already present).

`applyTierChange` (setup.ts, tier-switch flow) still uses the synchronous `runInWorkspace` helper for its own config write and its `withProgress` is still `cancellable: false` — the same freeze-bug class Defect 1 fixed, left untouched because it was not the reported symptom.

## Verification

```
cd extension
npx tsc --noEmit -p tsconfig.json
node --max-old-space-size=8192 ./node_modules/typescript/bin/tsc -p tsconfig.test.json
node node_modules/mocha/bin/mocha "out-test/test/disablePluginsIntegration.test.js" "out-test/test/runAnalysisEnabledGate.test.js" "out-test/test/setupCompositeScaffoldGate.test.js" "out-test/test/formatAnalysisIssuesMessage.test.js" "out-test/test/runInWorkspaceAsyncCancellation.test.js" --timeout 10000
```
Clean type-check; 30/30 tests pass (7 pre-existing + 1 mixed-EOL test in `disablePluginsIntegration.test.ts` + 2 new cancellation tests).
