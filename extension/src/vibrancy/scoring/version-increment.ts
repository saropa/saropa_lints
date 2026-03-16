import * as semver from 'semver';
import { VibrancyResult } from '../types';

/** The type of version increment between two versions. */
export type VersionIncrement = 'major' | 'minor' | 'patch' | 'prerelease' | 'none';

/** Filter type for bulk update operations. */
export type IncrementFilter = 'all' | 'major' | 'minor' | 'patch';

/**
 * Classify the increment type between two semver versions.
 * Returns 'none' if versions are equal or cannot be parsed.
 */
export function classifyIncrement(from: string, to: string): VersionIncrement {
    const fromParsed = semver.parse(from);
    const toParsed = semver.parse(to);

    if (!fromParsed || !toParsed) {
        return 'none';
    }

    if (semver.eq(fromParsed, toParsed)) {
        return 'none';
    }

    if (!semver.gt(toParsed, fromParsed)) {
        return 'none';
    }

    if (toParsed.major > fromParsed.major) {
        return 'major';
    }

    if (toParsed.minor > fromParsed.minor) {
        return 'minor';
    }

    if (toParsed.patch > fromParsed.patch) {
        return 'patch';
    }

    if (toParsed.prerelease.length > 0 || fromParsed.prerelease.length > 0) {
        return 'prerelease';
    }

    return 'none';
}

/**
 * Check if an increment type passes a filter.
 * - 'all': Include all increment types
 * - 'major': Only major increments
 * - 'minor': Minor or major increments
 * - 'patch': Only patch increments
 */
export function incrementMatchesFilter(
    increment: VersionIncrement,
    filter: IncrementFilter,
): boolean {
    if (increment === 'none') {
        return false;
    }

    switch (filter) {
        case 'all':
            return true;
        case 'major':
            return increment === 'major';
        case 'minor':
            return increment === 'minor' || increment === 'major';
        case 'patch':
            return increment === 'patch';
    }
}

/**
 * Filter vibrancy results by increment type.
 * Only includes packages that:
 * - Have update info with a different latest version
 * - Match the specified increment filter
 */
export function filterByIncrement(
    packages: readonly VibrancyResult[],
    filter: IncrementFilter,
): VibrancyResult[] {
    return packages.filter(pkg => {
        const updateInfo = pkg.updateInfo;
        if (!updateInfo) {
            return false;
        }

        if (updateInfo.updateStatus === 'up-to-date') {
            return false;
        }

        const increment = classifyIncrement(
            updateInfo.currentVersion,
            updateInfo.latestVersion,
        );

        return incrementMatchesFilter(increment, filter);
    });
}

/** Format version increment for display. */
export function formatIncrement(increment: VersionIncrement): string {
    switch (increment) {
        case 'major':
            return 'major';
        case 'minor':
            return 'minor';
        case 'patch':
            return 'patch';
        case 'prerelease':
            return 'prerelease';
        case 'none':
            return 'up-to-date';
    }
}
