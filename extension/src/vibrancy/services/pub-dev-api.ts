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

    const cachedInfo = cache?.get<PubDevPackageInfo>(infoCacheKey);
    const cachedPrerelease = cache?.get<PrereleaseInfo>(prereleaseCacheKey);
    if (cachedInfo && cachedPrerelease !== undefined) {
        logger?.cacheHit(infoCacheKey);
        return { info: cachedInfo, prerelease: cachedPrerelease };
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
        if (!resp.ok) { return { info: null, prerelease: null }; }

        const json: any = await resp.json();
        const latest = json.latest ?? {};
        const pubspec = latest.pubspec ?? {};

        const info: PubDevPackageInfo = {
            name: json.name ?? name,
            latestVersion: latest.version ?? '',
            publishedDate: latest.published ?? '',
            repositoryUrl: pubspec.repository ?? pubspec.homepage ?? null,
            isDiscontinued: json.isDiscontinued ?? false,
            isUnlisted: json.isUnlisted ?? false,
            pubPoints: 0,
            publisher: null,
            license: pubspec.license ?? null,
            description: pubspec.description ?? null,
            topics: Array.isArray(pubspec.topics) ? pubspec.topics : [],
        };

        const archiveUrl = latest.archive_url ?? null;
        if (archiveUrl) {
            await cache?.set(`${cachePrefix}.archiveUrl.${name}`, archiveUrl);
        }

        const versions: string[] = Array.isArray(json.versions)
            ? json.versions.map((v: any) => v.version).filter(Boolean)
            : [];
        const prerelease = versions.length > 0
            ? extractPrereleaseInfo(versions)
            : null;

        await cache?.set(infoCacheKey, info);
        if (prerelease) {
            await cache?.set(prereleaseCacheKey, prerelease);
        }

        return { info, prerelease };
    } catch {
        logger?.error(`Failed to fetch package info for ${name} from ${registryUrl}`);
        return { info: null, prerelease: null };
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
        pubPoints: 0, platforms: [], wasmReady: null,
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

    try {
        logger?.apiRequest('GET', url);
        const t0 = Date.now();
        const resp = await fetchWithRetry(url, { headers }, logger);
        logger?.apiResponse(resp.status, resp.statusText, Date.now() - t0);
        if (!resp.ok) { return fallback; }

        const json: any = await resp.json();
        const tags: string[] = json.score?.tags ?? [];
        const result: PubDevMetrics = {
            pubPoints: json.score?.grantedPoints ?? 0,
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
