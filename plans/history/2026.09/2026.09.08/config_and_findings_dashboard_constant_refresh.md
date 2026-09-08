# Config Dashboard and Findings Dashboard: constant refresh while typing

The Config Dashboard ("Saropa Lints Config") and the Findings Dashboard both reassigned the
entire webview HTML document on background events (analyzer diagnostics ticks, config-file
saves, workspace tree refreshes) with no regard for whether the user currently had focus in a
search box or text field, making both panels effectively unusable for searching or editing
whenever the Dart analyzer was active — which, during normal editing, is nearly continuously.

## Root cause

Both panels' `refresh()`/`rebuildDashboardHtml()` paths ended in an unconditional
`webview.html = <freshly built HTML string>`. VS Code treats this as a full document reload:
focus, unsubmitted input values, scroll position, and any transient client-side DOM state
(e.g. the Config Dashboard's client-rendered "Matching rules" panel) are destroyed and rebuilt
from scratch. The trigger for these reassignments was background, not user-initiated:

- `extension.ts`'s `vscode.languages.onDidChangeDiagnostics` listener (400ms debounce) called
  `rulePacksWebviewProvider.refresh()` unconditionally on every diagnostics change anywhere in
  the workspace.
- `violationsWideReportView.ts` had its own `onDidChangeDiagnostics` listener (500ms debounce)
  with partial mitigations (visible-only, content-signature no-op guard) that still rebuilt on
  every *genuine* diagnostics change — which happens on every analysis pass while a Dart file is
  being actively edited with the dashboard open.
- `refreshFindingsDashboardIfOpen()` (called from `IssuesTreeProvider.onDidChangeTreeData`, save
  watchers, and locale reload) had the same unconditional-rebuild behavior.

The Config Dashboard's "Matching rules" → "in `<package>`" links (reported separately as not
working) were a symptom of the same bug: that panel is populated entirely by client-side
JavaScript in response to live search input and is never round-tripped through the server-side
HTML builder, so a background `webview.html` reassignment silently wipes it (and its search box
contents) out from under the user.

The Config Dashboard additionally never persisted `<details>` open/closed state across a
rebuild — every accordion reset to its hardcoded default on every refresh. The Findings
Dashboard already had this persistence (`SECTION_STATE_STORAGE_KEY` /
`loadPersistedSectionState()`); the Config Dashboard did not.

## Fix

Both webviews now track focus on editable controls client-side (`focusin`/`focusout` on
`INPUT`/`TEXTAREA`/`SELECT`/contenteditable elements) and post `uiFocus`/`uiBlur` to the
extension host. While a field is focused, background-triggered rebuilds queue a pending flag
instead of reassigning `webview.html`; the queued rebuild replays on `uiBlur` so no update is
silently dropped — just delayed until it is safe to redraw. Explicit user-initiated actions
(clicking a toggle, changing tier, submitting a form) still refresh immediately as before,
since those call sites were left unguarded.

The client-side focus-tracking script was needed by both dashboards independently (they hit the
same class of bug via separate implementations), so it was extracted into a single shared
export, `getFocusTrackingScript()` in `extension/src/views/dashboardHero.ts`, alongside the
file's existing shared dashboard-script helpers (`getAnnouncerScript`,
`getFullWidthToggleScript`).

The Config Dashboard's six persistable `<details>` sections (packs "For your project" / "All
packages", each domain sub-group, Disabled rules, Shed rules, Style & opinions) now carry a
stable `id` and read/write their open/closed state through `context.workspaceState`, matching
the pattern the Findings Dashboard already used (`SECTION_STATE_STORAGE_KEY` equivalent, named
`saropa.configDashboard.sectionState`).

`RulePacksWebviewProvider`'s constructor gained a required `vscode.Memento` parameter (the
extension's `context.workspaceState`) to back this persistence; both call sites
(`extension.ts`, `extension/src/test/ux/generate-pages.ts`) were updated.

`RulePacksWebviewProvider.onDidDispose` was found (during review) to leak the interaction-guard
state: closing the panel while a field had focus (e.g. clicking the tab's close button instead
of blurring first) left `_userInteracting` stuck `true` forever, since the fresh webview on
reopen has no focused element to fire the `uiBlur` that would normally clear it — every
subsequent `refresh()` would silently no-op and the dashboard would stay blank until the
extension host restarted. Fixed by resetting both interaction-guard fields inside
`onDidDispose`, mirroring the reset `violationsWideReportView.ts` already performed for its own
equivalent flags.

## Files changed

- `extension/src/rulePacks/rulePacksWebviewProvider.ts` — interaction guard, section-state
  persistence, dispose-time reset, constructor signature.
- `extension/src/rulePacks/configDashboardScript.ts` — focus-tracking wiring (now via the shared
  helper), `<details>`-toggle persistence wiring.
- `extension/src/views/violationsWideReportView.ts` — interaction guard on the diagnostics
  listener and `refreshFindingsDashboardIfOpen`.
- `extension/src/views/violations-dashboard-script.ts` — focus-tracking wiring (now via the
  shared helper).
- `extension/src/views/dashboardHero.ts` — new shared `getFocusTrackingScript()` export.
- `extension/src/extension.ts` — updated `RulePacksWebviewProvider` construction to pass
  `context.workspaceState`.
- `extension/src/test/ux/generate-pages.ts` — updated the same constructor call with a fixture
  `vscode.Memento` stand-in.
- `CHANGELOG.md` — Fixed (Extension) entries under the existing `[16.3.0] — Unreleased` section.

A rename plan for package-first rule IDs (`isar_avoid_cached_stream` vs
`avoid_cached_isar_stream`) was written separately as a planning-only deliverable:
`plans/PLAN_rule_id_package_first_rename.md` — not implemented, no code changed for it.

## Verification

- `npx tsc --noEmit -p .` and `npx tsc -p tsconfig.test.json --noEmit`: clean, no errors.
- `npm run compile`: produced a fresh `dist/extension.js`.
- Scoped mocha: `violationsDashboardHtml.test.js` (46/46) and
  `configDashboardScriptOptimizerEmbed.test.js` (8/8) pass. `rulePacksWebviewProvider.test.ts`
  and `configFileCardCoverage.test.ts` require the real `vscode` module (VS Code Extension Test
  Host) and cannot run from this environment — confirmed pre-existing/environmental by
  reproducing the identical `MODULE_NOT_FOUND: vscode` failure on a clean `HEAD` stash.
- Not visually verified: neither dashboard was exercised in a live Extension Development Host
  (F5) from this session, per the project's own extension-verification protocol — an agent
  session cannot launch one. A human needs to reload the extension and confirm: typing in the
  Config Dashboard's search fields (pack search, disabled-rules search, stylistic search,
  banned-usage identifier/reason) is not interrupted while diagnostics are actively changing
  elsewhere; the "in `<package>`" rule-finder links now work; section expand/collapse survives
  a refresh and a panel close/reopen; the Findings Dashboard's text filter behaves the same way.
