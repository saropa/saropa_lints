/**
 * Tree data provider for Saropa Lints Summary view.
 * Shows totals, by severity, by impact, and tier from violations.json.
 */

import * as vscode from 'vscode';
import { readViolations, filterDisabledFromData } from '../violationsReader';
import { getProjectRoot } from '../projectRoot';
import { readDisabledRules } from '../configWriter';
import {
  SecurityHotspotReviewStateService,
  countSecurityHotspotReviewStates,
} from '../securityHotspotReviewState';

/** Stable id used for expandable nodes so getChildren does not rely on label text. */
class SummaryItem extends vscode.TreeItem {
  constructor(
    label: string,
    description?: string,
    collapsible: vscode.TreeItemCollapsibleState = vscode.TreeItemCollapsibleState.None,
    public readonly nodeId?: string,
    commandId?: string,
    commandArgs?: unknown[],
  ) {
    super(label, collapsible);
    this.description = description;
    if (commandId) {
      this.command = { command: commandId, title: label, arguments: commandArgs ?? [] };
    }
    this.contextValue = 'summaryItem';
  }
}

type SuppressionsGroupNodeId = 'suppressionsByKind' | 'suppressionsByRule' | 'suppressionsByFile';

export class SummaryTreeProvider implements vscode.TreeDataProvider<SummaryItem> {
  private _onDidChangeTreeData = new vscode.EventEmitter<SummaryItem | undefined | void>();
  readonly onDidChangeTreeData = this._onDidChangeTreeData.event;
  private readonly hotspotReviewState: SecurityHotspotReviewStateService;

  constructor(private readonly workspaceState: vscode.Memento) {
    this.hotspotReviewState = new SecurityHotspotReviewStateService(workspaceState);
  }

  refresh(): void {
    this._onDidChangeTreeData.fire();
  }

  getTreeItem(element: SummaryItem): vscode.TreeItem {
    return element;
  }

  async getChildren(element?: SummaryItem): Promise<SummaryItem[]> {
    const root = getProjectRoot();
    // C5: Return empty for no-workspace and no-data so viewsWelcome renders.
    if (!root) return [];

    const rawData = readViolations(root);
    if (!rawData) return [];

    // Filter out violations for rules disabled in config so summary
    // counts stay consistent with the Violations view.
    const data = filterDisabledFromData(rawData, readDisabledRules(root));
    const s = data.summary;
    const c = data.config;

    if (!element) {
      const total = s?.totalViolations ?? data.violations.length;
      const hotspotCounts = countSecurityHotspotReviewStates(
        data.violations,
        data.config?.ruleMetadataByRule,
        this.hotspotReviewState,
      );
      const items: SummaryItem[] = [
        // Clickable: opens Violations view with all findings (clears filters).
        new SummaryItem('Total violations', String(total), vscode.TreeItemCollapsibleState.None, undefined, 'saropaLints.focusIssues'),
        new SummaryItem('Tier', c?.tier ?? '—'),
        new SummaryItem('Files analyzed', s?.filesAnalyzed != null ? String(s.filesAnalyzed) : '—'),
        new SummaryItem('Files with violations', s?.filesWithIssues != null ? String(s.filesWithIssues) : '—'),
      ];
      if (hotspotCounts.total > 0) {
        const reviewed = hotspotCounts.reviewedSafe + hotspotCounts.reviewedFixed;
        const percent = Math.round((reviewed / hotspotCounts.total) * 100);
        items.push(
          new SummaryItem(
            'Security hotspot review',
            `${percent}% reviewed — ${hotspotCounts.open} open, ${hotspotCounts.reviewedSafe} safe, ${hotspotCounts.reviewedFixed} fixed`,
            vscode.TreeItemCollapsibleState.Expanded,
            'hotspotReview',
            'saropaLints.reviewHotspotState',
          ),
        );
      }
      if (s?.bySeverity) {
        items.push(
          new SummaryItem(
            'By severity',
            `${s.bySeverity.error ?? 0} error, ${s.bySeverity.warning ?? 0} warning, ${s.bySeverity.info ?? 0} info`,
            vscode.TreeItemCollapsibleState.Expanded,
            'bySeverity',
          ),
        );
      }
      if (s?.byImpact) {
        const bi = s.byImpact;
        items.push(
          new SummaryItem(
            'By impact',
            `critical ${bi.critical ?? 0}, high ${bi.high ?? 0}, medium ${bi.medium ?? 0}, low ${bi.low ?? 0}, opinionated ${bi.opinionated ?? 0}`,
            vscode.TreeItemCollapsibleState.Expanded,
            'byImpact',
          ),
        );
      }
      if (s?.byRuleType) {
        items.push(
          new SummaryItem(
            'By rule type',
            formatBreakdownDescription(s.byRuleType),
            vscode.TreeItemCollapsibleState.Expanded,
            'byRuleType',
          ),
        );
      }
      if (s?.byRuleStatus) {
        items.push(
          new SummaryItem(
            'By rule status',
            formatBreakdownDescription(s.byRuleStatus),
            vscode.TreeItemCollapsibleState.Expanded,
            'byRuleStatus',
          ),
        );
      }
      if ((s?.suppressions?.total ?? 0) > 0) {
        const byKind = s?.suppressions?.byKind;
        const parts: string[] = [];
        if ((byKind?.ignore ?? 0) > 0) parts.push(`${byKind?.ignore ?? 0} ignore`);
        if ((byKind?.ignoreForFile ?? 0) > 0) parts.push(`${byKind?.ignoreForFile ?? 0} file-level`);
        if ((byKind?.baseline ?? 0) > 0) parts.push(`${byKind?.baseline ?? 0} baseline`);
        const desc = parts.length > 0 ? parts.join(', ') : `${s?.suppressions?.total ?? 0} total`;
        items.push(
          new SummaryItem(
            'Suppressions',
            desc,
            vscode.TreeItemCollapsibleState.Expanded,
            'suppressions',
            'saropaLints.focusIssues',
          ),
        );
      }
      return items;
    }

    if ((element.nodeId === 'bySeverity' || element.label === 'By severity') && s?.bySeverity) {
      return [
        new SummaryItem('Error', String(s.bySeverity.error ?? 0), vscode.TreeItemCollapsibleState.None, undefined, 'saropaLints.focusIssuesWithSeverityFilter', ['error']),
        new SummaryItem('Warning', String(s.bySeverity.warning ?? 0), vscode.TreeItemCollapsibleState.None, undefined, 'saropaLints.focusIssuesWithSeverityFilter', ['warning']),
        new SummaryItem('Info', String(s.bySeverity.info ?? 0), vscode.TreeItemCollapsibleState.None, undefined, 'saropaLints.focusIssuesWithSeverityFilter', ['info']),
      ];
    }
    if ((element.nodeId === 'byImpact' || element.label === 'By impact') && s?.byImpact) {
      return [
        new SummaryItem('Critical', String(s.byImpact.critical ?? 0), vscode.TreeItemCollapsibleState.None, undefined, 'saropaLints.focusIssuesWithImpactFilter', ['critical']),
        new SummaryItem('High', String(s.byImpact.high ?? 0), vscode.TreeItemCollapsibleState.None, undefined, 'saropaLints.focusIssuesWithImpactFilter', ['high']),
        new SummaryItem('Medium', String(s.byImpact.medium ?? 0), vscode.TreeItemCollapsibleState.None, undefined, 'saropaLints.focusIssuesWithImpactFilter', ['medium']),
        new SummaryItem('Low', String(s.byImpact.low ?? 0), vscode.TreeItemCollapsibleState.None, undefined, 'saropaLints.focusIssuesWithImpactFilter', ['low']),
        new SummaryItem('Opinionated', String(s.byImpact.opinionated ?? 0), vscode.TreeItemCollapsibleState.None, undefined, 'saropaLints.focusIssuesWithImpactFilter', ['opinionated']),
      ];
    }
    if ((element.nodeId === 'byRuleType' || element.label === 'By rule type') && s?.byRuleType) {
      return Object.entries(s.byRuleType)
        .sort((a, b) => b[1] - a[1])
        .map(([ruleType, count]) =>
          new SummaryItem(
            prettifyToken(ruleType),
            String(count),
            vscode.TreeItemCollapsibleState.None,
            undefined,
            'saropaLints.focusIssuesByRuleMetadata',
            ['ruleType', ruleType],
          ),
        );
    }
    if (
      (element.nodeId === 'byRuleStatus' || element.label === 'By rule status') &&
      s?.byRuleStatus
    ) {
      return Object.entries(s.byRuleStatus)
        .sort((a, b) => b[1] - a[1])
        .map(([ruleStatus, count]) =>
          new SummaryItem(
            prettifyToken(ruleStatus),
            String(count),
            vscode.TreeItemCollapsibleState.None,
            undefined,
            'saropaLints.focusIssuesByRuleMetadata',
            ['ruleStatus', ruleStatus],
          ),
        );
    }
    if (element.nodeId === 'suppressions' && s?.suppressions) {
      return buildSuppressionGroupChildren(s.suppressions);
    }
    if (
      element.nodeId &&
      isSuppressionGroupNodeId(element.nodeId) &&
      s?.suppressions
    ) {
      return buildSuppressionEntries(element.nodeId, s.suppressions);
    }
    if (element.nodeId === 'hotspotReview') {
      const hotspotCounts = countSecurityHotspotReviewStates(
        data.violations,
        data.config?.ruleMetadataByRule,
        this.hotspotReviewState,
      );
      return [
        new SummaryItem('Reviewed', String(hotspotCounts.reviewedSafe + hotspotCounts.reviewedFixed), vscode.TreeItemCollapsibleState.None, undefined, 'saropaLints.reviewHotspotState'),
        new SummaryItem('Open', String(hotspotCounts.open), vscode.TreeItemCollapsibleState.None, undefined, 'saropaLints.reviewHotspotState'),
        new SummaryItem('Reviewed Safe', String(hotspotCounts.reviewedSafe), vscode.TreeItemCollapsibleState.None, undefined, 'saropaLints.reviewHotspotState'),
        new SummaryItem('Reviewed Fixed', String(hotspotCounts.reviewedFixed), vscode.TreeItemCollapsibleState.None, undefined, 'saropaLints.reviewHotspotState'),
      ];
    }

    return [];
  }
}

function isSuppressionGroupNodeId(value: string): value is SuppressionsGroupNodeId {
  return value === 'suppressionsByKind' || value === 'suppressionsByRule' || value === 'suppressionsByFile';
}

function buildSuppressionGroupChildren(suppressions: NonNullable<NonNullable<ReturnType<typeof readViolations>>['summary']>['suppressions']): SummaryItem[] {
  const children: SummaryItem[] = [];
  if (suppressions.byKind && Object.keys(suppressions.byKind).length > 0) {
    children.push(
      new SummaryItem(
        'By kind',
        formatBreakdownDescription(suppressions.byKind),
        vscode.TreeItemCollapsibleState.Collapsed,
        'suppressionsByKind',
      ),
    );
  }
  if (suppressions.byRule && Object.keys(suppressions.byRule).length > 0) {
    children.push(
      new SummaryItem(
        'By rule',
        `${Object.keys(suppressions.byRule).length} rules`,
        vscode.TreeItemCollapsibleState.Collapsed,
        'suppressionsByRule',
      ),
    );
  }
  if (suppressions.byFile && Object.keys(suppressions.byFile).length > 0) {
    children.push(
      new SummaryItem(
        'By file',
        `${Object.keys(suppressions.byFile).length} files`,
        vscode.TreeItemCollapsibleState.Collapsed,
        'suppressionsByFile',
      ),
    );
  }
  if (children.length === 0) {
    children.push(new SummaryItem('Total', String(suppressions.total ?? 0)));
  }
  return children;
}

function buildSuppressionEntries(
  nodeId: SuppressionsGroupNodeId,
  suppressions: NonNullable<NonNullable<ReturnType<typeof readViolations>>['summary']>['suppressions'],
): SummaryItem[] {
  if (nodeId === 'suppressionsByKind') {
    return Object.entries(suppressions.byKind ?? {})
      .sort((a, b) => b[1] - a[1] || a[0].localeCompare(b[0]))
      .map(([kind, count]) => new SummaryItem(prettifyToken(kind), String(count)));
  }
  if (nodeId === 'suppressionsByRule') {
    return Object.entries(suppressions.byRule ?? {})
      .sort((a, b) => b[1] - a[1] || a[0].localeCompare(b[0]))
      .map(([rule, count]) =>
        new SummaryItem(
          rule,
          String(count),
          vscode.TreeItemCollapsibleState.None,
          undefined,
          'saropaLints.focusIssuesForRules',
          [[rule]],
        ),
      );
  }
  return Object.entries(suppressions.byFile ?? {})
    .sort((a, b) => b[1] - a[1] || a[0].localeCompare(b[0]))
    .map(([filePath, count]) =>
      new SummaryItem(
        filePath,
        String(count),
        vscode.TreeItemCollapsibleState.None,
        undefined,
        'saropaLints.openFileAndFocusIssues',
        [filePath],
      ),
    );
}

function formatBreakdownDescription(entries: Record<string, number>): string {
  const sorted = Object.entries(entries).sort((a, b) => b[1] - a[1]);
  if (sorted.length === 0) return '—';
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
