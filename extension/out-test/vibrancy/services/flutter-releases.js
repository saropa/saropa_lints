"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.fetchFlutterReleases = fetchFlutterReleases;
exports.parseStableReleases = parseStableReleases;
const fetch_retry_1 = require("./fetch-retry");
const RELEASES_URL = 'https://storage.googleapis.com/flutter_infra_release/releases/releases_linux.json';
/** Fetch stable Flutter releases, newest first. */
async function fetchFlutterReleases(cache, logger) {
    const cacheKey = 'flutter.releases';
    const cached = cache?.get(cacheKey);
    if (cached) {
        logger?.cacheHit(cacheKey);
        return cached;
    }
    logger?.cacheMiss(cacheKey);
    try {
        logger?.apiRequest('GET', RELEASES_URL);
        const t0 = Date.now();
        const resp = await (0, fetch_retry_1.fetchWithRetry)(RELEASES_URL, undefined, logger);
        logger?.apiResponse(resp.status, resp.statusText, Date.now() - t0);
        if (!resp.ok) {
            return [];
        }
        const json = await resp.json();
        const releases = parseStableReleases(json);
        await cache?.set(cacheKey, releases);
        return releases;
    }
    catch {
        logger?.error('Failed to fetch Flutter releases');
        return [];
    }
}
/** Extract stable releases from the Flutter releases JSON. */
function parseStableReleases(json) {
    const raw = json?.releases ?? [];
    return raw
        .filter((r) => r.channel === 'stable')
        .map((r) => ({
        version: r.version ?? '',
        releaseDate: r.release_date ?? '',
    }))
        .sort((a, b) => new Date(b.releaseDate).getTime()
        - new Date(a.releaseDate).getTime());
}
//# sourceMappingURL=flutter-releases.js.map