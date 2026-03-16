import * as assert from 'assert';
import {
    classifyUpgradeStatus, findBlockers,
} from '../../../vibrancy/scoring/blocker-analyzer';
import { PubOutdatedEntry, DepEdge, VibrancyResult } from '../../../vibrancy/types';

function makeEntry(overrides: Partial<PubOutdatedEntry> & { package: string }): PubOutdatedEntry {
    return {
        current: '1.0.0',
        upgradable: '1.0.0',
        resolvable: '1.0.0',
        latest: '1.0.0',
        ...overrides,
    };
}

function makeResult(name: string, score: number): VibrancyResult {
    return {
        package: {
            name, version: '1.0.0', constraint: '^1.0.0',
            source: 'hosted', isDirect: true, section: 'dependencies',
        },
        pubDev: null, github: null, knownIssue: null,
        score, category: score >= 70 ? 'vibrant' : 'end-of-life',
        resolutionVelocity: 0, engagementLevel: 0,
        popularity: 0, publisherTrust: 0,
        updateInfo: null, license: null, drift: null,
        archiveSizeBytes: null, bloatRating: null,
        isUnused: false, platforms: null,
        verifiedPublisher: false, wasmReady: null, blocker: null, upgradeBlockStatus: 'up-to-date',
        transitiveInfo: null, alternatives: [], latestPrerelease: null, prereleaseTag: null,
        vulnerabilities: [],
    };
}

describe('blocker-analyzer', () => {
    describe('classifyUpgradeStatus', () => {
        it('should return up-to-date when current equals latest', () => {
            const entry = makeEntry({
                package: 'x', current: '2.0.0', latest: '2.0.0',
            });
            assert.strictEqual(classifyUpgradeStatus(entry), 'up-to-date');
        });

        it('should return blocked when resolvable < latest', () => {
            const entry = makeEntry({
                package: 'x',
                current: '1.0.0', upgradable: '1.0.0',
                resolvable: '1.0.0', latest: '2.0.0',
            });
            assert.strictEqual(classifyUpgradeStatus(entry), 'blocked');
        });

        it('should return constrained when upgradable < resolvable', () => {
            const entry = makeEntry({
                package: 'x',
                current: '1.0.0', upgradable: '1.1.0',
                resolvable: '2.0.0', latest: '2.0.0',
            });
            assert.strictEqual(classifyUpgradeStatus(entry), 'constrained');
        });

        it('should return upgradable when all versions match latest', () => {
            const entry = makeEntry({
                package: 'x',
                current: '1.0.0', upgradable: '2.0.0',
                resolvable: '2.0.0', latest: '2.0.0',
            });
            assert.strictEqual(classifyUpgradeStatus(entry), 'upgradable');
        });

        it('should return up-to-date when current is null', () => {
            const entry = makeEntry({
                package: 'x', current: null,
            });
            assert.strictEqual(classifyUpgradeStatus(entry), 'up-to-date');
        });
    });

    describe('findBlockers', () => {
        it('should find a single blocker', () => {
            const outdated: PubOutdatedEntry[] = [
                makeEntry({
                    package: 'intl',
                    current: '0.17.0', upgradable: '0.17.0',
                    resolvable: '0.17.0', latest: '0.19.0',
                }),
            ];
            const reverseDeps = new Map<string, DepEdge[]>([
                ['intl', [{ dependentPackage: 'date_picker_timeline' }]],
            ]);
            const results = [makeResult('date_picker_timeline', 12)];
            const directDeps = new Set(['intl', 'date_picker_timeline']);

            const blockers = findBlockers(
                outdated, reverseDeps, results, directDeps,
            );
            assert.strictEqual(blockers.length, 1);
            assert.strictEqual(blockers[0].blockedPackage, 'intl');
            assert.strictEqual(
                blockers[0].blockerPackage, 'date_picker_timeline',
            );
            assert.strictEqual(blockers[0].blockerVibrancyScore, 12);
            assert.strictEqual(blockers[0].blockerCategory, 'end-of-life');
        });

        it('should prefer direct dependency as blocker', () => {
            const outdated: PubOutdatedEntry[] = [
                makeEntry({
                    package: 'meta',
                    current: '1.0.0', resolvable: '1.0.0', latest: '2.0.0',
                }),
            ];
            const reverseDeps = new Map<string, DepEdge[]>([
                ['meta', [
                    { dependentPackage: 'transitive_pkg' },
                    { dependentPackage: 'direct_pkg' },
                ]],
            ]);
            const results = [makeResult('direct_pkg', 80)];
            const directDeps = new Set(['direct_pkg']);

            const blockers = findBlockers(
                outdated, reverseDeps, results, directDeps,
            );
            assert.strictEqual(blockers[0].blockerPackage, 'direct_pkg');
        });

        it('should return empty when no packages are blocked', () => {
            const outdated: PubOutdatedEntry[] = [
                makeEntry({
                    package: 'http',
                    current: '1.0.0', upgradable: '2.0.0',
                    resolvable: '2.0.0', latest: '2.0.0',
                }),
            ];
            const blockers = findBlockers(
                outdated, new Map(), [], new Set(),
            );
            assert.deepStrictEqual(blockers, []);
        });

        it('should handle blocked package with no reverse deps', () => {
            const outdated: PubOutdatedEntry[] = [
                makeEntry({
                    package: 'orphan',
                    current: '1.0.0', resolvable: '1.0.0', latest: '2.0.0',
                }),
            ];
            const blockers = findBlockers(
                outdated, new Map(), [], new Set(),
            );
            assert.deepStrictEqual(blockers, []);
        });

        it('should handle blocker without vibrancy result', () => {
            const outdated: PubOutdatedEntry[] = [
                makeEntry({
                    package: 'pkg',
                    current: '1.0.0', resolvable: '1.0.0', latest: '2.0.0',
                }),
            ];
            const reverseDeps = new Map<string, DepEdge[]>([
                ['pkg', [{ dependentPackage: 'unknown_blocker' }]],
            ]);
            const blockers = findBlockers(
                outdated, reverseDeps, [], new Set(),
            );
            assert.strictEqual(blockers[0].blockerVibrancyScore, null);
            assert.strictEqual(blockers[0].blockerCategory, null);
        });
    });
});
