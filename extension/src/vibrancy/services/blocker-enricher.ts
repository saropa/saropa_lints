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
import { fetchDepGraph, buildReverseDeps } from './dep-graph';
import { findBlockers, classifyUpgradeStatus } from '../scoring/blocker-analyzer';
import {
    detectSharedDepConflicts, SharedDepConflict,
} from '../scoring/shared-dep-conflict-detector';
import { buildConstraintIndex } from './shared-dep-constraints';

/** Result of blocker enrichment: enriched results + reverse dep graph. */
export interface BlockerEnrichResult {
    readonly results: VibrancyResult[];
    readonly reverseDeps: ReadonlyMap<string, readonly DepEdge[]>;
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
        return { results, reverseDeps: new Map() };
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
    return { results: enriched, reverseDeps };
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
        blockerMap.set(c.blockedPackage, toBlockerInfo(c, resultMap));
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
): BlockerInfo {
    const constrainerResult = resultMap.get(conflict.constrainerPackage);
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
    };
}
