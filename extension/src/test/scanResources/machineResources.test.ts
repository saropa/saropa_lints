import * as assert from 'node:assert';
import {
  classifyMachinePressure,
  defaultReserveMb,
  readMachineSnapshot,
} from '../../scanResources/machineResources';

describe('defaultReserveMb', () => {
  it('is 10% of RAM bounded to 512..2048 MB', () => {
    assert.strictEqual(defaultReserveMb(undefined), 768);
    assert.strictEqual(defaultReserveMb(2000), 512);
    assert.strictEqual(defaultReserveMb(16000), 1600);
    assert.strictEqual(defaultReserveMb(64000), 2048);
  });
  it('treats junk totals as unknown', () => {
    assert.strictEqual(defaultReserveMb(NaN), 768);
    assert.strictEqual(defaultReserveMb(-5), 768);
  });
});

describe('classifyMachinePressure', () => {
  const machine = (freeMb: number) => ({ totalMb: 16000, freeMb, cores: 8 });
  it('ok with plenty of free memory', () => {
    assert.strictEqual(classifyMachinePressure(machine(8000)).level, 'ok');
  });
  it('high under twice the reserve', () => {
    // reserve = 1600 → high below 3200
    assert.strictEqual(classifyMachinePressure(machine(3000)).level, 'high');
  });
  it('critical under the reserve', () => {
    const p = classifyMachinePressure(machine(1000));
    assert.strictEqual(p.level, 'critical');
    assert.strictEqual(p.reserveMb, 1600);
  });
  it('honors an explicit reserve', () => {
    assert.strictEqual(classifyMachinePressure(machine(900), 500).level, 'high');
  });
});

describe('readMachineSnapshot', () => {
  it('returns sane positive numbers and never throws', () => {
    const s = readMachineSnapshot();
    assert.ok(s.totalMb > 0);
    assert.ok(s.freeMb >= 0);
    assert.ok(s.cores >= 1);
  });
});
