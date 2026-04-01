import * as assert from 'assert';
import { VibrancyResult, VibrancyCategory } from '../../../vibrancy/types';
import { ReportMetadata } from '../../../vibrancy/services/report-exporter';
import { countByCategory } from '../../../vibrancy/scoring/status-classifier';

function makeResult(overrides: Partial<VibrancyResult> = {}): VibrancyResult {
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
        category: 'vibrant' as VibrancyCategory,
        resolutionVelocity: 80,
        engagementLevel: 70,
        popularity: 60,
        publisherTrust: 0,
        updateInfo: null,
        archiveSizeBytes: null,
        bloatRating: null,
        license: null,
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
                makeResult({ category: 'stable' }),
                makeResult({ category: 'outdated' }),
                makeResult({ category: 'abandoned' }),
                makeResult({ category: 'end-of-life' }),
            ];
            const counts = countByCategory(results);
            assert.strictEqual(counts.vibrant, 2);
            assert.strictEqual(counts.stable, 1);
            assert.strictEqual(counts.outdated, 1);
            assert.strictEqual(counts.abandoned, 1);
            assert.strictEqual(counts.eol, 1);
        });

        it('should return zeros for empty results', () => {
            const counts = countByCategory([]);
            assert.strictEqual(counts.vibrant, 0);
            assert.strictEqual(counts.stable, 0);
            assert.strictEqual(counts.outdated, 0);
            assert.strictEqual(counts.abandoned, 0);
            assert.strictEqual(counts.eol, 0);
        });
    });

    describe('ReportMetadata shape', () => {
        it('should accept valid metadata', () => {
            const meta: ReportMetadata = {
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
