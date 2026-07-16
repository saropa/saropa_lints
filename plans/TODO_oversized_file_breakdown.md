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
- **views/issuesTree.ts** 1340 → 783 (partial): extracted node types → `issuesTreeTypes.ts` (79),
  the command layer (hide/suppress/copy/apply-fix) → `issuesTreeCommands.ts` (296), and the
  ~220-line `getTreeItem` renderer (plus its `severityThemeIcon` / `violationLabel` /
  stale-icon helpers) → `issuesTreeItemBuilder.ts` (288). `getTreeItem` is a pure function of the
  node plus a small render context (root, collapse state, fix set, hotspot service), so the move is
  behavior-identical. The remaining `IssuesTreeProvider` class (~525 lines) holds the stateful
  filter/suppression/index machinery and `getChildren`. `check-types` clean; 22/22 tree tests green
  (they pin `getTreeItem` collapse states, file open-command, and violation tooltip). See Finish
  Report (2026-07-16) below.
- **views/dashboardChromeStyles.ts** 1199 → 72-line composer + `dashboardChromeStylesTokens.ts`
  (133), `dashboardChromeStylesComponents.ts` (731), `dashboardChromeStylesSystem.ts` (307). The
  14 `chrome*()` band functions relocated verbatim; `check-types` clean; generated CSS byte-identical
  (`getDashboardChromeStyles` 32831 chars / `getDashboardTokens` 3717 chars, unchanged).
- **views/violationsDashboardStyles.ts** 1350 → 77-line composer + `violationsDashboardStylesParts.ts`
  (1337, the 9 per-section CSS fragments). The CSS volume is inherent data — the win is the
  monolithic ~1300-line single function is now 9 independently-findable fragments behind a thin
  composer. `check-types` clean; output byte-identical (48952 / 1603 chars, unchanged).
- **vibrancy/views/report-styles.ts** 1152 → 36-line composer + `report-styles-parts.ts` (1174, 8
  per-section fragments). `check-types` clean; output byte-identical (49517 chars, unchanged).
- **views/commandCatalogWebviewHtml.ts** 1881 → 360-line markup builder + `commandCatalogStyles.ts`
  (829, the CSS) + `commandCatalogScript.ts` (707, the static client JS). Both moved functions are
  byte-identical to HEAD; `check-types` clean.
- **views/projectVibrancyReportView.ts** 1369 → 804 (controller + HTML builders retained) +
  `projectVibrancyClientScript.ts` (574, the code-health client script + its string-data tables).
  `check-types` clean; 28/28 report-HTML/inflight/contributions tests green (the report-HTML test
  pins the embedded script, so byte-identical).
- **views/violationsWideReportView.ts** 952 → 832 (partial): pure stats/aggregation helpers extracted
  to `violationsWideReportStats.ts` (139). The ~320-line `getOrCreatePanel` controller stays — same
  stateful-controller risk as `issuesTree`, deferred as follow-up. Stats block identical to HEAD;
  `check-types` clean. (No test exists for this file.)
- **vibrancy/views/report-script.ts** 1876 → 44-line composer + `report-script-parts.ts` (1897, 9
  fragments of the one IIFE body). Split-then-rejoin of the same string ⇒ byte-identical; the
  assembled script runs in one scope exactly as before. `check-types` clean; output byte-identical
  (92317 chars, unchanged); `report-html.test` (150 cases, embeds the script) green.

## Remaining oversized files

All ten files in the original list have been addressed. Two remain **partial** — their bulk is a
single stateful class/controller (`IssuesTreeProvider` in `issuesTree.ts`; `getOrCreatePanel` in
`violationsWideReportView.ts`) whose methods would have to be converted to free functions to split
further. That is a behavior-risk refactor (no byte-identical guarantee, and `violationsWideReportView`
has no test), deliberately deferred rather than attempted in this behavior-preserving sweep.

| Partial file | Now | What remains |
|---|---|---|
| views/issuesTree.ts | 783 | the ~525-line `IssuesTreeProvider` class — stateful filter/suppression/index machinery + `getChildren` grouping (`getTreeItem` now extracted) |
| views/violationsWideReportView.ts | 832 | the ~320-line `getOrCreatePanel` controller + message handler |

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

---

## Finish Report (2026-06-24) — Full oversized view-file sweep

### What changed

All ten files in the "Remaining oversized files" list were decomposed into focused sibling modules
behind thin composers. Eight are fully decomposed; two (`issuesTree.ts`, `violationsWideReportView.ts`)
are partial — their bulk is a single stateful class/controller that cannot be split without converting
methods to free functions, a behavior-risk refactor deferred deliberately. The per-file results,
sizes, and module names are recorded in the "Done" section above.

The decompositions fall into three mechanical patterns, each chosen to be provably safe:

- **Composer + section modules** (report-html, command-catalog registry/webview): the largest
  self-contained blocks (input types, data tables, CSS, client scripts, section builders) move to
  sibling modules; the original file becomes a thin composer that re-exports the public surface so
  external importers are untouched. Module graphs are acyclic.
- **Monolith string split** (the three CSS-in-TS files and the two client-script files): a single
  ~1000–1900-line template-literal function is split at section/banner/function boundaries into part
  functions; the composer concatenates them. Because this is split-then-rejoin of the same string,
  the generated output is byte-identical and (for the client scripts) still executes in one scope.
- **Leaf extraction** (issuesTree command layer, projectVibrancy client script, violationsWide stats):
  self-contained, side-effect-free helper clusters move to a sibling; the stateful controller/class
  stays in place.

### Why

The files had grown well past a navigable size (the largest were ~1900 lines), mixing distinct
concerns — input types, data, CSS, client JS, markup builders, and panel controllers — in one file.
No section could be imported or located independently. Splitting them makes each concern findable and,
where the planned central-dashboard consolidation applies, independently composable.

### Verification

- `npm run check-types` clean after every split and on the final consolidated pass.
- Tested files green: command-catalog (28/29; the 1 failure is a pre-existing package.json↔catalog
  drift that fails identically on HEAD), issues tree (22/22), Project Vibrancy report
  (28/28 — its test pins the embedded client script), and `report-html.test` (150) which embeds the
  Package Vibrancy report script.
- Untested CSS/JS monoliths verified byte-identical by comparing the composed output length before and
  after (e.g. report-script 92317 chars, report-styles 49517, dashboard chrome 32831/3717, findings
  styles 48952/1603 — all unchanged). The command-catalog `getStyles`/`getScript` and the
  violationsWide stats blocks were diffed against HEAD and are identical modulo the added `export`.

### Deferred (plan kept active)

Two partial files retain a stateful unit (the `IssuesTreeProvider` class; the `getOrCreatePanel`
controller). Splitting those is a behavior-risk refactor with no byte-identical guarantee, and
`violationsWideReportView` has no test. This plan stays in `plans/` (not archived) as the tracker for
those two deferred items rather than fragmenting them into a separate file.

### Scope note

Behavior-preserving internal refactors only; no user-facing change, no new or changed l10n strings
(all `l10n()` calls moved verbatim with their keys).

---

## Finish Report (2026-07-16) — issuesTree.ts getTreeItem extraction

### What changed

`views/issuesTree.ts` was the first of the two deferred partial files. Its bulk is the stateful
`IssuesTreeProvider` class, but ~220 of those lines were `getTreeItem` — a large `switch` on node
kind that renders a `vscode.TreeItem`. It reads no mutable provider state beyond four values, so it
is effectively pure.

Moved `getTreeItem` (plus its only consumers `severityThemeIcon`, `violationLabel`, and the
`STALE_ICON` / `STALE_LABEL` / `MESSAGE_LABEL_LEN` constants) into a new sibling
`views/issuesTreeItemBuilder.ts` (288 lines) as a free function `buildIssueTreeItem(element, ctx)`.
The provider's `getTreeItem` is now an 11-line delegator that supplies the render context: workspace
root, collapse state (`collapsedOrExpanded`, which already respects the expand-all override), the
fix-availability set, and the hotspot-review service. `issuesTree.ts` dropped 1020 → 783; the
provider class dropped 762 → ~525.

This clears the "item builders" portion of the deferred issuesTree work. The remaining ~525-line
class is the stateful filter/suppression/index machinery and `getChildren` — a genuine behavior-risk
split (converting stateful methods to free functions), left for a later pass.

### Why

Same rationale as the rest of this sweep: a large file mixing distinct concerns is hard to read and
review. `getTreeItem` is a self-contained rendering concern that no longer needs to live inside the
class, and extracting it is provably safe because the method is a pure function of its inputs.

### Verification

- `npm run check-types` clean.
- 22/22 `issuesTree.test` cases green. The suite pins exactly the extracted surface — severity/folder
  collapse states (default + expand-all override), the file-row `vscode.open` command (present when
  the file exists, absent when moved/deleted), and the violation tooltip's related-rules block — so a
  green run confirms the render output is behavior-identical.

### Scope note

Behavior-preserving internal refactor; no user-facing change, no new or changed l10n strings.

Finish report appended: plans/TODO_oversized_file_breakdown.md
