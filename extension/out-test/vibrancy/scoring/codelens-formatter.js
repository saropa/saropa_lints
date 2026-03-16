"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.categoryEmoji = categoryEmoji;
exports.formatCodeLensTitle = formatCodeLensTitle;
const known_issues_1 = require("./known-issues");
const status_classifier_1 = require("./status-classifier");
const bloat_calculator_1 = require("./bloat-calculator");
const indicator_config_1 = require("../services/indicator-config");
/** @deprecated Use getCategoryIndicator() for customizable indicators. */
function categoryEmoji(category) {
    switch (category) {
        case 'vibrant': return '🟢';
        case 'quiet': return '🟡';
        case 'legacy-locked': return '🟠';
        case 'stale': return '🟠';
        case 'end-of-life': return '🔴';
    }
}
function formatUpdateSegment(result) {
    if (!result.updateInfo
        || result.updateInfo.updateStatus === 'up-to-date') {
        return `${(0, indicator_config_1.getIndicator)('upToDate')} Up to date`;
    }
    const { currentVersion, latestVersion, updateStatus } = result.updateInfo;
    return `${(0, indicator_config_1.getIndicator)('updateAvailable')} ${currentVersion} → ${latestVersion} (${updateStatus})`;
}
function formatAlertSegment(result) {
    const warning = (0, indicator_config_1.getIndicator)('warning');
    const replacement = result.knownIssue?.replacement;
    const displayReplacement = replacement
        ? (0, known_issues_1.getReplacementDisplayText)(replacement, result.package.version, result.knownIssue?.replacementObsoleteFromVersion)
        : undefined;
    if (displayReplacement) {
        if ((0, known_issues_1.isReplacementPackageName)(displayReplacement)) {
            return `${warning} Replace with ${displayReplacement}`;
        }
        return `${warning} Consider: ${displayReplacement}`;
    }
    if (result.knownIssue?.reason) {
        return `${warning} Known issue`;
    }
    return null;
}
/** Build the display string for a CodeLens annotation. Pure function. */
function formatCodeLensTitle(result, detail) {
    const style = (0, indicator_config_1.loadIndicatorStyle)();
    const indicator = (0, indicator_config_1.getCategoryIndicator)(result.category);
    const displayScore = Math.round(result.score / 10);
    let scorePart;
    if (style === 'none') {
        scorePart = `${displayScore}/10`;
    }
    else if (style === 'text') {
        scorePart = `${displayScore}/10 ${indicator}`;
    }
    else if (style === 'both') {
        scorePart = `${indicator} ${displayScore}/10`;
    }
    else {
        const label = (0, status_classifier_1.categoryLabel)(result.category);
        scorePart = `${indicator} ${displayScore}/10 ${label}`;
    }
    const parts = [scorePart];
    if (detail === 'minimal') {
        return parts[0];
    }
    if (detail === 'full' && result.archiveSizeBytes !== null) {
        parts.push((0, bloat_calculator_1.formatSizeMB)(result.archiveSizeBytes));
    }
    parts.push(formatUpdateSegment(result));
    const alert = formatAlertSegment(result);
    if (alert) {
        parts.push(alert);
    }
    if (result.isUnused) {
        parts.push(`${(0, indicator_config_1.getIndicator)('unused')} Unused`);
    }
    return parts.join(' · ');
}
//# sourceMappingURL=codelens-formatter.js.map