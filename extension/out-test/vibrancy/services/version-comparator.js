"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.detectNewVersions = detectNewVersions;
exports.markVersionSeen = markVersionSeen;
exports.markAllSeen = markAllSeen;
exports.buildWatchList = buildWatchList;
const pub_dev_api_1 = require("./pub-dev-api");
const changelog_service_1 = require("./changelog-service");
const SEEN_VERSION_PREFIX = 'freshness.seen.';
const STAGGER_DELAY_MS = 500;
const BATCH_SIZE = 5;
/**
 * Check packages for new versions with staggered API calls.
 * Batches requests to avoid rate limits (5 packages per batch, 500ms delay).
 */
async function detectNewVersions(watchList, cache) {
    const notifications = [];
    for (let i = 0; i < watchList.length; i += BATCH_SIZE) {
        const batch = watchList.slice(i, i + BATCH_SIZE);
        const results = await Promise.all(batch.map(entry => checkPackageVersion(entry, cache)));
        for (const result of results) {
            if (result) {
                notifications.push(result);
            }
        }
        if (i + BATCH_SIZE < watchList.length) {
            await delay(STAGGER_DELAY_MS);
        }
    }
    return notifications;
}
async function checkPackageVersion(entry, cache) {
    const info = await (0, pub_dev_api_1.fetchPackageInfo)(entry.name, cache);
    if (!info) {
        return null;
    }
    const latestVersion = info.latestVersion;
    const updateType = (0, changelog_service_1.compareVersions)(entry.currentVersion, latestVersion);
    if (updateType === 'up-to-date' || updateType === 'unknown') {
        return null;
    }
    const seenKey = SEEN_VERSION_PREFIX + entry.name;
    const seenVersion = cache.get(seenKey);
    if (seenVersion === latestVersion) {
        return null;
    }
    return {
        name: entry.name,
        currentVersion: entry.currentVersion,
        newVersion: latestVersion,
        updateType,
        blockedBy: entry.blockedBy,
    };
}
/** Record that a version has been seen to prevent re-notification. */
async function markVersionSeen(name, version, cache) {
    const seenKey = SEEN_VERSION_PREFIX + name;
    await cache.set(seenKey, version);
}
/** Mark all notifications as seen in the cache. */
async function markAllSeen(notifications, cache) {
    for (const n of notifications) {
        await markVersionSeen(n.name, n.newVersion, cache);
    }
}
/**
 * Build watch list from scan results based on filter mode.
 * Only includes direct dependencies; transitive deps are excluded.
 * Includes blocker info if the package has an upgrade blocker.
 */
function buildWatchList(results, filterMode, customList, unhealthyThreshold = 40) {
    const directResults = results.filter(r => r.package.isDirect);
    const toEntry = (r) => ({
        name: r.package.name,
        currentVersion: r.package.version,
        blockedBy: r.blocker?.blockerPackage ?? null,
    });
    switch (filterMode) {
        case 'all':
            return directResults.map(toEntry);
        case 'unhealthy':
            return directResults
                .filter(r => r.score < unhealthyThreshold)
                .map(toEntry);
        case 'custom': {
            const customSet = new Set(customList ?? []);
            return directResults
                .filter(r => customSet.has(r.package.name))
                .map(toEntry);
        }
    }
}
function delay(ms) {
    return new Promise(resolve => setTimeout(resolve, ms));
}
//# sourceMappingURL=version-comparator.js.map