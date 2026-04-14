import * as assert from 'assert';
import {
    calcResolutionVelocity,
    effectiveResolutionVelocity,
    calcEngagementLevel,
    calcPopularity,
    calcPublishRecency,
    calcFlaggedIssuePenalty,
    calcPublisherTrust,
    calcPubQualityBonus,
    calcAdoptionBonus,
    computeVibrancyScore,
    TRUSTED_PUBLISHERS,
    RESOLUTION_PUBLISH_RECENCY_CAP,
} from '../../../vibrancy/scoring/vibrancy-calculator';
import { GitHubMetrics } from '../../../vibrancy/types';

function makeMetrics(overrides: Partial<GitHubMetrics> = {}): GitHubMetrics {
    return {
        stars: 100,
        openIssues: 10,
        closedIssuesLast90d: 5,
        mergedPrsLast90d: 3,
        avgCommentsPerIssue: 2,
        daysSinceLastUpdate: 10,
        daysSinceLastClose: 5,
        flaggedIssues: [],
        license: null,
        ...overrides,
    };
}

describe('vibrancy-calculator', () => {
    describe('calcResolutionVelocity', () => {
        it('should return high score for active repos', () => {
            const score = calcResolutionVelocity(makeMetrics({
                closedIssuesLast90d: 30,
                mergedPrsLast90d: 20,
                daysSinceLastClose: 1,
            }));
            assert.ok(score > 70);
        });

        it('should return low score for inactive repos', () => {
            const score = calcResolutionVelocity(makeMetrics({
                closedIssuesLast90d: 0,
                mergedPrsLast90d: 0,
                daysSinceLastClose: 999,
            }));
            assert.ok(score < 10);
        });

        it('should stay within 0-100', () => {
            const high = calcResolutionVelocity(makeMetrics({
                closedIssuesLast90d: 1000,
                mergedPrsLast90d: 1000,
                daysSinceLastClose: 0,
            }));
            assert.ok(high >= 0 && high <= 100);
        });
    });

    describe('effectiveResolutionVelocity', () => {
        it('should use GitHub resolution when > 0', () => {
            const rv = effectiveResolutionVelocity(makeMetrics({
                closedIssuesLast90d: 10,
                mergedPrsLast90d: 5,
                daysSinceLastClose: 7,
            }), 20);
            assert.ok(rv > 20, 'should use GitHub-derived resolution');
        });

        it('should use publish recency when GitHub resolution is 0 and publish recent', () => {
            const inactive = makeMetrics({
                closedIssuesLast90d: 0,
                mergedPrsLast90d: 0,
                daysSinceLastClose: 999,
            });
            const rv = effectiveResolutionVelocity(inactive, 20);
            assert.ok(rv >= 90 && rv <= RESOLUTION_PUBLISH_RECENCY_CAP,
                `recent publish should supply full resolution scale: got ${rv}`);
        });

        it('should return 0 when no GitHub and no recent publish', () => {
            assert.strictEqual(effectiveResolutionVelocity(null, undefined), 0);
            assert.strictEqual(effectiveResolutionVelocity(null, 400), 0);
        });

        it('should allow publish-based resolution up to 100 (same scale as GitHub)', () => {
            const rv = effectiveResolutionVelocity(null, 1);
            assert.ok(rv >= 99 && rv <= 100, 'just-published should get ~100 resolution');
        });
    });

    describe('calcEngagementLevel', () => {
        it('should reward high comment volume and recency', () => {
            const score = calcEngagementLevel(makeMetrics({
                avgCommentsPerIssue: 8,
                daysSinceLastUpdate: 2,
            }));
            assert.ok(score > 60);
        });

        it('should penalize stale repos', () => {
            const score = calcEngagementLevel(makeMetrics({
                avgCommentsPerIssue: 0,
                daysSinceLastUpdate: 500,
            }));
            assert.ok(score < 10);
        });

        it('should boost stale repos with recent publish date', () => {
            const without = calcEngagementLevel(makeMetrics({
                avgCommentsPerIssue: 1,
                daysSinceLastUpdate: 300,
            }));
            const with180d = calcEngagementLevel(makeMetrics({
                avgCommentsPerIssue: 1,
                daysSinceLastUpdate: 300,
            }), 180);
            assert.ok(with180d > without,
                `publish recency should boost: ${with180d} > ${without}`);
        });

        it('should not boost when publish date is older than 365 days', () => {
            const without = calcEngagementLevel(makeMetrics({
                avgCommentsPerIssue: 0,
                daysSinceLastUpdate: 500,
            }));
            const withOld = calcEngagementLevel(makeMetrics({
                avgCommentsPerIssue: 0,
                daysSinceLastUpdate: 500,
            }), 400);
            assert.strictEqual(withOld, without);
        });

        it('should not change score when publish date is absent', () => {
            const metrics = makeMetrics({ daysSinceLastUpdate: 200 });
            const withUndef = calcEngagementLevel(metrics, undefined);
            const without = calcEngagementLevel(metrics);
            assert.strictEqual(withUndef, without);
        });
    });

    describe('calcPublishRecency', () => {
        it('should return 100 for just-published packages', () => {
            assert.strictEqual(calcPublishRecency(0), 100);
        });

        it('should return ~50 for 6-month-old packages', () => {
            const score = calcPublishRecency(180);
            assert.ok(score > 45 && score < 55, `expected ~50, got ${score}`);
        });

        it('should return 0 for packages older than 365 days', () => {
            assert.strictEqual(calcPublishRecency(365), 0);
            assert.strictEqual(calcPublishRecency(500), 0);
        });
    });

    describe('calcPopularity', () => {
        it('should combine pub points and stars', () => {
            const score = calcPopularity(140, 3000);
            assert.ok(score > 50);
        });

        it('should return 0 for zero inputs', () => {
            assert.strictEqual(calcPopularity(0, 0), 0);
        });

        it('should normalize pub points against 160 max (pub.dev maximum)', () => {
            // 160/160 points = 100, 0 stars = 0, average = 50
            const score = calcPopularity(160, 0);
            assert.strictEqual(score, 50);
        });
    });

    describe('computeVibrancyScore', () => {
        it('should compute weighted average with defaults', () => {
            const score = computeVibrancyScore({
                resolutionVelocity: 80,
                engagementLevel: 60,
                popularity: 50,
            });
            // 0.5*80 + 0.4*60 + 0.1*50 = 40 + 24 + 5 = 69
            assert.strictEqual(score, 69);
        });

        it('should clamp to 0-100', () => {
            const score = computeVibrancyScore({
                resolutionVelocity: 100,
                engagementLevel: 100,
                popularity: 100,
            });
            assert.ok(score <= 100);
        });

        it('should apply custom weights', () => {
            const score = computeVibrancyScore(
                { resolutionVelocity: 100, engagementLevel: 0, popularity: 0 },
                { resolutionVelocity: 1.0, engagementLevel: 0, popularity: 0 },
            );
            assert.strictEqual(score, 100);
        });

        it('should allow popularity-heavy weights', () => {
            const score = computeVibrancyScore(
                { resolutionVelocity: 0, engagementLevel: 0, popularity: 80 },
                { resolutionVelocity: 0, engagementLevel: 0, popularity: 1.0 },
            );
            assert.strictEqual(score, 80);
        });

        it('should produce different scores with different weights', () => {
            const params = {
                resolutionVelocity: 90,
                engagementLevel: 30,
                popularity: 10,
            };
            const defaultScore = computeVibrancyScore(params);
            const evenScore = computeVibrancyScore(params, {
                resolutionVelocity: 0.33,
                engagementLevel: 0.34,
                popularity: 0.33,
            });
            assert.notStrictEqual(defaultScore, evenScore);
        });

        it('should return 0 when all inputs are 0', () => {
            const score = computeVibrancyScore(
                { resolutionVelocity: 0, engagementLevel: 0, popularity: 0 },
            );
            assert.strictEqual(score, 0);
        });

        it('should subtract penalty from score', () => {
            const base = computeVibrancyScore({
                resolutionVelocity: 80,
                engagementLevel: 60,
                popularity: 50,
            });
            const penalized = computeVibrancyScore({
                resolutionVelocity: 80,
                engagementLevel: 60,
                popularity: 50,
            }, undefined, 10);
            assert.strictEqual(penalized, base - 10);
        });

        it('should clamp penalty result to 0', () => {
            const score = computeVibrancyScore({
                resolutionVelocity: 5,
                engagementLevel: 5,
                popularity: 5,
            }, undefined, 50);
            assert.strictEqual(score, 0);
        });
    });

    describe('calcPublisherTrust', () => {
        it('should return max bonus for trusted publishers', () => {
            for (const pub of TRUSTED_PUBLISHERS) {
                assert.strictEqual(calcPublisherTrust(pub), 15);
            }
        });

        it('should return 1/3 bonus for verified publishers', () => {
            assert.strictEqual(calcPublisherTrust('invertase.io'), 5);
        });

        it('should return negative penalty for no publisher', () => {
            assert.strictEqual(calcPublisherTrust(null), -5);
        });

        it('should respect custom maxBonus', () => {
            assert.strictEqual(calcPublisherTrust('dart.dev', 21), 21);
            assert.strictEqual(calcPublisherTrust('other.dev', 21), 7);
            assert.strictEqual(calcPublisherTrust(null, 21), -7);
        });

        it('should return 0 when maxBonus is 0', () => {
            assert.strictEqual(calcPublisherTrust('dart.dev', 0), 0);
            assert.strictEqual(calcPublisherTrust(null, 0), 0);
        });
    });

    describe('computeVibrancyScore with bonus', () => {
        it('should add bonus to score', () => {
            const base = computeVibrancyScore({
                resolutionVelocity: 80,
                engagementLevel: 60,
                popularity: 50,
            });
            const boosted = computeVibrancyScore({
                resolutionVelocity: 80,
                engagementLevel: 60,
                popularity: 50,
            }, undefined, 0, 15);
            assert.strictEqual(boosted, base + 15);
        });

        it('should apply bonus and penalty together', () => {
            const score = computeVibrancyScore({
                resolutionVelocity: 80,
                engagementLevel: 60,
                popularity: 50,
            }, undefined, 10, 15);
            // 69 - 10 + 15 = 74
            assert.strictEqual(score, 74);
        });

        it('should clamp bonus result to 100', () => {
            const score = computeVibrancyScore({
                resolutionVelocity: 100,
                engagementLevel: 100,
                popularity: 100,
            }, undefined, 0, 15);
            assert.strictEqual(score, 100);
        });
    });

    describe('calcFlaggedIssuePenalty', () => {
        it('should return 0 for no flagged issues', () => {
            assert.strictEqual(calcFlaggedIssuePenalty(0), 0);
        });

        it('should return 5 for 1 flagged issue', () => {
            assert.strictEqual(calcFlaggedIssuePenalty(1), 5);
        });

        it('should return 7 for 2 flagged issues', () => {
            assert.strictEqual(calcFlaggedIssuePenalty(2), 7);
        });

        it('should cap at 15 for many flagged issues', () => {
            assert.strictEqual(calcFlaggedIssuePenalty(6), 15);
            assert.strictEqual(calcFlaggedIssuePenalty(20), 15);
        });

        it('should return 0 for negative input', () => {
            assert.strictEqual(calcFlaggedIssuePenalty(-1), 0);
        });
    });

    describe('calcAdoptionBonus', () => {
        it('should return 0 for null (fetch failed)', () => {
            assert.strictEqual(calcAdoptionBonus(null), 0);
        });

        it('should return 0 for zero dependents (no penalty)', () => {
            assert.strictEqual(calcAdoptionBonus(0), 0);
        });

        it('should return 0 for negative count', () => {
            assert.strictEqual(calcAdoptionBonus(-5), 0);
        });

        it('should return ~1.0 for 1 dependent', () => {
            const bonus = calcAdoptionBonus(1);
            // log10(2)/log10(1001) * 10 ≈ 1.003
            assert.ok(bonus > 0.9 && bonus < 1.1, `expected ~1.0, got ${bonus}`);
        });

        it('should return ~3.5 for 10 dependents', () => {
            const bonus = calcAdoptionBonus(10);
            assert.ok(bonus > 3.0 && bonus < 4.0, `expected ~3.5, got ${bonus}`);
        });

        it('should return ~5.7 for 50 dependents', () => {
            const bonus = calcAdoptionBonus(50);
            assert.ok(bonus > 5.2 && bonus < 6.2, `expected ~5.7, got ${bonus}`);
        });

        it('should return ~7.7 for 200 dependents', () => {
            const bonus = calcAdoptionBonus(200);
            assert.ok(bonus > 7.2 && bonus < 8.2, `expected ~7.7, got ${bonus}`);
        });

        it('should return 10.0 (max) for 1000 dependents', () => {
            const bonus = calcAdoptionBonus(1000);
            assert.strictEqual(bonus, 10);
        });

        it('should cap at maxBonus for very high counts', () => {
            const bonus = calcAdoptionBonus(50000);
            assert.strictEqual(bonus, 10);
        });

        it('should respect custom maxBonus', () => {
            const bonus = calcAdoptionBonus(1000, 20);
            assert.strictEqual(bonus, 20);
        });

        it('should return 0 when maxBonus is 0', () => {
            assert.strictEqual(calcAdoptionBonus(500, 0), 0);
        });

        it('should monotonically increase with count', () => {
            const counts = [1, 5, 10, 50, 100, 200, 500, 1000];
            let prev = 0;
            for (const count of counts) {
                const bonus = calcAdoptionBonus(count);
                assert.ok(bonus > prev,
                    `bonus for ${count} (${bonus}) should exceed bonus for previous (${prev})`);
                prev = bonus;
            }
        });

        it('should lift composite score for packages with ecosystem adoption', () => {
            // A package with no GitHub activity but 200 dependents should
            // get a meaningful boost over the same package with 0 dependents
            const params = { resolutionVelocity: 0, engagementLevel: 0, popularity: 50 };
            const publisherTrust = 5;

            const withoutAdoption = computeVibrancyScore(
                params, undefined, 0, publisherTrust,
            );
            const adoptionBonusValue = calcAdoptionBonus(200);
            const withAdoption = computeVibrancyScore(
                params, undefined, 0, publisherTrust + adoptionBonusValue,
            );
            assert.ok(withAdoption > withoutAdoption,
                'adoption bonus should lift score for packages depended on by others');
            // ~7.7 point lift for 200 dependents
            assert.ok(withAdoption - withoutAdoption > 7,
                `expected ~7.7 point lift, got ${withAdoption - withoutAdoption}`);
        });
    });

    describe('calcPubQualityBonus', () => {
        it('should return max bonus for perfect pub.dev score', () => {
            assert.strictEqual(calcPubQualityBonus(160), 10);
        });

        it('should return 0 for zero pub points', () => {
            assert.strictEqual(calcPubQualityBonus(0), 0);
        });

        it('should scale linearly with pub points', () => {
            assert.strictEqual(calcPubQualityBonus(80), 5);
        });

        it('should respect custom maxBonus', () => {
            assert.strictEqual(calcPubQualityBonus(160, 20), 20);
            assert.strictEqual(calcPubQualityBonus(80, 20), 10);
        });

        it('should return 0 when maxBonus is 0', () => {
            assert.strictEqual(calcPubQualityBonus(160, 0), 0);
        });

        it('should return 0 for negative pub points', () => {
            assert.strictEqual(calcPubQualityBonus(-10), 0);
        });

        it('should cap at maxBonus even if pub points exceed 160', () => {
            // Defensive: pub.dev max is 160, but guard against unexpected data
            assert.strictEqual(calcPubQualityBonus(200), 10);
        });

        it('should lift composite score for high-quality packages with no GitHub activity', () => {
            // Before: 160/160 pub points, no GitHub, verified publisher → near-zero
            // After:  pub quality bonus (+10) lifts the score meaningfully
            const params = { resolutionVelocity: 0, engagementLevel: 0, popularity: 50 };
            const publisherTrust = 5; // verified, non-trusted publisher

            // Without pub quality bonus: 0 + 0 + 5 + 5 = 10
            const withoutBonus = computeVibrancyScore(
                params, undefined, 0, publisherTrust,
            );
            assert.strictEqual(withoutBonus, 10);

            // With pub quality bonus: 0 + 0 + 5 + 5 + 10 = 20
            const pubQuality = calcPubQualityBonus(160);
            const withBonus = computeVibrancyScore(
                params, undefined, 0, publisherTrust + pubQuality,
            );
            assert.strictEqual(withBonus, 20);
            assert.ok(withBonus > withoutBonus,
                'pub quality bonus should meaningfully lift scores for well-vetted packages');
        });
    });
});
