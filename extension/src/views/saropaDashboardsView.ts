/**
 * "Saropa Dashboards" launchpad — one editor tab that consolidates every Saropa dashboard so users
 * do not have to open each one separately.
 *
 * Six panes in one responsive grid:
 *   - Project Map and Code Health are FULLY EMBEDDED. Each runs a `dart run` scan, so their real
 *     interactive markup (ECharts treemap / hot-spot table; sortable function table) is dropped in.
 *   - Lints Config, Findings, Package, and Command Catalog are FAST (local files / in-memory cache),
 *     so each shows a compact live summary card plus an "Open full screen" deep-link (see
 *     [dashboardSummaries.ts]). Embedding their full interactive documents would force six
 *     `acquireVsCodeApi()` handles and colliding ids/styles into one document — the launchpad shows
 *     summaries instead and links out.
 *
 * **Loading model — shell first, panes stream in.** The webview HTML shell (hero + the four summary
 * cards + two "Scanning…" placeholders) is set ONCE and appears instantly. The two heavy scans then
 * run SEQUENTIALLY in the background (they are both `dart run` against the same package; running them
 * together makes the second block on the first's build-snapshot / pub lock and the pair can stall —
 * the original "consolidated view hangs" bug). As each scan finishes the host posts a `paneReady`
 * message and the client patches that pane in place. A failed scan posts `paneError`, which renders
 * an inline retry button scoped to that pane — one engine erroring never blanks the page.
 *
 * **Single API handle.** `acquireVsCodeApi()` may be called only once per document. The client shim
 * acquires it up front and re-exposes it, so the embedded engine scripts (which each call
 * `acquireVsCodeApi()`) share the one messaging channel.
 *
 * **Style isolation.** Project Map's stylesheet is scoped under `.pm-pane` and arrives as its own
 * complete `<style>` element (the `<!--PM_*-->` markers wrap the tags), so the client injects it
 * verbatim with `insertAdjacentHTML` — never re-wrapped in another `<style>`. The earlier code
 * double-wrapped it, whose inner `</style>` closed the block early and spilled the theme-token CSS
 * onto the page as visible text (and blanked the treemap). The static `.pm-pane` theme tokens and
 * height fixups now live in the shell head, applied once.
 */
import * as nodePath from 'node:path';
import * as vscode from 'vscode';
import { getProjectRoot } from '../projectRoot';
import { hasSaropaLintsDep } from '../pubspecReader';
import { l10n } from '../i18n/runtime';
import { getProjectVibrancyReportStyles } from './projectVibrancyReportStyles';
import { getKeyboardShortcutsStyles } from './keyboard-shortcuts';
import { buildDashboardHero } from './dashboardHero';
import { openFileFromReport, pmPaneThemeTokens, scanProjectMapToParts } from './projectMapView';
import { applyFileSuppression, buildCodeHealthFragment } from './projectVibrancyReportView';
import { runProjectVibrancyScan } from './projectVibrancyCliRunner';
import {
  buildCatalogSummary,
  buildConfigSummary,
  buildFindingsSummary,
  buildPackageSummary,
  SUMMARY_OPEN_COMMANDS,
} from './dashboardSummaries';

let panel: vscode.WebviewPanel | undefined;
let extensionUri: vscode.Uri;
let extensionContext: vscode.ExtensionContext;
let inflight: Promise<void> | undefined;
let scanTokenSource: vscode.CancellationTokenSource | undefined;
let lastRoot: string | undefined; // resolves relative drill-down paths from either heavy pane
let lastCodeHealthStdout = ''; // backs the Code Health pane's "Copy JSON" action

/** The two heavy panes the launchpad loads via background scans + `paneReady` messages. */
type HeavyEngine = 'projectMap' | 'codeHealth';

/**
 * Commands the launchpad may execute on behalf of a webview click. The webview can only post a
 * `data-command` from this set (or a `rescanPane`), so a compromised/buggy script cannot drive
 * arbitrary VS Code commands. Covers the two heavy panes' "Open full screen" plus the four light
 * deep-links and the Code Health settings link.
 */
const OPEN_COMMAND_ALLOWLIST: ReadonlySet<string> = new Set<string>([
  'saropaLints.openProjectHealthDashboard',
  'saropaLints.openProjectVibrancyReport',
  'saropaLints.openProjectVibrancySettings',
  SUMMARY_OPEN_COMMANDS.lintsConfig,
  SUMMARY_OPEN_COMMANDS.package,
  SUMMARY_OPEN_COMMANDS.findings,
  SUMMARY_OPEN_COMMANDS.commandCatalog,
]);

/** Registers the `Saropa Dashboards` command; call once at activation. */
export function registerSaropaDashboardsCommand(context: vscode.ExtensionContext): void {
  extensionUri = context.extensionUri;
  extensionContext = context;
  context.subscriptions.push(
    vscode.commands.registerCommand('saropaLints.openDashboards', () => openDashboards()),
  );
}

function openDashboards(): Promise<void> {
  if (inflight) {
    panel?.reveal(vscode.ViewColumn.One);
    return inflight; // a render is already running — share it, don't double-spawn the heavy scans
  }
  const root = getProjectRoot();
  if (!root) {
    void vscode.window.showErrorMessage(l10n('notify.commands.projectMapNoProject'));
    return Promise.resolve();
  }
  if (!hasSaropaLintsDep(root)) {
    void vscode.window.showErrorMessage(l10n('notify.commands.projectMapMissingDep'));
    return Promise.resolve();
  }
  inflight = renderAndLoad(root).finally(() => {
    inflight = undefined;
  });
  return inflight;
}

/**
 * Sets the shell immediately (hero + four live summary cards + two "Scanning…" placeholders), then
 * loads the two heavy panes in the background. The shell carries fresh summaries on every open, so
 * the light panes are never stale.
 */
async function renderAndLoad(root: string): Promise<void> {
  lastRoot = root;
  const p = getOrCreatePanel();
  p.webview.html = buildShell(p.webview.cspSource, echartsUriString(p.webview), {
    config: buildConfigSummary(root),
    package: buildPackageSummary(),
    findings: buildFindingsSummary(root),
    catalog: buildCatalogSummary(extensionContext),
  });
  p.reveal(vscode.ViewColumn.One);
  await loadHeavyPanes(root);
}

/** Runs the two heavy scans sequentially; each renders into its pane the instant it finishes. */
async function loadHeavyPanes(root: string): Promise<void> {
  scanTokenSource?.cancel();
  scanTokenSource?.dispose();
  const cts = new vscode.CancellationTokenSource();
  scanTokenSource = cts;
  await loadProjectMapPane(root, cts.token);
  if (cts.token.isCancellationRequested || !panel) return;
  await loadCodeHealthPane(root, cts.token);
}

async function loadProjectMapPane(root: string, token: vscode.CancellationToken): Promise<void> {
  if (!panel) return;
  try {
    const parts = await scanProjectMapToParts(root, panel.webview, extensionUri, token);
    if (!panel || token.isCancellationRequested) return;
    if (!parts) {
      postPaneError('projectMap');
      return;
    }
    // styleHtml is already a complete `<style>` element — the client injects it verbatim.
    void panel.webview.postMessage({
      type: 'paneReady',
      engine: 'projectMap',
      style: parts.styleHtml,
      body: parts.bodyHtml,
      script: parts.scriptHtml,
    });
  } catch {
    if (panel) postPaneError('projectMap');
  }
}

async function loadCodeHealthPane(root: string, token: vscode.CancellationToken): Promise<void> {
  if (!panel) return;
  try {
    const scan = await runProjectVibrancyScan(root, token);
    if (!panel || token.isCancellationRequested) return;
    if (!scan.payload) {
      postPaneError('codeHealth');
      return;
    }
    lastCodeHealthStdout = scan.rawStdout;
    // No saved-report-file row in the consolidated pane (reportFilePath omitted) — the standalone
    // Code Health panel owns the persisted-file workflow; "Open full screen" reaches it.
    const frag = buildCodeHealthFragment(scan.payload);
    void panel.webview.postMessage({
      type: 'paneReady',
      engine: 'codeHealth',
      body: frag.body,
      script: frag.script,
    });
  } catch {
    if (panel) postPaneError('codeHealth');
  }
}

function postPaneError(engine: HeavyEngine): void {
  void panel?.webview.postMessage({ type: 'paneError', engine });
}

/** Re-runs a single heavy pane's scan in response to its in-pane retry/rescan button. */
async function rescanPane(engine: HeavyEngine): Promise<void> {
  if (!lastRoot || !panel) return;
  void panel.webview.postMessage({ type: 'paneLoading', engine });
  const cts = new vscode.CancellationTokenSource();
  try {
    if (engine === 'projectMap') {
      await loadProjectMapPane(lastRoot, cts.token);
    } else {
      await loadCodeHealthPane(lastRoot, cts.token);
    }
  } finally {
    cts.dispose();
  }
}

function getOrCreatePanel(): vscode.WebviewPanel {
  if (panel) return panel;
  panel = vscode.window.createWebviewPanel(
    'saropaDashboards',
    'Saropa Dashboards',
    vscode.ViewColumn.One,
    {
      enableScripts: true,
      retainContextWhenHidden: true,
      // The Project Map pane loads the vendored ECharts from media/.
      localResourceRoots: [vscode.Uri.joinPath(extensionUri, 'media')],
    },
  );
  panel.onDidDispose(() => {
    panel = undefined;
    scanTokenSource?.cancel();
    scanTokenSource?.dispose();
    scanTokenSource = undefined;
  });
  panel.webview.onDidReceiveMessage((msg: unknown) => handleHostMessage(msg));
  return panel;
}

/**
 * Routes messages from the launchpad client: drill-down file opens (the heavy panes post `{file}` /
 * `{file, line}`), allowlisted command deep-links, single-pane rescans, and the Code Health pane's
 * richer actions (copy JSON / copy text / suppress a flag) so its toolbar is not silent here.
 */
function handleHostMessage(msg: unknown): void {
  const data = msg as {
    type?: string;
    file?: string;
    line?: number;
    flag?: string;
    text?: string;
    command?: string;
    engine?: HeavyEngine;
  };
  switch (data.type) {
    case 'openFile':
      if (typeof data.file === 'string' && lastRoot) {
        void openFileAtLine(lastRoot, data.file, data.line ?? 1);
      }
      return;
    case 'openCommand':
      if (typeof data.command === 'string' && OPEN_COMMAND_ALLOWLIST.has(data.command)) {
        void vscode.commands.executeCommand(data.command);
      }
      return;
    case 'rescanPane':
      if (data.engine === 'projectMap' || data.engine === 'codeHealth') {
        void rescanPane(data.engine);
      }
      return;
    case 'copyJson':
      void copyCodeHealthJson();
      return;
    case 'copyText':
      void copyText(data.text);
      return;
    case 'suppressFlag':
      if (typeof data.file === 'string' && typeof data.flag === 'string') {
        void applyFileSuppression(data.file, data.flag);
      }
      return;
    default:
      return;
  }
}

/** Opens a report-relative file at [line] (1-based), resolving against the project root. */
async function openFileAtLine(root: string, relativeFile: string, line: number): Promise<void> {
  if (line <= 1) {
    // Project Map row clicks carry no line — reuse the shared opener (preview, line 1).
    await openFileFromReport(root, relativeFile);
    return;
  }
  const target = nodePath.isAbsolute(relativeFile)
    ? relativeFile
    : nodePath.join(root, relativeFile);
  try {
    const doc = await vscode.workspace.openTextDocument(vscode.Uri.file(target));
    const editor = await vscode.window.showTextDocument(doc, { preview: true });
    const pos = new vscode.Position(Math.max(0, line - 1), 0);
    editor.selection = new vscode.Selection(pos, pos);
    editor.revealRange(new vscode.Range(pos, pos), vscode.TextEditorRevealType.InCenter);
  } catch {
    void vscode.window.showWarningMessage(
      l10n('notify.commands.projectMapCouldNotOpen', { file: relativeFile }),
    );
  }
}

async function copyCodeHealthJson(): Promise<void> {
  if (lastCodeHealthStdout.trim().length === 0) {
    void vscode.window.showInformationMessage(l10n('codeHealth.runReportFirst'));
    return;
  }
  await vscode.env.clipboard.writeText(lastCodeHealthStdout);
  void vscode.window.showInformationMessage(l10n('codeHealth.copiedJson'));
}

async function copyText(text: string | undefined): Promise<void> {
  if (typeof text !== 'string' || text.length === 0) return;
  // Bound to 1 MB so a runaway selection can't paste a multi-megabyte string by accident.
  const capped = text.length > 1_000_000 ? text.slice(0, 1_000_000) : text;
  await vscode.env.clipboard.writeText(capped);
}

/** The vendored ECharts webview URI — computable without a scan, so the shell can load it up front. */
function echartsUriString(webview: vscode.Webview): string {
  return webview.asWebviewUri(vscode.Uri.joinPath(extensionUri, 'media', 'echarts.min.js')).toString();
}

/** Pre-built summary-card bodies for the four fast panes. */
export interface ShellSummaries {
  config: string;
  package: string;
  findings: string;
  catalog: string;
}

/**
 * Builds the full launchpad document, set once as the webview HTML. Pure (no webview): the only host
 * values are [cspSource] and [echartsUri], so unit tests can assert the shell contract — six panes,
 * one ECharts loader, one shared API shim, the four summaries embedded, and the two heavy panes in
 * their scanning state — directly. The heavy panes' real content arrives later via `paneReady`.
 */
export function buildShell(
  cspSource: string,
  echartsUri: string,
  summaries: ShellSummaries,
): string {
  const hero = buildDashboardHero({
    title: l10n('dashboards.heroTitle'),
    showFullWidthToggle: false,
  });

  const scanningPm = `<div class="pane-status">${escapeHtml(l10n('dashboards.projectMap.scanning'))}</div>`;
  const scanningCh = `<div class="pane-status">${escapeHtml(l10n('dashboards.codeHealth.scanning'))}</div>`;

  const panes =
    heavyPane('projectMap', l10n('dashboards.pane.projectMap'),
      'saropaLints.openProjectHealthDashboard', scanningPm) +
    heavyPane('codeHealth', l10n('dashboards.pane.codeHealth'),
      'saropaLints.openProjectVibrancyReport', scanningCh) +
    lightPane('findings', l10n('dashboards.pane.findings'),
      SUMMARY_OPEN_COMMANDS.findings, summaries.findings) +
    lightPane('lintsConfig', l10n('dashboards.pane.lintsConfig'),
      SUMMARY_OPEN_COMMANDS.lintsConfig, summaries.config) +
    lightPane('package', l10n('dashboards.pane.package'),
      SUMMARY_OPEN_COMMANDS.package, summaries.package) +
    lightPane('commandCatalog', l10n('dashboards.pane.commandCatalog'),
      SUMMARY_OPEN_COMMANDS.commandCatalog, summaries.catalog);

  // Localized strings the client needs at message time (scanning / failed / retry), kept host-side.
  const clientStrings = JSON.stringify({
    scanning: {
      projectMap: l10n('dashboards.projectMap.scanning'),
      codeHealth: l10n('dashboards.codeHealth.scanning'),
    },
    paneFailed: l10n('dashboards.paneFailed'),
    retry: l10n('dashboards.retry'),
  });

  // 'unsafe-inline' (scripts): the host shim + each embedded engine's inline script run inline; no
  // nonce so one policy covers them all. 'unsafe-inline' (styles): Code Health pills + Project Map
  // cells set color via inline style attributes, and the client injects Project Map's `<style>`.
  // ${cspSource} (scripts): the vendored ECharts file in media/.
  const csp =
    `default-src 'none'; img-src ${cspSource} data:; ` +
    `style-src ${cspSource} 'unsafe-inline'; script-src ${cspSource} 'unsafe-inline';`;

  return `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta http-equiv="Content-Security-Policy" content="${csp}">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Saropa Dashboards</title>
  <style>${getProjectVibrancyReportStyles()}${getKeyboardShortcutsStyles()}${hostStyles()}${pmPaneThemeTokens()}${pmPaneHostFixups()}</style>
  <script src="${echartsUri}"></script>
</head>
<body>
  <header>${hero}</header>
  <main class="dash-grid">${panes}</main>
  <script>window.SD = ${clientStrings};</script>
  <script>${clientScript()}</script>
</body>
</html>`;
}

/** A heavy pane: title + rescan + "Open full screen" in the head; a scanning placeholder body. */
function heavyPane(engine: HeavyEngine, title: string, command: string, body: string): string {
  return paneShell(engine, title, command, body, true);
}

/** A light pane: title + "Open full screen" in the head; a live summary card body. */
function lightPane(engine: string, title: string, command: string, body: string): string {
  return paneShell(engine, title, command, body, false);
}

/** One dashboard pane: a titled card with a rescan (heavy only) + deep-link, and a patchable body. */
function paneShell(
  engine: string,
  title: string,
  command: string,
  body: string,
  rescan: boolean,
): string {
  const rescanBtn = rescan
    ? `<button type="button" class="icon-btn" data-rescan="${escapeHtml(engine)}" ` +
      `title="${escapeHtml(l10n('dashboards.rescan'))}" aria-label="${escapeHtml(l10n('dashboards.rescan'))}">⟳</button>`
    : '';
  const openBtn =
    `<button type="button" class="btn btn-sm" data-command="${escapeHtml(command)}">` +
    `${escapeHtml(l10n('dashboards.openFull'))}</button>`;
  return `<section class="dash-pane">
    <div class="pane-head"><h2>${escapeHtml(title)}</h2><div class="pane-actions">${rescanBtn}${openBtn}</div></div>
    <div class="pane-body" id="paneBody-${escapeHtml(engine)}">${body}</div>
  </section>`;
}

/** Host layout: the responsive grid, pane chrome, and summary-card styling on the shared tokens. */
function hostStyles(): string {
  return `
.dash-grid {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: var(--space-4, 16px);
  align-items: start;
}
@media (max-width: 1100px) { .dash-grid { grid-template-columns: 1fr; } }
.dash-pane {
  display: flex;
  flex-direction: column;
  border: 1px solid var(--border, var(--vscode-widget-border));
  border-radius: var(--radius-lg, 12px);
  background: var(--surface-1, var(--vscode-editorWidget-background));
  overflow: hidden;
  min-width: 0;
}
.pane-head {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: var(--space-2, 8px);
  padding: var(--space-2, 8px) var(--space-3, 12px);
  border-bottom: 1px solid var(--border, var(--vscode-widget-border));
  background: var(--surface-2, var(--vscode-editor-inactiveSelectionBackground));
}
.pane-head h2 { margin: 0; font-size: var(--text-h3, 1.05rem); }
.pane-actions { display: flex; align-items: center; gap: var(--space-2, 8px); }
.icon-btn {
  border: 1px solid var(--border, var(--vscode-widget-border));
  background: transparent;
  color: var(--muted, var(--vscode-descriptionForeground));
  border-radius: var(--radius-sm, 6px);
  cursor: pointer;
  width: 26px; height: 26px;
  line-height: 1;
  font-size: 14px;
}
.icon-btn:hover { color: var(--vscode-foreground); background: var(--surface-1, var(--vscode-editorWidget-background)); }
.btn-sm { padding: 2px 10px; font-size: 0.85rem; }
.pane-body { padding: var(--space-3, 12px); min-width: 0; overflow-x: auto; }
.pane-status {
  display: flex; align-items: center; justify-content: center;
  gap: var(--space-2, 8px);
  min-height: 180px; color: var(--muted, var(--vscode-descriptionForeground));
  text-align: center;
}
.pane-failed { color: var(--accent-error, var(--vscode-errorForeground)); flex-direction: column; }
.summary-grid {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(110px, 1fr));
  gap: var(--space-3, 12px);
}
.metric {
  display: flex;
  flex-direction: column;
  gap: 2px;
  padding: var(--space-3, 12px);
  border: 1px solid var(--border, var(--vscode-widget-border));
  border-radius: var(--radius-md, 8px);
  background: var(--surface-2, var(--vscode-editor-inactiveSelectionBackground));
}
.metric-value { font-size: 1.5rem; font-weight: 600; font-variant-numeric: tabular-nums; line-height: 1.1; }
.metric-label { font-size: 0.8rem; color: var(--muted, var(--vscode-descriptionForeground)); }
.metric-warn .metric-value { color: var(--accent-warning, var(--vscode-editorWarning-foreground)); }
.metric-bad .metric-value { color: var(--accent-error, var(--vscode-errorForeground)); }
.summary-empty { color: var(--muted, var(--vscode-descriptionForeground)); margin: 0; padding: var(--space-3, 12px) 0; }
`;
}

/**
 * Project Map's `.pm-pane` fills the viewport in its standalone export (`min-height: 100vh`); inside
 * a grid cell that would force the pane absurdly tall, so the host collapses it back to content
 * height. Scoped to the consolidated pane only, leaving the standalone export untouched.
 */
function pmPaneHostFixups(): string {
  return `.dash-pane .pm-pane { min-height: 0; }
.dash-pane .pm-pane .page { padding: 0; }
.dash-pane .pm-pane .banner { position: static; margin: 0 0 16px; }`;
}

/**
 * The single client script. Acquires + re-exposes the one `acquireVsCodeApi` handle, delegates
 * deep-link / rescan clicks to the host, and patches each heavy pane when its `paneReady`,
 * `paneLoading`, or `paneError` message arrives. Injected scripts must be re-created as real
 * `<script>` elements — markup set via innerHTML does not execute its scripts. Project Map's
 * `<style>` is inserted verbatim (it is already a `<style>` element), never re-wrapped.
 */
function clientScript(): string {
  return `
(function () {
  var api = acquireVsCodeApi();
  window.acquireVsCodeApi = function () { return api; };
  var SD = window.SD || { scanning: {}, paneFailed: 'Scan failed.', retry: 'Retry' };

  document.addEventListener('click', function (e) {
    var openEl = e.target.closest && e.target.closest('[data-command]');
    if (openEl) { api.postMessage({ type: 'openCommand', command: openEl.getAttribute('data-command') }); return; }
    var rescanEl = e.target.closest && e.target.closest('[data-rescan]');
    if (rescanEl) { api.postMessage({ type: 'rescanPane', engine: rescanEl.getAttribute('data-rescan') }); return; }
  });

  function paneBody(engine) { return document.getElementById('paneBody-' + engine); }

  function showScanning(engine) {
    var el = paneBody(engine);
    if (!el) return;
    var div = document.createElement('div');
    div.className = 'pane-status';
    div.textContent = (SD.scanning && SD.scanning[engine]) || '';
    el.replaceChildren(div);
  }

  function showError(engine) {
    var el = paneBody(engine);
    if (!el) return;
    var wrap = document.createElement('div');
    wrap.className = 'pane-status pane-failed';
    var msg = document.createElement('span');
    msg.textContent = SD.paneFailed;
    var btn = document.createElement('button');
    btn.type = 'button';
    btn.className = 'btn';
    btn.setAttribute('data-rescan', engine);
    btn.textContent = SD.retry;
    wrap.replaceChildren(msg, btn);
    el.replaceChildren(wrap);
  }

  function applyPane(engine, style, body, script) {
    var el = paneBody(engine);
    if (!el) return;
    // Project Map ships its own complete <style> element — insert verbatim so it is parsed as CSS,
    // never re-wrapped (the double-wrap bug spilled the tokens onto the page as visible text).
    if (style) { document.head.insertAdjacentHTML('beforeend', style); }
    el.innerHTML = body;
    // innerHTML does not run <script>; re-create the engine script so it executes (ECharts is
    // already loaded in the head, and acquireVsCodeApi is shimmed above).
    if (script) {
      var s = document.createElement('script');
      s.textContent = script;
      el.appendChild(s);
    }
  }

  window.addEventListener('message', function (e) {
    var m = e.data || {};
    if (m.type === 'paneReady') { applyPane(m.engine, m.style, m.body, m.script); }
    else if (m.type === 'paneLoading') { showScanning(m.engine); }
    else if (m.type === 'paneError') { showError(m.engine); }
  });
})();
`;
}

function escapeHtml(text: string): string {
  return text
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;');
}
