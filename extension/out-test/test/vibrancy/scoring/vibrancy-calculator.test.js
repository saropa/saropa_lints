"use strict";
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || (function () {
    var ownKeys = function(o) {
        ownKeys = Object.getOwnPropertyNames || function (o) {
            var ar = [];
            for (var k in o) if (Object.prototype.hasOwnProperty.call(o, k)) ar[ar.length] = k;
            return ar;
        };
        return ownKeys(o);
    };
    return function (mod) {
        if (mod && mod.__esModule) return mod;
        var result = {};
        if (mod != null) for (var k = ownKeys(mod), i = 0; i < k.length; i++) if (k[i] !== "default") __createBinding(result, mod, k[i]);
        __setModuleDefault(result, mod);
        return result;
    };
})();
Object.defineProperty(exports, "__esModule", { value: true });
const assert = __importStar(require("assert"));
const vibrancy_calculator_1 = require("../../../vibrancy/scoring/vibrancy-calculator");
function makeMetrics(overrides = {}) {
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
            const score = (0, vibrancy_calculator_1.calcResolutionVelocity)(makeMetrics({
                closedIssuesLast90d: 30,
                mergedPrsLast90d: 20,
                daysSinceLastClose: 1,
            }));
            assert.ok(score > 70);
        });
        it('should return low score for inactive repos', () => {
            const score = (0, vibrancy_calculator_1.calcResolutionVelocity)(makeMetrics({
                closedIssuesLast90d: 0,
                mergedPrsLast90d: 0,
                daysSinceLastClose: 999,
            }));
            assert.ok(score < 10);
        });
        it('should stay within 0-100', () => {
            const high = (0, vibrancy_calculator_1.calcResolutionVelocity)(makeMetrics({
                closedIssuesLast90d: 1000,
                mergedPrsLast90d: 1000,
                daysSinceLastClose: 0,
            }));
            assert.ok(high >= 0 && high <= 100);
        });
    });
    describe('effectiveResolutionVelocity', () => {
        it('should use GitHub resolution when > 0', () => {
            const rv = (0, vibrancy_calculator_1.effectiveResolutionVelocity)(makeMetrics({
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
            const rv = (0, vibrancy_calculator_1.effectiveResolutionVelocity)(inactive, 20);
            assert.ok(rv >= 90 && rv <= vibrancy_calculator_1.RESOLUTION_PUBLISH_RECENCY_CAP, `recent publish should supply full resolution scale: got ${rv}`);
        });
        it('should return 0 when no GitHub and no recent publish', () => {
            assert.strictEqual((0, vibrancy_calculator_1.effectiveResolutionVelocity)(null, undefined), 0);
            assert.strictEqual((0, vibrancy_calculator_1.effectiveResolutionVelocity)(null, 400), 0);
        });
        it('should allow publish-based resolution up to 100 (same scale as GitHub)', () => {
            const rv = (0, vibrancy_calculator_1.effectiveResolutionVelocity)(null, 1);
            assert.ok(rv >= 99 && rv <= 100, 'just-published should get ~100 resolution');
        });
    });
    describe('calcEngagementLevel', () => {
        it('should reward high comment volume and recency', () => {
            const score = (0, vibrancy_calculator_1.calcEngagementLevel)(makeMetrics({
                avgCommentsPerIssue: 8,
                daysSinceLastUpdate: 2,
            }));
            assert.ok(score > 60);
        });
        it('should penalize stale repos', () => {
            const score = (0, vibrancy_calculator_1.calcEngagementLevel)(makeMetrics({
                avgCommentsPerIssue: 0,
                daysSinceLastUpdate: 500,
            }));
            assert.ok(score < 10);
        });
        it('should boost stale repos with recent publish date', () => {
            const without = (0, vibrancy_calculator_1.calcEngagementLevel)(makeMetrics({
                avgCommentsPerIssue: 1,
                daysSinceLastUpdate: 300,
            }));
            const with180d = (0, vibrancy_calculator_1.calcEngagementLevel)(makeMetrics({
                avgCommentsPerIssue: 1,
                daysSinceLastUpdate: 300,
            }), 180);
            assert.ok(with180d > without, `publish recency should boost: ${with180d} > ${without}`);
        });
        it('should not boost when publish date is older than 365 days', () => {
            const without = (0, vibrancy_calculator_1.calcEngagementLevel)(makeMetrics({
                avgCommentsPerIssue: 0,
                daysSinceLastUpdate: 500,
            }));
            const withOld = (0, vibrancy_calculator_1.calcEngagementLevel)(makeMetrics({
                avgCommentsPerIssue: 0,
                daysSinceLastUpdate: 500,
            }), 400);
            assert.strictEqual(withOld, without);
        });
        it('should not change score when publish date is absent', () => {
            const metrics = makeMetrics({ daysSinceLastUpdate: 200 });
            const withUndef = (0, vibrancy_calculator_1.calcEngagementLevel)(metrics, undefined);
            const without = (0, vibrancy_calculator_1.calcEngagementLevel)(metrics);
            assert.strictEqual(withUndef, without);
        });
    });
    describe('calcPublishRecency', () => {
        it('should return 100 for just-published packages', () => {
            assert.strictEqual((0, vibrancy_calculator_1.calcPublishRecency)(0), 100);
        });
        it('should return ~50 for 6-month-old packages', () => {
            const score = (0, vibrancy_calculator_1.calcPublishRecency)(180);
            assert.ok(score > 45 && score < 55, `expected ~50, got ${score}`);
        });
        it('should return 0 for packages older than 365 days', () => {
            assert.strictEqual((0, vibrancy_calculator_1.calcPublishRecency)(365), 0);
            assert.strictEqual((0, vibrancy_calculator_1.calcPublishRecency)(500), 0);
        });
    });
    describe('calcPopularity', () => {
        it('should combine pub points and stars', () => {
            const score = (0, vibrancy_calculator_1.calcPopularity)(140, 3000);
            assert.ok(score > 50);
        });
        it('should return 0 for zero inputs', () => {
            assert.strictEqual((0, vibrancy_calculator_1.calcPopularity)(0, 0), 0);
        });
    });
    describe('computeVibrancyScore', () => {
        it('should compute weighted average with defaults', () => {
            const score = (0, vibrancy_calculator_1.computeVibrancyScore)({
                resolutionVelocity: 80,
                engagementLevel: 60,
                popularity: 50,
            });
            // 0.5*80 + 0.4*60 + 0.1*50 = 40 + 24 + 5 = 69
            assert.strictEqual(score, 69);
        });
        it('should clamp to 0-100', () => {
            const score = (0, vibrancy_calculator_1.computeVibrancyScore)({
                resolutionVelocity: 100,
                engagementLevel: 100,
                popularity: 100,
            });
            assert.ok(score <= 100);
        });
        it('should apply custom weights', () => {
            const score = (0, vibrancy_calculator_1.computeVibrancyScore)({ resolutionVelocity: 100, engagementLevel: 0, popularity: 0 }, { resolutionVelocity: 1.0, engagementLevel: 0, popularity: 0 });
            assert.strictEqual(score, 100);
        });
        it('should allow popularity-heavy weights', () => {
            const score = (0, vibrancy_calculator_1.computeVibrancyScore)({ resolutionVelocity: 0, engagementLevel: 0, popularity: 80 }, { resolutionVelocity: 0, engagementLevel: 0, popularity: 1.0 });
            assert.strictEqual(score, 80);
        });
        it('should produce different scores with different weights', () => {
            const params = {
                resolutionVelocity: 90,
                engagementLevel: 30,
                popularity: 10,
            };
            const defaultScore = (0, vibrancy_calculator_1.computeVibrancyScore)(params);
            const evenScore = (0, vibrancy_calculator_1.computeVibrancyScore)(params, {
                resolutionVelocity: 0.33,
                engagementLevel: 0.34,
                popularity: 0.33,
            });
            assert.notStrictEqual(defaultScore, evenScore);
        });
        it('should return 0 when all inputs are 0', () => {
            const score = (0, vibrancy_calculator_1.computeVibrancyScore)({ resolutionVelocity: 0, engagementLevel: 0, popularity: 0 });
            assert.strictEqual(score, 0);
        });
        it('should subtract penalty from score', () => {
            const base = (0, vibrancy_calculator_1.computeVibrancyScore)({
                resolutionVelocity: 80,
                engagementLevel: 60,
                popularity: 50,
            });
            const penalized = (0, vibrancy_calculator_1.computeVibrancyScore)({
                resolutionVelocity: 80,
                engagementLevel: 60,
                popularity: 50,
            }, undefined, 10);
            assert.strictEqual(penalized, base - 10);
        });
        it('should clamp penalty result to 0', () => {
            const score = (0, vibrancy_calculator_1.computeVibrancyScore)({
                resolutionVelocity: 5,
                engagementLevel: 5,
                popularity: 5,
            }, undefined, 50);
            assert.strictEqual(score, 0);
        });
    });
    describe('calcPublisherTrust', () => {
        it('should return max bonus for major publishers', () => {
            for (const pub of vibrancy_calculator_1.MAJOR_PUBLISHERS) {
                assert.strictEqual((0, vibrancy_calculator_1.calcPublisherTrust)(pub), 15);
            }
        });
        it('should return 1/3 bonus for verified publishers', () => {
            assert.strictEqual((0, vibrancy_calculator_1.calcPublisherTrust)('invertase.io'), 5);
        });
        it('should return negative penalty for no publisher', () => {
            assert.strictEqual((0, vibrancy_calculator_1.calcPublisherTrust)(null), -5);
        });
        it('should respect custom maxBonus', () => {
            assert.strictEqual((0, vibrancy_calculator_1.calcPublisherTrust)('dart.dev', 21), 21);
            assert.strictEqual((0, vibrancy_calculator_1.calcPublisherTrust)('other.dev', 21), 7);
            assert.strictEqual((0, vibrancy_calculator_1.calcPublisherTrust)(null, 21), -7);
        });
        it('should return 0 when maxBonus is 0', () => {
            assert.strictEqual((0, vibrancy_calculator_1.calcPublisherTrust)('dart.dev', 0), 0);
            assert.strictEqual((0, vibrancy_calculator_1.calcPublisherTrust)(null, 0), 0);
        });
    });
    describe('computeVibrancyScore with bonus', () => {
        it('should add bonus to score', () => {
            const base = (0, vibrancy_calculator_1.computeVibrancyScore)({
                resolutionVelocity: 80,
                engagementLevel: 60,
                popularity: 50,
            });
            const boosted = (0, vibrancy_calculator_1.computeVibrancyScore)({
                resolutionVelocity: 80,
                engagementLevel: 60,
                popularity: 50,
            }, undefined, 0, 15);
            assert.strictEqual(boosted, base + 15);
        });
        it('should apply bonus and penalty together', () => {
            const score = (0, vibrancy_calculator_1.computeVibrancyScore)({
                resolutionVelocity: 80,
                engagementLevel: 60,
                popularity: 50,
            }, undefined, 10, 15);
            // 69 - 10 + 15 = 74
            assert.strictEqual(score, 74);
        });
        it('should clamp bonus result to 100', () => {
            const score = (0, vibrancy_calculator_1.computeVibrancyScore)({
                resolutionVelocity: 100,
                engagementLevel: 100,
                popularity: 100,
            }, undefined, 0, 15);
            assert.strictEqual(score, 100);
        });
    });
    describe('calcFlaggedIssuePenalty', () => {
        it('should return 0 for no flagged issues', () => {
            assert.strictEqual((0, vibrancy_calculator_1.calcFlaggedIssuePenalty)(0), 0);
        });
        it('should return 5 for 1 flagged issue', () => {
            assert.strictEqual((0, vibrancy_calculator_1.calcFlaggedIssuePenalty)(1), 5);
        });
        it('should return 7 for 2 flagged issues', () => {
            assert.strictEqual((0, vibrancy_calculator_1.calcFlaggedIssuePenalty)(2), 7);
        });
        it('should cap at 15 for many flagged issues', () => {
            assert.strictEqual((0, vibrancy_calculator_1.calcFlaggedIssuePenalty)(6), 15);
            assert.strictEqual((0, vibrancy_calculator_1.calcFlaggedIssuePenalty)(20), 15);
        });
        it('should return 0 for negative input', () => {
            assert.strictEqual((0, vibrancy_calculator_1.calcFlaggedIssuePenalty)(-1), 0);
        });
    });
});
//# sourceMappingURL=vibrancy-calculator.test.js.map