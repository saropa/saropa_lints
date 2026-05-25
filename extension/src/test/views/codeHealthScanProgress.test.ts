/**
 * Render coverage for the Code Health Dashboard's scanning-state view.
 *
 * This is the surface that replaced the frozen "scanning…" notification: it must
 * open with a live progress bar, the phase stepper, running counters, and the
 * Pause/Restart/Cancel controls, and its script must acquire the webview API so
 * streamed events can patch the DOM. Pins those elements so the scanning UX
 * cannot silently regress to a blank/static panel.
 */
import '../vibrancy/register-vscode-mock';

import * as assert from 'node:assert';

import { buildCodeHealthScanningHtml } from '../../views/codeHealthScanProgress';

describe('Code Health scanning-state HTML', () => {
  const html = buildCodeHealthScanningHtml();

  it('renders the progress bar and current-file line', () => {
    assert.ok(html.includes('id="barFill"'), 'progress bar fill missing');
    assert.ok(html.includes('id="currentFile"'), 'current-file line missing');
    assert.ok(html.includes('id="phasePct"'), 'percent readout missing');
  });

  it('renders the five-phase stepper', () => {
    for (const phase of ['parse', 'history', 'blame', 'usage', 'score']) {
      assert.ok(html.includes(`data-phase="${phase}"`), `stepper missing phase ${phase}`);
    }
  });

  it('renders the live counters and the worst-functions preview', () => {
    assert.ok(html.includes('id="cFiles"'), 'files counter missing');
    assert.ok(html.includes('id="cFns"'), 'functions counter missing');
    assert.ok(html.includes('id="cProb"'), 'problems counter missing');
    assert.ok(html.includes('id="probList"'), 'problems preview list missing');
  });

  it('renders pause, restart, and cancel controls', () => {
    assert.ok(html.includes('id="btnPause"'), 'pause button missing');
    assert.ok(html.includes('id="btnRestart"'), 'restart button missing');
    assert.ok(html.includes('id="btnCancel"'), 'cancel button missing');
  });

  it('acquires the webview API and posts control messages', () => {
    assert.ok(html.includes('acquireVsCodeApi()'), 'webview API not acquired');
    assert.ok(html.includes("type:'pause'") || html.includes('type: \'pause\''), 'pause not posted');
    assert.ok(html.includes("type:'cancel'") || html.includes('type: \'cancel\''), 'cancel not posted');
    assert.ok(html.includes("type:'restart'") || html.includes('type: \'restart\''), 'restart not posted');
  });

  it('carries a CSP that confines styles and scripts to the nonce', () => {
    assert.ok(html.includes("default-src 'none'"), 'CSP default-src missing');
    assert.ok(/script-src 'nonce-[A-Za-z0-9]+'/.test(html), 'script nonce CSP missing');
  });

  it('shows the extension version and an engine-version slot', () => {
    const versioned = buildCodeHealthScanningHtml('99.9.9');
    assert.ok(versioned.includes('Saropa Lints v99.9.9'), 'extension version missing');
    assert.ok(versioned.includes('id="engineVer"'), 'engine version slot missing');
  });
});
