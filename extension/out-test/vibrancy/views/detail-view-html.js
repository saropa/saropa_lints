"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.buildDetailViewHtml = buildDetailViewHtml;
const status_classifier_1 = require("../scoring/status-classifier");
const known_issues_1 = require("../scoring/known-issues");
const bloat_calculator_1 = require("../scoring/bloat-calculator");
const time_formatter_1 = require("../scoring/time-formatter");
const html_utils_1 = require("./html-utils");
const detail_view_styles_1 = require("./detail-view-styles");
const detail_view_script_1 = require("./detail-view-script");
/** Build HTML for the package detail view in the sidebar. */
function buildDetailViewHtml(result) {
    if (!result) {
        return buildPlaceholderHtml();
    }
    return buildPackageDetailHtml(result);
}
function buildPlaceholderHtml() {
    return `<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta http-equiv="Content-Security-Policy"
        content="default-src 'none'; style-src 'unsafe-inline'; script-src 'unsafe-inline';">
    <style>${(0, detail_view_styles_1.getDetailStyles)()}</style>
</head>
<body class="placeholder">
    <div class="empty-state">
        <div class="icon">📦</div>
        <p>Select a package to see details</p>
    </div>
</body>
</html>`;
}
function buildPackageDetailHtml(r) {
    const displayScore = Math.round(r.score / 10);
    const name = (0, html_utils_1.escapeHtml)(r.package.name);
    return `<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta http-equiv="Content-Security-Policy"
        content="default-src 'none'; style-src 'unsafe-inline'; script-src 'unsafe-inline';">
    <style>${(0, detail_view_styles_1.getDetailStyles)()}</style>
</head>
<body>
    <header>
        <h1>${name}</h1>
        <div class="score ${r.category}">${displayScore}/10</div>
    </header>
    <div class="category-badge ${r.category}">${(0, status_classifier_1.categoryLabel)(r.category)}</div>
    
    ${buildVersionSection(r)}
    ${buildUpdateSection(r)}
    ${buildSuggestionSection(r)}
    ${buildCommunitySection(r)}
    ${buildAlertsSection(r)}
    ${buildPlatformsSection(r)}
    ${buildLinksSection(r)}
    
    <script>${(0, detail_view_script_1.getDetailScript)()}</script>
</body>
</html>`;
}
function buildVersionSection(r) {
    const parts = [];
    const current = (0, html_utils_1.escapeHtml)(r.package.constraint || r.package.version);
    const latest = r.updateInfo?.latestVersion
        ? (0, html_utils_1.escapeHtml)(r.updateInfo.latestVersion)
        : null;
    if (latest && r.updateInfo?.updateStatus !== 'up-to-date') {
        parts.push(`<div class="detail-row">${current} → ${latest}</div>`);
    }
    else {
        parts.push(`<div class="detail-row">${current}</div>`);
    }
    if (r.pubDev?.publishedDate) {
        const date = r.pubDev.publishedDate.split('T')[0];
        parts.push(`<div class="detail-row muted">Published: ${date}</div>`);
    }
    if (r.license) {
        const licenseBadge = isPermissiveLicense(r.license)
            ? `${(0, html_utils_1.escapeHtml)(r.license)} ✅`
            : (0, html_utils_1.escapeHtml)(r.license);
        parts.push(`<div class="detail-row">${licenseBadge}</div>`);
    }
    if (r.archiveSizeBytes !== null) {
        parts.push(`<div class="detail-row muted">Size: ${(0, bloat_calculator_1.formatSizeMB)(r.archiveSizeBytes)}</div>`);
    }
    return buildSection('📦 VERSION', parts);
}
function buildUpdateSection(r) {
    if (!r.updateInfo || r.updateInfo.updateStatus === 'up-to-date') {
        return '';
    }
    const status = r.updateInfo.updateStatus;
    const statusLabel = status === 'unknown' ? '' : `(${status})`;
    const parts = [];
    parts.push(`<div class="update-header">${statusLabel}</div>`);
    const buttons = [];
    buttons.push(`<button class="action-btn" data-action="upgrade" data-package="${(0, html_utils_1.escapeHtml)(r.package.name)}">Upgrade</button>`);
    if (r.updateInfo.changelog?.entries.length) {
        buttons.push(`<button class="action-btn secondary" data-action="changelog" data-package="${(0, html_utils_1.escapeHtml)(r.package.name)}">Changelog</button>`);
    }
    parts.push(`<div class="button-row">${buttons.join('')}</div>`);
    if (r.blocker) {
        parts.push(`<div class="blocker-info">⚠️ Blocked by ${(0, html_utils_1.escapeHtml)(r.blocker.blockerPackage)}</div>`);
    }
    return buildSection('⬆️ UPDATE', parts);
}
function buildSuggestionSection(r) {
    const suggestions = [];
    if (r.knownIssue?.replacement) {
        const displayReplacement = (0, known_issues_1.getReplacementDisplayText)(r.knownIssue.replacement, r.package.version, r.knownIssue.replacementObsoleteFromVersion);
        if (displayReplacement) {
            if ((0, known_issues_1.isReplacementPackageName)(displayReplacement)) {
                suggestions.push(`Consider migrating to ${(0, html_utils_1.escapeHtml)(displayReplacement)}.`);
            }
            else {
                suggestions.push(`Consider: ${(0, html_utils_1.escapeHtml)(displayReplacement)}.`);
            }
        }
    }
    if (r.knownIssue?.migrationNotes) {
        suggestions.push((0, html_utils_1.escapeHtml)(r.knownIssue.migrationNotes));
    }
    if (r.alternatives.length > 0) {
        const altNames = r.alternatives
            .slice(0, 3)
            .map(a => (0, html_utils_1.escapeHtml)(a.name))
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
function buildCommunitySection(r) {
    const parts = [];
    if (r.github) {
        const gh = r.github;
        const metrics = [];
        metrics.push(`⭐ ${formatNumber(gh.stars)}`);
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
            parts.push(`<div class="detail-row muted">Last commit: ${(0, time_formatter_1.formatRelativeTime)(gh.daysSinceLastCommit)}</div>`);
        }
        if (gh.isArchived) {
            parts.push(`<div class="detail-row warning">🗄️ Repository is archived</div>`);
        }
    }
    if (r.pubDev?.pubPoints !== undefined) {
        parts.push(`<div class="detail-row">${r.pubDev.pubPoints}/160 pub points</div>`);
    }
    if (r.verifiedPublisher && r.pubDev?.publisher) {
        parts.push(`<div class="detail-row">✅ ${(0, html_utils_1.escapeHtml)(r.pubDev.publisher)}</div>`);
    }
    if (r.drift) {
        const driftLabel = r.drift.label === 'current' ? '✓ Current'
            : r.drift.label === 'recent' ? '✓ Recent'
                : `${r.drift.releasesBehind} releases behind (${r.drift.label})`;
        parts.push(`<div class="detail-row muted">Drift: ${driftLabel}</div>`);
    }
    if (parts.length === 0) {
        return '';
    }
    return buildSection('📊 COMMUNITY', parts);
}
function buildAlertsSection(r) {
    const alerts = [];
    if (r.knownIssue) {
        const status = r.knownIssue.status;
        const reason = r.knownIssue.reason ?? '';
        alerts.push(`<div class="alert-item">${getAlertIcon(status)} ${(0, html_utils_1.escapeHtml)(status)}: ${(0, html_utils_1.escapeHtml)(reason)}</div>`);
    }
    if (r.github?.flaggedIssues?.length) {
        for (const issue of r.github.flaggedIssues.slice(0, 3)) {
            const issueTitle = truncate(issue.title, 50);
            alerts.push(`<div class="alert-item flagged-issue"><a href="${(0, html_utils_1.escapeHtml)(issue.url)}" data-url="${(0, html_utils_1.escapeHtml)(issue.url)}">🚩 #${issue.number}: ${(0, html_utils_1.escapeHtml)(issueTitle)}</a></div>`);
        }
    }
    if (alerts.length === 0) {
        return '';
    }
    return buildSection('🚨 ALERTS', alerts);
}
function buildPlatformsSection(r) {
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
        `<div class="detail-row">${(0, html_utils_1.escapeHtml)(text)}${wasmBadge}</div>`,
    ]);
}
function buildLinksSection(r) {
    const pubUrl = `https://pub.dev/packages/${encodeURIComponent(r.package.name)}`;
    const links = [];
    links.push(`<a href="${pubUrl}" data-url="${pubUrl}" class="link">View on pub.dev</a>`);
    // Prefer canonical GitHub URL (may differ from pubspec URL which can include /tree/main)
    const repoLink = r.github?.repoUrl ?? r.pubDev?.repositoryUrl;
    if (repoLink) {
        links.push(`<a href="${(0, html_utils_1.escapeHtml)(repoLink)}" data-url="${(0, html_utils_1.escapeHtml)(repoLink)}" class="link">Repository</a>`);
    }
    return `<div class="links-section">${links.join('')}</div>`;
}
function buildSection(title, parts) {
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
function isPermissiveLicense(license) {
    const permissive = ['MIT', 'BSD-2-Clause', 'BSD-3-Clause', 'Apache-2.0', 'ISC', 'Zlib'];
    return permissive.some(p => license.includes(p));
}
function getAlertIcon(status) {
    const s = status.toLowerCase();
    if (s.includes('critical') || s.includes('security')) {
        return '❌';
    }
    if (s.includes('deprecated') || s.includes('discontinued')) {
        return '⚠️';
    }
    if (s.includes('unmaintained') || s.includes('archived')) {
        return '📦';
    }
    return '⚠️';
}
function formatNumber(n) {
    if (n >= 1000) {
        return `${(n / 1000).toFixed(1)}k`;
    }
    return String(n);
}
function truncate(text, max) {
    if (text.length <= max) {
        return text;
    }
    return text.slice(0, max - 3) + '...';
}
//# sourceMappingURL=detail-view-html.js.map