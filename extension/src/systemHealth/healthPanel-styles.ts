import { getDashboardChromeStyles } from '../views/dashboardChromeStyles';

export function getHealthPanelStyles(): string {
  return `${getDashboardChromeStyles()}
.health-table {
  width: 100%;
  border-collapse: collapse;
  font-size: 13px;
}
.health-table th,
.health-table td {
  text-align: left;
  padding: 6px 10px;
  border-bottom: 1px solid var(--vscode-widget-border, #e5e7eb);
  white-space: nowrap;
}
.health-table th {
  background: var(--vscode-editorWidget-background);
  position: sticky;
  top: 0;
  z-index: 1;
  font-weight: 600;
  color: var(--vscode-foreground);
}
.health-table td {
  color: var(--vscode-foreground);
}
.health-table tr:hover td {
  background: var(--vscode-list-hoverBackground, rgba(90,93,110,.1));
}
.health-table .cmd-cell {
  max-width: 320px;
  overflow: hidden;
  text-overflow: ellipsis;
}
.health-table .cmd-cell:hover {
  white-space: normal;
  word-break: break-all;
}
.pill {
  display: inline-block;
  padding: 1px 7px;
  border-radius: 9px;
  font-size: 11px;
  font-weight: 600;
}
.pill-orphan {
  background: var(--vscode-editorError-foreground, #f14c4c);
  color: #fff;
}
.pill-daemon {
  background: var(--vscode-editorWarning-foreground, #cca700);
  color: #000;
}
.pill-process {
  background: var(--vscode-editorInfo-foreground, #3794ff);
  color: #fff;
}
.summary-bar {
  display: flex;
  gap: 16px;
  padding: 12px 16px;
  background: var(--vscode-editorWidget-background);
  border-bottom: 1px solid var(--vscode-widget-border, #e5e7eb);
  flex-wrap: wrap;
  align-items: center;
}
.summary-stat {
  font-size: 13px;
  color: var(--vscode-foreground);
}
.summary-stat strong {
  font-weight: 700;
}
.btn-kill {
  padding: 3px 10px;
  border: none;
  border-radius: 4px;
  font-size: 12px;
  cursor: pointer;
  background: var(--vscode-editorError-foreground, #f14c4c);
  color: #fff;
}
.btn-kill:hover {
  opacity: 0.85;
}
.btn-kill:disabled {
  opacity: 0.4;
  cursor: default;
}
.btn-refresh {
  padding: 3px 10px;
  border: 1px solid var(--vscode-widget-border, #e5e7eb);
  border-radius: 4px;
  font-size: 12px;
  cursor: pointer;
  background: var(--vscode-button-secondaryBackground, transparent);
  color: var(--vscode-foreground);
}
.btn-refresh:hover {
  background: var(--vscode-list-hoverBackground, rgba(90,93,110,.1));
}
.empty-state {
  text-align: center;
  padding: 48px 16px;
  color: var(--vscode-descriptionForeground, #94a3b8);
  font-size: 14px;
}
`;
}
