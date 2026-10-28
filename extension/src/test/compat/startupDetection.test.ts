import * as assert from 'node:assert';
import type { ProjectFacts } from '../../compat/projectFacts';
import type { PubVersion } from '../../compat/pubVersions';
import {
  computeStartup, detectState, dontAskKey, isSuppressed, offerMessage,
} from '../../compat/startupDetection';

const versions: PubVersion[] = [
  { version: '16.10.0', sdk: '>=3.6.0 <4.0.0' },
  { version: '17.0.0', sdk: '>=3.11.0 <4.0.0' },
];

function facts(over: Partial<ProjectFacts> & { lock?: string; source?: string } = {}): ProjectFacts {
  const { lock, source, ...rest } = over;
  return {
    dartVersion: '3.13.0',
    locked: lock ? { saropaLints: { version: lock, source: source ?? 'hosted' } } : {},
    inPubspec: false,
    pluginBlockDisabled: false,
    ...rest,
  };
}

describe('detectState', () => {
  it('classifies each route', () => {
    assert.strictEqual(detectState(facts({ inPubspec: true, lock: '16.10.0' })), 'pubspecOnly');
    assert.strictEqual(detectState(facts({ pluginVersion: '16.10.0' })), 'pluginOnly');
    assert.strictEqual(detectState(facts({ inPubspec: true, lock: '16.10.0', pluginVersion: '16.10.0' })), 'bothAgree');
    assert.strictEqual(detectState(facts({ inPubspec: true, lock: '16.10.0', pluginVersion: '16.9.0' })), 'bothDisagree');
    assert.strictEqual(detectState(facts()), 'neither');
  });
  it('local path or git source', () => {
    assert.strictEqual(detectState(facts({ inPubspec: true, lock: '16.10.0', source: 'path' })), 'localSource');
    assert.strictEqual(detectState(facts({ inPubspec: true, lock: '16.10.0', source: 'git' })), 'localSource');
  });
  it('Dart below 3.11 with the plugin route', () => {
    assert.strictEqual(detectState(facts({ dartVersion: '3.10.0', pluginVersion: '16.10.0' })), 'dartTooOld');
    assert.strictEqual(detectState(facts({ dartVersion: '3.10.0', inPubspec: true, lock: '16.10.0' })), 'pubspecOnly');
  });
  it('a disabled plugin block does not count', () => {
    assert.strictEqual(detectState(facts({ pluginVersion: '16.10.0', pluginBlockDisabled: true })), 'neither');
  });
});

describe('computeStartup', () => {
  it('offers the newest applicable version to a pubspec project', async () => {
    const r = await computeStartup(facts({ inPubspec: true, lock: '16.10.0' }), versions);
    assert.strictEqual(r.offer?.offered, '17.0.0');
    assert.strictEqual(r.offer?.route, 'dependency');
  });
  it('offers to a plugin-only project using the plugin version', async () => {
    const r = await computeStartup(facts({ pluginVersion: '16.10.0' }), versions);
    assert.strictEqual(r.offer?.offered, '17.0.0');
    assert.strictEqual(r.offer?.route, 'plugin');
    assert.strictEqual(r.offer?.installed.plugin, '16.10.0');
  });
  it('treats a ^range plugin version as its base version', async () => {
    const r = await computeStartup(facts({ pluginVersion: '^16.10.0' }), versions);
    assert.strictEqual(r.offer?.installed.plugin, '16.10.0');
  });
  it('filters by environment.sdk', async () => {
    const r = await computeStartup(facts({ dartVersion: '3.10.0', inPubspec: true, lock: '16.9.0' }), versions);
    assert.strictEqual(r.offer?.offered, '16.10.0');
  });
  it('no offer when already on the latest applicable version', async () => {
    assert.strictEqual((await computeStartup(facts({ pluginVersion: '17.0.0' }), versions)).offer, undefined);
    assert.strictEqual((await computeStartup(facts({ inPubspec: true, lock: '17.0.0', pluginVersion: '17.0.0' }), versions)).offer, undefined);
    // Dart 3.10 cannot take 17.0.0, so 16.10.0 is the latest applicable.
    assert.strictEqual((await computeStartup(facts({ dartVersion: '3.10.0', inPubspec: true, lock: '16.10.0' }), versions)).offer, undefined);
  });
  it('both disagree: offers when either side is behind', async () => {
    const r = await computeStartup(facts({ inPubspec: true, lock: '17.0.0', pluginVersion: '16.10.0' }), versions);
    assert.strictEqual(r.state, 'bothDisagree');
    assert.strictEqual(r.offer?.route, 'both');
  });
  it('no offer for neither, local source, or Dart too old for the plugin', async () => {
    assert.strictEqual((await computeStartup(facts(), versions)).offer, undefined);
    assert.strictEqual((await computeStartup(facts({ inPubspec: true, lock: '16.0.0', source: 'path' }), versions)).offer, undefined);
    assert.strictEqual((await computeStartup(facts({ dartVersion: '3.10.0', pluginVersion: '16.0.0' }), versions)).offer, undefined);
  });
  it('counts renamed rules from the lowest installed version', async () => {
    const calls: string[] = [];
    const r = await computeStartup(
      facts({ inPubspec: true, lock: '16.10.0', pluginVersion: '16.9.0' }),
      versions,
      (from, to) => { calls.push(`${from}>${to}`); return 3; },
    );
    assert.deepStrictEqual(calls, ['16.9.0>17.0.0']);
    assert.strictEqual(r.offer?.renamedCount, 3);
  });
});

describe('dont-ask keys', () => {
  it('are per folder, route and version', async () => {
    const offer = (await computeStartup(facts({ pluginVersion: '16.10.0' }), versions)).offer!;
    const key = dontAskKey('/a', 'plugin', '17.0.0');
    assert.strictEqual(key, '/a::plugin@17.0.0');
    assert.ok(isSuppressed([key], offer, '/a'));
    assert.ok(!isSuppressed([key], offer, '/b'));
    assert.ok(!isSuppressed([dontAskKey('/a', 'dependency', '17.0.0')], offer, '/a'));
    assert.ok(!isSuppressed([dontAskKey('/a', 'plugin', '17.1.0')], offer, '/a'));
    assert.ok(!isSuppressed(undefined, offer, '/a'));
  });
});

describe('offerMessage', () => {
  const t = (k: string, p: Record<string, string> = {}) => `${k}|${Object.entries(p).map(([a, b]) => `${a}=${b}`).join(',')}`;
  it('picks the key by Dart and rename presence', async () => {
    const base = (await computeStartup(facts({ pluginVersion: '16.10.0' }), versions)).offer!;
    assert.ok(offerMessage(base, t).startsWith('compat.startup.offer|'));
    assert.ok(offerMessage({ ...base, dart: undefined }, t).startsWith('compat.startup.offerNoDart|'));
    assert.ok(offerMessage({ ...base, renamedCount: 2 }, t).startsWith('compat.startup.offerRenames|'));
    assert.ok(offerMessage({ ...base, dart: undefined, renamedCount: 2 }, t).startsWith('compat.startup.offerNoDartRenames|'));
  });
  it('states both versions when the routes disagree', async () => {
    const o = (await computeStartup(facts({ inPubspec: true, lock: '17.0.0', pluginVersion: '16.10.0' }), versions)).offer!;
    assert.ok(offerMessage(o, t).includes('installedDisagree'));
  });
});
