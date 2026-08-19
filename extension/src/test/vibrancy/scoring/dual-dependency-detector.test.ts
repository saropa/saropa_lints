/**
 * Tests **dual-dependency-detector**: finding direct dependencies that are
 * also reachable transitively through another direct dependency — a
 * type-identity risk, not a version conflict (pub resolves one version).
 */
import * as assert from 'assert';
import {
    detectDualDependencies, attachViaConstraints,
} from '../../../vibrancy/scoring/dual-dependency-detector';
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

describe('dual-dependency-detector', () => {
    describe('detectDualDependencies', () => {
        it('flags a direct dep also required by another direct dep', () => {
            // project -> flutter_cache_manager (direct)
            // project -> cached_network_image_ce (direct) -> flutter_cache_manager
            const rev = reverse([
                ['project', 'flutter_cache_manager'],
                ['project', 'cached_network_image_ce'],
                ['cached_network_image_ce', 'flutter_cache_manager'],
            ]);
            const direct = new Map([
                ['flutter_cache_manager', '^3.4.2'],
                ['cached_network_image_ce', '^4.10.0'],
            ]);
            const risks = detectDualDependencies(direct, rev);
            assert.strictEqual(risks.length, 1);
            assert.strictEqual(risks[0].packageName, 'flutter_cache_manager');
            assert.strictEqual(risks[0].directConstraint, '^3.4.2');
            assert.strictEqual(risks[0].sources.length, 1);
            assert.strictEqual(risks[0].sources[0].viaPackage, 'cached_network_image_ce');
        });

        it('reports no risk when a direct dep is only required by the project', () => {
            const rev = reverse([
                ['project', 'flutter_cache_manager'],
                ['project', 'cached_network_image_ce'],
            ]);
            const direct = new Map([
                ['flutter_cache_manager', '^3.4.2'],
                ['cached_network_image_ce', '^4.10.0'],
            ]);
            const risks = detectDualDependencies(direct, rev);
            assert.strictEqual(risks.length, 0);
        });

        it('finds the nearest direct-dep ancestor through an intermediate transitive package', () => {
            // project -> shared_util (direct)
            // project -> wrapper (direct) -> middle (transitive) -> shared_util
            const rev = reverse([
                ['project', 'shared_util'],
                ['project', 'wrapper'],
                ['wrapper', 'middle'],
                ['middle', 'shared_util'],
            ]);
            const direct = new Map([
                ['shared_util', '^1.0.0'],
                ['wrapper', '^2.0.0'],
            ]);
            const risks = detectDualDependencies(direct, rev);
            assert.strictEqual(risks.length, 1);
            assert.strictEqual(risks[0].sources[0].viaPackage, 'wrapper');
        });

        it('is cycle-safe when the reverse graph loops back on itself', () => {
            const rev = reverse([
                ['project', 'a'],
                ['project', 'b'],
                ['a', 'b'],
                ['b', 'a'],
            ]);
            const direct = new Map([
                ['a', '^1.0.0'],
                ['b', '^2.0.0'],
            ]);
            assert.doesNotThrow(() => detectDualDependencies(direct, rev));
        });
    });

    describe('attachViaConstraints', () => {
        it('fills in the via-package declared constraint from the index', () => {
            const risks = detectDualDependencies(
                new Map([
                    ['flutter_cache_manager', '^3.4.2'],
                    ['cached_network_image_ce', '^4.10.0'],
                ]),
                reverse([
                    ['project', 'flutter_cache_manager'],
                    ['project', 'cached_network_image_ce'],
                    ['cached_network_image_ce', 'flutter_cache_manager'],
                ]),
            );
            const index = new Map([
                ['cached_network_image_ce', new Map([['flutter_cache_manager', '^3.4.1']])],
            ]);
            const attached = attachViaConstraints(risks, index);
            assert.strictEqual(attached[0].sources[0].viaConstraint, '^3.4.1');
        });

        it('leaves viaConstraint null when the index has no entry', () => {
            const risks = detectDualDependencies(
                new Map([
                    ['a', '^1.0.0'],
                    ['b', '^2.0.0'],
                ]),
                reverse([
                    ['project', 'a'],
                    ['project', 'b'],
                    ['b', 'a'],
                ]),
            );
            const attached = attachViaConstraints(risks, new Map());
            assert.strictEqual(attached[0].sources[0].viaConstraint, null);
        });
    });
});
