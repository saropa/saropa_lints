/**
 * Module overview (comment coverage pass).
 * comment-coverage: module overview (batch).
 *
 * Vibrancy UI experiment: scoring, providers, and webview assets.
 */

import { VibrancyCategory, KnownIssue, PubDevPackageInfo, VibrancyResult } from '../types';
import { isTrustedPublisher } from './trusted-publishers';

// Re-export display helpers from the centralized dictionary so existing
// import paths (`from './status-classifier'`) continue to work.
export {
    categoryLabel, categoryIcon, categoryToSeverity, categoryToGrade,
    scoreToGrade, type VibrancyGrade,
} from '../category-dictionary';

/**
 * True when a package has a concrete, actionable update available.
 *
 * "Actionable" means a known newer version exists — patch, minor, or major.
 * `'unknown'` is excluded on purpose: it means the update status could not be
 * determined (offline, no pub.dev data), which is NOT the same as "an update
 * is waiting". This is the single source of truth for the update total shown
 * in the status bar and the package-tree badge — the two had drifted (the
 * status bar omitted the `'unknown'` exclusion and over-reported the count).
 */
export function isUpdatable(result: VibrancyResult): boolean {
    const status = result.updateInfo?.updateStatus;
    return status !== undefined && status !== 'up-to-date' && status !== 'unknown';
}

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
    /** Days since last code commit (GitHub pushed_at). */
    daysSinceLastCommit?: number;
    /** Days since last package publish. */
    daysSinceLastPublish?: number;
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

    // Dormancy cap: recent release and/or recent commits can mask inactivity
    // in pure score terms. If neither code nor releases moved for >=90 days,
    // a package cannot be "vibrant". If both are stale for >=180 days, it
    // cannot be better than "outdated".
    const commitDormant90 = (params.daysSinceLastCommit ?? -1) >= 90;
    const publishDormant90 = (params.daysSinceLastPublish ?? -1) >= 90;
    if (commitDormant90 && publishDormant90 && category === 'vibrant') {
        category = 'stable';
    }
    const commitDormant180 = (params.daysSinceLastCommit ?? -1) >= 180;
    const publishDormant180 = (params.daysSinceLastPublish ?? -1) >= 180;
    if (commitDormant180 && publishDormant180 && category === 'stable') {
        category = 'outdated';
    }

    // SDK-adjacent packages often score in the "stable"/"outdated" bands because the
    // formula weights GitHub churn and the dormancy caps above penalize the long
    // release gaps typical of finished, first-party packages (e.g. path_provider,
    // which publishes rarely precisely because it is complete). Trusted publishers
    // are not "low activity" risks, so lift one band each. Promote exactly once
    // (not a cascade outdated -> stable -> vibrant) so a genuinely low-scoring
    // first-party package still reads as 'stable', not 'vibrant'. 'abandoned' and
    // the hard EOL signals handled at the top are intentionally left untouched.
    if (isTrustedPublisher(params.pubDev?.publisher)) {
        if (category === 'stable') { return 'vibrant'; }
        if (category === 'outdated') { return 'stable'; }
    }
    return category;
}

