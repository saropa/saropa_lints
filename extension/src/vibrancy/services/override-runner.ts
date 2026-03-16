import { PackageDependency, OverrideAnalysis } from '../types';
import { DepGraphPackage } from './dep-graph';
import { parseOverrides } from './override-parser';
import { getOverrideAges } from './override-age';
import { analyzeOverrides } from '../scoring/override-analyzer';
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
): Promise<OverrideAnalysis[]> {
    try {
        const overrideEntries = parseOverrides(yamlContent);
        if (overrideEntries.length === 0) {
            return [];
        }

        const packageNames = overrideEntries.map(e => e.name);
        const ages = await getOverrideAges(packageNames, workspaceRoot);

        const analyses = analyzeOverrides(overrideEntries, [...deps], [...depGraphPackages], ages);
        return applyKnownOverrideReasons(analyses);
    } catch (err) {
        logger.info(`Override analysis failed: ${err}`);
        return [];
    }
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
