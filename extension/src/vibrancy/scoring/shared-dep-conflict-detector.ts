/**
 * Detects diamond / shared-transitive-dependency upgrade conflicts.
 *
 * The reverse-dependency walk in `blocker-analyzer` only explains blocks of the
 * form "B depends on A, B's constraint holds A back". It cannot explain the
 * common SIBLING conflict: two direct deps both depend on a shared transitive
 * dep T, and one sibling caps T below the version the other needs at its latest.
 * That is why `analyzer` / `meta` blocks (e.g. `dart_style` held back because
 * `saropa_lints` caps `analyzer <13`) showed up as unexplained "constrained"
 * rows with no named blocker. This module finds the pivot dep T and attributes
 * the block to the sibling whose constraint is the binding ceiling.
 *
 * Pure — no I/O, no VS Code API. Constraint ranges are supplied by the caller
 * (read from the pub cache) because `dart pub deps --json` does not expose them.
 */

import { PubOutdatedEntry, DepEdge } from '../types';
import * as semver from 'semver';

/** One detected shared-transitive-dependency conflict. */
export interface SharedDepConflict {
    readonly blockedPackage: string;
    readonly currentVersion: string;
    readonly latestVersion: string;
    /** The shared transitive dep both packages need (e.g. "analyzer"). */
    readonly sharedDependency: string;
    /** Highest shared-dep version pub can resolve under current constraints. */
    readonly sharedResolvable: string;
    /** Latest published shared-dep version. */
    readonly sharedLatest: string;
    /** The sibling whose constraint is the binding ceiling (e.g. "saropa_lints"). */
    readonly constrainerPackage: string;
    /** The constraint that sibling places on the shared dep (e.g. ">=9.0.0 <13.0.0"). */
    readonly constrainerConstraint: string;
}

/** Constraint each package declares on each dependency: pkg -> (dep -> range). */
export type ConstraintIndex = ReadonlyMap<string, ReadonlyMap<string, string>>;

/** True when pub cannot lift the package to its latest under current constraints. */
function isBlocked(entry: PubOutdatedEntry): boolean {
    return !!entry.resolvable && !!entry.latest
        && entry.resolvable !== entry.latest;
}

/** Names of packages that depend on `dep`, from the reverse-dependency graph. */
function dependentsOf(
    dep: string,
    reverseDeps: ReadonlyMap<string, readonly DepEdge[]>,
): string[] {
    return (reverseDeps.get(dep) ?? []).map(e => e.dependentPackage);
}

/**
 * Shared transitive deps that are blocked AND depended on by 2+ packages —
 * the pivots a diamond conflict turns on. Keyed by dep name.
 */
function findContestedSharedDeps(
    outdated: readonly PubOutdatedEntry[],
    reverseDeps: ReadonlyMap<string, readonly DepEdge[]>,
): Map<string, PubOutdatedEntry> {
    const contested = new Map<string, PubOutdatedEntry>();
    for (const entry of outdated) {
        if (!isBlocked(entry)) { continue; }
        if (dependentsOf(entry.package, reverseDeps).length < 2) { continue; }
        contested.set(entry.package, entry);
    }
    return contested;
}

/**
 * Is `constraint` the binding ceiling on the shared dep? Binding means it
 * permits the resolved version but excludes the latest — i.e. it is exactly
 * what stops the upgrade, not a looser range that allows both.
 */
function isBindingCeiling(
    constraint: string, resolvable: string, latest: string,
): boolean {
    const range = semver.validRange(constraint.replace(/["']/g, '').trim());
    const lo = semver.coerce(resolvable);
    const hi = semver.coerce(latest);
    if (!range || !lo || !hi) { return false; }
    return semver.satisfies(lo.version, range)
        && !semver.satisfies(hi.version, range);
}

/**
 * Among the siblings that depend on shared dep T, find the one whose
 * constraint is the binding ceiling. Prefers direct deps so the reported
 * blocker is one the user can actually act on.
 */
function findConstrainer(
    sharedDep: PubOutdatedEntry,
    excludePackage: string,
    reverseDeps: ReadonlyMap<string, readonly DepEdge[]>,
    constraints: ConstraintIndex,
    directDeps: ReadonlySet<string>,
): string | null {
    let fallback: string | null = null;
    for (const candidate of dependentsOf(sharedDep.package, reverseDeps)) {
        if (candidate === excludePackage) { continue; }
        const constraint = constraints.get(candidate)?.get(sharedDep.package);
        if (!constraint) { continue; }
        if (!isBindingCeiling(
            constraint, sharedDep.resolvable!, sharedDep.latest!,
        )) { continue; }
        if (directDeps.has(candidate)) { return candidate; }
        fallback ??= candidate;
    }
    return fallback;
}

/**
 * Detect diamond conflicts for blocked direct deps. For each blocked direct
 * dep P, find a contested shared dep T that P depends on and the sibling that
 * binds T's ceiling; emit one conflict per blocked package (first match wins).
 */
export function detectSharedDepConflicts(
    outdated: readonly PubOutdatedEntry[],
    reverseDeps: ReadonlyMap<string, readonly DepEdge[]>,
    constraints: ConstraintIndex,
    directDeps: ReadonlySet<string>,
): SharedDepConflict[] {
    const contested = findContestedSharedDeps(outdated, reverseDeps);
    if (contested.size === 0) { return []; }

    const conflicts: SharedDepConflict[] = [];
    for (const entry of outdated) {
        if (!isBlocked(entry) || !directDeps.has(entry.package)) { continue; }
        for (const [name, shared] of contested) {
            if (!dependentsOf(name, reverseDeps).includes(entry.package)) {
                continue;
            }
            const constrainer = findConstrainer(
                shared, entry.package, reverseDeps, constraints, directDeps,
            );
            if (!constrainer) { continue; }
            conflicts.push({
                blockedPackage: entry.package,
                currentVersion: entry.current ?? '',
                latestVersion: entry.latest ?? '',
                sharedDependency: name,
                sharedResolvable: shared.resolvable ?? '',
                sharedLatest: shared.latest ?? '',
                constrainerPackage: constrainer,
                constrainerConstraint:
                    constraints.get(constrainer)?.get(name) ?? '',
            });
            break;
        }
    }
    return conflicts;
}
