import '../vibrancy/register-vscode-mock';
import * as assert from 'node:assert';
import { decideOnUpgrade, offerableVersion } from '../../compat/upgradeGate';
import type { Recommendation } from '../../compat/recommend';

const rec = (o: Partial<Recommendation> = {}): Recommendation => ({
  route: 'dependency',
  constraint: '^16.10.0',
  pluginVersion: '16.10.0',
  messageKey: 'compat.recommend.latestOk',
  messageParams: {},
  blockers: [],
  fixes: [],
  notes: [],
  ...o,
});

describe('offerableVersion', () => {
  it('offers the recommended version when it differs from installed', () => {
    assert.strictEqual(offerableVersion(rec(), '16.0.0'), '16.10.0');
  });
  it('offers nothing when already installed', () => {
    assert.strictEqual(offerableVersion(rec(), '16.10.0'), undefined);
  });
  it('offers nothing when no version is acceptable', () => {
    assert.strictEqual(offerableVersion(rec({ route: 'none', pluginVersion: '' }), '16.0.0'), undefined);
  });
});

describe('decideOnUpgrade', () => {
  it('applies when the solver accepts the offered version', () => {
    assert.strictEqual(decideOnUpgrade(rec(), '16.10.0'), 'apply');
  });
  it('opens the card when the probe found nothing that resolves', () => {
    const r = rec({ route: 'plugin', constraint: '', messageKey: 'compat.recommend.noVersionResolves' });
    assert.strictEqual(decideOnUpgrade(r, '16.10.0'), 'openCard');
  });
  it('opens the card when route is none', () => {
    assert.strictEqual(decideOnUpgrade(rec({ route: 'none', pluginVersion: '' }), '16.10.0'), 'openCard');
  });
  it('opens the card when the solver chose a different version than offered', () => {
    assert.strictEqual(decideOnUpgrade(rec({ pluginVersion: '15.2.0' }), '16.10.0'), 'openCard');
  });
});
