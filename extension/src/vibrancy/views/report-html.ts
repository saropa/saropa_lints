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
// Phase 5 style migration (see plans/PLAN_extension_ui_redesign.md, Phase 5):
// pull in the canonical :root token layer alongside the legacy report-styles
// system. This is the main Package Dashboard shell -- its markup vocabulary
// (report-header, dash-split, scan-progress, ...) is almost entirely disjoint
// from dashboardChromeStyles' component classes, so a full swap to
// getDashboardChromeStyles() would break rendering until the markup itself is
// rewritten. Adding only the token subset is additive (new custom properties,
// no rule overrides) so it carries zero visual-regression risk while moving
// this consumer one step closer to the single design-system goal.
import { getDashboardTokens } from '../../views/dashboardChromeStyles';
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
// Phase 5 tab shell: tab bar + deep-link panels (Upgrades/Full report/Known
// issues/Compare) and the in-document Settings tab. See packages-tabs.ts for
// why the deep-link tabs open the existing standalone panels rather than
// re-rendering their markup inline.
import { buildTabBar, buildDeepLinkPanels, getPackagesTabsStyles, getPackagesTabsScript } from './packages-tabs';
import { buildSettingsTab, getSettingsTabStyles, getSettingsTabScript, VibrancySettingGroup } from './settings-tab';

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
    <style nonce="${cspNonce}">${getDashboardTokens()}${getPillButtonStyles()}${getReportStyles()}${getChartStyles()}${getKeyboardShortcutsStyles()}${getPackageDetailStylesScoped()}${getPackagesTabsStyles()}${getSettingsTabStyles()}</style>
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
    ${/* Phase 5 tab shell: Overview (this existing dashboard content, now
        wrapped as the 'overview' tab panel), Upgrades / Full report / Known
        issues / Compare (deep-link panels that open the existing standalone
        webviews), and Settings (in-document form over every
        packageVibrancy.* setting). See packages-tabs.ts for why the
        deep-link tabs don't re-render their target's markup inline. */ ''}
    ${buildTabBar()}
    <main id="pkg-tab-overview" class="pkg-tab-panel" role="tabpanel" aria-labelledby="pkg-tab-btn-overview">
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
            <div class="detail-pane-actions">
                <button type="button" class="detail-pane-copy" id="detailPaneCopyAi" title="${escapeHtml(l10n('packageDashboard.detailPane.copyForAi'))}" aria-label="${escapeHtml(l10n('packageDashboard.detailPane.copyForAi'))}" hidden>&#129302;</button>
                <button type="button" class="detail-pane-copy" id="detailPaneCopy" title="${escapeHtml(l10n('packageDashboard.row.copyRowJson'))}" aria-label="${escapeHtml(l10n('packageDashboard.row.copyRowJson'))}">&#128203;</button>
                <button type="button" class="detail-pane-close" id="detailPaneClose" title="${escapeHtml(l10n('packageDashboard.detailPane.close'))}" aria-label="${escapeHtml(l10n('packageDashboard.detailPane.close'))}">×</button>
            </div>
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
    ${buildDeepLinkPanels()}
    ${buildSettingsTab(options.vibrancySettingGroups ?? [])}
    ${buildKeyboardShortcutsOverlay([
        { key: '/', label: l10n('packageDashboard.shortcuts.focusSearch') },
        { key: '↓ / j', label: l10n('packageDashboard.shortcuts.nextRow') },
        { key: '↑ / k', label: l10n('packageDashboard.shortcuts.prevRow') },
        { key: 'Enter / Space', label: l10n('packageDashboard.shortcuts.toggleDetail') },
        { key: 'Esc', label: l10n('packageDashboard.shortcuts.escapeSearch') },
        { key: 'Alt + ←', label: l10n('packageDashboard.shortcuts.historyBack') },
        // Phase 7: the tab bar's digit shortcut (packages-tabs.ts's SCRIPT keydown handler) had no
        // discoverable entry in this overlay before this pass -- a user pressing '?' would never
        // learn the tabs were even keyboard-reachable.
        { key: '1-6', label: l10n('packageDashboard.shortcuts.jumpToTab') },
        { key: '?', label: l10n('packageDashboard.shortcuts.showOverlay') },
    ])}
    <script nonce="${cspNonce}">${buildPackageDataScript(results, options.overrideNames, buildRepoShareMap(results))}${getReportScript()}${getChartScript()}(function(){${getFullWidthToggleScript()}${getKeyboardShortcutsScript()}})();${getPackagesTabsScript()}${getSettingsTabScript()}</script>
</body>
</html>`;
}
