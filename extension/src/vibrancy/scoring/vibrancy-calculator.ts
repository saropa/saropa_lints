/**
 * Module overview (comment coverage pass).
 * comment-coverage: module overview (batch).
 *
 * Vibrancy UI experiment: scoring, providers, and webview assets.
 */

import { GitHubMetrics, MaintainerQualityFlags } from '../types';
import { isTrustedPublisher } from './trusted-publishers';

export { TRUSTED_PUBLISHERS, isTrustedPublisher } from './trusted-publishers';

/**
 * Default scoring weights for the vibrancy formula:
 *   V_score = (W_R * Resolution) + (W_E * Engagement) + (W_P * Popularity)
 *           + publisherBonus + pubQualityBonus + adoptionBonus − penalty
 *
 * Resolution and Engagement are heavily weighted because active maintainer
 * response matters more than historical star counts. The pubQualityBonus
 * (0–10) ensures packages with high pub.dev points aren't penalized to
 * near-zero just because GitHub activity is low. These can be overridden
 * via VS Code settings (saropaLints.packageVibrancy.weights.*).
 */

/** Weight for Resolution Velocity (closed issues + merged PRs). */
export const DEFAULT_WEIGHT_RESOLUTION = 0.5;

/** Weight for Engagement Level (comment volume + discussion recency). */
export const DEFAULT_WEIGHT_ENGAGEMENT = 0.4;

/** Weight for Popularity (pub.dev points + GitHub stars). */
export const DEFAULT_WEIGHT_POPULARITY = 0.1;

/** User-configurable scoring weights. Must sum to ~1.0 for meaningful scores. */
export interface ScoringWeights {
    readonly resolutionVelocity: number;
    readonly engagementLevel: number;
    readonly popularity: number;
}

function clamp(value: number): number {
    return Math.min(100, Math.max(0, value));
}

function normalize(value: number, max: number): number {
    if (max <= 0) { return 0; }
    return clamp((value / max) * 100);
}

/** Resolution Velocity: closed issues + merged PRs in 90 days. */
export function calcResolutionVelocity(metrics: GitHubMetrics): number {
    const closureRate = metrics.closedIssuesLast90d + metrics.mergedPrsLast90d;
    const recencyBonus = clamp(100 - metrics.daysSinceLastClose);
    return clamp((normalize(closureRate, 50) + recencyBonus) / 2);
}

/**
 * When GitHub resolution is 0, we use publish recency as the resolution signal.
 * We use the same 0–100 scale as GitHub-based resolution so recency and
 * issue/PR vibrancy are treated equally (each can contribute up to 50% of the score).
 */
export const RESOLUTION_PUBLISH_RECENCY_CAP = 100;

/**
 * Effective resolution velocity: GitHub-based resolution, or when that is 0,
 * publish recency on the same 0–100 scale. Release-active but issue-quiet
 * packages (e.g. uuid) then get a resolution score commensurate with recency.
 */
export function effectiveResolutionVelocity(
    github: GitHubMetrics | null,
    daysSinceLastPublish: number | undefined,
): number {
    const fromGitHub = github ? calcResolutionVelocity(github) : 0;
    if (fromGitHub > 0) { return fromGitHub; }
    if (daysSinceLastPublish === undefined || daysSinceLastPublish >= 365) {
        return 0;
    }
    const fromPublish = calcPublishRecency(daysSinceLastPublish);
    return Math.min(RESOLUTION_PUBLISH_RECENCY_CAP, fromPublish);
}

/** Publish recency on a 365-day window (vs GitHub's 100-day window). */
export function calcPublishRecency(daysSinceLastPublish: number): number {
    return clamp(100 - (daysSinceLastPublish * 100 / 365));
}

/** Commit recency on a 90-day window (older than ~3 months is stale). */
export function calcCommitRecency(daysSinceLastCommit: number): number {
    return clamp(100 - (daysSinceLastCommit * 100 / 90));
}

/** Engagement Level: comment volume + recency. */
export function calcEngagementLevel(
    metrics: GitHubMetrics,
    daysSinceLastPublish?: number,
    daysSinceLastCommit?: number,
): number {
    const commentScore = normalize(metrics.avgCommentsPerIssue, 10);
    const gitRecency = clamp(100 - metrics.daysSinceLastUpdate);
    const pubRecency = daysSinceLastPublish !== undefined
        ? calcPublishRecency(daysSinceLastPublish)
        : 0;
    // "updated_at" includes issue/comment activity; commit recency is the
    // stronger "is code still moving?" signal. Clamp git recency by commit
    // recency when commit data is available, then allow recent releases to
    // lift recency for package-first workflows.
    const commitRecency = daysSinceLastCommit !== undefined
        ? calcCommitRecency(daysSinceLastCommit)
        : gitRecency;
    const codeActivityRecency = Math.min(gitRecency, commitRecency);
    const recencyScore = Math.max(codeActivityRecency, pubRecency);
    return clamp((commentScore + recencyScore) / 2);
}

/** Popularity: pub.dev points + GitHub stars. */
export function calcPopularity(pubPoints: number, stars: number): number {
    // pub.dev maximum is 160, not 150
    const pointsNorm = normalize(pubPoints, 160);
    const starsNorm = normalize(stars, 5000);
    return clamp((pointsNorm + starsNorm) / 2);
}

/**
 * Publisher trust bonus/penalty (−maxBonus/3 to +maxBonus).
 * Full bonus when `publisher` is in `TRUSTED_PUBLISHERS` (`trusted-publishers.ts`).
 */
export function calcPublisherTrust(
    publisher: string | null,
    maxBonus: number = 15,
): number {
    if (maxBonus <= 0) { return 0; }
    if (!publisher) { return -Math.round(maxBonus / 3); }
    if (isTrustedPublisher(publisher)) { return maxBonus; }
    return Math.round(maxBonus / 3);
}

/** Maximum pub.dev quality bonus added to the vibrancy score. */
export const DEFAULT_MAX_PUB_QUALITY_BONUS = 10;

/**
 * Bonus for high pub.dev quality (0–maxBonus).
 * Scales linearly with pub.dev points (0–160). Packages that pass pub.dev's
 * quality checks deserve a score floor even when GitHub activity is low —
 * a "finished" package with 160/160 points isn't a 0.1/100 risk.
 */
export function calcPubQualityBonus(
    pubPoints: number,
    maxBonus: number = DEFAULT_MAX_PUB_QUALITY_BONUS,
): number {
    if (maxBonus <= 0 || pubPoints <= 0) { return 0; }
    return Math.min(maxBonus, (pubPoints / 160) * maxBonus);
}

/** Maximum adoption bonus added to the vibrancy score. */
export const DEFAULT_MAX_ADOPTION_BONUS = 10;

/**
 * Bonus for ecosystem adoption measured by reverse dependency count (0–maxBonus).
 * This is bonus-only: packages with 0 dependents get 0 bonus (no penalty).
 *
 * Uses a logarithmic curve because reverse dependency counts are extremely
 * skewed on pub.dev:
 *   - Most packages: 0–10 dependents
 *   - Moderately popular: 50–200
 *   - Very popular (provider, http): 500–2000+
 *
 * The log curve spreads the meaningful range across the bonus:
 *   -    1 dep  →  1.0 bonus  (minimal signal)
 *   -   10 deps →  3.5 bonus  (some adoption)
 *   -   50 deps →  5.7 bonus  (solid adoption)
 *   -  200 deps →  7.7 bonus  (strong adoption)
 *   - 1000 deps → 10.0 bonus  (saturated — max)
 */
export function calcAdoptionBonus(
    reverseDependencyCount: number | null,
    maxBonus: number = DEFAULT_MAX_ADOPTION_BONUS,
): number {
    // Null = fetch failed or not yet fetched → no bonus, no penalty
    if (reverseDependencyCount === null || reverseDependencyCount <= 0) {
        return 0;
    }
    if (maxBonus <= 0) { return 0; }
    // log10(count + 1) / log10(1001) maps 1→~0, 1000→1.0
    const normalized = Math.log10(reverseDependencyCount + 1) / Math.log10(1001);
    return Math.min(maxBonus, normalized * maxBonus);
}

/** Maximum maintainer-quality bonus added to the vibrancy score. */
export const DEFAULT_MAX_MAINTAINER_QUALITY_BONUS = 10;

/**
 * Bonus for shipping maintainer-quality folders: runnable demo (`example/`),
 * regression suite (`test/`), maintainer automation (`tool/`), extended docs
 * (`doc/`). Each present flag earns an equal share of `maxBonus`, so a
 * fully-equipped package (all four) earns the full bonus.
 *
 * Why this is a bonus rather than a penalty: a package that ships these
 * folders is healthier than one that doesn't. The earlier model counted
 * their bytes against the package via tarball-size-as-bloat — exactly the
 * wrong direction on all four signals. Each is now an independent positive
 * component, surfaced in the hover so developers can see why the score
 * moved.
 *
 * Equal-weight rationale: the absence of any one of these is a real signal
 * (a package with no tests is less trustworthy than one with tests), so we
 * don't want any single flag to dominate. If empirical calibration shows
 * one signal matters disproportionately (likely `hasTests`), the function
 * can be re-weighted without changing call sites.
 *
 * Returns 0 when `flags` is null — the analyzer couldn't read the tarball
 * so we can't confirm or deny these signals. Treat absence-of-data as
 * neutral, NOT as a penalty.
 */
export function calcMaintainerQualityBonus(
    flags: MaintainerQualityFlags | null,
    maxBonus: number = DEFAULT_MAX_MAINTAINER_QUALITY_BONUS,
): number {
    if (!flags || maxBonus <= 0) { return 0; }
    const present = [flags.hasExample, flags.hasTests, flags.hasTools, flags.hasDocs]
        .filter(Boolean).length;
    if (present === 0) { return 0; }
    return Math.min(maxBonus, (present / 4) * maxBonus);
}

/** Penalty for flagged high-signal open issues (0–15 points). */
export function calcFlaggedIssuePenalty(flaggedCount: number): number {
    if (flaggedCount <= 0) { return 0; }
    return Math.min(15, 5 + (flaggedCount - 1) * 2);
}

/** Compute overall vibrancy score (0-100). */
export function computeVibrancyScore(
    params: {
        resolutionVelocity: number;
        engagementLevel: number;
        popularity: number;
    },
    weights?: ScoringWeights,
    penalty?: number,
    bonus?: number,
): number {
    const wR = weights?.resolutionVelocity ?? DEFAULT_WEIGHT_RESOLUTION;
    const wE = weights?.engagementLevel ?? DEFAULT_WEIGHT_ENGAGEMENT;
    const wP = weights?.popularity ?? DEFAULT_WEIGHT_POPULARITY;

    const raw = (wR * params.resolutionVelocity)
        + (wE * params.engagementLevel)
        + (wP * params.popularity)
        + (bonus ?? 0)
        - (penalty ?? 0);
    return Math.round(clamp(raw) * 10) / 10;
}
