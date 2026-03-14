/**
 * Run history — persists last K analysis snapshots in workspace state.
 * Used by W5 (trends) and W6 (celebration / progress messages).
 */

import * as vscode from 'vscode';
import { ViolationsData } from './violationsReader';

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
}

export function loadHistory(state: vscode.Memento): RunSnapshot[] {
  const raw = state.get<RunSnapshot[]>(HISTORY_KEY);
  return Array.isArray(raw) ? raw : [];
}

function saveHistory(state: vscode.Memento, history: RunSnapshot[]): void {
  void state.update(HISTORY_KEY, history);
}

/**
 * Appends a snapshot from the current violations data.
 * Deduplicates: skips if total matches the last entry (no real change).
 * Returns the updated history array.
 */
export function appendSnapshot(
  state: vscode.Memento,
  data: ViolationsData,
): RunSnapshot[] {
  const history = loadHistory(state);
  const total = data.summary?.totalViolations ?? data.violations.length;
  const last = history.length > 0 ? history[history.length - 1] : undefined;

  // Skip duplicate — same total as last snapshot means no real change.
  if (last && last.total === total) return history;

  const snapshot: RunSnapshot = {
    timestamp: new Date().toISOString(),
    total,
    error: data.summary?.bySeverity?.error ?? 0,
    warning: data.summary?.bySeverity?.warning ?? 0,
    info: data.summary?.bySeverity?.info ?? 0,
    critical: data.summary?.byImpact?.critical ?? 0,
  };

  history.push(snapshot);

  // Cap at MAX_ENTRIES by dropping oldest entries.
  while (history.length > MAX_ENTRIES) {
    history.shift();
  }

  saveHistory(state, history);
  return history;
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
    return `First run: ${history[0].total} violations`;
  }
  const recent = history.slice(-TREND_DISPLAY_COUNT);
  return recent.map((s) => String(s.total)).join(' \u2192 ');
}
