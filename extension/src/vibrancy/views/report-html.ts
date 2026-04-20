import { VibrancyResult, activeFileUsages, hasActiveReExport } from '../types';
import {
    categoryLabel, categoryToGrade, countByCategory, scoreToGrade,
} from '../scoring/status-classifier';
import { formatSizeMB, formatSizeKB } from '../scoring/bloat-calculator';
import { worstSeverity, severityEmoji, severityLabel } from '../scoring/vuln-classifier';
import { getReportStyles } from './report-styles';
import { getReportScript } from './report-script';
import { escapeHtml } from './html-utils';
import { buildChartSection } from './chart-html';
import { getChartStyles } from './chart-styles';
import { getChartScript } from './chart-script';

/** Options passed to the report builder beyond just results. */
export interface ReportOptions {
    readonly results: VibrancyResult[];
    readonly overrideCount: number;
    /** Names of packages that have dependency_overrides entries. */
    readonly overrideNames: ReadonlySet<string>;
    readonly pubspecUri: string | null;
    /** Extension version from package.json, shown next to the report title. */
    readonly extensionVersion: string;
}

/** Columns that can be auto-hidden when all values are empty or off by default. */
type HidableColumn = 'transitives' | 'vulns' | 'status' | 'files' | 'license' | 'description';

/** Build the full HTML for the vibrancy report webview. */
export function buildReportHtml(options: ReportOptions): string {
    const { results } = options;
    /* Average score for the radial gauge (0-100 raw scale). */
    const avg = results.length > 0
        ? Math.round(results.reduce((s, r) => s + r.score, 0) / results.length)
        : 0;
    return `<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta http-equiv="Content-Security-Policy"
        content="default-src 'none'; style-src 'unsafe-inline'; script-src 'unsafe-inline';">
    <style>${getReportStyles()}${getChartStyles()}</style>
</head>
<body>
    <div class="report-header">
        <h1>Saropa Package Vibrancy <span class="header-version">v${escapeHtml(options.extensionVersion)}</span></h1>
        ${buildRadialGauge(avg)}
    </div>
    ${buildReportSummary(options)}
    ${buildChartSection(results)}
    ${buildToolbar(options)}
    ${buildReportTable(results, options.overrideNames)}
    <script>${buildPackageDataScript(results, options.overrideNames)}${getReportScript()}${getChartScript()}</script>
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
    const totalBytes = results.reduce(
        (sum, r) => sum + (r.archiveSizeBytes ?? 0), 0,
    );
    const totalSize = totalBytes > 0 ? formatSizeMB(totalBytes) : '\u2014';
    const vulnPackages = results.filter(r => r.vulnerabilities.length > 0).length;
    // "Single-use" excludes packages whose only reference is a re-export.
    // A `lib/foo.dart` that does `export 'package:bar/...';` is exposing the
    // package as part of its own public API, so the dep isn't "easy to remove"
    // even though it appears in just one source file.
    const singleUse = results.filter(
        r => activeFileUsages(r.fileUsages).length === 1
            && !hasActiveReExport(r.fileUsages),
    ).length;

    return `<div class="summary">
        <div class="summary-card"><div class="count">${results.length}</div><div class="label">Packages</div></div>
        <div class="summary-card"><div class="count">${avgGrade}</div><div class="label">Project Package Grade</div></div>
        <div class="summary-card"><div class="count">${totalSize}</div><div class="label">Total Size*</div></div>
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
    <p class="caveat">*Archive sizes before tree shaking. Actual app size will be smaller.</p>`;
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
    const copyAllBtn = '<button id="copy-all" class="toolbar-btn" title="Copy entire table as JSON (all rows + expander details)">&#128203; Copy All JSON</button>';
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
    return `<div class="table-toolbar">
        <input type="text" id="search-input" placeholder="Search packages\u2026" class="search-input" />
        ${footprintToggle}
        ${copyAllBtn}
        ${pubspecBtn}
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
    /* License and description are off by default — no toggle UI yet. */
    hidden.add('license');
    hidden.add('description');
    return hidden;
}

/** Shared tooltip for cells that require GitHub data (stars, issues, PRs). */
const NO_GITHUB_TOOLTIP = 'No GitHub repository found';

/** Derive shared transitive dep names from all results' TransitiveInfo. */
function deriveSharedDepNames(results: VibrancyResult[]): ReadonlySet<string> {
    return new Set(
        results.flatMap(r => r.transitiveInfo?.sharedDeps ?? []),
    );
}

function buildReportTable(
    results: VibrancyResult[],
    overrideNames: ReadonlySet<string>,
): string {
    const hidden = getHiddenColumns(results);
    const sharedDepNames = deriveSharedDepNames(results);
    const th = (col: string, label: string, tooltip?: string) => {
        const titleAttr = tooltip ? ` title="${escapeHtml(tooltip)}"` : '';
        return `<th data-col="${col}"${titleAttr}>${label}<span class="sort-arrow"></span></th>`;
    };
    const thOpt = (col: HidableColumn, label: string, tooltip?: string) =>
        hidden.has(col) ? '' : th(col, label, tooltip);

    /* Count visible columns so the detail row can span them all.
       Base columns: expand + copy + name + version + category + published +
       stars + issues + prs + size + deps + update = 12. */
    const visibleCols = 12
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
            ${th('stars', 'Stars', 'GitHub repository star count')}
            ${th('issues', 'Issues', 'Open GitHub issues (excludes pull requests when available)')}
            ${th('prs', 'PRs', 'Open GitHub pull requests')}
            ${th('size', 'Size', 'Archive size on pub.dev (before tree shaking)')}
            <th title="Direct transitive dependencies \u2014 shared deps highlighted">Deps</th>
            ${thOpt('files', 'References', 'Number of source files that import this package \u2014 click to search')}
            ${thOpt('transitives', 'Transitives', 'Number of transitive (indirect) dependencies this package pulls in')}
            ${thOpt('vulns', 'Vulns', 'Known security vulnerabilities from OSV and GitHub Advisory databases')}
            ${thOpt('license', 'License', 'SPDX license identifier from pub.dev')}
            ${th('update', 'Update', 'Available version update: major, minor, or patch')}
            ${thOpt('status', 'Status', 'Usage status: whether the package appears unused in your code')}
            ${thOpt('description', 'Description', 'Package description from pub.dev')}
        </tr></thead>
        <tbody id="pkg-body">
            ${results.map(r => buildRow(r, hidden, overrideNames, sharedDepNames, visibleCols)).join('\n')}
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
    colspan: number,
): string {
    const name = escapeHtml(r.package.name);
    const date = r.pubDev?.publishedDate.split('T')[0] ?? '';
    const stars = r.github?.stars ?? '';
    const issueCount = r.github?.trueOpenIssues ?? r.github?.openIssues ?? '';
    const prCount = r.github?.openPullRequests ?? '';
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
        data-published="${date}" data-stars="${stars}"
        data-issues="${issueCount}" data-prs="${prCount}"
        data-size="${r.archiveSizeBytes ?? 0}"
        data-files="${activeFileCount}"
        data-transitives="${transitiveCount}"
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
        ${buildCategoryCell(r)}
        ${buildPublishedCell(r)}
        ${buildStarsCell(r)}
        ${buildIssuesCell(r)}
        ${buildPrsCell(r)}
        ${buildSizeCell(r)}
        ${buildDepsCell(r)}
        ${hidden.has('files') ? '' : buildReferencesCell(r)}
        ${hidden.has('transitives') ? '' : buildTransitivesCell(r)}
        ${hidden.has('vulns') ? '' : buildVulnsCell(r)}
        ${hidden.has('license') ? '' : buildLicenseCell(r)}
        ${buildUpdateCell(r)}
        ${hidden.has('status') ? '' : buildStatusCell(r)}
        ${hidden.has('description') ? '' : buildDescCell(r)}
    </tr>
    <tr class="detail-row" data-detail-for="${name}" style="display:none">
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
    const months = Math.max(0, Math.floor((Date.now() - ms) / (30.44 * 86_400_000)));
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
function buildCategoryCell(r: VibrancyResult): string {
    const grade = categoryToGrade(r.category);
    const tooltip = buildHealthTooltip(r);
    return `<td title="${escapeHtml(tooltip)}"><span class="grade-badge grade-${grade}">${grade}</span></td>`;
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

/** Build a multi-line tooltip explaining the vibrancy score breakdown. */
function buildHealthTooltip(r: VibrancyResult): string {
    const fmt = (v: number) => Math.round(v);
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
    return lines.join('\n');
}

/** Resolve the canonical repository URL (trailing slashes stripped). */
function resolveRepoUrl(r: VibrancyResult): string | undefined {
    return (r.github?.repoUrl ?? r.pubDev?.repositoryUrl)
        ?.replace(/\/+$/, '');
}

function buildStarsCell(r: VibrancyResult): string {
    const stars = r.github?.stars;
    if (stars == null) {
        return `<td class="cell-right" title="${NO_GITHUB_TOOLTIP}"><span class="dimmed">\u2014</span></td>`;
    }
    return `<td class="cell-right">${stars.toLocaleString('en-US')}</td>`;
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
    return `<td class="cell-right size-cell" title="${escapeHtml(tooltip)}"
        data-size-own="${own}" data-size-unique="${own + uniqueT}" data-size-total="${own + uniqueT + sharedT}">`
        + `<span class="size-own">${ownLabel}</span>`
        + `<span class="size-unique">${uniqueLabel}</span>`
        + `<span class="size-total">${totalLabel}</span>`
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
    // file is exposing the package as part of its public API.
    const tooltipLines = active.map(u =>
        `${u.filePath}:${u.line}${u.isExport ? ' (re-export)' : ''}`,
    );
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
    return `<td class="cell-right${cls}" title="${escapeHtml(tooltip)}">`
        + `<span class="ref-link" data-pkg="${name}">${count}</span>${reexportBadge}`
        + `</td>`;
}

function buildTransitivesCell(r: VibrancyResult): string {
    const count = r.transitiveInfo?.transitiveCount ?? 0;
    const flagged = r.transitiveInfo?.flaggedCount ?? 0;
    let text: string;
    if (count === 0) { return '<td title="No transitive dependencies"><span class="dimmed">\u2014</span></td>'; }
    if (flagged > 0) { text = `${count} (${flagged}\u26A0)`; }
    else { text = `${count}`; }
    const cls = flagged > 0 ? ' class="transitive-flagged"' : '';
    return `<td${cls}>${text}</td>`;
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
    if (!hasUpdate) { return '<td><span class="dimmed">\u2013</span></td>'; }
    const text = escapeHtml(`\u2192 ${r.updateInfo!.latestVersion}`);
    const cls = getUpdateClass(r.updateInfo!.updateStatus);
    return `<td class="${cls}"><a href="${url}">${text}</a></td>`;
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

/** Plain-text description cell (hidable, off by default). */
function buildDescCell(r: VibrancyResult): string {
    const desc = r.pubDev?.description;
    if (!desc) { return '<td class="desc-text"><span class="dimmed">\u2014</span></td>'; }
    return `<td class="desc-text" title="${escapeHtml(desc)}">${escapeHtml(desc)}</td>`;
}

/** Deps column: icon showing transitive dep count, with shared deps highlighted. */
function buildDepsCell(r: VibrancyResult): string {
    const info = r.transitiveInfo;
    if (!info || info.transitiveCount === 0) {
        return '<td class="cell-right" title="No transitive dependencies"><span class="dimmed">\u2014</span></td>';
    }
    const total = info.transitiveCount;
    const shared = info.sharedDeps.length;
    /* Build a tooltip listing all transitive deps, marking shared ones. */
    const depLines = info.transitives.map(dep => {
        const isShared = info.sharedDeps.includes(dep);
        return isShared ? `\u2022 ${dep} (shared)` : `\u2022 ${dep}`;
    });
    const tooltip = `${total} transitive deps${shared > 0 ? ` (${shared} shared)` : ''}\n${depLines.join('\n')}`;
    /* Show count with a tree icon; highlight if shared deps exist. */
    const sharedBadge = shared > 0
        ? ` <span class="badge-shared" title="${shared} shared with other packages">${shared}s</span>`
        : '';
    return `<td class="cell-right" title="${escapeHtml(tooltip)}"><span class="deps-icon">\u{1F333}</span> ${total}${sharedBadge}</td>`;
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
        </div>
    </div>`;
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
    const fileList = active.slice(0, 20).map(u =>
        `<div class="file-row">${escapeHtml(u.filePath)}:${u.line}</div>`,
    ).join('\n');
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
): string {
    const entries = results.map(r => {
        const key = JSON.stringify(r.package.name);
        const val = JSON.stringify(buildPackageJson(r, overrideNames));
        return `${key}:${val}`;
    });
    /* Escape < to \u003c so embedded JSON cannot break out of the script tag */
    const raw = `var packageData={${entries.join(',')}};`;
    return raw.replace(/</g, '\\u003c');
}

/** Build a comprehensive JSON-safe object for one package row. */
function buildPackageJson(
    r: VibrancyResult,
    overrideNames: ReadonlySet<string>,
): Record<string, unknown> {
    const name = r.package.name;
    const encoded = encodeURIComponent(name);
    const activeFiles = activeFileUsages(r.fileUsages);
    const repoBase = resolveRepoUrl(r) ?? null;
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
        },
        category: categoryLabel(r.category),
        published: r.pubDev?.publishedDate.split('T')[0] ?? null,
        stars: r.github?.stars ?? null,
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
        files: activeFiles.map(u => `${u.filePath}:${u.line}`),
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
            license: `https://pub.dev/packages/${encoded}/license`,
            changelog: `https://pub.dev/packages/${encoded}/changelog`,
            repository: r.pubDev?.repositoryUrl ?? null,
            issues: repoBase ? `${repoBase}/issues` : null,
            pullRequests: repoBase ? `${repoBase}/pulls` : null,
        },
    };
}
