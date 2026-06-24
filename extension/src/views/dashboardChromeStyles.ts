/**
 * Shared chrome stylesheet for the gold-standard editor-area dashboards (Findings, Lints Config,
 * Code Health). Establishes ONE visual language for the elements every dashboard exposes:
 *
 *   - `.dash-hero` — header band with title + status line + optional gauge (§4.1)
 *   - `.hero-gauge` — partial-arc score gauge (§6.3)
 *   - `.kpi-row` / `.kpi-card` / `.kpi-k` / `.kpi-v` / `.kpi-sub` (§4.2, §14.8)
 *   - `.toolbar-band` / `.toolbar-row` / `.field` / `.seg` (§4.3, §14.4)
 *   - `.btn` / `.btn.tier-1` / `.btn.tier-3` / `.btn.danger` (§8.10)
 *   - `details.more` overflow trigger + menu (§14.4)
 *   - `.chip-strip` / `.chip` (§8.5, §14.10)
 *   - `.bar-row` / `.donut` (§6.1)
 *   - `.dash-table` — sortable, sticky-header table base (§7)
 *
 * Each dashboard's own stylesheet imports this string and then adds dashboard-specific rules.
 * The chrome is bound entirely to `var(--vscode-*)` tokens so dashboards inherit the host theme.
 *
 * Naming aligns with the Findings dashboard which has been the de-facto gold-standard for the
 * longest, so its existing markup keeps working with no changes; Lints Config and Code Health
 * adopt the same names so a user moving between the three sees a single visual language.
 */

// The component-band builders moved to sibling files; imported here so the
// two composers below keep their exact join order and byte-identical output.
import {
  chromeTokens,
  chromeBaseLayout,
} from './dashboardChromeStylesTokens';
import {
  chromeHeroAndGauge,
  chromeKpiCards,
  chromeToolbarAndButtons,
  chromeChipStrip,
  chromeChartAndDonut,
  chromeTableBase,
} from './dashboardChromeStylesComponents';
import {
  chromeMicroAndMotion,
  chromeEmptyAndError,
  chromeAccessibility,
  chromePrintStyles,
  chromeReducedMotion,
} from './dashboardChromeStylesSystem';

export function getDashboardChromeStyles(): string {
  return [
    chromeTokens(),
    chromeBaseLayout(),
    chromeHeroAndGauge(),
    chromeKpiCards(),
    chromeToolbarAndButtons(),
    chromeChipStrip(),
    chromeChartAndDonut(),
    chromeTableBase(),
    chromeMicroAndMotion(),
    chromeEmptyAndError(),
    chromeAccessibility(),
    chromePrintStyles(),
    chromeReducedMotion(),
  ].join('\n');
}

/**
 * The canonical token `:root` ONLY — no component CSS. For surfaces that keep their own
 * bespoke components (the rule-violations gauge, the command-catalog tiles, the package-details
 * badges) but must draw every color/space/radius/type value from the one shared system. Lets
 * them alias their private token names (e.g. `--s-3`) to the canonical ones (`--space-3`)
 * without pulling in — and colliding with — the full chrome component stylesheet.
 */
export function getDashboardTokens(): string {
  return chromeTokens();
}
