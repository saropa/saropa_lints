# Extension UI Redesign — sidebar + dashboards to 10/10

**Created:** 2026-09-03 · **Status:** Planned, not started
**Trigger:** Screenshot of the sidebar in the kykto project (v15.2.12): 6 stacked sections, 35 flat
rows, mixed verbs/nouns/settings/toggles, a raw "DIAGNOSTIC ENGINES" debug webview at the bottom,
and the single most important fact ("Lint integration: Off") shown as a warning row with no
one-click fix. Navigation requires reading every row.
**Baseline inventory:** the 7 views, 191 commands, 108 settings, 19 webviews, 5 style systems, and
the CLI-only features are catalogued in the appendix. Do not re-inventory.
**Relationship to `PLAN_central_dashboard_consolidation.md`:** that plan defines what folds into
the findings hub (lists A–D). This plan defines the *navigation shell* around it. They do not
conflict; Phase 3 here consumes its list C ("summarize + deep-link").

---

## 1. Design principles (the bar for 10/10)

1. **Sidebar = state + one-click actions. Dashboards = data + configuration.**
   The sidebar answers "is it on, is it healthy, what do I do next" in under two seconds. Anything
   that needs a table, a chart, a toggle grid, or an explanation lives in a webview.
2. **Every row has exactly one job.** A row is either a status (icon + value, click opens detail)
   or an action (verb, click does it). No row is both. No row is a setting label with a gray value
   you cannot change in place.
3. **Nothing important is more than two clicks away.** Sidebar row → dashboard → thing. Three
   clicks is a defect.
4. **Nothing is hidden in config files, settings.json, or CLI.** Every `analysis_options_custom.yaml`
   key, every `saropaLints.*` setting a user would plausibly change, and every `bin/*.dart` report
   gets a visible surface. Settings that remain in `contributes.configuration` also get a UI
   control; the JSON is a mirror, not the primary path.
5. **One design system.** `dashboardChromeStyles` is the only style system. The vibrancy
   `report-styles*`, `violationsDashboardStyles`, `consolidatedStyles`, `audit-report-styles`, and
   Project Map inline CSS are migrated onto it or deleted.
6. **Live or gone.** A dashboard that renders once and goes stale is a screenshot, not a dashboard.
   Every dashboard subscribes to the model it displays and updates without reopen.
7. **Menus are small.** Right-click menus ≤ 6 items. View-title `...` menus ≤ 5 items. No cascading
   submenus. Grouped commands go into a dashboard, not a menu.
8. **Empty, loading, error, and off states are designed**, not incidental. Every section and
   dashboard has all four.
9. **Debug stays out of the way.** Engine controls are one row ("Engines: 2 running") that opens
   the health panel. The raw log never sits in the primary sidebar.

---

## 2. Target information architecture

### 2.1 Sidebar — 3 sections, ≤ 14 rows total

```
SAROPA LINTS                                     [▶ Run] [⟳] [...]
  ● Health 82 · 143 issues · ↓12 since yesterday      → Findings Dashboard
  ● Engines  plugin live · daemon idle                 → Health Panel
  ○ Lint integration OFF — click to enable           → enable (one click, then hides)

DASHBOARDS
  ⌂ Home                 findings, health, packages   → Saropa Dashboards (hub)
  ⚙ Rules & Tiers        tier, packs, overrides, SDK  → Lints Config
  📦 Packages            vibrancy, upgrades, opps     → Package Dashboard
  ♥ Code Health          per-function grades          → Code Health Dashboard
  🗺 Project Map         size, dead weight, hotspots  → Project Map
  🔍 Full Audit          every rule, one run          → Audit report

QUICK ACTIONS
  ▶ Run analysis
  ✂ Fix stale ignores           (N found)
  ⌘ All commands…               → Command Catalog
```

**Removed from sidebar (moved, not deleted):**

| Today's row | Goes to |
|---|---|
| Show errors / warnings / infos / hints (double-click toggles) | Findings Dashboard toolbar chips (single click, live) + `...` view menu |
| Run analysis after config change / dependency change | Rules & Tiers dashboard → "Automation" card |
| UI language | Rules & Tiers dashboard → "Extension" card |
| Analyzer plugin (row) / Tier (row) | Engines row (plugin state) / Rules & Tiers hero (tier) |
| Initialize / Update config | Banner state when config missing; otherwise Rules & Tiers → "Config" card |
| Find stale ignores | Merged into "Fix stale ignores" (finds first, shows count, then offers fix) |
| Upgrade Opportunities / Full Opportunities Report | Tabs inside Package Dashboard |
| Getting Started / About / pub.dev / AI instructions | `...` view-title menu (4 items) |
| Debug webview (DIAGNOSTIC ENGINES) | Health Panel webview, opened from Engines row |
| Detected packages / Lane / Migrate config keys / triage rows | Rules & Tiers dashboard |

**Banner view** stays but only for two states: not a Dart project (info, no action) and
setup-needed (one button "Set up Saropa Lints", runs `enable` + init). Everything else hides it.

### 2.2 Dashboards — 6 first-class, everything else is a tab or a drill-down

| Dashboard | Tabs / regions | Absorbs (today separate) | Live source |
|---|---|---|---|
| **Home** (`saropaDashboardsView`) | KPI band: health, issues, engines, packages, code-health grade, project size. One card per other dashboard with its top-3 signal and an "Open" button. | Status tree rows; consolidated view gauge | live diagnostics model + vibrancy model + engine status |
| **Findings** (`violationsWideReportView`) | Toolbar chips: severity ×4, tier, pack, file scope. Group-by. Hotspot review. Suppressed. Trends. | Severity toggles; `focusIssues*`; Related Rule Telemetry as a side panel; Rule Explain as a drawer | `onDidChangeDiagnostics` |
| **Rules & Tiers** (`rulePacksWebviewProvider`) | Tabs: Tier · Rule packs · Overrides · SDK rollout · Config file · Automation · Extension | `analysis_options_custom.yaml`: `max_issues`, `output`, `platforms`, `severities`, `banned_usage`, `saropa_tier`, `runtime_tier`, `diagnostic_statistics`; settings: run-after-*, uiLanguage, scanOnSave, inlineAnnotations, issuesPageSize, groupBy; baseline create/view/apply; Analysis Optimizer as a tab | config file watcher + settings change |
| **Packages** (`vibrancy/report-webview`) | Tabs: Overview · Upgrade opportunities · Full report · Known issues · Compare · Settings | opportunities-panel, feature-inventory, known-issues, comparison, package-detail (drawer); all 60 `packageVibrancy.*` settings as a form | scan events (already live) |
| **Code Health** (`projectVibrancyReportView`) | existing + Settings tab (lcov path, thresholds) | 7 `projectVibrancy.*` settings | CLI stream (already live) |
| **Project Map** (`projectMapView`) | existing + Reports tab | `severity_report`, `impact_report`, `quality_gate` (+ yaml editor), `stub_test_report`, `accuracy_report`, `memory_report`, `doctor` — each a "Run" button with streamed output and a table | must be converted to live (CLI stream, same pattern as Code Health) |

**Health Panel** (`systemHealth/healthPanel` + `debug/debugPanel` merged): engines ON/OFF, PID,
RSS, restart/kill, poll graph, log expander (collapsed by default). Opened from Engines row. Not a
sidebar view.

**Command Catalog** stays as the escape hatch, reachable from Quick Actions and `...` menu.

### 2.3 Status bar

Unchanged text; click → Home instead of Findings. Fix the dead `saropaLints.editorDashboards.focus`
target (`extension.ts:1237`) → `saropaLints.openDashboards`.

---

## 3. Phases (each independently shippable; each ends with a screenshot in the finish report)

### Phase 0 — Fix the broken things (½ day, Sonnet) — DONE 2026-09-03
- [x] Status-bar disabled-state click targets an uncontributed command (`extension.ts:1237-1240`).
      Fixed: now fires `saropaLints.openDashboards` (verified registered in `saropaDashboardsView.ts:115`).
- [x] Severity rows toggle only on double-click (`extension.ts:625-654`) — replaced with a
      single-click `TreeItem.command` on `SeverityToggleItem` (`sectionedSidebar.ts:93-111`); removed
      the 400ms double-click detector from `extension.ts`; updated the tooltip copy in `en.json`.
- [x] `focusPackageVibrancyPackages` / `focusIssues*` — re-checked: both route through live,
      registered commands (`revealFindingsDashboard`, `packageVibrancy.showReport`), not dead views.
      Original inventory note was imprecise; no fix required.
- [x] "Lint integration: Off" banner row — re-checked: already single-click via `saropaLints.enable`
      (`sectionedSidebar.ts:214-221`, `LeafItem` wires `TreeItem.command`). No fix required.

### Phase 1 — Sidebar shell (2 days, Sonnet) — PARTIALLY DONE 2026-09-03
Files: `views/sectionedSidebar.ts`, `views/configTree.ts`, `package.json` (views, menus),
`extension.ts:604-658`, `en.json`.

**Shipped (the safe, non-stranding slice):**
- [x] Views collapsed 7 → 5: deleted the standalone `severityFilters` and `help` view
      contributions from `package.json`. Diagnostics rows (severity toggles + Lint
      integration/Analyzer plugin/Tier) now render inside the Settings panel
      (`buildSettingsItems` appends `buildDiagnosticsItems`, `sectionedSidebar.ts:593-612`).
      The 4 Help commands moved to the Dashboards view's `view/title` "..." overflow menu
      (`package.json`, group `9_help`) instead of a dedicated panel.
- [x] Removed the now-redundant `toggleSeverityInline` command and its inline context-menu
      button (dead once severity rows became single-click in Phase 0).
- [x] Moved the version-suffixed view title (`Dashboards (vX.Y.Z)`) from the deleted Help view
      onto the Dashboards view (`extension.ts`); added the `sidebarShell.dashboardsViewTitle`
      l10n key.
- [x] Renamed the view label "Editor dashboards" → "Dashboards" in `package.nls.json`.
- [x] Updated `test/views/overviewTreeFlat.test.ts` for the new 5-view contract (12/12 passing);
      fixed one pre-existing unrelated failure in the same assertion (`debugPanel` was never in
      `SECTION_VIEW_IDS`, predates this work).
- [x] `tsc --noEmit` clean; touched test files pass. Translated locale catalogs (`package.nls.*.json`,
      `src/i18n/locales/<lang>.json`) are now stale for the changed keys — NOT regenerated, per the
      hard rule against running the MT pipeline without an explicit in-the-moment request.

**Deferred — not done, do NOT treat as complete:**
- [ ] Still 5 views, not the target 4. `banner`, `editorDashboards` (Dashboards), `settings`
      (now carries actions+settings+triage+diagnostics), `status`, `debugPanel` (webview, Phase 2).
- [ ] Status section is still the full 8-row list (Health, violation count, hotspots, suppressions,
      trends, regression, last run…), not the 3-row Health/Engines/Integration redesign in §2.1.
      Adding the Engines row needs the engine-status callback wired in from `extension.ts:1330-1425`
      — not done; Debug panel content still lives only in the separate webview view.
- [ ] Dashboards section still lists all 11 rows from `buildEditorDashboardItems`, not reduced to
      the 6-row target — Upgrade Opportunities / Full Opportunities Report / Analysis Optimizer /
      Command Catalog still render as top-level rows because Phases 4-6 (which give them a tab
      home inside Rules & Tiers / Packages / Project Map) have not landed. Removing them now would
      have stranded those features.
- [ ] No live badges added beyond the existing package-adoption-needle count.
- [ ] Quick Actions not restructured into the 3-row target; Settings panel still holds the full
      action+setting+triage+diagnostics row list (~15-20 rows depending on triage state).
- [ ] Empty/off/error states not audited.
- [ ] Row-count target (≤14) NOT met — full redesign needs Phases 4-6 to land first so dashboard
      rows have somewhere to go. Revisit this phase once those land.

### Phase 2 — Health Panel merge (1 day, Sonnet) — DONE 2026-09-04
- [x] Engine cards (ON/OFF, PID, RSS, Kill/Restart all) moved into the Health Panel editor-tab
      webview, on the shared chrome stylesheet (`healthPanel-styles.ts` already extended
      `getDashboardChromeStyles()`; engine-card CSS now layers on top of it via the new
      `systemHealth/engineCardsHtml.ts:getEngineCardsStyles()`). Log renders as a native
      `<details>`/`<summary>` expander, collapsed by default.
- [x] Deleted `debug/debugPanel.ts` and `debug/debugPanel-html.ts` outright (not just the bespoke
      markup) — their content (types, builders, styles) moved into `systemHealth/engineCardsHtml.ts`
      and `systemHealth/healthPanel.ts`. `debug/saropaLspClient.ts` is untouched, still in `debug/`.
- [x] `saropaLints.debugPanel` view contribution removed from `package.json` — the sidebar is back
      down to 4 views (banner, editorDashboards, settings, status), meeting Phase 1's original view
      count target as a side effect.
- [x] `saropaLints.debug.enabled` setting repurposed (not deleted): it now gates whether the Engines
      section renders inside the Health Panel (`HealthPanel.collectEngines()`), instead of gating a
      standalone view's existence. Description updated in `package.nls.json`.
- [x] `saropaLints.toggleDebugPanel` command kept (palette/history compatibility) but now opens the
      Health Panel via `HealthPanel.createOrShow`, same as `showProcessHealth`; title updated.
- [x] Engine deps, the log buffer, and the toggle/killAll/restartAll event emitters moved to
      `HealthPanel` **static** members so they survive the tab being closed and reopened — the
      former sidebar webview view was always resolved at activation and never really closed, so this
      preserves that "always tracking" behavior despite the panel itself now being a lazily-opened tab.
      `tsc --noEmit` clean on both the main and test projects; 13/13 sidebar-contract tests plus the
      broader affected sweep (81 tests) pass.

**Deferred — not done:**
- [ ] Engines status row in the sidebar ("plugin live · daemon idle · LSP live") — still part of the
      undone Phase 1 status-row redesign, not this phase. Blocked on the same Phases 4-6 dependency
      noted under Phase 1.
- [ ] LSP scan-progress surfacing in the Engines card (file count, diagnostic count) — the server only
      logs this to stderr today; exposing it requires a protocol change on the LSP side, out of scope
      for a webview-merge phase.

**LSP server state (v16.0.0) — context carried forward:** the LSP server now runs a full workspace
scan on startup (all `.dart` files under `lib/`, `bin/`, `test/`), so the Problems panel populates
project-wide without the user opening every file. It is ON by default, so the Engines section's
typical LSP card state is now "running", not "stopped" — the Phase 1 deferred sidebar-summary work
above should say "LSP live" not "LSP off" as its example.

### Phase 3 — Home hub (2 days, Sonnet) — DONE 2026-09-04
Files: `views/saropaDashboardsView.ts`, `views/dashboardSummaries.ts`, `systemHealth/healthPanel.ts`,
`views/projectVibrancyReportView.ts`, `extension.ts`, `en.json`.
- [x] KPI band (6 tiles: health score, open issue count, engines, packages, Code Health grade,
      project size) + one card per other first-class dashboard (Findings, Rules & Tiers/Lints
      Config, Packages, Code Health, Project Map, Full Audit), each with its top live signals and an
      "Open" button. Every value is a cheap read (JSON export / in-memory cache / config / file
      stat) — nothing on Home triggers a `dart run` scan, which also removes the old
      sequential-heavy-scan-on-every-open cost the pre-Phase-3 launchpad paid. Code Health's card
      reads the last in-session scan result (`getLastProjectVibrancyPayload`, new); Project Map's
      card reads only its last report's file mtime (`getLastProjectMapMtime`, new) — the CLI emits
      HTML only, no structured size/hotspot JSON, so a numeric "project size" is not cheaply
      available; both surfaces show an honest "not scanned" state instead of a fabricated number.
      Added `HealthPanel.getEngineStatuses()` (new public static accessor) so the KPI band can read
      the same engine snapshot the Health Panel shows without opening that panel.
- [x] Replaced the consolidated dashboard's (`saropaLints.openConsolidatedDashboard`,
      `views/consolidated/*`) grade-gauge hero with the Home KPI band. Confirmed nothing else
      referenced it (`grep` for the command id found only its own registration, the manifest
      contribution, the command-catalog listing, and its own tests) and deleted it outright:
      `views/consolidated/{consolidatedModel,consolidatedView,consolidatedClient,consolidatedStyles}.ts`,
      `test/{consolidatedModel,consolidatedClient}.test.ts`, the command registration + import in
      `extension.ts`, the `package.json` command contribution, the `package.nls.json` title string,
      the `commandCatalogEntriesProject.ts` entry, and both dead entries in `tsconfig.test.json` +
      the `npm test` mocha spec list.
- [x] Status bar's enabled-state click target repointed from `saropaLints.openViolationsWideReport`
      to `saropaLints.openDashboards` (`extension.ts`, the `updateAllStatusBars` closure). The
      disabled-state target already pointed at `openDashboards` since Phase 0.
- [x] `tsc --noEmit -p .` and `tsc -p tsconfig.test.json` both clean; `npm run verify-nls-keys`
      clean (347 keys). Rewrote `test/views/saropaDashboardsView.test.ts` for the new KPI-band + card
      contract (9/9 passing) since the shell's HTML shape changed.

**Deferred — not done:**
- [ ] Project size KPI/card shows presence-only ("Mapped — see Project Map" / "Not scanned"), not a
      real size number — the `project_health` CLI's `--format html` output carries no structured
      size/dead-weight JSON to read cheaply; scraping the generated report markup for a number was
      rejected as fragile (see `saropa-lints-extension-development` skill's guidance against reading
      generated HTML as a data source). A real number needs a Dart-side `--format json` (or similar
      machine-readable summary) addition to `bin/project_health.dart`, out of scope for a
      TS-only hub phase.
- [ ] Code Health's KPI tile/card only reflects a scan that happened *this VS Code session* (the
      cache is in-memory, not persisted) — reopening VS Code resets it to "not scanned" even if a
      report file exists on disk from an earlier session. A persisted-report reader (parallel to
      Project Map's mtime check) would need to pick the latest of potentially many
      `reports/<yyyymmdd>/..._saropa_code_health.json` files, which was judged not worth the added
      file-system-glob cost for this phase; revisit if users report the KPI looking stale on first
      open.
- [ ] Translated locale catalogs (`package.nls.*.json`, `src/i18n/locales/<lang>.json`) are stale for
      the new/changed keys — not regenerated, per the hard rule against running the MT pipeline
      without an explicit in-the-moment request.

### Phase 4 — Rules & Tiers becomes the config surface (3 days, Sonnet; Opus for the yaml editor design only)
Files: `rulePacks/rulePacksWebviewProvider.ts`, `configDashboardStyles.ts`,
`analysisOptimizer/*`, `setup.ts` (baseline), `lib/src/config/*` for key names.
- [ ] Tabs as in §2.2. Every `analysis_options_custom.yaml` top-level key gets a control that writes
      the file (round-trip through the existing YAML writer; do not regex the file).
- [ ] Every `saropaLints.*` extension setting outside the vibrancy/health/todo/drift groups gets a
      control that calls `workspace.getConfiguration().update`.
- [ ] Baseline: create / view diff / apply, with the current baseline file rendered as a table.
- [ ] Analysis Optimizer moves in as a tab; its panel command becomes a deep link.
- [ ] Config file watcher already exists for live reload; wire it to re-render the active tab.

### Phase 5 — Packages consolidation (2 days, Sonnet)
Files: `vibrancy/views/*`.
- [ ] Tabs: Overview · Upgrades · Full report · Known issues · Compare · Settings.
- [ ] Migrate `report-styles*.ts` onto `dashboardChromeStyles`; delete the parallel system.
- [ ] Settings tab renders all 60 `packageVibrancy.*` settings as grouped forms (token, weights,
      budget, watch, upgrade, vuln). Group the 7 nullable budget gates as one "Budget" card.
- [ ] Reduce the ~90 `packageVibrancy.*` commands: keep the ones bound to buttons/tabs, mark the
      rest `commandPalette: false` or delete if unreachable. Target ≤ 25.

### Phase 6 — Project Map live + CLI reports (2 days, Sonnet) — DONE 2026-09-04
Files: `views/projectMapView.ts`, `views/projectMapShell.ts` (new), `views/projectMapReports.ts` (new),
`bin/*.dart` (read-only reference).
- [x] Convert Project Map from one-shot render to a live pattern. The panel now opens immediately
      showing a scanning state (spinner, elapsed timer, a streamed activity log fed by the CLI's real
      stdout/stderr) instead of the old `vscode.window.withProgress` notification that rendered
      nothing until the scan finished. On completion the panel swaps in the extracted report fragment
      in place — no full-document reload, no lost tab state. Cancel and Restart both act on a real
      `CancellationTokenSource` against the actual child process.
- [x] Reports tab: one card per `severity_report`, `impact_report`, `quality_gate`, `stub_test_report`,
      `accuracy_report`, `memory_report`, `doctor` — all 7 CLIs the plan listed. Each Run button
      spawns its CLI and streams stdout/stderr live into a `.dash-table` (real `<table>`, sticky
      header, chrome-styled). `quality_gate`'s card has an inline `<textarea>` YAML editor for
      `saropa_quality_gate.yaml` (Save writes the file; Run re-evaluates against it). Every run
      persists its combined output to `reports/.saropa_lints/reports-tab/<id>.log`.
- [x] Project Map's own chrome (hero, tab bar, scanning state, report cards) now builds from
      `getDashboardChromeStyles()` plus a small supplementary stylesheet layered on top — the same
      pattern Code Health's scanning view already uses (`codeHealthScanProgress.ts`), not a second
      bespoke system.
- [x] `tsc --noEmit -p .` clean. `tsc -p tsconfig.test.json` clean for every file this phase touched
      (an unrelated, already-in-progress edit to `views/saropaDashboardsView.ts` from a concurrent
      session fails that same test compile independently of this phase — verified via `git status`
      showing it modified before this phase started; not caused by or fixed in this change).

**Deferred — not done, do NOT treat as complete:**
- [ ] **No true percentage progress bar for the Map scan.** `bin/project_health.dart` has no
      `--progress` NDJSON protocol the way `bin/project_vibrancy.dart` does (verified: no `--progress`
      flag exists in the file, and `bin/*.dart` was explicitly out of scope for this phase to edit).
      The scanning state is genuinely live (real elapsed timer, a real activity log, a real process
      kill on Cancel) but cannot show "43% — 812/1900 files" the way Code Health does, because the CLI
      never emits that data. Adding it requires a Dart-side change to `project_health.dart` mirroring
      `project_vibrancy.dart`'s `--progress`/`--control` flags — a follow-up, not a TS-only fix.
- [ ] **Report cards show raw output, not per-tool structured columns.** All 7 CLIs are
      `print()`-based text tools with no shared machine-readable contract (only `accuracy_report` and
      `stub_test_report` have a `--format json` option). Rather than write a bespoke, fragile regex
      parser per tool's wording, every card streams a generic two-column `.dash-table` (line number +
      raw text) — live-updating, but not "File / Line / Rule" columns for `severity_report` specifically.
      A follow-up could add per-tool parsers for the highest-value cards (severity_report, doctor).
- [ ] **The embedded `project_health --format html` report itself keeps its own `.pm-pane` styles**,
      not `dashboardChromeStyles` — deliberate, not an oversight: `health_html_template.dart`'s output
      is also a portable standalone artifact (CI export, shareable file with no VS Code host), and
      rebinding its internals onto the webview-only chrome system would break that use case. Only the
      NEW shell this phase built (hero, tabs, scanning state, report cards) uses the chrome directly.
- [ ] **No dedicated unit test for `projectMapView.ts` / `projectMapShell.ts` / `projectMapReports.ts`.**
      No test file existed for this view before this phase (only `saropaDashboardsView.test.ts`
      references "projectMap" incidentally, and it currently fails to compile for unrelated reasons —
      see above). Correctness evidence here is `tsc --noEmit` clean plus manual review of the generated
      client script; it has not been evaluated in a real Extension Development Host.
- [ ] `transformProjectMapHtml()` / `webviewThemeOverride()` in `projectMapView.ts` are now dead code
      (their only caller, the old single-command `renderPanel()`, was replaced) but were left in place
      rather than deleted, since deleting is out of scope for a feature phase and nothing else in this
      review confirmed they're safe to remove — a cleanup candidate for Phase 7.

### Phase 7 — Design-system sweep + polish (1 day, Sonnet)
- [ ] Grep for any `<style>` not sourced from `dashboardChromeStyles*`; migrate or justify inline.
- [ ] Every dashboard: loading skeleton, empty state, error state, off/disabled state.
- [ ] Keyboard: every dashboard tab reachable by `1-9`, `/` focuses search, `Esc` closes drawers
      (extend existing `keyboard-shortcuts`).
- [ ] Dark/light/high-contrast pass against VS Code theme tokens; no raw hex where a token exists.
- [ ] All new strings via `l10n()` + `en.json`; regenerate locales.

---

## 4. Acceptance (measured, not felt)

| Metric | Today | Target |
|---|---|---|
| Sidebar views | 7 | 4 (banner conditional) |
| Sidebar rows (Dart project, integration on) | 35 | ≤ 14 |
| Rows that need double-click | 4 | 0 |
| Commands reachable only via palette | ~145 | ≤ 40 (all listed in Command Catalog) |
| Style systems | 5 | 1 |
| Dashboards that are one-shot static | 6 | 0 (Full Audit and About may stay static; they are reports) |
| `analysis_options_custom.yaml` keys with no UI | 8 | 0 |
| `bin/*.dart` reports with no UI | 8 | 0 |
| Max clicks from sidebar to any setting or report | 4+ | 2 |
| Broken command targets | 3 | 0 |

Each phase's finish report includes a sidebar screenshot (kykto project) and a table row showing the
metric moved.

---

## 5. Agent execution notes

- Load `saropa-lints-extension-development` before touching `extension/src`. Load
  `saropa-lints-config-and-tiers` for Phase 4. Do not load both for Phase 1.
- One phase per agent session. Phases 2, 5, 6 are independent of each other and can run in
  parallel after Phase 1 lands.
- Do not "fix" the deliberately unregistered tree providers (`extension.ts:581-590`); they are
  data sources. Do not migrate the three files the consolidation plan marks "intentionally not
  migrated".
- Never edit `extension/CHANGELOG.md`; append to root `CHANGELOG.md` `— Unreleased`.
- Screenshots go to the scratchpad, then are attached to the finish report via SendUserFile.

---

## Appendix — baseline inventory (2026-09-03, v15.2.12 code)

**Views** (`package.json:52-104`): banner, editorDashboards, status, settings, severityFilters,
help, debugPanel (webview view, `debug/debugPanel.ts:64`). All rows flat
(`sectionedSidebar.ts:688-702`).

**Commands:** 191 (`package.json:106-991`). In menus: 9. Palette-gated: ~40. Palette-only: ~145.
`packageVibrancy.*`: ~90 (`package.json:614-926`).

**Settings:** 108 across 8 groups (`package.json:1220+`): core 15, severity 4, code health 7,
sidebar 1, TODOs 8, drift 5, vibrancy 60, system health 7, debug 2.

**Webviews (19):** Home/launchpad (live), Findings (live), Lints Config (interactive), Analysis
Optimizer (interactive), Code Health (live stream), Project Map (**static**), Package Dashboard
(live), Upgrade Opportunities (live), Full Opportunities (static export), Full Audit (static),
Consolidated (live), Command Catalog (live), About, Rule Explain, Related Rule Telemetry, Health
Panel (live poll), Known Issues (live), Comparison (static), Package Detail (unregistered view).

**Style systems (5):** `views/dashboardChromeStyles*.ts` (canonical, 12 consumers),
`vibrancy/views/report-styles*.ts`, `violationsDashboardStyles.ts`, `consolidatedStyles.ts`,
`audit/audit-report-styles.ts`, plus Project Map inline.

**No-UI features:** `bin/severity_report`, `quality_gate`, `impact_report`, `memory_report`,
`accuracy_report`, `stub_test_report`, `diagnostic_baseline`, `doctor`; yaml keys `max_issues`,
`output`, `platforms`, `severities`, `banned_usage`, `saropa_tier`, `runtime_tier`,
`diagnostic_statistics`; baseline contents (create only).

**Broken targets:** `saropaLints.editorDashboards.focus` (status bar), `focusPackageVibrancyPackages`,
`focusIssues*` (views not contributed).

**Prior art (do not redo):** `plans/history/**/sidebar_view_inventory.md`,
`dashboard-style-unification.md`, `consolidated-dashboards-iframe-to-composed.md`,
`severity-filter-sidebar-toggles.md`, `extension_sidebar_view_icons.md`.
