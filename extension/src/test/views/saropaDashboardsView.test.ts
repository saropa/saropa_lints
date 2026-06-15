/**
 * Pins the single-document composition contract for the consolidated "Saropa Dashboards" view.
 *
 * The view assembles both engines' real markup into ONE webview document (not iframes). Two
 * properties make that safe and must hold: exactly one `acquireVsCodeApi()` handle is acquired and
 * shared (the API may be acquired only once per document), and Project Map's styles stay scoped
 * under `.pm-pane` so they cannot leak onto the shared chrome or the Code Health pane. These
 * assertions guard both, plus that each pane's content is present and that a failed scan degrades
 * to an inline placeholder rather than blanking the page.
 */
import '../vibrancy/register-vscode-mock';

import * as assert from 'node:assert';
import { buildDashboardsDocument } from '../../views/saropaDashboardsView';
import type { ProjectMapParts } from '../../views/projectMapView';
import type { CodeHealthFragment } from '../../views/projectVibrancyReportView';

const pmParts: ProjectMapParts = {
  styleHtml: '<style>.pm-pane .banner { color: red; } .pm-pane table { width: 100%; }</style>',
  bodyHtml: '<div class="pm-pane"><div id="treemap"></div><table id="hot"></table></div>',
  scriptHtml: 'var pmApi = acquireVsCodeApi();',
  echartsUri: 'https://example/echarts.min.js',
};
const chFrag: CodeHealthFragment = {
  body: '<header class="dash-hero"><h1>Code Health</h1></header><table id="pvTable"></table>',
  script: '(function(){ var vscode = acquireVsCodeApi(); })();',
};

describe('saropaDashboardsView buildDashboardsDocument', () => {
  it('acquires the VS Code API once and re-exposes it for both engines', () => {
    const out = buildDashboardsDocument('vscode-resource:', pmParts, chFrag);
    // The shim acquires once and overrides the global so both engine scripts share the handle.
    assert.ok(out.includes('window.acquireVsCodeApi = function () { return api; };'),
      'host does not re-expose a shared acquireVsCodeApi handle');
    // Exactly one real acquisition by the host (the engines call the re-exposed global, not a
    // fresh `var ... = acquireVsCodeApi()` that VS Code would reject as a second acquisition).
    const realAcquire = out.match(/var api = acquireVsCodeApi\(\);/g) ?? [];
    assert.strictEqual(realAcquire.length, 1, 'expected exactly one host-side API acquisition');
  });

  it('embeds both engines markup and scripts in one document', () => {
    const out = buildDashboardsDocument('vscode-resource:', pmParts, chFrag);
    assert.ok(out.includes('<div class="pm-pane">'), 'Project Map markup missing');
    assert.ok(out.includes('id="pvTable"'), 'Code Health markup missing');
    assert.ok(out.includes('var pmApi = acquireVsCodeApi();'), 'Project Map script missing');
    assert.ok(out.includes('var vscode = acquireVsCodeApi();'), 'Code Health script missing');
    // ECharts is loaded exactly once for the Project Map pane.
    const echarts = out.match(/echarts\.min\.js/g) ?? [];
    assert.strictEqual(echarts.length, 1, 'expected exactly one ECharts loader');
  });

  it('keeps Project Map styles scoped under .pm-pane so they cannot leak', () => {
    const out = buildDashboardsDocument('vscode-resource:', pmParts, chFrag);
    // Every Project Map bespoke selector that could collide is prefixed.
    assert.ok(out.includes('.pm-pane .banner'), 'banner rule not scoped');
    assert.ok(out.includes('.pm-pane table'), 'table rule not scoped');
    // The host shrinks the standalone full-viewport pane back to content height.
    assert.ok(out.includes('.dash-pane .pm-pane { min-height: 0; }'), 'pane height fixup missing');
  });

  it('degrades a failed scan to an inline placeholder without dropping the other pane', () => {
    const out = buildDashboardsDocument('vscode-resource:', null, chFrag);
    assert.ok(out.includes('pane-failed'), 'failed pane should show a placeholder');
    assert.ok(out.includes('id="pvTable"'), 'the surviving pane must still render');
    // No ECharts loader and no Project Map script when its scan failed.
    assert.ok(!out.includes('echarts.min.js'), 'no ECharts when Project Map scan failed');
  });
});
