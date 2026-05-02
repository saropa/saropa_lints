/**
 * HTML-render coverage for the Code Health Dashboard's adherence to the
 * editor-dashboard UX guidelines (§14.11, §8.16). Pins three behaviors:
 *
 *   1. KPI cards collapse to a single muted "all clear" line when every
 *      category count is zero — no five identical-twin "0" cards greeting
 *      the user on a healthy project.
 *   2. The filtered-table empty-state CTA is rendered (hidden by default;
 *      script reveals it when the filter narrows to zero rows).
 *   3. The gate-failure banner exposes a tier-1 *Open Code Health settings*
 *      button so the user has an actionable next step, not just text.
 */
import '../vibrancy/register-vscode-mock';

import * as assert from 'node:assert';

import { buildProjectVibrancyHtml } from '../../views/projectVibrancyReportView';
import type { ProjectVibrancyPayload } from '../../views/projectVibrancyTypes';

function payload(overrides: Partial<ProjectVibrancyPayload> = {}): ProjectVibrancyPayload {
  return {
    summary: { functionCount: 0, averageScore: 100, averageGrade: 'A' },
    functions: [],
    gates: { pass: true, violations: [] },
    generatedAt: new Date().toISOString(),
    ...overrides,
  };
}

describe('Code Health Dashboard HTML', () => {
  it('collapses the KPI strip to an all-clear line when every category is zero (§14.11)', () => {
    const html = buildProjectVibrancyHtml(payload());
    assert.ok(html.includes('class="kpi-allclear"'));
    assert.ok(html.includes('all clear'));
    // No KPI cards should render — the all-clear line replaces the row.
    assert.ok(!html.includes('class="kpi-row"'));
  });

  it('renders only the non-zero KPI cards when some categories carry findings (§14.11)', () => {
    const html = buildProjectVibrancyHtml(payload({
      summary: {
        functionCount: 10,
        averageScore: 60,
        averageGrade: 'C',
        unusedCount: 3,
        uncoveredCount: 0,
        stubTestedCount: 2,
        suspiciousCoverageCount: 0,
        testDriftCount: 0,
      },
    }));
    assert.ok(html.includes('class="kpi-row"'));
    assert.ok(html.includes('data-flag-filter="unused"'));
    assert.ok(html.includes('data-flag-filter="stub_tested"'));
    // Suppressed zero-count cards must not render at all.
    assert.ok(!html.includes('data-flag-filter="uncovered"'));
    assert.ok(!html.includes('data-flag-filter="suspicious_coverage"'));
    assert.ok(!html.includes('data-flag-filter="test_drift"'));
  });

  it('renders the filtered-table empty-state CTA with a tier-1 reset button (§8.16)', () => {
    const html = buildProjectVibrancyHtml(payload());
    assert.ok(html.includes('id="pvEmpty"'));
    assert.ok(html.includes('id="pvResetFilters"'));
    assert.ok(html.includes('class="btn tier-1"'));
    assert.ok(html.includes('Reset filters'));
  });

  it('exposes a tier-1 Open Code Health settings button in the gate-failure banner (§8.16)', () => {
    const html = buildProjectVibrancyHtml(payload({
      gates: { pass: false, violations: [{ gate: 'avg_score', message: 'too low' }] },
    }));
    assert.ok(html.includes('class="gate-warn"'));
    assert.ok(html.includes('data-cmd="openProjectVibrancySettings"'));
    assert.ok(html.includes('Open Code Health settings'));
    // The script wires [data-cmd] handlers via querySelectorAll, so the
    // button does not need an explicit id to dispatch.
  });
});
