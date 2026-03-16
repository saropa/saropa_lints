import { Vulnerability } from '../types';
import { CacheService } from './cache-service';
import { ScanLogger } from './scan-logger';
import { fetchWithRetry } from './fetch-retry';
import { classifySeverity } from '../scoring/vuln-classifier';

const OSV_BATCH_URL = 'https://api.osv.dev/v1/querybatch';
const CACHE_KEY_PREFIX = 'osv.vulns';

/** Input package info for OSV query. */
export interface OsvPackageQuery {
    readonly name: string;
    readonly version: string;
}

/** Result of vulnerability query for a single package. */
export interface OsvQueryResult {
    readonly name: string;
    readonly version: string;
    readonly vulnerabilities: readonly Vulnerability[];
}

interface OsvBatchRequest {
    readonly queries: readonly OsvQuery[];
}

interface OsvQuery {
    readonly package: {
        readonly name: string;
        readonly ecosystem: 'Pub';
    };
    readonly version: string;
}

interface OsvBatchResponse {
    readonly results: readonly OsvVulnResult[];
}

interface OsvVulnResult {
    readonly vulns?: readonly OsvVulnerability[];
}

interface OsvVulnerability {
    readonly id: string;
    readonly summary?: string;
    readonly details?: string;
    readonly severity?: readonly OsvSeverity[];
    readonly affected?: readonly OsvAffected[];
    readonly references?: readonly OsvReference[];
}

interface OsvSeverity {
    readonly type: string;
    readonly score: string;
}

interface OsvAffected {
    readonly ranges?: readonly OsvRange[];
}

interface OsvRange {
    readonly type: string;
    readonly events: readonly OsvEvent[];
}

interface OsvEvent {
    readonly introduced?: string;
    readonly fixed?: string;
}

interface OsvReference {
    readonly type: string;
    readonly url: string;
}

/**
 * Query OSV database for vulnerabilities affecting the given packages.
 * Uses batch endpoint for efficiency (one HTTP call for all packages).
 */
export async function queryVulnerabilities(
    packages: readonly OsvPackageQuery[],
    cache?: CacheService,
    logger?: ScanLogger,
): Promise<readonly OsvQueryResult[]> {
    if (packages.length === 0) {
        return [];
    }

    const uncached: OsvPackageQuery[] = [];
    const cachedResults = new Map<string, readonly Vulnerability[]>();

    for (const pkg of packages) {
        const cacheKey = `${CACHE_KEY_PREFIX}.${pkg.name}.${pkg.version}`;
        const cached = cache?.get<readonly Vulnerability[]>(cacheKey);
        if (cached !== undefined && cached !== null) {
            logger?.cacheHit(cacheKey);
            cachedResults.set(`${pkg.name}@${pkg.version}`, cached);
        } else {
            logger?.cacheMiss(cacheKey);
            uncached.push(pkg);
        }
    }

    if (uncached.length > 0) {
        const freshResults = await fetchVulnerabilities(uncached, cache, logger);
        for (const result of freshResults) {
            cachedResults.set(
                `${result.name}@${result.version}`,
                result.vulnerabilities,
            );
        }
    }

    return packages.map(pkg => ({
        name: pkg.name,
        version: pkg.version,
        vulnerabilities: cachedResults.get(`${pkg.name}@${pkg.version}`) ?? [],
    }));
}

async function fetchVulnerabilities(
    packages: readonly OsvPackageQuery[],
    cache?: CacheService,
    logger?: ScanLogger,
): Promise<readonly OsvQueryResult[]> {
    const queries: OsvQuery[] = packages.map(pkg => ({
        package: { name: pkg.name, ecosystem: 'Pub' },
        version: pkg.version,
    }));

    const body: OsvBatchRequest = { queries };

    try {
        logger?.apiRequest('POST', OSV_BATCH_URL);
        const t0 = Date.now();
        const resp = await fetchWithRetry(
            OSV_BATCH_URL,
            {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify(body),
            },
            logger,
        );
        logger?.apiResponse(resp.status, resp.statusText, Date.now() - t0);

        if (!resp.ok) {
            logger?.error(`OSV batch query failed: ${resp.status}`);
            return packages.map(pkg => ({
                name: pkg.name,
                version: pkg.version,
                vulnerabilities: [],
            }));
        }

        const json = await resp.json() as OsvBatchResponse;
        return parseOsvResponse(packages, json, cache, logger);
    } catch (err) {
        logger?.error(`OSV batch query error: ${err}`);
        return packages.map(pkg => ({
            name: pkg.name,
            version: pkg.version,
            vulnerabilities: [],
        }));
    }
}

function parseOsvResponse(
    packages: readonly OsvPackageQuery[],
    response: OsvBatchResponse,
    cache?: CacheService,
    logger?: ScanLogger,
): OsvQueryResult[] {
    const results: OsvQueryResult[] = [];

    for (let i = 0; i < packages.length; i++) {
        const pkg = packages[i];
        const vulnResult = response.results[i];
        const vulnerabilities = vulnResult?.vulns
            ? vulnResult.vulns.map(parseVulnerability)
            : [];

        if (vulnerabilities.length > 0) {
            logger?.info(
                `${pkg.name}@${pkg.version}: ${vulnerabilities.length} vulnerability(ies)`,
            );
        }

        const cacheKey = `${CACHE_KEY_PREFIX}.${pkg.name}.${pkg.version}`;
        cache?.set(cacheKey, vulnerabilities);

        results.push({
            name: pkg.name,
            version: pkg.version,
            vulnerabilities,
        });
    }

    return results;
}

function parseVulnerability(osv: OsvVulnerability): Vulnerability {
    const cvssScore = extractCvssScore(osv.severity);
    const severity = classifySeverity(cvssScore);
    const fixedVersion = extractFixedVersion(osv.affected);
    const url = extractAdvisoryUrl(osv);

    return {
        id: osv.id,
        summary: osv.summary ?? osv.details?.slice(0, 200) ?? 'No description',
        severity,
        cvssScore,
        fixedVersion,
        url,
    };
}

function extractCvssScore(
    severities: readonly OsvSeverity[] | undefined,
): number | null {
    if (!severities) { return null; }

    for (const sev of severities) {
        if (sev.type === 'CVSS_V3' || sev.type === 'CVSS_V2') {
            const score = parseFloat(sev.score);
            if (!isNaN(score)) {
                return score;
            }
            const match = sev.score.match(/CVSS:\d+\.\d+\/AV:\w+.*?(\d+\.?\d*)/);
            if (match) {
                return parseFloat(match[1]);
            }
        }
    }

    return null;
}

function extractFixedVersion(
    affected: readonly OsvAffected[] | undefined,
): string | null {
    if (!affected) { return null; }

    for (const a of affected) {
        if (!a.ranges) { continue; }
        for (const range of a.ranges) {
            for (const event of range.events) {
                if (event.fixed) {
                    return event.fixed;
                }
            }
        }
    }

    return null;
}

function extractAdvisoryUrl(osv: OsvVulnerability): string {
    if (osv.references) {
        for (const ref of osv.references) {
            if (ref.type === 'ADVISORY' || ref.type === 'WEB') {
                return ref.url;
            }
        }
        if (osv.references.length > 0) {
            return osv.references[0].url;
        }
    }

    if (osv.id.startsWith('GHSA-')) {
        return `https://github.com/advisories/${osv.id}`;
    }
    return `https://osv.dev/vulnerability/${osv.id}`;
}
