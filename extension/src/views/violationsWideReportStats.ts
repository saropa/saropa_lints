/**
 * Pure stats / aggregation helpers for the Findings (violations) wide dashboard:
 * severity & impact tallies, top-rule picking, per-rule accumulation, and
 * distinct-file counts. Split out of violationsWideReportView.ts so the panel
 * controller is not interleaved with side-effect-free counting logic.
 */

import * as vscode from 'vscode';
import type { Violation } from '../violationsReader';

export function buildScannerSlice(
  cfg: vscode.WorkspaceConfiguration,
): { enabled: boolean; hasDartFiles: boolean } {
  const hasDartFiles = vscode.languages
    .getDiagnostics()
    .some(([uri]) => uri.fsPath.endsWith('.dart'));
  return {
    enabled: cfg.get<boolean>('todosAndHacks.workspaceScanEnabled', false),
    hasDartFiles,
  };
}

export function countBySeverity(violations: readonly Violation[]): Record<string, number> {
  return {
    error: violations.filter((v) => (v.severity ?? 'info').toLowerCase() === 'error').length,
    warning: violations.filter((v) => (v.severity ?? 'info').toLowerCase() === 'warning').length,
    info: violations.filter((v) => (v.severity ?? 'info').toLowerCase() === 'info').length,
  };
}

export function countByImpact(violations: readonly Violation[]): Record<string, number> {
  // Three-bucket severity model (was: 5-bucket critical/high/medium/low/
  // opinionated taxonomy; collapsed 2026-05-03).
  return {
    error: violations.filter((v) => (v.impact ?? 'info').toLowerCase() === 'error').length,
    warning: violations.filter((v) => (v.impact ?? 'info').toLowerCase() === 'warning').length,
    info: violations.filter((v) => (v.impact ?? 'info').toLowerCase() === 'info').length,
  };
}

/** Highest-volume rule across the post-disable violations; absent if no rules. */
export function pickTopRule(violations: readonly Violation[]): { name: string; count: number } | undefined {
  if (violations.length === 0) return undefined;
  const counts = new Map<string, number>();
  for (const v of violations) {
    counts.set(v.rule, (counts.get(v.rule) ?? 0) + 1);
  }
  let best: { name: string; count: number } | undefined;
  for (const [name, count] of counts) {
    if (!best || count > best.count) best = { name, count };
  }
  return best;
}

/**
 * Cap on rows in the noisy-rule triage table. Trimmed 20 → 10 so the table
 * stays scannable above the fold: each row now expands to its full message +
 * affected-file list, so 10 rich rows beat 20 terse ones.
 */
export const TOP_RULES_LIMIT = 10;

/**
 * Per-rule cap on files listed inside an expanded Top-Rules row. Guards against
 * a pathological "one rule, hundreds of files" case ballooning the webview DOM.
 */
const TOP_RULE_FILES_LIMIT = 12;

interface TopRuleEntry {
  name: string;
  count: number;
  severity: string;
  /** Representative finding message (first occurrence), shown on expand. */
  message: string;
  /** Files carrying this rule, highest-count first, with a representative line. */
  files: Array<{ file: string; count: number; line: number }>;
}

interface RuleAccumulator {
  count: number;
  severity: string;
  message: string;
  /** file path → { occurrence count, lowest line seen } for that rule. */
  files: Map<string, { count: number; line: number }>;
}

/** Single pass: tally per-rule count, severity, first message, and per-file stats. */
function accumulateRuleStats(violations: readonly Violation[]): Map<string, RuleAccumulator> {
  const acc = new Map<string, RuleAccumulator>();
  for (const v of violations) {
    let entry = acc.get(v.rule);
    if (!entry) {
      // A rule has a single LintCode severity, so first-seen is deterministic.
      entry = {
        count: 0,
        severity: (v.severity ?? 'info').toLowerCase(),
        message: v.message ?? '',
        files: new Map(),
      };
      acc.set(v.rule, entry);
    }
    entry.count += 1;
    if (!entry.message && v.message) entry.message = v.message;
    const line = v.line ?? 1;
    const perFile = entry.files.get(v.file);
    if (perFile) {
      perFile.count += 1;
      if (line < perFile.line) perFile.line = line;
    } else {
      entry.files.set(v.file, { count: 1, line });
    }
  }
  return acc;
}

/**
 * Top-N rules by violation count. Sorted by count desc; ties broken by rule
 * name for stable rendering between rebuilds. Each entry carries the data the
 * dashboard's expandable Top-Rules row needs (message + affected files), so
 * the user can triage without scrolling to the findings table.
 */
export function pickTopRules(violations: readonly Violation[], limit: number): TopRuleEntry[] {
  if (violations.length === 0) return [];
  const acc = accumulateRuleStats(violations);
  const entries = Array.from(acc, ([name, stats]) => ({ name, stats }));
  entries.sort((a, b) => b.stats.count - a.stats.count || a.name.localeCompare(b.name));
  return entries.slice(0, limit).map(({ name, stats }) => {
    const files = Array.from(stats.files, ([file, s]) => ({ file, count: s.count, line: s.line }))
      .sort((a, b) => b.count - a.count || a.file.localeCompare(b.file))
      .slice(0, TOP_RULE_FILES_LIMIT);
    return { name, count: stats.count, severity: stats.severity, message: stats.message, files };
  });
}

export function countDistinctFiles(violations: readonly Violation[]): number {
  const set = new Set<string>();
  for (const v of violations) set.add(v.file);
  return set.size;
}

