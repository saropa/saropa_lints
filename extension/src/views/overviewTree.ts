/**
 * Tree data provider for Saropa Lints Overview (dashboard) view.
 * Single entry point: key number, primary CTA, and links to other views.
 */

import * as vscode from 'vscode';
import { readViolations } from '../violationsReader';

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
        new OverviewItem(primaryLabel, 'View in Issues', 'saropaLints.focusView'),
        new OverviewItem('View Issues', undefined, 'saropaLints.focusView'),
      );
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
