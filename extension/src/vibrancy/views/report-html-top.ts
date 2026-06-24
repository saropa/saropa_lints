/**
 * Top-chrome builders for the package-vibrancy report: the hero radial gauge,
 * the "Scanned X ago" status pill, the scan-in-progress placeholder, the
 * "why this grade?" breakdown panel, the summary KPI cards, and the
 * search/filter toolbar. The report-html.ts composer assembles these above
 * the package table.
 */

import { VibrancyResult, activeFileUsages, hasActiveReExport } from '../types';
import { countByCategory, scoreToGrade } from '../scoring/status-classifier';
import { formatSizeMB } from '../scoring/bloat-calculator';
import { createWebviewCspNonce, escapeHtml } from './html-utils';
import { StatusPill } from '../../views/dashboardHero';
import { l10n } from '../../i18n/runtime';
import { ReportOptions } from './report-html-shared';

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
export function buildLastScanPill(ts?: number): StatusPill {
    // Clicking the pill rescans the dashboard AND re-checks pub.dev for a newer
    // saropa_lints version (re-surfacing the upgrade notification). The id is
    // wired by getReportScript().
    if (typeof ts !== 'number' || !Number.isFinite(ts) || ts <= 0) {
        return {
            glyph: '⟳',
            label: l10n('packageDashboard.status.lastScanUnknown'),
            title: l10n('packageDashboard.status.lastScanUnknownTitle'),
            tone: 'neutral',
            actionId: 'lastScanRescan',
        };
    }
    return {
        glyph: '⟳',
        label: l10n('packageDashboard.status.lastScanLabel', { when: formatScanRelative(ts) }),
        title: l10n('packageDashboard.status.lastScanTitle', {
            timestamp: new Date(ts).toLocaleString(),
        }),
        tone: 'neutral',
        actionId: 'lastScanRescan',
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

/**
 * Empty-state placeholder shown while the first scan is running.  Kept
 * deliberately simple: no chart, no table, no gauge — just a plainly
 * worded card so first-time users know the extension is doing real work
 * and roughly how long to wait.  Uses the same VS Code theme tokens as
 * the real dashboard so it doesn't look out of place.  No script tag
 * because there is nothing interactive to drive yet — the open panel
 * auto-refreshes from `publishResults` when the scan finishes.
 */
export function buildScanInProgressHtml(options: ReportOptions): string {
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
export function buildRadialGauge(avgScore: number): string {
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
export function buildGradeBreakdown(results: readonly VibrancyResult[], avgScore: number): string {
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

export function buildReportSummary(options: ReportOptions): string {
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
        <div class="summary-card vibrant" data-filter="vibrant" role="button" tabindex="0" title="${escapeHtml(gradeTitle('vibrantTitle'))}"><div class="count">${counts.vibrant}</div><div class="label">A</div></div>
        <div class="summary-card stable" data-filter="stable" role="button" tabindex="0" title="${escapeHtml(gradeTitle('stableTitle'))}"><div class="count">${counts.stable}</div><div class="label">B</div></div>
        <div class="summary-card outdated" data-filter="outdated" role="button" tabindex="0" title="${escapeHtml(gradeTitle('outdatedTitle'))}"><div class="count">${counts.outdated}</div><div class="label">C</div></div>
        <div class="summary-card abandoned" data-filter="abandoned" role="button" tabindex="0" title="${escapeHtml(gradeTitle('abandonedTitle'))}"><div class="count">${counts.abandoned}</div><div class="label">E</div></div>
        <div class="summary-card eol" data-filter="end-of-life" role="button" tabindex="0" title="${escapeHtml(gradeTitle('eolTitle'))}"><div class="count">${counts.eol}</div><div class="label">F</div></div>
        <div class="summary-card updates" data-filter="updates" role="button" tabindex="0"><div class="count">${updates}</div><div class="label">${escapeHtml(l10n('packageDashboard.summary.updates'))}</div></div>
        <div class="summary-card unused" data-filter="unused" role="button" tabindex="0"><div class="count">${results.filter(r => r.isUnused).length}</div><div class="label">${escapeHtml(l10n('packageDashboard.summary.unused'))}</div></div>
        ${singleUse > 0 ? `<div class="summary-card single-use" data-filter="single-use" role="button" tabindex="0"><div class="count">${singleUse}</div><div class="label">${escapeHtml(l10n('packageDashboard.summary.singleUse'))}</div></div>` : ''}
        <div class="summary-card vulns" data-filter="vulns" role="button" tabindex="0"><div class="count">${vulnPackages}</div><div class="label">${escapeHtml(l10n('packageDashboard.summary.vulnerable'))}</div></div>
        <div class="summary-card overrides" data-filter="overrides" role="button" tabindex="0"><div class="count">${overrideCount}</div><div class="label">${escapeHtml(l10n('packageDashboard.summary.overrides'))}</div></div>
    </div>`;
}

/**
 * Wrap the toolbar in a collapsible <details> so users can fold the
 * search/filters row away once they have narrowed the table to what they
 * care about. Defaults to open to preserve the existing landing
 * experience — collapse is opt-in. Matches the dashboard's existing
 * disclosure pattern (network section, chart section).
 */
export function buildFiltersSection(options: ReportOptions): string {
    const title = escapeHtml(l10n('packageDashboard.sections.filters'));
    return `<details class="filters-section dashboard-collapsible" open>
        <summary><h2>${title}</h2></summary>
        ${buildToolbar(options)}
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
