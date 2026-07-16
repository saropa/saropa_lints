/**
 * Tests for buildDailySummary — the Saropa Suite daily-report contribution.
 *
 * Pins the contract shape (tool id, echoed date, openCommand), the count
 * omissions (healthScore withheld on a partial sweep, outdatedPackages absent
 * when no scan ran), the day-over-day delta drawn from run-history, and the
 * failure-only Trouble list.
 */

import * as assert from 'node:assert';
import { buildDailySummary } from '../dailySummary';
import type { ViolationsData } from '../violationsReader';
import type { RunSnapshot } from '../runHistory';

/** Violations data with the fields the summary + health score read. */
function data(opts: {
  total?: number;
  error?: number;
  warning?: number;
  info?: number;
  filesAnalyzed?: number;
  filesExpected?: number;
}): ViolationsData {
  const error = opts.error ?? 0;
  const warning = opts.warning ?? 0;
  const info = opts.info ?? 0;
  return {
    violations: [],
    summary: {
      totalViolations: opts.total ?? error + warning + info,
      filesAnalyzed: opts.filesAnalyzed ?? 100,
      filesExpected: opts.filesExpected ?? 100,
      bySeverity: { error, warning, info },
      byImpact: { error, warning, info },
    },
  };
}

function snap(date: string, total: number, score?: number): RunSnapshot {
  return { timestamp: `${date}T12:00:00.000Z`, total, error: 0, warning: 0, info: 0, score };
}

describe('buildDailySummary', () => {
  it('echoes the tool id, requested date, and open command', () => {
    const s = buildDailySummary({ date: '2026-07-16', data: data({ warning: 5 }), history: [] });
    assert.strictEqual(s.tool, 'saropa-lints');
    assert.strictEqual(s.date, '2026-07-16');
    assert.strictEqual(s.openCommand, 'saropaLints.openProjectHealthDashboard');
  });

  it('reports violation and severity counts plus a health score', () => {
    const s = buildDailySummary({
      date: '2026-07-16',
      data: data({ error: 2, warning: 3, info: 4 }),
      history: [],
    });
    assert.strictEqual(s.counts.violations, 9);
    assert.strictEqual(s.counts.critical, 2);
    assert.strictEqual(s.counts.warnings, 3);
    assert.strictEqual(s.counts.info, 4);
    assert.strictEqual(typeof s.counts.healthScore, 'number');
  });

  it('omits healthScore on a partial sweep', () => {
    // filesAnalyzed well below filesExpected * MIN_COVERAGE_FOR_SCORE.
    const s = buildDailySummary({
      date: '2026-07-16',
      data: data({ warning: 5, filesAnalyzed: 1, filesExpected: 1000 }),
      history: [],
    });
    assert.strictEqual('healthScore' in s.counts, false);
    assert.ok(s.headline.includes('unavailable'));
  });

  it('omits outdatedPackages when the count is undefined', () => {
    const s = buildDailySummary({ date: '2026-07-16', data: data({ warning: 5 }), history: [] });
    assert.strictEqual('outdatedPackages' in s.counts, false);
  });

  it('includes outdatedPackages when provided', () => {
    const s = buildDailySummary({
      date: '2026-07-16',
      data: data({ warning: 5 }),
      history: [],
      outdatedPackages: 7,
    });
    assert.strictEqual(s.counts.outdatedPackages, 7);
  });

  it('raises Trouble for error-level violations, none when clean', () => {
    const withErrors = buildDailySummary({ date: '2026-07-16', data: data({ error: 3 }), history: [] });
    assert.strictEqual(withErrors.trouble.length >= 1, true);
    assert.strictEqual(withErrors.trouble[0].command, 'saropaLints.focusIssues');

    const clean = buildDailySummary({ date: '2026-07-16', data: data({ info: 2 }), history: [] });
    assert.strictEqual(clean.trouble.length, 0);
  });

  it('flags a health-score regression against the prior day', () => {
    // Prior day scored 90; today has heavy findings that score lower.
    const history = [snap('2026-07-15', 1, 90)];
    const s = buildDailySummary({
      date: '2026-07-16',
      data: data({ error: 20, filesAnalyzed: 100, filesExpected: 100 }),
      history,
    });
    const regression = s.trouble.find((t) => t.label.startsWith('Health score dropped'));
    assert.ok(regression, 'expected a score-regression Trouble item');
    assert.strictEqual(regression?.command, 'saropaLints.openProjectHealthDashboard');
  });

  it('uses only pre-date history as the delta baseline', () => {
    // Same-day snapshot must not be the baseline; the 2026-07-14 entry is.
    const history = [snap('2026-07-14', 20, 70), snap('2026-07-16', 99, 40)];
    const s = buildDailySummary({
      date: '2026-07-16',
      data: data({ warning: 4 }),
      history,
    });
    // 4 violations now vs 20 at the prior-day baseline → "16 fewer".
    assert.ok(s.headline.includes('16 fewer'), s.headline);
  });
});
