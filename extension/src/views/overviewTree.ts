/**
 * Tree data provider for Saropa Lints Overview (dashboard) view.
 * Shows Health Score as the primary number, then issues, trends, and links.
 */

import * as vscode from 'vscode';
import { readViolations } from '../violationsReader';
import { loadHistory, getTrendSummary, getScoreTrendSummary, findPreviousScore, detectScoreRegression } from '../runHistory';
import { computeHealthScore, formatScoreDelta } from '../healthScore';

/** C1: Format an ISO timestamp as a human-readable relative time. */
function formatTimeAgo(iso: string): string {
  const ms = Date.now() - new Date(iso).getTime();
  if (ms < 0 || !Number.isFinite(ms)) return 'just now';
  const sec = Math.floor(ms / 1000);
  if (sec < 60) return 'just now';
  const min = Math.floor(sec / 60);
  if (min < 60) return `${min} min ago`;
  const hrs = Math.floor(min / 60);
  if (hrs < 24) return `${hrs}h ago`;
  const days = Math.floor(hrs / 24);
  return `${days}d ago`;
}

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

    // C5: Return empty array so VS Code's viewsWelcome content renders instead.
    if (!enabled) return [];

    const root = vscode.workspace.workspaceFolders?.[0]?.uri.fsPath;
    const data = root ? readViolations(root) : null;
    const total = data?.summary?.totalViolations ?? data?.violations?.length ?? 0;
    const critical = data?.summary?.byImpact?.critical ?? 0;

    const items: OverviewItem[] = [];

    // C5: No violations.json yet — return empty so viewsWelcome "Run Analysis" shows.
    if (!data) return [];

    // H2: Health Score — the primary number in Overview.
    // data is guaranteed non-null here (early return above handles null).
    const history = loadHistory(this.workspaceState);
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

    // Violation summary — secondary to the score.
    if (total > 0) {
      const issueLabel = critical > 0
        ? `${critical} critical, ${total} total`
        : `${total} violations`;
      items.push(
        new OverviewItem(issueLabel, 'View in Issues', 'saropaLints.focusIssues'),
      );
    } else {
      // Zero violations after analysis — clean project.
      items.push(
        new OverviewItem('No violations', 'All clear', 'saropaLints.focusIssues'),
      );
    }

    // D5: Score-driven trend — show score sparkline with time span.
    const scoreTrend = getScoreTrendSummary(history);
    if (scoreTrend) {
      items.push(new OverviewItem('Trends', scoreTrend, 'saropaLints.focusIssues'));
    } else {
      // Fall back to violation-count trend when no scores available yet.
      const trend = getTrendSummary(history);
      if (trend) {
        items.push(new OverviewItem('Trends', trend, 'saropaLints.focusIssues'));
      }
    }

    // D5: Regression alert — show when score dropped.
    const regression = detectScoreRegression(history);
    if (regression) {
      const criticalCount = data.summary?.byImpact?.critical ?? 0;
      const regDesc = criticalCount > 0
        ? `${criticalCount} critical violation${criticalCount === 1 ? '' : 's'}`
        : 'View issues';
      items.push(new OverviewItem(
        `Score dropped ${regression.previousScore} \u2192 ${regression.currentScore}`,
        regDesc,
        'saropaLints.focusIssues',
      ));
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

    // C1: "Last run" timestamp from most recent history entry.
    if (history.length > 0) {
      const lastTs = history[history.length - 1].timestamp;
      items.push(
        new OverviewItem('Last run', formatTimeAgo(lastTs), 'saropaLints.runAnalysis'),
      );
    }

    // C1: Primary CTA — always available for re-running analysis.
    items.push(
      new OverviewItem('Run Analysis', undefined, 'saropaLints.runAnalysis'),
    );

    items.push(
      new OverviewItem('Summary', undefined, 'saropaLints.summary.focus'),
      new OverviewItem('Config', undefined, 'saropaLints.config.focus'),
      new OverviewItem('Logs', undefined, 'saropaLints.logs.focus'),
      new OverviewItem('Suggestions', undefined, 'saropaLints.suggestions.focus'),
    );

    return items;
  }
}
