# Analyzer plugin lost on Lint integration off→on

Toggling the sidebar's "Lint integration" row Off commented out the `plugins:` block in `analysis_options.yaml`, but toggling it back On never restored it, so a project silently lost live in-editor diagnostics while the sidebar continued to report "Lint integration: On". The sidebar compounded this by reporting only the `saropaLints.enabled` setting, which does not control the analyzer plugin at all.

## Defect analysis

Two independent subsystems were presented through one control:

1. `saropaLints.enabled` (VS Code workspace setting) — gates scan-on-save delivery.
2. The top-level `plugins:` block in `analysis_options.yaml` — the only thing the Dart analysis server reads to decide whether to load the in-process plugin.

`runDisable` acted on **both** (setting to `false`, block commented out via `disablePluginsIntegration`). `runEnable` acted on **one** (setting to `true`), with an explicit code comment justifying the omission: Enable must not switch on the multi-GB in-process plugin as a side effect. That reasoning is sound in isolation but produced a non-invertible toggle — the single sidebar row's two directions were not inverses, so Off→On was lossy.

### Why the obvious fix is wrong

Keying the restore off the on-disk disable sentinel fails. `write_config_runner.dart` computes `willBeDisabled = isNewFile || wasDisabled` and wraps the block in the *same* sentinel for a brand-new project, because new projects deliberately default to the lighter daemon-only delivery. `config_writer.dart`'s `wrapPluginsYamlAsDisabled` documents that both producers emit an identical on-disk shape by design. A sentinel-based restore would therefore switch the heavy plugin on for every new user's first Enable — precisely the outcome the default exists to prevent.

### Evidence the defect was live

An affected project's commented block was in the **verbose** form (per-rule description comments). The Dart writer only ever emits the disabled block via `wrapPluginsYamlAsDisabled(..., compact: true)`; a verbose *commented* block is what the extension's own `disablePluginsIntegration` produces when it comments out a live verbose block. This indicates the block was live and was taken away by `runDisable`. Not conclusive on its own — a pre-`96d4ca93` writer could also emit a verbose disabled block.

## Changes

### Ownership memento (`extension/src/setup.ts`)

`runDisable` now records ownership in `context.workspaceState`, keyed by project root, and **only** when `disablePluginsIntegration` returns `'commented'` — a genuine live→disabled transition it performed itself. `'already-off'` and `'no-config'` never claim ownership, which is the branch that keeps new projects safe.

`runEnable` restores the block only while holding that claim, then clears it and restarts the analysis server. The claim is cleared even when `restorePluginsIntegration` returns `false`, so a hand-edited file cannot leave a stale claim behind. `runReenablePlugin` also releases the claim, so it cannot fight a subsequent Enable.

The memento — rather than on-disk state — is what makes the restore safe, for the reason given above. Accepted trade-off: `workspaceState` is per-machine, so on a fresh clone the claim is absent and Enable leaves the block alone, degrading to the previous behavior rather than guessing wrong in the expensive direction.

### Restore ordering

The restore runs before `write_config` is spawned. `restorePluginsIntegration` writes synchronously and the Dart subprocess re-reads the file, so `wasDisabled` observes a live block and keeps it live. Ordering the restore after `write_config` would have made the fix inert.

### Recovery path for a declared-but-dormant plugin

Restoring the block and restarting the analysis server are two steps in `runEnable`; cancelling between them leaves the block live but the plugin unloaded. `runReenablePlugin` previously reported "nothing to restore" in that state — a dead end, since the file looks correct and the only remedy was a manual window reload. It now detects an already-live block, restarts the server, and reports success.

### Sidebar honesty (`extension/src/views/configTree.ts`)

A dedicated row reports the `plugins:` block's real on-disk state (`live` / `disabled` / `absent`) via the new exported `getPluginsIntegrationState`. Every state maps to a real command — `verifyPlugin`, `reenablePlugin`, and `initializeConfig` respectively — preserving the view's "no dead rows" invariant. An earlier revision left the command undefined for `live` and `absent`, which broke the `every leaf has a click command` assertion in `test/views/overviewTreeFlat.test.ts` and would have shipped an unclickable row in the common case.

Four user-facing strings were added to `extension/src/i18n/locales/en.json` under `dashboards.controls.*`.

## Verification

`tsc --noEmit` clean on both `tsconfig.json` and `tsconfig.test.json`. Seven new tests in `extension/src/test/pluginDisableOwnership.test.ts` pin the ownership rules — including the two negative cases (already-disabled block, no plugins block) that guard the new-project default, per-root key isolation, and the already-live recovery path. The previously-broken sidebar assertion passes.

## Not verified

The end-to-end Off→On round trip was not exercised in a live VS Code window; `runEnable` requires a real `pub get` and `write_config` spawn, so only the unit-level ownership rules are pinned. The analysis-server restart is a guarded `executeCommand` against the Dart extension and is not asserted by any test. Translated locale catalogs were not regenerated, leaving the four new keys English-only in the non-English locales.
