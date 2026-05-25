/**
 * Module overview (comment coverage pass).
 * comment-coverage: module overview (batch).
 *
 * VS Code views: trees, dashboards, or webview HTML builders.
 */

import * as vscode from 'vscode';
import * as nodePath from 'node:path';
import { createWebviewCspNonce, escapeHtml } from '../vibrancy/views/html-utils';
import { getProjectRoot } from '../projectRoot';
import { runProjectVibrancyScan } from './projectVibrancyCliRunner';
import type {
  ProjectVibrancyFunctionRow,
  ProjectVibrancyPayload,
  VibrancyScanControl,
} from './projectVibrancyTypes';
import { buildCodeHealthScanningHtml } from './codeHealthScanProgress';
import { getProjectVibrancyReportStyles } from './projectVibrancyReportStyles';
import { pluralize } from './webview-format';
import {
  buildKeyboardShortcutsButton,
  buildKeyboardShortcutsOverlay,
  getKeyboardShortcutsScript,
  getKeyboardShortcutsStyles,
} from './keyboard-shortcuts';
import { l10n } from '../i18n/runtime';

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
// Single-flight guard: a project vibrancy scan spawns a full-project AST walk
// via `dart run`, which is heavy. Without this, every command invocation
// (sidebar item, rescan button, command palette) starts a fresh dart process
// in parallel — N rapid clicks pin N CPU cores. Subsequent calls while a scan
// is in progress reuse the in-flight promise so they share the same panel
// update instead of stacking.
let inflightScan: Promise<void> | undefined;
// Pause/resume/cancel handle for the scan currently feeding the panel. Set when
// a streaming scan starts, cleared when it ends.
let currentControl: VibrancyScanControl | undefined;
// Monotonic scan generation. A Restart cancels the in-flight scan and starts a
// new one in the same panel; the old scan's async completion must not clobber
// the new scan's view, so every callback checks its captured epoch against this.
let scanEpoch = 0;

export async function openProjectVibrancyReport(): Promise<void> {
  if (inflightScan) {
    // Reveal the panel if it already exists so a re-click feels responsive
    // even though we're not starting a new scan.
    currentPanel?.reveal(vscode.ViewColumn.One);
    return inflightScan;
  }
  const projectRoot = getProjectRoot();
  if (!projectRoot) {
    void vscode.window.showErrorMessage(l10n('codeHealth.openWorkspaceFirst'));
    return;
  }
  inflightScan = runScanAndRender(projectRoot).finally(() => {
    inflightScan = undefined;
  });
  return inflightScan;
}

/** Running extension version, shown on the scanning panel so the loaded build is visible. */
function codeHealthExtensionVersion(): string {
  try {
    const ext = vscode.extensions.getExtension('saropa.saropa-lints');
    const version = (ext?.packageJSON as { version?: string } | undefined)?.version;
    return typeof version === 'string' ? version : 'dev';
  } catch {
    return 'dev';
  }
}

/** Re-run Code Health scan only when its dashboard tab is already open. */
export function refreshCodeHealthDashboardIfOpen(): void {
  if (!currentPanel) return;
  void openProjectVibrancyReport();
}

async function runScanAndRender(projectRoot: string): Promise<void> {
  // Open the panel in its scanning state immediately so the user sees live
  // progress (bar, current file, counters) instead of a frozen notification —
  // the whole point of this view. The full report replaces this HTML on
  // completion.
  const panel = getOrCreatePanel();
  panel.webview.html = buildCodeHealthScanningHtml(codeHealthExtensionVersion());
  panel.reveal(vscode.ViewColumn.One);
  await runStreamingScan(projectRoot, panel);
}

/**
 * Streams a scan into the already-open scanning panel, forwarding progress
 * events to the webview and capturing the pause/cancel control. On success the
 * panel swaps to the full report; on cancel/failure it tells the view to stop
 * the spinner (the runner already toasts genuine failures).
 */
async function runStreamingScan(
  projectRoot: string,
  panel: vscode.WebviewPanel,
): Promise<void> {
  const epoch = ++scanEpoch;
  const scan = await runProjectVibrancyScan(projectRoot, undefined, {
    onEvent: (event) => {
      if (epoch === scanEpoch) void panel.webview.postMessage({ type: 'event', event });
    },
    onControl: (control) => {
      if (epoch === scanEpoch) currentControl = control;
    },
  });
  // A Restart (or a fresh open) superseded this scan — ignore its stale result
  // so it cannot overwrite the newer scan's view.
  if (epoch !== scanEpoch) return;
  currentControl = undefined;
  if (!scan.payload) {
    void panel.webview.postMessage({ type: 'stopped' });
    return;
  }
  lastReportRawStdout = scan.rawStdout;
  panel.webview.html = buildHtml(scan.payload);
  panel.reveal(vscode.ViewColumn.One);
}

/** Cancels the in-flight scan and starts a fresh one in the same panel. */
async function restartScan(): Promise<void> {
  const root = getProjectRoot();
  if (!root || !currentPanel) return;
  currentControl?.cancel();
  currentControl = undefined;
  currentPanel.webview.html = buildCodeHealthScanningHtml(codeHealthExtensionVersion());
  await runStreamingScan(root, currentPanel);
}

function getOrCreatePanel(): vscode.WebviewPanel {
  if (currentPanel) return currentPanel;
  currentPanel = vscode.window.createWebviewPanel(
    'saropaProjectVibrancyReport',
    l10n('codeHealth.panelTitle'),
    vscode.ViewColumn.One,
    { enableScripts: true, retainContextWhenHidden: true },
  );
  currentPanel.onDidDispose(() => {
    // Closing the panel is an implicit cancel — otherwise the dart scan keeps
    // burning CPU with no visible surface to stop it (the old "runaway scan"
    // symptom). This replaces the notification token that used to cancel it.
    currentControl?.cancel();
    currentControl = undefined;
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
      void vscode.window.showInformationMessage(l10n('codeHealth.runReportFirst'));
      return;
    }
    await vscode.env.clipboard.writeText(lastReportRawStdout);
    void vscode.window.showInformationMessage(l10n('codeHealth.copiedJson'));
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
  // Scanning-view controls — only meaningful while a streaming scan is running.
  if (data.type === 'pause') {
    currentControl?.pause();
    return;
  }
  if (data.type === 'resume') {
    currentControl?.resume();
    return;
  }
  if (data.type === 'cancel') {
    currentControl?.cancel();
    return;
  }
  if (data.type === 'restart') {
    await restartScan();
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
    void vscode.window.showErrorMessage(l10n('codeHealth.couldNotOpenFile', { path: relativePath }));
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
  if (!iso) return l10n('codeHealth.script.neverRun');
  const parsed = Date.parse(iso);
  if (Number.isNaN(parsed)) return l10n('codeHealth.script.neverRun');
  const sec = Math.max(0, Math.floor((Date.now() - parsed) / 1000));
  if (sec < 60) return l10n('codeHealth.freshness.justNow');
  if (sec < 3600) return l10n('codeHealth.freshness.minutesAgo', { min: String(Math.floor(sec / 60)) });
  if (sec < 86400) return l10n('codeHealth.freshness.hoursAgo', { hr: String(Math.floor(sec / 3600)) });
  const days = Math.floor(sec / 86400);
  if (days < 7) return l10n('codeHealth.freshness.daysAgo', { day: String(days) });
  return l10n('codeHealth.freshness.weeksAgo', { wk: String(Math.floor(days / 7)) });
}

/**
 * Compose the Code Health Dashboard HTML document. Exported so unit tests can
 * assert the rendered structure (KPI behavior, empty-state CTA, gate banner)
 * without standing up a real VS Code webview.
 */
export function buildProjectVibrancyHtml(payload: ProjectVibrancyPayload): string {
  return buildHtml(payload);
}

function buildHtml(payload: ProjectVibrancyPayload): string {
  const summary = payload.summary ?? {};
  const rows = [...(payload.functions ?? [])].sort((a, b) => a.score - b.score).slice(0, 200);
  const nonce = createWebviewCspNonce();
  const gateFailed = payload.gates?.pass === false;
  return `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8" />
  <title>${escapeHtml(l10n('codeHealth.documentTitle'))}</title>
  <!-- 'unsafe-inline' on style-src: hero gauge sets dynamic CSS vars (--gauge-target,
       --gauge-arc, --gauge-color) via inline style="..." attributes. CSP nonces only
       authorize <style> blocks, not style attributes — without 'unsafe-inline' the vars
       are dropped, the dasharray falls back to 0, and the gauge renders as a tiny dot. -->
  <meta http-equiv="Content-Security-Policy" content="default-src 'none'; style-src 'nonce-${nonce}' 'unsafe-inline'; script-src 'nonce-${nonce}';">
  <style nonce="${nonce}">${getProjectVibrancyReportStyles()}${getKeyboardShortcutsStyles()}</style>
</head>
<body>
<a href="#pvTable" class="skip-link">${escapeHtml(l10n('codeHealth.skipToTable'))}</a>
<div id="announcer" role="status" aria-live="polite" aria-atomic="true"></div>
<header>
${buildHero(payload, summary)}
</header>
${gateFailed ? buildGateBanner(payload) : ''}
${buildKpiRow(summary)}
${buildToolbar()}
<div class="chip-strip" id="filter-strip" hidden></div>
<main id="pv-main">
${buildTable(rows)}
</main>
${buildKeyboardShortcutsOverlay([
  { key: '/', label: l10n('codeHealth.shortcuts.focusFilter') },
  { key: 'Esc', label: l10n('codeHealth.shortcuts.clearFilter') },
  { key: 'Enter', label: l10n('codeHealth.shortcuts.activateKpi') },
  { key: 'Space', label: l10n('codeHealth.shortcuts.activateKpiSpace') },
  { key: '?', label: l10n('codeHealth.shortcuts.showOverlay') },
])}
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
    `${escapeHtml(l10n('codeHealth.hero.generated'))} <strong>${escapeHtml(generated)}</strong>`,
    pluralize(fnCount, { one: l10n('codeHealth.hero.functionOne'), other: l10n('codeHealth.hero.functionOther') }),
    escapeHtml(l10n('codeHealth.hero.avgFormat', { score: avgScore.toFixed(1), grade: avgGrade })),
    gateFailed
      ? `<span class="pill bad">${escapeHtml(l10n('codeHealth.hero.gatesFailing'))}</span>`
      : `<span class="pill good">${escapeHtml(l10n('codeHealth.hero.gatesPassing'))}</span>`,
  ];
  const statusLine = parts
    .map((p, i) => (i === 0 ? `<span>${p}</span>` : `<span class="dot">·</span><span>${p}</span>`))
    .join('');
  // §15.2 — keyboard-shortcut overlay trigger appended to the status line so
  // it sits in the hero's trailing-actions slot, consistent with the
  // full-width toggle position on other dashboards. This dashboard does not
  // expose the full-width toggle, so the kbd button is the sole trailing
  // action here.
  return `<header class="dash-hero">
  <div class="hero-text">
    <h1>${escapeHtml(l10n('codeHealth.hero.title'))}</h1>
    <p class="status-line">${statusLine}${buildKeyboardShortcutsButton()}</p>
  </div>
  ${buildHeroGauge(avgScore, avgGrade)}
</header>`;
}

/** Hero gauge — average score on a 0–100 scale, red→green hue. */
function buildHeroGauge(score: number, grade: string): string {
  const rounded = Math.round(score);
  const hsl = hslForScore(rounded);
  const tooltip = l10n('codeHealth.gauge.tooltip', { rounded: String(rounded), grade });
  return `<div class="hero-gauge" role="img"
    aria-label="${escapeHtml(l10n('codeHealth.gauge.ariaLabel', { rounded: String(rounded) }))}"
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
      ? l10n('codeHealth.gate.fallback')
      : pluralize(violations.length, { one: l10n('codeHealth.gate.failingOne'), other: l10n('codeHealth.gate.failingOther') });
  // §8.16 — empty/error states must name the next action with a tier-1 button.
  // Previously this banner only carried explanatory text; the user had to
  // hunt for the *Code Health settings* toolbar button to act on it. The
  // tier-1 button inside the banner closes that gap; #openPvSettings is
  // the same id wired in the toolbar so the existing click handler reaches
  // it too (querySelector picks up either occurrence on dispatch).
  return `<div class="gate-warn" role="alert">
    <span class="glyph">⚠</span>
    <span class="gate-msg">${summary}</span>
    <button type="button" class="btn tier-1" data-cmd="openProjectVibrancySettings"
      title="${escapeHtml(l10n('codeHealth.gate.openSettingsTitle'))}">${escapeHtml(l10n('codeHealth.gate.openSettingsButton'))}</button>
  </div>`;
}

/**
 * KPI strip: clickable preset-filter cards (§14.8) for the actionable flag types, plus a
 * static average grade card. Clicking a flag card sets the table to show only rows that
 * carry that flag.
 *
 * §14.11 — cards whose value is zero are suppressed so a healthy project
 * does not greet the user with five identical-twin "0 / 0 / 0 / 0 / 0"
 * boxes. When every category is zero, the row collapses to a single muted
 * line acknowledging the all-clear state without occupying card real estate.
 */
function buildKpiRow(summary: NonNullable<ProjectVibrancyPayload['summary']>): string {
  const specs: KpiInput[] = [
    { flag: 'unused', label: l10n('codeHealth.kpi.unused'), value: summary.unusedCount ?? 0, sub: l10n('codeHealth.kpi.unusedSub'), classes: 'crit' },
    { flag: 'uncovered', label: l10n('codeHealth.kpi.uncovered'), value: summary.uncoveredCount ?? 0, sub: l10n('codeHealth.kpi.uncoveredSub'), classes: 'errors' },
    { flag: 'stub_tested', label: l10n('codeHealth.kpi.stubTested'), value: summary.stubTestedCount ?? 0, sub: l10n('codeHealth.kpi.stubTestedSub'), classes: 'warnings' },
    { flag: 'suspicious_coverage', label: l10n('codeHealth.kpi.suspiciousCoverage'), value: summary.suspiciousCoverageCount ?? 0, sub: l10n('codeHealth.kpi.suspiciousCoverageSub'), classes: 'warnings' },
    { flag: 'test_drift', label: l10n('codeHealth.kpi.testDrift'), value: summary.testDriftCount ?? 0, sub: l10n('codeHealth.kpi.testDriftSub'), classes: 'todos' },
  ];
  const live = specs.filter((s) => s.value > 0);
  if (live.length === 0) {
    return `<p class="kpi-allclear" aria-label="${escapeHtml(l10n('codeHealth.kpi.ariaLabel'))}">${escapeHtml(l10n('codeHealth.kpi.allClear'))}</p>`;
  }
  const cards = live.map(kpiCard).join('');
  return `<section class="kpi-row" aria-label="${escapeHtml(l10n('codeHealth.kpi.ariaLabel'))}">${cards}</section>`;
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
  const humanFlag = input.flag.replace(/_/g, ' ');
  const tooltip = interactive
    ? l10n('codeHealth.kpi.clickToFilter', { flag: humanFlag })
    : l10n('codeHealth.kpi.noFlagged', { flag: humanFlag });
  return `<button type="button" class="kpi-card ${input.classes} ${interactiveClass}"${filterAttr}${tabAttr}
    title="${escapeHtml(tooltip)}"${interactive ? '' : ' disabled'}>
    <span class="kpi-k">${escapeHtml(input.label)}</span>
    <span class="kpi-v">${input.value}</span>
    <span class="kpi-sub">${escapeHtml(input.sub)}</span>
  </button>`;
}

/** Toolbar with one tier-1 primary (*Rescan*), tier-2 secondaries, and a search field. */
function buildToolbar(): string {
  return `<section class="toolbar-band" role="toolbar" aria-label="${escapeHtml(l10n('codeHealth.toolbar.ariaLabel'))}">
  <div class="toolbar-row spread">
    <div class="toolbar-row" style="gap:6px;">
      <button class="btn tier-1" id="rescan" type="button"
        title="${escapeHtml(l10n('codeHealth.toolbar.rescanTitle'))}">${escapeHtml(l10n('codeHealth.toolbar.rescan'))}</button>
      <button class="btn" id="copyJson" type="button"
        title="${escapeHtml(l10n('codeHealth.toolbar.copyJsonTitle'))}">${escapeHtml(l10n('codeHealth.toolbar.copyJson'))}</button>
      <button class="btn" id="openPvSettings" type="button"
        title="${escapeHtml(l10n('codeHealth.toolbar.settingsTitle'))}">${escapeHtml(l10n('codeHealth.toolbar.settingsButton'))}</button>
    </div>
    <label class="field" title="${escapeHtml(l10n('codeHealth.toolbar.filterTitle'))}">
      <span class="glyph">🔎</span>
      <label class="sr-only" for="pvSearch">${escapeHtml(l10n('codeHealth.toolbar.filterLabel'))}</label>
      <input id="pvSearch" type="search" placeholder="${escapeHtml(l10n('codeHealth.toolbar.filterPlaceholder'))}" autocomplete="off" />
    </label>
  </div>
</section>`;
}

/** Sortable, sticky-header functions table (top 200 worst by score). */
function buildTable(rows: readonly ProjectVibrancyFunctionRow[]): string {
  const tbodyRows = rows.map((row) => buildTableRow(row)).join('');
  return `<section class="section" aria-label="${escapeHtml(l10n('codeHealth.table.ariaLabel'))}">
  <h2>${escapeHtml(l10n('codeHealth.table.heading'))} <span class="count">${escapeHtml(l10n('codeHealth.table.topCount', { shown: String(rows.length), total: String(rows.length) }))}</span></h2>
  <div class="dash-table-wrap">
    <table class="dash-table code-health" id="pvTable">
      <thead>
        <tr>
          <th class="sortable col-grade" data-sort="grade" aria-sort="none">${escapeHtml(l10n('codeHealth.table.colGrade'))} <span class="arrow">▲</span></th>
          <th class="sortable col-score" data-sort="score" aria-sort="ascending">${escapeHtml(l10n('codeHealth.table.colScore'))} <span class="arrow">▲</span></th>
          <th class="sortable col-name"  data-sort="name"  aria-sort="none">${escapeHtml(l10n('codeHealth.table.colFunction'))} <span class="arrow">▲</span></th>
          <th class="sortable col-file"  data-sort="file"  aria-sort="none">${escapeHtml(l10n('codeHealth.table.colFile'))} <span class="arrow">▲</span></th>
          <th class="sortable col-line"  data-sort="line"  aria-sort="none">${escapeHtml(l10n('codeHealth.table.colLine'))} <span class="arrow">▲</span></th>
          <th class="sortable col-usage" data-sort="usage" aria-sort="none">${escapeHtml(l10n('codeHealth.table.colUsage'))} <span class="arrow">▲</span></th>
          <th class="sortable col-coverage" data-sort="coverage" aria-sort="none">${escapeHtml(l10n('codeHealth.table.colCoverage'))} <span class="arrow">▲</span></th>
          <th class="sortable col-complexity" data-sort="complexity" aria-sort="none">${escapeHtml(l10n('codeHealth.table.colComplexity'))} <span class="arrow">▲</span></th>
          <th class="col-flags">${escapeHtml(l10n('codeHealth.table.colFlags'))}</th>
        </tr>
      </thead>
      <tbody id="pvBody">${tbodyRows}</tbody>
    </table>
    <!-- §8.16 — empty-state banner shown by the script when text-filter or
         flag-filter narrows the visible row count to zero. Carries a tier-1
         *Reset filters* button so the user is not stranded looking at an
         empty table with no cue for the next action. -->
    <div id="pvEmpty" class="empty-cta" role="status" hidden>
      <p class="empty-msg">${escapeHtml(l10n('codeHealth.table.noMatch'))}</p>
      <button type="button" class="btn tier-1" id="pvResetFilters"
        title="${escapeHtml(l10n('codeHealth.table.resetFiltersTitle'))}">${escapeHtml(l10n('codeHealth.table.resetFilters'))}</button>
    </div>
  </div>
  <p class="hint">${escapeHtml(l10n('codeHealth.table.hint'))}</p>
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

/** Client-script strings resolved at host HTML build time. */
function codeHealthScriptStrings(): Record<string, string> {
  return {
    activeFiltersLabel: l10n('codeHealth.script.activeFiltersLabel'),
    clearAll: l10n('codeHealth.script.clearAll'),
  };
}

/** Inline client script — sort, search filter, KPI flag-filter, file-link nav, toolbar buttons. */
function buildClientScript(): string {
  const CH = codeHealthScriptStrings();
  return `
(function() {
  var CH = ${JSON.stringify(CH)};
  const vscode = acquireVsCodeApi();
  const state = { search: '', flag: null, sortKey: 'score', sortAsc: true };

  function postCmd(type) { vscode.postMessage({ type: type }); }
  document.getElementById('rescan').addEventListener('click', function() { postCmd('rescan'); });
  document.getElementById('copyJson').addEventListener('click', function() { postCmd('copyJson'); });
  document.getElementById('openPvSettings').addEventListener('click', function() { postCmd('openProjectVibrancySettings'); });
  // The gate-failure banner now exposes its own tier-1 *Open Code Health
  // settings* button (§8.16). Wire any [data-cmd] button on the page so
  // future banner / empty-state CTAs reuse the same dispatch path.
  document.querySelectorAll('[data-cmd]').forEach(function(b) {
    b.addEventListener('click', function() { postCmd(b.getAttribute('data-cmd')); });
  });

  const tbody = document.getElementById('pvBody');
  const searchEl = document.getElementById('pvSearch');
  const stripEl = document.getElementById('filter-strip');
  const emptyEl = document.getElementById('pvEmpty');
  const resetEmptyBtn = document.getElementById('pvResetFilters');
  if (resetEmptyBtn) resetEmptyBtn.addEventListener('click', resetFilters);

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
    let visible = 0;
    let total = 0;
    Array.from(tbody.querySelectorAll('tr')).forEach(function(tr) {
      total++;
      const hay = (tr.dataset.search || '').toLowerCase();
      const flagsArr = (tr.dataset.flags || '').split(/\\s+/);
      let show = true;
      if (state.search && hay.indexOf(state.search) === -1) show = false;
      if (state.flag && flagsArr.indexOf(state.flag) === -1) show = false;
      tr.style.display = show ? '' : 'none';
      if (show) visible++;
    });
    // §8.16 — show the empty-state CTA only when filters reduced the table
    // to zero rows. If there were no rows to begin with (e.g. fresh project,
    // no scan data) we leave the table alone — that is a different empty
    // condition handled by the upstream "no data" path, not by reset.
    if (emptyEl) emptyEl.hidden = !(visible === 0 && tbody.children.length > 0);
    renderStrip();
    // §15.3 — announce filter result count to screen readers.
    announce(visible + ' of ' + total + ' rows visible');
  }

  // §15.3 — polite live-region announcer.
  function announce(message) {
    var el = document.getElementById('announcer');
    if (!el) { return; }
    el.textContent = '';
    setTimeout(function() { el.textContent = message; }, 50);
  }

  function renderStrip() {
    const chips = [];
    if (state.search) chips.push({ key: 'search', label: 'search: "' + escapeHtml(state.search) + '"' });
    if (state.flag) chips.push({ key: 'flag', label: 'flag: ' + state.flag.replace(/_/g, ' ') });
    if (chips.length === 0) {
      stripEl.hidden = true; stripEl.innerHTML = ''; return;
    }
    stripEl.hidden = false;
    const html = ['<span class="lbl">' + CH.activeFiltersLabel + '</span>'];
    chips.forEach(function(chip) {
      html.push('<span class="chip">' + chip.label +
        '<button type="button" class="x" data-chip="' + chip.key + '" aria-label="Remove ' + chip.key + '">×</button></span>');
    });
    html.push('<button type="button" class="clear-all" id="clear-all-filters">' + CH.clearAll + '</button>');
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

  // §15.2 — page-level keyboard shortcuts advertised in the overlay.
  // '/' focuses the row filter; 'Esc' on a focused, non-empty filter clears it.
  document.addEventListener('keydown', function(e) {
    var tag = e.target && e.target.tagName ? e.target.tagName.toLowerCase() : '';
    var isEditable = tag === 'input' || tag === 'textarea' || tag === 'select';
    if (e.key === '/' && !isEditable) {
      e.preventDefault();
      if (searchEl) { searchEl.focus(); searchEl.select && searchEl.select(); }
    } else if (e.key === 'Escape' && e.target === searchEl && searchEl && searchEl.value) {
      e.preventDefault();
      searchEl.value = '';
      state.search = '';
      applyFilters();
    }
  });
  ${getKeyboardShortcutsScript()}
})();
`;
}
