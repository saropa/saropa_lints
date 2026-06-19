/**
 * Tests for the standalone Drift Advisor extension recommendation gate.
 *
 * Pins the four-way AND: the install-the-standalone-extension toast fires only when
 * the standalone extension is missing, a Drift server is actually connected, the
 * suggestion was not shown in this workspace before, and proactive nudges are on.
 * Any one false suppresses it.
 */

import * as assert from 'node:assert';

import {
  shouldRecommendDriftAdvisor,
  type DriftRecommendInputs,
} from '../../driftAdvisor/driftAdvisorRecommendGate';

describe('driftAdvisor/driftAdvisorRecommendGate', () => {
  const base: DriftRecommendInputs = {
    standaloneInstalled: false,
    serverConnected: true,
    alreadySurfaced: false,
    proactiveNudgesDisabled: false,
  };

  it('recommends when the standalone is absent, a server is connected, unseen, and nudges on', () => {
    assert.strictEqual(shouldRecommendDriftAdvisor(base), true);
  });

  it('stays silent when the standalone extension is already installed', () => {
    assert.strictEqual(
      shouldRecommendDriftAdvisor({ ...base, standaloneInstalled: true }),
      false,
    );
  });

  it('stays silent when no server is connected', () => {
    assert.strictEqual(
      shouldRecommendDriftAdvisor({ ...base, serverConnected: false }),
      false,
    );
  });

  it('stays silent once the recommendation was already shown', () => {
    assert.strictEqual(
      shouldRecommendDriftAdvisor({ ...base, alreadySurfaced: true }),
      false,
    );
  });

  it('stays silent when proactive nudges are turned off', () => {
    assert.strictEqual(
      shouldRecommendDriftAdvisor({ ...base, proactiveNudgesDisabled: true }),
      false,
    );
  });
});
