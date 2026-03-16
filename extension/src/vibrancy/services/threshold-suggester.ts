import { VibrancyResult, CiThresholds } from '../types';

/**
 * Suggest sensible CI thresholds based on current scan results.
 * 
 * Strategy:
 * - maxEndOfLife: current count (so existing ones don't fail; any new ones will)
 * - maxLegacyLocked: current count + 1 (small buffer)
 * - minAverageVibrancy: current average rounded down to nearest 5
 * - failOnVulnerability: always true for safety
 */
export function suggestThresholds(results: readonly VibrancyResult[]): CiThresholds {
    const endOfLifeCount = countCategory(results, 'end-of-life');
    const legacyLockedCount = countCategory(results, 'legacy-locked');
    const averageVibrancy = computeAverageVibrancy(results);

    return {
        maxEndOfLife: endOfLifeCount,
        maxLegacyLocked: legacyLockedCount + 1,
        minAverageVibrancy: roundDownToNearest5(averageVibrancy),
        failOnVulnerability: true,
    };
}

function countCategory(
    results: readonly VibrancyResult[],
    category: string,
): number {
    return results.filter(r => r.category === category).length;
}

function computeAverageVibrancy(results: readonly VibrancyResult[]): number {
    if (results.length === 0) { return 0; }
    const total = results.reduce((sum, r) => sum + r.score, 0);
    return Math.round(total / results.length);
}

function roundDownToNearest5(value: number): number {
    return Math.floor(value / 5) * 5;
}

/** Format thresholds for display in quick-pick. */
export function formatThresholdsSummary(thresholds: CiThresholds): string {
    const parts = [
        `EOL ≤ ${thresholds.maxEndOfLife}`,
        `Legacy ≤ ${thresholds.maxLegacyLocked}`,
        `Avg ≥ ${thresholds.minAverageVibrancy}`,
    ];
    if (thresholds.failOnVulnerability) {
        parts.push('Fail on vuln');
    }
    return parts.join(' | ');
}
