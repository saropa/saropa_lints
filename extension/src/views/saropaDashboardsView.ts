/**
 * Consolidated "Saropa Dashboards" webview: shows the Project Map and Code Health dashboards
 * together on one page, side by side, with each screen's FULL interactive content preserved.
 *
 * Each engine renders inside its own `<iframe srcdoc>` so its existing HTML — ECharts treemap /
 * scatter / hot-spots for Project Map, the score gauge / sortable function table for Code Health —
 * embeds byte-for-byte with no id renaming and no script surgery. An iframe is an isolated document,
 * which avoids the two hazards of dropping both full reports into one page: the once-per-document
 * `acquireVsCodeApi()` limit and DOM id collisions.
 *
 * The only glue is a message bridge: each iframe gets a tiny `acquireVsCodeApi` shim that bubbles its
 * drill-down messages up to this host (tagged with `__src`); a host-level relay forwards them to the
 * extension, and routes scan events / commands back down into the right iframe.
 *
 * This is additive — the standalone `saropaLints.openProjectHealthDashboard` and Code Health commands
 * are unchanged; this is a third entry that composes them.
 *
 * Phase 1 (this file) wires the host shell + the Project Map pane. The Code Health pane is added in
 * Phase 2.
 */
import * as vscode from 'vscode';
import { getProjectRoot } from '../projectRoot';
import { hasSaropaLintsDep } from '../pubspecReader';
import { l10n } from '../i18n/runtime';
import { getDashboardChromeStyles } from './dashboardChromeStyles';
import { buildDashboardHero } from './dashboardHero';
import {
  openFileFromReport,
  scanProjectMapToHtml,
} from './projectMapView';

let panel: vscode.WebviewPanel | undefined;
let extensionUri: vscode.Uri;
let inflight = false;
let lastRoot: string | undefined; // resolves relative paths from iframe drill-downs

/** Registers the `Saropa Dashboards` command; call once at activation. */
export function registerSaropaDashboardsCommand(context: vscode.ExtensionContext): void {
  extensionUri = context.extensionUri;
  context.subscriptions.push(
    vscode.commands.registerCommand('saropaLints.openDashboards', () => openDashboards()),
  );
}

function openDashboards(): void {
  const root = getProjectRoot();
  if (!root) {
    void vscode.window.showErrorMessage(l10n('notify.commands.projectMapNoProject'));
    return;
  }
  if (!hasSaropaLintsDep(root)) {
    void vscode.window.showErrorMessage(l10n('notify.commands.projectMapMissingDep'));
    return;
  }
  lastRoot = root;
  const p = getOrCreatePanel();
  p.webview.html = buildHostHtml(p.webview);
  p.reveal(vscode.ViewColumn.One);
  // Kick off the Project Map pane's scan; its HTML streams into the iframe when ready.
  if (!inflight) {
    inflight = true;
    void loadProjectMapPane(root, p).finally(() => {
      inflight = false;
    });
  }
}

/** Runs the Project Map scan and pushes its embeddable HTML into the pane's iframe. */
async function loadProjectMapPane(root: string, p: vscode.WebviewPanel): Promise<void> {
  const html = await vscode.window.withProgress(
    {
      location: vscode.ProgressLocation.Notification,
      title: l10n('dashboards.projectMap.scanning'),
      cancellable: true,
    },
    (_progress, token) => scanProjectMapToHtml(root, p.webview, extensionUri, token),
  );
  if (!html) {
    // Panel may have been disposed mid-scan, or the scan failed (its own error toast fired).
    void p.webview.postMessage({ type: 'pmFailed' });
    return;
  }
  // Embed with the drill-down shim so the report's row clicks reach this host.
  void p.webview.postMessage({ type: 'pmContent', html: injectIframeBridge(html, 'projectMap') });
}

/**
 * Injects a tiny `acquireVsCodeApi` shim into an engine's HTML so that, inside an iframe (where the
 * real API is absent), its `postMessage` calls bubble to the parent host tagged with [source]. The
 * engine HTML is otherwise untouched. Inserted before `</head>` so it is defined before the engine's
 * body scripts run and is governed by the document's own CSP (which permits inline scripts).
 */
export function injectIframeBridge(html: string, source: string): string {
  const shim = `<script>
(function () {
  var api = {
    postMessage: function (m) {
      parent.postMessage(Object.assign({ __src: '${source}' }, m), '*');
    },
    getState: function () { return undefined; },
    setState: function () {},
  };
  window.acquireVsCodeApi = function () { return api; };
})();
</script>`;
  return html.replace('</head>', `${shim}</head>`);
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
      // The Project Map iframe loads the vendored ECharts from media/; child frames inherit the
      // host's resource roots.
      localResourceRoots: [vscode.Uri.joinPath(extensionUri, 'media')],
    },
  );
  panel.onDidDispose(() => {
    panel = undefined;
  });
  panel.webview.onDidReceiveMessage((msg: unknown) => handleHostMessage(msg));
  return panel;
}

/** Routes messages bubbled up from the panes' iframes (and the host's own chrome buttons). */
function handleHostMessage(msg: unknown): void {
  const data = msg as { __src?: string; type?: string; file?: string };
  // Project Map row-click drill-down → open the file, exactly as the standalone panel does.
  if (data.__src === 'projectMap' && data.type === 'openFile' && typeof data.file === 'string' && lastRoot) {
    void openFileFromReport(lastRoot, data.file);
    return;
  }
  // "Open full screen" on a pane header opens that engine's standalone panel.
  if (data.type === 'openProjectMapFull') {
    void vscode.commands.executeCommand('saropaLints.openProjectHealthDashboard');
    return;
  }
}

/** The host shell document: shared chrome + a responsive two-pane grid + the message-relay script. */
function buildHostHtml(webview: vscode.Webview): string {
  const cspSource = webview.cspSource;
  // frame-src 'self' permits the per-pane srcdoc iframes; inline allowances match the embedded
  // engine reports, which are inline-heavy.
  const csp =
    `default-src 'none'; frame-src 'self'; img-src ${cspSource} data:; ` +
    `style-src ${cspSource} 'unsafe-inline'; script-src ${cspSource} 'unsafe-inline';`;
  const hero = buildDashboardHero({
    title: l10n('dashboards.heroTitle'),
    showFullWidthToggle: false,
  });
  return `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta http-equiv="Content-Security-Policy" content="${csp}">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Saropa Dashboards</title>
  <style>${getDashboardChromeStyles()}${hostStyles()}</style>
</head>
<body>
  <header>${hero}</header>
  <main class="dash-grid">
    <section class="dash-pane">
      <div class="pane-head">
        <h2>${escapeHtml(l10n('dashboards.pane.projectMap'))}</h2>
        <button type="button" class="btn" id="pmOpenFull">${escapeHtml(l10n('dashboards.openFull'))}</button>
      </div>
      <div class="pane-body">
        <div id="pmLoading" class="pane-loading">${escapeHtml(l10n('dashboards.projectMap.scanning'))}</div>
        <iframe id="pmFrame" class="pane-frame" title="${escapeHtml(l10n('dashboards.pane.projectMap'))}"></iframe>
      </div>
    </section>
  </main>
  <script>${bridgeScript()}</script>
</body>
</html>`;
}

/** Host-specific layout on top of the shared chrome: the two-pane responsive grid. */
function hostStyles(): string {
  return `
.dash-grid {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: var(--space-4);
}
@media (max-width: 980px) { .dash-grid { grid-template-columns: 1fr; } }
.dash-pane {
  display: flex;
  flex-direction: column;
  min-height: 72vh;
  border: 1px solid var(--border);
  border-radius: var(--radius-lg);
  background: var(--surface-1);
  overflow: hidden;
}
.pane-head {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: var(--space-2);
  padding: var(--space-2) var(--space-3);
  border-bottom: 1px solid var(--border);
  background: var(--surface-2);
}
.pane-head h2 { margin: 0; font-size: var(--text-h3); }
.pane-body { position: relative; flex: 1 1 auto; min-height: 0; }
.pane-frame { width: 100%; height: 100%; border: 0; display: block; background: var(--surface-1); }
.pane-loading {
  position: absolute; inset: 0;
  display: flex; align-items: center; justify-content: center;
  color: var(--muted);
}
.pane-failed { color: var(--accent-error); }
`;
}

/**
 * Host relay. Owns the single `acquireVsCodeApi()`. Bubbled iframe messages (tagged `__src`) are
 * forwarded to the extension; `pmContent` from the extension is written into the pane's iframe.
 */
function bridgeScript(): string {
  return `
(function () {
  var vscode = acquireVsCodeApi();
  var pmFrame = document.getElementById('pmFrame');
  var pmLoading = document.getElementById('pmLoading');
  window.addEventListener('message', function (e) {
    var d = e.data || {};
    // Bubbled up from a pane iframe — forward to the extension.
    if (d.__src) { vscode.postMessage(d); return; }
    // From the extension: the Project Map report is ready — embed it.
    if (d.type === 'pmContent') {
      pmFrame.srcdoc = d.html;
      if (pmLoading) { pmLoading.style.display = 'none'; }
      return;
    }
    if (d.type === 'pmFailed') {
      if (pmLoading) { pmLoading.textContent = ''; pmLoading.className = 'pane-loading pane-failed'; }
      return;
    }
  });
  var openFull = document.getElementById('pmOpenFull');
  if (openFull) {
    openFull.addEventListener('click', function () {
      vscode.postMessage({ type: 'openProjectMapFull' });
    });
  }
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
