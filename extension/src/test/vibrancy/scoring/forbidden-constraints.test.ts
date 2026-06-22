/**
 * Tests [detectForbiddenConstraints] and [formatForbiddenConstraint]: the
 * hard-incompatibility class where a declared constraint excludes an SDK pin.
 */
import * as assert from 'assert';
import {
    detectForbiddenConstraints, formatForbiddenConstraint,
} from '../../../vibrancy/scoring/forbidden-constraints';
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

describe('forbidden-constraints', () => {
    describe('detectForbiddenConstraints', () => {
        it('flags a declared constraint that excludes the SDK-pinned version', () => {
            // characters ^1.4.1 declared, but flutter_test pins 1.4.0 — pub
            // calls flutter_test forbidden; only an override holds this together.
            const direct = new Map([['characters', '^1.4.1']]);
            const resolved = new Map([['characters', '1.4.0']]);
            const rev = reverse([['flutter_test', 'characters']]);
            const sdk = new Set(['flutter_test']);

            const result = detectForbiddenConstraints(direct, resolved, rev, sdk);

            assert.strictEqual(result.length, 1);
            assert.strictEqual(result[0].package, 'characters');
            assert.strictEqual(result[0].declaredConstraint, '^1.4.1');
            assert.strictEqual(result[0].pinnedVersion, '1.4.0');
            assert.strictEqual(result[0].pinnedBy, 'flutter_test');
        });

        it('does not flag when the declared constraint permits the pinned version', () => {
            const direct = new Map([['characters', '^1.4.0']]);
            const resolved = new Map([['characters', '1.4.0']]);
            const rev = reverse([['flutter_test', 'characters']]);
            const sdk = new Set(['flutter_test']);

            assert.deepStrictEqual(
                detectForbiddenConstraints(direct, resolved, rev, sdk), [],
            );
        });

        it('does not flag when no SDK package pins the dependency', () => {
            // A hosted-only mismatch cannot produce a resolved-yet-excluded
            // state, so it is not attributed here.
            const direct = new Map([['characters', '^1.4.1']]);
            const resolved = new Map([['characters', '1.4.0']]);
            const rev = reverse([['some_lib', 'characters']]);
            const sdk = new Set(['flutter_test']);

            assert.deepStrictEqual(
                detectForbiddenConstraints(direct, resolved, rev, sdk), [],
            );
        });

        it('does not flag an unparseable or any constraint', () => {
            const direct = new Map([['characters', 'any']]);
            const resolved = new Map([['characters', '1.4.0']]);
            const rev = reverse([['flutter_test', 'characters']]);
            const sdk = new Set(['flutter_test']);

            assert.deepStrictEqual(
                detectForbiddenConstraints(direct, resolved, rev, sdk), [],
            );
        });

        it('skips a package with no resolved version', () => {
            const direct = new Map([['characters', '^1.4.1']]);
            const rev = reverse([['flutter_test', 'characters']]);
            const sdk = new Set(['flutter_test']);

            assert.deepStrictEqual(
                detectForbiddenConstraints(direct, new Map(), rev, sdk), [],
            );
        });
    });

    describe('formatForbiddenConstraint', () => {
        it('mirrors pub\'s incompatibility phrasing', () => {
            const text = formatForbiddenConstraint({
                package: 'characters', declaredConstraint: '^1.4.1',
                pinnedVersion: '1.4.0', pinnedBy: 'flutter_test',
            });
            assert.strictEqual(
                text,
                'your characters ^1.4.1 is incompatible with flutter_test '
                + '(Flutter SDK), which pins characters 1.4.0',
            );
        });
    });
});
