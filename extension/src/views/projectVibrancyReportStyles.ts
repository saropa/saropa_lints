/**
 * CSS for the **Code Health Dashboard** editor webview (project vibrancy JSON).
 *
 * The shared chrome stylesheet (`views/dashboardChromeStyles.ts`) provides the header band,
 * KPI cards, toolbar band, button tiers, segmented control, chip strip, gauge, and sortable
 * table base — so this surface looks identical to the Findings and Lints Config dashboards.
 * Only Code Health-specific rules live here:
 *
 *   - `.code-health-table` — column widths and the grade pill column
 *   - `.grade-badge` — letter-grade pill (A through F → semantic colors)
 *   - `.flag-pill` — small pill for each function flag (unused, uncovered, …)
 *   - `.gate-warn` — top-of-page banner when quality gates fail
 */
import { getDashboardChromeStyles } from './dashboardChromeStyles';

export function getProjectVibrancyReportStyles(): string {
  return [
    getDashboardChromeStyles(),
    codeHealthTableStyles(),
    gradeAndFlagPillStyles(),
    rowExpanderAndDetailStyles(),
    gateBannerStyles(),
    healthSummaryStateStyles(),
    reportFileRowStyles(),
  ].join('\n');
}

/**
 * Score-cell expander chevron + the expanded "why" detail row. The chevron
 * lives inside the score cell so the score column itself is the affordance —
 * users instinctively click the score to ask "why is this low?". The detail
 * panel spans every column (colspan=9) and lists each flag with its label,
 * evidence (e.g. CC 36, 0% tests) and the threshold rule that fired, so the
 * reader does not have to triangulate four numeric columns to reconstruct WHY.
 */
function rowExpanderAndDetailStyles(): string {
  return `
.dash-table.code-health .col-score { width: 92px; text-align: left; white-space: nowrap; }
.row-expander {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  width: 18px;
  height: 18px;
  margin-right: 4px;
  padding: 0;
  border: 0;
  background: transparent;
  color: var(--muted);
  cursor: pointer;
  vertical-align: middle;
  border-radius: 3px;
}
.row-expander:hover { background: var(--surface-2); color: var(--vscode-foreground); }
.row-expander:focus-visible { outline: 1px solid var(--accent-info); outline-offset: 1px; }
.row-expander .chev {
  display: inline-block;
  width: 0;
  height: 0;
  border-top: 4px solid transparent;
  border-bottom: 4px solid transparent;
  border-left: 5px solid currentColor;
  transition: transform 80ms ease-out;
}
.row-expander.open .chev { transform: rotate(90deg); }

.pv-detail-row > td {
  padding: 0 !important;
  background: var(--surface-2);
  border-top: 1px solid var(--border);
}
.pv-detail-panel {
  padding: 10px 14px 12px 32px;
  font-size: 0.92em;
}
.pv-detail-heading {
  margin: 0 0 6px 0;
  font-size: 0.85em;
  font-weight: 600;
  color: var(--muted);
  text-transform: uppercase;
  letter-spacing: 0.5px;
}
.pv-detail-list { margin: 0; padding: 0; list-style: none; }
.pv-detail-item {
  display: grid;
  grid-template-columns: max-content max-content 1fr max-content;
  gap: 8px 12px;
  align-items: baseline;
  padding: 4px 0;
  border-top: 1px dashed var(--border);
}
/* Suppress button: small, low-key chip. Visually subordinate to the rule
   text — the user reads the rule first, then decides to suppress. Right-
   aligned in the grid (max-content column) so it stays out of the rule's
   way regardless of rule length. */
.pv-suppress-btn {
  justify-self: end;
  border: 1px solid var(--border);
  background: transparent;
  color: var(--muted);
  font-size: 0.82em;
  padding: 2px 8px;
  border-radius: 3px;
  cursor: pointer;
  white-space: nowrap;
}
.pv-suppress-btn:hover {
  background: var(--surface-2);
  color: var(--vscode-foreground);
  border-color: var(--accent-warning);
}
.pv-suppress-btn:focus-visible {
  outline: 1px solid var(--accent-info);
  outline-offset: 1px;
}
.pv-detail-item:first-child { border-top: 0; }
.pv-detail-label {
  font-weight: 600;
  color: var(--accent-warning);
  text-transform: lowercase;
}
.pv-detail-item.unused .pv-detail-label,
.pv-detail-item.uncovered .pv-detail-label { color: var(--accent-error); }
.pv-detail-item.test_drift .pv-detail-label { color: var(--accent-info); }
.pv-detail-evidence {
  font-family: var(--vscode-editor-font-family, ui-monospace, monospace);
  font-size: 0.92em;
  color: var(--vscode-foreground);
}
.pv-detail-rule {
  color: var(--muted);
}
.pv-detail-empty {
  margin: 0;
  color: var(--muted);
  font-style: italic;
}
.flag-evidence {
  opacity: 0.78;
  font-weight: 400;
  margin-left: 2px;
}
`;
}

/**
 * Saved-report-file action row + the new toolbar inline-checkbox + load-more
 * button styles. Grouped here so the report-view-specific chrome (anything
 * that isn't the score pill, flag pill, or table grid) lives in one place.
 */
function reportFileRowStyles(): string {
  return `
.report-file {
  display: flex;
  align-items: center;
  gap: 8px;
  margin: 0 0 12px 0;
  padding: 8px 12px;
  border: 1px solid var(--border);
  border-radius: 6px;
  background: var(--surface-2);
  font-size: 0.9em;
}
.report-file .rf-label { color: var(--muted); flex: 0 0 auto; }
.report-file .rf-path {
  flex: 1 1 auto;
  min-width: 0;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
  font-family: var(--vscode-editor-font-family, ui-monospace, monospace);
  color: var(--link);
  cursor: pointer;
}
.report-file .rf-path:hover { text-decoration: underline; }
.report-file .btn { flex: 0 0 auto; }
/* Inline checkbox label next to the search field — "Hide boilerplate methods" */
.check-inline {
  display: inline-flex;
  align-items: center;
  gap: 6px;
  cursor: pointer;
  user-select: none;
  font-size: 0.9em;
  color: var(--vscode-foreground);
}
.check-inline input[type="checkbox"] { cursor: pointer; }
/* Render-window "Show next N" button, shown when the filtered list is longer
   than the current visible window (default 500 rows). */
.load-more {
  display: flex;
  justify-content: center;
  padding: 10px 0;
}
.load-more .btn { min-width: 220px; }
/* Score-threshold input — a compact numeric field with a 'Score ≤' prefix.
   Narrow on purpose so it doesn't compete with the search field for space. */
.score-threshold {
  display: inline-flex;
  align-items: center;
  gap: 4px;
  padding: 2px 6px;
  border: 1px solid var(--border, var(--vscode-input-border, #8884));
  border-radius: 4px;
  background: var(--vscode-input-background, transparent);
}
.score-threshold .prefix {
  font-size: 0.85em;
  color: var(--muted, var(--vscode-descriptionForeground));
  white-space: nowrap;
}
.score-threshold input[type="number"] {
  width: 48px;
  border: none;
  background: transparent;
  color: var(--vscode-input-foreground);
  font: inherit;
  text-align: right;
  padding: 0;
}
.score-threshold input[type="number"]:focus { outline: none; }
.score-threshold input[type="number"]::-webkit-inner-spin-button,
.score-threshold input[type="number"]::-webkit-outer-spin-button {
  -webkit-appearance: none; appearance: none; margin: 0;
}
.sr-only-label {
  position: absolute; width: 1px; height: 1px;
  padding: 0; margin: -1px; overflow: hidden;
  clip: rect(0, 0, 0, 0); white-space: nowrap; border: 0;
}
/* Multi-select KPI cards: an active card carries a thicker outline + brighter
   foreground so several active cards read as a group, not as a momentary
   selection. */
.kpi-card.active {
  outline: 2px solid var(--vscode-focusBorder, var(--accent-info, #3794ff));
  outline-offset: 1px;
}
`;
}

/**
 * Code Health table column widths and minor spacing on top of `.dash-table`.
 *
 * Score is rendered as a colored *pill* (red→amber→green by value) so the cell
 * carries both the value and the bucketing at a glance — no separate grade
 * column needed. Sort arrows are hidden by default and revealed only on the
 * column currently being sorted on (the old design painted an up-arrow on every
 * header forever, which read as decoration rather than state).
 */
function codeHealthTableStyles(): string {
  return `
.dash-table.code-health th, .dash-table.code-health td { padding: 5px 8px; }
.dash-table.code-health .col-score { width: 62px; text-align: center; }
.dash-table.code-health .col-name  { width: 22%; }
.dash-table.code-health .col-file  { width: 26%; }
.dash-table.code-health .col-line  { width: 80px; text-align: right; font-variant-numeric: tabular-nums; color: var(--muted); white-space: nowrap; }
.dash-table.code-health .col-usage,
.dash-table.code-health .col-coverage,
.dash-table.code-health .col-complexity { width: 80px; text-align: right; font-variant-numeric: tabular-nums; }
.dash-table.code-health .col-changed { width: 80px; text-align: right; font-variant-numeric: tabular-nums; color: var(--muted); white-space: nowrap; }
.dash-table.code-health .col-flags { color: var(--muted); }
.dash-table.code-health .fn-link {
  cursor: pointer;
  color: var(--link);
  font-family: var(--vscode-editor-font-family, ui-monospace, monospace);
}
.dash-table.code-health .fn-link:hover { text-decoration: underline; }
.dash-table.code-health .file-link {
  cursor: pointer;
  color: var(--link);
  font-family: var(--vscode-editor-font-family, ui-monospace, monospace);
  display: inline-flex;
  min-width: 0;
  max-width: 100%;
}
.dash-table.code-health .file-link:hover { text-decoration: underline; }
/* Path truncation collapses the DIRECTORY and keeps the basename whole, so the
   filename is never the part that gets cropped (end-ellipsis on the whole
   string used to eat the filename, leaving an unreadable stub like
   '…/drift_midd…'). Dir shrinks first (flex:0 1), basename never shrinks
   (flex:0 0). */
.dash-table.code-health .path-dir { overflow: hidden; text-overflow: ellipsis; white-space: nowrap; flex: 0 1 auto; min-width: 0; }
.dash-table.code-health .path-base { white-space: nowrap; flex: 0 0 auto; }
/* Score pill: background is set inline per-row from hslForScore (red→amber→
   green). Black text wins contrast on every hue in the ramp; the previous
   yellow-on-yellow pill was unreadable. Tabular numerals so a column of pills
   visually aligns regardless of digit count. */
.dash-table.code-health .score-pill {
  display: inline-block;
  min-width: 30px;
  padding: 2px 8px;
  border-radius: 999px;
  font-size: 0.82em;
  font-weight: 700;
  font-variant-numeric: tabular-nums;
  text-align: center;
  line-height: 1.2;
}
/* Sort-arrow visibility: render the chevron ONLY on the actively-sorted column,
   and rotate by sort direction. Idle headers show no decoration. */
.dash-table.code-health th.sortable .arrow {
  display: inline-block;
  width: 0;
  height: 0;
  margin-left: 6px;
  vertical-align: middle;
  visibility: hidden;
  border-left: 4px solid transparent;
  border-right: 4px solid transparent;
  border-bottom: 5px solid currentColor;
}
.dash-table.code-health th.sortable[aria-sort="ascending"] .arrow,
.dash-table.code-health th.sortable[aria-sort="descending"] .arrow {
  visibility: visible;
}
.dash-table.code-health th.sortable[aria-sort="descending"] .arrow { transform: rotate(180deg); }
`;
}

/** Letter-grade pill (A–F → semantic backgrounds) and per-flag pills. */
function gradeAndFlagPillStyles(): string {
  return `
.grade-badge {
  display: inline-block;
  min-width: 22px;
  text-align: center;
  padding: 2px 8px;
  border-radius: 999px;
  font-size: 0.78em;
  font-weight: 700;
  letter-spacing: 0.3px;
}
.grade-badge.grade-A { background: var(--status-good); color: var(--vscode-editor-background); }
.grade-badge.grade-B { background: var(--accent-info); color: var(--vscode-editor-background); }
.grade-badge.grade-C, .grade-badge.grade-D, .grade-badge.grade-E {
  background: var(--accent-warning);
  color: var(--vscode-editor-background);
}
.grade-badge.grade-F { background: var(--accent-error); color: var(--vscode-editor-background); }
.grade-badge.grade-X { background: var(--vscode-badge-background); color: var(--vscode-badge-foreground); }
.flag-pills { display: inline-flex; flex-wrap: wrap; gap: 4px; }
.flag-pill {
  display: inline-block;
  padding: 1px 6px;
  border-radius: 999px;
  font-size: 0.78em;
  background: color-mix(in srgb, var(--accent-warning) 20%, transparent);
  color: var(--accent-warning);
  white-space: nowrap;
}
.flag-pill.unused, .flag-pill.uncovered { background: color-mix(in srgb, var(--accent-error) 20%, transparent); color: var(--accent-error); }
.flag-pill.stub_tested, .flag-pill.suspicious_coverage { background: color-mix(in srgb, var(--accent-warning) 20%, transparent); color: var(--accent-warning); }
.flag-pill.test_drift { background: color-mix(in srgb, var(--accent-info) 20%, transparent); color: var(--accent-info); }
`;
}

/** Top-of-page banner shown when project vibrancy quality gates fail. */
function gateBannerStyles(): string {
  return `
.gate-warn {
  display: flex; align-items: center; gap: 10px;
  margin: 0 0 12px 0;
  padding: 8px 12px;
  border-radius: 6px;
  border-inline-start: 3px solid var(--vscode-inputValidation-errorBorder);
  background: var(--vscode-inputValidation-errorBackground);
  color: var(--vscode-inputValidation-errorForeground);
  font-size: 0.92em;
}
.gate-warn .glyph { font-size: 1.1em; }
.gate-warn .gate-msg { flex: 1 1 auto; }
.gate-warn .btn { flex: 0 0 auto; }
`;
}

/**
 * Empty / all-clear states for the KPI strip and the filtered table.
 *
 * §14.11 — when every KPI category is zero we collapse the row to a single
 * muted line; without dedicated styling that line would inherit body weight
 * and read as content rather than as an "all clear" acknowledgement.
 *
 * §8.16 — the empty-state CTA shown when filters reduce the table to zero
 * rows shares the visual vocabulary of empty states elsewhere (centered
 * text + tier-1 button) so users do not learn a new pattern per surface.
 */
function healthSummaryStateStyles(): string {
  return `
.kpi-allclear {
  margin: 0 0 12px 0;
  padding: 10px 14px;
  font-size: 0.92em;
  color: var(--muted);
  border: 1px dashed var(--border);
  border-radius: 6px;
  background: transparent;
}
.empty-cta {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 10px;
  padding: 24px 16px;
  margin: 12px 0;
  border: 1px dashed var(--border);
  border-radius: 6px;
  background: var(--surface-2);
}
.empty-cta .empty-msg {
  margin: 0;
  color: var(--muted);
  font-size: 0.95em;
}
`;
}
