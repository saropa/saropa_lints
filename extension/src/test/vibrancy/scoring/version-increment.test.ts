import * as assert from 'assert';
import {
    classifyIncrement, incrementMatchesFilter, filterByIncrement, formatIncrement,
    VersionIncrement, IncrementFilter,
} from '../../../vibrancy/scoring/version-increment';
import { VibrancyResult } from '../../../vibrancy/types';

describe('version-increment', () => {
    describe('classifyIncrement', () => {
        it('detects major increment', () => {
            assert.strictEqual(classifyIncrement('1.0.0', '2.0.0'), 'major');
            assert.strictEqual(classifyIncrement('1.2.3', '2.0.0'), 'major');
            assert.strictEqual(classifyIncrement('0.9.9', '1.0.0'), 'major');
        });

        it('detects minor increment', () => {
            assert.strictEqual(classifyIncrement('1.0.0', '1.1.0'), 'minor');
            assert.strictEqual(classifyIncrement('1.2.3', '1.3.0'), 'minor');
            assert.strictEqual(classifyIncrement('2.5.1', '2.6.0'), 'minor');
        });

        it('detects patch increment', () => {
            assert.strictEqual(classifyIncrement('1.0.0', '1.0.1'), 'patch');
            assert.strictEqual(classifyIncrement('1.2.3', '1.2.4'), 'patch');
            assert.strictEqual(classifyIncrement('2.5.1', '2.5.9'), 'patch');
        });

        it('detects prerelease changes', () => {
            assert.strictEqual(classifyIncrement('1.0.0-alpha', '1.0.0-beta'), 'prerelease');
            assert.strictEqual(classifyIncrement('1.0.0-rc.1', '1.0.0-rc.2'), 'prerelease');
        });

        it('returns none for equal versions', () => {
            assert.strictEqual(classifyIncrement('1.0.0', '1.0.0'), 'none');
            assert.strictEqual(classifyIncrement('2.3.4', '2.3.4'), 'none');
        });

        it('returns none for downgrades', () => {
            assert.strictEqual(classifyIncrement('2.0.0', '1.0.0'), 'none');
            assert.strictEqual(classifyIncrement('1.2.0', '1.1.0'), 'none');
            assert.strictEqual(classifyIncrement('1.0.2', '1.0.1'), 'none');
        });

        it('returns none for invalid versions', () => {
            assert.strictEqual(classifyIncrement('invalid', '1.0.0'), 'none');
            assert.strictEqual(classifyIncrement('1.0.0', 'invalid'), 'none');
            assert.strictEqual(classifyIncrement('', ''), 'none');
        });

        it('handles versions with build metadata', () => {
            assert.strictEqual(classifyIncrement('1.0.0+1', '2.0.0+1'), 'major');
            assert.strictEqual(classifyIncrement('1.0.0+build', '1.1.0+build'), 'minor');
        });
    });

    describe('incrementMatchesFilter', () => {
        it('all filter matches all increment types', () => {
            assert.strictEqual(incrementMatchesFilter('major', 'all'), true);
            assert.strictEqual(incrementMatchesFilter('minor', 'all'), true);
            assert.strictEqual(incrementMatchesFilter('patch', 'all'), true);
            assert.strictEqual(incrementMatchesFilter('prerelease', 'all'), true);
        });

        it('all filter excludes none', () => {
            assert.strictEqual(incrementMatchesFilter('none', 'all'), false);
        });

        it('major filter only matches major', () => {
            assert.strictEqual(incrementMatchesFilter('major', 'major'), true);
            assert.strictEqual(incrementMatchesFilter('minor', 'major'), false);
            assert.strictEqual(incrementMatchesFilter('patch', 'major'), false);
        });

        it('minor filter matches minor and major', () => {
            assert.strictEqual(incrementMatchesFilter('major', 'minor'), true);
            assert.strictEqual(incrementMatchesFilter('minor', 'minor'), true);
            assert.strictEqual(incrementMatchesFilter('patch', 'minor'), false);
        });

        it('patch filter only matches patch', () => {
            assert.strictEqual(incrementMatchesFilter('patch', 'patch'), true);
            assert.strictEqual(incrementMatchesFilter('minor', 'patch'), false);
            assert.strictEqual(incrementMatchesFilter('major', 'patch'), false);
        });
    });

    describe('filterByIncrement', () => {
        const makeResult = (
            name: string,
            current: string,
            latest: string,
        ): VibrancyResult => ({
            package: {
                name,
                version: current,
                constraint: `^${current}`,
                source: 'hosted',
                isDirect: true,
                section: 'dependencies',
            },
            pubDev: null,
            github: null,
            knownIssue: null,
            score: 80,
            category: 'vibrant',
            resolutionVelocity: 0.8,
            engagementLevel: 0.7,
            popularity: 0.6,
            publisherTrust: 15,
            updateInfo: current === latest ? null : {
                currentVersion: current,
                latestVersion: latest,
                updateStatus: 'major',
                changelog: null,
            },
            license: 'MIT',
            drift: null,
            archiveSizeBytes: null,
            bloatRating: null,
            isUnused: false,
            platforms: null,
            verifiedPublisher: true,
            wasmReady: null,
        blocker: null,
        upgradeBlockStatus: 'upgradable',
        transitiveInfo: null,
        alternatives: [],
        latestPrerelease: null,
        prereleaseTag: null,
        vulnerabilities: [],
    });

        it('filters packages by all', () => {
            const packages = [
                makeResult('pkg-major', '1.0.0', '2.0.0'),
                makeResult('pkg-minor', '1.0.0', '1.1.0'),
                makeResult('pkg-patch', '1.0.0', '1.0.1'),
            ];
            const filtered = filterByIncrement(packages, 'all');
            assert.strictEqual(filtered.length, 3);
        });

        it('filters packages by major', () => {
            const packages = [
                makeResult('pkg-major', '1.0.0', '2.0.0'),
                makeResult('pkg-minor', '1.0.0', '1.1.0'),
                makeResult('pkg-patch', '1.0.0', '1.0.1'),
            ];
            const filtered = filterByIncrement(packages, 'major');
            assert.strictEqual(filtered.length, 1);
            assert.strictEqual(filtered[0].package.name, 'pkg-major');
        });

        it('filters packages by minor (includes major)', () => {
            const packages = [
                makeResult('pkg-major', '1.0.0', '2.0.0'),
                makeResult('pkg-minor', '1.0.0', '1.1.0'),
                makeResult('pkg-patch', '1.0.0', '1.0.1'),
            ];
            const filtered = filterByIncrement(packages, 'minor');
            assert.strictEqual(filtered.length, 2);
            const names = filtered.map(p => p.package.name);
            assert.ok(names.includes('pkg-major'));
            assert.ok(names.includes('pkg-minor'));
        });

        it('filters packages by patch', () => {
            const packages = [
                makeResult('pkg-major', '1.0.0', '2.0.0'),
                makeResult('pkg-minor', '1.0.0', '1.1.0'),
                makeResult('pkg-patch', '1.0.0', '1.0.1'),
            ];
            const filtered = filterByIncrement(packages, 'patch');
            assert.strictEqual(filtered.length, 1);
            assert.strictEqual(filtered[0].package.name, 'pkg-patch');
        });

        it('excludes packages without update info', () => {
            const packages = [
                makeResult('pkg-no-update', '1.0.0', '1.0.0'),
            ];
            const filtered = filterByIncrement(packages, 'all');
            assert.strictEqual(filtered.length, 0);
        });
    });

    describe('formatIncrement', () => {
        it('formats all increment types', () => {
            assert.strictEqual(formatIncrement('major'), 'major');
            assert.strictEqual(formatIncrement('minor'), 'minor');
            assert.strictEqual(formatIncrement('patch'), 'patch');
            assert.strictEqual(formatIncrement('prerelease'), 'prerelease');
            assert.strictEqual(formatIncrement('none'), 'up-to-date');
        });
    });
});
