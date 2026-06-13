/**
 * Tests [detectVersionDrift]: flagging a package pinned at a different major in
 * a configured sibling repo. The canonical case is saropa_lints `^9.7.0` in one
 * project vs `^13.12.7` in a sibling — an implicit, uncommented upgrade blocker
 * pub-outdated cannot see because it only scans one workspace.
 */
import * as assert from 'assert';
import {
    detectVersionDrift, SiblingConstraints,
} from '../../../vibrancy/scoring/cross-project-drift-detector';

/** Result candidate: name + this project's constraint. */
function res(name: string, constraint: string) {
    return { package: { name, constraint } };
}

/** Sibling constraint maps: repo -> (pkg -> constraint). */
function siblings(
    map: Record<string, Record<string, string>>,
): SiblingConstraints {
    return new Map(Object.entries(map).map(([repo, deps]) => [
        repo, new Map(Object.entries(deps)),
    ]));
}

describe('cross-project-drift-detector', () => {
    it('flags a package lagging a sibling major as behind', () => {
        const drift = detectVersionDrift(
            [res('saropa_lints', '^9.7.0')],
            siblings({ saropa_kykto: { saropa_lints: '^13.12.7' } }),
        );
        const d = drift.get('saropa_lints');
        assert.ok(d);
        assert.strictEqual(d!.behind, true);
        assert.strictEqual(d!.ownConstraint, '^9.7.0');
        assert.deepStrictEqual(d!.siblings, [
            { repo: 'saropa_kykto', constraint: '^13.12.7' },
        ]);
    });

    it('flags a divergent-but-ahead sibling as not behind', () => {
        const drift = detectVersionDrift(
            [res('foo', '^4.0.0')],
            siblings({ other: { foo: '^2.0.0' } }),
        );
        const d = drift.get('foo');
        assert.ok(d);
        assert.strictEqual(d!.behind, false);
    });

    it('ignores siblings on the same major', () => {
        const drift = detectVersionDrift(
            [res('foo', '^4.1.0')],
            siblings({ other: { foo: '^4.9.0' } }),
        );
        assert.strictEqual(drift.get('foo'), undefined);
    });

    it('ignores packages the sibling does not declare', () => {
        const drift = detectVersionDrift(
            [res('foo', '^1.0.0')],
            siblings({ other: { bar: '^2.0.0' } }),
        );
        assert.strictEqual(drift.get('foo'), undefined);
    });

    it('collects multiple divergent siblings', () => {
        const drift = detectVersionDrift(
            [res('foo', '^1.0.0')],
            siblings({
                a: { foo: '^2.0.0' },
                b: { foo: '^3.0.0' },
                c: { foo: '^1.5.0' }, // same major — excluded
            }),
        );
        const d = drift.get('foo');
        assert.ok(d);
        assert.strictEqual(d!.siblings.length, 2);
        assert.strictEqual(d!.behind, true);
    });

    it('returns empty when no siblings configured', () => {
        const drift = detectVersionDrift([res('foo', '^1.0.0')], new Map());
        assert.strictEqual(drift.size, 0);
    });

    it('skips uncoercible own constraints (git/path/sdk)', () => {
        const drift = detectVersionDrift(
            [res('foo', 'any')],
            siblings({ other: { foo: '^2.0.0' } }),
        );
        assert.strictEqual(drift.get('foo'), undefined);
    });
});
