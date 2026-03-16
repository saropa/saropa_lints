import { VibrancyResult, DepEdge } from '../types';
import { ScanLogger } from './scan-logger';
import { fetchPubOutdated } from './pub-outdated';
import { fetchDepGraph, buildReverseDeps } from './dep-graph';
import { findBlockers, classifyUpgradeStatus } from '../scoring/blocker-analyzer';

/** Result of blocker enrichment: enriched results + reverse dep graph. */
export interface BlockerEnrichResult {
    readonly results: VibrancyResult[];
    readonly reverseDeps: ReadonlyMap<string, readonly DepEdge[]>;
}

/** Enrich results with upgrade blocker info from dart pub CLI. */
export async function enrichWithBlockers(
    results: VibrancyResult[],
    cwd: string,
    logger: ScanLogger,
): Promise<BlockerEnrichResult> {
    const [outdatedResult, depGraphResult] = await Promise.all([
        fetchPubOutdated(cwd),
        fetchDepGraph(cwd),
    ]);
    if (!outdatedResult.success || !depGraphResult.success) {
        logger.info('Blocker analysis skipped — CLI commands failed');
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
        };
    });
    return { results: enriched, reverseDeps };
}
