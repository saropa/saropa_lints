import { CacheService } from './cache-service';
import { ScanLogger } from './scan-logger';
import { fetchWithRetry } from './fetch-retry';
import { buildHeaders } from './github-api';
import { VersionGapItem, VersionGapResult } from '../types';

/** GitHub REST API v3 base URL. */
const GITHUB_API = 'https://api.github.com';

/** Maximum items to return in a version-gap result. */
const MAX_GAP_ITEMS = 100;

/** Maximum items per API page. */
const PER_PAGE = 100;

interface FetchParams {
    readonly token?: string;
    readonly cache?: CacheService;
    readonly logger?: ScanLogger;
    /** Package name for monorepo tag lookup (e.g., "firebase_core"). */
    readonly packageName?: string;
}

/**
 * Fetch the published date for a specific version from GitHub releases or tags.
 * Tries multiple tag naming conventions for compatibility with monorepos.
 */
export async function fetchVersionDate(
    owner: string,
    repo: string,
    version: string,
    params?: FetchParams,
): Promise<string | null> {
    const cacheKey = `gh.release.date.${owner}.${repo}.${version}`;
    const cached = params?.cache?.get<string>(cacheKey);
    if (cached) { return cached; }

    const headers = buildHeaders(params?.token);

    // Try multiple tag formats: v1.0.0, 1.0.0, package-v1.0.0, package_v1.0.0
    const tagCandidates = buildTagCandidates(version, params?.packageName);

    for (const tag of tagCandidates) {
        const date = await tryReleaseTag(owner, repo, tag, headers, params?.logger);
        if (date) {
            // Version dates never change — cache without TTL concern
            await params?.cache?.set(cacheKey, date);
            return date;
        }
    }

    // Fallback: search releases list for a matching tag_name
    const date = await searchReleasesList(
        owner, repo, version, params?.packageName, headers, params?.logger,
    );
    if (date) {
        await params?.cache?.set(cacheKey, date);
    }
    return date;
}

/**
 * Fetch PRs and issues between two version dates.
 * Returns items sorted by closed/merged date descending.
 */
export async function fetchVersionGap(
    owner: string,
    repo: string,
    currentVersion: string,
    latestVersion: string,
    params?: FetchParams,
): Promise<VersionGapResult> {
    const packageName = params?.packageName ?? repo;

    // Check cache first
    const cacheKey = `gh.gap.${owner}.${repo}.${currentVersion}.${latestVersion}`;
    const cached = params?.cache?.get<VersionGapResult>(cacheKey);
    if (cached) {
        params?.logger?.cacheHit(cacheKey);
        return cached;
    }

    // Step 1: Get dates for both versions
    const [fromDate, toDate] = await Promise.all([
        fetchVersionDate(owner, repo, currentVersion, params),
        fetchVersionDate(owner, repo, latestVersion, params),
    ]);

    if (!fromDate || !toDate) {
        // Can't determine date range — return empty result
        const empty: VersionGapResult = {
            packageName,
            currentVersion,
            latestVersion,
            owner,
            repo,
            items: [],
            truncated: false,
            fromDate,
            toDate,
        };
        return empty;
    }

    // Step 2: Fetch merged PRs and closed issues in parallel
    const headers = buildHeaders(params?.token);
    const [prs, issues] = await Promise.all([
        fetchMergedPRs(owner, repo, fromDate, toDate, headers, params?.logger),
        fetchClosedIssues(owner, repo, fromDate, toDate, headers, params?.logger),
    ]);

    // Step 3: Combine, deduplicate, sort by date, truncate
    const combined = [...prs, ...issues];
    combined.sort((a, b) => {
        const dateA = a.closedAt ?? a.createdAt;
        const dateB = b.closedAt ?? b.createdAt;
        // Descending: newest first
        return dateB.localeCompare(dateA);
    });

    const truncated = combined.length > MAX_GAP_ITEMS;
    const items = combined.slice(0, MAX_GAP_ITEMS);

    const result: VersionGapResult = {
        packageName,
        currentVersion,
        latestVersion,
        owner,
        repo,
        items,
        truncated,
        fromDate,
        toDate,
    };

    await params?.cache?.set(cacheKey, result);
    return result;
}

// ---------------------------------------------------------------------------
// Internal helpers
// ---------------------------------------------------------------------------

/** Build tag name candidates for a version. */
function buildTagCandidates(
    version: string,
    packageName?: string,
): readonly string[] {
    const candidates = [`v${version}`, version];
    if (packageName) {
        // Monorepo conventions: firebase_core-v1.0.0, firebase_core_v1.0.0
        candidates.push(`${packageName}-v${version}`);
        candidates.push(`${packageName}_v${version}`);
    }
    return candidates;
}

/** Try to get a release date from a specific tag. */
async function tryReleaseTag(
    owner: string,
    repo: string,
    tag: string,
    headers: Record<string, string>,
    logger?: ScanLogger,
): Promise<string | null> {
    const url = `${GITHUB_API}/repos/${owner}/${repo}/releases/tags/${encodeURIComponent(tag)}`;
    const resp = await fetchWithRetry(url, { headers }, logger);
    if (!resp.ok) { return null; }

    const data = await resp.json() as { published_at?: string; created_at?: string };
    return data.published_at ?? data.created_at ?? null;
}

/** Search releases list for a tag matching the version. */
async function searchReleasesList(
    owner: string,
    repo: string,
    version: string,
    packageName: string | undefined,
    headers: Record<string, string>,
    logger?: ScanLogger,
): Promise<string | null> {
    // Fetch first 100 releases (most repos have fewer)
    const url = `${GITHUB_API}/repos/${owner}/${repo}/releases?per_page=${PER_PAGE}`;
    const resp = await fetchWithRetry(url, { headers }, logger);
    if (!resp.ok) { return null; }

    const releases = await resp.json() as readonly {
        tag_name: string;
        published_at?: string;
        created_at?: string;
    }[];

    const candidates = buildTagCandidates(version, packageName);
    const match = releases.find(r =>
        candidates.some(c => r.tag_name === c),
    );

    return match?.published_at ?? match?.created_at ?? null;
}

/** Fetch merged PRs in a date range. */
async function fetchMergedPRs(
    owner: string,
    repo: string,
    fromDate: string,
    toDate: string,
    headers: Record<string, string>,
    logger?: ScanLogger,
): Promise<VersionGapItem[]> {
    // Fetch closed PRs sorted by updated date, filter by merged_at in range
    const url = `${GITHUB_API}/repos/${owner}/${repo}/pulls`
        + `?state=closed&sort=updated&direction=desc&per_page=${PER_PAGE}`;

    const resp = await fetchWithRetry(url, { headers }, logger);
    if (!resp.ok) { return []; }

    const pulls = await resp.json() as readonly GitHubPR[];

    return pulls
        .filter(pr =>
            pr.merged_at
            && pr.merged_at > fromDate
            && pr.merged_at <= toDate,
        )
        .map(pr => ({
            number: pr.number,
            title: pr.title,
            url: pr.html_url,
            type: 'pr' as const,
            state: 'merged' as const,
            author: pr.user?.login ?? 'unknown',
            createdAt: pr.created_at,
            closedAt: pr.merged_at,
            labels: (pr.labels ?? []).map(l => l.name),
        }));
}

/** Fetch closed issues (excluding PRs) in a date range. */
async function fetchClosedIssues(
    owner: string,
    repo: string,
    fromDate: string,
    toDate: string,
    headers: Record<string, string>,
    logger?: ScanLogger,
): Promise<VersionGapItem[]> {
    // GitHub's issues endpoint includes PRs — filter them out via pull_request field
    const url = `${GITHUB_API}/repos/${owner}/${repo}/issues`
        + `?state=closed&since=${fromDate}&per_page=${PER_PAGE}&sort=updated&direction=desc`;

    const resp = await fetchWithRetry(url, { headers }, logger);
    if (!resp.ok) { return []; }

    const issues = await resp.json() as readonly GitHubIssue[];

    return issues
        .filter(issue =>
            // Exclude PRs (GitHub returns PRs in the issues endpoint)
            !issue.pull_request
            && issue.closed_at
            && issue.closed_at > fromDate
            && issue.closed_at <= toDate,
        )
        .map(issue => ({
            number: issue.number,
            title: issue.title,
            url: issue.html_url,
            type: 'issue' as const,
            state: 'closed' as const,
            author: issue.user?.login ?? 'unknown',
            createdAt: issue.created_at,
            closedAt: issue.closed_at,
            labels: (issue.labels ?? []).map(l =>
                typeof l === 'string' ? l : l.name,
            ),
        }));
}

// ---------------------------------------------------------------------------
// GitHub API response types (subset of fields we use)
// ---------------------------------------------------------------------------

interface GitHubPR {
    readonly number: number;
    readonly title: string;
    readonly html_url: string;
    readonly created_at: string;
    readonly merged_at: string | null;
    readonly user?: { readonly login: string };
    readonly labels?: readonly { readonly name: string }[];
}

interface GitHubIssue {
    readonly number: number;
    readonly title: string;
    readonly html_url: string;
    readonly created_at: string;
    readonly closed_at: string | null;
    readonly user?: { readonly login: string };
    readonly pull_request?: unknown;
    readonly labels?: readonly (string | { readonly name: string })[];
}
