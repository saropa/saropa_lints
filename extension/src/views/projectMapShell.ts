/**
 * Composite document shell for the Saropa Project Map panel: a chrome-styled
 * tab bar (Map / Reports) wrapping two panes in ONE webview document, plus the
 * single inline client script that both panes share.
 *
 * Replaces the old per-command `webview.html = transformProjectMapHtml(...)`
 * full-document swap with a shell built from `dashboardChromeStyles` (design
 * principle 5, "one design system") — the Map pane's embedded
 * `project_health --format html` fragment keeps its own scoped `.pm-pane`
 * styles (it is also a portable standalone report used outside VS Code, e.g.
 * a CI artifact — rebinding ITS internals onto the webview-only chrome system
 * would break that non-VS-Code use case), but everything this extension
 * builds around it — the hero, the tab bar, the scanning state, the Reports
 * cards — draws from the shared chrome.
 */
import * as vscode from 'vscode';
import { escapeHtml, jsonForScriptBlock } from '../vibrancy/views/html-utils';
import { getDashboardChromeStyles } from './dashboardChromeStyles';
import type { ProjectMapParts } from './projectMapView';
import { l10n } from '../i18n/runtime';
// Project Map already ships working digit shortcuts (1-2, see pmShellScript's keydown handler
// below) but never surfaced the shared '?' overlay that Findings/Packages/Rules & Tiers use —
// so those shortcuts were undiscoverable. Same button + overlay + script + styles pattern.
import {
  buildKeyboardShortcutsButton,
  buildKeyboardShortcutsOverlay,
  getKeyboardShortcutsScript,
  getKeyboardShortcutsStyles,
} from './keyboard-shortcuts';

/** Strings the inline client script needs, resolved host-side for i18n. */
function shellStrings(): Record<string, string> {
  return {
    tabMap: l10n('projectMap.tabs.map'),
    tabReports: l10n('projectMap.tabs.reports'),
    cancel: l10n('projectMap.scan.cancel'),
    restart: l10n('projectMap.scan.restart'),
    stopped: l10n('projectMap.scan.stopped'),
    elapsedPrefix: l10n('projectMap.scan.elapsed'),
    running: l10n('projectMap.reports.running'),
    exitOk: l10n('projectMap.reports.exitOk'),
    exitFail: l10n('projectMap.reports.exitFail'),
    saved: l10n('projectMap.reports.gate.saved'),
    saveError: l10n('projectMap.reports.gate.saveError'),
  };
}

/** Full composite document: chrome CSS + tab bar + the two panes + the one shared script. */
export function buildShellHtml(
  webview: vscode.Webview,
  mapPaneHtml: string,
  reportsPaneHtml: string,
): string {
  const cspSource = webview.cspSource;
  // 'unsafe-inline' (not a nonce) for style/script: the embedded Project Map
  // report fragment carries its own un-nonced <style>/<script> tags (see
  // extractProjectMapParts in projectMapView.ts).
  const csp =
    `default-src 'none'; img-src ${cspSource} data:; ` +
    `style-src ${cspSource} 'unsafe-inline'; script-src ${cspSource} 'unsafe-inline';`;
  return `<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8" />
<title>${escapeHtml(l10n('projectMap.panelTitle'))}</title>
<meta http-equiv="Content-Security-Policy" content="${csp}">
<style>${getDashboardChromeStyles()}${pmShellStyles()}${getKeyboardShortcutsStyles()}</style>
<script>${pmShellScript()}${getKeyboardShortcutsScript()}</script>
</head>
<body>
<header class="dash-hero">
  <div class="hero-text">
    <h1>${escapeHtml(l10n('projectMap.panelTitle'))}</h1>
    <p class="status-line">${buildKeyboardShortcutsButton()}</p>
  </div>
</header>
<nav class="pm-tabs" role="tablist" aria-label="${escapeHtml(l10n('projectMap.tabs.aria'))}">
  <button type="button" class="pm-tab active" id="pmTabBtnMap" data-tab="map" role="tab" aria-selected="true" aria-controls="pmTabMap">${escapeHtml(l10n('projectMap.tabs.map'))}</button>
  <button type="button" class="pm-tab" id="pmTabBtnReports" data-tab="reports" role="tab" aria-selected="false" aria-controls="pmTabReports">${escapeHtml(l10n('projectMap.tabs.reports'))}</button>
</nav>
<section id="pmTabMap" class="pm-tab-panel" role="tabpanel" aria-labelledby="pmTabBtnMap">
${mapPaneHtml}
</section>
<section id="pmTabReports" class="pm-tab-panel" role="tabpanel" aria-labelledby="pmTabBtnReports" hidden>
${reportsPaneHtml}
</section>
${buildKeyboardShortcutsOverlay([
  { key: '1-2', label: l10n('projectMap.shortcuts.jumpToTab') },
  { key: '?', label: l10n('projectMap.shortcuts.showOverlay') },
])}
</body>
</html>`;
}

/** The Map tab's content while a scan is in flight: spinner, elapsed timer, live activity log. */
export function buildScanningMapPaneHtml(): string {
  return `<div class="pm-scan" id="pmScan">
  <p class="status-line"><span class="spinner" aria-hidden="true"></span><span>${escapeHtml(l10n('projectMap.scan.subtitle'))}</span><span class="dot">·</span><span>${escapeHtml(l10n('projectMap.scan.elapsed'))} <span id="pmScanElapsed">0s</span></span></p>
  <div class="controls">
    <button type="button" class="btn danger" id="pmCancelBtn">${escapeHtml(l10n('projectMap.scan.cancel'))}</button>
    <button type="button" class="btn" id="pmRestartBtn">${escapeHtml(l10n('projectMap.scan.restart'))}</button>
  </div>
  <section class="pm-scan-log">
    <h3>${escapeHtml(l10n('projectMap.scan.logHeading'))}</h3>
    <p class="hint" id="pmScanLogEmpty">${escapeHtml(l10n('projectMap.scan.logEmpty'))}</p>
    <div class="dash-table-wrap" id="pmScanLogWrap" hidden>
      <table class="dash-table">
        <thead><tr><th class="col-line">${escapeHtml(l10n('projectMap.reports.colLine'))}</th><th>${escapeHtml(l10n('projectMap.reports.colText'))}</th></tr></thead>
        <tbody id="pmScanLogBody"></tbody>
      </table>
    </div>
  </section>
</div>`;
}

/** The Map tab's content once the scan finishes: the extracted report fragment, embedded inline. */
export function buildDoneMapPaneHtml(parts: ProjectMapParts): string {
  return `${parts.styleHtml}
<script src="${parts.echartsUri}"></script>
<div class="pm-embed">${parts.bodyHtml}</div>
${parts.scriptHtml}`;
}

/** Chrome-adjacent styles this shell adds on top of `dashboardChromeStyles` (tabs, scan state, report cards). */
function pmShellStyles(): string {
  return `
.pm-tabs { display: flex; gap: 4px; border-bottom: 1px solid var(--border); margin-bottom: var(--space-4); }
.pm-tab {
  padding: 8px 14px;
  border: 0; border-bottom: 2px solid transparent;
  background: transparent;
  color: var(--muted);
  font: inherit; font-weight: 600;
  cursor: pointer;
}
.pm-tab:hover { color: var(--vscode-foreground); }
.pm-tab.active { color: var(--vscode-foreground); border-bottom-color: var(--vscode-focusBorder); }
.pm-tab:focus-visible { outline: 1px solid var(--vscode-focusBorder); outline-offset: -2px; }
.pm-tab-panel[hidden] { display: none; }
.pm-scan .controls { display: flex; gap: var(--space-2); margin: var(--space-3) 0 var(--space-5); }
.pm-scan-log h3 { font-size: var(--text-h3); margin: 0 0 var(--space-2); }
.spinner {
  width: 14px; height: 14px;
  border: 2px solid var(--vscode-progressBar-background, #0e70c0);
  border-right-color: transparent;
  border-radius: 50%;
  display: inline-block;
  animation: pmspin 0.8s linear infinite;
}
@keyframes pmspin { to { transform: rotate(360deg); } }
@media (prefers-reduced-motion: reduce) { .spinner { animation: none; } }
.report-cards { display: grid; gap: var(--space-4); }
.report-desc { color: var(--muted); font-size: var(--text-body); margin: 0 0 var(--space-3); }
.report-status { color: var(--muted); font-size: var(--text-caption); }
.report-status.ok { color: var(--status-good); font-weight: 600; }
.report-status.fail { color: var(--status-bad); font-weight: 600; }
.report-output-wrap { margin-top: var(--space-3); max-height: 280px; overflow: auto; }
.report-output-wrap .col-line { width: 48px; }
.gate-editor { margin-bottom: var(--space-3); }
.gate-editor-label { display: block; font-size: var(--text-caption); color: var(--muted); margin-bottom: var(--space-1); }
.gate-yaml {
  width: 100%;
  font-family: var(--vscode-editor-font-family, monospace);
  font-size: var(--text-body);
  padding: var(--space-2);
  border: 1px solid var(--vscode-input-border, var(--border));
  border-radius: var(--radius-sm);
  background: var(--vscode-input-background);
  color: var(--vscode-input-foreground);
  resize: vertical;
}
`;
}

/**
 * The one shared inline client script for the whole panel — a SINGLE
 * `acquireVsCodeApi()` call, re-exposed via `window.acquireVsCodeApi` so the
 * embedded Project Map report script (which also calls `acquireVsCodeApi()`)
 * gets the same handle instead of throwing "an instance has already been
 * acquired" (the exact bug this pattern exists to avoid — see
 * healthPanel-script.ts for the same shim).
 */
function pmShellScript(): string {
  const strings = jsonForScriptBlock(shellStrings());
  return `
(function(){
  var S = ${strings};
  var api = acquireVsCodeApi();
  window.acquireVsCodeApi = function () { return api; };

  // --- Tab switching (pure client-side; no round trip to the host) ---
  function selectTab(name){
    var isMap = name === 'map';
    document.getElementById('pmTabBtnMap').classList.toggle('active', isMap);
    document.getElementById('pmTabBtnMap').setAttribute('aria-selected', String(isMap));
    document.getElementById('pmTabBtnReports').classList.toggle('active', !isMap);
    document.getElementById('pmTabBtnReports').setAttribute('aria-selected', String(!isMap));
    document.getElementById('pmTabMap').hidden = !isMap;
    document.getElementById('pmTabReports').hidden = isMap;
  }
  document.getElementById('pmTabBtnMap').addEventListener('click', function(){ selectTab('map'); });
  document.getElementById('pmTabBtnReports').addEventListener('click', function(){ selectTab('reports'); });

  // Digit shortcuts 1-2 jump directly to a tab (Phase 7, UX_UI_GUIDELINES "every dashboard tab
  // reachable by 1-9" convention -- matches the pattern already shipped on Rules & Tiers (Phase 4)
  // and Packages (Phase 7). Ignored while focus is in the gate-editor textarea or an input so
  // typing does not hijack the view.
  document.addEventListener('keydown', function(e){
    var tag = (document.activeElement && document.activeElement.tagName) || '';
    if (tag === 'INPUT' || tag === 'SELECT' || tag === 'TEXTAREA') { return; }
    if (e.key === '1') { selectTab('map'); document.getElementById('pmTabBtnMap').focus(); }
    else if (e.key === '2') { selectTab('reports'); document.getElementById('pmTabBtnReports').focus(); }
  });

  // --- Scanning-state elapsed timer + cancel/restart + activity log ---
  var scanStarted = Date.now();
  var scanTimer = setInterval(function(){
    var el = document.getElementById('pmScanElapsed');
    if (!el){ clearInterval(scanTimer); return; }
    el.textContent = Math.floor((Date.now() - scanStarted) / 1000) + 's';
  }, 1000);
  var cancelBtn = document.getElementById('pmCancelBtn');
  if (cancelBtn) cancelBtn.addEventListener('click', function(){ api.postMessage({type:'cancelScan'}); });
  var restartBtn = document.getElementById('pmRestartBtn');
  if (restartBtn) restartBtn.addEventListener('click', function(){ api.postMessage({type:'restartScan'}); });

  var scanLogRows = 0;
  function addScanLogLine(text){
    var wrap = document.getElementById('pmScanLogWrap');
    var empty = document.getElementById('pmScanLogEmpty');
    if (!wrap) return; // done-state markup already replaced the scanning pane
    if (empty){ empty.hidden = true; }
    wrap.hidden = false;
    scanLogRows++;
    var tr = document.createElement('tr');
    var tdN = document.createElement('td');
    tdN.className = 'num';
    tdN.textContent = String(scanLogRows);
    var tdT = document.createElement('td');
    tdT.textContent = text;
    tr.appendChild(tdN); tr.appendChild(tdT);
    var body = document.getElementById('pmScanLogBody');
    body.appendChild(tr);
    body.parentElement.parentElement.scrollTop = body.parentElement.parentElement.scrollHeight;
  }

  // --- Reports tab: Run buttons, live output tables, quality-gate editor ---
  var reportRowCounts = {};
  function addReportLine(reportId, text){
    var wrap = document.getElementById('report-output-wrap-' + reportId);
    if (!wrap) return;
    wrap.hidden = false;
    reportRowCounts[reportId] = (reportRowCounts[reportId] || 0) + 1;
    var tr = document.createElement('tr');
    var tdN = document.createElement('td');
    tdN.className = 'num';
    tdN.textContent = String(reportRowCounts[reportId]);
    var tdT = document.createElement('td');
    tdT.textContent = text;
    tr.appendChild(tdN); tr.appendChild(tdT);
    var body = document.getElementById('report-output-' + reportId);
    body.appendChild(tr);
    wrap.scrollTop = wrap.scrollHeight;
  }
  function setReportStatus(reportId, text, cls){
    var el = document.getElementById('report-status-' + reportId);
    if (!el) return;
    el.textContent = text;
    el.className = 'report-status' + (cls ? ' ' + cls : '');
  }
  document.querySelectorAll('.report-run-btn').forEach(function(btn){
    btn.addEventListener('click', function(){
      var id = btn.getAttribute('data-report-id');
      reportRowCounts[id] = 0;
      var body = document.getElementById('report-output-' + id);
      if (body) body.innerHTML = '';
      setReportStatus(id, S.running);
      api.postMessage({type:'runReport', reportId: id});
    });
  });
  var gateEditor = document.getElementById('gateYamlEditor');
  if (gateEditor) {
    api.postMessage({type:'loadGateConfig'});
    var gateSaveBtn = document.getElementById('gateSaveBtn');
    gateSaveBtn.addEventListener('click', function(){
      api.postMessage({type:'saveGateConfig', text: gateEditor.value});
    });
  }

  window.addEventListener('message', function(e){
    var msg = e.data || {};
    if (msg.type === 'mapLog'){ addScanLogLine(msg.text); }
    else if (msg.type === 'mapStopped'){
      var phase = document.querySelector('.pm-scan .status-line span:last-child');
      if (phase) phase.textContent = S.stopped;
      var sp = document.querySelector('.pm-scan .spinner');
      if (sp) sp.style.display = 'none';
    }
    else if (msg.type === 'reportLine'){ addReportLine(msg.reportId, msg.text); }
    else if (msg.type === 'reportDone'){
      setReportStatus(msg.reportId, msg.exitCode === 0 ? S.exitOk : S.exitFail, msg.exitCode === 0 ? 'ok' : 'fail');
    }
    else if (msg.type === 'gateConfig'){
      if (gateEditor) gateEditor.value = msg.text || '';
    }
    else if (msg.type === 'gateConfigSaved'){
      var status = document.getElementById('gateSaveStatus');
      if (!status) return;
      status.textContent = msg.ok ? S.saved : (S.saveError + ': ' + (msg.error || ''));
      status.className = 'report-status ' + (msg.ok ? 'ok' : 'fail');
    }
  });
})();
`;
}
