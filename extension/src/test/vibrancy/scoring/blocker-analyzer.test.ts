/**
 * Tests [classifyUpgradeStatus] and [findBlockers]: pub outdated rows, semver edges,
 * and synthetic [VibrancyResult] rows for graph-derived blocker messages.
 */
import * as assert from 'assert';
import {
    classifyUpgradeStatus, findBlockers, formatSharedDepDetail,
} from '../../../vibrancy/scoring/blocker-analyzer';
import { PubOutdatedEntry, DepEdge, VibrancyResult, BlockerInfo } from '../../../vibrancy/types';
import { makeMinimalResult } from '../test-helpers';

/** Builds a [PubOutdatedEntry] with sane defaults; override fields per case. */
function makeEntry(overrides: Partial<PubOutdatedEntry> & { package: string }): PubOutdatedEntry {
    return {
        current: '1.0.0',
        upgradable: '1.0.0',
        resolvable: '1.0.0',
        latest: '1.0.0',
        ...overrides,
    };
}

/** Minimal [VibrancyResult] for a direct hosted dependency with given vibrancy score. */
function makeResult(name: string, score: number): VibrancyResult {
    return makeMinimalResult({
        name,
        score,
        category: score >= 70 ? 'vibrant' : 'end-of-life',
    });
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

    describe('formatSharedDepDetail', () => {
        function blocker(o: Partial<BlockerInfo>): BlockerInfo {
            return {
                blockedPackage: 'dart_style', currentVersion: '3.1.7',
                latestVersion: '3.1.8', blockerPackage: 'saropa_lints',
                blockerVibrancyScore: null, blockerCategory: null, ...o,
            };
        }

        it('returns null for an ordinary reverse-dependency blocker', () => {
            assert.strictEqual(formatSharedDepDetail(blocker({})), null);
        });

        it('names the shared dep, ceiling, and resolvable/latest gap', () => {
            const detail = formatSharedDepDetail(blocker({
                sharedDependency: 'analyzer',
                blockerConstraint: '>=9.0.0 <13.0.0',
                sharedDependencyResolvable: '12.0.0',
                sharedDependencyLatest: '13.1.0',
            }));
            assert.strictEqual(
                detail,
                'via analyzer — saropa_lints caps >=9.0.0 <13.0.0 '
                + '(12.0.0 resolvable, 13.1.0 latest)',
            );
        });
    });
});
