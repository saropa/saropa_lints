import * as vscode from 'vscode';
import { l10n } from '../i18n/runtime';
import { buildSnapshot, killProcess, queryDartProcesses } from './processQuery';
import { killProcessTree, queryModelHostProcesses, scanOrphanedHosts } from './orphanHosts';
import { queryLoadedModels } from './ollamaQuery';
import { querySystemMemory } from './systemQuery';
import { buildMachineDashboardHtml, type MachineDashboardData } from './machineDashboard-html';
import {
  buildRecommendations,
  computeDevToolBudget,
  DEFAULT_ANALYSIS_SERVER_WARNING_GB,
  groupDartProcesses,
  groupModelHosts,
} from './machineDashboardData';

/** Message shapes the webview can post back to the extension host. */
type DashboardMessage =
  | { type: 'refresh' }
  | { type: 'kill'; pid: number; group: string }
  | { type: 'runCommand'; command: string; recId: string; args?: unknown[] };

/**
 * Singleton webview panel — one Machine Health view makes sense at a time,
 * same convention as {@link HealthPanel}. Separate panel (not a merge into
 * HealthPanel) because the audiences differ: HealthPanel answers "is
 * saropa_lints healthy?"; this answers "is my *machine* healthy?" across
 * every Dart/Flutter/Ollama process regardless of who owns it.
 */
export class MachineDashboard implements vscode.Disposable {
  private static instance: MachineDashboard | undefined;

  private readonly panel: vscode.WebviewPanel;
  private readonly disposables: vscode.Disposable[] = [];
  private disposed = false;

  /**
   * Open the panel, or bring an already-open one to front and refresh it.
   * Refresh-on-reveal matters here even more than for HealthPanel: this
   * panel's data (system RAM, Ollama models) can go stale in seconds, not
   * minutes, while the tab sits unfocused in the background.
   */
  static createOrShow(context: vscode.ExtensionContext): void {
    // All data sources are Windows-only CIM queries — show a clear message
    // rather than an empty webview on other platforms.
    if (process.platform !== 'win32') {
      void vscode.window.showInformationMessage(
        l10n('machineDashboard.platformUnsupported'),
      );
      return;
    }
    if (MachineDashboard.instance) {
      MachineDashboard.instance.panel.reveal();
      void MachineDashboard.instance.refresh();
      return;
    }
    MachineDashboard.instance = new MachineDashboard(context);
  }

  private constructor(context: vscode.ExtensionContext) {
    this.panel = vscode.window.createWebviewPanel(
      'saropaMachineDashboard',
      l10n('machineDashboard.title'),
      vscode.ViewColumn.One,
      { enableScripts: true, retainContextWhenHidden: true },
    );
    this.panel.onDidDispose(() => this.dispose(), null, this.disposables);
    this.panel.webview.onDidReceiveMessage(
      (msg: DashboardMessage) => this.handleMessage(msg),
      null,
      this.disposables,
    );
    context.subscriptions.push(this);
    void this.refresh();
  }

  private async refresh(): Promise<void> {
    const data = await MachineDashboard.queryData();
    // queryData() awaits several PowerShell shell-outs and an HTTP round
    // trip; the user can close the panel mid-query, and writing to a
    // disposed webview throws — same disposed-guard pattern as HealthPanel.
    if (this.disposed) return;
    this.panel.webview.html = buildMachineDashboardHtml(data);
  }

  /**
   * Gather every data source the dashboard needs. Static (not an instance
   * method) so the same aggregation can back a future "quick check" command
   * that never opens the panel.
   */
  static async queryData(): Promise<MachineDashboardData> {
    // Every data source here shells out to PowerShell CIM queries — all
    // Windows-only, same constraint as processQuery.ts and orphanHosts.ts.
    // Returning the empty shape (not throwing) lets the HTML layer render
    // its normal empty state rather than needing a separate error path.
    if (process.platform !== 'win32') {
      return { system: undefined, groups: [], recommendations: [], budget: undefined };
    }
    // Five independent queries fired concurrently rather than sequentially —
    // none depends on another's result, and this panel already reads as
    // slow (each PowerShell shell-out is tens of ms) if run in series.
    const [system, dartProcesses, modelHosts, loadedModels, orphanHostScan] = await Promise.all([
      querySystemMemory(),
      queryDartProcesses(),
      queryModelHostProcesses(),
      queryLoadedModels(),
      scanOrphanedHosts(),
    ]);
    const dartSnapshot = await buildSnapshot(dartProcesses);
    // Both orphan classes union into one set for grouping: buildSnapshot
    // already applies the "parent PID no longer alive" test that both the
    // Flutter-daemon and scan-daemon rows need — no need to re-derive it.
    const dartOrphanPids = new Set([
      ...dartSnapshot.orphanedDaemonPids,
      ...dartSnapshot.orphanedScanDaemonPids,
    ]);
    const modelHostOrphanPids = new Set(orphanHostScan.orphans.map((o) => o.processId));

    // Filter out empty groups at the source — groupModelHosts always returns a
    // group object even with zero hosts, and downstream consumers (recommendations,
    // future CLI quick-check) shouldn't have to remember to filter it themselves.
    const modelHostGroup = groupModelHosts(modelHosts, modelHostOrphanPids);
    const groups = [
      ...groupDartProcesses(dartProcesses, dartOrphanPids),
      ...(modelHostGroup.processCount > 0 ? [modelHostGroup] : []),
    ];

    const config = vscode.workspace.getConfiguration('saropaLints.systemHealth');
    const analysisServerWarningGB = config.get<number>(
      'analysisServerWarningGB',
      DEFAULT_ANALYSIS_SERVER_WARNING_GB,
    );
    // Read the same threshold processMonitor uses for its proactive notification,
    // so the dashboard's "low memory" recommendation agrees with the notification.
    const systemMemoryWarningPercent = config.get<number>(
      'systemMemoryWarningPercent',
      15,
    );
    // Dev-tool memory budget — the percentage of total RAM the user considers
    // acceptable for Dart/Flutter/Ollama combined.
    const devToolBudgetPercent = config.get<number>(
      'devToolBudgetPercent',
      60,
    );
    // Read directly from Dart-Code's own setting (not a saropa_lints
    // mirror) so "no heap cap" reflects what the analysis server will
    // actually launch with, not a copy that could drift out of sync.
    const analyzerVmArgs = vscode.workspace
      .getConfiguration('dart')
      .get<string[]>('analyzerVmAdditionalArgs', []);

    const recommendations = buildRecommendations({
      system,
      groups,
      loadedModels,
      orphanCount: dartOrphanPids.size + modelHostOrphanPids.size,
      // Dart orphan bytes must be looked up by PID against the full process
      // list — buildSnapshot's orphan arrays are PID-only, not full rows —
      // then added to the model-host scan's already-summed total.
      orphanTotalBytes:
        [...dartOrphanPids].reduce((sum, pid) => {
          const p = dartProcesses.find((d) => d.processId === pid);
          return sum + (p?.workingSetSize ?? 0);
        }, 0) + orphanHostScan.totalCommittedBytes,
      analysisServerWarningGB,
      systemMemoryWarningPercent,
      devToolBudgetPercent,
      analyzerVmArgs,
    });

    // Compute budget after groups are finalized — the budget is derived from
    // the same group RSS totals the dashboard already displays, so they
    // always agree without a separate data path.
    const budget = computeDevToolBudget(system, groups, devToolBudgetPercent);
    return { system, groups, recommendations, budget };
  }

  private handleMessage(msg: DashboardMessage): void {
    switch (msg.type) {
      case 'refresh':
        void this.refresh();
        break;
      case 'kill':
        void this.killAndRefresh(msg.pid, msg.group);
        break;
      case 'runCommand':
        // Recommendation actions dispatch through the normal VS Code command
        // registry rather than this class owning switch-case logic per
        // command — every action (restart analysis server, reclaim orphans,
        // set heap cap, unload a model) already has its own registered
        // command with its own confirmation UI where one is needed, so this
        // class never has to know what any of them actually do.
        void vscode.commands.executeCommand(msg.command, ...(msg.args ?? []));
        break;
    }
  }

  /**
   * Model-host processes need the tree-kill (`/T`) taskkill variant — the
   * same reasoning as `orphanHosts.ts`'s own reclaim path: killing
   * `ollama.exe` without `/T` strands its `llama-server.exe` child. Every
   * other group is a bare Dart/Flutter process where a plain kill suffices.
   */
  private async killAndRefresh(pid: number, group: string): Promise<void> {
    const success = group === 'modelHost' ? await killProcessTree(pid) : await killProcess(pid);
    if (this.disposed) return;
    if (success) void this.refresh();
  }

  dispose(): void {
    this.disposed = true;
    MachineDashboard.instance = undefined;
    for (const d of this.disposables) d.dispose();
    this.disposables.length = 0;
  }
}
