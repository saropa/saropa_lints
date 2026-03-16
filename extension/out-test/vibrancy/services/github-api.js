"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.extractGitHubRepo = extractGitHubRepo;
exports.fetchRepoMetrics = fetchRepoMetrics;
const issue_signals_1 = require("../scoring/issue-signals");
const fetch_retry_1 = require("./fetch-retry");
/** GitHub REST API v3 base URL. */
const GITHUB_API = 'https://api.github.com';
/** Window for "recent" activity — issues/PRs closed within this period count. */
const NINETY_DAYS_MS = 90 * 24 * 60 * 60 * 1000;
/** Milliseconds in one day, used for recency calculations. */
const ONE_DAY_MS = 24 * 60 * 60 * 1000;
/** Sentinel value when no issue/PR has ever been closed in the repo. */
const NO_CLOSE_DAYS = 999;
/** Extract owner/repo from a GitHub URL. */
function extractGitHubRepo(repoUrl) {
    const match = repoUrl.match(/github\.com\/([^/]+)\/([^/.\s#]+)/);
    if (!match) {
        return null;
    }
    return { owner: match[1], repo: match[2] };
}
function buildHeaders(token) {
    const headers = {
        'Accept': 'application/vnd.github.v3+json',
        'User-Agent': 'saropa-package-vibrancy',
    };
    if (token) {
        headers['Authorization'] = `token ${token}`;
    }
    return headers;
}
/** Fetch GitHub metrics for a repository. */
async function fetchRepoMetrics(owner, repo, params) {
    const log = params?.logger;
    const cacheKey = `gh.${owner}.${repo}`;
    const cached = params?.cache?.get(cacheKey);
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
            (0, fetch_retry_1.fetchWithRetry)(repoUrl, { headers }, log),
            (0, fetch_retry_1.fetchWithRetry)(issuesUrl, { headers }, log),
            (0, fetch_retry_1.fetchWithRetry)(pullsUrl, { headers }, log),
            (0, fetch_retry_1.fetchWithRetry)(openUrl, { headers }, log),
            (0, fetch_retry_1.fetchWithRetry)(openPrsUrl, { headers }, log),
        ]);
        const elapsed = Date.now() - t0;
        logResponses(log, [repoResp, issuesResp, pullsResp, openResp, openPrsResp], elapsed);
        if (!repoResp.ok) {
            return null;
        }
        const repoData = await repoResp.json();
        const rawIssues = issuesResp.ok
            ? await issuesResp.json() : [];
        const pulls = pullsResp.ok
            ? await pullsResp.json() : [];
        const rawOpen = openResp.ok
            ? await openResp.json() : [];
        // Open PRs fetch is optional — graceful fallback if it fails
        const openPrCount = openPrsResp.ok
            ? (await openPrsResp.json()).length : undefined;
        const filterPrs = (i) => !i.pull_request;
        const issues = rawIssues.filter(filterPrs);
        const openIssues = rawOpen.filter(filterPrs);
        const htmlUrl = repoData.html_url ?? `https://github.com/${owner}/${repo}`;
        const flagged = (0, issue_signals_1.flagHighSignalIssues)(openIssues, htmlUrl);
        const metrics = buildMetrics({ repoData, closedIssues: issues, pulls, flagged, openPrCount }, now);
        await params?.cache?.set(cacheKey, metrics);
        return metrics;
    }
    catch {
        log?.error(`Failed to fetch GitHub metrics for ${owner}/${repo}`);
        return null;
    }
}
function logResponses(log, responses, elapsed) {
    for (const r of responses) {
        log?.apiResponse(r.status, r.statusText, elapsed);
    }
}
function buildMetrics(raw, now) {
    const cutoff = now - NINETY_DAYS_MS;
    const closedRecent = raw.closedIssues.filter((i) => i.closed_at && new Date(i.closed_at).getTime() > cutoff);
    const mergedRecent = raw.pulls.filter((p) => p.merged_at && new Date(p.merged_at).getTime() > cutoff);
    const totalComments = raw.closedIssues.reduce((sum, i) => sum + (i.comments ?? 0), 0);
    const avgComments = raw.closedIssues.length > 0
        ? totalComments / raw.closedIssues.length : 0;
    const lastClose = closedRecent.length > 0
        ? Math.max(...closedRecent.map((i) => new Date(i.closed_at).getTime()))
        : 0;
    const daysSinceClose = lastClose > 0
        ? Math.floor((now - lastClose) / ONE_DAY_MS) : NO_CLOSE_DAYS;
    const updatedAt = new Date(raw.repoData.updated_at ?? 0).getTime();
    const daysSinceUpdate = Math.floor((now - updatedAt) / ONE_DAY_MS);
    // pushed_at = last commit timestamp (available from existing /repos response)
    const pushedAt = raw.repoData.pushed_at
        ? new Date(raw.repoData.pushed_at).getTime() : 0;
    const daysSinceCommit = pushedAt > 0
        ? Math.max(0, Math.floor((now - pushedAt) / ONE_DAY_MS))
        : undefined;
    const combinedOpen = raw.repoData.open_issues_count ?? 0;
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
//# sourceMappingURL=github-api.js.map