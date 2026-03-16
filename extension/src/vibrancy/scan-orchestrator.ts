import {
    VibrancyResult, PackageDependency, GitHubMetrics, KnownIssue,
    PubDevMetrics, AlternativeSuggestion,
} from './types';
import { CacheService } from './services/cache-service';
import { ScanLogger } from './services/scan-logger';
import {
    fetchPackageInfoWithPrerelease, fetchPackageMetrics, fetchPublisher,
    fetchArchiveSize,
} from './services/pub-dev-api';
import { calcBloatRating } from './scoring/bloat-calculator';
import { calcDrift } from './scoring/drift-calculator';
import { FlutterRelease } from './services/flutter-releases';
import { extractGitHubRepo, fetchRepoMetrics } from './services/github-api';
import { extractRepoSubpath, buildUpdateInfo } from './services/changelog-service';
import { findKnownIssue, isReplacementPackageName, getReplacementDisplayText } from './scoring/known-issues';
import {
    effectiveResolutionVelocity,
    calcEngagementLevel,
    calcPopularity,
    calcFlaggedIssuePenalty,
    calcPublisherTrust,
    calcPublishRecency,
    computeVibrancyScore,
    ScoringWeights,
} from './scoring/vibrancy-calculator';
import { classifyStatus } from './scoring/status-classifier';
import { searchAlternatives, buildAlternatives } from './services/pub-dev-search';

interface RepoInfo {
    readonly owner: string;
    readonly repo: string;
    readonly subpath: string | null;
}

interface AnalyzeParams {
    readonly cache: CacheService;
    readonly logger?: ScanLogger;
    readonly githubToken?: string;
    readonly weights?: ScoringWeights;
    readonly repoOverrides?: Record<string, string>;
    readonly publisherTrustBonus?: number;
    readonly flutterReleases?: readonly FlutterRelease[];
    readonly existingPackages?: readonly string[];
}

/** Analyze a single package and compute its vibrancy result. */
export async function analyzePackage(
    dep: PackageDependency,
    params: AnalyzeParams,
): Promise<VibrancyResult> {
    const log = params.logger;
    const knownIssue = findKnownIssue(dep.name, dep.version);
    if (knownIssue) { log?.info(`Known issue: ${knownIssue.status}`); }

    const [pubDevResult, metrics, publisher] = await Promise.all([
        fetchPackageInfoWithPrerelease(dep.name, params.cache, log),
        fetchPackageMetrics(dep.name, params.cache, log),
        fetchPublisher(dep.name, params.cache, log),
    ]);
    const pubDev = pubDevResult.info;
    const prereleaseInfo = pubDevResult.prerelease;

    const repoUrl = resolveRepoUrl(dep.name, pubDev?.repositoryUrl, params);
    const { github, repoInfo } = await fetchGitHubData(repoUrl, params);

    const pubPoints = metrics.pubPoints;
    const scores = computeScores({
        github, pubPoints, publishedDate: pubDev?.publishedDate ?? null,
        publisher, weights: params.weights,
        maxPublisherBonus: params.publisherTrustBonus,
    });
    const pubDevWithPoints = pubDev
        ? { ...pubDev, pubPoints, publisher } : null;
    const category = classifyStatus({
        score: scores.score, knownIssue, pubDev: pubDevWithPoints,
    });

    log?.score({
        name: dep.name, total: scores.score, category,
        rv: scores.resolutionVelocity, eg: scores.engagementLevel,
        pop: scores.popularity, pt: scores.publisherTrust,
    });

    const [updateInfo, archiveSizeBytes] = await Promise.all([
        pubDev
            ? buildUpdateInfo(
                { current: dep.version, latest: pubDev.latestVersion, constraint: dep.constraint },
                repoInfo, {
                    token: params.githubToken, cache: params.cache,
                    packageName: dep.name,
                },
            )
            : null,
        resolveArchiveSize(dep.name, knownIssue, params),
    ]);
    const bloatRating = archiveSizeBytes !== null
        ? calcBloatRating(archiveSizeBytes) : null;

    const drift = calcDrift(
        pubDev?.publishedDate ?? null, params.flutterReleases ?? [],
    );

    const merged = mergeMetrics(metrics, knownIssue, publisher);
    logDataGaps(dep.name, metrics, knownIssue, log);

    const alternatives = await resolveAlternatives({
        score: scores.score,
        topics: pubDev?.topics ?? [],
        curatedReplacement: knownIssue?.replacement,
        replacementObsoleteFromVersion: knownIssue?.replacementObsoleteFromVersion,
        currentVersion: dep.version,
        packageName: dep.name,
        existingPackages: params.existingPackages ?? [],
        cache: params.cache,
        logger: log,
    });

    return {
        package: dep, pubDev: pubDevWithPoints, github, knownIssue,
        ...scores, category, updateInfo,
        license: pubDevWithPoints?.license ?? github?.license ?? knownIssue?.license ?? null,
        drift, archiveSizeBytes, bloatRating, isUnused: false,
        platforms: merged.platforms,
        verifiedPublisher: merged.verifiedPublisher,
        wasmReady: merged.wasmReady,
        blocker: null,
        upgradeBlockStatus: 'up-to-date',
        transitiveInfo: null,
        alternatives,
        latestPrerelease: prereleaseInfo?.latestPrerelease ?? null,
        prereleaseTag: prereleaseInfo?.prereleaseTag ?? null,
        vulnerabilities: [],
    };
}

function resolveRepoUrl(
    name: string,
    pubDevUrl: string | null | undefined,
    params: AnalyzeParams,
): string | null {
    return params.repoOverrides?.[name] ?? pubDevUrl ?? null;
}

async function fetchGitHubData(
    repoUrl: string | null,
    params: AnalyzeParams,
): Promise<{ github: GitHubMetrics | null; repoInfo: RepoInfo | null }> {
    if (!repoUrl) { return { github: null, repoInfo: null }; }

    const parsed = extractGitHubRepo(repoUrl);
    if (!parsed) { return { github: null, repoInfo: null }; }

    const repoInfo = { ...parsed, subpath: extractRepoSubpath(repoUrl) };
    const github = await fetchRepoMetrics(parsed.owner, parsed.repo, {
        token: params.githubToken, cache: params.cache,
        logger: params.logger,
    });
    return { github, repoInfo };
}

async function resolveArchiveSize(
    name: string,
    knownIssue: KnownIssue | null,
    params: AnalyzeParams,
): Promise<number | null> {
    const live = await fetchArchiveSize(name, params.cache, params.logger);
    if (live !== null) { return live; }
    return knownIssue?.archiveSizeBytes ?? null;
}

function mergeMetrics(
    live: PubDevMetrics,
    ki: KnownIssue | null,
    publisher: string | null,
): { platforms: readonly string[] | null; verifiedPublisher: boolean; wasmReady: boolean | null } {
    const platforms = live.platforms.length > 0
        ? live.platforms
        : ki?.platforms ?? null;
    const verifiedPublisher = publisher !== null
        || (ki?.verifiedPublisher ?? false);
    const wasmReady = live.wasmReady !== null
        ? live.wasmReady
        : ki?.wasmReady ?? null;
    return { platforms, verifiedPublisher, wasmReady };
}

function logDataGaps(
    name: string,
    live: PubDevMetrics,
    ki: KnownIssue | null,
    log?: ScanLogger,
): void {
    if (!ki || !log) { return; }
    if (ki.platforms?.length && live.platforms.length === 0) {
        log.info(`${name}: platforms missing from API, using known issue`);
    }
    if (ki.pubPoints !== undefined && live.pubPoints === 0) {
        log.info(`${name}: pubPoints missing from API, known issue has ${ki.pubPoints}`);
    }
}

function daysSince(isoDate: string): number | undefined {
    const ms = Date.parse(isoDate);
    if (isNaN(ms)) { return undefined; }
    return Math.max(0, Math.floor((Date.now() - ms) / 86_400_000));
}

const ALTERNATIVES_SCORE_THRESHOLD = 40;

async function resolveAlternatives(params: {
    readonly score: number;
    readonly topics: readonly string[];
    readonly curatedReplacement: string | undefined;
    readonly replacementObsoleteFromVersion?: string;
    readonly currentVersion: string | undefined;
    readonly packageName: string;
    readonly existingPackages: readonly string[];
    readonly cache: CacheService;
    readonly logger?: ScanLogger;
}): Promise<readonly AlternativeSuggestion[]> {
    // Only use curated replacement when it's a package name; use explicit version field
    // so we never suggest "Update to v9+" when already on v9+.
    const curatedOnlyIfPackage = params.curatedReplacement && isReplacementPackageName(params.curatedReplacement)
        ? getReplacementDisplayText(
            params.curatedReplacement,
            params.currentVersion,
            params.replacementObsoleteFromVersion,
        )
        : undefined;
    if (curatedOnlyIfPackage) {
        return buildAlternatives(curatedOnlyIfPackage, []);
    }

    if (params.score >= ALTERNATIVES_SCORE_THRESHOLD) {
        return [];
    }

    if (params.topics.length === 0) {
        return [];
    }

    const exclude = [params.packageName, ...params.existingPackages];
    const discovery = await searchAlternatives(
        params.topics, exclude, params.cache, params.logger,
    );

    return buildAlternatives(undefined, discovery);
}

function computeScores(params: {
    readonly github: GitHubMetrics | null;
    readonly pubPoints: number;
    readonly publishedDate: string | null;
    readonly publisher: string | null;
    readonly weights?: ScoringWeights;
    readonly maxPublisherBonus?: number;
}) {
    const { github, pubPoints, publishedDate, publisher } = params;
    const daysSincePublish = publishedDate
        ? daysSince(publishedDate) : undefined;
    // Resolution from GitHub (issues/PRs) or, when 0, from publish recency on same 0–100 scale.
    const resolutionVelocity = effectiveResolutionVelocity(github, daysSincePublish);
    // When GitHub data is unavailable, use publish recency as engagement proxy.
    // Halve it to match calcEngagementLevel's (commentScore + recency) / 2 formula.
    const engagementLevel = github
        ? calcEngagementLevel(github, daysSincePublish)
        : daysSincePublish !== undefined
            ? calcPublishRecency(daysSincePublish) / 2
            : 0;
    const popularity = calcPopularity(pubPoints, github?.stars ?? 0);
    const publisherTrust = calcPublisherTrust(
        publisher, params.maxPublisherBonus,
    );

    const flaggedPenalty = github
        ? calcFlaggedIssuePenalty(github.flaggedIssues?.length ?? 0) : 0;
    const score = computeVibrancyScore(
        { resolutionVelocity, engagementLevel, popularity }, params.weights,
        flaggedPenalty, publisherTrust,
    );
    return {
        score, resolutionVelocity, engagementLevel,
        popularity, publisherTrust,
    };
}
