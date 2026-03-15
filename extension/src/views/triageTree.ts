/** I1/I2: Triage node types and data computation for the Config view. */
import * as vscode from 'vscode';
import type { ViolationsData, IssuesByRule } from '../violationsReader';
import { groupRulesByVolume, partitionStylistic, buildRuleImpactMap, identifyCriticalRules, getZeroIssueCount, type RuleImpactCounts } from '../triageUtils';
import { estimateScoreForRuleRemoval, type RuleRemovalEstimate } from '../healthScore';
import { countDisabledOverrides } from '../configWriter';

export interface ConfigSettingNode {
  kind: 'configSetting';
  label: string;
  description?: string;
  commandId?: string;
}

export interface TriageGroupNode {
  kind: 'triageGroup';
  groupId: string;
  label: string;
  description: string;
  rules: string[];
  totalIssues: number;
}

export interface TriageRuleNode {
  kind: 'triageRule';
  ruleName: string;
  issueCount: number;
}

export interface TriageInfoNode {
  kind: 'triageInfo';
  label: string;
  description?: string;
}

export type ConfigTreeNode = ConfigSettingNode | TriageGroupNode | TriageRuleNode | TriageInfoNode;

export interface TriageData {
  criticalGroup: TriageGroupNode | null;
  volumeGroups: TriageGroupNode[];
  zeroIssueCount: number;
  disabledOverrideCount: number;
  stylisticGroup: TriageGroupNode | null;
  issuesByRule: IssuesByRule;
}

/** Compute all triage groups from violations data. */
export function buildTriageData(data: ViolationsData, root?: string): TriageData | null {
  const issuesByRule = data.summary?.issuesByRule;
  if (!issuesByRule) return null;

  const violations = data.violations ?? [];
  const impactMap = buildRuleImpactMap(violations);

  // Critical rules — have at least one critical-impact violation.
  const criticalRules = identifyCriticalRules(impactMap, issuesByRule);
  const criticalRuleNames = new Set(criticalRules.map((r) => r.ruleName));

  // Filter critical rules OUT of the volume grouping to avoid double-counting.
  const nonCriticalIssues: IssuesByRule = {};
  for (const [rule, count] of Object.entries(issuesByRule)) {
    if (!criticalRuleNames.has(rule)) nonCriticalIssues[rule] = count;
  }

  // Also filter stylistic rules out of volume grouping.
  const stylisticNames = new Set(data.config?.stylisticRuleNames ?? []);
  const volumeIssues: IssuesByRule = {};
  const stylisticIssues: IssuesByRule = {};
  for (const [rule, count] of Object.entries(nonCriticalIssues)) {
    if (stylisticNames.has(rule)) {
      stylisticIssues[rule] = count;
    } else {
      volumeIssues[rule] = count;
    }
  }

  const volumeGroups = groupRulesByVolume(volumeIssues);

  // Build group nodes with score estimates.
  const criticalGroup = criticalRules.length > 0
    ? buildGroupNode('critical', 'Critical rules', criticalRules.map((r) => r.ruleName),
        criticalRules.reduce((s, r) => s + r.issueCount, 0), data, impactMap)
    : null;

  const volumeNodes = volumeGroups.map((g) =>
    buildGroupNode(g.id, `Group ${g.id}: ${g.label}`, g.rules, g.totalIssues, data, impactMap),
  );

  // Stylistic group.
  const { stylistic } = partitionStylistic(
    Object.keys(stylisticIssues),
    data.config?.stylisticRuleNames,
  );
  const stylisticTotal = stylistic.reduce((s, r) => s + (issuesByRule[r] ?? 0), 0);
  const stylisticGroup = stylistic.length > 0
    ? buildGroupNode('stylistic', 'Stylistic (opt-in)', stylistic, stylisticTotal, data, impactMap)
    : null;

  // Zero-issue count.
  const enabledRuleNames = data.config?.enabledRuleNames ?? [];
  const zeroCount = getZeroIssueCount(enabledRuleNames, issuesByRule);

  // I2: Count rules explicitly disabled by user overrides.
  const disabledCount = root ? countDisabledOverrides(root) : 0;

  return {
    criticalGroup,
    volumeGroups: volumeNodes,
    zeroIssueCount: zeroCount,
    disabledOverrideCount: disabledCount,
    stylisticGroup,
    issuesByRule,
  };
}

function buildGroupNode(
  id: string,
  label: string,
  rules: string[],
  totalIssues: number,
  data: ViolationsData,
  impactMap: Map<string, RuleImpactCounts>,
): TriageGroupNode {
  const estimate = estimateScoreForRuleRemoval(data, impactMap, rules);
  const desc = formatGroupDescription(rules.length, totalIssues, estimate);
  return { kind: 'triageGroup', groupId: id, label, description: desc, rules, totalIssues };
}

function formatGroupDescription(
  ruleCount: number,
  totalIssues: number,
  estimate: RuleRemovalEstimate | null,
): string {
  const parts: string[] = [];
  parts.push(`${ruleCount} rule${ruleCount === 1 ? '' : 's'}`);
  parts.push(`${totalIssues} issue${totalIssues === 1 ? '' : 's'}`);
  if (estimate && estimate.delta > 0) {
    parts.push(`est. +${estimate.delta} pts`);
  }
  return parts.join(', ');
}

/** Build child rule nodes for a triage group. */
export function getTriageGroupChildren(
  group: TriageGroupNode,
  issuesByRule: IssuesByRule,
): TriageRuleNode[] {
  return group.rules
    .map((rule) => ({
      kind: 'triageRule' as const,
      ruleName: rule,
      issueCount: issuesByRule[rule] ?? 0,
    }))
    .sort((a, b) => b.issueCount - a.issueCount);
}

/** Convert a ConfigTreeNode to a VS Code TreeItem for rendering. */
export function renderTreeItem(node: ConfigTreeNode): vscode.TreeItem {
  switch (node.kind) {
    case 'configSetting': {
      const item = new vscode.TreeItem(node.label, vscode.TreeItemCollapsibleState.None);
      item.description = node.description;
      if (node.commandId) item.command = { command: node.commandId, title: node.label, arguments: [] };
      return item;
    }
    case 'triageGroup':
      return renderGroupItem(node);
    case 'triageRule': {
      const item = new vscode.TreeItem(node.ruleName, vscode.TreeItemCollapsibleState.None);
      item.description = `${node.issueCount}`;
      item.command = { command: 'saropaLints.focusIssuesForRules', title: 'Show in Issues', arguments: [[node.ruleName]] };
      item.contextValue = 'triageRule';
      item.iconPath = new vscode.ThemeIcon('circle-outline');
      return item;
    }
    case 'triageInfo': {
      const item = new vscode.TreeItem(node.label, vscode.TreeItemCollapsibleState.None);
      item.description = node.description;
      item.iconPath = new vscode.ThemeIcon('pass', new vscode.ThemeColor('testing.iconPassed'));
      return item;
    }
  }
}

function renderGroupItem(node: TriageGroupNode): vscode.TreeItem {
  const item = new vscode.TreeItem(node.label, vscode.TreeItemCollapsibleState.Collapsed);
  item.description = node.description;
  item.command = { command: 'saropaLints.focusIssuesForRules', title: 'Show in Issues', arguments: [node.rules] };
  item.contextValue = 'triageGroup';
  const icon = node.groupId === 'critical' ? 'flame'
    : node.groupId === 'stylistic' ? 'paintcan' : 'tag';
  const color = node.groupId === 'critical' ? new vscode.ThemeColor('list.errorForeground') : undefined;
  item.iconPath = new vscode.ThemeIcon(icon, color);
  return item;
}
