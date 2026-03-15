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

/** D12: Parse a log file's first few lines to extract a human-readable hint. */
function parseLogHint(filePath: string, fileName: string): string | undefined {
  // Extension reports — easy to identify by filename pattern.
  if (fileName.includes('_saropa_extension')) return 'Extension report';

  // Init logs — look for tier in first 10 lines.
  if (fileName.includes('_init') || fileName.includes('_saropa_lints_init')) {
    try {
      const head = fs.readFileSync(filePath, 'utf-8').slice(0, 1024);
      const tierMatch = head.match(/tier[:\s]+(\w+)/i);
      if (tierMatch) return `Init: ${tierMatch[1]}`;
    } catch { /* unreadable */ }
    return 'Init log';
  }

  // Lint/analysis reports — extract violation counts.
  if (fileName.includes('_lint_report') || fileName.includes('_analysis_violations') || fileName.includes('_full_audit')) {
    try {
      const head = fs.readFileSync(filePath, 'utf-8').slice(0, 2048);
      const errMatch = head.match(/(\d+)\s*error/i);
      const warnMatch = head.match(/(\d+)\s*warning/i);
      const parts: string[] = [];
      if (errMatch) parts.push(`${errMatch[1]} errors`);
      if (warnMatch) parts.push(`${warnMatch[1]} warnings`);
      if (parts.length > 0) return parts.join(', ');
    } catch { /* unreadable */ }
    return 'Analysis report';
  }

  return undefined;
}

class LogItem extends vscode.TreeItem {
  constructor(
    label: string,
    public readonly fullPath: string,
    public readonly logKind: 'file' | 'folder' | 'action',
  ) {
    super(
      label,
      logKind === 'folder' ? vscode.TreeItemCollapsibleState.Expanded : vscode.TreeItemCollapsibleState.None,
    );
    if (logKind === 'file') {
      this.resourceUri = vscode.Uri.file(fullPath);
      this.command = {
        command: 'vscode.open',
        title: 'Open Log',
        arguments: [this.resourceUri],
      };
      this.iconPath = new vscode.ThemeIcon('output');
      // D12: Add parsed description hint.
      const hint = parseLogHint(fullPath, label);
      if (hint) this.description = hint;
    } else if (logKind === 'action') {
      // D12: "Run Analysis" action item.
      this.iconPath = new vscode.ThemeIcon('run');
      this.command = {
        command: 'saropaLints.runAnalysis',
        title: 'Run Analysis',
      };
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
      // D12: Show "Run Analysis" action when latest report is >1 hour old.
      if (dirs.length > 0) {
        const latestDir = path.join(reportsDir, (dirs[0].label as string));
        try {
          const latestFiles = fs.readdirSync(latestDir, { withFileTypes: true })
            .filter((d) => d.isFile())
            .map((d) => fs.statSync(path.join(latestDir, d.name)).mtimeMs)
            .sort((a, b) => b - a);
          const newestMs = latestFiles.length > 0 ? latestFiles[0] : 0;
          if (newestMs > 0 && Date.now() - newestMs > 3_600_000) {
            dirs.push(new LogItem('Run Analysis (reports may be stale)', '', 'action'));
          }
        } catch { /* ignore stat errors */ }
      }
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

    if (element.logKind === 'folder') {
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
