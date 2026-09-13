import * as vscode from 'vscode';
import { l10n } from '../i18n/runtime';
import { queryDartProcesses, buildSnapshot, killProcess } from './processQuery';
import { buildHealthPanelHtml } from './healthPanel-html';
import type { HealthPanelData } from './healthPanel-html';
import { scanOrphanedHosts, type OrphanHostScan } from './orphanHosts';
import { CHECK_ORPHANS_COMMAND } from './orphanPreflight';
import type { EngineStatus, EngineStatusDeps } from './engineCardsHtml';
import type { CiPublishPlan } from './ciPublish';

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
  | { type: 'toggle'; engine: 'analyzer' | 'scanDaemon' | 'lspServer' | 'ci'; enabled: boolean }
  | { type: 'killAll' }
  | { type: 'restartAll' }
  | { type: 'reclaimOrphans' }
  | { type: 'ciCopyCommands'; commands: string }
  | { type: 'ciPublish' }
  | { type: 'ciPublishDismiss' };

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
    engine: 'analyzer' | 'scanDaemon' | 'lspServer' | 'ci';
    enabled: boolean;
  }>();
  private static readonly _onKillAll = new vscode.EventEmitter<void>();
  private static readonly _onCiPublish = new vscode.EventEmitter<CiPublishPlan>();
  private static readonly _onRestartAll = new vscode.EventEmitter<void>();

  /** Subscribe to engine toggle requests from the panel UI. */
  static readonly onToggle = HealthPanel._onToggle.event;
  /** Subscribe to kill-all requests from the panel UI. */
  static readonly onKillAll = HealthPanel._onKillAll.event;
  /** Subscribe to restart-all requests from the panel UI. */
  static readonly onRestartAll = HealthPanel._onRestartAll.event;
  /**
   * Subscribe to the user accepting the publish step. Carries the plan that
   * was on screen when they pressed the button, so the host commits the
   * change they were actually shown rather than re-deriving one that may have
   * picked a different branch name in the meantime.
   */
  static readonly onCiPublish = HealthPanel._onCiPublish.event;

  /**
   * The CI change waiting to be published, if any.
   *
   * Static, like the engine deps: the toggle can be flipped from the sidebar
   * while the panel is closed, and the pending change must still be there when
   * it opens. Cleared by dismissing it, by publishing it, or by toggling in
   * the opposite direction (which supersedes it).
   */
  private static pendingCiPublish: CiPublishPlan | undefined;

  /**
   * Record (or clear, with undefined) the pending CI change and redraw.
   *
   * Never performs git itself — see `ciPublish.ts` for why the separation
   * matters.
   */
  static setPendingCiPublish(plan: CiPublishPlan | undefined): void {
    HealthPanel.pendingCiPublish = plan;
    void HealthPanel.instance?.refresh();
  }

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
   * Re-renders the panel if it is currently open, without appending a log
   * entry. WP4: `SaropaLspClient` calls this on every `saropa/scanProgress`
   * tick so the engine card's live "N/M files" line updates in real time —
   * `addLogEntry` would work too, but would spam the Activity log with one
   * line per tick (every 50 files) instead of the single "scan complete"
   * line that log already gets from the server's own log messages.
   */
  static refreshIfOpen(): void {
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
    // Delegates to the static accessor so other surfaces (e.g. the sidebar Engines
    // status row) can read the identical engine snapshot — one source of truth
    // for "what are the engines doing right now".
    return HealthPanel.getEngineStatuses();
  }

  /**
   * Public, panel-free snapshot of the three diagnostic engines. Lets a sidebar
   * row show an "engines running" count without creating/opening the Health
   * Panel webview. Mirrors `collectEngines()` exactly (same gate, same deps) so
   * the two surfaces can never disagree.
   */
  static getEngineStatuses(): EngineStatus[] | undefined {
    // No longer gated on saropaLints.debug.enabled. These are not debug
    // internals: they are the controls for whether analysis runs at all, and
    // one of them is the off switch for the project's CI. A kill switch behind
    // a setting the user has to know to enable is not a kill switch.
    //
    // The only remaining reason to return undefined is that the engine deps
    // have not been wired yet (early in activate), which is a timing fact
    // rather than a preference.
    const deps = HealthPanel.engineDeps;
    if (!deps) return undefined;
    return [
      deps.getAnalyzerPluginStatus(),
      deps.getScanDaemonStatus(),
      deps.getLspServerStatus(),
      deps.getCiStatus(),
    ];
  }

  private async refresh(): Promise<void> {
    // The orphan scan is queried alongside the Dart process table rather than
    // cached from the activation preflight: the panel is where a user goes to
    // confirm a reclaim worked, and a stale banner would still show the
    // processes they just terminated.
    const [data, orphanHosts] = await Promise.all([
      this.queryData(),
      HealthPanel.queryOrphanHosts(),
    ]);
    if (this.disposed) return;
    this.panel.webview.html = buildHealthPanelHtml({
      data,
      engines: this.collectEngines(),
      logEntries: HealthPanel.logEntries,
      orphanHosts,
      ciPublish: HealthPanel.pendingCiPublish,
    });
  }

  /** Orphan scan for the banner; failures degrade to no banner, never to a broken panel. */
  private static async queryOrphanHosts(): Promise<OrphanHostScan | undefined> {
    if (process.platform !== 'win32') return undefined;
    try {
      return await scanOrphanedHosts();
    } catch {
      return undefined;
    }
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
      case 'ciCopyCommands':
        void vscode.env.clipboard.writeText(msg.commands).then(() => {
          void vscode.window.showInformationMessage(l10n('debug.ci.publish.copied'));
        });
        break;
      case 'ciPublish': {
        // Read before firing: the handler clears the pending plan, and an
        // event carrying undefined would be a silent no-op the user reads as
        // a dead button.
        const plan = HealthPanel.pendingCiPublish;
        if (plan) HealthPanel._onCiPublish.fire(plan);
        break;
      }
      case 'ciPublishDismiss':
        // The file on disk is deliberately left as it is. Dismissing means
        // "I will deal with this myself", not "undo the edit" — reverting
        // someone's working tree from a Not now button would be its own bug.
        HealthPanel.setPendingCiPublish(undefined);
        break;
      case 'reclaimOrphans':
        // Delegated to the command so the confirmation modal and the kill
        // path have exactly one implementation, shared with the palette
        // entry and the preflight notification.
        void vscode.commands.executeCommand(CHECK_ORPHANS_COMMAND);
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
