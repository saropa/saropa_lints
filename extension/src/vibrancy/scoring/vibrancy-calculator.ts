import { GitHubMetrics } from '../types';
import { isTrustedPublisher } from './trusted-publishers';

export { TRUSTED_PUBLISHERS, isTrustedPublisher } from './trusted-publishers';

/**
 * Default scoring weights for the vibrancy formula:
 *   V_score = (W_R * Resolution) + (W_E * Engagement) + (W_P * Popularity)
 *           + publisherBonus − penalty
 *
 * Resolution and Engagement are heavily weighted because active maintainer
 * response matters more than historical star counts. These can be overridden
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

/** Engagement Level: comment volume + recency. */
export function calcEngagementLevel(
    metrics: GitHubMetrics,
    daysSinceLastPublish?: number,
): number {
    const commentScore = normalize(metrics.avgCommentsPerIssue, 10);
    const gitRecency = clamp(100 - metrics.daysSinceLastUpdate);
    const pubRecency = daysSinceLastPublish !== undefined
        ? calcPublishRecency(daysSinceLastPublish)
        : 0;
    const recencyScore = Math.max(gitRecency, pubRecency);
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
