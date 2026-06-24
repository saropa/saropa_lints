/**
 * Headless tree data for lint findings (`violations.json`): same shape the Findings Dashboard uses
 * for filters, JSON export, and palette-driven actions (no activity-bar tree view).
 * Structure: Severity → folder path → file → violations (capped); supports suppressions and filters.
 */

import * as vscode from 'vscode';
import * as fs from 'fs';
import * as path from 'path';
import { normalizePath, cachedFileExists, clearFileExistsCache } from '../pathUtils';
import { getRelatedRules, getRuleDescription, getRuleDocUrl } from '../ruleMetadata';
import { Violation } from '../violationsReader';
// Status-bar score + this tree now read LIVE diagnostics (same source as the
// Findings wide report) instead of the stale violations.json export, so the
// count can never lag the Problems panel. Aliased to the former names to keep
// every call site below unchanged — only the data source moves. The tree's own
// disabled / text / suppression filtering still runs on the returned set.
import {
  readLiveViolations as readViolations,
  hasLiveViolations as hasViolations,
} from '../liveViolationsData';
import {
  SecurityHotspotReviewStateService,
  isSecurityHotspotViolation,
} from '../securityHotspotReviewState';
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
import { readDisabledRules } from '../configWriter';
import { l10n } from '../i18n/runtime';
import { packsForRule, tierForRule } from './ruleGroupingMeta';
import { VIOLATIONS_GROUP_BY_MODES, type GroupByMode } from './issuesTreeGrouping';

// The node types and the command registrar moved to sibling modules;
// re-export them so existing importers keep referencing issuesTree.ts.
import {
  IssueTreeNode,
  GroupItem,
  SeverityItem,
  FolderItem,
  FileItem,
  ViolationItem,
  OverflowItem,
  PlaceholderItem,
} from './issuesTreeTypes';
export type { IssueTreeNode } from './issuesTreeTypes';

const SEVERITY_ORDER = ['error', 'warning', 'info'] as const;
const DEFAULT_PAGE_SIZE = 100;
const MESSAGE_LABEL_LEN = 56;

const STALE_ICON = new vscode.ThemeIcon(
  'warning',
  new vscode.ThemeColor('problemsWarningIcon.foreground'),
);
const STALE_LABEL = '(file moved or deleted)';

/** Map a severity string to a colored ThemeIcon matching VS Code's diagnostic palette. */
function severityThemeIcon(severity: string): vscode.ThemeIcon {
  const name = severity === 'error' ? 'error' : severity === 'warning' ? 'warning' : 'info';
  const color = severity === 'error'
    ? 'list.errorForeground'
    : severity === 'warning'
      ? 'list.warningForeground'
      : 'editorInfo.foreground';
  return new vscode.ThemeIcon(name, new vscode.ThemeColor(color));
}

function getPageSize(): number {
  const n = vscode.workspace.getConfiguration('saropaLints').get<number>('issuesPageSize', DEFAULT_PAGE_SIZE);
  return Math.max(1, Math.min(1000, typeof n === 'number' && !Number.isNaN(n) ? n : DEFAULT_PAGE_SIZE));
}

/**
 * D10: Grouping modes for the Issues tree top level.
 * 'severity' is the default (Error/Warning/Info); other modes flatten
 * across severities and group by the chosen dimension.
 */
// GroupByMode + the mode list live in issuesTreeGrouping (the single source of
// truth shared with the dashboard); re-exported here so existing importers of
// this module keep resolving the type. Adding a mode there (e.g. tier/pack)
// flows to every consumer without editing a second list.
export type { GroupByMode };
const GROUP_BY_MODES = VIOLATIONS_GROUP_BY_MODES;

/** Default grouping for new workspaces: impact surfaces Critical / High first. */
export function parseViolationsGroupBy(cfg: vscode.WorkspaceConfiguration): GroupByMode {
  const raw = cfg.get<string>('violationsGroupBy', 'impact') ?? 'impact';
  return (GROUP_BY_MODES as readonly string[]).includes(raw) ? (raw as GroupByMode) : 'impact';
}

function prependIssuesHelpRow(nodes: IssueTreeNode[]): IssueTreeNode[] {
  return nodes;
}

function violationNumericPriority(v: Violation): number {
  if (typeof v.priority === 'number' && Number.isFinite(v.priority)) {
    return v.priority;
  }
  return -1;
}

/** Same ordering intent as violations.json after export: higher priority first, then line. */
function sortViolationsByReportPriority(a: Violation, b: Violation): number {
  const pa = violationNumericPriority(a);
  const pb = violationNumericPriority(b);
  if (pa !== pb) return pb - pa;
  return (a.line ?? 0) - (b.line ?? 0);
}

function maxViolationPriority(list: Violation[]): number {
  let m = -1;
  for (const v of list) {
    m = Math.max(m, violationNumericPriority(v));
  }
  return m;
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
    // Default fallback is 'info' (was 'low' under the 5-bucket impact
    // taxonomy retired 2026-05-03 — both are the lowest-priority bucket).
    const impact = (v.impact ?? 'info').toLowerCase();
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
  for (const byFile of bySeverity.values()) {
    for (const list of byFile.values()) {
      list.sort(sortViolationsByReportPriority);
    }
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
  // Three-bucket severity model (post-collapse, 2026-05-03 — see
  // plan/COLLAPSE_LINT_IMPACT_TO_SEVERITY.md).
  private impactsToShow = new Set<string>(['error', 'warning', 'info']);
  private rulesToHide = new Set<string>();
  /** Rules disabled in analysis_options.yaml / analysis_options_custom.yaml.
   *  Merged with user-set rulesToHide when filtering violations. */
  private configDisabledRules = new Set<string>();
  private focusedFile: string | undefined = undefined;
  private groupBy: GroupByMode;
  private cachedIndex: Map<string, Map<string, Violation[]>> | null = null;
  private totalUnfiltered = 0;
  /** Rules that have quick-fix generators. Null = unknown (older analyzer), treat all as fixable. */
  private rulesWithFixesSet: Set<string> | null = null;
  private readonly securityHotspotReviewState: SecurityHotspotReviewStateService;
  /** When true, getTreeItem() returns Expanded instead of Collapsed for all collapsible nodes. */
  private _expandAllOverride = false;

  constructor(workspaceState: vscode.Memento) {
    this.workspaceState = workspaceState;
    this.securityHotspotReviewState = new SecurityHotspotReviewStateService(workspaceState);
    this.suppressions = loadSuppressions(workspaceState);
    this.groupBy = parseViolationsGroupBy(vscode.workspace.getConfiguration('saropaLints'));
  }

  hasViolations(): boolean {
    const root = getProjectRoot();
    return root ? hasViolations(root) : false;
  }

  /** Expand all collapsible nodes on the next render. Cleared by any subsequent non-expand refresh. */
  expandAll(): void {
    this._expandAllOverride = true;
    // Direct fire — bypasses fireChanged() which would immediately clear the flag.
    this._onDidChangeTreeData.fire();
  }

  /** Resolve collapse state: Expanded when expandAll is active, Collapsed otherwise. */
  private get collapsedOrExpanded(): vscode.TreeItemCollapsibleState {
    return this._expandAllOverride
      ? vscode.TreeItemCollapsibleState.Expanded
      : vscode.TreeItemCollapsibleState.Collapsed;
  }

  /**
   * Fire a tree refresh, clearing any pending expand-all override.
   * Every mutation except expandAll() must use this to prevent the flag from
   * persisting across unrelated filter/suppression changes.
   */
  private fireChanged(): void {
    this._expandAllOverride = false;
    this._onDidChangeTreeData.fire();
  }

  refresh(): void {
    this.cachedIndex = null;
    this.rulesWithFixesSet = null;
    // Clear file existence cache so moved/deleted files are detected on next render.
    clearFileExistsCache();
    this.fireChanged();
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
      this.configDisabledRules = readDisabledRules(root);
      const idx = buildFilteredIndex(
        violations,
        this.textFilter,
        this.severitiesToShow,
        this.impactsToShow,
        this.effectiveRulesToHide(),
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
    this.fireChanged();
  }

  setSeverityFilter(severities: Set<string>): void {
    this.severitiesToShow = new Set(severities);
    this.cachedIndex = null;
    this.fireChanged();
  }

  setImpactFilter(impacts: Set<string>): void {
    this.impactsToShow = new Set(impacts);
    this.cachedIndex = null;
    this.fireChanged();
  }

  setRulesToHide(rules: Set<string>): void {
    this.rulesToHide = new Set(rules);
    this.cachedIndex = null;
    this.fireChanged();
  }

  setFocusedFile(filePath: string): void {
    this.focusedFile = filePath;
    this.cachedIndex = null;
    this.fireChanged();
  }

  clearFocusedFile(): void {
    this.focusedFile = undefined;
    this.cachedIndex = null;
    this.fireChanged();
  }

  getFocusedFile(): string | undefined {
    return this.focusedFile;
  }

  clearFilters(): void {
    this.textFilter = '';
    this.severitiesToShow = new Set(SEVERITY_ORDER);
    // Three-bucket severity model (post-collapse, 2026-05-03).
    this.impactsToShow = new Set(['error', 'warning', 'info']);
    this.rulesToHide = new Set();
    this.focusedFile = undefined;
    this.cachedIndex = null;
    this.fireChanged();
  }

  /** D10: Current grouping mode. */
  getGroupBy(): GroupByMode {
    return this.groupBy;
  }

  /** D10: Change the grouping mode and refresh. */
  setGroupBy(mode: GroupByMode): void {
    this.groupBy = mode;
    this.cachedIndex = null;
    this.fireChanged();
  }

  clearSuppressionsAndRefresh(): void {
    this.suppressions = clearSuppressions();
    saveSuppressions(this.workspaceState, this.suppressions);
    this.cachedIndex = null;
    this.fireChanged();
  }

  addSuppressionFolder(folderPath: string): void {
    this.suppressions = addHiddenFolder(this.suppressions, folderPath);
    saveSuppressions(this.workspaceState, this.suppressions);
    this.cachedIndex = null;
    this.fireChanged();
  }

  addSuppressionFile(filePath: string): void {
    this.suppressions = addHiddenFile(this.suppressions, filePath);
    saveSuppressions(this.workspaceState, this.suppressions);
    this.cachedIndex = null;
    this.fireChanged();
  }

  addSuppressionRule(rule: string): void {
    this.suppressions = addHiddenRule(this.suppressions, rule);
    saveSuppressions(this.workspaceState, this.suppressions);
    this.cachedIndex = null;
    this.fireChanged();
  }

  addSuppressionRuleInFile(filePath: string, rule: string): void {
    this.suppressions = addHiddenRuleInFile(this.suppressions, filePath, rule);
    saveSuppressions(this.workspaceState, this.suppressions);
    this.cachedIndex = null;
    this.fireChanged();
  }

  addSuppressionSeverity(severity: string): void {
    this.suppressions = addHiddenSeverity(this.suppressions, severity);
    saveSuppressions(this.workspaceState, this.suppressions);
    this.cachedIndex = null;
    this.fireChanged();
  }

  addSuppressionImpact(impact: string): void {
    this.suppressions = addHiddenImpact(this.suppressions, impact);
    saveSuppressions(this.workspaceState, this.suppressions);
    this.cachedIndex = null;
    this.fireChanged();
  }

  /** Merge user-set rulesToHide with config-disabled rules for filtering. */
  private effectiveRulesToHide(): Set<string> {
    if (this.configDisabledRules.size === 0) return this.rulesToHide;
    if (this.rulesToHide.size === 0) return this.configDisabledRules;
    return new Set([...this.rulesToHide, ...this.configDisabledRules]);
  }

  private getIndex(root: string): Map<string, Map<string, Violation[]>> | null {
    const data = readViolations(root);
    if (!data) return null;
    const violations = data.violations ?? [];
    this.totalUnfiltered = violations.length;
    // Cache fix availability for contextValue in getTreeItem.
    // Null when the analyzer doesn't emit this field (backward compat).
    const fixNames = data.config?.rulesWithFixes;
    this.rulesWithFixesSet = fixNames ? new Set(fixNames) : null;
    // Re-read config-disabled rules so stale violations.json entries for
    // rules the user has since disabled are automatically hidden.
    this.configDisabledRules = readDisabledRules(root);
    this.cachedIndex = buildFilteredIndex(
      violations,
      this.textFilter,
      this.severitiesToShow,
      this.impactsToShow,
      this.effectiveRulesToHide(),
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
        this.collapsedOrExpanded,
      );
      item.iconPath = severityThemeIcon(element.severity);
      item.tooltip = `${element.count} ${element.severity}(s)`;
      item.contextValue = 'severity';
      item.accessibilityInformation = { label: `${element.severity}, ${element.count} issues`, role: 'treeitem' };
      return item;
    }
    if (element.kind === 'folder') {
      const item = new vscode.TreeItem(
        element.segmentName,
        this.collapsedOrExpanded,
      );
      // Inherit severity icon+color from parent so folders visually match their severity group.
      item.iconPath = element.severity
        ? severityThemeIcon(element.severity)
        : new vscode.ThemeIcon('folder');
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
      const absPath = path.join(wsRoot, element.filePath);
      const exists = cachedFileExists(absPath);
      const item = new vscode.TreeItem(
        `${base} (${element.violations.length})`,
        // Still collapsible so users can see which violations existed.
        this.collapsedOrExpanded,
      );
      if (exists) {
        item.resourceUri = vscode.Uri.file(absPath);
        item.iconPath = new vscode.ThemeIcon('document');
        item.description = element.filePath;
        // D10: When grouped by file/impact/rule/owasp, severity is empty — use generic label.
        item.tooltip = element.severity
          ? `${element.filePath} — ${element.violations.length} ${element.severity}(s)`
          : `${element.filePath} — ${element.violations.length} violation${element.violations.length === 1 ? '' : 's'}`;
        // Clicking the file row opens the file. The expand/collapse triangle
        // still toggles children; this matches VS Code's standard tree behavior
        // where a collapsible node with a command both expands and invokes.
        item.command = {
          command: 'vscode.open',
          title: 'Open File',
          arguments: [item.resourceUri],
        };
      } else {
        // File was moved or deleted since last analysis — show warning instead of broken link.
        item.iconPath = STALE_ICON;
        item.description = STALE_LABEL;
        item.tooltip = `File not found: ${element.filePath}\nRe-run analysis to update.`;
      }
      item.contextValue = 'file';
      item.accessibilityInformation = {
        label: `${base}, ${element.violations.length} issues`,
        role: 'treeitem',
      };
      return item;
    }
    if (element.kind === 'violation') {
      const v = element.violation;
      const absPath = path.join(wsRoot, v.file);
      const exists = cachedFileExists(absPath);
      const hotspot = isSecurityHotspotViolation(v);
      const hotspotState = hotspot
        ? this.securityHotspotReviewState.getEffective(v)
        : undefined;
      const item = new vscode.TreeItem(
        violationLabel(v),
        vscode.TreeItemCollapsibleState.None,
      );
      if (exists) {
        item.resourceUri = vscode.Uri.file(absPath);
        item.command = {
          command: 'vscode.open',
          title: 'Open',
          arguments: [
            item.resourceUri,
            { selection: new vscode.Range(v.line - 1, 0, v.line - 1, 0) },
          ],
        };
      }
      // else: file moved/deleted — no command, so clicking does nothing instead of "file not found".
      const tooltip = new vscode.MarkdownString();
      if (!exists) {
        tooltip.appendMarkdown('**File not found** — re-run analysis to update.\n\n---\n\n');
      }
      tooltip.appendMarkdown((v.message ?? '').replace(/]/g, '\\]'));
      if (hotspot && hotspotState) {
        tooltip.appendMarkdown('\n\n**Hotspot review:** `' + hotspotState + '`');
      }
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
        const related = getRelatedRules(ruleName).filter((r) => r !== ruleName);
        if (related.length > 0) {
          tooltip.appendMarkdown('\n\n**See also:** ');
          tooltip.appendMarkdown(
            related
              .slice(0, 3)
              .map((r) => '`' + r.replace(/`/g, '\\`') + '`')
              .join(', '),
          );
          if (related.length > 3) {
            tooltip.appendMarkdown(`, +${related.length - 3} more`);
          }
        }
        tooltip.appendMarkdown('\n\n[More](' + getRuleDocUrl(ruleName) + ')');
      }
      item.tooltip = tooltip;
      // Mark fixable violations so "Apply fix" is enabled; null set = unknown,
      // default to fixable for backward compat with older analyzer output.
      // Stale violations are not fixable — the file no longer exists.
      const hasFix = exists && (this.rulesWithFixesSet === null || this.rulesWithFixesSet.has(v.rule));
      if (hotspot) {
        item.description = hotspotState;
      }
      if (hotspot && hasFix) {
        item.contextValue = 'violationHotspotFixable';
      } else if (hotspot) {
        item.contextValue = 'violationHotspot';
      } else {
        item.contextValue = hasFix ? 'violationFixable' : 'violation';
      }
      item.accessibilityInformation = {
        label: `Line ${v.line} ${v.rule}, ${(v.message ?? '').slice(0, 40)}`,
        role: 'button',
      };
      return item;
    }
    if (element.kind === 'overflow') {
      const absPath = path.join(wsRoot, element.filePath);
      const exists = cachedFileExists(absPath);
      const item = new vscode.TreeItem(
        `and ${element.count} more…`,
        vscode.TreeItemCollapsibleState.None,
      );
      if (exists) {
        item.iconPath = new vscode.ThemeIcon('ellipsis');
        item.tooltip = 'Open file or use Problems view to see all';
        item.resourceUri = vscode.Uri.file(absPath);
        item.command = {
          command: 'vscode.open',
          title: 'Open file',
          arguments: [item.resourceUri],
        };
      } else {
        // File moved/deleted — don't attempt to open.
        item.iconPath = STALE_ICON;
        item.tooltip = `File not found: ${element.filePath}\nRe-run analysis to update.`;
      }
      item.contextValue = 'overflow';
      return item;
    }
    // D10: Generic group item for impact/rule/owasp grouping.
    if (element.kind === 'group') {
      const item = new vscode.TreeItem(
        `${element.label} (${element.count})`,
        this.collapsedOrExpanded,
      );
      // Mode-aware icon — reads from element.mode (snapshot at creation) so
      // `this.groupBy` changing mid-render doesn't mismatch the icon.
      // Three-bucket severity model (was 5 buckets pre-2026-05-03).
      if (element.mode === 'impact') {
        const k = element.groupKey;
        item.iconPath = new vscode.ThemeIcon(
          k === 'error' ? 'error' : k === 'warning' ? 'warning' : k === 'info' ? 'info' : 'circle-outline',
        );
      } else if (element.mode === 'owasp') {
        item.iconPath = new vscode.ThemeIcon('shield');
      } else if (element.mode === 'ruleStatus') {
        item.iconPath = new vscode.ThemeIcon('versions');
      } else if (element.mode === 'ruleType') {
        item.iconPath = new vscode.ThemeIcon('symbol-property');
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
    // Self-contained elements: these carry their own data and don't need
    // a disk read. Handle them first so a temporarily unavailable
    // violations.json (write lock during scan, etc.) can't make
    // already-loaded children disappear.
    if (element?.kind === 'file') {
      return this._buildFileChildren(element);
    }
    if (element?.kind === 'group') {
      return buildFileItems(element.violations);
    }

    // Everything below needs the violations index from disk.
    const root = getProjectRoot();
    if (!root) return [];

    const data = readViolations(root);
    // C5: Return empty array when no violations file so viewsWelcome content renders.
    if (!data) return [];

    const violations = data.violations ?? [];
    // Zero violations after analysis — show a clean-state item (not empty,
    // so JSON export and tests still see an explicit placeholder root).
    if (violations.length === 0 && !element) {
      return prependIssuesHelpRow([
        {
          kind: 'placeholder' as const,
          id: 'no-data' as const,
          label: 'No violations found',
          description: 'All clear',
          command: 'saropaLints.runAnalysis',
        },
      ]);
    }

    const index = this.getIndex(root);
    if (!index) return [];

    let filteredTotal = 0;
    for (const byFile of index.values()) {
      for (const list of byFile.values()) filteredTotal += list.length;
    }
    if (filteredTotal === 0 && !element) {
      return prependIssuesHelpRow([
        {
          kind: 'placeholder',
          id: 'no-match',
          label: 'No issues match your filters',
          description: 'Clear filters or suppressions',
          command: 'saropaLints.clearIssuesFilters',
        },
      ]);
    }

    if (!element) {
      // D10: Delegate to grouping-mode-specific root builder.
      if (this.groupBy !== 'severity') {
        return prependIssuesHelpRow(this.buildGroupedRoot(index));
      }
      const items: SeverityItem[] = [];
      for (const sev of SEVERITY_ORDER) {
        const byFile = index.get(sev);
        if (!byFile) continue;
        let count = 0;
        for (const list of byFile.values()) count += list.length;
        if (count > 0) items.push({ kind: 'severity', severity: sev, count });
      }
      return prependIssuesHelpRow(items);
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

    return [];
  }

  /** Build children for a file node from its embedded violations array. */
  private _buildFileChildren(element: FileItem): IssueTreeNode[] {
    const list = element.violations;
    const sorted = [...list].sort(sortViolationsByReportPriority);
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
        label: formatGroupLabel(currentMode, key),
        count: violations.length,
        violations,
      });
    }

    // Impact mode uses severity-keyed order (was 5-bucket order pre-2026-05-03);
    // other modes sort by count desc with name tie-breaker.
    if (currentMode === 'impact') {
      const order = ['error', 'warning', 'info'];
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
    if (mode === 'impact') return [(v.impact ?? 'info').toLowerCase()];
    if (mode === 'rule') return [v.rule];
    if (mode === 'file') return [v.file];
    if (mode === 'ruleType') return [v.metadata?.ruleType ?? 'unspecified'];
    if (mode === 'ruleStatus') return [v.metadata?.ruleStatus ?? 'ready'];
    if (mode === 'tier') return [tierForRule(v.rule)];
    // Pack is multi-key (a rule can live in several packs), exactly like OWASP.
    if (mode === 'pack') return packsForRule(v.rule);
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

function formatGroupLabel(mode: GroupByMode, key: string): string {
  // Tier keys are lowercase tier ids; title-case them. Pack keys are already
  // human labels (or the 'No pack' fallback) and pass through unchanged.
  if (mode === 'impact' || mode === 'tier') {
    return key.charAt(0).toUpperCase() + key.slice(1);
  }
  if (mode === 'ruleType' || mode === 'ruleStatus') {
    return key
      .replace(/([a-z])([A-Z])/g, '$1 $2')
      .replaceAll('_', ' ')
      .replaceAll('-', ' ')
      .replace(/\b\w/g, (c) => c.toUpperCase());
  }
  return key;
}

/** D10: Group violations by file into FileItem[], sorted by count desc then basename (matches tree labels). */
function buildFileItems(violations: Violation[]): FileItem[] {
  const byFile = new Map<string, Violation[]>();
  for (const v of violations) {
    const list = byFile.get(v.file) ?? [];
    list.push(v);
    byFile.set(v.file, list);
  }
  const items: FileItem[] = [];
  for (const [filePath, list] of byFile) {
    const sorted = [...list].sort(sortViolationsByReportPriority);
    items.push({ kind: 'file', severity: '', filePath, violations: sorted });
  }
  // Max FIX PRIORITY in file, then count desc, then basename asc, then full path.
  items.sort((a, b) => {
    const byPrio = maxViolationPriority(b.violations) - maxViolationPriority(a.violations);
    if (byPrio !== 0) return byPrio;
    const byCount = b.violations.length - a.violations.length;
    if (byCount !== 0) return byCount;
    const baseCmp = path.basename(a.filePath).localeCompare(path.basename(b.filePath));
    if (baseCmp !== 0) return baseCmp;
    return a.filePath.localeCompare(b.filePath);
  });
  return items;
}


// Command registration lives in issuesTreeCommands.ts; re-exported here so
// extension.ts keeps importing it from issuesTree.ts unchanged.
export { registerIssueCommands } from './issuesTreeCommands';
