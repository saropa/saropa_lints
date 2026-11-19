/**
 * Fetches the dependency ranges of a candidate (target) package version from
 * the pub.dev API so the blast-radius check can compare them with SDK pins.
 * I/O lives here; computeBlastRadius stays pure. Fails soft to null.
 */

import { fetchWithRetry } from './fetch-retry';
import { CacheService } from './cache-service';
import { ScanLogger } from './scan-logger';
import { VibrancyResult } from '../types';
import { VersionCandidate } from '../scoring/upgrade-blast-radius';

const PUB_DEV_URL = 'https://pub.dev';

export type TargetDeps = ReadonlyMap<string, string>;

/**
 * Pure: pubspec.dependencies of a /versions/<v> response as name -> range.
 * Empty map = pubspec present but no dependencies (a real answer, e.g. meta).
 * Null = unknown: no pubspec, or the release is retracted (never analysed or
 * suggested).
 */
export function parseTargetDeps(json: unknown): Map<string, string> | null {
    const j = json as { retracted?: unknown; pubspec?: { dependencies?: unknown } } | null;
    if (j?.retracted === true) { return null; }
    const pubspec = j?.pubspec;
    if (!pubspec || typeof pubspec !== 'object') { return null; }
    const out = new Map<string, string>();
    const deps = pubspec.dependencies;
    if (!deps || typeof deps !== 'object') { return out; }
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
    // `{}` is a real cached answer (no dependencies), so test type, not truthiness.
    if (cached && typeof cached === 'object') { return new Map(Object.entries(cached)); }
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
        try {
            const deps = await fetcher(r.package.name, v, cache, logger);
            if (deps) { out.set(`${r.package.name}@${v}`, deps); }
        } catch { /* one failed package must not reject the whole prefetch */ }
    }));
    return out;
}

/** Pure: /api/packages/<pkg> response -> releases with string dependency ranges. */
export function parseVersionList(json: unknown): VersionCandidate[] | null {
    const list = (json as { versions?: unknown } | null)?.versions;
    if (!Array.isArray(list)) { return null; }
    const out: VersionCandidate[] = [];
    for (const v of list as Record<string, any>[]) {
        if (typeof v?.version !== 'string') { continue; }
        const deps = new Map<string, string>();
        const rawDeps = v.pubspec?.dependencies;
        // Guard: Object.entries on a string would yield per-character junk.
        const entries = rawDeps && typeof rawDeps === 'object' ? Object.entries(rawDeps) : [];
        for (const [n, r] of entries) {
            if (typeof r === 'string') { deps.set(n, r); }
        }
        out.push({ version: v.version, deps, retracted: v.retracted === true });
    }
    return out;
}

/** All releases of a package in one request; cached; null on failure. */
export async function fetchVersionList(
    pkg: string, cache?: CacheService, logger?: ScanLogger, registryUrl = PUB_DEV_URL,
): Promise<VersionCandidate[] | null> {
    const key = `pub.versionList.${pkg}`;
    const cached = cache?.get<{ version: string; deps: Record<string, string>; retracted?: boolean }[]>(key);
    if (cached) {
        return cached.map(c => ({ ...c, deps: new Map(Object.entries(c.deps)) }));
    }
    try {
        const resp = await fetchWithRetry(
            `${registryUrl}/api/packages/${encodeURIComponent(pkg)}`, undefined, logger);
        if (!resp.ok) { return null; }
        const list = parseVersionList(await resp.json());
        if (list) {
            await cache?.set(key, list.map(c => ({ ...c, deps: Object.fromEntries(c.deps) })));
        }
        return list;
    } catch {
        return null;
    }
}

/** Release lists for packages whose latest is blocked; only those, to bound requests. */
export async function fetchVersionListsFor(
    pkgs: readonly string[], cache?: CacheService, logger?: ScanLogger,
    fetcher: typeof fetchVersionList = fetchVersionList,
): Promise<Map<string, VersionCandidate[]>> {
    const out = new Map<string, VersionCandidate[]>();
    await Promise.all(pkgs.map(async p => {
        try {
            const l = await fetcher(p, cache, logger);
            if (l) { out.set(p, l); }
        } catch { /* one failed package must not reject the whole prefetch */ }
    }));
    return out;
}
