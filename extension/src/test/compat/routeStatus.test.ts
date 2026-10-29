import * as assert from 'node:assert';
import { routeStatus } from '../../compat/routeStatus';

const t = (k: string, p: Record<string, string> = {}) =>
  `${k.replace('compat.status.', '')}${Object.values(p).length ? `[${Object.values(p).join(',')}]` : ''}`;

describe('routeStatus', () => {
  it('maps every state to its text and tooltip key', () => {
    const cases: [Parameters<typeof routeStatus>[0], Parameters<typeof routeStatus>[1], string, string][] = [
      ['pubspecOnly', { pubspec: '17.0.0' }, 'pubspec[17.0.0]', 'tipPubspec'],
      ['pubspecOnly', {}, 'pubspecUnlocked', 'tipPubspec'],
      ['pluginOnly', { plugin: '16.10.0' }, 'plugin[16.10.0]', 'tipPlugin'],
      ['bothAgree', { pubspec: '17.0.0', plugin: '17.0.0' }, 'both[17.0.0]', 'tipBoth'],
      ['bothDisagree', { pubspec: '16.10.0', plugin: '17.0.0' }, 'disagree[16.10.0,17.0.0]', 'tipDisagree[16.10.0,17.0.0]'],
      ['neither', {}, 'neither', 'tipNeither'],
      ['localSource', {}, 'localSource', 'tipLocalSource'],
      ['dartTooOld', {}, 'dartTooOld', 'tipDartTooOld'],
    ];
    for (const [state, installed, text, tip] of cases) {
      const r = routeStatus(state, installed, t);
      assert.strictEqual(r.text, text, state);
      assert.strictEqual(r.tooltip, `${tip}\n\ntipClick`, state);
    }
  });
});
