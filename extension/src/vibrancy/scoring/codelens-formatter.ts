import { VibrancyResult } from '../types';
import { isReplacementPackageName, getReplacementDisplayText } from './known-issues';
import { categoryToGrade } from './status-classifier';
import { formatSizeMB } from './bloat-calculator';
import {
    getCategoryIndicator, getIndicator, loadIndicatorStyle,
} from '../services/indicator-config';
import { categoryEmoji } from '../category-dictionary';

export type CodeLensDetail = 'minimal' | 'standard' | 'full';

// Re-export so existing callers (e.g. tests) that import from here still work.
export { categoryEmoji };

function formatUpdateSegment(result: VibrancyResult): string {
    if (!result.updateInfo
        || result.updateInfo.updateStatus === 'up-to-date') {
        return `${getIndicator('upToDate')} Up to date`;
    }
    const { currentVersion, latestVersion, updateStatus } = result.updateInfo;
    return `${getIndicator('updateAvailable')} ${currentVersion} → ${latestVersion} (${updateStatus})`;
}

function formatAlertSegment(result: VibrancyResult): string | null {
    const warning = getIndicator('warning');
    const replacement = result.knownIssue?.replacement;
    const displayReplacement = replacement
        ? getReplacementDisplayText(
            replacement,
            result.package.version,
            result.knownIssue?.replacementObsoleteFromVersion,
        )
        : undefined;
    if (displayReplacement) {
        if (isReplacementPackageName(displayReplacement)) {
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
export function formatCodeLensTitle(
    result: VibrancyResult,
    detail: CodeLensDetail,
): string {
    const style = loadIndicatorStyle();
    const indicator = getCategoryIndicator(result.category);
    /* Letter grade replaces the old /10 score across every indicator style.
       For 'text' style the indicator already spells out the category, so the
       letter would be redundant — indicator alone suffices. For 'none' the
       letter IS the indicator. For 'emoji'/'both' we show indicator + letter
       (emoji first, then grade), which keeps the visual signal plus a
       compact, consistent grade glyph. */
    const grade = categoryToGrade(result.category);

    let scorePart: string;
    if (style === 'text') {
        scorePart = indicator;
    } else if (style === 'none') {
        scorePart = grade;
    } else {
        scorePart = `${indicator} ${grade}`;
    }

    const parts: string[] = [scorePart];

    if (detail === 'minimal') { return parts[0]; }

    if (detail === 'full' && result.archiveSizeBytes !== null) {
        parts.push(formatSizeMB(result.archiveSizeBytes));
    }

    parts.push(formatUpdateSegment(result));

    const alert = formatAlertSegment(result);
    if (alert) { parts.push(alert); }

    if (result.isUnused) {
        parts.push(`${getIndicator('unused')} Unused`);
    }

    // Show replacement complexity for abandoned/end-of-life packages when migration is feasible
    if (detail === 'full' && result.replacementComplexity) {
        const rc = result.replacementComplexity;
        const isUnhealthy = result.category === 'abandoned' || result.category === 'end-of-life';
        const isFeasible = rc.level !== 'large' && rc.level !== 'native';
        if (isUnhealthy && isFeasible) {
            parts.push(`${rc.metrics.libCodeLines.toLocaleString('en-US')} LOC — ${rc.level} to replace`);
        }
    }

    return parts.join(' · ');
}
