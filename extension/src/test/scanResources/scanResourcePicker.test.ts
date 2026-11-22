import '../vibrancy/register-vscode-mock';

import * as assert from 'node:assert';
import { buildProfileChoices, recommendProfile } from '../../scanResources/scanResourcePicker';
import { DEFAULT_SETTINGS } from '../../scanResources/scanResourceSettings';

const m = (cores: number, totalMb: number, freeMb: number) => ({ cores, totalMb, freeMb });

describe('recommendProfile', () => {
  it('recommends gentle for small machines', () => {
    assert.strictEqual(recommendProfile(m(4, 16000, 12000)), 'gentle');
    assert.strictEqual(recommendProfile(m(8, 6000, 4000)), 'gentle');
  });
  it('recommends gentle when the machine is already tight', () => {
    assert.strictEqual(recommendProfile(m(8, 16000, 2000)), 'gentle');
  });
  it('recommends balanced for a roomy machine and never auto-picks fast', () => {
    assert.strictEqual(recommendProfile(m(16, 64000, 50000)), 'balanced');
    assert.strictEqual(recommendProfile(m(64, 256000, 200000)), 'balanced');
  });
});

describe('buildProfileChoices', () => {
  it('shows what each profile would do and marks exactly one recommended', () => {
    const choices = buildProfileChoices(DEFAULT_SETTINGS, m(8, 32000, 20000), 5000);
    assert.deepStrictEqual(choices.map((c) => c.profile), ['gentle', 'balanced', 'fast']);
    assert.strictEqual(choices.filter((c) => c.recommended).length, 1);
    const [gentle, balanced, fast] = choices;
    assert.ok(gentle.resources.jobs <= balanced.resources.jobs);
    assert.ok(balanced.resources.jobs <= fast.resources.jobs);
  });
  it('ignores manual overrides so each profile is shown on its own terms', () => {
    const choices = buildProfileChoices({ ...DEFAULT_SETTINGS, maxWorkers: 1, maxMemoryMb: 512 }, m(8, 32000, 20000), 5000);
    assert.ok(choices[2].resources.jobs > 1);
  });
});
