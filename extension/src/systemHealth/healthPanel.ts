import * as vscode from 'vscode';
import { l10n } from '../i18n/runtime';
import { queryDartProcesses, buildSnapshot, killProcess } from './processQuery';
import { buildHealthPanelHtml } from './healthPanel-html';
import type { HealthPanelData } from './healthPanel-html';
import type { EngineStatus, EngineStatusDeps } from './engineCardsHtml';

/** Maximum number of engine-log entries retained in the scrollback buffer. */
const MAX_LOG_ENTRIES = 100;

// All variants use a `type` discriminant (not `command`, which the former
// Debug Panel webview used) so this merged panel has one consistent
// vocabulary across both the process-table messages that already existed
// here and the engine-control messages folded in from that panel.
/** Message shapes the webview can post back to the extension host. */
type HealthPanelMessage =
  | { type: 'refresh' }
  | { type: 'killProcess'; pid: number }
  | { type: 'toggle'; engine: 'analyzer' | 'scanDaemon' | 'lspServer'; enabled: boolean }
  | { type: 'killAll' }
  | { type: 'restartAll' };

// Singleton webview panel: only one System Health view makes sense at a
// time, so re-invoking the command reveals + refreshes the existing panel
// instead of spawning a duplicate.
//
// Engine-status deps, the log buffer, and the toggle/killAll/restartAll
// event emitters are STATIC — they must survive across the panel being
// closed and reopened (the host wires them once at activation, the same
// way the former standalone Debug Panel sidebar webview did), whereas the
// `panel` (WebviewPanel) instance itself only exists while the tab is open.
export class HealthPanel implements vscode.Disposable {
  private static instance: HealthPanel | undefined;
  private static engineDeps: EngineStatusDeps | undefined;
  private static readonly logEntries: string[] = [];
  private static readonly _onToggle = new vscode.EventEmitter<{
    engine: 'analyzer' | 'scanDaemon' | 'lspServer';
    enabled: boolean;
  }>();
  private static readonly _onKillAll = new vscode.EventEmitter<void>();
  private static readonly _onRestartAll = new vscode.EventEmitter<void>();

  /** Subscribe to engine toggle requests from the panel UI. */
  static readonly onToggle = HealthPanel._onToggle.event;
  /** Subscribe to kill-all requests from the panel UI. */
  static readonly onKillAll = HealthPanel._onKillAll.event;
  /** Subscribe to restart-all requests from the panel UI. */
  static readonly onRestartAll = HealthPanel._onRestartAll.event;

  private readonly panel: vscode.WebviewPanel;
  private readonly disposables: vscode.Disposable[] = [];
  // Guards async callbacks (refresh/kill) that may resolve after the user
  // closed the panel — without this, a late webview.html write would throw
  // on a disposed webview.
  private disposed = false;

  /** Wire the engine-status callbacks once at activation. */
  static configureEngines(deps: EngineStatusDeps): void {
    HealthPanel.engineDeps = deps;
  }

  /**
   * Append a timestamped entry to the engine log and refresh the panel if
   * it is currently open. Safe to call before the panel has ever been
   * shown — the entry is retained in the static buffer either way.
   */
  static addLogEntry(message: string): void {
    const timestamp = new Date().toLocaleTimeString();
    HealthPanel.logEntries.push(`[${timestamp}] ${message}`);
    while (HealthPanel.logEntries.length > MAX_LOG_ENTRIES) {
      HealthPanel.logEntries.shift();
    }
    if (HealthPanel.instance) void HealthPanel.instance.refresh();
  }

  /**
   * Open the panel, or bring it to front and refresh if already open.
   * Refreshing on reveal matters because process state (RSS, orphans) and
   * engine state (plugin live/dead) can both have changed while the tab
   * was in the background — `retainContextWhenHidden` keeps the webview
   * alive but does not re-query anything on its own.
   */
  static createOrShow(context: vscode.ExtensionContext): void {
    if (HealthPanel.instance) {
      HealthPanel.instance.panel.reveal();
      void HealthPanel.instance.refresh();
      return;
    }
    HealthPanel.instance = new HealthPanel(context);
  }

  private constructor(context: vscode.ExtensionContext) {
    this.panel = vscode.window.createWebviewPanel(
      'saropaSystemHealth',
      l10n('systemHealth.panel.title'),
      vscode.ViewColumn.One,
      { enableScripts: true, retainContextWhenHidden: true },
    );

    this.panel.onDidDispose(() => this.dispose(), null, this.disposables);
    this.panel.webview.onDidReceiveMessage(
      (msg: HealthPanelMessage) => this.handleMessage(msg),
      null,
      this.disposables,
    );

    context.subscriptions.push(this);
    void this.refresh();
  }

  private collectEngines(): EngineStatus[] | undefined {
    // Delegates to the static accessor so the Home hub KPI band (which never
    // opens this panel) can read the identical engine snapshot — one source
    // of truth for "what are the engines doing right now".
    return HealthPanel.getEngineStatuses();
  }

  /**
   * Public, panel-free snapshot of the three diagnostic engines. Added for the
   * Home hub KPI band (`saropaDashboardsView.ts`), which needs an "engines
   * running" count without creating/opening the Health Panel webview. Mirrors
   * `collectEngines()` exactly (same gate, same deps) so the two surfaces can
   * never disagree.
   */
  static getEngineStatuses(): EngineStatus[] | undefined {
    // saropaLints.debug.enabled now gates the Engines section within this
    // panel (it used to gate the standalone Debug Panel sidebar webview's
    // existence entirely).
    const showEngines = vscode.workspace.getConfiguration('saropaLints.debug').get<boolean>('enabled', true);
    const deps = HealthPanel.engineDeps;
    if (!showEngines || !deps) return undefined;
    return [
      deps.getAnalyzerPluginStatus(),
      deps.getScanDaemonStatus(),
      deps.getLspServerStatus(),
    ];
  }

  private async refresh(): Promise<void> {
    const data = await this.queryData();
    if (this.disposed) return;
    this.panel.webview.html = buildHealthPanelHtml(data, this.collectEngines(), HealthPanel.logEntries);
  }

  private async queryData(): Promise<HealthPanelData | null> {
    // Process enumeration (queryDartProcesses) shells out to a Windows-only
    // tool; on other platforms there is no data source, so show the empty
    // state rather than attempting a query that would just fail.
    if (process.platform !== 'win32') return null;
    const processes = await queryDartProcesses();
    if (processes.length === 0) return null;
    const snapshot = await buildSnapshot(processes);
    return {
      processes,
      orphanPids: new Set([...snapshot.orphanedDaemonPids, ...snapshot.orphanedScanDaemonPids]),
      totalRssBytes: snapshot.totalRssBytes,
    };
  }

  /**
   * Route a webview message to its handler. The process-table messages
   * (refresh/killProcess) are handled directly here because this class
   * owns that data. The engine-control messages (toggle/killAll/restartAll)
   * only re-fire as events instead — the actual start/stop/kill mechanics
   * live in extension.ts, which has the closures (lspClient,
   * scanOnSaveController, runDisable/runReenablePlugin) this class has no
   * business owning.
   */
  private handleMessage(msg: HealthPanelMessage): void {
    switch (msg.type) {
      case 'refresh':
        void this.refresh();
        break;
      case 'killProcess':
        void this.killAndNotify(msg.pid);
        break;
      case 'toggle':
        HealthPanel._onToggle.fire({ engine: msg.engine, enabled: msg.enabled });
        break;
      case 'killAll':
        HealthPanel._onKillAll.fire();
        break;
      case 'restartAll':
        HealthPanel._onRestartAll.fire();
        break;
    }
  }

  private async killAndNotify(pid: number): Promise<void> {
    const success = await killProcess(pid);
    // killProcess is async and the panel may have closed while it ran.
    if (this.disposed) return;
    void this.panel.webview.postMessage({
      type: 'killResult',
      pid,
      success,
    });
    if (success) {
      void this.refresh();
    }
  }

  dispose(): void {
    // Set before clearing instance/disposables so any in-flight async
    // callback (refresh/kill) sees disposed=true on its next check.
    this.disposed = true;
    HealthPanel.instance = undefined;
    for (const d of this.disposables) d.dispose();
    this.disposables.length = 0;
  }
}
