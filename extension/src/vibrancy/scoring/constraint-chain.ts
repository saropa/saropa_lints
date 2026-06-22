/**
 * Resolves the dependency path from a deep constrainer up to a user-actionable
 * direct dependency.
 *
 * The diamond detector and the reverse-dependency walk both attribute a block
 * to a single dependent, one hop from the contested dep. But the package whose
 * declared range actually caps a shared dep is often buried deeper: the user's
 * direct dep A pulls in B, which pulls in C, and C is the one capping `analyzer`.
 * Reporting "C caps analyzer" alone is not actionable — C is nowhere in the
 * user's pubspec.yaml. This module walks the reverse-dependency graph upward
 * from C to the nearest direct dep A, yielding the chain A -> B -> C so the
 * block can be explained against a line the user can actually edit.
 *
 * Pure — no I/O, no VS Code API. The reverse-dep graph is supplied by the
 * caller (built from `dart pub deps --json`).
 */

import { DepEdge } from '../types';

/**
 * Package path from the nearest direct dependency down to `start`, as
 * `[directDep, …, start]`. Returns `[start]` when `start` is itself a direct
 * dep or has no direct ancestor (an orphaned transitive). BFS so the first
 * direct dep reached is the shortest, most relevant chain; a visited set guards
 * against the cycles `dart pub deps` graphs can contain.
 */
export function pathToDirectDep(
    start: string,
    reverseDeps: ReadonlyMap<string, readonly DepEdge[]>,
    directDeps: ReadonlySet<string>,
): string[] {
    if (directDeps.has(start)) { return [start]; }

    // parent[next] = the dependency `next` was reached through, so the chain can
    // be reconstructed once a direct dep is found. visited prevents a dependency
    // cycle from looping the walk forever.
    const parent = new Map<string, string>();
    const visited = new Set<string>([start]);
    const queue: string[] = [start];

    while (queue.length > 0) {
        const node = queue.shift();
        if (node === undefined) { break; }

        // reverseDeps.get(node) = packages that depend on `node`, i.e. one hop
        // closer to a direct dep.
        for (const edge of reverseDeps.get(node) ?? []) {
            const next = edge.dependentPackage;
            if (visited.has(next)) { continue; }
            visited.add(next);
            parent.set(next, node);
            if (directDeps.has(next)) {
                return reconstruct(next, start, parent);
            }
            queue.push(next);
        }
    }

    return [start];
}

/**
 * Rebuild the `[directDep, …, start]` chain by following parent links from the
 * direct dep back down to the constrainer. A broken link (should not happen
 * once a direct dep is found) stops the walk rather than looping.
 */
function reconstruct(
    directDep: string,
    start: string,
    parent: ReadonlyMap<string, string>,
): string[] {
    const chain: string[] = [directDep];
    let cursor = directDep;
    while (cursor !== start) {
        const next = parent.get(cursor);
        if (next === undefined) { break; }
        chain.push(next);
        cursor = next;
    }
    return chain;
}

/**
 * Human-readable chain like `A → B → C`, or null when the chain is a single
 * node (the constrainer is itself a direct dep, so there is no path to show).
 */
export function formatChain(chain: readonly string[]): string | null {
    if (chain.length < 2) { return null; }
    return chain.join(' → ');
}
