import { VibrancyResult, UpdateInfo } from '../types';
import { formatSizeMB } from '../scoring/bloat-calculator';
import { classifyLicense, licenseEmoji } from '../scoring/license-classifier';
import { severityEmoji, severityLabel, worstSeverity } from '../scoring/vuln-classifier';
import { DetailItem, GroupItem } from './tree-item-classes';

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
    const items: DetailItem[] = [
        new DetailItem('Version', result.package.constraint),
    ];
    if (result.pubDev) {
        const name = result.package.name;
        const ver = result.pubDev.latestVersion;
        const versionUrl = `https://pub.dev/packages/${name}/versions/${ver}`;
        items.push(new DetailItem('Latest', ver, versionUrl));
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
    if (result.drift) {
        const d = result.drift;
        const behind = d.releasesBehind === 0
            ? 'Current' : `${d.releasesBehind} Flutter releases behind`;
        items.push(new DetailItem(
            '🕐 Drift', `${behind} (${d.label})`,
        ));
    }
    return new GroupItem('📦 Version', items);
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
        if (b.blockerVibrancyScore !== null) {
            const score = Math.round(b.blockerVibrancyScore / 10);
            const cat = b.blockerCategory ?? 'unknown';
            items.push(new DetailItem(
                '  vibrancy', `${score}/10 (${cat})`,
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
        const repoUrl = result.pubDev?.repositoryUrl?.replace(/\/+$/, '');
        items.push(new DetailItem(
            '⭐ Stars', `${result.github.stars}`,
            repoUrl ?? undefined,
        ));
        items.push(new DetailItem(
            'Open Issues', `${result.github.openIssues}`,
            repoUrl ? `${repoUrl}/issues` : undefined,
        ));
    }
    if (result.pubDev?.pubPoints !== undefined) {
        items.push(new DetailItem(
            '📊 Pub Points', `${result.pubDev.pubPoints}/160`,
        ));
    }
    if (result.verifiedPublisher) {
        items.push(new DetailItem('✅ Publisher', 'Verified'));
    }
    if (items.length === 0) { return null; }
    return new GroupItem('📊 Community', items);
}

function buildSizeGroup(result: VibrancyResult): GroupItem | null {
    if (result.bloatRating === null || result.archiveSizeBytes === null) { return null; }
    const emoji = bloatEmoji(result.bloatRating);
    const sizeMB = formatSizeMB(result.archiveSizeBytes);
    return new GroupItem('📏 Size', [
        new DetailItem(`${emoji} Archive Size`, `${sizeMB} (${result.bloatRating}/10 bloat)`),
    ]);
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

    const countDesc = info.flaggedCount > 0
        ? `${info.transitiveCount} (${info.flaggedCount} flagged)`
        : `${info.transitiveCount}`;
    items.push(new DetailItem('Transitive', `${countDesc} packages`));

    if (info.sharedDeps.length > 0) {
        const sharedList = info.sharedDeps.slice(0, 3).join(', ');
        const more = info.sharedDeps.length > 3
            ? ` +${info.sharedDeps.length - 3}` : '';
        items.push(new DetailItem('🔗 Shared', `${sharedList}${more}`));
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
        const scoreText = alt.score !== null ? ` (${Math.round(alt.score / 10)}/10)` : '';
        const likesText = alt.likes > 0 ? `, ${alt.likes} likes` : '';
        const url = `https://pub.dev/packages/${alt.name}`;
        const emoji = alt.source === 'curated' ? '⭐' : '💡';

        items.push(new DetailItem(
            `${emoji} ${alt.name}`,
            `${badge}${scoreText}${likesText}`,
            url,
        ));
    }

    return new GroupItem('💡 Alternatives', items);
}
