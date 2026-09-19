/**
 * Fetches the dependency ranges of a candidate (target) package version from
 * the pub.dev API so the blast-radius check can compare them with SDK pins.
 * I/O lives here; computeBlastRadius stays pure. Fails soft to null.
 */

import { fetchWithRetry } from './fetch-retry';
import { CacheService } from './cache-service';
import { ScanLogger } from './scan-logger';
import { VibrancyResult } from '../types';

const PUB_DEV_URL = 'https://pub.dev';

export type TargetDeps = ReadonlyMap<string, string>;

/** Pure: pubspec.dependencies of a /versions/<v> response as name -> range. */
export function parseTargetDeps(json: unknown): Map<string, string> | null {
    const deps = (json as { pubspec?: { dependencies?: unknown } } | null)
        ?.pubspec?.dependencies;
    if (!deps || typeof deps !== 'object') { return null; }
    const out = new Map<string, string>();
    for (const [name, range] of Object.entries(deps as Record<string, unknown>)) {
        // Map-valued entries (sdk/git/path) carry no comparable version range.
        if (typeof range === 'string') { out.set(name, range); }
    }
    return out;
}

/** Fetch one pkg@version's dependency ranges; cached; null on any failure. */
export async function fetchTargetDeps(
    pkg: string, version: string,
    cache?: CacheService, logger?: ScanLogger, registryUrl = PUB_DEV_URL,
): Promise<Map<string, string> | null> {
    const key = `pub.targetDeps.${pkg}@${version}`;
    const cached = cache?.get<Record<string, string>>(key);
    if (cached) { return new Map(Object.entries(cached)); }
    const url = `${registryUrl}/api/packages/${encodeURIComponent(pkg)}/versions/${encodeURIComponent(version)}`;
    try {
        const resp = await fetchWithRetry(url, undefined, logger);
        if (!resp.ok) { return null; }
        const deps = parseTargetDeps(await resp.json());
        if (deps) { await cache?.set(key, Object.fromEntries(deps)); }
        return deps;
    } catch {
        return null;
    }
}

/** Target deps for every package that has a newer version; keyed pkg@version. */
export async function fetchTargetDepsFor(
    results: readonly VibrancyResult[],
    cache?: CacheService, logger?: ScanLogger,
    fetcher: typeof fetchTargetDeps = fetchTargetDeps,
): Promise<Map<string, Map<string, string>>> {
    const out = new Map<string, Map<string, string>>();
    const todo = results.filter(r =>
        r.updateInfo && r.updateInfo.updateStatus !== 'up-to-date');
    await Promise.all(todo.map(async r => {
        const v = r.updateInfo!.latestVersion;
        const deps = await fetcher(r.package.name, v, cache, logger);
        if (deps) { out.set(`${r.package.name}@${v}`, deps); }
    }));
    return out;
}
