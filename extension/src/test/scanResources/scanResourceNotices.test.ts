import * as assert from 'node:assert';
import {
  abortedNotice,
  daemonLowMemoryNotice,
  deepPausedNotice,
  deepPreflightNotice,
  fastDoneNotice,
  formatMb,
  throttledNotice,
} from '../../scanResources/scanResourceNotices';

const machine = (freeMb: number) => ({ totalMb: 32000, freeMb, cores: 8 });
const ids = (n: { actions: readonly { id: string }[] }): string[] => n.actions.map((a) => a.id);

describe('formatMb', () => {
  it('uses GB from 1024 MB up', () => {
    assert.strictEqual(formatMb(640), '640 MB');
    assert.strictEqual(formatMb(2048), '2.0 GB');
    assert.strictEqual(formatMb(-3), '0 MB');
  });
});

describe('throttledNotice / abortedNotice', () => {
  const ev = { event: 'throttle', from: 4, to: 1, level: 'critical', reason: 'free memory 400 MB is below the reserve' } as const;
  it('offers the gentle profile unless already on it', () => {
    assert.deepStrictEqual(ids(throttledNotice(ev, 'balanced')), ['gentleProfile', 'openSettings']);
    assert.deepStrictEqual(ids(throttledNotice(ev, 'gentle')), ['openSettings']);
    assert.deepStrictEqual(ids(abortedNotice('budget', 'fast')), ['gentleProfile', 'openSettings']);
  });
  it('carries the numbers and reason', () => {
    const n = throttledNotice(ev, 'balanced');
    assert.strictEqual(n.params.from, '4');
    assert.strictEqual(n.params.to, '1');
    assert.ok(n.params.reason.includes('reserve'));
    assert.strictEqual(n.severity, 'warning');
  });
});

describe('deepPreflightNotice', () => {
  it('is null when the machine has room', () => {
    assert.strictEqual(deepPreflightNotice(machine(16000), 1600, 4000), null);
  });
  it('explains the shortfall and offers the fast scan first', () => {
    const n = deepPreflightNotice(machine(3000), 1600, 4000);
    assert.ok(n);
    assert.deepStrictEqual(ids(n), ['runFast', 'runDeepAnyway']);
    assert.strictEqual(n.params.free, '2.9 GB');
    assert.strictEqual(n.params.needed, '4.0 GB');
  });
});

describe('deepPausedNotice', () => {
  it('offers resume, cancel and settings', () => {
    const n = deepPausedNotice({ level: 'critical', freeMb: 900, reserveMb: 1600 });
    assert.deepStrictEqual(ids(n), ['resume', 'cancelScan', 'openSettings']);
  });
});

describe('fastDoneNotice', () => {
  const summary = { filesScanned: 4500, elapsedMs: 65_000 };
  it('offers the deep scan with an estimate when the machine can host it', () => {
    const n = fastDoneNotice(summary, 120, machine(20000), 1600, true);
    assert.strictEqual(n.messageKey, 'scanResources.fastDoneOfferDeep');
    assert.deepStrictEqual(ids(n), ['runDeep', 'notNow', 'neverAskDeep']);
    assert.strictEqual(n.params.minutes, '25');
    assert.strictEqual(n.params.seconds, '65.0');
  });
  it('does not offer a deep scan the machine cannot host', () => {
    const n = fastDoneNotice(summary, 120, machine(3000), 1600, true);
    assert.strictEqual(n.messageKey, 'scanResources.fastDoneDeepUnavailable');
    assert.deepStrictEqual(ids(n), []);
  });
  it('stays quiet about deep when the user opted out', () => {
    const n = fastDoneNotice(summary, 0, machine(20000), 1600, false);
    assert.strictEqual(n.messageKey, 'scanResources.fastDone');
    assert.deepStrictEqual(ids(n), []);
  });
});

describe('daemonLowMemoryNotice', () => {
  it('offers to turn off type resolution, override once, or open settings', () => {
    const n = daemonLowMemoryNotice(machine(2000), 1600);
    assert.deepStrictEqual(ids(n), ['turnOffTypeResolution', 'startAnyway', 'openSettings']);
    assert.strictEqual(n.severity, 'warning');
  });
});
