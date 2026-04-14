/**
 * Tests for the exported buildFileRisks function.
 *
 * buildFileRisks was made public so the Overview tree's embedded "Riskiest
 * Files" group can reuse the same risk-scoring algorithm as the standalone
 * File Risk view. These tests validate the scoring and sorting contract.
 */

import * as assert from 'node:assert';
import { buildFileRisks } from '../views/fileRiskTree';
import type { Violation } from '../violationsReader';

function v(
  file: string,
  impact = 'medium',
  rule = 'test_rule',
): Violation {
  return { file, line: 1, rule, message: `msg`, severity: 'warning', impact };
}

describe('buildFileRisks', () => {
  it('returns empty array for empty input', () => {
    assert.deepStrictEqual(buildFileRisks([]), []);
  });

  it('aggregates violations per file', () => {
    const violations = [
      v('lib/a.dart', 'medium'),
      v('lib/a.dart', 'high'),
      v('lib/b.dart', 'low'),
    ];
    const risks = buildFileRisks(violations);
    assert.strictEqual(risks.length, 2);

    const fileA = risks.find((r) => r.filePath === 'lib/a.dart');
    assert.ok(fileA);
    assert.strictEqual(fileA.total, 2);
    assert.strictEqual(fileA.high, 1);
  });

  it('sorts by weighted risk score descending', () => {
    const violations = [
      // File A: 1 low violation (weight 0.25)
      v('lib/a.dart', 'low'),
      // File B: 1 critical violation (weight 8)
      v('lib/b.dart', 'critical'),
      // File C: 3 medium violations (weight 3)
      v('lib/c.dart', 'medium'),
      v('lib/c.dart', 'medium'),
      v('lib/c.dart', 'medium'),
    ];
    const risks = buildFileRisks(violations);
    assert.strictEqual(risks[0].filePath, 'lib/b.dart');
    assert.strictEqual(risks[1].filePath, 'lib/c.dart');
    assert.strictEqual(risks[2].filePath, 'lib/a.dart');
  });

  it('tracks critical and high counts separately', () => {
    const violations = [
      v('lib/x.dart', 'critical'),
      v('lib/x.dart', 'critical'),
      v('lib/x.dart', 'high'),
      v('lib/x.dart', 'medium'),
    ];
    const risks = buildFileRisks(violations);
    assert.strictEqual(risks[0].critical, 2);
    assert.strictEqual(risks[0].high, 1);
    assert.strictEqual(risks[0].total, 4);
  });

  it('defaults missing impact to medium weight', () => {
    // When impact is undefined, buildFileRisks defaults to 'medium'
    const violations: Violation[] = [
      { file: 'lib/a.dart', line: 1, rule: 'r', message: 'm', severity: 'warning' },
    ];
    const risks = buildFileRisks(violations);
    assert.strictEqual(risks.length, 1);
    // Medium weight is 1 — riskScore should be 1.
    assert.strictEqual(risks[0].riskScore, 1);
  });

  it('breaks ties by total violation count', () => {
    // Two files with same weighted score but different counts.
    // File A: 2 medium (weight 2, total 2)
    // File B: 1 medium + 4 opinionated (weight 1 + 0.2 = 1.2, total 5)
    // File A should sort first (higher weight).
    const violations = [
      v('lib/a.dart', 'medium'),
      v('lib/a.dart', 'medium'),
      v('lib/b.dart', 'medium'),
      v('lib/b.dart', 'opinionated'),
      v('lib/b.dart', 'opinionated'),
      v('lib/b.dart', 'opinionated'),
      v('lib/b.dart', 'opinionated'),
    ];
    const risks = buildFileRisks(violations);
    assert.strictEqual(risks[0].filePath, 'lib/a.dart');
  });
});
