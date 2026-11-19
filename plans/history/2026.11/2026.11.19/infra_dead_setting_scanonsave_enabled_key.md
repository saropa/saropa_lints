# BUG: `saropaLints.scanOnSave.enabled` — Dead Setting, No Effect, No Warning

**Status: Fixed (pending commit)**

Created: 2026-09-08
Rule: N/A (extension-native infrastructure, not a Dart AST rule)
File: `extension/src/scanOnSave/scanOnSaveController.ts` (line ~250)
Severity: High — silently defeats the user's attempt to fix a stale-diagnostic problem, costing multiple round-trips with no error or warning anywhere
Rule version: N/A

---

## Summary

`saropaLints.scanOnSave.enabled` is a settings key that a consumer project (`d:\src\contacts\.vscode\settings.json`) has set to `true`, and that a user reasonably tried toggling off/on to force the Scan Daemon to reload stale config. It has **zero effect** — the code path that used to read it was deleted and scan-on-save gating was merged entirely into the single master switch `saropaLints.enabled`. The key is also **absent from `package.json`'s configuration contribution**, so VS Code gives no "unknown setting" warning either. The result: a real-looking, settable, project-committed setting that silently does nothing, with no signal anywhere that it's dead.

---

## Attribution Evidence

This is an extension-native issue (TypeScript, VS Code extension host), not a Dart AST rule — filed per the "Rule Sources" split in `ISSUE_REPORT_GUIDE.md`.

```bash
# Positive — the dead code path/comment documenting the removal lives here
grep -rn "scanOnSave.enabled" extension/src/scanOnSave/scanOnSaveController.ts
# extension/src/scanOnSave/scanOnSaveController.ts:243:   * `scanOnSave.enabled` setting (default off); that setting was unreachable

# Negative — key is NOT declared in the extension's settings schema
grep -n "saropaLints.scanOnSave.enabled" extension/package.json
# 0 matches
```

**Emitter / relevant code:** `extension/src/scanOnSave/scanOnSaveController.ts:240-252` (`scanOnSaveIsEnabled`) and `:514-517` (`_isEnabled()`, which reads only `saropaLints.enabled`).

---

## Reproducer

Not a Dart snippet — a settings/workflow reproduction:

1. In any consumer project's `.vscode/settings.json`, set:
   ```json
   "saropaLints.enabled": true,
   "saropaLints.scanOnSave.enabled": true
   ```
2. Edit `analysis_options_custom.yaml` to change a rule's severity (e.g. add a `severities:` override disabling a rule that's currently firing).
3. Toggle `saropaLints.scanOnSave.enabled` to `false`, then back to `true` in Settings UI, expecting the Scan Daemon to restart and pick up the new config.
4. Save the affected `.dart` file.

**Frequency:** Always — the setting is never read by any code path.

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | Either: (a) the setting works as it appears to (restarts/gates the Scan Daemon), or (b) VS Code / the extension warns that the key is unrecognized or deprecated, or (c) the key is removed from consumers' settings via a migration, same as the `analysis_options_custom.yaml` legacy-key auto-migration already does for other stale config. |
| **Actual** | The Problems panel does not even flicker. No log line, no warning, no migration. The user has no way to discover the key is dead short of reading extension source. |

---

## Root Cause

`scanOnSaveController.ts:240-252`:

```ts
/**
 * Scan-on-save is the delivery path for `saropaLints.enabled` — there is no
 * separate toggle for it. A prior revision gated it behind its own
 * `scanOnSave.enabled` setting (default off); that setting was unreachable
 * for anyone who hadn't read the changelog, so turning the extension "on"
 * via the master switch silently did nothing. Deleted in favor of this
 * single switch.
 */
export function scanOnSaveIsEnabled(masterEnabled: boolean): boolean {
  return masterEnabled;
}
```

The fix for the *old* confusion (a separate toggle nobody could find) removed the toggle's *behavior* but left the *key* fully valid to set in any `settings.json` with no schema entry, no deprecation marker, and no runtime check for its presence. This is the same class of bug in the opposite direction: previously "the real toggle is unreachable", now "a fake toggle is reachable and looks real."

Compounding factor: `config_loader.dart`'s `_autoMigrateLegacyPluginKeys` already has precedent for silently migrating/cleaning up stale config keys (`log_level`, `lane`, `memory_mode`, `rule_packs` moved out of the `plugins:` block). No equivalent migration exists on the extension side for this dead settings key.

### Hypothesis A: package.json should mark the key deprecated

If VS Code's configuration schema still declared `saropaLints.scanOnSave.enabled` with `"deprecationMessage"` or `"markdownDeprecationMessage"`, the Settings UI would show a strikethrough/warning inline. Currently it's not declared at all, so even that passive signal is unavailable.

### Hypothesis B: the extension should actively detect and warn

On activation, scan `vscode.workspace.getConfiguration('saropaLints.scanOnSave').get('enabled')` — if the key is explicitly set (not just defaulted), log a one-time warning to the output channel and/or show a toast: "saropaLints.scanOnSave.enabled has no effect — use saropaLints.enabled instead."

---

## Suggested Fix

Prefer Hypothesis B (active warning) since the key was fully removed from `package.json` (Hypothesis A requires re-adding a declaration just to deprecate it, which reintroduces the "unreachable but real-looking" surface). On extension activation:

```ts
const legacyScanOnSave = vscode.workspace
  .getConfiguration('saropaLints.scanOnSave')
  .inspect<boolean>('enabled');
if (legacyScanOnSave?.workspaceValue !== undefined || legacyScanOnSave?.globalValue !== undefined) {
  outputChannel.appendLine(
    '[scan-on-save] saropaLints.scanOnSave.enabled is set but has no effect — ' +
    'scan-on-save is now gated entirely by saropaLints.enabled. Remove this key.',
  );
}
```

---

## Fixture Gap

N/A — extension-native, no Dart fixture. A unit test in `extension/src/test/scanOnSave/` should assert the warning fires when the legacy key is present in either scope.

---

## Changes Made

Implemented Hypothesis B (active warning), not Hypothesis A:

- `extension/src/scanOnSave/scanOnSaveController.ts` — added `_warnIfLegacyScanOnSaveKeySet()`,
  called on activation and again whenever `saropaLints.scanOnSave.enabled` changes. Uses
  `getConfiguration('saropaLints.scanOnSave').inspect('enabled')` (not `get`) to distinguish
  "never set" from "explicitly set", since the whole point is catching a user who toggles the
  dead key back to its default value. Logs to the output channel every time it's detected, and
  shows a one-time `showWarningMessage` toast per session (a config reload from an unrelated
  setting, e.g. tier, must not re-toast).
- `extension/src/i18n/locales/en.json` — added `scanOnSave.legacyKeyWarning`.
- `extension/src/test/vibrancy/vscode-mock.ts` — added `inspect()` to the mocked
  `getConfiguration()` result (previously only `get`/`update` existed), since the fix needed it.

Not re-declaring the key in `package.json` (Hypothesis A) — that would reintroduce the
"unreachable but real-looking" schema surface. Not adding a `config_loader.dart`-style key
migration — this is a TypeScript-side extension setting, not a Dart plugin config key, so there
is no migration path parallel to `_autoMigrateLegacyPluginKeys`.

---

## Tests Added

- `extension/src/test/scanOnSave/scanOnSaveController.test.ts` — `legacy scanOnSave.enabled key
  warning` describe block: asserts the output-channel line and the one warning toast fire when
  the key is set, and that both stay silent when it isn't.

Verified: `npx tsc --noEmit -p .` and `npx tsc -p tsconfig.test.json` clean; scoped mocha run
(`out-test/test/scanOnSave/**/*.test.js`) — 91 passing, including the 2 new cases.

---

## Commits

0d5162e08 fix: harden Explain-rule panel and legacy scanOnSave key detection

---

## Environment

- saropa_lints version: 15.0.3 (per `analysis_options.yaml` commented `plugins:` block in the reporting project)
- Dart SDK version: unrecorded
- custom_lint version: N/A (this project runs the native plugin / scan daemon, not custom_lint)
- Triggering project/file: `d:\src\contacts\.vscode\settings.json` (`saropaLints.scanOnSave.enabled: true`)
