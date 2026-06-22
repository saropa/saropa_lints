/**
 * Module overview (comment coverage pass).
 * comment-coverage: module overview (batch).
 *
 * Vibrancy UI experiment: scoring, providers, and webview assets.
 */

import { PackageDependency, OverrideAnalysis } from '../types';
import { DepGraphPackage } from './dep-graph';
import { parseOverrides } from './override-parser';
import { getOverrideAges } from './override-age';
import { analyzeOverrides } from '../scoring/override-analyzer';
// Type-only import — ConstraintIndex's module pulls in no vscode, so this keeps
// override-runner resolvable under the plain mocha unit runner.
import { ConstraintIndex } from '../scoring/shared-dep-conflict-detector';
import { findKnownIssue } from '../scoring/known-issues';
import { ScanLogger } from './scan-logger';

/**
 * Run override analysis for a pubspec.yaml.
 * Extracts override entries, fetches their git ages, and analyzes status.
 */
export async function runOverrideAnalysis(
    yamlContent: string,
    deps: readonly PackageDependency[],
    depGraphPackages: readonly DepGraphPackage[],
    workspaceRoot: string,
    logger: ScanLogger,
    // Declared constraints of the override's constrainer parents, read from the
    // pub cache by the caller (the index build needs vscode I/O, which this
    // module deliberately avoids so it stays unit-testable). Empty default keeps
    // the SDK-heuristic-only behavior when no index is supplied.
    constraints: ConstraintIndex = new Map(),
): Promise<OverrideAnalysis[]> {
    try {
        const overrideEntries = parseOverrides(yamlContent);
        if (overrideEntries.length === 0) {
            return [];
        }

        const packageNames = overrideEntries.map(e => e.name);
        const ages = await getOverrideAges(packageNames, workspaceRoot);

        const analyses = analyzeOverrides(
            overrideEntries, [...deps], [...depGraphPackages], ages, constraints,
        );
        return applyKnownOverrideReasons(analyses);
    } catch (err) {
        logger.info(`Override analysis failed: ${err}`);
        return [];
    }
}

/**
 * The constrainer parents whose declared constraints can name an override's
 * blocker: every package that depends on one of the overridden packages.
 * Bounding the constraint-index read to these keeps pub-cache I/O off the full
 * transitive graph. Pure (no I/O) so the caller can feed the result straight
 * into buildConstraintIndex.
 */
export function overrideConstrainerCandidates(
    overrideNames: Iterable<string>,
    depGraphPackages: readonly DepGraphPackage[],
): Set<string> {
    const overridden = new Set(overrideNames);
    return new Set(
        depGraphPackages
            .filter(p => p.dependencies.some(d => overridden.has(d)))
            .map(p => p.name),
    );
}

/** Flip stale overrides to active when a known override reason exists. */
export function applyKnownOverrideReasons(
    analyses: OverrideAnalysis[],
): OverrideAnalysis[] {
    return analyses.map(a => {
        if (a.status !== 'stale') { return a; }
        const reason = findKnownIssue(a.entry.name, a.entry.version)?.overrideReason;
        if (!reason) { return a; }
        return { ...a, status: 'active' as const, blocker: reason };
    });
}
