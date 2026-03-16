import { FlaggedIssue, GitHubMetrics } from '../types';
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

function buildHeaders(token?: string): Record<string, string> {
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
