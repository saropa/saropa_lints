import { VibrancyResult, activeFileUsages } from '../types';
import { categoryLabel, countByCategory } from '../scoring/status-classifier';
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
}

/** Columns that can be auto-hidden when all values are empty. */
type HidableColumn = 'transitives' | 'vulns' | 'status' | 'files';

/** Build the full HTML for the vibrancy report webview. */
export function buildReportHtml(options: ReportOptions): string {
    const { results } = options;
    return `<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta http-equiv="Content-Security-Policy"
        content="default-src 'none'; style-src 'unsafe-inline'; script-src 'unsafe-inline';">
    <style>${getReportStyles()}${getChartStyles()}</style>
</head>
<body>
    <h1>Package Vibrancy Report</h1>
    ${buildReportSummary(options)}
    ${buildChartSection(results)}
    ${buildToolbar(options)}
    ${buildReportTable(results, options.overrideNames)}
    <script>${buildPackageDataScript(results, options.overrideNames)}${getReportScript()}${getChartScript()}</script>
</body>
</html>`;
}

function buildReportSummary(options: ReportOptions): string {
    const { results, overrideCount } = options;
    const counts = countByCategory(results);
    const updates = results.filter(
        r => r.updateInfo && r.updateInfo.updateStatus !== 'up-to-date',
    ).length;
    const avg = results.length > 0
        ? Math.round(results.reduce((s, r) => s + r.score, 0) / results.length / 10)
        : 0;
    const totalBytes = results.reduce(
        (sum, r) => sum + (r.archiveSizeBytes ?? 0), 0,
    );
    const totalSize = totalBytes > 0 ? formatSizeMB(totalBytes) : '\u2014';
    const vulnPackages = results.filter(r => r.vulnerabilities.length > 0).length;
    const singleUse = results.filter(
        r => activeFileUsages(r.fileUsages).length === 1,
    ).length;

    return `<div class="summary">
        <div class="summary-card"><div class="count">${results.length}</div><div class="label">Packages</div></div>
        <div class="summary-card"><div class="count">${avg}/10</div><div class="label">Avg Score</div></div>
        <div class="summary-card"><div class="count">${totalSize}</div><div class="label">Total Size*</div></div>
        <div class="summary-card vibrant" data-filter="vibrant"><div class="count">${counts.vibrant}</div><div class="label">Vibrant</div></div>
        <div class="summary-card stable" data-filter="stable"><div class="count">${counts.stable}</div><div class="label">Stable</div></div>
        <div class="summary-card outdated" data-filter="outdated"><div class="count">${counts.outdated}</div><div class="label">Outdated</div></div>
        <div class="summary-card abandoned" data-filter="abandoned"><div class="count">${counts.abandoned}</div><div class="label">Abandoned</div></div>
        <div class="summary-card eol" data-filter="end-of-life"><div class="count">${counts.eol}</div><div class="label">End of Life</div></div>
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
    return `<div class="table-toolbar">
        <input type="text" id="search-input" placeholder="Search packages\u2026" class="search-input" />
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
    return hidden;
}

const HEALTH_TOOLTIP = 'Vibrancy Score (0\u201310): overall package health based on '
    + 'maintainer activity, community engagement, and popularity.';

function buildReportTable(
    results: VibrancyResult[],
    overrideNames: ReadonlySet<string>,
): string {
    const hidden = getHiddenColumns(results);
    const th = (col: string, label: string, tooltip?: string) => {
        const titleAttr = tooltip ? ` title="${escapeHtml(tooltip)}"` : '';
        return `<th data-col="${col}"${titleAttr}>${label}<span class="sort-arrow"></span></th>`;
    };
    const thOpt = (col: HidableColumn, label: string, tooltip?: string) =>
        hidden.has(col) ? '' : th(col, label, tooltip);

    return `<table>
        <thead><tr>
            <th class="col-copy"></th>
            ${th('name', 'Package', 'Package name on pub.dev')}
            ${th('version', 'Version', 'Installed version from pubspec.lock')}
            <th data-col="score" title="${escapeHtml(HEALTH_TOOLTIP)}">Health <span class="info-icon" title="${escapeHtml(HEALTH_TOOLTIP)}">&#9432;</span><span class="sort-arrow"></span></th>
            ${th('category', 'Category', 'Vibrancy classification: Vibrant, Stable, Outdated, Abandoned, or End-of-Life')}
            ${th('published', 'Published', 'Date the installed version was published to pub.dev')}
            ${th('stars', 'Stars', 'GitHub repository star count')}
            ${th('size', 'Size', 'Archive size on pub.dev (before tree shaking)')}
            ${thOpt('files', 'Files', 'Number of source files that import this package')}
            ${thOpt('transitives', 'Transitives', 'Number of transitive (indirect) dependencies this package pulls in')}
            ${thOpt('vulns', 'Vulns', 'Known security vulnerabilities from OSV and GitHub Advisory databases')}
            ${th('license', 'License', 'SPDX license identifier from pub.dev')}
            ${th('update', 'Update', 'Available version update: major, minor, or patch')}
            ${thOpt('status', 'Status', 'Usage status: whether the package appears unused in your code')}
            <th class="col-icon" title="Package description from pub.dev">&#8505;</th>
        </tr></thead>
        <tbody id="pkg-body">
            ${results.map(r => buildRow(r, hidden, overrideNames)).join('\n')}
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
): string {
    const name = escapeHtml(r.package.name);
    const date = r.pubDev?.publishedDate.split('T')[0] ?? '';
    const stars = r.github?.stars ?? '';
    const activeFileCount = activeFileUsages(r.fileUsages).length;
    const transitiveCount = r.transitiveInfo?.transitiveCount ?? 0;
    const vulnCount = r.vulnerabilities.length;
    const isOverridden = overrideNames.has(r.package.name) ? 'yes' : 'no';

    return `<tr data-name="${name}" data-version="${escapeHtml(r.package.version)}"
        data-score="${r.score}" data-category="${r.category}"
        data-published="${date}" data-stars="${stars}"
        data-size="${r.archiveSizeBytes ?? 0}"
        data-files="${activeFileCount}"
        data-transitives="${transitiveCount}"
        data-vulns="${vulnCount}"
        data-license="${escapeHtml(r.license ?? '')}"
        data-update="${r.updateInfo?.updateStatus ?? 'unknown'}"
        data-status="${r.isUnused ? 'unused' : 'ok'}"
        data-section="${r.package.section}"
        data-overridden="${isOverridden}">
        <td class="copy-cell"><span class="copy-btn" data-pkg="${name}" title="Copy row as JSON">&#128203;</span></td>
        ${buildNameCell(r)}
        ${buildVersionCell(r)}
        ${buildHealthCell(r)}
        <td>${categoryLabel(r.category)}</td>
        <td>${date}</td>
        ${buildStarsCell(r)}
        ${buildSizeCell(r)}
        ${hidden.has('files') ? '' : buildFilesCell(r)}
        ${hidden.has('transitives') ? '' : buildTransitivesCell(r)}
        ${hidden.has('vulns') ? '' : buildVulnsCell(r)}
        ${buildLicenseCell(r)}
        ${buildUpdateCell(r)}
        ${hidden.has('status') ? '' : buildStatusCell(r)}
        ${buildDescCell(r)}
    </tr>`;
}

function buildNameCell(r: VibrancyResult): string {
    const name = escapeHtml(r.package.name);
    const url = `https://pub.dev/packages/${encodeURIComponent(r.package.name)}`;
    let badge = '';
    if (r.package.section === 'dev_dependencies') {
        badge = ' <span class="badge-dev">dev</span>';
    } else if (r.package.section === 'transitive') {
        badge = ' <span class="badge-transitive">transitive</span>';
    }
    return `<td><a href="${url}">${name}</a>${badge}</td>`;
}

function buildVersionCell(r: VibrancyResult): string {
    const name = encodeURIComponent(r.package.name);
    const version = escapeHtml(r.package.version);
    const url = `https://pub.dev/packages/${name}/versions`;
    const ageSuffix = formatAgeSuffix(r.installedVersionDate ?? r.pubDev?.publishedDate);
    const tooltip = buildVersionTooltip(r);
    return `<td><a href="${url}" title="${escapeHtml(tooltip)}">${version}</a>${ageSuffix}</td>`;
}

/** Format an ISO date as a compact age suffix, e.g. " (4mo)" or " (2y)". */
function formatAgeSuffix(isoDate: string | null | undefined): string {
    if (!isoDate) { return ''; }
    const ms = Date.parse(isoDate);
    if (isNaN(ms)) { return ''; }
    const months = Math.max(0, Math.floor((Date.now() - ms) / (30.44 * 86_400_000)));
    let label: string;
    if (months < 1) { label = 'new'; }
    else if (months < 24) { label = `${months}mo`; }
    else { label = `${Math.floor(months / 12)}y`; }
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

/** Health column with score breakdown tooltip. */
function buildHealthCell(r: VibrancyResult): string {
    const scoreVal = Math.round(r.score / 10);
    const tooltip = buildHealthTooltip(r);
    return `<td title="${escapeHtml(tooltip)}">${scoreVal}/10</td>`;
}

/** Build a multi-line tooltip explaining the vibrancy score breakdown. */
function buildHealthTooltip(r: VibrancyResult): string {
    const fmt = (v: number) => Math.round(v);
    const lines = [
        `Vibrancy Score: ${Math.round(r.score / 10)}/10`,
        '',
        `Resolution Velocity: ${fmt(r.resolutionVelocity)}`,
        `Engagement Level: ${fmt(r.engagementLevel)}`,
        `Popularity: ${fmt(r.popularity)}`,
        `Publisher Trust: ${fmt(r.publisherTrust)}`,
    ];
    return lines.join('\n');
}

function buildStarsCell(r: VibrancyResult): string {
    const stars = r.github?.stars;
    const text = stars != null ? stars.toLocaleString('en-US') : '';
    return `<td class="cell-right">${text}</td>`;
}

function buildSizeCell(r: VibrancyResult): string {
    const text = r.archiveSizeBytes !== null
        ? formatSizeKB(r.archiveSizeBytes) : '\u2014';
    return `<td class="cell-right">${text}</td>`;
}

function buildFilesCell(r: VibrancyResult): string {
    const active = activeFileUsages(r.fileUsages);
    const count = active.length;
    if (count === 0) { return '<td class="cell-right">\u2014</td>'; }
    // Single-use = muted; 6+ = bold (deeply embedded)
    const cls = count === 1 ? ' class="cell-right file-single"'
        : count >= 6 ? ' class="cell-right file-deep"'
        : ' class="cell-right"';
    const tooltip = active.map(u => `${u.filePath}:${u.line}`).join('\n');
    return `<td${cls} title="${escapeHtml(tooltip)}">${count}</td>`;
}

function buildTransitivesCell(r: VibrancyResult): string {
    const count = r.transitiveInfo?.transitiveCount ?? 0;
    const flagged = r.transitiveInfo?.flaggedCount ?? 0;
    let text: string;
    if (count === 0) { text = '\u2014'; }
    else if (flagged > 0) { text = `${count} (${flagged}\u26A0)`; }
    else { text = `${count}`; }
    const cls = flagged > 0 ? ' class="transitive-flagged"' : '';
    return `<td${cls}>${text}</td>`;
}

function buildVulnsCell(r: VibrancyResult): string {
    const count = r.vulnerabilities.length;
    const worst = worstSeverity(r.vulnerabilities);
    if (count === 0) { return '<td>\u2014</td>'; }
    const emoji = worst ? severityEmoji(worst) : '';
    const label = worst ? severityLabel(worst) : '';
    const cls = worst ? ` class="vuln-${worst}"` : '';
    return `<td${cls}>${emoji} ${count} (${label})</td>`;
}

function buildLicenseCell(r: VibrancyResult): string {
    const license = r.license;
    if (!license) { return '<td>\u2014</td>'; }
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
    if (!hasUpdate) { return '<td>\u2713</td>'; }
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
    return '<td>\u2014</td>';
}

function buildDescCell(r: VibrancyResult): string {
    const desc = r.pubDev?.description;
    if (!desc) { return '<td class="col-icon"></td>'; }
    return `<td class="col-icon"><span class="desc-icon" title="${escapeHtml(desc)}">&#8505;</span></td>`;
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
    return {
        name,
        version: r.package.version,
        constraint: r.package.constraint,
        section: r.package.section,
        isOverridden: overrideNames.has(name),
        health: {
            score: Math.round(r.score / 10),
            resolutionVelocity: Math.round(r.resolutionVelocity),
            engagementLevel: Math.round(r.engagementLevel),
            popularity: Math.round(r.popularity),
            publisherTrust: Math.round(r.publisherTrust),
        },
        category: categoryLabel(r.category),
        published: r.pubDev?.publishedDate.split('T')[0] ?? null,
        stars: r.github?.stars ?? null,
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
        },
    };
}
