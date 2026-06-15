/**
 * Saropa Project Map dashboard webview. Runs `saropa_lints:project_health --format html`
 * asynchronously (non-blocking, cancellable progress), then renders the report
 * in an in-editor webview — swapping the report's CDN ECharts <script> for the
 * vendored copy in `media/` and adding a webview CSP, so charts render offline.
 *
 * Mirrors the Code Health report's in-flight guard + panel reuse pattern.
 */
import * as cp from 'node:child_process';
import * as fs from 'node:fs';
import * as path from 'node:path';
import * as vscode from 'vscode';
import { getProjectRoot } from '../projectRoot';
import { hasSaropaLintsDep } from '../pubspecReader';
import { killProcessTree, resolveCliCwd } from './devCliRoot';
import { l10n } from '../i18n/runtime';

let panel: vscode.WebviewPanel | undefined;
let extensionUri: vscode.Uri;
let inflight: Promise<void> | undefined;
let lastRoot: string | undefined; // resolves relative paths from row clicks

/** Registers the `Saropa Project Map` command; call once at activation. */
export function registerProjectMapCommand(context: vscode.ExtensionContext): void {
  extensionUri = context.extensionUri;
  context.subscriptions.push(
    vscode.commands.registerCommand('saropaLints.openProjectHealthDashboard', () =>
      openProjectMap(),
    ),
  );
}

function openProjectMap(): Promise<void> {
  if (inflight) {
    panel?.reveal(vscode.ViewColumn.One);
    return inflight; // a scan is already running — share it, don't double-spawn
  }
  const root = getProjectRoot();
  if (!root) {
    void vscode.window.showErrorMessage(l10n('notify.commands.projectMapNoProject'));
    return Promise.resolve();
  }
  if (!hasSaropaLintsDep(root)) {
    void vscode.window.showErrorMessage(
      l10n('notify.commands.projectMapMissingDep'),
    );
    return Promise.resolve();
  }
  inflight = runAndRender(root).finally(() => {
    inflight = undefined;
  });
  return inflight;
}

async function runAndRender(root: string): Promise<void> {
  lastRoot = root;
  const outputDir = path.join(root, 'reports', '.saropa_lints', 'health');
  const ok = await vscode.window.withProgress(
    {
      location: vscode.ProgressLocation.Notification,
      title: 'Saropa Lints: scanning Saropa Project Map…',
      cancellable: true,
    },
    (_progress, token) => runScan(root, outputDir, token),
  );
  if (!ok) return;
  const indexPath = path.join(outputDir, 'index.html');
  if (!fs.existsSync(indexPath)) {
    void vscode.window.showWarningMessage(l10n('notify.commands.projectMapNoHtml'));
    return;
  }
  renderPanel(indexPath);
}

/** Spawns the scan asynchronously so the extension host never blocks. */
function runScan(
  root: string,
  outputDir: string,
  token: vscode.CancellationToken,
): Promise<boolean> {
  return new Promise((resolve) => {
    const child = cp.spawn(
      'dart',
      [
        'run',
        'saropa_lints:project_health',
        '--path',
        root,
        '--complexity',
        '--git',
        // Per-feature performance gravity panel (compound widget patterns).
        '--performance',
        '--format',
        'html',
        '--output-dir',
        outputDir,
        // Re-parse only changed files on rescans (the project_health cache).
        '--cache',
      ],
      // resolveCliCwd: under F5 the in-repo CLI runs (it HAS project_health;
      // the project's published saropa_lints does not, which caused exit 255).
      { cwd: resolveCliCwd(root), shell: true },
    );
    let stderr = '';
    child.stderr.on('data', (d: Buffer) => (stderr += d.toString()));
    // Tree-kill on cancel — shell:true means child is cmd.exe; child.kill()
    // alone orphans the dart grandchild (runaway scan).
    token.onCancellationRequested(() => killProcessTree(child));
    child.on('error', (e: Error) => {
      void vscode.window.showErrorMessage(l10n('notify.commands.projectMapFailed', { message: e.message }));
      resolve(false);
    });
    child.on('close', (code: number | null) => {
      if (code !== 0) {
        const first = stderr.split('\n').find((l) => l.trim().length > 0) ?? '';
        void vscode.window.showErrorMessage(l10n('notify.commands.projectMapScanFailed', { code: String(code), details: first }));
        resolve(false);
        return;
      }
      resolve(true);
    });
  });
}

function renderPanel(indexPath: string): void {
  const p = getOrCreatePanel();
  const echartsUri = p.webview.asWebviewUri(
    vscode.Uri.joinPath(extensionUri, 'media', 'echarts.min.js'),
  );
  let html = fs.readFileSync(indexPath, 'utf8');
  // Swap the CDN ECharts for the vendored copy (webviews have no network).
  html = html.replace(
    /<script src="https:\/\/cdn[^"]*"><\/script>/,
    `<script src="${echartsUri.toString()}"></script>`,
  );
  // Webview CSP: allow the vendored script + the report's inline data/style.
  const csp =
    `<meta http-equiv="Content-Security-Policy" content="default-src 'none'; ` +
    `img-src ${p.webview.cspSource} data:; ` +
    `style-src ${p.webview.cspSource} 'unsafe-inline'; ` +
    `script-src ${p.webview.cspSource} 'unsafe-inline';">`;
  html = html.replace('<head>', `<head>${csp}`);
  // Theme-awareness (SAROPA_DASHBOARD_STYLE_GUIDE dual-binding): the standalone
  // export ships a fixed brand palette (the guide's fallback) since a browser/CI
  // file has no host theme. In the editor we rebind those same token names to the
  // host `--vscode-*` tokens so Project Map tracks the user's light/dark/high-contrast
  // theme like every other dashboard. Injected after the template's <style> (incl. its
  // dark @media), so this :root wins by source order; the brand accent stays fixed.
  html = html.replace('</head>', `${webviewThemeOverride()}</head>`);
  p.webview.html = html;
  p.reveal(vscode.ViewColumn.One);
}

/**
 * `<style>` that rebinds the Dart report's palette tokens to the host VS Code theme for the
 * in-editor webview. Maps surface/text/border tokens to `--vscode-*` so the HTML chrome
 * (banner, KPI chips, hot-spot table, filters, gravity panel) follows the user's theme; the
 * brand accent, radius, and shadows stay as the template defines them. The ECharts charts read
 * `prefers-color-scheme` (which tracks the theme kind in a webview), so they flip light/dark on
 * their own. Token names match `health_html_template.dart`'s `:root` exactly.
 */
function webviewThemeOverride(): string {
  return `<style>
:root {
  --bg: var(--vscode-editor-background);
  --surface: var(--vscode-editorWidget-background);
  --surface-2: var(--vscode-editor-inactiveSelectionBackground);
  --text: var(--vscode-foreground);
  --muted: var(--vscode-descriptionForeground);
  --border: var(--vscode-widget-border);
  --hover: var(--vscode-list-hoverBackground);
  --zebra: color-mix(in srgb, var(--vscode-foreground) 4%, transparent);
}
</style>`;
}

function getOrCreatePanel(): vscode.WebviewPanel {
  if (panel) return panel;
  panel = vscode.window.createWebviewPanel(
    'saropaProjectMap',
    'Saropa Project Map',
    vscode.ViewColumn.One,
    {
      enableScripts: true,
      retainContextWhenHidden: true,
      localResourceRoots: [vscode.Uri.joinPath(extensionUri, 'media')],
    },
  );
  panel.onDidDispose(() => {
    panel = undefined;
  });
  panel.webview.onDidReceiveMessage((msg: unknown) => {
    const data = msg as { type?: string; file?: string };
    if (data.type === 'openFile' && typeof data.file === 'string' && lastRoot) {
      void openFileFromReport(lastRoot, data.file);
    }
  });
  return panel;
}

/// Opens a report-relative file path in the editor (drill-down from a row click).
async function openFileFromReport(root: string, relativeFile: string): Promise<void> {
  const target = path.isAbsolute(relativeFile)
    ? relativeFile
    : path.join(root, relativeFile);
  try {
    const doc = await vscode.workspace.openTextDocument(vscode.Uri.file(target));
    await vscode.window.showTextDocument(doc, { preview: true });
  } catch {
    void vscode.window.showWarningMessage(l10n('notify.commands.projectMapCouldNotOpen', { file: relativeFile }));
  }
}
