/**
 * Package-table builders for the vibrancy report: the collapsible table
 * section, column-hiding logic, the row builder, and every per-cell builder
 * (name, version, category sparkline, activity, likes/downloads, size,
 * references, transitives, vulns, license, update, status, deps). Also hosts
 * buildDetailScoreSection (the docked detail pane's health-score block) since
 * it shares the same cell-level formatting helpers.
 */

import { VibrancyResult, activeFileUsages, hasActiveReExport } from '../types';
import { categoryToGrade } from '../scoring/status-classifier';
import { formatSizeMB, formatSizeKB } from '../scoring/bloat-calculator';
import { worstSeverity, severityEmoji, severityLabel } from '../scoring/vuln-classifier';
import { escapeHtml } from './html-utils';
import { l10n } from '../../i18n/runtime';
import {
    ReportOptions,
    resolveRepoUrl,
    computeActivitySignal,
    daysSinceIsoDate,
    formatAgeFromDays,
    buildDormancyStatus,
} from './report-html-shared';

/** Column header label / tooltip from `packageDashboard.columns.*`. */
function col(cid: string, part: 'label' | 'tooltip'): string {
    return l10n(`packageDashboard.columns.${cid}.${part}`);
}

/** Columns that can be auto-hidden when all values are empty or start collapsed. */
type HidableColumn = 'transitives' | 'vulns' | 'status' | 'files' | 'license' | 'description';

/**
 * Wrap the package table in a collapsible <details>. Defaults open so the
 * dashboard's primary content remains visible on first load; collapsing
 * is only useful when the user wants to focus on the chart or summary
 * cards above.
 */
export function buildPackagesSection(
    results: VibrancyResult[],
    options: ReportOptions,
): string {
    const title = escapeHtml(l10n('packageDashboard.sections.packages'));
    return `<details class="packages-section dashboard-collapsible" open>
        <summary><h2>${title}</h2></summary>
        <div class="table-scroll">${buildReportTable(results, options.overrideNames, options.packageTrends)}</div>
    </details>`;
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
            <th class="col-expand"><span class="sr-only">${escapeHtml(l10n('a11y.expandRow'))}</span></th>
            <th class="col-copy"><span class="sr-only">${escapeHtml(l10n('a11y.copyRow'))}</span></th>
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
    </tr>`;
    // The former inline detail row (buildDetailCard) is retired: selecting a row
    // now opens the richer docked detail pane (report-script openDetailPane),
    // so the dashboard has ONE detail surface instead of a light inline card
    // plus the standalone panel.
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

/**
 * Whole-month age of a published date, UTC and calendar-month aware (NOT a
 * naive `days / 365` truncation, which drifted by up to a month for older
 * packages). The day-of-month rollback below is the crux: an age only ticks
 * over to the next month once the day-of-month is reached, so 2024-09-29 →
 * 2025-09-28 is 11 months, not 12.
 *
 * `now` is injectable so the month math can be pinned in tests against a fixed
 * reference instant; production calls omit it and get the current time.
 */
export function computePublishedAgeMonths(isoDate: string | null, now: Date = new Date()): number | null {
    if (!isoDate) { return null; }
    const ms = Date.parse(isoDate);
    if (isNaN(ms)) { return null; }
    const from = new Date(ms);
    const years = now.getUTCFullYear() - from.getUTCFullYear();
    const monthsDelta = now.getUTCMonth() - from.getUTCMonth();
    let months = years * 12 + monthsDelta;
    if (now.getUTCDate() < from.getUTCDate()) {
        months -= 1;
    }
    return Math.max(0, months);
}

/**
 * Health Score breakdown panel (score factors + maintainer-quality bonuses).
 * Exported so the dashboard's docked detail pane can render it: it is the one
 * piece of the retired inline detail card the pane did not already cover, and
 * it is styled by report-styles (.detail-section / .detail-grid), which the
 * dashboard loads, so it renders correctly inside the pane.
 */
export function buildDetailScoreSection(r: VibrancyResult): string {
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
        <h3>${escapeHtml(l10n('packageDashboard.detail.healthScore'))} <span class="grade-badge grade-${grade}">${grade}</span></h3>
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
