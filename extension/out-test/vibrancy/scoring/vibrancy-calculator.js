"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.MAJOR_PUBLISHERS = exports.RESOLUTION_PUBLISH_RECENCY_CAP = exports.DEFAULT_WEIGHT_POPULARITY = exports.DEFAULT_WEIGHT_ENGAGEMENT = exports.DEFAULT_WEIGHT_RESOLUTION = void 0;
exports.calcResolutionVelocity = calcResolutionVelocity;
exports.effectiveResolutionVelocity = effectiveResolutionVelocity;
exports.calcPublishRecency = calcPublishRecency;
exports.calcEngagementLevel = calcEngagementLevel;
exports.calcPopularity = calcPopularity;
exports.calcPublisherTrust = calcPublisherTrust;
exports.calcFlaggedIssuePenalty = calcFlaggedIssuePenalty;
exports.computeVibrancyScore = computeVibrancyScore;
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
exports.DEFAULT_WEIGHT_RESOLUTION = 0.5;
/** Weight for Engagement Level (comment volume + discussion recency). */
exports.DEFAULT_WEIGHT_ENGAGEMENT = 0.4;
/** Weight for Popularity (pub.dev points + GitHub stars). */
exports.DEFAULT_WEIGHT_POPULARITY = 0.1;
function clamp(value) {
    return Math.min(100, Math.max(0, value));
}
function normalize(value, max) {
    if (max <= 0) {
        return 0;
    }
    return clamp((value / max) * 100);
}
/** Resolution Velocity: closed issues + merged PRs in 90 days. */
function calcResolutionVelocity(metrics) {
    const closureRate = metrics.closedIssuesLast90d + metrics.mergedPrsLast90d;
    const recencyBonus = clamp(100 - metrics.daysSinceLastClose);
    return clamp((normalize(closureRate, 50) + recencyBonus) / 2);
}
/**
 * When GitHub resolution is 0, we use publish recency as the resolution signal.
 * We use the same 0–100 scale as GitHub-based resolution so recency and
 * issue/PR vibrancy are treated equally (each can contribute up to 50% of the score).
 */
exports.RESOLUTION_PUBLISH_RECENCY_CAP = 100;
/**
 * Effective resolution velocity: GitHub-based resolution, or when that is 0,
 * publish recency on the same 0–100 scale. Release-active but issue-quiet
 * packages (e.g. uuid) then get a resolution score commensurate with recency.
 */
function effectiveResolutionVelocity(github, daysSinceLastPublish) {
    const fromGitHub = github ? calcResolutionVelocity(github) : 0;
    if (fromGitHub > 0) {
        return fromGitHub;
    }
    if (daysSinceLastPublish === undefined || daysSinceLastPublish >= 365) {
        return 0;
    }
    const fromPublish = calcPublishRecency(daysSinceLastPublish);
    return Math.min(exports.RESOLUTION_PUBLISH_RECENCY_CAP, fromPublish);
}
/** Publish recency on a 365-day window (vs GitHub's 100-day window). */
function calcPublishRecency(daysSinceLastPublish) {
    return clamp(100 - (daysSinceLastPublish * 100 / 365));
}
/** Engagement Level: comment volume + recency. */
function calcEngagementLevel(metrics, daysSinceLastPublish) {
    const commentScore = normalize(metrics.avgCommentsPerIssue, 10);
    const gitRecency = clamp(100 - metrics.daysSinceLastUpdate);
    const pubRecency = daysSinceLastPublish !== undefined
        ? calcPublishRecency(daysSinceLastPublish)
        : 0;
    const recencyScore = Math.max(gitRecency, pubRecency);
    return clamp((commentScore + recencyScore) / 2);
}
/** Popularity: pub.dev points + GitHub stars. */
function calcPopularity(pubPoints, stars) {
    const pointsNorm = normalize(pubPoints, 150);
    const starsNorm = normalize(stars, 5000);
    return clamp((pointsNorm + starsNorm) / 2);
}
/** Major trusted publishers (Dart/Google ecosystem). */
exports.MAJOR_PUBLISHERS = new Set([
    'dart.dev', 'google.dev', 'flutter.dev',
]);
/** Publisher trust bonus/penalty (−maxBonus/3 to +maxBonus). */
function calcPublisherTrust(publisher, maxBonus = 15) {
    if (maxBonus <= 0) {
        return 0;
    }
    if (!publisher) {
        return -Math.round(maxBonus / 3);
    }
    if (exports.MAJOR_PUBLISHERS.has(publisher)) {
        return maxBonus;
    }
    return Math.round(maxBonus / 3);
}
/** Penalty for flagged high-signal open issues (0–15 points). */
function calcFlaggedIssuePenalty(flaggedCount) {
    if (flaggedCount <= 0) {
        return 0;
    }
    return Math.min(15, 5 + (flaggedCount - 1) * 2);
}
/** Compute overall vibrancy score (0-100). */
function computeVibrancyScore(params, weights, penalty, bonus) {
    const wR = weights?.resolutionVelocity ?? exports.DEFAULT_WEIGHT_RESOLUTION;
    const wE = weights?.engagementLevel ?? exports.DEFAULT_WEIGHT_ENGAGEMENT;
    const wP = weights?.popularity ?? exports.DEFAULT_WEIGHT_POPULARITY;
    const raw = (wR * params.resolutionVelocity)
        + (wE * params.engagementLevel)
        + (wP * params.popularity)
        + (bonus ?? 0)
        - (penalty ?? 0);
    return Math.round(clamp(raw) * 10) / 10;
}
//# sourceMappingURL=vibrancy-calculator.js.map