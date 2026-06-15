# PLAN: Consolidated "Saropa Dashboards" — Project Map + Code Health on one page

**Status:** Active — both panes built as a single composed document; pending an Extension Development
Host (F5) render check.

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

## Not verified — requires F5 (a webview render cannot be unit-tested)

- The composed page actually rendering: both panes side by side, the treemap / scatter / hot-spot
  table interactive, the Code Health table sortable/filterable, in light / dark / high-contrast themes.
- A Project Map hot-spot row click and a Code Health function-link click both opening the file.
- The shared `acquireVsCodeApi` handle working for both panes (drill-down from each).
- That `.pm-pane` scoping fully isolates the two stylesheets in the live webview (no visual bleed).
