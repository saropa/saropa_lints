/**
 * Tests for the reciprocal deep-link targets (R5), the suite-awareness nudge gate
 * (R7), and the pubspec dependency probe both rely on.
 *
 * R5 pins that the Advisor "show live Drift issues" jump is offered only when a
 * Drift finding is present AND the Advisor extension is installed, and never for
 * non-Drift findings or a missing extension. R7 pins the four-way AND gate that
 * stops the install-Log-Capture toast from firing without the pairing, when the
 * tool is already installed, after it was shown once, or when nudges are off.
 */

import * as assert from 'node:assert';
import * as fs from 'node:fs';
import * as os from 'node:os';
import * as path from 'node:path';

import {
  ADVISOR_EXTENSION_ID,
  isDriftRuleId,
  suiteDeepLinkTargets,
} from '../suite/siblingDeepLinkTargets';
import { shouldNudgeSuiteAwareness, type SuiteNudgeInputs } from '../suite/suiteAwarenessGate';
import { hasPubspecDependency } from '../pubspecReader';

const installed = (id: string) => id === ADVISOR_EXTENSION_ID;
const noneInstalled = () => false;

describe('suite/siblingDeepLinkTargets (R5)', () => {
  it('classifies Drift rule ids', () => {
    assert.strictEqual(isDriftRuleId('avoid_drift_update_without_where'), true);
    assert.strictEqual(isDriftRuleId('prefer_final_locals'), false);
  });

  it('offers the Advisor runtime-issues jump for a Drift finding when Advisor is installed', () => {
    const targets = suiteDeepLinkTargets(['avoid_drift_update_without_where'], installed);
    assert.strictEqual(targets.length, 1);
    assert.strictEqual(targets[0].command, 'driftViewer.openIssues');
    assert.deepStrictEqual(targets[0].args, [{ category: 'drift' }]);
    assert.ok(targets[0].title.length > 0, 'title should be localized, not empty');
  });

  it('offers nothing when the Advisor extension is not installed', () => {
    assert.deepStrictEqual(suiteDeepLinkTargets(['avoid_drift_update_without_where'], noneInstalled), []);
  });

  it('offers nothing when no finding is a Drift rule', () => {
    assert.deepStrictEqual(suiteDeepLinkTargets(['prefer_final_locals', 'avoid_print'], installed), []);
  });

  it('offers nothing for an empty finding set', () => {
    assert.deepStrictEqual(suiteDeepLinkTargets([], installed), []);
  });
});

describe('suite/suiteAwarenessGate (R7)', () => {
  const base: SuiteNudgeInputs = {
    hasDriftAdvisorDep: true,
    logCaptureInstalled: false,
    alreadySurfaced: false,
    proactiveNudgesDisabled: false,
  };

  it('fires only when the pairing is present, Log Capture is absent, unseen, and nudges on', () => {
    assert.strictEqual(shouldNudgeSuiteAwareness(base), true);
  });

  it('stays silent without the Drift Advisor dependency', () => {
    assert.strictEqual(shouldNudgeSuiteAwareness({ ...base, hasDriftAdvisorDep: false }), false);
  });

  it('stays silent when Log Capture is already installed', () => {
    assert.strictEqual(shouldNudgeSuiteAwareness({ ...base, logCaptureInstalled: true }), false);
  });

  it('stays silent once the suggestion was already shown', () => {
    assert.strictEqual(shouldNudgeSuiteAwareness({ ...base, alreadySurfaced: true }), false);
  });

  it('stays silent when proactive nudges are turned off', () => {
    assert.strictEqual(shouldNudgeSuiteAwareness({ ...base, proactiveNudgesDisabled: true }), false);
  });
});

describe('pubspecReader.hasPubspecDependency', () => {
  function withPubspec(body: string): string {
    const root = fs.mkdtempSync(path.join(os.tmpdir(), 'saropa-pubspec-'));
    fs.writeFileSync(path.join(root, 'pubspec.yaml'), body);
    return root;
  }

  it('detects a dependency under any deps block', () => {
    const root = withPubspec('dev_dependencies:\n  saropa_drift_advisor: ^1.0.0\n');
    assert.strictEqual(hasPubspecDependency(root, 'saropa_drift_advisor'), true);
  });

  it('does not match a different package or a substring', () => {
    const root = withPubspec('dependencies:\n  saropa_drift_advisor_extra: ^1.0.0\n');
    assert.strictEqual(hasPubspecDependency(root, 'saropa_drift_advisor'), false);
    assert.strictEqual(hasPubspecDependency(root, 'drift'), false);
  });

  it('returns false when pubspec.yaml is absent', () => {
    const root = fs.mkdtempSync(path.join(os.tmpdir(), 'saropa-nopubspec-'));
    assert.strictEqual(hasPubspecDependency(root, 'saropa_drift_advisor'), false);
  });
});
