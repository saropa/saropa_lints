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
    reportStylesPart8()
  );
}
