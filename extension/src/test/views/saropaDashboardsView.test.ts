/**
 * Pins the iframe drill-down bridge for the consolidated "Saropa Dashboards" view.
 *
 * Each engine's report is embedded in an `<iframe srcdoc>` where the real `acquireVsCodeApi()` is
 * absent, so `injectIframeBridge` injects a shim that bubbles the report's `postMessage` calls up to
 * the host tagged with a `__src` source. The host relays them to the extension and dispatches by
 * source. These assertions guard the contract that makes the row-click drill-down reach the editor:
 * the shim is present, source-tagged, defined before the engine's body scripts run, and leaves the
 * rest of the report untouched.
 */
import '../vibrancy/register-vscode-mock';

import * as assert from 'node:assert';
import { injectIframeBridge } from '../../views/saropaDashboardsView';

describe('saropaDashboardsView injectIframeBridge', () => {
  const sample = '<html><head><meta charset="UTF-8"></head><body><div id="x">hi</div></body></html>';

  it('defines an acquireVsCodeApi shim so the embedded report can post messages', () => {
    const out = injectIframeBridge(sample, 'projectMap');
    assert.ok(out.includes('window.acquireVsCodeApi'), 'shim does not define acquireVsCodeApi');
    assert.ok(out.includes('parent.postMessage'), 'shim does not bubble to the parent host');
  });

  it('tags bubbled messages with the source so the host can dispatch by pane', () => {
    assert.ok(injectIframeBridge(sample, 'projectMap').includes("__src: 'projectMap'"));
    assert.ok(injectIframeBridge(sample, 'codeHealth').includes("__src: 'codeHealth'"));
  });

  it('injects the shim before </head> so it runs before the engine body scripts', () => {
    const out = injectIframeBridge(sample, 'projectMap');
    const shimIdx = out.indexOf('acquireVsCodeApi');
    const headEnd = out.indexOf('</head>');
    const bodyStart = out.indexOf('<body>');
    assert.ok(shimIdx > -1 && headEnd > -1, 'shim or </head> missing');
    assert.ok(shimIdx < headEnd, 'shim must be inside <head>');
    assert.ok(headEnd < bodyStart, 'shim must precede the body');
  });

  it('leaves the rest of the report document intact', () => {
    const out = injectIframeBridge(sample, 'projectMap');
    assert.ok(out.includes('<div id="x">hi</div>'), 'report body content was altered');
    assert.ok(out.includes('<meta charset="UTF-8">'), 'report head content was altered');
  });
});
