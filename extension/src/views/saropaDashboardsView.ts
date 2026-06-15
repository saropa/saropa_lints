/**
 * Consolidated "Saropa Dashboards" webview: shows the Project Map and Code Health dashboards
 * together on ONE page, side by side, with each screen's full interactive content preserved — the
 * ECharts treemap / churn-complexity scatter / hot-spot table from Project Map, and the score
 * status line, KPI preset filters, and sortable function table from Code Health.
 *
 * It is a single composed document, NOT an iframe per pane. Both engines' real markup, styles, and
 * scripts are assembled into one webview document. Two hazards make naive composition fail, and
 * each is handled without rewriting either engine:
 *
 *   1. `acquireVsCodeApi()` may be called only ONCE per document. The host acquires the single
 *      handle up front and overrides `window.acquireVsCodeApi` to return that cached handle, so
 *      both engines' scripts (Project Map's inline data script, Code Health's IIFE) get the same
 *      messaging channel.
 *   2. CSS would collide on bare selectors (`body`, `table`, `.chip`, `.panel`) and `:root` tokens.
 *      Project Map's stylesheet is scoped under `.pm-pane` (see health_html_template.dart), so it
 *      cannot leak onto the shared chrome or the Code Health pane. The two engines' DOM ids
 *      (`treemap`/`filter`/`hot` vs `pvTable`/`pvSearch`/…) do not overlap, so a shared document is
 *      safe.
 *
 * ECharts is loaded once in the host `<head>`; both panes' scans run to completion before the page
 * is assembled, so the composed view shows a single loading state rather than each engine's live
 * scan animation (those remain in the standalone panels). Drill-down clicks from either pane post
 * to this host, which opens the file or delegates to the matching standalone command.
 *
 * This is additive — the standalone `saropaLints.openProjectHealthDashboard` and
 * `saropaLints.openProjectVibrancyReport` commands are unchanged; this is a third entry that
 * composes them.
 */
import * as nodePath from 'node:path';
import * as vscode from 'vscode';
import { getProjectRoot } from '../projectRoot';
import { hasSaropaLintsDep } from '../pubspecReader';
import { l10n } from '../i18n/runtime';
import { getProjectVibrancyReportStyles } from './projectVibrancyReportStyles';
import { getKeyboardShortcutsStyles } from './keyboard-shortcuts';
import { buildDashboardHero } from './dashboardHero';
import {
  openFileFromReport,
  pmPaneThemeTokens,
  scanProjectMapToParts,
  type ProjectMapParts,
} from './projectMapView';
import {
  applyFileSuppression,
  buildCodeHealthFragment,
  type CodeHealthFragment,
} from './projectVibrancyReportView';
import { runProjectVibrancyScan } from './projectVibrancyCliRunner';

let panel: vscode.WebviewPanel | undefined;
let extensionUri: vscode.Uri;
let inflight: Promise<void> | undefined;
let lastRoot: string | undefined; // resolves relative drill-down paths from either pane
let lastCodeHealthStdout = ''; // backs the Code Health pane's "Copy JSON" action

/** Registers the `Saropa Dashboards` command; call once at activation. */
export function registerSaropaDashboardsCommand(context: vscode.ExtensionContext): void {
  extensionUri = context.extensionUri;
  context.subscriptions.push(
    vscode.commands.registerCommand('saropaLints.openDashboards', () => openDashboards()),
  );
}

function openDashboards(): Promise<void> {
  if (inflight) {
    panel?.reveal(vscode.ViewColumn.One);
    return inflight; // a scan pair is already running — share it, don't double-spawn
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
  inflight = runAndRender(root).finally(() => {
    inflight = undefined;
  });
  return inflight;
}

/**
 * Renders the loading shell immediately, runs BOTH scans concurrently, then assembles the composed
 * document once both finish. A failed pane renders an inline retry placeholder rather than blocking
 * the other pane — one engine erroring should not blank the whole view.
 */
async function runAndRender(root: string): Promise<void> {
  lastRoot = root;
  const p = getOrCreatePanel();
  p.webview.html = buildLoadingShell(p.webview);
  p.reveal(vscode.ViewColumn.One);
  const [pmParts, chFrag] = await vscode.window.withProgress(
    {
      location: vscode.ProgressLocation.Notification,
      title: l10n('dashboards.heroTitle'),
      cancellable: true,
    },
    (_progress, token) =>
      Promise.all([
        scanProjectMapToParts(root, p.webview, extensionUri, token),
        scanCodeHealthFragment(root, token),
      ]),
  );
  // The panel may have been disposed mid-scan.
  if (!panel) return;
  p.webview.html = buildDashboardsDocument(p.webview.cspSource, pmParts, chFrag);
}

/** Runs the Code Health scan and returns its embeddable fragment, or null on cancel/failure. */
async function scanCodeHealthFragment(
  root: string,
  token: vscode.CancellationToken,
): Promise<CodeHealthFragment | null> {
  const scan = await runProjectVibrancyScan(root, token);
  if (!scan.payload) return null;
  lastCodeHealthStdout = scan.rawStdout;
  // No saved-report-file row in the consolidated pane (reportFilePath omitted) — the standalone
  // Code Health panel owns the persisted-file workflow; "Open full screen" reaches it.
  return buildCodeHealthFragment(scan.payload);
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
  });
  panel.webview.onDidReceiveMessage((msg: unknown) => handleHostMessage(msg));
  return panel;
}

/**
 * Routes messages from both panes' scripts. Open-file drill-downs (Project Map posts `{file}`,
 * Code Health posts `{file, line}`) open the target; the richer Code Health actions are handled
 * here so its toolbar/detail buttons are not silent in the consolidated view.
 */
function handleHostMessage(msg: unknown): void {
  const data = msg as {
    type?: string;
    file?: string;
    line?: number;
    flag?: string;
    text?: string;
  };
  switch (data.type) {
    case 'openFile':
      if (typeof data.file === 'string' && lastRoot) {
        void openFileAtLine(lastRoot, data.file, data.line ?? 1);
      }
      return;
    case 'openProjectMapFull':
      void vscode.commands.executeCommand('saropaLints.openProjectHealthDashboard');
      return;
    case 'openCodeHealthFull':
      void vscode.commands.executeCommand('saropaLints.openProjectVibrancyReport');
      return;
    case 'openProjectVibrancySettings':
      void vscode.commands.executeCommand('saropaLints.openProjectVibrancySettings');
      return;
    case 'rescan':
    case 'restart':
      if (!inflight && lastRoot) {
        inflight = runAndRender(lastRoot).finally(() => {
          inflight = undefined;
        });
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

/** The loading shell shown immediately while both scans run. */
function buildLoadingShell(webview: vscode.Webview): string {
  const hero = buildDashboardHero({ title: l10n('dashboards.heroTitle'), showFullWidthToggle: false });
  const pm = paneShell('projectMap', l10n('dashboards.pane.projectMap'), false,
    `<div class="pane-status">${escapeHtml(l10n('dashboards.projectMap.scanning'))}</div>`);
  const ch = paneShell('codeHealth', l10n('dashboards.pane.codeHealth'), false,
    `<div class="pane-status">${escapeHtml(l10n('dashboards.codeHealth.scanning'))}</div>`);
  return wrapDocument(webview.cspSource, '', '', `<header>${hero}</header><main class="dash-grid">${pm}${ch}</main>`);
}

/**
 * The composed document: shared chrome + scoped Project Map styles + (once) ECharts, a two-pane
 * grid carrying each engine's real markup, and — last in the body so the shared `acquireVsCodeApi`
 * shim runs first — each engine's own script. Pure (no webview): the ECharts URI already lives in
 * [pmParts] and the only host value needed is [cspSource], so unit tests can assert the composition
 * contract (shared API shim, both panes present, Project Map styles scoped) directly.
 */
export function buildDashboardsDocument(
  cspSource: string,
  pmParts: ProjectMapParts | null,
  chFrag: CodeHealthFragment | null,
): string {
  const hero = buildDashboardHero({ title: l10n('dashboards.heroTitle'), showFullWidthToggle: false });
  const pmBody = pmParts
    ? pmParts.bodyHtml
    : `<div class="pane-status pane-failed">${escapeHtml(l10n('dashboards.scanFailed'))}</div>`;
  const chBody = chFrag
    ? chFrag.body
    : `<div class="pane-status pane-failed">${escapeHtml(l10n('dashboards.scanFailed'))}</div>`;
  const pm = paneShell('projectMap', l10n('dashboards.pane.projectMap'), true, pmBody);
  const ch = paneShell('codeHealth', l10n('dashboards.pane.codeHealth'), true, chBody);

  // ECharts loaded once for the Project Map pane; the engine scripts run after the shared-API shim.
  const echarts = pmParts ? `<script src="${pmParts.echartsUri}"></script>` : '';
  // Rebind Project Map's palette tokens to the editor theme (same as the standalone panel) so this
  // pane matches the theme-driven Code Health pane instead of rendering in the fixed brand palette.
  const extraStyle = pmParts
    ? `<style>${pmParts.styleHtml}${pmPaneThemeTokens()}${pmPaneHostFixups()}</style>`
    : '';
  const bodyScripts =
    `<script>${apiShimScript()}</script>` +
    (pmParts ? `<script>${pmParts.scriptHtml}</script>` : '') +
    (chFrag ? `<script>${chFrag.script}</script>` : '');

  return wrapDocument(
    cspSource,
    echarts,
    extraStyle,
    `<header>${hero}</header><main class="dash-grid">${pm}${ch}</main>${bodyScripts}`,
  );
}

/** One dashboard pane: a titled card with an optional "Open full screen" button and a body. */
function paneShell(engine: string, title: string, showOpenFull: boolean, body: string): string {
  const openFullId = engine === 'projectMap' ? 'dashOpenPmFull' : 'dashOpenChFull';
  const openFull = showOpenFull
    ? `<button type="button" class="btn" id="${openFullId}">${escapeHtml(l10n('dashboards.openFull'))}</button>`
    : '';
  return `<section class="dash-pane">
    <div class="pane-head"><h2>${escapeHtml(title)}</h2>${openFull}</div>
    <div class="pane-body">${body}</div>
  </section>`;
}

/** Wraps body content in the full HTML document with the host CSP, chrome styles, and layout. */
function wrapDocument(
  cspSource: string,
  headScripts: string,
  extraStyle: string,
  body: string,
): string {
  // 'unsafe-inline' (scripts): the host shim + both engines' inline scripts run inline; no nonce so
  // a single policy covers all three. 'unsafe-eval' is intentionally absent — nothing here evals.
  // 'unsafe-inline' (styles): Code Health score pills + Project Map cells set colour via inline
  // style attributes. ${cspSource} (scripts): the vendored ECharts file in media/.
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
  <style>${getProjectVibrancyReportStyles()}${getKeyboardShortcutsStyles()}${hostStyles()}</style>
  ${extraStyle}
  ${headScripts}
</head>
<body>
${body}
</body>
</html>`;
}

/** Host layout: the responsive two-pane grid and pane chrome on top of the shared dashboard styles. */
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
.pane-body { padding: var(--space-3, 12px); min-width: 0; overflow-x: auto; }
.pane-status {
  display: flex; align-items: center; justify-content: center;
  min-height: 200px; color: var(--muted, var(--vscode-descriptionForeground));
}
.pane-failed { color: var(--accent-error, var(--vscode-errorForeground)); }
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
 * Acquires the single VS Code API handle and re-exposes it, so both engines' scripts — which each
 * call `acquireVsCodeApi()` — share one messaging channel (the API may be acquired only once per
 * document). Also wires the panes' "Open full screen" buttons.
 */
function apiShimScript(): string {
  return `
(function () {
  var api = acquireVsCodeApi();
  window.acquireVsCodeApi = function () { return api; };
  var pmFull = document.getElementById('dashOpenPmFull');
  if (pmFull) pmFull.addEventListener('click', function () { api.postMessage({ type: 'openProjectMapFull' }); });
  var chFull = document.getElementById('dashOpenChFull');
  if (chFull) chFull.addEventListener('click', function () { api.postMessage({ type: 'openCodeHealthFull' }); });
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
