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

  it('renders the hero status line with a clickable, self-ticking freshness pill', () => {
    const recent = new Date(Date.now() - 90_000).toISOString();
    const html = renderViolationsDashboardHtml(
      minimalInput({ reportTimestamp: recent, extensionVersion: '1.2.3' }),
    );
    assert.ok(html.includes('class="status-line"'));
    // "Updated" replaced "Last run": the stamp reflects the last repaint from
    // live diagnostics, not a separate analysis pass.
    assert.ok(html.includes('Updated'));
    // The pill is a refresh button and carries the ticking template attrs so the
    // webview can re-age the label without a host rebuild.
    assert.ok(html.includes('data-action="refresh"'));
    assert.ok(html.includes('class="freshness-rel"'));
    assert.ok(html.includes(`data-updated-at="${recent}"`));
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

  it('groups the More menu into Export / Filter / Open / System sections with separators', () => {
    /* Pins the menu regroup: each of the four section titles must render
       (so labels are scannable instead of a flat 17-item dump), and at
       least three <hr class="menu-sep"> separators must render (one
       between each adjacent pair of sections). */
    const html = renderViolationsDashboardHtml(minimalInput({}));
    assert.ok(html.includes('Export'));
    // Ampersand is HTML-escaped by buildMoreActionsMenu's escapeHtml call,
    // so the rendered DOM string contains the entity form.
    assert.ok(html.includes('Filter &amp; focus'));
    assert.ok(html.includes('Open dashboard'));
    assert.ok(html.includes('System'));
    const sepCount = (html.match(/class="menu-sep"/g) ?? []).length;
    assert.ok(sepCount >= 3, `expected at least 3 menu-sep separators, got ${sepCount}`);
    assert.ok(html.includes('class="menu-section-title"'));
  });

  it('exposes "Reload from disk" and "Re-enable disabled rules" inside the More menu', () => {
    /* "Reload from disk" replaces the redundant toolbar Refresh button.
       "Re-enable disabled rules" closes the gap where disabling a rule
       from the dashboard left no in-dashboard path back. Both must be
       present in the rendered menu HTML. */
    const html = renderViolationsDashboardHtml(minimalInput({}));
    assert.ok(html.includes('id="btn-reload-disk"'));
    assert.ok(html.includes('Reload from disk'));
    assert.ok(html.includes('data-palette-cmd="saropaLints.reEnableDisabledRules"'));
    assert.ok(html.includes('Re-enable disabled rules'));
  });

  it('removes the duplicate Impact filter UI from the dashboard', () => {
    /* Post-collapse (2026-05-03) impact mirrors severity, so the second
       pill row, the Group-by-Impact option, the Impact-mix donut, and
       the imp-off chips were all duplicates. Pin their absence so they
       cannot drift back in. */
    const html = renderViolationsDashboardHtml(
      minimalInput({
        // Non-zero severity AND non-zero impact so the chart block is
        // genuinely allowed to render — we want to assert Impact stays
        // out even when data is present.
        severityCounts: { error: 1, warning: 2, info: 3 },
        impactCounts: { error: 1, warning: 2, info: 3 },
        // Diverge filters from defaults so the chip strip renders.
        severities: ['error'],
        impacts: ['error'],
      }),
    );
    assert.ok(!html.includes('data-imp="'));
    assert.ok(!html.includes('imp-off'));
    assert.ok(!html.includes('<option value="impact"'));
    assert.ok(!html.includes('Impact mix'));
    assert.ok(!html.includes('class="seg-label">Impact'));
  });

  it('reverses file-path truncation in finding rows so the filename stays visible', () => {
    /* Scoped CSS rule on .findings-table .col-msg .kpi-sub uses
       direction: rtl + text-align: left + unicode-bidi: plaintext to
       anchor the path to the right of the cell — when the column
       narrows, the FRONT of the path is clipped and the filename
       stays visible. */
    const html = renderViolationsDashboardHtml(minimalInput({}));
    assert.ok(html.includes('.findings-table .col-msg .kpi-sub'));
    assert.ok(html.includes('unicode-bidi: plaintext'));
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

  it('renders the health gauge without a /100 suffix and without the restart-prone animation', () => {
    /* Item 1 + 2: the visible score dropped its "/100" denominator, and the
       gauge fill is a static SVG dasharray (the gauge-fill-in keyframe that
       collapsed the ring to a dot on every rebuild is gone). */
    const html = renderViolationsDashboardHtml(minimalInput({}));
    assert.ok(!html.includes('/100'), 'gauge label and tooltip must not show /100');
    assert.ok(!html.includes('gauge-fill-in'), 'entrance keyframe must be removed');
    assert.ok(!html.includes('--gauge-target'), 'inline gauge CSS vars must be removed');
  });

  it('wires the pending gauge state for in-flight analysis (whiplash guard)', () => {
    /* Item 3: a not-yet-settled health score is dimmed to "computing" instead
       of flashing a misleading grade. The scaffolding + script hooks must ship. */
    const html = renderViolationsDashboardHtml(minimalInput({}));
    assert.ok(html.includes('data-pending="false"'));
    assert.ok(html.includes('class="gauge-pending"'));
    assert.ok(html.includes('setGaugePending'));
    assert.ok(html.includes("msg.type === 'gaugePending'"));
  });

  it('renders sortable headers and expandable rows in the Top Rules table', () => {
    /* Item 4 + 7: Rule / Count / Severity headers are click-to-sort (Rank is a
       stable position, so it is not sortable), and each rule row expands to its
       full message + affected-file breakdown when that detail is supplied. */
    const html = renderViolationsDashboardHtml(
      minimalInput({
        filteredCount: 70,
        totalRawAfterDisable: 70,
        severityCounts: { error: 0, warning: 0, info: 70 },
        topRules: [
          {
            name: 'prefer_const_constructors',
            count: 40,
            severity: 'info',
            message: 'Prefer const with constant constructors.',
            files: [
              { file: 'lib/a.dart', count: 25, line: 12 },
              { file: 'lib/b.dart', count: 15, line: 3 },
            ],
          },
          {
            name: 'avoid_print',
            count: 30,
            severity: 'warning',
            message: 'Avoid print calls in production code.',
            files: [{ file: 'lib/c.dart', count: 30, line: 7 }],
          },
        ],
      }),
    );
    assert.ok(html.includes('data-sort="rule"'));
    assert.ok(html.includes('data-sort="count"'));
    assert.ok(html.includes('data-sort="sev"'));
    // A rendered detail row (not the script's selector string) proves the row
    // expanded; key off the per-rule detail id which only the markup emits.
    assert.ok(html.includes('id="trd-prefer_const_constructors"'));
    assert.ok(html.includes('class="trow-detail"'));
    assert.ok(html.includes('Prefer const with constant constructors.'));
    assert.ok(html.includes('Files affected (2)'));
    assert.ok(html.includes('data-file="lib%2Fa.dart"'));
    assert.ok(html.includes('data-line="12"'));
  });

  it('keeps Top Rules rows flat (non-expandable) when no message or files are supplied', () => {
    /* Count-only rows (e.g. legacy callers) must not advertise a chevron that
       reveals nothing — the row renders flat, with the action buttons intact. */
    const html = renderViolationsDashboardHtml(
      minimalInput({
        filteredCount: 10,
        totalRawAfterDisable: 10,
        severityCounts: { error: 0, warning: 0, info: 10 },
        topRules: [{ name: 'some_rule', count: 10, severity: 'info' }],
      }),
    );
    // No rendered detail row, and the chevron slot is the hidden placeholder
    // (so the row carries no "click to reveal" affordance). `class="trow-detail"`
    // is emitted only by an actual detail row, never by the script.
    assert.ok(!html.includes('class="trow-detail"'));
    assert.ok(html.includes('trow-chev placeholder'));
    assert.ok(html.includes('data-row-action="hide-rule"'));
  });

  it('pins the group-by select dropdown to readable VS Code tokens', () => {
    /* Item 5: the open option list previously inherited a transparent
       background and a low-contrast bright highlight. */
    const html = renderViolationsDashboardHtml(minimalInput({}));
    assert.ok(html.includes('.field select option'));
    assert.ok(html.includes('--vscode-dropdown-background'));
  });

  it('renders findings bulk-selection and multi-sort markup when violations are shown', () => {
    const sections: DashboardSection[] = [
      {
        kind: 'severity',
        severity: 'error',
        files: [
          {
            filePath: 'lib/a.dart',
            violations: [
              {
                file: 'lib/a.dart',
                line: 10,
                rule: 'test_rule',
                message: 'hello',
                severity: 'error',
              },
            ],
          },
        ],
      },
    ];
    const html = renderViolationsDashboardHtml(
      minimalInput({
        filteredCount: 1,
        totalRawAfterDisable: 1,
        sections,
      }),
    );
    assert.ok(html.includes('id="findings-bulk-bar"'));
    assert.ok(html.includes('bulk-select-all'));
    assert.ok(html.includes('class="bulk-row-cb"'));
    assert.ok(html.includes('hydrateRecentSearches'));
    assert.ok(html.includes('sortLevels'));
    assert.ok(html.includes('saveFindingsRecent'));
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

  /* ──────────────────────────────────────────────────────────────────────
   * Scanner promo pill. The file-system TODO/HACK scanner shows a muted promo
   * pill when it is off and the workspace has Dart files. The analyzer
   * "other findings" / "analyzer todos" supplementary pills were removed once
   * the dashboard became holistic — those diagnostics now appear directly in
   * the main findings list, so there is no separate gap to surface.
   * ────────────────────────────────────────────────────────────────────── */
  function withScanner(
    s: Partial<NonNullable<Parameters<typeof renderViolationsDashboardHtml>[0]['scanner']>>,
  ): string {
    return renderViolationsDashboardHtml(
      minimalInput({
        scanner: { enabled: false, hasDartFiles: false, ...s },
      }),
    );
  }

  it('renders no scanner promo when the scanner slice is omitted', () => {
    const html = renderViolationsDashboardHtml(minimalInput({}));
    assert.ok(!html.includes('data-toggle="scanner"'));
  });

  it('renders scanner promo only when scanner off AND hasDartFiles', () => {
    // Suggesting the scanner in a non-Dart workspace would be noise — guard
    // against that explicitly. Likewise, no promo when scanner is already on.
    const offNoDart = withScanner({ enabled: false, hasDartFiles: false });
    assert.ok(!offNoDart.includes('data-toggle="scanner"'));

    const offWithDart = withScanner({ enabled: false, hasDartFiles: true });
    assert.ok(offWithDart.includes('data-toggle="scanner"'));
    assert.ok(offWithDart.includes('toggle promo'));
  });

  it('renders no scanner promo when the scanner is already on', () => {
    const html = withScanner({ enabled: true, hasDartFiles: true });
    assert.ok(!html.includes('data-toggle="scanner"'));
  });
});
