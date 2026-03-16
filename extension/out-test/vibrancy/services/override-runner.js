"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.runOverrideAnalysis = runOverrideAnalysis;
exports.applyKnownOverrideReasons = applyKnownOverrideReasons;
const override_parser_1 = require("./override-parser");
const override_age_1 = require("./override-age");
const override_analyzer_1 = require("../scoring/override-analyzer");
const known_issues_1 = require("../scoring/known-issues");
/**
 * Run override analysis for a pubspec.yaml.
 * Extracts override entries, fetches their git ages, and analyzes status.
 */
async function runOverrideAnalysis(yamlContent, deps, depGraphPackages, workspaceRoot, logger) {
    try {
        const overrideEntries = (0, override_parser_1.parseOverrides)(yamlContent);
        if (overrideEntries.length === 0) {
            return [];
        }
        const packageNames = overrideEntries.map(e => e.name);
        const ages = await (0, override_age_1.getOverrideAges)(packageNames, workspaceRoot);
        const analyses = (0, override_analyzer_1.analyzeOverrides)(overrideEntries, [...deps], [...depGraphPackages], ages);
        return applyKnownOverrideReasons(analyses);
    }
    catch (err) {
        logger.info(`Override analysis failed: ${err}`);
        return [];
    }
}
/** Flip stale overrides to active when a known override reason exists. */
function applyKnownOverrideReasons(analyses) {
    return analyses.map(a => {
        if (a.status !== 'stale') {
            return a;
        }
        const reason = (0, known_issues_1.findKnownIssue)(a.entry.name, a.entry.version)?.overrideReason;
        if (!reason) {
            return a;
        }
        return { ...a, status: 'active', blocker: reason };
    });
}
//# sourceMappingURL=override-runner.js.map