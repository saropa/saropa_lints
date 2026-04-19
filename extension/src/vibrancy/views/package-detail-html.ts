import {
    VibrancyResult, VersionGapResult, ReviewEntry, activeFileUsages,
} from '../types';
import { ReviewSummary } from '../services/review-state';
import { categoryLabel, categoryToGrade, scoreToGrade } from '../scoring/status-classifier';
import { formatSizeMB } from '../scoring/bloat-calculator';
import { classifyLicense, licenseEmoji } from '../scoring/license-classifier';
import { worstSeverity, severityEmoji, severityLabel } from '../scoring/vuln-classifier';
import { formatRelativeTime } from '../scoring/time-formatter';
import { formatPrereleaseTag } from '../scoring/prerelease-classifier';
import { escapeHtml, resolveRepoUrl } from './html-utils';
import { getPackageDetailStyles } from './package-detail-styles';
import { getPackageDetailScript } from './package-detail-script';

/**
 * Build the full HTML for the package detail webview panel.
 * All sections are rendered — version-gap section shows spinner if data is pending.
 */
export function buildPackageDetailHtml(
    result: VibrancyResult,
    reviews: readonly ReviewEntry[],
    reviewSummary: ReviewSummary | null,
): string {
    const parts = [
        buildHeader(result),
        buildDescriptionSection(result),
        buildTopicsSection(result),
        buildVersionSection(result),
        buildCommunitySection(result),
        buildFileUsagesSection(result),
        buildDependenciesSection(result),
        buildAlertsSection(result),
        buildVersionGapSection(result.versionGap, 'Version Gap', reviews, reviewSummary),
        buildVersionGapSection(result.overrideGap, 'Override Gap', reviews, reviewSummary),
        buildPlatformsSection(result),
        buildSuggestionsSection(result),
        buildImagesSection(result),
        buildLinksRow(result),
    ];

    return wrapHtml(result.package.name, parts.join('\n'));
}

// ---------------------------------------------------------------------------
// Sections
// ---------------------------------------------------------------------------

function buildHeader(r: VibrancyResult): string {
    const badgeClass = categoryBadgeClass(r.category);
    const grade = categoryToGrade(r.category);
    /* Letter grade only in the header badge; full category label lives in the title tooltip. */
    const cat = escapeHtml(categoryLabel(r.category));
    const license = r.license ? escapeHtml(r.license) : '';
    const pubUrl = `https://pub.dev/packages/${encodeURIComponent(r.package.name)}`;
    const repoUrl = resolveRepoUrl(r.github?.repoUrl, r.pubDev?.repositoryUrl);

    const docUrl = `https://pub.dev/documentation/${encodeURIComponent(r.package.name)}/latest/`;

    const links: string[] = [];
    links.push(actionLink(pubUrl, 'pub.dev'));
    links.push(actionLink(docUrl, 'Documentation'));
    links.push(actionLink(`${pubUrl}/changelog`, 'Changelog'));
    links.push(actionLink(`${pubUrl}/versions`, 'Versions'));
    if (repoUrl) {
        links.push(actionLink(repoUrl, 'Repository'));
        links.push(actionLink(`${repoUrl}/issues`, 'Open Issues'));
        links.push(actionLink(`${repoUrl}/issues/new`, 'Report Issue'));
    }

    // Show package logo from README if available (lazy-loaded)
    const logoHtml = r.readme?.logoUrl
        ? `<img class="package-logo" src="${escapeHtml(r.readme.logoUrl)}" alt="${escapeHtml(r.package.name)} logo" />`
        : '';

    return `
        <div class="header">
            ${logoHtml}<h1>${escapeHtml(r.package.name)}</h1>
            <span>v${escapeHtml(r.package.version)}</span>
            <span class="badge ${badgeClass}" title="${cat}">${grade}</span>
            <div class="header-meta">
                ${license ? `${license} &middot; ` : ''}${links.join(' &middot; ')}
            </div>
        </div>
    `;
}

function buildDescriptionSection(r: VibrancyResult): string {
    const desc = r.pubDev?.description;
    if (!desc) { return ''; }

    const pubUrl = `https://pub.dev/packages/${encodeURIComponent(r.package.name)}`;
    const maxLen = 100;

    if (desc.length <= maxLen) {
        return `<div class="description-text">${escapeHtml(desc)}</div>`;
    }

    // Truncate at the last word boundary within maxLen. If no whitespace
    // exists (e.g. a single long URL), falls back to the hard maxLen cut.
    const slice = desc.substring(0, maxLen);
    const truncated = slice.replace(/\s+\S*$/, '') || slice;
    return `<div class="description-text">${escapeHtml(truncated)}&hellip; ${actionLink(pubUrl, 'read more')}</div>`;
}

function buildTopicsSection(r: VibrancyResult): string {
    const topics = r.pubDev?.topics;
    if (!topics?.length) { return ''; }

    const badges = topics.map(t => {
        const url = `https://pub.dev/packages?q=topic%3A${encodeURIComponent(t)}`;
        return `<a href="#" class="topic-badge" data-action="openUrl" data-url="${escapeHtml(url)}">#${escapeHtml(t)}</a>`;
    }).join(' ');

    return `<div class="topics-row">${badges}</div>`;
}

function buildVersionSection(r: VibrancyResult): string {
    const rows: string[] = [];

    rows.push(row('Constraint', escapeHtml(r.package.constraint)));
    if (r.pubDev) {
        rows.push(row('Latest', escapeHtml(r.pubDev.latestVersion)));
        if (r.latestPrerelease) {
            const tag = formatPrereleaseTag(r.prereleaseTag);
            rows.push(row('Prerelease', `${escapeHtml(r.latestPrerelease)} (${escapeHtml(tag)})`));
        }
        rows.push(row('Published', escapeHtml(r.pubDev.publishedDate.split('T')[0])));
    }
    if (r.updateInfo && r.updateInfo.updateStatus !== 'up-to-date') {
        rows.push(row('Update',
            `${escapeHtml(r.updateInfo.currentVersion)} &rarr; ${escapeHtml(r.updateInfo.latestVersion)} (${escapeHtml(r.updateInfo.updateStatus)})`));
        if (r.blocker) {
            rows.push(row('Blocked by', `<strong>${escapeHtml(r.blocker.blockerPackage)}</strong>`));
        }
    }
    if (r.archiveSizeBytes !== null) {
        const sizeMB = formatSizeMB(r.archiveSizeBytes);
        const bloat = r.bloatRating !== null ? ` (${r.bloatRating}/10 bloat)` : '';
        rows.push(row('Size', `${sizeMB}${bloat}`));
    }

    const buttons: string[] = [];
    if (r.updateInfo && r.updateInfo.updateStatus !== 'up-to-date' && !r.blocker) {
        buttons.push(
            `<button class="action-btn" data-action="upgrade" `
            + `data-name="${escapeHtml(r.package.name)}" `
            + `data-version="${escapeHtml(r.updateInfo.latestVersion)}">Upgrade</button>`,
        );
    }
    const changelogUrl = `https://pub.dev/packages/${encodeURIComponent(r.package.name)}/changelog`;
    // Styled as a secondary button (not an <a>) to match the Upgrade button visually
    buttons.push(
        `<button class="action-btn secondary" data-action="openUrl" `
        + `data-url="${escapeHtml(changelogUrl)}">View Changelog</button>`,
    );

    return section('VERSION', `
        <table class="metrics-table"><tbody>${rows.join('')}</tbody></table>
        <div>${buttons.join('')}</div>
    `);
}

function buildCommunitySection(r: VibrancyResult): string {
    if (!r.github && !r.pubDev) { return ''; }
    const rows: string[] = [];

    if (r.github) {
        const gh = r.github;
        const repoUrl = resolveRepoUrl(gh.repoUrl, r.pubDev?.repositoryUrl);
        rows.push(row('Stars', `${gh.stars}`));
        if (r.likes !== null) {
            rows.push(row('Likes', `${r.likes}`));
        }
        const issues = gh.trueOpenIssues ?? gh.openIssues;
        // Make issue/PR counts clickable links to the GitHub pages
        const issueLink = repoUrl
            ? `${actionLink(`${repoUrl}/issues`, `${issues}`)} · ${actionLink(`${repoUrl}/issues/new`, 'Report')}`
            : `${issues}`;
        rows.push(row('Open Issues', issueLink));
        if (gh.openPullRequests !== undefined) {
            const prLink = repoUrl
                ? actionLink(`${repoUrl}/pulls`, `${gh.openPullRequests}`)
                : `${gh.openPullRequests}`;
            rows.push(row('Open PRs', prLink));
        }
        const activity = gh.closedIssuesLast90d + gh.mergedPrsLast90d;
        rows.push(row('Activity (90d)',
            activity > 0
                ? `${gh.closedIssuesLast90d} issues closed, ${gh.mergedPrsLast90d} PRs merged`
                : 'No recent activity'));
        if (gh.daysSinceLastCommit !== undefined) {
            rows.push(row('Last Commit', formatRelativeTime(gh.daysSinceLastCommit)));
        }
    }

    if (r.pubDev) {
        rows.push(row('Pub Points', `${r.pubDev.pubPoints}`));
        if (r.pubDev.publisher) {
            const badge = r.verifiedPublisher ? ' (verified)' : '';
            rows.push(row('Publisher', `${escapeHtml(r.pubDev.publisher)}${badge}`));
        }
    }
    if (r.transitiveInfo && r.transitiveInfo.transitiveCount > 0) {
        const flagged = r.transitiveInfo.flaggedCount > 0
            ? ` (${r.transitiveInfo.flaggedCount} flagged)` : '';
        rows.push(row('Transitive Deps', `${r.transitiveInfo.transitiveCount}${flagged}`));

        // True footprint: own archive + transitives this dep pulls in.
        // Distinguish unique (eliminated by removing this dep) from shared
        // (still pulled in by other direct deps after removal). When neither
        // size field is populated (null/undefined for fixtures from older
        // builds), skip the row so we don't render a misleading 0 MB.
        const own = r.archiveSizeBytes ?? 0;
        const uniqueT = r.transitiveInfo.uniqueTransitiveSizeBytes;
        const sharedT = r.transitiveInfo.sharedTransitiveSizeBytes;
        const haveData = (uniqueT !== null && uniqueT !== undefined)
            || (sharedT !== null && sharedT !== undefined);
        if (haveData) {
            const unique = uniqueT ?? 0;
            const shared = sharedT ?? 0;
            const ifRemoved = own + unique;
            const total = own + unique + shared;
            const breakdown = shared > 0
                ? `${formatSizeMB(ifRemoved)} unique &middot; +${formatSizeMB(shared)} shared = ${formatSizeMB(total)} total`
                : `${formatSizeMB(total)}`;
            rows.push(row(
                'True Footprint',
                `<span title="Own ${formatSizeMB(own)} + unique transitives ${formatSizeMB(unique)} + shared transitives ${formatSizeMB(shared)}. `
                + `Removing this dep saves ${formatSizeMB(ifRemoved)} (shared deps stay pulled in by others).">`
                + `${breakdown}</span>`,
            ));
        }
    }
    if (r.reverseDependencyCount !== null && r.reverseDependencyCount > 0) {
        // Link to pub.dev search for packages depending on this one
        const depSearchUrl = `https://pub.dev/packages?q=dependency%3A${encodeURIComponent(r.package.name)}`;
        rows.push(row('Dependents', `${actionLink(depSearchUrl, `${r.reverseDependencyCount.toLocaleString('en-US')} packages`)}`));
    }

    return section('COMMUNITY', `<table class="metrics-table"><tbody>${rows.join('')}</tbody></table>`);
}

function buildFileUsagesSection(r: VibrancyResult): string {
    const active = activeFileUsages(r.fileUsages);
    const commented = r.fileUsages.filter(u => u.isCommented);
    if (active.length === 0 && commented.length === 0) { return ''; }

    const items: string[] = [];
    for (const u of active) {
        const display = escapeHtml(`${u.filePath}:${u.line}`);
        items.push(
            `<div class="file-usage-item">`
            + `<a href="#" data-action="openFile" data-path="${escapeHtml(u.filePath)}" data-line="${u.line}">${display}</a>`
            + `</div>`,
        );
    }
    if (commented.length > 0) {
        items.push(`<div class="file-usage-commented">Commented-out references:</div>`);
        for (const u of commented) {
            const display = escapeHtml(`${u.filePath}:${u.line}`);
            items.push(
                `<div class="file-usage-item commented">`
                + `<a href="#" data-action="openFile" data-path="${escapeHtml(u.filePath)}" data-line="${u.line}">${display}</a>`
                + `</div>`,
            );
        }
    }

    const count = active.length;
    const label = count === 1 ? '1 file' : `${count} files`;
    return section(`FILE USAGES (${label})`, items.join(''));
}

function buildDependenciesSection(r: VibrancyResult): string {
    const deps = r.pubDev?.dependencies;
    if (!deps?.length) { return ''; }

    const chips = deps.map(name => {
        const url = `https://pub.dev/packages/${encodeURIComponent(name)}`;
        return `<a href="#" class="dep-chip" data-action="openUrl" data-url="${escapeHtml(url)}">${escapeHtml(name)}</a>`;
    }).join(' ');

    return section('DEPENDENCIES', `<div class="dep-list">${chips}</div>`);
}

function buildAlertsSection(r: VibrancyResult): string {
    const items: string[] = [];

    if (r.github?.isArchived) {
        items.push(alertItem('ARCHIVED — repository is read-only', 'critical'));
    }
    if (r.knownIssue?.reason) {
        items.push(alertItem(`Known Issue: ${r.knownIssue.reason}`, 'critical'));
    }
    if (r.isUnused) {
        items.push(alertItem('Unused — no imports detected', 'info'));
    }

    // Flagged issues
    const flagged = r.github?.flaggedIssues ?? [];
    for (const issue of flagged) {
        const signals = issue.matchedSignals.join(', ');
        items.push(alertItem(
            `<a href="#" data-action="openUrl" data-url="${escapeHtml(issue.url)}">`
            + `#${issue.number}</a>: ${escapeHtml(truncate(issue.title, 80))} `
            + `<em>(${escapeHtml(signals)})</em>`,
            'info',
        ));
    }

    // Vulnerabilities
    for (const vuln of r.vulnerabilities) {
        const icon = severityEmoji(vuln.severity);
        const fixInfo = vuln.fixedVersion ? ` — fix: ${escapeHtml(vuln.fixedVersion)}` : '';
        items.push(alertItem(
            `${icon} <a href="#" data-action="openUrl" data-url="${escapeHtml(vuln.url)}">`
            + `${escapeHtml(vuln.id)}</a>: `
            + `<span class="vuln-severity-${vuln.severity}">${escapeHtml(vuln.summary)}</span>`
            + fixInfo,
            vuln.severity === 'critical' || vuln.severity === 'high' ? 'critical' : 'info',
        ));
    }

    if (items.length === 0) { return ''; }
    return section('ALERTS', items.join(''));
}

function buildVersionGapSection(
    gap: VersionGapResult | null,
    label: string,
    reviews: readonly ReviewEntry[],
    summary: ReviewSummary | null,
): string {
    if (!gap) { return ''; }
    if (gap.items.length === 0 && !gap.fromDate) {
        // Could not determine version dates — show empty message
        return section(`${label} (${escapeHtml(gap.currentVersion)} → ${escapeHtml(gap.latestVersion)})`,
            '<div class="loading-spinner">Could not determine version dates for this package.</div>');
    }
    if (gap.items.length === 0) {
        return section(`${label} (${escapeHtml(gap.currentVersion)} → ${escapeHtml(gap.latestVersion)})`,
            '<div class="loading-spinner">No PRs or issues found between these versions.</div>');
    }

    // Unique prefix per section so IDs don't collide when both gaps render
    const sectionId = label.toLowerCase().replace(/\s+/g, '-');

    const reviewMap = new Map(reviews.map(r => [r.itemNumber, r]));

    const prCount = gap.items.filter(i => i.type === 'pr').length;
    const issueCount = gap.items.filter(i => i.type === 'issue').length;

    const summaryCards = `
        <div class="gap-summary">
            <div class="gap-card">
                <div class="count">${prCount}</div>
                <div class="label">PRs merged</div>
            </div>
            <div class="gap-card">
                <div class="count">${issueCount}</div>
                <div class="label">Issues closed</div>
            </div>
        </div>
    `;

    const toolbar = `
        <div class="gap-toolbar" data-section="${sectionId}">
            <input type="text" class="gap-search" placeholder="Search PRs and issues...">
            <button class="filter-btn active" data-filter="all">All</button>
            <button class="filter-btn" data-filter="unreviewed">Unreviewed</button>
            <button class="filter-btn" data-filter="prs">PRs</button>
            <button class="filter-btn" data-filter="issues">Issues</button>
        </div>
    `;

    const tableRows = gap.items.map(item => {
        const review = reviewMap.get(item.number);
        const status = review?.status ?? 'unreviewed';
        const notes = review?.notes ?? '';
        const typeClass = item.type === 'pr' ? 'type-pr' : 'type-issue';
        const typeLabel = item.type === 'pr' ? 'PR' : 'Issue';
        const searchText = [
            `#${item.number}`, item.title, item.author,
            ...item.labels, typeLabel, status,
        ].join(' ').toLowerCase();

        return `
            <tr data-number="${item.number}"
                data-type="${item.type}"
                data-review="${status}"
                data-searchtext="${escapeHtml(searchText)}">
                <td data-sort-number="${item.number}">
                    <a href="#" data-action="openUrl" data-url="${escapeHtml(item.url)}"
                       class="${typeClass}">#${item.number}</a>
                </td>
                <td class="${typeClass}" data-sort-type="${item.type}">${typeLabel}</td>
                <td data-sort-title="${escapeHtml(item.title)}">
                    ${escapeHtml(truncate(item.title, 80))}
                    ${item.labels.length > 0
                        ? `<br><small>${item.labels.map(l => escapeHtml(l)).join(', ')}</small>`
                        : ''}
                </td>
                <td data-sort-author="${escapeHtml(item.author)}">${escapeHtml(item.author)}</td>
                <td>
                    <select class="review-select" value="${status}">
                        <option value="unreviewed"${status === 'unreviewed' ? ' selected' : ''}>—</option>
                        <option value="reviewed"${status === 'reviewed' ? ' selected' : ''}>Reviewed</option>
                        <option value="applicable"${status === 'applicable' ? ' selected' : ''}>Applicable</option>
                        <option value="not-applicable"${status === 'not-applicable' ? ' selected' : ''}>N/A</option>
                    </select>
                    <input class="notes-input" type="text"
                           placeholder="Notes..."
                           value="${escapeHtml(notes)}">
                </td>
            </tr>
        `;
    }).join('');

    const table = `
        <table class="gap-table">
            <thead>
                <tr>
                    <th data-col="number">#<span class="sort-arrow"></span></th>
                    <th data-col="type">Type<span class="sort-arrow"></span></th>
                    <th data-col="title">Title<span class="sort-arrow"></span></th>
                    <th data-col="author">Author<span class="sort-arrow"></span></th>
                    <th>Review</th>
                </tr>
            </thead>
            <tbody>${tableRows}</tbody>
        </table>
    `;

    const footerText = summary
        ? `${summary.triaged} of ${summary.total} triaged | `
            + `${summary.applicable} applicable | `
            + `${summary.notApplicable} N/A | `
            + `${summary.unreviewed} remaining`
        : '';
    const footer = `<div class="gap-footer review-summary">${footerText}</div>`;

    const truncatedNote = gap.truncated
        ? `<div class="gap-footer"><em>Results truncated to 100 items.</em></div>` : '';

    const title = `${label} (${escapeHtml(gap.currentVersion)} → ${escapeHtml(gap.latestVersion)})`;
    return section(title, summaryCards + toolbar + table + footer + truncatedNote);
}

function buildPlatformsSection(r: VibrancyResult): string {
    if (!r.platforms?.length) { return ''; }
    const platforms = r.platforms.map(p => escapeHtml(p)).join(', ');
    const wasm = r.wasmReady ? ' &middot; WASM' : '';
    return section('PLATFORMS', `<div>${platforms}${wasm}</div>`);
}

function buildSuggestionsSection(r: VibrancyResult): string {
    if (!r.alternatives?.length) { return ''; }
    const items = r.alternatives.map(alt => {
        /* Letter grade only (alts don't carry a category, so derive from score). */
        const gradeText = alt.score !== null ? ` (${scoreToGrade(alt.score)})` : '';
        const url = `https://pub.dev/packages/${encodeURIComponent(alt.name)}`;
        return `<div>
            <a href="#" data-action="openUrl" data-url="${escapeHtml(url)}">${escapeHtml(alt.name)}</a>${gradeText}
        </div>`;
    }).join('');
    return section('SUGGESTIONS', items);
}

function buildImagesSection(r: VibrancyResult): string {
    const images = r.readme?.imageUrls;
    if (!images?.length) { return ''; }

    // Exclude the logo (already shown in header) and cap at 4 gallery images
    const galleryImages = images
        .filter(url => url !== r.readme?.logoUrl)
        .slice(0, 4);
    if (galleryImages.length === 0) { return ''; }

    const items = galleryImages.map(url =>
        `<a href="#" data-action="openUrl" data-url="${escapeHtml(url)}">`
        + `<img src="${escapeHtml(url)}" alt="README image" loading="lazy" />`
        + `</a>`,
    ).join('');

    return section('README IMAGES', `<div class="image-gallery">${items}</div>`);
}

function buildLinksRow(r: VibrancyResult): string {
    const pubUrl = `https://pub.dev/packages/${encodeURIComponent(r.package.name)}`;
    const docUrl = `https://pub.dev/documentation/${encodeURIComponent(r.package.name)}/latest/`;
    const repoUrl = resolveRepoUrl(r.github?.repoUrl, r.pubDev?.repositoryUrl);
    const links: string[] = [];
    links.push(actionLink(pubUrl, 'View on pub.dev'));
    links.push(actionLink(docUrl, 'Documentation'));
    links.push(actionLink(`${pubUrl}/changelog`, 'Changelog'));
    links.push(actionLink(`${pubUrl}/versions`, 'Versions'));
    if (repoUrl) {
        links.push(actionLink(repoUrl, 'Repository'));
        links.push(actionLink(`${repoUrl}/issues`, 'Open Issues'));
        links.push(actionLink(`${repoUrl}/issues/new`, 'Report Issue'));
    }
    return `<div class="links-row">${links.join(' &middot; ')}</div>`;
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/** Build an <a> tag styled as a link that opens a URL via the webview message handler. */
function actionLink(url: string, label: string): string {
    return `<a href="#" class="action-link" data-action="openUrl" data-url="${escapeHtml(url)}">${escapeHtml(label)}</a>`;
}

function section(title: string, body: string): string {
    return `
        <div class="section">
            <div class="section-header">${title}</div>
            <div class="section-body">${body}</div>
        </div>
    `;
}

function row(label: string, value: string): string {
    return `<tr><td>${escapeHtml(label)}</td><td>${value}</td></tr>`;
}

function alertItem(html: string, severity: 'critical' | 'info'): string {
    return `<div class="alert-item ${severity}">${html}</div>`;
}

function categoryBadgeClass(cat: string): string {
    if (cat === 'vibrant') { return 'badge-vibrant'; }
    if (cat === 'stable') { return 'badge-stable'; }
    if (cat === 'outdated') { return 'badge-outdated'; }
    if (cat === 'abandoned') { return 'badge-abandoned'; }
    if (cat === 'end-of-life') { return 'badge-eol'; }
    return '';
}

function truncate(text: string, max: number): string {
    return text.length > max ? text.substring(0, max - 3) + '...' : text;
}

function wrapHtml(title: string, body: string): string {
    return `<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta http-equiv="Content-Security-Policy"
          content="default-src 'none'; style-src 'unsafe-inline'; script-src 'unsafe-inline'; img-src https:;">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>${escapeHtml(title)}</title>
    <style>${getPackageDetailStyles()}</style>
</head>
<body>
    ${body}
    <script>${getPackageDetailScript()}</script>
</body>
</html>`;
}
