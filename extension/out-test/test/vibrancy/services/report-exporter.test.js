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
const status_classifier_1 = require("../../../vibrancy/scoring/status-classifier");
function makeResult(overrides = {}) {
    return {
        package: { name: 'test_pkg', version: '1.0.0', constraint: '^1.0.0', source: 'hosted', isDirect: true, section: 'dependencies' },
        pubDev: {
            name: 'test_pkg',
            latestVersion: '2.0.0',
            publishedDate: '2025-01-01T00:00:00Z',
            repositoryUrl: 'https://github.com/test/test_pkg',
            isDiscontinued: false,
            isUnlisted: false,
            pubPoints: 130,
            publisher: null,
            license: null,
            description: null,
            topics: [],
        },
        github: {
            stars: 500,
            openIssues: 10,
            closedIssuesLast90d: 5,
            mergedPrsLast90d: 3,
            avgCommentsPerIssue: 2,
            daysSinceLastUpdate: 10,
            daysSinceLastClose: 5,
            flaggedIssues: [],
            license: null,
        },
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
        isUnused: false, platforms: null, verifiedPublisher: false, wasmReady: null, blocker: null, upgradeBlockStatus: 'up-to-date',
        transitiveInfo: null, alternatives: [], latestPrerelease: null, prereleaseTag: null,
        vulnerabilities: [],
        ...overrides,
    };
}
describe('report-exporter', () => {
    describe('category counting', () => {
        it('should count all categories correctly', () => {
            const results = [
                makeResult({ category: 'vibrant' }),
                makeResult({ category: 'vibrant' }),
                makeResult({ category: 'quiet' }),
                makeResult({ category: 'legacy-locked' }),
                makeResult({ category: 'stale' }),
                makeResult({ category: 'end-of-life' }),
            ];
            const counts = (0, status_classifier_1.countByCategory)(results);
            assert.strictEqual(counts.vibrant, 2);
            assert.strictEqual(counts.quiet, 1);
            assert.strictEqual(counts.legacy, 1);
            assert.strictEqual(counts.stale, 1);
            assert.strictEqual(counts.eol, 1);
        });
        it('should return zeros for empty results', () => {
            const counts = (0, status_classifier_1.countByCategory)([]);
            assert.strictEqual(counts.vibrant, 0);
            assert.strictEqual(counts.quiet, 0);
            assert.strictEqual(counts.legacy, 0);
            assert.strictEqual(counts.stale, 0);
            assert.strictEqual(counts.eol, 0);
        });
    });
    describe('ReportMetadata shape', () => {
        it('should accept valid metadata', () => {
            const meta = {
                flutterVersion: '3.19.0',
                dartVersion: '3.3.0',
                executionTimeMs: 1500,
            };
            assert.strictEqual(meta.flutterVersion, '3.19.0');
            assert.strictEqual(meta.dartVersion, '3.3.0');
            assert.strictEqual(meta.executionTimeMs, 1500);
        });
    });
    describe('result mapping', () => {
        it('should have required fields for report rows', () => {
            const r = makeResult();
            assert.ok(r.package.name);
            assert.ok(r.package.version);
            assert.ok(r.pubDev?.latestVersion);
            assert.ok(r.category);
            assert.ok(typeof r.score === 'number');
        });
        it('should handle results without pubDev', () => {
            const r = makeResult({ pubDev: null });
            assert.strictEqual(r.pubDev, null);
        });
        it('should handle results without github metrics', () => {
            const r = makeResult({ github: null });
            assert.strictEqual(r.github, null);
        });
        it('should build pub.dev URL from package name', () => {
            const r = makeResult();
            const url = `https://pub.dev/packages/${r.package.name}`;
            assert.strictEqual(url, 'https://pub.dev/packages/test_pkg');
        });
    });
});
//# sourceMappingURL=report-exporter.test.js.map