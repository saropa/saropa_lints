/**
 * Module overview (comment coverage pass).
 * comment-coverage: module overview (batch).
 *
 * VS Code views: trees, dashboards, or webview HTML builders.
 */

import * as vscode from 'vscode';
import * as nodePath from 'node:path';
import * as nodeFs from 'node:fs';
import { createWebviewCspNonce, escapeHtml, jsonForScriptBlock } from '../vibrancy/views/html-utils';
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
import { mergeCodeHealthSuppression } from './codeHealthSuppression';

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
  if (data.type === 'copyText') {
    // Generic text-to-clipboard for in-page selections (currently the bulk
    // "Copy selected" workflow on the worst-functions table). Bounded to
    // 1 MB so a runaway selection can't paste a multi-megabyte string into
    // the clipboard by accident.
    const text = (data as { text?: string }).text;
    if (typeof text !== 'string' || text.length === 0) return;
    const capped = text.length > 1_000_000 ? text.slice(0, 1_000_000) : text;
    await vscode.env.clipboard.writeText(capped);
    const lineCount = capped.split('\n').filter((l) => l.length > 0).length;
    void vscode.window.showInformationMessage(
      `Copied ${lineCount} ${lineCount === 1 ? 'row' : 'rows'} to clipboard.`,
    );
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
    return;
  }
  if (data.type === 'suppressFlag') {
    const dm = data as { file?: string; flag?: string };
    if (typeof dm.file !== 'string' || typeof dm.flag !== 'string') return;
    await applyFileSuppression(dm.file, dm.flag);
    return;
  }
}

/**
 * Write a `// ignore_for_file: code_health:<flag>` directive into a source
 * file so the next Code Health scan drops that flag for that file. Pure merge
 * logic lives in [mergeCodeHealthSuppression] (testable; no I/O). This shim
 * resolves the report-relative path against the workspace root, reads the
 * file via VS Code's file API (respects unsaved buffers and any FS provider),
 * applies the merge, writes back, and offers a one-click rescan.
 *
 * The toast uses the existing rescan command (same path the toolbar button
 * uses) so the suppression closes the loop in a single user click.
 */
async function applyFileSuppression(reportFile: string, flag: string): Promise<void> {
  const root = getProjectRoot();
  if (!root) return;
  try {
    const uri = resolveReportFileUri(root, reportFile);
    const buffer = await vscode.workspace.fs.readFile(uri);
    const original = new TextDecoder('utf-8').decode(buffer);
    const merged = mergeCodeHealthSuppression(original, flag);
    const fileName = nodePath.basename(reportFile);
    if (merged.noChange) {
      void vscode.window.showInformationMessage(
        `'${flag}' is already suppressed in ${fileName}.`,
      );
      return;
    }
    await vscode.workspace.fs.writeFile(uri, new TextEncoder().encode(merged.content));
    const rescanAction = 'Rescan';
    const choice = await vscode.window.showInformationMessage(
      `Suppressed '${flag}' in ${fileName}.`,
      rescanAction,
    );
    if (choice === rescanAction) {
      await openProjectVibrancyReport();
    }
  } catch (e) {
    void vscode.window.showErrorMessage(
      `Could not suppress '${flag}' in ${reportFile}: ${(e as Error).message ?? e}`,
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
${buildTable(rows, nonce)}
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
  // Suppressed-file count: number of files dropped from the scan by codegen
  // detection or by `// ignore_for_file: code_health`. Surfaced as a hero pill
  // so suppression stays visible — "we silently skipped 247 of your files"
  // would be the failure mode otherwise.
  const supp = (summary as { suppressions?: { codegenFiles?: number; directiveFiles?: number } }).suppressions;
  const suppCodegen = supp?.codegenFiles ?? 0;
  const suppDirective = supp?.directiveFiles ?? 0;
  const suppTotal = suppCodegen + suppDirective;
  const parts = [
    `${escapeHtml(l10n('codeHealth.hero.generated'))} <strong>${escapeHtml(generated)}</strong>`,
    pluralize(fnCount, { one: l10n('codeHealth.hero.functionOne'), other: l10n('codeHealth.hero.functionOther') }),
    escapeHtml(l10n('codeHealth.hero.avgFormat', { score: Math.round(avgScore).toString(), grade: avgGrade })),
    `<span class="pill ${problemPillClass}" title="Functions scoring under 50 (grades D, E, F)">${problemCount.toLocaleString('en-US')} problems</span>`,
  ];
  if (suppTotal > 0) {
    const title = `${suppCodegen} auto-detected codegen file(s), ${suppDirective} suppressed via // ignore_for_file: code_health`;
    parts.push(
      `<span class="pill" title="${escapeHtml(title)}">${suppTotal.toLocaleString('en-US')} suppressed</span>`,
    );
  }
  parts.push(
    gateFailed
      ? `<span class="pill bad">${escapeHtml(l10n('codeHealth.hero.gatesFailing'))}</span>`
      : `<span class="pill good">${escapeHtml(l10n('codeHealth.hero.gatesPassing'))}</span>`,
  );
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

/**
 * Toolbar: tier-1 *Rescan*, tier-2 *Copy filtered* / *Copy JSON* / *Settings*,
 * then the filter controls — *Score ≤* numeric threshold, *Hide boilerplate*
 * checkbox (default ON), and the text search. The workflow is filter-driven:
 * narrow the table to the rows of interest, then *Copy filtered* dumps every
 * visible row to the clipboard. No selection checkboxes — the filters ARE the
 * selection, which keeps the table clean and scales to large reports.
 *
 * Boilerplate is hidden by default because `==`, `hashCode`, `toString`,
 * `copyWith`, `fromJson` etc. dominate a real project's worst-functions list
 * but rarely deserve triage; surfacing them obscures the actionable problems.
 */
function buildToolbar(): string {
  return `<section class="toolbar-band" role="toolbar" aria-label="${escapeHtml(l10n('codeHealth.toolbar.ariaLabel'))}">
  <div class="toolbar-row spread">
    <div class="toolbar-row" style="gap:6px;">
      <button class="btn tier-1" id="rescan" type="button"
        title="${escapeHtml(l10n('codeHealth.toolbar.rescanTitle'))}">${escapeHtml(l10n('codeHealth.toolbar.rescan'))}</button>
      <button class="btn" id="copyFiltered" type="button" disabled
        title="Copy every row currently shown in the table — one line per row: file:line, function name, score, flags. Use the score threshold, KPI tiles, search field, and boilerplate toggle to narrow the table down to the rows you want first.">Copy filtered</button>
      <button class="btn" id="copyJson" type="button"
        title="${escapeHtml(l10n('codeHealth.toolbar.copyJsonTitle'))}">${escapeHtml(l10n('codeHealth.toolbar.copyJson'))}</button>
      <button class="btn" id="openPvSettings" type="button"
        title="${escapeHtml(l10n('codeHealth.toolbar.settingsTitle'))}">${escapeHtml(l10n('codeHealth.toolbar.settingsButton'))}</button>
    </div>
    <div class="toolbar-row" style="gap:12px;">
      <label class="field score-threshold" title="Only show functions with a score at or below this number. Empty = no limit. Try 30 for the worst third, 50 for problem grades (D / E / F).">
        <span class="sr-only-label">Score ≤</span>
        <span class="prefix">Score ≤</span>
        <input id="pvScoreMax" type="number" min="0" max="100" inputmode="numeric" placeholder="—" autocomplete="off" />
      </label>
      <label class="check-inline" title="Hide equality, serialization, and dispatch boilerplate: operator overrides (==, &lt;, []), hashCode, toString, noSuchMethod, copyWith, fromJson, toJson, fromMap, toMap, props (Equatable). These are technically functions but rarely the source of code-health concerns; on by default so the table surfaces functions you can actually act on.">
        <input type="checkbox" id="hideBoilerplate" checked />
        <span>Hide boilerplate methods</span>
      </label>
      <label class="field" title="${escapeHtml(l10n('codeHealth.toolbar.filterTitle'))}">
        <span class="glyph">🔎</span>
        <label class="sr-only" for="pvSearch">${escapeHtml(l10n('codeHealth.toolbar.filterLabel'))}</label>
        <input id="pvSearch" type="search" placeholder="${escapeHtml(l10n('codeHealth.toolbar.filterPlaceholder'))}" autocomplete="off" />
      </label>
    </div>
  </div>
</section>`;
}

/**
 * Sortable, sticky-header functions table — bound to the FULL function list.
 *
 * Rendering strategy: rows are embedded as JSON in a `<script type="application/
 * json">` data block, NOT as server-side `<tr>` elements. The previous design
 * emitted 18,000+ `<tr>`s into the DOM up front, which locked the browser for
 * seconds on every render and made sort clicks unresponsive (re-appending 18k
 * DOM rows triggers 18k layouts). The inline script parses the data once and
 * renders a 500-row window into the empty tbody; sort/filter operate on the
 * data array (fast); a "Show next 500" button reveals more on demand. Selection
 * checkboxes feed the toolbar's *Copy selected* action.
 *
 * Sort indicators show ONLY on the active column and in the actual direction
 * (the previous all-up-arrow-forever design read as decoration, not state).
 * The grade column was dropped (it duplicated the score axis); the score is a
 * colored pill (red→amber→green) carrying both value and bucketing in one
 * cell. A `title` on the score header explains the composite formula since the
 * column header alone gave no clue what the number means.
 */
function buildTable(
  rows: readonly ProjectVibrancyFunctionRow[],
  nonce: string,
): string {
  const total = rows.length;
  const scoreTitle =
    'Composite health score, 0–100, lower = worse. Formula: ' +
    '40% test coverage + 25% how often the function is referenced + ' +
    '15% how recently its file changed + 15% cyclomatic complexity + ' +
    '5% documentation. Click to sort.';
  // Strip down to only the fields the row renderer reads — keeps the embedded
  // JSON small (3,600 functions × extra fields adds up fast).
  const rowData = rows.map((r) => ({
    file: r.file,
    name: r.name,
    lineStart: r.lineStart,
    lineEnd: r.lineEnd,
    score: r.score,
    usageCount: r.usageCount,
    coveragePercent: r.coveragePercent,
    complexity: r.complexity,
    flags: r.flags,
    lastChangedEpochSec: r.lastChangedEpochSec ?? 0,
  }));
  return `<section class="section" aria-label="${escapeHtml(l10n('codeHealth.table.ariaLabel'))}">
  <h2>${escapeHtml(l10n('codeHealth.table.heading'))} <span class="count" id="pvShownCount">showing 0 of ${total.toLocaleString('en-US')}</span></h2>
  <div class="dash-table-wrap" id="pvTableWrap">
    <table class="dash-table code-health" id="pvTable">
      <thead>
        <tr>
          <th class="sortable col-score" data-sort="score" aria-sort="ascending" title="${escapeHtml(scoreTitle)}">${escapeHtml(l10n('codeHealth.table.colScore'))}<span class="arrow"></span></th>
          <th class="sortable col-name"  data-sort="name"  aria-sort="none">${escapeHtml(l10n('codeHealth.table.colFunction'))}<span class="arrow"></span></th>
          <th class="sortable col-file"  data-sort="file"  aria-sort="none">${escapeHtml(l10n('codeHealth.table.colFile'))}<span class="arrow"></span></th>
          <th class="sortable col-line"  data-sort="line"  aria-sort="none">${escapeHtml(l10n('codeHealth.table.colLine'))}<span class="arrow"></span></th>
          <th class="sortable col-usage" data-sort="usage" aria-sort="none" title="How many times this function name is referenced across all scanned files (lib + test).">${escapeHtml(l10n('codeHealth.table.colUsage'))}<span class="arrow"></span></th>
          <th class="sortable col-coverage" data-sort="coverage" aria-sort="none" title="Line coverage % from LCOV, when available.">${escapeHtml(l10n('codeHealth.table.colCoverage'))}<span class="arrow"></span></th>
          <th class="sortable col-complexity" data-sort="complexity" aria-sort="none" title="Cyclomatic complexity — branches + loops + boolean operators inside the function body.">${escapeHtml(l10n('codeHealth.table.colComplexity'))}<span class="arrow"></span></th>
          <th class="sortable col-changed" data-sort="changed" aria-sort="none" title="How long ago the last commit touched this file (ISO timestamp in each cell's tooltip).">Changed<span class="arrow"></span></th>
          <th class="col-flags">${escapeHtml(l10n('codeHealth.table.colFlags'))}</th>
        </tr>
      </thead>
      <tbody id="pvBody"></tbody>
    </table>
    <div id="pvEmpty" class="empty-cta" role="status" hidden>
      <p class="empty-msg">${escapeHtml(l10n('codeHealth.table.noMatch'))}</p>
      <button type="button" class="btn tier-1" id="pvResetFilters"
        title="${escapeHtml(l10n('codeHealth.table.resetFiltersTitle'))}">${escapeHtml(l10n('codeHealth.table.resetFilters'))}</button>
    </div>
    <div id="pvLoadMore" class="load-more" hidden>
      <button type="button" class="btn" id="pvLoadMoreBtn">Show next 500</button>
    </div>
  </div>
  <p class="hint">Narrow the table with the search field, the score threshold, and the KPI tiles (click multiple to combine), then click <strong>Copy filtered</strong> to bulk-copy every visible row as <code>file:line  name  (score, flags)</code> lines.</p>
  <script id="pvRowData" type="application/json" nonce="${nonce}">${jsonForScriptBlock(rowData)}</script>
</section>`;
}

/** Client-script strings resolved at host HTML build time. */
function codeHealthScriptStrings(): Record<string, string> {
  return {
    activeFiltersLabel: l10n('codeHealth.script.activeFiltersLabel'),
    clearAll: l10n('codeHealth.script.clearAll'),
    expanderCollapsed: l10n('codeHealth.table.expanderAriaCollapsed'),
    expanderExpanded: l10n('codeHealth.table.expanderAriaExpanded'),
    detailHeading: l10n('codeHealth.table.detailHeading'),
    detailNoIssues: l10n('codeHealth.table.detailNoIssues'),
    suppressLabel: l10n('codeHealth.table.suppressLabel'),
    suppressTooltip: l10n('codeHealth.table.suppressTooltip'),
  };
}

/**
 * Localized descriptors for each flag, shipped to the client so each pill can
 * carry its evidence inline (e.g. `complex (CC 36)`) AND so the expanded detail
 * row can name the rule that fired (`Flagged when cyclomatic complexity > 10`).
 * The `evidence` template uses {cc}/{pct} tokens substituted per-row at render
 * time — knowing the threshold matters more than knowing the label.
 */
function codeHealthFlagDescriptors(): Record<string, { label: string; evidence: string; rule: string }> {
  const keys = [
    'unused', 'uncovered', 'complex', 'undocumented',
    'test_drift', 'stub_tested', 'suspicious_coverage',
  ];
  const out: Record<string, { label: string; evidence: string; rule: string }> = {};
  for (const k of keys) {
    out[k] = {
      label: l10n('codeHealth.flag.' + k + '.label'),
      evidence: l10n('codeHealth.flag.' + k + '.evidence'),
      rule: l10n('codeHealth.flag.' + k + '.rule'),
    };
  }
  return out;
}

/** Inline client script — sort, search filter, KPI flag-filter, file-link nav, toolbar buttons. */
function buildClientScript(): string {
  const CH = codeHealthScriptStrings();
  const FLAGS = codeHealthFlagDescriptors();
  return `
(function() {
  var CH = ${JSON.stringify(CH)};
  var FLAG_DESC = ${JSON.stringify(FLAGS)};
  var vscode = acquireVsCodeApi();

  // Row data is parsed once from the JSON script block. The previous design
  // server-rendered 18,000+ <tr> elements into the DOM up front and locked the
  // browser; this approach holds rows in memory, renders a 500-row window,
  // and runs filter/sort on the array (cheap) before re-rendering.
  var dataEl = document.getElementById('pvRowData');
  var allRows = [];
  try { allRows = JSON.parse(dataEl ? dataEl.textContent : '[]'); }
  catch (e) { allRows = []; }

  var RENDER_CHUNK = 500;
  var state = {
    search: '',
    // Multi-flag set: KPI cards add/remove membership (intersection — every
    // active flag must be present on the row). A single-flag mutual-exclusive
    // state was less useful: "show me unused AND complex" is a common ask.
    flags: Object.create(null),
    flagCount: 0,
    // Numeric score cap. null = no limit. Common values: 30 (worst third),
    // 50 (D/E/F problem grades).
    scoreMax: null,
    sortKey: 'score', sortAsc: true,
    hideBoilerplate: true,
    visibleCount: RENDER_CHUNK,
    // Per-row expansion: rowKey(r) of any rows the user has expanded to read
    // the "why scored low" detail. Set (not array) so re-renders after sort or
    // filter restore the open state in O(1) per row.
    expanded: Object.create(null)
  };
  var filtered = [];

  // Names that dominate a "worst functions" list because they are tiny,
  // uncovered, and rarely called — but where touching them rarely improves
  // anything. Hidden by default; toggle uncheck to see them.
  var BOILERPLATE_NAMES = {
    'hashCode': 1, 'toString': 1, 'noSuchMethod': 1,
    'copyWith': 1, 'props': 1,
    'fromJson': 1, 'toJson': 1, 'fromMap': 1, 'toMap': 1
  };
  function isBoilerplate(name) {
    if (!name) return false;
    if (BOILERPLATE_NAMES[name]) return true;
    if (!/^[A-Za-z_$]/.test(name)) return true; // operator overrides
    return false;
  }
  function displayName(name) {
    if (!name) return '';
    return /^[A-Za-z_$]/.test(name) ? name : 'operator ' + name;
  }
  function rowKey(r) { return r.file + ':' + r.lineStart + ':' + r.name; }

  function hslForScore(s) {
    var c = Math.max(0, Math.min(100, s));
    return 'hsl(' + Math.round((c / 100) * 130) + ', 70%, 50%)';
  }
  function fmtAge(epochSec) {
    if (!epochSec) return '—';
    var sec = Math.max(0, Math.floor(Date.now() / 1000 - epochSec));
    if (sec < 60) return 'now';
    if (sec < 3600) return Math.floor(sec / 60) + 'm';
    if (sec < 86400) return Math.floor(sec / 3600) + 'h';
    var days = Math.floor(sec / 86400);
    if (days < 14) return days + 'd';
    if (days < 60) return Math.floor(days / 7) + 'w';
    if (days < 365) return Math.floor(days / 30) + 'mo';
    return Math.floor(days / 365) + 'y';
  }
  function esc(s) {
    return String(s)
      .replace(/&/g, '&amp;').replace(/</g, '&lt;')
      .replace(/>/g, '&gt;').replace(/"/g, '&quot;');
  }

  function compileFiltered() {
    var q = state.search;
    var flagSet = state.flags;
    var flagCount = state.flagCount;
    var scoreMax = state.scoreMax;
    var hideBp = state.hideBoilerplate;
    filtered = allRows.filter(function(r) {
      if (hideBp && isBoilerplate(r.name)) return false;
      if (scoreMax !== null && r.score > scoreMax) return false;
      if (flagCount > 0) {
        // AND-intersection: every active flag must be present on the row.
        for (var f in flagSet) {
          if (r.flags.indexOf(f) === -1) return false;
        }
      }
      if (q) {
        var hay = (r.name + ' ' + r.file + ' ' + r.flags.join(' ')).toLowerCase();
        if (hay.indexOf(q) === -1) return false;
      }
      return true;
    });
    sortFiltered();
  }
  function sortVal(r, key) {
    switch (key) {
      case 'score': return r.score;
      case 'name': return (r.name || '').toLowerCase();
      case 'file': return (r.file || '').toLowerCase();
      case 'line': return r.lineStart;
      case 'usage': return r.usageCount;
      case 'coverage': return r.coveragePercent;
      case 'complexity': return r.complexity;
      case 'changed': return r.lastChangedEpochSec || 0;
      default: return 0;
    }
  }
  function sortFiltered() {
    var key = state.sortKey, asc = state.sortAsc;
    filtered.sort(function(a, b) {
      var av = sortVal(a, key), bv = sortVal(b, key);
      var c = (typeof av === 'number' && typeof bv === 'number')
        ? av - bv
        : String(av).localeCompare(String(bv));
      return asc ? c : -c;
    });
  }

  // Resolve a flag's i18n descriptor and substitute per-row tokens. Returns
  // { label, evidence, rule } — evidence is the inline "why" carried on the
  // pill, rule is the threshold sentence shown in the expanded detail panel.
  // Unknown flags fall back to the bare flag name so a future CLI flag can't
  // crash the renderer.
  function flagInfo(f, r) {
    var d = FLAG_DESC[f];
    if (!d) return { label: f.replace(/_/g, ' '), evidence: '', rule: '' };
    var pct = Math.round(r.coveragePercent || 0);
    var cc = r.complexity != null ? r.complexity : 0;
    var evidence = d.evidence
      .replace('{cc}', String(cc))
      .replace('{pct}', String(pct));
    return { label: d.label, evidence: evidence, rule: d.rule };
  }

  function rowHtml(r) {
    var scoreInt = Math.round(r.score);
    var color = hslForScore(scoreInt);
    var name = displayName(r.name);
    var cut = r.file.lastIndexOf('/');
    var dir = cut >= 0 ? r.file.slice(0, cut + 1) : '';
    var base = cut >= 0 ? r.file.slice(cut + 1) : r.file;
    var changedTxt = fmtAge(r.lastChangedEpochSec);
    var changedIso = r.lastChangedEpochSec
      ? new Date(r.lastChangedEpochSec * 1000).toISOString()
      : 'No git history available';
    var key = rowKey(r);
    var isOpen = !!state.expanded[key];
    var flagPills = r.flags.map(function(f) {
      var info = flagInfo(f, r);
      var ev = info.evidence ? ' <span class="flag-evidence">(' + esc(info.evidence) + ')</span>' : '';
      var title = info.rule ? ' title="' + esc(info.rule) + '"' : '';
      return '<span class="flag-pill ' + esc(f) + '"' + title + '>' + esc(info.label) + ev + '</span>';
    }).join(' ');
    var expLabel = isOpen ? CH.expanderExpanded : CH.expanderCollapsed;
    var expander =
      '<button type="button" class="row-expander' + (isOpen ? ' open' : '') +
      '" data-row-key="' + esc(key) + '" aria-expanded="' + (isOpen ? 'true' : 'false') +
      '" aria-controls="pv-detail-' + esc(key) + '" aria-label="' + esc(expLabel) + '" title="' + esc(expLabel) + '">' +
      '<span class="chev" aria-hidden="true"></span></button>';
    return '<tr data-key="' + esc(key) + '">' +
      '<td class="col-score">' + expander +
      '<span class="score-pill" style="background:' + color + ';color:#000;" title="Score ' + scoreInt + '/100">' + scoreInt + '</span></td>' +
      '<td class="col-name"><span class="fn-link" data-file="' + esc(r.file) + '" data-line="' + r.lineStart + '" title="Open at line ' + r.lineStart + '">' + esc(name) + '</span></td>' +
      '<td class="col-file"><span class="file-link" data-file="' + esc(r.file) + '" data-line="' + r.lineStart + '" title="' + esc(r.file) + '"><span class="path-dir">' + esc(dir) + '</span><span class="path-base">' + esc(base) + '</span></span></td>' +
      '<td class="col-line">' + r.lineStart + '-' + r.lineEnd + '</td>' +
      '<td class="col-usage">' + r.usageCount.toLocaleString('en-US') + '</td>' +
      '<td class="col-coverage">' + Math.round(r.coveragePercent) + '%</td>' +
      '<td class="col-complexity">' + r.complexity + '</td>' +
      '<td class="col-changed" title="' + esc(changedIso) + '">' + esc(changedTxt) + '</td>' +
      '<td class="col-flags"><span class="flag-pills">' + flagPills + '</span></td>' +
      '</tr>';
  }

  // Inline detail row rendered immediately after its parent when expanded.
  // colspan spans the full table width so the panel reads as a single block
  // instead of fragmenting into 9 cells. The "rule" text answers the user's
  // actual question — WHY did this function land on the worst list — rather
  // than restating column values they can already see above.
  function detailRowHtml(r) {
    var key = rowKey(r);
    var scoreInt = Math.round(r.score);
    var heading = CH.detailHeading.replace('{score}', String(scoreInt));
    var items;
    if (!r.flags || r.flags.length === 0) {
      items = '<p class="pv-detail-empty">' + esc(CH.detailNoIssues) + '</p>';
    } else {
      var parts = r.flags.map(function(f) {
        var info = flagInfo(f, r);
        var ev = info.evidence ? '<span class="pv-detail-evidence">' + esc(info.evidence) + '</span>' : '';
        // The suppress button writes a // ignore_for_file: code_health:<flag>
        // directive into the file so the next scan drops this flag for the
        // whole file. Per-function suppression is intentionally NOT offered
        // here — the dashboard's "your file, your call" model is file-scoped.
        var suppressBtn = '<button type="button" class="pv-suppress-btn"' +
          ' data-suppress-file="' + esc(r.file) + '"' +
          ' data-suppress-flag="' + esc(f) + '"' +
          ' title="' + esc(CH.suppressTooltip) + '">' +
          esc(CH.suppressLabel) + '</button>';
        return '<li class="pv-detail-item ' + esc(f) + '">' +
          '<span class="pv-detail-label">' + esc(info.label) + '</span>' + ev +
          (info.rule ? '<span class="pv-detail-rule">' + esc(info.rule) + '</span>' : '') +
          suppressBtn +
          '</li>';
      });
      items = '<ul class="pv-detail-list">' + parts.join('') + '</ul>';
    }
    return '<tr class="pv-detail-row" id="pv-detail-' + esc(key) + '" data-detail-for="' + esc(key) + '">' +
      '<td colspan="9"><div class="pv-detail-panel">' +
      '<h4 class="pv-detail-heading">' + esc(heading) + '</h4>' + items +
      '</div></td></tr>';
  }

  function render() {
    var tbody = document.getElementById('pvBody');
    if (!tbody) return;
    var slice = filtered.slice(0, state.visibleCount);
    // innerHTML is the fast path for a wholesale rebuild — appendChild'ing
    // hundreds of <tr>s individually triggers a layout per insert. Each row is
    // followed by its detail panel iff state.expanded[key] is set, so sort and
    // filter operations preserve open panels (single source of truth).
    var html = [];
    for (var i = 0; i < slice.length; i++) {
      var row = slice[i];
      html.push(rowHtml(row));
      if (state.expanded[rowKey(row)]) html.push(detailRowHtml(row));
    }
    tbody.innerHTML = html.join('');
    var countEl = document.getElementById('pvShownCount');
    if (countEl) {
      var totalStr = allRows.length.toLocaleString('en-US');
      var shownStr = slice.length.toLocaleString('en-US');
      var filtStr = filtered.length.toLocaleString('en-US');
      countEl.textContent = (filtered.length === allRows.length)
        ? 'showing ' + shownStr + ' of ' + totalStr
        : 'showing ' + shownStr + ' of ' + filtStr + ' (filtered from ' + totalStr + ')';
    }
    var loadMore = document.getElementById('pvLoadMore');
    if (loadMore) {
      loadMore.hidden = slice.length >= filtered.length;
      var btn = document.getElementById('pvLoadMoreBtn');
      if (btn) {
        var remaining = filtered.length - slice.length;
        var next = Math.min(RENDER_CHUNK, remaining);
        btn.textContent = 'Show next ' + next.toLocaleString('en-US') +
          ' (' + remaining.toLocaleString('en-US') + ' more)';
      }
    }
    var emptyEl = document.getElementById('pvEmpty');
    if (emptyEl) emptyEl.hidden = !(filtered.length === 0 && allRows.length > 0);
    updateSortArrows();
    updateCopyButton();
  }
  function updateSortArrows() {
    var ths = document.querySelectorAll('th.sortable[data-sort]');
    for (var i = 0; i < ths.length; i++) {
      var th = ths[i];
      var col = th.getAttribute('data-sort');
      th.setAttribute('aria-sort',
        col === state.sortKey ? (state.sortAsc ? 'ascending' : 'descending') : 'none');
    }
  }
  function applyAll() {
    compileFiltered();
    state.visibleCount = RENDER_CHUNK;
    render();
    renderStrip();
    announce(filtered.length + ' of ' + allRows.length + ' rows match');
  }

  // --- Toolbar wiring ----------------------------------------------------
  function postCmd(type) { vscode.postMessage({ type: type }); }
  document.getElementById('rescan').addEventListener('click', function() { postCmd('rescan'); });
  document.getElementById('copyJson').addEventListener('click', function() { postCmd('copyJson'); });
  document.getElementById('openPvSettings').addEventListener('click', function() { postCmd('openProjectVibrancySettings'); });
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
  document.querySelectorAll('[data-cmd]').forEach(function(b) {
    b.addEventListener('click', function() { postCmd(b.getAttribute('data-cmd')); });
  });

  var searchEl = document.getElementById('pvSearch');
  searchEl.addEventListener('input', function() {
    state.search = (searchEl.value || '').trim().toLowerCase();
    applyAll();
  });
  var hideBpEl = document.getElementById('hideBoilerplate');
  if (hideBpEl) {
    hideBpEl.addEventListener('change', function() {
      state.hideBoilerplate = hideBpEl.checked;
      applyAll();
    });
  }
  // KPI tiles are multi-select: click multiple to AND them (e.g. unused AND
  // complex). Click an active tile again to remove it. Previously the cards
  // were mutually-exclusive single-select, which made the obvious "find
  // unused-and-complex" query impossible.
  document.querySelectorAll('.kpi-card.interactive[data-flag-filter]').forEach(function(card) {
    card.addEventListener('click', function() {
      if (card.disabled) return;
      var key = card.getAttribute('data-flag-filter');
      if (state.flags[key]) {
        delete state.flags[key];
        state.flagCount--;
        card.classList.remove('active');
      } else {
        state.flags[key] = true;
        state.flagCount++;
        card.classList.add('active');
      }
      applyAll();
    });
  });

  // Score-threshold input: empty = no cap; a number caps the table to rows
  // whose score is at or below it. Tries to parse so '30', '30.5', '  50 ' all
  // work, but ignores anything not numeric (the placeholder shows '—' as a
  // hint that empty means no limit).
  var scoreMaxEl = document.getElementById('pvScoreMax');
  if (scoreMaxEl) {
    scoreMaxEl.addEventListener('input', function() {
      var raw = (scoreMaxEl.value || '').trim();
      if (raw === '') { state.scoreMax = null; }
      else {
        var n = parseFloat(raw);
        state.scoreMax = (isFinite(n) && n >= 0 && n <= 100) ? n : null;
      }
      applyAll();
    });
  }
  // Column sort: click flips direction on the active column, otherwise sorts
  // the new column ascending (smallest/worst first).
  document.querySelectorAll('th.sortable[data-sort]').forEach(function(th) {
    th.addEventListener('click', function() {
      var col = th.getAttribute('data-sort');
      if (state.sortKey === col) state.sortAsc = !state.sortAsc;
      else { state.sortKey = col; state.sortAsc = true; }
      sortFiltered();
      state.visibleCount = RENDER_CHUNK;
      render();
    });
  });
  var loadMoreBtn = document.getElementById('pvLoadMoreBtn');
  if (loadMoreBtn) {
    loadMoreBtn.addEventListener('click', function() {
      state.visibleCount = Math.min(state.visibleCount + RENDER_CHUNK, filtered.length);
      render();
    });
  }
  var resetEmptyBtn = document.getElementById('pvResetFilters');
  if (resetEmptyBtn) resetEmptyBtn.addEventListener('click', resetFilters);
  function resetFilters() {
    state.search = '';
    state.flags = Object.create(null);
    state.flagCount = 0;
    state.scoreMax = null;
    searchEl.value = '';
    if (scoreMaxEl) scoreMaxEl.value = '';
    document.querySelectorAll('.kpi-card.active').forEach(function(c) { c.classList.remove('active'); });
    applyAll();
  }

  // --- Filter-driven bulk copy ------------------------------------------
  // No selection checkboxes — the filters ARE the selection. *Copy filtered*
  // dumps every currently-visible row. The button label shows the live count
  // so the user knows how many rows they're about to copy before clicking.
  function updateCopyButton() {
    var btn = document.getElementById('copyFiltered');
    if (!btn) return;
    if (filtered.length === 0) {
      btn.textContent = 'Copy filtered';
      btn.setAttribute('disabled', '');
    } else {
      btn.textContent = 'Copy filtered (' + filtered.length.toLocaleString('en-US') + ')';
      btn.removeAttribute('disabled');
    }
  }

  var tbody = document.getElementById('pvBody');
  if (tbody) {
    // Delegated click handler: row-expander toggles the detail panel,
    // fn-link / file-link open the file at its line. Expander wins when its
    // ancestor chain matches because the button sits INSIDE the score cell
    // alongside the score pill — without the early-return the click would
    // fall through to no-op (score pill has no data-file).
    tbody.addEventListener('click', function(e) {
      var target = e.target;
      // Climb to a known affordance: row-expander, suppress button, or link.
      // The suppress button MUST be matched before bubbling to fn-link / file-
      // link checks because it can sit inside the detail panel below a row.
      var node = target;
      while (node && node !== tbody) {
        if (node.classList) {
          if (node.classList.contains('pv-suppress-btn')) {
            e.preventDefault();
            e.stopPropagation();
            var sFile = node.getAttribute('data-suppress-file');
            var sFlag = node.getAttribute('data-suppress-flag');
            if (!sFile || !sFlag) return;
            vscode.postMessage({ type: 'suppressFlag', file: sFile, flag: sFlag });
            return;
          }
          if (node.classList.contains('row-expander')) {
            e.preventDefault();
            var key = node.getAttribute('data-row-key');
            if (!key) return;
            if (state.expanded[key]) delete state.expanded[key];
            else state.expanded[key] = true;
            render();
            return;
          }
          if (node.classList.contains('fn-link') || node.classList.contains('file-link')) {
            var file = node.getAttribute('data-file');
            var line = Number(node.getAttribute('data-line') || '1');
            if (!file) return;
            vscode.postMessage({ type: 'openFile', file: file, line: line });
            return;
          }
        }
        node = node.parentNode;
      }
    });
  }

  // Bulk-copy format for LLM/chat paste: one line per row, file:line first
  // (clickable in most tools), then function name, then score + flags in
  // parentheses. Copies EVERY filtered row — filter narrows, button dumps.
  document.getElementById('copyFiltered').addEventListener('click', function() {
    if (filtered.length === 0) return;
    var lines = [];
    for (var i = 0; i < filtered.length; i++) {
      var r = filtered[i];
      var meta = ['score ' + Math.round(r.score)];
      if (r.flags && r.flags.length) meta.push(r.flags.join(', '));
      lines.push(r.file + ':' + r.lineStart + '  ' + displayName(r.name) +
        '  (' + meta.join(', ') + ')');
    }
    vscode.postMessage({ type: 'copyText', text: lines.join('\\n') });
  });

  // --- Active-filter strip ---------------------------------------------
  var stripEl = document.getElementById('filter-strip');
  function renderStrip() {
    if (!stripEl) return;
    // chip.key is the dismiss target: 'search', 'score', or 'flag:<name>' so
    // the X removes that specific filter only.
    var chips = [];
    if (state.search) chips.push({ key: 'search', label: 'search: "' + esc(state.search) + '"' });
    if (state.scoreMax !== null) chips.push({ key: 'score', label: 'score ≤ ' + state.scoreMax });
    for (var f in state.flags) {
      chips.push({ key: 'flag:' + f, label: 'flag: ' + f.replace(/_/g, ' ') });
    }
    if (chips.length === 0) { stripEl.hidden = true; stripEl.innerHTML = ''; return; }
    stripEl.hidden = false;
    var parts = ['<span class="lbl">' + esc(CH.activeFiltersLabel) + '</span>'];
    chips.forEach(function(chip) {
      parts.push('<span class="chip">' + chip.label +
        '<button type="button" class="x" data-chip="' + esc(chip.key) +
        '" aria-label="Remove filter">×</button></span>');
    });
    parts.push('<button type="button" class="clear-all" id="clear-all-filters">' + esc(CH.clearAll) + '</button>');
    stripEl.innerHTML = parts.join('');
    stripEl.querySelectorAll('.chip .x').forEach(function(btn) {
      btn.addEventListener('click', function() {
        var k = btn.getAttribute('data-chip') || '';
        if (k === 'search') { state.search = ''; searchEl.value = ''; }
        else if (k === 'score') { state.scoreMax = null; if (scoreMaxEl) scoreMaxEl.value = ''; }
        else if (k.indexOf('flag:') === 0) {
          var name = k.slice(5);
          if (state.flags[name]) { delete state.flags[name]; state.flagCount--; }
          var card = document.querySelector('.kpi-card.active[data-flag-filter="' + name + '"]');
          if (card) card.classList.remove('active');
        }
        applyAll();
      });
    });
    document.getElementById('clear-all-filters').addEventListener('click', resetFilters);
  }

  function announce(message) {
    var el = document.getElementById('announcer');
    if (!el) return;
    el.textContent = '';
    setTimeout(function() { el.textContent = message; }, 50);
  }

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
      applyAll();
    }
  });

  compileFiltered();
  render();
  updateCopyButton();
  ${getKeyboardShortcutsScript()}
})();
`;
}
