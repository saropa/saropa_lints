import { FlaggedIssue, GitHubMetrics, ReadmeData } from '../types';
import { flagHighSignalIssues } from '../scoring/issue-signals';
import { CacheService } from './cache-service';
import { ScanLogger } from './scan-logger';
import { fetchWithRetry } from './fetch-retry';

/** GitHub REST API v3 base URL. */
const GITHUB_API = 'https://api.github.com';

/** Window for "recent" activity — issues/PRs closed within this period count. */
const NINETY_DAYS_MS = 90 * 24 * 60 * 60 * 1000;

/** Milliseconds in one day, used for recency calculations. */
const ONE_DAY_MS = 24 * 60 * 60 * 1000;

/** Sentinel value when no issue/PR has ever been closed in the repo. */
const NO_CLOSE_DAYS = 999;

/** Extract owner/repo from a GitHub URL. */
export function extractGitHubRepo(
    repoUrl: string,
): { owner: string; repo: string } | null {
    const match = repoUrl.match(
        /github\.com\/([^/]+)\/([^/.\s#]+)/,
    );
    if (!match) { return null; }
    return { owner: match[1], repo: match[2] };
}

/** Build GitHub API request headers with optional auth token. */
export function buildHeaders(token?: string): Record<string, string> {
    const headers: Record<string, string> = {
        'Accept': 'application/vnd.github.v3+json',
        'User-Agent': 'saropa-package-vibrancy',
    };
    if (token) {
        headers['Authorization'] = `token ${token}`;
    }
    return headers;
}

/** Fetch GitHub metrics for a repository. */
export async function fetchRepoMetrics(
    owner: string,
    repo: string,
    params?: { token?: string; cache?: CacheService; logger?: ScanLogger },
): Promise<GitHubMetrics | null> {
    const log = params?.logger;
    const cacheKey = `gh.${owner}.${repo}`;
    const cached = params?.cache?.get<GitHubMetrics>(cacheKey);
    if (cached) {
        log?.cacheHit(cacheKey);
        return cached;
    }
    log?.cacheMiss(cacheKey);

    try {
        const headers = buildHeaders(params?.token);
        const now = Date.now();
        const cutoff = new Date(now - NINETY_DAYS_MS).toISOString();
        const repoUrl = `${GITHUB_API}/repos/${owner}/${repo}`;
        const issuesUrl = `${repoUrl}/issues?state=closed&since=${cutoff}&per_page=100`;
        const pullsUrl = `${repoUrl}/pulls?state=closed&per_page=100`;
        const openUrl = `${repoUrl}/issues?state=open&sort=comments&direction=desc&per_page=50`;
        // per_page=100 is the GitHub API max; repos with 100+ open PRs report a floor of 100
        const openPrsUrl = `${repoUrl}/pulls?state=open&per_page=100`;

        log?.apiRequest('GET', repoUrl);
        log?.apiRequest('GET', issuesUrl);
        log?.apiRequest('GET', pullsUrl);
        log?.apiRequest('GET', openUrl);
        log?.apiRequest('GET', openPrsUrl);
        const t0 = Date.now();

        const [repoResp, issuesResp, pullsResp, openResp, openPrsResp] = await Promise.all([
            fetchWithRetry(repoUrl, { headers }, log),
            fetchWithRetry(issuesUrl, { headers }, log),
            fetchWithRetry(pullsUrl, { headers }, log),
            fetchWithRetry(openUrl, { headers }, log),
            fetchWithRetry(openPrsUrl, { headers }, log),
        ]);
        const elapsed = Date.now() - t0;
        logResponses(log, [repoResp, issuesResp, pullsResp, openResp, openPrsResp], elapsed);

        if (!repoResp.ok) { return null; }

        const repoData: any = await repoResp.json();
        const rawIssues: any[] = issuesResp.ok
            ? await issuesResp.json() as any[] : [];
        const pulls: any[] = pullsResp.ok
            ? await pullsResp.json() as any[] : [];
        const rawOpen: any[] = openResp.ok
            ? await openResp.json() as any[] : [];
        // Open PRs fetch is optional — graceful fallback if it fails
        const openPrCount: number | undefined = openPrsResp.ok
            ? (await openPrsResp.json() as any[]).length : undefined;

        const filterPrs = (i: any) => !i.pull_request;
        const issues = rawIssues.filter(filterPrs);
        const openIssues = rawOpen.filter(filterPrs);

        const htmlUrl = repoData.html_url ?? `https://github.com/${owner}/${repo}`;
        const flagged = flagHighSignalIssues(openIssues, htmlUrl);
        const metrics = buildMetrics(
            { repoData, closedIssues: issues, pulls, flagged, openPrCount }, now,
        );
        await params?.cache?.set(cacheKey, metrics);
        return metrics;
    } catch {
        log?.error(`Failed to fetch GitHub metrics for ${owner}/${repo}`);
        return null;
    }
}

function logResponses(
    log: ScanLogger | undefined,
    responses: Response[],
    elapsed: number,
): void {
    for (const r of responses) {
        log?.apiResponse(r.status, r.statusText, elapsed);
    }
}

interface RawRepoData {
    readonly repoData: any;
    readonly closedIssues: any[];
    readonly pulls: any[];
    readonly flagged: FlaggedIssue[];
    /** Open PR count from the /pulls?state=open call, undefined if that call failed. */
    readonly openPrCount: number | undefined;
}

function buildMetrics(raw: RawRepoData, now: number): GitHubMetrics {
    const cutoff = now - NINETY_DAYS_MS;

    const closedRecent = raw.closedIssues.filter(
        (i: any) => i.closed_at && new Date(i.closed_at).getTime() > cutoff,
    );
    const mergedRecent = raw.pulls.filter(
        (p: any) => p.merged_at && new Date(p.merged_at).getTime() > cutoff,
    );

    const totalComments = raw.closedIssues.reduce(
        (sum: number, i: any) => sum + (i.comments ?? 0), 0,
    );
    const avgComments = raw.closedIssues.length > 0
        ? totalComments / raw.closedIssues.length : 0;

    const lastClose = closedRecent.length > 0
        ? Math.max(...closedRecent.map(
            (i: any) => new Date(i.closed_at).getTime(),
        ))
        : 0;

    const daysSinceClose = lastClose > 0
        ? Math.floor((now - lastClose) / ONE_DAY_MS) : NO_CLOSE_DAYS;

    const updatedAt = new Date(raw.repoData.updated_at ?? 0).getTime();
    const daysSinceUpdate = Math.floor(
        (now - updatedAt) / ONE_DAY_MS,
    );

    // pushed_at = last commit timestamp (available from existing /repos response)
    const pushedAt = raw.repoData.pushed_at
        ? new Date(raw.repoData.pushed_at).getTime() : 0;
    const daysSinceCommit = pushedAt > 0
        ? Math.max(0, Math.floor((now - pushedAt) / ONE_DAY_MS))
        : undefined;

    const combinedOpen: number = raw.repoData.open_issues_count ?? 0;
    // Separate true issues from PRs when open PR count is available
    const trueOpenIssues = raw.openPrCount !== undefined
        ? Math.max(0, combinedOpen - raw.openPrCount) : undefined;

    return {
        stars: raw.repoData.stargazers_count ?? 0,
        openIssues: combinedOpen,
        trueOpenIssues,
        openPullRequests: raw.openPrCount,
        closedIssuesLast90d: closedRecent.length,
        mergedPrsLast90d: mergedRecent.length,
        avgCommentsPerIssue: Math.round(avgComments * 10) / 10,
        daysSinceLastUpdate: Math.max(0, daysSinceUpdate),
        daysSinceLastClose: daysSinceClose,
        daysSinceLastCommit: daysSinceCommit,
        // Only set when the API confirms archived; omit for non-archived repos so the
        // optional type accurately represents "unknown" vs "confirmed archived".
        isArchived: raw.repoData.archived === true ? true : undefined,
        repoUrl: raw.repoData.html_url ?? undefined,
        flaggedIssues: raw.flagged,
        license: raw.repoData.license?.spdx_id ?? null,
    };
}

// ---------------------------------------------------------------------------
// README image extraction
// ---------------------------------------------------------------------------

/** Known badge/CI image domains to filter out of README images. */
const BADGE_PATTERNS = [
    'shields.io',
    'img.shields.io',
    'travis-ci.org',
    'travis-ci.com',
    'codecov.io',
    'coveralls.io',
    'badge.svg',        // Common badge filename
    '/badge.png',
    '/badge?',          // Badge API query URLs
    '/workflows/',      // GitHub Actions badge paths
    'github.com/actions/',
    'pub.dev/static/',  // pub.dev static assets (badges)
];

/**
 * Fetch the repository README from GitHub and extract image URLs.
 * Returns logo (first non-badge image before first ## heading) and all
 * non-badge images found in the markdown (max 5).
 */
export async function fetchReadmeImages(
    owner: string,
    repo: string,
    params?: { token?: string; cache?: CacheService; logger?: ScanLogger },
): Promise<ReadmeData | null> {
    const log = params?.logger;
    const cacheKey = `gh.readme.${owner}.${repo}`;
    const cached = params?.cache?.get<ReadmeData>(cacheKey);
    if (cached) {
        log?.cacheHit(cacheKey);
        return cached;
    }
    log?.cacheMiss(cacheKey);

    const url = `${GITHUB_API}/repos/${owner}/${repo}/readme`;
    const headers = buildHeaders(params?.token);

    try {
        log?.apiRequest('GET', url);
        const t0 = Date.now();
        const resp = await fetchWithRetry(url, { headers }, log);
        log?.apiResponse(resp.status, resp.statusText, Date.now() - t0);
        if (!resp.ok) { return null; }

        const json: any = await resp.json();
        if (json.encoding !== 'base64' || !json.content) { return null; }

        // Decode base64 README content
        const markdown = Buffer.from(json.content, 'base64').toString('utf-8');
        const result = parseMarkdownImages(markdown, owner, repo);

        await params?.cache?.set(cacheKey, result);
        return result;
    } catch {
        log?.error(`Failed to fetch README for ${owner}/${repo}`);
        return null;
    }
}

/**
 * Parse a markdown string for image URLs, filtering out badges and CI images.
 * Returns the logo (first non-badge image before any ## heading) and up to 5
 * non-badge images total.
 */
export function parseMarkdownImages(
    markdown: string,
    owner: string,
    repo: string,
): ReadmeData {
    const rawBaseUrl = `https://raw.githubusercontent.com/${owner}/${repo}/HEAD/`;
    const allUrls: string[] = [];

    // Match markdown images: ![alt](url) — supports balanced parentheses in URLs
    // (e.g. https://example.com/image(1).png) and ignores trailing title text
    const mdImageRegex = /!\[[^\]]*\]\(((?:[^()\s]|\([^)]*\))+)\)/g;
    let match: RegExpExecArray | null;
    while ((match = mdImageRegex.exec(markdown)) !== null) {
        allUrls.push(match[1].trim());
    }

    // Match HTML images: <img src="url">
    const htmlImageRegex = /<img[^>]+src=["']([^"']+)["']/gi;
    while ((match = htmlImageRegex.exec(markdown)) !== null) {
        allUrls.push(match[1].trim());
    }

    // Resolve relative URLs to absolute, filter out badges, and drop
    // http:// images — they would be silently blocked by the webview CSP
    // (which only allows img-src https:) resulting in empty placeholders.
    const resolved = allUrls
        .map(url => resolveImageUrl(url, rawBaseUrl))
        .filter(url => !isBadgeImage(url) && !url.startsWith('http://'));

    // Deduplicate while preserving order
    const seen = new Set<string>();
    const unique: string[] = [];
    for (const url of resolved) {
        if (!seen.has(url)) {
            seen.add(url);
            unique.push(url);
        }
    }

    // Logo: first non-badge image that appears before the first ## heading
    const firstHeadingIdx = markdown.search(/^##\s/m);
    const preHeading = firstHeadingIdx >= 0
        ? markdown.substring(0, firstHeadingIdx)
        : markdown;
    let logoUrl: string | null = null;

    // Check markdown images in the pre-heading section
    const preImageRegex = /!\[[^\]]*\]\(((?:[^()\s]|\([^)]*\))+)\)/g;
    while ((match = preImageRegex.exec(preHeading)) !== null) {
        const url = resolveImageUrl(match[1].trim(), rawBaseUrl);
        if (!isBadgeImage(url)) {
            logoUrl = url;
            break;
        }
    }

    // If no markdown image found, check HTML images in pre-heading section
    if (!logoUrl) {
        const preHtmlRegex = /<img[^>]+src=["']([^"']+)["']/gi;
        while ((match = preHtmlRegex.exec(preHeading)) !== null) {
            const url = resolveImageUrl(match[1].trim(), rawBaseUrl);
            if (!isBadgeImage(url)) {
                logoUrl = url;
                break;
            }
        }
    }

    return {
        logoUrl,
        imageUrls: unique.slice(0, 5),
    };
}

/**
 * Resolve a potentially relative URL against the raw GitHub content base.
 * Handles ./ and ../ prefixes by collapsing path segments so URLs like
 * ../assets/logo.png resolve correctly against the base URL.
 */
function resolveImageUrl(url: string, rawBaseUrl: string): string {
    if (url.startsWith('http://') || url.startsWith('https://')) {
        return url;
    }
    // Use URL constructor to properly resolve relative paths (collapses ../)
    try {
        return new URL(url, rawBaseUrl).href;
    } catch {
        // Fallback: strip leading ./ and concatenate directly
        const cleaned = url.startsWith('./') ? url.substring(2) : url;
        return rawBaseUrl + cleaned;
    }
}

/** Check if an image URL looks like a CI badge or status indicator. */
function isBadgeImage(url: string): boolean {
    const lower = url.toLowerCase();
    return BADGE_PATTERNS.some(p => lower.includes(p));
}
