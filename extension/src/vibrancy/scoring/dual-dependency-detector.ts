/**
 * Detects "dual dependency" risk: a package the project depends on directly
 * AND ALSO reaches transitively through another direct dependency. Pub always
 * resolves to a single installed version, so this is never a version
 * conflict — it is an import-path/type-identity risk: project code that
 * imports the type directly and a sibling package that re-exports or
 * consumes the same type may diverge if either side's constraint moves past
 * a breaking change independently.
 */

import { DepEdge } from '../types';

/** One direct dependency that also transitively requires the shared package. */
export interface DualDependencySource {
    readonly viaPackage: string;
    /** The via-package's own declared constraint on the shared dep, when read. */
    readonly viaConstraint: string | null;
}

/** A direct dependency that is also reachable through another direct dependency. */
export interface DualDependencyRisk {
    readonly packageName: string;
    readonly directConstraint: string;
    readonly sources: readonly DualDependencySource[];
}

/**
 * Find every direct dependency that is also transitively required by another
 * direct dependency. `directConstraints` maps package name -> declared
 * pubspec.yaml constraint, for every DIRECT dependency only (not transitive).
 */
export function detectDualDependencies(
    directConstraints: ReadonlyMap<string, string>,
    reverseDeps: ReadonlyMap<string, readonly DepEdge[]>,
): DualDependencyRisk[] {
    const directNames = new Set(directConstraints.keys());
    const risks: DualDependencyRisk[] = [];

    for (const [name, constraint] of directConstraints) {
        const viaDirect = findDirectAncestors(name, reverseDeps, directNames);
        if (viaDirect.length === 0) { continue; }
        risks.push({
            packageName: name,
            directConstraint: constraint,
            sources: viaDirect.map(viaPackage => ({ viaPackage, viaConstraint: null })),
        });
    }

    return risks;
}

/**
 * Walk the reverse-dependency graph upward from `target`, collecting the
 * nearest OTHER direct dependency on each path that transitively requires
 * it. Stops walking past a direct-dep ancestor — its own further ancestors
 * are the project root, not another intermediate package worth reporting as
 * a distinct source. Cycle-safe via `visited`.
 */
function findDirectAncestors(
    target: string,
    reverseDeps: ReadonlyMap<string, readonly DepEdge[]>,
    directNames: ReadonlySet<string>,
): string[] {
    const found = new Set<string>();
    const visited = new Set<string>([target]);
    const queue = (reverseDeps.get(target) ?? []).map(e => e.dependentPackage);

    while (queue.length > 0) {
        const current = queue.shift();
        if (current === undefined || visited.has(current)) { continue; }
        visited.add(current);

        if (directNames.has(current) && current !== target) {
            found.add(current);
            continue;
        }

        for (const edge of reverseDeps.get(current) ?? []) {
            if (!visited.has(edge.dependentPackage)) {
                queue.push(edge.dependentPackage);
            }
        }
    }

    return [...found];
}

/**
 * Fill in each source's `viaConstraint` from a constraint index built by
 * reading the via-packages' own pubspec.yaml (see `buildConstraintIndex`).
 * Kept as a separate pure step so this module stays free of pub-cache I/O.
 */
export function attachViaConstraints(
    risks: readonly DualDependencyRisk[],
    constraintIndex: ReadonlyMap<string, ReadonlyMap<string, string>>,
): DualDependencyRisk[] {
    return risks.map(risk => ({
        ...risk,
        sources: risk.sources.map(source => ({
            ...source,
            viaConstraint: constraintIndex.get(source.viaPackage)
                ?.get(risk.packageName) ?? null,
        })),
    }));
}
