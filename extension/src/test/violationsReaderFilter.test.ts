import * as assert from 'node:assert';
import { filterDisabledFromData, type ViolationsData, type Violation } from '../violationsReader';

/** Build a minimal Violation for testing. */
function v(rule: string, severity = 'warning', impact = 'medium', file = 'lib/a.dart'): Violation {
  return { file, line: 1, rule, message: `msg for ${rule}`, severity, impact };
}

describe('filterDisabledFromData', () => {
  it('returns the same object when disabled set is empty', () => {
    const data: ViolationsData = {
      violations: [v('rule_a')],
      summary: { totalViolations: 1 },
    };
    const result = filterDisabledFromData(data, new Set());
    // Pass-through — no allocation, same reference.
    assert.strictEqual(result, data);
  });

  it('removes violations for disabled rules', () => {
    const data: ViolationsData = {
      violations: [v('rule_a'), v('rule_b'), v('rule_a')],
      summary: { totalViolations: 3 },
    };
    const result = filterDisabledFromData(data, new Set(['rule_a']));
    assert.strictEqual(result.violations.length, 1);
    assert.strictEqual(result.violations[0].rule, 'rule_b');
  });

  it('recomputes totalViolations from filtered array', () => {
    const data: ViolationsData = {
      violations: [v('rule_a'), v('rule_b'), v('rule_c')],
      summary: { totalViolations: 3 },
    };
    const result = filterDisabledFromData(data, new Set(['rule_a']));
    assert.strictEqual(result.summary?.totalViolations, 2);
  });

  it('recomputes bySeverity from filtered violations', () => {
    const data: ViolationsData = {
      violations: [
        v('rule_a', 'error', 'critical'),
        v('rule_b', 'warning', 'high'),
        v('rule_c', 'info', 'low'),
      ],
      summary: { bySeverity: { error: 1, warning: 1, info: 1 } },
    };
    // Disable the error-severity rule.
    const result = filterDisabledFromData(data, new Set(['rule_a']));
    assert.strictEqual(result.summary?.bySeverity?.error, undefined);
    assert.strictEqual(result.summary?.bySeverity?.warning, 1);
    assert.strictEqual(result.summary?.bySeverity?.info, 1);
  });

  it('recomputes byImpact from filtered violations', () => {
    const data: ViolationsData = {
      violations: [
        v('rule_a', 'error', 'critical'),
        v('rule_b', 'warning', 'high'),
      ],
    };
    const result = filterDisabledFromData(data, new Set(['rule_a']));
    assert.strictEqual(result.summary?.byImpact?.critical, undefined);
    assert.strictEqual(result.summary?.byImpact?.high, 1);
  });

  it('recomputes filesWithIssues from filtered violations', () => {
    const data: ViolationsData = {
      violations: [
        v('rule_a', 'warning', 'medium', 'lib/a.dart'),
        v('rule_b', 'warning', 'medium', 'lib/b.dart'),
      ],
      summary: { filesWithIssues: 2 },
    };
    // Disable rule_a — only lib/b.dart should remain.
    const result = filterDisabledFromData(data, new Set(['rule_a']));
    assert.strictEqual(result.summary?.filesWithIssues, 1);
  });

  it('recomputes issuesByRule from filtered violations', () => {
    const data: ViolationsData = {
      violations: [v('rule_a'), v('rule_a'), v('rule_b')],
      summary: { issuesByRule: { rule_a: 2, rule_b: 1 } },
    };
    const result = filterDisabledFromData(data, new Set(['rule_a']));
    assert.deepStrictEqual(result.summary?.issuesByRule, { rule_b: 1 });
  });

  it('preserves config and timestamp fields', () => {
    const data: ViolationsData = {
      timestamp: '2026-01-01T00:00:00Z',
      violations: [v('rule_a')],
      config: { tier: 'recommended', enabledRuleCount: 100 },
    };
    const result = filterDisabledFromData(data, new Set(['rule_a']));
    assert.strictEqual(result.timestamp, '2026-01-01T00:00:00Z');
    assert.strictEqual(result.config?.tier, 'recommended');
    assert.strictEqual(result.config?.enabledRuleCount, 100);
  });

  it('preserves filesAnalyzed from original summary', () => {
    const data: ViolationsData = {
      violations: [v('rule_a')],
      summary: { filesAnalyzed: 50, totalViolations: 1 },
    };
    const result = filterDisabledFromData(data, new Set(['rule_a']));
    // filesAnalyzed is not recomputed — it reflects how many files
    // the analyzer scanned, not how many have remaining violations.
    assert.strictEqual(result.summary?.filesAnalyzed, 50);
  });

  it('returns empty violations when all rules are disabled', () => {
    const data: ViolationsData = {
      violations: [v('rule_a'), v('rule_b')],
      summary: { totalViolations: 2 },
    };
    const result = filterDisabledFromData(data, new Set(['rule_a', 'rule_b']));
    assert.strictEqual(result.violations.length, 0);
    assert.strictEqual(result.summary?.totalViolations, 0);
  });

  // ── Suppressions pass-through ───────────────────────────────────────

  it('preserves suppressions through filtering (counts are analysis-time, not filtered)', () => {
    const data: ViolationsData = {
      violations: [v('rule_a'), v('rule_b')],
      summary: {
        totalViolations: 2,
        suppressions: {
          total: 10,
          byKind: { ignore: 6, ignoreForFile: 3, baseline: 1 },
        },
      },
    };
    // Disabling rule_a should NOT change suppression counts — those were
    // recorded at analysis time and are independent of post-hoc filtering.
    const result = filterDisabledFromData(data, new Set(['rule_a']));
    assert.strictEqual(result.summary?.suppressions?.total, 10);
    assert.deepStrictEqual(result.summary?.suppressions?.byKind, {
      ignore: 6,
      ignoreForFile: 3,
      baseline: 1,
    });
  });

  it('preserves suppressions when no rules are disabled (pass-through)', () => {
    const data: ViolationsData = {
      violations: [v('rule_a')],
      summary: {
        totalViolations: 1,
        suppressions: { total: 3, byKind: { ignore: 3 } },
      },
    };
    // Empty disabled set → same reference, suppressions untouched.
    const result = filterDisabledFromData(data, new Set());
    assert.strictEqual(result.summary?.suppressions?.total, 3);
  });

  it('preserves suppressions byRule and byFile through filtering', () => {
    const data: ViolationsData = {
      violations: [v('rule_a'), v('rule_b')],
      summary: {
        totalViolations: 2,
        suppressions: {
          total: 5,
          byKind: { ignore: 3, baseline: 2 },
          byRule: { rule_c: 3, rule_d: 2 },
          byFile: { 'lib/x.dart': 5 },
        },
      },
    };
    const result = filterDisabledFromData(data, new Set(['rule_a']));
    // byRule/byFile are analysis-time data, not recomputed by filtering.
    assert.deepStrictEqual(result.summary?.suppressions?.byRule, { rule_c: 3, rule_d: 2 });
    assert.deepStrictEqual(result.summary?.suppressions?.byFile, { 'lib/x.dart': 5 });
  });
});
