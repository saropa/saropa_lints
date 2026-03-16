"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.analyzePackage = analyzePackage;
const pub_dev_api_1 = require("./services/pub-dev-api");
const bloat_calculator_1 = require("./scoring/bloat-calculator");
const drift_calculator_1 = require("./scoring/drift-calculator");
const github_api_1 = require("./services/github-api");
const changelog_service_1 = require("./services/changelog-service");
const known_issues_1 = require("./scoring/known-issues");
const vibrancy_calculator_1 = require("./scoring/vibrancy-calculator");
const status_classifier_1 = require("./scoring/status-classifier");
const pub_dev_search_1 = require("./services/pub-dev-search");
/** Analyze a single package and compute its vibrancy result. */
async function analyzePackage(dep, params) {
    const log = params.logger;
    const knownIssue = (0, known_issues_1.findKnownIssue)(dep.name, dep.version);
    if (knownIssue) {
        log?.info(`Known issue: ${knownIssue.status}`);
    }
    const [pubDevResult, metrics, publisher] = await Promise.all([
        (0, pub_dev_api_1.fetchPackageInfoWithPrerelease)(dep.name, params.cache, log),
        (0, pub_dev_api_1.fetchPackageMetrics)(dep.name, params.cache, log),
        (0, pub_dev_api_1.fetchPublisher)(dep.name, params.cache, log),
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
    const category = (0, status_classifier_1.classifyStatus)({
        score: scores.score, knownIssue, pubDev: pubDevWithPoints,
        isArchived: github?.isArchived,
    });
    log?.score({
        name: dep.name, total: scores.score, category,
        rv: scores.resolutionVelocity, eg: scores.engagementLevel,
        pop: scores.popularity, pt: scores.publisherTrust,
    });
    const [updateInfo, archiveSizeBytes] = await Promise.all([
        pubDev
            ? (0, changelog_service_1.buildUpdateInfo)({ current: dep.version, latest: pubDev.latestVersion, constraint: dep.constraint }, repoInfo, {
                token: params.githubToken, cache: params.cache,
                packageName: dep.name,
            })
            : null,
        resolveArchiveSize(dep.name, knownIssue, params),
    ]);
    const bloatRating = archiveSizeBytes !== null
        ? (0, bloat_calculator_1.calcBloatRating)(archiveSizeBytes) : null;
    const drift = (0, drift_calculator_1.calcDrift)(pubDev?.publishedDate ?? null, params.flutterReleases ?? []);
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
function resolveRepoUrl(name, pubDevUrl, params) {
    return params.repoOverrides?.[name] ?? pubDevUrl ?? null;
}
async function fetchGitHubData(repoUrl, params) {
    if (!repoUrl) {
        return { github: null, repoInfo: null };
    }
    const parsed = (0, github_api_1.extractGitHubRepo)(repoUrl);
    if (!parsed) {
        return { github: null, repoInfo: null };
    }
    const repoInfo = { ...parsed, subpath: (0, changelog_service_1.extractRepoSubpath)(repoUrl) };
    const github = await (0, github_api_1.fetchRepoMetrics)(parsed.owner, parsed.repo, {
        token: params.githubToken, cache: params.cache,
        logger: params.logger,
    });
    return { github, repoInfo };
}
async function resolveArchiveSize(name, knownIssue, params) {
    const live = await (0, pub_dev_api_1.fetchArchiveSize)(name, params.cache, params.logger);
    if (live !== null) {
        return live;
    }
    return knownIssue?.archiveSizeBytes ?? null;
}
function mergeMetrics(live, ki, publisher) {
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
function logDataGaps(name, live, ki, log) {
    if (!ki || !log) {
        return;
    }
    if (ki.platforms?.length && live.platforms.length === 0) {
        log.info(`${name}: platforms missing from API, using known issue`);
    }
    if (ki.pubPoints !== undefined && live.pubPoints === 0) {
        log.info(`${name}: pubPoints missing from API, known issue has ${ki.pubPoints}`);
    }
}
function daysSince(isoDate) {
    const ms = Date.parse(isoDate);
    if (isNaN(ms)) {
        return undefined;
    }
    return Math.max(0, Math.floor((Date.now() - ms) / 86_400_000));
}
const ALTERNATIVES_SCORE_THRESHOLD = 40;
async function resolveAlternatives(params) {
    // Only use curated replacement when it's a package name; use explicit version field
    // so we never suggest "Update to v9+" when already on v9+.
    const curatedOnlyIfPackage = params.curatedReplacement && (0, known_issues_1.isReplacementPackageName)(params.curatedReplacement)
        ? (0, known_issues_1.getReplacementDisplayText)(params.curatedReplacement, params.currentVersion, params.replacementObsoleteFromVersion)
        : undefined;
    if (curatedOnlyIfPackage) {
        return (0, pub_dev_search_1.buildAlternatives)(curatedOnlyIfPackage, []);
    }
    if (params.score >= ALTERNATIVES_SCORE_THRESHOLD) {
        return [];
    }
    if (params.topics.length === 0) {
        return [];
    }
    const exclude = [params.packageName, ...params.existingPackages];
    const discovery = await (0, pub_dev_search_1.searchAlternatives)(params.topics, exclude, params.cache, params.logger);
    return (0, pub_dev_search_1.buildAlternatives)(undefined, discovery);
}
function computeScores(params) {
    const { github, pubPoints, publishedDate, publisher } = params;
    const daysSincePublish = publishedDate
        ? daysSince(publishedDate) : undefined;
    // Resolution from GitHub (issues/PRs) or, when 0, from publish recency on same 0–100 scale.
    const resolutionVelocity = (0, vibrancy_calculator_1.effectiveResolutionVelocity)(github, daysSincePublish);
    // When GitHub data is unavailable, use publish recency as engagement proxy.
    // Halve it to match calcEngagementLevel's (commentScore + recency) / 2 formula.
    const engagementLevel = github
        ? (0, vibrancy_calculator_1.calcEngagementLevel)(github, daysSincePublish)
        : daysSincePublish !== undefined
            ? (0, vibrancy_calculator_1.calcPublishRecency)(daysSincePublish) / 2
            : 0;
    const popularity = (0, vibrancy_calculator_1.calcPopularity)(pubPoints, github?.stars ?? 0);
    const publisherTrust = (0, vibrancy_calculator_1.calcPublisherTrust)(publisher, params.maxPublisherBonus);
    const flaggedPenalty = github
        ? (0, vibrancy_calculator_1.calcFlaggedIssuePenalty)(github.flaggedIssues?.length ?? 0) : 0;
    const score = (0, vibrancy_calculator_1.computeVibrancyScore)({ resolutionVelocity, engagementLevel, popularity }, params.weights, flaggedPenalty, publisherTrust);
    return {
        score, resolutionVelocity, engagementLevel,
        popularity, publisherTrust,
    };
}
//# sourceMappingURL=scan-orchestrator.js.map