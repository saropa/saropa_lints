/** Tests target-version dependency fetch (fixtures, no network) and SDK pin derivation. */
import * as assert from 'assert';
import { parseTargetDeps, fetchTargetDeps, fetchTargetDepsFor, parseVersionList, fetchVersionListsFor } from '../../../vibrancy/services/upgrade-target-deps';
import { parseExactPins, parseLockedVersions, mergePins, deriveSdkPins } from '../../../vibrancy/services/sdk-pins';
import { attachBlastRadius } from '../../../vibrancy/scoring/blast-radius-attacher';
import { DepEdge, VibrancyResult } from '../../../vibrancy/types';

const analyzer13Response = {
    version: '13.1.0',
    pubspec: { dependencies: { meta: '^1.18.3', path: '^1.9.0', sdk_thing: { sdk: 'dart' } } },
};
const flutterPubspec = `name: flutter
dependencies:
  characters: ^1.4.0
  meta: 1.18.0
  collection: 1.19.1 # pinned
  sky_engine:
    sdk: flutter
dev_dependencies:
  foo: 9.9.9
`;
const lock = `packages:
  meta:
    dependency: transitive
    description:
      name: meta
    source: hosted
    version: "1.18.0"
`;

function res(name: string, cur: string, latest: string): VibrancyResult {
    return {
        package: { name, version: cur, constraint: `^${cur}`, source: 'hosted', isDirect: true, section: 'dependencies' },
        updateInfo: { currentVersion: cur, latestVersion: latest, updateStatus: 'major', changelog: null },
    } as unknown as VibrancyResult;
}

describe('parseTargetDeps', () => {
    it('keeps string ranges, drops sdk maps, null when absent', () => {
        const m = parseTargetDeps(analyzer13Response)!;
        assert.strictEqual(m.get('meta'), '^1.18.3');
        assert.ok(!m.has('sdk_thing'));
        assert.strictEqual(parseTargetDeps({}), null);
    });
    it('empty map when pubspec has no dependencies; null when retracted', () => {
        const m = parseTargetDeps({ pubspec: { name: 'meta' } });
        assert.ok(m && m.size === 0);
        assert.strictEqual(parseTargetDeps({ retracted: true, pubspec: { dependencies: { a: '^1.0.0' } } }), null);
    });
});

describe('fetchTargetDeps empty/retracted', () => {
    const realFetch = global.fetch;
    afterEach(() => { global.fetch = realFetch; });
    it('caches an empty dependency map; does not cache retracted', async () => {
        let calls = 0;
        let body: unknown = { pubspec: { name: 'meta' } };
        global.fetch = (async () => { calls++; return { ok: true, status: 200, json: async () => body }; }) as any;
        const store = new Map<string, unknown>();
        const cache: any = { get: (k: string) => store.get(k), set: async (k: string, v: unknown) => { store.set(k, v); } };
        assert.strictEqual((await fetchTargetDeps('meta', '1.18.3', cache))!.size, 0);
        await fetchTargetDeps('meta', '1.18.3', cache);
        assert.strictEqual(calls, 1);
        body = { retracted: true, pubspec: { dependencies: {} } };
        assert.strictEqual(await fetchTargetDeps('bad', '1.0.0', cache), null);
        assert.ok(!store.has('pub.targetDeps.bad@1.0.0'));
    });
});

describe('sdk pins semantics', () => {
    it('caret/range SDK deps are not pins', () => {
        const y = 'dependencies:\n  meta: ^1.18.3\n  collection: 1.19.1\n  vm: ">=1.0.0 <2.0.0"\n';
        assert.deepStrictEqual([...parseExactPins(y)], [['collection', '1.19.1']]);
    });
});

describe('fetchTargetDeps', () => {
    const realFetch = global.fetch;
    afterEach(() => { global.fetch = realFetch; });
    it('parses response, caches per pkg@version, fails soft', async () => {
        let calls = 0;
        global.fetch = (async (url: string) => {
            calls++;
            assert.ok(url.endsWith('/api/packages/analyzer/versions/13.1.0'));
            return { ok: true, status: 200, json: async () => analyzer13Response };
        }) as any;
        const store = new Map<string, unknown>();
        const cache: any = { get: (k: string) => store.get(k), set: async (k: string, v: unknown) => { store.set(k, v); } };
        assert.strictEqual((await fetchTargetDeps('analyzer', '13.1.0', cache))!.get('meta'), '^1.18.3');
        await fetchTargetDeps('analyzer', '13.1.0', cache);
        assert.strictEqual(calls, 1);
        assert.ok(store.has('pub.targetDeps.analyzer@13.1.0'));
        global.fetch = (async () => { throw new Error('offline'); }) as any;
        assert.strictEqual(await fetchTargetDeps('x', '1.0.0'), null);
        global.fetch = (async () => ({ ok: false, status: 404 })) as any;
        assert.strictEqual(await fetchTargetDeps('x', '1.0.0'), null);
    });
    it('fetchTargetDepsFor only queries packages with updates', async () => {
        const seen: string[] = [];
        const out = await fetchTargetDepsFor(
            [res('analyzer', '12.0.0', '13.1.0'), { ...res('http', '1.0.0', '1.0.0'), updateInfo: null } as any],
            undefined, undefined,
            async (p, v) => { seen.push(`${p}@${v}`); return new Map([['meta', '^1.18.3']]); });
        assert.deepStrictEqual(seen, ['analyzer@13.1.0']);
        assert.ok(out.has('analyzer@13.1.0'));
    });
});

describe('sdk pin derivation', () => {
    it('extracts only exact dependencies pins', () => {
        const p = parseExactPins(flutterPubspec);
        assert.strictEqual(p.get('meta'), '1.18.0');
        assert.strictEqual(p.get('collection'), '1.19.1');
        assert.ok(!p.has('characters') && !p.has('foo') && !p.has('sky_engine'));
    });
    it('lock version wins; lock parsing', () => {
        assert.strictEqual(parseLockedVersions(lock).get('meta'), '1.18.0');
        const m = mergePins([flutterPubspec], lock.replace('1.18.0', '1.18.1'));
        assert.strictEqual(m.get('meta'), '1.18.1');
    });
    it('deriveSdkPins is empty when no flutter root', async () => {
        assert.strictEqual((await deriveSdkPins('/nope', async () => null)).size, 0);
    });
});

describe('analyzer 13 sdk-blocked from data (held-back list emptied)', () => {
    const reverse = new Map<string, DepEdge[]>();
    it('is sdk-blocked using fetched target deps and derived pins', () => {
        const pins = mergePins([flutterPubspec], lock);
        const targetDeps = parseTargetDeps(analyzer13Response)!;
        const [r] = attachBlastRadius([res('analyzer', '12.0.0', '13.1.0')], {
            reverseDeps: reverse, constraints: new Map(), heldBack: [],
            sdkPins: pins, targetDepsOf: () => targetDeps,
        });
        assert.strictEqual(r.blastRadius?.verdict, 'sdk-blocked');
        const b = r.blastRadius?.sdkBlock;
        assert.strictEqual(b?.dep, 'meta');
        assert.strictEqual(b?.range, '^1.18.3');
        assert.strictEqual(b?.pinned, '1.18.0');
    });
    it('stays safe when target deps unknown (soft fail)', () => {
        const [r] = attachBlastRadius([res('analyzer', '12.0.0', '13.1.0')], {
            reverseDeps: reverse, constraints: new Map(), heldBack: [],
            sdkPins: new Map([['meta', '1.18.0']]), targetDepsOf: () => null,
        });
        assert.strictEqual(r.blastRadius?.verdict, 'safe');
    });
});

describe('robustness fixes', () => {
    it('parseLockedVersions accepts unquoted versions', () => {
        const lock = 'packages:\n  meta:\n    dependency: transitive\n    version: 1.18.0\n';
        assert.strictEqual(parseLockedVersions(lock).get('meta'), '1.18.0');
    });
    it('parseVersionList ignores non-object dependencies', () => {
        const l = parseVersionList({ versions: [{ version: '1.0.0', pubspec: { dependencies: 'abc' } }] });
        assert.strictEqual(l?.[0].deps.size, 0);
    });
    it('fetchVersionListsFor survives a throwing fetcher', async () => {
        const m = await fetchVersionListsFor(['a', 'b'], undefined, undefined, async (p: string) => {
            if (p === 'a') { throw new Error('boom'); }
            return [];
        });
        assert.deepStrictEqual([...m.keys()], ['b']);
    });
    it('fetchTargetDeps returns cached empty map', async () => {
        const cache = { get: () => ({}), set: async () => undefined } as any;
        const r = await fetchTargetDeps('meta', '1.0.0', cache);
        assert.strictEqual(r?.size, 0);
    });
});
