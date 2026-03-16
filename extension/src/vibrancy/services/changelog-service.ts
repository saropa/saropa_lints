import { UpdateStatus, UpdateInfo, ChangelogInfo, ChangelogEntry } from '../types';
import { CacheService } from './cache-service';
import { fetchWithRetry } from './fetch-retry';
import { fetchPubDevChangelog } from './pubdev-changelog';

const GITHUB_API = 'https://api.github.com';
const MAX_CHANGELOG_SIZE = 500_000;
const MAX_ENTRIES = 20;

interface SemverParts {
    readonly major: number;
    readonly minor: number;
    readonly patch: number;
}

/** Parse a semver string like "1.2.3". Ignores pre-release/build metadata. */
function parseSemver(version: string): SemverParts | null {
    const match = version.match(/^(\d+)\.(\d+)\.(\d+)/);
    if (!match) { return null; }
    return {
        major: parseInt(match[1], 10),
        minor: parseInt(match[2], 10),
        patch: parseInt(match[3], 10),
    };
}

function isGreaterThan(a: SemverParts, b: SemverParts): boolean {
    if (a.major !== b.major) { return a.major > b.major; }
    if (a.minor !== b.minor) { return a.minor > b.minor; }
    return a.patch > b.patch;
}

function isGreaterOrEqual(a: SemverParts, b: SemverParts): boolean {
    return !isGreaterThan(b, a);
}

/** Check if a Dart pub version constraint allows the given version. */
export function constraintAllowsVersion(
    constraint: string,
    version: string,
): boolean {
    if (constraint === 'any') { return true; }
    const v = parseSemver(version);
    if (!v) { return false; }

    const caretMatch = constraint.match(/^\^(\d+\.\d+\.\d+)/);
    if (caretMatch) {
        return caretAllows(parseSemver(caretMatch[1])!, v);
    }
    return false;
}

function caretAllows(base: SemverParts, target: SemverParts): boolean {
    if (!isGreaterOrEqual(target, base)) { return false; }
    if (base.major > 0) {
        return target.major === base.major;
    }
    if (base.minor > 0) {
        return target.major === 0 && target.minor === base.minor;
    }
    return target.major === 0 && target.minor === 0
        && target.patch === base.patch;
}

/** Compare two semver strings and return the update status. */
export function compareVersions(
    current: string,
    latest: string,
): UpdateStatus {
    const c = parseSemver(current);
    const l = parseSemver(latest);
    if (!c || !l) { return 'unknown'; }

    if (!isGreaterThan(l, c)) { return 'up-to-date'; }
    if (l.major > c.major) { return 'major'; }
    if (l.minor > c.minor) { return 'minor'; }
    return 'patch';
}

/**
 * Extract the package subpath from a monorepo GitHub URL.
 * e.g., "https://github.com/firebase/flutterfire/tree/master/packages/firebase_core"
 * returns "packages/firebase_core".
 * Returns null for non-monorepo URLs.
 */
export function extractRepoSubpath(repoUrl: string): string | null {
    const match = repoUrl.match(
        /github\.com\/[^/]+\/[^/]+\/tree\/[^/]+\/(.+)/,
    );
    if (!match) { return null; }
    return match[1].replace(/\/$/, '');
}

/**
 * Fetch CHANGELOG.md content from a GitHub repository.
 * For monorepo packages, tries the subpath first, then falls back to root.
 */
export async function fetchChangelog(
    owner: string,
    repo: string,
    params?: {
        subpath?: string | null;
        token?: string;
        cache?: CacheService;
    },
): Promise<string | null> {
    const subpath = params?.subpath;
    const cacheKey = `changelog.${owner}.${repo}.${subpath ?? 'root'}`;
    const cached = params?.cache?.get<string>(cacheKey);
    if (cached !== null && cached !== undefined) { return cached; }

    const headers: Record<string, string> = {
        'Accept': 'application/vnd.github.v3.raw',
        'User-Agent': 'saropa-package-vibrancy',
    };
    if (params?.token) {
        headers['Authorization'] = `token ${params.token}`;
    }

    const paths = subpath
        ? [`${subpath}/CHANGELOG.md`, 'CHANGELOG.md']
        : ['CHANGELOG.md'];

    for (const filePath of paths) {
        try {
            const url = `${GITHUB_API}/repos/${owner}/${repo}/contents/${filePath}`;
            const resp = await fetchWithRetry(url, { headers });
            if (!resp.ok) { continue; }

            let text = await resp.text();
            if (text.length > MAX_CHANGELOG_SIZE) {
                text = text.substring(0, MAX_CHANGELOG_SIZE);
            }

            await params?.cache?.set(cacheKey, text);
            return text;
        } catch {
            continue;
        }
    }

    return null;
}

/** Parse all version entries from a CHANGELOG.md string. */
function parseAllEntries(content: string): ChangelogEntry[] {
    const entries: ChangelogEntry[] = [];
    const headerPattern = /^##\s+\[?v?(\d+\.\d+\.\d+[^\]]*)\]?(?:\s*[-–]\s*(.+))?$/;

    const lines = content.replace(/\r\n/g, '\n').split('\n');
    let current: { version: string; date?: string; bodyLines: string[] } | null = null;

    for (const line of lines) {
        const match = line.match(headerPattern);
        if (match) {
            if (current) {
                entries.push({
                    version: current.version,
                    date: current.date,
                    body: current.bodyLines.join('\n').trim(),
                });
            }
            const versionRaw = match[1].trim();
            const versionClean = versionRaw.match(/^(\d+\.\d+\.\d+)/)?.[1] ?? versionRaw;
            current = {
                version: versionClean,
                date: match[2]?.trim(),
                bodyLines: [],
            };
        } else if (current) {
            current.bodyLines.push(line);
        }
    }

    if (current) {
        entries.push({
            version: current.version,
            date: current.date,
            body: current.bodyLines.join('\n').trim(),
        });
    }

    return entries;
}

/**
 * Parse CHANGELOG.md content and extract entries between two versions.
 * Returns entries newer than currentVersion and up to latestVersion.
 */
export function parseChangelog(
    content: string,
    currentVersion: string,
    latestVersion: string,
): ChangelogInfo {
    const allEntries = parseAllEntries(content);

    if (allEntries.length === 0) {
        return {
            entries: [], truncated: false,
            unavailableReason: 'No version entries found in CHANGELOG.md',
        };
    }

    const currentParsed = parseSemver(currentVersion);
    const latestParsed = parseSemver(latestVersion);

    if (!currentParsed || !latestParsed) {
        return {
            entries: [], truncated: false,
            unavailableReason: 'Could not parse version numbers',
        };
    }

    const relevant = allEntries.filter(entry => {
        const entryParsed = parseSemver(entry.version);
        if (!entryParsed) { return false; }
        return isGreaterThan(entryParsed, currentParsed)
            && !isGreaterThan(entryParsed, latestParsed);
    });

    const truncated = relevant.length > MAX_ENTRIES;
    const entries = relevant.slice(0, MAX_ENTRIES);

    return { entries, truncated };
}

/** Build complete UpdateInfo for a package. */
export async function buildUpdateInfo(
    versions: { current: string; latest: string; constraint: string },
    repoInfo: { owner: string; repo: string; subpath: string | null } | null,
    params?: { token?: string; cache?: CacheService; packageName?: string },
): Promise<UpdateInfo> {
    const { current: currentVersion, latest: latestVersion, constraint } = versions;
    const constraintCovers = constraintAllowsVersion(constraint, latestVersion);
    const updateStatus = constraintCovers
        ? 'up-to-date' as UpdateStatus
        : compareVersions(currentVersion, latestVersion);

    if (updateStatus === 'up-to-date') {
        return { currentVersion, latestVersion, updateStatus, changelog: null };
    }

    const content = await fetchChangelogWithFallback(
        repoInfo, params?.packageName, params,
    );

    const changelog = content
        ? parseChangelog(content, currentVersion, latestVersion)
        : {
            entries: [] as ChangelogEntry[], truncated: false,
            unavailableReason: 'Changelog not found',
        };

    return { currentVersion, latestVersion, updateStatus, changelog };
}

async function fetchChangelogWithFallback(
    repoInfo: { owner: string; repo: string; subpath: string | null } | null,
    packageName: string | undefined,
    params?: { token?: string; cache?: CacheService },
): Promise<string | null> {
    // Try GitHub API first
    if (repoInfo) {
        const ghContent = await fetchChangelog(repoInfo.owner, repoInfo.repo, {
            subpath: repoInfo.subpath,
            token: params?.token,
            cache: params?.cache,
        });
        if (ghContent) { return ghContent; }
    }

    // Fallback to pub.dev HTML scrape
    if (packageName) {
        return fetchPubDevChangelog(packageName, params?.cache);
    }

    return null;
}
