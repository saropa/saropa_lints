import * as assert from 'node:assert';
import {
  applyRecommendationToContent,
  hasActiveKey,
  isSmallMachine,
  recommendPluginMemory,
  recommendedPluginRssMb,
  shouldOfferSmallMachineTuning,
  upsertTopLevelKey,
} from '../../scanResources/pluginMemoryConfig';

const m = (totalMb: number, cores = 8, freeMb = totalMb / 2) => ({ totalMb, cores, freeMb });

describe('recommendedPluginRssMb', () => {
  it('is 35% of RAM rounded to 256, bounded to 1536..4096', () => {
    assert.strictEqual(recommendedPluginRssMb(m(4096)), 1536); // 1434 → floor
    assert.strictEqual(recommendedPluginRssMb(m(8192)), 2816); // 2867 → 2816
    assert.strictEqual(recommendedPluginRssMb(m(16384)), 5632 > 4096 ? 4096 : 5632);
    assert.strictEqual(recommendedPluginRssMb(m(65536)), 4096);
  });
});

describe('recommendPluginMemory', () => {
  it('only the gentle profile asks for tighter live analysis', () => {
    assert.ok(recommendPluginMemory('gentle', m(8192)));
    assert.strictEqual(recommendPluginMemory('balanced', m(8192)), null);
    assert.strictEqual(recommendPluginMemory('fast', m(8192)), null);
  });
  it('turns shedding on', () => {
    assert.strictEqual(recommendPluginMemory('gentle', m(8192))?.shedRules, true);
  });
});

describe('hasActiveKey', () => {
  it('ignores commented placeholders', () => {
    assert.strictEqual(hasActiveKey('# shed_rules: false\n', 'shed_rules'), false);
    assert.strictEqual(hasActiveKey('shed_rules: false\n', 'shed_rules'), true);
    assert.strictEqual(hasActiveKey('  shed_rules: true\n', 'shed_rules'), false); // nested, not top-level
  });
});

describe('upsertTopLevelKey', () => {
  it('replaces the commented placeholder init writes', () => {
    const out = upsertTopLevelKey('a: 1\n# max_rss_mb: 4096 # hard cap\nb: 2\n', 'max_rss_mb', 2816);
    assert.strictEqual(out, 'a: 1\nmax_rss_mb: 2816\nb: 2\n');
  });
  it('replaces an active value', () => {
    assert.strictEqual(upsertTopLevelKey('shed_rules: false\n', 'shed_rules', true), 'shed_rules: true\n');
  });
  it('appends when absent, adding a newline when needed', () => {
    assert.strictEqual(upsertTopLevelKey('a: 1', 'k', 5), 'a: 1\nk: 5\n');
    assert.strictEqual(upsertTopLevelKey('a: 1\n', 'k', 5), 'a: 1\nk: 5\n');
    assert.strictEqual(upsertTopLevelKey('', 'k', 5), 'k: 5\n');
  });
  it('touches nothing else', () => {
    const src = 'x: 1\n# comment\ny: two # trailing\n';
    assert.strictEqual(upsertTopLevelKey(src, 'k', 1), `${src}k: 1\n`);
  });
});

describe('applyRecommendationToContent', () => {
  it('writes both knobs', () => {
    const out = applyRecommendationToContent('# shed_rules: false\n', { maxRssMb: 2048, shedRules: true });
    assert.ok(out.includes('shed_rules: true'));
    assert.ok(out.includes('max_rss_mb: 2048'));
  });
});

describe('small-machine offer', () => {
  it('detects small machines by RAM or cores', () => {
    assert.strictEqual(isSmallMachine(m(8192, 16)), true);
    assert.strictEqual(isSmallMachine(m(32768, 4)), true);
    assert.strictEqual(isSmallMachine(m(32768, 16)), false);
  });
  it('offers only when neither limit is configured', () => {
    assert.ok(shouldOfferSmallMachineTuning(m(8192), '# shed_rules: false\n'));
    assert.strictEqual(shouldOfferSmallMachineTuning(m(8192), 'shed_rules: false\n'), null);
    assert.strictEqual(shouldOfferSmallMachineTuning(m(8192), 'max_rss_mb: 3000\n'), null);
    assert.strictEqual(shouldOfferSmallMachineTuning(m(65536, 16), ''), null);
  });
});
