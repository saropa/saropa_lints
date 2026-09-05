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

---

## Audit finding (2026-09-05) — target not achievable as written

Two independent implementation passes landed only **-46 lines** (1191 -> 1145) against this
plan's -300..-800 target, and both stopped for the same reason, verified against the code
rather than assumed:

`dashboardChromeStyles`' exported functions **bundle unrelated rules**, so they cannot be
adopted piecemeal:
- `chromeMicroAndMotion()` carries `@keyframes hero-in` **and** `code, .mono { font-family: monospace }`,
  which would repaint the Upgrades tab's `.opp-chip` elements.
- `chromeBaseLayout()` carries `.full-width-toggle` **and** a full `body` reset.

What did land: `.sr-only` -> `chromeAccessibility()`; `.status-line`/`.pill` -> `chromeHeroAndGauge()`;
`.report-header` -> `.dash-hero` across `report-html.ts` and `opportunities-html.ts`; `body` +
`.full-width-toggle` -> `chromeBaseLayout()` as a deliberate, described visual change. Also renamed
`.gauge-label` -> `.radial-gauge-label` to avoid a silent collision with chrome's unscoped 96px
gauge rule.

Kept deliberately (documented, not forgotten): `@keyframes hero-in` + its reduced-motion override,
and the `.summary` / `.table-toolbar` / `.footprint-toggle` families, whose chrome equivalents
(`.kpi-row` / `.toolbar-band` / `.seg`) need markup and script rewrites far beyond a small override.

**Prerequisite for the original target:** split `dashboardChromeStyles` into single-concern exports.
Until that exists, the remaining duplication is not removable without unaudited visual side effects.
Treat this plan as closed-as-scoped; do not carry the -700 figure forward as outstanding work.

### Final outcome (2026-09-05) — CLOSED, target not achievable

Phase 1 (split `dashboardChromeStyles` into single-concern exports) is DONE and verified
byte-identical: the bundled functions now compose fine-grained pieces in original order, pinned by
`extension/src/test/views/dashboardChromeStylesSeams.test.ts` (7 tests).

Phase 2 (adopt the chrome layer) is DONE as far as it can safely go:
- `@keyframes hero-in` + reduced-motion -> `chromeKeyframeHeroIn()` / `chromeReducedMotion()`. This
  was the one family blocked purely by the old bundling; the seam split unblocked it as predicted.
- `chromeSrOnlyLegacyDuplicate()` confirmed a byte-identical duplicate of `chromeAccessibility()`'s
  `.sr-only` and deleted, after verifying both consumers of `chromeBaseLayout()` always pair it with
  `chromeAccessibility()`. The seam test now pins `.sr-only` as defined exactly once.

Kept local, with reasons documented in the code itself (structural mismatches, not laziness):
- `.summary`/`.summary-card` vs `.kpi-row`/`.kpi-card` — inverted layout; 9 package-grade colors with
  no analog in chrome's 4 lint-severity categories. Extending chrome for one caller is shared-infra work.
- `.table-toolbar`/`.toolbar-btn` vs `.toolbar-band`/`.field`/`.btn` — chrome's band is
  `position: sticky`, an unrequested UX change on the most interaction-heavy surface.
- `.footprint-toggle`/`.toggle-btn` vs `.seg` — different INTERACTION models: `.seg` is
  `aria-pressed` additive multi-select, this is an `.active`-class single-select radio group.
  Migrating means rewriting `setFootprintMode()` and the ARIA model to save ~35 lines of CSS.

**Final line count: 1202 (HEAD was 1191, +11).** Real CSS was deduplicated, but the project's
mandatory WHY-comments documenting each kept-not-migrated decision more than offset it. This is the
honest number.

**Do not carry the -300..-800 target forward.** It assumed the duplicated families were
straightforward copies. They are not: the three remaining ones differ in layout semantics, domain
vocabulary, or ARIA interaction model. Any further reduction requires deliberate UX decisions
(sticky toolbar? shared multi-select semantics? a shared grade-color vocabulary?), not a CSS sweep.
