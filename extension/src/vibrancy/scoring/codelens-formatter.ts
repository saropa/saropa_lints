import { VibrancyCategory, VibrancyResult } from '../types';
import { isReplacementPackageName, getReplacementDisplayText } from './known-issues';
import { categoryLabel } from './status-classifier';
import { formatSizeMB } from './bloat-calculator';
import {
    getCategoryIndicator, getIndicator, loadIndicatorStyle,
} from '../services/indicator-config';

export type CodeLensDetail = 'minimal' | 'standard' | 'full';

/** @deprecated Use getCategoryIndicator() for customizable indicators. */
export function categoryEmoji(category: VibrancyCategory): string {
    switch (category) {
        case 'vibrant': return '🟢';
        case 'quiet': return '🟡';
        case 'legacy-locked': return '🟠';
        case 'end-of-life': return '🔴';
    }
}

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
    const displayScore = Math.round(result.score / 10);

    let scorePart: string;
    if (style === 'none') {
        scorePart = `${displayScore}/10`;
    } else if (style === 'text') {
        scorePart = `${displayScore}/10 ${indicator}`;
    } else if (style === 'both') {
        scorePart = `${indicator} ${displayScore}/10`;
    } else {
        const label = categoryLabel(result.category);
        scorePart = `${indicator} ${displayScore}/10 ${label}`;
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

    return parts.join(' · ');
}
