/**
 * Detects cross-project version drift — the same package pinned at a different
 * major in a configured sibling repo.
 *
 * pub-outdated only sees ONE workspace, so it cannot tell that this project
 * holds `saropa_lints ^9.7.0` while a sibling is on `^13.12.7`. That divergence
 * is an implicit upgrade blocker: the lagging consumer is stuck on an old major
 * whose bump may need a floor (analyzer/meta) this project's other pins forbid.
 * Comparing majors across configured siblings surfaces it.
 *
 * Pure — sibling constraints are supplied by the caller (read from disk).
 */

import { CrossProjectDrift, SiblingConstraint } from '../types';
import * as semver from 'semver';

/** Sibling constraint maps: repo label -> (package -> constraint range). */
export type SiblingConstraints = ReadonlyMap<string, ReadonlyMap<string, string>>;

/** A package result the detector compares (name + this project's constraint). */
interface DriftCandidate {
    readonly package: { readonly name: string; readonly constraint: string };
}

/** Major version of a constraint range, or null when it can't be coerced. */
function majorOf(constraint: string): number | null {
    const coerced = semver.coerce(constraint.replace(/["']/g, '').trim());
    return coerced ? coerced.major : null;
}

/**
 * Compare one package's own constraint against every sibling's. Returns the
 * divergent siblings (different major) and whether any is ahead, or null when
 * no sibling declares the package or none diverges.
 */
function driftForPackage(
    name: string,
    ownConstraint: string,
    siblings: SiblingConstraints,
): CrossProjectDrift | null {
    const ownMajor = majorOf(ownConstraint);
    if (ownMajor === null) { return null; }

    const divergent: SiblingConstraint[] = [];
    let behind = false;
    for (const [repo, constraints] of siblings) {
        const sibConstraint = constraints.get(name);
        if (!sibConstraint) { continue; }
        const sibMajor = majorOf(sibConstraint);
        if (sibMajor === null || sibMajor === ownMajor) { continue; }
        divergent.push({ repo, constraint: sibConstraint });
        if (sibMajor > ownMajor) { behind = true; }
    }
    if (divergent.length === 0) { return null; }
    return { ownConstraint, siblings: divergent, behind };
}

/**
 * Detect drift for every candidate package. Returns a map from package name to
 * its drift; packages with no divergent sibling are absent.
 */
export function detectVersionDrift(
    results: readonly DriftCandidate[],
    siblings: SiblingConstraints,
): Map<string, CrossProjectDrift> {
    const drift = new Map<string, CrossProjectDrift>();
    if (siblings.size === 0) { return drift; }
    for (const r of results) {
        const d = driftForPackage(r.package.name, r.package.constraint, siblings);
        if (d) { drift.set(r.package.name, d); }
    }
    return drift;
}

/**
 * Attach cross-project drift to scan results. Returns a new array; results with
 * no drift get `crossProjectDrift: null`.
 */
export function attachVersionDrift<T extends DriftCandidate>(
    results: readonly T[],
    siblings: SiblingConstraints,
): Array<T & { crossProjectDrift: CrossProjectDrift | null }> {
    const drift = detectVersionDrift(results, siblings);
    return results.map(r => ({
        ...r,
        crossProjectDrift: drift.get(r.package.name) ?? null,
    }));
}
