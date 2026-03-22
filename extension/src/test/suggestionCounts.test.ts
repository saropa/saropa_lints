/**
 * Unit tests for {@link countSuggestionItems}: parity with Suggestions view row cap (8)
 * and false-positive guards (zero totals, tier-only branches).
 */

import * as assert from 'node:assert';
import * as fs from 'node:fs';
import * as os from 'node:os';
import * as path from 'node:path';
import { countSuggestionItems } from '../suggestionCounts';
import type { ViolationsData } from '../violationsReader';

describe('countSuggestionItems', () => {
  it('returns 2 for empty violations (only run + open rows)', () => {
    const data: ViolationsData = { violations: [] };
    const n = countSuggestionItems(data, os.tmpdir(), 'recommended');
    assert.strictEqual(n, 2);
  });

  it('does not treat zero total as “has issues” for baseline/tier hints', () => {
    const data: ViolationsData = {
      violations: [],
      summary: { totalViolations: 0, byImpact: { critical: 0 }, bySeverity: { error: 0 } },
    };
    const n = countSuggestionItems(data, os.tmpdir(), 'recommended');
    assert.strictEqual(n, 2);
  });

  it('includes critical row when critical > 0', () => {
    const data: ViolationsData = {
      violations: [{ file: 'a.dart', line: 1, rule: 'r', message: 'm', impact: 'critical' }],
      summary: { totalViolations: 1, byImpact: { critical: 1 } },
    };
    const n = countSuggestionItems(data, os.tmpdir(), 'essential');
    assert.ok(n >= 3);
  });
});

describe('countSuggestionItems with temp workspace', () => {
  let dir: string;
  beforeEach(() => {
    dir = fs.mkdtempSync(path.join(os.tmpdir(), 'saropa-suggest-'));
  });
  afterEach(() => {
    fs.rmSync(dir, { recursive: true, force: true });
  });

  it('adds baseline hint when saropa_baseline.json is missing and total > 0', () => {
    const data: ViolationsData = {
      violations: [{ file: 'a.dart', line: 1, rule: 'r', message: 'm' }],
      summary: { totalViolations: 1 },
    };
    const withBaseline = countSuggestionItems(data, dir, 'essential');
    fs.writeFileSync(path.join(dir, 'saropa_baseline.json'), '{}');
    const withoutBaselineHint = countSuggestionItems(data, dir, 'essential');
    assert.ok(withBaseline > withoutBaselineHint);
  });
});
