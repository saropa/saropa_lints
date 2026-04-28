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
  const total = data.summary?.totalViolations ?? data.violations.length;
  const critical = byImpact?.critical ?? 0;
  const high = byImpact?.high ?? 0;
  const errors = bySeverity?.error ?? 0;

  const labels: string[] = [];
  if (critical > 0) {
    labels.push('critical');
  }
  if (high > 0 && labels.length < 3) {
    labels.push('high');
  }
  if (errors > 0 && !labels.some((l) => l.includes('error'))) {
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

  labels.push('run', 'open');
  return Math.min(labels.length, 8);
}
