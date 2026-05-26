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

/**
 * Extract the JSON-embedded row data from the generated HTML. The rewrite ships
 * rows as a JSON script block and renders into the DOM client-side, so the
 * server-rendered HTML no longer contains `<tr>` cells — tests have to read
 * either the JSON block or extract+execute the JS helpers.
 */
function extractRowData(html: string): unknown[] {
  const m = html.match(/<script id="pvRowData"[^>]*>([\s\S]*?)<\/script>/);
  if (!m) throw new Error('row data script not found');
  return JSON.parse(m[1]) as unknown[];
}

/**
 * Brace-match a named function out of the embedded inline script and return it
 * as a callable. Used to verify behavior of the boilerplate-detector / row
 * renderer / age formatter rather than just asserting their text is present
 * (an earlier session's bug had `fmtNum` present but inert; pinning behavior
 * by execution catches that class).
 */
function extractFn(html: string, name: string): (...args: unknown[]) => unknown {
  const start = html.indexOf(`function ${name}(`);
  if (start < 0) throw new Error(`${name} not found in generated HTML`);
  let depth = 0;
  let end = html.indexOf('{', start);
  for (let i = end; i < html.length; i++) {
    if (html[i] === '{') depth++;
    else if (html[i] === '}' && --depth === 0) {
      end = i + 1;
      break;
    }
  }
  // eslint-disable-next-line no-eval
  return eval(`(${html.slice(start, end)})`) as (...args: unknown[]) => unknown;
}

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

  it('drops the grade column and the score header carries a formula tooltip', () => {
    const html = buildProjectVibrancyHtml(rowsPayload());
    assert.ok(!html.includes('data-sort="grade"'));
    assert.ok(!html.includes('col-grade'));
    // Score header tooltip explains the composite (so users stop asking "what
    // does score mean?"). Quotes are HTML-escaped (&quot;) in the title attr,
    // so match against the unquoted core wording.
    assert.ok(/title="Composite health score[^"]*Formula: 40%/.test(html));
  });

  it('embeds the FULL function list as a JSON data block (no 200-cap; no DOM lockup)', () => {
    const html = buildProjectVibrancyHtml(rowsPayload());
    const rows = extractRowData(html);
    assert.strictEqual(rows.length, 3, 'all three rows must reach the client');
    // The tbody is empty initially — the script renders the visible window.
    // (Pre-rewrite, server-rendered 18k+ <tr>s locked the browser. The literal
    // string `<tr data-key="` also appears in the inline rowHtml template, so
    // this assertion has to look inside the actual <tbody>.)
    const tbodyMatch = html.match(/id="pvBody">([\s\S]*?)<\/tbody>/);
    assert.ok(tbodyMatch, 'tbody not found');
    assert.strictEqual(tbodyMatch![1].trim(), '');
    // Header count shows 0 initially; the script fills it on first render.
    assert.ok(html.includes('showing 0 of 3'));
  });

  it('boilerplate detector hides operators + equality/serialization names', () => {
    const html = buildProjectVibrancyHtml(rowsPayload());
    // isBoilerplate references the BOILERPLATE_NAMES table from the same
    // closure. Inject a matching table here so the extracted function resolves
    // it via the test scope. The list MUST stay in sync with the script.
    // eslint-disable-next-line @typescript-eslint/no-unused-vars
    const BOILERPLATE_NAMES: Record<string, number> = {
      hashCode: 1, toString: 1, noSuchMethod: 1,
      copyWith: 1, props: 1,
      fromJson: 1, toJson: 1, fromMap: 1, toMap: 1,
    };
    // Force the table to be available to the eval'd function via globalThis.
    (globalThis as unknown as { BOILERPLATE_NAMES: typeof BOILERPLATE_NAMES }).BOILERPLATE_NAMES = BOILERPLATE_NAMES;
    const isBoilerplate = extractFn(html, 'isBoilerplate') as (n: string) => boolean;
    assert.strictEqual(isBoilerplate('=='), true);
    assert.strictEqual(isBoilerplate('<='), true);
    assert.strictEqual(isBoilerplate('[]'), true);
    for (const n of ['hashCode', 'toString', 'noSuchMethod', 'copyWith', 'fromJson', 'toJson', 'fromMap', 'toMap', 'props']) {
      assert.strictEqual(isBoilerplate(n), true, `${n} should be boilerplate`);
    }
    for (const n of ['dispose', 'build', 'main', 'dbContactCount', 'run']) {
      assert.strictEqual(isBoilerplate(n), false, `${n} should NOT be boilerplate`);
    }
  });

  it('boilerplate-hide checkbox is present and defaults ON', () => {
    const html = buildProjectVibrancyHtml(rowsPayload());
    assert.ok(html.includes('id="hideBoilerplate"'));
    assert.ok(/id="hideBoilerplate"[^>]*checked/.test(html));
  });

  it('row renderer covers score pill, fn-link, path split, relative age, operator label', () => {
    // rowHtml has many closure deps (hslForScore, fmtAge, displayName, esc) so
    // we assert template fragments are present rather than executing it. Per-
    // helper unit tests below cover the pure functions (displayName, rowKey,
    // isBoilerplate).
    const html = buildProjectVibrancyHtml(rowsPayload());
    assert.ok(html.includes('class="score-pill"'));
    assert.ok(html.includes('class="fn-link"'));
    assert.ok(html.includes('class="path-dir"'));
    assert.ok(html.includes('class="path-base"'));
    assert.ok(html.includes("'operator ' + name"), 'operator label expression should be present');
    // Selection checkboxes were removed — filters drive the bulk-copy now.
    assert.ok(!html.includes('class="row-check"'));
    assert.ok(!html.includes('id="pvSelectAll"'));
    assert.ok(!html.includes('class="col-select"'));
  });

  it('displayName labels operators and passes identifier names through', () => {
    const html = buildProjectVibrancyHtml(rowsPayload());
    const displayName = extractFn(html, 'displayName') as (n: string) => string;
    assert.strictEqual(displayName('=='), 'operator ==');
    assert.strictEqual(displayName('[]'), 'operator []');
    assert.strictEqual(displayName('main'), 'main');
    assert.strictEqual(displayName('_private'), '_private');
    assert.strictEqual(displayName(''), '');
  });

  it('shows a problem-count chip in the hero (functions scoring under 50)', () => {
    const html = buildProjectVibrancyHtml(rowsPayload());
    // Two of three rows are under 50 (22.5 and 25.0); the chip should say "2".
    assert.ok(/\b2 problems</.test(html));
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
    const html = buildProjectVibrancyHtml(rowsPayload());
    assert.ok(!html.includes('class="report-file"'));
    assert.ok(!html.includes('id="copyReportPath"'));
  });

  it('renders `complex` as a sixth flag-filter KPI tile when complex functions exist', () => {
    const html = buildProjectVibrancyHtml(rowsPayload());
    assert.ok(html.includes('data-flag-filter="complex"'));
  });

  it('marks the default-sorted column (score, ascending) so the CSS arrow shows', () => {
    const html = buildProjectVibrancyHtml(rowsPayload());
    assert.ok(/<th class="sortable col-score" data-sort="score" aria-sort="ascending"/.test(html));
    // Every sortable column carries an arrow span; CSS reveals it only on the
    // active aria-sort. There are 8 sortable columns now (score, name, file,
    // line, usage, coverage, complexity, changed).
    assert.ok((html.match(/<span class="arrow"/g) ?? []).length >= 8);
  });

  it('toolbar exposes filter-driven bulk-copy + score threshold input', () => {
    const html = buildProjectVibrancyHtml(rowsPayload());
    // Copy filtered button is present and starts disabled (the script enables
    // it once the filtered row count is non-zero).
    assert.ok(/id="copyFiltered"[^>]*disabled/.test(html));
    // Score-threshold numeric input.
    assert.ok(/id="pvScoreMax"[^>]*type="number"/.test(html));
    // Selection UI must NOT be present — filters drive the workflow now.
    assert.ok(!html.includes('id="copySelected"'));
    assert.ok(!html.includes('id="pvSelectAll"'));
  });

  it('KPI tiles toggle multi-select state (clicking adds/removes flags)', () => {
    const html = buildProjectVibrancyHtml(rowsPayload());
    // The script holds an object/set of active flags, not a single string.
    assert.ok(html.includes('state.flags'));
    assert.ok(html.includes('state.flagCount'));
    // The active-filter strip emits a chip per active flag (key 'flag:<name>').
    assert.ok(html.includes("'flag:'"));
    // Score threshold also appears in the strip when set.
    assert.ok(html.includes("'score ≤ '"));
  });

  it('emits a "Show next N" load-more button (hidden initially; script unhides)', () => {
    const html = buildProjectVibrancyHtml(rowsPayload());
    assert.ok(html.includes('id="pvLoadMore"'));
    assert.ok(html.includes('id="pvLoadMoreBtn"'));
    // Initially hidden — the script unhides once it knows the visible window
    // is smaller than the filtered list.
    assert.ok(/id="pvLoadMore"[^>]*hidden/.test(html));
  });

  it('row data is keyed by file:line:name for stable selection across sort/filter', () => {
    const html = buildProjectVibrancyHtml(rowsPayload());
    const rowKey = extractFn(html, 'rowKey') as (r: unknown) => string;
    const k = rowKey({ file: 'lib/a.dart', name: '==', lineStart: 5 });
    assert.strictEqual(k, 'lib/a.dart:5:==');
  });
});
