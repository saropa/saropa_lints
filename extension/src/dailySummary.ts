/**
 * Build the Saropa Suite daily-report contribution (see [DailySummary] in
 * api.ts) from the local analysis snapshot the dashboards already compute.
 *
 * This is a thin wrapper, not new analysis: violation counts, the health
 * score, and run-history deltas all come from surfaces that already exist
 * (`openProjectHealthDashboard`, the status bar, Suggestions). It adds no
 * network access and reads nothing new from disk beyond what the caller
 * passes in.
 *
 * apiVersion 1 keeps no per-day history: `counts` reflect the current
 * snapshot echoed against the requested date, with a best-effort
 * day-over-day delta pulled from the run-history the extension already keeps.
 * The Workspace consumer tolerates that (documented in the Suite contract).
 */

import type { DailySummary } from './api';
import type { ViolationsData } from './violationsReader';
import type { RunSnapshot } from './runHistory';
import { computeHealthScore } from './healthScore';

/** Deep-link command ids reused as the Suite's data-out channel. */
const OPEN_COMMAND = 'saropaLints.openProjectHealthDashboard';
const FOCUS_ISSUES_COMMAND = 'saropaLints.focusIssues';

export interface DailySummaryInput {
  /** The requested day, YYYY-MM-DD. Echoed back verbatim. */
  date: string;
  /** Current local analysis snapshot. Caller guarantees non-null (undefined API result otherwise). */
  data: ViolationsData;
  /** Persisted run-history (workspace state) for the day-over-day delta. */
  history: readonly RunSnapshot[];
  /**
   * Outdated direct dependencies from the in-memory Package Vibrancy scan, or
   * undefined when no scan has run this session. Omitted from `counts` when
   * undefined so callers never see a misleading zero.
   */
  outdatedPackages?: number;
}

/** Severity counts read from the (already severity-normalized) summary, with a violations fallback. */
function severityCounts(data: ViolationsData): {
  total: number;
  error: number;
  warning: number;
  info: number;
} {
  const summary = data.summary;
  const bySeverity = summary?.bySeverity;
  const error = bySeverity?.error ?? 0;
  const warning = bySeverity?.warning ?? 0;
  const info = bySeverity?.info ?? 0;
  const total = summary?.totalViolations ?? data.violations.length;
  return { total, error, warning, info };
}

/**
 * The most recent history snapshot from a day strictly before `date` — the
 * baseline for the day-over-day delta. Returns undefined when history has no
 * such entry (first run, or only same-day snapshots). Timestamps are ISO, so
 * the leading 10 chars are the YYYY-MM-DD date and sort lexicographically.
 */
function baselineBefore(
  history: readonly RunSnapshot[],
  date: string,
): RunSnapshot | undefined {
  let baseline: RunSnapshot | undefined;
  for (const snap of history) {
    if (typeof snap.timestamp !== 'string') continue;
    const snapDate = snap.timestamp.slice(0, 10);
    // Entries are appended in chronological order, so the last one that
    // predates the requested day is the closest prior baseline.
    if (snapDate < date) baseline = snap;
  }
  return baseline;
}

/** Format a signed count as human text, e.g. "12 fewer" / "3 more" / "no change". */
function deltaPhrase(delta: number, noun: string): string {
  if (delta < 0) return `${Math.abs(delta)} fewer ${noun}`;
  if (delta > 0) return `${delta} more ${noun}`;
  return `no change in ${noun}`;
}

/**
 * Build the [DailySummary] payload. Pure — all inputs are passed in so the
 * extension wiring stays a one-liner and this stays unit-testable without a
 * VS Code host.
 */
export function buildDailySummary(input: DailySummaryInput): DailySummary {
  const { date, data, history, outdatedPackages } = input;
  const { total, error, warning, info } = severityCounts(data);
  const health = computeHealthScore(data);

  const counts: Record<string, number> = {
    violations: total,
    critical: error,
    warnings: warning,
    info,
  };
  // Health score is withheld on a partial sweep (see computeHealthScore) —
  // omit the key rather than report a misleading value.
  if (health) counts.healthScore = health.score;
  if (typeof outdatedPackages === 'number') counts.outdatedPackages = outdatedPackages;

  const baseline = baselineBefore(history, date);

  // Headline: score (+ delta) → violations (+ delta) → error count.
  const parts: string[] = [];
  if (health) {
    const scoreDelta =
      baseline?.score !== undefined ? health.score - baseline.score : undefined;
    const deltaTag =
      scoreDelta !== undefined && scoreDelta !== 0
        ? ` (${scoreDelta > 0 ? '+' : ''}${scoreDelta})`
        : '';
    parts.push(`Health score ${health.score}${deltaTag}`);
  } else {
    parts.push('Health score unavailable (partial analysis)');
  }
  const violationDeltaTag =
    baseline !== undefined ? ` (${deltaPhrase(total - baseline.total, 'than the previous run')})` : '';
  parts.push(`${total} violation${total === 1 ? '' : 's'}${violationDeltaTag}`);
  parts.push(`${error} error${error === 1 ? '' : 's'}`);
  const headline = `${parts.join(', ')}.`;

  // Trouble is failure-only: error-level findings and a score regression.
  const trouble: DailySummary['trouble'] = [];
  if (error > 0) {
    trouble.push({
      label: `${error} error-level violation${error === 1 ? '' : 's'}`,
      detail: 'Highest-severity findings — fix these first.',
      command: FOCUS_ISSUES_COMMAND,
    });
  }
  if (health && baseline?.score !== undefined && health.score < baseline.score) {
    const drop = baseline.score - health.score;
    trouble.push({
      label: `Health score dropped ${drop} point${drop === 1 ? '' : 's'}`,
      detail: `${baseline.score} → ${health.score} since the previous run.`,
      command: OPEN_COMMAND,
    });
  }

  return {
    tool: 'saropa-lints',
    date,
    headline,
    counts,
    trouble,
    openCommand: OPEN_COMMAND,
  };
}
