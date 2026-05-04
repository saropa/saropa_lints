/**
 * Tree data provider for Saropa Lints Suggestions view.
 * "What to do next" from violations.json and workspace state.
 */

import * as vscode from 'vscode';
import * as path from 'path';
import * as fs from 'fs';
import { readViolations, filterDisabledFromData, type ViolationsData } from '../violationsReader';
import { computeHealthScore, estimateScoreWithout } from '../healthScore';
import { getProjectRoot } from '../projectRoot';
import { readDisabledRules } from '../configWriter';
import { RULE_PACK_DEFINITIONS } from '../rulePacks/rulePackDefinitions';
import { readRulePacksEnabled } from '../rulePacks/rulePackYaml';

export { countSuggestionItems } from '../suggestionCounts';

class SuggestionItem extends vscode.TreeItem {
  constructor(
    label: string,
    description: string | undefined,
    public readonly commandId?: string,
    public readonly args: unknown[] = [],
  ) {
    super(label, vscode.TreeItemCollapsibleState.None);
    this.description = description;
    if (commandId) {
      this.command = { command: commandId, title: label, arguments: args };
    }
    this.iconPath = new vscode.ThemeIcon('lightbulb');
    this.contextValue = 'suggestionItem';
  }
}

export class SuggestionsTreeProvider implements vscode.TreeDataProvider<SuggestionItem> {
  private _onDidChangeTreeData = new vscode.EventEmitter<SuggestionItem | undefined | void>();
  readonly onDidChangeTreeData = this._onDidChangeTreeData.event;

  refresh(): void {
    this._onDidChangeTreeData.fire();
  }

  getTreeItem(element: SuggestionItem): vscode.TreeItem {
    return element;
  }

  async getChildren(): Promise<SuggestionItem[]> {
    const root = getProjectRoot();
    const items: SuggestionItem[] = [];
    const cfg = vscode.workspace.getConfiguration('saropaLints');

    const rawData = root ? readViolations(root) : null;
    // C5: When no data, return empty so viewsWelcome "Run analysis" shows.
    if (!rawData) return [];

    // Filter out violations for rules disabled in config so suggestion
    // counts stay consistent with the Violations view.
    const data = filterDisabledFromData(rawData, readDisabledRules(root!));

    const byImpact = data?.summary?.byImpact;
    const bySeverity = data?.summary?.bySeverity;
    const issuesByRule = data?.summary?.issuesByRule ?? {};
    const relatedByRule = data?.config?.relatedRulesByRule ?? {};
    const conflictingByRule = data?.config?.conflictingRulesByRule ?? {};
    const enabledRules = new Set(data?.config?.enabledRuleNames ?? []);
    const enabledPackIds = new Set(readRulePacksEnabled(root!));
    const total = data?.summary?.totalViolations ?? data?.violations?.length ?? 0;
    // Severity-keyed counts (was: critical/high under the 5-bucket impact
    // taxonomy retired on 2026-05-03). The bySeverity field still exists for
    // analyzer-error focus suggestions.
    const errorCount = byImpact?.error ?? 0;
    const warningCount = byImpact?.warning ?? 0;
    const errors = bySeverity?.error ?? 0;

    // Compute current score and projected scores for severity suggestions.
    const currentScore = computeHealthScore(data)?.score;

    if (errorCount > 0) {
      // Show estimated score gain from fixing all error-severity findings.
      // Skip the "+0 points" message when projected gain is zero.
      const projected = estimateScoreWithout(data, 'error');
      const gain = (currentScore !== undefined && projected !== null)
        ? projected - currentScore
        : null;
      const desc = (gain !== null && gain > 0)
        ? `estimated +${gain} points`
        : 'Show in Issues';
      items.push(
        new SuggestionItem(
          `Fix ${errorCount} error(s)`,
          desc,
          'saropaLints.focusIssuesWithImpactFilter',
          ['error'],
        ),
      );
    }
    if (warningCount > 0 && items.length < 3) {
      const projected = estimateScoreWithout(data, 'warning');
      const gain = (currentScore !== undefined && projected !== null)
        ? projected - currentScore
        : null;
      const desc = (gain !== null && gain > 0)
        ? `estimated +${gain} points`
        : 'Show in Issues';
      items.push(
        new SuggestionItem(
          `Address ${warningCount} warning(s)`,
          desc,
          'saropaLints.focusIssuesWithImpactFilter',
          ['warning'],
        ),
      );
    }
    if (errors > 0 && !items.some((i) => String(i.label).includes('error'))) {
      items.push(
        new SuggestionItem(
          `Fix ${errors} analyzer error(s)`,
          'Show in Issues',
          'saropaLints.focusIssuesWithSeverityFilter',
          ['error'],
        ),
      );
    }

    const baselinePath = root ? path.join(root, 'saropa_baseline.json') : '';
    if (total > 0 && root && !fs.existsSync(baselinePath)) {
      items.push(
        new SuggestionItem(
          'Create baseline to suppress existing violations',
          'New code still checked',
          'saropaLints.openConfig',
        ),
      );
    }

    const tier = cfg.get<string>('tier', 'recommended') ?? 'recommended';
    if (tier === 'recommended' && total > 0) {
      items.push(
        new SuggestionItem(
          'Consider professional tier for more rules',
          'Settings → saropaLints.tier',
          'saropaLints.initializeConfig',
        ),
      );
    }

    // Surface curated related rules that are not enabled yet.
    if (items.length < 8 && Object.keys(issuesByRule).length > 0) {
      finalTopRules:
      for (const sourceRule of Object.entries(issuesByRule)
        .sort((a, b) => b[1] - a[1])
        .map(([rule]) => rule)
        .slice(0, 5)) {
        const related = relatedByRule[sourceRule] ?? [];
        for (const candidate of related) {
          if (!candidate || enabledRules.has(candidate)) continue;
          const sourceConflicts = new Set(conflictingByRule[sourceRule] ?? []);
          if (sourceConflicts.has(candidate)) continue;
          const candidateConflicts = new Set(conflictingByRule[candidate] ?? []);
          const conflictsEnabled = [...candidateConflicts].some((name) => enabledRules.has(name));
          if (conflictsEnabled) continue;
          if (items.some((i) => String(i.label).includes(candidate))) continue;
          items.push(
            new SuggestionItem(
              `Consider enabling ${candidate}`,
              `Related to active rule ${sourceRule}`,
              'saropaLints.explainRuleFromSuggestion',
              [candidate, sourceRule],
            ),
          );
          if (items.length >= 8) break finalTopRules;
          break;
        }
      }
    }

    // Rule pack follow-up: recommend enabling a pack when many unmet related rules
    // cluster into the same currently-disabled pack.
    if (items.length < 8) {
      const candidateRelated = new Set<string>();
      for (const sourceRule of Object.keys(issuesByRule)) {
        for (const candidate of relatedByRule[sourceRule] ?? []) {
          if (!candidate || enabledRules.has(candidate)) continue;
          candidateRelated.add(candidate);
        }
      }
      const packScores = RULE_PACK_DEFINITIONS
        .filter((pack) => !enabledPackIds.has(pack.id))
        .map((pack) => ({
          pack,
          relatedCount: pack.ruleCodes.filter((code) => candidateRelated.has(code)).length,
        }))
        .filter((row) => row.relatedCount >= 2)
        .sort((a, b) => b.relatedCount - a.relatedCount || a.pack.label.localeCompare(b.pack.label))
        .slice(0, 2);

      for (const row of packScores) {
        if (items.length >= 8) break;
        items.push(
          new SuggestionItem(
            `Enable ${row.pack.label} rule pack`,
            `${row.relatedCount} related rules available`,
            'saropaLints.openConfigDashboard',
          ),
        );
      }
    }

    items.push(new SuggestionItem('Run analysis', 'Refresh violations', 'saropaLints.runAnalysis'));
    items.push(new SuggestionItem('Open config', 'analysis_options_custom.yaml', 'saropaLints.openConfig'));

    return items.slice(0, 8);
  }
}
