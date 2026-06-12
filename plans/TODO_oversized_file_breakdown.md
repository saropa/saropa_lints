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
risk (the test pins output); untested ones need a render spot-check after.

| File | Lines | Kind | Test | Suggested split |
|---|---|---|---|---|
| commandCatalogWebviewHtml.ts | 1856 | markup | none | hero / search-toolbar / frequent+recent bands / category sections / client script |
| vibrancy/views/report-html.ts | 1766 | markup | yes | hero+gauge+breakdown / summary cards / chart / filters / table / detail-row / network |
| vibrancy/views/report-script.ts | 1463 | client-js | none | filters / sorting / popovers / network-render / footprint-toggle (one IIFE module each) |
| commandCatalogRegistry.ts | 1348 | data | yes | split the catalog entries by category group into data files |
| issuesTree.ts | 1338 | tree-logic | yes | tree-data provider / grouping / tree-item builders / pagination |
| projectVibrancyReportView.ts | 1310 | controller | none | html builder / client script / message handler / controller |
| violationsDashboardStyles.ts | 1297 | css | none | split by component (hero / kpi / toolbar / table / panels / chart) |
| dashboardChromeStyles.ts | 1115 | css | none | split by component band |
| vibrancy/views/report-styles.ts | 930 | css | none | split by report section |
| violationsWideReportView.ts | 905 | controller | none | html builder / message handler / controller |

## Notes

- The client-script blobs (`-script.ts` 864, `report-script.ts` 1463) are single template-literal
  functions; splitting them means carving the embedded JS into separate IIFE-returning builders —
  lower value than the markup splits, do last.
- CSS-in-TS files split cleanly by component but are low risk / low urgency.
- `issuesTree.ts` is a sidebar tree (not a dashboard); its split is independent of consolidation.
