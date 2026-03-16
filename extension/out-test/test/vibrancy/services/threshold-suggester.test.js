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
const threshold_suggester_1 = require("../../../vibrancy/services/threshold-suggester");
function makeResult(overrides = {}) {
    return {
        package: { name: 'test_pkg', version: '1.0.0', constraint: '^1.0.0', source: 'hosted', isDirect: true, section: 'dependencies' },
        pubDev: null,
        github: null,
        knownIssue: null,
        score: 75,
        category: 'vibrant',
        resolutionVelocity: 80,
        engagementLevel: 70,
        popularity: 60,
        publisherTrust: 0,
        updateInfo: null,
        archiveSizeBytes: null,
        bloatRating: null,
        license: null,
        drift: null,
        isUnused: false,
        platforms: null,
        verifiedPublisher: false,
        wasmReady: null,
        blocker: null,
        upgradeBlockStatus: 'up-to-date',
        transitiveInfo: null,
        alternatives: [],
        latestPrerelease: null,
        prereleaseTag: null,
        vulnerabilities: [],
        ...overrides,
    };
}
describe('threshold-suggester', () => {
    describe('suggestThresholds', () => {
        it('should return zero thresholds for empty results', () => {
            const thresholds = (0, threshold_suggester_1.suggestThresholds)([]);
            assert.strictEqual(thresholds.maxStale, 0);
            assert.strictEqual(thresholds.maxEndOfLife, 0);
            assert.strictEqual(thresholds.maxLegacyLocked, 1);
            assert.strictEqual(thresholds.minAverageVibrancy, 0);
            assert.strictEqual(thresholds.failOnVulnerability, true);
        });
        it('should count stale packages correctly', () => {
            const results = [
                makeResult({ category: 'stale' }),
                makeResult({ category: 'stale' }),
                makeResult({ category: 'vibrant' }),
            ];
            const thresholds = (0, threshold_suggester_1.suggestThresholds)(results);
            assert.strictEqual(thresholds.maxStale, 2);
        });
        it('should count end-of-life packages correctly', () => {
            const results = [
                makeResult({ category: 'end-of-life' }),
                makeResult({ category: 'end-of-life' }),
                makeResult({ category: 'vibrant' }),
            ];
            const thresholds = (0, threshold_suggester_1.suggestThresholds)(results);
            assert.strictEqual(thresholds.maxEndOfLife, 2);
        });
        it('should count legacy-locked packages and add buffer', () => {
            const results = [
                makeResult({ category: 'legacy-locked' }),
                makeResult({ category: 'legacy-locked' }),
                makeResult({ category: 'legacy-locked' }),
                makeResult({ category: 'vibrant' }),
            ];
            const thresholds = (0, threshold_suggester_1.suggestThresholds)(results);
            assert.strictEqual(thresholds.maxLegacyLocked, 4);
        });
        it('should round down average vibrancy to nearest 5', () => {
            const results = [
                makeResult({ score: 72 }),
                makeResult({ score: 68 }),
                makeResult({ score: 85 }),
            ];
            const thresholds = (0, threshold_suggester_1.suggestThresholds)(results);
            assert.strictEqual(thresholds.minAverageVibrancy, 75);
        });
        it('should handle scores that divide evenly', () => {
            const results = [
                makeResult({ score: 50 }),
                makeResult({ score: 50 }),
            ];
            const thresholds = (0, threshold_suggester_1.suggestThresholds)(results);
            assert.strictEqual(thresholds.minAverageVibrancy, 50);
        });
        it('should handle healthy project (no issues)', () => {
            const results = [
                makeResult({ category: 'vibrant', score: 85 }),
                makeResult({ category: 'vibrant', score: 90 }),
                makeResult({ category: 'quiet', score: 55 }),
            ];
            const thresholds = (0, threshold_suggester_1.suggestThresholds)(results);
            assert.strictEqual(thresholds.maxStale, 0);
            assert.strictEqual(thresholds.maxEndOfLife, 0);
            assert.strictEqual(thresholds.maxLegacyLocked, 1);
            assert.strictEqual(thresholds.minAverageVibrancy, 75);
        });
        it('should handle project with many EOL packages', () => {
            // EOL category is set directly — these represent discontinued packages, not score-based classification
            const results = [
                makeResult({ category: 'end-of-life', score: 10 }),
                makeResult({ category: 'end-of-life', score: 15 }),
                makeResult({ category: 'end-of-life', score: 5 }),
                makeResult({ category: 'legacy-locked', score: 30 }),
                makeResult({ category: 'vibrant', score: 80 }),
            ];
            const thresholds = (0, threshold_suggester_1.suggestThresholds)(results);
            assert.strictEqual(thresholds.maxEndOfLife, 3);
            assert.strictEqual(thresholds.maxLegacyLocked, 2);
            assert.strictEqual(thresholds.minAverageVibrancy, 25);
        });
        it('should always set failOnVulnerability to true', () => {
            const thresholds = (0, threshold_suggester_1.suggestThresholds)([makeResult()]);
            assert.strictEqual(thresholds.failOnVulnerability, true);
        });
    });
    describe('formatThresholdsSummary', () => {
        it('should format all threshold values', () => {
            const thresholds = {
                maxStale: 1,
                maxEndOfLife: 2,
                maxLegacyLocked: 5,
                minAverageVibrancy: 60,
                failOnVulnerability: true,
            };
            const summary = (0, threshold_suggester_1.formatThresholdsSummary)(thresholds);
            assert.ok(summary.includes('Stale ≤ 1'));
            assert.ok(summary.includes('EOL ≤ 2'));
            assert.ok(summary.includes('Legacy ≤ 5'));
            assert.ok(summary.includes('Avg ≥ 60'));
            assert.ok(summary.includes('Fail on vuln'));
        });
        it('should omit vulnerability text when disabled', () => {
            const thresholds = {
                maxStale: 0,
                maxEndOfLife: 0,
                maxLegacyLocked: 1,
                minAverageVibrancy: 70,
                failOnVulnerability: false,
            };
            const summary = (0, threshold_suggester_1.formatThresholdsSummary)(thresholds);
            assert.ok(!summary.includes('Fail on vuln'));
        });
    });
});
//# sourceMappingURL=threshold-suggester.test.js.map