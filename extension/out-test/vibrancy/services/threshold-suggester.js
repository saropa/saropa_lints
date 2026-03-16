"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.suggestThresholds = suggestThresholds;
exports.formatThresholdsSummary = formatThresholdsSummary;
/**
 * Suggest sensible CI thresholds based on current scan results.
 *
 * Strategy:
 * - maxEndOfLife: current count (so existing ones don't fail; any new ones will)
 * - maxLegacyLocked: current count + 1 (small buffer)
 * - minAverageVibrancy: current average rounded down to nearest 5
 * - failOnVulnerability: always true for safety
 */
function suggestThresholds(results) {
    const endOfLifeCount = countCategory(results, 'end-of-life');
    const staleCount = countCategory(results, 'stale');
    const legacyLockedCount = countCategory(results, 'legacy-locked');
    const averageVibrancy = computeAverageVibrancy(results);
    return {
        maxStale: staleCount,
        maxEndOfLife: endOfLifeCount,
        maxLegacyLocked: legacyLockedCount + 1,
        minAverageVibrancy: roundDownToNearest5(averageVibrancy),
        failOnVulnerability: true,
    };
}
function countCategory(results, category) {
    return results.filter(r => r.category === category).length;
}
function computeAverageVibrancy(results) {
    if (results.length === 0) {
        return 0;
    }
    const total = results.reduce((sum, r) => sum + r.score, 0);
    return Math.round(total / results.length);
}
function roundDownToNearest5(value) {
    return Math.floor(value / 5) * 5;
}
/** Format thresholds for display in quick-pick. */
function formatThresholdsSummary(thresholds) {
    const parts = [
        `Stale ≤ ${thresholds.maxStale}`,
        `EOL ≤ ${thresholds.maxEndOfLife}`,
        `Legacy ≤ ${thresholds.maxLegacyLocked}`,
        `Avg ≥ ${thresholds.minAverageVibrancy}`,
    ];
    if (thresholds.failOnVulnerability) {
        parts.push('Fail on vuln');
    }
    return parts.join(' | ');
}
//# sourceMappingURL=threshold-suggester.js.map