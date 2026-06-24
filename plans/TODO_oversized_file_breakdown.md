# TODO — Oversized view-file breakdown

**Created:** 2026-06-12
**Context:** The extension's webview screens are modular by concern (per-screen html/script/styles/
controller split), but a handful of individual files are large. This tracks breaking each one into
focused modules. The **Findings dashboard is done** (it is the central-dashboard core — see
[CENTRAL_DASHBOARD_CONSOLIDATION.md](CENTRAL_DASHBOARD_CONSOLIDATION.md)); the rest are kept "linked
surface" dashboards the consolidation plan keeps as separate screens.

## Proven approach (used for the Findings dashboard)

1. Extract the largest self-contained block first (a client-script blob, or the input types +
   shared helpers) into a sibling module.
2. Split the remaining section builders into per-area modules (e.g. top-chrome / tables / panels),
   each importing a small shared module.
3. Mechanical line-range move (no transcription risk), then typecheck-driven import fixup.
4. Verify behavior with the screen's existing test (output must be byte-identical) + `npm run
   check-types`. Re-export any public types from the composer so external importers are untouched.

## Done

- **violationsDashboardHtml.ts** 2155 → 136-line composer + `violations-dashboard-shared.ts` (150),
  `-script.ts` (864), `-top.ts` (506), `-tables.ts` (278), `-panels.ts` (323). Test (30) green.

## Remaining oversized files (by size)

Each is a kept linked-surface dashboard; decompose with the approach above. Tested ones are lower
risk (the test pins output); untested ones need a render spot-check after. Paths are relative to
`extension/src/`.

**Line counts refreshed 2026-06-24** — none of these had been decomposed since the Findings
dashboard, and most grew. The table below is re-sorted by current size; the original (2026-06-12)
count follows each in parentheses where it changed.

| File | Lines | Kind | Test | Suggested split |
|---|---|---|---|---|
| views/commandCatalogWebviewHtml.ts | 1881 (was 1856) | markup | none | hero / search-toolbar / frequent+recent bands / category sections / client script |
| vibrancy/views/report-script.ts | 1876 (was 1463) | client-js | none | filters / sorting / popovers / network-render / footprint-toggle (one IIFE module each) |
| vibrancy/views/report-html.ts | 1709 (was 1766) | markup | yes | hero+gauge+breakdown / summary cards / chart / filters / table / detail-row / network |
| views/projectVibrancyReportView.ts | 1369 (was 1310) | controller | none | html builder / client script / message handler / controller |
| views/commandCatalogRegistry.ts | 1356 (was 1348) | data | yes | split the catalog entries by category group into data files |
| views/violationsDashboardStyles.ts | 1350 (was 1297) | css | none | split by component (hero / kpi / toolbar / table / panels / chart) |
| views/issuesTree.ts | 1340 (was 1338) | tree-logic | yes | tree-data provider / grouping / tree-item builders / pagination |
| views/dashboardChromeStyles.ts | 1199 (was 1115) | css | none | split by component band |
| vibrancy/views/report-styles.ts | 1152 (was 930) | css | none | split by report section |
| views/violationsWideReportView.ts | 952 (was 905) | controller | none | html builder / message handler / controller |

> **Path correction (2026-06-24):** the controller `projectVibrancyReportView.ts` lives at
> `views/projectVibrancyReportView.ts`, NOT under `vibrancy/views/`. Only the three `report-*.ts`
> files are under `vibrancy/views/`.

## Notes

- The client-script blobs (`-script.ts` 864, `report-script.ts` 1463) are single template-literal
  functions; splitting them means carving the embedded JS into separate IIFE-returning builders —
  lower value than the markup splits, do last.
- CSS-in-TS files split cleanly by component but are low risk / low urgency.
- `issuesTree.ts` is a sidebar tree (not a dashboard); its split is independent of consolidation.

---

## Finish Report (2026-06-12) — Findings dashboard decomposition

### What changed

The editor Findings (Violations) dashboard's HTML builder had grown to a single 2155-line file mixing
the input data types, an ~800-line embedded webview client script, and every section builder (hero,
KPI cards, toolbar, tables, charts, and the TODO/HACK, Drift, and suppressions panels). The file was
modular only by internal function boundaries, not by module — a reader had to scroll the whole file to
find any one section, and no section could be imported independently.

`violationsDashboardHtml.ts` is now a 136-line composer. Its parts moved into focused sibling modules:

- `violations-dashboard-shared.ts` — input/suppression types, `escapeHtml`, `SEVERITY_ORDER`,
  `formatRelative`. Every section module depends on this one small module rather than on each other.
- `violations-dashboard-script.ts` — the embedded client script, its l10n string map, and the default
  severity/impact arrays it seeds panel state with.
- `violations-dashboard-top.ts` — hero gauge, status line, KPI filter cards, toolbar, more-actions
  menu, active-filter chips.
- `violations-dashboard-tables.ts` — the Top Rules triage table and the grouped, sortable findings
  table (rows, meta line, overflow note, empty state).
- `violations-dashboard-panels.ts` — severity-mix chart, TODO/HACK block, Drift Advisor block,
  suppressions / view-hides block.

The composer re-exports `AnalyzerSuppressionsSlice` and `ViewSuppressionsSlice` so the two external
importers (`violationsWideReportView.ts` and the dashboard test) reference them from the composer,
unchanged.

### Why

The section builders are the reusable building blocks the planned single central dashboard composes
(see CENTRAL_DASHBOARD_CONSOLIDATION.md): the consolidation folds the findings experience into one
dashboard, and that dashboard imports `buildTopRulesTable`, `buildKpiCards`, the chart and panel
builders, etc. directly. Splitting them out is a prerequisite that is valuable on its own regardless
of whether the full consolidation ships.

### Verification

- Extraction was mechanical (line-range moves, no transcription), with imports computed per module
  and fixed against the type-checker.
- `npm run check-types` clean on the first pass after the section split.
- `violationsDashboardHtml.test` (30 cases pinning the rendered markup) green — the rendered output is
  byte-identical, so the refactor is behavior-preserving.

### Scope note

Behavior-preserving internal refactor; no user-facing change, no new or changed strings. The Findings
dashboard is closed; the table above tracks the remaining oversized view files (kept linked-surface
dashboards) for follow-up.

Finish report appended: plans/TODO_oversized_file_breakdown.md
