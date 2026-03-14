/**
 * Tree data provider for Saropa Lints Overview (dashboard) view.
 * Single entry point: key number, primary CTA, trends, and links to other views.
 */

import * as vscode from 'vscode';
import { readViolations } from '../violationsReader';
import { loadHistory, getTrendSummary } from '../runHistory';

class OverviewItem extends vscode.TreeItem {
  constructor(
    label: string,
    description: string | undefined,
    commandId: string,
    args: unknown[] = [],
  ) {
    super(label, vscode.TreeItemCollapsibleState.None);
    this.description = description;
    this.command = { command: commandId, title: label, arguments: args };
  }
}

export class OverviewTreeProvider implements vscode.TreeDataProvider<OverviewItem> {
  private _onDidChangeTreeData = new vscode.EventEmitter<OverviewItem | undefined | void>();
  readonly onDidChangeTreeData = this._onDidChangeTreeData.event;
  private workspaceState: vscode.Memento;

  constructor(workspaceState: vscode.Memento) {
    this.workspaceState = workspaceState;
  }

  refresh(): void {
    this._onDidChangeTreeData.fire();
  }

  getTreeItem(element: OverviewItem): vscode.TreeItem {
    return element;
  }

  async getChildren(): Promise<OverviewItem[]> {
    const cfg = vscode.workspace.getConfiguration('saropaLints');
    const enabled = cfg.get<boolean>('enabled', false) ?? false;

    if (!enabled) {
      return [
        new OverviewItem('Saropa Lints is off', 'Enable to get started', 'saropaLints.enable'),
        new OverviewItem('Enable Saropa Lints', undefined, 'saropaLints.enable'),
      ];
    }

    const root = vscode.workspace.workspaceFolders?.[0]?.uri.fsPath;
    const data = root ? readViolations(root) : null;
    const total = data?.summary?.totalViolations ?? data?.violations?.length ?? 0;
    const critical = data?.summary?.byImpact?.critical ?? 0;

    const items: OverviewItem[] = [];

    if (total === 0) {
      items.push(
        new OverviewItem('No analysis yet', 'Run analysis to see issues', 'saropaLints.runAnalysis'),
        new OverviewItem('Run Analysis', undefined, 'saropaLints.runAnalysis'),
      );
    } else {
      const primaryLabel = critical > 0 ? `${critical} critical, ${total} total` : `${total} violations`;
      items.push(
        new OverviewItem(primaryLabel, 'View in Issues', 'saropaLints.focusIssues'),
        new OverviewItem('View Issues', undefined, 'saropaLints.focusIssues'),
      );
    }

    // W5: Trends — show run history summary.
    const history = loadHistory(this.workspaceState);
    const trend = getTrendSummary(history);
    if (trend) {
      items.push(new OverviewItem('Trends', trend, 'saropaLints.focusIssues'));
    }

    // W6: Celebration — show delta when violations decreased.
    if (history.length >= 2) {
      const prev = history[history.length - 2];
      const curr = history[history.length - 1];
      const delta = prev.total - curr.total;
      if (delta > 0) {
        items.push(
          new OverviewItem(`\u2193 ${delta} fewer issues`, 'since last run', 'saropaLints.focusIssues'),
        );
      }
    }

    items.push(
      new OverviewItem('Summary', undefined, 'saropaLints.summary.focus'),
      new OverviewItem('Config', undefined, 'saropaLints.config.focus'),
      new OverviewItem('Logs', undefined, 'saropaLints.logs.focus'),
      new OverviewItem('Suggestions', undefined, 'saropaLints.suggestions.focus'),
    );

    return items;
  }
}
