/**
 * Health Score — single 0–100 number computed from violations data.
 *
 * The score uses severity-weighted violation density (violations per file)
 * with exponential decay: a few errors hurt a lot, many info-level findings
 * hurt less per-issue. This makes the score intuitive:
 *   100 = zero violations
 *   80+ = good shape (few issues, no errors)
 *   50–79 = needs work
 *   <50 = serious problems
 *
 * The formula is intentionally simple and all constants are grouped at
 * the top for easy tuning.
 *
 * Severity model: error / warning / info — collapsed from the prior 5-bucket
 * impact taxonomy on 2026-05-03 (see plan/COLLAPSE_LINT_IMPACT_TO_SEVERITY.md).
 * The Dart enum value LintImpact.error replaced LintImpact.critical, etc.
 */

import { ViolationsData } from './violationsReader';
import type { RuleImpactCounts } from './triageUtils';

// --- Tuning constants ---
// Keep in sync with lib/src/report/health_score_constants.dart (Dart package).
// Used by getHealthScoreParams() for Log Capture and consumer_contract.json.

/**
 * How much each severity contributes to the weighted violation count.
 * Three weights, matching the analyzer's native ERROR/WARNING/INFO model.
 *
 * The pre-2026-05-03 5-bucket map (`critical: 8, high: 3, medium: 1,
 * low: 0.25, opinionated: 0.05`) collapsed to:
 * - critical → error (8)
 * - high + medium → warning (avg ~2; chose 3 to keep WARNING noticeable)
 * - low + opinionated → info (chose 0.25 to keep INFO present but quiet)
 */
export const IMPACT_WEIGHTS = {
  error: 8,
  warning: 3,
  info: 0.25,
} as const;

/**
 * Controls how steeply the score drops as density increases.
 * Higher = harsher. At 0.3:
 *   density 1 → score ~74
 *   density 2 → score ~55
 *   density 5 → score ~22
 */
export const DECAY_RATE = 0.3;

/**
 * Minimum fraction of the project that must be analyzed before a score is
 * trusted. Below this, the report is treated as a partial sweep and no score
 * is produced (see [isReportTooPartial]).
 *
 * **Why this exists.** The IDE plugin analyzes files incrementally
 * (open/affected first) and writes the report on a debounce, so a snapshot can
 * land with only a handful of files. Dividing violations by that tiny
 * denominator inflates density and craters the score to a false 0% — the bug
 * this guards against. The score returns once a full `dart analyze` sweep
 * lands.
 *
 * **Deliberately low.** `filesExpected` (the denominator) counts *all*
 * discovered `.dart` files, including those later excluded by
 * `analysis_options`. A project with large excluded dirs analyzes far fewer
 * files than it discovers — e.g. this repo excludes its bundled `example`
 * fixture dirs and a full sweep covers ~0.24 of discovered files. The
 * threshold sits below
 * that so legitimate full sweeps still score.
 *
 * **What it catches / misses.** Catches grossly-partial reports (coverage
 * under the threshold, e.g. an early IDE sweep or an open-editors-only run).
 * It does NOT catch a mid-coverage report that over-represents messy files,
 * and it will withhold the score from a project that excludes more than
 * ~85% of its `.dart` files via `analysis_options`.
 */
export const MIN_COVERAGE_FOR_SCORE = 0.15;

/**
 * Coerce unknown values to number, returning 0 for null/undefined/NaN/non-numeric.
 * Guards against malformed JSON (e.g. "error": "bad").
 */
function safeNum(v: unknown): number {
  return typeof v === 'number' && Number.isFinite(v) ? v : 0;
}

// --- Public API ---

export interface HealthScoreResult {
  /** 0–100 score. Higher is better. */
  score: number;
  /** Weighted violation count used in the formula. */
  weightedViolations: number;
  /** Violations per file (weighted). */
  density: number;
}

/**
 * True when the report covers too small a fraction of the project to score.
 *
 * Returns false when `filesExpected` is absent (older plugin reports carry no
 * coverage signal — we trust them rather than hiding the score). Otherwise
 * compares analyzed-vs-expected against [MIN_COVERAGE_FOR_SCORE].
 */
export function isReportTooPartial(data: ViolationsData): boolean {
  const summary = data.summary;
  if (!summary) return false;
  const expected = summary.filesExpected ?? 0;
  if (expected <= 0) return false; // no coverage signal — do not gate
  const analyzed = summary.filesAnalyzed ?? 0;
  return analyzed < expected * MIN_COVERAGE_FOR_SCORE;
}

/**
 * Compute a health score from violations data.
 * Returns null if there is no summary data to compute from, or if the report
 * is only a partial sweep (see [isReportTooPartial]) — a score from an
 * incremental slice is misleading, so callers show "no score" instead.
 */
export function computeHealthScore(
  data: ViolationsData,
): HealthScoreResult | null {
  const summary = data.summary;
  if (!summary) return null;

  const filesAnalyzed = summary.filesAnalyzed ?? 0;
  // No files analyzed means no meaningful score.
  if (filesAnalyzed === 0) return null;
  // A tiny incremental sample inflates density and produces a false 0%.
  if (isReportTooPartial(data)) return null;

  const impact = summary.byImpact ?? {};
  const errorCount = safeNum(impact.error);
  const warningCount = safeNum(impact.warning);
  const infoCount = safeNum(impact.info);

  const weightedViolations =
    errorCount * IMPACT_WEIGHTS.error +
    warningCount * IMPACT_WEIGHTS.warning +
    infoCount * IMPACT_WEIGHTS.info;

  const density = weightedViolations / filesAnalyzed;

  // Exponential decay: score drops quickly at first, then flattens.
  // Clamp to 0 as a safety net if density somehow produces NaN.
  const rawScore = Math.round(100 * Math.exp(-density * DECAY_RATE));
  const score = Number.isFinite(rawScore) ? rawScore : 0;

  return { score, weightedViolations, density };
}

/**
 * Format a score delta for display.
 * Returns e.g. "▲4", "▼3", or "" if no change.
 */
export function formatScoreDelta(current: number, previous: number): string {
  // Round defensively in case callers supply non-integer scores.
  const delta = Math.round(current - previous);
  if (delta > 0) return `▲${delta}`;
  if (delta < 0) return `▼${Math.abs(delta)}`;
  return '';
}

/**
 * Estimate the score if all violations of a given severity were fixed.
 * Used by Suggestions to show "Fix N errors → estimated +X points".
 */
export function estimateScoreWithout(
  data: ViolationsData,
  impact: keyof typeof IMPACT_WEIGHTS,
): number | null {
  const summary = data.summary;
  if (!summary) return null;
  const filesAnalyzed = summary.filesAnalyzed ?? 0;
  if (filesAnalyzed === 0) return null;
  // Mirror computeHealthScore: do not project from a partial sweep.
  if (isReportTooPartial(data)) return null;

  const impactCounts = summary.byImpact ?? {};

  // Compute weighted sum with the target severity zeroed out.
  let weighted = 0;
  for (const [key, weight] of Object.entries(IMPACT_WEIGHTS)) {
    if (key === impact) continue;
    weighted += safeNum((impactCounts as Record<string, unknown>)[key]) * weight;
  }
  const density = weighted / filesAnalyzed;
  const raw = Math.round(100 * Math.exp(-density * DECAY_RATE));
  return Number.isFinite(raw) ? raw : 0;
}

export interface RuleRemovalEstimate {
  projectedScore: number;
  delta: number;
  issueCount: number;
}

/**
 * Estimate score if all violations from a set of rules were fixed.
 * Uses pre-computed ruleImpactMap (from buildRuleImpactMap) to avoid
 * re-scanning the violations array per group.
 */
export function estimateScoreForRuleRemoval(
  data: ViolationsData,
  ruleImpactMap: Map<string, RuleImpactCounts>,
  rules: string[],
): RuleRemovalEstimate | null {
  const health = computeHealthScore(data);
  if (!health) return null;
  const filesAnalyzed = data.summary?.filesAnalyzed ?? 0;
  if (filesAnalyzed === 0) return null;

  // Sum the weighted impact of violations being removed.
  let removedWeighted = 0;
  let removedCount = 0;
  for (const rule of rules) {
    const counts = ruleImpactMap.get(rule);
    if (!counts) continue;
    removedWeighted +=
      counts.error * IMPACT_WEIGHTS.error +
      counts.warning * IMPACT_WEIGHTS.warning +
      counts.info * IMPACT_WEIGHTS.info;
    removedCount += counts.error + counts.warning + counts.info;
  }
  if (removedCount === 0) return null;

  // Recompute score with the removed violations subtracted.
  const newWeighted = Math.max(0, health.weightedViolations - removedWeighted);
  const density = newWeighted / filesAnalyzed;
  const raw = Math.round(100 * Math.exp(-density * DECAY_RATE));
  const projectedScore = Number.isFinite(raw) ? raw : 0;

  return { projectedScore, delta: projectedScore - health.score, issueCount: removedCount };
}

/**
 * Estimate score after removing a single violation of the given severity.
 * Uses the violation's severity weight to subtract from the weighted total.
 */
export function estimateScoreWithoutViolation(
  data: ViolationsData,
  impact: string,
): { projectedScore: number; delta: number } | null {
  const health = computeHealthScore(data);
  if (!health) return null;
  const filesAnalyzed = data.summary?.filesAnalyzed ?? 0;
  if (filesAnalyzed === 0) return null;

  const weight = IMPACT_WEIGHTS[impact as keyof typeof IMPACT_WEIGHTS] ?? 0;
  const newWeighted = Math.max(0, health.weightedViolations - weight);
  const density = newWeighted / filesAnalyzed;
  const raw = Math.round(100 * Math.exp(-density * DECAY_RATE));
  const projectedScore = Number.isFinite(raw) ? raw : 0;

  return { projectedScore, delta: projectedScore - health.score };
}

/**
 * Return a color hint based on score thresholds.
 * Used by status bar and overview to pick visual treatment.
 */
export function scoreColorBand(
  score: number,
): 'green' | 'yellow' | 'red' {
  if (score >= 80) return 'green';
  if (score >= 50) return 'yellow';
  return 'red';
}
