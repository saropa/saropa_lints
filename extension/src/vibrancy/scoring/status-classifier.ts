import { VibrancyCategory, KnownIssue, PubDevPackageInfo, VibrancyResult } from '../types';
import { isTrustedPublisher } from './trusted-publishers';

// Re-export display helpers from the centralized dictionary so existing
// import paths (`from './status-classifier'`) continue to work.
export {
    categoryLabel, categoryIcon, categoryToSeverity, categoryToGrade,
    type VibrancyGrade,
} from '../category-dictionary';

/** Count results by vibrancy category. */
export function countByCategory(results: readonly VibrancyResult[]) {
    let vibrant = 0, stable = 0, outdated = 0, abandoned = 0, eol = 0;
    for (const r of results) {
        switch (r.category) {
            case 'vibrant': vibrant++; break;
            case 'stable': stable++; break;
            case 'outdated': outdated++; break;
            case 'abandoned': abandoned++; break;
            case 'end-of-life': eol++; break;
        }
    }
    return { vibrant, stable, outdated, abandoned, eol };
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

    let category: VibrancyCategory;
    if (params.score >= 70) { category = 'vibrant'; }
    else if (params.score >= 40) { category = 'stable'; }
    // Raised from 10 to 20: packages scoring 10-19 are now 'abandoned' instead of
    // 'outdated', so 4+ year untouched packages with only bonus points can't escape.
    else if (params.score >= 20) { category = 'outdated'; }
    else { category = 'abandoned'; }

    // Pub points floor: packages with strong pub.dev quality (>= 140/160) cannot be
    // classified as 'abandoned'. A stable, mature package with high pub points is
    // 'outdated' at worst — not abandoned. Hard EOL signals (known_issues,
    // discontinued, archived) already returned early above and are unaffected.
    if (category === 'abandoned' && (params.pubDev?.pubPoints ?? 0) >= 140) {
        category = 'outdated';
    }

    // SDK-adjacent packages often score in the "stable" band because the formula
    // weights GitHub churn; trusted publishers are not "low activity" risks.
    if (category === 'stable' && isTrustedPublisher(params.pubDev?.publisher)) {
        return 'vibrant';
    }
    return category;
}

