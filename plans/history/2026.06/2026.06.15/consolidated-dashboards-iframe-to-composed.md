# Consolidated "Saropa Dashboards" — iframe host replaced by a single composed document

The consolidated dashboard hosted the Project Map and Code Health reports in one webview by placing
each engine's full HTML in its own `<iframe srcdoc>`. That approach was fragile plumbing: a
parent/child `postMessage` bridge to relay drill-down clicks, content-driven iframe height guessing,
a `frame-src` CSP with no precedent in the repo, and two independent ECharts runtimes. The iframe was
reached for only to sidestep the actual integration — each iframe is an isolated document, so both
reports embedded untouched — rather than to serve the design.

The host now assembles both engines' real markup, styles, and scripts into ONE webview document. No
iframe, no `eval`, no shadow DOM.

## Finish Report (2026-06-15)

### Problem

Two hazards block dropping both full reports into one document, and the iframe existed only to avoid
solving them:

1. `acquireVsCodeApi()` may be acquired only once per webview document; both engines' scripts call it.
2. The two stylesheets collide on bare selectors (`body`, `table`, `.chip`, `.panel`) and on `:root`
   palette tokens.

### Change

- **`lib/src/cli/project_health/health_html_template.dart`** — every visual rule is scoped under a
  `.pm-pane` wrapper; the palette tokens and page background moved from `:root` / `body` onto
  `.pm-pane`; keyframes renamed (`pmRise`, `pmShimmer`) to avoid name clashes; `<!--PM_STYLE-->`,
  `<!--PM_BODY-->`, `<!--PM_SCRIPT-->` markers bound the three extractable blocks. The standalone
  browser/CI export renders identically because `.pm-pane` fills the viewport.
- **`extension/src/views/projectMapView.ts`** — `scanProjectMapToParts` runs the `project_health`
  scan and returns `{ styleHtml, bodyHtml, scriptHtml, echartsUri }` extracted by the markers (fails
  closed if the markers are absent — a template/version mismatch). The webview theme rebind now
  targets `.pm-pane`, not `:root`: a CSS variable resolves from the nearest ancestor that defines it,
  and `.pm-pane` is nearer than `:root` for every report element, so a `:root` rebind would be
  shadowed by the template's own `.pm-pane` tokens. The rebind CSS is shared via `pmPaneThemeTokens`
  so the consolidated host applies the identical editor-theme binding and the pane matches the
  theme-driven Code Health pane. The iframe-era `scanProjectMapToHtml` was removed.
- **`extension/src/views/projectVibrancyReportView.ts`** — the in-`<body>` markup assembly was
  factored out of `buildHtml` into `buildCodeHealthBody` (byte-for-byte identical output for the
  standalone panel); `buildCodeHealthFragment` returns `{ body, script }` for the host;
  `applyFileSuppression` was exported so the host can service the per-flag suppress button.
- **`extension/src/views/saropaDashboardsView.ts`** — rewritten. `openDashboards` runs both scans
  concurrently behind one in-flight guard, shows a loading shell, then renders the pure
  `buildDashboardsDocument(cspSource, pmParts, chFrag)`. The document loads ECharts once; an
  `apiShimScript` acquires the single VS Code API handle and re-exposes `window.acquireVsCodeApi` so
  both engines' scripts share it; the two engines' scripts follow the shim. `handleHostMessage`
  routes `openFile` (Project Map sends no line → preview at line 1; Code Health sends a line),
  `openProjectMapFull` / `openCodeHealthFull`, `openProjectVibrancySettings`, `rescan`/`restart`,
  `copyJson` (captured Code Health stdout), `copyText`, and `suppressFlag`. A failed pane renders an
  inline placeholder rather than blanking the page. The iframe bridge (`injectIframeBridge`) and its
  `frame-src` CSP were removed.
- **`extension/src/test/views/saropaDashboardsView.test.ts`** — replaced the `injectIframeBridge`
  assertions with four cases pinning the composition contract: exactly one host-side
  `acquireVsCodeApi()` plus the re-exposed shared handle, both panes' markup and scripts present with
  exactly one ECharts loader, Project Map styles scoped under `.pm-pane`, and a failed scan degrading
  to a placeholder without dropping the surviving pane.
- **`extension/src/i18n/locales/en.json`** — added `dashboards.scanFailed`.

### Why this shape

The decisive constraint is that the two engines' DOM ids do not overlap (`treemap`/`filter`/`hot` vs
`pvTable`/`pvSearch`/…), so a single document is safe once CSS is isolated and the API is shared.
Scoping Project Map's stylesheet under `.pm-pane` isolates the CSS without rewriting either engine's
scripts; sharing one acquired API handle satisfies the once-per-document limit without per-pane
message bridges. This removes the iframe's fragility while preserving 100% of each report's
interactive content.

### Verification

- `tsc` clean — `tsconfig.json` and `tsconfig.test.json`.
- `saropaDashboardsView.test.ts` (4) pass; `projectVibrancyReportHtml.test.ts` +
  `projectVibrancyInflight.test.ts` (24) pass — the Code Health body refactor preserved output.
- `health_html_reporter_test.dart` (2) passes — the scoped template still emits the banner, KPI strip,
  legend, and chart hosts.
- `dart analyze lib/src/cli/project_health/health_html_template.dart` — no issues.

### Not verified

A webview's render cannot be unit-tested. Pending an Extension Development Host (F5) launch: both panes
rendering side by side with their charts/tables interactive, drill-down from each pane opening the
file, and `.pm-pane` scoping fully isolating the two stylesheets with no visual bleed across panes.
The active plan `plans/PLAN_consolidated_dashboards.md` tracks this open verification gate.

## Finish Report (2026-06-15) — sequential scan ordering

### Problem

On open, the consolidated view stayed on its loading shell indefinitely and never populated either
pane (observed as a hang / "times out"). The composed document itself rendered correctly — host hero,
both scoped panes, consistent theme — so the failure was in the scan orchestration, not the markup.

### Cause

Both panes' data comes from `dart run saropa_lints:<tool>` (project_health and project_vibrancy),
spawned from the same working directory (`resolveCliCwd`). The host ran them with `Promise.all`, so two
`dart run` processes started together against the same package. The second blocks on dart's
build-snapshot / pub lock held by the first, and the pair can stall — neither scan resolves, so the
`buildDashboardsDocument` call that replaces the loading shell never runs. The standalone Project Map
and Code Health panels each run a single scan, which is why they complete and only the consolidated
view hangs.

### Change

`runAndRender` in `saropaDashboardsView.ts` now awaits the two scans sequentially (Project Map, then
Code Health) inside the progress callback instead of `Promise.all`. The progress notification reports
the active scan; a cancellation between scans skips the second and assembles with whatever completed.
This matches the one-scan-at-a-time behavior of the standalone panels and removes the lock contention.

### Verification

`tsc` clean (main + test); `saropaDashboardsView.test.ts` (4) still passes (the pure composition is
unchanged). The orchestration spawns real `dart` processes and is not unit-testable; the populated
render remains an F5 check (tracked in the active plan).
