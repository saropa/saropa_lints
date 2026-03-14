/**
 * Tree data provider for Saropa Lints Overview (dashboard) view.
 * Shows Health Score as the primary number, then issues, trends, and links.
 */

import * as vscode from 'vscode';
import { readViolations } from '../violationsReader';
import { loadHistory, getTrendSummary, findPreviousScore } from '../runHistory';
import { computeHealthScore, formatScoreDelta } from '../healthScore';

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

    if (total === 0 && !data) {
      items.push(
        new OverviewItem('No analysis yet', 'Run analysis to see issues', 'saropaLints.runAnalysis'),
        new OverviewItem('Run Analysis', undefined, 'saropaLints.runAnalysis'),
      );
      return items;
    }

    // H2: Health Score — the primary number in Overview.
    const history = loadHistory(this.workspaceState);
    if (data) {
      const health = computeHealthScore(data);
      if (health) {
        const prevScore = findPreviousScore(history);
        const delta = prevScore !== undefined
          ? formatScoreDelta(health.score, prevScore)
          : '';
        const scoreDesc = delta
          ? `${delta} from last run`
          : total === 0
            ? 'No violations'
            : `${total} violations`;
        items.push(
          new OverviewItem(
            `Health: ${health.score}`,
            scoreDesc,
            'saropaLints.focusIssues',
          ),
        );
      }
    }

    // Violation summary — secondary to the score.
    if (total > 0) {
      const issueLabel = critical > 0
        ? `${critical} critical, ${total} total`
        : `${total} violations`;
      items.push(
        new OverviewItem(issueLabel, 'View in Issues', 'saropaLints.focusIssues'),
      );
    } else if (data) {
      // Zero violations after analysis — clean project.
      items.push(
        new OverviewItem('No violations', 'All clear', 'saropaLints.focusIssues'),
      );
    }

    // W5: Trends — show run history summary.
    const trend = getTrendSummary(history);
    if (trend) {
      items.push(new OverviewItem('Trends', trend, 'saropaLints.focusIssues'));
    }

    // W6: Celebration — show delta when violations decreased.
    if (history.length >= 2) {
      const prev = history[history.length - 2];
      const curr = history[history.length - 1];
      const violationDelta = prev.total - curr.total;
      if (violationDelta > 0) {
        items.push(
          new OverviewItem(
            `\u2193 ${violationDelta} fewer issues`,
            'since last run',
            'saropaLints.focusIssues',
          ),
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
