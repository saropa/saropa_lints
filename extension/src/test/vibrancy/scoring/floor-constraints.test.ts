/**
 * Tests [findFloorConstrainer] and [formatFloorRequirement]: detection of
 * required-minimum (floor) constraints forcing a dependency up to a version.
 */
import * as assert from 'assert';
import {
    findFloorConstrainer, formatFloorRequirement,
} from '../../../vibrancy/scoring/floor-constraints';
import { ConstraintIndex } from '../../../vibrancy/scoring/shared-dep-conflict-detector';
import { DepEdge } from '../../../vibrancy/types';

/** Reverse-dep map (dep -> dependents) from `dependent: dep` pairs. */
function reverse(edges: Array<[string, string]>): Map<string, DepEdge[]> {
    const map = new Map<string, DepEdge[]>();
    for (const [dependent, dep] of edges) {
        const list = map.get(dep) ?? [];
        list.push({ dependentPackage: dependent });
        map.set(dep, list);
    }
    return map;
}

/** Constraint index from `[pkg, dep, range]` triples. */
function index(triples: Array<[string, string, string]>): ConstraintIndex {
    const map = new Map<string, Map<string, string>>();
    for (const [pkg, dep, range] of triples) {
        const inner = map.get(pkg) ?? new Map<string, string>();
        inner.set(dep, range);
        map.set(pkg, inner);
    }
    return map;
}

describe('floor-constraints', () => {
    describe('findFloorConstrainer', () => {
        it('reports the floor a git dep forces (device_calendar -> timezone)', () => {
            // device_calendar (a direct git dep) requires timezone ^0.11.0, so
            // timezone is forced up to 0.11.0. The detector names the constrainer.
            const rev = reverse([['device_calendar', 'timezone']]);
            const idx = index([['device_calendar', 'timezone', '^0.11.0']]);

            const floor = findFloorConstrainer(
                'timezone', rev, idx, new Set(['device_calendar']),
            );

            assert.ok(floor);
            assert.strictEqual(floor!.constrainer, 'device_calendar');
            assert.strictEqual(floor!.constraint, '^0.11.0');
            assert.strictEqual(floor!.floorVersion, '0.11.0');
            assert.strictEqual(floor!.chain, null);
        });

        it('picks the dependent with the highest lower bound', () => {
            const rev = reverse([
                ['a', 'timezone'],
                ['b', 'timezone'],
            ]);
            const idx = index([
                ['a', 'timezone', '^0.9.0'],
                ['b', 'timezone', '^0.11.0'],
            ]);

            const floor = findFloorConstrainer(
                'timezone', rev, idx, new Set(['a', 'b']),
            );

            assert.strictEqual(floor!.constrainer, 'b');
            assert.strictEqual(floor!.floorVersion, '0.11.0');
        });

        it('returns null when no dependent declares a lower-bounded constraint', () => {
            const rev = reverse([['a', 'timezone']]);
            const idx = index([['a', 'timezone', 'any']]);

            const floor = findFloorConstrainer(
                'timezone', rev, idx, new Set(['a']),
            );

            assert.strictEqual(floor, null);
        });

        it('returns null when the constrainer constraint is unreadable', () => {
            const rev = reverse([['a', 'timezone']]);
            const floor = findFloorConstrainer(
                'timezone', rev, index([]), new Set(['a']),
            );
            assert.strictEqual(floor, null);
        });

        it('attaches the chain when the constrainer is a deep transitive dep', () => {
            // direct -> mid -> deep, and deep requires timezone ^0.11.0.
            const rev = reverse([
                ['direct', 'mid'],
                ['mid', 'deep'],
                ['deep', 'timezone'],
            ]);
            const idx = index([['deep', 'timezone', '^0.11.0']]);

            const floor = findFloorConstrainer(
                'timezone', rev, idx, new Set(['direct']),
            );

            assert.strictEqual(floor!.constrainer, 'deep');
            assert.deepStrictEqual(floor!.chain, ['direct', 'mid', 'deep']);
        });
    });

    describe('formatFloorRequirement', () => {
        it('names the constrainer and constraint', () => {
            const text = formatFloorRequirement({
                dependency: 'timezone', constrainer: 'device_calendar',
                constraint: '^0.11.0', floorVersion: '0.11.0', chain: null,
            });
            assert.strictEqual(text, 'required by device_calendar (^0.11.0)');
        });

        it('appends the chain for a deep transitive constrainer', () => {
            const text = formatFloorRequirement({
                dependency: 'timezone', constrainer: 'deep',
                constraint: '^0.11.0', floorVersion: '0.11.0',
                chain: ['direct', 'mid', 'deep'],
            });
            assert.strictEqual(
                text, 'required by deep (^0.11.0) [via direct → mid → deep]',
            );
        });
    });
});
