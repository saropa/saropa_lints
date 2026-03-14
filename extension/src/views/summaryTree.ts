/**
 * Tree data provider for Saropa Lints Summary view.
 * Shows totals, by severity, by impact, and tier from violations.json.
 */

import * as vscode from 'vscode';
import { readViolations } from '../violationsReader';

/** Stable id used for expandable nodes (By severity, By impact) so getChildren does not rely on label text. */
class SummaryItem extends vscode.TreeItem {
  constructor(
    label: string,
    description?: string,
    collapsible: vscode.TreeItemCollapsibleState = vscode.TreeItemCollapsibleState.None,
    public readonly nodeId?: string,
  ) {
    super(label, collapsible);
    this.description = description;
  }
}

export class SummaryTreeProvider implements vscode.TreeDataProvider<SummaryItem> {
  private _onDidChangeTreeData = new vscode.EventEmitter<SummaryItem | undefined | void>();
  readonly onDidChangeTreeData = this._onDidChangeTreeData.event;

  refresh(): void {
    this._onDidChangeTreeData.fire();
  }

  getTreeItem(element: SummaryItem): vscode.TreeItem {
    return element;
  }

  async getChildren(element?: SummaryItem): Promise<SummaryItem[]> {
    const root = vscode.workspace.workspaceFolders?.[0]?.uri.fsPath;
    if (!root) return [new SummaryItem('No workspace', undefined)];

    const data = readViolations(root);
    if (!data) {
      if (!element) {
        return [
          new SummaryItem('No violations file', 'Run analysis to generate'),
        ];
      }
      return [];
    }

    const s = data.summary;
    const c = data.config;

    if (!element) {
      const total = s?.totalViolations ?? data.violations.length;
      const items: SummaryItem[] = [
        new SummaryItem('Total violations', String(total)),
        new SummaryItem('Tier', c?.tier ?? '—'),
        new SummaryItem('Files analyzed', s?.filesAnalyzed != null ? String(s.filesAnalyzed) : '—'),
        new SummaryItem('Files with issues', s?.filesWithIssues != null ? String(s.filesWithIssues) : '—'),
      ];
      if (s?.bySeverity) {
        items.push(
          new SummaryItem(
            'By severity',
            `${s.bySeverity.error ?? 0} error, ${s.bySeverity.warning ?? 0} warning, ${s.bySeverity.info ?? 0} info`,
            vscode.TreeItemCollapsibleState.Expanded,
            'bySeverity',
          ),
        );
      }
      if (s?.byImpact) {
        const bi = s.byImpact;
        items.push(
          new SummaryItem(
            'By impact',
            `critical ${bi.critical ?? 0}, high ${bi.high ?? 0}, medium ${bi.medium ?? 0}, low ${bi.low ?? 0}, opinionated ${bi.opinionated ?? 0}`,
            vscode.TreeItemCollapsibleState.Expanded,
            'byImpact',
          ),
        );
      }
      return items;
    }

    if ((element.nodeId === 'bySeverity' || element.label === 'By severity') && s?.bySeverity) {
      return [
        new SummaryItem('Error', String(s.bySeverity.error ?? 0)),
        new SummaryItem('Warning', String(s.bySeverity.warning ?? 0)),
        new SummaryItem('Info', String(s.bySeverity.info ?? 0)),
      ];
    }
    if ((element.nodeId === 'byImpact' || element.label === 'By impact') && s?.byImpact) {
      return [
        new SummaryItem('Critical', String(s.byImpact.critical ?? 0)),
        new SummaryItem('High', String(s.byImpact.high ?? 0)),
        new SummaryItem('Medium', String(s.byImpact.medium ?? 0)),
        new SummaryItem('Low', String(s.byImpact.low ?? 0)),
        new SummaryItem('Opinionated', String(s.byImpact.opinionated ?? 0)),
      ];
    }

    return [];
  }
}
