/**
 * Computes what upgrading a package `from -> to` would break, so the advisor
 * can suppress or annotate a "newer version available" nudge.
 *
 * pub.dev's latest is not always adoptable: analyzer 13 needs `meta ^1.18.3`
 * while Flutter stable pins `meta 1.18.0`, and several dependents cap analyzer
 * below 13. Three independent signals are combined, in precedence order
 * held-back > sdk-blocked > dependency-held-back > breaks-dependents > safe:
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

export type BlastVerdict =
    'safe' | 'breaks-dependents' | 'dependency-held-back' | 'sdk-blocked' | 'held-back';

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
    /** Target dependency whose required range needs a held-back version. */
    readonly depHeldBack?: DepHeldBack | null;
    /** Curated maintainer explanation (data, not localized). */
    readonly heldBackReason: string | null;
    /** Newest release newer than `from` that is not blocked; set by the attacher. */
    readonly newestCompatible?: string | null;
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

/** A target dependency range that can only be met by a held-back version. */
export interface DepHeldBack {
    readonly dep: string;
    readonly range: string;
    readonly reason: string;
}

export type BlastSummaryKey =
    | 'blastRadius.summary.heldBack'
    | 'blastRadius.summary.sdkBlocked'
    | 'blastRadius.summary.depHeldBack'
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
    /** Package -> version currently locked (pubspec.lock); optional. */
    lockedVersions?: ReadonlyMap<string, string>;
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
 * First target dependency whose range needs a version inside a held-back range
 * (its minimum lies in the held range) and that the current lock does not
 * already satisfy. Held-back deps cannot be upgraded, so the range is unmeetable.
 */
function findDepHeldBack(
    targetDeps: ReadonlyMap<string, string> | null,
    heldBack: readonly HeldBackEntry[],
    locked: ReadonlyMap<string, string> | undefined,
): DepHeldBack | null {
    if (!targetDeps) { return null; }
    for (const [dep, rawRange] of targetDeps) {
        const range = parseRange(rawRange);
        if (!range) { continue; }
        const lock = locked?.get(dep);
        const lockV = lock ? toVersion(lock) : null;
        if (lockV && semver.satisfies(lockV, range, { includePrerelease: true })) { continue; }
        let min: semver.SemVer | null = null;
        try { min = semver.minVersion(range); } catch { min = null; }
        if (!min) { continue; }
        const entry = findHeldBack(dep, min.version, heldBack);
        if (entry) { return { dep, range: rawRange.replace(/["']/g, '').trim(), reason: entry.reason }; }
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
    const depHeld = findDepHeldBack(input.targetDeps, input.heldBack, input.lockedVersions);
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
    // After sdk-blocked (a hard platform limit) but before dependents: the
    // package's own requirements are unmeetable, so no dependent fix helps.
    if (depHeld) {
        return {
            ...base, verdict: 'dependency-held-back', breakers, sdkBlock: null,
            depHeldBack: depHeld, heldBackReason: depHeld.reason,
            summaryKey: 'blastRadius.summary.depHeldBack',
            summaryParams: { ...pkgTo, dep: depHeld.dep, range: depHeld.range, reason: depHeld.reason },
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

/** One published release: its version and dependency ranges. */
export interface VersionCandidate {
    readonly version: string;
    readonly deps: ReadonlyMap<string, string>;
    readonly retracted?: boolean;
}

/** Max candidate releases evaluated per package. */
export const MAX_COMPAT_CANDIDATES = 25;

/**
 * Newest release in (from, blockedTo) that computeBlastRadius rates safe.
 * Skips retracted releases and prereleases (unless `from` is a prerelease).
 * Pure; `base` supplies everything except the target version and its deps.
 */
export function findNewestCompatible(
    base: Omit<BlastRadiusInput, 'to' | 'targetDeps'>,
    blockedTo: string,
    versions: readonly VersionCandidate[],
): string | null {
    const fromV = toVersion(base.from);
    if (!fromV) { return null; }
    const allowPre = !!semver.prerelease(fromV);
    const cands = versions
        .filter(c => !c.retracted && semver.valid(c.version)
            && semver.gt(c.version, fromV) && semver.lt(c.version, toVersion(blockedTo) ?? blockedTo)
            && (allowPre || !semver.prerelease(c.version)))
        .sort((a, b) => semver.rcompare(a.version, b.version))
        .slice(0, MAX_COMPAT_CANDIDATES);
    for (const c of cands) {
        const r = computeBlastRadius({ ...base, to: c.version, targetDeps: c.deps });
        if (r.verdict === 'safe') { return c.version; }
    }
    return null;
}
