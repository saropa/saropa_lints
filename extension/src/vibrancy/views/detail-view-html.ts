import { VibrancyResult } from '../types';
import { categoryLabel, categoryToGrade } from '../scoring/status-classifier';
import { isReplacementPackageName, getReplacementDisplayText } from '../scoring/known-issues';
import { formatSizeMB } from '../scoring/bloat-calculator';
import { formatRelativeTime } from '../scoring/time-formatter';
import { escapeHtml, resolveRepoUrl } from './html-utils';
import { getDetailStyles } from './detail-view-styles';
import { getDetailScript } from './detail-view-script';

/** Build HTML for the package detail view in the sidebar. */
export function buildDetailViewHtml(result: VibrancyResult | null): string {
    if (!result) {
        return buildPlaceholderHtml();
    }
    return buildPackageDetailHtml(result);
}

function buildPlaceholderHtml(): string {
    return `<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta http-equiv="Content-Security-Policy"
        content="default-src 'none'; style-src 'unsafe-inline'; script-src 'unsafe-inline';">
    <style>${getDetailStyles()}</style>
</head>
<body class="placeholder">
    <div class="empty-state">
        <div class="icon">📦</div>
        <p>Select a package to see details</p>
    </div>
</body>
</html>`;
}

function buildPackageDetailHtml(r: VibrancyResult): string {
    const name = escapeHtml(r.package.name);
    const grade = categoryToGrade(r.category);
    /* Letter grade only; full category name surfaces via title tooltip. */
    const gradeTitle = escapeHtml(categoryLabel(r.category));

    return `<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta http-equiv="Content-Security-Policy"
        content="default-src 'none'; style-src 'unsafe-inline'; script-src 'unsafe-inline'; img-src https:;">
    <style>${getDetailStyles()}</style>
</head>
<body>
    <header>
        ${buildSidebarLogo(r)}
        <h1>${name}</h1>
        <div class="score ${r.category}" title="${gradeTitle}">${grade}</div>
    </header>
    ${buildSidebarDescription(r)}
    ${buildSidebarTopics(r)}

    ${buildVersionSection(r)}
    ${buildUpdateSection(r)}
    ${buildSuggestionSection(r)}
    ${buildCommunitySection(r)}
    ${buildDirectDependenciesSection(r)}
    ${buildDependenciesSection(r)}
    ${buildAlertsSection(r)}
    ${buildPlatformsSection(r)}
    ${buildSidebarImagesSection(r)}
    ${buildLinksSection(r)}
    
    <script>${getDetailScript()}</script>
</body>
</html>`;
}

function buildVersionSection(r: VibrancyResult): string {
    const parts: string[] = [];

    const current = escapeHtml(r.package.constraint || r.package.version);
    const latest = r.updateInfo?.latestVersion
        ? escapeHtml(r.updateInfo.latestVersion)
        : null;

    if (latest && r.updateInfo?.updateStatus !== 'up-to-date') {
        parts.push(`<div class="detail-row">${current} → ${latest}</div>`);
    } else {
        parts.push(`<div class="detail-row">${current}</div>`);
    }

    if (r.pubDev?.publishedDate) {
        const date = r.pubDev.publishedDate.split('T')[0];
        parts.push(`<div class="detail-row muted">Published: ${date}</div>`);
    }

    if (r.license) {
        const licenseBadge = isPermissiveLicense(r.license)
            ? `${escapeHtml(r.license)} ✅`
            : escapeHtml(r.license);
        parts.push(`<div class="detail-row">${licenseBadge}</div>`);
    }

    if (r.archiveSizeBytes !== null) {
        parts.push(`<div class="detail-row muted">Size: ${formatSizeMB(r.archiveSizeBytes)}</div>`);
    }

    if (r.replacementComplexity) {
        const rc = r.replacementComplexity;
        const m = rc.metrics;
        parts.push(`<div class="detail-row muted">Source: ${m.libCodeLines.toLocaleString('en-US')} code · ${m.libCommentLines.toLocaleString('en-US')} comments · ${m.libFileCount} files</div>`);
        parts.push(`<div class="detail-row">Replace: <span class="${rc.level}">${escapeHtml(rc.summary)}</span></div>`);
    }

    return buildSection('📦 VERSION', parts);
}

function buildUpdateSection(r: VibrancyResult): string {
    if (!r.updateInfo || r.updateInfo.updateStatus === 'up-to-date') {
        return '';
    }

    const status = r.updateInfo.updateStatus;
    const statusLabel = status === 'unknown' ? '' : `(${status})`;
    const parts: string[] = [];

    parts.push(`<div class="update-header">${statusLabel}</div>`);

    const buttons: string[] = [];
    buttons.push(`<button class="action-btn" data-action="upgrade" data-package="${escapeHtml(r.package.name)}">Upgrade</button>`);

    if (r.updateInfo.changelog?.entries.length) {
        buttons.push(`<button class="action-btn secondary" data-action="changelog" data-package="${escapeHtml(r.package.name)}">Changelog</button>`);
    }

    parts.push(`<div class="button-row">${buttons.join('')}</div>`);

    if (r.blocker) {
        parts.push(`<div class="blocker-info">⚠️ Blocked by ${escapeHtml(r.blocker.blockerPackage)}</div>`);
    }

    return buildSection('⬆️ UPDATE', parts);
}

function buildSuggestionSection(r: VibrancyResult): string {
    const suggestions: string[] = [];

    if (r.knownIssue?.replacement) {
        const displayReplacement = getReplacementDisplayText(
            r.knownIssue.replacement,
            r.package.version,
            r.knownIssue.replacementObsoleteFromVersion,
        );
        if (displayReplacement) {
            if (isReplacementPackageName(displayReplacement)) {
                suggestions.push(`Consider migrating to ${escapeHtml(displayReplacement)}.`);
            } else {
                suggestions.push(`Consider: ${escapeHtml(displayReplacement)}.`);
            }
        }
    }

    if (r.knownIssue?.migrationNotes) {
        suggestions.push(escapeHtml(r.knownIssue.migrationNotes));
    }

    if (r.alternatives.length > 0) {
        const altNames = r.alternatives
            .slice(0, 3)
            .map(a => escapeHtml(a.name))
            .join(', ');
        suggestions.push(`Alternatives: ${altNames}`);
    }

    if (r.isUnused) {
        suggestions.push('This package appears to be unused — consider removing it.');
    }

    if (suggestions.length === 0) {
        return '';
    }

    const parts = suggestions.map(s => `<div class="suggestion-text">${s}</div>`);
    return buildSection('💡 SUGGESTION', parts);
}

function buildCommunitySection(r: VibrancyResult): string {
    const parts: string[] = [];

    if (r.github) {
        const gh = r.github;
        const metrics: string[] = [];
        metrics.push(`⭐ ${formatNumber(gh.stars)}`);
        if (r.likes !== null) {
            metrics.push(`❤️ ${formatNumber(r.likes)}`);
        }
        const issueCount = gh.trueOpenIssues ?? gh.openIssues;
        metrics.push(`📋 ${issueCount} issues`);
        if (gh.openPullRequests !== undefined) {
            metrics.push(`🔀 ${gh.openPullRequests} PRs`);
        }
        parts.push(`<div class="detail-row">${metrics.join('  ')}</div>`);

        const activity = gh.closedIssuesLast90d + gh.mergedPrsLast90d;
        if (activity > 0) {
            parts.push(`<div class="detail-row muted">90d: ${gh.closedIssuesLast90d} issues closed, ${gh.mergedPrsLast90d} PRs merged</div>`);
        }
        if (gh.daysSinceLastCommit !== undefined) {
            parts.push(`<div class="detail-row muted">Last commit: ${formatRelativeTime(gh.daysSinceLastCommit)}</div>`);
        }
        if (gh.isArchived) {
            parts.push(`<div class="detail-row warning">🗄️ Repository is archived</div>`);
        }
    }

    if (r.pubDev?.pubPoints !== undefined) {
        parts.push(`<div class="detail-row">${r.pubDev.pubPoints}/160 pub points</div>`);
    }

    if (r.reverseDependencyCount !== null && r.reverseDependencyCount > 0) {
        parts.push(`<div class="detail-row">📦 ${r.reverseDependencyCount.toLocaleString('en-US')} dependents</div>`);
    }

    if (r.verifiedPublisher && r.pubDev?.publisher) {
        parts.push(`<div class="detail-row">✅ ${escapeHtml(r.pubDev.publisher)}</div>`);
    }

    if (parts.length === 0) {
        return '';
    }

    return buildSection('📊 COMMUNITY', parts);
}

function buildDependenciesSection(r: VibrancyResult): string {
    const ti = r.transitiveInfo;
    if (!ti || ti.transitiveCount === 0) {
        return '';
    }

    const parts: string[] = [];
    const sharedCount = ti.sharedDeps.length;
    // Clamp to zero — sharedDeps should always be a subset of transitives
    // but defensive clamping prevents a negative display if data is inconsistent
    const uniqueCount = Math.max(0, ti.transitiveCount - sharedCount);

    // Total count with flagged indicator
    const flaggedNote = ti.flaggedCount > 0
        ? ` <span class="warning">(${ti.flaggedCount} flagged)</span>` : '';
    parts.push(
        `<div class="detail-row">`
        + `${ti.transitiveCount} transitive packages${flaggedNote}`
        + `</div>`,
    );

    if (sharedCount > 0) {
        // Visual bar showing unique vs shared proportion.
        // Shared deps are already in the project via other direct deps,
        // so they represent no additional weight — only unique deps are
        // the real cost of adding this package.
        const sharedPct = Math.round((sharedCount / ti.transitiveCount) * 100);
        const uniquePct = 100 - sharedPct;
        parts.push(
            `<div class="dep-bar">`
            + `<div class="dep-bar-unique" style="width:${uniquePct}%"></div>`
            + `<div class="dep-bar-shared" style="width:${sharedPct}%"></div>`
            + `</div>`,
        );
        parts.push(
            `<div class="detail-row">`
            + `🆕 ${uniqueCount} unique · 🔗 ${sharedCount} shared (${sharedPct}%)`
            + `</div>`,
        );

        // List shared deps with which other direct deps also use them
        const top = ti.sharedDeps.slice(0, 5);
        const sharedNames = top.map(d => escapeHtml(d)).join(', ');
        const overflow = ti.sharedDeps.length > 5
            ? ` +${ti.sharedDeps.length - 5} more` : '';
        parts.push(
            `<div class="detail-row muted">`
            + `Shared: ${sharedNames}${overflow}`
            + `</div>`,
        );
    }

    return buildSection('📊 DEPENDENCIES', parts);
}

function buildAlertsSection(r: VibrancyResult): string {
    const alerts: string[] = [];

    if (r.knownIssue) {
        const status = r.knownIssue.status;
        const reason = r.knownIssue.reason ?? '';
        alerts.push(`<div class="alert-item">${getAlertIcon(status)} ${escapeHtml(status)}: ${escapeHtml(reason)}</div>`);
    }

    if (r.github?.flaggedIssues?.length) {
        for (const issue of r.github.flaggedIssues.slice(0, 3)) {
            const issueTitle = truncate(issue.title, 50);
            alerts.push(`<div class="alert-item flagged-issue"><a href="${escapeHtml(issue.url)}" data-url="${escapeHtml(issue.url)}">🚩 #${issue.number}: ${escapeHtml(issueTitle)}</a></div>`);
        }
    }

    if (alerts.length === 0) {
        return '';
    }

    return buildSection('🚨 ALERTS', alerts);
}

function buildPlatformsSection(r: VibrancyResult): string {
    if (!r.platforms?.length) {
        return '';
    }

    const displayed = r.platforms.slice(0, 4);
    const remaining = r.platforms.length - displayed.length;
    let text = displayed.join(', ');
    if (remaining > 0) {
        text += `, +${remaining}`;
    }

    const wasmBadge = r.wasmReady ? ' 🌐 WASM' : '';

    return buildSection('📱 PLATFORMS', [
        `<div class="detail-row">${escapeHtml(text)}${wasmBadge}</div>`,
    ]);
}

function buildLinksSection(r: VibrancyResult): string {
    const pubUrl = `https://pub.dev/packages/${encodeURIComponent(r.package.name)}`;
    const repoUrl = resolveRepoUrl(r.github?.repoUrl, r.pubDev?.repositoryUrl);
    const links: string[] = [];

    // "View Full Details" opens the full editor-area detail panel
    links.push(
        `<button class="action-btn" data-action="fullDetails" `
        + `data-package="${escapeHtml(r.package.name)}">View Full Details</button>`,
    );

    const docUrl = `https://pub.dev/documentation/${encodeURIComponent(r.package.name)}/latest/`;

    // All links styled as underlined hyperlinks for discoverability
    links.push(sidebarLink(pubUrl, 'pub.dev'));
    links.push(sidebarLink(docUrl, 'Documentation'));
    links.push(sidebarLink(`${pubUrl}/changelog`, 'Changelog'));
    if (repoUrl) {
        links.push(sidebarLink(repoUrl, 'Repository'));
        links.push(sidebarLink(`${repoUrl}/issues`, 'Issues'));
        links.push(sidebarLink(`${repoUrl}/issues/new`, 'Report Issue'));
    }

    return `<div class="links-section">${links.join('')}</div>`;
}

/** Build a styled link for the sidebar detail view. */
function sidebarLink(url: string, label: string): string {
    return `<a href="${escapeHtml(url)}" data-url="${escapeHtml(url)}" class="link">${escapeHtml(label)}</a>`;
}

/** Show package logo from README in the sidebar header (lazy-loaded). */
function buildSidebarLogo(r: VibrancyResult): string {
    if (!r.readme?.logoUrl) { return ''; }
    return `<img class="sidebar-logo" src="${escapeHtml(r.readme.logoUrl)}" alt="${escapeHtml(r.package.name)} logo" />`;
}

/** Truncated description with "read more" link to pub.dev. */
function buildSidebarDescription(r: VibrancyResult): string {
    const desc = r.pubDev?.description;
    if (!desc) { return ''; }

    const pubUrl = `https://pub.dev/packages/${encodeURIComponent(r.package.name)}`;
    const maxLen = 80; // Shorter than the full panel (100) — sidebar is narrower
    if (desc.length <= maxLen) {
        return `<div class="sidebar-description">${escapeHtml(desc)}</div>`;
    }

    const slice = desc.substring(0, maxLen);
    const truncated = slice.replace(/\s+\S*$/, '') || slice;
    return `<div class="sidebar-description">${escapeHtml(truncated)}&hellip; <a href="${escapeHtml(pubUrl)}" data-url="${escapeHtml(pubUrl)}" class="link">more</a></div>`;
}

/** Topic pill badges linking to pub.dev topic search. */
function buildSidebarTopics(r: VibrancyResult): string {
    const topics = r.pubDev?.topics;
    if (!topics?.length) { return ''; }

    const badges = topics.map(t => {
        const url = `https://pub.dev/packages?q=topic%3A${encodeURIComponent(t)}`;
        return `<a href="${escapeHtml(url)}" data-url="${escapeHtml(url)}" class="sidebar-topic">#${escapeHtml(t)}</a>`;
    }).join(' ');

    return `<div class="sidebar-topics">${badges}</div>`;
}

/** Direct dependencies from the package's pubspec (clickable chips). */
function buildDirectDependenciesSection(r: VibrancyResult): string {
    const deps = r.pubDev?.dependencies;
    if (!deps?.length) { return ''; }

    const chips = deps.map(name => {
        const url = `https://pub.dev/packages/${encodeURIComponent(name)}`;
        return `<a href="${escapeHtml(url)}" data-url="${escapeHtml(url)}" class="sidebar-dep-chip">${escapeHtml(name)}</a>`;
    }).join(' ');

    return buildSection('📦 DIRECT DEPS', [`<div class="sidebar-dep-list">${chips}</div>`]);
}

/** README image gallery (up to 3 images, sidebar-sized). */
function buildSidebarImagesSection(r: VibrancyResult): string {
    const images = r.readme?.imageUrls;
    if (!images?.length) { return ''; }

    // Exclude the logo and cap at 3 for the narrower sidebar
    const galleryImages = images
        .filter(url => url !== r.readme?.logoUrl)
        .slice(0, 3);
    if (galleryImages.length === 0) { return ''; }

    const items = galleryImages.map(url =>
        `<a href="${escapeHtml(url)}" data-url="${escapeHtml(url)}">`
        + `<img src="${escapeHtml(url)}" alt="README image" loading="lazy" />`
        + `</a>`,
    ).join('');

    return buildSection('🖼️ README IMAGES', [`<div class="sidebar-gallery">${items}</div>`]);
}

function buildSection(title: string, parts: string[]): string {
    if (parts.length === 0) {
        return '';
    }
    return `
    <section class="collapsible" data-expanded="true">
        <h2 class="section-header">${title}</h2>
        <div class="section-content">
            ${parts.join('\n')}
        </div>
    </section>`;
}

function isPermissiveLicense(license: string): boolean {
    const permissive = ['MIT', 'BSD-2-Clause', 'BSD-3-Clause', 'Apache-2.0', 'ISC', 'Zlib'];
    return permissive.some(p => license.includes(p));
}

function getAlertIcon(status: string): string {
    const s = status.toLowerCase();
    if (s.includes('critical') || s.includes('security')) { return '❌'; }
    if (s.includes('deprecated') || s.includes('discontinued')) { return '⚠️'; }
    if (s.includes('unmaintained') || s.includes('archived')) { return '📦'; }
    return '⚠️';
}

function formatNumber(n: number): string {
    if (n >= 1000) {
        return `${(n / 1000).toFixed(1)}k`;
    }
    return String(n);
}

function truncate(text: string, max: number): string {
    if (text.length <= max) { return text; }
    return text.slice(0, max - 3) + '...';
}
