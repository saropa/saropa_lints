/**
 * HTML for the editor-area Saropa Violations Dashboard (grouped, filterable).
 *
 * Implements the gold-standard editor dashboard hierarchy from
 * `plan/guides/UX_UI_GUIDELINES.md`:
 *   §4.1 Hero with status line + version stamp.
 *   §4.2 KPI cards as preset filters with hero-sized numbers.
 *   §4.3 Toolbar band with density tiers (one primary, ≤4 secondary,
 *        rest behind "More actions ▾").
 *   §6   Bars + donut chart side by side.
 *   §7   Sortable, sticky-header findings table.
 *   §8.5 Active-filters chip strip.
 *   §14.7 Density-first content ordering — actionable data above empties.
 */

import { l10n } from '../i18n/runtime';
import { createWebviewCspNonce } from '../vibrancy/views/html-utils';
import { buildAnnouncer, buildSkipLink } from './dashboardHero';
import { buildKeyboardShortcutsOverlay, getKeyboardShortcutsStyles } from './keyboard-shortcuts';
import { buildChartsBlock, buildDriftBlock, buildSuppressionsBlock, buildTodoHackBlock } from './violations-dashboard-panels';
import { buildScript } from './violations-dashboard-script';
import { escapeHtml, type ViolationsDashboardHtmlInput } from './violations-dashboard-shared';
import { buildFindingsBlock, buildTopRulesTable } from './violations-dashboard-tables';
import { buildAnalysisProgress, buildHero, buildKpiCards, buildToolbar } from './violations-dashboard-top';
import { getFindingsEmptyStateStyles, getViolationsDashboardStyles } from './violationsDashboardStyles';
// Re-exported so violationsWideReportView and tests keep importing these types
// from the dashboard composer rather than the internal shared module.
export type { AnalyzerSuppressionsSlice, ViewSuppressionsSlice } from './violations-dashboard-shared';



/* ============================================================================
 * Composer — density-first DOM order (§14.7).
 * ========================================================================= */

export function renderViolationsDashboardHtml(input: ViolationsDashboardHtmlInput): string {
  const nonce = createWebviewCspNonce();
  return `<!DOCTYPE html>
<html lang="en"><head>
  <meta charset="UTF-8" />
  <title>${escapeHtml(l10n('findingsDash.documentTitle'))}</title>
  <!-- 'unsafe-inline' on style-src: the severity-mix chart bars set their width
       via an inline style="--bar-width:N%" attribute. CSP nonces authorize
       <style> blocks, not style attributes — without 'unsafe-inline' the var is
       dropped and every bar renders at zero width. (The hero gauge no longer
       needs this: its fill is now a static SVG stroke-dasharray attribute.) -->
  <meta http-equiv="Content-Security-Policy" content="default-src 'none'; style-src 'nonce-${nonce}' 'unsafe-inline'; script-src 'nonce-${nonce}';" />
  <style nonce="${nonce}">${getViolationsDashboardStyles()}${getKeyboardShortcutsStyles()}</style>
</head><body>
  ${buildSkipLink('findings-table', l10n('findingsDash.skipToFindings'))}
  ${buildAnnouncer()}
  <header>${buildHero(input)}</header>
  ${buildKpiCards(input)}
  ${buildToolbar(input)}
  ${buildAnalysisProgress()}
  <main id="findings-table" tabindex="-1">
    ${buildTopRulesTable(input)}
    ${buildFindingsBlock(input)}
  </main>
  <aside aria-label="${escapeHtml(l10n('findingsDash.secondaryAsideLabel'))}">
    ${buildTodoHackBlock(input)}
    ${buildDriftBlock(input.driftAdvisorSnapshot)}
    ${buildChartsBlock(input)}
    ${buildSuppressionsBlock(input)}
  </aside>
  ${buildKeyboardShortcutsOverlay([
    { key: '/', label: l10n('findingsDash.shortcuts.focusTextFilter') },
    { key: 'Esc', label: l10n('findingsDash.shortcuts.clearTextFilter') },
    { key: 'Enter', label: l10n('findingsDash.shortcuts.activateKpi') },
    { key: 'Space', label: l10n('findingsDash.shortcuts.activateKpiSpace') },
    { key: '?', label: l10n('findingsDash.shortcuts.showOverlay') },
  ])}
  <script nonce="${nonce}">${buildScript()}</script>
</body></html>`;
}


/** Editor-area empty state when no `violations.json` exists yet (nonce CSP + primary actions). */
export function buildFindingsEmptyStateHtml(message: string): string {
  const nonce = createWebviewCspNonce();
  const esc = escapeHtml(message);
  return `<!DOCTYPE html>
<html lang="en"><head>
  <meta charset="UTF-8"/>
  <!-- 'unsafe-inline' on style-src: kept consistent with the populated dashboard CSP
       so future inline-style additions (e.g. gauges, sparklines) work without a CSP
       regression that re-creates the gauge-renders-as-a-dot bug. -->
  <meta http-equiv="Content-Security-Policy" content="default-src 'none'; style-src 'nonce-${nonce}' 'unsafe-inline'; script-src 'nonce-${nonce}';"/>
  <style nonce="${nonce}">${getFindingsEmptyStateStyles()}</style>
</head><body>
  <div class="empty-hero">
    <h1>${escapeHtml(l10n('findingsDash.pageTitle'))}</h1>
    <p>${esc}</p>
    <p>${escapeHtml(l10n('findingsDash.emptyState.hintAfterMessage'))}</p>
    <div class="btns">
      <button type="button" class="primary" id="btn-run" data-run-analysis>${escapeHtml(l10n('toolbar.runAnalysis'))}</button>
      <button type="button" id="btn-refresh">${escapeHtml(l10n('findingsDash.emptyState.refreshDisk'))}</button>
    </div>
    ${buildAnalysisProgress()}
  </div>
  <script nonce="${nonce}">
    (function () {
      var vscode = acquireVsCodeApi();
      var running = false;
      function setRunning(on) {
        running = on;
        var box = document.getElementById('analysis-progress');
        if (box) box.hidden = !on;
        var btn = document.getElementById('btn-run');
        if (btn) btn.disabled = on;
      }
      document.getElementById('btn-run').addEventListener('click', function () {
        if (running) return;
        setRunning(true);
        vscode.postMessage({ type: 'runAnalysis' });
      });
      document.getElementById('btn-refresh').addEventListener('click', function () {
        vscode.postMessage({ type: 'refresh' });
      });
      window.addEventListener('message', function (event) {
        var msg = event && event.data ? event.data : null;
        if (!msg || msg.type !== 'analysisProgress') return;
        if (msg.status === 'started') {
          setRunning(true);
          return;
        }
        if (msg.status === 'completed' || msg.status === 'failed') {
          setRunning(false);
        }
      });
    })();
  </script>
</body></html>`;
}

