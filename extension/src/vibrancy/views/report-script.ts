/**
 * Embeds the **report webview** client script as one HTML-safe string (no external `.js`).
 * The returned template is injected into the Vibrancy report panel; it uses `acquireVsCodeApi`
 * for `postMessage` back to the extension (open package, navigate, filter sync).
 *
 * **State:** sort column/direction, card/chart/search filters, footprint mode (`own` | `unique` | `total`),
 * preset selection, and package navigation history for back/forward.
 *
 * **DOM contract:** expects `#pkg-body`, rows with `.pkg-row`, `data-*` attributes for sort keys,
 * and companion detail rows managed by the sort routine (detail rows follow their parent package row).
 *
 * **Algorithms:** table sort is stable for package rows; category/score columns use locale-aware
 * string compare with deterministic tie-breakers so CI and user machines match.
 */

import {
  reportScriptPart1,
  reportScriptPart2,
  reportScriptPart3,
  reportScriptPart4,
  reportScriptPart5,
  reportScriptPart6,
  reportScriptPart7,
  reportScriptPart8,
  reportScriptPart9,
} from './report-script-parts';
// Client script for the vibrancy **report** panel (sort, footprint modes, presets, charts).
// Message bridge: `acquireVsCodeApi().postMessage` for navigation + filter sync with extension.
// Table model: only `.pkg-row` participates in stable sort; detail rows are reattached in-order.
// Keyboard model: vim-ish j/k row focus; `/` focuses search from non-editable targets; Esc collapses.
/** Client-side JavaScript for the report webview (sorting, filtering, search). */
export function getReportScript(): string {
  return (
    reportScriptPart1() +
    reportScriptPart2() +
    reportScriptPart3() +
    reportScriptPart4() +
    reportScriptPart5() +
    reportScriptPart6() +
    reportScriptPart7() +
    reportScriptPart8() +
    reportScriptPart9()
  );
}
