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

  it('includes related-rule hint when related rule is not enabled', () => {
    const data: ViolationsData = {
      violations: [{ file: 'a.dart', line: 1, rule: 'require_dispose_implementation', message: 'm' }],
      summary: {
        totalViolations: 1,
        issuesByRule: { require_dispose_implementation: 1 },
      },
      config: {
        enabledRuleNames: ['require_dispose_implementation'],
        relatedRulesByRule: {
          require_dispose_implementation: ['require_stream_controller_dispose'],
        },
      },
    };
    const n = countSuggestionItems(data, os.tmpdir(), 'essential');
    assert.ok(n >= 3);
  });

  it('skips related-rule hint when candidate conflicts with enabled rule', () => {
    const data: ViolationsData = {
      violations: [{ file: 'a.dart', line: 1, rule: 'prefer_type_over_var', message: 'm' }],
      summary: {
        totalViolations: 1,
        issuesByRule: { prefer_type_over_var: 1 },
      },
      config: {
        enabledRuleNames: ['prefer_type_over_var'],
        relatedRulesByRule: {
          prefer_type_over_var: ['prefer_var_over_explicit_type'],
        },
        conflictingRulesByRule: {
          prefer_type_over_var: ['prefer_var_over_explicit_type'],
          prefer_var_over_explicit_type: ['prefer_type_over_var'],
        },
      },
    };
    const n = countSuggestionItems(data, os.tmpdir(), 'essential');
    // Expect baseline + run + open only (no related suggestion).
    assert.strictEqual(n, 3);
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

  it('adds a pack suggestion when multiple related candidates map to one disabled pack', () => {
    const data: ViolationsData = {
      violations: [{ file: 'a.dart', line: 1, rule: 'avoid_bloc_public_fields', message: 'm' }],
      summary: {
        totalViolations: 1,
        issuesByRule: { avoid_bloc_public_fields: 1 },
      },
      config: {
        enabledRuleNames: ['avoid_bloc_public_fields'],
        relatedRulesByRule: {
          avoid_bloc_public_fields: [
            'prefer_bloc_state_suffix',
            'prefer_bloc_event_suffix',
          ],
        },
      },
    };
    const n = countSuggestionItems(data, dir, 'essential');
    // baseline + related + pack + run + open
    assert.strictEqual(n, 5);
  });
});
