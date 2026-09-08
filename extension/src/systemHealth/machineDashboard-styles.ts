import { getDashboardChromeStyles } from '../views/dashboardChromeStyles';

// Extends the shared dashboard chrome (same as healthPanel-styles.ts) so this
// panel matches the rest of the extension's webviews without duplicating
// base layout/typography rules.
export function getMachineDashboardStyles(): string {
  return `${getDashboardChromeStyles()}
.summary-bar {
  display: flex;
  gap: 16px;
  align-items: center;
  padding: 12px 16px;
  background: var(--vscode-editorWidget-background);
  border-bottom: 1px solid var(--vscode-widget-border, #e5e7eb);
  flex-wrap: wrap;
}
.summary-bar.summary-warning { border-left: 4px solid var(--vscode-editorWarning-foreground, #cca700); }
.summary-bar.summary-critical { border-left: 4px solid var(--vscode-editorError-foreground, #f14c4c); }
.summary-stat { font-size: 13px; color: var(--vscode-foreground); }
.summary-stat strong { font-weight: 700; }
.btn-refresh {
  padding: 3px 10px;
  border: 1px solid var(--vscode-widget-border, #e5e7eb);
  border-radius: 4px;
  font-size: 12px;
  cursor: pointer;
  background: var(--vscode-button-secondaryBackground, transparent);
  color: var(--vscode-foreground);
}
.btn-refresh:hover { background: var(--vscode-list-hoverBackground, rgba(90,93,110,.1)); }
.section-title {
  font-size: 13px;
  font-weight: 600;
  margin: 16px 16px 8px;
  color: var(--vscode-foreground);
}
.recommendations { padding-bottom: 4px; }
.recommendations-empty {
  padding: 16px;
  color: var(--vscode-descriptionForeground, #94a3b8);
  font-size: 13px;
}
.rec-card {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 12px;
  margin: 0 16px 8px;
  padding: 8px 12px;
  border-radius: 6px;
  border-left: 4px solid var(--vscode-editorInfo-foreground, #3794ff);
  background: var(--vscode-editorWidget-background);
  font-size: 13px;
  /* Wrap action button below text at narrow viewports instead of overflowing. */
  flex-wrap: wrap;
}
.rec-card.rec-warning { border-left-color: var(--vscode-editorWarning-foreground, #cca700); }
.rec-card.rec-critical { border-left-color: var(--vscode-editorError-foreground, #f14c4c); }
.rec-text { color: var(--vscode-foreground); flex: 1; }
.btn-action {
  padding: 3px 10px;
  border: none;
  border-radius: 4px;
  font-size: 12px;
  cursor: pointer;
  white-space: nowrap;
  background: var(--vscode-button-background);
  color: var(--vscode-button-foreground);
}
.btn-action:hover { background: var(--vscode-button-hoverBackground); }
.btn-action:disabled { opacity: 0.5; cursor: default; }
.groups { padding: 4px 0 16px; }
.group-card {
  margin: 0 16px 10px;
  border: 1px solid var(--vscode-widget-border, #e5e7eb);
  border-radius: 6px;
  overflow: hidden;
}
.group-card summary {
  display: flex;
  align-items: center;
  gap: 12px;
  padding: 8px 12px;
  cursor: pointer;
  background: var(--vscode-editorWidget-background);
  list-style: none;
  /* Allow label+count+rss+badge to wrap at narrow widths. */
  flex-wrap: wrap;
}
.group-card summary::-webkit-details-marker { display: none; }
.group-label { font-weight: 600; font-size: 13px; color: var(--vscode-foreground); }
.group-count { font-size: 12px; color: var(--vscode-descriptionForeground, #94a3b8); }
.group-rss { font-size: 12px; font-weight: 700; color: var(--vscode-foreground); margin-left: auto; }
/* Local .pill overrides the chrome .pill (same specificity, later source
   order wins). This depends on getDashboardChromeStyles() being injected
   BEFORE this stylesheet — see dashboardChromeStylesComponents.ts. */
.pill {
  display: inline-block;
  padding: 1px 7px;
  border-radius: 9px;
  font-size: 11px;
  font-weight: 600;
}
.pill-orphan { background: var(--vscode-editorError-foreground, #f14c4c); color: #fff; }
/* Scroll the table horizontally at narrow widths rather than breaking the
   page layout — the process command-line column can be very wide. */
.group-table-wrap { overflow-x: auto; }
.group-table { width: 100%; border-collapse: collapse; font-size: 12px; }
.group-table td {
  padding: 4px 12px;
  border-top: 1px solid var(--vscode-widget-border, #e5e7eb);
  color: var(--vscode-foreground);
  white-space: nowrap;
}
.group-table .cmd-cell {
  max-width: 380px;
  overflow: hidden;
  text-overflow: ellipsis;
  width: 100%;
}
.group-table .cmd-cell:hover { white-space: normal; word-break: break-all; }
.btn-kill {
  padding: 2px 8px;
  border: none;
  border-radius: 4px;
  font-size: 11px;
  cursor: pointer;
  background: var(--vscode-editorError-foreground, #f14c4c);
  color: #fff;
}
.btn-kill:hover { opacity: 0.85; }
.btn-kill:disabled { opacity: 0.4; cursor: default; }
/* Budget bar — a single-number summary of dev-tool memory usage vs target. */
.budget-bar { padding: 8px 16px 4px; }
.budget-label {
  display: flex;
  justify-content: space-between;
  font-size: 12px;
  color: var(--vscode-descriptionForeground, #94a3b8);
  margin-bottom: 4px;
}
.budget-value { font-weight: 600; }
.budget-value.budget-over { color: var(--vscode-editorWarning-foreground, #cca700); }
.budget-value.budget-under { color: var(--vscode-foreground); }
.budget-track {
  position: relative;
  height: 6px;
  border-radius: 3px;
  background: var(--vscode-progressBar-background, rgba(90,93,110,.15));
  overflow: visible;
}
.budget-fill {
  height: 100%;
  border-radius: 3px;
  transition: width 0.3s ease;
}
/* Green when under budget, amber when over. */
.budget-fill.budget-under { background: var(--vscode-terminal-ansiGreen, #89d185); }
.budget-fill.budget-over { background: var(--vscode-editorWarning-foreground, #cca700); }
/* Vertical tick marking the budget target on the track. */
.budget-target {
  position: absolute;
  top: -2px;
  width: 2px;
  height: 10px;
  background: var(--vscode-foreground);
  opacity: 0.5;
  border-radius: 1px;
}
.empty-state {
  text-align: center;
  padding: 48px 16px;
  color: var(--vscode-descriptionForeground, #94a3b8);
  font-size: 14px;
}
`;
}
