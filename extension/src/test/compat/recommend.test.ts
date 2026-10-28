import * as assert from 'node:assert';
import { recommend, sameRecommendation } from '../../compat/recommend';
import type { ProjectFacts } from '../../compat/projectFacts';
import type { PubVersion } from '../../compat/pubVersions';
import type { ProbeResult } from '../../compat/solverProbe';

const K = 'compat.recommend.';
const V = (version: string, sdk = '>=3.9.0 <4.0.0', meta = '^1.18.0'): PubVersion => ({ version, sdk, meta });
const VERSIONS: PubVersion[] = [
  V('17.0.0', '>=3.10.0 <4.0.0', '^1.18.0'),
  V('16.10.0'),
  V('16.7.0'),
  V('15.2.0'),
];
const facts = (o: Partial<ProjectFacts> = {}): ProjectFacts => ({
  dartVersion: '3.13.0',
  flutterMetaPin: '1.18.0',
  locked: {},
  inPubspec: true,
  pluginBlockDisabled: false,
  ...o,
});
const ok: ProbeResult = { ok: true };
const fail = (blockingPackage?: string): ProbeResult => ({ ok: false, blockingPackage, reason: 'x', raw: 'x' });
const probeFor = (map: Record<string, ProbeResult>) => async (c: string) => map[c] ?? fail('analyzer');

describe('recommend', () => {
  it('latest ok: ^newest, plugin version exact', async () => {
    const r = await recommend(facts(), VERSIONS, probeFor({ '^17.0.0': ok }));
    assert.strictEqual(r.messageKey, K + 'latestOk');
    assert.strictEqual(r.constraint, '^17.0.0');
    assert.strictEqual(r.pluginVersion, '17.0.0');
    assert.strictEqual(r.route, 'dependency');
  });

  it('needs newer Dart: drops 17, no probe of it, offers upgrade or keep', async () => {
    const probed: string[] = [];
    const r = await recommend(facts({ dartVersion: '3.9.4' }), VERSIONS, async (c) => (probed.push(c), ok));
    assert.deepStrictEqual(probed, ['^16.10.0']);
    assert.strictEqual(r.messageKey, K + 'needsNewerDart');
    assert.strictEqual(r.constraint, '^16.10.0');
    assert.deepStrictEqual(r.fixes.map((f) => f.key), [K + 'fixFlutterUpgrade', K + 'fixKeepVersion']);
  });

  it('meta excludes the Flutter pin', async () => {
    const vs = [V('17.0.0', '>=3.9.0 <4.0.0', '^1.19.0'), V('16.10.0')];
    const r = await recommend(facts({ flutterMetaPin: '1.18.0' }), vs, probeFor({ '^16.10.0': ok }));
    assert.strictEqual(r.messageKey, K + 'metaExcludesPin');
    assert.strictEqual(r.constraint, '^16.10.0');
    assert.strictEqual(r.blockers[0].key, K + 'blockerMeta');
  });

  it('another package holds the analyzer: names it, falls back one major', async () => {
    const r = await recommend(facts(), VERSIONS, probeFor({ '^17.0.0': fail('objectbox_generator'), '^16.10.0': ok }));
    assert.strictEqual(r.messageKey, K + 'packageHoldsAnalyzer');
    assert.strictEqual(r.constraint, '^16.10.0');
    assert.strictEqual(r.blockers[0].params.package, 'objectbox_generator');
    assert.strictEqual(r.messageParams.package, 'objectbox_generator');
  });

  it('fallback goes to the previous major, not another minor of the same major', async () => {
    const probed: string[] = [];
    await recommend(facts(), VERSIONS, async (c) => (probed.push(c), c === '^15.2.0' ? ok : fail('analyzer')));
    assert.deepStrictEqual(probed, ['^17.0.0', '^16.10.0', '^15.2.0']);
  });

  it('no version resolves: plugin route only, at most 3 probes', async () => {
    let n = 0;
    const vs = [...VERSIONS, V('14.0.0')];
    const r = await recommend(facts(), vs, async () => (n++, fail('custom_lint')));
    assert.strictEqual(n, 3);
    assert.strictEqual(r.messageKey, K + 'noVersionResolves');
    assert.strictEqual(r.route, 'plugin');
    assert.strictEqual(r.pluginVersion, '17.0.0');
    assert.strictEqual(r.constraint, '');
    assert.strictEqual(r.blockers[0].params.package, 'custom_lint');
  });

  it('plugin-only project: no probe, no meta filter, sdk filter only', async () => {
    let probed = false;
    const vs = [V('17.0.0', '>=3.9.0 <4.0.0', '^1.99.0'), V('16.10.0')];
    const r = await recommend(
      facts({ inPubspec: false, pluginVersion: '16.7.0' }),
      vs,
      async () => ((probed = true), ok),
    );
    assert.strictEqual(probed, false);
    assert.strictEqual(r.route, 'plugin');
    assert.strictEqual(r.pluginVersion, '17.0.0');
    assert.strictEqual(r.constraint, '');
    assert.strictEqual(r.messageKey, K + 'pluginOnly');
  });

  it('both routes with plugin != locked: align plugin to locked', async () => {
    const r = await recommend(
      facts({ pluginVersion: '16.7.0', locked: { saropaLints: { version: '17.0.0', source: 'hosted' } } }),
      VERSIONS,
      probeFor({ '^17.0.0': ok }),
    );
    assert.strictEqual(r.route, 'both');
    assert.strictEqual(r.messageKey, K + 'alignPlugin');
    assert.strictEqual(r.pluginVersion, '17.0.0');
    assert.strictEqual(r.fixes[0].params.version, '17.0.0');
  });

  it('local path/git source: facts only, no probe', async () => {
    let probed = false;
    const r = await recommend(
      facts({ locked: { saropaLints: { version: '17.0.0', source: 'path' } } }),
      VERSIONS,
      async () => ((probed = true), ok),
    );
    assert.strictEqual(probed, false);
    assert.strictEqual(r.route, 'none');
    assert.strictEqual(r.messageKey, K + 'localSource');
    assert.strictEqual(r.constraint, '');
  });

  it('already correct: no action', async () => {
    const r = await recommend(
      facts({ pluginVersion: '17.0.0', locked: { saropaLints: { version: '17.0.0', source: 'hosted' } } }),
      VERSIONS,
      probeFor({ '^17.0.0': ok }),
    );
    assert.strictEqual(r.messageKey, K + 'alreadyCorrect');
    assert.strictEqual(r.fixes.length, 0);
  });

  it('offline: stale versions are flagged in notes', async () => {
    const r = await recommend(facts(), VERSIONS, probeFor({ '^17.0.0': ok }), { stale: true });
    assert.deepStrictEqual(r.notes.map((n) => n.key), [K + 'staleVersions']);
    const fresh = await recommend(facts(), VERSIONS, probeFor({ '^17.0.0': ok }));
    assert.strictEqual(fresh.notes.length, 0);
  });

  it('ignores prereleases', async () => {
    const r = await recommend(facts(), [V('18.0.0-dev.1'), ...VERSIONS], probeFor({ '^17.0.0': ok }));
    assert.strictEqual(r.constraint, '^17.0.0');
  });

  it('tool failure is reported as could-not-check, not as a blocking package', async () => {
    const probed: string[] = [];
    const toolFail: ProbeResult = { ok: false, toolError: true, reason: 'dart not found', raw: 'dart not found' };
    const r = await recommend(facts(), VERSIONS, async (c) => (probed.push(c), toolFail));
    assert.deepStrictEqual(probed, ['^17.0.0']);
    assert.strictEqual(r.route, 'none');
    assert.strictEqual(r.messageKey, K + 'probeFailed');
    assert.deepStrictEqual(r.messageParams, { detail: 'dart not found' });
    assert.strictEqual(r.blockers.length, 0);
    assert.strictEqual(r.constraint, '');
  });

  it('sameRecommendation compares route, constraint and plugin version', async () => {
    const a = await recommend(facts(), VERSIONS, probeFor({ '^17.0.0': ok }));
    const b = await recommend(facts(), VERSIONS, probeFor({ '^17.0.0': ok }));
    const c = await recommend(facts(), VERSIONS, probeFor({ '^17.0.0': fail('x'), '^16.10.0': ok }));
    assert.strictEqual(sameRecommendation(a, b), true);
    assert.strictEqual(sameRecommendation(a, c), false);
  });
});
