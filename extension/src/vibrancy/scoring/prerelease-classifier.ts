import * as semver from 'semver';

/** Check if a version string contains a prerelease suffix. */
export function isPrerelease(version: string): boolean {
    const parsed = semver.parse(version);
    if (!parsed) { return false; }
    return parsed.prerelease.length > 0;
}

/** Extract the prerelease tag from a version (e.g., 'dev', 'beta', 'rc'). */
export function getPrereleaseTag(version: string): string | null {
    const parsed = semver.parse(version);
    if (!parsed || parsed.prerelease.length === 0) { return null; }

    const first = parsed.prerelease[0];
    if (typeof first === 'string') {
        return first.toLowerCase();
    }
    return null;
}

/** Find the latest prerelease version from a list of versions. */
export function findLatestPrerelease(versions: string[]): string | null {
    const prereleases = versions.filter(isPrerelease);
    if (prereleases.length === 0) { return null; }

    return prereleases.reduce((latest, current) => {
        if (!latest) { return current; }
        return semver.gt(current, latest) ? current : latest;
    }, prereleases[0]);
}

/** Find the latest stable version from a list of versions. */
export function findLatestStable(versions: string[]): string | null {
    const stable = versions.filter(v => !isPrerelease(v));
    if (stable.length === 0) { return null; }

    return stable.reduce((latest, current) => {
        if (!latest) { return current; }
        return semver.gt(current, latest) ? current : latest;
    }, stable[0]);
}

/** Filter prerelease versions by allowed tags. */
export function filterByTags(versions: string[], tags: string[]): string[] {
    if (tags.length === 0) { return versions; }
    const lowerTags = new Set(tags.map(t => t.toLowerCase()));
    return versions.filter(v => {
        const tag = getPrereleaseTag(v);
        return tag !== null && lowerTags.has(tag);
    });
}

/**
 * Check if a prerelease is newer than the latest stable.
 * Returns true only if the prerelease version is strictly greater.
 */
export function isPrereleaseNewerThanStable(
    prereleaseVersion: string,
    stableVersion: string,
): boolean {
    return semver.gt(prereleaseVersion, stableVersion);
}

/** Classify prerelease maturity based on tag. */
export type PrereleaseTier = 'alpha' | 'dev' | 'beta' | 'rc' | 'other';

/** Get the maturity tier of a prerelease tag. */
export function getPrereleaseTier(tag: string | null): PrereleaseTier {
    if (!tag) { return 'other'; }
    const lower = tag.toLowerCase();
    if (lower === 'alpha') { return 'alpha'; }
    if (lower === 'dev') { return 'dev'; }
    if (lower === 'beta') { return 'beta'; }
    if (lower === 'rc' || lower.startsWith('rc')) { return 'rc'; }
    if (lower.includes('nullsafety')) { return 'beta'; }
    return 'other';
}

/** Format a prerelease tag for display. */
export function formatPrereleaseTag(tag: string | null): string {
    if (!tag) { return 'prerelease'; }
    const tier = getPrereleaseTier(tag);
    switch (tier) {
        case 'alpha': return 'Alpha';
        case 'dev': return 'Dev';
        case 'beta': return 'Beta';
        case 'rc': return 'RC';
        default: return tag;
    }
}

/** Extract prerelease info from a version list. */
export interface PrereleaseInfo {
    readonly latestStable: string | null;
    readonly latestPrerelease: string | null;
    readonly prereleaseTag: string | null;
    readonly hasNewerPrerelease: boolean;
}

export function extractPrereleaseInfo(versions: string[]): PrereleaseInfo {
    const validVersions = versions.filter(v => semver.valid(v));
    const latestStable = findLatestStable(validVersions);
    const latestPrerelease = findLatestPrerelease(validVersions);

    const prereleaseTag = latestPrerelease
        ? getPrereleaseTag(latestPrerelease) : null;

    const hasNewerPrerelease = latestStable && latestPrerelease
        ? isPrereleaseNewerThanStable(latestPrerelease, latestStable)
        : latestPrerelease !== null && latestStable === null;

    return {
        latestStable,
        latestPrerelease: hasNewerPrerelease ? latestPrerelease : null,
        prereleaseTag: hasNewerPrerelease ? prereleaseTag : null,
        hasNewerPrerelease,
    };
}
