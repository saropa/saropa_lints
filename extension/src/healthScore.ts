/**
 * Health Score — single 0–100 number computed from violations data.
 *
 * The score uses impact-weighted violation density (violations per file)
 * with exponential decay: a few critical issues hurt a lot, many minor
 * issues hurt less per-issue. This makes the score intuitive:
 *   100 = zero violations
 *   80+ = good shape (few issues, none critical)
 *   50–79 = needs work
 *   <50 = serious problems
 *
 * The formula is intentionally simple and all constants are grouped at
 * the top for easy tuning.
 */

import { ViolationsData } from './violationsReader';

// --- Tuning constants ---

/** How much each impact level contributes to the weighted violation count. */
const IMPACT_WEIGHTS = {
  critical: 8,
  high: 3,
  medium: 1,
  low: 0.25,
  opinionated: 0.05,
} as const;

/**
 * Controls how steeply the score drops as density increases.
 * Higher = harsher. At 0.3:
 *   density 1 → score ~74
 *   density 2 → score ~55
 *   density 5 → score ~22
 */
const DECAY_RATE = 0.3;

/**
 * Coerce unknown values to number, returning 0 for null/undefined/NaN/non-numeric.
 * Guards against malformed JSON (e.g. "critical": "bad").
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
 * Compute a health score from violations data.
 * Returns null if there is no summary data to compute from.
 */
export function computeHealthScore(
  data: ViolationsData,
): HealthScoreResult | null {
  const summary = data.summary;
  if (!summary) return null;

  const filesAnalyzed = summary.filesAnalyzed ?? 0;
  // No files analyzed means no meaningful score.
  if (filesAnalyzed === 0) return null;

  const impact = summary.byImpact ?? {};
  const critical = safeNum(impact.critical);
  const high = safeNum(impact.high);
  const medium = safeNum(impact.medium);
  const low = safeNum(impact.low);
  const opinionated = safeNum(impact.opinionated);

  const weightedViolations =
    critical * IMPACT_WEIGHTS.critical +
    high * IMPACT_WEIGHTS.high +
    medium * IMPACT_WEIGHTS.medium +
    low * IMPACT_WEIGHTS.low +
    opinionated * IMPACT_WEIGHTS.opinionated;

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
  if (delta > 0) return `\u25B2${delta}`;
  if (delta < 0) return `\u25BC${Math.abs(delta)}`;
  return '';
}

/**
 * Estimate the score if all violations of a given impact level were fixed.
 * C3: Used by Suggestions to show "Fix N critical → estimated +X points".
 */
export function estimateScoreWithout(
  data: ViolationsData,
  impact: keyof typeof IMPACT_WEIGHTS,
): number | null {
  const summary = data.summary;
  if (!summary) return null;
  const filesAnalyzed = summary.filesAnalyzed ?? 0;
  if (filesAnalyzed === 0) return null;

  const impactCounts = summary.byImpact ?? {};

  // Compute weighted sum with the target impact zeroed out.
  let weighted = 0;
  for (const [key, weight] of Object.entries(IMPACT_WEIGHTS)) {
    if (key === impact) continue;
    weighted += safeNum((impactCounts as Record<string, unknown>)[key]) * weight;
  }
  const density = weighted / filesAnalyzed;
  const raw = Math.round(100 * Math.exp(-density * DECAY_RATE));
  return Number.isFinite(raw) ? raw : 0;
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
