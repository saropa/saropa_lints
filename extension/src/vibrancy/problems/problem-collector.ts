import {
    VibrancyResult, OverrideAnalysis, FamilySplit, PackageRange,
    isUnusedRemovalEligibleSection,
} from '../types';
import {
    ProblemSeverity, generateProblemId,
    UnhealthyPackageProblem, StaleOverrideProblem,
    FamilyConflictProblem, RiskyTransitiveProblem, BlockedUpgradeProblem,
    UnusedProblem, LicenseRiskProblem, VulnerabilityProblem,
} from './problem-types';
import { ProblemRegistry } from './problem-registry';
import { classifyLicense, LicenseTier } from '../scoring/license-classifier';

/** Context for collecting problems. */
export interface CollectorContext {
    readonly packageRanges: Map<string, PackageRange>;
    readonly overrideAnalyses: readonly OverrideAnalysis[];
    readonly familySplits: readonly FamilySplit[];
}

/**
 * Collect all problems from scan results and populate the registry.
 * This is the main entry point for populating the problem registry.
 */
export function collectProblemsFromResults(
    results: readonly VibrancyResult[],
    context: CollectorContext,
    registry: ProblemRegistry,
): void {
    registry.clear();

    const overrideMap = buildOverrideMap(context.overrideAnalyses);
    const splitMap = buildSplitMap(context.familySplits);

    for (const result of results) {
        const line = context.packageRanges.get(result.package.name)?.line ?? 0;
        collectProblemsForPackage(result, line, overrideMap, splitMap, registry);
    }

    collectOverrideProblems(context.overrideAnalyses, registry);
    linkRelatedProblems(registry);
}

/**
 * Collect problems for a single package.
 */
export function collectProblemsForPackage(
    result: VibrancyResult,
    line: number,
    overrideMap: Map<string, OverrideAnalysis>,
    splitMap: Map<string, FamilySplit>,
    registry: ProblemRegistry,
): void {
    const name = result.package.name;

    if (result.category === 'end-of-life' || result.category === 'legacy-locked') {
        registry.add(createUnhealthyProblem(result, line));
    }

    // Dev dependencies (linters, codegen) are not suggested for removal when unused.
    if (result.isUnused && isUnusedRemovalEligibleSection(result.package.section)) {
        registry.add(createUnusedProblem(name, line));
    }

    if (result.upgradeBlockStatus === 'blocked' && result.blocker) {
        registry.add(createBlockedUpgradeProblem(result, line));
    }

    if (result.transitiveInfo && result.transitiveInfo.flaggedCount > 0) {
        registry.add(createRiskyTransitiveProblem(result, line));
    }

    const override = overrideMap.get(name);
    if (override?.status === 'stale'
        && !override.entry.isPathDep && !override.entry.isGitDep) {
        registry.add(createStaleOverrideProblem(override, line));
    }

    const split = splitMap.get(name);
    if (split) {
        registry.add(createFamilyConflictProblem(result, split, line));
    }

    if (result.license) {
        const tier = classifyLicense(result.license);
        if (tier === 'copyleft' || tier === 'unknown') {
            registry.add(createLicenseRiskProblem(name, result.license, tier, line));
        }
    }

    for (const vuln of result.vulnerabilities) {
        registry.add(createVulnerabilityProblem(name, vuln, line));
    }
}

/**
 * Collect problems from override analyses that may not have corresponding results.
 */
export function collectOverrideProblems(
    overrides: readonly OverrideAnalysis[],
    registry: ProblemRegistry,
): void {
    for (const override of overrides) {
        if (override.status !== 'stale') { continue; }
        if (override.entry.isPathDep || override.entry.isGitDep) { continue; }

        const existingProblems = registry.getForPackage(override.entry.name);
        const hasOverrideProblem = existingProblems.some(
            p => p.type === 'stale-override',
        );
        if (hasOverrideProblem) { continue; }

        registry.add(createStaleOverrideProblem(override, override.entry.line));
    }
}

/**
 * Link related problems for resolution chain tracking.
 */
export function linkRelatedProblems(registry: ProblemRegistry): void {
    const blockedProblems = registry.getByType('blocked-upgrade');
    for (const blocked of blockedProblems) {
        if (blocked.type !== 'blocked-upgrade') { continue; }

        const blockerProblems = registry.getForPackage(blocked.blockerPackage);
        for (const blockerProblem of blockerProblems) {
            registry.link(blockerProblem.id, blocked.id, 'blocks');
        }
    }

    const familyConflicts = registry.getByType('family-conflict');
    for (const conflict of familyConflicts) {
        if (conflict.type !== 'family-conflict') { continue; }

        for (const related of conflict.conflictingPackages) {
            const relatedConflicts = registry.getForPackage(related)
                .filter(p => p.type === 'family-conflict');
            for (const relatedConflict of relatedConflicts) {
                registry.link(conflict.id, relatedConflict.id, 'related');
            }
        }
    }
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

function createUnhealthyProblem(
    result: VibrancyResult,
    line: number,
): UnhealthyPackageProblem {
    const severity: ProblemSeverity = result.category === 'end-of-life' ? 'high' : 'medium';
    return {
        id: generateProblemId(result.package.name, 'unhealthy'),
        type: 'unhealthy',
        package: result.package.name,
        severity,
        line,
        score: result.score,
        category: result.category,
    };
}

function createUnusedProblem(name: string, line: number): UnusedProblem {
    return { id: generateProblemId(name, 'unused'), type: 'unused', package: name, severity: 'low', line };
}

function createBlockedUpgradeProblem(
    result: VibrancyResult,
    line: number,
): BlockedUpgradeProblem {
    const blocker = result.blocker!;
    return {
        id: generateProblemId(result.package.name, 'blocked-upgrade'),
        type: 'blocked-upgrade',
        package: result.package.name,
        severity: 'medium',
        line,
        currentVersion: blocker.currentVersion,
        latestVersion: blocker.latestVersion,
        blockerPackage: blocker.blockerPackage,
        blockerScore: blocker.blockerVibrancyScore,
    };
}

function createRiskyTransitiveProblem(
    result: VibrancyResult,
    line: number,
): RiskyTransitiveProblem {
    const info = result.transitiveInfo!;
    return {
        id: generateProblemId(result.package.name, 'risky-transitive'),
        type: 'risky-transitive',
        package: result.package.name,
        severity: 'medium',
        line,
        flaggedCount: info.flaggedCount,
        flaggedTransitives: info.sharedDeps.length > 0
            ? [...info.sharedDeps].slice(0, 3)
            : [...info.transitives].slice(0, 3),
    };
}

function createStaleOverrideProblem(override: OverrideAnalysis, line: number): StaleOverrideProblem {
    return {
        id: generateProblemId(override.entry.name, 'stale-override'),
        type: 'stale-override', package: override.entry.name, severity: 'low', line,
        overrideName: override.entry.name, ageDays: override.ageDays,
    };
}

function createFamilyConflictProblem(
    result: VibrancyResult,
    split: FamilySplit,
    line: number,
): FamilyConflictProblem {
    const ownGroup = split.versionGroups.find(
        g => g.packages.includes(result.package.name),
    );
    const otherPackages = split.versionGroups
        .flatMap(g => g.packages)
        .filter(p => p !== result.package.name);

    return {
        id: generateProblemId(result.package.name, 'family-conflict'),
        type: 'family-conflict',
        package: result.package.name,
        severity: 'high',
        line,
        familyId: split.familyId,
        familyLabel: split.familyLabel,
        currentMajor: ownGroup?.majorVersion ?? 0,
        conflictingPackages: otherPackages,
    };
}

function createLicenseRiskProblem(
    name: string,
    license: string,
    tier: LicenseTier,
    line: number,
): LicenseRiskProblem {
    const riskLevel = tier === 'copyleft' ? 'copyleft' : 'unknown';
    return {
        id: generateProblemId(name, 'license-risk'),
        type: 'license-risk',
        package: name,
        severity: tier === 'copyleft' ? 'medium' : 'low',
        line,
        license,
        riskLevel,
    };
}

function createVulnerabilityProblem(
    name: string,
    vuln: { id: string; summary: string; severity: string; fixedVersion: string | null },
    line: number,
): VulnerabilityProblem {
    const severityMap: Record<string, ProblemSeverity> = {
        'critical': 'high',
        'high': 'high',
        'medium': 'medium',
        'low': 'low',
    };
    return {
        id: generateProblemId(name, 'vulnerability', vuln.id),
        type: 'vulnerability',
        package: name,
        severity: severityMap[vuln.severity] ?? 'medium',
        line,
        vulnId: vuln.id,
        vulnSeverity: vuln.severity as 'critical' | 'high' | 'medium' | 'low',
        summary: vuln.summary,
        fixedVersion: vuln.fixedVersion,
    };
}
