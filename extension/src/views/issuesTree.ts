/**
 * Tree data provider for Saropa Lints Issues view.
 * Structure: Severity (Error, Warning, Info) → folder path tree → file → violations (capped).
 * Supports text/type filters and suppressions (hide folder, file, rule). Scale-safe for 65k+ issues.
 */

import * as vscode from 'vscode';
import * as path from 'path';
import { normalizePath } from '../pathUtils';
import { getRuleDescription, getRuleDocUrl } from '../ruleMetadata';
import { readViolations, hasViolations, Violation } from '../violationsReader';
import { computeHealthScore, estimateScoreWithoutViolation } from '../healthScore';
import { logReport, logSection, flushReport } from '../reportWriter';
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
import { normalizeOwaspId } from './securityPostureTree';
import { getProjectRoot } from '../projectRoot';

const SEVERITY_ORDER = ['error', 'warning', 'info'] as const;
const DEFAULT_PAGE_SIZE = 100;
const MESSAGE_LABEL_LEN = 56;

function getPageSize(): number {
  const n = vscode.workspace.getConfiguration('saropaLints').get<number>('issuesPageSize', DEFAULT_PAGE_SIZE);
  return Math.max(1, Math.min(1000, typeof n === 'number' && !Number.isNaN(n) ? n : DEFAULT_PAGE_SIZE));
}

/**
 * D10: Grouping modes for the Issues tree top level.
 * 'severity' is the default (Error/Warning/Info); other modes flatten
 * across severities and group by the chosen dimension.
 */
export type GroupByMode = 'severity' | 'file' | 'impact' | 'rule' | 'owasp';

/** Discriminated union for all node types in the Issues tree. */
type IssueTreeNode =
  | SeverityItem
  | FolderItem
  | FileItem
  | ViolationItem
  | OverflowItem
  | PlaceholderItem
  | GroupItem;

/**
 * D10: Generic group header for non-severity grouping modes.
 * Used by impact, rule, and owasp modes. Children are FileItem[]
 * sub-grouped from the violations list.
 */
interface GroupItem {
  kind: 'group';
  /** Snapshot of groupBy mode at creation time — prevents stale icon if mode changes between render cycles. */
  mode: GroupByMode;
  /** The raw key used for sorting and deduplication (e.g. 'critical', 'm1', rule name). */
  groupKey: string;
  /** Human-readable label shown in the tree (may be title-cased). */
  label: string;
  /** Total violations in this group. */
  count: number;
  /** All violations belonging to this group — sub-grouped by file when expanded. */
  violations: Violation[];
}

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

/** Build index: severity -> file path -> violations[]. Only includes violations that pass filters and suppressions. */
function buildFilteredIndex(
  violations: Violation[],
  textFilter: string,
  severitiesToShow: Set<string>,
  impactsToShow: Set<string>,
  rulesToHide: Set<string>,
  suppressions: Suppressions,
  focusedFile?: string,
): Map<string, Map<string, Violation[]>> {
  const text = textFilter.trim().toLowerCase();
  const bySeverity = new Map<string, Map<string, Violation[]>>();
  for (const v of violations) {
    // Focus mode: exact file match takes priority over all other filters.
    if (focusedFile && v.file !== focusedFile) continue;
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
  private focusedFile: string | undefined = undefined;
  private groupBy: GroupByMode = 'severity';
  private cachedIndex: Map<string, Map<string, Violation[]>> | null = null;
  private totalUnfiltered = 0;

  constructor(workspaceState: vscode.Memento) {
    this.workspaceState = workspaceState;
    this.suppressions = loadSuppressions(workspaceState);
  }

  hasViolations(): boolean {
    const root = getProjectRoot();
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
    const root = getProjectRoot();
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
    const root = getProjectRoot();
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
        this.focusedFile,
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
      this.rulesToHide.size > 0 ||
      this.focusedFile !== undefined;
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

  setFocusedFile(filePath: string): void {
    this.focusedFile = filePath;
    this.cachedIndex = null;
    this._onDidChangeTreeData.fire();
  }

  clearFocusedFile(): void {
    this.focusedFile = undefined;
    this.cachedIndex = null;
    this._onDidChangeTreeData.fire();
  }

  getFocusedFile(): string | undefined {
    return this.focusedFile;
  }

  clearFilters(): void {
    this.textFilter = '';
    this.severitiesToShow = new Set(SEVERITY_ORDER);
    this.impactsToShow = new Set(['critical', 'high', 'medium', 'low', 'opinionated']);
    this.rulesToHide = new Set();
    this.focusedFile = undefined;
    this.cachedIndex = null;
    this._onDidChangeTreeData.fire();
  }

  /** D10: Current grouping mode. */
  getGroupBy(): GroupByMode {
    return this.groupBy;
  }

  /** D10: Change the grouping mode and refresh. */
  setGroupBy(mode: GroupByMode): void {
    this.groupBy = mode;
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
      this.focusedFile,
    );
    return this.cachedIndex;
  }

  getTreeItem(element: IssueTreeNode): vscode.TreeItem {
    const wsRoot = getProjectRoot() ?? '';
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
      // D10: When grouped by file/impact/rule/owasp, severity is empty — use generic label.
      item.tooltip = element.severity
        ? `${element.filePath} — ${element.violations.length} ${element.severity}(s)`
        : `${element.filePath} — ${element.violations.length} violation${element.violations.length === 1 ? '' : 's'}`;
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
      const ruleName = v.rule ?? '';
      if (ruleName) {
        tooltip.appendMarkdown('\n\n**Rule:** `' + ruleName.replace(/`/g, '\\`') + '`');
        const desc = getRuleDescription(ruleName);
        if (desc) {
          tooltip.appendMarkdown('\n\n' + desc.replace(/]/g, '\\]'));
        }
        tooltip.appendMarkdown('\n\n[More](' + getRuleDocUrl(ruleName) + ')');
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
    // D10: Generic group item for impact/rule/owasp grouping.
    if (element.kind === 'group') {
      const item = new vscode.TreeItem(
        `${element.label} (${element.count})`,
        vscode.TreeItemCollapsibleState.Collapsed,
      );
      // D10: Mode-aware icon — reads from element.mode (snapshot at creation) to avoid stale this.groupBy.
      if (element.mode === 'impact') {
        const k = element.groupKey;
        item.iconPath = new vscode.ThemeIcon(
          k === 'critical' ? 'error' : k === 'high' ? 'warning' : k === 'medium' ? 'info' : 'circle-outline',
        );
      } else if (element.mode === 'owasp') {
        item.iconPath = new vscode.ThemeIcon('shield');
      } else {
        item.iconPath = new vscode.ThemeIcon('symbol-method');
      }
      item.tooltip = `${element.count} violation${element.count === 1 ? '' : 's'}`;
      item.contextValue = 'group';
      return item;
    }
    return new vscode.TreeItem('', vscode.TreeItemCollapsibleState.None);
  }

  async getChildren(element?: IssueTreeNode): Promise<IssueTreeNode[]> {
    const root = getProjectRoot();
    if (!root) return [];

    const data = readViolations(root);
    // C5: Return empty array when no violations file so viewsWelcome content renders.
    if (!data) return [];

    const violations = data.violations ?? [];
    // Zero violations after analysis — show a clean-state item (not empty,
    // because viewsWelcome would misleadingly say "No analysis results yet").
    if (violations.length === 0 && !element) {
      return [
        {
          kind: 'placeholder' as const,
          id: 'no-data' as const,
          label: 'No violations found',
          description: 'All clear',
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
      // D10: Delegate to grouping-mode-specific root builder.
      if (this.groupBy !== 'severity') {
        return this.buildGroupedRoot(index);
      }
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

    // D10: GroupItem children — sub-group violations by file for easy navigation.
    if (element.kind === 'group') {
      return buildFileItems(element.violations);
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

  /**
   * D10: Flatten all violations from the severity→file index into a single array.
   * Needed by non-severity grouping modes which ignore severity boundaries.
   */
  private collectAllViolations(index: Map<string, Map<string, Violation[]>>): Violation[] {
    const all: Violation[] = [];
    for (const byFile of index.values()) {
      for (const list of byFile.values()) {
        for (const v of list) all.push(v);
      }
    }
    return all;
  }

  /**
   * D10: Build root nodes for non-severity grouping modes.
   * File mode → flat FileItem[] sorted by violation count.
   * Impact/rule/owasp → GroupItem[] where each group header expands to FileItem[] children.
   * A single violation can appear in multiple OWASP groups (fan-out).
   */
  private buildGroupedRoot(index: Map<string, Map<string, Violation[]>>): IssueTreeNode[] {
    const all = this.collectAllViolations(index);

    // File mode bypasses GroupItem — returns FileItem[] directly.
    if (this.groupBy === 'file') {
      return buildFileItems(all);
    }

    // Snapshot mode once so extractGroupKeys and GroupItem.mode are consistent,
    // and getTreeItem reads element.mode instead of this.groupBy (avoids stale-icon race).
    const currentMode = this.groupBy;

    // Fan out violations into group buckets.
    // extractGroupKeys may return multiple keys (e.g. OWASP M1 + A03),
    // so one violation can appear under multiple group headers.
    const groups = new Map<string, Violation[]>();
    for (const v of all) {
      for (const key of this.extractGroupKeys(v, currentMode)) {
        const list = groups.get(key) ?? [];
        list.push(v);
        groups.set(key, list);
      }
    }

    const items: GroupItem[] = [];
    for (const [key, violations] of groups) {
      items.push({
        kind: 'group',
        mode: currentMode,
        groupKey: key,
        label: currentMode === 'impact' ? key.charAt(0).toUpperCase() + key.slice(1) : key,
        count: violations.length,
        violations,
      });
    }

    // Impact uses severity-like predefined order; others sort by count desc with name tie-breaker.
    if (currentMode === 'impact') {
      const order = ['critical', 'high', 'medium', 'low', 'opinionated'];
      items.sort((a, b) => order.indexOf(a.groupKey) - order.indexOf(b.groupKey));
    } else {
      items.sort((a, b) => b.count - a.count || a.groupKey.localeCompare(b.groupKey));
    }
    return items;
  }

  /**
   * D10: Extract grouping keys for a violation based on the given mode.
   * Returns an array because OWASP mode can map one violation to multiple categories.
   * Impact and rule modes always return exactly one key.
   * Accepts explicit mode parameter so callers use the snapshot, not live this.groupBy.
   */
  private extractGroupKeys(v: Violation, mode: GroupByMode): string[] {
    if (mode === 'impact') return [(v.impact ?? 'low').toLowerCase()];
    if (mode === 'rule') return [v.rule];
    if (mode === 'file') return [v.file];
    // OWASP: violation can map to multiple categories (e.g. both M1 and A03).
    // Use normalizeOwaspId (strip text after colon) to match the canonical IDs
    // used by securityPostureTree and owaspExport.
    const cats = [...(v.owasp?.mobile ?? []), ...(v.owasp?.web ?? [])].map(normalizeOwaspId);
    return cats.length > 0 ? cats : ['Uncategorized'];
  }

  getParent(element: IssueTreeNode): vscode.ProviderResult<IssueTreeNode> {
    return undefined;
  }
}

/** D10: Group violations by file into FileItem[], sorted by count desc then name. */
function buildFileItems(violations: Violation[]): FileItem[] {
  const byFile = new Map<string, Violation[]>();
  for (const v of violations) {
    const list = byFile.get(v.file) ?? [];
    list.push(v);
    byFile.set(v.file, list);
  }
  const items: FileItem[] = [];
  for (const [filePath, list] of byFile) {
    items.push({ kind: 'file', severity: '', filePath, violations: list });
  }
  // Sort by count descending, then by path ascending as tie-breaker for stable order.
  items.sort((a, b) => b.violations.length - a.violations.length || a.filePath.localeCompare(b.filePath));
  return items;
}

function folderPath(e: FolderItem): string {
  return e.pathPrefix ? `${e.pathPrefix}/${e.segmentName}` : e.segmentName;
}

/** Max end character for a line when requesting code actions (range is clamped by the editor). */
const APPLY_FIX_LINE_END = 4096;
/** Number of code actions to resolve when applying fix from tree (enough to find rule match). */
const APPLY_FIX_RESOLVE_COUNT = 10;

/**
 * Returns the string form of a diagnostic's code (VS Code allows code to be string, number, or { value }).
 */
function diagnosticCodeString(code: vscode.Diagnostic['code']): string {
  if (code === undefined || code === null) return '';
  if (typeof code === 'object' && code !== null && 'value' in code) {
    return String((code as { value: unknown }).value);
  }
  return String(code);
}

/**
 * Invokes the Dart analyzer's quick fix for the given violation at its file/line.
 * Prefers a code action matching the violation's rule; otherwise uses the first quick fix.
 */
async function applyFixForViolation(v: Violation, root: string): Promise<boolean> {
  const uri = vscode.Uri.file(path.join(root, v.file));
  const line = Math.max(0, (v.line ?? 1) - 1);
  const range = new vscode.Range(line, 0, line, APPLY_FIX_LINE_END);
  const codeActions = await vscode.commands.executeCommand<vscode.CodeAction[]>(
    'vscode.executeCodeActionProvider',
    uri,
    range,
    vscode.CodeActionKind.QuickFix.value,
    APPLY_FIX_RESOLVE_COUNT,
  );
  if (!Array.isArray(codeActions) || codeActions.length === 0) {
    void vscode.window.showInformationMessage('No quick fix available for this violation.');
    // D4: Return false — no fix was available.
    return false;
  }
  const rule = (v.rule ?? '').toString();
  const match = codeActions.find(
    (a) =>
      (Array.isArray(a.diagnostics) &&
        a.diagnostics.some((d) => diagnosticCodeString(d?.code) === rule)) ||
      (a.title && String(a.title).toLowerCase().includes(rule.toLowerCase())),
  );
  const action = match ?? codeActions[0];
  if (action.edit) {
    await vscode.workspace.applyEdit(action.edit);
  }
  if (action.command) {
    await vscode.commands.executeCommand(action.command.command, ...(action.command.arguments ?? []));
  }
  if (!action.edit && !action.command) {
    void vscode.window.showInformationMessage('No quick fix available for this violation.');
    // D4: Return false — code action had no edit or command.
    return false;
  }
  return true;
}

/**
 * D7: Fix all auto-fixable violations in a single file.
 * Processes violations bottom-up (descending line order) to avoid
 * line-number shifts invalidating subsequent fixes.
 */
async function fixAllInFile(
  violations: Violation[],
  root: string,
  progress: vscode.Progress<{ message?: string; increment?: number }>,
): Promise<{ fixed: number; skipped: number }> {
  const sorted = [...violations].sort((a, b) => (b.line ?? 0) - (a.line ?? 0));
  let fixed = 0;
  let skipped = 0;

  for (const v of sorted) {
    progress.report({ message: `${fixed + skipped + 1}/${sorted.length}` });
    const ok = await applyFixForViolation(v, root);
    if (ok) {
      fixed++;
    } else {
      skipped++;
    }
  }
  return { fixed, skipped };
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
    vscode.commands.registerCommand('saropaLints.applyFix', async (element: unknown) => {
      if (!element || typeof element !== 'object' || !('kind' in element) || (element as IssueTreeNode).kind !== 'violation') {
        return;
      }
      const v = (element as ViolationItem).violation;
      const root = getProjectRoot();
      if (!root) return;

      // D4: Estimate score delta before applying fix.
      const data = readViolations(root);
      const estimate = data ? estimateScoreWithoutViolation(data, v.impact ?? 'medium') : null;

      const applied = await vscode.window.withProgress(
        { location: vscode.ProgressLocation.Notification, title: 'Applying fix…', cancellable: false },
        () => applyFixForViolation(v, root),
      );

      // D4: Show score-aware result in status bar after successful fix.
      if (applied && estimate && estimate.delta > 0) {
        const pts = estimate.delta === 1 ? 'pt' : 'pts';
        void vscode.window.setStatusBarMessage(
          `Fixed 1 ${v.impact ?? ''} issue (est. +${estimate.delta} ${pts})`,
          4000,
        );
      }

      // Report: log fix attempt.
      if (root) {
        logSection('Fix');
        logReport(`- Rule: ${v.rule} (${v.file}:${v.line})`);
        logReport(`- Result: ${applied ? 'applied' : 'no fix available'}`);
        flushReport(root);
      }
    }),
    // D7: Fix all auto-fixable violations in a file.
    vscode.commands.registerCommand('saropaLints.fixAllInFile', async (element: unknown) => {
      if (!element || typeof element !== 'object' || !('kind' in element) ||
          (element as IssueTreeNode).kind !== 'file') return;
      const fileNode = element as FileItem;
      const root = getProjectRoot();
      if (!root) return;

      const data = readViolations(root);
      if (!data) return;
      const fileViolations = data.violations.filter(
        (v) => v.file === fileNode.filePath,
      );
      if (fileViolations.length === 0) return;

      // D7: Confirm before bulk-fixing files with many violations.
      const fileName = path.basename(fileNode.filePath);
      if (fileViolations.length > 20) {
        const ok = await vscode.window.showWarningMessage(
          `Fix ${fileViolations.length} violations in ${fileName}?`,
          { modal: true },
          'Fix All',
        );
        if (ok !== 'Fix All') return;
      }

      const result = await vscode.window.withProgress(
        {
          location: vscode.ProgressLocation.Notification,
          title: `Fixing violations in ${fileName}`,
          cancellable: false,
        },
        (progress) => fixAllInFile(fileViolations, root, progress),
      );

      // D7: Show result summary.
      const fixedMsg = `Fixed ${result.fixed}` +
        (result.skipped > 0 ? `, skipped ${result.skipped} (no fix available)` : '');
      void vscode.window.showInformationMessage(
        `${fixedMsg}. Run analysis to update score.`,
      );

      // Report: log bulk fix result.
      if (root) {
        logSection('Bulk Fix');
        logReport(`- File: ${fileNode.filePath}`);
        logReport(`- Fixed: ${result.fixed}, Skipped: ${result.skipped}`);
        flushReport(root);
      }

      // D7: Auto-run analysis after bulk fix to update score.
      const cfg = vscode.workspace.getConfiguration('saropaLints');
      const runAfter = cfg.get<boolean>('runAnalysisAfterConfigChange', true);
      if (runAfter && result.fixed > 0) {
        await vscode.commands.executeCommand('saropaLints.runAnalysis');
      }
    }),
  );
}
