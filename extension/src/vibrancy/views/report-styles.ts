/**
 * CSS string for the **package vibrancy report** webview. Uses `var(--vscode-*)` tokens so the
 * HTML panel tracks the active theme (light/dark/high-contrast) without bundling a static palette.
 *
 * **Layout:** header with radial gauge, filter cards, dependency table, charts, and footnotes.
 * **Gauge:** SVG stroke animation relies on CSS vars set inline on the circle so the arc can
 * animate from zero to the target without fighting attribute specificity.
 * **Tables:** zebra rows, sticky headers where supported, and responsive wrapping for long package names.
 */

import {
  reportStylesPart1,
  reportStylesPart2,
  reportStylesPart3,
  reportStylesPart4,
  reportStylesPart5,
  reportStylesPart6,
  reportStylesPart7,
  reportStylesPart8,
} from './report-styles-parts';
// PLAN_ext_ui_report_styles.md Pass 1/2: three chrome component bands are composed in here
// rather than re-declared in report-styles-parts.ts, because they were verified to be
// exact (or near-exact, see the .status-line override in reportStylesPart1) duplicates:
//   - chromeAccessibility(): provides .sr-only (used by the search-field label and the
//     table's expand-column header). Also brings .skip-link/#announcer/.focus-ring, which
//     are no-ops here since none of report-html*.ts's markup uses those classes today.
//   - chromeHeroAndGauge(): provides .status-line/.pill (this webview's hero status row and
//     rescan/freshness pills) and .dash-hero/.hero-text/.hero-text h1/.stamp (this webview's
//     hero band, now the markup report-html.ts + opportunities-html.ts emit -- see the
//     .report-header removal note in report-styles-parts.ts). Colors resolve identically
//     once chromeTokens() (loaded by every getReportStyles() consumer via getDashboardTokens())
//     is in scope. Also defines .hero-gauge/.gauge-label, which do NOT collide with this
//     file's .radial-gauge/.radial-gauge-label markup (the gauge label was deliberately
//     renamed in report-styles-parts.ts + report-html-top.ts to sidestep chrome's unscoped
//     .gauge-label rule -- see the comment there for why the two gauges stay separate rather
//     than being unified onto chrome's .hero-gauge).
//   - chromeBaseLayout(): provides the body reset (padding, font-size/line-height, global
//     box-sizing:border-box) and .full-width-toggle. This REPLACES report-styles-parts.ts'
//     own body/.full-width-toggle rules with a deliberately different (not just deduplicated)
//     visual treatment -- see the body-reset comment in reportStylesPart1 for the exact
//     before/after values and why the change is safe (known-issues-html.ts already ships it).
//   - chromeKeyframeHeroIn() / chromeReducedMotion(): PLAN_ext_ui_report_styles.md Phase 2
//     (2026-09-05). @keyframes hero-in and its reduced-motion override used to stay local in
//     reportStylesPart1 because the old chromeMicroAndMotion() bundled the keyframe with an
//     unrelated code/.mono monospace rule that would repaint opportunities-html.ts' .opp-chip
//     elements. Phase 1 split that bundle into single-concern exports; chromeKeyframeHeroIn()
//     carries ONLY the keyframe. chromeReducedMotion() is broader (also targets .kpi-card,
//     .chip, details.more .menu, .bar-row .bar-fill -- none of which this webview's markup
//     uses, so those clauses are no-ops here) but is the existing shared reduced-motion export
//     (known-issues-html.ts already composes it for the same reason), so reusing it here avoids
//     yet another bespoke local media query for the one selector (.dash-hero) this report needs.
// Appended (not prepended) so it matches the existing known-issues-html.ts /
// opportunities-html.ts convention of "report styles, then chrome" — with the duplicate
// rules now deleted from the report parts, load order no longer matters for these two
// bands, but keeping the convention consistent avoids surprising a future reader.
import { chromeHeroAndGauge } from '../../views/dashboardChromeStylesComponents';
import { chromeAccessibility, chromeKeyframeHeroIn, chromeReducedMotion } from '../../views/dashboardChromeStylesSystem';
import { chromeBaseLayout } from '../../views/dashboardChromeStylesTokens';
// Token-only palette: every color resolves through `var(--vscode-*)` so HC themes stay correct.
// Layout: max-width body with `data-full-width` escape hatch (ultrawide readability trade-off).
// Animation: gauge stroke uses inline CSS vars from TS/HTML so the arc can tween predictably.
/** CSS for the vibrancy report webview, using VS Code theme variables. */
export function getReportStyles(): string {
  return (
    reportStylesPart1() +
    reportStylesPart2() +
    reportStylesPart3() +
    reportStylesPart4() +
    reportStylesPart5() +
    reportStylesPart6() +
    reportStylesPart7() +
    reportStylesPart8() +
    chromeAccessibility() +
    chromeHeroAndGauge() +
    chromeBaseLayout() +
    chromeKeyframeHeroIn() +
    chromeReducedMotion()
  );
}
