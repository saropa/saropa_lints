"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.classifyUpgradeStatus = classifyUpgradeStatus;
exports.findBlockers = findBlockers;
const changelog_service_1 = require("../services/changelog-service");
/**
 * Classify upgrade status for a single pub outdated entry.
 * - up-to-date: current == latest
 * - upgradable: current < upgradable (can upgrade freely)
 * - blocked: resolvable < latest (something constrains it)
 * - constrained: upgradable < resolvable (your own constraint limits it)
 */
function classifyUpgradeStatus(entry) {
    if (!entry.current || !entry.latest) {
        return 'up-to-date';
    }
    if ((0, changelog_service_1.compareVersions)(entry.current, entry.latest) === 'up-to-date') {
        return 'up-to-date';
    }
    if (entry.resolvable && entry.latest
        && (0, changelog_service_1.compareVersions)(entry.resolvable, entry.latest) !== 'up-to-date') {
        return 'blocked';
    }
    if (entry.upgradable && entry.resolvable
        && (0, changelog_service_1.compareVersions)(entry.upgradable, entry.resolvable) !== 'up-to-date') {
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
function findBlockers(outdated, reverseDeps, results, directDeps) {
    const resultMap = new Map(results.map(r => [r.package.name, r]));
    const blockers = [];
    for (const entry of outdated) {
        if (classifyUpgradeStatus(entry) !== 'blocked') {
            continue;
        }
        const blocker = findBlockerForPackage(entry, reverseDeps, resultMap, directDeps);
        if (blocker) {
            blockers.push(blocker);
        }
    }
    return blockers;
}
function findBlockerForPackage(entry, reverseDeps, resultMap, directDeps) {
    const edges = reverseDeps.get(entry.package);
    if (!edges || edges.length === 0) {
        return null;
    }
    // Prefer direct dependencies as the reported blocker
    const directBlocker = edges.find(e => directDeps.has(e.dependentPackage));
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
//# sourceMappingURL=blocker-analyzer.js.map