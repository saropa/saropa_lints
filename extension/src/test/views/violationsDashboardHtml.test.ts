/**
 * Smoke tests for Findings dashboard HTML (suppressions block and core markers).
 */

import * as assert from 'node:assert';
import {
  renderViolationsDashboardHtml,
  type AnalyzerSuppressionsSlice,
  type ViewSuppressionsSlice,
} from '../../views/violationsDashboardHtml';
import type { DashboardSection } from '../../views/issuesTreeModel'; // type-only: no vscode at runtime

const emptyTodoHack = { enabled: false, capped: false, todos: [], hacks: [] };
const emptyDrift = { integrationEnabled: false, connected: false, issues: [] as [] };

const baseAnalyzer: AnalyzerSuppressionsSlice = {
  total: 0,
  byKind: [],
  byRule: [],
  byFile: [],
};

const baseView: ViewSuppressionsSlice = {
  active: false,
  folderCount: 0,
  fileCount: 0,
  ruleCount: 0,
  ruleInFileEntryCount: 0,
  severityCount: 0,
  impactCount: 0,
  sampleFolders: [],
  sampleFiles: [],
  sampleRules: [],
  sampleRuleInFileLines: [],
};

function minimalInput(overrides: Partial<Parameters<typeof renderViolationsDashboardHtml>[0]>) {
  return {
    exportViolations: [],
    totalRawAfterDisable: 0,
    filteredCount: 0,
    truncatedSource: false,
    maxSourceViolations: 4000,
    pageSize: 50,
    groupBy: 'severity' as const,
    textFilter: '',
    severities: ['error', 'warning', 'info'],
    // Three-bucket severity model (post-collapse, 2026-05-03).
    impacts: ['error', 'warning', 'info'],
    sections: [] as DashboardSection[],
    analyzerSuppressions: baseAnalyzer,
    viewSuppressions: baseView,
    todoHackSnapshot: emptyTodoHack,
    driftAdvisorSnapshot: emptyDrift,
    severityCounts: { error: 0, warning: 0, info: 0 },
    impactCounts: { error: 0, warning: 0, info: 0 },
    ...overrides,
  };
}

describe('violationsDashboardHtml', () => {
  it('includes suppressions block and export zero copy', () => {
    const html = renderViolationsDashboardHtml(minimalInput({}));
    assert.ok(html.includes('id="suppressions-block"'));
    assert.ok(html.includes('Suppressions (export)'));
    assert.ok(html.includes('Issues view hides'));
  });

  it('exposes full extension refresh on the toolbar', () => {
    const html = renderViolationsDashboardHtml(minimalInput({}));
    /* The visible toolbar collapses the palette into a "More actions ▾" menu
       (§4.3 density tiers) so we no longer expose a top-level Refresh-extension
       button. The hidden compatibility shim with that id stays for keyboard /
       legacy bindings, plus the saropaLints.refresh command id is present in
       both the menu and the hidden shim. */
    assert.ok(html.includes('id="btn-refresh-extension"'));
    assert.ok(html.includes("commandId: 'saropaLints.refresh'"));
  });

  it('renders analyzer suppressions with rule rows and focus-issues control', () => {
    const slice: AnalyzerSuppressionsSlice = {
      total: 3,
      byKind: [['ignore_for_file', 2]],
      byRule: [['my_rule', 3]],
      byFile: [['lib/a.dart', 1]],
    };
    const html = renderViolationsDashboardHtml(minimalInput({ analyzerSuppressions: slice }));
    assert.ok(html.includes('data-sup="focus-issues"'));
    assert.ok(html.includes('data-sup="rule"'));
    assert.ok(html.includes('my_rule'));
    assert.ok(html.includes('data-sup="file"'));
  });

  it('shows clear button when view suppressions are active', () => {
    const v: ViewSuppressionsSlice = {
      active: true,
      folderCount: 1,
      fileCount: 0,
      ruleCount: 0,
      ruleInFileEntryCount: 0,
      severityCount: 0,
      impactCount: 0,
      sampleFolders: ['lib/generated'],
      sampleFiles: [],
      sampleRules: [],
      sampleRuleInFileLines: [],
    };
    const html = renderViolationsDashboardHtml(minimalInput({ viewSuppressions: v }));
    assert.ok(html.includes('btn-clear-view-sup'));
    assert.ok(html.includes('lib/generated'));
  });

  it('renders the hero status line and last-run pill when a timestamp is supplied', () => {
    const recent = new Date(Date.now() - 90_000).toISOString();
    const html = renderViolationsDashboardHtml(
      minimalInput({ reportTimestamp: recent, extensionVersion: '1.2.3' }),
    );
    assert.ok(html.includes('class="status-line"'));
    assert.ok(html.includes('Last run'));
    assert.ok(html.includes('v1.2.3'));
  });

  it('omits the chart card when every severity and impact slot is zero', () => {
    /* §8.16 / §14.3: do not render an empty chart frame. */
    const html = renderViolationsDashboardHtml(minimalInput({}));
    assert.ok(!html.includes('Severity mix'));
    assert.ok(!html.includes('Impact mix'));
  });

  it('renders the chart card when at least one severity bucket has data', () => {
    const html = renderViolationsDashboardHtml(
      minimalInput({ severityCounts: { error: 2, warning: 0, info: 1 } }),
    );
    assert.ok(html.includes('Severity mix'));
    assert.ok(html.includes('class="bar-fill sev-error"'));
  });

  it('renders KPI cards as preset filters (interactive, role=button)', () => {
    const html = renderViolationsDashboardHtml(
      minimalInput({ severityCounts: { error: 5, warning: 2, info: 0 }, totalRawAfterDisable: 7, filteredCount: 7 }),
    );
    assert.ok(html.includes('class="kpi-row"'));
    assert.ok(html.includes('data-kpi-kind="sev"'));
    assert.ok(html.includes('data-kpi-value="error"'));
  });

  // Replaces the old "splits Critical and High into separate KPI cards" test.
  // After the LintImpact 5→3 collapse on 2026-05-03 the dashboard exposes
  // the analyzer's three severities as separate cards (Errors / Warnings /
  // Info) — Critical and High no longer have their own cards because they
  // collapsed into Errors and Warnings respectively.
  it('exposes one KPI card per severity (errors / warnings / info)', () => {
    const html = renderViolationsDashboardHtml(
      minimalInput({
        impactCounts: { error: 1, warning: 12, info: 0 },
        totalRawAfterDisable: 13,
        filteredCount: 13,
      }),
    );
    assert.ok(html.includes('data-kpi="errors"'));
    assert.ok(html.includes('data-kpi="warnings"'));
    assert.ok(html.includes('data-kpi="info"'));
    // Old per-impact-tier cards must be gone.
    assert.ok(!html.includes('data-kpi="critical"'));
    assert.ok(!html.includes('data-kpi="high"'));
  });

  it('orders KPI cards by importance (Visible > Errors > Warnings > Info > scope)', () => {
    const html = renderViolationsDashboardHtml(
      minimalInput({
        severityCounts: { error: 1, warning: 1, info: 0 },
        impactCounts: { error: 1, warning: 1, info: 0 },
        filesAffected: 5,
        totalRawAfterDisable: 2,
        filteredCount: 2,
      }),
    );
    const order = ['visible', 'errors', 'warnings', 'info', 'files'];
    let cursor = -1;
    for (const key of order) {
      const idx = html.indexOf(`data-kpi="${key}"`);
      assert.ok(idx > cursor, `KPI '${key}' must come after the previous card; got idx=${idx}, cursor=${cursor}`);
      cursor = idx;
    }
  });

  it('shows an active-filters chip strip when filters diverge from defaults', () => {
    const html = renderViolationsDashboardHtml(
      minimalInput({ textFilter: 'foo', severities: ['error'], impacts: ['error', 'warning'] }),
    );
    assert.ok(html.includes('id="chipStrip"'));
    assert.ok(html.includes('Active filters'));
    assert.ok(html.includes('contains'));
  });

  it('hides the chip strip at default filter state', () => {
    const html = renderViolationsDashboardHtml(minimalInput({}));
    assert.ok(!html.includes('id="chipStrip"'));
  });

  it('exposes Save report alongside Copy JSON inside the More-actions overflow menu', () => {
    // §14.4 — Copy JSON and Save report were moved out of the visible toolbar
    // row into the overflow menu so the visible-button budget stays within ~6.
    // The IDs must still render so existing message handlers and test contracts
    // keep working.
    const html = renderViolationsDashboardHtml(minimalInput({}));
    assert.ok(html.includes('id="btn-save"'));
    assert.ok(html.includes('id="btn-copy"'));
  });

  it('renders the Top Rules triage table with per-row Hide and Disable buttons when topRules are supplied', () => {
    const html = renderViolationsDashboardHtml(
      minimalInput({
        filteredCount: 95,
        totalRawAfterDisable: 95,
        severityCounts: { error: 5, warning: 30, info: 60 },
        topRules: [
          { name: 'prefer_no_commented_out_code', count: 60, severity: 'info' },
          { name: 'avoid_print_in_release', count: 25, severity: 'error' },
          { name: 'avoid_unawaited_future', count: 10, severity: 'warning' },
        ],
      }),
    );
    /* Section + table chrome present. */
    assert.ok(html.includes('top-rules-table'));
    assert.ok(html.includes('Top 3 rules'));
    assert.ok(html.includes('aria-label="Top rules by count"'));
    /* Each rule row carries the rule name (HTML-encoded) plus a percent-
       encoded rule id so the script can decode it before posting messages. */
    assert.ok(html.includes('data-rule="prefer_no_commented_out_code"'));
    assert.ok(html.includes('data-rule-enc="prefer_no_commented_out_code"'));
    /* Hide → workspace suppress. Disable → project config (writes YAML). */
    assert.ok(html.includes('data-row-action="hide-rule"'));
    assert.ok(html.includes('data-row-action="disable-rule"'));
    /* Severity pill is rendered next to each rule for triage context. */
    assert.ok(html.includes('sev-pill sev-info'));
    assert.ok(html.includes('sev-pill sev-error'));
    /* Script wires Hide → suppressRule and Disable → disableRule messages. */
    assert.ok(html.includes("type: 'suppressRule'"));
    assert.ok(html.includes("type: 'disableRule'"));
  });

  it('omits the Top Rules table when there are no findings to triage', () => {
    /* Avoids an empty triage shell next to the empty-state findings block.
       Use `aria-label="Top rules by count"` (only emitted by the section
       wrapper) to avoid false matches on the CSS class name in <style> /
       script blocks, which always ship in the page. */
    const html = renderViolationsDashboardHtml(
      minimalInput({
        filteredCount: 0,
        topRules: [{ name: 'should_not_render', count: 1, severity: 'info' }],
      }),
    );
    assert.ok(!html.includes('aria-label="Top rules by count"'));
  });

  it('omits the Top Rules table when topRules is empty', () => {
    const html = renderViolationsDashboardHtml(
      minimalInput({
        filteredCount: 5,
        totalRawAfterDisable: 5,
        severityCounts: { error: 5, warning: 0, info: 0 },
        topRules: [],
      }),
    );
    assert.ok(!html.includes('aria-label="Top rules by count"'));
  });

  it('exposes the keyboard-shortcut overlay trigger and dialog (§15.2)', () => {
    // §15.2 requires page-level shortcuts to be discoverable. The overlay
    // documents `/`, `Esc`, `Enter`, `Space`, and `?` — all bindings the
    // dashboard's inline script wires.
    const html = renderViolationsDashboardHtml(
      minimalInput({
        filteredCount: 1,
        totalRawAfterDisable: 1,
        severityCounts: { error: 1, warning: 0, info: 0 },
      }),
    );
    assert.ok(
      html.includes('id="kbdShortcutsToggle"'),
      'expected kbd-shortcut overlay trigger button',
    );
    assert.ok(
      html.includes('id="kbdShortcutsOverlay"'),
      'expected kbd-shortcut overlay dialog markup',
    );
    assert.ok(
      html.includes('aria-modal="true"'),
      'overlay should be marked as a modal dialog for screen readers',
    );
  });
});
