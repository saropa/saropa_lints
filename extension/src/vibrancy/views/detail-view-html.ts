/** * Module overview (comment coverage pass). * comment-coverage: module overview (batch). * * Vibrancy UI experiment: scoring, providers, and webview assets. */
import { VibrancyResult } from '../types';
import { categoryLabel, categoryToGrade } from '../scoring/status-classifier';
import { isReplacementPackageName, getReplacementDisplayText } from '../scoring/known-issues';
import { formatSizeMB } from '../scoring/bloat-calculator';
import { formatRelativeTime } from '../scoring/time-formatter';
import { escapeHtml, resolveRepoUrl } from './html-utils';
import { getDetailStyles } from './detail-view-styles';
import { getDetailScript } from './detail-view-script';
import { l10n } from '../../i18n/runtime';

/**
 * Assembles **sidebar package detail** HTML: placeholder when `result` is null, otherwise full panel
 * with styles from [getDetailStyles], script from [getDetailScript], and escaped fields from [escapeHtml].
 * Uses [categoryLabel] / [categoryToGrade] and known-issue replacement hints for advisory copy.
 */
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
        <p>${l10n('detailView.empty.selectPackage')}</p>
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
        parts.push(`<div class="detail-row muted">${l10n('detailView.version.published', { date })}</div>`);
    }

    if (r.license) {
        const licenseBadge = isPermissiveLicense(r.license)
            ? `${escapeHtml(r.license)} ✅`
            : escapeHtml(r.license);
        parts.push(`<div class="detail-row">${licenseBadge}</div>`);
    }

    /* Prefer code size — what the package contributes to a built app.
       Falls back to the archive total when the tarball analyzer couldn't
       run. The earlier model showed only archive size which over-reported
       by 100x+ for packages shipping example media. See
       plans/history/2026.05/2026.05.13/
       infra_vibrancy_bloat_uses_tarball_size_not_runtime.md. */
    const detailSizeBytes = r.codeSizeBytes ?? r.archiveSizeBytes;
    if (detailSizeBytes !== null) {
        const label = r.codeSizeBytes !== null
            ? l10n('detailView.version.codeSize')
            : l10n('detailView.version.archive');
        parts.push(`<div class="detail-row muted">${l10n('detailView.version.sizeLabel', { label, size: formatSizeMB(detailSizeBytes) })}</div>`);
    }

    if (r.replacementComplexity) {
        const rc = r.replacementComplexity;
        const m = rc.metrics;
        parts.push(`<div class="detail-row muted">${l10n('detailView.version.source', { code: m.libCodeLines.toLocaleString('en-US'), comments: m.libCommentLines.toLocaleString('en-US'), files: String(m.libFileCount) })}</div>`);
        parts.push(`<div class="detail-row">${l10n('detailView.version.replace', { summary: `<span class="${rc.level}">${escapeHtml(rc.summary)}</span>` })}</div>`);
    }

    return buildSection(`📦 ${l10n('detailView.section.version')}`, parts);
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
    buttons.push(`<button class="action-btn" data-action="upgrade" data-package="${escapeHtml(r.package.name)}">${l10n('detailView.update.upgrade')}</button>`);

    if (r.updateInfo.changelog?.entries.length) {
        buttons.push(`<button class="action-btn secondary" data-action="changelog" data-package="${escapeHtml(r.package.name)}">${l10n('detailView.update.changelog')}</button>`);
    }

    parts.push(`<div class="button-row">${buttons.join('')}</div>`);

    if (r.blocker) {
        parts.push(`<div class="blocker-info">⚠️ ${l10n('detailView.update.blockedBy', { package: escapeHtml(r.blocker.blockerPackage) })}</div>`);
    }

    return buildSection(`⬆️ ${l10n('detailView.section.update')}`, parts);
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
                suggestions.push(l10n('detailView.suggestion.migrateTo', { package: escapeHtml(displayReplacement) }));
            } else {
                suggestions.push(l10n('detailView.suggestion.consider', { text: escapeHtml(displayReplacement) }));
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
        suggestions.push(l10n('detailView.suggestion.alternatives', { names: altNames }));
    }

    if (r.isUnused) {
        suggestions.push(l10n('detailView.suggestion.unused'));
    }

    if (suggestions.length === 0) {
        return '';
    }

    const parts = suggestions.map(s => `<div class="suggestion-text">${s}</div>`);
    return buildSection(`💡 ${l10n('detailView.section.suggestion')}`, parts);
}

function buildCommunitySection(r: VibrancyResult): string {
    const parts: string[] = [];
    const publishAgeDays = daysSinceIsoDate(r.pubDev?.publishedDate);
    let commitAgeDays: number | undefined;

    if (r.github) {
        const gh = r.github;
        const metrics: string[] = [];
        metrics.push(`⭐ ${formatNumber(gh.stars)}`);
        if (r.likes !== null) {
            metrics.push(`❤️ ${formatNumber(r.likes)}`);
        }
        const issueCount = gh.trueOpenIssues ?? gh.openIssues;
        metrics.push(`📋 ${l10n('detailView.community.issues', { count: String(issueCount) })}`);
        if (gh.openPullRequests !== undefined) {
            metrics.push(`🔀 ${l10n('detailView.community.prs', { count: String(gh.openPullRequests) })}`);
        }
        parts.push(`<div class="detail-row">${metrics.join('  ')}</div>`);

        const activity = gh.closedIssuesLast90d + gh.mergedPrsLast90d;
        if (activity > 0) {
            parts.push(`<div class="detail-row muted">${l10n('detailView.community.activity90d', { closed: String(gh.closedIssuesLast90d), merged: String(gh.mergedPrsLast90d) })}</div>`);
        }
        if (gh.daysSinceLastCommit !== undefined) {
            commitAgeDays = gh.daysSinceLastCommit;
            parts.push(`<div class="detail-row muted">${l10n('detailView.community.lastCommit', { time: formatRelativeTime(gh.daysSinceLastCommit) })}</div>`);
        }
        if (gh.isArchived) {
            parts.push(`<div class="detail-row warning">🗄️ ${l10n('detailView.community.archived')}</div>`);
        }
    }

    if (r.pubDev?.pubPoints !== undefined) {
        parts.push(`<div class="detail-row">${l10n('detailView.community.pubPoints', { points: String(r.pubDev.pubPoints) })}</div>`);
    }
    if (publishAgeDays !== undefined) {
        parts.push(`<div class="detail-row muted">${l10n('detailView.community.latestRelease', { age: formatAgeFromDays(publishAgeDays) })}</div>`);
    }
    const dormancy = buildDormancyStatus(commitAgeDays, publishAgeDays);
    if (dormancy) {
        parts.push(`<div class="detail-row warning">⏱️ ${escapeHtml(dormancy)}</div>`);
    }

    if (r.reverseDependencyCount !== null && r.reverseDependencyCount > 0) {
        parts.push(`<div class="detail-row">📦 ${l10n('detailView.community.dependents', { count: r.reverseDependencyCount.toLocaleString('en-US') })}</div>`);
    }

    if (r.verifiedPublisher && r.pubDev?.publisher) {
        parts.push(`<div class="detail-row">✅ ${escapeHtml(r.pubDev.publisher)}</div>`);
    }

    if (parts.length === 0) {
        return '';
    }

    return buildSection(`📊 ${l10n('detailView.section.community')}`, parts);
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
        return l10n('detailView.dormancy.noActivity6mo');
    }
    if (commitAgeDays >= 90 && publishAgeDays >= 90) {
        return l10n('detailView.dormancy.noActivity3mo');
    }
    if (commitAgeDays >= 90 && publishAgeDays < 90) {
        return l10n('detailView.dormancy.codeInactive');
    }
    if (commitAgeDays < 90 && publishAgeDays >= 90) {
        return l10n('detailView.dormancy.releaseSlower');
    }
    return null;
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
        ? ` <span class="warning">${l10n('detailView.dependencies.flagged', { count: String(ti.flaggedCount) })}</span>` : '';
    parts.push(
        `<div class="detail-row">`
        + `${l10n('detailView.dependencies.transitiveCount', { count: String(ti.transitiveCount) })}${flaggedNote}`
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
            + `🆕 ${l10n('detailView.dependencies.unique', { count: String(uniqueCount) })} · 🔗 ${l10n('detailView.dependencies.shared', { count: String(sharedCount), pct: String(sharedPct) })}`
            + `</div>`,
        );

        // List shared deps with which other direct deps also use them
        const top = ti.sharedDeps.slice(0, 5);
        const sharedNames = top.map(d => escapeHtml(d)).join(', ');
        const overflow = ti.sharedDeps.length > 5
            ? ` ${l10n('detailView.dependencies.moreOverflow', { count: String(ti.sharedDeps.length - 5) })}` : '';
        parts.push(
            `<div class="detail-row muted">`
            + `${l10n('detailView.dependencies.sharedList', { names: sharedNames })}${overflow}`
            + `</div>`,
        );
    }

    return buildSection(`📊 ${l10n('detailView.section.dependencies')}`, parts);
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

    return buildSection(`🚨 ${l10n('detailView.section.alerts')}`, alerts);
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

    const wasmBadge = r.wasmReady ? ` 🌐 ${l10n('detailView.platforms.wasm')}` : '';

    return buildSection(`📱 ${l10n('detailView.section.platforms')}`, [
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
        + `data-package="${escapeHtml(r.package.name)}">${l10n('detailView.links.viewFullDetails')}</button>`,
    );

    const docUrl = `https://pub.dev/documentation/${encodeURIComponent(r.package.name)}/latest/`;

    // All links styled as underlined hyperlinks for discoverability
    links.push(sidebarLink(pubUrl, l10n('detailView.links.pubDev')));
    links.push(sidebarLink(docUrl, l10n('detailView.links.documentation')));
    links.push(sidebarLink(`${pubUrl}/changelog`, l10n('detailView.links.changelog')));
    if (repoUrl) {
        links.push(sidebarLink(repoUrl, l10n('detailView.links.repository')));
        links.push(sidebarLink(`${repoUrl}/issues`, l10n('detailView.links.issues')));
        links.push(sidebarLink(`${repoUrl}/issues/new`, l10n('detailView.links.reportIssue')));
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
    return `<img class="sidebar-logo" src="${escapeHtml(r.readme.logoUrl)}" alt="${escapeHtml(l10n('detailView.logoAlt', { packageName: r.package.name }))}" />`;
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
    return `<div class="sidebar-description">${escapeHtml(truncated)}&hellip; <a href="${escapeHtml(pubUrl)}" data-url="${escapeHtml(pubUrl)}" class="link">${l10n('detailView.readMore')}</a></div>`;
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

    return buildSection(`📦 ${l10n('detailView.section.directDeps')}`, [`<div class="sidebar-dep-list">${chips}</div>`]);
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
        + `<img src="${escapeHtml(url)}" alt="${escapeHtml(l10n('detailView.readmeImageAlt'))}" loading="lazy" />`
        + `</a>`,
    ).join('');

    return buildSection(`🖼️ ${l10n('detailView.section.readmeImages')}`, [`<div class="sidebar-gallery">${items}</div>`]);
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
