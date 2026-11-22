import * as assert from 'node:assert';
import { waitForRecovery } from '../../scanResources/scanResourceGuard';

const snap = (freeMb: number) => ({ totalMb: 16000, freeMb, cores: 8 });

describe('waitForRecovery', () => {
  it('returns at once on a healthy machine without sleeping', async () => {
    let slept = 0;
    const out = await waitForRecovery({ read: () => snap(8000), sleep: async () => { slept++; } });
    assert.strictEqual(out, 'recovered');
    assert.strictEqual(slept, 0);
  });
  it('waits while critical, then recovers', async () => {
    const reads = [500, 700, 5000];
    let i = 0;
    const out = await waitForRecovery({
      read: () => snap(reads[Math.min(i++, reads.length - 1)]),
      sleep: async () => undefined,
      pollMs: 10,
    });
    assert.strictEqual(out, 'recovered');
    assert.strictEqual(i, 3);
  });
  it('gives up after maxWaitMs', async () => {
    const out = await waitForRecovery({
      read: () => snap(100),
      sleep: async () => undefined,
      pollMs: 100,
      maxWaitMs: 300,
    });
    assert.strictEqual(out, 'timeout');
  });
  it('stops waiting when canceled', async () => {
    let canceled = false;
    const out = await waitForRecovery({
      read: () => snap(100),
      sleep: async () => { canceled = true; },
      isCanceled: () => canceled,
    });
    assert.strictEqual(out, 'canceled');
  });
  it('treats "high" as good enough to continue', async () => {
    // reserve 1600 → 2500 MB is high, not critical
    const out = await waitForRecovery({ read: () => snap(2500), sleep: async () => undefined });
    assert.strictEqual(out, 'recovered');
  });
  it('reports every poll', async () => {
    const seen: string[] = [];
    const reads = [100, 8000];
    let i = 0;
    await waitForRecovery({
      read: () => snap(reads[i++]),
      sleep: async () => undefined,
      onPoll: (p) => seen.push(p.level),
    });
    assert.deepStrictEqual(seen, ['critical', 'ok']);
  });
});
