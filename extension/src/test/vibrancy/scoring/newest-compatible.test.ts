/** Tests lock completeness and newest-compatible search (fixtures, no network). */
import '../register-vscode-mock';
import * as assert from 'assert';
import { attachBlastRadius, describeBlastSummary } from '../../../vibrancy/scoring/blast-radius-attacher';
import { VersionCandidate } from '../../../vibrancy/scoring/upgrade-blast-radius';
import { parseVersionList, fetchVersionList } from '../../../vibrancy/services/upgrade-target-deps';
import { DepEdge, VibrancyResult } from '../../../vibrancy/types';

function res(name: string, cur: string, latest: string): VibrancyResult {
    return {
        package: { name, version: cur, constraint: `^${cur}`, source: 'hosted', isDirect: true, section: 'dependencies' },
        updateInfo: { currentVersion: cur, latestVersion: latest, updateStatus: 'major', changelog: null },
    } as unknown as VibrancyResult;
}
const v = (version: string, deps: Record<string, string>, retracted = false): VersionCandidate =>
    ({ version, deps: new Map(Object.entries(deps)), retracted });

const reverse = new Map<string, DepEdge[]>();
const constraints = new Map<string, Map<string, string>>();
const held = [{ pkg: 'analyzer', range: '>=13.0.0', reason: 'needs meta ^1.18.3' }] as any;

describe('newest compatible + full lock', () => {
    const versions = [
        v('2.30.0', { analyzer: '^13.0.0' }),
        v('2.29.0-beta', { analyzer: '>=12.0.0 <13.0.0' }),
        v('2.28.1', { analyzer: '>=12.0.0 <13.0.0' }),
        v('2.28.0', { analyzer: '>=12.0.0 <13.0.0' }, true),
        v('2.20.0', { analyzer: '>=11.0.0 <12.0.0' }),
        v('2.0.0', { analyzer: '>=10.0.0 <11.0.0' }),
    ];

    it('drift_dev: latest held back, newest compatible 2.28.1', () => {
        const [r] = attachBlastRadius([res('drift_dev', '2.0.0', '2.30.0')], {
            reverseDeps: reverse, constraints, heldBack: held,
            targetDepsOf: () => new Map([['analyzer', '^13.0.0']]),
            versionsOf: () => versions,
        });
        assert.strictEqual(r.blastRadius?.verdict, 'dependency-held-back');
        assert.strictEqual(r.blastRadius?.newestCompatible, '2.28.1');
        assert.ok(describeBlastSummary(r.blastRadius!).includes('2.28.1'));
    });

    it('no compatible release -> field unset; missing list fails soft', () => {
        const only = [v('2.30.0', { analyzer: '^13.0.0' })];
        const ctx = { reverseDeps: reverse, constraints, heldBack: held,
            targetDepsOf: () => new Map([['analyzer', '^13.0.0']]) };
        const [a] = attachBlastRadius([res('drift_dev', '2.0.0', '2.30.0')], { ...ctx, versionsOf: () => only });
        assert.strictEqual(a.blastRadius?.newestCompatible, undefined);
        const [b] = attachBlastRadius([res('drift_dev', '2.0.0', '2.30.0')], { ...ctx, versionsOf: () => null });
        assert.strictEqual(b.blastRadius?.newestCompatible, undefined);
    });

    it('transitive lock satisfying the range avoids a false block', () => {
        const ctx = { reverseDeps: reverse, constraints, heldBack: held,
            targetDepsOf: () => new Map([['analyzer', '^13.0.0']]) };
        const [blocked] = attachBlastRadius([res('drift_dev', '2.0.0', '2.30.0')], ctx);
        assert.strictEqual(blocked.blastRadius?.verdict, 'dependency-held-back');
        const [ok] = attachBlastRadius([res('drift_dev', '2.0.0', '2.30.0')],
            { ...ctx, lockedVersions: new Map([['analyzer', '13.1.0']]) });
        assert.strictEqual(ok.blastRadius?.verdict, 'safe');
    });

    it('parseVersionList keeps string deps and retracted flag', () => {
        const l = parseVersionList({ versions: [
            { version: '1.0.0', pubspec: { dependencies: { a: '^1.0.0', s: { sdk: 'flutter' } } } },
            { version: '1.1.0', retracted: true },
        ] })!;
        assert.deepStrictEqual([...l[0].deps], [['a', '^1.0.0']]);
        assert.strictEqual(l[1].retracted, true);
        assert.strictEqual(parseVersionList({}), null);
    });

    it('fetchVersionList uses the cache and fails soft', async () => {
        const store = new Map<string, unknown>([['pub.versionList.x',
            [{ version: '1.0.0', deps: { a: '^1.0.0' } }]]]);
        const cache = { get: (k: string) => store.get(k) ?? null, set: async () => undefined } as any;
        const l = await fetchVersionList('x', cache);
        assert.strictEqual(l![0].deps.get('a'), '^1.0.0');
    });
});
