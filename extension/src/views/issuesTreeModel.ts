/**
 * Module overview (comment coverage pass).
 * comment-coverage: module overview (batch).
 *
 * VS Code views: trees, dashboards, or webview HTML builders.
 */

import * as vscode from 'vscode';
import * as path from 'path';

import { normalizePath } from '../pathUtils';
import type { Violation } from '../violationsReader';
import { normalizeOwaspId } from './securityPostureTree';
import type { Suppressions } from '../suppressionsStore';
import { isPathHidden, isRuleHidden } from '../suppressionsStore';
import { VIOLATIONS_GROUP_BY_MODES, type GroupByMode } from './issuesTreeGrouping';
import { packsForRule, tierForRule } from './ruleGroupingMeta';

export type { GroupByMode };
export { VIOLATIONS_GROUP_BY_MODES };
export const SEVERITY_ORDER = ['error', 'warning', 'info'] as const;
const DEFAULT_PAGE_SIZE = 100;
export const MESSAGE_LABEL_LEN = 56;

export const STALE_ICON = new vscode.ThemeIcon(
  'warning',
  new vscode.ThemeColor('problemsWarningIcon.foreground'),
);
export const STALE_LABEL = '(file moved or deleted)';

/** Map a severity string to a colored ThemeIcon matching VS Code's diagnostic palette. */
export function severityThemeIcon(severity: string): vscode.ThemeIcon {
  const name = severity === 'error' ? 'error' : severity === 'warning' ? 'warning' : 'info';
  const color = severity === 'error'
    ? 'list.errorForeground'
    : severity === 'warning'
      ? 'list.warningForeground'
      : 'editorInfo.foreground';
  return new vscode.ThemeIcon(name, new vscode.ThemeColor(color));
}

export function getPageSize(): number {
  const n = vscode.workspace.getConfiguration('saropaLints').get<number>('issuesPageSize', DEFAULT_PAGE_SIZE);
  // Clamp hard to protect tree rendering and pagination from accidental
  // extreme values in workspace settings.
  return Math.max(1, Math.min(1000, typeof n === 'number' && !Number.isNaN(n) ? n : DEFAULT_PAGE_SIZE));
}

/** Default grouping for new workspaces: impact surfaces Critical / High first. */
export function parseViolationsGroupBy(cfg: vscode.WorkspaceConfiguration): GroupByMode {
  const raw = cfg.get<string>('violationsGroupBy', 'impact') ?? 'impact';
  return (VIOLATIONS_GROUP_BY_MODES as readonly string[]).includes(raw) ? (raw as GroupByMode) : 'impact';
}

function violationNumericPriority(v: Violation): number {
  if (typeof v.priority === 'number' && Number.isFinite(v.priority)) {
    return v.priority;
  }
  // Missing priority falls back below all explicit priorities.
  return -1;
}

/** Same ordering intent as violations.json after export: higher priority first, then line. */
export function sortViolationsByReportPriority(a: Violation, b: Violation): number {
  const pa = violationNumericPriority(a);
  const pb = violationNumericPriority(b);
  if (pa !== pb) return pb - pa;
  return (a.line ?? 0) - (b.line ?? 0);
}

export function maxViolationPriority(list: Violation[]): number {
  let m = -1;
  for (const v of list) {
    m = Math.max(m, violationNumericPriority(v));
  }
  return m;
}

/**
 * D10: Generic group header for non-severity grouping modes.
 * Used by impact, rule, and owasp modes. Children are FileItem[]
 * sub-grouped from the violations list.
 */
export interface GroupItem {
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

export interface SeverityItem {
  kind: 'severity';
  severity: string;
  count: number;
}

export interface FolderItem {
  kind: 'folder';
  severity: string;
  pathPrefix: string;
  segmentName: string;
  count: number;
}

export interface FileItem {
  kind: 'file';
  severity: string;
  filePath: string;
  violations: Violation[];
}

export interface ViolationItem {
  kind: 'violation';
  violation: Violation;
}

export interface OverflowItem {
  kind: 'overflow';
  filePath: string;
  severity: string;
  count: number;
}

export interface PlaceholderItem {
  kind: 'placeholder';
  id: 'loading' | 'no-data' | 'no-match';
  label: string;
  description?: string;
  command?: string;
}

/** Build index: severity -> file path -> violations[]. Only includes violations that pass filters and suppressions. */
export function buildFilteredIndex(
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
      // Search matches only a focused subset of fields to keep filtering
      // predictable and fast on very large violation sets.
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
export function getPathTreeChildren(
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
      // Only immediate child folder at this tree depth; deeper levels are
      // resolved recursively as nodes expand.
      folderSet.add(parts[0]);
    }
  }
  const folders = Array.from(folderSet).sort();
  files.sort((a, b) => a.path.localeCompare(b.path));
  return { folders, files };
}

export function violationLabel(v: Violation): string {
  const msg = (v.message ?? '').slice(0, MESSAGE_LABEL_LEN);
  return `L${v.line}: [${v.rule}] ${msg}${msg.length >= MESSAGE_LABEL_LEN ? '…' : ''}`;
}

export function formatGroupLabel(mode: GroupByMode, key: string): string {
  // Tier keys are lowercase tier ids ('essential', …); title-case for display.
  // Pack keys are already human labels (RULE_PACK_DEFINITIONS.label) or the
  // 'No pack' fallback, so they pass through unchanged.
  if (mode === 'impact' || mode === 'tier') {
    return key.charAt(0).toUpperCase() + key.slice(1);
  }
  if (mode === 'ruleType' || mode === 'ruleStatus') {
    // Normalize camel/snake/kebab forms into readable title case labels.
    return key
      .replace(/([a-z])([A-Z])/g, '$1 $2')
      .replaceAll('_', ' ')
      .replaceAll('-', ' ')
      .replace(/\b\w/g, (c) => c.toUpperCase());
  }
  return key;
}

/** D10: Group violations by file into FileItem[], sorted by count desc then basename (matches tree labels). */
export function buildFileItems(violations: Violation[]): FileItem[] {
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

export function folderPath(e: FolderItem): string {
  return e.pathPrefix ? `${e.pathPrefix}/${e.segmentName}` : e.segmentName;
}

/** Violations grouped by file for dashboard / tree rendering. */
export interface DashboardFileBlock {
  filePath: string;
  violations: Violation[];
}

/** Dashboard section when grouping by severity (matches Issues tree). */
export interface DashboardSeveritySection {
  kind: 'severity';
  severity: string;
  files: DashboardFileBlock[];
}

/** Dashboard section for impact, rule, OWASP, file, ruleType, ruleStatus modes. */
export interface DashboardNamedSection {
  kind: 'named';
  mode: GroupByMode;
  groupKey: string;
  label: string;
  files: DashboardFileBlock[];
}

export type DashboardSection = DashboardSeveritySection | DashboardNamedSection;

/**
 * D10: Grouping keys for a violation (same contract as Issues tree).
 * OWASP can return multiple keys per violation.
 */
export function extractViolationGroupKeys(v: Violation, mode: GroupByMode): string[] {
  if (mode === 'impact') {
    return [(v.impact ?? 'low').toLowerCase()];
  }
  if (mode === 'rule') {
    return [v.rule];
  }
  if (mode === 'file') {
    return [v.file];
  }
  if (mode === 'ruleType') {
    return [v.metadata?.ruleType ?? 'unspecified'];
  }
  if (mode === 'ruleStatus') {
    return [v.metadata?.ruleStatus ?? 'ready'];
  }
  if (mode === 'tier') {
    return [tierForRule(v.rule)];
  }
  // Pack is multi-key (a rule can live in several packs), exactly like OWASP.
  if (mode === 'pack') {
    return packsForRule(v.rule);
  }
  const cats = [...(v.owasp?.mobile ?? []), ...(v.owasp?.web ?? [])].map(normalizeOwaspId);
  return cats.length > 0 ? cats : ['Uncategorized'];
}

/** Flatten severity→file index into one list (order not guaranteed). */
export function collectAllViolationsFromIndex(
  index: Map<string, Map<string, Violation[]>>,
): Violation[] {
  const all: Violation[] = [];
  for (const byFile of index.values()) {
    for (const list of byFile.values()) {
      for (const v of list) {
        all.push(v);
      }
    }
  }
  return all;
}

/**
 * Build collapsible dashboard sections from a filtered index and grouping mode.
 * Mirrors Issues tree root structure without VS Code tree nodes.
 */
export function buildDashboardSections(
  index: Map<string, Map<string, Violation[]>>,
  groupBy: GroupByMode,
): DashboardSection[] {
  if (groupBy === 'severity') {
    const out: DashboardSeveritySection[] = [];
    for (const sev of SEVERITY_ORDER) {
      const byFile = index.get(sev);
      if (!byFile || byFile.size === 0) {
        continue;
      }
      const files: DashboardFileBlock[] = [];
      for (const [filePath, violations] of byFile) {
        files.push({ filePath, violations: [...violations].sort(sortViolationsByReportPriority) });
      }
      files.sort((a, b) => {
        const byPrio = maxViolationPriority(b.violations) - maxViolationPriority(a.violations);
        if (byPrio !== 0) {
          return byPrio;
        }
        return a.filePath.localeCompare(b.filePath);
      });
      out.push({ kind: 'severity', severity: sev, files });
    }
    return out;
  }

  const all = collectAllViolationsFromIndex(index);
  if (groupBy === 'file') {
    const items = buildFileItems(all);
    return items.map(
      (fi): DashboardNamedSection => ({
        kind: 'named',
        mode: 'file',
        groupKey: fi.filePath,
        label: fi.filePath,
        files: [{ filePath: fi.filePath, violations: fi.violations }],
      }),
    );
  }

  const groups = new Map<string, Violation[]>();
  for (const v of all) {
    for (const key of extractViolationGroupKeys(v, groupBy)) {
      const list = groups.get(key) ?? [];
      list.push(v);
      groups.set(key, list);
    }
  }
  const named: DashboardNamedSection[] = [];
  for (const [key, violations] of groups) {
    const fileItems = buildFileItems(violations);
    named.push({
      kind: 'named',
      mode: groupBy,
      groupKey: key,
      label: formatGroupLabel(groupBy, key),
      files: fileItems.map((fi) => ({ filePath: fi.filePath, violations: fi.violations })),
    });
  }
  if (groupBy === 'impact') {
    const order = ['critical', 'high', 'medium', 'low', 'opinionated'];
    named.sort((a, b) => order.indexOf(a.groupKey) - order.indexOf(b.groupKey));
  } else {
    named.sort((a, b) => {
      const ca = a.files.reduce((n, f) => n + f.violations.length, 0);
      const cb = b.files.reduce((n, f) => n + f.violations.length, 0);
      return cb - ca || a.groupKey.localeCompare(b.groupKey);
    });
  }
  return named;
}

/** Stable key for deduplicating violations in exports. */
export function violationDedupeKey(v: Violation): string {
  return `${v.file}\0${v.line}\0${v.rule}`;
}
