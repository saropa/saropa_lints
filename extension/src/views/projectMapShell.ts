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
import type { ProjectMapParts, ProjectMapTotals } from './projectMapView';
import { reportJsonColumnsForScript } from './projectMapReports';
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
    // WP1 progress bar label. Contains {percent}/{done}/{total} placeholders
    // the client script fills in per-tick (see handleProgressEvent above) —
    // interpolation happens client-side rather than resolving three separate
    // l10n() calls per tick, but the TEMPLATE itself still comes from the
    // catalog (never concatenated English fragments), per the i18n rule.
    progressLabel: l10n('projectMap.scan.progress'),
    running: l10n('projectMap.reports.running'),
    exitOk: l10n('projectMap.reports.exitOk'),
    exitFail: l10n('projectMap.reports.exitFail'),
    saved: l10n('projectMap.reports.gate.saved'),
    saveError: l10n('projectMap.reports.gate.saveError'),
  };
}

/**
 * Full composite document: chrome CSS + tab bar + the two panes + the one
 * shared script. [heroKpis], added for WP5 (`plans/PLAN_ext_ui_dart_deferred.md`),
 * is the last successful scan's size totals — cached across panel/window
 * reopens (see `getCachedProjectMapTotals` in `projectMapView.ts`) so the
 * hero shows a real Files/Lines/Size readout immediately instead of nothing
 * until a fresh scan finishes. Undefined before the very first scan ever
 * completes for this workspace, in which case the hero renders exactly as it
 * did before this feature existed.
 */
export function buildShellHtml(
  webview: vscode.Webview,
  mapPaneHtml: string,
  reportsPaneHtml: string,
  heroKpis?: ProjectMapTotals,
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
  ${heroKpis ? buildHeroKpiStrip(heroKpis) : ''}
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

/**
 * WP5 hero KPI strip: Files / Lines / Size, read from the last known scan
 * totals (fresh or cached — [buildShellHtml]'s caller decides which). Kept
 * to 3 tiles (not all 5 `ProjectMapTotals` fields) because the hero is
 * visible on BOTH tabs at all times — dead-file/hotspot counts are already
 * one click away in the Map tab's own KPI row (`health_html_template.dart`),
 * so repeating them here would just be noise in a header that's always on
 * screen.
 */
function buildHeroKpiStrip(totals: ProjectMapTotals): string {
  return `<dl class="hero-kpis">
    <div class="hero-kpi"><dt>${escapeHtml(l10n('projectMap.hero.files'))}</dt><dd>${totals.fileCount.toLocaleString()}</dd></div>
    <div class="hero-kpi"><dt>${escapeHtml(l10n('projectMap.hero.lines'))}</dt><dd>${totals.loc.toLocaleString()}</dd></div>
    <div class="hero-kpi"><dt>${escapeHtml(l10n('projectMap.hero.size'))}</dt><dd>${humanBytes(totals.bytes)}</dd></div>
  </dl>`;
}

/**
 * Byte formatter for the hero strip. Deliberately a small local copy rather
 * than importing `health_html_template.dart`'s identical JS `humanBytes` (that
 * one lives inside a Dart-generated string, not a shared TS module) or reaching
 * into an unrelated vibrancy formatter — this is genuinely the only place in
 * the Project Map SHELL (as opposed to the embedded report) that needs it.
 */
function humanBytes(bytes: number): string {
  if (bytes < 1024) return `${bytes} B`;
  if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(1)} KB`;
  return `${(bytes / (1024 * 1024)).toFixed(1)} MB`;
}

/**
 * The Map tab's content while a scan is in flight: spinner, elapsed timer,
 * live activity log, and (WP1) a percentage progress bar. The bar starts
 * hidden — it only appears once the CLI actually emits a `phase`/`tick`
 * event, which never happens against a published engine that predates
 * `--progress` (see projectHealthCliRunner.ts doc comment) — so an old
 * engine degrades to exactly the previous elapsed-timer-only experience
 * instead of showing a permanently-stuck 0% bar.
 */
export function buildScanningMapPaneHtml(): string {
  return `<div class="pm-scan" id="pmScan">
  <p class="status-line"><span class="spinner" aria-hidden="true"></span><span>${escapeHtml(l10n('projectMap.scan.subtitle'))}</span><span class="dot">·</span><span>${escapeHtml(l10n('projectMap.scan.elapsed'))} <span id="pmScanElapsed">0s</span></span></p>
  <div class="pm-progress" id="pmProgressWrap" hidden>
    <div class="pm-progress-track" role="progressbar" aria-valuemin="0" aria-valuemax="100" aria-valuenow="0" id="pmProgressBar">
      <div class="pm-progress-fill" id="pmProgressFill"></div>
    </div>
    <p class="hint" id="pmProgressLabel"></p>
  </div>
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
.hero-kpis { display: flex; gap: var(--space-5); margin: var(--space-2) 0 0; padding: 0; }
.hero-kpi { display: flex; flex-direction: column; gap: 2px; }
.hero-kpi dt { margin: 0; font-size: var(--text-caption); color: var(--muted); }
.hero-kpi dd { margin: 0; font-size: var(--text-h3); font-weight: 700; }
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
.pm-progress { margin: var(--space-3) 0; }
.pm-progress-track {
  /* Track uses the neutral border color (not the accent at reduced opacity --
     the CSS opacity property on this element would also fade the fill child,
     since opacity creates one shared stacking context for the whole subtree). */
  width: 100%; height: 8px;
  background: var(--border);
  border-radius: var(--radius-sm);
  overflow: hidden;
}
.pm-progress-fill {
  height: 100%; width: 0%;
  background: var(--vscode-progressBar-background, #0e70c0);
  /* Smooths the bar between tick events (which arrive once per file, not
     once per frame) instead of visibly snapping on every file scanned. */
  transition: width 0.2s ease-out;
}
#pmProgressLabel { margin: var(--space-1) 0 0; }
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
  // WP2: `{reportId: [field,...]}` for every JSON-enabled report card, so the
  // generic client script below can build a typed row's cells in the SAME
  // order as the `<th>` headers `buildTypedReportTable` rendered host-side,
  // without hardcoding per-tool field names in this script.
  const reportColumns = jsonForScriptBlock(reportJsonColumnsForScript());
  return `
(function(){
  var S = ${strings};
  var RC = ${reportColumns};
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
    var body = document.getElementById('report-output-' + reportId);
    var tr = document.createElement('tr');
    var cols = RC[reportId];
    if (cols) {
      // WP2 fallback path (postJsonReportRows in projectMapReports.ts): a
      // supportsJson CLI's output failed to JSON.parse (older engine or a
      // real crash). This card's table has N typed columns, not the generic
      // num+text pair, so a plain 2-cell row would visually misalign under
      // those headers -- span the whole row instead so the raw text is still
      // fully readable (never a silently truncated/misaligned failure).
      var td = document.createElement('td');
      td.colSpan = cols.length;
      td.textContent = text;
      tr.appendChild(td);
    } else {
      reportRowCounts[reportId] = (reportRowCounts[reportId] || 0) + 1;
      var tdN = document.createElement('td');
      tdN.className = 'num';
      tdN.textContent = String(reportRowCounts[reportId]);
      var tdT = document.createElement('td');
      tdT.textContent = text;
      tr.appendChild(tdN); tr.appendChild(tdT);
    }
    body.appendChild(tr);
    wrap.scrollTop = wrap.scrollHeight;
  }
  // WP2: renders a JSON-enabled CLI's parsed rows into its typed table, one
  // <tr> per row with cells pulled from RC[reportId] in header order. Runs
  // once per report run (on 'reportRows', after the process exits) rather
  // than incrementally, since the whole array only exists once the CLI's
  // single JSON document has fully arrived.
  function addReportRows(reportId, rows){
    var wrap = document.getElementById('report-output-wrap-' + reportId);
    var body = document.getElementById('report-output-' + reportId);
    var cols = RC[reportId];
    if (!wrap || !body || !cols) return;
    wrap.hidden = false;
    body.innerHTML = '';
    for (var i = 0; i < rows.length; i++) {
      var row = rows[i];
      var tr = document.createElement('tr');
      for (var c = 0; c < cols.length; c++) {
        var td = document.createElement('td');
        var v = row ? row[cols[c]] : undefined;
        td.textContent = (v === undefined || v === null) ? '' : String(v);
        tr.appendChild(td);
      }
      body.appendChild(tr);
    }
    wrap.scrollTop = 0;
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

  // --- WP1 progress bar: one 'phase' event carries the total, then one
  // 'tick' event per file scanned. Reveals the bar lazily (stays hidden for
  // a legacy engine that never emits these) and never regresses the percent
  // backwards — a stray out-of-order event should not visibly rewind the bar.
  var pmProgressTotal = 0;
  var pmProgressMaxPct = 0;
  function showProgress(donePct, doneCount, totalCount, currentFile){
    var wrap = document.getElementById('pmProgressWrap');
    if (!wrap) return; // done-state markup already replaced the scanning pane
    wrap.hidden = false;
    var fill = document.getElementById('pmProgressFill');
    var bar = document.getElementById('pmProgressBar');
    var label = document.getElementById('pmProgressLabel');
    var pct = Math.max(pmProgressMaxPct, Math.min(100, donePct));
    pmProgressMaxPct = pct;
    if (fill) fill.style.width = pct + '%';
    if (bar) bar.setAttribute('aria-valuenow', String(Math.round(pct)));
    if (label) {
      label.textContent = S.progressLabel
        .replace('{percent}', String(Math.round(pct)))
        .replace('{done}', String(doneCount))
        .replace('{total}', String(totalCount))
        + (currentFile ? ' — ' + currentFile : '');
    }
  }
  function handleProgressEvent(ev){
    if (!ev || typeof ev.event !== 'string') return;
    if (ev.event === 'phase' && typeof ev.total === 'number') {
      pmProgressTotal = ev.total;
      showProgress(0, 0, pmProgressTotal, null);
    } else if (ev.event === 'tick' && typeof ev.done === 'number') {
      var total = typeof ev.total === 'number' ? ev.total : pmProgressTotal;
      var pct = total > 0 ? (ev.done / total) * 100 : 0;
      showProgress(pct, ev.done, total, ev.file || null);
    } else if (ev.event === 'done') {
      showProgress(100, pmProgressTotal, pmProgressTotal, null);
    }
  }

  window.addEventListener('message', function(e){
    var msg = e.data || {};
    if (msg.type === 'mapLog'){ addScanLogLine(msg.text); }
    else if (msg.type === 'mapProgress'){ handleProgressEvent(msg.event); }
    else if (msg.type === 'mapStopped'){
      var phase = document.querySelector('.pm-scan .status-line span:last-child');
      if (phase) phase.textContent = S.stopped;
      var sp = document.querySelector('.pm-scan .spinner');
      if (sp) sp.style.display = 'none';
    }
    else if (msg.type === 'reportLine'){ addReportLine(msg.reportId, msg.text); }
    else if (msg.type === 'reportRows'){ addReportRows(msg.reportId, msg.rows || []); }
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
