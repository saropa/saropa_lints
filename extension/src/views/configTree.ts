/**
 * Tree data provider for Saropa Lints Config view.
 * Shows current settings, detected platform/packages, triage groups, and actions.
 *
 * I1: The triage section shows rules grouped by priority (critical, volume A–D,
 * stylistic) so users can see which rules produce the most violations and
 * navigate to them in the Violations view.
 */

import * as vscode from 'vscode';
import { readPubspec } from '../pubspecReader';
import { getProjectRoot } from '../projectRoot';
import { readViolations } from '../violationsReader';
import {
  type ConfigTreeNode,
  type ConfigSettingNode,
  type TriageData,
  type TriageGroupNode,
  buildTriageData,
  getTriageGroupChildren,
  renderTreeItem,
} from './triageTree';

function setting(label: string, description?: string, commandId?: string): ConfigSettingNode {
  return { kind: 'configSetting', label, description, commandId };
}

export class ConfigTreeProvider implements vscode.TreeDataProvider<ConfigTreeNode> {
  private _onDidChangeTreeData = new vscode.EventEmitter<ConfigTreeNode | undefined | void>();
  readonly onDidChangeTreeData = this._onDidChangeTreeData.event;

  // Cached per refresh so expanding groups reuses the same computation.
  private cachedTriage: TriageData | null = null;

  refresh(): void {
    this.cachedTriage = null;
    this._onDidChangeTreeData.fire();
  }

  getTreeItem(element: ConfigTreeNode): vscode.TreeItem {
    return renderTreeItem(element);
  }

  getChildren(element?: ConfigTreeNode): ConfigTreeNode[] {
    // Child level: expand triage groups to show individual rules.
    if (element?.kind === 'triageGroup') {
      const issuesByRule = this.cachedTriage?.issuesByRule ?? {};
      return getTriageGroupChildren(element as TriageGroupNode, issuesByRule);
    }
    if (element) return []; // Other nodes have no children.

    // Root level — standalone Config view shows everything in one flat list.
    return [...this.buildSettingNodes(), ...this.buildTriageSection(), ...this.buildActionNodes()];
  }

  /** Settings + action nodes (no triage). Used by the overview "Settings" section. */
  getSettingAndActionNodes(): ConfigTreeNode[] {
    return [...this.buildSettingNodes(), ...this.buildActionNodes()];
  }

  /** Triage nodes only (groups + info). Used by the overview "Issues" section. */
  getTriageNodes(): ConfigTreeNode[] {
    return this.buildTriageSection();
  }

  /** Lint integration, tier, run-after-config, detected packages. */
  private buildSettingNodes(): ConfigTreeNode[] {
    const cfg = vscode.workspace.getConfiguration('saropaLints');
    const enabled = cfg.get<boolean>('enabled', true) ?? true;
    const tier = cfg.get<string>('tier', 'recommended') ?? 'recommended';
    const runAfter = cfg.get<boolean>('runAnalysisAfterConfigChange', true) ?? true;

    const items: ConfigTreeNode[] = [
      setting('Lint integration', enabled ? 'On' : 'Off', enabled ? 'saropaLints.disable' : 'saropaLints.enable'),
      setting('Tier', tier, 'saropaLints.setTier'),
      setting('Run analysis after config change', runAfter ? 'Yes' : 'No'),
    ];

    // Detected platform/packages from pubspec.
    const root = getProjectRoot();
    if (root) {
      const pubspec = readPubspec(root);
      const parts: string[] = [];
      if (pubspec.isFlutter) parts.push('Flutter');
      if (pubspec.packages.length > 0) {
        const pkgs = pubspec.packages.slice(0, 5).join(', ');
        parts.push(pubspec.packages.length > 5 ? pkgs + '…' : pkgs);
      }
      if (parts.length > 0) items.push(setting('Detected', parts.join(' · ')));
    }

    return items;
  }

  /** Open config, initialize, run analysis. */
  private buildActionNodes(): ConfigTreeNode[] {
    return [
      setting('Open analysis_options_custom.yaml', undefined, 'saropaLints.openConfig'),
      setting('Initialize / Update config', undefined, 'saropaLints.initializeConfig'),
      setting('Run analysis', undefined, 'saropaLints.runAnalysis'),
    ];
  }

  /** I1: Triage groups — only when violations data with issuesByRule is available. */
  private buildTriageSection(): ConfigTreeNode[] {
    const root = getProjectRoot();
    if (!root) return [];

    const data = readViolations(root);
    if (!data) return [];

    this.cachedTriage = buildTriageData(data, root);
    if (!this.cachedTriage) return [];

    return this.buildTriageNodes(this.cachedTriage);
  }

  /** Build the flat list of triage group nodes for the root level. */
  private buildTriageNodes(triage: TriageData): ConfigTreeNode[] {
    const nodes: ConfigTreeNode[] = [];
    if (triage.criticalGroup) nodes.push(triage.criticalGroup);
    nodes.push(...triage.volumeGroups);
    if (triage.zeroIssueCount > 0) {
      nodes.push({
        kind: 'triageInfo',
        label: `${triage.zeroIssueCount} rules with zero issues`,
        description: 'auto-enabled',
      });
    }
    // I2: Show count of rules explicitly disabled by user overrides.
    if (triage.disabledOverrideCount > 0) {
      nodes.push({
        kind: 'triageInfo',
        label: `${triage.disabledOverrideCount} rules disabled by override`,
      });
    }
    if (triage.stylisticGroup) nodes.push(triage.stylisticGroup);
    return nodes;
  }
}
