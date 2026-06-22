/**
 * Tests [classifyUpgradeStatus] and [findBlockers]: pub outdated rows, semver edges,
 * and synthetic [VibrancyResult] rows for graph-derived blocker messages.
 */
import * as assert from 'assert';
import {
    classifyUpgradeStatus, findBlockers, formatSharedDepDetail,
    formatConstrainedReason, managedSourceNote, isHostedUpgradeable,
    formatPinIntent, formatVersionDrift,
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

        it('appends the dependency chain when the constrainer is a deep transitive dep', () => {
            const detail = formatSharedDepDetail(blocker({
                blockerPackage: 'analyzer_plugin',
                sharedDependency: 'analyzer',
                blockerConstraint: '>=9.0.0 <13.0.0',
                sharedDependencyResolvable: '12.0.0',
                sharedDependencyLatest: '13.1.0',
                blockerChain: ['build_runner', 'build', 'analyzer_plugin'],
            }));
            assert.strictEqual(
                detail,
                'via analyzer — analyzer_plugin caps >=9.0.0 <13.0.0 '
                + '(12.0.0 resolvable, 13.1.0 latest) '
                + '[via build_runner → build → analyzer_plugin]',
            );
        });

        it('omits the chain clause for a single-node chain', () => {
            const detail = formatSharedDepDetail(blocker({
                sharedDependency: 'analyzer',
                blockerConstraint: '>=9.0.0 <13.0.0',
                sharedDependencyResolvable: '12.0.0',
                sharedDependencyLatest: '13.1.0',
                blockerChain: ['saropa_lints'],
            }));
            assert.strictEqual(
                detail,
                'via analyzer — saropa_lints caps >=9.0.0 <13.0.0 '
                + '(12.0.0 resolvable, 13.1.0 latest)',
            );
        });

        it('names the SDK as pinner for an SDK-inferred block', () => {
            const detail = formatSharedDepDetail(blocker({
                blockerPackage: 'flutter_test',
                sharedDependency: 'characters',
                blockerConstraint: '',
                blockerIsSdkPin: true,
                sharedDependencyResolvable: '1.4.0',
                sharedDependencyLatest: '1.4.1',
            }));
            assert.strictEqual(
                detail,
                'via characters — pinned by flutter_test (Flutter SDK) '
                + '(1.4.0 resolvable, 1.4.1 latest)',
            );
        });
    });

    describe('formatConstrainedReason', () => {
        it('returns null when no reason', () => {
            assert.strictEqual(formatConstrainedReason(null), null);
            assert.strictEqual(formatConstrainedReason(undefined), null);
        });

        it('names the constraint and the resolvable/latest gap', () => {
            assert.strictEqual(
                formatConstrainedReason({
                    constraint: '^1.9.0', resolvable: '1.9.2', latest: '1.9.2',
                }),
                'your constraint ^1.9.0 caps this — 1.9.2 resolvable, 1.9.2 latest',
            );
        });
    });

    describe('managedSourceNote / isHostedUpgradeable', () => {
        it('flags non-hosted sources', () => {
            assert.strictEqual(managedSourceNote('git'), 'via git override');
            assert.strictEqual(managedSourceNote('path'), 'via path override');
            assert.strictEqual(managedSourceNote('sdk'), 'SDK-managed');
            assert.strictEqual(managedSourceNote('hosted'), null);
        });

        it('treats only hosted as pub-upgradeable', () => {
            assert.strictEqual(isHostedUpgradeable('hosted'), true);
            assert.strictEqual(isHostedUpgradeable('git'), false);
            assert.strictEqual(isHostedUpgradeable('sdk'), false);
        });
    });

    describe('formatPinIntent', () => {
        it('returns null when no intent', () => {
            assert.strictEqual(formatPinIntent(null), null);
        });

        it('labels a do-not-upgrade hold', () => {
            assert.strictEqual(
                formatPinIntent({ reason: 'DO NOT BUMP', kind: 'do-not-upgrade' }),
                'Held: DO NOT BUMP',
            );
        });

        it('labels a do-not-use package', () => {
            assert.strictEqual(
                formatPinIntent({ reason: 'COMMERCIAL', kind: 'do-not-use' }),
                'Do not use: COMMERCIAL',
            );
        });
    });

    describe('formatVersionDrift', () => {
        it('returns null when no drift', () => {
            assert.strictEqual(formatVersionDrift(null), null);
            assert.strictEqual(
                formatVersionDrift({ ownConstraint: '^1', siblings: [], behind: false }),
                null,
            );
        });

        it('leads with "behind" and names the siblings', () => {
            assert.strictEqual(
                formatVersionDrift({
                    ownConstraint: '^9.7.0',
                    siblings: [{ repo: 'saropa_kykto', constraint: '^13.12.7' }],
                    behind: true,
                }),
                'behind — saropa_kykto on ^13.12.7 (you have ^9.7.0)',
            );
        });

        it('leads with "differs" when not behind', () => {
            assert.strictEqual(
                formatVersionDrift({
                    ownConstraint: '^4.0.0',
                    siblings: [{ repo: 'other', constraint: '^2.0.0' }],
                    behind: false,
                }),
                'differs — other on ^2.0.0 (you have ^4.0.0)',
            );
        });
    });
});
