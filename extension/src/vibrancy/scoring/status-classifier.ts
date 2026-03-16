import { VibrancyCategory, KnownIssue, PubDevPackageInfo, VibrancyResult } from '../types';

/** Count results by vibrancy category. */
export function countByCategory(results: readonly VibrancyResult[]) {
    let vibrant = 0, quiet = 0, legacy = 0, eol = 0;
    for (const r of results) {
        switch (r.category) {
            case 'vibrant': vibrant++; break;
            case 'quiet': quiet++; break;
            case 'legacy-locked': legacy++; break;
            case 'end-of-life': eol++; break;
        }
    }
    return { vibrant, quiet, legacy, eol };
}

/** Classify a package into a vibrancy category. */
export function classifyStatus(params: {
    score: number;
    knownIssue: KnownIssue | null;
    pubDev: PubDevPackageInfo | null;
}): VibrancyCategory {
    if (params.knownIssue?.status === 'end_of_life') { return 'end-of-life'; }
    if (params.pubDev?.isDiscontinued) { return 'end-of-life'; }

    if (params.score >= 70) { return 'vibrant'; }
    if (params.score >= 40) { return 'quiet'; }
    if (params.score >= 10) { return 'legacy-locked'; }
    return 'end-of-life';
}

/** Map category to ThemeIcon id. */
export function categoryIcon(category: VibrancyCategory): string {
    switch (category) {
        case 'vibrant': return 'pass';
        case 'quiet': return 'info';
        case 'legacy-locked': return 'warning';
        case 'end-of-life': return 'error';
    }
}

/** Map category to DiagnosticSeverity value. */
export function categoryToSeverity(category: VibrancyCategory): number {
    switch (category) {
        case 'end-of-life': return 1;
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
        case 'end-of-life': return 'End of Life';
    }
}
