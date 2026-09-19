/**
 * Computes what upgrading a package `from -> to` would break, so the advisor
 * can suppress or annotate a "newer version available" nudge.
 *
 * pub.dev's latest is not always adoptable: analyzer 13 needs `meta ^1.18.3`
 * while Flutter stable pins `meta 1.18.0`, and several dependents cap analyzer
 * below 13. Three independent signals are combined, in precedence order
 * held-back > sdk-blocked > dependency-capped > dependency-held-back >
 * breaks-dependents > safe:
 *   - a curated held-back entry matching the target version,
 *   - a target dependency range that excludes a version pinned by the SDK,
 *   - dependency-capped (data-driven): the target needs dep D at a version the
 *     lock does not have, and another project package caps D below it,
 *   - dependency-held-back: same need, but decided only by the curated list,
 *   - dependents whose declared range on the package excludes the target.
 *
 * FALLBACK DECISION: the curated held-back list is a fallback for when the
 * data cannot decide. Self entries apply only when targetDeps is unknown or
 * there is no lock data; dependency entries apply per dep only when that
 * dep's locked version is unknown. When lock + ranges are available they
 * decide (e.g. analyzer needed at >=13, locked 12, nothing caps it: not
 * blocked, whatever the list says).
 *
 * Pure — no I/O, no VS Code API. All graph and version data is supplied by the
 * caller.
 */

import * as semver from 'semver';
import { DepEdge } from '../types';
import { ConstraintIndex } from './shared-dep-conflict-detector';
import { pathToDirectDep, formatChain } from './constraint-chain';
import { HeldBackEntry } from './held-back-upgrades';

export type BlastVerdict =
    'safe' | 'breaks-dependents' | 'dependency-held-back' | 'dependency-capped'
    | 'sdk-blocked' | 'held-back';

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
    /** Target dependency the project cannot raise because a dependent caps it. */
    readonly depCapped?: DepCapped | null;
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

/** A dependency the target needs, capped below the needed version by others. */
export interface DepCapped {
    readonly dep: string;
    /** Range the target requires of `dep`. */
    readonly range: string;
    /** `dep`'s currently locked version. */
    readonly locked: string;
    readonly cappers: readonly BlastBreaker[];
}

export type BlastSummaryKey =
    | 'blastRadius.summary.depCapped'
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
        // A known lock means the data decides (see findDepCapped); the curated
        // list is consulted only for deps whose locked version is unknown.
        if (lockV) { continue; }
        let min: semver.SemVer | null = null;
        try { min = semver.minVersion(range); } catch { min = null; }
        if (!min) { continue; }
        const entry = findHeldBack(dep, min.version, heldBack);
        if (entry) { return { dep, range: rawRange.replace(/["']/g, '').trim(), reason: entry.reason }; }
    }
    return null;
}

/**
 * Data-driven: first target dependency D whose required range the locked D
 * does not satisfy AND whose required minimum is excluded by the declared
 * range of some other dependent of D (excluding `pkg` itself, whose own range
 * is replaced by the upgrade). Those dependents cap D.
 */
function findDepCapped(input: BlastRadiusInput): DepCapped | null {
    const { targetDeps, lockedVersions: locked, reverseDeps, constraints } = input;
    if (!targetDeps || !locked) { return null; }
    let roots: Set<string> | null = null;
    for (const [dep, rawRange] of targetDeps) {
        const range = parseRange(rawRange);
        const lock = locked.get(dep);
        const lockV = lock ? toVersion(lock) : null;
        if (!range || !lockV || semver.satisfies(lockV, range, { includePrerelease: true })) { continue; }
        let min: semver.SemVer | null = null;
        try { min = semver.minVersion(range); } catch { min = null; }
        if (!min) { continue; }
        const cappers: BlastBreaker[] = [];
        const seen = new Set<string>();
        for (const edge of reverseDeps.get(dep) ?? []) {
            const name = edge.dependentPackage;
            if (name === input.pkg || seen.has(name)) { continue; }
            seen.add(name);
            const constraint = constraints.get(name)?.get(dep);
            if (!constraint || !excludes(constraint, min.version)) { continue; }
            roots ??= graphRoots(reverseDeps);
            const path = pathToDirectDep(name, reverseDeps, roots);
            cappers.push({
                name, constraint, chain: path.length > 1 ? path : null, fixedInLatest: null,
            });
        }
        if (cappers.length > 0) {
            return { dep, range: rawRange.replace(/["']/g, '').trim(), locked: lock!, cappers };
        }
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

    // Curated self entry is a fallback: skipped when target deps and lock are
    // both known, since then the data-driven checks below decide.
    const dataDecides = !!input.targetDeps && (input.lockedVersions?.size ?? 0) > 0;
    const held = dataDecides ? null : findHeldBack(pkg, to, input.heldBack);
    const sdkBlock = findSdkBlock(pkg, to, input.targetDeps, input.sdkPins);
    const depCapped = findDepCapped(input);
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
    if (depCapped) {
        return {
            ...base, verdict: 'dependency-capped', breakers, sdkBlock: null,
            depCapped, heldBackReason: null,
            summaryKey: 'blastRadius.summary.depCapped',
            summaryParams: {
                ...pkgTo, dep: depCapped.dep, range: depCapped.range,
                cappers: depCapped.cappers.map(c => {
                    const via = formatChain(c.chain ?? []);
                    return `${c.name} ${c.constraint}${via ? ` via ${via}` : ''}`;
                }).join(', '),
            },
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
