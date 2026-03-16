import { Vulnerability } from '../types';
import { CacheService } from './cache-service';
import { ScanLogger } from './scan-logger';
import { fetchWithRetry } from './fetch-retry';
import { classifySeverity } from '../scoring/vuln-classifier';

const GITHUB_ADVISORIES_URL = 'https://api.github.com/advisories';
const CACHE_KEY_PREFIX = 'ghsa.vulns';

export interface GhsaPackageQuery {
    readonly name: string;
    readonly version: string;
}

export interface GhsaQueryResult {
    readonly name: string;
    readonly version: string;
    readonly vulnerabilities: readonly Vulnerability[];
}

interface GhsaAdvisory {
    readonly ghsa_id: string;
    readonly cve_id: string | null;
    readonly summary: string;
    readonly description: string;
    readonly severity: 'low' | 'medium' | 'high' | 'critical';
    readonly cvss?: {
        readonly score: number;
        readonly vector_string: string;
    };
    readonly vulnerabilities: readonly GhsaVulnerability[];
    readonly html_url: string;
}

interface GhsaVulnerability {
    readonly package: {
        readonly ecosystem: string;
        readonly name: string;
    };
    readonly vulnerable_version_range: string;
    readonly first_patched_version: string | null;
}

function buildHeaders(token?: string): Record<string, string> {
    const headers: Record<string, string> = {
        'Accept': 'application/vnd.github+json',
        'User-Agent': 'saropa-package-vibrancy',
        'X-GitHub-Api-Version': '2022-11-28',
    };
    if (token) {
        headers['Authorization'] = `Bearer ${token}`;
    }
    return headers;
}

/** Max concurrent requests to avoid rate limiting. */
const MAX_CONCURRENT = 5;

/**
 * Query GitHub Advisory Database for vulnerabilities affecting Pub packages.
 * Queries packages in parallel batches since the API doesn't support batch queries.
 */
export async function queryGitHubAdvisories(
    packages: readonly GhsaPackageQuery[],
    token?: string,
    cache?: CacheService,
    logger?: ScanLogger,
): Promise<readonly GhsaQueryResult[]> {
    if (packages.length === 0) {
        return [];
    }

    const results: GhsaQueryResult[] = [];
    const uncached: GhsaPackageQuery[] = [];

    for (const pkg of packages) {
        const cacheKey = `${CACHE_KEY_PREFIX}.${pkg.name}.${pkg.version}`;
        const cached = cache?.get<readonly Vulnerability[]>(cacheKey);
        if (cached !== undefined && cached !== null) {
            logger?.cacheHit(cacheKey);
            results.push({ name: pkg.name, version: pkg.version, vulnerabilities: cached });
        } else {
            logger?.cacheMiss(cacheKey);
            uncached.push(pkg);
        }
    }

    // Process uncached packages in parallel batches
    for (let i = 0; i < uncached.length; i += MAX_CONCURRENT) {
        const batch = uncached.slice(i, i + MAX_CONCURRENT);
        const batchResults = await Promise.all(
            batch.map(async (pkg) => {
                const vulns = await fetchAdvisoriesForPackage(
                    pkg.name, pkg.version, token, logger,
                );
                const cacheKey = `${CACHE_KEY_PREFIX}.${pkg.name}.${pkg.version}`;
                cache?.set(cacheKey, vulns);
                return { name: pkg.name, version: pkg.version, vulnerabilities: vulns };
            }),
        );
        results.push(...batchResults);
    }

    return results;
}

async function fetchAdvisoriesForPackage(
    name: string,
    version: string,
    token?: string,
    logger?: ScanLogger,
): Promise<readonly Vulnerability[]> {
    const url = new URL(GITHUB_ADVISORIES_URL);
    url.searchParams.set('ecosystem', 'pub');
    url.searchParams.set('package', name);
    url.searchParams.set('affects', version);
    url.searchParams.set('per_page', '100');

    try {
        logger?.apiRequest('GET', url.toString());
        const t0 = Date.now();
        const resp = await fetchWithRetry(
            url.toString(),
            { headers: buildHeaders(token) },
            logger,
        );
        logger?.apiResponse(resp.status, resp.statusText, Date.now() - t0);

        if (!resp.ok) {
            if (resp.status === 404) {
                return [];
            }
            logger?.error(`GitHub Advisory query failed for ${name}: ${resp.status}`);
            return [];
        }

        const advisories = await resp.json() as readonly GhsaAdvisory[];
        return advisories.flatMap(adv => parseAdvisory(adv, name));
    } catch (err) {
        logger?.error(`GitHub Advisory query error for ${name}: ${err}`);
        return [];
    }
}

function parseAdvisory(advisory: GhsaAdvisory, packageName: string): Vulnerability[] {
    const matchingVulns = advisory.vulnerabilities.filter(
        v => v.package.ecosystem === 'pub' && v.package.name === packageName,
    );

    if (matchingVulns.length === 0) {
        return [];
    }

    const cvssScore = advisory.cvss?.score ?? null;
    const severity = cvssScore !== null
        ? classifySeverity(cvssScore)
        : mapGhsaSeverity(advisory.severity);

    const fixedVersion = matchingVulns
        .map(v => v.first_patched_version)
        .find(v => v !== null) ?? null;

    return [{
        id: advisory.ghsa_id,
        summary: advisory.summary || advisory.description.slice(0, 200),
        severity,
        cvssScore,
        fixedVersion,
        url: advisory.html_url,
    }];
}

function mapGhsaSeverity(
    ghsaSeverity: 'low' | 'medium' | 'high' | 'critical',
): Vulnerability['severity'] {
    return ghsaSeverity;
}

/**
 * Merge vulnerabilities from multiple sources, deduplicating by ID.
 * First occurrence wins; later duplicates are skipped.
 */
export function mergeVulnerabilities(
    ...sources: readonly (readonly Vulnerability[])[]
): readonly Vulnerability[] {
    const seen = new Map<string, Vulnerability>();

    for (const source of sources) {
        for (const vuln of source) {
            if (!seen.has(vuln.id)) {
                seen.set(vuln.id, vuln);
            }
        }
    }

    return Array.from(seen.values());
}
