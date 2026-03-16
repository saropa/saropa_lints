"use strict";
/**
 * Detail-level tree item builders.
 *
 * These builders produce DetailItem[] arrays for tree nodes that represent
 * secondary/detail views: dependency graph summaries, override entries,
 * and actionable insights. Extracted from tree-item-builders.ts to keep
 * each module under the 300-line limit.
 */
Object.defineProperty(exports, "__esModule", { value: true });
exports.buildDepGraphSummaryDetails = buildDepGraphSummaryDetails;
exports.buildOverrideDetails = buildOverrideDetails;
exports.buildInsightDetails = buildInsightDetails;
const override_analyzer_1 = require("../scoring/override-analyzer");
const tree_item_classes_1 = require("./tree-item-classes");
/**
 * Build detail items for DepGraphSummaryItem children.
 *
 * Shows counts of direct, transitive, and total unique packages,
 * plus any dependency_overrides and highly-shared transitive deps.
 */
function buildDepGraphSummaryDetails(summary) {
    const items = [];
    items.push(new tree_item_classes_1.DetailItem('Direct', `${summary.directCount} packages`));
    items.push(new tree_item_classes_1.DetailItem('Transitive', `${summary.transitiveCount} packages`));
    items.push(new tree_item_classes_1.DetailItem('Total Unique', `${summary.totalUnique} packages`));
    // Warn about dependency_overrides if any are present
    if (summary.overrideCount > 0) {
        items.push(new tree_item_classes_1.DetailItem('⚠️ Overrides', `${summary.overrideCount} in pubspec.yaml`));
    }
    // Show the top shared transitive deps (those used by many direct deps)
    if (summary.sharedDeps.length > 0) {
        for (const shared of summary.sharedDeps.slice(0, 3)) {
            items.push(new tree_item_classes_1.DetailItem(`🔗 ${shared.name}`, `used by ${shared.usedBy.length} direct deps`));
        }
    }
    return items;
}
/**
 * Build detail items for an override node.
 *
 * Provides status (active vs. stale), age info with staleness hints,
 * dependency type (path/git), and a risk warning about bypassing
 * version constraints.
 */
function buildOverrideDetails(analysis) {
    const items = [];
    // Active overrides resolve a real constraint conflict;
    // stale overrides have no detectable conflict and may be removable
    if (analysis.status === 'active') {
        items.push(new tree_item_classes_1.DetailItem('✓ Status', `Active — ${analysis.blocker ?? 'resolves constraint'}`));
    }
    else {
        items.push(new tree_item_classes_1.DetailItem('⚠️ Status', 'Stale — no version conflict detected'));
    }
    // Show how long the override has been in place
    if (analysis.ageDays !== null) {
        const ageStr = (0, override_analyzer_1.formatAge)(analysis.ageDays);
        const dateStr = analysis.addedDate
            ? ` (since ${analysis.addedDate.toISOString().split('T')[0]})`
            : '';
        items.push(new tree_item_classes_1.DetailItem('📅 Age', `${ageStr}${dateStr}`));
        // Nudge the user to review old but still-active overrides
        if ((0, override_analyzer_1.isOldOverride)(analysis) && analysis.status === 'active') {
            items.push(new tree_item_classes_1.DetailItem('💡 Hint', 'Review whether this override is still needed'));
        }
    }
    // Indicate non-standard dependency sources
    if (analysis.entry.isPathDep) {
        items.push(new tree_item_classes_1.DetailItem('📁 Type', 'Local path dependency'));
    }
    else if (analysis.entry.isGitDep) {
        items.push(new tree_item_classes_1.DetailItem('🔗 Type', 'Git dependency'));
    }
    // Always warn that overrides bypass normal version resolution
    items.push(new tree_item_classes_1.DetailItem('⚠️ Risk', 'Bypasses version constraints'));
    return items;
}
/**
 * Build detail items for an insight node.
 *
 * Lists each problem with a severity-coloured emoji, an optional
 * suggested action, and any packages that would be unblocked if the
 * insight's problems are fixed.
 */
function buildInsightDetails(insight) {
    const items = [];
    // Map severity to a traffic-light emoji for quick scanning
    for (const problem of insight.problems) {
        const emoji = problem.severity === 'high' ? '🔴'
            : problem.severity === 'medium' ? '🟡' : '🔵';
        items.push(new tree_item_classes_1.DetailItem(`${emoji} ${problem.type}`, problem.message));
    }
    // Show the recommended next step if one was computed
    if (insight.suggestedAction) {
        items.push(new tree_item_classes_1.DetailItem('💡 Suggested', insight.suggestedAction));
    }
    // List packages whose upgrades are gated on fixing this insight
    if (insight.unlocksIfFixed.length > 0) {
        items.push(new tree_item_classes_1.DetailItem('🔓 Unlocks', insight.unlocksIfFixed.join(', ')));
    }
    return items;
}
//# sourceMappingURL=tree-item-detail-builders.js.map