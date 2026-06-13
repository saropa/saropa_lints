/**
 * Tests [detectSharedDepConflicts]: diamond / shared-transitive-dependency
 * blocks the reverse-dependency walk cannot see. The canonical case is
 * `dart_style` held back because a sibling (`saropa_lints`) caps the shared
 * transitive dep `analyzer` below the version `dart_style` needs at its latest.
 */
import * as assert from 'assert';
import {
    detectSharedDepConflicts, ConstraintIndex,
} from '../../../vibrancy/scoring/shared-dep-conflict-detector';
import { PubOutdatedEntry, DepEdge } from '../../../vibrancy/types';

/** Builds a [PubOutdatedEntry]; override per case. */
function entry(o: Partial<PubOutdatedEntry> & { package: string }): PubOutdatedEntry {
    return {
        current: '1.0.0', upgradable: '1.0.0',
        resolvable: '1.0.0', latest: '1.0.0', ...o,
    };
}

/** Reverse deps: dep -> packages that depend on it. */
function reverse(map: Record<string, string[]>): Map<string, DepEdge[]> {
    return new Map(Object.entries(map).map(([dep, dependents]) => [
        dep, dependents.map(p => ({ dependentPackage: p })),
    ]));
}

/** Constraint index: pkg -> (dep -> range). */
function constraints(
    map: Record<string, Record<string, string>>,
): ConstraintIndex {
    return new Map(Object.entries(map).map(([pkg, deps]) => [
        pkg, new Map(Object.entries(deps)),
    ]));
}

describe('shared-dep-conflict-detector', () => {
    describe('detectSharedDepConflicts', () => {
        it('attributes the dart_style/analyzer/saropa_lints diamond', () => {
            const outdated = [
                entry({
                    package: 'dart_style', current: '3.1.7',
                    resolvable: '3.1.7', latest: '3.1.8',
                }),
                entry({
                    package: 'analyzer', current: '12.0.0',
                    resolvable: '12.0.0', latest: '13.1.0',
                }),
            ];
            const reverseDeps = reverse({
                analyzer: ['dart_style', 'saropa_lints'],
            });
            const constraintIndex = constraints({
                saropa_lints: { analyzer: '>=9.0.0 <13.0.0' },
                dart_style: { analyzer: '^12.0.0' },
            });
            const direct = new Set(['dart_style', 'saropa_lints']);

            const conflicts = detectSharedDepConflicts(
                outdated, reverseDeps, constraintIndex, direct,
            );

            assert.strictEqual(conflicts.length, 1);
            const c = conflicts[0];
            assert.strictEqual(c.blockedPackage, 'dart_style');
            assert.strictEqual(c.sharedDependency, 'analyzer');
            assert.strictEqual(c.constrainerPackage, 'saropa_lints');
            assert.strictEqual(c.constrainerConstraint, '>=9.0.0 <13.0.0');
            assert.strictEqual(c.sharedResolvable, '12.0.0');
            assert.strictEqual(c.sharedLatest, '13.1.0');
        });

        it('ignores shared deps that are not blocked', () => {
            const outdated = [
                entry({
                    package: 'dart_style', current: '3.1.7',
                    resolvable: '3.1.7', latest: '3.1.8',
                }),
                // analyzer up-to-date — not a contested pivot.
                entry({
                    package: 'analyzer', current: '13.1.0',
                    resolvable: '13.1.0', latest: '13.1.0',
                }),
            ];
            const conflicts = detectSharedDepConflicts(
                outdated,
                reverse({ analyzer: ['dart_style', 'saropa_lints'] }),
                constraints({ saropa_lints: { analyzer: '>=9.0.0 <13.0.0' } }),
                new Set(['dart_style', 'saropa_lints']),
            );
            assert.deepStrictEqual(conflicts, []);
        });

        it('ignores deps with a single dependent (not a diamond)', () => {
            const outdated = [
                entry({
                    package: 'analyzer', current: '12.0.0',
                    resolvable: '12.0.0', latest: '13.1.0',
                }),
                entry({
                    package: 'dart_style', current: '3.1.7',
                    resolvable: '3.1.7', latest: '3.1.8',
                }),
            ];
            const conflicts = detectSharedDepConflicts(
                outdated,
                reverse({ analyzer: ['dart_style'] }),
                constraints({ dart_style: { analyzer: '^12.0.0' } }),
                new Set(['dart_style']),
            );
            assert.deepStrictEqual(conflicts, []);
        });

        it('skips a sibling whose constraint already allows the latest', () => {
            // other_pkg permits analyzer 13 — it is not the binding ceiling,
            // and no sibling caps it, so there is no attributable blocker.
            const outdated = [
                entry({
                    package: 'dart_style', current: '3.1.7',
                    resolvable: '3.1.7', latest: '3.1.8',
                }),
                entry({
                    package: 'analyzer', current: '12.0.0',
                    resolvable: '12.0.0', latest: '13.1.0',
                }),
            ];
            const conflicts = detectSharedDepConflicts(
                outdated,
                reverse({ analyzer: ['dart_style', 'other_pkg'] }),
                constraints({ other_pkg: { analyzer: '>=9.0.0 <14.0.0' } }),
                new Set(['dart_style', 'other_pkg']),
            );
            assert.deepStrictEqual(conflicts, []);
        });

        it('prefers a direct sibling over a transitive constrainer', () => {
            const outdated = [
                entry({
                    package: 'dart_style', current: '3.1.7',
                    resolvable: '3.1.7', latest: '3.1.8',
                }),
                entry({
                    package: 'analyzer', current: '12.0.0',
                    resolvable: '12.0.0', latest: '13.1.0',
                }),
            ];
            const conflicts = detectSharedDepConflicts(
                outdated,
                reverse({
                    analyzer: ['dart_style', 'transitive_capper', 'saropa_lints'],
                }),
                constraints({
                    transitive_capper: { analyzer: '>=9.0.0 <13.0.0' },
                    saropa_lints: { analyzer: '>=9.0.0 <13.0.0' },
                }),
                new Set(['dart_style', 'saropa_lints']),
            );
            assert.strictEqual(conflicts.length, 1);
            assert.strictEqual(conflicts[0].constrainerPackage, 'saropa_lints');
        });

        it('returns empty with no constraint data', () => {
            const outdated = [
                entry({
                    package: 'dart_style', current: '3.1.7',
                    resolvable: '3.1.7', latest: '3.1.8',
                }),
                entry({
                    package: 'analyzer', current: '12.0.0',
                    resolvable: '12.0.0', latest: '13.1.0',
                }),
            ];
            const conflicts = detectSharedDepConflicts(
                outdated,
                reverse({ analyzer: ['dart_style', 'saropa_lints'] }),
                new Map(),
                new Set(['dart_style', 'saropa_lints']),
            );
            assert.deepStrictEqual(conflicts, []);
        });
    });
});
