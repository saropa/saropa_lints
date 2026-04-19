import * as vscode from 'vscode';

import { VibrancyResult, UpdateInfo } from '../types';
import { formatSizeMB } from '../scoring/bloat-calculator';
import { categoryToGrade, scoreToGrade } from '../scoring/status-classifier';
import { classifyLicense, licenseEmoji } from '../scoring/license-classifier';
import { formatRelativeTime } from '../scoring/time-formatter';
import { severityEmoji, severityLabel, worstSeverity } from '../scoring/vuln-classifier';
import { DetailItem, GroupItem, SourceCodeItem } from './tree-item-classes';

// Builder functions for tree item group nodes (Version, Update, Community, etc.).
// Detail-level builders live in tree-item-detail-builders.ts and are
// re-exported here so existing callers keep working.
export {
    buildDepGraphSummaryDetails,
    buildOverrideDetails,
    buildInsightDetails,
} from './tree-item-detail-builders';

function updateEmoji(status: string): string {
    switch (status) {
        case 'patch': return '🟢';
        case 'minor': return '🟡';
        case 'major': return '🔴';
        default: return '🟡';
    }
}
function bloatEmoji(rating: number): string {
    if (rating <= 3) { return '🟢'; }
    if (rating <= 6) { return '🟡'; }
    return '🔴';
}
function replacementEmoji(level: import('../services/package-code-analyzer').ReplacementLevel): string {
    switch (level) {
        case 'trivial': return '🟢';
        case 'small': return '🟡';
        case 'moderate': return '🟠';
        case 'large': return '🔴';
        case 'native': return '🔧';
    }
}

/** Build grouped child items for a package node. */
export function buildGroupItems(result: VibrancyResult): GroupItem[] {
    const groups: GroupItem[] = [];
    groups.push(buildVersionGroup(result));

    const update = buildUpdateGroup(result);
    if (update) { groups.push(update); }

    const community = buildCommunityGroup(result);
    if (community) { groups.push(community); }

    const size = buildSizeGroup(result);
    if (size) { groups.push(size); }

    const deps = buildDependencyGroup(result);
    if (deps) { groups.push(deps); }

    const security = buildSecurityGroup(result);
    if (security) { groups.push(security); }

    const alerts = buildAlertsGroup(result);
    if (alerts) { groups.push(alerts); }

    const alternatives = buildAlternativesGroup(result);
    if (alternatives) { groups.push(alternatives); }

    return groups;
}

function buildVersionGroup(result: VibrancyResult): GroupItem {
    // Only mark as latest when explicitly confirmed up-to-date.
    // updateInfo: null means "no pub.dev data" — not the same as up-to-date.
    const isLatest = result.updateInfo?.updateStatus === 'up-to-date';

    const versionSuffix = isLatest ? ' (latest)' : '';
    const items: DetailItem[] = [
        new DetailItem('Version', result.package.constraint + versionSuffix),
    ];
    if (result.pubDev) {
        const name = result.package.name;
        const ver = result.pubDev.latestVersion;
        const versionUrl = `https://pub.dev/packages/${name}/versions/${ver}`;
        // Only show Latest as a separate row when it differs from constraint
        if (!isLatest) {
            items.push(new DetailItem('Latest', ver, versionUrl));
        }
        if (result.pubDev.publishedDate) {
            items.push(new DetailItem(
                'Published', result.pubDev.publishedDate.split('T')[0],
                versionUrl,
            ));
        }
    }
    if (result.license) {
        const tier = classifyLicense(result.license);
        const emoji = licenseEmoji(tier);
        items.push(new DetailItem(
            `${emoji} License`, result.license,
        ));
    }
    if (result.platforms?.length) {
        items.push(new DetailItem(
            '🖥️ Platforms', result.platforms.join(', '),
        ));
    }
    if (result.wasmReady !== null && result.wasmReady !== undefined) {
        items.push(new DetailItem(
            '🌐 WASM', result.wasmReady ? 'Ready' : 'Not ready',
        ));
    }
    // Collapse when on latest version — the details are less actionable
    const state = isLatest
        ? vscode.TreeItemCollapsibleState.Collapsed
        : vscode.TreeItemCollapsibleState.Expanded;
    return new GroupItem('📦 Version', items, state);
}

function buildUpdateGroup(result: VibrancyResult): GroupItem | null {
    if (!result.updateInfo
        || result.updateInfo.updateStatus === 'up-to-date') {
        return null;
    }
    const ui = result.updateInfo;
    const emoji = updateEmoji(ui.updateStatus);
    const items: DetailItem[] = [
        new DetailItem(
            `${emoji} ${ui.currentVersion} → ${ui.latestVersion}`,
            `(${ui.updateStatus})`,
        ),
    ];
    if (result.blocker) {
        const b = result.blocker;
        items.push(new DetailItem(
            '🔒 Blocked by', b.blockerPackage,
        ));
        /* Prefer the category-derived letter (respects EOL/trusted-publisher
           overrides); fall back to score-derived letter if only the raw score
           survived. Either way: letter, no /10. */
        if (b.blockerCategory !== null) {
            items.push(new DetailItem(
                '  vibrancy', categoryToGrade(b.blockerCategory),
            ));
        } else if (b.blockerVibrancyScore !== null) {
            items.push(new DetailItem(
                '  vibrancy', scoreToGrade(b.blockerVibrancyScore),
            ));
        }
    }
    appendChangelogItems(items, ui, result.package.name);
    return new GroupItem('⬆️ Update', items);
}

function appendChangelogItems(
    items: DetailItem[], ui: UpdateInfo, packageName: string,
): void {
    const cl = ui.changelog;
    if (cl?.entries.length) {
        const baseUrl = `https://pub.dev/packages/${packageName}/changelog`;
        for (const entry of cl.entries) {
            const dateStr = entry.date ? ` (${entry.date})` : '';
            const firstLine = entry.body.split('\n').find(l => l.trim()) ?? '';
            const preview = firstLine.length > 60
                ? firstLine.substring(0, 57) + '...' : firstLine;
            const anchor = entry.version.replace(/\./g, '');
            items.push(new DetailItem(
                `v${entry.version}${dateStr}`, preview, `${baseUrl}#${anchor}`,
            ));
        }
        if (cl.truncated) {
            items.push(new DetailItem('...', 'More entries on pub.dev', baseUrl));
        }
    } else if (cl?.unavailableReason) {
        items.push(new DetailItem('Changelog', cl.unavailableReason));
    }
}

function buildCommunityGroup(result: VibrancyResult): GroupItem | null {
    const items: DetailItem[] = [];
    if (result.github) {
        const gh = result.github;
        const repoUrl = (gh.repoUrl ?? result.pubDev?.repositoryUrl)
            ?.replace(/\/+$/, '');
        items.push(new DetailItem(
            '⭐ Stars', `${gh.stars}`,
            repoUrl ?? undefined,
        ));
        const issueCount = gh.trueOpenIssues ?? gh.openIssues;
        items.push(new DetailItem(
            'Open Issues', `${issueCount}`,
            repoUrl ? `${repoUrl}/issues` : undefined,
        ));
        if (gh.openPullRequests !== undefined) {
            items.push(new DetailItem(
                'Open PRs', `${gh.openPullRequests}`,
                repoUrl ? `${repoUrl}/pulls` : undefined,
            ));
        }
        const activity = gh.closedIssuesLast90d + gh.mergedPrsLast90d;
        if (activity > 0) {
            items.push(new DetailItem(
                '🔧 Activity (90d)',
                `${gh.closedIssuesLast90d} closed, ${gh.mergedPrsLast90d} merged`,
            ));
        }
        if (gh.daysSinceLastCommit !== undefined) {
            items.push(new DetailItem(
                '📅 Last Commit', formatRelativeTime(gh.daysSinceLastCommit),
            ));
        }
        if (gh.isArchived) {
            items.push(new DetailItem('🗄️ Archived', 'Repository is archived'));
        }
    }
    if (result.pubDev?.pubPoints !== undefined) {
        items.push(new DetailItem(
            '📊 Pub Points', `${result.pubDev.pubPoints}/160`,
        ));
    }
    if (result.reverseDependencyCount !== null && result.reverseDependencyCount > 0) {
        const count = result.reverseDependencyCount;
        const depUrl = `https://pub.dev/packages?q=dependency%3A${encodeURIComponent(result.package.name)}`;
        items.push(new DetailItem(
            '📦 Dependents', `${count.toLocaleString('en-US')} packages`,
            depUrl,
        ));
    }
    if (result.verifiedPublisher) {
        items.push(new DetailItem('✅ Publisher', 'Verified'));
    }
    if (items.length === 0) { return null; }
    return new GroupItem('📊 Community', items);
}

function buildSizeGroup(result: VibrancyResult): GroupItem | null {
    const items: (DetailItem | SourceCodeItem)[] = [];

    if (result.bloatRating !== null && result.archiveSizeBytes !== null) {
        const emoji = bloatEmoji(result.bloatRating);
        const sizeMB = formatSizeMB(result.archiveSizeBytes);
        items.push(new DetailItem(
            `${emoji} Archive Size`, `${sizeMB} (${result.bloatRating}/10 bloat)`,
        ));
    }

    if (result.replacementComplexity) {
        const rc = result.replacementComplexity;
        const emoji = replacementEmoji(rc.level);
        // Short description for tree view; full summary in tooltip
        const shortDesc = formatShortSourceDesc(rc.metrics);
        items.push(new SourceCodeItem(
            emoji, shortDesc, rc.summary, result.package.name,
        ));
    }

    if (items.length === 0) { return null; }
    return new GroupItem('📏 Size', items);
}

/** Format a compact source description for the tree view. */
function formatShortSourceDesc(
    m: import('../services/package-code-analyzer').PackageCodeMetrics,
): string {
    // Handle edge case where package has no lib/ content
    if (m.libCodeLines === 0 && m.libFileCount === 0) {
        return m.hasNativeCode ? 'native only' : 'no source';
    }
    // e.g. "2.5k lines, 18 files" or "500 lines + native"
    const loc = m.libCodeLines;
    const locStr = loc >= 1000
        ? `${(loc / 1000).toFixed(1)}k` : `${loc}`;
    const fileStr = m.libFileCount === 1 ? '1 file' : `${m.libFileCount} files`;
    const native = m.hasNativeCode ? ' + native' : '';
    return `${locStr} lines, ${fileStr}${native}`;
}

function buildAlertsGroup(result: VibrancyResult): GroupItem | null {
    const items: DetailItem[] = [];
    if (result.isUnused) {
        items.push(new DetailItem(
            '⚠️ Unused', 'No imports found in lib/, bin/, or test/',
        ));
    }
    appendFlaggedItems(items, result);
    if (result.knownIssue?.reason) {
        items.push(new DetailItem('❌ Known Issue', result.knownIssue.reason));
    }
    if (items.length === 0) { return null; }
    return new GroupItem('🚨 Alerts', items);
}

function appendFlaggedItems(
    items: DetailItem[],
    result: VibrancyResult,
): void {
    const flagged = result.github?.flaggedIssues;
    if (!flagged?.length) { return; }
    items.push(new DetailItem(
        '🚩 Flagged Issues', `${flagged.length} high-signal`,
    ));
    for (const issue of flagged.slice(0, 3)) {
        const title = issue.title.length > 50
            ? issue.title.substring(0, 47) + '...' : issue.title;
        items.push(new DetailItem(
            `  #${issue.number}`, `${title} (${issue.matchedSignals[0]})`,
            issue.url || undefined,
        ));
    }
}

/** Build Dependencies group for transitive analysis. */
export function buildDependencyGroup(result: VibrancyResult): GroupItem | null {
    const info = result.transitiveInfo;
    if (!info || info.transitiveCount === 0) { return null; }

    const items: DetailItem[] = [];

    // Split transitives into unique (only this package pulls them in)
    // and shared (already in the dep graph via other direct deps).
    // This distinguishes real added weight from already-paid-for deps.
    const sharedCount = info.sharedDeps.length;
    // Clamp to zero — sharedDeps should always be a subset of transitives
    // but defensive clamping prevents a negative display if data is inconsistent
    const uniqueCount = Math.max(0, info.transitiveCount - sharedCount);

    const flaggedSuffix = info.flaggedCount > 0
        ? ` (${info.flaggedCount} flagged)` : '';
    items.push(new DetailItem(
        'Transitive', `${info.transitiveCount} packages${flaggedSuffix}`,
    ));

    if (sharedCount > 0) {
        // Show unique vs shared breakdown so users can tell whether a
        // package's reported size is mostly shared weight they already carry
        items.push(new DetailItem(
            '🆕 Unique', `${uniqueCount} packages (added by this dep only)`,
        ));
        const sharedList = info.sharedDeps.slice(0, 3).join(', ');
        const more = info.sharedDeps.length > 3
            ? ` +${info.sharedDeps.length - 3}` : '';
        items.push(new DetailItem(
            '🔗 Shared', `${sharedCount} packages — ${sharedList}${more}`,
        ));
    }

    return new GroupItem('📊 Dependencies', items);
}

function buildSecurityGroup(result: VibrancyResult): GroupItem | null {
    if (result.vulnerabilities.length === 0) { return null; }

    const items: DetailItem[] = [];
    const worst = worstSeverity(result.vulnerabilities);
    const worstLabel = worst ? severityLabel(worst) : 'Unknown';
    const worstEmoji = worst ? severityEmoji(worst) : '🛡️';

    items.push(new DetailItem(
        `${worstEmoji} Severity`,
        `${worstLabel} (${result.vulnerabilities.length} total)`,
    ));

    for (const vuln of result.vulnerabilities.slice(0, 5)) {
        const emoji = severityEmoji(vuln.severity);
        const summary = vuln.summary.length > 50
            ? vuln.summary.substring(0, 47) + '...' : vuln.summary;
        const fixInfo = vuln.fixedVersion ? ` [fix: ${vuln.fixedVersion}]` : '';
        items.push(new DetailItem(
            `${emoji} ${vuln.id}`,
            `${summary}${fixInfo}`,
            vuln.url,
        ));
    }

    if (result.vulnerabilities.length > 5) {
        items.push(new DetailItem(
            '...',
            `${result.vulnerabilities.length - 5} more vulnerabilities`,
        ));
    }

    return new GroupItem('🛡️ Security', items);
}
function buildAlternativesGroup(result: VibrancyResult): GroupItem | null {
    if (!result.alternatives?.length) { return null; }

    const items: DetailItem[] = [];
    for (const alt of result.alternatives) {
        const badge = alt.source === 'curated' ? 'Recommended' : 'Similar';
        /* Letter grade only (derived from the alt's raw score — alts don't
           carry a category). Previously "(7/10)". */
        const gradeText = alt.score !== null ? ` (${scoreToGrade(alt.score)})` : '';
        const likesText = alt.likes > 0 ? `, ${alt.likes} likes` : '';
        const url = `https://pub.dev/packages/${alt.name}`;
        const emoji = alt.source === 'curated' ? '⭐' : '💡';

        items.push(new DetailItem(
            `${emoji} ${alt.name}`,
            `${badge}${gradeText}${likesText}`,
            url,
        ));
    }

    return new GroupItem('💡 Alternatives', items);
}
