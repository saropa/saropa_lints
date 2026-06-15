# PLAN: Consolidated "Saropa Dashboards" — Project Map + Code Health on one page

**Status:** Active — Phase 1 landed, Phase 2 pending an Extension Development Host (F5) check of the
iframe mechanism.

## Context

The Project Map and Code Health dashboards are two separate webview panels, each opened by its own
command, so they cannot be viewed together. A consolidated page shows both side by side, with **every
bit of each screen's interactive content preserved** — the ECharts treemap / churn-complexity scatter
/ hot-spot table for Project Map, and the score gauge / sortable-expandable function table / live scan
progress for Code Health. Nothing is summarized or stripped; the two reports are composed, not rebuilt.

Tabs were rejected (they show one screen at a time). The composition is a responsive grid where each
engine renders inside its own `<iframe srcdoc>`. Iframes are required because both engines' client
scripts call `acquireVsCodeApi()`, which a webview permits only once per document, and both use
unscoped DOM ids (`#filter`, `#hot`, `#pvTable`, …) that would collide if merged into one document.
An iframe isolates each engine's document, so its existing HTML embeds byte-for-byte.

## Phase 1 — host shell + Project Map pane (LANDED)

A new `saropaLints.openDashboards` command opens a host webview (`saropaDashboardsView.ts`) with the
shared chrome and a responsive two-pane grid. The Project Map pane embeds the full interactive report
in an iframe:

- `projectMapView.ts` was refactored to export `transformProjectMapHtml` (vendored-ECharts URI swap +
  CSP + host-theme token rebind) and `scanProjectMapToHtml` (run the `project_health` scan, return the
  embeddable HTML), plus `openFileFromReport` for drill-down. The standalone Project Map command reuses
  the same helpers, so both paths render identically.
- The host injects an `acquireVsCodeApi` shim into the report (`injectIframeBridge`) so the report's
  row-click `postMessage` bubbles up to the host tagged with `__src: 'projectMap'`; the host relays it
  to the extension, which opens the file via `openFileFromReport`.
- Host CSP adds `frame-src 'self'` for the srcdoc iframe; `localResourceRoots` includes `media/` so the
  vendored ECharts resolves inside the frame.
- Registered in `extension.ts`, `package.json`, `commandCatalogRegistry.ts` (catalog-sync test passes),
  and the editor-dashboards sidebar leaf. New `dashboards.*` strings in `en.json`.

Additive: the standalone Project Map and Code Health commands are unchanged.

**Verified:** `tsc` clean (main + test); catalog-sync test accepts the new command; the
`injectIframeBridge` contract is pinned by `saropaDashboardsView.test.ts` (4 cases); existing view
tests pass. **Not verified:** the iframe actually rendering — a webview's render cannot be unit-tested
and requires an F5 launch.

## Phase 2 — Code Health pane (PENDING)

Gated on the Phase 1 F5 check confirming the iframe/CSP/bridge mechanism works (the `frame-src 'self'`
+ `srcdoc` path has no prior use in this repo). Then add the second pane:

- Set the Code Health iframe `srcdoc` to the scanning-progress HTML first; run `runProjectVibrancyScan`;
  relay each NDJSON scan `event` from the host into the iframe (`iframe.contentWindow.postMessage`) so
  the live phase stepper / counters animate as today; on completion swap the iframe `srcdoc` to
  `buildProjectVibrancyHtml(payload)`.
- Namespace Code Health's messages (`__src: 'codeHealth'`) and dispatch them in the host:
  `openFile` / `suppressFlag` / `pause` / `resume` / `restart` / `rescan` / `copyJson` /
  `openProjectVibrancySettings`. Reuse the existing handler logic from `projectVibrancyReportView.ts`
  (extract a context-taking variant so both the standalone panel and the host can call it).
- Wire `refreshCodeHealthDashboardIfOpen` to re-run only the Code Health pane on diagnostics change.

## Risks / open unknowns (resolve at the Phase 1 F5 check)

- `frame-src 'self'` may not cover `srcdoc` in the VS Code webview CSP flavor — if the pane renders
  blank, fall back to a `blob:`/`data:` framed document or a nonce'd `child-src`.
- The `acquireVsCodeApi` shim must be defined before the engine's first script runs (injected before
  `</head>`; pinned by the bridge test).
- Content-driven iframe height may need a ResizeObserver→postMessage handshake; otherwise the fixed
  72vh panes scroll internally (the Phase 1 default).

## Verification (end to end)

- `cd extension && npx tsc -p tsconfig.json` and `tsconfig.test.json` — clean.
- `commandCatalogRegistry.test.ts` + `saropaDashboardsView.test.ts` pass.
- F5: open "Saropa Dashboards"; Project Map pane renders the full interactive report; a hot-spot row
  click opens the file; (Phase 2) the Code Health pane streams its scan then shows the report; both
  panes sit side by side; both standalone commands still work; verify in light / dark / high-contrast.
