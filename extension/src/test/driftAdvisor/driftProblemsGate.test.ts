/**
 * Tests for the Drift Advisor Problems-panel publish gate.
 *
 * Pins the duplicate-suppression rule: when the standalone Saropa Drift Advisor
 * extension is active it owns the Problems panel, so the Lints integration must NOT
 * also publish (otherwise every anomaly squiggle appears twice). When the standalone
 * extension is absent, the existing `showInProblems` opt-out is the only gate.
 */

import * as assert from 'node:assert';

import {
  shouldPublishDriftProblems,
  type DriftProblemsGateInputs,
} from '../../driftAdvisor/driftProblemsGate';

describe('driftAdvisor/driftProblemsGate', () => {
  const base: DriftProblemsGateInputs = {
    standaloneActive: false,
    showInProblems: true,
  };

  it('suppresses the publish when the standalone extension is active, even with showInProblems on', () => {
    assert.strictEqual(
      shouldPublishDriftProblems({ ...base, standaloneActive: true }),
      false,
    );
  });

  it('suppresses regardless of showInProblems when the standalone extension is active', () => {
    assert.strictEqual(
      shouldPublishDriftProblems({ standaloneActive: true, showInProblems: false }),
      false,
    );
  });

  it('publishes when the standalone extension is absent and showInProblems is on', () => {
    assert.strictEqual(shouldPublishDriftProblems(base), true);
  });

  it('suppresses when the standalone extension is absent but the user opted out', () => {
    assert.strictEqual(
      shouldPublishDriftProblems({ standaloneActive: false, showInProblems: false }),
      false,
    );
  });
});
