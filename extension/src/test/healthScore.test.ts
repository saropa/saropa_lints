/**
 * Tests for the health-score coverage gate.
 *
 * The gate exists because the IDE plugin analyzes files incrementally and
 * writes the report on a debounce, so a snapshot can land covering only a
 * handful of files. Dividing violations by that tiny denominator inflates
 * density and craters the score to a false 0% (the bug these tests pin).
 */

import * as assert from 'node:assert';
import {
  computeHealthScore,
  isReportTooPartial,
  MIN_COVERAGE_FOR_SCORE,
} from '../healthScore';
import type { ViolationsData } from '../violationsReader';

/** Build violations data with the summary fields the score reads. */
function data(opts: {
  filesAnalyzed: number;
  filesExpected?: number;
  warning?: number;
  info?: number;
  error?: number;
}): ViolationsData {
  return {
    violations: [],
    summary: {
      filesAnalyzed: opts.filesAnalyzed,
      filesExpected: opts.filesExpected,
      byImpact: {
        error: opts.error ?? 0,
        warning: opts.warning ?? 0,
        info: opts.info ?? 0,
      },
    },
  };
}

describe('isReportTooPartial', () => {
  it('is false when filesExpected is absent (older reports carry no signal)', () => {
    assert.strictEqual(isReportTooPartial(data({ filesAnalyzed: 10 })), false);
  });

  it('is true when coverage is below the threshold', () => {
    // 10 of 3000 discovered = 0.3% coverage — a partial IDE sweep.
    assert.strictEqual(
      isReportTooPartial(data({ filesAnalyzed: 10, filesExpected: 3000 })),
      true,
    );
  });

  it('is false when coverage clears the threshold', () => {
    // This repo's full sweep covers ~0.24 of discovered files (example* is
    // excluded). That must remain above the gate.
    assert.strictEqual(
      isReportTooPartial(data({ filesAnalyzed: 742, filesExpected: 3070 })),
      false,
    );
  });

  it('treats exactly-at-threshold coverage as sufficient', () => {
    const expected = 1000;
    const analyzed = Math.ceil(expected * MIN_COVERAGE_FOR_SCORE);
    assert.strictEqual(
      isReportTooPartial(data({ filesAnalyzed: analyzed, filesExpected: expected })),
      false,
    );
  });

  it('is false when filesExpected is zero (no usable denominator)', () => {
    assert.strictEqual(
      isReportTooPartial(data({ filesAnalyzed: 5, filesExpected: 0 })),
      false,
    );
  });
});

describe('computeHealthScore coverage gate', () => {
  it('returns null for a grossly-partial report instead of a false 0%', () => {
    // 8 files, all violation-dense: without the gate this craters to 0%.
    const result = computeHealthScore(
      data({ filesAnalyzed: 8, filesExpected: 3000, warning: 200, info: 400 }),
    );
    assert.strictEqual(result, null);
  });

  it('scores a full sweep of the same project', () => {
    const result = computeHealthScore(
      data({ filesAnalyzed: 441, filesExpected: 500, warning: 48, info: 125 }),
    );
    assert.ok(result, 'expected a score for a full sweep');
    // density = (48*3 + 125*0.25) / 441 ≈ 0.40 → ~89.
    assert.ok(result!.score > 80 && result!.score <= 100, `score ${result!.score}`);
  });

  it('still scores reports with no coverage signal (back-compat)', () => {
    const result = computeHealthScore(
      data({ filesAnalyzed: 441, warning: 48, info: 125 }),
    );
    assert.ok(result, 'older reports without filesExpected must still score');
  });

  it('returns 100 for a clean full sweep', () => {
    const result = computeHealthScore(
      data({ filesAnalyzed: 441, filesExpected: 500 }),
    );
    assert.strictEqual(result!.score, 100);
  });
});
