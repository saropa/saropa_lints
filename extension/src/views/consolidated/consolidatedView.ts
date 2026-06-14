/**
 * Consolidated dashboard — panel controller (extension-host side).
 *
 * Async-first architecture: the webview HTML shell is set EXACTLY ONCE on
 * creation; refreshes never reassign `.html`. On every (debounced) diagnostic
 * change the host rebuilds the cheap rule-grouped model (zero analysis — it
 * reads already-computed diagnostics) and posts it; the webview patches its DOM
 * in place. Occurrences are streamed per-rule on demand (lazy), so the initial
 * payload is ~60 group headers, never thousands of rows.
 */

import * as path from 'path';
import * as vscode from 'vscode';
import { getProjectRoot } from '../../projectRoot';
import { createWebviewCspNonce } from '../../vibrancy/views/html-utils';
import { gradeColor, type LetterGrade } from '../../healthGrade';
import { l10n } from '../../i18n/runtime';
import { buildConsolidatedModel, type ConsolidatedModel } from './consolidatedModel';
import { getConsolidatedStyles } from './consolidatedStyles';
import { getConsolidatedClient } from './consolidatedClient';
import { buildSuiteEvidence, type RuleEvidence } from '../../suite/siblingEnvelopes';

const VIEW_TYPE = 'saropaConsolidatedDashboard';
// Coalesce the burst of per-file diagnostic events VS Code emits during a run
// into one model push. Shorter than the legacy dashboard's 500ms because this
// path only re-groups + posts JSON (no HTML rebuild), so it can be snappier.
const REFRESH_DEBOUNCE_MS = 400;
// Cap occurrences sent per rule so one 2000-hit rule cannot jank the webview.
// The remainder is summarized as a "+N more" note; the editor is the place to
// work through a rule that large.
const MAX_OCC = 200;

const GRADE_LABEL_KEY: Record<LetterGrade, string> = {
  A: 'consolidated.gradeExcellent',
  B: 'consolidated.gradeGood',
  C: 'consolidated.gradeFair',
  D: 'consolidated.gradeWeak',
  E: 'consolidated.gradeSevere',
};

let panel: vscode.WebviewPanel | undefined;
let listener: vscode.Disposable | undefined;
let refreshTimer: NodeJS.Timeout | undefined;
let lastModel: ConsolidatedModel | undefined;
// Runtime evidence from the sibling suite mirrors (R2), rebuilt each push and
// keyed by rule so the model message can badge a row. Empty when no sibling has
// written a mirror referencing a Lints rule.
let lastEvidence: Map<string, RuleEvidence> = new Map();

/** Open (or focus) the consolidated dashboard. */
export function openConsolidatedDashboard(context: vscode.ExtensionContext): void {
  if (panel) {
    panel.reveal(vscode.ViewColumn.Active);
    return;
  }
  const root = getProjectRoot();
  if (!root) {
    void vscode.window.showErrorMessage(l10n('wideReport.openWorkspaceFirst'));
    return;
  }

  panel = vscode.window.createWebviewPanel(VIEW_TYPE, 'Saropa Lints', vscode.ViewColumn.Active, {
    enableScripts: true,
    retainContextWhenHidden: true,
  });
  // Shell once — never reassigned. All subsequent updates are postMessage.
  panel.webview.html = buildShell();
  panel.onDidDispose(disposePanel);
  panel.webview.onDidReceiveMessage((msg: unknown) => handleMessage(msg));

  listener = vscode.languages.onDidChangeDiagnostics(() => {
    if (!panel?.visible) return;
    if (refreshTimer) clearTimeout(refreshTimer);
    refreshTimer = setTimeout(() => {
      refreshTimer = undefined;
      pushModel();
    }, REFRESH_DEBOUNCE_MS);
  });
  context.subscriptions.push({ dispose: disposePanel });
}

function disposePanel(): void {
  listener?.dispose();
  listener = undefined;
  if (refreshTimer) {
    clearTimeout(refreshTimer);
    refreshTimer = undefined;
  }
  panel = undefined;
  lastModel = undefined;
}

function handleMessage(msg: unknown): void {
  const m = msg as { type?: string; rule?: string; file?: string; line?: number };
  if (m.type === 'ready') {
    pushModel();
  } else if (m.type === 'expand' && typeof m.rule === 'string') {
    pushOccurrences(m.rule);
  } else if (m.type === 'open' && typeof m.file === 'string') {
    openSource(m.file, m.line ?? 1);
  }
}

function pushModel(): void {
  const root = getProjectRoot();
  if (!root || !panel) return;
  // The model build is pure and low-risk, but pushModel runs inside a debounced
  // timer (and the diagnostics listener) with no caller to catch a throw — an
  // unhandled error there would silently kill the refresh loop. Guard it so one
  // bad build is logged and skipped, leaving the last good model on screen.
  try {
    lastModel = buildConsolidatedModel(root);
    // R2: read the sibling mirrors so a Drift rule row can carry "Advisor
    // confirms at runtime" / "Log Capture saw N". Reads two small JSON files;
    // absent or malformed mirrors yield an empty map (no badges), never a throw.
    lastEvidence = buildSuiteEvidence(root);
    void panel.webview.postMessage(toModelMessage(lastModel, lastEvidence));
  } catch (err) {
    console.error('[saropaLints] consolidated dashboard model build failed', err);
  }
}

function pushOccurrences(rule: string): void {
  if (!panel) return;
  const group = lastModel?.groups.find((g) => g.rule === rule);
  if (!group) {
    void panel.webview.postMessage({ type: 'occurrences', rule, items: [], more: '' });
    return;
  }
  const items = group.occurrences.slice(0, MAX_OCC);
  const extra = group.occurrences.length - items.length;
  void panel.webview.postMessage({
    type: 'occurrences',
    rule,
    items,
    more: extra > 0 ? l10n('consolidated.more', { count: String(extra) }) : '',
  });
}

function openSource(file: string, line: number): void {
  const root = getProjectRoot();
  if (!root) return;
  // file is root-relative + forward-slashed (matches the live model); resolve
  // back to an absolute path. VS Code surfaces its own error if it cannot open.
  const abs = path.resolve(root, file);
  const pos = new vscode.Position(Math.max(0, line - 1), 0);
  void vscode.window.showTextDocument(vscode.Uri.file(abs), {
    selection: new vscode.Range(pos, pos),
    preview: true,
  });
}

/**
 * Build the already-localized runtime-evidence badges for one rule (R2). The
 * webview renders strings, not raw counts, so localization stays host-side: the
 * Advisor badge is presence-only ("confirms at runtime"); the Log Capture badge
 * carries the occurrence count. Empty array for a rule with no sibling evidence.
 */
function evidenceBadges(rule: string, evidence: Map<string, RuleEvidence>): string[] {
  const row = evidence.get(rule);
  if (!row) return [];
  const badges: string[] = [];
  if (row.advisorCount > 0) {
    badges.push(l10n('consolidated.evidence.advisor'));
  }
  if (row.logCaptureCount > 0) {
    badges.push(l10n('consolidated.evidence.logCapture', { count: String(row.logCaptureCount) }));
  }
  return badges;
}

/** Map the model to the (already-localized) message the webview renders. */
function toModelMessage(model: ConsolidatedModel, evidence: Map<string, RuleEvidence>): unknown {
  return {
    type: 'model',
    score: model.score,
    grade: model.grade,
    color: gradeColor(model.score),
    label: l10n(GRADE_LABEL_KEY[model.grade]),
    summaryLine:
      l10n('consolidated.summaryFindings', { count: String(model.totals.total) }) +
      ' · ' +
      l10n('consolidated.summaryRules', { count: String(model.groups.length) }),
    chips: [
      { kind: 'error', n: model.totals.error, label: l10n('consolidated.wordErrors') },
      { kind: 'warning', n: model.totals.warning, label: l10n('consolidated.wordWarnings') },
      { kind: 'info', n: model.totals.info, label: l10n('consolidated.wordInfo') },
      { kind: '', n: model.totals.files, label: l10n('consolidated.wordFiles') },
    ],
    groups: model.groups.map((g) => ({
      rule: g.rule,
      count: g.count,
      worst: g.worst,
      badges: evidenceBadges(g.rule, evidence),
    })),
  };
}

function escapeHtml(s: string): string {
  return s
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;');
}

/** The static shell — set once. Skeleton + styles + localized client bundle. */
function buildShell(): string {
  const nonce = createWebviewCspNonce();
  const csp = `default-src 'none'; style-src 'nonce-${nonce}'; script-src 'nonce-${nonce}';`;
  // Two client-only literals the host can't pre-format (shown before any
  // message arrives / when a group is empty). Everything else is localized in
  // the messages or the skeleton below.
  const sl = JSON.stringify({
    fetching: l10n('consolidated.fetching'),
    noOccurrences: l10n('consolidated.noOccurrences'),
  });
  return `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <meta http-equiv="Content-Security-Policy" content="${csp}">
  <style nonce="${nonce}">${getConsolidatedStyles()}</style>
</head>
<body>
  <div class="app">
    <header class="hero">
      <div class="gauge" id="gauge">
        <div class="gauge-inner">
          <span class="gauge-grade" id="gaugeGrade">–</span>
          <span class="gauge-score" id="gaugeScore"></span>
        </div>
      </div>
      <div class="hero-meta">
        <div class="hero-kicker">${escapeHtml(l10n('consolidated.kicker'))}</div>
        <h1 class="hero-title">Saropa Lints<span class="live" title="${escapeHtml(l10n('consolidated.liveTitle'))}"></span></h1>
        <div class="grade-label" id="gradeLabel"></div>
        <div class="chips" id="chips"></div>
      </div>
    </header>
    <div class="toolbar">
      <input class="search" id="search" type="text" placeholder="${escapeHtml(l10n('consolidated.searchPlaceholder'))}" aria-label="${escapeHtml(l10n('consolidated.searchPlaceholder'))}">
      <span class="count-note" id="summary"></span>
    </div>
    <div class="groups" id="groups"></div>
    <div class="empty hidden" id="empty">${escapeHtml(l10n('consolidated.empty'))}</div>
  </div>
  <script nonce="${nonce}">window.SL = ${sl};</script>
  <script nonce="${nonce}">${getConsolidatedClient()}</script>
</body>
</html>`;
}
