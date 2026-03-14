/**
 * Tree data provider for Saropa Lints Logs view.
 * Lists report logs under reports/ (analysis, test, publish) and opens on click.
 */

import * as vscode from 'vscode';
import * as path from 'path';
import * as fs from 'fs';

const LOG_PATTERNS = [
  /_analysis_violations_.*\.log$/,
  /_dart_test.*\.log$/,
  /_saropa_lints_full_audit\.md$/,
];

class LogItem extends vscode.TreeItem {
  constructor(
    label: string,
    public readonly fullPath: string,
    public readonly kind: 'file' | 'folder',
  ) {
    super(
      label,
      kind === 'folder' ? vscode.TreeItemCollapsibleState.Expanded : vscode.TreeItemCollapsibleState.None,
    );
    if (kind === 'file') {
      this.resourceUri = vscode.Uri.file(fullPath);
      this.command = {
        command: 'vscode.open',
        title: 'Open Log',
        arguments: [this.resourceUri],
      };
      this.iconPath = new vscode.ThemeIcon('output');
    } else {
      this.iconPath = new vscode.ThemeIcon('folder');
    }
  }
}

export class LogsTreeProvider implements vscode.TreeDataProvider<LogItem> {
  private _onDidChangeTreeData = new vscode.EventEmitter<LogItem | undefined | void>();
  readonly onDidChangeTreeData = this._onDidChangeTreeData.event;

  refresh(): void {
    this._onDidChangeTreeData.fire();
  }

  getTreeItem(element: LogItem): vscode.TreeItem {
    return element;
  }

  async getChildren(element?: LogItem): Promise<LogItem[]> {
    const root = vscode.workspace.workspaceFolders?.[0]?.uri.fsPath;
    // C5: Return empty for no-workspace so viewsWelcome renders.
    if (!root) return [];

    const reportsDir = path.join(root, 'reports');
    // C5: Return empty when no reports/ folder so viewsWelcome "Run Analysis" shows.
    if (!fs.existsSync(reportsDir)) return [];

    if (!element) {
      const dirs = fs.readdirSync(reportsDir, { withFileTypes: true })
        .filter((d) => d.isDirectory() && /^\d{8}$/.test(d.name))
        .map((d) => new LogItem(d.name, path.join(reportsDir, d.name), 'folder'))
        .sort((a, b) => (b.label as string).localeCompare(a.label as string))
        .slice(0, 30);
      if (dirs.length === 0) {
        const files = fs.readdirSync(reportsDir, { withFileTypes: true })
          .filter((d) => d.isFile() && LOG_PATTERNS.some((p) => p.test(d.name)))
          .map((d) => new LogItem(d.name, path.join(reportsDir, d.name), 'file'))
          .sort((a, b) => (b.label as string).localeCompare(a.label as string))
          .slice(0, 20);
        return files.length ? files : [new LogItem('No log files found', '', 'file')];
      }
      return dirs;
    }

    if (element.kind === 'folder') {
      const names = fs.readdirSync(element.fullPath, { withFileTypes: true });
      return names
        .filter((d) => d.isFile() && (d.name.endsWith('.log') || d.name.endsWith('.md')))
        .map((d) => new LogItem(d.name, path.join(element.fullPath, d.name), 'file'))
        .sort((a, b) => (b.label as string).localeCompare(a.label as string))
        .slice(0, 50);
    }

    return [];
  }
}
