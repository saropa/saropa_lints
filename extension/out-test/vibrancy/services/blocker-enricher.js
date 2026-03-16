"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.enrichWithBlockers = enrichWithBlockers;
const pub_outdated_1 = require("./pub-outdated");
const dep_graph_1 = require("./dep-graph");
const blocker_analyzer_1 = require("../scoring/blocker-analyzer");
/** Enrich results with upgrade blocker info from dart pub CLI. */
async function enrichWithBlockers(results, cwd, logger) {
    const [outdatedResult, depGraphResult] = await Promise.all([
        (0, pub_outdated_1.fetchPubOutdated)(cwd),
        (0, dep_graph_1.fetchDepGraph)(cwd),
    ]);
    if (!outdatedResult.success || !depGraphResult.success) {
        logger.info('Blocker analysis skipped — CLI commands failed');
        return { results, reverseDeps: new Map() };
    }
    const reverseDeps = (0, dep_graph_1.buildReverseDeps)(depGraphResult.packages);
    const directNames = new Set(results.map(r => r.package.name));
    const blockers = (0, blocker_analyzer_1.findBlockers)(outdatedResult.entries, reverseDeps, results, directNames);
    const blockerMap = new Map(blockers.map(b => [b.blockedPackage, b]));
    const outdatedMap = new Map(outdatedResult.entries.map(e => [e.package, e]));
    const enriched = results.map(r => {
        const entry = outdatedMap.get(r.package.name);
        const status = entry
            ? (0, blocker_analyzer_1.classifyUpgradeStatus)(entry) : 'up-to-date';
        return {
            ...r,
            blocker: blockerMap.get(r.package.name) ?? null,
            upgradeBlockStatus: status,
        };
    });
    return { results: enriched, reverseDeps };
}
//# sourceMappingURL=blocker-enricher.js.map