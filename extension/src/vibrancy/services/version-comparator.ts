import { NewVersionNotification, VibrancyResult } from '../types';
import { CacheService } from './cache-service';
import { fetchPackageInfo } from './pub-dev-api';
import { compareVersions } from './changelog-service';

const SEEN_VERSION_PREFIX = 'freshness.seen.';
const STAGGER_DELAY_MS = 500;
const BATCH_SIZE = 5;

/** A package to watch for new versions. */
export interface WatchEntry {
    readonly name: string;
    readonly currentVersion: string;
    /** If upgrade is blocked, the name of the blocking package. */
    readonly blockedBy: string | null;
}

/**
 * Check packages for new versions with staggered API calls.
 * Batches requests to avoid rate limits (5 packages per batch, 500ms delay).
 */
export async function detectNewVersions(
    watchList: readonly WatchEntry[],
    cache: CacheService,
): Promise<NewVersionNotification[]> {
    const notifications: NewVersionNotification[] = [];

    for (let i = 0; i < watchList.length; i += BATCH_SIZE) {
        const batch = watchList.slice(i, i + BATCH_SIZE);
        const results = await Promise.all(
            batch.map(entry => checkPackageVersion(entry, cache)),
        );

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

async function checkPackageVersion(
    entry: WatchEntry,
    cache: CacheService,
): Promise<NewVersionNotification | null> {
    const info = await fetchPackageInfo(entry.name, cache);
    if (!info) { return null; }

    const latestVersion = info.latestVersion;
    const updateType = compareVersions(entry.currentVersion, latestVersion);

    if (updateType === 'up-to-date' || updateType === 'unknown') {
        return null;
    }

    const seenKey = SEEN_VERSION_PREFIX + entry.name;
    const seenVersion = cache.get<string>(seenKey);

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
export async function markVersionSeen(
    name: string,
    version: string,
    cache: CacheService,
): Promise<void> {
    const seenKey = SEEN_VERSION_PREFIX + name;
    await cache.set(seenKey, version);
}

/** Mark all notifications as seen in the cache. */
export async function markAllSeen(
    notifications: readonly NewVersionNotification[],
    cache: CacheService,
): Promise<void> {
    for (const n of notifications) {
        await markVersionSeen(n.name, n.newVersion, cache);
    }
}

/**
 * Build watch list from scan results based on filter mode.
 * Only includes direct dependencies; transitive deps are excluded.
 * Includes blocker info if the package has an upgrade blocker.
 */
export function buildWatchList(
    results: readonly VibrancyResult[],
    filterMode: 'all' | 'unhealthy' | 'custom',
    customList?: readonly string[],
    unhealthyThreshold: number = 40,
): WatchEntry[] {
    const directResults = results.filter(r => r.package.isDirect);

    const toEntry = (r: VibrancyResult): WatchEntry => ({
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

function delay(ms: number): Promise<void> {
    return new Promise(resolve => setTimeout(resolve, ms));
}
