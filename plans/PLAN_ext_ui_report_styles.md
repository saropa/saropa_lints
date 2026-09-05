# Plan — Migrate `report-styles-parts.ts` onto `dashboardChromeStyles`

**Created:** 2026-09-05 · **Status:** Not started
**Parent:** `PLAN_ext_ui_redesign.md` Phase 5 / Phase 7 deferred item
**Scope:** TS-only, extension side. No Dart changes.
**Model:** Sonnet for implementation. Opus only if the token/component mapping gets ambiguous.

---

## 1. Problem

`report-styles-parts.ts` (1191 lines, 8 exported functions) is the last un-migrated parallel
style system. It feeds the Package Dashboard through a single importer (`report-styles.ts`).
`violationsDashboardStylesParts.ts` and `audit-report-styles.ts` were already migrated (Phase 7).
This file duplicates ~6 component families from `dashboardChromeStyles` while also carrying ~15
component families unique to the Package Dashboard. The duplication means bug fixes to the shared
chrome (contrast, spacing, motion) must be applied twice, and the two copies drift.

## 2. Constraints

- The Package Dashboard is a **live interactive** webview (detail pane, network diagram, keyboard
  overlay, filter chips, sparklines, dependency popovers) — not a mostly-static report like
  Full Audit. Visual regressions are harder to catch.
- `report-styles.ts` is the ONLY importer. No other file imports `report-styles-parts.ts`.
- The Playwright UX harness already has a `package-dashboard` fixture plus `comparison`,
  `known-issues` fixtures. Use them for before/after verification.
- `--workers=2` is required for the Playwright suite (default worker count OOMs Chromium).
- Extension Dev Host visual verification is mandatory for this plan — tsc + Playwright alone
  is not sufficient for a live interactive dashboard.

## 3. Strategy: replace duplicates, keep uniques, shrink the file

Do NOT attempt a full rewrite. Work in three passes:

### Pass 1 — Drop the 6 duplicated families (mechanical, safe)

These class families in `report-styles-parts.ts` are confirmed duplicates of
`dashboardChromeStyles` components. For each, remove from `report-styles-parts.ts` and rely
on the chrome's version (which `report-styles.ts` must also import if it doesn't already):

| report-styles class | Chrome equivalent | Notes |
|---|---|---|
| `.sr-only` | `chromeBaseLayout` `.sr-only` | File's own comment says "duplicated" |
| `.status-line` + `.pill` family | `chromeHeroAndGauge` | Near-identical; report uses raw VS Code tokens, chrome uses aliases. Verify pill color mapping. |
| `.full-width-toggle` | `chromeBaseLayout` | Functionally identical |
| `.report-header` | `.dash-hero` | Structural twin |
| `@keyframes hero-in` + reduced-motion | `chromeMicroAndMotion` | Identical |
| `body` base (font, color, bg, max-width) | `chromeBaseLayout` | Same intent |

**Verification:** `npm run ux:gen && npm run ux:test --workers=2` — the `package-dashboard`
fixture must produce identical screenshots (or improved contrast, never worse). Then Extension
Dev Host visual check.

### Pass 2 — Adapt near-duplicates with minor token differences

| report-styles class | Chrome near-match | Adaptation needed |
|---|---|---|
| `.summary` / `.summary-card` | `.kpi-row` / `.kpi-card` | Similar purpose, different markup contract. Either adapt the Package Dashboard's markup to use `.kpi-*` or keep as-is. Evaluate visual parity. |
| `.table-toolbar` / `.toolbar-btn` | `.toolbar-band` / `.field` | Different API. May keep the report version if the markup divergence is too large. |
| `.footprint-toggle` / `.toggle-btn` | `.seg` segmented control | Comparable intent, different API. Evaluate case by case. |

For each: if the chrome component can serve with ≤10 lines of override, use it. Otherwise
keep the report version — reducing duplication is the goal, not forcing every class onto the
chrome at the cost of fragile overrides.

### Pass 3 — Reorganize what remains

After passes 1-2, `report-styles-parts.ts` should shrink from ~1191 lines to ~700-800 lines
(the unique Package Dashboard components). Reorganize remaining functions by domain:

- Gauge + grades (`.radial-gauge`, `.grade-*`)
- Detail pane + expansion (`.dash-split`, `.detail-pane`, `.expand-chevron`, `.detail-card`)
- Dependency graph (`.network-*`, `.dep-popover`)
- Badges (`.badge-*`)
- Scan progress (`.scan-progress-*`)
- Filters (`.active-filter*`, `.age-filter`, `.preset-filter`)

No functional change — just regroup for maintainability.

## 4. Files touched

| File | Change |
|---|---|
| `vibrancy/views/report-styles-parts.ts` | Remove duplicated families, reorganize remainder |
| `vibrancy/views/report-styles.ts` | Ensure it imports `getDashboardChromeStyles()` |
| `vibrancy/views/report-html.ts` | May need markup adjustments if Pass 2 swaps class names |
| `views/dashboardChromeStyles*.ts` | Read-only — do NOT modify the chrome to accommodate the Package Dashboard |

## 5. Verification checklist

- [ ] `tsc --noEmit` clean
- [ ] `npm run ux:gen && npm run ux:test --workers=2` — `package-dashboard`, `comparison`,
      `known-issues` fixtures all pass (axe-core, overflow, no new contrast regressions)
- [ ] Extension Dev Host (`python scripts/run_extension_local.py d:\src\saropa_kykto`):
  - Package Dashboard Overview tab: gauge, grade badges, summary cards, detail pane
  - Dependency popover + network graph
  - Keyboard overlay (`?` button)
  - Filter chips + toolbar
  - Sparklines
  - Dark + light theme
  - Narrow viewport (380px)
- [ ] `report-styles-parts.ts` line count reduced by ≥300 lines

## 6. Estimate

Sonnet, 1 session (~2-3 hours). The mechanical Pass 1 is fast; Pass 2 evaluation and Extension
Dev Host verification are the time sinks.

## 7. Risks

- **Visual regression in the gauge:** The Package Dashboard's `.radial-gauge` (SMIL-driven,
  72px) is distinct from the chrome's `.hero-gauge` (CSS-driven, 96px). Do NOT conflate them.
- **Pill color mapping:** The report's `.pill` uses raw `--vscode-*` tokens; the chrome uses
  `--status-*` aliases. Verify the alias chain resolves to the same colors before swapping.
- **Detail pane interaction:** The master-detail split (`.dash-split`) is unique to this
  dashboard and is the most interaction-heavy surface. Test click-to-expand, popover
  positioning, and keyboard navigation after any change to surrounding layout CSS.
