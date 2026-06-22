/**
 * Detects hard-incompatibility (forbidden) constraints — a directly-declared
 * constraint that cannot coexist with a Flutter/Dart SDK pin.
 *
 * The diamond detector explains "held back" (a dependency capped below its
 * latest) and the floor detector explains "forced up." This is a third class:
 * the user declares `characters: ^1.4.1`, but `flutter_test` (an SDK package)
 * pins `characters 1.4.0` exactly. The two ranges have no overlap, so pub's own
 * solver calls the SDK package "forbidden." In a successfully-resolved project
 * this state survives only because an override forces the SDK-pinned version,
 * leaving the declared constraint quietly broken — it reads as satisfiable but
 * is not. Surfacing it tells the user the declared constraint is wrong, not the
 * override.
 *
 * The SDK pin is opaque (no readable range), so the pinned version is taken from
 * the resolved graph: for an SDK-transitive dep the resolved version IS what the
 * SDK forced. A mismatch is only attributed to the SDK — a hosted sibling with
 * an excluding constraint would have failed resolution outright rather than
 * silently winning, so it cannot produce this "resolved yet excluded" state.
 *
 * Pure — no I/O, no VS Code API.
 */

import { DepEdge } from '../types';
import * as semver from 'semver';

/** A declared constraint that conflicts with an SDK package's pin. */
export interface ForbiddenConstraint {
    /** The directly-declared package whose constraint cannot hold. */
    readonly package: string;
    /** The constraint the root pubspec declares (e.g. "^1.4.1"). */
    readonly declaredConstraint: string;
    /** The version actually pinned — the resolved version the SDK forces. */
    readonly pinnedVersion: string;
    /** The SDK package whose pin the declared constraint conflicts with. */
    readonly pinnedBy: string;
}

/** True when `version` falls inside `constraint`; defensively true when either is unparseable. */
function satisfies(version: string, constraint: string): boolean {
    const cleaned = constraint.replace(/["']/g, '').trim();
    if (cleaned === '' || cleaned === 'any') { return true; }

    const range = semver.validRange(cleaned);
    const coerced = semver.coerce(version);
    // Unparseable input must not be reported as forbidden — only emit when we
    // can prove the declared range genuinely excludes the pinned version.
    if (!range || !coerced) { return true; }
    return semver.satisfies(coerced.version, range);
}

/**
 * Direct dependencies whose declared constraint excludes the version an SDK
 * package pins them to. Each is a latent resolution failure (forbidden by pub's
 * solver) currently masked by an override.
 */
export function detectForbiddenConstraints(
    directConstraints: ReadonlyMap<string, string>,
    resolvedVersions: ReadonlyMap<string, string>,
    reverseDeps: ReadonlyMap<string, readonly DepEdge[]>,
    sdkPackages: ReadonlySet<string>,
): ForbiddenConstraint[] {
    const forbidden: ForbiddenConstraint[] = [];

    for (const [pkg, constraint] of directConstraints) {
        const resolved = resolvedVersions.get(pkg);
        if (!resolved) { continue; }

        // Only an SDK pin can force a package to a version the user's own
        // declared constraint excludes while still resolving.
        const sdkPinner = (reverseDeps.get(pkg) ?? [])
            .map(e => e.dependentPackage)
            .find(d => sdkPackages.has(d));
        if (!sdkPinner) { continue; }

        if (!satisfies(resolved, constraint)) {
            forbidden.push({
                package: pkg,
                declaredConstraint: constraint,
                pinnedVersion: resolved,
                pinnedBy: sdkPinner,
            });
        }
    }

    return forbidden;
}

/**
 * Plain-text explanation of a forbidden constraint, mirroring pub's own
 * "is forbidden" phrasing: "your `characters ^1.4.1` is incompatible with
 * flutter_test (Flutter SDK), which pins characters 1.4.0".
 */
export function formatForbiddenConstraint(f: ForbiddenConstraint): string {
    return `your ${f.package} ${f.declaredConstraint} is incompatible with `
        + `${f.pinnedBy} (Flutter SDK), which pins ${f.package} ${f.pinnedVersion}`;
}
