/**
 * Full saropa_lints version list from the pub.dev API, with the per-version
 * constraints the compatibility checks need (SDK, meta, analyzer).
 *
 * Cached with its fetch time. When the network fails the cache is served
 * with `stale: true`; with no cache at all a typed [PubVersionsError] is
 * thrown. The fetch function is injectable for tests.
 */

import { fetchWithRetry } from '../vibrancy/services/fetch-retry';

export const PUB_API_URL = 'https://pub.dev/api/packages/saropa_lints';

export interface PubVersion {
  version: string;
  /** `environment.sdk` constraint. */
  sdk?: string;
  /** `meta` dependency constraint. */
  meta?: string;
  /** `analyzer` dependency constraint. */
  analyzer?: string;
  /** ISO publish date. */
  published?: string;
}

export interface PubVersionsResult {
  versions: PubVersion[];
  /** Epoch ms of the fetch that produced `versions`. */
  fetchedAt: number;
  /** True when the network failed and the cache was served instead. */
  stale: boolean;
  /** pub.dev's `latest.version` (stable), when present. */
  latest?: string;
}

/** Cached payload; persistable as plain JSON. */
export interface PubVersionsCache {
  versions: PubVersion[];
  fetchedAt: number;
  latest?: string;
}

/** Optional persistent cache (e.g. backed by extension globalState). */
export interface PubVersionsStore {
  get(): PubVersionsCache | undefined;
  set(cache: PubVersionsCache): void | PromiseLike<void>;
}

export interface GetPubVersionsOptions {
  /** Defaults to fetchWithRetry. */
  fetchFn?: (url: string) => Promise<Response>;
  /** Defaults to an in-memory store shared by the module. */
  store?: PubVersionsStore;
  /** Defaults to Date.now. */
  now?: () => number;
}

export type PubVersionsErrorReason = 'http' | 'network' | 'parse';

/** Thrown when the fetch fails and there is no cache to fall back on. */
export class PubVersionsError extends Error {
  constructor(
    public readonly reason: PubVersionsErrorReason,
    message: string,
  ) {
    super(message);
    this.name = 'PubVersionsError';
  }
}

let memoryCache: PubVersionsCache | undefined;
const memoryStore: PubVersionsStore = {
  get: () => memoryCache,
  set: (c) => { memoryCache = c; },
};

function str(v: unknown): string | undefined {
  return typeof v === 'string' && v ? v : undefined;
}

/** Map one entry of the pub.dev API `versions` array; null when unusable. */
export function parsePubVersion(entry: unknown): PubVersion | null {
  const e = entry as any;
  const version = str(e?.version);
  if (!version) { return null; }
  const pubspec = e?.pubspec;
  const deps = { ...(pubspec?.dev_dependencies ?? {}), ...(pubspec?.dependencies ?? {}) };
  return {
    version,
    sdk: str(pubspec?.environment?.sdk),
    meta: str(deps.meta),
    analyzer: str(deps.analyzer),
    published: str(e?.published),
  };
}

/**
 * Return the saropa_lints version list. Throws [PubVersionsError] only when
 * the fetch fails and nothing is cached.
 */
export async function getPubVersions(
  opts: GetPubVersionsOptions = {},
): Promise<PubVersionsResult> {
  const fetchFn = opts.fetchFn ?? ((u: string) => fetchWithRetry(u));
  const store = opts.store ?? memoryStore;
  const now = opts.now ?? Date.now;

  let failure: PubVersionsError;
  try {
    const resp = await fetchFn(PUB_API_URL);
    if (!resp.ok) {
      failure = new PubVersionsError('http', `pub.dev returned HTTP ${resp.status}`);
    } else {
      const json: any = await resp.json();
      const raw: unknown = json?.versions;
      if (!Array.isArray(raw)) {
        failure = new PubVersionsError('parse', 'pub.dev response has no versions list');
      } else {
        const versions = raw.map(parsePubVersion).filter((v): v is PubVersion => v !== null);
        const cache: PubVersionsCache = {
          versions,
          fetchedAt: now(),
          latest: str(json?.latest?.version),
        };
        await store.set(cache);
        return { ...cache, stale: false };
      }
    }
  } catch (err) {
    failure = new PubVersionsError('network', err instanceof Error ? err.message : String(err));
  }

  const cached = store.get();
  if (cached) { return { ...cached, stale: true }; }
  throw failure;
}
