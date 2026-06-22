/**
 * Assembles the per-package constraint-explanation notes the pubspec annotator
 * writes — the analyzer's answer to the `Because …` lines users paste by hand.
 *
 * Three explanation classes feed in, each from its own detector:
 *  - ceiling: a shared dep held below its latest (diamond block), already
 *    enriched onto each result's `blocker` during the scan;
 *  - floor: a dependency forced up to a required minimum (findFloorConstrainer);
 *  - forbidden: a declared constraint that excludes an SDK pin
 *    (detectForbiddenConstraints).
 *
 * Notes are emitted only for `targetNames` (the direct deps actually written in
 * pubspec.yaml), so transitive packages — which have no line to annotate — are
 * skipped. Pure: no I/O, no VS Code API.
 */

import { VibrancyResult } from '../types';
import { formatSharedDepDetail } from './blocker-analyzer';
import { FloorConstraint, formatFloorRequirement } from './floor-constraints';
import { ForbiddenConstraint, formatForbiddenConstraint } from './forbidden-constraints';

/**
 * Map of package name -> ordered explanation lines (held-back, then forbidden,
 * then required-by). A package with no constraint story is absent from the map.
 */
export function buildConstraintNotes(
    results: readonly VibrancyResult[],
    floors: readonly FloorConstraint[],
    forbiddens: readonly ForbiddenConstraint[],
    targetNames: ReadonlySet<string>,
): Map<string, string[]> {
    const notes = new Map<string, string[]>();

    const add = (pkg: string, line: string): void => {
        if (!targetNames.has(pkg)) { return; }
        const list = notes.get(pkg) ?? [];
        list.push(line);
        notes.set(pkg, list);
    };

    // Ceiling blocks: only diamond/shared-dep blocks carry a chain worth
    // documenting; ordinary reverse-dep blockers return null and are skipped.
    for (const r of results) {
        if (!r.blocker) { continue; }
        const detail = formatSharedDepDetail(r.blocker);
        if (detail) { add(r.package.name, `held back — ${detail}`); }
    }

    for (const f of forbiddens) { add(f.package, formatForbiddenConstraint(f)); }
    for (const f of floors) { add(f.dependency, formatFloorRequirement(f)); }

    return notes;
}
