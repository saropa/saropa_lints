/**
 * CSS for the audit report webview.
 *
 * Split out of audit-report-html.ts to keep that file under the project's
 * file-size convention (CLAUDE.md: files <=200 lines) and to match the
 * vibrancy panel convention of splitting html/script/styles into separate
 * modules (extension/src/vibrancy/views/report-*.ts).
 *
 * Uses `var(--vscode-*)` theme tokens throughout (per the plan's "Verified
 * hardening" note: the CSS token strategy is the one thing worth reusing
 * from report-html-shared.ts, but the audit report needs its own concrete
 * stylesheet since it is not typed to VibrancyResult[]).
 */

/** Returns the raw CSS body (no wrapping <style> tag — the caller adds the nonce). */
export function buildAuditStyles(): string {
  return `
/* Audit report — uses VS Code theme tokens for seamless integration. */
:root {
  --audit-bg: var(--vscode-editor-background);
  --audit-fg: var(--vscode-editor-foreground);
  --audit-border: var(--vscode-panel-border, #333);
  --audit-header-bg: var(--vscode-sideBar-background, #252526);
  --audit-hover: var(--vscode-list-hoverBackground, #2a2d2e);
  --audit-chip-bg: var(--vscode-badge-background, #4d4d4d);
  --audit-chip-fg: var(--vscode-badge-foreground, #fff);
  --audit-chip-active-bg: var(--vscode-button-background, #0e639c);
  --audit-chip-active-fg: var(--vscode-button-foreground, #fff);
  --audit-sev-error: var(--vscode-editorError-foreground, #f44747);
  --audit-sev-warning: var(--vscode-editorWarning-foreground, #cca700);
  --audit-sev-info: var(--vscode-editorInfo-foreground, #3794ff);
}

body {
  background: var(--audit-bg);
  color: var(--audit-fg);
  font-family: var(--vscode-font-family);
  font-size: var(--vscode-font-size, 13px);
  margin: 0;
  padding: 0;
}

.audit-header {
  padding: 16px 20px 12px;
  border-bottom: 1px solid var(--audit-border);
  background: var(--audit-header-bg);
}
.audit-header h1 { margin: 0 0 4px; font-size: 1.4em; font-weight: 600; }
.audit-subtitle { margin: 0 0 10px; opacity: 0.7; font-size: 0.9em; }

.audit-kpi-strip { display: flex; gap: 8px; flex-wrap: wrap; }
.audit-kpi {
  padding: 3px 10px;
  border-radius: 12px;
  font-size: 0.85em;
  font-weight: 500;
  background: var(--audit-chip-bg);
  color: var(--audit-chip-fg);
}
.audit-kpi-error { background: var(--audit-sev-error); }
.audit-kpi-warning { background: var(--audit-sev-warning); color: #000; }
.audit-kpi-info { background: var(--audit-sev-info); }

.audit-controls {
  padding: 10px 20px;
  display: flex;
  flex-wrap: wrap;
  gap: 10px;
  align-items: flex-start;
  border-bottom: 1px solid var(--audit-border);
}

.audit-search {
  flex: 1 1 200px;
  padding: 5px 10px;
  border: 1px solid var(--audit-border);
  border-radius: 4px;
  background: var(--vscode-input-background);
  color: var(--vscode-input-foreground);
  font-size: 0.95em;
}
.audit-search:focus { outline: 1px solid var(--vscode-focusBorder); }

.audit-filters { display: flex; gap: 12px; flex-wrap: wrap; }
.audit-filter-group { display: flex; align-items: center; gap: 4px; flex-wrap: wrap; }
.audit-filter-label { font-size: 0.8em; opacity: 0.6; margin-right: 2px; }

.audit-chip {
  padding: 2px 8px;
  border: 1px solid var(--audit-border);
  border-radius: 10px;
  background: transparent;
  color: var(--audit-fg);
  font-size: 0.8em;
  cursor: pointer;
  opacity: 0.5;
}
.audit-chip-active {
  background: var(--audit-chip-active-bg);
  color: var(--audit-chip-active-fg);
  border-color: transparent;
  opacity: 1;
}
.audit-chip-count { font-size: 0.85em; opacity: 0.7; }

.audit-actions { display: flex; gap: 6px; }
.audit-btn {
  padding: 4px 12px;
  border: 1px solid var(--audit-border);
  border-radius: 4px;
  background: var(--vscode-button-secondaryBackground, #3a3d41);
  color: var(--vscode-button-secondaryForeground, #fff);
  cursor: pointer;
  font-size: 0.85em;
}
.audit-btn:hover { background: var(--vscode-button-secondaryHoverBackground, #45494e); }
.audit-btn:disabled { opacity: 0.5; cursor: default; }

.audit-table-wrap { overflow-x: auto; }
.audit-table {
  width: 100%;
  border-collapse: collapse;
  font-size: 0.9em;
}
.audit-table th {
  position: sticky;
  top: 0;
  background: var(--audit-header-bg);
  padding: 8px 10px;
  text-align: left;
  border-bottom: 2px solid var(--audit-border);
  font-weight: 600;
  white-space: nowrap;
}
.audit-table td {
  padding: 5px 10px;
  border-bottom: 1px solid var(--audit-border);
  vertical-align: top;
}
.audit-row:hover { background: var(--audit-hover); }

/* Zebra striping. */
.audit-row:nth-child(even) { background: rgba(128,128,128,0.04); }
.audit-row:nth-child(even):hover { background: var(--audit-hover); }

.audit-clickable { cursor: pointer; text-decoration: underline; }
.audit-clickable:hover { color: var(--vscode-textLink-foreground); }

.audit-sev-pill {
  display: inline-block;
  padding: 1px 6px;
  border-radius: 8px;
  font-size: 0.85em;
  font-weight: 500;
}
.audit-sev-error { color: var(--audit-sev-error); }
.audit-sev-warning { color: var(--audit-sev-warning); }
.audit-sev-info { color: var(--audit-sev-info); }

.audit-col-file { max-width: 300px; overflow: hidden; text-overflow: ellipsis; }
.audit-col-line { white-space: nowrap; min-width: 60px; }
.audit-col-rule { white-space: nowrap; }
.audit-col-message { max-width: 500px; }

.audit-empty, .audit-filtered-empty {
  text-align: center;
  padding: 40px 20px;
  opacity: 0.6;
  font-size: 1.1em;
}
.audit-empty-icon {
  display: block;
  font-size: 2.5em;
  margin-bottom: 8px;
  opacity: 0.5;
}

/* Active row highlight for keyboard navigation. */
.audit-row-active {
  outline: 2px solid var(--vscode-focusBorder, #007fd4);
  outline-offset: -2px;
  background: var(--audit-hover) !important;
}

.audit-keyboard-hint {
  text-align: center;
  padding: 6px;
  opacity: 0.4;
  font-size: 0.8em;
  margin: 0;
}

/* Baseline diffing: "new" rows get a left accent border. */
.audit-baseline-new-row { border-left: 3px solid var(--audit-sev-error); }
.audit-baseline-tag {
  font-size: 0.85em;
  opacity: 0.6;
  font-style: italic;
}
.audit-baseline-new { border-color: var(--audit-sev-error); }

/* Status badges next to rule names when baseline data is present. */
.audit-status-badge {
  display: inline-block;
  padding: 0 4px;
  border-radius: 3px;
  font-size: 0.7em;
  font-weight: 600;
  vertical-align: middle;
  margin-left: 4px;
}
.audit-status-new {
  background: var(--audit-sev-error);
  color: #fff;
}
.audit-status-unchanged {
  opacity: 0.4;
}

.audit-pagination {
  padding: 10px 20px;
  text-align: center;
  display: flex;
  gap: 10px;
  justify-content: center;
  align-items: center;
}

/* Shown while the deferred (>10MB) diagnostics payload is still loading
   from the temp file — see audit-report-panel.ts MAX_INLINE_BYTES. */
.audit-loading-banner {
  padding: 6px 20px;
  font-size: 0.85em;
  opacity: 0.7;
  text-align: center;
}
`;
}
