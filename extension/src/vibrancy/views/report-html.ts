/**
 * Module overview (comment coverage pass).
 * comment-coverage: module overview (batch).
 *
 * Vibrancy UI experiment: scoring, providers, and webview assets.
 *
 * Composer for the package-vibrancy report webview. Assembles the document
 * shell (CSP, styles, scripts) and stitches together the top-chrome
 * (report-html-top), package table (report-html-table), and data payloads
 * (report-html-data). Section builders live in those sibling modules; this
 * file owns only the page skeleton and the public export surface.
 */

import { countByCategory, scoreToGrade } from '../scoring/status-classifier';
import { getReportStyles } from './report-styles';
import { getPackageDetailStylesScoped } from './package-detail-styles';
import { getPillButtonStyles } from './pill-button-styles';
import { getReportScript } from './report-script';
import { createWebviewCspNonce, escapeHtml } from './html-utils';
import { buildChartSection } from './chart-html';
import { getChartStyles } from './chart-styles';
import { getChartScript } from './chart-script';
import { buildFullWidthToggle, buildStatusLine, getFullWidthToggleScript } from '../../views/dashboardHero';
import {
    buildKeyboardShortcutsButton,
    buildKeyboardShortcutsOverlay,
    getKeyboardShortcutsScript,
    getKeyboardShortcutsStyles,
} from '../../views/keyboard-shortcuts';
import { l10n } from '../../i18n/runtime';
import { ReportOptions } from './report-html-shared';
import {
    buildLastScanPill,
    buildScanInProgressHtml,
    buildRadialGauge,
    buildGradeBreakdown,
    buildReportSummary,
    buildFiltersSection,
} from './report-html-top';
import { buildPackagesSection } from './report-html-table';
import {
    buildNetworkSection,
    buildRepoShareMap,
    buildPackageDataScript,
} from './report-html-data';

// Re-export the public surface so existing importers (report-webview.ts,
// package-detail-html.ts, the report tests) keep referencing report-html.ts
// unchanged after the section split.
export { ReportOptions };
export {
    buildSparklineSvg,
    computePublishedAgeMonths,
    buildDetailScoreSection,
} from './report-html-table';

/** Build the full HTML for the vibrancy report webview. */
export function buildReportHtml(options: ReportOptions): string {
    const { results } = options;
    // No results yet AND a scan is currently running — render an explicit
    // "scan in progress" placeholder instead of the normal dashboard.  The
    // normal dashboard with zero results looks broken (Grade E gauge at 0,
    // empty status line, empty table) and was being mistaken for a
    // failed/dead scan.  The placeholder makes the actual state visible
    // and auto-refresh in `publishResults` swaps it for the real dashboard
    // as soon as the scan finishes.
    if (options.isScanning && results.length === 0) {
        return buildScanInProgressHtml(options);
    }
    const cspNonce = createWebviewCspNonce();
    /* Average score for the radial gauge (0-100 raw scale). */
    const avg = results.length > 0
        ? Math.round(results.reduce((s, r) => s + r.score, 0) / results.length)
        : 0;
    // Status line carries the highest-signal facts the dashboard knows: total packages,
    // direct vs transitive breakdown, vibrant count, and any flagged categories. The user
    // gets a single muted sentence instead of having to scan the full table to gauge health.
    const directCount = results.filter(r => r.package.isDirect).length;
    const totalCount = results.length;
    const transitives = totalCount - directCount;
    const byCat = countByCategory(results);
    const eolCount = byCat.eol + byCat.abandoned;
    const overallGrade = scoreToGrade(avg);
    const statusLineHtml = buildStatusLine([
        {
            glyph: '📦',
            label: l10n('packageDashboard.status.packagesCount', { count: String(totalCount) }),
            title: l10n('packageDashboard.status.packagesBreakdown', {
                direct: String(directCount),
                transitive: String(transitives),
            }),
        },
        {
            label: l10n('packageDashboard.status.gradeLine', { grade: overallGrade, avg: String(avg) }),
            tone: avg >= 75 ? 'good' : avg >= 50 ? 'warn' : 'bad',
        },
        ...(eolCount > 0
            ? [{
                label: l10n('packageDashboard.status.flaggedCount', { count: String(eolCount) }),
                tone: 'bad' as const,
                title: l10n('packageDashboard.status.flaggedTitle'),
            }]
            : []),
        buildLastScanPill(options.lastScanTimestamp),
    ]);
    return `<!DOCTYPE html>
<html lang="en">
<head>
    <title>${escapeHtml(l10n('packageDashboard.documentTitle'))}</title>
    <meta charset="UTF-8">
    <!-- Strict CSP: nonce-only style/script, no 'unsafe-inline'. CSP3 ignores
         'unsafe-inline' when a nonce is present anyway, which previously caused
         the radial gauge's inline style="--gauge-target:..." attribute to be
         stripped, collapsing stroke-dasharray to "0 999" so only the rounded
         linecap (a single dot) was painted. The gauge now writes its
         stroke-dasharray as a direct SVG presentation attribute and animates
         via SMIL <animate>, so no inline style attributes are needed. -->
    <meta http-equiv="Content-Security-Policy"
        content="default-src 'none'; style-src 'nonce-${cspNonce}'; script-src 'nonce-${cspNonce}';">
    <style nonce="${cspNonce}">${getPillButtonStyles()}${getReportStyles()}${getChartStyles()}${getKeyboardShortcutsStyles()}${getPackageDetailStylesScoped()}</style>
</head>
<body>
    <header class="report-header">
        <div class="hero-text">
          <h1>${escapeHtml(l10n('packageDashboard.heroTitle'))} <span class="header-version">v${escapeHtml(options.extensionVersion)}</span></h1>
          ${statusLineHtml.replace('</p>', `${buildKeyboardShortcutsButton()}${buildFullWidthToggle()}</p>`)}
        </div>
        ${buildRadialGauge(avg)}
    </header>
    ${/* Live scan-progress bar. Hidden until the host posts `scanStarted`; the
        client fills it from `scanProgress` (percent + phase message) and hides
        it on `scanFinished`. Without this the dashboard sat on stale data with
        only a VS Code toast during a rescan, which read as "the page hung". */ ''}
    <div id="scan-progress" class="scan-progress" hidden role="progressbar"
         aria-label="${escapeHtml(l10n('packageDashboard.progress.aria'))}"
         data-starting="${escapeHtml(l10n('packageDashboard.progress.starting'))}"
         aria-valuemin="0" aria-valuemax="100" aria-valuenow="0">
        <div class="scan-progress-track"><div id="scan-progress-fill" class="scan-progress-fill"></div></div>
        <div class="scan-progress-meta">
            <span id="scan-progress-label" class="scan-progress-label"></span>
            <span id="scan-progress-pct" class="scan-progress-pct"></span>
        </div>
    </div>
    <main>
    ${buildGradeBreakdown(results, avg)}
    ${buildReportSummary(options)}
    ${buildChartSection(results)}
    ${buildFiltersSection(options)}
    <div class="dash-split">
    ${buildPackagesSection(results, options)}
    ${/* Docked master-detail pane (§7). Hidden until a row is selected so the
        default view stays the full-width table; the host renders one package's
        rich detail on demand and the client injects it here, replacing the
        former standalone PackageDetailPanel tab. */ ''}
    <aside id="detail-pane" class="detail-pane pkg-detail" aria-label="${escapeHtml(l10n('packageDashboard.detailPane.aria'))}" tabindex="-1" hidden>
        <div class="detail-pane-head">
            <span class="detail-pane-kicker">${escapeHtml(l10n('packageDashboard.detailPane.title'))}</span>
            <button type="button" class="detail-pane-close" id="detailPaneClose" title="${escapeHtml(l10n('packageDashboard.detailPane.close'))}" aria-label="${escapeHtml(l10n('packageDashboard.detailPane.close'))}">×</button>
        </div>
        <div id="detail-pane-body"></div>
    </aside>
    </div>
    ${/* Network panel lives at the bottom: it's a wide, scrollable diagram
       * that pushes the high-density table further down when placed above,
       * so users had to scroll past it just to reach the package list.
       * Anchoring it after the table keeps the primary view (status, chart,
       * table) immediately visible and treats the network as a drill-down. */ ''}
    ${buildNetworkSection(results)}
    </main>
    ${buildKeyboardShortcutsOverlay([
        { key: '/', label: l10n('packageDashboard.shortcuts.focusSearch') },
        { key: '↓ / j', label: l10n('packageDashboard.shortcuts.nextRow') },
        { key: '↑ / k', label: l10n('packageDashboard.shortcuts.prevRow') },
        { key: 'Enter / Space', label: l10n('packageDashboard.shortcuts.toggleDetail') },
        { key: 'Esc', label: l10n('packageDashboard.shortcuts.escapeSearch') },
        { key: 'Alt + ←', label: l10n('packageDashboard.shortcuts.historyBack') },
        { key: '?', label: l10n('packageDashboard.shortcuts.showOverlay') },
    ])}
    <script nonce="${cspNonce}">${buildPackageDataScript(results, options.overrideNames, buildRepoShareMap(results))}${getReportScript()}${getChartScript()}(function(){${getFullWidthToggleScript()}${getKeyboardShortcutsScript()}})();</script>
</body>
</html>`;
}
