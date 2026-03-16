import { VibrancyResult, DepEdge, UpgradeStep, UpdateStatus, OverrideAnalysis } from '../types';
import { matchFamily } from '../data/package-families';

let currentOverrideAnalyses: readonly OverrideAnalysis[] = [];

/**
 * Set override analyses for the current upgrade planning session.
 * Called before buildUpgradeOrder to provide override context.
 */
export function setOverrideAnalyses(analyses: readonly OverrideAnalysis[]): void {
    currentOverrideAnalyses = analyses;
}

const UPDATE_RISK: Record<string, number> = {
    'patch': 1, 'minor': 2, 'major': 3, 'unknown': 4,
};

/**
 * Build a safe upgrade order for all upgradable packages.
 *
 * Call setOverrideAnalyses() before this to enable override resolution hints.
 *
 * Skips blocked packages. Orders by:
 * 1. Topological sort (dependencies before dependents)
 * 2. Risk gradient (patch < minor < major)
 * 3. Higher vibrancy first (more likely to succeed)
 * Family packages are grouped together.
 */
export function buildUpgradeOrder(
    results: readonly VibrancyResult[],
    reverseDeps: ReadonlyMap<string, readonly DepEdge[]>,
): UpgradeStep[] {
    const upgradable = results.filter(isUpgradable);
    if (upgradable.length === 0) { return []; }

    const nameSet = new Set(upgradable.map(r => r.package.name));
    const depMap = buildForwardDeps(reverseDeps, nameSet);
    const sorted = topoSort(upgradable, depMap);
    const grouped = groupByFamily(sorted);
    return assignOrder(grouped);
}

function isUpgradable(r: VibrancyResult): boolean {
    return r.updateInfo !== null
        && r.updateInfo.updateStatus !== 'up-to-date'
        && r.upgradeBlockStatus !== 'blocked';
}

/**
 * Build forward dependency map: package → packages it depends on.
 * Only includes packages in the upgradable set.
 */
function buildForwardDeps(
    reverseDeps: ReadonlyMap<string, readonly DepEdge[]>,
    nameSet: ReadonlySet<string>,
): Map<string, Set<string>> {
    const forward = new Map<string, Set<string>>();
    for (const name of nameSet) {
        forward.set(name, new Set());
    }
    for (const [dep, edges] of reverseDeps) {
        if (!nameSet.has(dep)) { continue; }
        for (const edge of edges) {
            if (!nameSet.has(edge.dependentPackage)) { continue; }
            // edge.dependentPackage depends on dep
            const deps = forward.get(edge.dependentPackage);
            if (deps) { deps.add(dep); }
        }
    }
    return forward;
}

/** Kahn's algorithm: topological sort with risk-gradient tiebreaking. */
function topoSort(
    items: readonly VibrancyResult[],
    depMap: ReadonlyMap<string, Set<string>>,
): VibrancyResult[] {
    const resultMap = new Map(items.map(r => [r.package.name, r]));
    const inDegree = new Map<string, number>();
    for (const r of items) {
        const deps = depMap.get(r.package.name);
        inDegree.set(r.package.name, deps?.size ?? 0);
    }

    const sorted: VibrancyResult[] = [];
    const queue = items
        .filter(r => (inDegree.get(r.package.name) ?? 0) === 0)
        .sort(compareByRisk);

    while (queue.length > 0) {
        const current = queue.shift()!;
        sorted.push(current);

        for (const [name, deps] of depMap) {
            if (!deps.has(current.package.name)) { continue; }
            deps.delete(current.package.name);
            const deg = (inDegree.get(name) ?? 1) - 1;
            inDegree.set(name, deg);
            if (deg === 0) {
                const r = resultMap.get(name);
                if (r) { insertSorted(queue, r); }
            }
        }
    }
    return sorted;
}

function compareByRisk(a: VibrancyResult, b: VibrancyResult): number {
    const riskA = UPDATE_RISK[a.updateInfo?.updateStatus ?? 'unknown'] ?? 4;
    const riskB = UPDATE_RISK[b.updateInfo?.updateStatus ?? 'unknown'] ?? 4;
    if (riskA !== riskB) { return riskA - riskB; }
    return b.score - a.score;
}

function insertSorted(queue: VibrancyResult[], item: VibrancyResult): void {
    const idx = queue.findIndex(q => compareByRisk(item, q) <= 0);
    if (idx < 0) { queue.push(item); }
    else { queue.splice(idx, 0, item); }
}

/** Group family packages together (adjacent in the list). */
function groupByFamily(sorted: VibrancyResult[]): VibrancyResult[] {
    const familyMap = new Map<string, VibrancyResult[]>();
    const nonFamily: VibrancyResult[] = [];

    for (const r of sorted) {
        const family = matchFamily(r.package.name);
        if (family) {
            let group = familyMap.get(family.id);
            if (!group) { group = []; familyMap.set(family.id, group); }
            group.push(r);
        } else {
            nonFamily.push(r);
        }
    }

    const result: VibrancyResult[] = [];
    const placed = new Set<string>();
    for (const r of sorted) {
        if (placed.has(r.package.name)) { continue; }
        const family = matchFamily(r.package.name);
        if (family && familyMap.has(family.id)) {
            for (const member of familyMap.get(family.id)!) {
                if (!placed.has(member.package.name)) {
                    result.push(member);
                    placed.add(member.package.name);
                }
            }
        } else {
            result.push(r);
            placed.add(r.package.name);
        }
    }
    return result;
}

function toStep(
    r: VibrancyResult, order: number,
): UpgradeStep {
    const family = matchFamily(r.package.name);
    const mayResolveOverride = findOverrideBlockedBy(r.package.name);
    return {
        packageName: r.package.name,
        currentVersion: r.updateInfo!.currentVersion,
        targetVersion: r.updateInfo!.latestVersion,
        updateType: r.updateInfo!.updateStatus as UpdateStatus,
        familyId: family?.id ?? null,
        order,
        mayResolveOverride,
    };
}

/**
 * Check if any active override is blocked by this package.
 * If upgrading this package might resolve the conflict, return the override name.
 */
function findOverrideBlockedBy(packageName: string): string | null {
    for (const analysis of currentOverrideAnalyses) {
        if (analysis.status === 'active' && analysis.blocker === packageName) {
            return analysis.entry.name;
        }
    }
    return null;
}

function assignOrder(items: VibrancyResult[]): UpgradeStep[] {
    return items.map((r, i) => toStep(r, i + 1));
}
