/**
 * Model for the consolidated dashboard: one entry per rule.
 *
 * At scale the unit of interaction is the RULE, not the finding — 1000 findings
 * collapse to ~60 rule groups. This builds those groups from the LIVE #1a model
 * (so the surface reads the exact diagnostics the Problems panel shows, zero
 * analysis triggered) and grades them with the shared `severityScore`, so the
 * consolidated hero and the Findings Dashboard gauge can never disagree.
 *
 * Occurrences are retained on each group but are NOT sent to the webview in the
 * initial payload — the view streams them per-rule on expand (lazy loading), so
 * first paint costs ~60 small headers, never 1000 rows.
 */

import {
  buildViolationsDataFromDiagnostics,
  type GetDiagnosticsFn,
} from '../../liveDiagnosticsModel';
import { severityScore, scoreToGrade, type LetterGrade } from '../../healthGrade';

export type Severity = 'error' | 'warning' | 'info';

export interface Occurrence {
  file: string;
  line: number;
  message: string;
  severity: Severity;
}

export interface RuleGroup {
  rule: string;
  count: number;
  /** Highest severity present in the group — drives the row accent + rank. */
  worst: Severity;
  error: number;
  warning: number;
  info: number;
  occurrences: Occurrence[];
}

export interface ConsolidatedModel {
  score: number;
  grade: LetterGrade;
  totals: { error: number; warning: number; info: number; files: number; total: number };
  groups: RuleGroup[];
}

const SEVERITY_RANK: Record<Severity, number> = { error: 0, warning: 1, info: 2 };

function worstOf(a: Severity, b: Severity): Severity {
  return SEVERITY_RANK[a] <= SEVERITY_RANK[b] ? a : b;
}

export function buildConsolidatedModel(
  root: string,
  getDiagnostics?: GetDiagnosticsFn,
): ConsolidatedModel {
  const data = buildViolationsDataFromDiagnostics(root, getDiagnostics);

  const byRule = new Map<string, RuleGroup>();
  const files = new Set<string>();
  let error = 0;
  let warning = 0;
  let info = 0;

  for (const v of data.violations) {
    const severity = (v.severity ?? 'info') as Severity;
    files.add(v.file);
    if (severity === 'error') error++;
    else if (severity === 'warning') warning++;
    else info++;

    let group = byRule.get(v.rule);
    if (!group) {
      group = { rule: v.rule, count: 0, worst: 'info', error: 0, warning: 0, info: 0, occurrences: [] };
      byRule.set(v.rule, group);
    }
    group.count++;
    group[severity]++;
    group.worst = worstOf(group.worst, severity);
    group.occurrences.push({ file: v.file, line: v.line, message: v.message, severity });
  }

  // Triage rank: worst severity first, then highest count, then rule name for a
  // stable order across rebuilds (so live updates don't reshuffle the list).
  const groups = [...byRule.values()].sort(
    (a, b) =>
      SEVERITY_RANK[a.worst] - SEVERITY_RANK[b.worst] ||
      b.count - a.count ||
      a.rule.localeCompare(b.rule),
  );
  // Within a group, surface the worst occurrences first so the lazy expansion
  // reads top-down by urgency.
  for (const g of groups) {
    g.occurrences.sort(
      (a, b) =>
        SEVERITY_RANK[a.severity] - SEVERITY_RANK[b.severity] ||
        a.file.localeCompare(b.file) ||
        a.line - b.line,
    );
  }

  const score = severityScore({ error, warning, info });
  return {
    score,
    grade: scoreToGrade(score),
    totals: { error, warning, info, files: files.size, total: data.violations.length },
    groups,
  };
}
