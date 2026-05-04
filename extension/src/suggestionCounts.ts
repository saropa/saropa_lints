/**
 * Pure helpers for **Suggestions** row counts (no VS Code API).
 *
 * `countSuggestionItems` mirrors the branching in {@link SuggestionsTreeProvider.getChildren}
 * (capped at 8) so the Overview sidebar toggle can show “how much is in Suggestions” without
 * constructing tree nodes. Kept in a standalone module so unit tests and `sidebarSectionCounts`
 * do not pull in `vscode` or the full Suggestions tree provider.
 */

import * as fs from 'node:fs';
import * as path from 'node:path';
import type { ViolationsData } from './violationsReader';
import { RULE_PACK_DEFINITIONS } from './rulePacks/rulePackDefinitions';
import { readRulePacksEnabled } from './rulePacks/rulePackYaml';

/**
 * Same row count as `SuggestionsTreeProvider.getChildren` (capped at 8), for Overview sidebar toggles.
 */
export function countSuggestionItems(data: ViolationsData, root: string, tier: string): number {
  const byImpact = data.summary?.byImpact;
  const bySeverity = data.summary?.bySeverity;
  const issuesByRule = data.summary?.issuesByRule ?? {};
  const relatedByRule = data.config?.relatedRulesByRule ?? {};
  const conflictingByRule = data.config?.conflictingRulesByRule ?? {};
  const enabledRules = new Set(data.config?.enabledRuleNames ?? []);
  const enabledPackIds = new Set(readRulePacksEnabled(root));
  const total = data.summary?.totalViolations ?? data.violations.length;
  // Severity-keyed counts (was: critical/high under the 5-bucket impact
  // taxonomy retired on 2026-05-03).
  const errorCount = byImpact?.error ?? 0;
  const warningCount = byImpact?.warning ?? 0;
  const errors = bySeverity?.error ?? 0;

  const labels: string[] = [];
  if (errorCount > 0) {
    labels.push('errors');
  }
  if (warningCount > 0 && labels.length < 3) {
    labels.push('warnings');
  }
  // Mirrored analyzer-error suggestion stays even when the impact-error label
  // already pushed (the two come from different summary fields).
  if (errors > 0 && labels.length < 3 && !labels.includes('errors')) {
    labels.push('errors');
  }

  const baselinePath = path.join(root, 'saropa_baseline.json');
  if (total > 0 && !fs.existsSync(baselinePath)) {
    labels.push('baseline');
  }
  if (tier === 'recommended' && total > 0) {
    labels.push('tier');
  }

  // Match SuggestionsTree related-rule recommendations (up to 5 source rules).
  for (const sourceRule of Object.entries(issuesByRule)
    .sort((a, b) => b[1] - a[1])
    .map(([rule]) => rule)
    .slice(0, 5)) {
    if (labels.length >= 8) break;
    const related = relatedByRule[sourceRule] ?? [];
    const sourceConflicts = new Set(conflictingByRule[sourceRule] ?? []);
    const candidate = related.find((r) => {
      if (!r || enabledRules.has(r)) return false;
      if (sourceConflicts.has(r)) return false;
      const candidateConflicts = new Set(conflictingByRule[r] ?? []);
      return ![...candidateConflicts].some((name) => enabledRules.has(name));
    });
    if (!candidate) continue;
    if (labels.includes(`related:${candidate}`)) continue;
    labels.push(`related:${candidate}`);
  }

  const candidateRelated = new Set<string>();
  for (const sourceRule of Object.keys(issuesByRule)) {
    for (const candidate of relatedByRule[sourceRule] ?? []) {
      if (!candidate || enabledRules.has(candidate)) continue;
      candidateRelated.add(candidate);
    }
  }
  const packSuggestionCount = RULE_PACK_DEFINITIONS
    .filter((pack) => !enabledPackIds.has(pack.id))
    .map((pack) => pack.ruleCodes.filter((code) => candidateRelated.has(code)).length)
    .filter((count) => count >= 2)
    .sort((a, b) => b - a)
    .slice(0, 2).length;
  for (let i = 0; i < packSuggestionCount && labels.length < 8; i += 1) {
    labels.push(`pack:${i}`);
  }

  labels.push('run', 'open');
  return Math.min(labels.length, 8);
}
