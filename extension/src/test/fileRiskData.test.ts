/**
 * Tests for the exported buildFileRisks function.
 *
 * buildFileRisks was made public so the Overview tree's embedded "Riskiest
 * Files" group can reuse the same risk-scoring algorithm as the standalone
 * File Risk view. These tests validate the scoring and sorting contract.
 *
 * Severity model — error / warning / info (collapsed from the prior 5-bucket
 * impact taxonomy on 2026-05-03; see plan/COLLAPSE_LINT_IMPACT_TO_SEVERITY.md).
 * The `FileRisk.critical` field counts errors and `FileRisk.high` counts
 * warnings — names retained for back-compat with the JSON shape consumed by
 * `treeSerializers.ts`.
 */

import * as assert from 'node:assert';
import { buildFileRisks } from '../views/fileRiskTree';
import type { Violation } from '../violationsReader';

function v(
  file: string,
  impact = 'warning',
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
      v('lib/a.dart', 'warning'),
      v('lib/a.dart', 'warning'),
      v('lib/b.dart', 'info'),
    ];
    const risks = buildFileRisks(violations);
    assert.strictEqual(risks.length, 2);

    const fileA = risks.find((r) => r.filePath === 'lib/a.dart');
    assert.ok(fileA);
    assert.strictEqual(fileA.total, 2);
    // `high` field counts warnings post-2026-05-03.
    assert.strictEqual(fileA.high, 2);
  });

  it('sorts by weighted risk score descending', () => {
    const violations = [
      // File A: 1 info violation (weight 0.25)
      v('lib/a.dart', 'info'),
      // File B: 1 error violation (weight 8)
      v('lib/b.dart', 'error'),
      // File C: 3 warning violations (weight 3 each = 9)
      v('lib/c.dart', 'warning'),
      v('lib/c.dart', 'warning'),
      v('lib/c.dart', 'warning'),
    ];
    const risks = buildFileRisks(violations);
    // C wins because 3*3=9 > 8 (error single).
    assert.strictEqual(risks[0].filePath, 'lib/c.dart');
    assert.strictEqual(risks[1].filePath, 'lib/b.dart');
    assert.strictEqual(risks[2].filePath, 'lib/a.dart');
  });

  it('tracks error (was: critical) and warning (was: high) counts separately', () => {
    // Field names `critical` / `high` are kept for JSON back-compat — they
    // now hold error and warning severity counts respectively.
    const violations = [
      v('lib/x.dart', 'error'),
      v('lib/x.dart', 'error'),
      v('lib/x.dart', 'warning'),
      v('lib/x.dart', 'info'),
    ];
    const risks = buildFileRisks(violations);
    assert.strictEqual(risks[0].critical, 2);
    assert.strictEqual(risks[0].high, 1);
    assert.strictEqual(risks[0].total, 4);
  });

  it('defaults missing impact to warning weight', () => {
    // When impact is undefined, buildFileRisks defaults to 'warning' (was
    // 'medium' under the 5-bucket taxonomy retired 2026-05-03).
    const violations: Violation[] = [
      { file: 'lib/a.dart', line: 1, rule: 'r', message: 'm', severity: 'warning' },
    ];
    const risks = buildFileRisks(violations);
    assert.strictEqual(risks.length, 1);
    // Warning weight is 3 — riskScore should be 3.
    assert.strictEqual(risks[0].riskScore, 3);
  });

  it('breaks ties by weighted score (error single beats info quintuple)', () => {
    // File A: 1 error → weight 8.
    // File B: 5 info → weight 5*0.25 = 1.25.
    // File A must sort first (higher weight).
    const violations = [
      v('lib/a.dart', 'error'),
      v('lib/b.dart', 'info'),
      v('lib/b.dart', 'info'),
      v('lib/b.dart', 'info'),
      v('lib/b.dart', 'info'),
      v('lib/b.dart', 'info'),
    ];
    const risks = buildFileRisks(violations);
    assert.strictEqual(risks[0].filePath, 'lib/a.dart');
  });
});
