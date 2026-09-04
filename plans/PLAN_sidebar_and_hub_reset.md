# Sidebar + Hub Reset — fix the half-finished redesign

**Created:** 2026-09-04 · **Status:** Proposed, awaiting go
**Trigger:** `bugs/WIP home hub.png` — the live extension after Phases 0–7 of
`PLAN_extension_ui_redesign.md`. User verdict: rows and buttons that may open a screen, run
something, or change a setting with no way to tell which; a bespoke visual language; no logical
layout; a "hub" page that solves no problem.
**Supersedes:** the §2.1 sidebar target and the Phase 3 "Home hub" section of
`PLAN_extension_ui_redesign.md`. Everything else in that plan stands.

---

## 1. What actually went wrong (diagnosis, from code — not from the screenshot)

1. **Phases 4–6 landed; Phase 1 was never revisited.** The sidebar was supposed to shrink to
   ≤14 rows once the dashboards had tabs to absorb the displaced rows. Lints Config now has
   Tier · Rule packs · Overrides · SDK rollout · Config file · Automation · Extension tabs
   (`rulePacks/rulePacksWebviewProvider.ts:704-1911`), with a live switch/select for every
   `saropaLints.*` setting (`rulePacks/settingsCatalog.ts`, schema-driven). Package Dashboard has
   Overview · Upgrades · Full report · Known issues · Compare · Settings (`vibrancy/views/packages-tabs.ts`).
   Project Map has a Reports tab. **Every destination exists. The sidebar still shows ~35 rows
   across 4 sections because nobody went back and removed the rows that now have a home.**
2. **Three kinds of row, one look.** `sectionedSidebar.ts` + `configTree.ts` render
   navigate-rows ("Findings Dashboard"), run-rows ("Run analysis"), and setting-rows
   ("Show errors: Off", "Tier: recommended") with the same `LeafItem` shape — icon, label, gray
   description. The user cannot tell what a click does without clicking. This is the root of
   "users have to guess."
3. **The hub's controls band duplicates two other surfaces.** `saropaDashboardsView.ts:290-334`
   (`buildControlsBand`) renders Actions / Settings / Help as `.btn` pills. Every one of those
   buttons is ALSO a sidebar row, and every setting is ALSO a real switch on Lints Config ›
   Automation/Extension. A setting rendered as a button labeled "Lint integration: Off" is not a
   component in `plans/guides/SAROPA_DASHBOARD_STYLE_GUIDE.md` §5 at all.
4. **The hub's KPI tiles are a bespoke component.** `dashboardSummaries.ts:327` (`kpiTile`) emits
   `.metric` / `.metric-value` / `.metric-label` with its own CSS in `saropaDashboardsView.ts:416-441`.
   The canonical chrome already has `.kpi-card` / `.kpi-v` / `.kpi-k` and — critically —
   `.kpi-card.interactive` (`dashboardChromeStylesComponents.ts:153-176`) used by Lints Config,
   Known Issues, Comparison, Analysis Optimizer. This is the "invented style guide": the hub
   re-implemented the KPI card, non-clickable, then put an action verb ("Run analysis") in the
   number slot of one tile.
5. **Two truths on one screen.** "Lint integration: Off" (`saropaLints.enabled`, which gates only
   scan-on-save delivery — `extension.ts:553-560`, `scanOnSaveController.ts:48-55`) sits beside
   324 real findings published by the LSP server (`saropaLints.lspServer.enabled`, default on,
   `extension.ts:1278-1304`). Both are true; the label makes the extension look broken.
6. **Nothing was ever looked at.** Every phase's finish report says "no Extension Development
   Host verification." The previous session found `dist/extension.js` was a day stale. Screenshot
   `bugs/WIP home hub.png` is the first human look at the whole design.

---

## 2. The rule that fixes "users have to guess"

A sidebar row is exactly one of three kinds, and **the section it sits in tells you which**:

| Section | Click does | Row shape | Example |
|---|---|---|---|
| **STATUS** | Opens the detail for that fact. Never changes anything. | `● fact · value` — noun, current value | `Engines · LSP on · plugin off` |
| **DASHBOARDS** | Opens one editor-tab page. Never changes anything. | Noun only, page icon | `Lints Config` |
| **ACTIONS** | Runs something now. Visible outcome (progress, toast, diff). | Verb first, play/tool icon | `Run analysis` |

**Settings do not live in the sidebar.** A setting is a switch, a select, or a segmented control on
Lints Config (Tier tab for tier; Automation/Extension tabs for every `saropaLints.*` key; Config file
tab for every `analysis_options_custom.yaml` key). The sidebar may *show* a setting's value as a
STATUS row whose click opens the tab that owns the switch — it never flips it.

Inside webviews the same rule, already written in the style guide, is enforced on audit:
- setting → `<label class="switch">` / `<select>` / `.seg` (Lints Config already does this)
- run → `.btn` with a verb ("Run", "Rescan", "Fix"); exactly one `.btn.primary` per group (§5.4)
- open another page → `.btn.ghost` "Open ↗" or a row click on an `.kpi-card.interactive`
- a value that is not clickable → plain `.kpi-card` (no `.interactive`, no hover)

---

## 3. Target sidebar — 3 sections, 14 rows

```
SAROPA LINTS                       (banner view — only while setup is needed; one row, one action)
  🚀 Set up project                → saropaLints.enable   (pubspec + config + pub get)

STATUS                             (always visible in a Dart project)
  ● Health 82 · 324 issues         → Findings Dashboard
  ● Engines · LSP on · plugin off · scan-on-save off   → Health Panel (the toggles live there)
  ● Hotspots · 0% reviewed         → hotspot review            (hidden when there are none)
  ● Last run · 3h ago              → Findings Dashboard        (hidden before the first run)

DASHBOARDS                         (view/title: ▶ Run analysis · ⟳ Refresh · … Help ×4)
  Findings          324 issues · 11 errors
  Lints Config      recommended · 152 rules
  Packages          38 packages · 8 need attention
  Code Health       B · 1,204 functions        (or "not scanned")
  Project Map       mapped 3h ago               (or "not scanned")
  Full Audit        one-shot report, every rule
  All commands…     search 190 commands

ACTIONS
  ▶ Run analysis
  ✂ Fix stale ignores              (N found — hidden when 0 after a scan)
  🛠 Initialize / Update config
```

### 3.1 Every current row and where it goes

| Current row (section) | Fate | Home it already has |
|---|---|---|
| Lint integration: Off (banner) | **Rewritten** — banner only when `!hasSaropaLintsDep`; the `enabled=false` state moves to the Engines STATUS row as "scan-on-save off" | Health Panel |
| Saropa Dashboards (Dashboards) | **Removed** — see §4 | — |
| Lints Config | Keep, rename desc | — |
| Analysis Optimizer | **Removed** | Lints Config › Config file tab (embedded, Phase 4) |
| Package Dashboard | Keep as "Packages" | — |
| Upgrade Opportunities | **Removed** | Packages › Upgrades tab (Phase 5) |
| Full Opportunities Report | **Removed** | Packages › Full report tab (Phase 5) |
| Code Health Dashboard | Keep as "Code Health" | — |
| Saropa Project Map | Keep as "Project Map" | — |
| Findings Dashboard | Keep as "Findings", moved to top of section | — |
| Full Audit | Keep | — |
| Command Catalog | Keep as "All commands…" | — |
| Health: N (Status) | Keep, merge with issue count into one row | — |
| N critical, N total (Status) | **Merged** into Health row | — |
| Hotspots (Status) | Keep | — |
| N suppressed (Status) | **Removed** | Findings › Suppressed |
| Trends (Status) | **Removed** | Findings › Trends |
| Score dropped / ↓ fewer issues (Status) | **Removed** — delta becomes the Health row's description | Findings › Trends |
| Last run (Status) | Keep; click opens Findings (it currently RUNS analysis — a status row must not) | — |
| Run analysis (Settings) | Keep → ACTIONS | — |
| Initialize / Update config (Settings) | Keep → ACTIONS | — |
| Find stale ignores (Settings) | **Merged** into Fix stale ignores (open decision §7.2) | — |
| Fix stale ignores (Settings) | Keep → ACTIONS | — |
| Run analysis after config change (Settings) | **Removed** | Lints Config › Automation (switch) |
| Run analysis after dependency change | **Removed** | Lints Config › Automation (switch) |
| UI language | **Removed** | Lints Config › Extension (select) |
| Detected: Flutter · pkgs | **Removed** | Lints Config › Extension › platform table |
| Migrate config keys | **Removed** from sidebar; stays in palette + Lints Config › Config file "Migrate" button (add if missing) | Lints Config |
| Triage: "N rules disabled by override" | **Removed** | Lints Config › Overrides |
| Triage: per-rule volume groups | **Removed** | Findings › group by rule |
| Triage data may be outdated | **Removed** (row existed only to explain the rows above) | — |
| Show errors / warnings / infos / hints | **Removed** | Findings toolbar severity `.seg` + Lints Config › Automation (`severity.*` switches) |
| Lint integration: On/Off (Settings) | **Removed** as a toggle row; value shown in Engines STATUS row | Health Panel |
| Analyzer plugin | **Removed**; value shown in Engines STATUS row | Health Panel |
| Tier: recommended | **Removed**; value shown in Lints Config DASHBOARDS row description | Lints Config › Tier |
| Lane: Light | **Removed**; needs a Config file tab card (§5 P2) | Lints Config › Config file |
| Engines (LSP / Analyzer) (Settings, added 2026-09-04) | Becomes the Engines STATUS row | Health Panel |
| Open analysis_options_custom.yaml | Already filtered out; delete the dead builder | — |
| Open Lints Config / Open Package Vibrancy (`buildDashboardShortcutNodes`) | Delete the dead builder | — |

Net: **35 → 14 rows**, 4 views → 3 (banner, status, dashboards+actions can be two views or one
view with two groups — see §5 P1 for why two views).

---

## 4. The hub: delete it

**What problem was it meant to solve?** `PLAN_extension_ui_redesign.md` §2.2: "one page, KPI band,
one card per dashboard with its top-3 signal." The problem that page solves is "I want the numbers
from six dashboards without opening six tabs."

**Why it does not earn its place:**
- The STATUS section above shows Health / issues / engines / hotspots without opening anything.
- Every DASHBOARDS row carries that dashboard's top signal in its description — the "top-3 signal
  card" collapses to one line each, in the sidebar, live.
- Each dashboard already has its own hero KPI strip (Lints Config, Packages, Findings, Code Health).
- The hub's Actions/Settings/Help band is 100% duplication and violates §2 above.
- It is ~860 lines (`saropaDashboardsView.ts` 480 + `dashboardSummaries.ts` 381) plus tests,
  ~25 `dashboards.*` l10n keys across 30+ locales, and an entry in the Playwright harness — all
  maintenance for a page whose only unique content is six numbers already visible elsewhere.

**Delete:** `views/saropaDashboardsView.ts`, `views/dashboardSummaries.ts`,
`test/views/saropaDashboardsView.test.ts`, the `dashboards` fixture in `test/ux/generate-pages.ts`,
the `saropaLints.openDashboards` command + manifest entry + command-catalog entry, the
`dashboards.*` keys in `en.json` (leave stale translations to the next regen), the
`saropaLints.dashboards.*` webview `retainContextWhenHidden` panel. Repoint every caller of
`saropaLints.openDashboards` (status bar `extension.ts:1074-1215`; `enable` post-focus at
`extension.ts:1563`; walkthrough steps if any — grep) to `saropaLints.openViolationsWideReport`
(Findings). Keep `HealthPanel.getEngineStatuses()` — the Engines STATUS row uses it.
Retire `plans/guides/SAROPA_DASHBOARDS_HUB.md` to `plan/history/` (it documents a two-pane
composition that Phase 3 already replaced; it is stale twice over).

**Alternative, if a one-page overview is wanted later:** rebuild as KPI-only — six
`.kpi-card.interactive` tiles from the canonical chrome, each a click-through, no controls band, no
cards. ~120 lines. Not in this plan; do not start it without a stated user need.

---

## 5. Phases (each ends with `npm run compile` + F5 + a screenshot the user has seen)

### P0 — Delete the hub (½ day)
Files: as listed in §4. `overviewTreeFlat.test.ts:176` ("surfaces the five expected dashboards")
and `:186` (Help overflow) updated. `tsc --noEmit -p .`, `tsc -p tsconfig.test.json`, scoped mocha
on `views/**` and `extension` command-registration tests. **Gate:** F5, sidebar Dashboards section
shows no "Saropa Dashboards" row; status-bar click opens Findings.

### P1 — Sidebar rebuild to §3 (1 day)
Files: `views/sectionedSidebar.ts` (rewrite `buildEditorDashboardItems`, `buildActionItems`,
`buildStatusItems`; delete `buildSettingsItems`, `buildDiagnosticsItems`, `isRedundantSettingsAction`,
`SeverityToggleItem`), `views/configTree.ts` (delete `buildSettingNodes`, `buildActionNodes`,
`buildDashboardShortcutNodes`, `buildDiagnosticControlNodes`, `buildTriageSection` **from the
sidebar path** — check `ConfigTreeProvider` for other consumers before deleting the class members;
`getTriageNodes` may feed the Findings triage), `package.json` (`contributes.views`: rename
`saropaLints.settings` → `saropaLints.actions`, drop `hasViolations` from the Status `when` so the
Engines row is always visible; `view/title`: move ▶ Run analysis to the Dashboards view title),
`package.nls.json` (view names), `en.json` (new `sidebar.status.*` / `sidebar.dashboards.*` /
`sidebar.actions.*` keys — the current rows are mostly hardcoded English; externalize on the way
through), `test/views/overviewTreeFlat.test.ts` (rewrite against the 14-row contract: three
sections, every row's `command` id asserted, no row in STATUS/DASHBOARDS may target a
run/toggle command — that assertion is the §2 rule made executable).

Two views, not one, for Dashboards + Actions: VS Code tree views cannot render a group heading
inside a flat leaf list without a collapsible parent (which would draw chevrons — the layout's one
hard rule, `sectionedSidebar.ts:1-10`). A section title *is* the affordance, so it must be a view.

Row descriptions are live: Findings uses `readVisibleLiveViolations` (already the source for
Status), Lints Config reads `saropaLints.tier` + the enabled-rule count Lints Config's hero already
computes (extract that read into a shared helper, do not duplicate), Packages uses
`getLatestResults()` (`countAdoptionNeedles` already does), Code Health uses
`getLastProjectVibrancyPayload()`, Project Map uses `getLastProjectMapMtime()`. The Engines row
uses `HealthPanel.getEngineStatuses()` and `scanOnSaveIsEnabled(cfg.enabled)`.

**Gate:** F5 screenshot of the whole sidebar at 3 states: fresh project (no scan), scanned project,
`saropaLints.enabled=false`. User confirms every row's click does what its section says.

### P2 — Homes for the evicted rows that need one (½ day)
- Lane (`lane:` top-level key in `analysis_options_custom.yaml`) — add a Config file tab card in
  `rulePacksWebviewProvider.ts` beside the other 8 top-level keys; a two-option `.seg` (Light /
  Full) writing through `customConfigYaml.ts`; extend `CUSTOM_YAML_TOP_LEVEL_KEYS` so
  `configFileCardCoverage.test.ts` pins it.
- Migrate config keys — a `.btn` on the Config file tab if `saropaLints.migrateConfig` has no
  dashboard surface (grep first).
- Verify (no code expected): `severity.*` rows render on the Automation tab (they are not in
  `EXCLUDED_EXACT_KEYS`); "N rules disabled by override" is visible on Overrides; Findings' group-by-rule
  covers the triage volume groups.

**Gate:** F5, Lints Config › Config file shows the Lane card; flipping it updates the yaml.

### P3 — Make "Lint integration" honest (½ day)
- Banner (`buildBannerItems`) shows only when `!hasSaropaLintsDep(root)`. The `enabled=false` state
  is no longer a warning banner — it is a fact on the Engines row ("scan-on-save off").
- Rename the setting's manifest label (`package.nls.json` for `saropaLints.enabled`) from "Lint
  integration" to "Scan on save (saropa_lints daemon)" and its description to say what it gates and
  what it does not (the LSP server and analyzer plugin are separate switches in the Health Panel).
- Health Panel engine cards: each card's subtitle says what that engine produces ("publishes
  diagnostics for open + workspace files" / "in-process analyzer squiggles" / "scan on save") so a
  user with 324 findings and one engine off understands where the findings come from.
- `saropaLints.enable` post-action focus (`extension.ts:1563`) → Findings.

**Gate:** with `enabled=false` and LSP on, the sidebar shows real counts AND an Engines row that
explains them; no row says "Off" next to a warning triangle.

### P4 — Verification protocol becomes a rule (no code)
Add to `.claude/rules/` (project): *an extension change is not done until `npm run compile` has
produced a fresh `dist/extension.js`, the Extension Development Host has been reloaded, and a
screenshot of the changed surface has been saved to `bugs/` and shown to the user.* Retro-apply to
Phases 4–7 of the parent plan: one F5 session walking Lints Config's 7 tabs, Packages' 6 tabs, Project
Map's 2 tabs, Health Panel — with the user — before any of them is called visually complete.

### P5 — Locale regen (user runs it)
`en.json` will have ~20 new `sidebar.*` keys and ~25 deleted `dashboards.*` keys. Command for the
user to run when P0–P3 are accepted:
`D:\Tools\Python\Python314\python.exe D:\src\saropa_lints\extension\scripts\generate_translations.py`

---

## 6. Out of scope (explicitly)
- `vibrancy/views/report-styles-parts.ts` migration (parent plan Phase 5/7 deferral) — untouched.
- The 6 pre-existing `findings-populated` a11y failures in `violations-dashboard-tables.ts`.
- `computeLiveHealthScore`'s synchronous disk read on the refresh path (code-review finding, low).
- Any change to the dashboards' internal layouts beyond P2's Lane card and P3's engine-card copy.

## 7. Decisions
1. **Hub: DELETE** — decided by the user 2026-09-04 ("delete it"). §4 is the spec. P0 is go.
2. **Stale ignores: one row or two?** Not yet decided — default to keeping both. "Fix stale ignores" merging "Find" is the parent plan's
   intent, but only if `saropaLints.fixStaleIgnores` shows what it will remove and asks before
   writing. If it deletes silently, keep both rows (Find = safe preview, Fix = destructive).
   Verify in `staleIgnores/*.ts` during P1; default to keeping both if in doubt.

## 8. Acceptance (the whole plan)
- Sidebar: 3 sections, ≤14 rows, every row's section tells you what a click does; a test asserts no
  STATUS/DASHBOARDS row targets a run/toggle command.
- No setting is flipped from the sidebar; every `saropaLints.*` setting has a switch on Lints Config.
- No webview renders a setting as a button.
- No surface uses a KPI/stat component other than the chrome's `.kpi-card`.
- "Off" never appears beside live findings without the row that explains where they come from.
- Every phase has a screenshot in `bugs/` the user has seen. `dist/extension.js` is fresh.
