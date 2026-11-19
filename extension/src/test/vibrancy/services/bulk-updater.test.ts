/** * Module overview (comment coverage pass). * comment-coverage: module overview (batch). * * Extension Jest tests: validates commands, webviews, parsers, and state against VS Code APIs (often with local mocks). */
import * as assert from 'assert';
import { resetMocks, messageMock, setTestConfig, clearTestConfig } from '../vscode-mock';
import { getUpdatablePackages, formatFilterLabel, UpdateEntry } from '../../../vibrancy/services/bulk-updater';
import { VibrancyResult } from '../../../vibrancy/types';
import { BlastRadius } from '../../../vibrancy/scoring/upgrade-blast-radius';

/**
 * Tests **bulk-updater**: [getUpdatablePackages] eligibility from synthetic [VibrancyResult] rows,
 * semver ceiling checks, and [formatFilterLabel] strings for quick-pick UX.
 */

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
        // Fixture predates newer required fields; the code under test reads only a few.
    } as unknown as VibrancyResult);

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

    describe('blast radius', () => {
        const blast = (
            verdict: BlastRadius['verdict'], pkg: string, to: string,
            extra: Partial<BlastRadius> = {},
        ): BlastRadius => ({
            pkg, from: '1.0.0', to, verdict, breakers: [], sdkBlock: null,
            heldBackReason: null,
            summaryKey: 'blastRadius.summary.safe',
            summaryParams: { pkg, from: '1.0.0', to },
            ...extra,
        });
        const withBlast = (r: VibrancyResult, b: BlastRadius): VibrancyResult =>
            ({ ...r, blastRadius: b });

        it('skips breaks-dependents packages with a reason', () => {
            const r = withBlast(makeResult('lints', '1.0.0', '2.0.0'), blast(
                'breaks-dependents', 'lints', '2.0.0', {
                    breakers: [{ name: 'app', constraint: '^1.0.0', chain: null, fixedInLatest: null }],
                    summaryKey: 'blastRadius.summary.breaksOne',
                    summaryParams: { pkg: 'lints', to: '2.0.0', count: 1, names: 'app' },
                }));
            const { updatable, skipped } = getUpdatablePackages([r], new Set(), new Set(), 'all');
            assert.strictEqual(updatable.length, 0);
            assert.strictEqual(skipped.length, 1);
            assert.strictEqual(skipped[0].name, 'lints');
            assert.ok(skipped[0].reason.includes('upgrade not recommended'));
            assert.ok(skipped[0].reason.includes('would break 1 dependent: app'));
        });

        it('updates packages whose verdict is safe', () => {
            const r = withBlast(makeResult('http', '1.0.0', '2.0.0'), blast('safe', 'http', '2.0.0'));
            const { updatable, skipped } = getUpdatablePackages([r], new Set(), new Set(), 'all');
            assert.deepStrictEqual(updatable.map(u => u.name), ['http']);
            assert.strictEqual(skipped.length, 0);
        });

        it('skips held-back analyzer 12 -> 13 while http still updates', () => {
            const analyzer = withBlast(makeResult('analyzer', '12.0.0', '13.0.0'), blast(
                'held-back', 'analyzer', '13.0.0', {
                    heldBackReason: 'needs meta ^1.18.3',
                    summaryKey: 'blastRadius.summary.heldBack',
                    summaryParams: { pkg: 'analyzer', to: '13.0.0', reason: 'needs meta ^1.18.3' },
                }));
            const http = withBlast(makeResult('http', '1.0.0', '1.1.0'), blast('safe', 'http', '1.1.0'));
            const { updatable, skipped } = getUpdatablePackages(
                [analyzer, http], new Set(), new Set(), 'all');
            assert.deepStrictEqual(updatable.map(u => u.name), ['http']);
            assert.strictEqual(skipped.length, 1);
            assert.strictEqual(skipped[0].name, 'analyzer');
            assert.ok(skipped[0].reason.includes('analyzer 13.0.0 is held back: needs meta ^1.18.3'));
        });

        it('does not suppress when blastRadius is missing', () => {
            const { updatable, skipped } = getUpdatablePackages(
                [makeResult('pkg-a', '1.0.0', '2.0.0')], new Set(), new Set(), 'all');
            assert.strictEqual(updatable.length, 1);
            assert.strictEqual(skipped.length, 0);
        });

        it('skips sdk-blocked packages using the localized SDK line', () => {
            const r = withBlast(makeResult('analyzer', '12.0.0', '13.1.0'), blast(
                'sdk-blocked', 'analyzer', '13.1.0', {
                    sdkBlock: { pkg: 'analyzer', to: '13.1.0', dep: 'meta', range: '^1.18.3', pinned: '1.18.0' },
                    summaryKey: 'blastRadius.summary.sdkBlocked',
                    summaryParams: { pkg: 'analyzer', to: '13.1.0' },
                }));
            const { skipped } = getUpdatablePackages([r], new Set(), new Set(), 'all');
            assert.ok(skipped[0].reason.includes('needs meta ^1.18.3; Flutter pins meta 1.18.0'));
        });

        it('blast-radius skip takes precedence over suppressed', () => {
            const r = withBlast(makeResult('lints', '1.0.0', '2.0.0'), blast('held-back', 'lints', '2.0.0'));
            const { skipped } = getUpdatablePackages([r], new Set(['lints']), new Set(), 'all');
            assert.ok(skipped[0].reason.startsWith('upgrade not recommended'));
        });

        it('returns empty arrays for empty input', () => {
            const { updatable, skipped } = getUpdatablePackages([], new Set(), new Set(), 'all');
            assert.deepStrictEqual(updatable, []);
            assert.deepStrictEqual(skipped, []);
        });

        it('reports increment-filter mismatches as skipped', () => {
            const { updatable, skipped } = getUpdatablePackages(
                [makeResult('pkg-a', '1.0.0', '2.0.0')], new Set(), new Set(), 'patch');
            assert.strictEqual(updatable.length, 0);
            assert.ok(skipped[0].reason.startsWith('not a patch update'));
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
