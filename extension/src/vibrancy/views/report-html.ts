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
import { buildFullWidthToggle, buildStatusLine, getFullWidthToggleScript } from '../../views/dashboardHero';
import {
    buildKeyboardShortcutsButton,
    buildKeyboardShortcutsOverlay,
    getKeyboardShortcutsScript,
    getKeyboardShortcutsStyles,
} from '../../views/keyboard-shortcuts';

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
}

/** Columns that can be auto-hidden when all values are empty or start collapsed. */
type HidableColumn = 'transitives' | 'vulns' | 'status' | 'files' | 'license' | 'description';

/** Build the full HTML for the vibrancy report webview. */
export function buildReportHtml(options: ReportOptions): string {
    const { results } = options;
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
        { glyph: '📦', label: `${totalCount} packages`, title: `${directCount} direct, ${transitives} transitive` },
        { label: `Grade ${overallGrade} · ${avg}/100`, tone: avg >= 75 ? 'good' : avg >= 50 ? 'warn' : 'bad' },
        ...(eolCount > 0 ? [{ label: `${eolCount} flagged`, tone: 'bad' as const, title: 'Abandoned or end-of-life' }] : []),
    ]);
    return `<!DOCTYPE html>
<html lang="en">
<head>
    <title>Saropa Package Dashboard</title>
    <meta charset="UTF-8">
    <!-- 'unsafe-inline' on style-src: radial gauge sets dynamic CSS vars
         (--gauge-target, --gauge-arc) via inline style="..." attributes. CSP
         nonces only authorize <style> blocks, not style attributes — without
         'unsafe-inline' the vars are dropped, the dasharray falls back to 0,
         and the gauge renders as a tiny dot. -->
    <meta http-equiv="Content-Security-Policy"
        content="default-src 'none'; style-src 'nonce-${cspNonce}' 'unsafe-inline'; script-src 'nonce-${cspNonce}';">
    <style nonce="${cspNonce}">${getPillButtonStyles()}${getReportStyles()}${getChartStyles()}${getKeyboardShortcutsStyles()}</style>
</head>
<body>
    <div class="report-header">
        <div class="hero-text">
          <h1>Saropa Package Dashboard <span class="header-version">v${escapeHtml(options.extensionVersion)}</span></h1>
          ${statusLineHtml.replace('</p>', `${buildKeyboardShortcutsButton()}${buildFullWidthToggle()}</p>`)}
        </div>
        ${buildRadialGauge(avg)}
    </div>
    ${buildReportSummary(options)}
    ${buildChartSection(results)}
    ${buildNetworkSection(results)}
    ${buildToolbar(options)}
    ${buildReportTable(results, options.overrideNames, options.packageTrends)}
    ${buildKeyboardShortcutsOverlay([
        { key: '/', label: 'Focus the search field' },
        { key: '↓ / j', label: 'Highlight the next package row' },
        { key: '↑ / k', label: 'Highlight the previous package row' },
        { key: 'Enter / Space', label: 'Toggle the highlighted package detail expander' },
        { key: 'Esc', label: 'Clear focused search; second Esc collapses all expanded rows' },
        { key: 'Alt + ←', label: 'Go back through the package navigation history' },
        { key: '?', label: 'Show this shortcut overlay' },
    ])}
    <script nonce="${cspNonce}">${buildPackageDataScript(results, options.overrideNames, buildRepoShareMap(results))}${getReportScript()}${getChartScript()}(function(){${getFullWidthToggleScript()}${getKeyboardShortcutsScript()}})();</script>
</body>
</html>`;
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
        <summary>Dependency Network</summary>
        <div id="dep-network" data-network="${payload}" class="network-canvas"></div>
    </details>`;
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
    return `<div class="radial-gauge" title="Project Package Grade: ${gradeLabel}">
        <svg viewBox="0 0 88 88" class="gauge-svg">
            <circle cx="44" cy="44" r="${r}" fill="none"
                stroke="var(--vscode-widget-border)" stroke-width="7"
                stroke-dasharray="${arcLength} ${circumference}"
                stroke-dashoffset="0"
                stroke-linecap="round"
                transform="rotate(135 44 44)" />
            <circle cx="44" cy="44" r="${r}" fill="none"
                stroke="${color}" stroke-width="7"
                stroke-dasharray="${filled} ${circumference}"
                stroke-dashoffset="0"
                stroke-linecap="round"
                transform="rotate(135 44 44)"
                class="gauge-fill" style="--gauge-target: ${filled}; --gauge-arc: ${arcLength};" />
        </svg>
        <div class="gauge-label">${gradeLabel}</div>
    </div>`;
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
    const totalOwnBytes = results.reduce(
        (sum, r) => sum + (r.archiveSizeBytes ?? 0), 0,
    );
    const totalUniqueBytes = results.reduce((sum, r) => {
        const own = r.archiveSizeBytes ?? 0;
        const unique = r.transitiveInfo?.uniqueTransitiveSizeBytes ?? 0;
        return sum + own + unique;
    }, 0);
    const totalAllBytes = results.reduce((sum, r) => {
        const own = r.archiveSizeBytes ?? 0;
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

    const gradeTooltip = `Project grade ${avgGrade}\nAverage score: ${Math.round(avgScore)}/100\nPackages: ${results.length}\nA:${counts.vibrant} B:${counts.stable} C:${counts.outdated} E:${counts.abandoned} F:${counts.eol}`;
    return `<div class="summary">
        <div class="summary-card"><div class="count">${results.length}</div><div class="label">Packages</div></div>
        <div class="summary-card" title="${escapeHtml(gradeTooltip)}"><div class="count">${avgGrade}</div><div class="label">Project Package Grade</div></div>
        <div class="summary-card total-size"
            data-total-size-own="${totalOwnBytes}"
            data-total-size-unique="${totalUniqueBytes}"
            data-total-size-total="${totalAllBytes}">
            <div class="count">${totalSize}</div><div class="label">Total Size*</div>
        </div>
        <div class="summary-card vibrant" data-filter="vibrant" title="Vibrant"><div class="count">${counts.vibrant}</div><div class="label">A</div></div>
        <div class="summary-card stable" data-filter="stable" title="Stable"><div class="count">${counts.stable}</div><div class="label">B</div></div>
        <div class="summary-card outdated" data-filter="outdated" title="Outdated"><div class="count">${counts.outdated}</div><div class="label">C</div></div>
        <div class="summary-card abandoned" data-filter="abandoned" title="Abandoned"><div class="count">${counts.abandoned}</div><div class="label">E</div></div>
        <div class="summary-card eol" data-filter="end-of-life" title="End of Life"><div class="count">${counts.eol}</div><div class="label">F</div></div>
        <div class="summary-card updates" data-filter="updates"><div class="count">${updates}</div><div class="label">Updates</div></div>
        <div class="summary-card unused" data-filter="unused"><div class="count">${results.filter(r => r.isUnused).length}</div><div class="label">Unused</div></div>
        ${singleUse > 0 ? `<div class="summary-card single-use" data-filter="single-use"><div class="count">${singleUse}</div><div class="label">Single-use</div></div>` : ''}
        <div class="summary-card vulns" data-filter="vulns"><div class="count">${vulnPackages}</div><div class="label">Vulnerable</div></div>
        <div class="summary-card overrides" data-filter="overrides"><div class="count">${overrideCount}</div><div class="label">Overrides</div></div>
    </div>
    <p class="caveat">*Archive sizes before tree shaking. Actual app size will be smaller.<br>Activity thresholds: 90d = stale, 180d = dormant (commit + release timelines).</p>`;
}

/** Toolbar with search box and pubspec link, placed between chart and table. */
function buildToolbar(options: ReportOptions): string {
    const pubspecBtn = options.pubspecUri
        ? '<button id="open-pubspec" class="toolbar-btn" title="Open pubspec.yaml">&#128196; pubspec.yaml</button>'
        : '';
    // Copies every package row as a JSON array, including all expander
    // content (health factors, vulnerabilities, file references, full
    // transitive dep list with shared flags, links). Same per-package
    // shape as the per-row copy button, just aggregated.
    const copyAllBtn = '<button id="copy-all" class="toolbar-btn" title="Copy report JSON (all rows + details)">&#128203; Copy</button>';
    const saveBtn = '<button id="save-all" class="toolbar-btn" title="Save report JSON to reports/YYYYMMDD/...">&#128190; Save</button>';
    const resetViewBtn = '<button id="reset-view" class="toolbar-btn" title="Reset filters, sort, and saved view state">&#8635; Reset view</button>';
    // Rescan button — invokes saropaLints.packageVibrancy.rescan via the
    // webview message channel so users don't have to leave the report to
    // trigger a refresh after editing pubspec.yaml or running `pub get`.
    // The `rescan` command (not `scan`) clears the per-package pub.dev
    // cache first so the report shows current pub.dev state — without it
    // the 24h cache TTL made the button a silent no-op for fresh entries.
    const rescanBtn = '<button id="rescan" class="toolbar-btn" title="Rescan packages — clears the pub.dev cache and re-fetches versions">&#128260; Rescan</button>';
    // Open another project — file picker → opens the selected
    // pubspec.yaml's folder in a new VS Code window. Useful for
    // diagnosing multiple projects without swapping workspace roots.
    const openOtherBtn = '<button id="open-other" class="toolbar-btn" title="Open another pubspec.yaml\'s project in a new window for Vibrancy scan">&#128194; Open Project\u2026</button>';
    // Footprint-mode toggle controls what the Size column shows:
    //   own     = archive size of the package itself (default; matches old behavior)
    //   unique  = own + transitives used ONLY by this dep (cost saved if removed)
    //   total   = own + ALL transitives, including ones shared with other deps
    const footprintToggle = `<div class="footprint-toggle" role="group" aria-label="Size column footprint mode"
        title="What the Size column shows: own archive only, plus unique transitives (cost if removed), or plus all transitives (theoretical max).">
        <span class="toggle-label">Footprint:</span>
        <button class="toggle-btn footprint-btn active" data-footprint="own"
            title="Own archive size only — matches pub.dev download size">Own</button>
        <button class="toggle-btn footprint-btn" data-footprint="unique"
            title="Own size + transitives used only by this dep (savings if you remove it)">+ Unique</button>
        <button class="toggle-btn footprint-btn" data-footprint="total"
            title="Own size + all transitives, including ones shared with other deps">+ All</button>
    </div>`;
    // Search field wrapped so we can absolutely position a clear (X) button
    // inside it; the button stays hidden until the user types something, and
    // a click clears the input + re-runs filters.
    const searchField = `<div class="search-wrapper">
        <label class="sr-only" for="search-input">Search packages</label>
        <input type="text" id="search-input" placeholder="Search packages\u2026" class="search-input" />
        <button type="button" id="search-clear" class="search-clear" title="Clear search" aria-label="Clear search" hidden>&times;</button>
    </div>`;
    const ageFilter = `<div class="age-filter" title="Filter by publish age">
        <label for="age-max">Published age</label>
        <input id="age-max" type="range" min="0" max="240" value="240" />
        <span id="age-max-label">All</span>
    </div>`;
    const presetFilter = `<div class="preset-filter" title="Apply quick filter presets">
        <label for="filter-preset">Preset</label>
        <select id="filter-preset">
            <option value="none">None</option>
            <option value="modernization">Modernization</option>
            <option value="risk-hotspots">Risk hotspots</option>
            <option value="cleanup-candidates">Cleanup candidates</option>
            <option value="direct-only">Direct only</option>
        </select>
    </div>`;
    const devToggle = `<label class="dev-toggle" title="Include dev dependencies in table and totals">
        <input id="include-dev-toggle" type="checkbox" checked />
        Include dev
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
        ${pubspecBtn}
    </div>
    <div id="active-filters" class="active-filters" hidden>
        <span class="active-filters-label">Active filters:</span>
        <div class="active-filters-list"></div>
        <button id="clear-all-filters" class="clear-filter-btn" type="button">Clear all</button>
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

/** Shared tooltip for cells that require GitHub data (issues, PRs). */
const NO_GITHUB_TOOLTIP = 'No GitHub repository found';

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
            ${th('name', 'Package', 'Package name \u2014 click to open pubspec.yaml entry')}
            ${th('version', 'Version', 'Installed version from pubspec.lock')}
            ${th('score', 'Category', 'Vibrancy classification and health score (0\u201310)')}
            ${th('published', 'Published', 'Date the installed version was published to pub.dev')}
            ${th('activity', 'Activity', 'Code-and-release activity grade from commit + publish recency')}
            ${th('likes', 'Likes', 'pub.dev likes \u2014 click to open the package score page')}
            ${th('downloads', 'Downloads', 'pub.dev downloads in the last 30 days \u2014 click to open the package score page')}
            ${th('issues', 'Issues', 'Open GitHub issues (excludes pull requests when available)')}
            ${th('prs', 'PRs', 'Open GitHub pull requests')}
            ${th('size', 'Size', 'Archive size on pub.dev (before tree shaking)')}
            ${th('deps', 'Deps', 'Direct transitive dependencies \u2014 shared deps highlighted')}
            ${thOpt('files', 'References', 'Number of source files that import this package \u2014 click to search')}
            ${thOpt('transitives', 'Transitives', 'Number of transitive (indirect) dependencies this package pulls in')}
            ${thOpt('vulns', 'Vulns', 'Known security vulnerabilities from OSV and GitHub Advisory databases')}
            ${thOpt('license', 'License', 'SPDX license identifier from pub.dev')}
            ${th('update', 'Update', 'Available version update: major, minor, or patch')}
            ${thOpt('status', 'Status', 'Usage status: whether the package appears unused in your code')}
            ${thOpt('description', 'Description', 'Package description from pub.dev')}
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
        data-size="${r.archiveSizeBytes ?? 0}"
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
        <td class="expand-cell"><span class="expand-chevron" title="Expand details">\u25B6</span></td>
        <td class="copy-cell"><span class="copy-btn" data-pkg="${name}" title="Copy row as JSON">&#128203;</span></td>
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
        badge = ' <span class="badge-dev">dev</span>';
    } else if (r.package.section === 'transitive') {
        badge = ' <span class="badge-transitive">transitive</span>';
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
        lines.push(`Installed: ${r.package.version} (${installedDate})`);
    }
    const latest = r.pubDev?.latestVersion;
    if (latest && latest !== r.package.version) {
        const suffix = latestDate ? ` (${latestDate})` : '';
        lines.push(`Latest: ${latest}${suffix}`);
    }
    if (createdDate) { lines.push(`Created: ${createdDate}`); }
    if (r.package.constraint) { lines.push(`Constraint: ${r.package.constraint}`); }
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
        return '<td title="Publish date not available from pub.dev"><span class="dimmed">\u2014</span></td>';
    }
    return `<td><a href="${url}">${date}</a>${ageSuffix}</td>`;
}

function buildActivityCell(r: VibrancyResult): string {
    const activity = computeActivitySignal(r);
    if (activity.grade === null) {
        return '<td title="Activity grade unavailable (missing commit or release data)"><span class="dimmed">\u2014</span></td>';
    }
    const title = activity.message ?? 'Activity based on recent commits and releases';
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
        `Grade: ${categoryToGrade(r.category)}`,
        '',
        `Resolution Velocity: ${fmt(r.resolutionVelocity)}`,
        `Engagement Level: ${fmt(r.engagementLevel)}`,
        `Popularity: ${fmt(r.popularity)}`,
        `Publisher Trust: ${fmt(r.publisherTrust)}`,
    ];
    if (commitAgeDays !== undefined) {
        lines.push(`Code commits: ${formatAgeFromDays(commitAgeDays)} ago`);
    }
    if (publishAgeDays !== undefined) {
        lines.push(`Latest release: ${formatAgeFromDays(publishAgeDays)} ago`);
    }
    const dormancy = buildDormancyStatus(commitAgeDays, publishAgeDays);
    if (dormancy) {
        lines.push('', `Activity signal: ${dormancy}`);
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
        return `<td class="cell-right" title="pub.dev likes not available"><a href="${href}"><span class="dimmed">\u2014</span></a></td>`;
    }
    const full = likes.toLocaleString('en-US');
    const compact = formatCompactCount(likes);
    return `<td class="cell-right" title="${full} pub.dev likes">`
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
        return `<td class="cell-right" title="pub.dev 30-day downloads not available"><a href="${href}"><span class="dimmed">\u2014</span></a></td>`;
    }
    const full = downloads.toLocaleString('en-US');
    const compact = formatCompactCount(downloads);
    return `<td class="cell-right" title="${full} downloads in the last 30 days">`
        + `<a href="${href}">${escapeHtml(compact)}</a></td>`;
}

function buildIssuesCell(r: VibrancyResult): string {
    const count = r.github?.trueOpenIssues ?? r.github?.openIssues;
    if (count == null) { return `<td class="cell-right" title="${NO_GITHUB_TOOLTIP}"><span class="dimmed">\u2014</span></td>`; }
    const repoUrl = resolveRepoUrl(r);
    if (repoUrl) {
        return `<td class="cell-right"><a href="${escapeHtml(repoUrl)}/issues">${count.toLocaleString('en-US')}</a></td>`;
    }
    return `<td class="cell-right">${count.toLocaleString('en-US')}</td>`;
}

function buildPrsCell(r: VibrancyResult): string {
    const count = r.github?.openPullRequests;
    if (count == null) { return `<td class="cell-right" title="${NO_GITHUB_TOOLTIP}"><span class="dimmed">\u2014</span></td>`; }
    const repoUrl = resolveRepoUrl(r);
    if (repoUrl) {
        return `<td class="cell-right"><a href="${escapeHtml(repoUrl)}/pulls">${count.toLocaleString('en-US')}</a></td>`;
    }
    return `<td class="cell-right">${count.toLocaleString('en-US')}</td>`;
}

function buildSizeCell(r: VibrancyResult): string {
    if (r.archiveSizeBytes === null) {
        return '<td class="cell-right size-cell" title="Archive size not available from pub.dev"><span class="dimmed">\u2014</span></td>';
    }
    // Render three precomputed labels — the toolbar toggle picks which one is
    // visible by toggling a class on the table. This avoids re-running format
    // logic in JS on every toggle.
    const own = r.archiveSizeBytes;
    const uniqueT = r.transitiveInfo?.uniqueTransitiveSizeBytes ?? 0;
    const sharedT = r.transitiveInfo?.sharedTransitiveSizeBytes ?? 0;
    const ownLabel = formatSizeKB(own);
    const uniqueLabel = formatSizeKB(own + uniqueT);
    const totalLabel = formatSizeKB(own + uniqueT + sharedT);
    const tooltip = r.transitiveInfo && r.transitiveInfo.transitiveCount > 0
        ? `Own: ${ownLabel}\nWith unique transitives: ${uniqueLabel}\nWith shared transitives: ${totalLabel}`
        : `Archive size: ${ownLabel}`;
    const packageName = escapeHtml(r.package.name);
    return `<td class="cell-right size-cell" title="${escapeHtml(tooltip)}"
        data-size-own="${own}" data-size-unique="${own + uniqueT}" data-size-total="${own + uniqueT + sharedT}">`
        + `<span class="size-link size-own" data-pkg="${packageName}" title="Open local package folder">${ownLabel}</span>`
        + `<span class="size-link size-unique" data-pkg="${packageName}" title="Open local package folder">${uniqueLabel}</span>`
        + `<span class="size-link size-total" data-pkg="${packageName}" title="Open local package folder">${totalLabel}</span>`
        + `</td>`;
}

/** References column: click count to search for imports of this package. */
function buildReferencesCell(r: VibrancyResult): string {
    const active = activeFileUsages(r.fileUsages);
    const count = active.length;
    if (count === 0) {
        return '<td class="cell-right" title="No source file imports detected"><span class="dimmed">\u2014</span></td>';
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
            const label = `${u.filePath}:${u.exportLine} (re-export)`;
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
            const label = `${u.filePath}:${u.line}${u.isExport ? ' (re-export)' : ''}`;
            tooltipLines.push(label);
            refEntries.push({ path: u.filePath, line: u.line, label });
        }
    }
    if (isReExport) {
        tooltipLines.unshift('Public API surface — at least one usage is a re-export.', '');
    }
    const tooltip = tooltipLines.join('\n');
    const name = escapeHtml(r.package.name);
    // Tiny badge after the count when re-exported — the whole table is dense
    // so we keep this to a single character ("\u21AA" leftwards arrow with
    // hook = "exposed onward").
    const reexportBadge = isReExport
        ? ' <span class="ref-reexport-badge" title="Re-exported">\u21AA</span>'
        : '';
    const refsData = encodeURIComponent(JSON.stringify(refEntries.slice(0, 50)));
    return `<td class="cell-right refs-cell${cls}" title="${escapeHtml(tooltip)}">`
        + `<span class="ref-link" data-pkg="${name}" data-refs="${refsData}" title="Open file references">${count}</span>${reexportBadge}`
        + `</td>`;
}

function buildTransitivesCell(
    r: VibrancyResult,
    tablePackageNames: ReadonlySet<string>,
): string {
    const count = r.transitiveInfo?.transitiveCount ?? 0;
    const flagged = r.transitiveInfo?.flaggedCount ?? 0;
    if (count === 0) {
        return '<td class="cell-right transitives-cell" title="No transitive dependencies"><span class="dimmed">\u2014</span></td>';
    }
    const info = r.transitiveInfo!;
    const depList = info.transitives
        .filter(dep => tablePackageNames.has(dep))
        .join(',');
    const text = flagged > 0 ? `${count} (${flagged}\u26A0)` : `${count}`;
    const cls = flagged > 0 ? ' transitive-flagged' : '';
    return `<td class="cell-right transitives-cell${cls}">`
        + `<span class="dep-list-link" data-pkg="${escapeHtml(r.package.name)}" data-deps="${escapeHtml(depList)}" title="Show transitive dependencies">${text}</span>`
        + `</td>`;
}

function buildVulnsCell(r: VibrancyResult): string {
    const count = r.vulnerabilities.length;
    const worst = worstSeverity(r.vulnerabilities);
    if (count === 0) { return '<td title="No known vulnerabilities"><span class="dimmed">\u2014</span></td>'; }
    const emoji = worst ? severityEmoji(worst) : '';
    const label = worst ? severityLabel(worst) : '';
    const cls = worst ? ` class="vuln-${worst}"` : '';
    return `<td${cls}>${emoji} ${count} (${label})</td>`;
}

function buildLicenseCell(r: VibrancyResult): string {
    const license = r.license;
    if (!license) { return '<td title="License not specified on pub.dev"><span class="dimmed">\u2014</span></td>'; }
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
        return '<td><span class="badge-unused">Unused</span></td>';
    }
    return '<td title="Package is in use"><span class="dimmed">\u2014</span></td>';
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
        return '<td class="cell-right deps-cell" title="No transitive dependencies"><span class="dimmed">\u2014</span></td>';
    }
    const total = info.transitiveCount;
    const shared = info.sharedDeps.length;
    const linkedDeps = info.transitives.filter(dep => tablePackageNames.has(dep));
    /* Build a tooltip listing all transitive deps, marking shared ones. */
    const depLines = linkedDeps.map(dep => {
        const isShared = info.sharedDeps.includes(dep);
        return isShared ? `\u2022 ${dep} (shared)` : `\u2022 ${dep}`;
    });
    const tooltip = `${total} transitive deps${shared > 0 ? ` (${shared} shared)` : ''}\n${depLines.join('\n')}`;
    /* Show count with a tree icon; highlight if shared deps exist. */
    const sharedBadge = shared > 0
        ? ` <span class="badge-shared" title="${shared} shared with other packages">${shared}s</span>`
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
        activityRows.push(`<span class="detail-label">Code Commit Activity</span><span>${escapeHtml(formatAgeFromDays(commitAgeDays))} ago</span>`);
    }
    if (publishAgeDays !== undefined) {
        activityRows.push(`<span class="detail-label">Release Activity</span><span>${escapeHtml(formatAgeFromDays(publishAgeDays))} ago</span>`);
    }
    const dormancy = buildDormancyStatus(commitAgeDays, publishAgeDays);
    if (dormancy) {
        activityRows.push(`<span class="detail-label">Dormancy Signal</span><span>${escapeHtml(dormancy)}</span>`);
    }
    /* The "Overall" numeric row was removed — it was the same info as the
       header grade letter, just shown as a /10. The factor rows below stay
       because they're distinct dimensions, not the same aggregate. */
    return `<div class="detail-section">
        <h4>Health Score <span class="grade-badge grade-${grade}">${grade}</span></h4>
        <div class="detail-grid">
            <span class="detail-label">Resolution Velocity</span><span>${fmt(r.resolutionVelocity)}</span>
            <span class="detail-label">Engagement Level</span><span>${fmt(r.engagementLevel)}</span>
            <span class="detail-label">Popularity</span><span>${fmt(r.popularity)}</span>
            <span class="detail-label">Publisher Trust</span><span>${fmt(r.publisherTrust)}</span>
            ${activityRows.join('')}
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
        return 'No commits and no releases in 6+ months';
    }
    if (commitAgeDays >= 90 && publishAgeDays >= 90) {
        return 'No commits and no releases in 3+ months';
    }
    if (commitAgeDays >= 90 && publishAgeDays < 90) {
        return 'Release active, code inactive (3+ months without commits)';
    }
    if (commitAgeDays < 90 && publishAgeDays >= 90) {
        return 'Code active, release cadence is slower (3+ months)';
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
        ? `${dormancy} (activity grade ${grade})`
        : `Code and release activity is healthy (activity grade ${grade})`;
    return { score, grade, message, sortValue: String(score) };
}

function buildDetailVulnSection(r: VibrancyResult): string {
    const rows = r.vulnerabilities.map(v => {
        const sev = v.severity ? `<span class="vuln-${v.severity}">${severityLabel(v.severity)}</span>` : '';
        const link = v.url ? `<a href="${escapeHtml(v.url)}">${escapeHtml(v.id)}</a>` : escapeHtml(v.id);
        const fix = v.fixedVersion ? ` \u2192 fix in ${escapeHtml(v.fixedVersion)}` : '';
        return `<div class="vuln-row">${sev} ${link}: ${escapeHtml(v.summary ?? '')}${fix}</div>`;
    });
    return `<div class="detail-section">
        <h4>Vulnerabilities (${r.vulnerabilities.length})</h4>
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
            rows.push(`<div class="file-row"><span class="file-link" data-path="${path}" data-line="${u.exportLine}">${path}:${u.exportLine}</span> (re-export)</div>`);
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
        ? `<div class="dimmed">... and ${active.length - 20} more</div>` : '';
    return `<div class="detail-section">
        <h4>File References (${active.length}) <span class="ref-link detail-search-link" data-pkg="${name}" title="Search imports">\u{1F50D}</span></h4>
        ${fileList}${more}
    </div>`;
}

function buildDetailDepsSection(r: VibrancyResult): string {
    const info = r.transitiveInfo!;
    const depItems = info.transitives.map(dep => {
        const isShared = info.sharedDeps.includes(dep);
        const cls = isShared ? ' class="dep-shared"' : '';
        const badge = isShared ? ' <span class="badge-shared-sm">shared</span>' : '';
        return `<span${cls}>${escapeHtml(dep)}${badge}</span>`;
    });
    return `<div class="detail-section">
        <h4>Transitive Dependencies (${info.transitiveCount})</h4>
        <div class="dep-cloud">${depItems.join(' ')}</div>
    </div>`;
}

function buildDetailLinksSection(r: VibrancyResult): string {
    const name = encodeURIComponent(r.package.name);
    const links: string[] = [
        `<a href="https://pub.dev/packages/${name}">pub.dev</a>`,
        `<a href="https://pub.dev/packages/${name}/changelog">changelog</a>`,
        `<a href="https://pub.dev/packages/${name}/versions">versions</a>`,
    ];
    const repoUrl = (r.github?.repoUrl ?? r.pubDev?.repositoryUrl)?.replace(/\/+$/, '');
    if (repoUrl) {
        links.push(`<a href="${escapeHtml(repoUrl)}">repository</a>`);
        links.push(`<a href="${escapeHtml(repoUrl)}/issues">issues</a>`);
    }
    return `<div class="detail-section detail-links">
        <h4>Links</h4>
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
