/**
 * Module overview (comment coverage pass).
 * comment-coverage: module overview (batch).
 *
 * Vibrancy UI experiment: scoring, providers, and webview assets.
 */

import * as vscode from 'vscode';
import {
    VibrancyResult, DepEdge, BlockerInfo, PubOutdatedEntry, PackageDependency,
} from '../types';
import { ScanLogger } from './scan-logger';
import { fetchPubOutdated } from './pub-outdated';
import { fetchDepGraph, buildReverseDeps, DepGraphPackage } from './dep-graph';
import { findBlockers, classifyUpgradeStatus } from '../scoring/blocker-analyzer';
import {
    detectSharedDepConflicts, SharedDepConflict,
} from '../scoring/shared-dep-conflict-detector';
import { pathToDirectDep } from '../scoring/constraint-chain';
import { findFloorConstrainer, FloorConstraint } from '../scoring/floor-constraints';
import {
    detectForbiddenConstraints, ForbiddenConstraint,
} from '../scoring/forbidden-constraints';
import { buildConstraintIndex } from './shared-dep-constraints';
import { extractPubConflictExplanation } from './pub-conflict-text';

/** Result of blocker enrichment: enriched results + reverse dep graph. */
export interface BlockerEnrichResult {
    readonly results: VibrancyResult[];
    readonly reverseDeps: ReadonlyMap<string, readonly DepEdge[]>;
    /** Required-minimum constraints on direct deps (for pubspec annotation). */
    readonly floors: readonly FloorConstraint[];
    /** Declared constraints that conflict with an SDK pin (for annotation). */
    readonly forbiddens: readonly ForbiddenConstraint[];
}

/** Enrich results with upgrade blocker info from dart pub CLI. */
export async function enrichWithBlockers(
    results: VibrancyResult[],
    workspaceRoot: vscode.Uri,
    logger: ScanLogger,
    deps: readonly PackageDependency[] = [],
): Promise<BlockerEnrichResult> {
    const cwd = workspaceRoot.fsPath;
    // SDK-sourced packages (flutter, flutter_test, …) pin exact transitive
    // versions opaquely; the diamond detector uses this set for its SDK-pin
    // fallback when no hosted constrainer is readable.
    const sdkPackages = new Set(
        deps.filter(d => d.source === 'sdk').map(d => d.name),
    );
    const [outdatedResult, depGraphResult] = await Promise.all([
        fetchPubOutdated(cwd),
        fetchDepGraph(cwd),
    ]);
    if (!outdatedResult.success || !depGraphResult.success) {
        // Surface the actual stderr so the "silent no-transitives"
        // failure mode (no Transitives column, Footprint toggle has
        // nothing to vary) is self-diagnosing from the log. Typical
        // causes: `dart` not on PATH, `.dart_tool/` missing because
        // `pub get` never ran, or permissions/sandbox issues.
        const reasons: string[] = [];
        if (!outdatedResult.success) {
            reasons.push(`pub outdated: ${outdatedResult.errorMessage ?? 'unknown error'}`);
        }
        if (!depGraphResult.success) {
            reasons.push(`pub deps: ${depGraphResult.errorMessage ?? 'unknown error'}`);
        }
        logger.error(
            `Blocker analysis skipped — CLI commands failed — ${reasons.join(' | ')}`,
        );
        // When pub failed on a version conflict, surface its own authoritative
        // "Because … is forbidden / is required" reasoning verbatim — the
        // reconstruction detectors cannot run without a resolved graph, so this
        // is the only place the real cause is available.
        const pubExplanation = extractPubConflictExplanation(
            `${outdatedResult.errorMessage ?? ''}\n${depGraphResult.errorMessage ?? ''}`,
        );
        if (pubExplanation.length > 0) {
            logger.error(
                `pub version-solving conflict:\n${pubExplanation.join('\n')}`,
            );
        }
        return { results, reverseDeps: new Map(), floors: [], forbiddens: [] };
    }

    const reverseDeps = buildReverseDeps(depGraphResult.packages);
    const directNames = new Set(results.map(r => r.package.name));
    const blockers = findBlockers(
        outdatedResult.entries, reverseDeps, results, directNames,
    );
    const blockerMap = new Map(
        blockers.map(b => [b.blockedPackage, b]),
    );

    // Diamond-conflict pass: explains blocks the reverse-dep walk above can
    // never see (a sibling capping a shared transitive dep). It takes priority
    // for the packages it covers because for exactly those the reverse-dep walk
    // returns the wrong blocker or none.
    await mergeSharedDepConflicts(
        outdatedResult.entries, reverseDeps, directNames,
        results, workspaceRoot, blockerMap, logger, sdkPackages,
    );

    const outdatedMap = new Map(
        outdatedResult.entries.map(e => [e.package, e]),
    );

    const enriched = results.map(r => {
        const entry = outdatedMap.get(r.package.name);
        const status = entry
            ? classifyUpgradeStatus(entry) : 'up-to-date';
        return {
            ...r,
            blocker: blockerMap.get(r.package.name) ?? null,
            upgradeBlockStatus: status,
            // A `constrained` row is capped by the user's own constraint; name
            // the line and the version it would otherwise reach so the reason
            // is actionable instead of a bare label.
            constrainedReason: status === 'constrained' && entry
                ? {
                    constraint: r.package.constraint,
                    resolvable: entry.resolvable ?? '',
                    latest: entry.latest ?? '',
                }
                : null,
        };
    });

    // Floor (required-minimum) and forbidden (declared-vs-SDK-pin) findings for
    // the direct deps, for the pubspec annotator. Computed here because this is
    // where the resolved graph, reverse deps, and SDK set already live.
    const { floors, forbiddens } = await computeConstraintFindings(
        depGraphResult.packages, reverseDeps, directNames, deps,
        sdkPackages, workspaceRoot,
    );

    return { results: enriched, reverseDeps, floors, forbiddens };
}

/**
 * Floor and forbidden constraint findings for the direct dependencies.
 *
 * Forbidden detection is free — it reads the already-resolved versions and the
 * declared direct constraints. Floor detection needs each constrainer's
 * declared lower bound, so it reads the pubspecs of the packages depending on a
 * direct dep (bounded to that set to keep pub-cache I/O off the full graph).
 */
async function computeConstraintFindings(
    graphPackages: readonly DepGraphPackage[],
    reverseDeps: ReadonlyMap<string, readonly DepEdge[]>,
    directNames: ReadonlySet<string>,
    deps: readonly PackageDependency[],
    sdkPackages: ReadonlySet<string>,
    workspaceRoot: vscode.Uri,
): Promise<{ floors: FloorConstraint[]; forbiddens: ForbiddenConstraint[] }> {
    const resolvedVersions = new Map(graphPackages.map(p => [p.name, p.version]));
    const directConstraints = new Map(
        deps.filter(d => d.isDirect).map(d => [d.name, d.constraint]),
    );

    const forbiddens = detectForbiddenConstraints(
        directConstraints, resolvedVersions, reverseDeps, sdkPackages,
    );

    // Floor constrainers are the packages depending on a direct dep.
    const floorCandidates = new Set<string>();
    for (const dep of directNames) {
        for (const edge of reverseDeps.get(dep) ?? []) {
            floorCandidates.add(edge.dependentPackage);
        }
    }
    const constraintIndex = await buildConstraintIndex(
        workspaceRoot, floorCandidates,
    );

    const floors: FloorConstraint[] = [];
    for (const dep of directNames) {
        const floor = findFloorConstrainer(
            dep, reverseDeps, constraintIndex, directNames,
        );
        if (floor) { floors.push(floor); }
    }

    return { floors, forbiddens };
}

/**
 * Detect shared-transitive-dependency conflicts and fold them into blockerMap.
 * Reads constrainer pubspecs only for packages that depend on a contested
 * shared dep, keeping pub-cache I/O bounded to the relevant subgraph.
 */
async function mergeSharedDepConflicts(
    outdated: readonly PubOutdatedEntry[],
    reverseDeps: ReadonlyMap<string, readonly DepEdge[]>,
    directNames: ReadonlySet<string>,
    results: readonly VibrancyResult[],
    workspaceRoot: vscode.Uri,
    blockerMap: Map<string, BlockerInfo>,
    logger: ScanLogger,
    sdkPackages: ReadonlySet<string>,
): Promise<void> {
    const candidates = collectConstrainerCandidates(outdated, reverseDeps);
    if (candidates.size === 0) { return; }

    const constraints = await buildConstraintIndex(workspaceRoot, candidates);
    const conflicts = detectSharedDepConflicts(
        outdated, reverseDeps, constraints, directNames, sdkPackages,
    );
    if (conflicts.length === 0) { return; }

    const resultMap = new Map(results.map(r => [r.package.name, r]));
    for (const c of conflicts) {
        blockerMap.set(
            c.blockedPackage,
            toBlockerInfo(c, resultMap, reverseDeps, directNames),
        );
    }
    logger.info(
        `Shared-dependency conflicts detected: ${conflicts.length} `
        + `(${conflicts.map(c => `${c.blockedPackage} via ${c.sharedDependency}`).join(', ')})`,
    );
}

/**
 * Packages that depend on a blocked, shared (2+ dependents) transitive dep —
 * the only packages whose pubspec constraints can name a diamond blocker.
 */
function collectConstrainerCandidates(
    outdated: readonly PubOutdatedEntry[],
    reverseDeps: ReadonlyMap<string, readonly DepEdge[]>,
): Set<string> {
    const candidates = new Set<string>();
    for (const entry of outdated) {
        const blocked = !!entry.resolvable && !!entry.latest
            && entry.resolvable !== entry.latest;
        if (!blocked) { continue; }
        const dependents = reverseDeps.get(entry.package) ?? [];
        if (dependents.length < 2) { continue; }
        for (const edge of dependents) {
            candidates.add(edge.dependentPackage);
        }
    }
    return candidates;
}

/** Convert a detected conflict into a BlockerInfo, enriched from scan results. */
function toBlockerInfo(
    conflict: SharedDepConflict,
    resultMap: ReadonlyMap<string, VibrancyResult>,
    reverseDeps: ReadonlyMap<string, readonly DepEdge[]>,
    directDeps: ReadonlySet<string>,
): BlockerInfo {
    const constrainerResult = resultMap.get(conflict.constrainerPackage);
    // When the constrainer is buried in the transitive graph, record the path
    // up to a direct dep so the block can be explained against an editable line.
    // Single-node chains (constrainer is itself direct) carry no extra info.
    const chain = pathToDirectDep(
        conflict.constrainerPackage, reverseDeps, directDeps,
    );
    return {
        blockedPackage: conflict.blockedPackage,
        currentVersion: conflict.currentVersion,
        latestVersion: conflict.latestVersion,
        blockerPackage: conflict.constrainerPackage,
        blockerVibrancyScore: constrainerResult?.score ?? null,
        blockerCategory: constrainerResult?.category ?? null,
        sharedDependency: conflict.sharedDependency,
        sharedDependencyResolvable: conflict.sharedResolvable,
        sharedDependencyLatest: conflict.sharedLatest,
        blockerConstraint: conflict.constrainerConstraint,
        blockerIsSdkPin: conflict.viaSdk,
        blockerChain: chain.length > 1 ? chain : null,
    };
}
