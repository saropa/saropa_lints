# Sidebar row collapse — 25–39 rows → 13

**Created:** 2026-09-04 · **Author:** Fable (planning) · **Executors:** Sonnet per work package
**Parent:** `PLAN_extension_ui_redesign.md` §2.1 (target IA) — this file supersedes that section's
row tables and every "still open toward ≤14" note. Do not re-derive the inventory; it is below.
**Status:** Planned. WP0 is a commit of already-verified work; WP1–WP7 not started.

Every disposition in this file was verified against the checked-in source on 2026-09-04, not
inherited from the parent plan's tables (which were wrong twice: Home hub, severity chips).
Line numbers are from that snapshot — re-grep before editing, do not trust them blindly.

---

## 1. Current inventory (from code, Dart project, `saropa_lints` dep present, integration on)

Row counts assume: violations exist, `violations.json` export exists with triage data,
`saropaLints.debug.enabled` on. Ranges show the data-dependent spread.

| View | Builder | Rows | Contents |
|---|---|---|---|
| Banner | `sectionedSidebar.ts` `buildBannerItems` | 0 | "Set Up Project" only when dep missing |
| Dashboards | `buildEditorDashboardItems` | 6 | Lints Config · Package Dashboard · Code Health · Project Map · Findings · Full Audit |
| Settings | `buildSettingsItems` = `buildActionItems` + `configTree.getSettingAndActionNodes` (filtered by `isRedundantSettingsAction`) + `configTree.getTriageNodes` + `buildDiagnosticsItems` | 17–24 | see §2 |
| Status | `buildStatusItems` | 2–9 | Health · Engines · Lint integration · Hotspots · Suppressed · Trends · Score dropped · Fewer issues · Last run |
| **Total** | | **25–39** | target ≤ 14 |

---

## 2. Disposition — every row, with the verification that decided it

Legend: **KEEP** · **CUT** (verified duplicate exists today) · **MOVE** (landing spot must be
built in the same WP before the row is removed) · **FOLD** (information survives inside another row).

### 2.1 Settings panel (17–24 rows → 4, +1 conditional)

| # | Row | Source | Disposition | Evidence |
|---|---|---|---|---|
| 1 | Run analysis | `buildActionItems` | KEEP | Quick Action in target IA |
| 2 | Initialize / Update config | `buildActionItems` | KEEP | No dashboard equivalent found (grep `initializeConfig` in `rulePacksWebviewProvider.ts` → 0 hits). Real setup/repair action. |
| 3 | Fix stale ignores | `buildActionItems` | KEEP | Merged row, landed 2026-09-04 |
| 4 | Command Catalog | `buildActionItems` | KEEP | Escape hatch in target IA |
| 5 | Run analysis after config change | `configTree.buildSettingNodes` | **CUT** | `settingsCatalog.ts` excludes only `enabled`/`tier` + 4 prefixes → key renders as a boolean control on Rules & Tiers **Automation** tab (`_buildAutomationTab`, `rulePacksWebviewProvider.ts:1888`). Command `toggleRunAnalysisAfterConfigChange` stays palette-contributed (`package.json:146`). |
| 6 | Run analysis after dependency change | `buildSettingNodes` | **CUT** | Same — Automation tab. Palette: `package.json:150`. |
| 7 | UI language | `buildSettingNodes` | **CUT** | `settingsCatalog.ts:158` routes `uiLanguage` to the **Extension** tab. `onDidChangeConfiguration` (`extension.ts:803`) already applies locale + reloads dashboards on any change source. Palette: `pickUiLanguage` `package.json:174`. |
| 8 | Detected (`Flutter · pkg, pkg…`) | `buildSettingNodes` | **CUT** | Package Dashboard lists every dependency; Extension tab `_buildPlatformsBlock` (`:1634`) shows platforms. Click target `openPubspec` stays palette-contributed (`package.json:142`). |
| 9 | Migrate config keys | `configTree.buildActionNodes` | **FOLD → conditional** | `migrateConfigKeys(root, {dryRun:true})` (`config/migrateConfig.ts:75`) returns `moved[]` — a ready-made detector. Show the row ONLY when `moved.length > 0`, labeled with the count; it disappears once migrated. Steady state: 0 rows. |
| 10 | Open analysis_options_custom.yaml | `buildActionNodes` | already filtered | `isRedundantSettingsAction` drops it |
| 11–18 | Triage rows (guard row, or critical group + volume groups A–D + "N rules with zero issues" + "N rules disabled by override" + stylistic) | `configTree.getTriageNodes` | **CUT all** | Volume/critical/stylistic groups duplicate Findings' top-rules triage table (`violations-dashboard-tables.ts:28`, input `topRules` built at `violationsWideReportView.ts:310`) and its Errors KPI card. Zero-issue / disabled-override rows already click to Lints Config, which has the Overrides tab. Guard rows ("run analysis first" / "stale export") duplicate Findings' freshness pill. |
| 19–22 | Show errors / warnings / infos / hints | `buildDiagnosticsItems` (`SeverityToggleItem`) | **CUT** | `severity.error|warning|info|hint` not excluded by `settingsCatalog.ts` → 4 boolean controls on the Automation tab. Behavior parity verified: `registerSeverityToggle` (`extension.ts:2738`) does nothing but `cfg.update` + `refreshAllSections`; consumers (`scanOnSaveController.ts:20`, `issuesTree.ts:44`, `vibrancy/providers/diagnostics.ts:15`) react to `affectsSeveritySettings` on config change regardless of who wrote it. Commands stay palette-contributed (`package.json:154–166`). The parent plan's "NOT cut" entry compared against the wrong surface (Findings chips); the Automation tab is the real duplicate. |
| 23 | Analyzer plugin (live / disabled / absent) | `configTree.buildAnalyzerPluginNode` | **MOVE → Status, conditional** | It is a state, not a setting. Engines row already reports the analyzer engine when live. Render in Status ONLY when state ≠ `live` (disabled → `reenablePlugin`, absent → `initializeConfig`), warning color. The `live` → `verifyPlugin` probe stays in Command Catalog / Health Panel. |
| 24 | Tier | `configTree.buildDiagnosticControlNodes` | **FOLD → Lints Config row description** | Click already opens `openConfigDashboard` = the same command as the Dashboards "Lints Config" row. Fold the value into that row's description: `Tier: recommended · Lane: light`. |
| 25 | Lane | `configTree.buildLaneNode` | **MOVE → Config file tab card, + FOLD** | `lane` is an `analysis_options_custom.yaml` top-level key with NO Config-file-tab card (`CUSTOM_YAML_TOP_LEVEL_KEYS`, `customConfigYaml.ts:38`, lacks it). Build the card (WP2), then fold the value into the Lints Config row description alongside Tier. `setLane` stays palette-contributed (`package.json:360`). |

### 2.2 Status panel (2–9 rows → 3, +1 conditional)

| # | Row | Disposition | Evidence |
|---|---|---|---|
| 1 | Health | KEEP; gains a tooltip `Last run: {timeAgo}` | absorbs row 9 |
| 2 | Engines | KEEP (conditional on `debug.enabled`, unchanged) | |
| 3 | Lint integration | KEEP | |
| 4 | Hotspots: N% reviewed | **MOVE → Findings status-line pill** | Findings renders no hotspot data (grep `hotspot` in `violationsWideReportView.ts` → 0). Pill: `🛡 {open} open · {percent}% reviewed`, tooltip with safe/fixed breakdown, click → `saropaLints.reviewHotspotState` (no-arg path shows a QuickPick — `issuesViewCommands.ts:209`). |
| 5 | N suppressed | **CUT** | Findings already renders `analyzerSuppressions` + `viewSuppressions` (`violationsWideReportView.ts:295–296`). |
| 6 | Trends | **MOVE → Findings status-line pill** | `getScoreTrendSummary` / `getTrendSummary` (`runHistory.ts:138/110`) have no dashboard home. |
| 7 | Score dropped A → B | **MOVE → Findings status-line pill** (`bad` class) | `detectScoreRegression` (`runHistory.ts:180`). |
| 8 | ↓ N fewer issues | **FOLD into the trend pill** | The arrow-series trend text already shows direction; a separate milestone pill is noise. Keep the `good` class when last two totals fell. |
| 9 | Last run | **FOLD → Health row tooltip** | Findings has its own freshness pill; the sidebar keeps the timestamp as hover text on Health, zero rows. |
| — | View `when` clause | **CHANGE** `saropaLints.isDartProject && saropaLints.hasViolations` → `saropaLints.isDartProject` (`package.json:69`) | Target IA says Lint integration is "always shown"; the `hasViolations` gate hides the whole panel on a clean project. `buildStatusItems` handles zero violations (Health says "No violations"; Health is omitted when no `violations.json` has ever been written because `computeLiveHealthScore` needs `filesAnalyzed` — `liveViolationsData.ts:125`). Lint integration renders unconditionally, so the panel is never empty. |

### 2.3 Dashboards (6 → 6)

Unchanged, except the Lints Config row description becomes `Tier: {tier} · Lane: {lane}` (WP2).

### 2.4 Resulting count

| View | Steady state | Worst case |
|---|---|---|
| Banner | 0 | 1 (no dep) |
| Dashboards | 6 | 6 |
| Quick Actions (renamed Settings view) | 4 | 5 (+ Migrate when legacy keys exist) |
| Status | 3 | 4 (+ Analyzer plugin warning) |
| **Total** | **13** | 15, and only while something needs fixing |

---

## 3. Work packages

Rules for every executor:
- Load `saropa-lints-extension-development` before editing `extension/src`.
- Every cut row's command stays registered (palette / Command Catalog) — only the sidebar row goes.
- Every new user-facing string → `en.json` via `l10n()` at write time (`.claude/rules/i18n.md`).
  Never touch the generated `<lang>.json` / `package.nls.<lang>.json` files.
- Dense code comments on everything touched — say WHY the row went and WHERE it lives now.
- Tests: update the named test files in the same WP. `overviewTreeFlat.test.ts` has three global
  invariants that will catch mistakes — every leaf has a command, no nesting, "Run analysis"
  exactly once.
- Verify per WP with the scoped commands in §4 — not the full suite.
- Do not commit; WP6 commits everything after WP7 passes. (Exception: WP0.)
- Do not edit `PLAN_extension_ui_redesign.md` except in WP6.

### Sequencing

```
WP0 (commit prior slice)
  ├── Lane A (all touch sectionedSidebar.ts — SEQUENTIAL): WP1 → WP2 → WP3 → WP5
  └── Lane B (Findings only — parallel with Lane A):        WP4
WP5 depends on WP4 (landing spot must exist before Status rows are cut).
WP6 (manifest, catalog sweep, docs, commit) after both lanes.
WP7 (verification + screenshot) last.
```

---

### WP0 — Commit the prior session's verified slice · Haiku · 5 min

The working tree carries a verified, uncommitted slice (Status/Dashboards/Quick Actions collapse,
2026-09-04 — `tsc` clean, 237 passing / 15 pre-existing failures). Commit it before fanning out so
Lane A and Lane B start from a clean base.

Stage ONLY: `extension/src/i18n/locales/en.json`, `extension/src/stale-ignore-commands.ts`,
`extension/src/test/views/overviewTreeFlat.test.ts`,
`extension/src/test/views/sidebarStatusEngines.test.ts`, `extension/src/views/configTree.ts`,
`extension/src/views/sectionedSidebar.ts`, `plans/PLAN_extension_ui_redesign.md`, `CHANGELOG.md`
(if modified). Other dirty files belong to other sessions — leave them.

Commit: `feat: collapse sidebar Status/Dashboards/Quick Actions rows (11→6 dashboards, merged stale-ignore, Lint integration in Status)`.

---

### WP1 — Cut the Settings duplicates · Sonnet · ~1.5 h

**Files:** `extension/src/views/sectionedSidebar.ts`, `extension/src/views/configTree.ts`,
`extension/src/i18n/locales/en.json`, `extension/src/test/views/overviewTreeFlat.test.ts`.

1. `sectionedSidebar.ts`:
   - Delete `SeverityToggleItem` class (export; grep first — only user is `buildDiagnosticsItems`).
   - Delete `buildDiagnosticsItems`. In `buildSettingsItems` drop the `diagnostics` and `triage`
     spreads; the panel becomes `[...actions, ...settings]`. Rewrite the doc comment: what left,
     where each thing lives now (Automation tab / Extension tab / Findings top-rules table /
     Lints Config).
   - Update the file header comment's "Settings" bullet.
2. `configTree.ts`:
   - `buildSettingNodes`: delete the three setting rows and the Detected block → the method is
     now empty; delete it and the `formatLanguageChoiceLabel` / `readPubspec` imports if unused.
   - `buildActionNodes`: replace the unconditional Migrate row with a conditional one:
     `const probe = migrateConfigKeys(root, { dryRun: true }); if (!probe.error && probe.moved.length > 0)` →
     `setting(l10n('dashboards.controls.migrateLegacyKeys', { count }), l10n('…migrateLegacyKeysDesc'), 'saropaLints.migrateConfig', 'arrow-right')`.
     Root comes from `getProjectRoot()`; no root → no row. Add both keys to `en.json` under
     `dashboards.controls`. Comment WHY conditional (one-shot migration; steady state = 0 rows).
   - `getSettingAndActionNodes` stays (returns `buildActionNodes()` only now).
   - Delete `getTriageNodes` (no caller after step 1). Leave `getChildren`'s own triage use
     alone — the provider is an unregistered data source (`extension.ts:581–590`); do not touch.
   - Leave `getDiagnosticControlNodes` / `buildDiagnosticControlNodes` / `buildAnalyzerPluginNode`
     / `buildLaneNode` in place — WP2 and WP3 consume them next.
3. `en.json`: delete `diagnostics.sidebar.severityToggleTooltip` (and the now-empty
   `diagnostics.sidebar` / `diagnostics` objects if nothing else is inside — grep first).
4. `overviewTreeFlat.test.ts`:
   - Replace "Settings section carries the diagnostics rows" with
     "Settings section carries no severity toggles — they live on the Rules & Tiers Automation tab":
     assert `contextValue === 'severityToggle'` count is 0 AND no leaf command matches
     `/^saropaLints\.toggleSeverity/`.
   - Add "Settings section carries no setting-value rows": assert no leaf command is
     `toggleRunAnalysisAfterConfigChange`, `toggleRunAnalysisAfterDependencyChange`,
     `pickUiLanguage`, `openPubspec`.
   - Add "Settings section carries no triage rows": assert no node has `kind` starting
     `triage`.
   - Add "Migrate row is absent when no legacy keys": stub `migrateConfig.migrateConfigKeys`
     (sinon, module import `* as migrateConfig from '../../config/migrateConfig'`) → `{moved:[],skipped:[]}`,
     assert no `saropaLints.migrateConfig` leaf; second case stub `moved:['max_issues']` → leaf present.
   - Update the file's header comment.

**Acceptance:** Settings panel returns exactly Run analysis · Initialize/Update config · Fix stale
ignores · Command Catalog · (Migrate, only when stubbed legacy keys). §4 scoped run green except
the 15 pre-existing failures.

---

### WP2 — Tier + Lane: Config-file-tab Lane card, fold both into the Lints Config row · Sonnet · ~2 h

**Files:** `extension/src/rulePacks/customConfigYaml.ts`, `extension/src/rulePacks/rulePacksWebviewProvider.ts`,
`extension/src/rulePacks/configDashboardScript.ts` (message handler, if the card posts a message),
`extension/src/views/sectionedSidebar.ts`, `extension/src/views/configTree.ts`, `en.json`,
`extension/src/test/views/overviewTreeFlat.test.ts`, `extension/src/test/rulePacks/configFileCardCoverage.test.ts` (auto-covers).

**Pre-check (do first, report in the finish note):** grep every consumer of
`CUSTOM_YAML_TOP_LEVEL_KEYS` and `CustomYamlTopLevelKey`. If anything iterates the array with the
generic `readScalarKey`/`writeScalarKey` helpers, adding `lane` there must NOT route through those
(lane has deprecation-fallback semantics in `config/laneConfig.ts`). Use `readRawLaneFromCustomConfig`
+ `writeLaneToCustomConfig` for the card.

1. `customConfigYaml.ts`: add `'lane'` to `CUSTOM_YAML_TOP_LEVEL_KEYS` with a comment pointing
   at `laneConfig.ts` as the reader/writer.
2. `rulePacksWebviewProvider.ts`: add `'lane'` to `CONFIG_FILE_CARD_IDS`, `CONFIG_FILE_KEY_TO_CARD.lane = 'lane'`,
   builder `lane: (root) => this._buildLaneCard(root)`. Card = two-option segmented control
   (light / full) mirroring `_buildTierCapCard`'s select pattern; on change post a message the
   provider handles by calling `writeLaneToCustomConfig(root, value)`, then `_runAnalysisIfEnabled()`
   + `refresh()` (same tail as the tier-cap handler at `:2124`). Reuse the existing
   `dashboards.controls.laneLight` / `laneFull` en.json strings for the option labels; add
   `rulesTiers.configFile.lane.title` / `.hint` keys.
3. `sectionedSidebar.ts` `buildEditorDashboardItems`: Lints Config description becomes
   `l10n('dashboards.lintsConfig.description', { tier, lane })` = `"Tier: {tier} · Lane: {lane}"`.
   Tier from `getConfiguration('saropaLints').get('tier','recommended')`; lane via
   `readRawLaneFromCustomConfig(root)` → `'full' | 'light'` (same fallback as `buildLaneNode`).
   No root → omit the lane half. Add the key to `en.json`.
4. `configTree.ts`: delete `buildDiagnosticControlNodes`' Tier and Lane entries and `buildLaneNode`.
   After WP3 takes the plugin node the method and `getDiagnosticControlNodes` die entirely — leave
   that deletion to WP3.
5. Tests: `overviewTreeFlat.test.ts` add "Lints Config row carries tier and lane in its
   description" (stub `laneConfig.readRawLaneFromCustomConfig` → `'full'`, set
   `saropaLints.tier` via `setTestConfig`, assert description contains both). Assert no leaf
   command is `saropaLints.setLane`. `configFileCardCoverage.test.ts` needs no edit — it will
   fail until steps 1–2 are consistent, which is the point.

**Acceptance:** Config file tab renders a Lane card that round-trips `lane:`; sidebar has no Tier /
Lane rows; Lints Config row shows both values; coverage test green.

---

### WP3 — Analyzer plugin → conditional Status warning row · Sonnet · ~45 min

**Files:** `sectionedSidebar.ts`, `configTree.ts`, `extension/src/test/views/sidebarStatusEngines.test.ts`.

1. `configTree.ts`: rename `buildAnalyzerPluginNode` → public `getAnalyzerPluginWarningNode(): ConfigTreeNode[]`
   returning `[]` when `getPluginsIntegrationState(root) === 'live'`, else the existing
   disabled/absent node (keep the `dashboards.controls.analyzerPlugin*` keys; drop the `live` branch
   and its `verifyPlugin` mapping — the probe stays in Command Catalog). Add
   `triageInfoVariant`-style warning coloring if `ConfigSettingNode` supports it; if not, render via
   a `LeafItem` in sectionedSidebar with `list.warningForeground` instead and delete the configTree
   method. Pick one; do not leave both.
   Delete `getDiagnosticControlNodes` + `buildDiagnosticControlNodes` (empty after WP2).
2. `sectionedSidebar.ts` `buildStatusItems`: after `appendLintIntegrationRow`, push the warning
   node(s). `buildStatusItems` must accept the `configProvider` (thread it through
   `createSidebarSectionProviders`' Status factory — the Settings factory already receives it).
3. `sidebarStatusEngines.test.ts`: new describe "Status — Analyzer plugin warning row": stub
   `setup.getPluginsIntegrationState` → `'live'` → no row; `'disabled'` → row with command
   `saropaLints.reenablePlugin`; `'absent'` → `saropaLints.initializeConfig`.

**Acceptance:** Status shows the plugin row only in disabled/absent states; tests green.

---

### WP4 — Findings dashboard: history + hotspot status-line pills · Sonnet · ~2 h · parallel with Lane A

**Files:** `extension/src/views/violations-dashboard-shared.ts`, `violationsWideReportView.ts`,
`violations-dashboard-top.ts`, `violations-dashboard-script.ts` (pre-check), `en.json`,
`extension/src/test/views/violationsDashboardHtml.test.ts`.

**Pre-check:** in `violations-dashboard-script.ts` find how `data-palette-cmd` clicks are dispatched
(the More menu uses it). If the handler is scoped to `.menu-item`, widen it to any
`[data-palette-cmd]` element — the hotspot pill needs it. Confirm the extension side handles the
`paletteCommand` message with an arbitrary command id (it does for the menu; verify no allow-list).

1. `violations-dashboard-shared.ts`: add to `ViolationsDashboardHtmlInput`:
   ```ts
   /** Run-history signals (runHistory.ts) — replaces the sidebar's Trends / Score dropped / Fewer issues rows. */
   history?: {
     /** getScoreTrendSummary ?? getTrendSummary — arrow series, undefined with no history. */
     trend?: string;
     /** detectScoreRegression — present only when the score fell. */
     regression?: { previousScore: number; currentScore: number; drop: number };
     /** true when the last two snapshots' totals fell (was the "↓ N fewer issues" row). */
     improved: boolean;
   };
   /** Security-hotspot review counts — replaces the sidebar's Hotspots row. Absent when total === 0. */
   hotspots?: { total: number; open: number; reviewedSafe: number; reviewedFixed: number };
   ```
2. `violationsWideReportView.ts` `rebuildDashboardHtml`: build both slices —
   `const history = loadHistory(context.workspaceState)`; hotspots via
   `countSecurityHotspotReviewStates(afterDisabled.violations, raw.config?.ruleMetadataByRule, new SecurityHotspotReviewStateService(context.workspaceState))`;
   omit `hotspots` when `total === 0`. Put small builder fns next to
   `buildAnalyzerSuppressionsSlice`. Note in a comment that both slices are part of the render
   signature on purpose (a new run or a review-state change must repaint).
3. `violations-dashboard-top.ts` `buildStatusLine`: after the findings-count pill and before the
   TODO/HACK pill, push (in this order, each only when present):
   - regression → `<span class="pill bad" title="{l10n findingsDash.status.regressionTitle}">▼ {prev} → {curr}</span>`
   - trend → `<span class="pill {improved ? 'good' : ''}" title="{findingsDash.status.trendTitle}">{trend}</span>`
   - hotspots → `<span class="pill {open>0 ? 'warn' : 'good'} toggle" role="button" tabindex="0" data-palette-cmd="saropaLints.reviewHotspotState" title="{findingsDash.status.hotspotsTitle with safe/fixed}">🛡 {findingsDash.status.hotspotsPill {open} {percent}}</span>`
   All strings via `l10n` with `{token}` placeholders; add keys under `findingsDash.status`.
   The trend text itself comes from `runHistory.ts`, which still concatenates English
   (`"First run: N violations"`, `"over 2 weeks"`) — out of scope here; leave a `// TODO(i18n)` on
   the pill pointing at `runHistory.ts` rather than localizing half of it.
4. `violationsDashboardHtml.test.ts`: three cases — no `history`/`hotspots` → no new pills;
   regression + improved trend → `pill bad` with `▼ 82 → 71` and `pill good` with the trend text;
   hotspots `{total:4,open:1,…}` → pill with `data-palette-cmd="saropaLints.reviewHotspotState"`
   and `75%`.

**Acceptance:** Findings status line renders trend / regression / hotspot pills from the new
slices; clicking the hotspot pill opens the review QuickPick; tests green.

---

### WP5 — Status collapse · Sonnet · ~45 min · after WP4

**Files:** `sectionedSidebar.ts`, `extension/package.json` (`:69` when-clause), `sidebarStatusEngines.test.ts`,
`overviewTreeFlat.test.ts`.

1. `buildStatusItems`: delete the hotspot block, `appendSuppressionRow`, `appendTrendRow`,
   `appendRegressionAndMilestone`, and the Last-run block. Remove the now-unused imports
   (`getTrendSummary`, `getScoreTrendSummary`, `detectScoreRegression`,
   `SecurityHotspotReviewStateService`, `countSecurityHotspotReviewStates`, `formatTimeAgo` if
   unused — see step 2). Comment at the top of the function: where each row went (Findings status
   line: WP4) and why suppressions were a straight cut.
2. `appendHealthRow`: set `item.tooltip = l10n('status.health.lastRunTooltip', { ago })` from
   `history.at(-1)?.timestamp` via `formatTimeAgo` when present. `LeafItem` has no tooltip param —
   assign after construction. Add the key to `en.json`.
3. `package.json:69`: `"when": "saropaLints.isDartProject"`. Comment in the `views` block is not
   possible (JSON) — explain in the `sectionedSidebar.ts` header instead.
4. Tests: `sidebarStatusEngines.test.ts` add "Status carries only Health / Engines / Lint
   integration (+ plugin warning)": stub history with a regression + hotspot counts > 0 and
   assert no leaf command is `reviewHotspotState`, no label starts `Trends` / `Score dropped` /
   `↓` / `Last run`, no `eye-closed` icon. Assert Health tooltip contains the relative time.
   `overviewTreeFlat.test.ts`: the `package.json` view assertion already checks ids — add an
   assertion that the Status view's `when` no longer references `hasViolations`.

**Acceptance:** Status = Health · Engines · Lint integration (+ plugin warning); panel visible on a
clean project; tests green.

---

### WP6 — Manifest rename, catalog sweep, docs, commit · Sonnet · ~45 min

1. `extension/package.nls.json`: `"views.settings.name": "Quick Actions"`. View ID
   `saropaLints.settings` stays — renaming an ID orphans persisted view state (see §6). Run
   `npm run verify-nls-keys`.
2. `en.json` orphan sweep: grep each of `dashboards.controls.lane`, `laneLight`, `laneFull`,
   `analyzerPluginLive`, `severityToggleTooltip` for remaining callers; delete only true orphans.
3. `CHANGELOG.md` → existing top `## [16.0.0-beta.2]` → `### Changed`, three bullets max
   (1–3 sentences each): sidebar collapsed to 13 rows with where things moved; Findings status
   line gains trend/regression/hotspot pills; Rules & Tiers Config file tab gains a Lane card.
   The changelog guard hook will warn about a pre-existing version mismatch — ignore, do not
   touch versions.
   Two gaps between the shipped changelog and the code must be closed in the same edit
   (see `AUDIT_extension_ux_facts.md` §4): (a) beta.2 never records that the Settings panel's
   "Engines (LSP / Analyzer)" and "Process health" rows — announced in beta.1 — were cut by the
   2026-09-04 slice (`configTree.ts:114-126`); add a bullet saying where engine toggles live now
   (Status Engines row when debug is on, otherwise Health Panel / Command Catalog). (b) beta.1
   claims the status bar click opens the Dashboards view while integration is off; code opens
   Findings in every state (`extension.ts:1310`). Beta.1 is published and its text stays; beta.2
   must state the actual behavior rather than inherit the claim.
4. `plans/PLAN_extension_ui_redesign.md`: replace §2.1's "NOT cut" table and the "Row count
   after 2026-09-04's cuts" paragraph with one line pointing here; tick the Phase 1 checklist's
   "Row-count target (≤14)" item; §4 acceptance table "Sidebar rows" → 13. Nothing else.
5. Stage exactly the files WP1–WP6 touched (`git status` first; other sessions' files stay
   unstaged). Commit:
   `feat: collapse sidebar to 13 rows; move trends/regression/hotspots to Findings, Lane to Config file tab`
   with a body listing the per-row moves.

---

### WP7 — Verification · Sonnet · ~30 min + host time

1. §4 commands. Expected: type-checks clean; scoped mocha green except the same 15 pre-existing
   failures listed in §4 (report the exact count; anything else is a regression to fix, not note).
2. Extension Development Host: `python scripts/run_extension_local.py d:\src\saropa_kykto`.
   Confirm against §2.4 and screenshot the full sidebar + the Findings status line to the
   scratchpad; attach via `SendUserFile`. Explicit checks (none has ever been done for this plan):
   - Sidebar shows exactly Dashboards (6) · Quick Actions (4) · Status (3) on kykto with debug on.
   - No panel renders VS Code's "There is no data provider registered" placeholder (see §6).
   - Toggle a severity on the Automation tab → Problems panel filters; toggle Lane on the Config
     file tab → `analysis_options_custom.yaml` changes.
   - Findings status line shows the trend pill; hotspot pill click opens the QuickPick.
3. Append a "Finish Report (date) — row collapse" to the bottom of this file: measured row
   count, test numbers, screenshot filename, anything deferred.

---

## 4. Verification commands (scoped — never the full suite)

```
cd d:\src\saropa_lints\extension
npm run check-types
node --max-old-space-size=8192 ./node_modules/typescript/bin/tsc -p tsconfig.test.json
node node_modules/mocha/bin/mocha "out-test/test/views/**/*.test.js" "out-test/test/rulePacks/**/*.test.js" --timeout 10000
npm run verify-nls-keys
python ..\scripts\run_extension_local.py d:\src\saropa_kykto
```

Pre-existing failures on unmodified `main` (15): 13× `issuesTree.test.js`
"vscode.workspace.onDidChangeConfiguration is not a function", `languagePick.test.js` coverage
badge, `uxLabels.test.js` (expects removed `saropaLints.help` view). Plus 5–6 in
`rulePackYaml.test.ts` / `scanner.test.ts` when the rulePacks glob is included (test-isolation
issue documented in the parent plan's Phase 4). Same count before and after = no regression.

---

## 5. Explicitly not in scope

- Locale regeneration (`generate_translations.py`) — operator-only, publish-time gate.
- Localizing `runHistory.ts`'s trend strings — flagged with a TODO in WP4.
- `Initialize / Update config` row — kept; no verified duplicate.
- The `report-styles-parts.ts` migration, `?`-overlay shortcuts — parent plan, untouched.
- Deleting `ConfigTreeProvider.getChildren`'s triage/dashboard-shortcut rows — the provider is an
  intentionally unregistered data source; leave it.

---

## 6. Gotchas

- **Dead panels in the user's installed build (open, blocked on user).** Screenshot 2026-09-04
  21:15 shows three empty panels — "Diagnostics", "Help (V15.2.12)", "Debug" — rendering "There is
  no data provider registered". The installed `16.0.913` manifest (`git show a451467b:extension/package.json`)
  contributes only banner/editorDashboards/settings/status, so those are cached view descriptors
  from the previous stable install. The 16.0.0-beta.1 changelog names exactly those three panels
  as folded away (Diagnostics → Settings, Help → Dashboards "…" menu, Debug → Health Panel), and
  the "Help (V15.2.12)" label is the last stable version's own view name — both consistent with
  stale descriptors rather than a packaging fault. User-side check: Command Palette → "View: Reset View
  Locations" → "Developer: Reload Window". If they persist, inspect
  `%USERPROFILE%\.vscode\extensions\saropa.saropa-lints-16.0.913\package.json`; if it contributes
  those ids the publish pipeline packaged a stale manifest (`scripts/modules/_extension_publish.py`
  order: precompile → copy → vsce) — that becomes its own bug. Do NOT rename any view id in this
  plan; that is exactly how such orphans are created.
- Bash tool cwd persists inside `extension/` mid-session; check `pwd` before `cd extension`.
- `node ./node_modules/.bin/tsc` fails under Git Bash; use `node ./node_modules/typescript/bin/tsc`.
- Editing `CHANGELOG.md` fires `scripts/hooks/changelog_guard.py`, which warns on a pre-existing
  pubspec/package.json/tag version mismatch. The edit lands. Never bump versions.
- No `## [X.Y.Z] — Unreleased` section exists; append to `## [16.0.0-beta.2]`. Never create one.
- Webview client scripts are template literals — no regex literals (`\d` collapses to `d`).
- `overviewTreeFlat.test.ts` stubs `runHistory.loadHistory` → `[]` and `violationsReader.readViolations`
  → `null` in `beforeEach`; Status-row tests that need history belong in `sidebarStatusEngines.test.ts`,
  which uses `setTestConfig` / `clearTestConfig` from `test/vibrancy/vscode-mock.ts`.
- The Findings render signature (`violationsWideReportView.ts:323`) neutralizes `reportTimestamp`
  and `firstPaint` only; the new `history` / `hotspots` slices must stay in the signature so a
  review-state change repaints.
- Working tree carries other sessions' uncommitted edits (`extension/package.json`,
  `bugs/infra_publish_audit_minor_warnings_20260904.md`, `scripts/modules/*.py`, …). Stage by
  explicit path in WP0 and WP6.
