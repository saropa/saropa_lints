"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.collectTransitives = collectTransitives;
exports.buildAdjacencyMap = buildAdjacencyMap;
exports.countTransitives = countTransitives;
exports.findSharedDeps = findSharedDeps;
exports.flagRiskyTransitives = flagRiskyTransitives;
exports.enrichTransitiveInfo = enrichTransitiveInfo;
exports.calcTransitiveRiskPenalty = calcTransitiveRiskPenalty;
exports.buildDepGraphSummary = buildDepGraphSummary;
/**
 * Recursively collect all transitive dependencies for a package.
 * Uses cycle detection to avoid infinite loops.
 */
function collectTransitives(packageName, adjacency, visited = new Set(), startNode) {
    const result = new Set();
    const rootNode = startNode ?? packageName;
    const queue = adjacency.get(packageName) ?? [];
    for (const dep of queue) {
        if (visited.has(dep)) {
            continue;
        }
        if (dep === rootNode) {
            continue;
        }
        visited.add(dep);
        result.add(dep);
        const nested = collectTransitives(dep, adjacency, visited, rootNode);
        for (const n of nested) {
            result.add(n);
        }
    }
    return result;
}
/**
 * Build adjacency map from package list: package → its direct deps.
 */
function buildAdjacencyMap(packages) {
    const map = new Map();
    for (const pkg of packages) {
        map.set(pkg.name, pkg.dependencies);
    }
    return map;
}
/**
 * Count transitive dependencies for each direct dependency.
 */
function countTransitives(directDeps, packages) {
    const adjacency = buildAdjacencyMap(packages);
    const results = [];
    for (const directDep of directDeps) {
        const transitives = collectTransitives(directDep, adjacency);
        results.push({
            directDep,
            transitiveCount: transitives.size,
            flaggedCount: 0,
            transitives: [...transitives],
            sharedDeps: [],
        });
    }
    return results;
}
/**
 * Find dependencies that are shared by multiple direct deps.
 * Returns packages depended on by 2+ direct deps.
 */
function findSharedDeps(directDeps, packages) {
    const adjacency = buildAdjacencyMap(packages);
    const depToUsers = new Map();
    for (const directDep of directDeps) {
        const transitives = collectTransitives(directDep, adjacency);
        for (const transitive of transitives) {
            const users = depToUsers.get(transitive);
            if (users) {
                users.push(directDep);
            }
            else {
                depToUsers.set(transitive, [directDep]);
            }
        }
    }
    const shared = [];
    for (const [name, usedBy] of depToUsers) {
        if (usedBy.length >= 2) {
            shared.push({ name, usedBy: [...usedBy] });
        }
    }
    return shared.sort((a, b) => b.usedBy.length - a.usedBy.length);
}
/**
 * Flag risky transitive dependencies based on known issues.
 */
function flagRiskyTransitives(transitiveInfos, knownIssues) {
    const flagged = [];
    for (const info of transitiveInfos) {
        for (const transitive of info.transitives) {
            const issues = knownIssues.get(transitive);
            // No version context for transitives — flag if ANY entry is risky
            const risky = issues?.find(i => i.status === 'discontinued' || i.status === 'end-of-life');
            if (risky) {
                flagged.push({
                    name: transitive,
                    directDep: info.directDep,
                    reason: risky.reason ?? risky.status,
                });
            }
        }
    }
    return flagged;
}
/**
 * Enrich TransitiveInfo entries with flagged counts and shared deps.
 */
function enrichTransitiveInfo(infos, sharedDeps, knownIssues) {
    const sharedSet = new Set(sharedDeps.map(s => s.name));
    return infos.map(info => {
        let flaggedCount = 0;
        const sharedInThis = [];
        for (const transitive of info.transitives) {
            const issues = knownIssues.get(transitive);
            // No version context for transitives — flag if ANY entry is risky
            if (issues?.some(i => i.status === 'discontinued' || i.status === 'end-of-life')) {
                flaggedCount++;
            }
            if (sharedSet.has(transitive)) {
                sharedInThis.push(transitive);
            }
        }
        return {
            ...info,
            flaggedCount,
            sharedDeps: sharedInThis,
        };
    });
}
/**
 * Calculate score penalty based on transitive dependency risks.
 * - Each flagged (EOL/discontinued) transitive: -2 points (max -10)
 * - High transitive count (>20): -1 to -5 points based on count
 */
function calcTransitiveRiskPenalty(info) {
    let penalty = 0;
    const flaggedPenalty = Math.min(info.flaggedCount * 2, 10);
    penalty += flaggedPenalty;
    if (info.transitiveCount > 20) {
        const countPenalty = Math.min(Math.floor((info.transitiveCount - 20) / 10), 5);
        penalty += countPenalty;
    }
    return penalty;
}
/**
 * Build summary of the full dependency graph.
 */
function buildDepGraphSummary(directDeps, packages, overrideCount) {
    const directSet = new Set(directDeps);
    const allTransitives = new Set();
    const adjacency = buildAdjacencyMap(packages);
    for (const directDep of directDeps) {
        const transitives = collectTransitives(directDep, adjacency);
        for (const t of transitives) {
            if (!directSet.has(t)) {
                allTransitives.add(t);
            }
        }
    }
    const sharedDeps = findSharedDeps(directDeps, packages);
    const highBlast = sharedDeps.filter(s => s.usedBy.length >= 5);
    return {
        directCount: directDeps.length,
        transitiveCount: allTransitives.size,
        totalUnique: directDeps.length + allTransitives.size,
        overrideCount,
        sharedDeps: highBlast,
    };
}
//# sourceMappingURL=transitive-analyzer.js.map