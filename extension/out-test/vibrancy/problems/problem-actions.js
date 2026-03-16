"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.determineBestAction = determineBestAction;
exports.calculateResolutionChain = calculateResolutionChain;
exports.getUnlockedPackages = getUnlockedPackages;
exports.findHighPriorityActions = findHighPriorityActions;
exports.formatAction = formatAction;
exports.actionIcon = actionIcon;
/** Priority weights for action types (higher = more important). */
const ACTION_PRIORITY = {
    'fix-vulnerability': 100, 'remove': 80, 'upgrade-blocker': 70, 'upgrade-family': 60,
    'replace': 50, 'upgrade': 40, 'remove-override': 30, 'review-license': 20, 'none': 0,
};
/**
 * Determine the best action to address problems for a package.
 */
function determineBestAction(problems, alternatives) {
    const problemIds = problems.map(p => p.id);
    if (problems.length === 0) {
        return {
            type: 'none',
            description: 'No action needed',
            targetPackages: [],
            resolvesProblemIds: [],
            priority: 0,
        };
    }
    const hasVulnerability = problems.some(p => p.type === 'vulnerability');
    const hasUnused = problems.some(p => p.type === 'unused');
    const hasUnhealthy = problems.some(p => p.type === 'unhealthy');
    const hasBlocked = problems.some(p => p.type === 'blocked-upgrade');
    const hasFamilyConflict = problems.some(p => p.type === 'family-conflict');
    const hasStaleOverride = problems.some(p => p.type === 'stale-override');
    const hasRiskyTransitive = problems.some(p => p.type === 'risky-transitive');
    const hasLicenseRisk = problems.some(p => p.type === 'license-risk');
    const packageName = problems[0].package;
    if (hasVulnerability) {
        const vuln = problems.find(p => p.type === 'vulnerability');
        if (vuln && vuln.type === 'vulnerability' && vuln.fixedVersion) {
            return {
                type: 'fix-vulnerability',
                description: `Upgrade to ${vuln.fixedVersion} to fix ${vuln.vulnId}`,
                targetPackages: [packageName],
                resolvesProblemIds: problemIds.filter(id => problems.find(p => p.id === id)?.type === 'vulnerability'),
                priority: ACTION_PRIORITY['fix-vulnerability'],
            };
        }
    }
    if (hasUnused && hasUnhealthy) {
        return {
            type: 'remove',
            description: 'Remove this package — unused and unhealthy',
            targetPackages: [packageName],
            resolvesProblemIds: problemIds,
            priority: ACTION_PRIORITY['remove'],
        };
    }
    if (hasUnused) {
        return {
            type: 'remove',
            description: 'Remove this package — no imports found',
            targetPackages: [packageName],
            resolvesProblemIds: problemIds.filter(id => problems.find(p => p.id === id)?.type === 'unused'),
            priority: ACTION_PRIORITY['remove'],
        };
    }
    if (hasBlocked) {
        const blocked = problems.find(p => p.type === 'blocked-upgrade');
        if (blocked && blocked.type === 'blocked-upgrade') {
            return {
                type: 'upgrade-blocker',
                description: `Upgrade ${blocked.blockerPackage} first`,
                targetPackages: [blocked.blockerPackage],
                resolvesProblemIds: problemIds.filter(id => problems.find(p => p.id === id)?.type === 'blocked-upgrade'),
                priority: ACTION_PRIORITY['upgrade-blocker'],
            };
        }
    }
    if (hasFamilyConflict) {
        const conflict = problems.find(p => p.type === 'family-conflict');
        if (conflict && conflict.type === 'family-conflict') {
            const allFamily = [packageName, ...conflict.conflictingPackages];
            return {
                type: 'upgrade-family',
                description: `Upgrade all ${conflict.familyLabel} packages together`,
                targetPackages: allFamily,
                resolvesProblemIds: problemIds.filter(id => problems.find(p => p.id === id)?.type === 'family-conflict'),
                priority: ACTION_PRIORITY['upgrade-family'],
            };
        }
    }
    if (hasStaleOverride) {
        return {
            type: 'remove-override',
            description: 'Remove override from pubspec.yaml',
            targetPackages: [packageName],
            resolvesProblemIds: problemIds.filter(id => problems.find(p => p.id === id)?.type === 'stale-override'),
            priority: ACTION_PRIORITY['remove-override'],
        };
    }
    if (hasUnhealthy && alternatives.length > 0) {
        return {
            type: 'replace',
            description: `Consider replacing with ${alternatives[0]}`,
            targetPackages: [packageName, alternatives[0]],
            resolvesProblemIds: problemIds.filter(id => problems.find(p => p.id === id)?.type === 'unhealthy'),
            priority: ACTION_PRIORITY['replace'],
        };
    }
    if (hasRiskyTransitive) {
        return {
            type: 'upgrade',
            description: 'Upgrade to get safer transitive dependencies',
            targetPackages: [packageName],
            resolvesProblemIds: problemIds.filter(id => problems.find(p => p.id === id)?.type === 'risky-transitive'),
            priority: ACTION_PRIORITY['upgrade'],
        };
    }
    if (hasLicenseRisk) {
        const license = problems.find(p => p.type === 'license-risk');
        if (license && license.type === 'license-risk') {
            return {
                type: 'review-license',
                description: `Review license: ${license.license} (${license.riskLevel})`,
                targetPackages: [packageName],
                resolvesProblemIds: problemIds.filter(id => problems.find(p => p.id === id)?.type === 'license-risk'),
                priority: ACTION_PRIORITY['review-license'],
            };
        }
    }
    if (hasUnhealthy) {
        return {
            type: 'none',
            description: 'Review package health and consider alternatives',
            targetPackages: [packageName],
            resolvesProblemIds: [],
            priority: ACTION_PRIORITY['none'],
        };
    }
    return {
        type: 'none',
        description: 'No specific action recommended',
        targetPackages: [],
        resolvesProblemIds: [],
        priority: ACTION_PRIORITY['none'],
    };
}
/**
 * Calculate the full resolution chain for a package.
 * Returns a list of actions that would cascade from fixing this package.
 */
function calculateResolutionChain(packageName, registry) {
    const problems = registry.getForPackage(packageName);
    const actions = [];
    for (const problem of problems) {
        const chain = registry.getResolutionChain(problem.id);
        if (chain.length === 0) {
            continue;
        }
        const packageGroups = new Map();
        for (const p of chain) {
            const existing = packageGroups.get(p.package) ?? [];
            existing.push(p);
            packageGroups.set(p.package, existing);
        }
        for (const [pkg, pkgProblems] of packageGroups) {
            actions.push({
                type: 'none',
                description: `Resolves ${pkgProblems.length} problem(s) in ${pkg}`,
                targetPackages: [pkg],
                resolvesProblemIds: pkgProblems.map(p => p.id),
                priority: pkgProblems.length * 10,
            });
        }
    }
    return actions.sort((a, b) => b.priority - a.priority);
}
/**
 * Get packages that would be unlocked if the given package is fixed.
 */
function getUnlockedPackages(packageName, registry) {
    const unlocked = new Set();
    const problems = registry.getForPackage(packageName);
    for (const problem of problems) {
        const chain = registry.getResolutionChain(problem.id);
        for (const resolved of chain) {
            if (resolved.package !== packageName) {
                unlocked.add(resolved.package);
            }
        }
    }
    return Array.from(unlocked);
}
/**
 * Find all high-priority actions across all packages.
 */
function findHighPriorityActions(registry, limit = 10) {
    const actions = [];
    for (const pkgProblems of registry.getAllSortedByPriority()) {
        const action = determineBestAction(pkgProblems.problems, []);
        if (action.type !== 'none') {
            actions.push(action);
        }
    }
    return actions
        .sort((a, b) => b.priority - a.priority)
        .slice(0, limit);
}
/**
 * Format an action as a human-readable string.
 */
function formatAction(action) {
    if (action.resolvesProblemIds.length > 1) {
        return `${action.description} (resolves ${action.resolvesProblemIds.length} problems)`;
    }
    return action.description;
}
/** Map action type to its display icon. */
const ACTION_ICONS = {
    'remove': '🗑️', 'upgrade': '⬆️', 'upgrade-blocker': '🔓', 'upgrade-family': '👨‍👩‍👧‍👦',
    'remove-override': '✂️', 'replace': '🔄', 'review-license': '📜', 'fix-vulnerability': '🛡️', 'none': '💡',
};
/** Get the icon for an action type. */
function actionIcon(type) { return ACTION_ICONS[type]; }
//# sourceMappingURL=problem-actions.js.map