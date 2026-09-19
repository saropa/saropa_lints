/**
 * Tests [computeBlastRadius]: each verdict, precedence, unparseable ranges,
 * empty graph, and direct vs transitive breaker chains.
 */
import * as assert from 'assert';
import { computeBlastRadius } from '../../../vibrancy/scoring/upgrade-blast-radius';
import { HELD_BACK_UPGRADES } from '../../../vibrancy/scoring/held-back-upgrades';
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
function constraintsOf(rows: Array<[string, string, string]>): Map<string, Map<string, string>> {
    const map = new Map<string, Map<string, string>>();
    for (const [pkg, dep, range] of rows) {
        const inner = map.get(pkg) ?? new Map<string, string>();
        inner.set(dep, range);
        map.set(pkg, inner);
    }
    return map;
}

const base = {
    pkg: 'analyzer', from: '12.0.0', to: '13.1.0',
    reverseDeps: new Map<string, DepEdge[]>(),
    constraints: new Map<string, Map<string, string>>(),
    targetDeps: null,
    sdkPins: new Map<string, string>(),
    heldBack: [],
};

describe('computeBlastRadius', () => {
    it('is safe on an empty graph', () => {
        const r = computeBlastRadius(base);
        assert.strictEqual(r.verdict, 'safe');
        assert.deepStrictEqual(r.breakers, []);
        assert.strictEqual(r.sdkBlock, null);
        assert.strictEqual(r.heldBackReason, null);
    });

    it('is safe when every dependent range admits the target', () => {
        const r = computeBlastRadius({
            ...base,
            reverseDeps: reverse([['lints', 'analyzer']]),
            constraints: constraintsOf([['lints', 'analyzer', '>=12.0.0 <14.0.0']]),
        });
        assert.strictEqual(r.verdict, 'safe');
    });

    it('reports a direct dependent that caps below the target', () => {
        const r = computeBlastRadius({
            ...base,
            reverseDeps: reverse([['lints', 'analyzer'], ['app', 'lints']]),
            constraints: constraintsOf([['lints', 'analyzer', '^12.0.0']]),
        });
        assert.strictEqual(r.verdict, 'breaks-dependents');
        assert.strictEqual(r.breakers.length, 1);
        assert.strictEqual(r.breakers[0].name, 'lints');
        assert.strictEqual(r.breakers[0].constraint, '^12.0.0');
        assert.deepStrictEqual(r.breakers[0].chain, ['app', 'lints']);
        assert.strictEqual(r.summaryKey, 'blastRadius.summary.breaksOne');
        assert.strictEqual(r.summaryParams.names, 'lints');
    });

    it('has a null chain when the breaker has no ancestor', () => {
        const r = computeBlastRadius({
            ...base,
            reverseDeps: reverse([['lints', 'analyzer']]),
            constraints: constraintsOf([['lints', 'analyzer', '^12.0.0']]),
        });
        assert.strictEqual(r.breakers[0].chain, null);
    });

    it('traces a transitive breaker up to its root', () => {
        const r = computeBlastRadius({
            ...base,
            reverseDeps: reverse([
                ['c', 'analyzer'], ['b', 'c'], ['a', 'b'],
            ]),
            constraints: constraintsOf([['c', 'analyzer', '<13.0.0']]),
        });
        assert.deepStrictEqual(r.breakers[0].chain, ['a', 'b', 'c']);
    });

    it('ignores unparseable ranges', () => {
        const r = computeBlastRadius({
            ...base,
            reverseDeps: reverse([['x', 'analyzer']]),
            constraints: constraintsOf([['x', 'analyzer', 'not a range!!']]),
        });
        assert.strictEqual(r.verdict, 'safe');
    });

    it('ignores dependents with no recorded constraint', () => {
        const r = computeBlastRadius({
            ...base, reverseDeps: reverse([['x', 'analyzer']]),
        });
        assert.strictEqual(r.verdict, 'safe');
    });

    it('leaves fixedInLatest unknown (null) even when latestOf is given', () => {
        const r = computeBlastRadius({
            ...base,
            reverseDeps: reverse([['lints', 'analyzer']]),
            constraints: constraintsOf([['lints', 'analyzer', '^12.0.0']]),
            latestOf: new Map([['lints', '3.0.0']]),
        });
        assert.strictEqual(r.breakers[0].fixedInLatest, null);
    });

    it('is sdk-blocked when a target dep excludes the SDK pin', () => {
        const r = computeBlastRadius({
            ...base,
            targetDeps: new Map([['meta', '^1.18.3']]),
            sdkPins: new Map([['meta', '1.18.0']]),
        });
        assert.strictEqual(r.verdict, 'sdk-blocked');
        assert.deepStrictEqual(r.sdkBlock, {
            pkg: 'analyzer', to: '13.1.0', dep: 'meta',
            range: '^1.18.3', pinned: '1.18.0',
        });
    });

    it('is not sdk-blocked when the pin satisfies the range', () => {
        const r = computeBlastRadius({
            ...base,
            targetDeps: new Map([['meta', '^1.16.0']]),
            sdkPins: new Map([['meta', '1.18.0']]),
        });
        assert.strictEqual(r.verdict, 'safe');
    });

    it('is held-back when the seeded analyzer entry matches', () => {
        const r = computeBlastRadius({ ...base, heldBack: HELD_BACK_UPGRADES });
        assert.strictEqual(r.verdict, 'held-back');
        assert.ok(r.heldBackReason?.includes('meta'));
    });

    it('does not hold back a target outside the range or another package', () => {
        const below = computeBlastRadius({
            ...base, to: '12.5.0', heldBack: HELD_BACK_UPGRADES,
        });
        assert.strictEqual(below.verdict, 'safe');
        const other = computeBlastRadius({
            ...base, pkg: 'meta', heldBack: HELD_BACK_UPGRADES,
        });
        assert.strictEqual(other.verdict, 'safe');
    });

    it('prefers held-back over sdk-blocked and breaks-dependents', () => {
        const r = computeBlastRadius({
            ...base,
            reverseDeps: reverse([['lints', 'analyzer']]),
            constraints: constraintsOf([['lints', 'analyzer', '^12.0.0']]),
            targetDeps: new Map([['meta', '^1.18.3']]),
            sdkPins: new Map([['meta', '1.18.0']]),
            heldBack: HELD_BACK_UPGRADES,
        });
        assert.strictEqual(r.verdict, 'held-back');
        assert.ok(r.sdkBlock);
        assert.strictEqual(r.breakers.length, 1);
    });

    it('prefers sdk-blocked over breaks-dependents', () => {
        const r = computeBlastRadius({
            ...base,
            reverseDeps: reverse([['lints', 'analyzer']]),
            constraints: constraintsOf([['lints', 'analyzer', '^12.0.0']]),
            targetDeps: new Map([['meta', '^1.18.3']]),
            sdkPins: new Map([['meta', '1.18.0']]),
        });
        assert.strictEqual(r.verdict, 'sdk-blocked');
    });

    it('caret on 0.x excludes the next minor', () => {
        const r = computeBlastRadius({
            ...base, pkg: 'p', from: '0.1.0', to: '0.2.0',
            reverseDeps: reverse([['a', 'p']]),
            constraints: constraintsOf([['a', 'p', '^0.1.0']]),
        });
        assert.strictEqual(r.verdict, 'breaks-dependents');
    });

    it('prerelease target is not treated as its release version', () => {
        const r = computeBlastRadius({
            ...base, pkg: 'p', from: '1.0.0', to: '2.0.0-dev.1',
            reverseDeps: reverse([['a', 'p']]),
            constraints: constraintsOf([['a', 'p', '>=2.0.0 <3.0.0']]),
        });
        assert.strictEqual(r.verdict, 'breaks-dependents');
    });

    it('treats `any` and unparseable constraints as non-breaking', () => {
        for (const c of ['any', 'garbage']) {
            const r = computeBlastRadius({
                ...base,
                reverseDeps: reverse([['a', 'analyzer']]),
                constraints: constraintsOf([['a', 'analyzer', c]]),
            });
            assert.strictEqual(r.verdict, 'safe', c);
        }
    });
});

describe('dependency-held-back verdict', () => {
    const drift = {
        ...base, pkg: 'drift_dev', from: '2.28.0', to: '2.30.0',
        targetDeps: new Map([['analyzer', '^13.0.0']]),
        heldBack: HELD_BACK_UPGRADES,
    };

    it('blocks drift_dev needing analyzer ^13 when analyzer is held back', () => {
        const r = computeBlastRadius(drift);
        assert.strictEqual(r.verdict, 'dependency-held-back');
        assert.strictEqual(r.summaryKey, 'blastRadius.summary.depHeldBack');
        assert.strictEqual(r.summaryParams.dep, 'analyzer');
        assert.strictEqual(r.summaryParams.range, '^13.0.0');
    });

    it('is safe when analyzer is not held back', () => {
        assert.strictEqual(computeBlastRadius({ ...drift, heldBack: [] }).verdict, 'safe');
    });

    it('is safe when the lock already satisfies the range', () => {
        const r = computeBlastRadius({
            ...drift, lockedVersions: new Map([['analyzer', '13.2.0']]),
        });
        assert.strictEqual(r.verdict, 'safe');
    });

    it('is safe when the range needs an older analyzer', () => {
        const r = computeBlastRadius({ ...drift, targetDeps: new Map([['analyzer', '>=12.0.0 <13.0.0']]) });
        assert.strictEqual(r.verdict, 'safe');
    });

    it('self held-back outranks it', () => {
        const r = computeBlastRadius({
            ...drift,
            heldBack: [...HELD_BACK_UPGRADES, { pkg: 'drift_dev', range: '>=2.30.0', reason: 'x' }],
        });
        assert.strictEqual(r.verdict, 'held-back');
    });
});

describe('dependency-capped verdict (data-driven)', () => {
    const drift = {
        ...base, pkg: 'drift_dev', from: '2.28.0', to: '2.35.0',
        targetDeps: new Map([['analyzer', '>=13.0.0']]),
        reverseDeps: reverse([['drift_dev', 'analyzer'], ['saropa_lints', 'analyzer']]),
        constraints: constraintsOf([
            ['drift_dev', 'analyzer', '>=12.0.0 <13.0.0'],
            ['saropa_lints', 'analyzer', '<13.0.0'],
        ]),
        lockedVersions: new Map([['analyzer', '12.1.0']]),
        heldBack: HELD_BACK_UPGRADES,
    };

    it('blocks and names the capper', () => {
        const r = computeBlastRadius(drift);
        assert.strictEqual(r.verdict, 'dependency-capped');
        assert.strictEqual(r.summaryKey, 'blastRadius.summary.depCapped');
        assert.strictEqual(r.depCapped?.dep, 'analyzer');
        assert.deepStrictEqual(r.depCapped?.cappers.map(c => c.name), ['saropa_lints']);
        assert.ok(String(r.summaryParams.cappers).includes('saropa_lints <13.0.0'));
    });

    it('is not blocked by data when nothing caps analyzer (curated fallback ignored)', () => {
        const r = computeBlastRadius({
            ...drift,
            reverseDeps: reverse([['drift_dev', 'analyzer']]),
            constraints: constraintsOf([['drift_dev', 'analyzer', '>=12.0.0 <13.0.0']]),
        });
        assert.strictEqual(r.verdict, 'safe');
    });

    it('is safe when the lock already satisfies the range', () => {
        const r = computeBlastRadius({
            ...drift, lockedVersions: new Map([['analyzer', '13.2.0']]),
        });
        assert.strictEqual(r.verdict, 'safe');
    });

    it('curated list still decides when the lock has no entry for the dep', () => {
        const r = computeBlastRadius({
            ...drift, lockedVersions: new Map([['other', '1.0.0']]),
            reverseDeps: reverse([]), constraints: constraintsOf([]),
        });
        assert.strictEqual(r.verdict, 'dependency-held-back');
    });

    it('sdk-blocked outranks it', () => {
        const r = computeBlastRadius({
            ...drift, targetDeps: new Map([['analyzer', '>=13.0.0'], ['meta', '^1.18.3']]),
            sdkPins: new Map([['meta', '1.18.0']]),
        });
        assert.strictEqual(r.verdict, 'sdk-blocked');
    });

    it('self curated entry is skipped when target deps and lock are known', () => {
        const r = computeBlastRadius({
            ...base, targetDeps: new Map([['meta', '^1.18.3']]),
            lockedVersions: new Map([['meta', '1.18.3']]), heldBack: HELD_BACK_UPGRADES,
        });
        assert.strictEqual(r.verdict, 'safe');
    });
});

describe('computeBlastRadius: capper edge cases', () => {
    const capped = {
        ...base, targetDeps: new Map([['meta', '>=1.18.3']]),
        lockedVersions: new Map([['meta', '1.18.0']]),
        reverseDeps: reverse([['a', 'meta'], ['b', 'meta']]),
        constraints: constraintsOf([['a', 'meta', '^1.18.0'], ['b', 'meta', '<1.18.2']]),
    };
    it('names only the capper whose range excludes the need', () => {
        const r = computeBlastRadius(capped);
        assert.strictEqual(r.verdict, 'dependency-capped');
        assert.deepStrictEqual(r.depCapped?.cappers.map(c => c.name), ['b']);
    });
    it('dependency_overrides on the dep bypasses the cap', () => {
        const r = computeBlastRadius({ ...capped, overrides: new Set(['meta']) });
        assert.strictEqual(r.verdict, 'safe');
    });
    it('a lock ABOVE the needed range is not a cap', () => {
        const r = computeBlastRadius({
            ...capped, targetDeps: new Map([['meta', '^1.10.0']]),
            lockedVersions: new Map([['meta', '2.0.0']]),
            constraints: constraintsOf([['b', 'meta', '^0.9.0']]),
        });
        assert.notStrictEqual(r.verdict, 'dependency-capped');
    });
    it('treats pub `any` as unconstrained', () => {
        const r = computeBlastRadius({
            ...capped, constraints: constraintsOf([['a', 'meta', 'any'], ['b', 'meta', 'any']]),
        });
        assert.strictEqual(r.verdict, 'safe');
    });
    it('handles a ^x-0 prerelease caret and 0.x caret', () => {
        const r = computeBlastRadius({
            ...capped, targetDeps: new Map([['meta', '^13.0.0-0']]),
            lockedVersions: new Map([['meta', '12.0.0']]),
            constraints: constraintsOf([['b', 'meta', '^0.3.14']]),
        });
        assert.strictEqual(r.verdict, 'dependency-capped');
    });
    it('overriding the upgraded package removes its breakers', () => {
        const r = computeBlastRadius({
            ...base, reverseDeps: reverse([['lints', 'analyzer']]),
            constraints: constraintsOf([['lints', 'analyzer', '^12.0.0']]),
            overrides: new Set(['analyzer']),
        });
        assert.strictEqual(r.verdict, 'safe');
    });
    it('flags a safe verdict reached without target deps as unverified', () => {
        assert.strictEqual(computeBlastRadius(base).unverified, true);
        assert.strictEqual(
            computeBlastRadius({ ...base, targetDeps: new Map() }).unverified, false);
    });
});
