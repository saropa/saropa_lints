import * as assert from 'assert';
import { snapshotVersions } from '../../../vibrancy/services/lock-diff-notifier';
import { VibrancyResult } from '../../../vibrancy/types';

function makeResult(
    name: string,
    version: string,
): VibrancyResult {
    return {
        package: { name, version, constraint: `^${version}`, source: 'hosted', isDirect: true, section: 'dependencies' },
        pubDev: null,
        github: null,
        knownIssue: null,
        score: 85,
        category: 'vibrant',
        resolutionVelocity: 50,
        engagementLevel: 40,
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
    };
}

describe('lock-diff-notifier', () => {
    describe('snapshotVersions', () => {
        it('should create map from results', () => {
            const results = [
                makeResult('http', '1.0.0'),
                makeResult('path', '1.8.0'),
            ];
            const map = snapshotVersions(results);
            assert.strictEqual(map.get('http'), '1.0.0');
            assert.strictEqual(map.get('path'), '1.8.0');
        });

        it('should return empty map for empty results', () => {
            const map = snapshotVersions([]);
            assert.strictEqual(map.size, 0);
        });
    });
});
