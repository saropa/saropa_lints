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
    gateBannerStyles(),
    healthSummaryStateStyles(),
  ].join('\n');
}

/** Code Health table column widths and minor spacing on top of `.dash-table`. */
function codeHealthTableStyles(): string {
  return `
.dash-table.code-health th, .dash-table.code-health td { padding: 5px 8px; }
.dash-table.code-health .col-grade { width: 56px; text-align: center; }
.dash-table.code-health .col-score { width: 64px; text-align: right; font-variant-numeric: tabular-nums; }
.dash-table.code-health .col-name  { width: 22%; }
.dash-table.code-health .col-file  { width: 26%; }
.dash-table.code-health .col-line  { width: 80px; text-align: right; font-variant-numeric: tabular-nums; color: var(--muted); white-space: nowrap; }
.dash-table.code-health .col-usage,
.dash-table.code-health .col-coverage,
.dash-table.code-health .col-complexity { width: 80px; text-align: right; font-variant-numeric: tabular-nums; }
.dash-table.code-health .col-flags { color: var(--muted); }
.dash-table.code-health .file-link {
  cursor: pointer;
  color: var(--link);
  font-family: var(--vscode-editor-font-family, ui-monospace, monospace);
}
.dash-table.code-health .file-link:hover { text-decoration: underline; }
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
