/**
 * Pure-logic tests for the scan-progress gating helpers. The notification UI
 * itself needs a live VS Code host, so only the decision functions are covered.
 */
import * as assert from 'assert';
import { isScanInFlight, scanPercent } from '../scanProgressMath';

describe('analysisToastProgress', () => {
  it('isScanInFlight is false with no snapshot', () => {
    assert.strictEqual(isScanInFlight(undefined), false);
  });

  it('isScanInFlight is true while filesScanned < totalFiles and not done', () => {
    assert.strictEqual(isScanInFlight({ filesScanned: 10, totalFiles: 100 }), true);
  });

  it('isScanInFlight honors the explicit done flag over the ratio (canceled scan)', () => {
    assert.strictEqual(isScanInFlight({ filesScanned: 10, totalFiles: 100, done: true }), false);
  });

  it('isScanInFlight is false when all files are scanned', () => {
    assert.strictEqual(isScanInFlight({ filesScanned: 100, totalFiles: 100 }), false);
  });

  it('scanPercent floors and caps at 99 while running', () => {
    assert.strictEqual(scanPercent({ filesScanned: 1, totalFiles: 3 }), 33);
    assert.strictEqual(scanPercent({ filesScanned: 999, totalFiles: 1000 }), 99);
  });

  it('scanPercent returns 0 for an empty workspace', () => {
    assert.strictEqual(scanPercent({ filesScanned: 0, totalFiles: 0 }), 0);
  });
});
