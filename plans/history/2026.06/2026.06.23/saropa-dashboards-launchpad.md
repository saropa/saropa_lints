# Saropa Dashboards launchpad rebuild

The consolidated "Saropa Dashboards" editor view hung on a blank "Scanning…" screen and then
rendered corrupted output (Project Map's theme CSS printed as visible page text, treemap blank). It
was rebuilt into a fast, lazily-loaded launchpad that consolidates all six Saropa dashboards plus an
Actions / Settings / Help control band on one page.

## Finish Report (2026-06-23)

### Defects fixed

1. **Style corruption + blank treemap.** Project Map's `<!--PM_STYLE_*-->` markers wrap the
   `<style>…</style>` tags themselves, so `scanProjectMapToParts` returns `styleHtml` as a complete
   `<style>` element. The previous code wrapped that in `<style>` a second time and appended the
   `.pm-pane` theme tokens + host fixups; the inner `</style>` closed the block early, spilling the
   token CSS onto the page as visible text and leaving the treemap unsized (blank). The arriving
   style is now injected verbatim client-side via `head.insertAdjacentHTML`, and the static
   `.pm-pane` theme tokens + height fixups live once in the shell head.

2. **All-or-nothing hang.** Both `dart run` scans ran behind a single modal gate that rendered
   nothing until both finished, so the page sat blank for the duration of two cold dart builds.

### Implementation

- **Shell-first, panes stream in.** `buildShell` sets the webview HTML once: hero, the control band,
  four live summary cards, and two "Scanning…" placeholders. ECharts loads once in the head (its URI
  is computable without a scan). The two heavy scans run sequentially in the background (kept
  sequential — concurrent `dart run` against the same package makes the second block on the first's
  build-snapshot / pub lock); each posts a `paneReady` message and the client patches that pane in
  place. Failures post `paneError`, which renders an inline retry scoped to the pane; each heavy pane
  also has a Rescan control that re-runs only its own scan.

- **Light dashboards as summary cards.** Lints Config, Findings, Package, and Command Catalog read
  local files / in-memory caches, so `dashboardSummaries.ts` builds a compact metric card per
  dashboard (reusing `readViolations`, `readPubspec`, `readRulePacksEnabled`, `getLatestResults`,
  `catalogEntries`, `readCommandHistory`) with an "Open full screen" deep-link. Embedding their full
  interactive documents was rejected: it would force six `acquireVsCodeApi()` handles and colliding
  ids/styles into one document.

- **Control band.** An Actions / Settings / Help band under the hero (`buildControlsBand`) surfaces
  run analysis, initialize config, the lint-integration / tier / run-after / UI-language settings
  (each label shows its current value), and the help links. Webview clicks post a `data-command`
  that the host runs only if it is in `OPEN_COMMAND_ALLOWLIST`. After a stateful Settings toggle the
  host recomputes the band and posts `controlsUpdated`; the client swaps the band via `outerHTML`
  (not `innerHTML`) so a second `#dashControls` is not nested inside the first — a fresh defect
  caught and fixed during this work.

- **Single API handle.** A client shim acquires `acquireVsCodeApi()` once and re-exposes it so the
  embedded Project Map and Code Health scripts share one messaging channel.

- **Sidebar.** The "Saropa Dashboards" row now leads the Editor dashboards section as its entry
  point; its description updated from "Project Map + Code Health, side by side" to "All dashboards on
  one page".

### Files

- `extension/src/views/saropaDashboardsView.ts` — rewritten (shell-once, lazy panes, control band,
  corruption fix).
- `extension/src/views/dashboardSummaries.ts` — new (light-dashboard summary cards).
- `extension/src/views/sectionedSidebar.ts` — "Saropa Dashboards" moved to top of Editor dashboards.
- `extension/src/i18n/locales/en.json` — new `dashboards.*` keys (pane titles, summaries, controls,
  retry/rescan).
- `extension/src/test/views/saropaDashboardsView.test.ts` — rewritten to pin the shell contract.

### Verification

- `tsc -p tsconfig.test.json` compiles clean.
- `out-test/test/views/saropaDashboardsView.test.js` passes (11 cases): one API acquisition, one
  ECharts loader, all six panes, four summaries embedded, heavy panes scanning + rescan + deep-link,
  light deep-links, control band commands present, lint-integration command flips with state,
  controls band patchable, theme tokens scoped under `.pm-pane`, style injected verbatim.

### Not regenerated

- Translated locale catalogs are stale: the new `en.json` keys exist only in English. Regeneration
  runs the machine-translation pipeline (`extension/scripts/generate_translations.py`) on its own
  cadence; the publish coverage gate (`generate_locales.py --fail-on-missing`) blocks a release until
  it runs.
