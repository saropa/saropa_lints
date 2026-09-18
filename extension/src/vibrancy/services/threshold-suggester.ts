/**
 * Module overview (comment coverage pass).
 * comment-coverage: module overview (batch).
 *
 * Vibrancy UI experiment: scoring, providers, and webview assets.
 */

import { VibrancyResult, CiThresholds } from '../types';

/**
 * Suggest sensible CI thresholds based on current scan results.
 * 
 * Strategy:
 * - maxEndOfLife: current count (so existing ones don't fail; any new ones will)
 * - maxOutdated: direct and dev dependencies with a newer version available,
 *   + 1 (small buffer). The same measure the generated CI check enforces
 *   (see buildCheckerScript), so a pipeline built from these suggestions
 *   passes on the project it was suggested for.
 * - minAverageVibrancy: current average rounded down to nearest 5
 * - failOnVulnerability: always true for safety
 */
export function suggestThresholds(results: readonly VibrancyResult[]): CiThresholds {
    const endOfLifeCount = countCategory(results, 'end-of-life');
    const abandonedCount = countCategory(results, 'abandoned');
    const outdatedCount = countUpdatableDirect(results);
    const averageVibrancy = computeAverageVibrancy(results);

    return {
        maxAbandoned: abandonedCount,
        maxEndOfLife: endOfLifeCount,
        maxOutdated: outdatedCount + 1,
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

/**
 * Direct (including dev) dependencies with an update available — not the
 * `outdated` vibrancy category, which is a score band, not version currency.
 */
function countUpdatableDirect(results: readonly VibrancyResult[]): number {
    return results.filter((r) => {
        const status = r.updateInfo?.updateStatus;
        return r.package.isDirect && (status === 'patch' || status === 'minor' || status === 'major');
    }).length;
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
        `Abandoned ≤ ${thresholds.maxAbandoned}`,
        `EOL ≤ ${thresholds.maxEndOfLife}`,
        `Outdated ≤ ${thresholds.maxOutdated}`,
        `Avg ≥ ${thresholds.minAverageVibrancy}`,
    ];
    if (thresholds.failOnVulnerability) {
        parts.push('Fail on vuln');
    }
    return parts.join(' | ');
}
