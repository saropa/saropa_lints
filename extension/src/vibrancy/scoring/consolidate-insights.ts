import {
    VibrancyResult, OverrideAnalysis, FamilySplit, Problem,
    ProblemType, ActionType, PackageInsight,
} from '../types';

const PROBLEM_WEIGHTS: Record<ProblemType, number> = {
    'unhealthy': 25,
    'family-conflict': 25,
    'risky-transitive': 15,
    'blocked-upgrade': 10,
    'stale-override': 10,
    'unused': 5,
    'license-risk': 20,
};

const EOL_WEIGHT = 30;
const LEGACY_WEIGHT = 20;

/**
 * Consolidate all feature outputs into unified per-package insights.
 * Cross-references vibrancy results, overrides, family splits, and blockers
 * to produce a ranked list of action items.
 */
export function consolidateInsights(
    results: readonly VibrancyResult[],
    overrides: readonly OverrideAnalysis[],
    splits: readonly FamilySplit[],
): PackageInsight[] {
    const insights: PackageInsight[] = [];
    const overrideMap = buildOverrideMap(overrides);
    const splitMap = buildSplitMap(splits);

    for (const result of results) {
        const problems = collectProblems(result, overrideMap, splitMap);
        if (problems.length === 0) { continue; }

        const combinedRiskScore = computeCombinedRisk(problems, result);
        const { action, actionType } = determineSuggestedAction(problems, result);
        const unlocksIfFixed = findUnlockedPackages(
            result.package.name, results, overrides,
        );

        insights.push({
            name: result.package.name,
            combinedRiskScore,
            problems,
            suggestedAction: action,
            actionType,
            unlocksIfFixed,
        });
    }

    return insights.sort((a, b) => b.combinedRiskScore - a.combinedRiskScore);
}

function buildOverrideMap(
    overrides: readonly OverrideAnalysis[],
): Map<string, OverrideAnalysis> {
    return new Map(overrides.map(o => [o.entry.name, o]));
}

function buildSplitMap(
    splits: readonly FamilySplit[],
): Map<string, FamilySplit> {
    const map = new Map<string, FamilySplit>();
    for (const split of splits) {
        for (const group of split.versionGroups) {
            for (const pkg of group.packages) {
                map.set(pkg, split);
            }
        }
    }
    return map;
}

/**
 * Collect all problems affecting a package.
 */
export function collectProblems(
    result: VibrancyResult,
    overrideMap: Map<string, OverrideAnalysis>,
    splitMap: Map<string, FamilySplit>,
): Problem[] {
    const problems: Problem[] = [];

    if (result.category === 'end-of-life') {
        problems.push({
            type: 'unhealthy',
            severity: 'high',
            message: 'Package is end-of-life',
        });
    } else if (result.category === 'legacy-locked') {
        problems.push({
            type: 'unhealthy',
            severity: 'medium',
            message: `Score ${result.score}/100 — legacy-locked`,
        });
    }

    if (result.isUnused) {
        problems.push({
            type: 'unused',
            severity: 'low',
            message: 'No imports found in lib/, bin/, or test/',
        });
    }

    if (result.upgradeBlockStatus === 'blocked' && result.blocker) {
        problems.push({
            type: 'blocked-upgrade',
            severity: 'medium',
            message: `Update blocked by ${result.blocker.blockerPackage}`,
            relatedPackage: result.blocker.blockerPackage,
        });
    }

    const transitiveInfo = result.transitiveInfo;
    if (transitiveInfo && transitiveInfo.flaggedCount > 0) {
        problems.push({
            type: 'risky-transitive',
            severity: 'medium',
            message: `${transitiveInfo.flaggedCount} risky transitive(s)`,
        });
    }

    const override = overrideMap.get(result.package.name);
    if (override?.status === 'stale'
        && !override.entry.isPathDep && !override.entry.isGitDep) {
        problems.push({
            type: 'stale-override',
            severity: 'low',
            message: 'No version conflict detected — review this override',
        });
    }

    const split = splitMap.get(result.package.name);
    if (split) {
        const otherPackages = split.versionGroups
            .flatMap(g => g.packages)
            .filter(p => p !== result.package.name);
        problems.push({
            type: 'family-conflict',
            severity: 'high',
            message: `${split.familyLabel} version split with ${otherPackages.join(', ')}`,
        });
    }

    return problems;
}

/**
 * Compute combined risk score from problems.
 */
export function computeCombinedRisk(
    problems: readonly Problem[],
    result: VibrancyResult,
): number {
    let score = 0;

    for (const problem of problems) {
        if (problem.type === 'unhealthy') {
            score += result.category === 'end-of-life' ? EOL_WEIGHT : LEGACY_WEIGHT;
        } else {
            score += PROBLEM_WEIGHTS[problem.type];
        }
    }

    return score;
}

interface ActionResult {
    action: string | null;
    actionType: ActionType;
}

/**
 * Determine the single best action for a package.
 */
export function determineSuggestedAction(
    problems: readonly Problem[],
    result: VibrancyResult,
): ActionResult {
    const hasUnused = problems.some(p => p.type === 'unused');
    const hasUnhealthy = problems.some(p => p.type === 'unhealthy');
    const hasBlocked = problems.some(p => p.type === 'blocked-upgrade');
    const hasFamilyConflict = problems.some(p => p.type === 'family-conflict');
    const hasStaleOverride = problems.some(p => p.type === 'stale-override');
    const hasRiskyTransitive = problems.some(p => p.type === 'risky-transitive');

    if (hasUnused && hasUnhealthy) {
        return {
            action: 'Remove this package — unused and unhealthy',
            actionType: 'remove',
        };
    }

    if (hasUnused) {
        return {
            action: 'Remove this package — no imports found',
            actionType: 'remove',
        };
    }

    if (hasBlocked) {
        const blocker = problems.find(p => p.type === 'blocked-upgrade');
        return {
            action: `Upgrade ${blocker?.relatedPackage} first`,
            actionType: 'upgrade-blocker',
        };
    }

    if (hasFamilyConflict) {
        const conflict = problems.find(p => p.type === 'family-conflict');
        return {
            action: conflict?.message.includes('Firebase')
                ? 'Upgrade all Firebase packages together'
                : 'Upgrade all family packages together',
            actionType: 'upgrade-family',
        };
    }

    if (hasStaleOverride) {
        return {
            action: 'Remove override from pubspec.yaml',
            actionType: 'remove-override',
        };
    }

    if (hasUnhealthy && result.alternatives.length > 0) {
        const alt = result.alternatives[0];
        return {
            action: `Consider replacing with ${alt.name}`,
            actionType: 'replace',
        };
    }

    if (hasRiskyTransitive) {
        return {
            action: 'Upgrade to get safer transitive dependencies',
            actionType: 'upgrade',
        };
    }

    if (hasUnhealthy) {
        return {
            action: 'Review package health and consider alternatives',
            actionType: 'none',
        };
    }

    return { action: null, actionType: 'none' };
}

/**
 * Find packages that would be unblocked if this package is fixed.
 */
export function findUnlockedPackages(
    packageName: string,
    results: readonly VibrancyResult[],
    overrides: readonly OverrideAnalysis[],
): string[] {
    const unlocked: string[] = [];

    for (const result of results) {
        if (result.blocker?.blockerPackage === packageName) {
            unlocked.push(result.package.name);
        }
    }

    for (const override of overrides) {
        if (override.status === 'active' && override.blocker === packageName) {
            unlocked.push(`${override.entry.name} override`);
        }
    }

    return unlocked;
}
