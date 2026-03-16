import { VibrancyResult } from '../types';
import { categoryLabel } from '../scoring/status-classifier';
import { isReplacementPackageName, getReplacementDisplayText } from '../scoring/known-issues';
import { formatSizeMB } from '../scoring/bloat-calculator';
import { escapeHtml } from './html-utils';
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
    const displayScore = Math.round(r.score / 10);
    const name = escapeHtml(r.package.name);

    return `<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta http-equiv="Content-Security-Policy"
        content="default-src 'none'; style-src 'unsafe-inline'; script-src 'unsafe-inline';">
    <style>${getDetailStyles()}</style>
</head>
<body>
    <header>
        <h1>${name}</h1>
        <div class="score ${r.category}">${displayScore}/10</div>
    </header>
    <div class="category-badge ${r.category}">${categoryLabel(r.category)}</div>
    
    ${buildVersionSection(r)}
    ${buildUpdateSection(r)}
    ${buildSuggestionSection(r)}
    ${buildCommunitySection(r)}
    ${buildAlertsSection(r)}
    ${buildPlatformsSection(r)}
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
        const metrics: string[] = [];
        metrics.push(`⭐ ${formatNumber(r.github.stars)}`);
        metrics.push(`📋 ${r.github.openIssues} issues`);
        parts.push(`<div class="detail-row">${metrics.join('  ')}</div>`);
    }

    if (r.pubDev?.pubPoints !== undefined) {
        parts.push(`<div class="detail-row">${r.pubDev.pubPoints}/160 pub points</div>`);
    }

    if (r.verifiedPublisher && r.pubDev?.publisher) {
        parts.push(`<div class="detail-row">✅ ${escapeHtml(r.pubDev.publisher)}</div>`);
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
    const links: string[] = [];

    links.push(`<a href="${pubUrl}" data-url="${pubUrl}" class="link">View on pub.dev</a>`);

    if (r.pubDev?.repositoryUrl) {
        links.push(`<a href="${escapeHtml(r.pubDev.repositoryUrl)}" data-url="${escapeHtml(r.pubDev.repositoryUrl)}" class="link">Repository</a>`);
    }

    return `<div class="links-section">${links.join('')}</div>`;
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
