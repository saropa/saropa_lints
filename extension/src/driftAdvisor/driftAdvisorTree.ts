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
import { ADVISOR_EXTENSION_ID } from '../suite/siblingDeepLinkTargets';
import { shouldPublishDriftProblems } from './driftProblemsGate';
import { getDriftAuthToken } from './auth';
import { l10n } from '../i18n/runtime';

type DriftTreeNode =
  | { kind: 'placeholder'; message: string; command?: vscode.Command }
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
  // Set when the server rejected the last fetch with 401/403 — distinct from
  // "connected, zero issues" so a bad token doesn't masquerade as a clean project.
  private authFailed = false;

  constructor(private readonly diagnosticCollection: vscode.DiagnosticCollection) {}

  setState(server: DriftServerInfo | null, issues: DriftIssueMapped[]): void {
    this.server = server;
    this.issues = issues;
    this.loading = false;
    this.authFailed = false;
    this.updateDiagnostics();
    this._onDidChangeTreeData.fire();
  }

  setLoading(loading: boolean): void {
    this.loading = loading;
    this._onDidChangeTreeData.fire();
  }

  /**
   * Record that the server was reached but rejected the request due to a bad
   * or missing auth token. Keeps the server node visible (it IS reachable)
   * while replacing the issue list with an actionable auth-error placeholder.
   */
  setAuthFailed(server: DriftServerInfo): void {
    this.server = server;
    this.issues = [];
    this.loading = false;
    this.authFailed = true;
    this.updateDiagnostics();
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

  /**
   * Re-publish (or suppress) Problems diagnostics from the cached issue set without
   * re-running discovery/fetch. Called when the standalone Drift Advisor extension
   * is enabled/disabled mid-session (via vscode.extensions.onDidChange), so the
   * duplicate-suppression decision flips immediately rather than waiting for the
   * next poll/refresh.
   */
  reevaluateDiagnostics(): void {
    this.updateDiagnostics();
  }

  private updateDiagnostics(): void {
    this.diagnosticCollection.clear();

    // The standalone Saropa Drift Advisor extension (saropa.drift-viewer) is the
    // canonical owner of these Problems-panel diagnostics. When installed AND active
    // it publishes the same anomalies / index suggestions, so emitting our copy
    // produces duplicate squiggles (one per extension). Check isActive — not mere
    // presence — so an installed-but-disabled standalone extension does not suppress
    // us. The Lints "Drift Advisor" tree view is unaffected; it does not depend on
    // this publish.
    const standalone = vscode.extensions.getExtension(ADVISOR_EXTENSION_ID);
    const showInProblems = vscode.workspace
      .getConfiguration('saropaLints.driftAdvisor')
      .get<boolean>('showInProblems', true);
    if (!shouldPublishDriftProblems({ standaloneActive: standalone?.isActive ?? false, showInProblems })) {
      return;
    }
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
      item.command = element.command;
      return item;
    }
    if (element.kind === 'server') {
      const s = element.server;
      // Host is stored at discovery time on DriftServerInfo — no re-parsing needed.
      const label = `Server: ${s.host}:${s.port}`;
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
      return [{ kind: 'placeholder', message: l10n('driftAdvisor.discovering') }];
    }
    if (!this.server) {
      const cfg = vscode.workspace.getConfiguration('saropaLints.driftAdvisor');
      const integration = cfg.get<boolean>('integration', false);
      return [{
        kind: 'placeholder',
        message: integration
          ? l10n('driftAdvisor.noServerFound')
          : l10n('driftAdvisor.integrationOff'),
      }];
    }
    // Server rejected the last fetch (401/403) — a bad or expired token, not zero issues.
    if (this.authFailed) {
      return [
        { kind: 'server', server: this.server },
        {
          kind: 'placeholder',
          message: l10n('driftAdvisor.authFailed'),
          command: { command: 'workbench.action.openSettings', title: 'Open Settings', arguments: ['saropaLints.driftAdvisor.authToken'] },
        },
      ];
    }
    // Server detected but requires auth and no token is configured — guide the user.
    if (this.server.authRequired) {
      if (!getDriftAuthToken()) {
        return [
          { kind: 'server', server: this.server },
          {
            kind: 'placeholder',
            message: l10n('driftAdvisor.authRequired'),
            command: { command: 'workbench.action.openSettings', title: 'Open Settings', arguments: ['saropaLints.driftAdvisor.authToken'] },
          },
        ];
      }
    }
    const nodes: DriftTreeNode[] = [
      { kind: 'server', server: this.server },
      ...this.issues.map((issue) => ({ kind: 'issue' as const, issue })),
    ];
    return nodes;
  }
}
