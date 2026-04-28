/**
 * Tree data provider for suppressed diagnostics summary.
 * Reads suppression aggregates from violations.json summary.suppressions.
 */

import * as vscode from 'vscode';
import { readViolations, filterDisabledFromData } from '../violationsReader';
import { getProjectRoot } from '../projectRoot';
import { readDisabledRules } from '../configWriter';

type SuppressionsNodeId = 'byKind' | 'byRule' | 'byFile';

class SuppressionsItem extends vscode.TreeItem {
  constructor(
    label: string,
    description?: string,
    collapsible: vscode.TreeItemCollapsibleState = vscode.TreeItemCollapsibleState.None,
    readonly nodeId?: SuppressionsNodeId,
    commandId?: string,
    commandArgs?: unknown[],
  ) {
    super(label, collapsible);
    this.description = description;
    this.contextValue = 'suppressionsItem';
    if (commandId) {
      this.command = { command: commandId, title: label, arguments: commandArgs ?? [] };
    }
  }
}

export class SuppressionsTreeProvider implements vscode.TreeDataProvider<SuppressionsItem> {
  private readonly _onDidChangeTreeData = new vscode.EventEmitter<SuppressionsItem | undefined | void>();
  readonly onDidChangeTreeData = this._onDidChangeTreeData.event;

  refresh(): void {
    this._onDidChangeTreeData.fire();
  }

  getTreeItem(element: SuppressionsItem): vscode.TreeItem {
    return element;
  }

  async getChildren(element?: SuppressionsItem): Promise<SuppressionsItem[]> {
    const root = getProjectRoot();
    if (!root) return [];
    const raw = readViolations(root);
    if (!raw) return [];
    const data = filterDisabledFromData(raw, readDisabledRules(root));
    const sup = data.summary?.suppressions;
    if (!sup || (sup.total ?? 0) <= 0) return [];

    if (!element) {
      return [
        new SuppressionsItem('Total suppressions', String(sup.total ?? 0), vscode.TreeItemCollapsibleState.None, undefined, 'saropaLints.focusIssues'),
        new SuppressionsItem(
          'By kind',
          formatCountDescription(sup.byKind),
          vscode.TreeItemCollapsibleState.Collapsed,
          'byKind',
        ),
        new SuppressionsItem(
          'By rule',
          `${Object.keys(sup.byRule ?? {}).length} rules`,
          vscode.TreeItemCollapsibleState.Collapsed,
          'byRule',
        ),
        new SuppressionsItem(
          'By file',
          `${Object.keys(sup.byFile ?? {}).length} files`,
          vscode.TreeItemCollapsibleState.Collapsed,
          'byFile',
        ),
      ];
    }

    if (element.nodeId === 'byKind') {
      return Object.entries(sup.byKind ?? {})
        .sort((a, b) => b[1] - a[1] || a[0].localeCompare(b[0]))
        .map(([kind, count]) => new SuppressionsItem(prettifyToken(kind), String(count)));
    }
    if (element.nodeId === 'byRule') {
      return Object.entries(sup.byRule ?? {})
        .sort((a, b) => b[1] - a[1] || a[0].localeCompare(b[0]))
        .map(([rule, count]) =>
          new SuppressionsItem(
            rule,
            String(count),
            vscode.TreeItemCollapsibleState.None,
            undefined,
            'saropaLints.focusIssuesForRules',
            [[rule]],
          ),
        );
    }
    if (element.nodeId === 'byFile') {
      return Object.entries(sup.byFile ?? {})
        .sort((a, b) => b[1] - a[1] || a[0].localeCompare(b[0]))
        .map(([filePath, count]) =>
          new SuppressionsItem(
            filePath,
            String(count),
            vscode.TreeItemCollapsibleState.None,
            undefined,
            'saropaLints.openFileAndFocusIssues',
            [filePath],
          ),
        );
    }
    return [];
  }
}

function formatCountDescription(entries: Record<string, number> | undefined): string {
  if (!entries) return '—';
  const sorted = Object.entries(entries).sort((a, b) => b[1] - a[1]);
  return sorted.map(([k, v]) => `${k} ${v}`).join(', ');
}

function prettifyToken(token: string): string {
  if (!token) return 'Unknown';
  return token
    .replace(/([a-z])([A-Z])/g, '$1 $2')
    .replaceAll('_', ' ')
    .replaceAll('-', ' ')
    .replace(/\b\w/g, (c) => c.toUpperCase());
}
