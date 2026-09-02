import * as vscode from 'vscode';
import { createWebviewCspNonce, escapeHtml } from '../vibrancy/views/html-utils';
import { l10n } from '../i18n/runtime';
import { formatBytes } from '../systemHealth/processQuery';
import type { EngineStatus } from './debugPanel';

// ────────────────────────────────────────────────────────────────
// Public entry point
// ────────────────────────────────────────────────────────────────

/**
 * Build the full HTML document for the Debug Panel sidebar webview.
 *
 * The panel shows engine status cards, bulk action buttons, and a
 * timestamped scrollable log. Every user-facing string is routed
 * through `l10n()` for translation readiness.
 */
export function buildDebugPanelHtml(
  _webview: vscode.Webview,
  _extensionUri: vscode.Uri,
  engines: EngineStatus[],
  logEntries: string[],
): string {
  const nonce = createWebviewCspNonce();
  const title = l10n('debug.panel.title');

  return `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta http-equiv="Content-Security-Policy"
    content="default-src 'none'; style-src 'nonce-${nonce}'; script-src 'nonce-${nonce}';">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>${escapeHtml(title)}</title>
  <style nonce="${nonce}">${getStyles()}</style>
</head>
<body>
  ${buildEnginesSection(engines)}
  ${buildActionsBar()}
  ${buildLogSection(logEntries)}
  <script nonce="${nonce}">${getScript()}</script>
</body>
</html>`;
}

// ────────────────────────────────────────────────────────────────
// Section builders
// ────────────────────────────────────────────────────────────────

/** Render the "Diagnostic Engines" heading and one card per engine. */
function buildEnginesSection(engines: EngineStatus[]): string {
  const heading = escapeHtml(l10n('debug.section.engines'));
  const cards = engines.map(buildEngineCard).join('');

  return `<section class="engines-section">
  <h2 class="section-heading">${heading}</h2>
  ${cards}
</section>`;
}

/**
 * Render a single engine status card.
 *
 * Layout per card:
 *   Name           [ON] [OFF]    PID: 12345
 *   Status: active
 *   Rules: 203 . RSS: 1.02 GB
 */
function buildEngineCard(engine: EngineStatus): string {
  // Determine which engine key to send in the toggle message.
  // The key is derived from the EngineStatus.name value — the
  // extension wires these in a fixed order (analyzer, scanDaemon,
  // lspServer), so we use a data attribute the script reads.
  const engineKey = engineNameToKey(engine.name);

  // Toggle button labels — ON is highlighted when enabled, OFF when disabled.
  const onLabel = escapeHtml(l10n('debug.toggle.on'));
  const offLabel = escapeHtml(l10n('debug.toggle.off'));
  const onClass = engine.enabled ? 'toggle-btn toggle-on active' : 'toggle-btn toggle-on';
  const offClass = engine.enabled ? 'toggle-btn toggle-off' : 'toggle-btn toggle-off active';

  // PID display — omitted when the engine has no running process.
  const pidLabel = escapeHtml(l10n('debug.engine.pid'));
  const pidValue = engine.pid !== undefined
    ? `<span class="engine-pid">${pidLabel} ${engine.pid}</span>`
    : '';

  // Status pill — color class varies by lifecycle state.
  const statusLabel = escapeHtml(l10n('debug.engine.status'));
  const statusClass = statusColorClass(engine.status);
  const statusText = escapeHtml(engine.status);

  // Rules and RSS on a secondary line.
  const metricsLine = buildMetricsLine(engine);

  return `<div class="engine-card" data-engine="${escapeHtml(engineKey)}">
  <div class="engine-header">
    <span class="engine-name">${escapeHtml(engine.name)}</span>
    <span class="engine-controls">
      <button class="${onClass}" data-action="toggleOn">${onLabel}</button>
      <button class="${offClass}" data-action="toggleOff">${offLabel}</button>
    </span>
    ${pidValue}
  </div>
  <div class="engine-detail">
    <span class="engine-status"><span class="status-label">${statusLabel}</span> <span class="status-value ${statusClass}">${statusText}</span></span>
  </div>
  ${metricsLine}
</div>`;
}

/**
 * Build the "Rules: N . RSS: X" metrics line for an engine card.
 * Omitted entirely when there are no metrics to show.
 */
function buildMetricsLine(engine: EngineStatus): string {
  const parts: string[] = [];

  // Rule count — only shown when the engine reports loaded rules.
  if (engine.ruleCount !== undefined) {
    const rulesLabel = escapeHtml(l10n('debug.engine.rules'));
    parts.push(`${rulesLabel} ${engine.ruleCount}`);
  }

  // RSS — shown as formatted bytes, or as a note when not measurable.
  if (engine.rssBytes !== undefined) {
    const rssLabel = escapeHtml(l10n('debug.engine.rss'));
    parts.push(`${rssLabel} ${escapeHtml(formatBytes(engine.rssBytes))}`);
  } else if (engine.rssNote) {
    const rssLabel = escapeHtml(l10n('debug.engine.rss'));
    parts.push(`${rssLabel} ${escapeHtml(engine.rssNote)}`);
  }

  if (parts.length === 0) {
    return '';
  }

  return `<div class="engine-metrics">${parts.join(' <span class="metric-sep">·</span> ')}</div>`;
}

/** Render the Kill All / Restart All action buttons. */
function buildActionsBar(): string {
  const killLabel = escapeHtml(l10n('debug.action.killAll'));
  const restartLabel = escapeHtml(l10n('debug.action.restartAll'));

  return `<div class="actions-bar">
  <button class="btn-danger" data-action="killAll">${killLabel}</button>
  <button class="btn-secondary" data-action="restartAll">${restartLabel}</button>
</div>`;
}

/** Render the scrollable log section with timestamped entries. */
function buildLogSection(logEntries: string[]): string {
  const heading = escapeHtml(l10n('debug.section.log'));

  // Empty-state message when no log entries have been recorded yet.
  if (logEntries.length === 0) {
    const emptyMsg = escapeHtml(l10n('debug.log.empty'));
    return `<section class="log-section">
  <h2 class="section-heading">${heading}</h2>
  <div class="log-empty">${emptyMsg}</div>
</section>`;
  }

  // Render each entry as a single <div> — newest at the bottom so the
  // CSS-anchored scroll stays at the tail.
  const lines = logEntries
    .map((entry) => `<div class="log-line">${escapeHtml(entry)}</div>`)
    .join('');

  return `<section class="log-section">
  <h2 class="section-heading">${heading}</h2>
  <div class="log-container">${lines}</div>
</section>`;
}

// ────────────────────────────────────────────────────────────────
// Helpers
// ────────────────────────────────────────────────────────────────

/**
 * Map a human-readable engine name to the message key the extension
 * host expects in toggle commands. Falls back to the name itself
 * (lowercased, spaces stripped) if no known mapping matches.
 */
function engineNameToKey(name: string): string {
  const lower = name.toLowerCase();
  if (lower.includes('analyzer')) return 'analyzer';
  if (lower.includes('scan')) return 'scanDaemon';
  if (lower.includes('lsp')) return 'lspServer';
  // Fallback for future engines.
  return name.replace(/\s+/g, '').toLowerCase();
}

/**
 * Return a CSS class name that colors the status text according to
 * the engine's lifecycle state.
 */
function statusColorClass(status: string): string {
  switch (status.toLowerCase()) {
    case 'active':
    case 'running':
      return 'status-active';
    case 'starting':
      return 'status-starting';
    case 'stopped':
    case 'error':
      return 'status-stopped';
    default:
      // Idle, unknown, or custom states get the default foreground.
      return 'status-default';
  }
}

// ────────────────────────────────────────────────────────────────
// Inline CSS
// ────────────────────────────────────────────────────────────────

/**
 * All styles for the debug panel.
 *
 * Uses `var(--vscode-*)` custom properties so colors adapt to the
 * active VS Code theme (light, dark, high-contrast). Follows the
 * same token/spacing conventions as healthPanel-styles.ts.
 */
function getStyles(): string {
  return `
/* ── Base ──────────────────────────────────────────────────── */
body {
  font-family: var(--vscode-font-family, system-ui, sans-serif);
  font-size: 13px;
  color: var(--vscode-foreground);
  padding: 0;
  margin: 0;
}

/* ── Section headings ─────────────────────────────────────── */
.section-heading {
  font-size: 13px;
  font-weight: 600;
  text-transform: uppercase;
  letter-spacing: 0.05em;
  color: var(--vscode-foreground);
  padding: 10px 12px 6px;
  margin: 0;
  border-bottom: 1px solid var(--vscode-widget-border, #e5e7eb);
}

/* ── Engine cards ─────────────────────────────────────────── */
.engine-card {
  padding: 8px 12px;
  border-bottom: 1px solid var(--vscode-widget-border, #e5e7eb);
}
.engine-header {
  display: flex;
  align-items: center;
  gap: 6px;
  flex-wrap: wrap;
}
.engine-name {
  font-weight: 600;
  flex-shrink: 0;
}
.engine-controls {
  display: inline-flex;
  gap: 2px;
  flex-shrink: 0;
}
.engine-pid {
  margin-left: auto;
  font-size: 12px;
  color: var(--vscode-descriptionForeground, #94a3b8);
  font-family: var(--vscode-editor-font-family, monospace);
}
.engine-detail {
  margin-top: 4px;
  font-size: 12px;
}
.engine-metrics {
  margin-top: 2px;
  font-size: 12px;
  color: var(--vscode-descriptionForeground, #94a3b8);
}
.metric-sep {
  margin: 0 4px;
}

/* ── Status colors ────────────────────────────────────────── */
.status-label {
  color: var(--vscode-descriptionForeground, #94a3b8);
}
.status-active {
  color: var(--vscode-testing-iconPassed, #73c991);
}
.status-starting {
  color: var(--vscode-editorWarning-foreground, #cca700);
}
.status-stopped {
  color: var(--vscode-descriptionForeground, #94a3b8);
}
.status-default {
  color: var(--vscode-foreground);
}

/* ── Toggle buttons ───────────────────────────────────────── */
.toggle-btn {
  padding: 2px 8px;
  border: 1px solid var(--vscode-widget-border, #e5e7eb);
  border-radius: 3px;
  font-size: 11px;
  font-weight: 600;
  cursor: pointer;
  background: transparent;
  color: var(--vscode-foreground);
}
.toggle-btn:hover {
  opacity: 0.85;
}
/* ON button highlighted green when the engine is enabled. */
.toggle-on.active {
  background: var(--vscode-testing-iconPassed, #73c991);
  color: #000;
  border-color: var(--vscode-testing-iconPassed, #73c991);
}
/* OFF button highlighted red when the engine is disabled. */
.toggle-off.active {
  background: var(--vscode-editorError-foreground, #f14c4c);
  color: #fff;
  border-color: var(--vscode-editorError-foreground, #f14c4c);
}

/* ── Actions bar ──────────────────────────────────────────── */
.actions-bar {
  display: flex;
  gap: 8px;
  padding: 10px 12px;
  border-bottom: 1px solid var(--vscode-widget-border, #e5e7eb);
}
.btn-danger {
  padding: 4px 12px;
  border: none;
  border-radius: 4px;
  font-size: 12px;
  cursor: pointer;
  background: var(--vscode-editorError-foreground, #f14c4c);
  color: #fff;
}
.btn-danger:hover {
  opacity: 0.85;
}
.btn-secondary {
  padding: 4px 12px;
  border: 1px solid var(--vscode-widget-border, #e5e7eb);
  border-radius: 4px;
  font-size: 12px;
  cursor: pointer;
  background: var(--vscode-button-secondaryBackground, transparent);
  color: var(--vscode-foreground);
}
.btn-secondary:hover {
  background: var(--vscode-list-hoverBackground, rgba(90,93,110,.1));
}

/* ── Log section ──────────────────────────────────────────── */
.log-container {
  max-height: 200px;
  overflow-y: auto;
  padding: 6px 12px;
  font-family: var(--vscode-editor-font-family, monospace);
  font-size: 12px;
}
.log-line {
  padding: 1px 0;
  white-space: pre-wrap;
  word-break: break-all;
  color: var(--vscode-foreground);
}
.log-line:nth-child(odd) {
  background: var(--vscode-list-hoverBackground, rgba(90,93,110,.04));
}
.log-empty {
  padding: 16px 12px;
  text-align: center;
  color: var(--vscode-descriptionForeground, #94a3b8);
  font-size: 12px;
}
`;
}

// ────────────────────────────────────────────────────────────────
// Inline script
// ────────────────────────────────────────────────────────────────

/**
 * Client-side script that wires button clicks to vscode.postMessage.
 *
 * Runs inside the webview sandbox — `acquireVsCodeApi()` is the
 * only bridge back to the extension host.
 */
function getScript(): string {
  return `(function() {
  // Acquire the VS Code API handle (can only be called once per
  // webview lifetime — the result is cached by the host).
  const vscode = acquireVsCodeApi();

  // Delegate all button clicks via a single document listener to
  // avoid per-button addEventListener boilerplate.
  document.addEventListener('click', function(e) {
    const btn = e.target.closest('button[data-action]');
    if (!btn) return;

    const action = btn.dataset.action;

    // Toggle ON — tell the host this engine should be enabled.
    if (action === 'toggleOn') {
      const card = btn.closest('.engine-card');
      if (card) {
        vscode.postMessage({
          command: 'toggle',
          engine: card.dataset.engine,
          enabled: true
        });
      }
      return;
    }

    // Toggle OFF — tell the host this engine should be disabled.
    if (action === 'toggleOff') {
      const card = btn.closest('.engine-card');
      if (card) {
        vscode.postMessage({
          command: 'toggle',
          engine: card.dataset.engine,
          enabled: false
        });
      }
      return;
    }

    // Bulk actions.
    if (action === 'killAll') {
      vscode.postMessage({ command: 'killAll' });
      return;
    }
    if (action === 'restartAll') {
      vscode.postMessage({ command: 'restartAll' });
      return;
    }
  });

  // Auto-scroll the log container to the bottom on load so the
  // newest entries are visible without manual scrolling.
  var logContainer = document.querySelector('.log-container');
  if (logContainer) {
    logContainer.scrollTop = logContainer.scrollHeight;
  }
})();`;
}
