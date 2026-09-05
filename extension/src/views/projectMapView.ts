/**
 * Saropa Project Map dashboard webview. Runs `saropa_lints:project_health --format html`
 * asynchronously (non-blocking, cancellable progress), then renders the report
 * in an in-editor webview — swapping the report's CDN ECharts <script> for the
 * vendored copy in `media/` and adding a webview CSP, so charts render offline.
 *
 * Mirrors the Code Health report's in-flight guard + panel reuse pattern.
 */
import * as fs from 'node:fs';
import * as path from 'node:path';
import * as vscode from 'vscode';
import { getProjectRoot } from '../projectRoot';
import { hasSaropaLintsDep } from '../pubspecReader';
import { resolveCliCwd } from './devCliRoot';
import { runProjectHealthScan } from './projectHealthCliRunner';
import type { VibrancyScanEvent } from './projectVibrancyTypes';
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

/**
 * WP5 (`plans/PLAN_ext_ui_dart_deferred.md`): `workspaceState` key for the
 * last scan's size totals. Persisted here (not just held in a module
 * variable) so a REOPENED panel — after the extension host itself restarted,
 * not just the panel being closed — can still show a real number instead of
 * nothing until the next scan finishes; a plain in-memory variable would
 * reset to undefined on every extension reload.
 */
const TOTALS_STATE_KEY = 'saropaLints.projectMap.lastTotals';

let panel: vscode.WebviewPanel | undefined;
let extensionUri: vscode.Uri;
/** Set once at activation so scan completion can persist [ProjectMapTotals] across panel/window reopens. */
let extContext: vscode.ExtensionContext | undefined;
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
  extContext = context;
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
 * design principle 6). WP1 (PLAN_ext_ui_dart_deferred.md) added a
 * `--progress` NDJSON protocol to `bin/project_health.dart`, mirroring
 * `project_vibrancy`'s exactly — so this pane now also renders a live "N% —
 * done/total files" bar the same way Code Health does, in addition to the
 * elapsed timer, activity log, and a Cancel button backed by a real process
 * kill instead of a notification token.
 */
async function runAndRender(root: string): Promise<void> {
  lastRoot = root;
  const epoch = ++scanEpoch;
  const p = getOrCreatePanel();
  // WP5: render the LAST scan's cached size totals immediately in the hero
  // strip, before this fresh scan has produced anything — the whole point is
  // that reopening the panel (or the window) never shows a blank hero again.
  p.webview.html = buildShellHtml(
    p.webview,
    buildScanningMapPaneHtml(),
    buildReportsTabHtml(),
    getCachedProjectMapTotals(),
  );
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
  const ok = await runScan(
    root,
    outputDir,
    scanCancelSource.token,
    (line, stream) => {
      if (epoch !== scanEpoch) return; // superseded by a Restart — drop stale output
      void p.webview.postMessage({ type: 'mapLog', text: line, stream });
    },
    (event) => {
      if (epoch !== scanEpoch) return; // superseded by a Restart — drop stale progress
      void p.webview.postMessage({ type: 'mapProgress', event });
    },
  );
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
  // WP5: this scan just produced a fresh totals snapshot embedded in its own
  // report script (`health_html_template.dart`'s `const DATA = {...totals};`)
  // — extract and persist it so the NEXT panel open shows a real number
  // immediately instead of nothing, and use it (not the possibly-stale
  // cache) for THIS render since it is strictly newer.
  const totals = extractProjectMapTotals(parts.scriptHtml) ?? getCachedProjectMapTotals();
  if (totals) cacheProjectMapTotals(totals);
  p.webview.html = buildShellHtml(
    p.webview,
    buildDoneMapPaneHtml(parts),
    buildReportsTabHtml(),
    totals,
  );
}

/** Cancels the in-flight scan (if any) and starts a fresh one in the same panel. */
async function restartScan(): Promise<void> {
  if (!panel || !lastRoot) return;
  scanCancelSource?.cancel();
  const epoch = ++scanEpoch;
  // WP5: a Restart keeps showing the last known totals (cached or from the
  // scan just superseded) rather than blanking the hero mid-rescan.
  panel.webview.html = buildShellHtml(
    panel.webview,
    buildScanningMapPaneHtml(),
    buildReportsTabHtml(),
    getCachedProjectMapTotals(),
  );
  await runStreamingScan(lastRoot, panel, epoch);
}

/**
 * Spawns the scan asynchronously so the extension host never blocks, via
 * `projectHealthCliRunner.ts`'s `runProjectHealthScan` (WP1: adds
 * `--progress` NDJSON parsing on top of the previous plain buffered spawn).
 * [onOutputLine], when given, streams each stdout/stderr line as it arrives —
 * the mechanism [runStreamingScan] uses to keep the panel's activity log
 * live. [onProgress] receives parsed scan-progress events for the percentage
 * bar. Both optional so `scanProjectMapToParts` (the consolidated dashboard's
 * embed path) keeps its original buffered, non-streaming behavior unchanged
 * — it passes neither, so `--progress` is never added to its spawn.
 */
async function runScan(
  root: string,
  outputDir: string,
  token: vscode.CancellationToken,
  onOutputLine?: (line: string, stream: 'stdout' | 'stderr') => void,
  onProgress?: (event: VibrancyScanEvent) => void,
): Promise<boolean> {
  // resolveCliCwd: under F5 the in-repo CLI runs (it HAS project_health; the
  // project's published saropa_lints does not, which caused exit 255).
  const cliCwd = resolveCliCwd(root);
  const streaming = onOutputLine !== undefined || onProgress !== undefined;
  const result = await runProjectHealthScan(
    root,
    outputDir,
    cliCwd,
    token,
    streaming ? { onOutputLine, onProgress } : undefined,
  );
  if (result.spawnErrorMessage !== undefined) {
    // Spawn itself failed (missing/non-executable `dart`), not a scan error.
    void vscode.window.showErrorMessage(
      l10n('notify.commands.projectMapFailed', { message: result.spawnErrorMessage }),
    );
    return false;
  }
  if (!result.ok && !result.cancelled) {
    void vscode.window.showErrorMessage(
      l10n('notify.commands.projectMapScanFailed', {
        code: String(result.exitCode ?? -1),
        details: result.firstStderrLine,
      }),
    );
  }
  return result.ok;
}

/**
 * The three composable pieces of the Project Map report, extracted from the generated HTML by its
 * `<!--PM_*-->` boundary markers so the standalone panel's shell (projectMapShell.ts) can drop the
 * report into one shared document beside the Reports tab:
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

/**
 * WP5 (`plans/PLAN_ext_ui_dart_deferred.md`): the size summary
 * `health_html_reporter.dart`'s `buildHealthHtml` already embeds as
 * `DATA.totals` in every report — `fileCount`/`loc`/`bytes` are the ones the
 * hero KPI strip shows; `deadFiles`/`hotspots` ride along since they are the
 * SAME object, not because the hero renders them.
 */
export interface ProjectMapTotals {
  fileCount: number;
  loc: number;
  bytes: number;
  deadFiles: number;
  hotspots: number;
}

/** Narrows to a finite number — guards against a malformed/partial DATA blob before trusting a field. */
function isFiniteNumber(value: unknown): value is number {
  return typeof value === 'number' && Number.isFinite(value);
}

/**
 * Pulls `DATA.totals` out of the report's embedded script (the
 * `<!--PM_SCRIPT_START-->`-delimited fragment `extractProjectMapParts`
 * already isolates). `health_html_reporter.dart` emits `DATA` via
 * `jsonEncode` (compact, one line — no `JsonEncoder.withIndent`), so the
 * whole assignment is exactly one line; matching on THAT line rather than
 * scanning for the next statement's name keeps this parser from breaking the
 * moment `health_html_template.dart` reorders what follows it.
 *
 * Returns undefined for a template/version mismatch or any field with the
 * wrong shape — WP5's contract is "cache real data or show nothing", never a
 * fabricated/partial number.
 */
export function extractProjectMapTotals(scriptHtml: string): ProjectMapTotals | undefined {
  const match = /^const DATA = (.+);$/m.exec(scriptHtml);
  if (!match) return undefined;
  let parsed: unknown;
  try {
    parsed = JSON.parse(match[1]);
  } catch {
    return undefined;
  }
  const totals = (parsed as { totals?: unknown } | null)?.totals as
    | Partial<Record<keyof ProjectMapTotals, unknown>>
    | undefined;
  if (
    totals &&
    isFiniteNumber(totals.fileCount) &&
    isFiniteNumber(totals.loc) &&
    isFiniteNumber(totals.bytes) &&
    isFiniteNumber(totals.deadFiles) &&
    isFiniteNumber(totals.hotspots)
  ) {
    return {
      fileCount: totals.fileCount,
      loc: totals.loc,
      bytes: totals.bytes,
      deadFiles: totals.deadFiles,
      hotspots: totals.hotspots,
    };
  }
  return undefined;
}

/** Reads the last cached totals from workspaceState, or undefined before the first successful scan ever ran. */
function getCachedProjectMapTotals(): ProjectMapTotals | undefined {
  return extContext?.workspaceState.get<ProjectMapTotals>(TOTALS_STATE_KEY);
}

/** Persists a fresh totals snapshot; best-effort no-op if called before [registerProjectMapCommand]. */
function cacheProjectMapTotals(totals: ProjectMapTotals): void {
  void extContext?.workspaceState.update(TOTALS_STATE_KEY, totals);
}

const _pmStyleRe = /<!--PM_STYLE_START-->([\s\S]*?)<!--PM_STYLE_END-->/;
const _pmBodyRe = /<!--PM_BODY_START-->([\s\S]*?)<!--PM_BODY_END-->/;
const _pmScriptRe = /<!--PM_SCRIPT_START-->([\s\S]*?)<!--PM_SCRIPT_END-->/;

/**
 * Extracts the `<!--PM_*-->`-delimited fragment from a raw
 * `project_health --format html` document, or null if the markers are
 * missing (a template/version mismatch — fail closed rather than embed a
 * broken fragment). Shared by [scanProjectMapToParts] and the standalone
 * panel's own live-scan render, so both call sites parse the SAME report
 * the SAME way.
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
