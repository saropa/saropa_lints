# Central Dashboard Consolidation — what folds into one dashboard

**Created:** 2026-06-12
**Question answered:** Of the items spread across the many dashboards, how many can move into one
central dashboard — business logic (stats/detail), pop-ups, expanders, links, and more.
**Method:** Three parallel code inventories catalogued every surfaced item across the Findings,
Package Vibrancy, Project Map, Code Health, Rule Packs, Command Catalog, Rule Explain, Issues tree,
TODO/HACK tree, and status bar. ~238 distinct items total.

## The central dashboard today

The "Open Dashboard" (consolidated view) currently shows only: a grade gauge, rule groups (one row
per rule with severity counts), and lazy-expand occurrence lists that jump to source. Minimal.

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
dashboard already has. ~20 items:

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

- **Fold directly (A + B):** ~18 findings-domain items + ~5 rule-detail items = **~23 items become
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
*landing layout* changes, not the screens themselves. Decomposing the Findings dashboard into section
builders is the highest-value next step because those builders are exactly what the central dashboard
will compose.

## Recommended next step

Decompose the Findings dashboard (`violationsDashboardHtml.ts`) into per-section builder modules
(hero, KPI cards, toolbar, top-rules table, charts, TODO/HACK, drift, suppressions), because those
modules are the building blocks list A above needs. The client-script extraction is already done
(`violations-dashboard-script.ts`). That work is reusable whether or not the full consolidation ships.
