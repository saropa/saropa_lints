import * as vscode from 'vscode';
import { l10n } from '../i18n/runtime';
import { queryDartProcesses, buildSnapshot, killProcess } from './processQuery';
import { buildHealthPanelHtml } from './healthPanel-html';
import type { HealthPanelData } from './healthPanel-html';

export class HealthPanel implements vscode.Disposable {
  private static instance: HealthPanel | undefined;
  private readonly panel: vscode.WebviewPanel;
  private readonly disposables: vscode.Disposable[] = [];
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
    this.disposed = true;
    HealthPanel.instance = undefined;
    for (const d of this.disposables) d.dispose();
    this.disposables.length = 0;
  }
}
