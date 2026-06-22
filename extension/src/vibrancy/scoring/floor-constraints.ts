/**
 * Detects floor (required-minimum) constraints — the opposite of the ceiling
 * blocks the diamond detector finds.
 *
 * A ceiling caps a dependency BELOW its latest ("dart_style held back because a
 * sibling caps analyzer <13"). A floor forces a dependency UP to a minimum
 * ("timezone ^0.11.0 is required because device_calendar depends on it"). The
 * upgrade-blocker pipeline only reasons about ceilings, so a forced minimum —
 * common with git dependencies that declare aggressive lower bounds — was never
 * explained. This module finds the dependent whose declared lower bound sets the
 * binding floor on a shared dep, so the requirement can be documented against
 * the package that imposes it.
 *
 * Pure — no I/O, no VS Code API. Constraint ranges come from the caller's index
 * (read from the pub cache); the reverse-dep graph comes from
 * `dart pub deps --json`.
 */

import { DepEdge } from '../types';
import { ConstraintIndex } from './shared-dep-conflict-detector';
import { pathToDirectDep, formatChain } from './constraint-chain';
import * as semver from 'semver';

/** A required-minimum constraint forcing a dependency up to a floor version. */
export interface FloorConstraint {
    /** The dependency whose minimum is forced (e.g. "timezone"). */
    readonly dependency: string;
    /** Package whose lower bound sets the binding floor (e.g. "device_calendar"). */
    readonly constrainer: string;
    /** That package's declared constraint (e.g. "^0.11.0"). */
    readonly constraint: string;
    /** The minimum version the constraint forces (e.g. "0.11.0"). */
    readonly floorVersion: string;
    /**
     * Path from a user-actionable direct dep down to the constrainer, when the
     * constrainer is buried transitively; null when it is itself direct.
     */
    readonly chain: readonly string[] | null;
}

/** The lower bound a constraint imposes, or null when it sets no minimum. */
function lowerBound(constraint: string): semver.SemVer | null {
    const range = semver.validRange(constraint.replace(/["']/g, '').trim());
    if (!range) { return null; }
    // minVersion returns null for an empty/`*` range (no floor) and the smallest
    // satisfying version otherwise — exactly the floor a constraint forces.
    return semver.minVersion(range);
}

/**
 * Among the packages depending on `dependency`, the one whose declared lower
 * bound is the highest — the binding floor. Returns null when no dependent
 * declares a readable lower-bounded constraint (e.g. all are `any` or
 * unreadable). Ties resolve to the first dependent encountered; the floor
 * version is identical either way.
 */
export function findFloorConstrainer(
    dependency: string,
    reverseDeps: ReadonlyMap<string, readonly DepEdge[]>,
    constraints: ConstraintIndex,
    directDeps: ReadonlySet<string>,
): FloorConstraint | null {
    let best: { name: string; constraint: string; floor: semver.SemVer } | null = null;

    for (const edge of reverseDeps.get(dependency) ?? []) {
        const dependent = edge.dependentPackage;
        const constraint = constraints.get(dependent)?.get(dependency);
        if (!constraint) { continue; }

        const floor = lowerBound(constraint);
        if (!floor) { continue; }

        // Keep the highest lower bound: that is the constraint pub must honor to
        // satisfy everyone, i.e. the one that actually forces the floor.
        if (!best || semver.gt(floor, best.floor)) {
            best = { name: dependent, constraint, floor };
        }
    }

    if (!best) { return null; }

    const chain = pathToDirectDep(best.name, reverseDeps, directDeps);
    return {
        dependency,
        constrainer: best.name,
        constraint: best.constraint,
        floorVersion: best.floor.version,
        chain: chain.length > 1 ? chain : null,
    };
}

/**
 * Plain-text reason for a forced minimum, e.g. "required by device_calendar
 * (^0.11.0)" — and "required by … [via A → B → C]" when the constrainer is a
 * deep transitive dep. Mirrors the diamond-block detail voice so the report and
 * the pubspec annotation read consistently.
 */
export function formatFloorRequirement(floor: FloorConstraint): string {
    const parts = [`required by ${floor.constrainer} (${floor.constraint})`];
    const chain = formatChain(floor.chain ?? []);
    if (chain) { parts.push(`[via ${chain}]`); }
    return parts.join(' ');
}
