# PROPOSAL: Show the `saropaLints.enabled` Master Switch on the Engines Screen

**Status: Implemented**

Created: 2026-09-08
Type: Tooling / Infrastructure
Related rules: N/A (extension-native — Health Panel UI, `extension/src/systemHealth/engineCardsHtml.ts`)

---

## Summary

The Health Panel's "Diagnostic Engines" section (`buildEnginesSection` in `extension/src/systemHealth/engineCardsHtml.ts`) shows three cards — Analyzer Plugin, Scan Daemon, LSP Server — each with its own ON/OFF toggle. There is no card for the overall master switch, `saropaLints.enabled`, even though that single setting gates scan-on-save entirely (see the sibling report `infra_dead_setting_scanonsave_enabled_key.md`) and materially affects at least the Scan Daemon and Analyzer Plugin cards' own `enabled` computation. A user looking at "the engines screen" to control the extension has no way to find or flip the master switch from that screen — they have to already know it exists and go find it in raw Settings.

---

## Motivation

Concrete case that surfaced this: a user changed a rule severity in `analysis_options_custom.yaml`, needed the Scan Daemon to pick up the new config, and went to the Engines screen expecting a master control. They found three per-engine toggles but no overall one, and — reasonably, but incorrectly — assumed toggling `saropaLints.scanOnSave.enabled` (found in their own `.vscode/settings.json`) was the master switch for that engine. It is not (see the sibling bug report); the real gate is `saropaLints.enabled`, read directly by `getScanDaemonStatus()` in `extension.ts:1828-1843`:

```ts
getScanDaemonStatus: (): EngineStatus => {
  const scanOnSaveEnabled = vscode.workspace
    .getConfiguration('saropaLints')
    .get<boolean>('enabled', true) ?? true;
  ...
```

The Engines screen already computes and displays state that *depends on* `saropaLints.enabled` (both `getAnalyzerPluginStatus` and `getScanDaemonStatus` factor it in) without ever showing that setting itself as a controllable row. That's the same "two truths on one screen" class of bug the P3 fix in `PLAN_ext_ui_sidebar_reset.md` (referenced in a comment right above `getScanDaemonStatus`) already fixed once for the Scan Daemon card's own honesty — this proposal extends that principle: don't just make each card honest about the master switch's effect, surface the master switch itself.

**Correction to the premise above:** `saropaLints.enabled` is not actually absent from the toggle wiring today. The Analyzer Plugin card's toggle handler (`extension.ts:1907-1925`, inside `HealthPanel.onToggle`) already writes it directly as a side effect:

```ts
} else if (engine === 'analyzer') {
  if (enabled) {
    await runReenablePlugin(context);
    await cfg.update('enabled', true, vscode.ConfigurationTarget.Workspace);   // master switch
    ...
  } else {
    await runDisable(context);
    await cfg.update('enabled', false, vscode.ConfigurationTarget.Workspace); // master switch
    ...
  }
```

(`cfg` = `vscode.workspace.getConfiguration('saropaLints')`, defined at `extension.ts:560`.) So the Analyzer Plugin ON/OFF toggle is a de facto master switch already — flipping it off also clears `saropaLints.enabled`, which is why `getScanDaemonStatus` goes "stopped" the moment Analyzer Plugin is turned off, not just when scan daemon itself is toggled. Adding a *separate* master-switch card that writes the same key means two controls racing on one setting with different blast radii: the new card would only flip `enabled`, while the Analyzer Plugin card flips `enabled` *and* rewrites the on-disk `plugins:` YAML block via `runDisable`/`runReenablePlugin`. That divergence needs to be resolved in the design, not discovered during implementation — see Edge Case 1 below.

---

## Detection / Behavior

Add a fourth card (or a header-level toggle above the three engine cards) labeled something like "Saropa Lints (master switch)" that reads/writes `saropaLints.enabled` directly, using the existing `HealthPanel.onToggle` dispatch pattern already used for `analyzer` / `scanDaemon` / `lspServer` in `extension.ts:1897-1940`.

### Should show (desired)

- A card/row for the master switch, visually distinguished from the three engine cards (e.g. placed above them, or with a divider) since it's a different kind of control — it's the thing that gates the others, not a peer engine.
- Toggling it off should visibly reflect in the other three cards' status immediately (they already partially react — `getScanDaemonStatus` and `getAnalyzerPluginStatus` both read it — but there's currently no direct control to flip it from this screen at all).

### Should NOT happen (current state, to be fixed)

- User opens the Engines screen looking for "the on/off switch for the whole extension" and finds none — has to leave the panel and search Settings.

---

## Proposed Tier

N/A — extension UI feature, not a lint rule.

---

## Edge Cases

1. **Interaction with per-engine toggles** — if the master switch is off, should the three engine toggles be disabled/greyed out (since they're moot), or left interactive but ineffective? Recommend greying them out with a tooltip ("enable the master switch first") to avoid the exact "toggled it, nothing happened" confusion that prompted this report.
   **Also:** the Analyzer Plugin toggle already writes `saropaLints.enabled` today (see Motivation correction above) alongside its own YAML-block side effect. A new master-switch card must not fight this — either (a) the Analyzer Plugin toggle handler stops touching `saropaLints.enabled` and only manages the YAML block, and the new master card becomes the sole writer of `enabled`, or (b) the new card is documented as reflecting the same key the Analyzer Plugin toggle already flips, with the master toggling OFF also visually flipping the Analyzer Plugin card to OFF (and vice versa is NOT expected — re-enabling the master should not silently re-enable the analyzer YAML integration). Option (a) is cleaner and avoids two code paths writing one setting; pick it unless there's a reason the coupling was intentional.
2. **Workspace vs. global setting scope** — `saropaLints.enabled` can be set at either scope; the existing per-engine toggles write to `vscode.ConfigurationTarget.Workspace` (see `extension.ts:1906`, `:1919`, `:1923`). The master switch card should follow the same convention for consistency.
3. **Naming clarity** — the card label should make clear this is the extension-wide kill switch, not a fourth peer "engine", so users don't read it as "there are 4 engines now."

---

## Alternatives Considered

- **Leave it in Settings only.** Rejected — the Engines screen is exactly where a user goes to reason about "what's running and why," and per the sibling bug report, users are already reaching for a control on this screen and picking the wrong one when it's absent.
- **Just fix the dead-key bug and call it done.** Insufficient on its own — even with `scanOnSave.enabled` properly deprecated/warned-about, the user's underlying need (a visible master switch on the Engines screen) is still unmet.

---

## Decision

Accepted — option (b): the master switch card writes `saropaLints.enabled`; the Live Analysis toggle keeps writing it too (`runDisable` in `setup.ts` clears it, so option (a) would require changing the shared sidebar disable command). Only the Scan on Save card dims when master is off: it is the only engine gated by that setting, while the analyzer YAML block and LSP setting are independent.

---

## Implementation Notes

- `extension/src/systemHealth/engineCardsHtml.ts` — `buildEnginesSection` / `buildEngineCard` for the rendering pattern to extend or a new sibling function.
- `extension/src/extension.ts:1897-1940` — `HealthPanel.onToggle` dispatch; add a fourth `engine === 'master'` (or similar) branch that reads/writes `saropaLints.enabled` via `vscode.workspace.getConfiguration('saropaLints').update('enabled', ...)`.
- `extension/src/systemHealth/healthPanel.ts:18-24` — the `HealthPanelMessage` toggle union type (the `type: 'toggle'; engine: ...` member is line 21) needs the new engine key added.
- Consider whether `getAnalyzerPluginStatus` / `getScanDaemonStatus` / `getLspServerStatus` need any change, or whether they already correctly reflect master-switch state (per the code read during investigation, `getScanDaemonStatus` already does; `getAnalyzerPluginStatus` and `getLspServerStatus` should be checked for the same).

---

## Commits

<!-- Add commit hashes as implementation lands -->

---

## Finish Report (2026-11-20)

The Engines screen had no control for the extension-wide `saropaLints.enabled` setting. A master switch card now sits above the engine cards in the Health Panel and writes that setting at Workspace scope.

- Only the Scan Daemon card dims when the master is off (the sole engine gated by the setting). The dimmed card keeps its tooltip reachable (no `pointer-events: none`) and shows `cursor: not-allowed`.
- `buildEnginesSection` derives the gate from the master entry when the flag is omitted.
- A failed settings write (no workspace folder) shows an error toast and skips the context and status-bar updates, so the UI never shows a state that was not applied.
- The sidebar "Engines: N running" count excludes the master entry.
- Tests: `engineCardsHtml.test.ts` (master placement, scan-daemon-only dimming, no dimming when on or unspecified, derived gate) and `sidebarStatusEngines.test.ts`. Both `tsc` runs are clean; 18 tests pass in the two suites.
- A folder-level `saropaLints.enabled` value outranks the Workspace write: the master card shows a note when one exists, and a warning appears after a click that did not take effect.
- Known, accepted: analyzer OFF still clears `saropaLints.enabled` via `runDisable` (option b).
- Locale catalogs are stale for the new `en.json` keys; regeneration is a publish-time gate.
- Status: visual verification at F5 (light and dark themes, ~380px) is pending, so this file stays in `bugs/` until a screenshot exists.
