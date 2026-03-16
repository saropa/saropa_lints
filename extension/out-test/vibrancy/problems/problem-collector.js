"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.collectProblemsFromResults = collectProblemsFromResults;
exports.collectProblemsForPackage = collectProblemsForPackage;
exports.collectOverrideProblems = collectOverrideProblems;
exports.linkRelatedProblems = linkRelatedProblems;
const types_1 = require("../types");
const problem_types_1 = require("./problem-types");
const license_classifier_1 = require("../scoring/license-classifier");
/**
 * Collect all problems from scan results and populate the registry.
 * This is the main entry point for populating the problem registry.
 */
function collectProblemsFromResults(results, context, registry) {
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
function collectProblemsForPackage(result, line, overrideMap, splitMap, registry) {
    const name = result.package.name;
    // Stale packages (score < 10) are unhealthy but not end-of-life
    if (result.category === 'end-of-life' || result.category === 'stale' || result.category === 'legacy-locked') {
        registry.add(createUnhealthyProblem(result, line));
    }
    // Dev dependencies (linters, codegen) are not suggested for removal when unused.
    if (result.isUnused && (0, types_1.isUnusedRemovalEligibleSection)(result.package.section)) {
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
        const tier = (0, license_classifier_1.classifyLicense)(result.license);
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
function collectOverrideProblems(overrides, registry) {
    for (const override of overrides) {
        if (override.status !== 'stale') {
            continue;
        }
        if (override.entry.isPathDep || override.entry.isGitDep) {
            continue;
        }
        const existingProblems = registry.getForPackage(override.entry.name);
        const hasOverrideProblem = existingProblems.some(p => p.type === 'stale-override');
        if (hasOverrideProblem) {
            continue;
        }
        registry.add(createStaleOverrideProblem(override, override.entry.line));
    }
}
/**
 * Link related problems for resolution chain tracking.
 */
function linkRelatedProblems(registry) {
    const blockedProblems = registry.getByType('blocked-upgrade');
    for (const blocked of blockedProblems) {
        if (blocked.type !== 'blocked-upgrade') {
            continue;
        }
        const blockerProblems = registry.getForPackage(blocked.blockerPackage);
        for (const blockerProblem of blockerProblems) {
            registry.link(blockerProblem.id, blocked.id, 'blocks');
        }
    }
    const familyConflicts = registry.getByType('family-conflict');
    for (const conflict of familyConflicts) {
        if (conflict.type !== 'family-conflict') {
            continue;
        }
        for (const related of conflict.conflictingPackages) {
            const relatedConflicts = registry.getForPackage(related)
                .filter(p => p.type === 'family-conflict');
            for (const relatedConflict of relatedConflicts) {
                registry.link(conflict.id, relatedConflict.id, 'related');
            }
        }
    }
}
function buildOverrideMap(overrides) {
    return new Map(overrides.map(o => [o.entry.name, o]));
}
function buildSplitMap(splits) {
    const map = new Map();
    for (const split of splits) {
        for (const group of split.versionGroups) {
            for (const pkg of group.packages) {
                map.set(pkg, split);
            }
        }
    }
    return map;
}
function createUnhealthyProblem(result, line) {
    // EOL = high severity; stale/legacy-locked = medium
    const severity = result.category === 'end-of-life' ? 'high' : 'medium';
    return {
        id: (0, problem_types_1.generateProblemId)(result.package.name, 'unhealthy'),
        type: 'unhealthy',
        package: result.package.name,
        severity,
        line,
        score: result.score,
        category: result.category,
    };
}
function createUnusedProblem(name, line) {
    return { id: (0, problem_types_1.generateProblemId)(name, 'unused'), type: 'unused', package: name, severity: 'low', line };
}
function createBlockedUpgradeProblem(result, line) {
    const blocker = result.blocker;
    return {
        id: (0, problem_types_1.generateProblemId)(result.package.name, 'blocked-upgrade'),
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
function createRiskyTransitiveProblem(result, line) {
    const info = result.transitiveInfo;
    return {
        id: (0, problem_types_1.generateProblemId)(result.package.name, 'risky-transitive'),
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
function createStaleOverrideProblem(override, line) {
    return {
        id: (0, problem_types_1.generateProblemId)(override.entry.name, 'stale-override'),
        type: 'stale-override', package: override.entry.name, severity: 'low', line,
        overrideName: override.entry.name, ageDays: override.ageDays,
    };
}
function createFamilyConflictProblem(result, split, line) {
    const ownGroup = split.versionGroups.find(g => g.packages.includes(result.package.name));
    const otherPackages = split.versionGroups
        .flatMap(g => g.packages)
        .filter(p => p !== result.package.name);
    return {
        id: (0, problem_types_1.generateProblemId)(result.package.name, 'family-conflict'),
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
function createLicenseRiskProblem(name, license, tier, line) {
    const riskLevel = tier === 'copyleft' ? 'copyleft' : 'unknown';
    return {
        id: (0, problem_types_1.generateProblemId)(name, 'license-risk'),
        type: 'license-risk',
        package: name,
        severity: tier === 'copyleft' ? 'medium' : 'low',
        line,
        license,
        riskLevel,
    };
}
function createVulnerabilityProblem(name, vuln, line) {
    const severityMap = {
        'critical': 'high',
        'high': 'high',
        'medium': 'medium',
        'low': 'low',
    };
    return {
        id: (0, problem_types_1.generateProblemId)(name, 'vulnerability', vuln.id),
        type: 'vulnerability',
        package: name,
        severity: severityMap[vuln.severity] ?? 'medium',
        line,
        vulnId: vuln.id,
        vulnSeverity: vuln.severity,
        summary: vuln.summary,
        fixedVersion: vuln.fixedVersion,
    };
}
//# sourceMappingURL=problem-collector.js.map