import * as assert from 'node:assert';
import {
  DEFAULT_SETTINGS,
  MAX_WORKERS,
  canHostDeepScan,
  estimateDeepScan,
  normalizeScanResourceSettings,
  resolveScanResources,
  type ScanResourceSettings,
} from '../../scanResources/scanResourceSettings';

const machine = (cores: number, freeMb: number) => ({ cores, freeMb, totalMb: freeMb * 2 });
const settings = (over: Partial<ScanResourceSettings> = {}): ScanResourceSettings => ({
  ...DEFAULT_SETTINGS,
  ...over,
});

describe('normalizeScanResourceSettings', () => {
  it('falls back to defaults for junk', () => {
    const s = normalizeScanResourceSettings({
      profile: 'turbo',
      maxWorkers: 'many',
      maxMemoryMb: NaN,
      lowPriority: 'yes',
      baselineMode: 7,
      notifyOnPressure: null,
    });
    assert.deepStrictEqual(s, DEFAULT_SETTINGS);
  });
  it('clamps numbers and keeps valid values', () => {
    const s = normalizeScanResourceSettings({
      profile: 'gentle',
      maxWorkers: 999,
      maxMemoryMb: 100,
      lowPriority: false,
      baselineMode: 'deep',
    });
    assert.strictEqual(s.profile, 'gentle');
    assert.strictEqual(s.maxWorkers, MAX_WORKERS);
    assert.strictEqual(s.maxMemoryMb, 256); // too small to run a worker
    assert.strictEqual(s.lowPriority, false);
    assert.strictEqual(s.baselineMode, 'deep');
  });
  it('treats 0 memory as automatic', () => {
    assert.strictEqual(normalizeScanResourceSettings({ maxMemoryMb: 0 }).maxMemoryMb, 0);
  });
});

describe('resolveScanResources', () => {
  it('balanced leaves a core free', () => {
    const r = resolveScanResources(settings(), machine(8, 32000), 5000);
    assert.strictEqual(r.jobs, 7);
    assert.strictEqual(r.limitedBy, 'cpu');
  });
  it('gentle is capped at two workers', () => {
    const r = resolveScanResources(settings({ profile: 'gentle' }), machine(16, 32000), 5000);
    assert.strictEqual(r.jobs, 2);
  });
  it('fast uses every core', () => {
    const r = resolveScanResources(settings({ profile: 'fast' }), machine(8, 32000), 5000);
    assert.strictEqual(r.jobs, 8);
  });
  it('is limited by memory on a tight machine', () => {
    // balanced: 50% of 2000 = 1000 MB budget → (1000-300)/300 = 2 workers
    const r = resolveScanResources(settings(), machine(16, 2000), 5000);
    assert.strictEqual(r.jobs, 2);
    assert.strictEqual(r.limitedBy, 'memory');
  });
  it('small projects stay on one worker', () => {
    const r = resolveScanResources(settings(), machine(16, 32000), 40);
    assert.strictEqual(r.jobs, 1);
    assert.strictEqual(r.limitedBy, 'files');
  });
  it('an explicit worker count wins but never exceeds the file count', () => {
    const r = resolveScanResources(settings({ maxWorkers: 6 }), machine(4, 8000), 3);
    assert.strictEqual(r.jobs, 3);
    assert.strictEqual(r.limitedBy, 'setting');
  });
  it('an explicit memory budget is used verbatim', () => {
    const r = resolveScanResources(settings({ maxMemoryMb: 4096 }), machine(8, 1000), 5000);
    assert.strictEqual(r.maxMemoryMb, 4096);
  });
  it('always returns at least one worker and a usable budget', () => {
    const r = resolveScanResources(settings(), machine(1, 100), 0);
    assert.ok(r.jobs >= 1);
    assert.ok(r.maxMemoryMb >= 512);
  });
});

describe('deep scan estimates', () => {
  it('estimates minutes from the measured rate', () => {
    assert.strictEqual(estimateDeepScan(4500).minutes, 25);
    assert.strictEqual(estimateDeepScan(3).minutes, 1);
  });
  it('needs its memory plus the reserve', () => {
    assert.strictEqual(canHostDeepScan(machine(8, 6000), 1000), true);
    assert.strictEqual(canHostDeepScan(machine(8, 4500), 1000), false);
  });
});
