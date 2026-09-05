/**
 * Unit tests for the Project Map webview shell (`projectMapShell.ts`). This
 * module had zero test coverage before this pass (deferred from Phase 6 —
 * see docs/handover/20260905_0011_keyboard_overlay_and_dead_code.md) even
 * though it is the composite document every Project Map render goes through:
 * the tab bar, the scanning-state pane, the done-state pane, and (as of this
 * pass) the shared '?' keyboard-shortcuts overlay. These tests pin the HTML
 * shape so a future refactor of the shell cannot silently drop a tab, an aria
 * attribute, or the overlay wiring.
 */
import * as assert from 'node:assert';
import type * as vscode from 'vscode';
import {
  buildShellHtml,
  buildScanningMapPaneHtml,
  buildDoneMapPaneHtml,
} from '../../views/projectMapShell';
import type { ProjectMapParts } from '../../views/projectMapView';

/**
 * Minimal fake `vscode.Webview` — `buildShellHtml` only reads `.cspSource` to
 * build its CSP meta tag, so a full vscode-mock module is unnecessary here
 * (and `projectMapShell.ts` itself never imports 'vscode' at runtime: its
 * `vscode.Webview` parameter type is erased by TypeScript's import elision
 * since nothing in the module touches the `vscode` namespace at runtime).
 */
function fakeWebview(): vscode.Webview {
  return { cspSource: 'vscode-webview://fake-csp-source' } as unknown as vscode.Webview;
}

describe('projectMapShell buildShellHtml', () => {
  it('renders both tab buttons with correct roles, aria wiring, and active state', () => {
    const html = buildShellHtml(fakeWebview(), '<p>map content</p>', '<p>reports content</p>');
    // Map starts active (aria-selected="true", not [hidden]); Reports starts hidden.
    assert.ok(html.includes('id="pmTabBtnMap"'));
    assert.ok(html.includes('id="pmTabBtnReports"'));
    assert.ok(html.includes('role="tab"'));
    assert.ok(html.includes('role="tablist"'));
    assert.ok(/id="pmTabBtnMap"[^>]*aria-selected="true"/.test(html));
    assert.ok(/id="pmTabBtnReports"[^>]*aria-selected="false"/.test(html));
    assert.ok(/id="pmTabReports"[^>]*hidden/.test(html), 'Reports panel must start hidden');
    assert.ok(!/id="pmTabMap"[^>]*hidden/.test(html), 'Map panel must start visible');
  });

  it('embeds the map and reports pane content verbatim inside their panels', () => {
    const html = buildShellHtml(fakeWebview(), '<p>MAP_MARKER</p>', '<p>REPORTS_MARKER</p>');
    assert.ok(html.includes('MAP_MARKER'));
    assert.ok(html.includes('REPORTS_MARKER'));
    // MAP_MARKER must be inside the Map section, not the Reports section.
    const mapSectionStart = html.indexOf('id="pmTabMap"');
    const reportsSectionStart = html.indexOf('id="pmTabReports"');
    const markerIdx = html.indexOf('MAP_MARKER');
    assert.ok(markerIdx > mapSectionStart && markerIdx < reportsSectionStart);
  });

  it('sets a CSP meta tag scoped to the webview cspSource with unsafe-inline for style/script', () => {
    const html = buildShellHtml(fakeWebview(), '', '');
    assert.match(html, /Content-Security-Policy/);
    assert.match(html, /style-src vscode-webview:\/\/fake-csp-source 'unsafe-inline'/);
    assert.match(html, /script-src vscode-webview:\/\/fake-csp-source 'unsafe-inline'/);
  });

  it('surfaces the shared "?" keyboard-shortcuts button and overlay listing the 1-2 tab shortcut', () => {
    // Phase 7 leftover fixed by this pass: Project Map already had working digit
    // shortcuts (1/2, wired in pmShellScript below) but no discoverable '?' overlay.
    const html = buildShellHtml(fakeWebview(), '', '');
    assert.ok(html.includes('id="kbdShortcutsToggle"'), 'expected the shared shortcuts trigger button');
    assert.ok(html.includes('id="kbdShortcutsOverlay"'), 'expected the shared shortcuts overlay markup');
    assert.ok(html.includes('1-2'), 'overlay must document the 1/2 tab-jump shortcut');
  });

  it('wires the digit-shortcut keydown handler and the shared overlay script into the one inline <script>', () => {
    const html = buildShellHtml(fakeWebview(), '', '');
    // Both scripts share one nonce-less <script> tag (unsafe-inline CSP) rather
    // than a second tag, so a script-src rule need not be duplicated.
    const scriptMatches = html.match(/<script>/g) ?? [];
    assert.strictEqual(scriptMatches.length, 1, 'expected exactly one inline <script> tag');
    assert.ok(html.includes("e.key === '1'"));
    assert.ok(html.includes("e.key === '2'"));
    assert.ok(html.includes('kbdShortcutsToggle'));
  });
});

describe('projectMapShell buildScanningMapPaneHtml', () => {
  it('renders the spinner, elapsed timer, and cancel/restart controls', () => {
    const html = buildScanningMapPaneHtml();
    assert.ok(html.includes('id="pmScan"'));
    assert.ok(html.includes('class="spinner"'));
    assert.ok(html.includes('id="pmScanElapsed"'));
    assert.ok(html.includes('id="pmCancelBtn"'));
    assert.ok(html.includes('id="pmRestartBtn"'));
  });

  it('starts with the activity log empty-state visible and the log table hidden', () => {
    const html = buildScanningMapPaneHtml();
    assert.ok(/id="pmScanLogEmpty"[^>]*>/.test(html));
    assert.ok(/id="pmScanLogWrap"[^>]* hidden/.test(html), 'log table must start hidden until a line arrives');
  });
});

describe('projectMapShell buildDoneMapPaneHtml', () => {
  const parts: ProjectMapParts = {
    styleHtml: '<style>.pm-pane{color:red}</style>',
    bodyHtml: '<div class="pm-pane">REPORT_BODY</div>',
    scriptHtml: '<script>console.log("report script")</script>',
    echartsUri: 'vscode-webview://fake/echarts.min.js',
  };

  it('composes the extracted style/body/script parts plus a single ECharts <script src>', () => {
    const html = buildDoneMapPaneHtml(parts);
    assert.ok(html.includes(parts.styleHtml));
    assert.ok(html.includes(parts.scriptHtml));
    assert.ok(html.includes(`<script src="${parts.echartsUri}"></script>`));
  });

  it('wraps the report body markup in a .pm-embed container', () => {
    const html = buildDoneMapPaneHtml(parts);
    assert.match(html, /<div class="pm-embed">[\s\S]*REPORT_BODY[\s\S]*<\/div>/);
  });
});
