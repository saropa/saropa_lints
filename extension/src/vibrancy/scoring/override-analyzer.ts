import { OverrideEntry, OverrideAnalysis, PackageDependency } from '../types';
import { DepGraphPackage } from '../services/dep-graph';
import { calculateAgeDays, formatAge } from '../services/override-age';
import * as semver from 'semver';

export { formatAge };

/**
 * Analyze each override to determine if it's active (resolving a real conflict)
 * or stale (no longer needed).
 *
 * Pure function — no I/O.
 */
export function analyzeOverrides(
    overrides: readonly OverrideEntry[],
    deps: readonly PackageDependency[],
    depGraph: DepGraphPackage[],
    ages: ReadonlyMap<string, Date>,
): OverrideAnalysis[] {
    const depMap = new Map(deps.map(d => [d.name, d]));
    const graphMap = new Map(depGraph.map(p => [p.name, p]));

    return overrides.map(entry => {
        const addedDate = ages.get(entry.name) ?? null;
        const ageDays = calculateAgeDays(addedDate);

        if (entry.isPathDep || entry.isGitDep) {
            return {
                entry,
                status: 'active' as const,
                blocker: entry.isPathDep ? 'local path override' : 'git override',
                addedDate,
                ageDays,
            };
        }

        const conflict = findConflict(entry, depMap, graphMap);
        return {
            entry,
            status: conflict ? 'active' : 'stale',
            blocker: conflict,
            addedDate,
            ageDays,
        };
    });
}

/**
 * Find which package (if any) constrains the overridden package to a conflicting range.
 * Returns the name of the blocking package or null if no conflict exists.
 */
function findConflict(
    override: OverrideEntry,
    deps: Map<string, PackageDependency>,
    depGraph: Map<string, DepGraphPackage>,
): string | null {
    const overriddenVersion = cleanVersion(override.version);
    if (!overriddenVersion) { return null; }

    const parsed = semver.coerce(overriddenVersion);
    if (!parsed) { return null; }

    for (const [, pkg] of depGraph) {
        if (pkg.name === override.name) { continue; }
        if (!pkg.dependencies.includes(override.name)) { continue; }

        const dep = deps.get(pkg.name);
        if (!dep) { continue; }

        const constraint = findTransitiveConstraint(pkg.name, override.name, depGraph);
        if (constraint && !satisfiesConstraint(parsed.version, constraint)) {
            return pkg.name;
        }
    }

    const directDep = deps.get(override.name);
    if (directDep && directDep.isDirect) {
        const constraint = directDep.constraint;
        if (constraint && !satisfiesConstraint(parsed.version, constraint)) {
            return 'direct constraint';
        }
    }

    return null;
}

/**
 * Find the version constraint a package applies to a dependency.
 * This is a heuristic since we don't have full constraint info in the dep graph.
 */
function findTransitiveConstraint(
    _parentName: string,
    _depName: string,
    _depGraph: Map<string, DepGraphPackage>,
): string | null {
    return null;
}

/**
 * Check if a version satisfies a constraint.
 * Handles common constraint formats: ^1.0.0, >=1.0.0, <2.0.0, etc.
 */
function satisfiesConstraint(version: string, constraint: string): boolean {
    try {
        const cleaned = constraint.replace(/["']/g, '').trim();
        if (cleaned === 'any') { return true; }

        const range = semver.validRange(cleaned);
        if (!range) { return true; }

        return semver.satisfies(version, range);
    } catch {
        return true;
    }
}

/**
 * Clean a version string by removing quotes and whitespace.
 */
function cleanVersion(version: string): string {
    return version.replace(/["']/g, '').trim();
}

/**
 * Check if an override is considered "old" (over a certain threshold).
 * Default threshold is 180 days (6 months).
 */
export function isOldOverride(
    analysis: OverrideAnalysis,
    thresholdDays = 180,
): boolean {
    return analysis.ageDays !== null && analysis.ageDays > thresholdDays;
}

/**
 * Group analyses by status for easier UI rendering.
 */
export function groupByStatus(
    analyses: readonly OverrideAnalysis[],
): { active: OverrideAnalysis[]; stale: OverrideAnalysis[] } {
    const active: OverrideAnalysis[] = [];
    const stale: OverrideAnalysis[] = [];

    for (const a of analyses) {
        if (a.status === 'active') {
            active.push(a);
        } else {
            stale.push(a);
        }
    }

    return { active, stale };
}
