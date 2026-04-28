import * as assert from 'assert';
import { buildTierChips, computePackDashboardStats } from '../../rulePacks/rulePacksWebviewProvider';

describe('rulePacksWebviewProvider dashboard helpers', () => {
  it('computes enabled and detected pack/rule totals', () => {
    const stats = computePackDashboardStats([
      { id: 'a', label: 'A', rules: 3, enabled: true, detected: false },
      { id: 'b', label: 'B', rules: 5, enabled: false, detected: true },
      { id: 'c', label: 'C', rules: 2, enabled: true, detected: true },
    ]);

    assert.deepStrictEqual(stats, {
      totalPacks: 3,
      enabledPacks: 2,
      detectedPacks: 2,
      enabledRules: 5,
      detectedRules: 7,
    });
  });

  it('marks the current tier chip', () => {
    const html = buildTierChips('recommended');
    assert.ok(html.includes('recommended (current)'));
    assert.ok(html.includes('tier-chip active'));
    assert.ok(html.includes('pedantic'));
  });
});

