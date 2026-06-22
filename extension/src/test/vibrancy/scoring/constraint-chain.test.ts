/**
 * Tests [pathToDirectDep] and [formatChain]: the multi-hop walk from a deep
 * constrainer up to a user-actionable direct dependency.
 */
import * as assert from 'assert';
import { pathToDirectDep, formatChain } from '../../../vibrancy/scoring/constraint-chain';
import { DepEdge } from '../../../vibrancy/types';

/** Build a reverse-dep map (dep -> dependents) from `dependent: dep` pairs. */
function reverse(edges: Array<[string, string]>): Map<string, DepEdge[]> {
    const map = new Map<string, DepEdge[]>();
    for (const [dependent, dep] of edges) {
        const list = map.get(dep) ?? [];
        list.push({ dependentPackage: dependent });
        map.set(dep, list);
    }
    return map;
}

describe('constraint-chain', () => {
    describe('pathToDirectDep', () => {
        it('returns the single node when start is already a direct dep', () => {
            const rev = reverse([]);
            const chain = pathToDirectDep('dart_style', rev, new Set(['dart_style']));
            assert.deepStrictEqual(chain, ['dart_style']);
        });

        it('walks multiple hops to the nearest direct dep (A -> B -> C)', () => {
            // C constrains analyzer; A is the direct dep that pulls in B -> C.
            // The walk connects the deep constrainer C to the editable line A.
            const rev = reverse([
                ['A', 'B'], // A depends on B
                ['B', 'C'], // B depends on C
                ['C', 'analyzer'], // C depends on analyzer
            ]);
            const chain = pathToDirectDep('C', rev, new Set(['A']));
            assert.deepStrictEqual(chain, ['A', 'B', 'C']);
        });

        it('returns the shortest chain when two direct deps reach the start', () => {
            // Both A (1 hop) and X -> Y (2 hops) pull in C; BFS picks A.
            const rev = reverse([
                ['A', 'C'],
                ['X', 'Y'],
                ['Y', 'C'],
            ]);
            const chain = pathToDirectDep('C', rev, new Set(['A', 'X']));
            assert.deepStrictEqual(chain, ['A', 'C']);
        });

        it('returns the single node when no direct ancestor exists', () => {
            const rev = reverse([['B', 'C']]); // B is transitive, not direct
            const chain = pathToDirectDep('C', rev, new Set(['unrelated']));
            assert.deepStrictEqual(chain, ['C']);
        });

        it('does not loop on a dependency cycle', () => {
            // A -> B -> A cycle with no direct dep; must terminate, not hang.
            const rev = reverse([
                ['A', 'B'],
                ['B', 'A'],
            ]);
            const chain = pathToDirectDep('A', rev, new Set(['none']));
            assert.deepStrictEqual(chain, ['A']);
        });
    });

    describe('formatChain', () => {
        it('joins a multi-node chain with arrows', () => {
            assert.strictEqual(formatChain(['A', 'B', 'C']), 'A → B → C');
        });

        it('returns null for a single-node chain', () => {
            assert.strictEqual(formatChain(['A']), null);
        });

        it('returns null for an empty chain', () => {
            assert.strictEqual(formatChain([]), null);
        });
    });
});
