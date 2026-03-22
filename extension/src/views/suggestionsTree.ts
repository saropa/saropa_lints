/**
 * Tree data provider for Saropa Lints Suggestions view.
 * "What to do next" from violations.json and workspace state.
 */

import * as vscode from 'vscode';
import * as path from 'path';
import * as fs from 'fs';
import { readViolations, type ViolationsData } from '../violationsReader';
import { computeHealthScore, estimateScoreWithout } from '../healthScore';
import { getProjectRoot } from '../projectRoot';

export { countSuggestionItems } from '../suggestionCounts';

class SuggestionItem extends vscode.TreeItem {
  constructor(
    label: string,
    description: string | undefined,
    public readonly commandId?: string,
    public readonly args: unknown[] = [],
  ) {
    super(label, vscode.TreeItemCollapsibleState.None);
    this.description = description;
    if (commandId) {
      this.command = { command: commandId, title: label, arguments: args };
    }
    this.iconPath = new vscode.ThemeIcon('lightbulb');
    this.contextValue = 'suggestionItem';
  }
}

export class SuggestionsTreeProvider implements vscode.TreeDataProvider<SuggestionItem> {
  private _onDidChangeTreeData = new vscode.EventEmitter<SuggestionItem | undefined | void>();
  readonly onDidChangeTreeData = this._onDidChangeTreeData.event;

  refresh(): void {
    this._onDidChangeTreeData.fire();
  }

  getTreeItem(element: SuggestionItem): vscode.TreeItem {
    return element;
  }

  async getChildren(): Promise<SuggestionItem[]> {
    const root = getProjectRoot();
    const items: SuggestionItem[] = [];
    const cfg = vscode.workspace.getConfiguration('saropaLints');

    const data = root ? readViolations(root) : null;
    // C5: When no data, return empty so viewsWelcome "Run analysis" shows.
    if (!data) return [];

    const byImpact = data?.summary?.byImpact;
    const bySeverity = data?.summary?.bySeverity;
    const total = data?.summary?.totalViolations ?? data?.violations?.length ?? 0;
    const critical = byImpact?.critical ?? 0;
    const high = byImpact?.high ?? 0;
    const errors = bySeverity?.error ?? 0;

    // C3: Compute current score and projected scores for impact suggestions.
    const currentScore = computeHealthScore(data)?.score;

    if (critical > 0) {
      // C3: Show estimated score gain from fixing all critical issues.
      // Skip score message when gain is zero ("+0 points" is not useful).
      const projected = estimateScoreWithout(data, 'critical');
      const gain = (currentScore !== undefined && projected !== null)
        ? projected - currentScore
        : null;
      const desc = (gain !== null && gain > 0)
        ? `estimated +${gain} points`
        : 'Show in Issues';
      items.push(
        new SuggestionItem(
          `Fix ${critical} critical issue(s)`,
          desc,
          'saropaLints.focusIssuesWithImpactFilter',
          ['critical'],
        ),
      );
    }
    if (high > 0 && items.length < 3) {
      const projected = estimateScoreWithout(data, 'high');
      const gain = (currentScore !== undefined && projected !== null)
        ? projected - currentScore
        : null;
      const desc = (gain !== null && gain > 0)
        ? `estimated +${gain} points`
        : 'Show in Issues';
      items.push(
        new SuggestionItem(
          `Address ${high} high-impact issue(s)`,
          desc,
          'saropaLints.focusIssuesWithImpactFilter',
          ['high'],
        ),
      );
    }
    if (errors > 0 && !items.some((i) => String(i.label).includes('error'))) {
      items.push(
        new SuggestionItem(
          `Fix ${errors} analyzer error(s)`,
          'Show in Issues',
          'saropaLints.focusIssuesWithSeverityFilter',
          ['error'],
        ),
      );
    }

    const baselinePath = root ? path.join(root, 'saropa_baseline.json') : '';
    if (total > 0 && root && !fs.existsSync(baselinePath)) {
      items.push(
        new SuggestionItem(
          'Create baseline to suppress existing violations',
          'New code still checked',
          'saropaLints.openConfig',
        ),
      );
    }

    const tier = cfg.get<string>('tier', 'recommended') ?? 'recommended';
    if (tier === 'recommended' && total > 0) {
      items.push(
        new SuggestionItem(
          'Consider professional tier for more rules',
          'Settings → saropaLints.tier',
          'saropaLints.initializeConfig',
        ),
      );
    }

    items.push(new SuggestionItem('Run analysis', 'Refresh violations', 'saropaLints.runAnalysis'));
    items.push(new SuggestionItem('Open config', 'analysis_options_custom.yaml', 'saropaLints.openConfig'));

    return items.slice(0, 8);
  }
}
