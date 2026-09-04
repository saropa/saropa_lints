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
import {
  buildDoneMapPaneHtml,
  buildScanningMapPaneHtml,
  buildShellHtml,
} from './projectMapShell';
import {
  buildReportsTabHtml,
  handleReportsPanelMessage,
  type ReportRunControl,
} from './projectMapReports';
import { l10n } from '../i18n/runtime';
import { saropaLintsDataPath } from '../reportsPaths';

let panel: vscode.WebviewPanel | undefined;
let extensionUri: vscode.Uri;
let inflight: Promise<void> | undefined;
let lastRoot: string | undefined; // resolves relative paths from row clicks
// Live cancel handle for the in-flight Project Map scan shown in the webview's
// own scanning state (replaces the old vscode.window.withProgress notification
// token — the scan's stop/cancel affordance now lives in the panel itself, per
// design principle 6 "Live or gone").
let scanCancelSource: vscode.CancellationTokenSource | undefined;
// One CLI process per report card id, keyed so a card's own Run/Cancel only
// affects that card. See projectMapReports.ts for the run/stream mechanism.
const reportControls = new Map<string, ReportRunControl>();
// Monotonic epoch: a Restart from the scanning view must not let a stale scan's
// completion clobber a newer one's rendered fragment (same guard shape as
// projectVibrancyReportView's scanEpoch).
let scanEpoch = 0;

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

/**
 * Opens the panel immediately in its live scanning state (spinner + elapsed
 * timer + a streamed activity log of any stdout/stderr the CLI emits), runs
 * the scan, then swaps in the finished report — replacing the old
 * `vscode.window.withProgress` notification, which rendered nothing in the
 * panel until the whole scan finished (a "screenshot, not a dashboard" per
 * design principle 6). `project_health.dart` has no `--progress` NDJSON
 * protocol the way `project_vibrancy` does (verified: no `--progress` flag in
 * bin/project_health.dart), so this cannot show a percentage bar the way Code
 * Health does — but the panel is live from the first click, streams whatever
 * the process actually prints, and its Cancel button works against a real
 * process kill instead of a notification token.
 */
async function runAndRender(root: string): Promise<void> {
  lastRoot = root;
  const epoch = ++scanEpoch;
  const p = getOrCreatePanel();
  p.webview.html = buildShellHtml(p.webview, buildScanningMapPaneHtml(), buildReportsTabHtml());
  p.reveal(vscode.ViewColumn.One);
  await runStreamingScan(root, p, epoch);
}

/** Runs the scan for [epoch], streaming raw output lines into the already-open scanning pane. */
async function runStreamingScan(
  root: string,
  p: vscode.WebviewPanel,
  epoch: number,
): Promise<void> {
  // Shared helper builds the `reports/.saropa_lints` prefix; append the view-specific subdir.
  const outputDir = path.join(saropaLintsDataPath(root), 'health');
  scanCancelSource?.dispose();
  scanCancelSource = new vscode.CancellationTokenSource();
  const ok = await runScan(root, outputDir, scanCancelSource.token, (line, stream) => {
    if (epoch !== scanEpoch) return; // superseded by a Restart — drop stale output
    void p.webview.postMessage({ type: 'mapLog', text: line, stream });
  });
  if (epoch !== scanEpoch) return; // a newer scan (Restart) already owns the panel
  if (!ok) {
    void p.webview.postMessage({ type: 'mapStopped' });
    return;
  }
  const indexPath = path.join(outputDir, 'index.html');
  if (!fs.existsSync(indexPath)) {
    void vscode.window.showWarningMessage(l10n('notify.commands.projectMapNoHtml'));
    void p.webview.postMessage({ type: 'mapStopped' });
    return;
  }
  const raw = fs.readFileSync(indexPath, 'utf8');
  // Extract just the report's fragment (style/body/script) rather than a full
  // standalone document — the panel now owns one <head>/<body>/CSP for both
  // tabs, mirroring how the consolidated dashboard already embeds this same
  // report (scanProjectMapToParts) instead of nesting a second <html>.
  const parts = extractProjectMapParts(raw, p.webview, extensionUri);
  if (!parts) {
    void vscode.window.showWarningMessage(l10n('notify.commands.projectMapNoHtml'));
    void p.webview.postMessage({ type: 'mapStopped' });
    return;
  }
  p.webview.html = buildShellHtml(
    p.webview,
    buildDoneMapPaneHtml(parts),
    buildReportsTabHtml(),
  );
}

/** Cancels the in-flight scan (if any) and starts a fresh one in the same panel. */
async function restartScan(): Promise<void> {
  if (!panel || !lastRoot) return;
  scanCancelSource?.cancel();
  const epoch = ++scanEpoch;
  panel.webview.html = buildShellHtml(panel.webview, buildScanningMapPaneHtml(), buildReportsTabHtml());
  await runStreamingScan(lastRoot, panel, epoch);
}

/**
 * Spawns the scan asynchronously so the extension host never blocks.
 * [onOutputLine], when given, streams each stdout/stderr line as it arrives —
 * the mechanism [runStreamingScan] uses to keep the panel live. Optional so
 * `scanProjectMapToParts` (the consolidated dashboard's embed path) keeps its
 * original buffered behavior unchanged.
 */
function runScan(
  root: string,
  outputDir: string,
  token: vscode.CancellationToken,
  onOutputLine?: (line: string, stream: 'stdout' | 'stderr') => void,
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
    // Buffers an incomplete trailing line between chunks so streamed output
    // never splits mid-word — same shape as projectMapReports.ts's runner.
    let stdoutBuf = '';
    let stderrBuf = '';
    const flush = (buf: string, chunk: string, stream: 'stdout' | 'stderr'): string => {
      const combined = buf + chunk;
      const lines = combined.split('\n');
      const remainder = lines.pop() ?? '';
      for (const line of lines) onOutputLine?.(line.replace(/\r$/, ''), stream);
      return remainder;
    };
    child.stdout.on('data', (d: Buffer) => {
      stdoutBuf = flush(stdoutBuf, d.toString(), 'stdout');
    });
    child.stderr.on('data', (d: Buffer) => {
      stderr += d.toString();
      stderrBuf = flush(stderrBuf, d.toString(), 'stderr');
    });
    // Tree-kill on cancel — shell:true means child is cmd.exe; child.kill()
    // alone orphans the dart grandchild (runaway scan).
    token.onCancellationRequested(() => killProcessTree(child));
    child.on('error', (e: Error) => {
      void vscode.window.showErrorMessage(l10n('notify.commands.projectMapFailed', { message: e.message }));
      resolve(false);
    });
    child.on('close', (code: number | null) => {
      if (stdoutBuf.length > 0) onOutputLine?.(stdoutBuf, 'stdout');
      if (stderrBuf.length > 0) onOutputLine?.(stderrBuf, 'stderr');
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

/**
 * Applies the in-editor transforms to a raw `project_health --format html` document: swaps the CDN
 * ECharts `<script>` for the vendored copy (webviews have no network), injects a CSP that permits
 * the vendored script + the report's inline data/style, and rebinds the report's palette tokens to
 * the host theme. Returns a self-contained HTML document usable either as `webview.html` (the
 * standalone Project Map panel) or as an `<iframe srcdoc>` inside the consolidated dashboard.
 *
 * Exported so the consolidated "Saropa Dashboards" view can embed the EXACT same interactive report
 * (treemap, scatter, hot-spots) without re-deriving these transforms or rebuilding the engine.
 *
 * NOTE (2026-09-04, Phase 6): the standalone panel no longer calls this — it now composes the
 * `dashboardChromeStyles`-based shell (see projectMapShell.ts) via [extractProjectMapParts] instead
 * of swapping in a full second `<html>` document. Left in place (still exported, still exercised by
 * nothing that requires deleting it this phase) rather than removed, since deleting an exported
 * helper is a bigger call than a feature phase should make unilaterally — see the plan doc's
 * "Deferred" note for Phase 6.
 */
export function transformProjectMapHtml(
  raw: string,
  webview: vscode.Webview,
  extUri: vscode.Uri,
): string {
  const echartsUri = webview.asWebviewUri(
    vscode.Uri.joinPath(extUri, 'media', 'echarts.min.js'),
  );
  let html = raw.replace(
    /<script src="https:\/\/cdn[^"]*"><\/script>/,
    `<script src="${echartsUri.toString()}"></script>`,
  );
  // Webview CSP: allow the vendored script + the report's inline data/style.
  const csp =
    `<meta http-equiv="Content-Security-Policy" content="default-src 'none'; ` +
    `img-src ${webview.cspSource} data:; ` +
    `style-src ${webview.cspSource} 'unsafe-inline'; ` +
    `script-src ${webview.cspSource} 'unsafe-inline';">`;
  html = html.replace('<head>', `<head>${csp}`);
  // Theme-awareness (SAROPA_DASHBOARD_STYLE_GUIDE dual-binding): the standalone export ships a fixed
  // brand palette since a browser/CI file has no host theme; in the editor we rebind those same token
  // names to `--vscode-*`. Injected after the template's <style> (incl. its dark @media) so this
  // :root wins by source order; the brand accent stays fixed.
  return html.replace('</head>', `${webviewThemeOverride()}</head>`);
}

/**
 * The three composable pieces of the Project Map report, extracted from the generated HTML by its
 * `<!--PM_*-->` boundary markers so the consolidated "Saropa Dashboards" view can drop the report
 * into one shared document beside Code Health:
 *
 *   - [styleHtml]  — the `<style>` block. Every rule is scoped under `.pm-pane`, so it cannot leak
 *                    onto the host chrome or the Code Health pane.
 *   - [bodyHtml]   — the `.pm-pane` markup (banner, KPI strip, treemap/scatter chart hosts, the
 *                    hot-spot and gravity tables). Its ids (`treemap`, `filter`, `hot`, …) do not
 *                    collide with Code Health's `pv*` ids.
 *   - [scriptHtml] — the inline data/render `<script>` (NOT the ECharts loader, which the host
 *                    loads once). It calls `acquireVsCodeApi()`, satisfied by the host's shared shim.
 *   - [echartsUri] — the vendored ECharts webview URI the host puts in a single `<script src>`.
 */
export interface ProjectMapParts {
  styleHtml: string;
  bodyHtml: string;
  scriptHtml: string;
  echartsUri: string;
}

const _pmStyleRe = /<!--PM_STYLE_START-->([\s\S]*?)<!--PM_STYLE_END-->/;
const _pmBodyRe = /<!--PM_BODY_START-->([\s\S]*?)<!--PM_BODY_END-->/;
const _pmScriptRe = /<!--PM_SCRIPT_START-->([\s\S]*?)<!--PM_SCRIPT_END-->/;

/**
 * Extracts the `<!--PM_*-->`-delimited fragment from a raw
 * `project_health --format html` document, or null if the markers are
 * missing (a template/version mismatch — fail closed rather than embed a
 * broken fragment). Shared by [scanProjectMapToParts] (the consolidated
 * dashboard's embed path) and the standalone panel's own live-scan render, so
 * both surfaces parse the SAME report the SAME way.
 */
function extractProjectMapParts(
  raw: string,
  webview: vscode.Webview,
  extUri: vscode.Uri,
): ProjectMapParts | null {
  const style = _pmStyleRe.exec(raw);
  const body = _pmBodyRe.exec(raw);
  const script = _pmScriptRe.exec(raw);
  if (!style || !body || !script) return null;
  const echartsUri = webview.asWebviewUri(
    vscode.Uri.joinPath(extUri, 'media', 'echarts.min.js'),
  );
  return {
    styleHtml: style[1].trim(),
    bodyHtml: body[1].trim(),
    scriptHtml: script[1].trim(),
    echartsUri: echartsUri.toString(),
  };
}

/**
 * Runs the Project Map scan for [root] and returns its composable pieces for the consolidated
 * dashboard, or null if the scan failed, produced no output, or the report is missing its
 * `<!--PM_*-->` markers. [token] cancels the scan (e.g. when the host panel closes). Reuses the
 * SAME scan the standalone panel runs, so both render identical data.
 */
export async function scanProjectMapToParts(
  root: string,
  webview: vscode.Webview,
  extUri: vscode.Uri,
  token: vscode.CancellationToken,
): Promise<ProjectMapParts | null> {
  // Shared helper builds the `reports/.saropa_lints` prefix; append the view-specific subdir.
  const outputDir = path.join(saropaLintsDataPath(root), 'health');
  const ok = await runScan(root, outputDir, token);
  if (!ok) return null;
  const indexPath = path.join(outputDir, 'index.html');
  if (!fs.existsSync(indexPath)) return null;
  const raw = fs.readFileSync(indexPath, 'utf8');
  return extractProjectMapParts(raw, webview, extUri);
}

/**
 * `<style>` that rebinds the Dart report's palette tokens to the host VS Code theme for the
 * in-editor webview. Maps surface/text/border tokens to `--vscode-*` so the HTML chrome
 * (banner, KPI chips, hot-spot table, filters, gravity panel) follows the user's theme; the
 * brand accent, radius, and shadows stay as the template defines them. The ECharts charts read
 * `prefers-color-scheme` (which tracks the theme kind in a webview), so they flip light/dark on
 * their own.
 *
 * The override targets `.pm-pane` — the template now declares its palette tokens on that wrapper
 * (not `:root`) so the consolidated dashboard can host this report beside Code Health without the
 * two stylesheets' `:root` blocks fighting. A `:root` override would be shadowed: a CSS variable
 * resolves from the nearest ancestor that defines it, and `.pm-pane` is nearer than `:root` for
 * every report element. Token names match `health_html_template.dart`'s `.pm-pane` exactly.
 */
function webviewThemeOverride(): string {
  return `<style>${pmPaneThemeTokens()}</style>`;
}

/**
 * The `.pm-pane` palette-token rebind to the host VS Code theme, without the `<style>` wrapper.
 * Exported so the consolidated "Saropa Dashboards" host can apply the SAME rebind to its embedded
 * Project Map pane — otherwise the pane would render in the template's fixed brand palette while the
 * Code Health pane follows the editor theme, and the two panes would not match (the inconsistency the
 * consolidated view exists to remove). The brand accent / radius / shadows stay as the template
 * defines them; only surface/text/border tokens follow the theme.
 */
export function pmPaneThemeTokens(): string {
  return `
.pm-pane {
  --bg: var(--vscode-editor-background);
  --surface: var(--vscode-editorWidget-background);
  --surface-2: var(--vscode-editor-inactiveSelectionBackground);
  --text: var(--vscode-foreground);
  --muted: var(--vscode-descriptionForeground);
  --border: var(--vscode-widget-border);
  --hover: var(--vscode-list-hoverBackground);
  --zebra: color-mix(in srgb, var(--vscode-foreground) 4%, transparent);
}
`;
}

function getOrCreatePanel(): vscode.WebviewPanel {
  if (panel) return panel;
  panel = vscode.window.createWebviewPanel(
    'saropaProjectMap',
    l10n('projectMap.panelTitle'),
    vscode.ViewColumn.One,
    {
      enableScripts: true,
      retainContextWhenHidden: true,
      localResourceRoots: [vscode.Uri.joinPath(extensionUri, 'media')],
    },
  );
  panel.onDidDispose(() => {
    // Closing the panel is an implicit cancel — otherwise the dart scan (or any
    // still-running report card) keeps burning CPU with no visible surface to
    // stop it, the same "runaway scan" failure mode the Code Health dashboard
    // already guards against.
    scanCancelSource?.cancel();
    scanCancelSource = undefined;
    for (const control of reportControls.values()) control.cancel();
    reportControls.clear();
    panel = undefined;
  });
  panel.webview.onDidReceiveMessage((msg: unknown) => {
    void handlePanelMessage(msg);
  });
  return panel;
}

/**
 * Routes every inbound webview message. Project Map's own concerns (file
 * drill-down, scan cancel/restart) are handled inline; Reports-tab concerns
 * delegate to [handleReportsPanelMessage] so the CLI-report logic stays in one
 * module instead of duplicated per dashboard.
 */
async function handlePanelMessage(msg: unknown): Promise<void> {
  const data = msg as { type?: string; file?: string; line?: number; reportId?: string; text?: string };
  if (data.type === 'openFile' && typeof data.file === 'string' && lastRoot) {
    await openFileFromReport(lastRoot, data.file);
    return;
  }
  if (data.type === 'cancelScan') {
    scanCancelSource?.cancel();
    return;
  }
  if (data.type === 'restartScan') {
    await restartScan();
    return;
  }
  if (!panel || !lastRoot) return;
  await handleReportsPanelMessage(data, lastRoot, panel, reportControls);
}

/// Opens a report-relative file path in the editor (drill-down from a row click).
/// Exported so the consolidated dashboard host can resolve Project Map row-click drill-downs the
/// same way the standalone panel does.
export async function openFileFromReport(root: string, relativeFile: string): Promise<void> {
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
