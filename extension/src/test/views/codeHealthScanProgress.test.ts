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

/**
 * Pull a named helper out of the generated webview script and turn it back into a
 * callable, so tests can assert what it *does*, not merely that it's present.
 * Balances braces (the simple non-greedy regex would stop at the first `}` and
 * truncate multi-block bodies like fmtDuration).
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

  it('formats counts with thousands separators and durations with units', () => {
    assert.ok(html.includes("textContent = fmtNum"), 'counters not run through fmtNum');
    assert.ok(html.includes('textContent = fmtDuration(s)'), 'elapsed not run through fmtDuration');
    // Execute the generated helpers, not just assert they exist: an earlier bug
    // had a fmtNum present but inert (its regex collapsed inside the template
    // literal), so the function existed yet produced no commas.
    const fmtNum = extractFn(html, 'fmtNum');
    assert.strictEqual(fmtNum(3604), '3,604', 'four-figure count not grouped');
    assert.strictEqual(fmtNum(452887), '452,887', 'six-figure count not grouped');
    const fmtDuration = extractFn(html, 'fmtDuration');
    assert.strictEqual(fmtDuration(42), '42s', 'sub-minute duration wrong');
    assert.strictEqual(fmtDuration(6762), '1h 52m', 'multi-thousand-second duration not rolled to h/m');
  });

  it('makes problem rows clickable to open the function at its line', () => {
    assert.ok(html.includes("type:'openFile'"), 'row click does not post openFile');
    assert.ok(html.includes("file: ev.file"), 'openFile omits the file');
    assert.ok(html.includes("line: ev.line"), 'openFile omits the line');
    assert.ok(html.includes("'clickable'"), 'clickable affordance missing');
  });

  it('keeps the filename visible and labels bare operator names', () => {
    // Split path rendering: directory truncates, basename stays whole.
    assert.ok(html.includes('function applyPath'), 'path splitter missing');
    assert.ok(html.includes('path-base'), 'always-visible basename span missing');
    assert.ok(html.includes("'operator '"), 'operator labeling missing');
  });

  it('lays the problem table out as a fixed-column grid', () => {
    assert.ok(html.includes('grid-template-columns'), 'uniform grid columns missing');
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
