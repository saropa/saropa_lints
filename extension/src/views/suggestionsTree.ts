/**
 * Tree data provider for Saropa Lints Suggestions view.
 * "What to do next" from violations.json and workspace state.
 */

import * as vscode from 'vscode';
import * as path from 'path';
import * as fs from 'fs';
import { readViolations } from '../violationsReader';

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
    const root = vscode.workspace.workspaceFolders?.[0]?.uri.fsPath;
    const items: SuggestionItem[] = [];

    const cfg = vscode.workspace.getConfiguration('saropaLints');
    const enabled = cfg.get<boolean>('enabled', false) ?? false;

    if (!enabled) {
      items.push(new SuggestionItem('Enable Saropa Lints', 'One-click setup', 'saropaLints.enable'));
      return items;
    }

    const data = root ? readViolations(root) : null;
    const byImpact = data?.summary?.byImpact;
    const bySeverity = data?.summary?.bySeverity;
    const total = data?.summary?.totalViolations ?? data?.violations?.length ?? 0;
    const critical = byImpact?.critical ?? 0;
    const high = byImpact?.high ?? 0;
    const errors = bySeverity?.error ?? 0;

    if (critical > 0) {
      items.push(
        new SuggestionItem(
          `Fix ${critical} critical issue(s) first`,
          'Security/crash/memory',
          'saropaLints.runAnalysis',
        ),
      );
    }
    if (high > 0 && items.length < 3) {
      items.push(
        new SuggestionItem(
          `Address ${high} high-impact issue(s)`,
          'Significant quality issues',
          'saropaLints.runAnalysis',
        ),
      );
    }
    if (errors > 0 && !items.some((i) => String(i.label).includes('error'))) {
      items.push(
        new SuggestionItem(`Fix ${errors} analyzer error(s)`, 'See Problems view', 'saropaLints.runAnalysis'),
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

    if (items.length === 2) {
      return items;
    }
    return items.slice(0, 8);
  }
}
