"use strict";
/**
 * Triage grouping from violations data (issuesByRule).
 * Used for data-driven triage: Group A (1–5), B (6–20), C (21–100), D (100+).
 */
Object.defineProperty(exports, "__esModule", { value: true });
exports.TRIAGE_GROUP_BOUNDS = void 0;
exports.groupRulesByVolume = groupRulesByVolume;
exports.partitionStylistic = partitionStylistic;
exports.buildRuleImpactMap = buildRuleImpactMap;
exports.identifyCriticalRules = identifyCriticalRules;
exports.getZeroIssueCount = getZeroIssueCount;
exports.TRIAGE_GROUP_BOUNDS = [
    { id: 'A', min: 1, max: 5, label: '1–5 issues' },
    { id: 'B', min: 6, max: 20, label: '6–20 issues' },
    { id: 'C', min: 21, max: 100, label: '21–100 issues' },
    { id: 'D', min: 101, max: Number.MAX_SAFE_INTEGER, label: '100+ issues' },
];
/**
 * Group rules by issue count for triage UI.
 * Only includes rules that have at least one issue (from issuesByRule).
 * Stylistic rules can be filtered separately using config.stylisticRuleNames.
 */
function groupRulesByVolume(issuesByRule) {
    const result = exports.TRIAGE_GROUP_BOUNDS.map((b) => ({
        id: b.id,
        label: b.label,
        rules: [],
        totalIssues: 0,
    }));
    for (const [rule, count] of Object.entries(issuesByRule)) {
        if (count <= 0)
            continue;
        for (let i = 0; i < exports.TRIAGE_GROUP_BOUNDS.length; i++) {
            const b = exports.TRIAGE_GROUP_BOUNDS[i];
            if (count >= b.min && count <= b.max) {
                result[i].rules.push(rule);
                result[i].totalIssues += count;
                break;
            }
        }
    }
    return result.filter((g) => g.rules.length > 0);
}
/**
 * Split enabled rule names into stylistic vs non-stylistic.
 * When stylisticRuleNames is absent, all are treated as non-stylistic.
 */
function partitionStylistic(ruleNames, stylisticRuleNames) {
    const stylisticSet = new Set(stylisticRuleNames ?? []);
    const stylistic = [];
    const nonStylistic = [];
    for (const r of ruleNames) {
        if (stylisticSet.has(r)) {
            stylistic.push(r);
        }
        else {
            nonStylistic.push(r);
        }
    }
    return { stylistic, nonStylistic };
}
/**
 * Single O(n) scan of violations to build per-rule impact breakdown.
 * Returned map is reused by all triage groups for score estimation,
 * avoiding repeated scans of a potentially large violations array.
 */
function buildRuleImpactMap(violations) {
    const map = new Map();
    for (const v of violations) {
        let counts = map.get(v.rule);
        if (!counts) {
            counts = { critical: 0, high: 0, medium: 0, low: 0, opinionated: 0 };
            map.set(v.rule, counts);
        }
        const impact = v.impact ?? 'low';
        if (impact in counts) {
            counts[impact] += 1;
        }
    }
    return map;
}
/**
 * Rules that have at least one critical-impact violation.
 * These are "always on" in the triage — users should fix, not disable.
 */
function identifyCriticalRules(impactMap, issuesByRule) {
    const result = [];
    for (const [rule, counts] of impactMap) {
        if (counts.critical > 0) {
            result.push({ ruleName: rule, issueCount: issuesByRule[rule] ?? counts.critical });
        }
    }
    // Sort by issue count descending for display priority.
    return result.sort((a, b) => b.issueCount - a.issueCount);
}
/**
 * Count of enabled rules with zero violations — good news, auto-enabled.
 */
function getZeroIssueCount(enabledRuleNames, issuesByRule) {
    let count = 0;
    for (const rule of enabledRuleNames) {
        if (!issuesByRule[rule] || issuesByRule[rule] === 0)
            count += 1;
    }
    return count;
}
//# sourceMappingURL=triageUtils.js.map