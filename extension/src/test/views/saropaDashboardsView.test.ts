/**
 * Pins the "Saropa Dashboards" Home hub shell contract (plan Phase 3).
 *
 * The hub sets its webview HTML once: a hero, a 6-tile KPI band, the controls band, and one card
 * per first-class dashboard (Findings, Rules & Tiers, Packages, Code Health, Project Map, Full
 * Audit) carrying its top signals plus an "Open" deep-link. Unlike the pre-Phase-3 version, nothing
 * here streams in later — every value is a cheap read, so the shell is the whole page.
 */
import '../vibrancy/register-vscode-mock';

import * as assert from 'node:assert';
import { buildShell, type HomeCardSummaries } from '../../views/saropaDashboardsView';
import type { HomeKpis } from '../../views/dashboardSummaries';

const cards: HomeCardSummaries = {
  findings: '<div class="summary-grid" data-test="findings"></div>',
  rulesAndTiers: '<div class="summary-grid" data-test="rulesAndTiers"></div>',
  packages: '<div class="summary-grid" data-test="packages"></div>',
  codeHealth: '<div class="summary-grid" data-test="codeHealth"></div>',
  projectMap: '<div class="summary-grid" data-test="projectMap"></div>',
  fullAudit: '<p class="summary-empty" data-test="fullAudit"></p>',
};

const EMPTY_KPIS: HomeKpis = {
  healthScore: null,
  issueCount: null,
  enginesRunning: null,
  enginesTotal: 3,
  packagesTotal: 0,
  packagesAttention: 0,
  codeHealthGrade: null,
  projectMapScanned: false,
};

describe('saropaDashboardsView buildShell', () => {
  it('renders the KPI band with all 6 tiles', () => {
    const out = buildShell('vscode-resource:', EMPTY_KPIS, cards);
    const tiles = out.match(/class="metric kpi-tile/g) ?? [];
    assert.strictEqual(tiles.length, 6, 'expected exactly 6 KPI tiles');
  });

  it('renders all six dashboard cards', () => {
    const out = buildShell('vscode-resource:', EMPTY_KPIS, cards);
    for (const id of ['findings', 'lintsConfig', 'package', 'codeHealth', 'projectMap', 'fullAudit']) {
      assert.ok(out.includes(`id="paneBody-${id}"`), `card ${id} missing`);
    }
  });

  it('embeds every card summary body', () => {
    const out = buildShell('vscode-resource:', EMPTY_KPIS, cards);
    for (const key of ['findings', 'rulesAndTiers', 'packages', 'codeHealth', 'projectMap', 'fullAudit']) {
      assert.ok(out.includes(`data-test="${key}"`), `summary ${key} not embedded`);
    }
  });

  it('deep-links every card to its standalone dashboard command', () => {
    const out = buildShell('vscode-resource:', EMPTY_KPIS, cards);
    for (const cmd of [
      'saropaLints.openConfigDashboard',
      'saropaLints.packageVibrancy.showReport',
      'saropaLints.openViolationsWideReport',
      'saropaLints.openProjectVibrancyReport',
      'saropaLints.openProjectHealthDashboard',
      'saropaLints.fullAudit',
    ]) {
      assert.ok(out.includes(`data-command="${cmd}"`), `card deep-link ${cmd} missing`);
    }
  });

  it('shows the honest "not scanned" state when a KPI has no data yet', () => {
    const out = buildShell('vscode-resource:', EMPTY_KPIS, cards);
    // Health/issues/engines/packages/code-health/project-size all lack data in EMPTY_KPIS.
    const notScanned = out.match(/Not scanned/g) ?? [];
    assert.ok(notScanned.length > 0, 'expected at least one "not scanned" KPI tile');
  });

  it('renders real KPI values when data is present', () => {
    const kpis: HomeKpis = {
      healthScore: 82,
      issueCount: 143,
      enginesRunning: 2,
      enginesTotal: 3,
      packagesTotal: 40,
      packagesAttention: 3,
      codeHealthGrade: 'B',
      projectMapScanned: true,
    };
    const out = buildShell('vscode-resource:', kpis, cards);
    assert.ok(out.includes('82%'), 'health score value missing');
    assert.ok(out.includes('143'), 'issue count value missing');
    assert.ok(out.includes('2/3'), 'engines running value missing');
    assert.ok(out.includes('>B<'), 'code health grade value missing');
  });

  it('surfaces the Actions / Settings / Help controls in the band', () => {
    const out = buildShell('vscode-resource:', EMPTY_KPIS, cards);
    // The hub is a full entry point: every merged-sidebar command appears
    // in the controls band so users do not have to leave it to operate or configure.
    for (const cmd of [
      // Actions
      'saropaLints.runAnalysis',
      'saropaLints.initializeConfig',
      // Settings
      'saropaLints.openConfigDashboard',
      'saropaLints.toggleRunAnalysisAfterConfigChange',
      'saropaLints.toggleRunAnalysisAfterDependencyChange',
      'saropaLints.pickUiLanguage',
      // Help
      'saropaLints.openWalkthrough',
      'saropaLints.showAbout',
      'saropaLints.openPubDevSaropaLints',
      'saropaLints.createSaropaInstructions',
    ]) {
      assert.ok(out.includes(`data-command="${cmd}"`), `control command ${cmd} missing from band`);
    }
    // The lint-integration button toggles, so its command flips with state.
    const enabled = buildShell('vscode-resource:', EMPTY_KPIS, cards, {
      lintEnabled: true,
      tier: 'recommended',
      runAfterConfig: true,
      runAfterDependency: true,
      uiLanguageLabel: 'English',
    });
    assert.ok(enabled.includes('data-command="saropaLints.disable"'), 'enabled state must offer disable');
    const disabled = buildShell('vscode-resource:', EMPTY_KPIS, cards, {
      lintEnabled: false,
      tier: 'recommended',
      runAfterConfig: true,
      runAfterDependency: true,
      uiLanguageLabel: 'English',
    });
    assert.ok(disabled.includes('data-command="saropaLints.enable"'), 'disabled state must offer enable');
  });

  it('patches only the controls band on a settings toggle (no full re-render)', () => {
    const out = buildShell('vscode-resource:', EMPTY_KPIS, cards);
    assert.ok(out.includes('id="dashControls"'), 'controls band needs an id to patch');
    assert.ok(out.includes("m.type === 'controlsUpdated'"), 'client must handle controlsUpdated');
  });

  it('acquires the VS Code API exactly once', () => {
    const out = buildShell('vscode-resource:', EMPTY_KPIS, cards);
    const acquire = out.match(/acquireVsCodeApi\(\)/g) ?? [];
    assert.strictEqual(acquire.length, 1, 'expected exactly one acquireVsCodeApi() call');
  });
});
