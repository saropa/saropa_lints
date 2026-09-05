# Extension UX — fact sheet (no proposals)

**Date:** 2026-09-04 · **Scope:** `extension/src` at working tree; git history for the hub.
**Source reports** (full tables, every claim cited to file:line):
`D:\.claude_temp\claude\d--src-saropa-lints\20226a76-b23a-44fb-b78a-9ee271916957\scratchpad\audit_suggestions.md`,
`…\audit_dashboards.md`, `…\audit_hub_postmortem.md`.

This file states what IS. It contains no recommendation. Direction is the owner's call.

---

## 1. Suggestion surfacing — 34 "the user should do X" signals

### 1.1 By how the signal actually reaches the user

| Reality | Count | Signals |
|---|---|---|
| **Never computed proactively** — code exists, runs only when the user asks | 5 | Legacy config keys need migration (`migrateConfigKeys` dry-run exists, no caller; sidebar row is unconditional and looks the same whether needed or not) · Stale `// ignore:` comments (CLI only on demand) · Plugin silent / no report (`verifyPluginLiveness` runs only after Enable or a manual command) · Tier-too-low / baseline-missing / related-rule (`suggestionCounts.ts` — **zero non-test importers**) · Daily summary trouble list (`dailySummary.ts` — public API only, no in-extension UI) |
| **Computed, but the row lives in the Status view, which is hidden when `hasViolations` is false** (`package.json:69`; Disable forces it false, `extension.ts:1476,1634`) | 5 | Lint integration: Off (the fix row disappears exactly when integration is off and diagnostics stop) · Engines: 0 running (hidden precisely when no engine produces diagnostics) · Hotspots to review · Score regression · Analyzer plugin state via Engines row |
| **Toast only** — auto-dismisses, no persistent surface anywhere after it closes | 9 | Setup prompt (dep missing; fires on every activation, no memento) · Plugin divergence Restore/Keep · Rule packs available · New saropa_lints on pub.dev · Install Drift Advisor · Install Log Capture · Crash-covered rule · Score crossed a band · Memory shed disabled |
| **Visible only inside a dashboard the user must already have open** | 3 | Drift Advisor offline (Findings pill) · TODO/HACK scanner off (Findings promo pill) · Package needles (Package Dashboard row description — only after a scan) |
| **Status-bar tooltip only** (no click target for the fact) | 2 | N package updates available (main item tooltip; click opens Findings, not Packages) · Score is partial |
| Persistent, actionable, always visible | 4 | Set Up Project (banner row) · Scan-on-save state (own status-bar item — **no click command**) · Violation CodeLens · Memory/system-health status-bar item |
| Informational / celebration | 6 | You fixed N · No errors · Tier changed · First run · Analysis finished · Vibrancy cached cue (10 s) |

### 1.2 Structural facts

- **318** `show*Message` call sites; **42** carry action buttons; **17** modal. Hardcoded non-`l10n` English at `config/migrateConfig.ts:177-207`, all of `pluginLiveness.ts`, `extension.ts:2676-2753` (tier change, first run), `extension.ts:349-352,406-409`.
- **5** status-bar items. Main item click → Findings in every state, including "Saropa Lints: Off" (`extension.ts:1241`) — it does not lead to Enable.
- `needsBanner` is set true for "dep present, integration off" (`sectionedSidebar.ts:793`) but `buildBannerItems` returns `[]` for that case (`:212-225`) → Banner view shows, empty.
- Activation with `lspServer.enabled=true` (default) calls `disablePluginsIntegration` every start (`extension.ts:1315-1319`); the divergence prompt classifies that as legitimate and stays silent (`pluginDivergencePrompt.ts:55-58`).
- **7** tree providers are constructed and never registered as views (`extension.ts:577-589`; `package.json` contributes 4). Their guidance nodes (hotspot review, "Enable workspace scan…", drift placeholder, dashboard shortcuts) render nowhere.
- `saropaLints.upgradePackNudge.enabled` is the shared opt-out for three unrelated nudges (rule packs, Log Capture install, Drift Advisor install).
- Two nudge gates are in-memory only and reset on window reload (`memoryPressureWatcher.ts:233`, `processMonitor.ts:107`).
- Activation runs **36** steps that can speak to the user; the first 4 s can produce: scan-on-save SB, setup toast, divergence toast, rule-pack toast (+4 s), Log Capture toast (+5 s), upgrade toast, vibrancy cue, post-analysis toast if pubspec.lock changed.

---

## 2. Dashboard complexity — 15 editor webviews

### 2.1 Totals

| Measure | Value |
|---|---|
| Distinct `createWebviewPanel` sites | **15** (+1 browser-opened HTML export; 1 unregistered `WebviewViewProvider` class; 1 HTML builder with 0 importers) |
| Tabs | **15** — Rules & Tiers 7, Package Dashboard 6 (4 are deep-link cards that open another panel), Project Map 2; the other 12 webviews have none |
| Static interactive controls in builders | **299**; rendered is higher (+54 Package Settings fields, +29 Rules & Tiers setting rows, per-row templates) |
| Host-handled message types | **124** (+15 `command` sub-ids, +8 optimizer sub-ops) |
| Host TS / client JS / CSS | **21,197 / 7,088 / 7,201** lines (+1,752 shared chrome) |
| Reachable from the sidebar | 10 of 15 |

### 2.2 The three that carry two-thirds of the surface

| Dashboard | Tabs | Controls (static) | Message types | Host + client + CSS lines | Refresh model |
|---|---|---|---|---|---|
| Rules & Tiers | 7 | 76 (+29 setting rows rendered) | 19 (+15 +8 sub-ids) | 2,654 + 995 + 824 | **Full document reload** on every refresh; 0 host→client postMessage |
| Package Dashboard | 6 | 72 (+54 settings fields rendered) | 20 | 4,230 + 2,565 + 2,109 | Full reload at scan boundaries; incremental progress |
| Findings | 0 | 52 | 24 | 2,424 + 968 + 840 | **Full document reload on every debounced diagnostics change** (`violationsWideReportView.ts:473-486 → :335`) |

Health Panel also full-reloads on every poll tick (`healthPanel.ts:141`).

### 2.3 The same write path exists in two places

| What is written | Place 1 | Place 2 |
|---|---|---|
| `analyzer.exclude` in analysis_options.yaml (5 ops) | Analysis Optimizer standalone panel | Rules & Tiers → Config file (embedded copy of the same markup, 12 controls rendered twice) |
| Disabled rules | Rules & Tiers → Overrides | Findings row button `Disable` |
| Baseline | Rules & Tiers → Config file `createBaseline` | Full Audit `saveBaseline` (a different baseline file) |
| `todosAndHacks.workspaceScanEnabled` | Findings `enableTodosScan` handler | Findings `toggleSupplementary` handler (two handlers, one key, same page) |
| Rule packs on/off | Rules & Tiers → Rule packs | Rules & Tiers → SDK rollout |

### 2.4 Settings coverage (105 `saropaLints.*` manifest keys)

- Rules & Tiers Automation/Extension grid: **29** — includes all 7 `systemHealth.*`, `debug.enabled`, 3 `lspServer.*`, which the **Health Panel itself does not expose** (it only reads `debug.enabled`).
- Package Dashboard Settings tab: 54. Dedicated controls: `enabled`, `tier`.
- **20** keys with no in-dashboard control: `projectVibrancy.*` 7 (Code Health opens the VS Code Settings UI instead), `todosAndHacks.*` 8, `driftAdvisor.*` 5 (Findings covers 2 of these via buttons).

### 2.5 Not reachable from the sidebar

Related Rule Telemetry (command only) · Known Issues, Upgrade Opportunities (Package Dashboard tab or command) · Analysis Optimizer standalone (Rules & Tiers button or command) · Rule Explain (only via an unregistered tree's command).

---

## 3. Home hub post-mortem — what "a child's interface" was, observably

Lifetime as shipped code: **5 h 46 min** (`57ab8774` 08:52 → `ea2c7a8e` 14:38). First human look ~13:00, after discovering `dist/extension.js` was a day stale. The trigger screenshot `bugs/WIP home hub.png` was never committed.

### 3.1 Observable failure properties (each verified in source at `ea2c7a8e^`)

| # | Property |
|---|---|
| 1 | **Zero unique facts.** Every tile, card, and button had a pre-existing home in the sidebar, status bar, or a dashboard hero (duplication table in the source report, §d). |
| 2 | Listed as the **first row of the sidebar section it duplicated** — a row to open a page of buttons that open the rows beneath it. |
| 3 | **Status-bar click was retargeted to it** (`57ab8774`), making it the most-reached surface — unverified in a live host. |
| 4 | First-time user saw KPI tiles: **"Run analysis" / 0 / 2/3 running / Not scanned / Not scanned / Not scanned**. A verb sat in a number slot as inert text. The "Project size" tile never showed a size in any state. |
| 5 | KPI tiles **not clickable** — "2/3 running" had no path to the engine that was down. |
| 6 | **4 of 6 cards were empty-state sentences** for a first-time user; Full Audit card was static text in every state. Card metrics truncated to 3 by a `limit`, dropping computed values. |
| 7 | **17 buttons of one visual class** mixing navigate / run / toggle-setting; settings rendered as buttons with the value in the label ("Lint integration: Off"). |
| 8 | "Lint integration: Off" button rendered **beside 324 live findings** (two data sources on one page: cached `violations.json` vs live diagnostics). |
| 9 | **Shared chrome stylesheet and `:root` tokens never included** — every `var()` fell to a hardcoded px fallback; hero and all buttons rendered with webview defaults; bespoke `.metric` component instead of the canonical `.kpi-card`. |
| 10 | Up to **28 nested bordered rounded boxes** (12px / 8px radii) and **9 `<h2>`** under one default `<h1>`. |
| 11 | No good/healthy tone — healthy and unknown values looked identical (tone only as a 3px left border). |
| 12 | Rendered once per open; no refresh, loading, or error state. Code Health tile reset to "Not scanned" on every VS Code restart. |
| 13 | Palette title and Command Catalog description still described the June two-pane design. |
| 14 | No icons, emoji, gradients, or illustrations — the verdict is attributable to items 1–12, not decoration. |

### 3.2 Recorded owner feedback (verbatim, from repo docs)

- Brief: "nothing should be too many clicks away, nothing should be hidden in config files, settings, or CLI commands."
- "Where is the 'home hub'??? … user WILL NOT FIND IT. STOP BURYING CRITICAL FEATURES."
- "you have links in the sidebar and on the web that may change setting, open screen, run something... but user's have to guess! you have invented a SHIT new style guide. nothing is logically laid out. … what problem did you think you solved?"
- "stop obscuring features - use concise subtitle description or (i) tooltips. be extensive"
- Deletion commit: "duplicated the sidebar and each dashboard's own settings without adding anything a dashboard couldn't already show."

### 3.3 Process facts common to every phase in `PLAN_extension_ui_redesign.md`

Every phase's finish report (0–7) records "no Extension Development Host verification." Correctness evidence in every case was `tsc` + scoped mocha, later + a Playwright static render. No phase produced the screenshot the plan's own §3 header requires.

---

## 4. Not in this file

No design, no priorities, no recommendation. The row-collapse plan (`PLAN_sidebar_row_collapse.md`) is on hold pending the owner's direction from these facts.
