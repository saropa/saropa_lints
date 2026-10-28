import * as assert from 'node:assert';
import {
  getPubVersions, parsePubVersion, PubVersionsCache, PubVersionsError, PubVersionsStore,
} from '../../compat/pubVersions';

const body = {
  latest: { version: '2.0.0' },
  versions: [
    {
      version: '1.0.0', published: '2026-01-01T00:00:00Z',
      pubspec: { environment: { sdk: '>=3.9.0 <4.0.0' }, dependencies: { meta: '^1.18.0', analyzer: '>=12.0.0 <13.0.0' } },
    },
    { version: '2.0.0', pubspec: {} },
    { nope: true },
  ],
};

function okFetch(): (u: string) => Promise<Response> {
  return async () => ({ ok: true, status: 200, json: async () => body } as unknown as Response);
}

function memStore(): PubVersionsStore & { value?: PubVersionsCache } {
  const s: PubVersionsStore & { value?: PubVersionsCache } = {
    get: () => s.value,
    set: (c) => { s.value = c; },
  };
  return s;
}

describe('getPubVersions', () => {
  it('parses versions and constraints and caches', async () => {
    const store = memStore();
    const r = await getPubVersions({ fetchFn: okFetch(), store, now: () => 42 });
    assert.strictEqual(r.stale, false);
    assert.strictEqual(r.fetchedAt, 42);
    assert.strictEqual(r.latest, '2.0.0');
    assert.deepStrictEqual(r.versions[0], {
      version: '1.0.0', sdk: '>=3.9.0 <4.0.0', meta: '^1.18.0',
      analyzer: '>=12.0.0 <13.0.0', published: '2026-01-01T00:00:00Z',
    });
    assert.strictEqual(r.versions.length, 2);
    assert.strictEqual(store.value?.fetchedAt, 42);
  });

  it('serves the cache as stale when fetch throws', async () => {
    const store = memStore();
    await getPubVersions({ fetchFn: okFetch(), store, now: () => 1 });
    const r = await getPubVersions({
      fetchFn: async () => { throw new Error('offline'); }, store, now: () => 99,
    });
    assert.strictEqual(r.stale, true);
    assert.strictEqual(r.fetchedAt, 1);
    assert.strictEqual(r.versions.length, 2);
  });

  it('serves the cache as stale on a non-ok response', async () => {
    const store = memStore();
    await getPubVersions({ fetchFn: okFetch(), store });
    const r = await getPubVersions({
      fetchFn: async () => ({ ok: false, status: 503 } as Response), store,
    });
    assert.strictEqual(r.stale, true);
  });

  it('throws a typed error with no cache', async () => {
    await assert.rejects(
      getPubVersions({ fetchFn: async () => { throw new Error('offline'); }, store: memStore() }),
      (e: unknown) => e instanceof PubVersionsError && e.reason === 'network',
    );
    await assert.rejects(
      getPubVersions({ fetchFn: async () => ({ ok: false, status: 500 } as Response), store: memStore() }),
      (e: unknown) => e instanceof PubVersionsError && e.reason === 'http',
    );
  });

  it('throws a parse error on a malformed body with no cache', async () => {
    await assert.rejects(
      getPubVersions({
        fetchFn: async () => ({ ok: true, status: 200, json: async () => ({}) } as unknown as Response),
        store: memStore(),
      }),
      (e: unknown) => e instanceof PubVersionsError && e.reason === 'parse',
    );
  });

  it('parsePubVersion rejects entries without a version', () => {
    assert.strictEqual(parsePubVersion({}), null);
  });
});
