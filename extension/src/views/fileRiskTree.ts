/**
 * D6: File Risk tree — files ranked by violation density.
 * Shows the riskiest files first so developers know where to focus.
 * Click a file to open it in the editor and filter the Violations view.
 */

import * as vscode from 'vscode';
import * as path from 'path';
import { readViolations, Violation } from '../violationsReader';
import { getProjectRoot } from '../projectRoot';
import { readDisabledRules } from '../configWriter';
import { loadSuppressions, isPathHidden, isRuleHidden } from '../suppressionsStore';

/**
 * Impact weights matching healthScore.ts so that risk ranking is
 * consistent with the health score formula. A single critical violation
 * outweighs 8 medium ones in the weighted score.
 */
const RISK_WEIGHTS: Record<string, number> = {
  critical: 8,
  high: 3,
  medium: 1,
  low: 0.25,
  opinionated: 0.05,
};

const MAX_FILES = 30;

export interface FileRisk {
  filePath: string;
  total: number;
  critical: number;
  high: number;
  riskScore: number;
}

/**
 * Aggregate violations per file and compute a weighted risk score.
 * Returns files sorted by risk score descending — worst files first.
 *
 * Also used by the Overview tree for its embedded "Riskiest Files" group.
 */
export function buildFileRisks(violations: Violation[]): FileRisk[] {
  const byFile = new Map<string, { total: number; critical: number; high: number; weighted: number }>();

  for (const v of violations) {
    const entry = byFile.get(v.file) ?? { total: 0, critical: 0, high: 0, weighted: 0 };
    entry.total++;
    const impact = (v.impact ?? 'medium').toLowerCase();
    if (impact === 'critical') entry.critical++;
    if (impact === 'high') entry.high++;
    entry.weighted += RISK_WEIGHTS[impact] ?? 1;
    byFile.set(v.file, entry);
  }

  const risks: FileRisk[] = [];
  for (const [filePath, entry] of byFile) {
    risks.push({
      filePath,
      total: entry.total,
      critical: entry.critical,
      high: entry.high,
      riskScore: entry.weighted,
    });
  }

  // Sort by weighted risk score descending, then by total count.
  risks.sort((a, b) => b.riskScore - a.riskScore || b.total - a.total);
  return risks;
}

type FileRiskNode = SummaryNode | FileNode | TimestampNode;

interface SummaryNode {
  kind: 'summary';
  label: string;
  description: string;
}

interface FileNode {
  kind: 'file';
  risk: FileRisk;
}

interface TimestampNode {
  kind: 'timestamp';
  label: string;
  isStale: boolean;
}

/** Threshold in milliseconds beyond which scan data is considered stale (24 hours). */
const STALE_THRESHOLD_MS = 24 * 60 * 60 * 1000;

/** Format an ISO timestamp into a human-readable relative age string. */
export function formatAge(isoTimestamp: string): { label: string; isStale: boolean } {
  const scanDate = new Date(isoTimestamp);
  if (isNaN(scanDate.getTime())) return { label: 'unknown', isStale: false };

  const ageMs = Date.now() - scanDate.getTime();
  const isStale = ageMs > STALE_THRESHOLD_MS;

  // Build relative label: "2 hours ago", "3 days ago", etc.
  const seconds = Math.floor(ageMs / 1000);
  if (seconds < 60) return { label: 'just now', isStale };
  const minutes = Math.floor(seconds / 60);
  if (minutes < 60) return { label: `${minutes}m ago`, isStale };
  const hours = Math.floor(minutes / 60);
  if (hours < 24) return { label: `${hours}h ago`, isStale };
  const days = Math.floor(hours / 24);
  return { label: `${days}d ago`, isStale };
}

/** Pick an icon reflecting severity mix: flame for critical, warning for high, info otherwise. */
function riskIcon(r: FileRisk): vscode.ThemeIcon {
  if (r.critical > 0) return new vscode.ThemeIcon('flame', new vscode.ThemeColor('list.errorForeground'));
  if (r.high > 0) return new vscode.ThemeIcon('warning', new vscode.ThemeColor('list.warningForeground'));
  return new vscode.ThemeIcon('info');
}

export class FileRiskTreeProvider implements vscode.TreeDataProvider<FileRiskNode> {
  private _onDidChangeTreeData = new vscode.EventEmitter<FileRiskNode | undefined | void>();
  readonly onDidChangeTreeData = this._onDidChangeTreeData.event;
  private workspaceState: vscode.Memento;

  constructor(workspaceState: vscode.Memento) {
    this.workspaceState = workspaceState;
  }

  refresh(): void {
    this._onDidChangeTreeData.fire();
  }

  getTreeItem(element: FileRiskNode): vscode.TreeItem {
    if (element.kind === 'summary') {
      const item = new vscode.TreeItem(element.label, vscode.TreeItemCollapsibleState.None);
      item.description = element.description;
      item.iconPath = new vscode.ThemeIcon('graph');
      item.contextValue = 'fileRiskSummary';
      // Click → show all violations (clear filters and focus Violations view).
      item.command = {
        command: 'saropaLints.focusIssues',
        title: 'Show all violations',
        arguments: [],
      };
      return item;
    }

    if (element.kind === 'timestamp') {
      const item = new vscode.TreeItem(element.label, vscode.TreeItemCollapsibleState.None);
      // Stale data gets a warning icon; fresh data gets a clock icon.
      item.iconPath = element.isStale
        ? new vscode.ThemeIcon('warning', new vscode.ThemeColor('list.warningForeground'))
        : new vscode.ThemeIcon('clock');
      item.contextValue = 'fileRiskTimestamp';
      if (element.isStale) {
        item.tooltip = 'Scan data may be outdated. Run analysis to refresh.';
        // Click → run analysis to refresh the data.
        item.command = {
          command: 'saropaLints.runAnalysis',
          title: 'Run analysis',
          arguments: [],
        };
      }
      return item;
    }

    const r = element.risk;
    const base = path.basename(r.filePath);
    const item = new vscode.TreeItem(base, vscode.TreeItemCollapsibleState.None);
    item.description = r.filePath;
    item.iconPath = riskIcon(r);

    // Build tooltip with breakdown.
    const parts: string[] = [`${r.total} violation${r.total === 1 ? '' : 's'}`];
    if (r.critical > 0) parts.push(`${r.critical} critical`);
    if (r.high > 0) parts.push(`${r.high} high`);
    item.tooltip = `${r.filePath}\n${parts.join(', ')}\nRisk score: ${Math.round(r.riskScore)}`;

    // Click → open the file in the editor and filter Violations view.
    item.command = {
      command: 'saropaLints.openFileAndFocusIssues',
      title: 'Open file and show issues',
      arguments: [r.filePath],
    };
    item.contextValue = 'fileRiskFile';
    return item;
  }

  getChildren(element?: FileRiskNode): FileRiskNode[] {
    if (element) return [];

    const root = getProjectRoot();
    if (!root) return [];

    const data = readViolations(root);
    if (!data || data.violations.length === 0) return [];

    // Filter out violations that should not affect risk scores:
    // 1. Rules disabled in analysis_options.yaml / analysis_options_custom.yaml
    // 2. Files/folders/rules/severities/impacts hidden via view-level suppressions
    const disabled = readDisabledRules(root);
    const suppressions = loadSuppressions(this.workspaceState);
    const violations = data.violations.filter((v) => {
      if (disabled.has(v.rule)) return false;
      if (isPathHidden(suppressions, v.file)) return false;
      if (isRuleHidden(suppressions, v.file, v.rule)) return false;
      const severity = (v.severity ?? 'info').toLowerCase();
      if (suppressions.hiddenSeverities.includes(severity)) return false;
      const impact = (v.impact ?? 'low').toLowerCase();
      if (suppressions.hiddenImpacts.includes(impact)) return false;
      return true;
    });
    if (violations.length === 0) return [];

    const risks = buildFileRisks(violations);
    if (risks.length === 0) return [];

    const items: FileRiskNode[] = [];

    // D6: Summary — flat counts of files and severity breakdown.
    const totalViolations = risks.reduce((s, r) => s + r.total, 0);
    const totalCritical = risks.reduce((s, r) => s + r.critical, 0);
    const totalHigh = risks.reduce((s, r) => s + r.high, 0);
    const parts: string[] = [`${risks.length} file${risks.length === 1 ? '' : 's'}`];
    if (totalCritical > 0) parts.push(`${totalCritical} critical`);
    if (totalHigh > 0) parts.push(`${totalHigh} high`);
    // Only show total violations when there are medium/low beyond critical+high.
    const otherCount = totalViolations - totalCritical - totalHigh;
    if (otherCount > 0) parts.push(`${otherCount} other`);
    items.push({
      kind: 'summary',
      label: parts.join(', '),
      description: `${totalViolations} violation${totalViolations === 1 ? '' : 's'} total`,
    });

    // File items capped at MAX_FILES.
    for (const risk of risks.slice(0, MAX_FILES)) {
      items.push({ kind: 'file', risk });
    }

    // Timestamp node — shows when the scan was run, with a warning if stale.
    if (data.timestamp) {
      const { label: ageLabel, isStale } = formatAge(data.timestamp);
      items.push({
        kind: 'timestamp',
        label: isStale ? `Scanned ${ageLabel} — click to refresh` : `Scanned ${ageLabel}`,
        isStale,
      });
    }

    return items;
  }
}
