/**
 * Shared findings-grade math: turns severity counts into a 0–100 score, a
 * letter grade, and a gauge color.
 *
 * Single source so every dashboard surface (the Findings Dashboard gauge, the
 * consolidated dashboard hero) shows the SAME grade for the same findings. A
 * grade that disagreed between two dashboards would be exactly the
 * displayed-vs-reality mismatch the live-diagnostics work exists to eliminate.
 *
 * The score answers "is this codebase quiet?", not a precise quality metric;
 * it is always paired with the absolute per-severity counts on the surface.
 */

export type LetterGrade = 'A' | 'B' | 'C' | 'D' | 'E';

export interface SeverityCounts {
  error?: number;
  warning?: number;
  info?: number;
}

/**
 * Errors weigh heaviest, warnings moderate, info marginal; clamped to 0–100.
 * Penalty weights (5 / 2 / 0.5) are the long-standing Findings Dashboard
 * weights — kept identical so extracting this helper changes no displayed score.
 */
export function severityScore(counts: SeverityCounts): number {
  const e = counts.error ?? 0;
  const w = counts.warning ?? 0;
  const i = counts.info ?? 0;
  const penalty = e * 5 + w * 2 + i * 0.5;
  return Math.max(0, Math.min(100, Math.round(100 - penalty)));
}

export function scoreToGrade(score: number): LetterGrade {
  if (score >= 90) return 'A';
  if (score >= 75) return 'B';
  if (score >= 60) return 'C';
  if (score >= 40) return 'D';
  return 'E';
}

/**
 * Gauge hue: green→amber as the score climbs above 50, amber→red below it.
 * Matches the original Findings Dashboard gauge so the two never diverge.
 */
export function gradeColor(score: number): string {
  return score >= 50
    ? `hsl(${Math.round(60 + (score - 50) * 1.2)}, 70%, 48%)`
    : `hsl(${Math.round(score * 1.2)}, 75%, 48%)`;
}
