import { PubDevPackageInfo, PubDevMetrics } from '../types';
import { CacheService } from './cache-service';
import { ScanLogger } from './scan-logger';
import { fetchWithRetry } from './fetch-retry';
import { extractPrereleaseInfo, PrereleaseInfo } from '../scoring/prerelease-classifier';
import {
    RegistryService,
    buildPackageApiUrl,
    buildMetricsApiUrl,
    buildPublisherApiUrl,
    buildScoreApiUrl,
    buildRegistryHeaders,
} from './registry-service';

const PUB_DEV_URL = 'https://pub.dev';

/** Simple hash for registry URL to use in cache keys. */
function hashUrl(url: string): string {
    let hash = 0;
    for (let i = 0; i < url.length; i++) {
        const char = url.charCodeAt(i);
        hash = ((hash << 5) - hash) + char;
        hash = hash & hash;
    }
    return Math.abs(hash).toString(36);
}

/** Options for registry-aware API calls. */
export interface RegistryOptions {
    readonly registryService?: RegistryService;
    readonly registryUrl?: string;
}

/** Result of fetching package info including prerelease data. */
export interface PackageInfoResult {
    readonly info: PubDevPackageInfo | null;
    readonly prerelease: PrereleaseInfo | null;
    /** Map of version string to ISO publish date for all known versions. */
    readonly versionDates: Readonly<Record<string, string>>;
}

/** Fetch package metadata from a registry. */
export async function fetchPackageInfo(
    name: string,
    cache?: CacheService,
    logger?: ScanLogger,
    registryOpts?: RegistryOptions,
): Promise<PubDevPackageInfo | null> {
    const result = await fetchPackageInfoWithPrerelease(name, cache, logger, registryOpts);
    return result.info;
}

/** Fetch package metadata from a registry including prerelease info. */
export async function fetchPackageInfoWithPrerelease(
    name: string,
    cache?: CacheService,
    logger?: ScanLogger,
    registryOpts?: RegistryOptions,
): Promise<PackageInfoResult> {
    const registryUrl = registryOpts?.registryUrl ?? PUB_DEV_URL;
    const registryService = registryOpts?.registryService;
    const cachePrefix = registryUrl === PUB_DEV_URL ? 'pub' : `reg.${hashUrl(registryUrl)}`;

    const infoCacheKey = `${cachePrefix}.info.${name}`;
    const prereleaseCacheKey = `${cachePrefix}.prerelease.${name}`;

    const versionDatesCacheKey = `${cachePrefix}.versionDates.${name}`;

    const cachedInfo = cache?.get<PubDevPackageInfo>(infoCacheKey);
    const cachedPrerelease = cache?.get<PrereleaseInfo>(prereleaseCacheKey);
    if (cachedInfo && cachedPrerelease !== undefined) {
        logger?.cacheHit(infoCacheKey);
        const cachedDates = cache?.get<Record<string, string>>(versionDatesCacheKey) ?? {};
        return { info: cachedInfo, prerelease: cachedPrerelease, versionDates: cachedDates };
    }
    logger?.cacheMiss(infoCacheKey);

    const url = buildPackageApiUrl(registryUrl, name);
    const headers = registryService
        ? await buildRegistryHeaders(registryUrl, registryService)
        : {};

    try {
        logger?.apiRequest('GET', url);
        const t0 = Date.now();
        const resp = await fetchWithRetry(url, { headers }, logger);
        logger?.apiResponse(resp.status, resp.statusText, Date.now() - t0);
        if (!resp.ok) { return { info: null, prerelease: null, versionDates: {} }; }

        const json: any = await resp.json();
        const latest = json.latest ?? {};
        const pubspec = latest.pubspec ?? {};

        // Extract version dates map and created date (first version) before
        // constructing PubDevPackageInfo so createdDate is set at creation.
        const versionDates: Record<string, string> = {};
        let createdDate: string | undefined;
        const versionStrings: string[] = [];
        if (Array.isArray(json.versions)) {
            for (const v of json.versions) {
                if (!v.version) { continue; }
                versionStrings.push(v.version);
                if (v.published) {
                    versionDates[v.version] = v.published;
                    if (!createdDate) { createdDate = v.published; }
                }
            }
        }

        // Extract direct dependency names from pubspec.dependencies (keys only)
        const rawDeps = pubspec.dependencies;
        const dependencyNames = rawDeps && typeof rawDeps === 'object'
            ? Object.keys(rawDeps).sort()
            : [];

        const info: PubDevPackageInfo = {
            name: json.name ?? name,
            latestVersion: latest.version ?? '',
            publishedDate: latest.published ?? '',
            createdDate,
            repositoryUrl: pubspec.repository ?? pubspec.homepage ?? null,
            isDiscontinued: json.isDiscontinued ?? false,
            isUnlisted: json.isUnlisted ?? false,
            pubPoints: 0,
            publisher: null,
            license: pubspec.license ?? null,
            description: pubspec.description ?? null,
            topics: Array.isArray(pubspec.topics) ? pubspec.topics : [],
            dependencies: dependencyNames,
        };

        const archiveUrl = latest.archive_url ?? null;
        if (archiveUrl) {
            await cache?.set(`${cachePrefix}.archiveUrl.${name}`, archiveUrl);
        }

        const prerelease = versionStrings.length > 0
            ? extractPrereleaseInfo(versionStrings)
            : null;

        await cache?.set(infoCacheKey, info);
        await cache?.set(versionDatesCacheKey, versionDates);
        if (prerelease) {
            await cache?.set(prereleaseCacheKey, prerelease);
        }

        return { info, prerelease, versionDates };
    } catch {
        logger?.error(`Failed to fetch package info for ${name} from ${registryUrl}`);
        return { info: null, prerelease: null, versionDates: {} };
    }
}

const WASM_TAGS = ['is:wasm-ready', 'sdk:wasm'];

/** Fetch registry metrics: points, platforms, and WASM readiness. */
export async function fetchPackageMetrics(
    name: string,
    cache?: CacheService,
    logger?: ScanLogger,
    registryOpts?: RegistryOptions,
): Promise<PubDevMetrics> {
    const fallback: PubDevMetrics = {
        pubPoints: 0, likes: null, downloadCount30Days: null,
        platforms: [], wasmReady: null,
    };

    const registryUrl = registryOpts?.registryUrl ?? PUB_DEV_URL;
    const registryService = registryOpts?.registryService;
    const cachePrefix = registryUrl === PUB_DEV_URL ? 'pub' : `reg.${hashUrl(registryUrl)}`;

    const cacheKey = `${cachePrefix}.metrics.${name}`;
    const cached = cache?.get<PubDevMetrics>(cacheKey);
    if (cached) {
        logger?.cacheHit(cacheKey);
        return cached;
    }
    logger?.cacheMiss(cacheKey);

    const url = buildMetricsApiUrl(registryUrl, name);
    const headers = registryService
        ? await buildRegistryHeaders(registryUrl, registryService)
        : {};

    // Fetch metrics and score (likes) endpoints in parallel
    const scoreUrl = buildScoreApiUrl(registryUrl, name);
    try {
        const [metricsResp, scoreResp] = await Promise.all([
            (async () => {
                logger?.apiRequest('GET', url);
                const t0 = Date.now();
                const resp = await fetchWithRetry(url, { headers }, logger);
                logger?.apiResponse(resp.status, resp.statusText, Date.now() - t0);
                return resp;
            })(),
            (async () => {
                logger?.apiRequest('GET', scoreUrl);
                const t0 = Date.now();
                const resp = await fetchWithRetry(scoreUrl, { headers }, logger);
                logger?.apiResponse(resp.status, resp.statusText, Date.now() - t0);
                return resp;
            })(),
        ]);

        // Extract likes + 30-day download count from the score API even if
        // the metrics endpoint failed — the two endpoints are independent,
        // and one succeeding should not be discarded because the other
        // failed. `downloadCount30Days` is a package-specific trust signal
        // (unlike repo stars, which are shared across all packages in a
        // monorepo) so we want it whenever the score API responds.
        let likes: number | null = null;
        let downloadCount30Days: number | null = null;
        if (scoreResp.ok) {
            const scoreJson: any = await scoreResp.json();
            likes = scoreJson.likeCount ?? null;
            downloadCount30Days = scoreJson.downloadCount30Days ?? null;
        }

        if (!metricsResp.ok) {
            // Return partial result: score-derived fields available, metrics zeroed
            return { ...fallback, likes, downloadCount30Days };
        }

        const metricsJson: any = await metricsResp.json();
        const tags: string[] = metricsJson.score?.tags ?? [];

        const result: PubDevMetrics = {
            pubPoints: metricsJson.score?.grantedPoints ?? 0,
            likes,
            downloadCount30Days,
            platforms: extractPlatforms(tags),
            wasmReady: tags.some(t => WASM_TAGS.includes(t)),
        };

        await cache?.set(cacheKey, result);
        return result;
    } catch {
        logger?.error(`Failed to fetch metrics for ${name} from ${registryUrl}`);
        return fallback;
    }
}

function extractPlatforms(tags: string[]): string[] {
    return tags
        .filter(t => t.startsWith('platform:'))
        .map(t => t.slice('platform:'.length))
        .sort();
}

/** Fetch verified publisher ID from a registry. */
export async function fetchPublisher(
    name: string,
    cache?: CacheService,
    logger?: ScanLogger,
    registryOpts?: RegistryOptions,
): Promise<string | null> {
    const registryUrl = registryOpts?.registryUrl ?? PUB_DEV_URL;
    const registryService = registryOpts?.registryService;
    const cachePrefix = registryUrl === PUB_DEV_URL ? 'pub' : `reg.${hashUrl(registryUrl)}`;

    const cacheKey = `${cachePrefix}.publisher.${name}`;
    const cached = cache?.get<string | null>(cacheKey);
    if (cached !== undefined) {
        logger?.cacheHit(cacheKey);
        return cached;
    }
    logger?.cacheMiss(cacheKey);

    const url = buildPublisherApiUrl(registryUrl, name);
    const headers = registryService
        ? await buildRegistryHeaders(registryUrl, registryService)
        : {};

    try {
        logger?.apiRequest('GET', url);
        const t0 = Date.now();
        const resp = await fetchWithRetry(url, { headers }, logger);
        logger?.apiResponse(resp.status, resp.statusText, Date.now() - t0);
        if (!resp.ok) { return null; }

        const json: any = await resp.json();
        const publisherId = json.publisherId ?? null;

        await cache?.set(cacheKey, publisherId);
        return publisherId;
    } catch {
        logger?.error(`Failed to fetch publisher for ${name} from ${registryUrl}`);
        return null;
    }
}

/** Fetch archive size in bytes via HEAD request to the package archive. */
export async function fetchArchiveSize(
    name: string,
    cache?: CacheService,
    logger?: ScanLogger,
    registryOpts?: RegistryOptions,
): Promise<number | null> {
    const registryUrl = registryOpts?.registryUrl ?? PUB_DEV_URL;
    const registryService = registryOpts?.registryService;
    const cachePrefix = registryUrl === PUB_DEV_URL ? 'pub' : `reg.${hashUrl(registryUrl)}`;

    const cacheKey = `${cachePrefix}.archiveSize.${name}`;
    const cached = cache?.get<number>(cacheKey);
    if (cached !== null && cached !== undefined) {
        logger?.cacheHit(cacheKey);
        return cached;
    }
    logger?.cacheMiss(cacheKey);

    const archiveUrl = await resolveArchiveUrl(name, cache, logger, registryOpts);
    if (!archiveUrl) { return null; }

    const headers = registryService
        ? await buildRegistryHeaders(registryUrl, registryService)
        : {};

    return headContentLength(archiveUrl, cacheKey, cache, logger, headers);
}

async function resolveArchiveUrl(
    name: string,
    cache?: CacheService,
    logger?: ScanLogger,
    registryOpts?: RegistryOptions,
): Promise<string | null> {
    const registryUrl = registryOpts?.registryUrl ?? PUB_DEV_URL;
    const registryService = registryOpts?.registryService;
    const cachePrefix = registryUrl === PUB_DEV_URL ? 'pub' : `reg.${hashUrl(registryUrl)}`;

    const cachedUrl = cache?.get<string>(`${cachePrefix}.archiveUrl.${name}`);
    if (cachedUrl) { return cachedUrl; }

    const url = buildPackageApiUrl(registryUrl, name);
    const headers = registryService
        ? await buildRegistryHeaders(registryUrl, registryService)
        : {};

    try {
        logger?.apiRequest('GET', url);
        const t0 = Date.now();
        const resp = await fetchWithRetry(url, { headers }, logger);
        logger?.apiResponse(resp.status, resp.statusText, Date.now() - t0);
        if (!resp.ok) { return null; }

        const json: any = await resp.json();
        return json.latest?.archive_url ?? null;
    } catch {
        return null;
    }
}

/**
 * Fetch how many published packages on pub.dev depend on this package.
 * Scrapes the pub.dev search results page for the "Results N packages" count.
 * Only works for pub.dev (not custom registries) — ecosystem adoption on a
 * private registry is meaningless for vibrancy scoring.
 *
 * Returns null on failure (network error, unexpected HTML format) so the
 * scoring layer can gracefully skip the adoption bonus.
 */
export async function fetchReverseDependencyCount(
    name: string,
    cache?: CacheService,
    logger?: ScanLogger,
): Promise<number | null> {
    const cacheKey = `pub.reverseDeps.${name}`;
    const cached = cache?.get<number>(cacheKey);
    if (cached !== null && cached !== undefined) {
        logger?.cacheHit(cacheKey);
        return cached;
    }
    logger?.cacheMiss(cacheKey);

    // Use the pub.dev HTML search page because the JSON search API
    // doesn't return a total count — it only returns paginated results.
    const url = `https://pub.dev/packages?q=dependency%3A${encodeURIComponent(name)}`;
    try {
        logger?.apiRequest('GET', url);
        const t0 = Date.now();
        const resp = await fetchWithRetry(url, undefined, logger);
        logger?.apiResponse(resp.status, resp.statusText, Date.now() - t0);
        if (!resp.ok) { return null; }

        const html = await resp.text();
        // pub.dev renders "Results N packages" at the top of search results.
        // When no packages match, the page shows a different message with no
        // "Results" prefix, so the regex returns null → 0 dependents.
        const match = html.match(/Results\s+([\d,]+)\s+packages?/i);
        if (!match) { return 0; }

        // Count may contain commas for thousands (e.g. "1,314 packages")
        const count = parseInt(match[1].replace(/,/g, ''), 10);
        if (!Number.isFinite(count)) { return null; }

        await cache?.set(cacheKey, count);
        return count;
    } catch {
        logger?.error(`Failed to fetch reverse dependency count for ${name}`);
        return null;
    }
}

async function headContentLength(
    archiveUrl: string,
    cacheKey: string,
    cache?: CacheService,
    logger?: ScanLogger,
    headers?: Record<string, string>,
): Promise<number | null> {
    try {
        logger?.apiRequest('HEAD', archiveUrl);
        const t0 = Date.now();
        const resp = await fetchWithRetry(
            archiveUrl, { method: 'HEAD', headers }, logger,
        );
        logger?.apiResponse(resp.status, resp.statusText, Date.now() - t0);
        if (!resp.ok) { return null; }

        const header = resp.headers.get('Content-Length');
        if (!header) { return null; }

        const size = parseInt(header, 10);
        if (!Number.isFinite(size)) { return null; }

        await cache?.set(cacheKey, size);
        return size;
    } catch {
        return null;
    }
}
