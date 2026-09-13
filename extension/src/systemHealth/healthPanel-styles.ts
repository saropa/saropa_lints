import { getDashboardChromeStyles } from '../views/dashboardChromeStyles';
import { getEngineCardsStyles } from './engineCardsHtml';

// Extends the shared dashboard chrome so this panel matches the other
// vibrancy/views panels without duplicating base layout/typography rules.
// Also carries the engine-card / actions-bar / log-section styles that
// moved in from the former standalone Debug Panel webview.
export function getHealthPanelStyles(): string {
  return `${getDashboardChromeStyles()}
${getEngineCardsStyles()}
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
/* Local .pill: the chrome base rule is doubled (.pill.pill in
   dashboardChromeStylesComponents.ts) to raise its specificity above this
   single-class selector, so this override applies regardless of injection
   order relative to getDashboardChromeStyles(). */
.pill {
  display: inline-block;
  padding: 1px 7px;
  border-radius: 9px;
  font-size: 11px;
  font-weight: 600;
}
/* Orphan/daemon/process colors track VS Code's own error/warning/info
   theme tokens so the severity read (red=orphan) stays consistent with
   the rest of the editor UI across light/dark/high-contrast themes. */
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
/* Orphaned-host banner. Uses the editorWarning token rather than a literal
   amber so it stays legible in light, dark and high-contrast themes; the
   text color is the editor foreground so the banner never becomes a block
   of unreadable low-contrast text when a theme redefines the warning hue. */
.orphan-banner {
  display: flex;
  gap: 12px;
  align-items: center;
  flex-wrap: wrap;
  padding: 10px 16px;
  border-bottom: 1px solid var(--vscode-widget-border, #e5e7eb);
  border-left: 4px solid var(--vscode-editorWarning-foreground, #cca700);
  background: var(--vscode-inputValidation-warningBackground, var(--vscode-editorWidget-background));
}
.orphan-banner-text {
  font-size: 13px;
  font-weight: 600;
  color: var(--vscode-foreground);
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
/* ── CI publish step ──────────────────────────────────────────────
   Bordered rather than plain, because this section is a prompt that is
   waiting on the user, not status they can read past. */
.ci-publish-section {
  margin: 16px 0;
  padding: 12px 14px;
  border: 1px solid var(--vscode-focusBorder, #0078d4);
  border-radius: 6px;
  background: var(--vscode-editorWidget-background, rgba(90,93,110,.08));
}
.publish-intro {
  margin: 6px 0 12px;
  font-size: 12px;
  line-height: 1.5;
  color: var(--vscode-descriptionForeground, #94a3b8);
}
.publish-commands-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  margin-bottom: 4px;
}
.publish-commands-label {
  font-size: 11px;
  text-transform: uppercase;
  letter-spacing: .04em;
  color: var(--vscode-descriptionForeground, #94a3b8);
}
.publish-copy {
  display: inline-flex;
  align-items: center;
  gap: 4px;
  padding: 2px 8px;
  border: 1px solid var(--vscode-widget-border, #e5e7eb);
  border-radius: 4px;
  font-size: 11px;
  cursor: pointer;
  background: var(--vscode-button-secondaryBackground, transparent);
  color: var(--vscode-foreground);
}
.publish-copy:hover {
  background: var(--vscode-list-hoverBackground, rgba(90,93,110,.1));
}
.publish-commands {
  margin: 0;
  padding: 8px 10px;
  border-radius: 4px;
  overflow-x: auto;
  font-family: var(--vscode-editor-font-family, monospace);
  font-size: 12px;
  line-height: 1.6;
  background: var(--vscode-textCodeBlock-background, rgba(0,0,0,.18));
  color: var(--vscode-foreground);
  /* Selectable so the commands can be taken by hand, not only by the button. */
  user-select: text;
}
.publish-note {
  margin: 10px 0 0;
  font-size: 12px;
  color: var(--vscode-descriptionForeground, #94a3b8);
}
.publish-actions {
  display: flex;
  gap: 8px;
  margin-top: 12px;
}
.publish-btn {
  padding: 4px 12px;
  border: 1px solid var(--vscode-widget-border, #e5e7eb);
  border-radius: 4px;
  font-size: 12px;
  cursor: pointer;
  background: var(--vscode-button-secondaryBackground, transparent);
  color: var(--vscode-foreground);
}
.publish-btn.primary {
  border-color: transparent;
  background: var(--vscode-button-background, #0078d4);
  color: var(--vscode-button-foreground, #fff);
}
.publish-btn:hover {
  opacity: .88;
}
.publish-btn:disabled {
  opacity: .5;
  cursor: default;
}
.empty-state {
  text-align: center;
  padding: 48px 16px;
  color: var(--vscode-descriptionForeground, #94a3b8);
  font-size: 14px;
}
`;
}
