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
  });

  // Builds a populated payload for the table/header rewrite tests. Kept inline
  // so each assertion below reads like the screenshot the user would see.
  function rowsPayload(): ProjectVibrancyPayload {
    return payload({
      summary: {
        functionCount: 3,
        averageScore: 42.5,
        averageGrade: 'D',
        unusedCount: 1,
        testDriftCount: 0,
      },
      functions: [
        { file: 'lib/a.dart', name: '==', lineStart: 5, lineEnd: 6, score: 22.5, grade: 'E', category: 'risky', usageCount: 0, coveragePercent: 0, complexity: 3, flags: ['unused'], lastChangedEpochSec: Math.floor(Date.now() / 1000) - 86400 * 3 },
        { file: 'lib/database/drift_middleware/user_data/contact_drift_io.dart', name: 'dbContactCountWithCountry', lineStart: 12, lineEnd: 22, score: 25.0, grade: 'E', category: 'risky', usageCount: 0, coveragePercent: 0, complexity: 12, flags: ['unused', 'complex'], lastChangedEpochSec: Math.floor(Date.now() / 1000) - 86400 * 90 },
        { file: 'lib/main.dart', name: 'main', lineStart: 1, lineEnd: 3, score: 80.0, grade: 'A', category: 'healthy', usageCount: 1, coveragePercent: 50, complexity: 1, flags: [] },
      ],
    });
  }

  it('drops the grade column and renders the score as a colored pill (no decimal)', () => {
    const html = buildProjectVibrancyHtml(rowsPayload());
    // The grade axis was redundant with the score axis (grade is bucketed
    // score) — replaced by the colored score pill.
    assert.ok(!html.includes('data-sort="grade"'));
    assert.ok(!html.includes('col-grade'));
    assert.ok(html.includes('class="score-pill"'));
    // Whole-number score, not "22.5" / "25.0".
    assert.ok(/>23</.test(html), 'score pill should show rounded 23 for 22.5');
    assert.ok(/>25</.test(html));
    assert.ok(/>80</.test(html));
  });

  it('binds to the FULL function list with a truthful "showing N of TOTAL" count', () => {
    const html = buildProjectVibrancyHtml(rowsPayload());
    // No artificial 200-row slice; the count must reflect the actual data.
    assert.ok(html.includes('showing 3 of 3'));
    // Three <tr> data rows (one per function).
    const trCount = (html.match(/<tr data-score=/g) ?? []).length;
    assert.strictEqual(trCount, 3);
  });

  it('makes the function name clickable and labels bare operator overrides', () => {
    const html = buildProjectVibrancyHtml(rowsPayload());
    assert.ok(html.includes('class="fn-link"'));
    // `==` row should render `operator ==`, not bare `==`.
    assert.ok(html.includes('operator =='));
  });

  it('splits file paths into a truncatable directory and an always-visible basename', () => {
    const html = buildProjectVibrancyHtml(rowsPayload());
    assert.ok(html.includes('class="path-dir"'));
    assert.ok(html.includes('class="path-base"'));
    // The basename for the deep path should appear as a separate span so it
    // cannot be eaten by an end-ellipsis.
    assert.ok(html.includes('>contact_drift_io.dart<'));
  });

  it('renders a Changed column with relative ages and an ISO tooltip', () => {
    const html = buildProjectVibrancyHtml(rowsPayload());
    assert.ok(html.includes('class="sortable col-changed"'));
    assert.ok(html.includes('>Changed<'));
    // 3 days → "3d"; 90 days → roughly "3mo" via the days→months bucket.
    assert.ok(/>3d</.test(html));
    assert.ok(/>3mo</.test(html));
  });

  it('shows a problem-count chip in the hero (functions scoring under 50)', () => {
    const html = buildProjectVibrancyHtml(rowsPayload());
    // Two of three rows are under 50 (22.5 and 25.0); the chip should say "2".
    assert.ok(/\b2 problems</.test(html));
    // No hero gauge anymore — the chip carries the triage signal directly.
    assert.ok(!html.includes('class="hero-gauge"'));
  });

  it('renders the saved-report file row with copy / open / reveal actions', () => {
    const reportPath = 'd:/proj/reports/20260525/20260525_143022_saropa_code_health.json';
    const html = buildProjectVibrancyHtml(rowsPayload(), reportPath);
    assert.ok(html.includes('class="report-file"'));
    assert.ok(html.includes(reportPath));
    assert.ok(html.includes('id="copyReportPath"'));
    assert.ok(html.includes('id="openReportFile"'));
    assert.ok(html.includes('id="revealReportFile"'));
  });

  it('does not render the saved-report row when no file path is provided', () => {
    // Failed writes leave reportFilePath undefined; the strip must NOT render
    // a path the user cannot reach (would lie about a non-existent artifact).
    const html = buildProjectVibrancyHtml(rowsPayload());
    assert.ok(!html.includes('class="report-file"'));
    assert.ok(!html.includes('id="copyReportPath"'));
  });

  it('renders `complex` as a sixth flag-filter KPI tile when complex functions exist', () => {
    const html = buildProjectVibrancyHtml(rowsPayload());
    assert.ok(html.includes('data-flag-filter="complex"'));
  });

  it('renders sort arrows on every sortable column for CSS-driven visibility', () => {
    const html = buildProjectVibrancyHtml(rowsPayload());
    // CSS hides the arrow on every column except the active one (aria-sort);
    // the markup carries an arrow per sortable column so the active arrow can
    // appear without re-rendering. Verify the markup AND the default active
    // sort (score, ascending).
    assert.ok(/<th class="sortable col-score" data-sort="score" aria-sort="ascending">/.test(html));
    assert.ok((html.match(/<span class="arrow"/g) ?? []).length >= 7);
  });
});
