import { CacheService } from './cache-service';
import { ScanLogger } from './scan-logger';
import { fetchWithRetry } from './fetch-retry';

const RELEASES_URL =
    'https://storage.googleapis.com/flutter_infra_release/releases/releases_linux.json';

export interface FlutterRelease {
    readonly version: string;
    readonly releaseDate: string;
}

/** Fetch stable Flutter releases, newest first. */
export async function fetchFlutterReleases(
    cache?: CacheService,
    logger?: ScanLogger,
): Promise<FlutterRelease[]> {
    const cacheKey = 'flutter.releases';
    const cached = cache?.get<FlutterRelease[]>(cacheKey);
    if (cached) {
        logger?.cacheHit(cacheKey);
        return cached;
    }
    logger?.cacheMiss(cacheKey);

    try {
        logger?.apiRequest('GET', RELEASES_URL);
        const t0 = Date.now();
        const resp = await fetchWithRetry(RELEASES_URL, undefined, logger);
        logger?.apiResponse(resp.status, resp.statusText, Date.now() - t0);
        if (!resp.ok) { return []; }

        const json: any = await resp.json();
        const releases = parseStableReleases(json);
        await cache?.set(cacheKey, releases);
        return releases;
    } catch {
        logger?.error('Failed to fetch Flutter releases');
        return [];
    }
}

/** Extract stable releases from the Flutter releases JSON. */
export function parseStableReleases(json: any): FlutterRelease[] {
    const raw: any[] = json?.releases ?? [];
    return raw
        .filter((r: any) => r.channel === 'stable')
        .map((r: any) => ({
            version: r.version ?? '',
            releaseDate: r.release_date ?? '',
        }))
        .sort((a, b) =>
            new Date(b.releaseDate).getTime()
            - new Date(a.releaseDate).getTime(),
        );
}
