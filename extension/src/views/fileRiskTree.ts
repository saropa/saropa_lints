/**
 * D6: File Risk tree — files ranked by violation density.
 * Shows the riskiest files first so developers know where to focus.
 * Click a file to filter the Violations view to that file.
 */

import * as vscode from 'vscode';
import * as path from 'path';
import { readViolations, Violation } from '../violationsReader';
import { getProjectRoot } from '../projectRoot';

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

interface FileRisk {
  filePath: string;
  total: number;
  critical: number;
  high: number;
  riskScore: number;
}

/**
 * Aggregate violations per file and compute a weighted risk score.
 * Returns files sorted by risk score descending — worst files first.
 */
function buildFileRisks(violations: Violation[]): FileRisk[] {
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

type FileRiskNode = SummaryNode | FileNode;

interface SummaryNode {
  kind: 'summary';
  label: string;
  description: string;
}

interface FileNode {
  kind: 'file';
  risk: FileRisk;
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

  refresh(): void {
    this._onDidChangeTreeData.fire();
  }

  getTreeItem(element: FileRiskNode): vscode.TreeItem {
    if (element.kind === 'summary') {
      const item = new vscode.TreeItem(element.label, vscode.TreeItemCollapsibleState.None);
      item.description = element.description;
      item.iconPath = new vscode.ThemeIcon('graph');
      item.contextValue = 'fileRiskSummary';
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

    // Click → filter Violations view to this file.
    item.command = {
      command: 'saropaLints.focusIssuesForFile',
      title: 'Show issues for this file',
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

    const risks = buildFileRisks(data.violations);
    if (risks.length === 0) return [];

    const items: FileRiskNode[] = [];

    // D6: Summary — "Top N files have X% of critical issues".
    const totalCritical = risks.reduce((s, r) => s + r.critical, 0);
    if (totalCritical > 0) {
      const topN = Math.min(5, risks.length);
      const topCritical = risks.slice(0, topN).reduce((s, r) => s + r.critical, 0);
      const pct = Math.round((topCritical / totalCritical) * 100);
      items.push({
        kind: 'summary',
        label: `Top ${topN} files have ${pct}% of critical issues`,
        description: `${totalCritical} critical total`,
      });
    }

    // File items capped at MAX_FILES.
    for (const risk of risks.slice(0, MAX_FILES)) {
      items.push({ kind: 'file', risk });
    }

    return items;
  }
}
