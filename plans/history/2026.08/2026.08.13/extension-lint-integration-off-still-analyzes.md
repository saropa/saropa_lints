# Lint integration off still ran background analysis

Toggling "Lint integration" off in the sidebar only stopped in-editor
diagnostics; it did not stop the extension from spawning `dart analyze` in
the background. A user with the integration off still saw a "Running
analysis" progress notification sourced from the Saropa Lints output
channel.

## Root cause

`runAnalysis()` and `runAnalysisForFiles()` in `extension/src/setup.ts` had
no check on the `saropaLints.enabled` setting. Every caller — the manual
"Run Analysis" command, the `pubspec.lock` dependency-change watcher, the
config-change auto-run after `initializeConfig`/`enableRulePack`, and the
`saropaLints.runAnalysis` command itself — funneled through these two
functions without ever checking whether the integration was disabled.
Toggling the sidebar setting only flipped the config value and (per an
earlier, separate fix) commented out the `plugins:` block in
`analysis_options.yaml`; nothing gated the extension's own analyze runs
against the same flag.

Separately, `maybeNudgeCrashCoveredRule()` in
`extension/src/suite/crashCoverageNudge.ts` could still offer to enable a
disabled lint rule via a toast even while the whole integration was off.

## Fix

- `runAnalysis()` and `runAnalysisForFiles()` (`extension/src/setup.ts`) now
  return `false` immediately when `saropaLints.enabled` is `false`, before
  touching the progress UI or spawning a process. This is the single choke
  point every existing and future auto-trigger passes through, so gating it
  here covers all callers without duplicating the check at each call site.
- The manual `saropaLints.runAnalysis` command (`extension/src/extension.ts`)
  checks the setting explicitly and shows an informational message when
  blocked, since a user who clicks "Analyze" should be told why nothing
  happened rather than see silence.
- `maybeNudgeCrashCoveredRule()` now no-ops when the integration is off.
- Added the `notify.main.lintIntegrationOffCannotAnalyze` string to
  `en.json` and regenerated all translated locale catalogs.

A third, previously undiscovered bypass was found during the reflection
pass: `runAnalysisAfterConfigChangeScoped()` (also in `setup.ts`) calls
`dart`/`flutter analyze` directly and only checked the
`runAnalysisAfterConfigChange` setting, not `saropaLints.enabled`. Its two
callers are `runEnable()` (the `saropaLints.enable` command's own
post-config analysis, called *before* `enabled` is flipped to `true` — this
one legitimately needs to run regardless) and `applyTierChange()` (the
`saropaLints.setTier` command) — the latter had no legitimate reason to
bypass the gate and would run a full analyze even with the integration off.
Fixed by adding the same `enabled` check to the shared helper, with an
explicit `{ skipEnabledCheck: true }` opt-out passed only from the
`runEnable()` call site.

Also, the toolbar "Run Analysis" (▶) button (`package.json` view/title menu)
now carries `&& saropaLints.enabled` in its `when` clause, so it disappears
entirely while the integration is off rather than appearing clickable and
toasting a rejection message. The command remains reachable from the
command palette, which still shows the informational toast.

Deliberately left alone: Drift Advisor polling and the TODOs/HACKs
workspace scan, each gated by their own independent setting rather than
`saropaLints.enabled`; the pub.dev upgrade checker, which is unrelated to
lint analysis; the `write_config` calls themselves (writing
`analysis_options.yaml` while disabled is harmless since the plugin block
stays commented out).

## Testing

Added `extension/src/test/runAnalysisEnabledGate.test.ts` (registered in
`tsconfig.test.json` and the `test` npm script), asserting both
`runAnalysis` and `runAnalysisForFiles` resolve to `false` without
attempting to spawn a process when `saropaLints.enabled` is `false`. Ran
scoped to the new test plus the sibling `setup.ts` tests
(`disablePluginsIntegration.test.ts`, `setupCompositeScaffoldGate.test.ts`,
`saropaDashboardsView.test.ts`): 21 passing, 0 failing. The unrelated
`commandCatalogRegistry` test failure (missing catalog entries for seven
pre-existing commands) was confirmed present on a clean `main` checkout
before this change and left untouched.

`applyTierChange()` / `runSetTier()` (the newly-found third bypass) has no
dedicated automated test: asserting "no process was spawned" would require
mocking `child_process` around `runInWorkspace`, which this test suite does
not currently do anywhere. The fix there reuses the same reviewed
conditional-early-return pattern as the other two gated functions; verified
by code inspection and the full-project `tsc --noEmit` type-check (0
errors), not by a dedicated unit test. Flagged here for anyone adding
`child_process` mocking to this suite later.

Ran `tsc --noEmit` across the full extension source after all edits: 0
errors.
