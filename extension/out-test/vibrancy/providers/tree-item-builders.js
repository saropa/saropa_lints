"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.buildInsightDetails = exports.buildOverrideDetails = exports.buildDepGraphSummaryDetails = void 0;
exports.buildGroupItems = buildGroupItems;
exports.buildDependencyGroup = buildDependencyGroup;
const bloat_calculator_1 = require("../scoring/bloat-calculator");
const license_classifier_1 = require("../scoring/license-classifier");
const time_formatter_1 = require("../scoring/time-formatter");
const vuln_classifier_1 = require("../scoring/vuln-classifier");
const tree_item_classes_1 = require("./tree-item-classes");
// Builder functions for tree item group nodes (Version, Update, Community, etc.).
// Detail-level builders live in tree-item-detail-builders.ts and are
// re-exported here so existing callers keep working.
var tree_item_detail_builders_1 = require("./tree-item-detail-builders");
Object.defineProperty(exports, "buildDepGraphSummaryDetails", { enumerable: true, get: function () { return tree_item_detail_builders_1.buildDepGraphSummaryDetails; } });
Object.defineProperty(exports, "buildOverrideDetails", { enumerable: true, get: function () { return tree_item_detail_builders_1.buildOverrideDetails; } });
Object.defineProperty(exports, "buildInsightDetails", { enumerable: true, get: function () { return tree_item_detail_builders_1.buildInsightDetails; } });
function updateEmoji(status) {
    switch (status) {
        case 'patch': return '🟢';
        case 'minor': return '🟡';
        case 'major': return '🔴';
        default: return '🟡';
    }
}
function bloatEmoji(rating) {
    if (rating <= 3) {
        return '🟢';
    }
    if (rating <= 6) {
        return '🟡';
    }
    return '🔴';
}
/** Build grouped child items for a package node. */
function buildGroupItems(result) {
    const groups = [];
    groups.push(buildVersionGroup(result));
    const update = buildUpdateGroup(result);
    if (update) {
        groups.push(update);
    }
    const community = buildCommunityGroup(result);
    if (community) {
        groups.push(community);
    }
    const size = buildSizeGroup(result);
    if (size) {
        groups.push(size);
    }
    const deps = buildDependencyGroup(result);
    if (deps) {
        groups.push(deps);
    }
    const security = buildSecurityGroup(result);
    if (security) {
        groups.push(security);
    }
    const alerts = buildAlertsGroup(result);
    if (alerts) {
        groups.push(alerts);
    }
    const alternatives = buildAlternativesGroup(result);
    if (alternatives) {
        groups.push(alternatives);
    }
    return groups;
}
function buildVersionGroup(result) {
    const items = [
        new tree_item_classes_1.DetailItem('Version', result.package.constraint),
    ];
    if (result.pubDev) {
        const name = result.package.name;
        const ver = result.pubDev.latestVersion;
        const versionUrl = `https://pub.dev/packages/${name}/versions/${ver}`;
        items.push(new tree_item_classes_1.DetailItem('Latest', ver, versionUrl));
        if (result.pubDev.publishedDate) {
            items.push(new tree_item_classes_1.DetailItem('Published', result.pubDev.publishedDate.split('T')[0], versionUrl));
        }
    }
    if (result.license) {
        const tier = (0, license_classifier_1.classifyLicense)(result.license);
        const emoji = (0, license_classifier_1.licenseEmoji)(tier);
        items.push(new tree_item_classes_1.DetailItem(`${emoji} License`, result.license));
    }
    if (result.platforms?.length) {
        items.push(new tree_item_classes_1.DetailItem('🖥️ Platforms', result.platforms.join(', ')));
    }
    if (result.wasmReady !== null && result.wasmReady !== undefined) {
        items.push(new tree_item_classes_1.DetailItem('🌐 WASM', result.wasmReady ? 'Ready' : 'Not ready'));
    }
    if (result.drift) {
        const d = result.drift;
        const behind = d.releasesBehind === 0
            ? 'Current' : `${d.releasesBehind} Flutter releases behind`;
        items.push(new tree_item_classes_1.DetailItem('🕐 Drift', `${behind} (${d.label})`));
    }
    return new tree_item_classes_1.GroupItem('📦 Version', items);
}
function buildUpdateGroup(result) {
    if (!result.updateInfo
        || result.updateInfo.updateStatus === 'up-to-date') {
        return null;
    }
    const ui = result.updateInfo;
    const emoji = updateEmoji(ui.updateStatus);
    const items = [
        new tree_item_classes_1.DetailItem(`${emoji} ${ui.currentVersion} → ${ui.latestVersion}`, `(${ui.updateStatus})`),
    ];
    if (result.blocker) {
        const b = result.blocker;
        items.push(new tree_item_classes_1.DetailItem('🔒 Blocked by', b.blockerPackage));
        if (b.blockerVibrancyScore !== null) {
            const score = Math.round(b.blockerVibrancyScore / 10);
            const cat = b.blockerCategory ?? 'unknown';
            items.push(new tree_item_classes_1.DetailItem('  vibrancy', `${score}/10 (${cat})`));
        }
    }
    appendChangelogItems(items, ui, result.package.name);
    return new tree_item_classes_1.GroupItem('⬆️ Update', items);
}
function appendChangelogItems(items, ui, packageName) {
    const cl = ui.changelog;
    if (cl?.entries.length) {
        const baseUrl = `https://pub.dev/packages/${packageName}/changelog`;
        for (const entry of cl.entries) {
            const dateStr = entry.date ? ` (${entry.date})` : '';
            const firstLine = entry.body.split('\n').find(l => l.trim()) ?? '';
            const preview = firstLine.length > 60
                ? firstLine.substring(0, 57) + '...' : firstLine;
            const anchor = entry.version.replace(/\./g, '');
            items.push(new tree_item_classes_1.DetailItem(`v${entry.version}${dateStr}`, preview, `${baseUrl}#${anchor}`));
        }
        if (cl.truncated) {
            items.push(new tree_item_classes_1.DetailItem('...', 'More entries on pub.dev', baseUrl));
        }
    }
    else if (cl?.unavailableReason) {
        items.push(new tree_item_classes_1.DetailItem('Changelog', cl.unavailableReason));
    }
}
function buildCommunityGroup(result) {
    const items = [];
    if (result.github) {
        const gh = result.github;
        const repoUrl = (gh.repoUrl ?? result.pubDev?.repositoryUrl)
            ?.replace(/\/+$/, '');
        items.push(new tree_item_classes_1.DetailItem('⭐ Stars', `${gh.stars}`, repoUrl ?? undefined));
        const issueCount = gh.trueOpenIssues ?? gh.openIssues;
        items.push(new tree_item_classes_1.DetailItem('Open Issues', `${issueCount}`, repoUrl ? `${repoUrl}/issues` : undefined));
        if (gh.openPullRequests !== undefined) {
            items.push(new tree_item_classes_1.DetailItem('Open PRs', `${gh.openPullRequests}`, repoUrl ? `${repoUrl}/pulls` : undefined));
        }
        const activity = gh.closedIssuesLast90d + gh.mergedPrsLast90d;
        if (activity > 0) {
            items.push(new tree_item_classes_1.DetailItem('🔧 Activity (90d)', `${gh.closedIssuesLast90d} closed, ${gh.mergedPrsLast90d} merged`));
        }
        if (gh.daysSinceLastCommit !== undefined) {
            items.push(new tree_item_classes_1.DetailItem('📅 Last Commit', (0, time_formatter_1.formatRelativeTime)(gh.daysSinceLastCommit)));
        }
        if (gh.isArchived) {
            items.push(new tree_item_classes_1.DetailItem('🗄️ Archived', 'Repository is archived'));
        }
    }
    if (result.pubDev?.pubPoints !== undefined) {
        items.push(new tree_item_classes_1.DetailItem('📊 Pub Points', `${result.pubDev.pubPoints}/160`));
    }
    if (result.verifiedPublisher) {
        items.push(new tree_item_classes_1.DetailItem('✅ Publisher', 'Verified'));
    }
    if (items.length === 0) {
        return null;
    }
    return new tree_item_classes_1.GroupItem('📊 Community', items);
}
function buildSizeGroup(result) {
    if (result.bloatRating === null || result.archiveSizeBytes === null) {
        return null;
    }
    const emoji = bloatEmoji(result.bloatRating);
    const sizeMB = (0, bloat_calculator_1.formatSizeMB)(result.archiveSizeBytes);
    return new tree_item_classes_1.GroupItem('📏 Size', [
        new tree_item_classes_1.DetailItem(`${emoji} Archive Size`, `${sizeMB} (${result.bloatRating}/10 bloat)`),
    ]);
}
function buildAlertsGroup(result) {
    const items = [];
    if (result.isUnused) {
        items.push(new tree_item_classes_1.DetailItem('⚠️ Unused', 'No imports found in lib/, bin/, or test/'));
    }
    appendFlaggedItems(items, result);
    if (result.knownIssue?.reason) {
        items.push(new tree_item_classes_1.DetailItem('❌ Known Issue', result.knownIssue.reason));
    }
    if (items.length === 0) {
        return null;
    }
    return new tree_item_classes_1.GroupItem('🚨 Alerts', items);
}
function appendFlaggedItems(items, result) {
    const flagged = result.github?.flaggedIssues;
    if (!flagged?.length) {
        return;
    }
    items.push(new tree_item_classes_1.DetailItem('🚩 Flagged Issues', `${flagged.length} high-signal`));
    for (const issue of flagged.slice(0, 3)) {
        const title = issue.title.length > 50
            ? issue.title.substring(0, 47) + '...' : issue.title;
        items.push(new tree_item_classes_1.DetailItem(`  #${issue.number}`, `${title} (${issue.matchedSignals[0]})`, issue.url || undefined));
    }
}
/** Build Dependencies group for transitive analysis. */
function buildDependencyGroup(result) {
    const info = result.transitiveInfo;
    if (!info || info.transitiveCount === 0) {
        return null;
    }
    const items = [];
    const countDesc = info.flaggedCount > 0
        ? `${info.transitiveCount} (${info.flaggedCount} flagged)`
        : `${info.transitiveCount}`;
    items.push(new tree_item_classes_1.DetailItem('Transitive', `${countDesc} packages`));
    if (info.sharedDeps.length > 0) {
        const sharedList = info.sharedDeps.slice(0, 3).join(', ');
        const more = info.sharedDeps.length > 3
            ? ` +${info.sharedDeps.length - 3}` : '';
        items.push(new tree_item_classes_1.DetailItem('🔗 Shared', `${sharedList}${more}`));
    }
    return new tree_item_classes_1.GroupItem('📊 Dependencies', items);
}
function buildSecurityGroup(result) {
    if (result.vulnerabilities.length === 0) {
        return null;
    }
    const items = [];
    const worst = (0, vuln_classifier_1.worstSeverity)(result.vulnerabilities);
    const worstLabel = worst ? (0, vuln_classifier_1.severityLabel)(worst) : 'Unknown';
    const worstEmoji = worst ? (0, vuln_classifier_1.severityEmoji)(worst) : '🛡️';
    items.push(new tree_item_classes_1.DetailItem(`${worstEmoji} Severity`, `${worstLabel} (${result.vulnerabilities.length} total)`));
    for (const vuln of result.vulnerabilities.slice(0, 5)) {
        const emoji = (0, vuln_classifier_1.severityEmoji)(vuln.severity);
        const summary = vuln.summary.length > 50
            ? vuln.summary.substring(0, 47) + '...' : vuln.summary;
        const fixInfo = vuln.fixedVersion ? ` [fix: ${vuln.fixedVersion}]` : '';
        items.push(new tree_item_classes_1.DetailItem(`${emoji} ${vuln.id}`, `${summary}${fixInfo}`, vuln.url));
    }
    if (result.vulnerabilities.length > 5) {
        items.push(new tree_item_classes_1.DetailItem('...', `${result.vulnerabilities.length - 5} more vulnerabilities`));
    }
    return new tree_item_classes_1.GroupItem('🛡️ Security', items);
}
function buildAlternativesGroup(result) {
    if (!result.alternatives?.length) {
        return null;
    }
    const items = [];
    for (const alt of result.alternatives) {
        const badge = alt.source === 'curated' ? 'Recommended' : 'Similar';
        const scoreText = alt.score !== null ? ` (${Math.round(alt.score / 10)}/10)` : '';
        const likesText = alt.likes > 0 ? `, ${alt.likes} likes` : '';
        const url = `https://pub.dev/packages/${alt.name}`;
        const emoji = alt.source === 'curated' ? '⭐' : '💡';
        items.push(new tree_item_classes_1.DetailItem(`${emoji} ${alt.name}`, `${badge}${scoreText}${likesText}`, url));
    }
    return new tree_item_classes_1.GroupItem('💡 Alternatives', items);
}
//# sourceMappingURL=tree-item-builders.js.map