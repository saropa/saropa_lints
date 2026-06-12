/**
 * Module overview (comment coverage pass).
 * comment-coverage: module overview (batch).
 *
 * Vibrancy UI experiment: scoring, providers, and webview assets.
 */

import { VibrancyResult, activeFileUsages, hasActiveReExport } from '../types';
import {
    categoryLabel, categoryToGrade, countByCategory, scoreToGrade,
} from '../scoring/status-classifier';
import { formatSizeMB, formatSizeKB } from '../scoring/bloat-calculator';
import { worstSeverity, severityEmoji, severityLabel } from '../scoring/vuln-classifier';
import { getReportStyles } from './report-styles';
import { getPillButtonStyles } from './pill-button-styles';
import { getReportScript } from './report-script';
import { createWebviewCspNonce, escapeHtml } from './html-utils';
import { buildChartSection } from './chart-html';
import { getChartStyles } from './chart-styles';
import { getChartScript } from './chart-script';
import { buildFullWidthToggle, buildStatusLine, getFullWidthToggleScript, StatusPill } from '../../views/dashboardHero';
import {
    buildKeyboardShortcutsButton,
    buildKeyboardShortcutsOverlay,
    getKeyboardShortcutsScript,
    getKeyboardShortcutsStyles,
} from '../../views/keyboard-shortcuts';
import { l10n } from '../../i18n/runtime';

/** Column header label / tooltip from `packageDashboard.columns.*`. */
function col(cid: string, part: 'label' | 'tooltip'): string {
    return l10n(`packageDashboard.columns.${cid}.${part}`);
}

/** Options passed to the report builder beyond just results. */
export interface ReportOptions {
    readonly results: VibrancyResult[];
    readonly overrideCount: number;
    /** Names of packages that have dependency_overrides entries. */
    readonly overrideNames: ReadonlySet<string>;
    readonly pubspecUri: string | null;
    /** Extension version from package.json, shown next to the report title. */
    readonly extensionVersion: string;
    /** Optional per-package score history for inline sparkline rendering. */
    readonly packageTrends?: ReadonlyMap<string, number[]>;
    /**
     * True when a scan is currently in progress.  Used by `buildReportHtml`
     * to show a "Scan in progress" placeholder when there are no results
     * yet — without it the dashboard would render `0 packages`, `Grade E`,
     * an empty radial gauge, and an empty table, which looks broken to a
     * first-time user whose initial scan is still running.  When prior
     * results exist the dashboard keeps rendering them (stale but
     * meaningful) and the open panel auto-refreshes when the scan
     * completes via `publishResults`.
     */
    readonly isScanning?: boolean;
    // Wall-clock ms-since-epoch the displayed data was scanned at.  Drives
    // the "Scanned X ago" pill in the hero status line so users can tell at
    // a glance whether a Rescan click actually produced fresh data — without
    // it, the dashboard re-rendering with identical numbers reads as "rescan
    // did nothing" even when a scan really did run.  Undefined ⇒ no scan
    // has completed since the panel opened, or the displayed data came from
    // a pre-timestamp persisted snapshot.
    readonly lastScanTimestamp?: number;
}

/** Columns that can be auto-hidden when all values are empty or start collapsed. */
type HidableColumn = 'transitives' | 'vulns' | 'status' | 'files' | 'license' | 'description';

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
    <style nonce="${cspNonce}">${getPillButtonStyles()}${getReportStyles()}${getChartStyles()}${getKeyboardShortcutsStyles()}</style>
</head>
<body>
    <div class="report-header">
        <div class="hero-text">
          <h1>${escapeHtml(l10n('packageDashboard.heroTitle'))} <span class="header-version">v${escapeHtml(options.extensionVersion)}</span></h1>
          ${statusLineHtml.replace('</p>', `${buildKeyboardShortcutsButton()}${buildFullWidthToggle()}</p>`)}
        </div>
        ${buildRadialGauge(avg)}
    </div>
    ${buildGradeBreakdown(results, avg)}
    ${buildReportSummary(options)}
    ${buildChartSection(results)}
    ${buildFiltersSection(options)}
    ${buildPackagesSection(results, options)}
    ${/* Network panel lives at the bottom: it's a wide, scrollable diagram
       * that pushes the high-density table further down when placed above,
       * so users had to scroll past it just to reach the package list.
       * Anchoring it after the table keeps the primary view (status, chart,
       * table) immediately visible and treats the network as a drill-down. */ ''}
    ${buildNetworkSection(results)}
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

/**
 * Build the "Scanned X ago" pill for the hero status line.
 *
 * Surfaces the wall-clock recency of the displayed data so users can tell
 * at a glance whether a Rescan click actually produced fresh results —
 * without this, the dashboard re-rendering with identical numbers reads
 * as "rescan did nothing" even when the scan really did run.  An absolute
 * timestamp lives in the tooltip for the cases where "5m ago" isn't
 * precise enough (e.g. distinguishing two scans seconds apart).
 *
 * Pre-timestamp persisted snapshots have no `ts` — show "unknown" rather
 * than dropping the pill so the affordance stays in the same place every
 * render (a pill that comes and goes makes the dashboard layout jump).
 */
function buildLastScanPill(ts?: number): StatusPill {
    if (typeof ts !== 'number' || !Number.isFinite(ts) || ts <= 0) {
        return {
            glyph: '⟳',
            label: l10n('packageDashboard.status.lastScanUnknown'),
            title: l10n('packageDashboard.status.lastScanUnknownTitle'),
            tone: 'neutral',
        };
    }
    return {
        glyph: '⟳',
        label: l10n('packageDashboard.status.lastScanLabel', { when: formatScanRelative(ts) }),
        title: l10n('packageDashboard.status.lastScanTitle', {
            timestamp: new Date(ts).toLocaleString(),
        }),
        tone: 'neutral',
    };
}

/**
 * Format a ms-since-epoch timestamp as a relative-to-now string.
 *
 * Clock skew is real (NTP drift, VM time jumps after sleep, user system
 * clock set wrong) so future timestamps are normalised to "just now"
 * rather than showing a nonsensical negative value.
 */
function formatScanRelative(ts: number): string {
    const diffMs = Date.now() - ts;
    if (diffMs < 0) return l10n('packageDashboard.time.justNow');
    const sec = Math.floor(diffMs / 1000);
    if (sec < 45) return l10n('packageDashboard.time.justNow');
    const min = Math.floor(sec / 60);
    if (min < 60) return l10n('packageDashboard.time.minutesAgo', { min: String(min) });
    const hr = Math.floor(min / 60);
    if (hr < 24) return l10n('packageDashboard.time.hoursAgo', { hr: String(hr) });
    const day = Math.floor(hr / 24);
    return l10n('packageDashboard.time.daysAgo', { day: String(day) });
}

function buildNetworkSection(results: VibrancyResult[]): string {
    const direct = results.filter(r => r.package.isDirect);
    const nodes = direct.map(d => {
        const links = (d.transitiveInfo?.transitives ?? [])
            .filter(t => results.some(r => r.package.name === t))
            .slice(0, 20);
        return { name: d.package.name, links };
    });
    const payload = escapeHtml(JSON.stringify(nodes));
    return `<details class="network-wrap">
        <summary>${escapeHtml(l10n('packageDashboard.network.summary'))}</summary>
        <div id="dep-network" data-network="${payload}" class="network-canvas"></div>
    </details>`;
}

/**
 * Empty-state placeholder shown while the first scan is running.  Kept
 * deliberately simple: no chart, no table, no gauge — just a plainly
 * worded card so first-time users know the extension is doing real work
 * and roughly how long to wait.  Uses the same VS Code theme tokens as
 * the real dashboard so it doesn't look out of place.  No script tag
 * because there is nothing interactive to drive yet — the open panel
 * auto-refreshes from `publishResults` when the scan finishes.
 */
function buildScanInProgressHtml(options: ReportOptions): string {
    const cspNonce = createWebviewCspNonce();
    return `<!DOCTYPE html>
<html lang="en">
<head>
    <title>${escapeHtml(l10n('packageDashboard.documentTitle'))}</title>
    <meta charset="UTF-8">
    <meta http-equiv="Content-Security-Policy"
        content="default-src 'none'; style-src 'nonce-${cspNonce}' 'unsafe-inline';">
    <style nonce="${cspNonce}">
        body {
            font-family: var(--vscode-font-family);
            color: var(--vscode-foreground);
            background: var(--vscode-editor-background);
            margin: 0;
            padding: 48px 24px;
            display: flex;
            justify-content: center;
        }
        .scanning-card {
            max-width: 480px;
            text-align: center;
        }
        .scanning-card h1 {
            font-size: 1.4em;
            margin: 0 0 12px;
        }
        .scanning-card p {
            color: var(--vscode-descriptionForeground);
            line-height: 1.5;
            margin: 8px 0;
        }
        .scanning-card .version {
            font-size: 0.85em;
            color: var(--vscode-descriptionForeground);
            opacity: 0.7;
        }
        /* Three-dot pulse — tied to font-size so it scales with theme settings. */
        .dots::after {
            content: '...';
            display: inline-block;
            animation: dotPulse 1.4s steps(4, end) infinite;
            width: 1.2em;
            text-align: left;
            overflow: hidden;
            vertical-align: bottom;
        }
        @keyframes dotPulse {
            0%   { content: ''; }
            25%  { content: '.'; }
            50%  { content: '..'; }
            75%  { content: '...'; }
            100% { content: ''; }
        }
    </style>
</head>
<body>
    <div class="scanning-card">
        <h1>${escapeHtml(l10n('packageDashboard.scanning.heading'))}<span class="dots"></span></h1>
        <p>${escapeHtml(l10n('packageDashboard.scanning.body1'))}</p>
        <p>${escapeHtml(l10n('packageDashboard.scanning.body2'))}</p>
        <p class="version">${escapeHtml(l10n('packageDashboard.scanning.versionStamp', { version: options.extensionVersion }))}</p>
    </div>
</body>
</html>`;
}

/**
 * Animated radial gauge SVG showing the overall project health score.
 * The arc fills from red (0) through yellow (50) to green (100) and
 * animates on load via a CSS stroke-dashoffset transition.
 */
function buildRadialGauge(avgScore: number): string {
    /* avgScore is 0-100 (raw vibrancy score). */
    const pct = Math.max(0, Math.min(100, avgScore));
    /* Arc geometry: 270-degree arc (3/4 circle), radius 36, centered at 44,44. */
    const r = 36;
    const circumference = 2 * Math.PI * r;
    /* 270 degrees = 3/4 of full circle */
    const arcLength = circumference * 0.75;
    const filled = arcLength * (pct / 100);
    /* Color: interpolate red(0) -> yellow(50) -> green(100). */
    const color = pct >= 50
        ? `hsl(${Math.round(60 + (pct - 50) * 1.2)}, 80%, 45%)`
        : `hsl(${Math.round(pct * 1.2)}, 80%, 45%)`;
    /* Grade derived from score thresholds (never F: F requires hard EOL
       signals that can't be inferred from an average score). */
    const gradeLabel = scoreToGrade(pct);
    // stroke-dasharray is written as a direct SVG presentation attribute (not
    // inline style or CSS var) so it survives the strict CSP — see the CSP
    // comment in buildReportHtml for the failure mode this avoids. SMIL
    // <animate> is used for the fill-in animation because it's part of SVG,
    // not CSS, so it doesn't require any style-src concessions.
    // role/tabindex make the gauge keyboard-actionable; the click handler in
    // report-script.ts toggles the <details id="grade-breakdown"> panel so
    // the gauge doubles as a "why this grade?" affordance.
    return `<div class="radial-gauge" role="button" tabindex="0"
            aria-controls="grade-breakdown"
            data-breakdown-trigger="gauge"
            title="${escapeHtml(l10n('packageDashboard.gaugeTitle', { grade: gradeLabel }))}">
        <svg viewBox="0 0 88 88" class="gauge-svg">
            <circle cx="44" cy="44" r="${r}" fill="none"
                stroke="var(--vscode-widget-border)" stroke-width="7"
                stroke-dasharray="${arcLength} ${circumference}"
                stroke-dashoffset="0"
                stroke-linecap="round"
                transform="rotate(135 44 44)" />
            <circle cx="44" cy="44" r="${r}" fill="none"
                stroke="${color}" stroke-width="7"
                stroke-dasharray="${filled} ${arcLength}"
                stroke-dashoffset="0"
                stroke-linecap="round"
                transform="rotate(135 44 44)"
                class="gauge-fill">
                <animate attributeName="stroke-dasharray"
                    from="0 ${arcLength}"
                    to="${filled} ${arcLength}"
                    dur="1.2s"
                    fill="freeze"
                    calcMode="spline"
                    keySplines="0.25 0.1 0.25 1" />
            </circle>
        </svg>
        <div class="gauge-label">${gradeLabel}</div>
    </div>`;
}

/**
 * "Why this grade?" breakdown — a collapsible panel that explains the inputs
 * driving the overall project grade. Opens when the user clicks the radial
 * gauge or the Project Package Grade summary card (wired up in
 * report-script.ts). The panel itself is a plain <details> so it works
 * without JS — clicking the summary still toggles it. All drill-down links
 * route through existing infrastructure (filterByCard, navigateToPackageRow)
 * to keep behavior consistent with the rest of the dashboard.
 */
function buildGradeBreakdown(results: readonly VibrancyResult[], avgScore: number): string {
    if (results.length === 0) return '';
    const counts = countByCategory(results);
    const total = results.length;
    const avgGrade = scoreToGrade(avgScore);
    const vulnerable = results.filter(r => r.vulnerabilities.length > 0).length;
    const updates = results.filter(
        r => r.updateInfo && r.updateInfo.updateStatus !== 'up-to-date',
    ).length;
    const flagged = counts.eol + counts.abandoned;
    // Sort by score ascending (worst first); ties broken by category severity
    // implicitly via score, then name for stability. Score is the same number
    // that drives the gauge — surfacing the bottom 5 directly tells the user
    // which packages to look at to lift the project grade.
    const bottom = [...results]
        .sort((a, b) => a.score - b.score || a.package.name.localeCompare(b.package.name))
        .slice(0, 5);
    const distRow = (key: 'vibrant' | 'stable' | 'outdated' | 'abandoned' | 'eol', filter: string, count: number) => {
        const pct = total > 0 ? Math.round((count / total) * 100) : 0;
        return `<li class="breakdown-dist-row">
            <button type="button" class="breakdown-filter-btn" data-filter="${filter}"
                title="${escapeHtml(l10n('packageDashboard.breakdown.filterTooltip'))}">
                <span class="grade-badge grade-${gradeBadgeLetter(key)}">${gradeBadgeLetter(key)}</span>
                <span class="breakdown-dist-label">${escapeHtml(l10n(`packageDashboard.summary.${key}Title`))}</span>
            </button>
            <span class="breakdown-dist-count">${count}</span>
            <span class="breakdown-dist-pct">${pct}%</span>
        </li>`;
    };
    const bottomItem = (r: VibrancyResult) => {
        const grade = scoreToGrade(r.score);
        return `<li class="breakdown-bottom-row">
            <button type="button" class="breakdown-jump-btn" data-pkg="${escapeHtml(r.package.name)}"
                title="${escapeHtml(l10n('packageDashboard.breakdown.jumpTooltip', { name: r.package.name }))}">
                <span class="grade-badge grade-${grade}">${grade}</span>
                <span class="breakdown-pkg-name">${escapeHtml(r.package.name)}</span>
            </button>
            <span class="breakdown-pkg-score">${Math.round(r.score)}/100</span>
        </li>`;
    };
    const heading = escapeHtml(l10n('packageDashboard.breakdown.title', {
        grade: avgGrade,
        avgScore: String(Math.round(avgScore)),
        pkgCount: String(total),
    }));
    return `<details id="grade-breakdown" class="grade-breakdown">
        <summary class="grade-breakdown-summary">
            <span class="grade-breakdown-title">${heading}</span>
            <span class="grade-breakdown-hint">${escapeHtml(l10n('packageDashboard.breakdown.hint'))}</span>
        </summary>
        <div class="grade-breakdown-body">
            <section class="breakdown-section">
                <h3>${escapeHtml(l10n('packageDashboard.breakdown.distributionHeading'))}</h3>
                <ul class="breakdown-dist">
                    ${distRow('vibrant', 'vibrant', counts.vibrant)}
                    ${distRow('stable', 'stable', counts.stable)}
                    ${distRow('outdated', 'outdated', counts.outdated)}
                    ${distRow('abandoned', 'abandoned', counts.abandoned)}
                    ${distRow('eol', 'end-of-life', counts.eol)}
                </ul>
            </section>
            <section class="breakdown-section">
                <h3>${escapeHtml(l10n('packageDashboard.breakdown.signalsHeading'))}</h3>
                <ul class="breakdown-signals">
                    <li><button type="button" class="breakdown-filter-btn" data-filter="end-of-life"
                        ${flagged === 0 ? 'disabled' : ''}>${escapeHtml(l10n('packageDashboard.breakdown.signalFlagged', { count: String(flagged) }))}</button></li>
                    <li><button type="button" class="breakdown-filter-btn" data-filter="vulns"
                        ${vulnerable === 0 ? 'disabled' : ''}>${escapeHtml(l10n('packageDashboard.breakdown.signalVulnerable', { count: String(vulnerable) }))}</button></li>
                    <li><button type="button" class="breakdown-filter-btn" data-filter="updates"
                        ${updates === 0 ? 'disabled' : ''}>${escapeHtml(l10n('packageDashboard.breakdown.signalUpdates', { count: String(updates) }))}</button></li>
                </ul>
            </section>
            <section class="breakdown-section">
                <h3>${escapeHtml(l10n('packageDashboard.breakdown.bottomHeading'))}</h3>
                <ol class="breakdown-bottom">
                    ${bottom.map(bottomItem).join('')}
                </ol>
            </section>
            <section class="breakdown-section breakdown-thresholds">
                <h3>${escapeHtml(l10n('packageDashboard.breakdown.thresholdsHeading'))}</h3>
                <ul>
                    <li><span class="grade-badge grade-A">A</span> ${escapeHtml(l10n('packageDashboard.breakdown.thresholdA'))}</li>
                    <li><span class="grade-badge grade-B">B</span> ${escapeHtml(l10n('packageDashboard.breakdown.thresholdB'))}</li>
                    <li><span class="grade-badge grade-C">C</span> ${escapeHtml(l10n('packageDashboard.breakdown.thresholdC'))}</li>
                    <li><span class="grade-badge grade-E">E</span> ${escapeHtml(l10n('packageDashboard.breakdown.thresholdE'))}</li>
                    <li><span class="grade-badge grade-F">F</span> ${escapeHtml(l10n('packageDashboard.breakdown.thresholdF'))}</li>
                </ul>
            </section>
        </div>
    </details>`;
}

/** Map a distribution category bucket to its letter-grade badge. The
 *  buckets used in countByCategory don't carry the letter directly, so this
 *  small lookup keeps the badge styling consistent with the rest of the
 *  dashboard's grade-A/B/C/E/F CSS classes. */
function gradeBadgeLetter(bucket: 'vibrant' | 'stable' | 'outdated' | 'abandoned' | 'eol'): string {
    switch (bucket) {
        case 'vibrant': return 'A';
        case 'stable': return 'B';
        case 'outdated': return 'C';
        case 'abandoned': return 'E';
        case 'eol': return 'F';
    }
}

function buildReportSummary(options: ReportOptions): string {
    const { results, overrideCount } = options;
    const counts = countByCategory(results);
    const updates = results.filter(
        r => r.updateInfo && r.updateInfo.updateStatus !== 'up-to-date',
    ).length;
    const avgScore = results.length > 0
        ? results.reduce((s, r) => s + r.score, 0) / results.length
        : 0;
    const avgGrade = results.length > 0 ? scoreToGrade(avgScore) : '—';
    /* Total Size summary prefers code-size — the bytes the package
       contributes to a built app. Falls back to the gzipped archive when the
       tarball analyzer couldn't run, so the rollup is never blank when ANY
       size info is available. Mirrors buildSizeCell's fallback.

       dev_dependencies are EXCLUDED from every Total Size variant. They are
       compile/lint/test-time tooling (saropa_lints, build_runner, lints) and
       never reach the APK / IPA / web bundle, so counting them as "shipped
       bytes" gave 66%+ of "total size" to dev-only packages and inverted what
       this card communicates. The Include-dev toggle still affects the
       package table (people want dev rows visible there) but never the
       size summary — shipped bytes is the only meaning of this number. */
    const isShippable = (r: VibrancyResult) => r.package.section !== 'dev_dependencies';
    const shippableResults = results.filter(isShippable);
    const ownBytes = (r: VibrancyResult) => r.codeSizeBytes ?? r.archiveSizeBytes ?? 0;
    const totalOwnBytes = shippableResults.reduce(
        (sum, r) => sum + ownBytes(r), 0,
    );
    const totalUniqueBytes = shippableResults.reduce((sum, r) => {
        const own = ownBytes(r);
        const unique = r.transitiveInfo?.uniqueTransitiveSizeBytes ?? 0;
        return sum + own + unique;
    }, 0);
    const totalAllBytes = shippableResults.reduce((sum, r) => {
        const own = ownBytes(r);
        const unique = r.transitiveInfo?.uniqueTransitiveSizeBytes ?? 0;
        const shared = r.transitiveInfo?.sharedTransitiveSizeBytes ?? 0;
        return sum + own + unique + shared;
    }, 0);
    const totalSize = totalOwnBytes > 0 ? formatSizeMB(totalOwnBytes) : '\u2014';
    const vulnPackages = results.filter(r => r.vulnerabilities.length > 0).length;
    // "Single-use" excludes packages whose only reference is a re-export.
    // A `lib/foo.dart` that does `export 'package:bar/...';` is exposing the
    // package as part of its own public API, so the dep isn't "easy to remove"
    // even though it appears in just one source file.
    const singleUse = results.filter(
        r => activeFileUsages(r.fileUsages).length === 1
            && !hasActiveReExport(r.fileUsages),
    ).length;

    const gradeTooltip = l10n('packageDashboard.summary.gradeTooltip', {
        avgGrade,
        avgScore: String(Math.round(avgScore)),
        pkgCount: String(results.length),
        a: String(counts.vibrant),
        b: String(counts.stable),
        c: String(counts.outdated),
        e: String(counts.abandoned),
        f: String(counts.eol),
    });
    // Anchor each caveat to the card it describes via `title=` instead of
    // a floating <p class="caveat"> at the bottom of the summary. Users
    // reported the bottom-of-block notes were visually disconnected from
    // their referent data (Total Size* / activity grade cards).
    const totalSizeTitle =
        `${l10n('packageDashboard.summary.totalSize')}\n\n${l10n('packageDashboard.summary.caveatLine1')}`;
    const thresholdCaveat = l10n('packageDashboard.summary.caveatLine2');
    const gradeTitle = (key: string) =>
        `${l10n(`packageDashboard.summary.${key}`)}\n\n${thresholdCaveat}`;
    return `<div class="summary">
        <div class="summary-card"><div class="count">${results.length}</div><div class="label">${escapeHtml(l10n('packageDashboard.summary.packages'))}</div></div>
        <div class="summary-card" role="button" tabindex="0"
            aria-controls="grade-breakdown" data-breakdown-trigger="grade-card"
            title="${escapeHtml(gradeTooltip)}"><div class="count">${avgGrade}</div><div class="label">${escapeHtml(l10n('packageDashboard.summary.projectGrade'))}</div></div>
        <div class="summary-card total-size"
            title="${escapeHtml(totalSizeTitle)}"
            data-total-size-own="${totalOwnBytes}"
            data-total-size-unique="${totalUniqueBytes}"
            data-total-size-total="${totalAllBytes}">
            <div class="count">${totalSize}</div><div class="label">${escapeHtml(l10n('packageDashboard.summary.totalSize'))}</div>
        </div>
        <div class="summary-card vibrant" data-filter="vibrant" title="${escapeHtml(gradeTitle('vibrantTitle'))}"><div class="count">${counts.vibrant}</div><div class="label">A</div></div>
        <div class="summary-card stable" data-filter="stable" title="${escapeHtml(gradeTitle('stableTitle'))}"><div class="count">${counts.stable}</div><div class="label">B</div></div>
        <div class="summary-card outdated" data-filter="outdated" title="${escapeHtml(gradeTitle('outdatedTitle'))}"><div class="count">${counts.outdated}</div><div class="label">C</div></div>
        <div class="summary-card abandoned" data-filter="abandoned" title="${escapeHtml(gradeTitle('abandonedTitle'))}"><div class="count">${counts.abandoned}</div><div class="label">E</div></div>
        <div class="summary-card eol" data-filter="end-of-life" title="${escapeHtml(gradeTitle('eolTitle'))}"><div class="count">${counts.eol}</div><div class="label">F</div></div>
        <div class="summary-card updates" data-filter="updates"><div class="count">${updates}</div><div class="label">${escapeHtml(l10n('packageDashboard.summary.updates'))}</div></div>
        <div class="summary-card unused" data-filter="unused"><div class="count">${results.filter(r => r.isUnused).length}</div><div class="label">${escapeHtml(l10n('packageDashboard.summary.unused'))}</div></div>
        ${singleUse > 0 ? `<div class="summary-card single-use" data-filter="single-use"><div class="count">${singleUse}</div><div class="label">${escapeHtml(l10n('packageDashboard.summary.singleUse'))}</div></div>` : ''}
        <div class="summary-card vulns" data-filter="vulns"><div class="count">${vulnPackages}</div><div class="label">${escapeHtml(l10n('packageDashboard.summary.vulnerable'))}</div></div>
        <div class="summary-card overrides" data-filter="overrides"><div class="count">${overrideCount}</div><div class="label">${escapeHtml(l10n('packageDashboard.summary.overrides'))}</div></div>
    </div>`;
}

/**
 * Wrap the toolbar in a collapsible <details> so users can fold the
 * search/filters row away once they have narrowed the table to what they
 * care about. Defaults to open to preserve the existing landing
 * experience — collapse is opt-in. Matches the dashboard's existing
 * disclosure pattern (network section, chart section).
 */
function buildFiltersSection(options: ReportOptions): string {
    const title = escapeHtml(l10n('packageDashboard.sections.filters'));
    return `<details class="filters-section dashboard-collapsible" open>
        <summary><h2>${title}</h2></summary>
        ${buildToolbar(options)}
    </details>`;
}

/**
 * Wrap the package table in a collapsible <details>. Defaults open so the
 * dashboard's primary content remains visible on first load; collapsing
 * is only useful when the user wants to focus on the chart or summary
 * cards above.
 */
function buildPackagesSection(
    results: VibrancyResult[],
    options: ReportOptions,
): string {
    const title = escapeHtml(l10n('packageDashboard.sections.packages'));
    return `<details class="packages-section dashboard-collapsible" open>
        <summary><h2>${title}</h2></summary>
        ${buildReportTable(results, options.overrideNames, options.packageTrends)}
    </details>`;
}

/** Toolbar with search box and pubspec link, placed between chart and table. */
function buildToolbar(options: ReportOptions): string {
    const tb = 'packageDashboard.toolbar';
    const pubspecBtn = options.pubspecUri
        ? `<button id="open-pubspec" class="toolbar-btn" title="${escapeHtml(l10n(`${tb}.openPubspecTitle`))}">&#128196; ${escapeHtml(l10n(`${tb}.openPubspecLabel`))}</button>`
        : '';
    // Copies every package row as a JSON array, including all expander
    // content (health factors, vulnerabilities, file references, full
    // transitive dep list with shared flags, links). Same per-package
    // shape as the per-row copy button, just aggregated.
    const copyAllBtn =
        `<button id="copy-all" class="toolbar-btn" title="${escapeHtml(l10n(`${tb}.copyAllTitle`))}">&#128203; ${escapeHtml(l10n(`${tb}.copyAllLabel`))}</button>`;
    const saveBtn =
        `<button id="save-all" class="toolbar-btn" title="${escapeHtml(l10n(`${tb}.saveAllTitle`))}">&#128190; ${escapeHtml(l10n(`${tb}.saveAllLabel`))}</button>`;
    // Saves the same per-package JSON shape as "Save", but filtered to only
    // packages with an available update (update.status present and not
    // 'up-to-date'/'unknown' — the same outdated test the modernization
    // filter uses at report-script.ts). Gives users a focused upgrade
    // worklist without the noise of already-current dependencies.
    const saveUpgradeBtn =
        `<button id="save-upgrade" class="toolbar-btn" title="${escapeHtml(l10n(`${tb}.saveUpgradeTitle`))}">&#128190; ${escapeHtml(l10n(`${tb}.saveUpgradeLabel`))}</button>`;
    // hidden by default — the script flips it on as soon as any sort/filter/
    // footprint state diverges from defaults. Markup-level hide means a slow
    // or failed script still keeps the button out of sight on a pristine view,
    // so "Reset view" never appears against a view that has nothing to reset.
    const resetViewBtn =
        `<button id="reset-view" class="toolbar-btn" title="${escapeHtml(l10n(`${tb}.resetViewTitle`))}" hidden disabled>&#8635; ${escapeHtml(l10n(`${tb}.resetViewLabel`))}</button>`;
    // Rescan button — invokes saropaLints.packageVibrancy.rescan via the
    // webview message channel so users don't have to leave the report to
    // trigger a refresh after editing pubspec.yaml or running `pub get`.
    // The `rescan` command (not `scan`) clears the per-package pub.dev
    // cache first so the report shows current pub.dev state — without it
    // the 24h cache TTL made the button a silent no-op for fresh entries.
    const rescanBtn =
        `<button id="rescan" class="toolbar-btn" title="${escapeHtml(l10n(`${tb}.rescanTitle`))}">&#128260; ${escapeHtml(l10n(`${tb}.rescanLabel`))}</button>`;
    // Open another project — file picker → opens the selected
    // pubspec.yaml's folder in a new VS Code window. Useful for
    // diagnosing multiple projects without swapping workspace roots.
    const openOtherBtn =
        `<button id="open-other" class="toolbar-btn" title="${escapeHtml(l10n(`${tb}.openOtherTitle`))}">&#128194; ${escapeHtml(l10n(`${tb}.openOtherLabel`))}</button>`;
    // Footprint-mode toggle controls what the Size column shows:
    //   own     = archive size of the package itself (default; matches old behavior)
    //   unique  = own + transitives used ONLY by this dep (cost saved if removed)
    //   total   = own + ALL transitives, including ones shared with other deps
    const footprintToggle = `<div class="footprint-toggle" role="group" aria-label="${escapeHtml(l10n(`${tb}.footprintGroupAria`))}"
        title="${escapeHtml(l10n(`${tb}.footprintGroupTitle`))}">
        <span class="toggle-label">${escapeHtml(l10n(`${tb}.footprintLabel`))}</span>
        <button class="toggle-btn footprint-btn active" data-footprint="own"
            title="${escapeHtml(l10n(`${tb}.footprintOwnTitle`))}">${escapeHtml(l10n(`${tb}.footprintOwn`))}</button>
        <button class="toggle-btn footprint-btn" data-footprint="unique"
            title="${escapeHtml(l10n(`${tb}.footprintUniqueTitle`))}">${escapeHtml(l10n(`${tb}.footprintUnique`))}</button>
        <button class="toggle-btn footprint-btn" data-footprint="total"
            title="${escapeHtml(l10n(`${tb}.footprintTotalTitle`))}">${escapeHtml(l10n(`${tb}.footprintTotal`))}</button>
    </div>`;
    // Search field wrapped so we can absolutely position a clear (X) button
    // inside it; the button stays hidden until the user types something, and
    // a click clears the input + re-runs filters.
    const searchField = `<div class="search-wrapper">
        <label class="sr-only" for="search-input">${escapeHtml(l10n(`${tb}.searchLabel`))}</label>
        <input type="text" id="search-input" placeholder="${escapeHtml(l10n(`${tb}.searchPlaceholder`))}" class="search-input" />
        <button type="button" id="search-clear" class="search-clear" title="${escapeHtml(l10n(`${tb}.clearSearchTitle`))}" aria-label="${escapeHtml(l10n(`${tb}.clearSearchAria`))}" hidden>&times;</button>
    </div>`;
    const ageFilter = `<div class="age-filter" title="${escapeHtml(l10n(`${tb}.ageFilterTitle`))}">
        <label for="age-max">${escapeHtml(l10n(`${tb}.publishedAgeLabel`))}</label>
        <input id="age-max" type="range" min="0" max="240" value="240" />
        <span id="age-max-label">${escapeHtml(l10n(`${tb}.ageMaxAll`))}</span>
    </div>`;
    const presetFilter = `<div class="preset-filter" title="${escapeHtml(l10n(`${tb}.presetFilterTitle`))}">
        <label for="filter-preset">${escapeHtml(l10n(`${tb}.presetLabel`))}</label>
        <select id="filter-preset">
            <option value="none">${escapeHtml(l10n(`${tb}.presetNone`))}</option>
            <option value="modernization">${escapeHtml(l10n(`${tb}.presetModernization`))}</option>
            <option value="risk-hotspots">${escapeHtml(l10n(`${tb}.presetRiskHotspots`))}</option>
            <option value="cleanup-candidates">${escapeHtml(l10n(`${tb}.presetCleanup`))}</option>
            <option value="direct-only">${escapeHtml(l10n(`${tb}.presetDirectOnly`))}</option>
        </select>
    </div>`;
    const devToggle = `<label class="dev-toggle" title="${escapeHtml(l10n(`${tb}.devToggleTitle`))}">
        <input id="include-dev-toggle" type="checkbox" checked />
        ${escapeHtml(l10n(`${tb}.includeDev`))}
    </label>`;
    return `<div class="table-toolbar">
        ${searchField}
        ${ageFilter}
        ${presetFilter}
        ${devToggle}
        ${footprintToggle}
        ${rescanBtn}
        ${openOtherBtn}
        ${resetViewBtn}
        ${copyAllBtn}
        ${saveBtn}
        ${saveUpgradeBtn}
        ${pubspecBtn}
    </div>
    <div id="active-filters" class="active-filters" hidden>
        <span class="active-filters-label">${escapeHtml(l10n(`${tb}.activeFiltersLabel`))}</span>
        <div class="active-filters-list"></div>
        <button id="clear-all-filters" class="clear-filter-btn" type="button">${escapeHtml(l10n(`${tb}.clearAllFilters`))}</button>
    </div>`;
}

/** Determine which optional columns should be hidden (all values empty). */
function getHiddenColumns(results: VibrancyResult[]): Set<HidableColumn> {
    const hidden = new Set<HidableColumn>();
    const hasTransitives = results.some(
        r => r.transitiveInfo && r.transitiveInfo.transitiveCount > 0,
    );
    if (!hasTransitives) { hidden.add('transitives'); }
    const hasVulns = results.some(r => r.vulnerabilities.length > 0);
    if (!hasVulns) { hidden.add('vulns'); }
    const hasUnused = results.some(r => r.isUnused);
    if (!hasUnused) { hidden.add('status'); }
    const hasFileUsages = results.some(r => r.fileUsages.length > 0);
    if (!hasFileUsages) { hidden.add('files'); }
    /* License and description start collapsed — no toggle UI yet. */
    hidden.add('license');
    hidden.add('description');
    return hidden;
}

/**
 * Build a canonical-repo → count map so the JSON export can flag packages
 * that share a repo URL with other project packages. Stars on GitHub apply
 * to the whole repository (not to a subdirectory), so a high star count on
 * a monorepo sibling like `firebase_core` doesn't signal anything
 * `firebase_core`-specific — every Firebase package in the project would
 * report the same number. The sibling count lets consumers of the row JSON
 * disambiguate "this repo has 12k stars on its own merit" from "this repo
 * has 12k stars shared across 8 project packages".
 */
function buildRepoShareMap(
    results: readonly VibrancyResult[],
): ReadonlyMap<string, number> {
    const counts = new Map<string, number>();
    for (const r of results) {
        const url = resolveRepoUrl(r);
        if (!url) { continue; }
        counts.set(url, (counts.get(url) ?? 0) + 1);
    }
    return counts;
}

/** Derive shared transitive dep names from all results' TransitiveInfo. */
function deriveSharedDepNames(results: VibrancyResult[]): ReadonlySet<string> {
    return new Set(
        results.flatMap(r => r.transitiveInfo?.sharedDeps ?? []),
    );
}

function buildReportTable(
    results: VibrancyResult[],
    overrideNames: ReadonlySet<string>,
    packageTrends: ReadonlyMap<string, number[]> | undefined,
): string {
    const hidden = getHiddenColumns(results);
    const sharedDepNames = deriveSharedDepNames(results);
    const tablePackageNames = new Set(results.map(r => r.package.name));
    const th = (col: string, label: string, tooltip?: string) => {
        const titleAttr = tooltip ? ` title="${escapeHtml(tooltip)}"` : '';
        return `<th data-col="${col}"${titleAttr}>${label}<span class="sort-arrow"></span></th>`;
    };
    const thOpt = (col: HidableColumn, label: string, tooltip?: string) =>
        hidden.has(col) ? '' : th(col, label, tooltip);

    /* Count visible columns so the detail row can span them all.
       Base columns: expand + copy + name + version + category + published +
       activity + likes + downloads + issues + prs + size + deps + update = 14.
       (Stars used to be a column; it was replaced by Likes because GitHub
       stars apply to the whole repo — monorepo siblings all reported the
       same number — while pub.dev likes are per-package. Downloads were
       added as a second package-specific trust signal from the same
       source.) */
    const visibleCols = 14
        + (hidden.has('files') ? 0 : 1)
        + (hidden.has('transitives') ? 0 : 1)
        + (hidden.has('vulns') ? 0 : 1)
        + (hidden.has('license') ? 0 : 1)
        + (hidden.has('status') ? 0 : 1)
        + (hidden.has('description') ? 0 : 1);

    return `<table>
        <thead><tr>
            <th class="col-expand"></th>
            <th class="col-copy"></th>
            ${th('name', col('name', 'label'), col('name', 'tooltip'))}
            ${th('version', col('version', 'label'), col('version', 'tooltip'))}
            ${th('score', col('score', 'label'), col('score', 'tooltip'))}
            ${th('published', col('published', 'label'), col('published', 'tooltip'))}
            ${th('activity', col('activity', 'label'), col('activity', 'tooltip'))}
            ${th('likes', col('likes', 'label'), col('likes', 'tooltip'))}
            ${th('downloads', col('downloads', 'label'), col('downloads', 'tooltip'))}
            ${th('issues', col('issues', 'label'), col('issues', 'tooltip'))}
            ${th('prs', col('prs', 'label'), col('prs', 'tooltip'))}
            ${th('size', col('size', 'label'), col('size', 'tooltip'))}
            ${th('deps', col('deps', 'label'), col('deps', 'tooltip'))}
            ${thOpt('files', col('files', 'label'), col('files', 'tooltip'))}
            ${thOpt('transitives', col('transitives', 'label'), col('transitives', 'tooltip'))}
            ${thOpt('vulns', col('vulns', 'label'), col('vulns', 'tooltip'))}
            ${thOpt('license', col('license', 'label'), col('license', 'tooltip'))}
            ${th('update', col('update', 'label'), col('update', 'tooltip'))}
            ${thOpt('status', col('status', 'label'), col('status', 'tooltip'))}
            ${thOpt('description', col('description', 'label'), col('description', 'tooltip'))}
        </tr></thead>
        <tbody id="pkg-body">
            ${results.map(r => buildRow(
        r,
        hidden,
        overrideNames,
        sharedDepNames,
        tablePackageNames,
        visibleCols,
        packageTrends,
    )).join('\n')}
        </tbody>
    </table>`;
}

// ---------------------------------------------------------------------------
// Row builder + cell helpers
// ---------------------------------------------------------------------------

function buildRow(
    r: VibrancyResult,
    hidden: Set<HidableColumn>,
    overrideNames: ReadonlySet<string>,
    sharedDepNames: ReadonlySet<string>,
    tablePackageNames: ReadonlySet<string>,
    colspan: number,
    packageTrends: ReadonlyMap<string, number[]> | undefined,
): string {
    const name = escapeHtml(r.package.name);
    const date = r.pubDev?.publishedDate.split('T')[0] ?? '';
    const publishedAgeMonths = computePublishedAgeMonths(
        r.installedVersionDate ?? r.pubDev?.publishedDate ?? null,
    );
    /* data-likes / data-downloads feed the sort logic (see report-script.ts
       sortTable). Empty string sorts as NaN → alphabetical fallback, which
       matches the prior data-stars behavior for packages missing the
       signal. */
    const likes = r.likes ?? '';
    const downloads = r.downloadCount30Days ?? '';
    const issueCount = r.github?.trueOpenIssues ?? r.github?.openIssues ?? '';
    const prCount = r.github?.openPullRequests ?? '';
    const activity = computeActivitySignal(r);
    const activeFileCount = activeFileUsages(r.fileUsages).length;
    const transitiveCount = r.transitiveInfo?.transitiveCount ?? 0;
    const vulnCount = r.vulnerabilities.length;
    // A transitive package is "shared" if 2+ direct deps pull it in,
    // meaning removing any single direct dep would NOT eliminate it.
    const isSharedTransitive = r.package.section === 'transitive'
        && sharedDepNames.has(r.package.name);
    const isOverridden = overrideNames.has(r.package.name) ? 'yes' : 'no';
    // Re-export marker: drives the row tooltip badge and ensures the
    // client-side "single-use" filter excludes packages exposed via export.
    const isReExport = hasActiveReExport(r.fileUsages) ? 'yes' : 'no';

    return `<tr class="pkg-row" data-name="${name}" data-version="${escapeHtml(r.package.version)}"
        data-score="${r.score}" data-category="${r.category}"
        data-published="${date}" data-likes="${likes}" data-downloads="${downloads}"
        data-activity="${activity.sortValue}"
        data-age-months="${publishedAgeMonths ?? ''}"
        data-issues="${issueCount}" data-prs="${prCount}"
        data-size="${r.codeSizeBytes ?? r.archiveSizeBytes ?? 0}"
        data-files="${activeFileCount}"
        data-transitives="${transitiveCount}"
        data-deps="${transitiveCount}"
        data-vulns="${vulnCount}"
        data-license="${escapeHtml(r.license ?? '')}"
        data-update="${r.updateInfo?.updateStatus ?? 'unknown'}"
        data-status="${r.isUnused ? 'unused' : 'ok'}"
        data-section="${r.package.section}"
        data-overridden="${isOverridden}"
        data-shared-transitive="${isSharedTransitive ? 'yes' : 'no'}"
        data-reexport="${isReExport}">
        <td class="expand-cell"><span class="expand-chevron" title="${escapeHtml(l10n('packageDashboard.row.expandDetails'))}">\u25B6</span></td>
        <td class="copy-cell"><span class="copy-btn" data-pkg="${name}" title="${escapeHtml(l10n('packageDashboard.row.copyRowJson'))}">&#128203;</span></td>
        ${buildNameCell(r)}
        ${buildVersionCell(r)}
        ${buildCategoryCell(r, packageTrends?.get(r.package.name) ?? [])}
        ${buildPublishedCell(r)}
        ${buildActivityCell(r)}
        ${buildLikesCell(r)}
        ${buildDownloadsCell(r)}
        ${buildIssuesCell(r)}
        ${buildPrsCell(r)}
        ${buildSizeCell(r)}
        ${buildDepsCell(r, tablePackageNames)}
        ${hidden.has('files') ? '' : buildReferencesCell(r)}
        ${hidden.has('transitives') ? '' : buildTransitivesCell(r, tablePackageNames)}
        ${hidden.has('vulns') ? '' : buildVulnsCell(r)}
        ${hidden.has('license') ? '' : buildLicenseCell(r)}
        ${buildUpdateCell(r)}
        ${hidden.has('status') ? '' : buildStatusCell(r)}
        ${hidden.has('description') ? '' : buildDescCell(r)}
    </tr>
    <tr class="detail-row" data-detail-for="${name}" hidden>
        <td colspan="${colspan}">${buildDetailCard(r)}</td>
    </tr>`;
}

function buildNameCell(r: VibrancyResult): string {
    const name = escapeHtml(r.package.name);
    const desc = r.pubDev?.description;
    const titleAttr = desc ? ` title="${escapeHtml(desc)}"` : '';
    let badge = '';
    if (r.package.section === 'dev_dependencies') {
        badge = ` <span class="badge-dev">${escapeHtml(l10n('packageDashboard.cells.devBadge'))}</span>`;
    } else if (r.package.section === 'transitive') {
        badge = ` <span class="badge-transitive">${escapeHtml(l10n('packageDashboard.cells.transitiveBadge'))}</span>`;
    }
    return `<td><span class="pkg-name-link" data-pkg="${name}"${titleAttr}>${name}</span>${badge}</td>`;
}

function buildVersionCell(r: VibrancyResult): string {
    const name = encodeURIComponent(r.package.name);
    const version = escapeHtml(r.package.version);
    const url = `https://pub.dev/packages/${name}/versions`;
    const tooltip = buildVersionTooltip(r);
    return `<td><a href="${url}" title="${escapeHtml(tooltip)}">${version}</a></td>`;
}

/** Format an ISO date as a compact age suffix, e.g. " (4mo)" or " (2y)". */
function formatAgeSuffix(isoDate: string | null | undefined): string {
    if (!isoDate) { return ''; }
    const ms = Date.parse(isoDate);
    if (isNaN(ms)) { return ''; }
    // Use calendar-month math in UTC to avoid drift from fixed-day month
    // approximations, especially around month-end boundaries.
    const from = new Date(ms);
    const now = new Date();
    const years = now.getUTCFullYear() - from.getUTCFullYear();
    const monthsDelta = now.getUTCMonth() - from.getUTCMonth();
    let months = years * 12 + monthsDelta;
    if (now.getUTCDate() < from.getUTCDate()) {
        months -= 1;
    }
    months = Math.max(0, months);
    // Suppress the suffix entirely for ages under a month — the previous
    // "(new)" label was misleading (recently published != fresh release of a
    // mature package), so we just omit it rather than guess a useful word.
    if (months < 1) { return ''; }
    const label = months < 24 ? `${months}mo` : `${Math.floor(months / 12)}y`;
    return ` <span class="version-age">(${label})</span>`;
}

/** Build a multi-line tooltip with version details. */
function buildVersionTooltip(r: VibrancyResult): string {
    const lines: string[] = [];
    const installedDate = formatDate(r.installedVersionDate);
    const latestDate = formatDate(r.pubDev?.publishedDate);
    const createdDate = formatDate(r.pubDev?.createdDate);

    if (installedDate) {
        lines.push(l10n('packageDashboard.versionTooltip.installed', {
            version: r.package.version,
            date: installedDate,
        }));
    }
    const latest = r.pubDev?.latestVersion;
    if (latest && latest !== r.package.version) {
        const suffix = latestDate ? ` (${latestDate})` : '';
        lines.push(l10n('packageDashboard.versionTooltip.latest', {
            version: `${latest}${suffix}`,
        }));
    }
    if (createdDate) {
        lines.push(l10n('packageDashboard.versionTooltip.created', { date: createdDate }));
    }
    if (r.package.constraint) {
        lines.push(l10n('packageDashboard.versionTooltip.constraint', {
            constraint: r.package.constraint,
        }));
    }
    return lines.join('\n');
}

/** Extract YYYY-MM-DD from an ISO date string. */
function formatDate(isoDate: string | null | undefined): string {
    if (!isoDate) { return ''; }
    return isoDate.split('T')[0] ?? '';
}

/** Category column: letter grade badge only. Label/score surfaced via tooltip. */
function buildCategoryCell(r: VibrancyResult, trend: number[]): string {
    const grade = categoryToGrade(r.category);
    const tooltip = buildHealthTooltip(r);
    const color = sparklineColorForCategory(r.category);
    const sparkline = buildSparklineSvg(trend, color);
    return `<td title="${escapeHtml(tooltip)}"><span class="category-cell"><span class="grade-badge grade-${grade}">${grade}</span>${sparkline}</span></td>`;
}

function sparklineColorForCategory(category: VibrancyResult['category']): string {
    if (category === 'vibrant') { return 'var(--vscode-testing-iconPassed)'; }
    if (category === 'stable') { return 'var(--vscode-editorInfo-foreground)'; }
    if (category === 'outdated' || category === 'abandoned') {
        return 'var(--vscode-editorWarning-foreground)';
    }
    return 'var(--vscode-editorError-foreground)';
}

export function buildSparklineSvg(scores: readonly number[], color: string): string {
    if (scores.length < 2) { return ''; }
    const w = 40;
    const h = 16;
    const step = w / (scores.length - 1);
    const points = scores.map((s, i) =>
        `${(i * step).toFixed(1)},${(h - (Math.max(0, Math.min(100, s)) / 100) * h).toFixed(1)}`,
    ).join(' ');
    return `<svg width="${w}" height="${h}" class="sparkline" aria-hidden="true">
        <polyline points="${points}" fill="none" stroke="${color}" stroke-width="1.5"/>
    </svg>`;
}

/** Published date linking to the pub.dev package page, with age suffix. */
function buildPublishedCell(r: VibrancyResult): string {
    const date = r.pubDev?.publishedDate.split('T')[0] ?? '';
    const url = `https://pub.dev/packages/${encodeURIComponent(r.package.name)}`;
    const ageSuffix = formatAgeSuffix(r.installedVersionDate ?? r.pubDev?.publishedDate);
    if (!date) {
        return `<td title="${escapeHtml(l10n('packageDashboard.cells.publishDateUnavailable'))}"><span class="dimmed">\u2014</span></td>`;
    }
    return `<td><a href="${url}">${date}</a>${ageSuffix}</td>`;
}

function buildActivityCell(r: VibrancyResult): string {
    const activity = computeActivitySignal(r);
    if (activity.grade === null) {
        return `<td title="${escapeHtml(l10n('packageDashboard.cells.activityGradeUnavailable'))}"><span class="dimmed">\u2014</span></td>`;
    }
    const title = activity.message ?? l10n('packageDashboard.cells.activityFallback');
    return `<td title="${escapeHtml(title)}"><span class="grade-badge grade-${activity.grade}">${activity.grade}</span></td>`;
}

/** Build a multi-line tooltip explaining the vibrancy score breakdown. */
function buildHealthTooltip(r: VibrancyResult): string {
    const fmt = (v: number) => Math.round(v);
    const publishAgeDays = daysSinceIsoDate(r.pubDev?.publishedDate);
    const commitAgeDays = r.github?.daysSinceLastCommit;
    /* The leading "Vibrancy Score: n/10" line was removed — the cell
       already shows the letter grade and a numeric restatement adds no
       new information. The factor rows that remain are distinct signals,
       not the aggregate. */
    const lines = [
        l10n('packageDashboard.healthTooltip.grade', { grade: categoryToGrade(r.category) }),
        '',
        l10n('packageDashboard.healthTooltip.resolutionVelocity', { value: String(fmt(r.resolutionVelocity)) }),
        l10n('packageDashboard.healthTooltip.engagementLevel', { value: String(fmt(r.engagementLevel)) }),
        l10n('packageDashboard.healthTooltip.popularity', { value: String(fmt(r.popularity)) }),
        l10n('packageDashboard.healthTooltip.publisherTrust', { value: String(fmt(r.publisherTrust)) }),
    ];
    if (commitAgeDays !== undefined) {
        lines.push(l10n('packageDashboard.healthTooltip.codeCommits', { age: formatAgeFromDays(commitAgeDays) }));
    }
    if (publishAgeDays !== undefined) {
        lines.push(l10n('packageDashboard.healthTooltip.latestRelease', { age: formatAgeFromDays(publishAgeDays) }));
    }
    const dormancy = buildDormancyStatus(commitAgeDays, publishAgeDays);
    if (dormancy) {
        lines.push('', l10n('packageDashboard.healthTooltip.activitySignal', { signal: dormancy }));
    }
    return lines.join('\n');
}

/** Resolve the canonical repository URL (trailing slashes stripped). */
function resolveRepoUrl(r: VibrancyResult): string | undefined {
    return (r.github?.repoUrl ?? r.pubDev?.repositoryUrl)
        ?.replace(/\/+$/, '');
}

/** Build the pub.dev score page URL for a package. */
function pubDevScoreUrl(name: string): string {
    return `https://pub.dev/packages/${encodeURIComponent(name)}/score`;
}

/**
 * Compact number formatter shared by Likes and Downloads cells. Keeps the
 * table narrow for high-traffic packages (e.g. `http` has 8M+ downloads
 * which would blow out the column at full width). The cell's title
 * attribute still exposes the full comma-formatted number for precise
 * inspection.
 */
function formatCompactCount(n: number): string {
    if (n >= 1_000_000) { return `${(n / 1_000_000).toFixed(1)}M`; }
    if (n >= 1_000) { return `${(n / 1_000).toFixed(1)}k`; }
    return String(n);
}

/**
 * Likes cell — pub.dev like count for the package. Replaces the old Stars
 * column. GitHub stars are a repo-level signal, not a package-level one;
 * every package published from a monorepo (firebase/flutterfire,
 * bloclibrary/bloc, flutter/packages, ...) reported the same star count,
 * which was misleading and prompted this switch. Likes are per-package and
 * so give a true per-row comparison. The number links to the package's
 * pub.dev /score tab, which shows likes alongside downloads and pub points.
 */
function buildLikesCell(r: VibrancyResult): string {
    const likes = r.likes;
    const href = pubDevScoreUrl(r.package.name);
    if (likes == null) {
        return `<td class="cell-right" title="${escapeHtml(l10n('packageDashboard.cells.likesUnavailable'))}"><a href="${href}"><span class="dimmed">\u2014</span></a></td>`;
    }
    const full = likes.toLocaleString('en-US');
    const compact = formatCompactCount(likes);
    return `<td class="cell-right" title="${escapeHtml(l10n('packageDashboard.cells.likesCount', { count: full }))}">`
        + `<a href="${href}">${escapeHtml(compact)}</a></td>`;
}

/**
 * Downloads cell — pub.dev `downloadCount30Days` for the package. Per-
 * package trust signal, surfaced from the same score API response that
 * populates Likes. Null when the score API failed or did not return the
 * field (e.g. older registry mirrors that predate the feature).
 */
function buildDownloadsCell(r: VibrancyResult): string {
    const downloads = r.downloadCount30Days;
    const href = pubDevScoreUrl(r.package.name);
    if (downloads == null) {
        return `<td class="cell-right" title="${escapeHtml(l10n('packageDashboard.cells.downloadsUnavailable'))}"><a href="${href}"><span class="dimmed">\u2014</span></a></td>`;
    }
    const full = downloads.toLocaleString('en-US');
    const compact = formatCompactCount(downloads);
    return `<td class="cell-right" title="${escapeHtml(l10n('packageDashboard.cells.downloadsCount', { count: full }))}">`
        + `<a href="${href}">${escapeHtml(compact)}</a></td>`;
}

function buildIssuesCell(r: VibrancyResult): string {
    const count = r.github?.trueOpenIssues ?? r.github?.openIssues;
    if (count == null) {
        return `<td class="cell-right" title="${escapeHtml(l10n('packageDashboard.cells.noGithub'))}"><span class="dimmed">\u2014</span></td>`;
    }
    const repoUrl = resolveRepoUrl(r);
    if (repoUrl) {
        return `<td class="cell-right"><a href="${escapeHtml(repoUrl)}/issues">${count.toLocaleString('en-US')}</a></td>`;
    }
    return `<td class="cell-right">${count.toLocaleString('en-US')}</td>`;
}

function buildPrsCell(r: VibrancyResult): string {
    const count = r.github?.openPullRequests;
    if (count == null) {
        return `<td class="cell-right" title="${escapeHtml(l10n('packageDashboard.cells.noGithub'))}"><span class="dimmed">\u2014</span></td>`;
    }
    const repoUrl = resolveRepoUrl(r);
    if (repoUrl) {
        return `<td class="cell-right"><a href="${escapeHtml(repoUrl)}/pulls">${count.toLocaleString('en-US')}</a></td>`;
    }
    return `<td class="cell-right">${count.toLocaleString('en-US')}</td>`;
}

function buildSizeCell(r: VibrancyResult): string {
    /* Prefer codeSizeBytes — what the package actually contributes to a built
       app (`lib/` + declared `flutter.assets:`). Falls back to the gzipped
       tarball size only when the analyzer couldn't run, so the cell is never
       blank when ANY size info is available. The earlier model used
       archiveSizeBytes here and over-reported by 100x+ for packages that ship
       example media (audioplayers showed ~20 MB when the real contribution is
       ~40 KB). See plans/history/2026.05/2026.05.13/
       infra_vibrancy_bloat_uses_tarball_size_not_runtime.md. */
    const own = r.codeSizeBytes ?? r.archiveSizeBytes;
    if (own === null) {
        return `<td class="cell-right size-cell" title="${escapeHtml(l10n('packageDashboard.cells.sizeUnavailable'))}"><span class="dimmed">—</span></td>`;
    }
    // Render three precomputed labels — the toolbar toggle picks which one is
    // visible by toggling a class on the table. This avoids re-running format
    // logic in JS on every toggle.
    const uniqueT = r.transitiveInfo?.uniqueTransitiveSizeBytes ?? 0;
    const sharedT = r.transitiveInfo?.sharedTransitiveSizeBytes ?? 0;
    const ownLabel = formatSizeKB(own);
    const uniqueLabel = formatSizeKB(own + uniqueT);
    const totalLabel = formatSizeKB(own + uniqueT + sharedT);
    /* Tooltip discloses whether we're showing code-size (analyzer ran) or the
       tarball fallback so the developer can tell the cases apart. When both
       differ, surface the on-disk total too so the asymmetry (e.g. 40 KB code
       / 20 MB on disk) is visible without leaving the dashboard. */
    const sizeKindLabel = r.codeSizeBytes !== null
        ? l10n('packageDashboard.size.codeSize', { size: ownLabel })
        : l10n('packageDashboard.size.archiveSize', { size: ownLabel });
    const tooltipParts: string[] = [sizeKindLabel];
    if (r.archiveSizeBytes !== null && r.codeSizeBytes !== null
        && r.archiveSizeBytes !== r.codeSizeBytes) {
        tooltipParts.push(l10n('packageDashboard.size.onDisk', { size: formatSizeMB(r.archiveSizeBytes) }));
    }
    if (r.transitiveInfo && r.transitiveInfo.transitiveCount > 0) {
        tooltipParts.push(l10n('packageDashboard.size.withUniqueTransitives', { size: uniqueLabel }));
        tooltipParts.push(l10n('packageDashboard.size.withSharedTransitives', { size: totalLabel }));
    }
    const tooltip = tooltipParts.join('\n');
    const packageName = escapeHtml(r.package.name);
    const openFolderTitle = escapeHtml(l10n('packageDashboard.size.openFolder'));
    return `<td class="cell-right size-cell" title="${escapeHtml(tooltip)}"
        data-size-own="${own}" data-size-unique="${own + uniqueT}" data-size-total="${own + uniqueT + sharedT}">`
        + `<span class="size-link size-own" data-pkg="${packageName}" title="${openFolderTitle}">${ownLabel}</span>`
        + `<span class="size-link size-unique" data-pkg="${packageName}" title="${openFolderTitle}">${uniqueLabel}</span>`
        + `<span class="size-link size-total" data-pkg="${packageName}" title="${openFolderTitle}">${totalLabel}</span>`
        + `</td>`;
}

/** References column: click count to search for imports of this package. */
function buildReferencesCell(r: VibrancyResult): string {
    const active = activeFileUsages(r.fileUsages);
    const count = active.length;
    if (count === 0) {
        return `<td class="cell-right" title="${escapeHtml(l10n('packageDashboard.references.noImports'))}"><span class="dimmed">\u2014</span></td>`;
    }
    // Single-use = muted; 6+ = bold (deeply embedded). A re-export overrides
    // single-use styling so it doesn't read as "easy to remove".
    const isReExport = hasActiveReExport(r.fileUsages);
    const cls = isReExport ? '' /* re-export = full-strength, never muted */
        : count === 1 ? ' file-single'
        : count >= 6 ? ' file-deep'
        : '';
    // Mark re-export lines in the multi-line tooltip so the user sees which
    // file is exposing the package as part of its public API. A file that
    // both imports and re-exports the same package (deduplicated into one
    // usage) renders as two tooltip rows so the user still sees both
    // directive locations — the count on the cell is just the file count.
    const tooltipLines: string[] = [];
    const refEntries: Array<{ path: string; line: number; label: string }> = [];
    for (const u of active) {
        if (u.exportLine != null) {
            const label = l10n('packageDashboard.references.reExportLine', {
                location: `${u.filePath}:${u.exportLine}`,
            });
            tooltipLines.push(label);
            refEntries.push({ path: u.filePath, line: u.exportLine, label });
        }
        if (u.importLine != null) {
            const label = `${u.filePath}:${u.importLine}`;
            tooltipLines.push(label);
            refEntries.push({ path: u.filePath, line: u.importLine, label });
        }
        // Fallback for fixtures that don't populate the directive lines.
        if (u.exportLine == null && u.importLine == null) {
            const location = `${u.filePath}:${u.line}`;
            const label = u.isExport
                ? l10n('packageDashboard.references.reExportLine', { location })
                : location;
            tooltipLines.push(label);
            refEntries.push({ path: u.filePath, line: u.line, label });
        }
    }
    if (isReExport) {
        tooltipLines.unshift(l10n('packageDashboard.references.publicApiSurface'), '');
    }
    const tooltip = tooltipLines.join('\n');
    const name = escapeHtml(r.package.name);
    // Tiny badge after the count when re-exported — the whole table is dense
    // so we keep this to a single character ("\u21AA" leftwards arrow with
    // hook = "exposed onward").
    const reexportBadge = isReExport
        ? ` <span class="ref-reexport-badge" title="${escapeHtml(l10n('packageDashboard.references.reExportedBadge'))}">\u21AA</span>`
        : '';
    const refsData = encodeURIComponent(JSON.stringify(refEntries.slice(0, 50)));
    return `<td class="cell-right refs-cell${cls}" title="${escapeHtml(tooltip)}">`
        + `<span class="ref-link" data-pkg="${name}" data-refs="${refsData}" title="${escapeHtml(l10n('packageDashboard.references.openFileReferences'))}">${count}</span>${reexportBadge}`
        + `</td>`;
}

function buildTransitivesCell(
    r: VibrancyResult,
    tablePackageNames: ReadonlySet<string>,
): string {
    const count = r.transitiveInfo?.transitiveCount ?? 0;
    const flagged = r.transitiveInfo?.flaggedCount ?? 0;
    if (count === 0) {
        return `<td class="cell-right transitives-cell" title="${escapeHtml(l10n('packageDashboard.deps.noTransitives'))}"><span class="dimmed">\u2014</span></td>`;
    }
    const info = r.transitiveInfo!;
    const depList = info.transitives
        .filter(dep => tablePackageNames.has(dep))
        .join(',');
    const text = flagged > 0 ? `${count} (${flagged}\u26A0)` : `${count}`;
    const cls = flagged > 0 ? ' transitive-flagged' : '';
    return `<td class="cell-right transitives-cell${cls}">`
        + `<span class="dep-list-link" data-pkg="${escapeHtml(r.package.name)}" data-deps="${escapeHtml(depList)}" title="${escapeHtml(l10n('packageDashboard.deps.showTransitives'))}">${text}</span>`
        + `</td>`;
}

function buildVulnsCell(r: VibrancyResult): string {
    const count = r.vulnerabilities.length;
    const worst = worstSeverity(r.vulnerabilities);
    if (count === 0) { return `<td title="${escapeHtml(l10n('packageDashboard.cells.noVulnerabilities'))}"><span class="dimmed">\u2014</span></td>`; }
    const emoji = worst ? severityEmoji(worst) : '';
    const label = worst ? severityLabel(worst) : '';
    const cls = worst ? ` class="vuln-${worst}"` : '';
    return `<td${cls}>${emoji} ${count} (${label})</td>`;
}

function buildLicenseCell(r: VibrancyResult): string {
    const license = r.license;
    if (!license) { return `<td title="${escapeHtml(l10n('packageDashboard.cells.licenseUnspecified'))}"><span class="dimmed">\u2014</span></td>`; }
    const name = encodeURIComponent(r.package.name);
    const url = `https://pub.dev/packages/${name}/license`;
    return `<td><a href="${url}">${escapeHtml(license)}</a></td>`;
}

function buildUpdateCell(r: VibrancyResult): string {
    /* Must match client-side matchesCardFilter 'updates' case in report-script.ts. */
    const hasUpdate = r.updateInfo
        && r.updateInfo.updateStatus !== 'up-to-date'
        && r.updateInfo.updateStatus !== 'unknown';
    const name = encodeURIComponent(r.package.name);
    const url = `https://pub.dev/packages/${name}/changelog`;
    if (!hasUpdate) { return '<td class="cell-right"><span class="dimmed">\u2013</span></td>'; }
    const text = escapeHtml(`\u2192 ${r.updateInfo!.latestVersion}`);
    const cls = getUpdateClass(r.updateInfo!.updateStatus);
    return `<td class="cell-right ${cls}"><a href="${url}">${text}</a></td>`;
}

function getUpdateClass(status: string): string {
    if (status === 'major') { return 'update-major'; }
    if (status === 'minor') { return 'update-minor'; }
    if (status === 'patch') { return 'update-patch'; }
    return '';
}

function buildStatusCell(r: VibrancyResult): string {
    if (r.isUnused) {
        return `<td><span class="badge-unused">${escapeHtml(l10n('packageDashboard.cells.unusedBadge'))}</span></td>`;
    }
    return `<td title="${escapeHtml(l10n('packageDashboard.cells.packageInUse'))}"><span class="dimmed">\u2014</span></td>`;
}

/** Plain-text description cell (hidable, starts collapsed). */
function buildDescCell(r: VibrancyResult): string {
    const desc = r.pubDev?.description;
    if (!desc) { return '<td class="desc-text"><span class="dimmed">\u2014</span></td>'; }
    return `<td class="desc-text" title="${escapeHtml(desc)}">${escapeHtml(desc)}</td>`;
}

/** Deps column: icon showing transitive dep count, with shared deps highlighted. */
function buildDepsCell(
    r: VibrancyResult,
    tablePackageNames: ReadonlySet<string>,
): string {
    const info = r.transitiveInfo;
    if (!info || info.transitiveCount === 0) {
        return `<td class="cell-right deps-cell" title="${escapeHtml(l10n('packageDashboard.deps.noTransitives'))}"><span class="dimmed">\u2014</span></td>`;
    }
    const total = info.transitiveCount;
    const shared = info.sharedDeps.length;
    const linkedDeps = info.transitives.filter(dep => tablePackageNames.has(dep));
    /* Build a tooltip listing all transitive deps, marking shared ones. */
    const depLines = linkedDeps.map(dep => {
        const isShared = info.sharedDeps.includes(dep);
        return isShared
            ? l10n('packageDashboard.deps.tooltipDepShared', { dep })
            : l10n('packageDashboard.deps.tooltipDep', { dep });
    });
    const tooltipHeader = shared > 0
        ? l10n('packageDashboard.deps.tooltipHeaderShared', { total: String(total), shared: String(shared) })
        : l10n('packageDashboard.deps.tooltipHeader', { total: String(total) });
    const tooltip = `${tooltipHeader}\n${depLines.join('\n')}`;
    /* Render the transitive count as a plain number (no tree emoji — it read as
       decorative noise in a dense table); append a shared-deps badge when any
       transitive is also pulled in by another package. */
    const sharedBadge = shared > 0
        ? ` <span class="badge-shared" title="${escapeHtml(l10n('packageDashboard.deps.sharedBadgeTitle', { count: String(shared) }))}">${shared}s</span>`
        : '';
    const depList = linkedDeps.join(',');
    return `<td class="cell-right deps-cell" title="${escapeHtml(tooltip)}">`
        + `<span class="dep-list-link" data-pkg="${escapeHtml(r.package.name)}" data-deps="${escapeHtml(depList)}">${total}${sharedBadge}</span>`
        + `</td>`;
}

function computePublishedAgeMonths(isoDate: string | null): number | null {
    if (!isoDate) { return null; }
    const ms = Date.parse(isoDate);
    if (isNaN(ms)) { return null; }
    const from = new Date(ms);
    const now = new Date();
    const years = now.getUTCFullYear() - from.getUTCFullYear();
    const monthsDelta = now.getUTCMonth() - from.getUTCMonth();
    let months = years * 12 + monthsDelta;
    if (now.getUTCDate() < from.getUTCDate()) {
        months -= 1;
    }
    return Math.max(0, months);
}

/** Expandable detail card shown when a row is expanded. Contains score
 *  breakdown, vulnerability list, file usages, and dependency tree. */
function buildDetailCard(r: VibrancyResult): string {
    const sections: string[] = [];

    /* Score breakdown */
    sections.push(buildDetailScoreSection(r));

    /* Vulnerabilities */
    if (r.vulnerabilities.length > 0) {
        sections.push(buildDetailVulnSection(r));
    }

    /* File usages */
    const active = activeFileUsages(r.fileUsages);
    if (active.length > 0) {
        sections.push(buildDetailFilesSection(r, active));
    }

    /* Transitive dependency tree */
    if (r.transitiveInfo && r.transitiveInfo.transitiveCount > 0) {
        sections.push(buildDetailDepsSection(r));
    }

    /* Links */
    sections.push(buildDetailLinksSection(r));

    return `<div class="detail-card">${sections.join('')}</div>`;
}

function buildDetailScoreSection(r: VibrancyResult): string {
    const fmt = (v: number) => Math.round(v);
    const grade = categoryToGrade(r.category);
    const publishAgeDays = daysSinceIsoDate(r.pubDev?.publishedDate);
    const commitAgeDays = r.github?.daysSinceLastCommit;
    const activityRows: string[] = [];
    if (commitAgeDays !== undefined) {
        activityRows.push(`<span class="detail-label">${escapeHtml(l10n('packageDashboard.detail.codeCommitActivity'))}</span><span>${escapeHtml(l10n('packageDashboard.detail.ago', { age: formatAgeFromDays(commitAgeDays) }))}</span>`);
    }
    if (publishAgeDays !== undefined) {
        activityRows.push(`<span class="detail-label">${escapeHtml(l10n('packageDashboard.detail.releaseActivity'))}</span><span>${escapeHtml(l10n('packageDashboard.detail.ago', { age: formatAgeFromDays(publishAgeDays) }))}</span>`);
    }
    const dormancy = buildDormancyStatus(commitAgeDays, publishAgeDays);
    if (dormancy) {
        activityRows.push(`<span class="detail-label">${escapeHtml(l10n('packageDashboard.detail.dormancySignal'))}</span><span>${escapeHtml(dormancy)}</span>`);
    }
    /* Maintainer-quality bonus rows — each of `example/`, `test/`, `tool/`,
       `doc/` is a positive component on the health score (NOT a bloat
       penalty as the old tarball-size model treated them). Each present
       flag adds a row so the developer can see why the score moved.
       Absent flags don't render — they're non-contributions, not penalties.
       See plans/history/2026.05/2026.05.13/
       infra_vibrancy_bloat_uses_tarball_size_not_runtime.md. */
    const qualityRows: string[] = [];
    if (r.maintainerQuality) {
        const q = r.maintainerQuality;
        if (q.hasExample) {
            qualityRows.push(`<span class="detail-label">${escapeHtml(l10n('packageDashboard.detail.qualityExample'))}</span><span title="${escapeHtml(l10n('packageDashboard.detail.qualityExampleTitle'))}">+</span>`);
        }
        if (q.hasTests) {
            qualityRows.push(`<span class="detail-label">${escapeHtml(l10n('packageDashboard.detail.qualityTests'))}</span><span title="${escapeHtml(l10n('packageDashboard.detail.qualityTestsTitle'))}">+</span>`);
        }
        if (q.hasTools) {
            qualityRows.push(`<span class="detail-label">${escapeHtml(l10n('packageDashboard.detail.qualityTools'))}</span><span title="${escapeHtml(l10n('packageDashboard.detail.qualityToolsTitle'))}">+</span>`);
        }
        if (q.hasDocs) {
            qualityRows.push(`<span class="detail-label">${escapeHtml(l10n('packageDashboard.detail.qualityDocs'))}</span><span title="${escapeHtml(l10n('packageDashboard.detail.qualityDocsTitle'))}">+</span>`);
        }
    }
    /* The "Overall" numeric row was removed — it was the same info as the
       header grade letter, just shown as a /10. The factor rows below stay
       because they're distinct dimensions, not the same aggregate. */
    return `<div class="detail-section">
        <h4>${escapeHtml(l10n('packageDashboard.detail.healthScore'))} <span class="grade-badge grade-${grade}">${grade}</span></h4>
        <div class="detail-grid">
            <span class="detail-label">${escapeHtml(l10n('packageDashboard.detail.resolutionVelocity'))}</span><span>${fmt(r.resolutionVelocity)}</span>
            <span class="detail-label">${escapeHtml(l10n('packageDashboard.detail.engagementLevel'))}</span><span>${fmt(r.engagementLevel)}</span>
            <span class="detail-label">${escapeHtml(l10n('packageDashboard.detail.popularity'))}</span><span>${fmt(r.popularity)}</span>
            <span class="detail-label">${escapeHtml(l10n('packageDashboard.detail.publisherTrust'))}</span><span>${fmt(r.publisherTrust)}</span>
            ${activityRows.join('')}
            ${qualityRows.join('')}
        </div>
    </div>`;
}

function daysSinceIsoDate(isoDate: string | null | undefined): number | undefined {
    if (!isoDate) { return undefined; }
    const ms = Date.parse(isoDate);
    if (isNaN(ms)) { return undefined; }
    return Math.max(0, Math.floor((Date.now() - ms) / 86_400_000));
}

function formatAgeFromDays(days: number): string {
    if (days < 30) { return `${days}d`; }
    if (days < 365) { return `${Math.floor(days / 30)}mo`; }
    return `${Math.floor(days / 365)}y`;
}

function buildDormancyStatus(
    commitAgeDays: number | undefined,
    publishAgeDays: number | undefined,
): string | null {
    if (commitAgeDays === undefined || publishAgeDays === undefined) {
        return null;
    }
    if (commitAgeDays >= 180 && publishAgeDays >= 180) {
        return l10n('packageDashboard.dormancy.noActivity6mo');
    }
    if (commitAgeDays >= 90 && publishAgeDays >= 90) {
        return l10n('packageDashboard.dormancy.noActivity3mo');
    }
    if (commitAgeDays >= 90 && publishAgeDays < 90) {
        return l10n('packageDashboard.dormancy.releaseActiveCodeInactive');
    }
    if (commitAgeDays < 90 && publishAgeDays >= 90) {
        return l10n('packageDashboard.dormancy.codeActiveReleaseSlow');
    }
    return null;
}

function computeActivitySignal(r: VibrancyResult): {
    score: number | null;
    grade: ReturnType<typeof scoreToGrade> | null;
    message: string | null;
    sortValue: string;
} {
    const publishAgeDays = daysSinceIsoDate(r.pubDev?.publishedDate);
    const commitAgeDays = r.github?.daysSinceLastCommit;
    if (publishAgeDays === undefined || commitAgeDays === undefined) {
        return { score: null, grade: null, message: null, sortValue: '' };
    }
    // Activity score focuses on "is code/release work still happening now?"
    // so both timelines use a 90-day decay and the worst leg dominates.
    const commitScore = Math.max(0, 100 - (commitAgeDays * 100 / 90));
    const releaseScore = Math.max(0, 100 - (publishAgeDays * 100 / 90));
    const score = Math.round(Math.min(commitScore, releaseScore));
    const grade = scoreToGrade(score);
    const dormancy = buildDormancyStatus(commitAgeDays, publishAgeDays);
    const message = dormancy
        ? l10n('packageDashboard.activity.withDormancy', { dormancy, grade })
        : l10n('packageDashboard.activity.healthy', { grade });
    return { score, grade, message, sortValue: String(score) };
}

function buildDetailVulnSection(r: VibrancyResult): string {
    const rows = r.vulnerabilities.map(v => {
        const sev = v.severity ? `<span class="vuln-${v.severity}">${severityLabel(v.severity)}</span>` : '';
        const link = v.url ? `<a href="${escapeHtml(v.url)}">${escapeHtml(v.id)}</a>` : escapeHtml(v.id);
        const fix = v.fixedVersion
            ? ` ${escapeHtml(l10n('packageDashboard.detail.fixInVersion', { version: v.fixedVersion }))}`
            : '';
        return `<div class="vuln-row">${sev} ${link}: ${escapeHtml(v.summary ?? '')}${fix}</div>`;
    });
    return `<div class="detail-section">
        <h4>${escapeHtml(l10n('packageDashboard.detail.vulnerabilitiesHeading', { count: String(r.vulnerabilities.length) }))}</h4>
        ${rows.join('\n')}
    </div>`;
}

function buildDetailFilesSection(
    r: VibrancyResult,
    active: ReturnType<typeof activeFileUsages>,
): string {
    const name = escapeHtml(r.package.name);
    // Each usage is one source file after the scanner dedupe. Render a
    // row per directive kind (import / export) that the file contains so
    // both line locations stay visible even though the header count is
    // now files-not-directives. Files without the split fields fall back
    // to the pre-dedupe single-line display.
    const fileList = active.slice(0, 20).flatMap(u => {
        const rows: string[] = [];
        const path = escapeHtml(u.filePath);
        if (u.exportLine != null) {
            rows.push(`<div class="file-row"><span class="file-link" data-path="${path}" data-line="${u.exportLine}">${path}:${u.exportLine}</span> ${escapeHtml(l10n('packageDashboard.references.reExportSuffix'))}</div>`);
        }
        if (u.importLine != null) {
            rows.push(`<div class="file-row"><span class="file-link" data-path="${path}" data-line="${u.importLine}">${path}:${u.importLine}</span></div>`);
        }
        if (u.exportLine == null && u.importLine == null) {
            rows.push(`<div class="file-row"><span class="file-link" data-path="${path}" data-line="${u.line}">${path}:${u.line}</span></div>`);
        }
        return rows;
    }).join('\n');
    const more = active.length > 20
        ? `<div class="dimmed">${escapeHtml(l10n('packageDashboard.references.andMore', { count: String(active.length - 20) }))}</div>` : '';
    return `<div class="detail-section">
        <h4>${escapeHtml(l10n('packageDashboard.references.fileReferencesHeading', { count: String(active.length) }))} <span class="ref-link detail-search-link" data-pkg="${name}" title="${escapeHtml(l10n('packageDashboard.references.searchImports'))}">\u{1F50D}</span></h4>
        ${fileList}${more}
    </div>`;
}

function buildDetailDepsSection(r: VibrancyResult): string {
    const info = r.transitiveInfo!;
    const depItems = info.transitives.map(dep => {
        const isShared = info.sharedDeps.includes(dep);
        const cls = isShared ? ' class="dep-shared"' : '';
        const badge = isShared ? ` <span class="badge-shared-sm">${escapeHtml(l10n('packageDashboard.deps.sharedBadge'))}</span>` : '';
        return `<span${cls}>${escapeHtml(dep)}${badge}</span>`;
    });
    return `<div class="detail-section">
        <h4>${escapeHtml(l10n('packageDashboard.deps.transitiveDepsHeading', { count: String(info.transitiveCount) }))}</h4>
        <div class="dep-cloud">${depItems.join(' ')}</div>
    </div>`;
}

function buildDetailLinksSection(r: VibrancyResult): string {
    const name = encodeURIComponent(r.package.name);
    const links: string[] = [
        `<a href="https://pub.dev/packages/${name}">${escapeHtml(l10n('packageDashboard.links.pubDev'))}</a>`,
        `<a href="https://pub.dev/packages/${name}/changelog">${escapeHtml(l10n('packageDashboard.links.changelog'))}</a>`,
        `<a href="https://pub.dev/packages/${name}/versions">${escapeHtml(l10n('packageDashboard.links.versions'))}</a>`,
    ];
    const repoUrl = (r.github?.repoUrl ?? r.pubDev?.repositoryUrl)?.replace(/\/+$/, '');
    if (repoUrl) {
        links.push(`<a href="${escapeHtml(repoUrl)}">${escapeHtml(l10n('packageDashboard.links.repository'))}</a>`);
        links.push(`<a href="${escapeHtml(repoUrl)}/issues">${escapeHtml(l10n('packageDashboard.links.issues'))}</a>`);
    }
    return `<div class="detail-section detail-links">
        <h4>${escapeHtml(l10n('packageDashboard.links.heading'))}</h4>
        <div class="link-list">${links.join(' \u2022 ')}</div>
    </div>`;
}

// ---------------------------------------------------------------------------
// Copy-as-JSON data map
// ---------------------------------------------------------------------------

/** Build a script block embedding per-package JSON for the copy button. */
function buildPackageDataScript(
    results: VibrancyResult[],
    overrideNames: ReadonlySet<string>,
    repoShareMap: ReadonlyMap<string, number>,
): string {
    const entries = results.map(r => {
        const key = JSON.stringify(r.package.name);
        const val = JSON.stringify(buildPackageJson(r, overrideNames, repoShareMap));
        return `${key}:${val}`;
    });
    /* Escape < to \u003c so embedded JSON cannot break out of the script tag */
    const raw = `var packageData={${entries.join(',')}};`;
    return raw.replace(/</g, '\\u003c');
}

/**
 * Build the `stars` JSON block: the raw GitHub star count paired with the
 * canonical repo URL and a monorepo-sibling count. Repo stars are not a
 * reliable per-package signal because every package in a monorepo
 * (firebase/flutterfire, bloclibrary/bloc, flutter/packages, ...) reports
 * the same number. We still surface the count because it's useful context
 * for the repo as a whole, but we pair it with `repoUrl` (so consumers can
 * click through) and `monorepoSiblings` (so they can discount the number
 * when >0). Returns null when no GitHub data was fetched.
 */
function buildStarsBlock(
    r: VibrancyResult,
    repoShareMap: ReadonlyMap<string, number>,
): { count: number; repoUrl: string | null; monorepoSiblings: number } | null {
    const count = r.github?.stars;
    if (count == null) { return null; }
    const repoUrl = resolveRepoUrl(r) ?? null;
    /* `repoShareMap` counts how many results resolve to the same repo URL;
       subtract this row to get the number of OTHER packages in the project
       sharing the repo. 0 siblings = dedicated repo, so the star count is
       reliable per-package. */
    const shared = repoUrl ? (repoShareMap.get(repoUrl) ?? 1) - 1 : 0;
    return { count, repoUrl, monorepoSiblings: Math.max(0, shared) };
}

/** Build a comprehensive JSON-safe object for one package row. */
function buildPackageJson(
    r: VibrancyResult,
    overrideNames: ReadonlySet<string>,
    repoShareMap: ReadonlyMap<string, number>,
): Record<string, unknown> {
    const name = r.package.name;
    const encoded = encodeURIComponent(name);
    const activeFiles = activeFileUsages(r.fileUsages);
    const repoBase = resolveRepoUrl(r) ?? null;
    const activity = computeActivitySignal(r);
    return {
        name,
        version: r.package.version,
        constraint: r.package.constraint,
        section: r.package.section,
        isOverridden: overrideNames.has(name),
        health: {
            score: Math.round(r.score / 10),
            grade: categoryToGrade(r.category),
            resolutionVelocity: Math.round(r.resolutionVelocity),
            engagementLevel: Math.round(r.engagementLevel),
            popularity: Math.round(r.popularity),
            publisherTrust: Math.round(r.publisherTrust),
            activityScore: activity.score,
            activityGrade: activity.grade,
        },
        category: categoryLabel(r.category),
        published: r.pubDev?.publishedDate.split('T')[0] ?? null,
        /* Per-package pub.dev signals (what the Likes / Downloads table
           columns now show). These are the primary trust indicators we
           expose in the report because, unlike repo stars, they measure
           this specific package. */
        likes: r.likes ?? null,
        downloadCount30Days: r.downloadCount30Days ?? null,
        /* Repo-level context retained for consumers that still want the
           GitHub star count, paired with the repo URL and the count of
           other project packages sharing the same repo (monorepo
           detection). See buildStarsBlock for the rationale. */
        stars: buildStarsBlock(r, repoShareMap),
        openIssues: r.github?.trueOpenIssues ?? r.github?.openIssues ?? null,
        openPullRequests: r.github?.openPullRequests ?? null,
        /* Exported JSON keeps both fields so consumers can tell code size
           (what reaches the app) from on-disk archive (the gzipped tarball).
           `archiveSize` retained for backwards-compatibility with existing
           downstream parsers; `codeSize` is the new authoritative number. */
        codeSize: r.codeSizeBytes !== null ? formatSizeKB(r.codeSizeBytes) : null,
        archiveSize: r.archiveSizeBytes !== null
            ? formatSizeKB(r.archiveSizeBytes) : null,
        license: r.license ?? null,
        update: r.updateInfo ? {
            status: r.updateInfo.updateStatus,
            latestVersion: r.updateInfo.latestVersion,
        } : null,
        isUnused: r.isUnused,
        fileCount: activeFiles.length,
        // One entry per source file. Now that the scanner dedupes by
        // (filePath, isCommented), a file that both imports and
        // re-exports the same package is a single object with both
        // `import` and `export` line numbers populated — previously it
        // showed up as two separate `"path:line"` strings, which made
        // `fileCount` double-count the file.
        files: activeFiles.map(u => {
            const entry: Record<string, unknown> = { path: u.filePath };
            if (u.importLine != null) { entry.import = u.importLine; }
            if (u.exportLine != null) { entry.export = u.exportLine; }
            return entry;
        }),
        transitives: r.transitiveInfo ? {
            count: r.transitiveInfo.transitiveCount,
            flagged: r.transitiveInfo.flaggedCount,
            // Full dep list + shared markers mirrors the expander's
            // "Transitive Dependencies" section so the JSON has
            // everything the expander reveals visually.
            deps: [...r.transitiveInfo.transitives],
            sharedDeps: [...r.transitiveInfo.sharedDeps],
        } : null,
        vulnerabilities: r.vulnerabilities.map(v => ({
            id: v.id,
            summary: v.summary,
            severity: v.severity,
            cvssScore: v.cvssScore,
            fixedVersion: v.fixedVersion,
            url: v.url,
        })),
        description: r.pubDev?.description ?? null,
        platforms: r.platforms ?? null,
        verifiedPublisher: r.verifiedPublisher,
        wasmReady: r.wasmReady,
        links: {
            pubDev: `https://pub.dev/packages/${encoded}`,
            versions: `https://pub.dev/packages/${encoded}/versions`,
            /* Score page is the destination for the Likes / Downloads
               cells; including it here lets JSON consumers jump to the
               same view without rebuilding the URL. */
            score: `https://pub.dev/packages/${encoded}/score`,
            license: `https://pub.dev/packages/${encoded}/license`,
            changelog: `https://pub.dev/packages/${encoded}/changelog`,
            repository: r.pubDev?.repositoryUrl ?? null,
            issues: repoBase ? `${repoBase}/issues` : null,
            pullRequests: repoBase ? `${repoBase}/pulls` : null,
        },
    };
}
