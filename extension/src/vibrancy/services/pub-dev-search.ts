import { AlternativeSuggestion } from '../types';
import { CacheService } from './cache-service';
import { ScanLogger } from './scan-logger';
import { fetchWithRetry } from './fetch-retry';

const SEARCH_URL = 'https://pub.dev/api/search';

interface SearchResult {
    readonly name: string;
    readonly likes: number;
}

interface SearchResponse {
    readonly packages: readonly { package: string }[];
}

interface PackageScore {
    readonly grantedPoints: number;
    readonly likeCount: number;
}

/**
 * Search pub.dev for alternative packages sharing the same topics.
 * Returns top 3 alternatives sorted by popularity, excluding the original
 * package and any already in the project.
 */
export async function searchAlternatives(
    topics: readonly string[],
    exclude: readonly string[],
    cache?: CacheService,
    logger?: ScanLogger,
): Promise<AlternativeSuggestion[]> {
    if (topics.length === 0) {
        return [];
    }

    const cacheKey = `pub.search.${topics.slice().sort().join(',')}`;
    const cached = cache?.get<SearchResult[]>(cacheKey);
    if (cached) {
        logger?.cacheHit(cacheKey);
        return filterAndRank(cached, exclude, cache, logger);
    }
    logger?.cacheMiss(cacheKey);

    const results = await searchByTopics(topics, logger);
    if (results.length > 0) {
        await cache?.set(cacheKey, results);
    }

    return filterAndRank(results, exclude, cache, logger);
}

async function searchByTopics(
    topics: readonly string[],
    logger?: ScanLogger,
): Promise<SearchResult[]> {
    const topicQueries = topics.map(t => `topic:${t}`).join(' ');
    const query = encodeURIComponent(topicQueries);
    const url = `${SEARCH_URL}?q=${query}&sort=popularity`;

    try {
        logger?.apiRequest('GET', url);
        const t0 = Date.now();
        const resp = await fetchWithRetry(url, undefined, logger);
        logger?.apiResponse(resp.status, resp.statusText, Date.now() - t0);

        if (!resp.ok) {
            return [];
        }

        const json = await resp.json() as SearchResponse;
        const packages = json.packages ?? [];
        const topPackages = packages.slice(0, 20);

        const scores = await Promise.all(
            topPackages.map(pkg => fetchPackageScore(pkg.package, logger)),
        );

        return topPackages.map((pkg, i) => ({
            name: pkg.package,
            likes: scores[i]?.likeCount ?? 0,
        }));
    } catch {
        logger?.error(`Failed to search pub.dev for topics: ${topics.join(', ')}`);
        return [];
    }
}

async function fetchPackageScore(
    name: string,
    logger?: ScanLogger,
): Promise<PackageScore | null> {
    const url = `https://pub.dev/api/packages/${name}/score`;
    try {
        const resp = await fetchWithRetry(url, undefined, logger);
        if (!resp.ok) { return null; }

        const json: any = await resp.json();
        return {
            grantedPoints: json.grantedPoints ?? 0,
            likeCount: json.likeCount ?? 0,
        };
    } catch {
        return null;
    }
}

async function filterAndRank(
    results: SearchResult[],
    exclude: readonly string[],
    cache?: CacheService,
    logger?: ScanLogger,
): Promise<AlternativeSuggestion[]> {
    const excludeSet = new Set(exclude.map(n => n.toLowerCase()));
    const filtered = results.filter(
        r => !excludeSet.has(r.name.toLowerCase()),
    );

    const suggestions: AlternativeSuggestion[] = [];
    for (const result of filtered.slice(0, 5)) {
        const score = await getVibrancyScore(result.name, cache, logger);
        if (score !== null && score < 50) {
            continue;
        }
        suggestions.push({
            name: result.name,
            source: 'discovery',
            score,
            likes: result.likes,
        });
        if (suggestions.length >= 3) {
            break;
        }
    }

    return suggestions;
}

async function getVibrancyScore(
    name: string,
    cache?: CacheService,
    _logger?: ScanLogger,
): Promise<number | null> {
    const cacheKey = `pub.metrics.${name}`;
    const cached = cache?.get<{ pubPoints: number }>(cacheKey);
    if (cached) {
        return Math.min(100, Math.round(cached.pubPoints * 100 / 160));
    }
    return null;
}

/**
 * Build alternatives list combining curated replacements with discovery.
 * Curated replacements always come first; discovery only if no curated exists.
 */
export function buildAlternatives(
    curatedReplacement: string | undefined,
    discoveryAlternatives: AlternativeSuggestion[],
): AlternativeSuggestion[] {
    const alternatives: AlternativeSuggestion[] = [];

    if (curatedReplacement) {
        alternatives.push({
            name: curatedReplacement,
            source: 'curated',
            score: null,
            likes: 0,
        });
    }

    if (alternatives.length === 0) {
        alternatives.push(...discoveryAlternatives);
    }

    return alternatives;
}
