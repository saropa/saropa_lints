# Extension: upgrade-notification hang + clickable "Scanned X ago" rescan pill

Accepting an upgrade from the Package Dashboard's "Upgrading Saropa Lints to X"
progress notification left it pinned open with an unresponsive Cancel button
until VS Code was reloaded. The upgrade flow ran a full project analysis through
a synchronous child process on the same call path, which blocked the extension
host event loop for the entire analysis duration, freezing the notification and
the rest of the extension UI. Separately, the dashboard offered no way to
re-surface the upgrade notification once dismissed: the background pub.dev check
is double-throttled (an anti-thrash time window plus a dismissed-version memory),
so there was no deterministic path to re-test the upgrade flow.

## Finish Report (2026-06-15)

### Scope

(B) VS Code extension (`extension/`, TypeScript). No Dart lint-rule, analyzer, or
`example/` changes.

### Deep Review

- **Logic & Safety.** `runAnalysis` now resolves through the async, cancellable
  `runInWorkspaceAsync` instead of the blocking `runInWorkspace`. The cancellation
  branch returns early after flushing the report and setting `ok = false`, matching
  the existing cancellation handling in `runInitializeConfig`. No new recursion or
  shared mutable state.
- **Architecture & Adherence.** The clickable pill reuses the existing message-bridge
  pattern (`postMessage` from the webview script → `_handleMessage` in the panel
  controller) rather than introducing a parallel channel. `StatusPill` gained one
  optional `actionId` field instead of a parallel "interactive pill" type, so the
  shared `buildStatusLine` builder remains the single source for pill rendering.
  `forceUpgradeCheck` delegates to the existing `checkForUpgrade` after clearing the
  persisted throttle state, rather than duplicating the fetch/compare logic.
- **Linter-Specific Integrity.** SKIPPED [B-NOT-IN-SCOPE] — no lint rules touched.
- **Performance.** Removing the synchronous full-project analyze from the event loop
  is the core performance correction; analysis now streams output and stays
  cancellable. The pill click triggers the same rescan command already used by the
  toolbar button, adding only one extra pub.dev version check.
- **Documentation Quality.** The cancellable rationale is documented at the
  `runAnalysis` progress block; `forceUpgradeCheck` carries a doc header explaining
  why it bypasses both throttles and why an up-to-date project correctly shows no
  prompt.

### Testing Validation

**A. Existing-test audit.** Grepped `src/test/` for the changed symbols
(`buildStatusLine`, `StatusPill`, `forceUpgradeCheck`, `checkForUpdatesNow`,
`rescanAndCheckUpdates`, `pill-action`, `lastScanRescan`, `runAnalysis`). Matches:
`commandCatalogRegistry.test.ts` (command parity) and the report-html/report-webview
suites. No assertion pinned the last-scan pill as a `<span>`, so the span→button
change broke no snapshot. The command-parity test required the new
`saropaLints.checkForUpdatesNow` command to also appear in the command catalog
registry; the registry gained a matching entry under "Package Vibrancy — Updates".

**B. Test execution.**
- `npm run check-types` — clean.
- `tsc -p tsconfig.test.json` — clean.
- `mocha` on `upgradeChecker`, `report-html`, `report-webview` (with the vscode mock
  required first) — 164 passing.
- `mocha` on `commandCatalogRegistry` — 16 passing, 1 failing. The single failure is
  pre-existing at HEAD: package.json commands `saropaLints.enableRule` and
  `saropaLints.openFinding` are absent from the catalog registry, independent of this
  change. The new `checkForUpdatesNow` command is not in the failure's missing list,
  and every catalog-integrity assertion (no duplicates, non-empty title/description/
  icon, valid category, A→Z title sort) passes, validating the added entry.

### Extension Localization

`en.json` had two existing values edited (`packageDashboard.status.lastScanTitle`,
`lastScanUnknownTitle`) to describe the pill's new click behavior; their placeholder
sets are unchanged (`{timestamp}` retained, none added or removed), so no call-site
signatures shifted. One manifest key was added: `command.checkForUpdatesNow.title` in
`package.nls.json`. Translated locale catalogs and `package.nls.<lang>.json` are now
stale for these strings and require regeneration through the machine-translation
pipeline, which is run on its own cadence and is not executed as part of this change.
The publish coverage gate (`generate_locales.py --fail-on-missing`) will block a
release until the catalogs are regenerated.

### Project Maintenance

- CHANGELOG: `[Unreleased]` gained a `Fixed (Extension)` entry (notification hang) and
  an `Added (Extension)` entry (clickable pill + command).
- README verified — no updates needed (no rule-count or product-fact change).
- pubspec / dependencies — unchanged.
- Roadmap — no lint entries to remove.
- No bug archive — task did not close a `bugs/*.md` file.

### Core Logic Diff Summary

- `setup.ts` `runAnalysis`: synchronous `runInWorkspace(... 'analyze')` →
  `await runInWorkspaceAsync(... { token })`; progress made `cancellable: true` with a
  cancellation early-return.
- `upgrade-checker.ts`: new exported `forceUpgradeCheck` clears the `STATE_KEY`
  workspace state, then calls `checkForUpgrade`.
- `extension.ts`: registers `saropaLints.checkForUpdatesNow` → `forceUpgradeCheck`.
- `dashboardHero.ts`: `StatusPill.actionId` optional field; `buildStatusLine` renders a
  `<button class="pill pill-action">` when set, otherwise the inert `<span>`.
- `dashboardChromeStyles.ts` + `report-styles.ts`: `.pill.pill-action` button reset
  (pointer cursor, hover, focus-visible ring).
- `report-html.ts`: last-scan pill carries `actionId: 'lastScanRescan'`.
- `report-script.ts`: click handler posts `{ type: 'rescanAndCheckUpdates' }`.
- `report-webview.ts`: handles `rescanAndCheckUpdates` → rescan + showReport +
  `checkForUpdatesNow`.
- `commandCatalogRegistry.ts`: catalog entry for the new command.

### Outstanding

- Machine-translation regeneration of the locale and NLS catalogs for the edited and
  added strings (run separately; not part of this change).
- Pre-existing command-catalog parity gap for `enableRule` / `openFinding` is unrelated
  and left untouched.
