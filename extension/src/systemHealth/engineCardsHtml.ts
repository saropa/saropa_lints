import { escapeHtml } from '../vibrancy/views/html-utils';
import { l10n } from '../i18n/runtime';
import { formatBytes } from './processQuery';

/**
 * Runtime snapshot of a single diagnostic engine (analyzer, scan daemon, LSP).
 * Moved here (from the former standalone Debug Panel sidebar webview) when
 * the engine cards merged into the Health Panel editor-tab dashboard.
 */
export interface EngineStatus {
  /** Stable machine key for toggle messages and data-attributes.
   *  Must match the message union: 'analyzer' | 'scanDaemon' | 'lspServer'. */
  key: 'analyzer' | 'scanDaemon' | 'lspServer';
  /** Display name shown in the panel header row — must come from l10n(). */
  name: string;
  /** Whether the user has toggled this engine on. */
  enabled: boolean;
  /** Freeform lifecycle label: "active", "idle", "running", "stopped", "starting", etc. */
  status: string;
  /** OS process ID when the engine is running. */
  pid?: number;
  /** Number of lint rules loaded by this engine. */
  ruleCount?: number;
  /** Resident set size in bytes. */
  rssBytes?: number;
  /** Explanatory note when RSS cannot be measured (e.g. in-process engines). */
  rssNote?: string;
}

/** Callback signatures the host supplies so the panel can read engine state. */
export interface EngineStatusDeps {
  getAnalyzerPluginStatus: () => EngineStatus;
  getScanDaemonStatus: () => EngineStatus;
  getLspServerStatus: () => EngineStatus;
}

// ────────────────────────────────────────────────────────────────
// Section builders
// ────────────────────────────────────────────────────────────────

/** Render the "Diagnostic Engines" heading and one card per engine. */
export function buildEnginesSection(engines: EngineStatus[]): string {
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
  // Use the explicit key from EngineStatus — stable across locales,
  // unlike the display name which goes through l10n().
  const engineKey = engine.key;

  // "What does this engine do" subtitle — the sidebar's own "users have to
  // guess" complaint applies here too, so this is a visible line, not a
  // hover-only tooltip. Description keys use 'analyzerPlugin' (matching the
  // existing debug.engine.analyzerPlugin name key) rather than the terser
  // 'analyzer' EngineStatus.key.
  const descriptionKey = engineKey === 'analyzer' ? 'analyzerPlugin' : engineKey;
  const description = escapeHtml(l10n(`debug.engine.description.${descriptionKey}`));

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
  const statusLabel = escapeHtml(l10n('debug.engine.statusLabel'));
  const statusClass = statusColorClass(engine.status);
  const statusText = escapeHtml(l10n(`debug.engine.statusValue.${engine.status}`));

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
  <div class="engine-description">${description}</div>
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

  // Rule count only applies to the analyzer engine — omitted for the scan
  // daemon and LSP server, which don't report a loaded-rule figure.
  if (engine.ruleCount !== undefined) {
    const rulesLabel = escapeHtml(l10n('debug.engine.rules'));
    parts.push(`${rulesLabel} ${engine.ruleCount}`);
  }

  // rssBytes and rssNote are mutually exclusive: an out-of-process engine
  // (scan daemon, LSP server) reports a real measured RSS, while an
  // in-process one (the analyzer plugin) can't be isolated from the host
  // extension's own memory, so it reports an explanatory note instead.
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

/**
 * Render the Kill All / Restart All action buttons plus a visible subtitle
 * for each — both buttons currently only affect the LSP Server (see
 * extension.ts `HealthPanel.onKillAll`/`onRestartAll`), so the subtitle
 * says that explicitly rather than letting the "All" in the label imply
 * more than the buttons actually do.
 */
export function buildActionsBar(): string {
  const killLabel = escapeHtml(l10n('debug.action.killAll'));
  const restartLabel = escapeHtml(l10n('debug.action.restartAll'));
  const killDescription = escapeHtml(l10n('debug.action.killAllDescription'));
  const restartDescription = escapeHtml(l10n('debug.action.restartAllDescription'));

  return `<div class="actions-bar">
  <div class="action-item">
    <button class="btn-danger" data-action="killAll" title="${killDescription}">${killLabel}</button>
    <div class="action-description">${killDescription}</div>
  </div>
  <div class="action-item">
    <button class="btn-secondary" data-action="restartAll" title="${restartDescription}">${restartLabel}</button>
    <div class="action-description">${restartDescription}</div>
  </div>
</div>`;
}

/**
 * Render the scrollable log section with timestamped entries.
 *
 * A native `<details>`/`<summary>` collapsed-by-default expander — no
 * script needed to toggle it, and it keeps the engine cards above the
 * fold instead of the log's scrollback dominating the panel.
 */
export function buildLogSection(logEntries: string[]): string {
  const heading = escapeHtml(l10n('debug.section.log'));

  if (logEntries.length === 0) {
    const emptyMsg = escapeHtml(l10n('debug.log.empty'));
    return `<details class="log-section">
  <summary class="section-heading">${heading}</summary>
  <div class="log-empty">${emptyMsg}</div>
</details>`;
  }

  // Newest at the bottom so the CSS-anchored scroll stays at the tail.
  const lines = logEntries
    .map((entry) => `<div class="log-line">${escapeHtml(entry)}</div>`)
    .join('');

  return `<details class="log-section">
  <summary class="section-heading">${heading}</summary>
  <div class="log-container">${lines}</div>
</details>`;
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
      return 'status-default';
  }
}

// ────────────────────────────────────────────────────────────────
// Inline CSS — appended to healthPanel-styles.ts's stylesheet.
// ────────────────────────────────────────────────────────────────

/**
 * Styles for the engine cards, actions bar, and log section. Uses
 * `var(--vscode-*)` custom properties so colors adapt to the active
 * VS Code theme (light, dark, high-contrast).
 */
export function getEngineCardsStyles(): string {
  return `
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
.engine-description {
  margin-top: 2px;
  font-size: 12px;
  color: var(--vscode-descriptionForeground, #94a3b8);
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
.toggle-on.active {
  background: var(--vscode-testing-iconPassed, #73c991);
  color: #000;
  border-color: var(--vscode-testing-iconPassed, #73c991);
}
.toggle-off.active {
  background: var(--vscode-editorError-foreground, #f14c4c);
  color: #fff;
  border-color: var(--vscode-editorError-foreground, #f14c4c);
}

/* ── Actions bar ──────────────────────────────────────────── */
.actions-bar {
  display: flex;
  gap: 16px;
  padding: 10px 12px;
  border-bottom: 1px solid var(--vscode-widget-border, #e5e7eb);
}
.action-item {
  display: flex;
  flex-direction: column;
  gap: 4px;
  max-width: 220px;
}
.action-description {
  font-size: 11px;
  color: var(--vscode-descriptionForeground, #94a3b8);
  line-height: 1.35;
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
/* .log-section is a <details> element — its .section-heading <summary>
   needs the pointer cursor a plain heading doesn't, and the default
   marker/list-item spacing suppressed so it still reads as a heading. */
.log-section > summary.section-heading {
  cursor: pointer;
  list-style: none;
  display: block;
}
.log-section > summary.section-heading::-webkit-details-marker {
  display: none;
}
.log-section > summary.section-heading::before {
  content: '▸';
  display: inline-block;
  margin-right: 6px;
  transition: transform 0.1s ease;
}
.log-section[open] > summary.section-heading::before {
  transform: rotate(90deg);
}
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
