import * as vscode from 'vscode';
import * as nodePath from 'node:path';
import { createWebviewCspNonce, escapeHtml } from '../vibrancy/views/html-utils';
import { getProjectRoot } from '../projectRoot';
import { runProjectVibrancyScan } from './projectVibrancyCliRunner';
import type { ProjectVibrancyFunctionRow, ProjectVibrancyPayload } from './projectVibrancyTypes';
import { getProjectVibrancyReportStyles } from './projectVibrancyReportStyles';

/**
 * **Code Health Dashboard** webview: runs [runProjectVibrancyScan], renders JSON as HTML in an
 * editor-area panel. Manages singleton `currentPanel`, reuses last stdout for copy/debug, and
 * registers disposal when the tab closes.
 *
 * Layout matches the gold-standard pattern shared with the Findings and Lints Config dashboards
 * (see `views/dashboardChromeStyles.ts`): hero band with status line + score gauge, KPI strip
 * with cards as preset filters, banded sticky toolbar with one tier-1 primary, sortable
 * sticky-header table, active-filter chip strip when search is non-empty.
 */

let currentPanel: vscode.WebviewPanel | undefined;
let lastReportRawStdout = '';

export async function openProjectVibrancyReport(): Promise<void> {
  const projectRoot = getProjectRoot();
  if (!projectRoot) {
    void vscode.window.showErrorMessage('Open a Dart/Flutter workspace first.');
    return;
  }
  const scan = await vscode.window.withProgress(
    {
      location: vscode.ProgressLocation.Notification,
      title: 'Project Vibrancy: scanning functions...',
      cancellable: false,
    },
    async () => runProjectVibrancyScan(projectRoot),
  );
  if (!scan.payload) return;
  lastReportRawStdout = scan.rawStdout;
  const panel = getOrCreatePanel();
  panel.webview.html = buildHtml(scan.payload);
  panel.reveal(vscode.ViewColumn.One);
}

function getOrCreatePanel(): vscode.WebviewPanel {
  if (currentPanel) return currentPanel;
  currentPanel = vscode.window.createWebviewPanel(
    'saropaProjectVibrancyReport',
    'Saropa Code Health Dashboard',
    vscode.ViewColumn.One,
    { enableScripts: true, retainContextWhenHidden: true },
  );
  currentPanel.onDidDispose(() => {
    currentPanel = undefined;
  });
  currentPanel.webview.onDidReceiveMessage(async (msg: unknown) => {
    await handlePanelMessage(msg);
  });
  return currentPanel;
}

async function handlePanelMessage(msg: unknown): Promise<void> {
  const data = msg as { type?: string; file?: string; line?: number };
  if (data.type === 'copyJson') {
    if (lastReportRawStdout.trim().length === 0) {
      void vscode.window.showInformationMessage('Run the report again, then copy JSON.');
      return;
    }
    await vscode.env.clipboard.writeText(lastReportRawStdout);
    void vscode.window.showInformationMessage('Project Vibrancy JSON copied to clipboard.');
    return;
  }
  if (data.type === 'openProjectVibrancySettings') {
    await vscode.commands.executeCommand('saropaLints.openProjectVibrancySettings');
    return;
  }
  if (data.type === 'rescan') {
    await openProjectVibrancyReport();
    return;
  }
  if (data.type === 'openFile' && typeof data.file === 'string') {
    await openFileAtLine(data.file, data.line ?? 1);
  }
}

async function openFileAtLine(relativePath: string, line: number): Promise<void> {
  const root = getProjectRoot();
  if (!root) return;
  try {
    const uri = resolveReportFileUri(root, relativePath);
    const doc = await vscode.workspace.openTextDocument(uri);
    const editor = await vscode.window.showTextDocument(doc);
    const targetLine = Math.max(0, line - 1);
    const pos = new vscode.Position(targetLine, 0);
    editor.selection = new vscode.Selection(pos, pos);
    editor.revealRange(new vscode.Range(pos, pos), vscode.TextEditorRevealType.InCenter);
  } catch {
    void vscode.window.showErrorMessage(`Could not open file: ${relativePath}`);
  }
}

/** Map report letter grade to CSS suffix (A–F); unknown → X. */
function gradeBadgeClass(grade: string): string {
  const c = grade.trim().charAt(0).toUpperCase();
  return c >= 'A' && c <= 'F' ? c : 'X';
}

function resolveReportFileUri(root: string, filePathFromReport: string): vscode.Uri {
  const raw = filePathFromReport.trim();
  const windowsAbsolute = /^[a-zA-Z]:[\\/]/.test(raw);
  const posixAbsolute = raw.startsWith('/');
  if (windowsAbsolute || posixAbsolute) return vscode.Uri.file(raw);
  const normalizedRelative = raw
    .replaceAll('\\', '/')
    .replace(/^(\.\/)+/, '')
    .replace(/^\/+/, '');
  return vscode.Uri.file(nodePath.resolve(root, normalizedRelative));
}

/**
 * Map a 0–100 average score to an HSL hue along red → amber → green per UX_UI_GUIDELINES §2.3.
 * Same ramp the Lints Config gauge uses, so the two gauges read consistently — green when the
 * score is healthy, red when it isn't.
 */
function hslForScore(score: number): string {
  const clamped = Math.max(0, Math.min(100, score));
  const hue = Math.round((clamped / 100) * 130);
  return `hsl(${hue}, 70%, 50%)`;
}

function formatRelativeFreshness(iso: string | undefined): string {
  if (!iso) return 'never run';
  const t = Date.parse(iso);
  if (Number.isNaN(t)) return 'never run';
  const sec = Math.max(0, Math.floor((Date.now() - t) / 1000));
  if (sec < 60) return 'just now';
  if (sec < 3600) return `${Math.floor(sec / 60)}m ago`;
  if (sec < 86400) return `${Math.floor(sec / 3600)}h ago`;
  const days = Math.floor(sec / 86400);
  if (days < 7) return `${days}d ago`;
  return `${Math.floor(days / 7)}w ago`;
}

function buildHtml(payload: ProjectVibrancyPayload): string {
  const summary = payload.summary ?? {};
  const rows = [...(payload.functions ?? [])].sort((a, b) => a.score - b.score).slice(0, 200);
  const nonce = createWebviewCspNonce();
  const gateFailed = payload.gates?.pass === false;
  const body = [
    buildHero(payload, summary),
    gateFailed ? buildGateBanner(payload) : '',
    buildKpiRow(summary),
    buildToolbar(),
    '<div class="chip-strip" id="filter-strip" hidden></div>',
    buildTable(rows),
  ].join('\n');
  return `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8" />
  <title>Saropa Code Health Dashboard</title>
  <!-- 'unsafe-inline' on style-src: hero gauge sets dynamic CSS vars (--gauge-target,
       --gauge-arc, --gauge-color) via inline style="..." attributes. CSP nonces only
       authorize <style> blocks, not style attributes — without 'unsafe-inline' the vars
       are dropped, the dasharray falls back to 0, and the gauge renders as a tiny dot. -->
  <meta http-equiv="Content-Security-Policy" content="default-src 'none'; style-src 'nonce-${nonce}' 'unsafe-inline'; script-src 'nonce-${nonce}';">
  <style nonce="${nonce}">${getProjectVibrancyReportStyles()}</style>
</head>
<body>
${body}
<script nonce="${nonce}">${buildClientScript()}</script>
</body>
</html>`;
}

/** Header band with status line + hero gauge driven by averageScore. */
function buildHero(payload: ProjectVibrancyPayload, summary: NonNullable<ProjectVibrancyPayload['summary']>): string {
  const generated = formatRelativeFreshness(payload.generatedAt);
  const avgScore = typeof summary.averageScore === 'number' ? summary.averageScore : 0;
  const avgGrade = summary.averageGrade ?? '—';
  const fnCount = summary.functionCount ?? (payload.functions?.length ?? 0);
  const gateFailed = payload.gates?.pass === false;
  const parts = [
    `Generated <strong>${escapeHtml(generated)}</strong>`,
    `${fnCount} function${fnCount === 1 ? '' : 's'}`,
    `avg ${escapeHtml(avgScore.toFixed(1))} (${escapeHtml(avgGrade)})`,
    gateFailed
      ? '<span class="pill bad">gates failing</span>'
      : '<span class="pill good">gates passing</span>',
  ];
  const statusLine = parts
    .map((p, i) => (i === 0 ? `<span>${p}</span>` : `<span class="dot">·</span><span>${p}</span>`))
    .join('');
  return `<header class="dash-hero">
  <div class="hero-text">
    <h1>Saropa Code Health Dashboard</h1>
    <p class="status-line">${statusLine}</p>
  </div>
  ${buildHeroGauge(avgScore, avgGrade)}
</header>`;
}

/** Hero gauge — average score on a 0–100 scale, red→green hue. */
function buildHeroGauge(score: number, grade: string): string {
  const rounded = Math.round(score);
  const hsl = hslForScore(rounded);
  const tooltip = `Average score ${rounded} of 100 (grade ${grade}).`;
  return `<div class="hero-gauge" role="img"
    aria-label="${escapeHtml(`Average score ${rounded} of 100`)}"
    title="${escapeHtml(tooltip)}"
    style="--gauge-target:${rounded};--gauge-arc:100;--gauge-color:${hsl};">
    <svg viewBox="0 0 100 100" aria-hidden="true">
      <path class="gauge-track" d="M 15 80 A 45 45 0 1 1 85 80" pathLength="100"></path>
      <path class="gauge-fill" d="M 15 80 A 45 45 0 1 1 85 80" pathLength="100"></path>
    </svg>
    <div class="gauge-label">
      <span class="lg">${escapeHtml(grade)}</span>
      <span class="sm">${rounded} / 100</span>
    </div>
  </div>`;
}

/** Banner shown when project vibrancy quality gates fail. */
function buildGateBanner(payload: ProjectVibrancyPayload): string {
  const violations = payload.gates?.violations ?? [];
  const summary =
    violations.length === 0
      ? 'Open Project Vibrancy settings to inspect thresholds.'
      : `${violations.length} gate${violations.length === 1 ? '' : 's'} failing — open Project Vibrancy settings to adjust thresholds, or copy the JSON to inspect <code>gates.violations</code>.`;
  return `<div class="gate-warn" role="alert"><span class="glyph">⚠</span><span>${summary}</span></div>`;
}

/**
 * KPI strip: clickable preset-filter cards (§14.8) for the actionable flag types, plus a
 * static average grade card. Clicking a flag card sets the table to show only rows that
 * carry that flag.
 */
function buildKpiRow(summary: NonNullable<ProjectVibrancyPayload['summary']>): string {
  const cards = [
    kpiCard({
      flag: 'unused',
      label: 'Unused',
      value: summary.unusedCount ?? 0,
      sub: 'functions referenced nowhere',
      classes: 'crit',
    }),
    kpiCard({
      flag: 'uncovered',
      label: 'Uncovered',
      value: summary.uncoveredCount ?? 0,
      sub: 'no LCOV coverage',
      classes: 'errors',
    }),
    kpiCard({
      flag: 'stub_tested',
      label: 'Stub-tested',
      value: summary.stubTestedCount ?? 0,
      sub: 'tests exist but assert little',
      classes: 'warnings',
    }),
    kpiCard({
      flag: 'suspicious_coverage',
      label: 'Suspicious coverage',
      value: summary.suspiciousCoverageCount ?? 0,
      sub: 'coverage looks fabricated',
      classes: 'warnings',
    }),
    kpiCard({
      flag: 'test_drift',
      label: 'Test drift',
      value: summary.testDriftCount ?? 0,
      sub: 'tests lag the function',
      classes: 'todos',
    }),
  ].join('');
  return `<section class="kpi-row" aria-label="Code health summary">${cards}</section>`;
}

interface KpiInput {
  flag: string;
  label: string;
  value: number;
  sub: string;
  classes: string;
}
function kpiCard(input: KpiInput): string {
  const interactive = input.value > 0;
  const interactiveClass = interactive ? 'interactive' : '';
  const filterAttr = interactive ? ` data-flag-filter="${input.flag}"` : '';
  const tabAttr = interactive ? ' tabindex="0"' : '';
  const tooltip = interactive
    ? `Click to filter the table to functions flagged ${input.flag.replace(/_/g, ' ')}.`
    : `No functions flagged ${input.flag.replace(/_/g, ' ')}.`;
  return `<button type="button" class="kpi-card ${input.classes} ${interactiveClass}"${filterAttr}${tabAttr}
    title="${escapeHtml(tooltip)}"${interactive ? '' : ' disabled'}>
    <span class="kpi-k">${escapeHtml(input.label)}</span>
    <span class="kpi-v">${input.value}</span>
    <span class="kpi-sub">${escapeHtml(input.sub)}</span>
  </button>`;
}

/** Toolbar with one tier-1 primary (*Rescan*), tier-2 secondaries, and a search field. */
function buildToolbar(): string {
  return `<section class="toolbar-band" role="toolbar" aria-label="Code Health actions">
  <div class="toolbar-row spread">
    <div class="toolbar-row" style="gap:6px;">
      <button class="btn tier-1" id="rescan" type="button"
        title="Re-run the project vibrancy scan and refresh this dashboard.">Rescan</button>
      <button class="btn" id="copyJson" type="button"
        title="Copy the raw project vibrancy JSON to the clipboard.">Copy JSON</button>
      <button class="btn" id="openPvSettings" type="button"
        title="Open the Project Vibrancy settings.">Project Vibrancy settings</button>
    </div>
    <label class="field" title="Filter rows by name, file, or flag.">
      <span class="glyph">🔎</span>
      <label class="sr-only" for="pvSearch">Filter rows</label>
      <input id="pvSearch" type="search" placeholder="Filter rows…" autocomplete="off" />
    </label>
  </div>
</section>`;
}

/** Sortable, sticky-header functions table (top 200 worst by score). */
function buildTable(rows: readonly ProjectVibrancyFunctionRow[]): string {
  const tbodyRows = rows.map((row) => buildTableRow(row)).join('');
  return `<section class="section" aria-label="Worst functions by score">
  <h2>Worst functions <span class="count">top ${rows.length} of ${rows.length}</span></h2>
  <div class="dash-table-wrap">
    <table class="dash-table code-health" id="pvTable">
      <thead>
        <tr>
          <th class="sortable col-grade" data-sort="grade" aria-sort="none">Grade <span class="arrow">▲</span></th>
          <th class="sortable col-score" data-sort="score" aria-sort="ascending">Score <span class="arrow">▲</span></th>
          <th class="sortable col-name"  data-sort="name"  aria-sort="none">Function <span class="arrow">▲</span></th>
          <th class="sortable col-file"  data-sort="file"  aria-sort="none">File <span class="arrow">▲</span></th>
          <th class="sortable col-line"  data-sort="line"  aria-sort="none">Line <span class="arrow">▲</span></th>
          <th class="sortable col-usage" data-sort="usage" aria-sort="none">Usage <span class="arrow">▲</span></th>
          <th class="sortable col-coverage" data-sort="coverage" aria-sort="none">Coverage <span class="arrow">▲</span></th>
          <th class="sortable col-complexity" data-sort="complexity" aria-sort="none">Complexity <span class="arrow">▲</span></th>
          <th class="col-flags">Flags</th>
        </tr>
      </thead>
      <tbody id="pvBody">${tbodyRows}</tbody>
    </table>
  </div>
  <p class="hint">Showing the worst 200 functions by score. Use the search field to narrow further.</p>
</section>`;
}

function buildTableRow(row: ProjectVibrancyFunctionRow): string {
  const gClass = gradeBadgeClass(row.grade);
  const flags = row.flags
    .map((f) => `<span class="flag-pill ${escapeHtml(f)}">${escapeHtml(f.replace(/_/g, ' '))}</span>`)
    .join(' ');
  const flagsAttr = row.flags.join(' ');
  const search = `${row.name} ${row.file} ${row.flags.join(' ')}`.toLowerCase();
  return `<tr data-grade="${escapeHtml(row.grade)}" data-score="${row.score}" data-name="${escapeHtml(row.name)}"
    data-file="${escapeHtml(row.file)}" data-line="${row.lineStart}" data-line-end="${row.lineEnd}"
    data-usage="${row.usageCount}" data-coverage="${row.coveragePercent}" data-complexity="${row.complexity}"
    data-flags="${escapeHtml(flagsAttr)}" data-search="${escapeHtml(search)}">
    <td class="col-grade"><span class="grade-badge grade-${gClass}">${escapeHtml(row.grade)}</span></td>
    <td class="col-score">${row.score.toFixed(1)}</td>
    <td class="col-name">${escapeHtml(row.name)}</td>
    <td class="col-file"><span class="file-link" data-file="${escapeHtml(row.file)}" data-line="${row.lineStart}">${escapeHtml(row.file)}</span></td>
    <td class="col-line">${row.lineStart}-${row.lineEnd}</td>
    <td class="col-usage">${row.usageCount}</td>
    <td class="col-coverage">${row.coveragePercent.toFixed(1)}%</td>
    <td class="col-complexity">${row.complexity}</td>
    <td class="col-flags"><span class="flag-pills">${flags}</span></td>
  </tr>`;
}

/** Inline client script — sort, search filter, KPI flag-filter, file-link nav, toolbar buttons. */
function buildClientScript(): string {
  return `
(function() {
  const vscode = acquireVsCodeApi();
  const state = { search: '', flag: null, sortKey: 'score', sortAsc: true };

  function postCmd(type) { vscode.postMessage({ type: type }); }
  document.getElementById('rescan').addEventListener('click', function() { postCmd('rescan'); });
  document.getElementById('copyJson').addEventListener('click', function() { postCmd('copyJson'); });
  document.getElementById('openPvSettings').addEventListener('click', function() { postCmd('openProjectVibrancySettings'); });

  const tbody = document.getElementById('pvBody');
  const searchEl = document.getElementById('pvSearch');
  const stripEl = document.getElementById('filter-strip');

  searchEl.addEventListener('input', function() {
    state.search = (searchEl.value || '').trim().toLowerCase();
    applyFilters();
  });

  document.querySelectorAll('.kpi-card.interactive[data-flag-filter]').forEach(function(card) {
    card.addEventListener('click', function() {
      if (card.disabled) return;
      const key = card.getAttribute('data-flag-filter');
      const wasActive = card.classList.contains('active');
      document.querySelectorAll('.kpi-card.active').forEach(function(c) { c.classList.remove('active'); });
      state.flag = wasActive ? null : key;
      if (state.flag) card.classList.add('active');
      applyFilters();
    });
  });

  function applyFilters() {
    Array.from(tbody.querySelectorAll('tr')).forEach(function(tr) {
      const hay = (tr.dataset.search || '').toLowerCase();
      const flagsArr = (tr.dataset.flags || '').split(/\\s+/);
      let show = true;
      if (state.search && hay.indexOf(state.search) === -1) show = false;
      if (state.flag && flagsArr.indexOf(state.flag) === -1) show = false;
      tr.style.display = show ? '' : 'none';
    });
    renderStrip();
  }

  function renderStrip() {
    const chips = [];
    if (state.search) chips.push({ key: 'search', label: 'search: "' + escapeHtml(state.search) + '"' });
    if (state.flag) chips.push({ key: 'flag', label: 'flag: ' + state.flag.replace(/_/g, ' ') });
    if (chips.length === 0) {
      stripEl.hidden = true; stripEl.innerHTML = ''; return;
    }
    stripEl.hidden = false;
    const html = ['<span class="lbl">Active filters:</span>'];
    chips.forEach(function(chip) {
      html.push('<span class="chip">' + chip.label +
        '<button type="button" class="x" data-chip="' + chip.key + '" aria-label="Remove ' + chip.key + '">×</button></span>');
    });
    html.push('<button type="button" class="clear-all" id="clear-all-filters">Clear all</button>');
    stripEl.innerHTML = html.join('');
    stripEl.querySelectorAll('.chip .x').forEach(function(btn) {
      btn.addEventListener('click', function() { removeChip(btn.getAttribute('data-chip')); });
    });
    document.getElementById('clear-all-filters').addEventListener('click', resetFilters);
  }

  function removeChip(key) {
    if (key === 'search') { state.search = ''; searchEl.value = ''; }
    else if (key === 'flag') {
      state.flag = null;
      document.querySelectorAll('.kpi-card.active').forEach(function(c) { c.classList.remove('active'); });
    }
    applyFilters();
  }
  function resetFilters() {
    state.search = ''; state.flag = null;
    searchEl.value = '';
    document.querySelectorAll('.kpi-card.active').forEach(function(c) { c.classList.remove('active'); });
    applyFilters();
  }

  function val(tr, key) {
    if (key === 'score' || key === 'coverage') return parseFloat(tr.dataset[key] || '0');
    if (key === 'usage' || key === 'complexity' || key === 'line') return parseInt(tr.dataset[key === 'line' ? 'line' : key] || '0', 10);
    if (key === 'grade') return (tr.dataset.grade || '').toLowerCase();
    if (key === 'name') return (tr.dataset.name || '').toLowerCase();
    if (key === 'file') return (tr.dataset.file || '').toLowerCase();
    return '';
  }
  function resort() {
    const rows = Array.from(tbody.querySelectorAll('tr'));
    rows.sort(function(a, b) {
      const av = val(a, state.sortKey);
      const bv = val(b, state.sortKey);
      let c = 0;
      if (typeof av === 'number' && typeof bv === 'number') c = av - bv;
      else c = String(av).localeCompare(String(bv));
      return state.sortAsc ? c : -c;
    });
    rows.forEach(function(r) { tbody.appendChild(r); });
    document.querySelectorAll('th.sortable').forEach(function(th) {
      th.setAttribute('aria-sort',
        th.getAttribute('data-sort') === state.sortKey
          ? (state.sortAsc ? 'ascending' : 'descending')
          : 'none');
    });
  }
  document.querySelectorAll('th.sortable[data-sort]').forEach(function(th) {
    th.addEventListener('click', function() {
      const col = th.getAttribute('data-sort');
      if (state.sortKey === col) state.sortAsc = !state.sortAsc;
      else { state.sortKey = col; state.sortAsc = true; }
      resort();
    });
  });

  document.querySelectorAll('.file-link').forEach(function(el) {
    el.addEventListener('click', function() {
      const file = el.getAttribute('data-file');
      const line = Number(el.getAttribute('data-line') || '1');
      if (!file) return;
      vscode.postMessage({ type: 'openFile', file: file, line: line });
    });
  });

  function escapeHtml(s) {
    return String(s).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');
  }
})();
`;
}
