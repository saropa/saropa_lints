import { VibrancyResult } from '../types';
import { categoryLabel, countByCategory } from '../scoring/status-classifier';
import { formatSizeMB } from '../scoring/bloat-calculator';
import { worstSeverity, severityEmoji, severityLabel } from '../scoring/vuln-classifier';
import { getReportStyles } from './report-styles';
import { getReportScript } from './report-script';
import { escapeHtml } from './html-utils';

/** Build the full HTML for the vibrancy report webview. */
export function buildReportHtml(results: VibrancyResult[]): string {
    return `<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta http-equiv="Content-Security-Policy"
        content="default-src 'none'; style-src 'unsafe-inline'; script-src 'unsafe-inline';">
    <style>${getReportStyles()}</style>
</head>
<body>
    <h1>Package Vibrancy Report</h1>
    ${buildReportSummary(results)}
    ${buildReportTable(results)}
    <script>${getReportScript()}</script>
</body>
</html>`;
}

function buildReportSummary(results: VibrancyResult[]): string {
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
    const totalSize = totalBytes > 0 ? formatSizeMB(totalBytes) : '—';
    const vulnPackages = results.filter(r => r.vulnerabilities.length > 0).length;

    return `<div class="summary">
        <div class="summary-card"><div class="count">${results.length}</div><div class="label">Packages</div></div>
        <div class="summary-card"><div class="count">${avg}/10</div><div class="label">Avg Score</div></div>
        <div class="summary-card"><div class="count">${totalSize}</div><div class="label">Total Size*</div></div>
        <div class="summary-card vibrant"><div class="count">${counts.vibrant}</div><div class="label">Vibrant</div></div>
        <div class="summary-card quiet"><div class="count">${counts.quiet}</div><div class="label">Quiet</div></div>
        <div class="summary-card legacy"><div class="count">${counts.legacy}</div><div class="label">Legacy</div></div>
        <div class="summary-card eol"><div class="count">${counts.eol}</div><div class="label">End of Life</div></div>
        <div class="summary-card updates"><div class="count">${updates}</div><div class="label">Updates</div></div>
        <div class="summary-card unused"><div class="count">${results.filter(r => r.isUnused).length}</div><div class="label">Unused</div></div>
        <div class="summary-card vulns"><div class="count">${vulnPackages}</div><div class="label">Vulnerable</div></div>
    </div>
    <p class="caveat">*Archive sizes before tree shaking. Actual app size will be smaller.</p>`;
}

function buildReportTable(results: VibrancyResult[]): string {
    return `<table>
        <thead><tr>
            <th data-col="name">Package<span class="sort-arrow"></span></th>
            <th data-col="version">Version<span class="sort-arrow"></span></th>
            <th data-col="score">Score<span class="sort-arrow"></span></th>
            <th data-col="category">Category<span class="sort-arrow"></span></th>
            <th data-col="published">Published<span class="sort-arrow"></span></th>
            <th data-col="stars">Stars<span class="sort-arrow"></span></th>
            <th data-col="size">Size<span class="sort-arrow"></span></th>
            <th data-col="transitives">Transitives<span class="sort-arrow"></span></th>
            <th data-col="vulns">Vulns<span class="sort-arrow"></span></th>
            <th data-col="license">License<span class="sort-arrow"></span></th>
            <th data-col="drift">Drift<span class="sort-arrow"></span></th>
            <th data-col="update">Update<span class="sort-arrow"></span></th>
            <th data-col="status">Status<span class="sort-arrow"></span></th>
        </tr></thead>
        <tbody id="pkg-body">
            ${results.map(buildRow).join('\n')}
        </tbody>
    </table>`;
}

function buildRow(r: VibrancyResult): string {
    const name = escapeHtml(r.package.name);
    const version = escapeHtml(r.package.version);
    const date = r.pubDev?.publishedDate.split('T')[0] ?? '';
    const stars = r.github?.stars ?? '';
    const sizeText = r.archiveSizeBytes !== null
        ? formatSizeMB(r.archiveSizeBytes) : '—';
    const url = `https://pub.dev/packages/${encodeURIComponent(r.package.name)}`;

    const hasUpdate = r.updateInfo
        && r.updateInfo.updateStatus !== 'up-to-date';
    const updateText = hasUpdate
        ? `→ ${escapeHtml(r.updateInfo!.latestVersion)}`
        : '✓';
    const updateClass = r.updateInfo?.updateStatus === 'major' ? 'update-major'
        : r.updateInfo?.updateStatus === 'minor' ? 'update-minor'
        : r.updateInfo?.updateStatus === 'patch' ? 'update-patch'
        : '';

    const transitiveCount = r.transitiveInfo?.transitiveCount ?? 0;
    const flaggedCount = r.transitiveInfo?.flaggedCount ?? 0;
    const transitiveText = transitiveCount > 0
        ? (flaggedCount > 0 ? `${transitiveCount} (${flaggedCount}⚠)` : `${transitiveCount}`)
        : '—';
    const transitiveClass = flaggedCount > 0 ? 'transitive-flagged' : '';

    const vulnCount = r.vulnerabilities.length;
    const worst = worstSeverity(r.vulnerabilities);
    const vulnEmoji = worst ? severityEmoji(worst) : '';
    const vulnLabel = worst ? severityLabel(worst) : '';
    const vulnText = vulnCount > 0 ? `${vulnEmoji} ${vulnCount} (${vulnLabel})` : '—';
    const vulnClass = vulnCount > 0 ? `vuln-${worst}` : '';

    return `<tr data-name="${name}" data-version="${version}"
        data-score="${r.score}" data-category="${r.category}"
        data-published="${date}" data-stars="${stars}"
        data-size="${r.archiveSizeBytes ?? 0}"
        data-transitives="${transitiveCount}"
        data-vulns="${vulnCount}"
        data-license="${escapeHtml(r.license ?? '')}"
        data-drift="${r.drift?.releasesBehind ?? ''}"
        data-update="${r.updateInfo?.updateStatus ?? 'unknown'}"
        data-status="${r.isUnused ? 'unused' : 'ok'}">
        <td><a href="${url}">${name}</a></td>
        <td>${version}</td>
        <td>${Math.round(r.score / 10)}/10</td>
        <td>${categoryLabel(r.category)}</td>
        <td>${date}</td>
        <td>${stars}</td>
        <td>${sizeText}</td>
        <td class="${transitiveClass}">${transitiveText}</td>
        <td class="${vulnClass}">${vulnText}</td>
        <td>${escapeHtml(r.license ?? '—')}</td>
        <td>${r.drift ? `${r.drift.releasesBehind} (${r.drift.label})` : '—'}</td>
        <td class="${updateClass}">${updateText}</td>
        <td>${r.isUnused ? '<span class="badge-unused">Unused</span>' : '—'}</td>
    </tr>`;
}

