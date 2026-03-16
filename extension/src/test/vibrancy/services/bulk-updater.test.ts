import * as assert from 'assert';
import { resetMocks, messageMock, setTestConfig, clearTestConfig } from '../vscode-mock';
import { getUpdatablePackages, formatFilterLabel, UpdateEntry } from '../../../vibrancy/services/bulk-updater';
import { VibrancyResult } from '../../../vibrancy/types';

describe('bulk-updater', () => {
    beforeEach(() => {
        resetMocks();
        clearTestConfig();
    });

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

    describe('getUpdatablePackages', () => {
        it('returns all updatable packages for all filter', () => {
            const results = [
                makeResult('pkg-major', '1.0.0', '2.0.0'),
                makeResult('pkg-minor', '1.0.0', '1.1.0'),
                makeResult('pkg-patch', '1.0.0', '1.0.1'),
            ];

            const { updatable, skipped } = getUpdatablePackages(
                results,
                new Set(),
                new Set(),
                'all',
            );

            assert.strictEqual(updatable.length, 3);
            assert.strictEqual(skipped.length, 0);
        });

        it('filters by major increment', () => {
            const results = [
                makeResult('pkg-major', '1.0.0', '2.0.0'),
                makeResult('pkg-minor', '1.0.0', '1.1.0'),
                makeResult('pkg-patch', '1.0.0', '1.0.1'),
            ];

            const { updatable, skipped } = getUpdatablePackages(
                results,
                new Set(),
                new Set(),
                'major',
            );

            assert.strictEqual(updatable.length, 1);
            assert.strictEqual(updatable[0].name, 'pkg-major');
            assert.strictEqual(skipped.length, 2);
        });

        it('filters by minor increment (includes major)', () => {
            const results = [
                makeResult('pkg-major', '1.0.0', '2.0.0'),
                makeResult('pkg-minor', '1.0.0', '1.1.0'),
                makeResult('pkg-patch', '1.0.0', '1.0.1'),
            ];

            const { updatable, skipped } = getUpdatablePackages(
                results,
                new Set(),
                new Set(),
                'minor',
            );

            assert.strictEqual(updatable.length, 2);
            const names = updatable.map(u => u.name);
            assert.ok(names.includes('pkg-major'));
            assert.ok(names.includes('pkg-minor'));
            assert.strictEqual(skipped.length, 1);
        });

        it('filters by patch increment', () => {
            const results = [
                makeResult('pkg-major', '1.0.0', '2.0.0'),
                makeResult('pkg-minor', '1.0.0', '1.1.0'),
                makeResult('pkg-patch', '1.0.0', '1.0.1'),
            ];

            const { updatable, skipped } = getUpdatablePackages(
                results,
                new Set(),
                new Set(),
                'patch',
            );

            assert.strictEqual(updatable.length, 1);
            assert.strictEqual(updatable[0].name, 'pkg-patch');
            assert.strictEqual(skipped.length, 2);
        });

        it('skips suppressed packages', () => {
            const results = [
                makeResult('pkg-a', '1.0.0', '2.0.0'),
                makeResult('pkg-b', '1.0.0', '2.0.0'),
            ];

            const { updatable, skipped } = getUpdatablePackages(
                results,
                new Set(['pkg-a']),
                new Set(),
                'all',
            );

            assert.strictEqual(updatable.length, 1);
            assert.strictEqual(updatable[0].name, 'pkg-b');
            assert.strictEqual(skipped.length, 1);
            assert.strictEqual(skipped[0].name, 'pkg-a');
            assert.strictEqual(skipped[0].reason, 'suppressed');
        });

        it('skips allowlisted packages', () => {
            const results = [
                makeResult('pkg-a', '1.0.0', '2.0.0'),
                makeResult('pkg-b', '1.0.0', '2.0.0'),
            ];

            const { updatable, skipped } = getUpdatablePackages(
                results,
                new Set(),
                new Set(['pkg-b']),
                'all',
            );

            assert.strictEqual(updatable.length, 1);
            assert.strictEqual(updatable[0].name, 'pkg-a');
            assert.strictEqual(skipped.length, 1);
            assert.strictEqual(skipped[0].name, 'pkg-b');
            assert.strictEqual(skipped[0].reason, 'in allowlist');
        });

        it('skips packages without updates', () => {
            const results = [
                makeResult('pkg-current', '1.0.0', '1.0.0'),
                makeResult('pkg-update', '1.0.0', '2.0.0'),
            ];

            const { updatable, skipped } = getUpdatablePackages(
                results,
                new Set(),
                new Set(),
                'all',
            );

            assert.strictEqual(updatable.length, 1);
            assert.strictEqual(updatable[0].name, 'pkg-update');
        });

        it('returns empty arrays when no updates available', () => {
            const results = [
                makeResult('pkg-current', '1.0.0', '1.0.0'),
            ];

            const { updatable, skipped } = getUpdatablePackages(
                results,
                new Set(),
                new Set(),
                'all',
            );

            assert.strictEqual(updatable.length, 0);
            assert.strictEqual(skipped.length, 0);
        });

        it('correctly classifies increment types in entries', () => {
            const results = [
                makeResult('pkg-major', '1.0.0', '2.0.0'),
                makeResult('pkg-minor', '1.0.0', '1.1.0'),
                makeResult('pkg-patch', '1.0.0', '1.0.1'),
            ];

            const { updatable } = getUpdatablePackages(
                results,
                new Set(),
                new Set(),
                'all',
            );

            const majorEntry = updatable.find(u => u.name === 'pkg-major');
            const minorEntry = updatable.find(u => u.name === 'pkg-minor');
            const patchEntry = updatable.find(u => u.name === 'pkg-patch');

            assert.strictEqual(majorEntry?.increment, 'major');
            assert.strictEqual(minorEntry?.increment, 'minor');
            assert.strictEqual(patchEntry?.increment, 'patch');
        });
    });

    describe('formatFilterLabel', () => {
        it('formats all filter labels correctly', () => {
            assert.strictEqual(formatFilterLabel('all'), 'Latest');
            assert.strictEqual(formatFilterLabel('major'), 'Major Only');
            assert.strictEqual(formatFilterLabel('minor'), 'Minor Only');
            assert.strictEqual(formatFilterLabel('patch'), 'Patch Only');
        });
    });
});
