/**
 * Tests on-disk vibrancy history JSON: append dedupe, reads, trends, legacy migration.
 */
import * as assert from 'assert';
import * as fs from 'node:fs/promises';
import * as os from 'node:os';
import * as path from 'node:path';
import { appendSnapshot, backfillFromLegacyReports, getPackageTrend, readHistory } from '../../../vibrancy/services/vibrancy-history';
import { VibrancyResult } from '../../../vibrancy/types';

/** Synthetic scan row for a single package with explicit version/category/score. */
function makeResult(
    name: string,
    version: string,
    score: number,
    category: VibrancyResult['category'],
): VibrancyResult {
    return {
        package: {
            name,
            version,
            constraint: `^${version}`,
            source: 'hosted',
            isDirect: true,
            section: 'dependencies',
        },
        pubDev: null,
        github: null,
        knownIssue: null,
        score,
        category,
        resolutionVelocity: 0,
        engagementLevel: 0,
        popularity: 0,
        publisherTrust: 0,
        updateInfo: null,
        license: null,
        archiveSizeBytes: null,
        bloatRating: null,
        isUnused: false,
        fileUsages: [],
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
        versionGap: null,
        overrideGap: null,
        replacementComplexity: null,
        likes: null,
        downloadCount30Days: null,
        reverseDependencyCount: null,
        readme: null,
    };
}

describe('vibrancy-history', () => {
    let workspaceRoot: string;

    beforeEach(async () => {
        workspaceRoot = await fs.mkdtemp(path.join(os.tmpdir(), 'saropa-vibrancy-history-'));
    });

    afterEach(async () => {
        await fs.rm(workspaceRoot, { recursive: true, force: true });
    });

    it('appends first snapshot and skips identical repeats', async () => {
        const results = [makeResult('http', '1.0.0', 60, 'stable')];
        const first = await appendSnapshot(workspaceRoot, results, '1.0.0');
        const second = await appendSnapshot(workspaceRoot, results, '1.0.0');
        assert.strictEqual(first, true);
        assert.strictEqual(second, false);

        const history = await readHistory(workspaceRoot);
        assert.strictEqual(history.snapshots.length, 1);
    });

    it('appends when score changes at same version', async () => {
        await appendSnapshot(
            workspaceRoot,
            [makeResult('http', '1.0.0', 60, 'stable')],
            '1.0.0',
        );
        const appended = await appendSnapshot(
            workspaceRoot,
            [makeResult('http', '1.0.0', 72, 'stable')],
            '1.0.0',
        );
        assert.strictEqual(appended, true);

        const history = await readHistory(workspaceRoot);
        assert.strictEqual(history.snapshots.length, 2);
        assert.deepStrictEqual(getPackageTrend(history, 'http'), [60, 72]);
    });

    it('backfills from legacy report JSON files once', async () => {
        const reportDir = path.join(workspaceRoot, 'report');
        await fs.mkdir(reportDir, { recursive: true });
        await fs.writeFile(
            path.join(reportDir, '2026-04-28_10-00-00_saropa_vibrancy.json'),
            JSON.stringify({
                audit_metadata: { timestamp: '2026-04-28T10:00:00.000Z' },
                packages: [{
                    name: 'http',
                    installed_version: '1.0.0',
                    vibrancy_score: 60,
                    status: 'Stable',
                }],
            }),
            'utf8',
        );
        await fs.writeFile(
            path.join(reportDir, '2026-04-28_11-00-00_saropa_vibrancy.json'),
            JSON.stringify({
                audit_metadata: { timestamp: '2026-04-28T11:00:00.000Z' },
                packages: [{
                    name: 'http',
                    installed_version: '1.0.0',
                    vibrancy_score: 72,
                    status: 'Stable',
                }],
            }),
            'utf8',
        );

        const imported = await backfillFromLegacyReports(workspaceRoot);
        assert.strictEqual(imported, 2);
        const history = await readHistory(workspaceRoot);
        assert.strictEqual(history.snapshots.length, 2);
        assert.deepStrictEqual(getPackageTrend(history, 'http'), [60, 72]);

        const secondRun = await backfillFromLegacyReports(workspaceRoot);
        assert.strictEqual(secondRun, 0);
    });
});
