import * as vscode from 'vscode';
import { l10n } from '../i18n/runtime';
import { queryDartProcesses, buildSnapshot, killProcess } from './processQuery';
import { buildHealthPanelHtml } from './healthPanel-html';
import type { HealthPanelData } from './healthPanel-html';

// Singleton webview panel: only one System Health view makes sense at a
// time, so re-invoking the command reveals + refreshes the existing panel
// instead of spawning a duplicate.
export class HealthPanel implements vscode.Disposable {
  private static instance: HealthPanel | undefined;
  private readonly panel: vscode.WebviewPanel;
  private readonly disposables: vscode.Disposable[] = [];
  // Guards async callbacks (refresh/kill) that may resolve after the user
  // closed the panel — without this, a late webview.html write would throw
  // on a disposed webview.
  private disposed = false;

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
      (msg) => this.handleMessage(msg),
      null,
      this.disposables,
    );

    context.subscriptions.push(this);
    void this.refresh();
  }

  private async refresh(): Promise<void> {
    const data = await this.queryData();
    if (this.disposed) return;
    this.panel.webview.html = buildHealthPanelHtml(data);
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
      orphanPids: new Set(snapshot.orphanedDaemonPids),
      totalRssBytes: snapshot.totalRssBytes,
    };
  }

  private handleMessage(msg: { type: string; pid?: number }): void {
    if (msg.type === 'refresh') {
      void this.refresh();
    } else if (msg.type === 'killProcess' && msg.pid !== undefined) {
      void this.killAndNotify(msg.pid);
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
