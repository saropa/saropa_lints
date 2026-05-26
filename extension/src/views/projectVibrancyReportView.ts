/**
 * Module overview (comment coverage pass).
 * comment-coverage: module overview (batch).
 *
 * VS Code views: trees, dashboards, or webview HTML builders.
 */

import * as vscode from 'vscode';
import * as nodePath from 'node:path';
import * as nodeFs from 'node:fs';
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
// Absolute path of the most recently persisted report file. The dashboard
// surfaces this as a click-to-copy / open / reveal-in-Explorer row so the user
// has a real artifact to share or version, not just a transient webview.
let lastReportFilePath: string | undefined;
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
  // Persist BEFORE rendering so the dashboard can show the real path it can be
  // copied / opened / revealed from. A failed write is non-fatal — the panel
  // still renders, just without a file row.
  lastReportFilePath = writeReportFile(projectRoot, scan.rawStdout);
  panel.webview.html = buildHtml(scan.payload, lastReportFilePath);
  panel.reveal(vscode.ViewColumn.One);
}

/**
 * Write the raw report JSON to `reports/<yyyymmdd>/<yyyymmdd>_<HHmmss>_saropa_code_health.json`
 * under the project root. Returns the absolute path, or `undefined` on failure
 * (a missing /reports parent dir is created; a permission error swallows so the
 * dashboard still renders).
 *
 * The date-partitioned filename pattern matches the rest of the saropa toolchain
 * so report files from multiple tools sit side-by-side in one folder per day.
 */
function writeReportFile(projectRoot: string, rawJson: string): string | undefined {
  if (rawJson.trim().length === 0) return undefined;
  try {
    const now = new Date();
    const day = reportDateStamp(now);
    const time = reportTimeStamp(now);
    const dir = nodePath.join(projectRoot, 'reports', day);
    nodeFs.mkdirSync(dir, { recursive: true });
    const filePath = nodePath.join(dir, `${day}_${time}_saropa_code_health.json`);
    nodeFs.writeFileSync(filePath, rawJson);
    return filePath;
  } catch {
    return undefined;
  }
}

/** `yyyymmdd` from a Date in local time — matches saropa report naming. */
function reportDateStamp(d: Date): string {
  const y = String(d.getFullYear()).padStart(4, '0');
  const m = String(d.getMonth() + 1).padStart(2, '0');
  const day = String(d.getDate()).padStart(2, '0');
  return `${y}${m}${day}`;
}

/** `HHmmss` from a Date in local time. */
function reportTimeStamp(d: Date): string {
  const h = String(d.getHours()).padStart(2, '0');
  const m = String(d.getMinutes()).padStart(2, '0');
  const s = String(d.getSeconds()).padStart(2, '0');
  return `${h}${m}${s}`;
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
    return;
  }
  if (data.type === 'copyReportPath') {
    if (!lastReportFilePath) return;
    await vscode.env.clipboard.writeText(lastReportFilePath);
    // Inline English (not l10n) so the publish gate isn't blocked on new keys
    // needing translation across all locales — fold into i18n in a later pass.
    void vscode.window.showInformationMessage(
      `Copied report path: ${lastReportFilePath}`,
    );
    return;
  }
  if (data.type === 'openReportFile') {
    if (!lastReportFilePath) return;
    try {
      const doc = await vscode.workspace.openTextDocument(
        vscode.Uri.file(lastReportFilePath),
      );
      await vscode.window.showTextDocument(doc);
    } catch {
      void vscode.window.showErrorMessage(
        `Could not open report file: ${lastReportFilePath}`,
      );
    }
    return;
  }
  if (data.type === 'revealReportFile') {
    if (!lastReportFilePath) return;
    // `revealFileInOS` opens the OS file browser at the file — Explorer on
    // Windows, Finder on macOS, the default file manager on Linux.
    await vscode.commands.executeCommand(
      'revealFileInOS',
      vscode.Uri.file(lastReportFilePath),
    );
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
export function buildProjectVibrancyHtml(
  payload: ProjectVibrancyPayload,
  reportFilePath?: string,
): string {
  return buildHtml(payload, reportFilePath);
}

function buildHtml(
  payload: ProjectVibrancyPayload,
  reportFilePath?: string,
): string {
  const summary = payload.summary ?? {};
  // Ship the FULL sorted list to the client — previously sliced to 200, which
  // meant KPI clicks and the search filter only operated on a tiny prefix and
  // produced misleading results (e.g. clicking "Test drift: 974" showed 5
  // because only 5 of the 974 happened to be in the worst-200).
  const rows = [...(payload.functions ?? [])].sort((a, b) => a.score - b.score);
  const problemCount = rows.filter((r) => r.score < 50).length;
  const complexCount = rows.filter((r) => r.flags.includes('complex')).length;
  const nonce = createWebviewCspNonce();
  const gateFailed = payload.gates?.pass === false;
  return `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8" />
  <title>${escapeHtml(l10n('codeHealth.documentTitle'))}</title>
  <!-- 'unsafe-inline' on style-src: score pills set their colour via inline
       style="--score-color:hsl(...)" attributes (one per row, ~thousands per
       report). CSP nonces only authorize <style> blocks, not style attributes —
       without 'unsafe-inline' every pill would lose its colour. -->
  <meta http-equiv="Content-Security-Policy" content="default-src 'none'; style-src 'nonce-${nonce}' 'unsafe-inline'; script-src 'nonce-${nonce}';">
  <style nonce="${nonce}">${getProjectVibrancyReportStyles()}${getKeyboardShortcutsStyles()}</style>
</head>
<body>
<a href="#pvTable" class="skip-link">${escapeHtml(l10n('codeHealth.skipToTable'))}</a>
<div id="announcer" role="status" aria-live="polite" aria-atomic="true"></div>
<header>
${buildHero(payload, summary, problemCount)}
</header>
${gateFailed ? buildGateBanner(payload) : ''}
${buildKpiRow(summary, complexCount)}
${buildReportFileRow(reportFilePath)}
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

/**
 * Header band: status line only. The hero gauge was removed because it
 * duplicated the average-score text right next to it (with different rounding
 * — header said "avg 53.5 (C)", gauge said "C 54/100"), which read as a layout
 * accident rather than a feature. Numbers in the status line now carry the
 * same info more compactly, and a problem-count chip surfaces the triage
 * signal (how many D/E/F functions) that the gauge silently omitted.
 */
function buildHero(
  payload: ProjectVibrancyPayload,
  summary: NonNullable<ProjectVibrancyPayload['summary']>,
  problemCount: number,
): string {
  const generated = formatRelativeFreshness(payload.generatedAt);
  const avgScore = typeof summary.averageScore === 'number' ? summary.averageScore : 0;
  const avgGrade = summary.averageGrade ?? '—';
  const fnCount = summary.functionCount ?? (payload.functions?.length ?? 0);
  const gateFailed = payload.gates?.pass === false;
  const problemPillClass = problemCount === 0 ? 'good' : problemCount < 50 ? 'warn' : 'bad';
  const parts = [
    `${escapeHtml(l10n('codeHealth.hero.generated'))} <strong>${escapeHtml(generated)}</strong>`,
    pluralize(fnCount, { one: l10n('codeHealth.hero.functionOne'), other: l10n('codeHealth.hero.functionOther') }),
    escapeHtml(l10n('codeHealth.hero.avgFormat', { score: Math.round(avgScore).toString(), grade: avgGrade })),
    `<span class="pill ${problemPillClass}" title="Functions scoring under 50 (grades D, E, F)">${problemCount.toLocaleString('en-US')} problems</span>`,
    gateFailed
      ? `<span class="pill bad">${escapeHtml(l10n('codeHealth.hero.gatesFailing'))}</span>`
      : `<span class="pill good">${escapeHtml(l10n('codeHealth.hero.gatesPassing'))}</span>`,
  ];
  const statusLine = parts
    .map((p, i) => (i === 0 ? `<span>${p}</span>` : `<span class="dot">·</span><span>${p}</span>`))
    .join('');
  return `<header class="dash-hero">
  <div class="hero-text">
    <h1>${escapeHtml(l10n('codeHealth.hero.title'))}</h1>
    <p class="status-line">${statusLine}${buildKeyboardShortcutsButton()}</p>
  </div>
</header>`;
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
function buildKpiRow(
  summary: NonNullable<ProjectVibrancyPayload['summary']>,
  complexCount: number,
): string {
  // 'complex' isn't in summary (no aggregate count in the CLI payload), so the
  // dashboard counts it directly from the loaded rows — keeps it in lock-step
  // with the table and the click filter, without shipping yet another CLI flag.
  const specs: KpiInput[] = [
    { flag: 'unused', label: l10n('codeHealth.kpi.unused'), value: summary.unusedCount ?? 0, sub: l10n('codeHealth.kpi.unusedSub'), classes: 'crit' },
    { flag: 'uncovered', label: l10n('codeHealth.kpi.uncovered'), value: summary.uncoveredCount ?? 0, sub: l10n('codeHealth.kpi.uncoveredSub'), classes: 'errors' },
    { flag: 'complex', label: 'COMPLEX', value: complexCount, sub: 'high cyclomatic complexity', classes: 'warnings' },
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

/**
 * Click-to-copy / open / reveal row for the persisted JSON file. Rendered only
 * when the write succeeded so we never lie about a file the user can't reach.
 * Three distinct actions because each maps to a different next step the user
 * actually takes with this artifact: copy the path to paste into a chat, open
 * the JSON in the editor, or jump to the folder in the OS file browser.
 */
function buildReportFileRow(reportFilePath: string | undefined): string {
  if (!reportFilePath) return '';
  return `<section class="report-file" aria-label="Saved report file">
  <span class="rf-label">Saved to</span>
  <span class="rf-path" id="reportFilePath" title="Click to copy" tabindex="0" role="button">${escapeHtml(reportFilePath)}</span>
  <button type="button" class="btn" id="copyReportPath" title="Copy this path to the clipboard">Copy path</button>
  <button type="button" class="btn" id="openReportFile" title="Open the JSON in the editor">Open</button>
  <button type="button" class="btn" id="revealReportFile" title="Reveal in the OS file browser">Reveal</button>
</section>`;
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

/**
 * Sortable, sticky-header functions table — bound to the FULL function list
 * (previously sliced to 200, which broke filters and KPI clicks because they
 * only saw the prefix). Sort indicators show ONLY on the active column and in
 * the actual direction (the previous design painted an up-arrow on every
 * header forever, which read as decoration, not state). The grade column was
 * dropped: it duplicated the score axis. The score itself is a colored pill
 * (red→amber→green by value) so the value AND the bucketing are in one cell.
 */
function buildTable(rows: readonly ProjectVibrancyFunctionRow[]): string {
  const tbodyRows = rows.map((row) => buildTableRow(row)).join('');
  const total = rows.length;
  return `<section class="section" aria-label="${escapeHtml(l10n('codeHealth.table.ariaLabel'))}">
  <h2>${escapeHtml(l10n('codeHealth.table.heading'))} <span class="count" id="pvShownCount">showing ${total.toLocaleString('en-US')} of ${total.toLocaleString('en-US')}</span></h2>
  <div class="dash-table-wrap">
    <table class="dash-table code-health" id="pvTable">
      <thead>
        <tr>
          <th class="sortable col-score" data-sort="score" aria-sort="ascending">${escapeHtml(l10n('codeHealth.table.colScore'))}<span class="arrow"></span></th>
          <th class="sortable col-name"  data-sort="name"  aria-sort="none">${escapeHtml(l10n('codeHealth.table.colFunction'))}<span class="arrow"></span></th>
          <th class="sortable col-file"  data-sort="file"  aria-sort="none">${escapeHtml(l10n('codeHealth.table.colFile'))}<span class="arrow"></span></th>
          <th class="sortable col-line"  data-sort="line"  aria-sort="none">${escapeHtml(l10n('codeHealth.table.colLine'))}<span class="arrow"></span></th>
          <th class="sortable col-usage" data-sort="usage" aria-sort="none">${escapeHtml(l10n('codeHealth.table.colUsage'))}<span class="arrow"></span></th>
          <th class="sortable col-coverage" data-sort="coverage" aria-sort="none">${escapeHtml(l10n('codeHealth.table.colCoverage'))}<span class="arrow"></span></th>
          <th class="sortable col-complexity" data-sort="complexity" aria-sort="none">${escapeHtml(l10n('codeHealth.table.colComplexity'))}<span class="arrow"></span></th>
          <th class="sortable col-changed" data-sort="changed" aria-sort="none" title="Last commit that touched this file">Changed<span class="arrow"></span></th>
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
  const flags = row.flags
    .map((f) => `<span class="flag-pill ${escapeHtml(f)}">${escapeHtml(f.replace(/_/g, ' '))}</span>`)
    .join(' ');
  const flagsAttr = row.flags.join(' ');
  // Search haystack — name + path + flags. The name comes first so a substring
  // typed into the filter prefers function-name matches over file-path matches.
  const search = `${row.name} ${row.file} ${row.flags.join(' ')}`.toLowerCase();
  const scoreInt = Math.round(row.score);
  const scoreColor = hslForScore(scoreInt);
  // Operator overrides come from the analyzer by their symbol (`==`, `<`, `[]`).
  // Bare in a "worst functions" list they read as nonsense; prefix `operator `
  // so the row is identifiable. (Class context would be ideal but isn't in the
  // CLI payload today — follow-up.)
  const displayName = /^[A-Za-z_$]/.test(row.name) ? row.name : `operator ${row.name}`;
  const dir = lastSlashDir(row.file);
  const base = lastSlashBase(row.file);
  const changed = row.lastChangedEpochSec;
  const changedText = changed ? formatRelativeAge(changed) : '—';
  const changedSort = changed ?? 0;
  return `<tr data-score="${row.score}" data-name="${escapeHtml(row.name)}"
    data-file="${escapeHtml(row.file)}" data-line="${row.lineStart}" data-line-end="${row.lineEnd}"
    data-usage="${row.usageCount}" data-coverage="${row.coveragePercent}" data-complexity="${row.complexity}"
    data-changed="${changedSort}" data-flags="${escapeHtml(flagsAttr)}" data-search="${escapeHtml(search)}">
    <td class="col-score"><span class="score-pill" style="background:${scoreColor};color:#000;" title="Score ${scoreInt}/100">${scoreInt}</span></td>
    <td class="col-name"><span class="fn-link" data-file="${escapeHtml(row.file)}" data-line="${row.lineStart}" title="Open at line ${row.lineStart}">${escapeHtml(displayName)}</span></td>
    <td class="col-file"><span class="file-link" data-file="${escapeHtml(row.file)}" data-line="${row.lineStart}" title="${escapeHtml(row.file)}"><span class="path-dir">${escapeHtml(dir)}</span><span class="path-base">${escapeHtml(base)}</span></span></td>
    <td class="col-line">${row.lineStart}-${row.lineEnd}</td>
    <td class="col-usage">${row.usageCount.toLocaleString('en-US')}</td>
    <td class="col-coverage">${Math.round(row.coveragePercent)}%</td>
    <td class="col-complexity">${row.complexity}</td>
    <td class="col-changed" title="${changed ? new Date(changed * 1000).toISOString() : 'No git history available'}">${escapeHtml(changedText)}</td>
    <td class="col-flags"><span class="flag-pills">${flags}</span></td>
  </tr>`;
}

/** Trailing directory portion (including final slash), '' if none. */
function lastSlashDir(filePath: string): string {
  const i = filePath.lastIndexOf('/');
  return i < 0 ? '' : filePath.slice(0, i + 1);
}

/** Basename, or the whole path if no slash. */
function lastSlashBase(filePath: string): string {
  const i = filePath.lastIndexOf('/');
  return i < 0 ? filePath : filePath.slice(i + 1);
}

/**
 * Compact relative age for the Changed column: "3d", "5w", "2mo", "1y". Per-row
 * so it has to be terse — the column is narrow, and ISO timestamps are in the
 * cell `title` for anyone wanting precision.
 */
function formatRelativeAge(epochSec: number): string {
  const sec = Math.max(0, Math.floor(Date.now() / 1000 - epochSec));
  if (sec < 60) return 'now';
  if (sec < 3600) return `${Math.floor(sec / 60)}m`;
  if (sec < 86400) return `${Math.floor(sec / 3600)}h`;
  const days = Math.floor(sec / 86400);
  if (days < 14) return `${days}d`;
  if (days < 60) return `${Math.floor(days / 7)}w`;
  if (days < 365) return `${Math.floor(days / 30)}mo`;
  return `${Math.floor(days / 365)}y`;
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
  // Report-file action row (present only when a JSON file was written). Clicking
  // the path itself also copies, since the path looks clickable.
  function wireReportBtn(id, type) {
    var el = document.getElementById(id);
    if (el) el.addEventListener('click', function() { postCmd(type); });
  }
  wireReportBtn('copyReportPath', 'copyReportPath');
  wireReportBtn('openReportFile', 'openReportFile');
  wireReportBtn('revealReportFile', 'revealReportFile');
  var rfPath = document.getElementById('reportFilePath');
  if (rfPath) {
    rfPath.addEventListener('click', function() { postCmd('copyReportPath'); });
    rfPath.addEventListener('keydown', function(e) {
      if (e.key === 'Enter' || e.key === ' ') { e.preventDefault(); postCmd('copyReportPath'); }
    });
  }
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
    if (emptyEl) emptyEl.hidden = !(visible === 0 && tbody.children.length > 0);
    var countEl = document.getElementById('pvShownCount');
    if (countEl) {
      countEl.textContent = 'showing ' + visible.toLocaleString('en-US') +
        ' of ' + total.toLocaleString('en-US');
    }
    renderStrip();
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
    if (key === 'usage' || key === 'complexity' || key === 'line' || key === 'changed') {
      return parseInt(tr.dataset[key] || '0', 10);
    }
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

  // Open-at-line for both the function-name and the file cells. One delegated
  // listener on the tbody so we don't attach thousands of per-row handlers
  // (with 18k+ rows that mattered: per-row listeners noticeably slowed render).
  if (tbody) {
    tbody.addEventListener('click', function(e) {
      var t = e.target;
      while (t && t !== tbody && !(t.classList && (t.classList.contains('fn-link') || t.classList.contains('file-link')))) {
        t = t.parentNode;
      }
      if (!t || t === tbody) return;
      var file = t.getAttribute('data-file');
      var line = Number(t.getAttribute('data-line') || '1');
      if (!file) return;
      vscode.postMessage({ type: 'openFile', file: file, line: line });
    });
  }

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
