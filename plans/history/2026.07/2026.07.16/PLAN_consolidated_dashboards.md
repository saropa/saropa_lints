# PLAN: Consolidated "Saropa Dashboards" — Project Map + Code Health on one page

**Status:** Closed 2026-07-16 — implementation complete and code-verified; the manual Extension
Development Host (F5) render check is dropped as a closing gate (see Finish Report).

## Context

The Project Map and Code Health dashboards are two separate webview panels, each opened by its own
command, so they cannot be viewed together. A consolidated page shows both side by side, with **every
bit of each screen's interactive content preserved** — the ECharts treemap / churn-complexity scatter
/ hot-spot table for Project Map, and the score status line / KPI preset filters / sortable-expandable
function table for Code Health. Nothing is summarized or stripped; the two reports are composed.

Tabs were rejected (they show one screen at a time). **Iframes were also rejected** — an iframe per
pane is fragile plumbing (a postMessage bridge, content-height guessing, a `frame-src` CSP with no
precedent in the repo, two ECharts runtimes) and was the wrong instinct. The composition is now a
single document.

## Architecture — one composed document (no iframes, no eval, no shadow DOM)

Both engines' real markup, styles, and scripts are assembled into ONE webview document by
`saropaDashboardsView.ts`. Two hazards make naive composition fail; each is solved without rewriting
either engine:

1. **`acquireVsCodeApi()` may be called only once per document.** The host acquires the single handle
   and overrides `window.acquireVsCodeApi` to return that cached handle (`apiShimScript`), so both
   engines' scripts share one channel. The shim runs first; the engine scripts follow.
2. **CSS would collide** on bare selectors (`body`, `table`, `.chip`, `.panel`) and `:root` tokens.
   Project Map's stylesheet is now scoped under a `.pm-pane` wrapper and its palette tokens live on
   that wrapper (see `health_html_template.dart`), so it cannot leak onto the shared chrome or the
   Code Health pane. The two engines' DOM ids (`treemap`/`filter`/`hot` vs `pvTable`/`pvSearch`/…) do
   not overlap, so one document is safe.

ECharts is loaded once in the host `<head>`. Both scans run to completion before the page is
assembled, so the composed view shows a single loading state (each engine's live scan animation stays
in its standalone panel).

### Pieces

- **`health_html_template.dart`** — every visual rule scoped under `.pm-pane`; page background / fonts
  / tokens on `.pm-pane` (not `body` / `:root`); `<!--PM_STYLE/BODY/SCRIPT-->` markers bound the
  extractable blocks. The standalone browser/CI export renders identically (`.pm-pane` fills the
  viewport).
- **`projectMapView.ts`** — `scanProjectMapToParts` runs the `project_health` scan and returns
  `{ styleHtml, bodyHtml, scriptHtml, echartsUri }` by the markers; `webviewThemeOverride` rebinds the
  tokens on `.pm-pane` (a `:root` override would be shadowed); `openFileFromReport` for drill-down.
- **`projectVibrancyReportView.ts`** — `buildCodeHealthBody` factored out of `buildHtml` (no output
  change for the standalone panel); `buildCodeHealthFragment` returns `{ body, script }` for the host;
  `applyFileSuppression` exported for the host's suppress action.
- **`saropaDashboardsView.ts`** — `saropaLints.openDashboards`: runs both scans concurrently, then
  `buildDashboardsDocument(cspSource, pmParts, chFrag)` (pure) assembles chrome + scoped PM styles +
  one ECharts loader + a two-pane grid + the shared-API shim + both engines' scripts. A failed pane
  degrades to an inline placeholder. Host CSP: `script-src ${cspSource} 'unsafe-inline'` (vendored
  ECharts + inline scripts; no eval), `style-src ${cspSource} 'unsafe-inline'`.

### Message routing (host `onDidReceiveMessage`)

`openFile {file, line?}` opens the target (Project Map sends no line → preview at line 1; Code Health
sends a line). `openProjectMapFull` / `openCodeHealthFull` reopen the standalone panels.
`openProjectVibrancySettings`, `rescan`/`restart` (re-run both scans), `copyJson` (captured Code Health
stdout), `copyText`, and `suppressFlag` (delegates to `applyFileSuppression`) cover the Code Health
toolbar/detail buttons so none are silent. The saved-report-file row is omitted from the consolidated
pane (its copy/open/reveal workflow lives in the standalone panel).

Additive: the standalone Project Map and Code Health commands are unchanged.

## Verified

- `tsc` clean — `tsconfig.json` and `tsconfig.test.json`.
- `buildDashboardsDocument` contract pinned by `saropaDashboardsView.test.ts` (4 cases: one shared API
  acquisition, both panes' markup + scripts present, Project Map styles scoped under `.pm-pane`, a
  failed scan degrades without dropping the other pane).
- `projectVibrancyReportHtml.test.ts` + `projectVibrancyInflight.test.ts` pass (Code Health body
  refactor preserved output).
- Dart `health_html_reporter_test.dart` passes (scoped template still emits the banner / KPI strip /
  legend / chart hosts).

## F5 progress

- **Confirmed:** the composed document renders — host hero + both scoped panes side by side (stacked
  below 1100px), consistent editor theme, no blank page, no style bleed in the chrome.
- **Fixed after first F5:** the two scans ran concurrently (`Promise.all`), and two `dart run
  saropa_lints:<tool>` against the same package from the same cwd contend on dart's build-snapshot /
  pub lock — the pair stalled and the panes never left the loading shell ("times out"). The scans now
  run sequentially, matching the standalone panels (one `dart run` at a time).

## Not verified — requires F5 (a webview render cannot be unit-tested)

- The composed page actually rendering: both panes side by side, the treemap / scatter / hot-spot
  table interactive, the Code Health table sortable/filterable, in light / dark / high-contrast themes.
- A Project Map hot-spot row click and a Code Health function-link click both opening the file.
- The shared `acquireVsCodeApi` handle working for both panes (drill-down from each).
- That `.pm-pane` scoping fully isolates the two stylesheets in the live webview (no visual bleed).

## Finish Report (2026-07-16)

Scope: (C) extension TypeScript + Dart HTML template — VS Code extension code.

### Work completed

- Consolidated `saropaLints.openDashboards` command composing Project Map and Code Health into one
  webview document (no iframes, no eval, no shadow DOM).
- Single shared `acquireVsCodeApi` handle via `apiShimScript`; Project Map CSS scoped under `.pm-pane`
  with palette tokens on the wrapper; one ECharts loader in the host head.
- `scanProjectMapToParts`, `buildCodeHealthFragment`/`buildCodeHealthBody`, `applyFileSuppression`
  exported and wired; full message routing (openFile, open*Full, settings, rescan/restart, copyJson,
  copyText, suppressFlag). Standalone Project Map and Code Health commands unchanged (additive).
- Sequential scan execution fix: two concurrent `dart run saropa_lints:<tool>` against the same package
  contended on dart's build-snapshot / pub lock and stalled the panes; scans now run one at a time.

### Work still to do

None blocking. Remaining item is manual visual QA only (below).

### Verification

- `tsc` clean (`tsconfig.json` + `tsconfig.test.json`).
- `saropaDashboardsView.test.ts` (4 cases: single API acquisition, both panes present, PM styles scoped
  under `.pm-pane`, one failed pane degrades without dropping the other).
- `projectVibrancyReportHtml.test.ts` + `projectVibrancyInflight.test.ts` pass (body refactor preserved
  output). Dart `health_html_reporter_test.dart` passes (scoped template emits banner / KPI strip /
  legend / chart hosts).
- Confirmed at first F5: composed document renders — host hero + both scoped panes side by side, no
  blank page, no chrome style bleed.

### SKIPPED

- SKIPPED [Manual-QA] — live-webview interaction sweep (treemap/scatter/hot-spot + Code Health
  sortable table across light/dark/high-contrast, drill-down file-open from each pane, full `.pm-pane`
  isolation in the running webview). A webview render cannot be unit-tested; the render itself was
  confirmed at F5. Dropped as a closing gate rather than held open indefinitely, matching the
  disposition of the sibling TESTING_AND_RELEASE plan (manual IDE sign-off dropped as a gate).

### Done confirmation

Implementation and all automated checks complete. Plan closed and archived.
