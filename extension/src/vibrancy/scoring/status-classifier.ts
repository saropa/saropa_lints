import { VibrancyCategory, KnownIssue, PubDevPackageInfo, VibrancyResult } from '../types';

/** Count results by vibrancy category. */
export function countByCategory(results: readonly VibrancyResult[]) {
    let vibrant = 0, quiet = 0, legacy = 0, stale = 0, eol = 0;
    for (const r of results) {
        switch (r.category) {
            case 'vibrant': vibrant++; break;
            case 'quiet': quiet++; break;
            case 'legacy-locked': legacy++; break;
            case 'stale': stale++; break;
            case 'end-of-life': eol++; break;
        }
    }
    return { vibrant, quiet, legacy, stale, eol };
}

/** Classify a package into a vibrancy category. */
export function classifyStatus(params: {
    score: number;
    knownIssue: KnownIssue | null;
    pubDev: PubDevPackageInfo | null;
    /** Archived GitHub repos are definitively end-of-life. */
    isArchived?: boolean;
}): VibrancyCategory {
    // Hard overrides: only truly dead packages get 'end-of-life'
    if (params.knownIssue?.status === 'end_of_life') { return 'end-of-life'; }
    if (params.pubDev?.isDiscontinued) { return 'end-of-life'; }
    if (params.isArchived === true) { return 'end-of-life'; }

    if (params.score >= 70) { return 'vibrant'; }
    if (params.score >= 40) { return 'quiet'; }
    if (params.score >= 10) { return 'legacy-locked'; }
    // Score < 10 with no EOL signals = stale, not dead
    return 'stale';
}

/** Map category to ThemeIcon id. */
export function categoryIcon(category: VibrancyCategory): string {
    switch (category) {
        case 'vibrant': return 'pass';
        case 'quiet': return 'info';
        case 'legacy-locked': return 'warning';
        case 'stale': return 'warning';
        case 'end-of-life': return 'error';
    }
}

/** Map category to DiagnosticSeverity value. */
export function categoryToSeverity(category: VibrancyCategory): number {
    switch (category) {
        case 'end-of-life': return 1;
        case 'stale': return 2;
        case 'legacy-locked': return 2;
        case 'quiet': return 3;
        case 'vibrant': return 3;
    }
}

/** Human-readable label for a category. */
export function categoryLabel(category: VibrancyCategory): string {
    switch (category) {
        case 'vibrant': return 'Vibrant';
        case 'quiet': return 'Quiet';
        case 'legacy-locked': return 'Legacy-Locked';
        case 'stale': return 'Stale';
        case 'end-of-life': return 'End of Life';
    }
}
