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
- **vibrancy/views/report-html.ts** 1709 → 182-line composer + `report-html-shared.ts` (115),
  `report-html-top.ts` (535), `report-html-table.ts` (772), `report-html-data.ts` (201). View
  tests (168 across report-html / report-webview / package-detail-html) green; `check-types` clean.
  See Finish Report (2026-06-24) below.
- **views/commandCatalogRegistry.ts** 1356 → 98-line composer + `commandCatalogTypes.ts` (47),
  `commandCatalogEntriesProject.ts` (627), `commandCatalogEntriesVibrancy.ts` (530),
  `commandCatalogEntriesMisc.ts` (115). Composed catalog identical (162 entries, same order);
  `check-types` clean; 28/29 catalog tests green (the 1 failure — 3 package.json commands missing
  from the catalog — pre-dates the split and fails identically on HEAD).
- **views/issuesTree.ts** 1340 → 1020 (partial): extracted node types → `issuesTreeTypes.ts` (79)
  and the command layer (hide/suppress/copy/apply-fix) → `issuesTreeCommands.ts` (296). The
  762-line `IssuesTreeProvider` class stays in place — splitting its methods (grouping / item
  builders / pagination) means converting stateful methods to free functions, a riskier refactor
  deferred as a follow-up. `check-types` clean; 22/22 tree tests green.

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
| views/projectVibrancyReportView.ts | 1369 (was 1310) | controller | none | html builder / client script / message handler / controller |
| views/violationsDashboardStyles.ts | 1350 (was 1297) | css | none | split by component (hero / kpi / toolbar / table / panels / chart) |
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

---

## Finish Report (2026-06-24) — Package-vibrancy report decomposition

### What changed

The package-vibrancy report's HTML builder (`vibrancy/views/report-html.ts`) had grown to 1709 lines
holding the document shell, the input `ReportOptions` type, the hero/gauge/breakdown/summary chrome,
the search-and-filter toolbar, the full package table with every per-cell builder, the copy-as-JSON
payload, and the dependency-network payload — all in one file. It was modular by internal function
boundary only; no section could be imported independently and a reader had to scroll the whole file
to find any one part.

`report-html.ts` is now a 182-line composer that owns only the page skeleton (CSP, styles, scripts)
and the public export surface. Its parts moved into four focused sibling modules:

- `report-html-shared.ts` (115) — the cross-cutting leaf helpers used by BOTH the table and the data
  modules: `ReportOptions`, `resolveRepoUrl`, the age/activity math (`computeActivitySignal`,
  `daysSinceIsoDate`, `formatAgeFromDays`, `buildDormancyStatus`). Kept separate so neither
  consumer has to import the other.
- `report-html-top.ts` (535) — top chrome: radial gauge, "Scanned X ago" pill, scan-in-progress
  placeholder, "why this grade?" breakdown, summary KPI cards, and the search/filter toolbar.
- `report-html-table.ts` (772) — the collapsible table section, column-hiding, the row builder, and
  every per-cell builder, plus `buildDetailScoreSection` (the detail pane's health-score block, which
  shares the cell-level formatters).
- `report-html-data.ts` (201) — the per-package copy-as-JSON map, the GitHub-stars sub-block, and the
  dependency-network payload.

The composer re-exports `ReportOptions`, `buildSparklineSvg`, `computePublishedAgeMonths`, and
`buildDetailScoreSection` so the external importers (`report-webview.ts`, `package-detail-html.ts`,
the UX page generator, and the three view tests) reference them from `report-html.ts` unchanged.

### Why

Same rationale as the Findings split: the section builders are reusable blocks, and a 1709-line
single file is hard to read, review, and modify safely. The shared/top/table/data split follows the
proven approach at the top of this plan. The module boundaries were chosen to be acyclic — shared
depends only on external modules; top/table/data each depend on shared but not on each other; the
composer depends on all four.

### Verification

- Extraction was mechanical (a one-shot line-range slicer; function bodies moved byte-for-byte, no
  transcription). Only import headers and `export` keywords were synthesized.
- `npm run check-types` clean on the first pass after the split.
- 168 view tests green across `report-html.test`, `report-webview.test`, and
  `package-detail-html.test` — `report-html.test` pins the rendered markup, so byte-identical output
  confirms the refactor is behavior-preserving. (The report tests rely on an earlier suite file
  registering the `vscode` module mock; scope a standalone run with
  `out-test/test/vibrancy/register-vscode-mock.js` listed first.)

### Scope note

Behavior-preserving internal refactor; no user-facing change, no new or changed strings.

Finish report appended: plans/TODO_oversized_file_breakdown.md
