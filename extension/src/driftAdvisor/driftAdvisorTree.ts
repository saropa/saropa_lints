/**
 * Drift Advisor tree view and diagnostics.
 *
 * TreeDataProvider for the "Drift Advisor" sidebar view: when integration is off or no server
 * is found, shows a single placeholder with guidance. When connected, shows a server node
 * (port, version) and one node per issue; issues with mapped file/line get a "Go to line"
 * command. Diagnostics are published to the Problems view (source "Saropa Drift Advisor",
 * codes drift_advisor_index_suggestion / drift_advisor_anomaly) when showInProblems is true.
 * State is set from extension.ts after discover → fetch → map; no async I/O in getChildren.
 */

import * as vscode from 'vscode';
import * as path from 'node:path';
import type { DriftServerInfo } from './types';
import type { DriftIssueMapped } from './types';

type DriftTreeNode =
  | { kind: 'placeholder'; message: string }
  | { kind: 'server'; server: DriftServerInfo }
  | { kind: 'issue'; issue: DriftIssueMapped };

const DIAGNOSTIC_SOURCE = 'Saropa Drift Advisor';
const CODE_INDEX_SUGGESTION = 'drift_advisor_index_suggestion';
const CODE_ANOMALY = 'drift_advisor_anomaly';

function severityToDiagnostic(s: DriftIssueMapped['severity']): vscode.DiagnosticSeverity {
  switch (s) {
    case 'error': return vscode.DiagnosticSeverity.Error;
    case 'warning': return vscode.DiagnosticSeverity.Warning;
    default: return vscode.DiagnosticSeverity.Information;
  }
}

export class DriftAdvisorTreeProvider implements vscode.TreeDataProvider<DriftTreeNode> {
  private readonly _onDidChangeTreeData = new vscode.EventEmitter<DriftTreeNode | undefined | void>();
  readonly onDidChangeTreeData = this._onDidChangeTreeData.event;

  private server: DriftServerInfo | null = null;
  private issues: DriftIssueMapped[] = [];
  private loading = false;

  constructor(private readonly diagnosticCollection: vscode.DiagnosticCollection) {}

  setState(server: DriftServerInfo | null, issues: DriftIssueMapped[]): void {
    this.server = server;
    this.issues = issues;
    this.loading = false;
    this.updateDiagnostics();
    this._onDidChangeTreeData.fire();
  }

  setLoading(loading: boolean): void {
    this.loading = loading;
    this._onDidChangeTreeData.fire();
  }

  getServer(): DriftServerInfo | null {
    return this.server;
  }

  /** Issue count when a server is connected; undefined when not connected. */
  getIssueCount(): number | undefined {
    if (this.server === null) return undefined;
    return this.issues.length;
  }

  private updateDiagnostics(): void {
    this.diagnosticCollection.clear();
    const showInProblems = vscode.workspace.getConfiguration('saropaLints.driftAdvisor').get<boolean>('showInProblems', true);
    if (!showInProblems) return;
    const byFile = new Map<string, vscode.Diagnostic[]>();
    for (const issue of this.issues) {
      if (!issue.uri?.fsPath) continue;
      const uri = vscode.Uri.file(issue.uri.fsPath);
      const line = issue.line ?? 0;
      const range = new vscode.Range(line, 0, line, 200);
      const code = issue.source === 'index-suggestion' ? CODE_INDEX_SUGGESTION : CODE_ANOMALY;
      const diag = new vscode.Diagnostic(
        range,
        `[Drift] ${issue.table}${issue.column ? '.' + issue.column : ''}: ${issue.message}`,
        severityToDiagnostic(issue.severity),
      );
      diag.source = DIAGNOSTIC_SOURCE;
      diag.code = code;
      const key = uri.toString();
      const list = byFile.get(key) ?? [];
      list.push(diag);
      byFile.set(key, list);
    }
    for (const [uriStr, list] of byFile) {
      this.diagnosticCollection.set(vscode.Uri.parse(uriStr), list);
    }
  }

  refresh(): void {
    this._onDidChangeTreeData.fire();
  }

  getTreeItem(element: DriftTreeNode): vscode.TreeItem {
    if (element.kind === 'placeholder') {
      const item = new vscode.TreeItem(element.message, vscode.TreeItemCollapsibleState.None);
      item.contextValue = 'driftAdvisorPlaceholder';
      return item;
    }
    if (element.kind === 'server') {
      const s = element.server;
      const label = `Server: 127.0.0.1:${s.port}`;
      const item = new vscode.TreeItem(label, vscode.TreeItemCollapsibleState.None);
      item.description = s.version ? `v${s.version}` : undefined;
      item.contextValue = 'driftAdvisorServer';
      item.iconPath = new vscode.ThemeIcon('server-process');
      return item;
    }
    // issue
    const issue = element.issue;
    const loc = issue.uri?.fsPath
      ? path.basename(issue.uri.fsPath) + (issue.line !== undefined ? `:${issue.line + 1}` : '')
      : `${issue.table}${issue.column ? '.' + issue.column : ''}`;
    const label = issue.message.length > 60 ? issue.message.slice(0, 57) + '…' : issue.message;
    const item = new vscode.TreeItem(label, vscode.TreeItemCollapsibleState.None);
    item.description = loc;
    item.tooltip = `${issue.source}: ${issue.table}${issue.column ? '.' + issue.column : ''}\n${issue.message}`;
    item.contextValue = 'driftAdvisorIssue';
    item.iconPath = new vscode.ThemeIcon(
      issue.source === 'index-suggestion' ? 'symbol-method' : 'warning',
      issue.severity === 'error' ? new vscode.ThemeColor('editorError.foreground') : undefined,
    );
    if (issue.uri?.fsPath !== undefined && issue.line !== undefined) {
      item.command = {
        command: 'vscode.open',
        title: 'Go to line',
        arguments: [
          vscode.Uri.file(issue.uri.fsPath),
          { selection: new vscode.Range(issue.line, 0, issue.line, 0), preview: false },
        ],
      };
    }
    return item;
  }

  async getChildren(element?: DriftTreeNode): Promise<DriftTreeNode[]> {
    if (element !== undefined) {
      return [];
    }
    if (this.loading) {
      return [{ kind: 'placeholder', message: 'Discovering server and fetching issues…' }];
    }
    if (!this.server) {
      const cfg = vscode.workspace.getConfiguration('saropaLints.driftAdvisor');
      const integration = cfg.get<boolean>('integration', false);
      return [{
        kind: 'placeholder',
        message: integration
          ? 'No Drift Advisor server found. Start your app with the server running, then click Refresh.'
          : 'Drift Advisor integration is off. Enable it in settings (saropaLints.driftAdvisor.integration), then click Refresh.',
      }];
    }
    const nodes: DriftTreeNode[] = [
      { kind: 'server', server: this.server },
      ...this.issues.map((issue) => ({ kind: 'issue' as const, issue })),
    ];
    return nodes;
  }
}
