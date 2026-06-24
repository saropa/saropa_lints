/**
 * Pins the "Saropa Dashboards" launchpad shell contract.
 *
 * The launchpad sets its webview HTML once: a hero, the four fast dashboards as live summary cards,
 * and the two heavy dashboards (Project Map, Code Health) as "Scanning…" placeholders that stream in
 * later via `paneReady` messages. These assertions guard the properties that make that safe: exactly
 * one `acquireVsCodeApi()` handle is acquired and re-exposed (the API may be acquired only once per
 * document); ECharts loads exactly once; all six panes are present; the heavy panes carry a rescan
 * control; the four summaries are embedded; and the client injects Project Map's `<style>` verbatim
 * rather than re-wrapping it (the double-wrap that previously spilled CSS onto the page).
 */
import '../vibrancy/register-vscode-mock';

import * as assert from 'node:assert';
import { buildShell, type ShellSummaries } from '../../views/saropaDashboardsView';

const summaries: ShellSummaries = {
  config: '<div class="summary-grid" data-test="config"></div>',
  package: '<div class="summary-grid" data-test="package"></div>',
  findings: '<div class="summary-grid" data-test="findings"></div>',
  catalog: '<div class="summary-grid" data-test="catalog"></div>',
};

const ECHARTS = 'vscode-resource:/media/echarts.min.js';

describe('saropaDashboardsView buildShell', () => {
  it('acquires the VS Code API once and re-exposes it for the embedded engines', () => {
    const out = buildShell('vscode-resource:', ECHARTS, summaries);
    assert.ok(
      out.includes('window.acquireVsCodeApi = function () { return api; };'),
      'shell does not re-expose a shared acquireVsCodeApi handle',
    );
    const realAcquire = out.match(/var api = acquireVsCodeApi\(\);/g) ?? [];
    assert.strictEqual(realAcquire.length, 1, 'expected exactly one host-side API acquisition');
  });

  it('loads ECharts exactly once in the shell head', () => {
    const out = buildShell('vscode-resource:', ECHARTS, summaries);
    const echarts = out.match(/echarts\.min\.js/g) ?? [];
    assert.strictEqual(echarts.length, 1, 'expected exactly one ECharts loader');
  });

  it('renders all six panes', () => {
    const out = buildShell('vscode-resource:', ECHARTS, summaries);
    for (const engine of ['projectMap', 'codeHealth', 'findings', 'lintsConfig', 'package', 'commandCatalog']) {
      assert.ok(out.includes(`id="paneBody-${engine}"`), `pane ${engine} missing`);
    }
  });

  it('embeds the four fast-dashboard summary cards', () => {
    const out = buildShell('vscode-resource:', ECHARTS, summaries);
    for (const key of ['config', 'package', 'findings', 'catalog']) {
      assert.ok(out.includes(`data-test="${key}"`), `summary ${key} not embedded`);
    }
  });

  it('shows the heavy panes scanning and gives each a rescan + deep-link control', () => {
    const out = buildShell('vscode-resource:', ECHARTS, summaries);
    // Heavy panes start in a scanning state, not blank.
    const scanning = out.match(/class="pane-status"/g) ?? [];
    assert.ok(scanning.length >= 2, 'both heavy panes should start in a scanning state');
    assert.ok(out.includes('data-rescan="projectMap"'), 'Project Map rescan control missing');
    assert.ok(out.includes('data-rescan="codeHealth"'), 'Code Health rescan control missing');
    assert.ok(
      out.includes('data-command="saropaLints.openProjectHealthDashboard"'),
      'Project Map open-full deep-link missing',
    );
    assert.ok(
      out.includes('data-command="saropaLints.openProjectVibrancyReport"'),
      'Code Health open-full deep-link missing',
    );
  });

  it('deep-links every light pane to its standalone command', () => {
    const out = buildShell('vscode-resource:', ECHARTS, summaries);
    for (const cmd of [
      'saropaLints.openConfigDashboard',
      'saropaLints.packageVibrancy.showReport',
      'saropaLints.openViolationsWideReport',
      'saropaLints.showCommandCatalog',
    ]) {
      assert.ok(out.includes(`data-command="${cmd}"`), `light deep-link ${cmd} missing`);
    }
  });

  it('keeps Project Map theme tokens + height fixups in the static head, scoped under .pm-pane', () => {
    const out = buildShell('vscode-resource:', ECHARTS, summaries);
    assert.ok(out.includes('.dash-pane .pm-pane { min-height: 0; }'), 'pane height fixup missing');
  });

  it('injects an arriving pane style verbatim (no double <style> wrap that spilled CSS)', () => {
    const out = buildShell('vscode-resource:', ECHARTS, summaries);
    // The client must insert the engine-provided style as raw HTML, not wrap it in another <style>.
    assert.ok(out.includes("insertAdjacentHTML('beforeend', style)"), 'style not injected verbatim');
    assert.ok(!/<style>\s*<style>/.test(out), 'shell must not nest <style> elements');
  });
});
