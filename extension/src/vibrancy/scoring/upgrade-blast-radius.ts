/**
 * Computes what upgrading a package `from -> to` would break, so the advisor
 * can suppress or annotate a "newer version available" nudge.
 *
 * pub.dev's latest is not always adoptable: analyzer 13 needs `meta ^1.18.3`
 * while Flutter stable pins `meta 1.18.0`, and several dependents cap analyzer
 * below 13. Three independent signals are combined, in precedence order
 * held-back > sdk-blocked > breaks-dependents > safe:
 *   - a curated held-back entry matching the target version,
 *   - a target dependency range that excludes a version pinned by the SDK,
 *   - dependents whose declared range on the package excludes the target.
 *
 * Pure — no I/O, no VS Code API. All graph and version data is supplied by the
 * caller.
 */

import * as semver from 'semver';
import { DepEdge } from '../types';
import { ConstraintIndex } from './shared-dep-conflict-detector';
import { pathToDirectDep } from './constraint-chain';
import { HeldBackEntry } from './held-back-upgrades';

export type BlastVerdict = 'safe' | 'breaks-dependents' | 'sdk-blocked' | 'held-back';

export interface BlastBreaker {
    /** Dependent whose range excludes the target. */
    readonly name: string;
    /** Its declared range on the package. */
    readonly constraint: string;
    /** Path from a direct dep (null when the breaker is itself direct). */
    readonly chain: readonly string[] | null;
    /** True/false when the breaker's own latest is known, else null. */
    readonly fixedInLatest: boolean | null;
}

export interface BlastRadius {
    readonly pkg: string;
    readonly from: string;
    readonly to: string;
    readonly verdict: BlastVerdict;
    readonly breakers: readonly BlastBreaker[];
    /** Structured SDK conflict (formatted at the UI edge, see blast-radius-attacher). */
    readonly sdkBlock: SdkBlock | null;
    /** Curated maintainer explanation (data, not localized). */
    readonly heldBackReason: string | null;
    /** l10n key of the one-line summary; format with `describeBlastSummary`. */
    readonly summaryKey: BlastSummaryKey;
    /** Params for `summaryKey`; `sdk` is pre-formatted by the edge, never here. */
    readonly summaryParams: Readonly<Record<string, string | number>>;
}

/** A target dependency range that excludes an SDK-pinned version. */
export interface SdkBlock {
    readonly pkg: string;
    readonly to: string;
    readonly dep: string;
    readonly range: string;
    readonly pinned: string;
}

export type BlastSummaryKey =
    | 'blastRadius.summary.heldBack'
    | 'blastRadius.summary.sdkBlocked'
    | 'blastRadius.summary.breaksOne'
    | 'blastRadius.summary.breaksOther'
    | 'blastRadius.summary.safe';

export interface BlastRadiusInput {
    pkg: string;
    from: string;
    to: string;
    reverseDeps: ReadonlyMap<string, readonly DepEdge[]>;
    constraints: ConstraintIndex;
    /** Target version's own dependency ranges (e.g. meta). */
    targetDeps: ReadonlyMap<string, string> | null;
    /** Package -> exact version pinned by the SDK. */
    sdkPins: ReadonlyMap<string, string>;
    heldBack: readonly HeldBackEntry[];
    /** Dependents' latest versions. */
    latestOf?: ReadonlyMap<string, string>;
}

/** Strip quotes and whitespace, then validate; null when unparseable. */
function parseRange(raw: string): string | null {
    return semver.validRange(raw.replace(/["']/g, '').trim());
}

/** True only when both sides parse and `version` lies outside `rawRange`. */
function excludes(rawRange: string, version: string): boolean {
    const range = parseRange(rawRange);
    const v = toVersion(version);
    if (!range || !v) { return false; }
    return !semver.satisfies(v, range, { includePrerelease: true });
}

/** Exact parse first (keeps prerelease tags); coerce only as a fallback. */
function toVersion(raw: string): string | null {
    return semver.valid(raw.trim()) ?? semver.coerce(raw)?.version ?? null;
}

/** Held-back entry whose package and range cover the target version, if any. */
function findHeldBack(
    pkg: string, to: string, heldBack: readonly HeldBackEntry[],
): HeldBackEntry | null {
    const v = toVersion(to);
    if (!v) { return null; }
    for (const entry of heldBack) {
        if (entry.pkg !== pkg) { continue; }
        const range = parseRange(entry.range);
        if (range && semver.satisfies(v, range, { includePrerelease: true })) { return entry; }
    }
    return null;
}

/** First target dependency whose range excludes the SDK-pinned version. */
function findSdkBlock(
    pkg: string, to: string,
    targetDeps: ReadonlyMap<string, string> | null,
    sdkPins: ReadonlyMap<string, string>,
): SdkBlock | null {
    if (!targetDeps) { return null; }
    for (const [dep, range] of targetDeps) {
        const pinned = sdkPins.get(dep);
        if (pinned === undefined || !excludes(range, pinned)) { continue; }
        return { pkg, to, dep, range, pinned };
    }
    return null;
}

/**
 * Packages with no dependents of their own. The caller does not pass the
 * direct-dep set, so graph roots stand in for it when tracing a chain.
 */
const rootsCache = new WeakMap<object, Set<string>>();

function graphRoots(
    reverseDeps: ReadonlyMap<string, readonly DepEdge[]>,
): Set<string> {
    const cached = rootsCache.get(reverseDeps);
    if (cached) { return cached; }
    const roots = new Set<string>();
    for (const edges of reverseDeps.values()) {
        for (const edge of edges) {
            if ((reverseDeps.get(edge.dependentPackage) ?? []).length === 0) {
                roots.add(edge.dependentPackage);
            }
        }
    }
    rootsCache.set(reverseDeps, roots);
    return roots;
}

/** Dependents whose declared range on `pkg` excludes `to`. */
function findBreakers(input: BlastRadiusInput): BlastBreaker[] {
    let roots: Set<string> | null = null;
    const breakers: BlastBreaker[] = [];
    const seen = new Set<string>();
    for (const edge of input.reverseDeps.get(input.pkg) ?? []) {
        const name = edge.dependentPackage;
        if (seen.has(name)) { continue; }
        seen.add(name);
        const constraint = input.constraints.get(name)?.get(input.pkg);
        if (!constraint || !excludes(constraint, input.to)) { continue; }

        roots ??= graphRoots(input.reverseDeps);
        const path = pathToDirectDep(name, input.reverseDeps, roots);
        breakers.push({
            name,
            constraint,
            chain: path.length > 1 ? path : null,
            // latestOf carries only a version number, not that release's ranges,
            // so a fix cannot be confirmed from it; stay unknown, never guess.
            fixedInLatest: null,
        });
    }
    return breakers;
}

export function computeBlastRadius(input: BlastRadiusInput): BlastRadius {
    const { pkg, from, to } = input;
    const base = { pkg, from, to };

    const held = findHeldBack(pkg, to, input.heldBack);
    const sdkBlock = findSdkBlock(pkg, to, input.targetDeps, input.sdkPins);
    const breakers = findBreakers(input);

    const pkgTo = { pkg, to };
    if (held) {
        return {
            ...base, verdict: 'held-back', breakers, sdkBlock,
            heldBackReason: held.reason,
            summaryKey: 'blastRadius.summary.heldBack',
            summaryParams: { ...pkgTo, reason: held.reason },
        };
    }
    if (sdkBlock) {
        return {
            ...base, verdict: 'sdk-blocked', breakers, sdkBlock,
            heldBackReason: null,
            summaryKey: 'blastRadius.summary.sdkBlocked',
            summaryParams: { ...pkgTo },
        };
    }
    if (breakers.length > 0) {
        return {
            ...base, verdict: 'breaks-dependents', breakers, sdkBlock: null,
            heldBackReason: null,
            summaryKey: breakers.length === 1
                ? 'blastRadius.summary.breaksOne' : 'blastRadius.summary.breaksOther',
            summaryParams: {
                ...pkgTo, count: breakers.length,
                names: breakers.map(b => b.name).join(', '),
            },
        };
    }
    return {
        ...base, verdict: 'safe', breakers: [], sdkBlock: null,
        heldBackReason: null,
        summaryKey: 'blastRadius.summary.safe',
        summaryParams: { pkg, from, to },
    };
}
