# Central Dashboard Consolidation — design, status, and remaining work

**Created:** 2026-06-12 · **Consolidated:** 2026-06-14 · **Status re-verified against code:** 2026-09-05
**Supersedes:** this file now also carries the diagnostics-residuals that were tracked separately in
`TODO_consolidated_dashboard_diagnostics.md` (folded in 2026-06-14; that file's completed
2026-06-12 finish report is archived under `plans/history/2026.06/2026.06.14/`).
**Question answered:** Of the items spread across the many dashboards, how many can move into one
central dashboard — business logic (stats/detail), pop-ups, expanders, links, and more.
**Method:** Three parallel code inventories catalogued every surfaced item across the Findings,
Package Vibrancy, Project Map, Code Health, Rule Packs, Command Catalog, Rule Explain, Issues tree,
TODO/HACK tree, and status bar. ~238 distinct items total.

---

## Status at a glance

- **Live-diagnostics plumbing: shipped.** The status bar, Issues sidebar tree, code lens, inline
  annotations, and the Issues-panel metadata filters / hotspot review all read live analyzer
  diagnostics, and a bundled rule-metadata catalog backfills the per-rule data live diagnostics
  lack. See **Shipped so far**.
- **The central dashboard: built, list A is folded in.** `violationsDashboardHtml.ts` now composes
  the dashboard from dedicated section-builder modules — `violations-dashboard-top.ts` (hero, KPI
  cards, toolbar, analysis progress), `violations-dashboard-tables.ts` (top-rules table, findings
  block/meta line), `violations-dashboard-panels.ts` (TODO/HACK, drift advisor, charts,
  suppressions), `violations-dashboard-shared.ts` (types/escaping) — this is Open TODO item 2,
  done (commit `b07d83fb`, "decompose Findings dashboard into per-section builder modules"), which
  also delivered essentially all of list A (item 3). Shared chrome (item 6) — keyboard-shortcuts
  overlay, full-width toggle, recent-searches popover — is also in place.
- **Not done: list B (rule-detail folded into the rule-group expander).** `ruleExplainView.ts`
  still stands alone as a separate screen; problem/how-to-fix, OWASP mapping, related rules,
  supersedes/migration, and "View in ROADMAP" have not been moved onto the dashboard's rule-group
  expander. This is now the highest-value remaining step (was item 4).
- **Not done: list C (summarize + deep-link cards).** No package-health / code-health /
  project-size / rule-packs / quality-gates-banner / disabled-rules-quick-re-enable cards exist on
  the central dashboard (item 5). **Note (2026-09-05):** the Home hub that was meant to host these
  cards was removed (commit `ea2c7a8e`). These cards need a new home — either the Findings
  dashboard itself or the sidebar row descriptions (which already carry per-dashboard summaries
  per `PLAN_ext_ui_sidebar_reset.md` §3). Evaluate whether these cards are still needed given the
  sidebar's live descriptions now surface the same top-line signals.
- **Not done: item 7** (decomposing the other oversized linked surfaces — Package Vibrancy
  report files, `projectVibrancyReportView.ts`, `commandCatalogWebviewHtml.ts`,
  `commandCatalogRegistry.ts`, `issuesTree.ts`, `dashboardChromeStyles.ts`) — unchecked, likely
  still open; not re-verified in this pass.
- **Item 1 (human render/interaction verification pass)** — status unverified in this pass; treat
  as still open unless someone confirms an F5 session covered it.

---

## Shipped so far (record — not work to redo)

From the live-diagnostics + consolidated-dashboard effort (2026-06-12):

- **Status-bar score, Issues sidebar tree, `pushModel` error boundary, headless consolidated-client
  eval test** — landed.
- **Live-diagnostics migrations** off the batch `violations.json` path:
  - `codeLensProvider.ts` — per-file count now live, refreshed on the debounced
    `onDidChangeDiagnostics` tick.
  - `inlineAnnotations.ts` — end-of-line text matches the squiggles exactly; cache invalidated on
    the same tick.
  - `issuesViewCommands.ts` — rule-type/status filters and security-hotspot review read live
    findings, enriched by the rule catalog below.
- **Rule-details catalog** (`bin/generate_rule_catalog.dart` → `extension/media/rules_catalog.json`,
  loaded by `ruleCatalog.ts`, applied by `applyRuleCatalog` in `liveDiagnosticsModel.ts`) — gives
  the live model the per-rule type / lifecycle / security-review metadata that raw diagnostics omit.
  Regenerated in the publish pipeline so it never ships stale.

Intentionally **not** migrated (correct as-is, do not "fix"):

- `configSuggestions.ts` — reads pubspec + analysis_options, never `violations.json`. N/A.
- `triageDashboardHtml.ts` — its job is to report the batch export's *freshness*; live diagnostics
  are never stale, so migrating would delete its reason to exist.
- `rulePacksWebviewProvider.ts` — uses the export *timestamp* and a disabled-rule suppressions
  snapshot; live's timestamp is always "now", which would mislabel run age.

**Closed / obsolete:** the supplementary analyzer-lints dashboard pill. The "show other analyzer
findings" / "show analyzer TODOs" toggles were deliberately removed in 13.13.0 once the Findings
Dashboard became holistic; rebuilding the pill would re-introduce the redundancy that removal fixed.

---

## Open TODO — remaining work

**Done (verified against code 2026-09-05):**

- ~~Decompose the Findings dashboard into per-section builder modules~~ — done via
  `violations-dashboard-top.ts` / `-tables.ts` / `-panels.ts` / `-shared.ts` / `-script.ts`,
  composed by `violationsDashboardHtml.ts` (commit `b07d83fb`).
- ~~Fold list A (findings-domain items) into the central dashboard as real sections~~ — hero, KPI
  cards, toolbar, analysis progress strip, top-rules table, findings meta line, TODO/HACK panel,
  drift advisor panel, charts, suppressions panel are all live in the composed dashboard.
- ~~Standardize list D shared chrome~~ — keyboard-shortcuts overlay, full-width toggle, and
  recent-searches popover are all present.

**Still open, in priority order:**

1. **Fold list B (rule-detail items) into the rule-group expander** — see inventory B (problem +
   how-to-fix, OWASP mapping, related rules, supersedes/migration, view-in-ROADMAP).
   `ruleExplainView.ts` still exists as a separate screen; this content has not moved onto the
   dashboard's rule-group expander. **Highest-value remaining step.**
2. **Add list C (summarize + deep-link cards)** — see inventory C (package health, code health,
   project size, rule packs, quality-gates banner, disabled-rules quick re-enable). None of these
   cards exist on the central dashboard yet.
3. **Consolidated webview: human render verification + tuning.** F5 in the Extension Development
   Host, verify theme / layout / elevated stylesheet, then a tuning pass. Validate click / keyboard
   interaction (DOM tree navigation the headless `consolidatedClient.test.ts` stub cannot model).
   Leave automated event-bubbling coverage out — not worth a jsdom dependency for one webview; keep
   it a launch-test item. Re-run after 1 and 2 land, since they change the DOM being verified.
4. **Decompose the kept-linked oversized surfaces (lower priority)** — Package Vibrancy
   `report-html.ts` / `report-script.ts` / `report-styles.ts` / `package-detail-html.ts`; and
   independently `projectVibrancyReportView.ts`, `commandCatalogWebviewHtml.ts`,
   `commandCatalogRegistry.ts`, `issuesTree.ts`, `dashboardChromeStyles.ts`. Not re-verified in
   this pass — status unknown.

Sequencing: **1 → 2 → 3**, with 4 in parallel as capacity allows.

---

## The key decision: fold vs. link

The dashboards span **four different data domains**: code findings, package health, project
structure/size, and config. Merging all four into one page recreates the "too many dashboards"
problem inside a single scroll. So the consolidation rule is:

- **FOLD IN** items in the *same domain* as the central dashboard (code findings) — these become
  real sections of it.
- **FOLD INTO EXPANDERS** the per-rule detail (Rule Explain) — it belongs on the rule group, not as
  a separate screen.
- **SUMMARIZE + DEEP-LINK** the other three domains — one stat card + an "Open" button each, not a
  wholesale merge. The full package/project/config screens stay as their own surfaces.
- **SHARE** the chrome (keyboard overlay, full-width toggle, recent-search popover) as common
  components every screen reuses.

## A. Fold directly into the central dashboard — same domain (findings)

These come from the existing Findings/Violations dashboard and operate on the exact data the central
dashboard already has. ~13 items:

1. **Top Rules triage table** — sortable by count/severity, with per-row **Hide** (workspace) and
   **Disable** (project config) actions. The dominant noise-reduction surface.
2. **Severity KPI cards as filters** — Errors / Warnings / Info / Files-affected / Top-rule, each
   clickable to filter.
3. **Severity segmented filter buttons** (multi-select) + **text filter** + **recent-searches
   popover**.
4. **Group-by selector** — severity / file / rule / ruleType / ruleStatus / OWASP.
5. **Severity Mix chart** (bars + donut, click-a-slice-to-filter).
6. **Active-filter chip strip** + Clear-all.
7. **Bulk select + Copy selected** (checkbox per row, select-all, copy subset as JSON).
8. **More-actions menu** — Copy JSON / Save dated report / export commands.
9. **Analysis progress strip** — streaming status + "computing" gauge dim so the grade never flashes
   a stale value mid-run.
10. **Findings meta line** — "N shown of M, capped at X, grouped by …".
11. **TODO/HACK panel** — workspace marker counts + rows (already a hero pill on the Findings view).
12. **Drift Advisor panel** — live external-issue sync rows (cross-tool, but finding-shaped).
13. **Suppressions / View-hides panel** — what is silenced (analyzer suppressions + workspace hides)
    with clear-all.

## B. Fold into the rule-group expander — per-rule detail (Rule Explain)

The central dashboard already groups by rule and expands occurrences. The Rule Explain screen's
content belongs *on that expander*, not as a separate panel. ~5 items:

14. **Problem + How-to-fix text** for the rule.
15. **OWASP mapping** (mobile/web categories).
16. **Related rules** + same-tag discovery links.
17. **Supersedes / migration** links.
18. **"View in ROADMAP"** doc link.

## C. Summarize + deep-link — other domains (one card + button each)

Do NOT merge these whole screens. Each becomes a single summary card on the central dashboard with a
button that opens the full surface. ~6 cards:

19. **Package health card** — project grade + flagged/EOL count → "Open Package Vibrancy".
20. **Code health card** — avg function score + problem count + gate pass/fail → "Open Code Health".
21. **Project size card** — total size + hot-spot count → "Open Project Map".
22. **Rule packs card** — tier + enabled/detected packs ratio → "Open Lints Config".
23. **Quality-gates banner** — surfaced inline when gates fail (high-signal, cross-domain).
24. **Disabled-rules quick re-enable** — the one genuinely-inline config action worth folding from
    Rule Packs (re-enable a rule without leaving the dashboard).

## D. Share as common chrome (not "items", but reused components)

25. Keyboard-shortcuts overlay, full-width toggle, recent-searches popover, status-bar trend delta
    (▲5/▼2 — cheap hero add). These are already partly shared; standardize them.

## Count summary

- **Fold directly (A + B):** ~13 findings-domain items + ~5 rule-detail items = **~18 items become
  real sections/expanders of the central dashboard.**
- **Summarize + link (C):** **~6 cards/banners** replace four separate full dashboards on the
  landing view (the full screens remain, one click away).
- **Shared chrome (D):** ~4 reusable components.

Net: the central dashboard absorbs the entire **findings** experience and the **rule-detail**
experience outright, and becomes the *hub* that summarizes-and-links the package/project/config
domains — rather than trying to be all four dashboards at once.

## How this answers the "break down oversized files" request (sequencing)

The consolidation decides which oversized files survive, so decompose these (they ARE the central
dashboard core or kept linked surfaces):

- **Survives as the central dashboard core → decompose into section builders:**
  `violationsDashboardHtml.ts` (+ its now-split `violations-dashboard-script.ts`),
  `violationsDashboardStyles.ts`, `violationsWideReportView.ts`. The Top-Rules / KPI / chart /
  suppressions / TODO / drift section builders become the reusable pieces the consolidated view
  composes.
- **Kept as a linked surface → decompose, lower priority:** the Package Vibrancy `report-html.ts` /
  `report-script.ts` / `report-styles.ts` / `package-detail-html.ts`.
- **Kept as linked surfaces → decompose independently of consolidation:**
  `projectVibrancyReportView.ts`, `commandCatalogWebviewHtml.ts`, `commandCatalogRegistry.ts`,
  `issuesTree.ts`, `dashboardChromeStyles.ts`.

None of the oversized files is *deleted* by consolidation (the full screens stay reachable), so the
earlier worry — "decomposing files we'll merge away" — is smaller than feared: only the per-dashboard
*landing layout* changes, not the screens themselves.
