/** * Module overview (comment coverage pass). * comment-coverage: module overview (batch). * * Vibrancy UI experiment: scoring, providers, and webview assets. */// Single scan pass: pub.dev, GitHub, issues, scores, and problem suggestions per package.
import {
    VibrancyResult, PackageDependency, GitHubMetrics, KnownIssue,
    PubDevMetrics, AlternativeSuggestion,
} from './types';
import { CacheService } from './services/cache-service';
import { ScanLogger } from './services/scan-logger';
import {
    fetchPackageInfoWithPrerelease, fetchPackageMetrics, fetchPublisher,
    fetchArchiveSize, fetchReverseDependencyCount, resolveArchiveUrl,
} from './services/pub-dev-api';
import { analyzeTarball, TarballAnalysis } from './services/tarball-analyzer';
import { calcBloatRating } from './scoring/bloat-calculator';
import { extractGitHubRepo, fetchRepoMetrics } from './services/github-api';
import { extractRepoSubpath, buildUpdateInfo } from './services/changelog-service';
import { findKnownIssue, isReplacementPackageName, getReplacementDisplayText } from './scoring/known-issues';
import {
    effectiveResolutionVelocity,
    calcEngagementLevel,
    calcPopularity,
    calcFlaggedIssuePenalty,
    calcPublisherTrust,
    calcPubQualityBonus,
    calcAdoptionBonus,
    calcMaintainerQualityBonus,
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
    readonly existingPackages?: readonly string[];
}

function normalizeVersionKey(version: string): string {
    const trimmed = version.trim();
    const noPrefix = trimmed.replace(/^[vV]/, '');
    const plusIdx = noPrefix.indexOf('+');
    return plusIdx >= 0 ? noPrefix.slice(0, plusIdx) : noPrefix;
}

/**
 * Resolve publish date for the installed version with fallbacks for
 * common lockfile/version-map mismatches.
 */
export function resolveInstalledVersionDate(
    installedVersion: string,
    versionDates: Readonly<Record<string, string>>,
    latestVersion?: string | null,
    latestPublishedDate?: string | null,
): string | null {
    const direct = versionDates[installedVersion];
    if (direct) { return direct; }

    const normalizedInstalled = normalizeVersionKey(installedVersion);
    if (!normalizedInstalled) { return null; }

    for (const [version, date] of Object.entries(versionDates)) {
        if (normalizeVersionKey(version) === normalizedInstalled) {
            return date;
        }
    }

    if (latestVersion && latestPublishedDate) {
        const normalizedLatest = normalizeVersionKey(latestVersion);
        if (normalizedInstalled === normalizedLatest) {
            return latestPublishedDate;
        }
    }

    return null;
}

/** Analyze a single package and compute its vibrancy result. */
export async function analyzePackage(
    dep: PackageDependency,
    params: AnalyzeParams,
): Promise<VibrancyResult> {
    const log = params.logger;
    const knownIssue = findKnownIssue(dep.name, dep.version);
    if (knownIssue) { log?.info(`Known issue: ${knownIssue.status}`); }

    const [pubDevResult, metrics, publisher, reverseDependencyCount] = await Promise.all([
        fetchPackageInfoWithPrerelease(dep.name, params.cache, log),
        fetchPackageMetrics(dep.name, params.cache, log),
        fetchPublisher(dep.name, params.cache, log),
        fetchReverseDependencyCount(dep.name, params.cache, log),
    ]);
    const pubDev = pubDevResult.info;
    const prereleaseInfo = pubDevResult.prerelease;
    const installedVersionDate = resolveInstalledVersionDate(
        dep.version,
        pubDevResult.versionDates,
        pubDev?.latestVersion ?? null,
        pubDev?.publishedDate ?? null,
    );

    const repoUrl = resolveRepoUrl(dep.name, pubDev?.repositoryUrl, params);
    const { github, repoInfo } = await fetchGitHubData(repoUrl, params);
    const daysSincePublish = pubDev?.publishedDate
        ? daysSince(pubDev.publishedDate)
        : undefined;

    /* Run tarball analysis + updateInfo + archive-size fallback in parallel.
       The tarball analysis is the source of truth for codeSizeBytes,
       folderBreakdown, and maintainerQuality flags. It can return null on
       slow networks or oversized tarballs — in that case we still have
       archiveSizeBytes as a coarse fallback so the hover doesn't go blank. */
    const [updateInfo, archiveSizeBytes, tarballAnalysis] = await Promise.all([
        pubDev
            ? buildUpdateInfo(
                { current: dep.version, latest: pubDev.latestVersion, constraint: dep.constraint },
                repoInfo, {
                    token: params.githubToken, cache: params.cache,
                    packageName: dep.name,
                },
            )
            : null,
        resolveArchiveSize(dep.name, dep.version, knownIssue, params),
        resolveTarballAnalysis(dep.name, params),
    ]);

    const codeSizeBytes = tarballAnalysis?.codeSizeBytes ?? null;
    const folderBreakdown = tarballAnalysis?.folderBreakdown ?? null;
    const maintainerQuality = tarballAnalysis?.maintainerQuality ?? null;
    const maintainerQualityBonus = calcMaintainerQualityBonus(maintainerQuality);

    /* Bloat rating runs on codeSizeBytes when available — that's what the
       package actually contributes to the user's app. Falls back to
       archiveSizeBytes only when the tarball analysis couldn't run, and
       even then the recalibrated thresholds keep ratings sane for the
       common case (`lib/`-only packages where the two are similar). */
    const bloatSourceBytes = codeSizeBytes ?? archiveSizeBytes;
    const bloatRating = bloatSourceBytes !== null
        ? calcBloatRating(bloatSourceBytes) : null;

    const pubPoints = metrics.pubPoints;
    const scores = computeScores({
        github, pubPoints, publishedDate: pubDev?.publishedDate ?? null,
        publisher, weights: params.weights,
        maxPublisherBonus: params.publisherTrustBonus,
        reverseDependencyCount,
        maintainerQualityBonus,
    });
    const pubDevWithPoints = pubDev
        ? { ...pubDev, pubPoints, publisher } : null;
    const category = classifyStatus({
        score: scores.score, knownIssue, pubDev: pubDevWithPoints,
        isArchived: github?.isArchived,
        daysSinceLastCommit: github?.daysSinceLastCommit,
        daysSinceLastPublish: daysSincePublish,
    });

    log?.score({
        name: dep.name, total: scores.score, category,
        rv: scores.resolutionVelocity, eg: scores.engagementLevel,
        pop: scores.popularity, pt: scores.publisherTrust,
        pq: scores.pubQualityBonus,
    });

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
        archiveSizeBytes,
        codeSizeBytes,
        folderBreakdown,
        maintainerQuality,
        maintainerQualityBonus,
        bloatRating, installedVersionDate, isUnused: false, fileUsages: [],
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
        versionGap: null,
        overrideGap: null,
        replacementComplexity: null,
        likes: metrics.likes,
        downloadCount30Days: metrics.downloadCount30Days,
        reverseDependencyCount,
        readme: null, // Lazy-loaded when detail panel opens
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
    installedVersion: string,
    knownIssue: KnownIssue | null,
    params: AnalyzeParams,
): Promise<number | null> {
    const live = await fetchArchiveSize(name, params.cache, params.logger);
    if (live !== null) { return live; }
    /* Version-gate the known-issues fallback: a seed value from an old
       version is not safe to surface on a newer one. findKnownIssue
       already filters by range when it returns a scoped entry, but an
       unscoped entry (or future additions) could leak stale numbers if
       we trusted them unconditionally. Belt-and-braces:
         - If the entry has appliesToMaxVersion and the installed version
           is at or past that ceiling, the size data is stale → return null.
         - Otherwise the data applies → use it.
       Without this, a project on audioplayers 6.5.1 could inherit the
       1.0-era 20.05 MB seed if the live HEAD fetch fails. */
    if (!knownIssue?.archiveSizeBytes) { return null; }
    const cap = knownIssue.appliesToMaxVersion;
    if (cap && versionGteForGate(installedVersion, cap)) { return null; }
    return knownIssue.archiveSizeBytes;
}

/** Segment-wise numeric version compare, mirrors known-issues.ts.versionGte. */
function versionGteForGate(a: string, b: string): boolean {
    const parse = (v: string): number[] => v.trim().replace(/[-+].*$/, '').split('.')
        .map(s => { const n = parseInt(s, 10); return Number.isNaN(n) ? 0 : n; });
    const pa = parse(a);
    const pb = parse(b);
    const len = Math.max(pa.length, pb.length);
    for (let i = 0; i < len; i++) {
        const va = pa[i] ?? 0;
        const vb = pb[i] ?? 0;
        if (va !== vb) { return va > vb; }
    }
    return true;
}

/**
 * Download + analyze the package tarball to produce codeSize, folder
 * breakdown, and maintainer-quality flags. Returns null on any failure so
 * the scan continues — the caller treats null as "data unavailable", not
 * "package has zero code size".
 */
async function resolveTarballAnalysis(
    name: string,
    params: AnalyzeParams,
): Promise<TarballAnalysis | null> {
    const url = await resolveArchiveUrl(name, params.cache, params.logger);
    if (!url) { return null; }
    return analyzeTarball(url, params.cache, params.logger);
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
    readonly reverseDependencyCount: number | null;
    readonly maintainerQualityBonus: number;
}) {
    const { github, pubPoints, publishedDate, publisher } = params;
    const daysSincePublish = publishedDate
        ? daysSince(publishedDate) : undefined;
    // Resolution from GitHub (issues/PRs) or, when 0, from publish recency on same 0–100 scale.
    const resolutionVelocity = effectiveResolutionVelocity(github, daysSincePublish);
    // When GitHub data is unavailable, use publish recency as engagement proxy.
    // Halve it to match calcEngagementLevel's (commentScore + recency) / 2 formula.
    const engagementLevel = github
        ? calcEngagementLevel(
            github,
            daysSincePublish,
            github.daysSinceLastCommit,
        )
        : daysSincePublish !== undefined
            ? calcPublishRecency(daysSincePublish) / 2
            : 0;
    const popularity = calcPopularity(pubPoints, github?.stars ?? 0);
    const publisherTrust = calcPublisherTrust(
        publisher, params.maxPublisherBonus,
    );

    const pubQualityBonus = calcPubQualityBonus(pubPoints);
    // Adoption bonus: reward packages that other published packages depend on.
    // Bonus-only — 0 dependents means 0 bonus, not a penalty.
    const adoptionBonus = calcAdoptionBonus(params.reverseDependencyCount);
    const flaggedPenalty = github
        ? calcFlaggedIssuePenalty(github.flaggedIssues?.length ?? 0) : 0;
    const score = computeVibrancyScore(
        { resolutionVelocity, engagementLevel, popularity }, params.weights,
        flaggedPenalty,
        publisherTrust + pubQualityBonus + adoptionBonus + params.maintainerQualityBonus,
    );
    return {
        score, resolutionVelocity, engagementLevel,
        popularity, publisherTrust, pubQualityBonus,
    };
}
