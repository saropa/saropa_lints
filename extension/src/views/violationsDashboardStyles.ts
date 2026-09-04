/**
 * CSS for the **Findings Dashboard** editor webview (`violationsDashboardHtml.ts`).
 *
 * Migrated onto the canonical dashboard chrome (`views/dashboardChromeStyles.ts`) per design
 * principle 5 ("one design system", plans/PLAN_extension_ui_redesign.md §1.5). The chrome's
 * class vocabulary (.dash-hero, .kpi-row/.kpi-card, .toolbar-band/.field/.seg/.btn,
 * .chip-strip/.chip, .chart-card/.bar-row/.donut) was originally modeled on THIS dashboard's own
 * markup, so no HTML or client-script changes were needed to adopt it — see the header comment
 * in `violationsDashboardStylesParts.ts` for exactly what stayed bespoke and why.
 *
 * Aligned to the gold-standard editor-area dashboard patterns documented in
 * `plan/guides/UX_UI_GUIDELINES.md` (§4 layout, §6 charts, §7 tables,
 * §8 affordances, §14 anti-pattern catalog). Key invariants:
 *   - All chrome bound to `var(--vscode-*)` tokens — never a hard-coded hue.
 *   - Three layered surfaces (page → panel → inset card) so structural depth
 *     is visible without heavy borders.
 *   - Three button tiers (primary / secondary / tertiary) so the user's eye
 *     lands on one action per region. See §8.10.
 *   - Hero KPI numbers ~1.8em (§4.2) — KPIs must read as the largest type
 *     after the title, otherwise the dashboard fails its glance test.
 */

import { getDashboardChromeStyles } from './dashboardChromeStyles';
import {
  vdsFindingsAndTopRulesTables,
  vdsHeroExtras,
  vdsKpiAndChartExtras,
  vdsMicroExtras,
  vdsSecondaryLists,
  vdsSectionExtras,
  vdsToolbarExtras,
} from './violationsDashboardStylesParts';
// Dashboard CSS is injected as one string; keep selectors stable with `violationsDashboardHtml.ts`.
// The chrome supplies tokens/hero/toolbar/kpi/chip/chart/table bases; the extras below layer the
// findings-specific bespoke content and the small set of intentional overrides on top, in source
// order, so a same-selector override always wins over the chrome default (see the parts file's
// header comment for which overrides are load-bearing vs. purely cosmetic convergence).
export function getViolationsDashboardStyles(): string {
  return (
    getDashboardChromeStyles() +
    vdsHeroExtras() +
    vdsToolbarExtras() +
    vdsKpiAndChartExtras() +
    vdsSectionExtras() +
    vdsFindingsAndTopRulesTables() +
    vdsSecondaryLists() +
    vdsMicroExtras()
  );
}

/** Empty-state document when `violations.json` is missing (matches dashboard tokens). */
export function getFindingsEmptyStateStyles(): string {
    return `
    body { margin: 0; padding: 24px; font-family: var(--vscode-font-family); font-size: 13px;
      color: var(--vscode-foreground); background: var(--vscode-editor-background); line-height: 1.5; }
    .empty-hero {
      max-width: 640px;
      margin: 8vh auto 0;
      padding: 28px 32px;
      border: 1px solid var(--vscode-widget-border);
      border-radius: 12px;
      background: var(--vscode-editorWidget-background);
      text-align: center;
    }
    h1 { margin: 0 0 10px; font-size: 1.45em; font-weight: 600; }
    p { margin: 0 0 14px; color: var(--vscode-descriptionForeground); }
    .btns { display: flex; flex-wrap: wrap; gap: 10px; justify-content: center; }
    button {
      padding: 8px 16px; cursor: pointer; border-radius: 999px;
      border: 1px solid var(--vscode-button-border, transparent);
      background: var(--vscode-button-secondaryBackground);
      color: var(--vscode-button-secondaryForeground);
      font: inherit; font-size: .95em;
      transition: background .12s ease, border-color .12s ease;
    }
    button:hover {
      background: var(--vscode-button-secondaryHoverBackground, var(--vscode-button-secondaryBackground));
      border-color: color-mix(in srgb, var(--vscode-focusBorder) 55%, transparent);
    }
    button:focus-visible { outline: 1px solid var(--vscode-focusBorder); outline-offset: 2px; }
    button.primary { background: var(--vscode-button-background); color: var(--vscode-button-foreground); font-weight: 600; }
    button.primary:hover { background: var(--vscode-button-hoverBackground, var(--vscode-button-background)); }
    `;
}
