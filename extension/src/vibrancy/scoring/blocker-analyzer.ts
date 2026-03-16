import {
    PubOutdatedEntry, DepEdge, VibrancyResult,
    BlockerInfo, UpgradeBlockStatus,
} from '../types';
import { compareVersions } from '../services/changelog-service';

/**
 * Classify upgrade status for a single pub outdated entry.
 * - up-to-date: current == latest
 * - upgradable: current < upgradable (can upgrade freely)
 * - blocked: resolvable < latest (something constrains it)
 * - constrained: upgradable < resolvable (your own constraint limits it)
 */
export function classifyUpgradeStatus(
    entry: PubOutdatedEntry,
): UpgradeBlockStatus {
    if (!entry.current || !entry.latest) { return 'up-to-date'; }
    if (compareVersions(entry.current, entry.latest) === 'up-to-date') {
        return 'up-to-date';
    }
    if (entry.resolvable && entry.latest
        && compareVersions(entry.resolvable, entry.latest) !== 'up-to-date') {
        return 'blocked';
    }
    if (entry.upgradable && entry.resolvable
        && compareVersions(entry.upgradable, entry.resolvable) !== 'up-to-date') {
        return 'constrained';
    }
    return 'upgradable';
}

/**
 * Find which packages block upgrades for blocked packages.
 *
 * For each package where resolvable < latest, walks the reverse dependency
 * graph to find which direct dependency is the likely blocker. Enriches
 * with the blocker's vibrancy score and category from scan results.
 */
export function findBlockers(
    outdated: readonly PubOutdatedEntry[],
    reverseDeps: ReadonlyMap<string, readonly DepEdge[]>,
    results: readonly VibrancyResult[],
    directDeps: ReadonlySet<string>,
): BlockerInfo[] {
    const resultMap = new Map(results.map(r => [r.package.name, r]));
    const blockers: BlockerInfo[] = [];

    for (const entry of outdated) {
        if (classifyUpgradeStatus(entry) !== 'blocked') { continue; }
        const blocker = findBlockerForPackage(
            entry, reverseDeps, resultMap, directDeps,
        );
        if (blocker) { blockers.push(blocker); }
    }

    return blockers;
}

function findBlockerForPackage(
    entry: PubOutdatedEntry,
    reverseDeps: ReadonlyMap<string, readonly DepEdge[]>,
    resultMap: ReadonlyMap<string, VibrancyResult>,
    directDeps: ReadonlySet<string>,
): BlockerInfo | null {
    const edges = reverseDeps.get(entry.package);
    if (!edges || edges.length === 0) { return null; }

    // Prefer direct dependencies as the reported blocker
    const directBlocker = edges.find(
        e => directDeps.has(e.dependentPackage),
    );
    const blockerName = directBlocker
        ? directBlocker.dependentPackage
        : edges[0].dependentPackage;

    const blockerResult = resultMap.get(blockerName);
    return {
        blockedPackage: entry.package,
        currentVersion: entry.current ?? '',
        latestVersion: entry.latest ?? '',
        blockerPackage: blockerName,
        blockerVibrancyScore: blockerResult?.score ?? null,
        blockerCategory: blockerResult?.category ?? null,
    };
}
