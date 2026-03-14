/**
 * Run history — persists last K analysis snapshots in workspace state.
 * Used by W5 (trends) and W6 (celebration / progress messages).
 */

import * as vscode from 'vscode';
import { ViolationsData } from './violationsReader';
import { computeHealthScore } from './healthScore';

const HISTORY_KEY = 'saropaLints.runHistory';
const MAX_ENTRIES = 20;
const TREND_DISPLAY_COUNT = 5;

export interface RunSnapshot {
  timestamp: string;
  total: number;
  error: number;
  warning: number;
  info: number;
  critical: number;
  /** Health score (0–100) at time of snapshot. Absent in old history entries. */
  score?: number;
}

/** Return type for appendSnapshot — includes whether a new entry was recorded. */
export interface AppendResult {
  history: RunSnapshot[];
  /** True when a new snapshot was appended; false when dedup suppressed it. */
  appended: boolean;
}

export function loadHistory(state: vscode.Memento): RunSnapshot[] {
  const raw = state.get<RunSnapshot[]>(HISTORY_KEY);
  return Array.isArray(raw) ? raw : [];
}

function saveHistory(state: vscode.Memento, history: RunSnapshot[]): void {
  // Log write failures so silent data loss is detectable in the output channel.
  state.update(HISTORY_KEY, history).then(undefined, (err: unknown) => {
    console.error('[saropaLints] Failed to save run history:', err);
  });
}

/**
 * Appends a snapshot from the current violations data.
 * Deduplicates by comparing total, severity breakdown, and score to the
 * last entry — a same-total run with different severity mix is still recorded.
 * Returns the updated history and whether a new entry was actually appended.
 */
export function appendSnapshot(
  state: vscode.Memento,
  data: ViolationsData,
): AppendResult {
  const history = loadHistory(state);
  const total = data.summary?.totalViolations ?? data.violations.length;
  const last = history.length > 0 ? history[history.length - 1] : undefined;

  const errorCount = data.summary?.bySeverity?.error ?? 0;
  const warningCount = data.summary?.bySeverity?.warning ?? 0;
  const infoCount = data.summary?.bySeverity?.info ?? 0;
  const criticalCount = data.summary?.byImpact?.critical ?? 0;
  const healthResult = computeHealthScore(data);

  // Skip duplicate — same total, severity breakdown, AND score as last snapshot.
  // A severity shift with the same total still records a new entry.
  if (
    last &&
    last.total === total &&
    last.error === errorCount &&
    last.warning === warningCount &&
    last.info === infoCount &&
    last.critical === criticalCount &&
    (last.score ?? -1) === (healthResult?.score ?? -1)
  ) {
    return { history, appended: false };
  }

  const snapshot: RunSnapshot = {
    timestamp: new Date().toISOString(),
    total,
    error: errorCount,
    warning: warningCount,
    info: infoCount,
    critical: criticalCount,
    score: healthResult?.score,
  };

  history.push(snapshot);

  // Cap at MAX_ENTRIES by dropping oldest entries.
  while (history.length > MAX_ENTRIES) {
    history.shift();
  }

  saveHistory(state, history);
  return { history, appended: true };
}

/**
 * Returns a human-readable trend summary for display in Overview.
 * - 0 entries: undefined
 * - 1 entry: "First run: N violations"
 * - 2+ entries: last K totals arrow-separated, e.g. "120 → 115 → 98"
 */
export function getTrendSummary(history: RunSnapshot[]): string | undefined {
  if (history.length === 0) return undefined;
  if (history.length === 1) {
    const n = history[0].total;
    return `First run: ${n} ${n === 1 ? 'violation' : 'violations'}`;
  }
  const recent = history.slice(-TREND_DISPLAY_COUNT);
  return recent.map((s) => String(s.total)).join(' \u2192 ');
}

/**
 * Find the most recent snapshot that has a score, excluding the last entry.
 * Used to compute the score delta ("▲4") shown in Overview and status bar.
 */
export function findPreviousScore(
  history: RunSnapshot[],
): number | undefined {
  for (let i = history.length - 2; i >= 0; i--) {
    if (history[i].score !== undefined) return history[i].score;
  }
  return undefined;
}
