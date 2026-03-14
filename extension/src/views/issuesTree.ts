/**
 * Tree data provider for Saropa Lints Issues view.
 * Structure: Severity (Error, Warning, Info) → folder path tree → file → violations (capped).
 * Supports text/type filters and suppressions (hide folder, file, rule). Scale-safe for 65k+ issues.
 */

import * as vscode from 'vscode';
import * as path from 'path';
import { readViolations, hasViolations, Violation } from '../violationsReader';
import {
  loadSuppressions,
  saveSuppressions,
  Suppressions,
  isPathHidden,
  isRuleHidden,
  addHiddenFolder,
  addHiddenFile,
  addHiddenRule,
  addHiddenRuleInFile,
  addHiddenSeverity,
  addHiddenImpact,
  clearSuppressions,
} from '../suppressionsStore';

const SEVERITY_ORDER = ['error', 'warning', 'info'] as const;
const DEFAULT_PAGE_SIZE = 100;
const MESSAGE_LABEL_LEN = 56;

function getPageSize(): number {
  const n = vscode.workspace.getConfiguration('saropaLints').get<number>('issuesPageSize', DEFAULT_PAGE_SIZE);
  return Math.max(1, Math.min(1000, typeof n === 'number' && !Number.isNaN(n) ? n : DEFAULT_PAGE_SIZE));
}

type IssueTreeNode =
  | SeverityItem
  | FolderItem
  | FileItem
  | ViolationItem
  | OverflowItem
  | PlaceholderItem;

interface SeverityItem {
  kind: 'severity';
  severity: string;
  count: number;
}

interface FolderItem {
  kind: 'folder';
  severity: string;
  pathPrefix: string;
  segmentName: string;
  count: number;
}

interface FileItem {
  kind: 'file';
  severity: string;
  filePath: string;
  violations: Violation[];
}

interface ViolationItem {
  kind: 'violation';
  violation: Violation;
}

interface OverflowItem {
  kind: 'overflow';
  filePath: string;
  severity: string;
  count: number;
}

interface PlaceholderItem {
  kind: 'placeholder';
  id: 'loading' | 'no-data' | 'no-match';
  label: string;
  description?: string;
  command?: string;
}

function normalizePath(p: string): string {
  return p.replace(/\\/g, '/');
}

/** Build index: severity -> file path -> violations[]. Only includes violations that pass filters and suppressions. */
function buildFilteredIndex(
  violations: Violation[],
  textFilter: string,
  severitiesToShow: Set<string>,
  impactsToShow: Set<string>,
  rulesToHide: Set<string>,
  suppressions: Suppressions,
): Map<string, Map<string, Violation[]>> {
  const text = textFilter.trim().toLowerCase();
  const bySeverity = new Map<string, Map<string, Violation[]>>();
  for (const v of violations) {
    const severity = (v.severity ?? 'info').toLowerCase();
    const impact = (v.impact ?? 'low').toLowerCase();
    if (!severitiesToShow.has(severity) || !impactsToShow.has(impact)) continue;
    if (suppressions.hiddenSeverities.includes(severity) || suppressions.hiddenImpacts.includes(impact)) continue;
    if (rulesToHide.has(v.rule)) continue;
    if (isPathHidden(suppressions, v.file)) continue;
    if (isRuleHidden(suppressions, v.file, v.rule)) continue;
    if (text) {
      const file = normalizePath(v.file);
      const match =
        file.includes(text) ||
        v.rule.toLowerCase().includes(text) ||
        (v.message && v.message.toLowerCase().includes(text));
      if (!match) continue;
    }
    let byFile = bySeverity.get(severity);
    if (!byFile) {
      byFile = new Map();
      bySeverity.set(severity, byFile);
    }
    const list = byFile.get(v.file) ?? [];
    list.push(v);
    byFile.set(v.file, list);
  }
  return bySeverity;
}

/** Get immediate children path segments under a folder prefix. Returns { folders: [name], files: [{ path, violations }] }. */
function getPathTreeChildren(
  severity: string,
  pathPrefix: string,
  byFile: Map<string, Violation[]>,
): { folders: string[]; files: { path: string; violations: Violation[] }[] } {
  const prefix = pathPrefix ? pathPrefix + '/' : '';
  const folderSet = new Set<string>();
  const files: { path: string; violations: Violation[] }[] = [];
  for (const [filePath, list] of byFile.entries()) {
    if (!filePath.startsWith(prefix)) continue;
    const rest = filePath.slice(prefix.length);
    const parts = rest.split('/');
    if (parts.length === 1) {
      files.push({ path: filePath, violations: list });
    } else {
      folderSet.add(parts[0]);
    }
  }
  const folders = Array.from(folderSet).sort();
  files.sort((a, b) => a.path.localeCompare(b.path));
  return { folders, files };
}

function violationLabel(v: Violation): string {
  const msg = (v.message ?? '').slice(0, MESSAGE_LABEL_LEN);
  return `L${v.line}: [${v.rule}] ${msg}${msg.length >= MESSAGE_LABEL_LEN ? '…' : ''}`;
}

export class IssuesTreeProvider implements vscode.TreeDataProvider<IssueTreeNode> {
  private _onDidChangeTreeData = new vscode.EventEmitter<IssueTreeNode | undefined | void>();
  readonly onDidChangeTreeData = this._onDidChangeTreeData.event;

  private workspaceState: vscode.Memento;
  private suppressions: Suppressions;
  private textFilter = '';
  private severitiesToShow = new Set<string>(SEVERITY_ORDER);
  private impactsToShow = new Set<string>(['critical', 'high', 'medium', 'low', 'opinionated']);
  private rulesToHide = new Set<string>();
  private cachedIndex: Map<string, Map<string, Violation[]>> | null = null;
  private totalUnfiltered = 0;

  constructor(workspaceState: vscode.Memento) {
    this.workspaceState = workspaceState;
    this.suppressions = loadSuppressions(workspaceState);
  }

  hasViolations(): boolean {
    const root = vscode.workspace.workspaceFolders?.[0]?.uri.fsPath;
    return root ? hasViolations(root) : false;
  }

  refresh(): void {
    this.cachedIndex = null;
    this._onDidChangeTreeData.fire();
  }

  getTypeFilterState(): { severitiesToShow: Set<string>; impactsToShow: Set<string> } {
    return {
      severitiesToShow: new Set(this.severitiesToShow),
      impactsToShow: new Set(this.impactsToShow),
    };
  }

  /** Rule names that have violations in current data (for Filter by rule). */
  getRuleNamesFromData(): string[] {
    const root = vscode.workspace.workspaceFolders?.[0]?.uri.fsPath;
    if (!root) return [];
    const data = readViolations(root);
    const violations = data?.violations ?? [];
    const set = new Set<string>();
    for (const v of violations) set.add(v.rule);
    return Array.from(set).sort();
  }

  getRulesToHide(): Set<string> {
    return new Set(this.rulesToHide);
  }

  getFilterState(): {
    textFilter: string;
    hasActiveFilters: boolean;
    hasSuppressions: boolean;
    totalUnfiltered: number;
    filteredCount: number;
  } {
    const root = vscode.workspace.workspaceFolders?.[0]?.uri.fsPath;
    let totalUnfiltered = this.totalUnfiltered;
    let filteredCount = 0;
    if (this.cachedIndex) {
      for (const byFile of this.cachedIndex.values()) {
        for (const list of byFile.values()) filteredCount += list.length;
      }
    } else if (root) {
      const data = readViolations(root);
      const violations = data?.violations ?? [];
      totalUnfiltered = violations.length;
      const idx = buildFilteredIndex(
        violations,
        this.textFilter,
        this.severitiesToShow,
        this.impactsToShow,
        this.rulesToHide,
        this.suppressions,
      );
      this.cachedIndex = idx;
      this.totalUnfiltered = totalUnfiltered;
      for (const byFile of idx.values()) {
        for (const list of byFile.values()) filteredCount += list.length;
      }
    }
    const hasActiveFilters =
      this.textFilter.trim() !== '' ||
      this.severitiesToShow.size < 3 ||
      this.impactsToShow.size < 5 ||
      this.rulesToHide.size > 0;
    const hasSuppressions =
      this.suppressions.hiddenFolders.length > 0 ||
      this.suppressions.hiddenFiles.length > 0 ||
      this.suppressions.hiddenRules.length > 0 ||
      Object.keys(this.suppressions.hiddenRuleInFile).length > 0 ||
      this.suppressions.hiddenSeverities.length > 0 ||
      this.suppressions.hiddenImpacts.length > 0;
    return {
      textFilter: this.textFilter,
      hasActiveFilters,
      hasSuppressions,
      totalUnfiltered,
      filteredCount,
    };
  }

  setTextFilter(value: string): void {
    this.textFilter = value;
    this.cachedIndex = null;
    this._onDidChangeTreeData.fire();
  }

  setSeverityFilter(severities: Set<string>): void {
    this.severitiesToShow = new Set(severities);
    this.cachedIndex = null;
    this._onDidChangeTreeData.fire();
  }

  setImpactFilter(impacts: Set<string>): void {
    this.impactsToShow = new Set(impacts);
    this.cachedIndex = null;
    this._onDidChangeTreeData.fire();
  }

  setRulesToHide(rules: Set<string>): void {
    this.rulesToHide = new Set(rules);
    this.cachedIndex = null;
    this._onDidChangeTreeData.fire();
  }

  clearFilters(): void {
    this.textFilter = '';
    this.severitiesToShow = new Set(SEVERITY_ORDER);
    this.impactsToShow = new Set(['critical', 'high', 'medium', 'low', 'opinionated']);
    this.rulesToHide = new Set();
    this.cachedIndex = null;
    this._onDidChangeTreeData.fire();
  }

  clearSuppressionsAndRefresh(): void {
    this.suppressions = clearSuppressions();
    saveSuppressions(this.workspaceState, this.suppressions);
    this.cachedIndex = null;
    this._onDidChangeTreeData.fire();
  }

  addSuppressionFolder(folderPath: string): void {
    this.suppressions = addHiddenFolder(this.suppressions, folderPath);
    saveSuppressions(this.workspaceState, this.suppressions);
    this.cachedIndex = null;
    this._onDidChangeTreeData.fire();
  }

  addSuppressionFile(filePath: string): void {
    this.suppressions = addHiddenFile(this.suppressions, filePath);
    saveSuppressions(this.workspaceState, this.suppressions);
    this.cachedIndex = null;
    this._onDidChangeTreeData.fire();
  }

  addSuppressionRule(rule: string): void {
    this.suppressions = addHiddenRule(this.suppressions, rule);
    saveSuppressions(this.workspaceState, this.suppressions);
    this.cachedIndex = null;
    this._onDidChangeTreeData.fire();
  }

  addSuppressionRuleInFile(filePath: string, rule: string): void {
    this.suppressions = addHiddenRuleInFile(this.suppressions, filePath, rule);
    saveSuppressions(this.workspaceState, this.suppressions);
    this.cachedIndex = null;
    this._onDidChangeTreeData.fire();
  }

  addSuppressionSeverity(severity: string): void {
    this.suppressions = addHiddenSeverity(this.suppressions, severity);
    saveSuppressions(this.workspaceState, this.suppressions);
    this.cachedIndex = null;
    this._onDidChangeTreeData.fire();
  }

  addSuppressionImpact(impact: string): void {
    this.suppressions = addHiddenImpact(this.suppressions, impact);
    saveSuppressions(this.workspaceState, this.suppressions);
    this.cachedIndex = null;
    this._onDidChangeTreeData.fire();
  }

  private getIndex(root: string): Map<string, Map<string, Violation[]>> | null {
    const data = readViolations(root);
    if (!data) return null;
    const violations = data.violations ?? [];
    this.totalUnfiltered = violations.length;
    this.cachedIndex = buildFilteredIndex(
      violations,
      this.textFilter,
      this.severitiesToShow,
      this.impactsToShow,
      this.rulesToHide,
      this.suppressions,
    );
    return this.cachedIndex;
  }

  getTreeItem(element: IssueTreeNode): vscode.TreeItem {
    const wsRoot = vscode.workspace.workspaceFolders?.[0]?.uri.fsPath ?? '';
    if (element.kind === 'placeholder') {
      const item = new vscode.TreeItem(
        element.label,
        vscode.TreeItemCollapsibleState.None,
      );
      item.description = element.description;
      item.iconPath =
        element.id === 'no-data'
          ? new vscode.ThemeIcon('run')
          : element.id === 'no-match'
            ? new vscode.ThemeIcon('filter')
            : new vscode.ThemeIcon('loading');
      if (element.command) {
        item.command = {
          command: element.command,
          title: element.id === 'no-match' ? 'Clear filters' : 'Run Analysis',
        };
      }
      item.contextValue = 'placeholder';
      return item;
    }
    if (element.kind === 'severity') {
      const label = `${element.severity.charAt(0).toUpperCase() + element.severity.slice(1)} (${element.count})`;
      const item = new vscode.TreeItem(
        label,
        vscode.TreeItemCollapsibleState.Collapsed,
      );
      item.iconPath = new vscode.ThemeIcon(
        element.severity === 'error' ? 'error' : element.severity === 'warning' ? 'warning' : 'info',
      );
      item.tooltip = `${element.count} ${element.severity}(s)`;
      item.contextValue = 'severity';
      item.accessibilityInformation = { label: `${element.severity}, ${element.count} issues`, role: 'treeitem' };
      return item;
    }
    if (element.kind === 'folder') {
      const item = new vscode.TreeItem(
        element.segmentName,
        vscode.TreeItemCollapsibleState.Collapsed,
      );
      item.iconPath = new vscode.ThemeIcon('folder');
      item.description = `${element.count} issues`;
      item.tooltip = `${element.pathPrefix || element.segmentName}/ — ${element.count} issues`;
      item.contextValue = 'folder';
      item.accessibilityInformation = {
        label: `${element.segmentName}, ${element.count} issues`,
        role: 'treeitem',
      };
      return item;
    }
    if (element.kind === 'file') {
      const base = path.basename(element.filePath);
      const item = new vscode.TreeItem(
        `${base} (${element.violations.length})`,
        vscode.TreeItemCollapsibleState.Collapsed,
      );
      item.resourceUri = vscode.Uri.file(path.join(wsRoot, element.filePath));
      item.iconPath = new vscode.ThemeIcon('document');
      item.description = element.filePath;
      item.tooltip = `${element.filePath} — ${element.violations.length} ${element.severity}(s)`;
      item.contextValue = 'file';
      item.accessibilityInformation = {
        label: `${base}, ${element.violations.length} issues`,
        role: 'treeitem',
      };
      return item;
    }
    if (element.kind === 'violation') {
      const v = element.violation;
      const item = new vscode.TreeItem(
        violationLabel(v),
        vscode.TreeItemCollapsibleState.None,
      );
      item.resourceUri = vscode.Uri.file(path.join(wsRoot, v.file));
      item.command = {
        command: 'vscode.open',
        title: 'Open',
        arguments: [
          item.resourceUri,
          { selection: new vscode.Range(v.line - 1, 0, v.line - 1, 0) },
        ],
      };
      const tooltip = new vscode.MarkdownString();
      tooltip.appendMarkdown((v.message ?? '').replace(/]/g, '\\]'));
      if (v.correction) {
        tooltip.appendMarkdown('\n\n**Fix:** ');
        tooltip.appendMarkdown(v.correction.replace(/]/g, '\\]'));
      }
      item.tooltip = tooltip;
      item.contextValue = 'violation';
      item.accessibilityInformation = {
        label: `Line ${v.line} ${v.rule}, ${(v.message ?? '').slice(0, 40)}`,
        role: 'button',
      };
      return item;
    }
    if (element.kind === 'overflow') {
      const item = new vscode.TreeItem(
        `and ${element.count} more…`,
        vscode.TreeItemCollapsibleState.None,
      );
      item.iconPath = new vscode.ThemeIcon('ellipsis');
      item.tooltip = 'Open file or use Problems view to see all';
      item.resourceUri = vscode.Uri.file(path.join(wsRoot, element.filePath));
      item.command = {
        command: 'vscode.open',
        title: 'Open file',
        arguments: [item.resourceUri],
      };
      item.contextValue = 'overflow';
      return item;
    }
    return new vscode.TreeItem('', vscode.TreeItemCollapsibleState.None);
  }

  async getChildren(element?: IssueTreeNode): Promise<IssueTreeNode[]> {
    const root = vscode.workspace.workspaceFolders?.[0]?.uri.fsPath;
    if (!root) return [];

    const data = readViolations(root);
    if (!data) {
      if (!element) {
        return [
          {
            kind: 'placeholder',
            id: 'no-data',
            label: 'No violations file yet. Run analysis.',
            command: 'saropaLints.runAnalysis',
          },
        ];
      }
      return [];
    }

    const violations = data.violations ?? [];
    if (violations.length === 0 && !element) {
      return [
        {
          kind: 'placeholder',
          id: 'no-data',
          label: 'No violations',
          description: 'Run analysis to see issues',
          command: 'saropaLints.runAnalysis',
        },
      ];
    }

    const index = this.getIndex(root);
    if (!index) return [];

    let filteredTotal = 0;
    for (const byFile of index.values()) {
      for (const list of byFile.values()) filteredTotal += list.length;
    }
    if (filteredTotal === 0 && !element) {
      return [
        {
          kind: 'placeholder',
          id: 'no-match',
          label: 'No issues match your filters',
          description: 'Clear filters or suppressions',
          command: 'saropaLints.clearIssuesFilters',
        },
      ];
    }

    if (!element) {
      const items: SeverityItem[] = [];
      for (const sev of SEVERITY_ORDER) {
        const byFile = index.get(sev);
        if (!byFile) continue;
        let count = 0;
        for (const list of byFile.values()) count += list.length;
        if (count > 0) items.push({ kind: 'severity', severity: sev, count });
      }
      return items;
    }

    if (element.kind === 'severity') {
      const byFile = index.get(element.severity);
      if (!byFile) return [];
      const { folders, files } = getPathTreeChildren(element.severity, '', byFile);
      const result: IssueTreeNode[] = [];
      for (const name of folders) {
        const pathPrefix = ''; // root-level folder: no prefix
        const segmentName = name;
        let count = 0;
        for (const [filePath, list] of byFile.entries()) {
          if (filePath === segmentName || filePath.startsWith(segmentName + '/')) count += list.length;
        }
        result.push({
          kind: 'folder',
          severity: element.severity,
          pathPrefix,
          segmentName,
          count,
        });
      }
      for (const { path: filePath, violations: list } of files) {
        result.push({
          kind: 'file',
          severity: element.severity,
          filePath,
          violations: list,
        });
      }
      return result;
    }

    if (element.kind === 'folder') {
      const byFile = index.get(element.severity);
      if (!byFile) return [];
      const prefix = element.pathPrefix ? `${element.pathPrefix}/${element.segmentName}` : element.segmentName;
      const { folders, files } = getPathTreeChildren(element.severity, prefix, byFile);
      const result: IssueTreeNode[] = [];
      for (const name of folders) {
        const nextPrefix = `${prefix}/${name}`;
        let count = 0;
        for (const [filePath, list] of byFile.entries()) {
          if (filePath === nextPrefix || filePath.startsWith(nextPrefix + '/')) count += list.length;
        }
        result.push({
          kind: 'folder',
          severity: element.severity,
          pathPrefix: prefix,
          segmentName: name,
          count,
        });
      }
      for (const { path: filePath, violations: list } of files) {
        result.push({
          kind: 'file',
          severity: element.severity,
          filePath,
          violations: list,
        });
      }
      return result;
    }

    if (element.kind === 'file') {
      const list = element.violations;
      const sorted = [...list].sort((a, b) => a.line - b.line);
      const pageSize = getPageSize();
      const page = sorted.slice(0, pageSize);
      const result: IssueTreeNode[] = page.map((v) => ({ kind: 'violation', violation: v }));
      const rest = sorted.length - pageSize;
      if (rest > 0) {
        result.push({
          kind: 'overflow',
          filePath: element.filePath,
          severity: element.severity,
          count: rest,
        });
      }
      return result;
    }

    return [];
  }

  getParent(element: IssueTreeNode): vscode.ProviderResult<IssueTreeNode> {
    return undefined;
  }
}

function folderPath(e: FolderItem): string {
  return e.pathPrefix ? `${e.pathPrefix}/${e.segmentName}` : e.segmentName;
}

export function registerIssueCommands(
  provider: IssuesTreeProvider,
  context: vscode.ExtensionContext,
): void {
  context.subscriptions.push(
    vscode.commands.registerCommand('saropaLints.hideFolder', (element: unknown) => {
      if (element && typeof element === 'object' && 'kind' in element && (element as IssueTreeNode).kind === 'folder') {
        provider.addSuppressionFolder(folderPath(element as FolderItem));
        vscode.window.setStatusBarMessage('Folder hidden. Clear suppressions to show again.', 3000);
      }
    }),
    vscode.commands.registerCommand('saropaLints.hideFile', (element: unknown) => {
      if (element && typeof element === 'object' && 'kind' in element && (element as IssueTreeNode).kind === 'file') {
        provider.addSuppressionFile((element as FileItem).filePath);
        vscode.window.setStatusBarMessage('File hidden. Clear suppressions to show again.', 3000);
      }
    }),
    vscode.commands.registerCommand('saropaLints.hideRule', (element: unknown) => {
      if (element && typeof element === 'object' && 'kind' in element && (element as IssueTreeNode).kind === 'violation') {
        provider.addSuppressionRule((element as ViolationItem).violation.rule);
        vscode.window.setStatusBarMessage('Rule hidden. Clear suppressions to show again.', 3000);
      }
    }),
    vscode.commands.registerCommand('saropaLints.hideRuleInFile', (element: unknown) => {
      if (element && typeof element === 'object' && 'kind' in element && (element as IssueTreeNode).kind === 'violation') {
        const v = (element as ViolationItem).violation;
        provider.addSuppressionRuleInFile(v.file, v.rule);
        vscode.window.setStatusBarMessage('Rule hidden in this file. Clear suppressions to show again.', 3000);
      }
    }),
    vscode.commands.registerCommand('saropaLints.hideSeverity', (element: unknown) => {
      if (element && typeof element === 'object' && 'kind' in element && (element as IssueTreeNode).kind === 'severity') {
        provider.addSuppressionSeverity((element as SeverityItem).severity);
        vscode.window.setStatusBarMessage('Severity hidden. Clear suppressions to show again.', 3000);
      }
    }),
    vscode.commands.registerCommand('saropaLints.hideImpact', (element: unknown) => {
      if (element && typeof element === 'object' && 'kind' in element && (element as IssueTreeNode).kind === 'violation') {
        const impact = ((element as ViolationItem).violation.impact ?? 'low').toLowerCase();
        provider.addSuppressionImpact(impact);
        vscode.window.setStatusBarMessage('Impact hidden. Clear suppressions to show again.', 3000);
      }
    }),
    vscode.commands.registerCommand('saropaLints.copyPath', (element: unknown) => {
      if (element && typeof element === 'object' && 'kind' in element) {
        const e = element as IssueTreeNode;
        let p = '';
        if (e.kind === 'folder') p = folderPath(e);
        else if (e.kind === 'file') p = e.filePath;
        if (p) void vscode.env.clipboard.writeText(p);
      }
    }),
    vscode.commands.registerCommand('saropaLints.copyMessage', (element: unknown) => {
      if (element && typeof element === 'object' && 'kind' in element && (element as IssueTreeNode).kind === 'violation') {
        const msg = (element as ViolationItem).violation.message ?? '';
        void vscode.env.clipboard.writeText(msg);
      }
    }),
  );
}
