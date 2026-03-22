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
  labels.push('run', 'open');
  return Math.min(labels.length, 8);
}
