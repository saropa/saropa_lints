"use strict";
/**
 * Read reports/.saropa_lints/violations.json and expose summary + violations.
 */
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || (function () {
    var ownKeys = function(o) {
        ownKeys = Object.getOwnPropertyNames || function (o) {
            var ar = [];
            for (var k in o) if (Object.prototype.hasOwnProperty.call(o, k)) ar[ar.length] = k;
            return ar;
        };
        return ownKeys(o);
    };
    return function (mod) {
        if (mod && mod.__esModule) return mod;
        var result = {};
        if (mod != null) for (var k = ownKeys(mod), i = 0; i < k.length; i++) if (k[i] !== "default") __createBinding(result, mod, k[i]);
        __setModuleDefault(result, mod);
        return result;
    };
})();
Object.defineProperty(exports, "__esModule", { value: true });
exports.getViolationsPath = getViolationsPath;
exports.readViolations = readViolations;
exports.hasViolations = hasViolations;
const path = __importStar(require("path"));
const fs = __importStar(require("fs"));
function getViolationsPath(workspaceRoot) {
    return path.join(workspaceRoot, 'reports', '.saropa_lints', 'violations.json');
}
function readViolations(workspaceRoot) {
    const p = getViolationsPath(workspaceRoot);
    if (!fs.existsSync(p))
        return null;
    try {
        const raw = JSON.parse(fs.readFileSync(p, 'utf-8'));
        const summary = raw.summary;
        return {
            violations: Array.isArray(raw.violations) ? raw.violations : [],
            summary: summary
                ? {
                    totalViolations: summary.totalViolations,
                    filesAnalyzed: summary.filesAnalyzed,
                    filesWithIssues: summary.filesWithIssues,
                    bySeverity: summary.bySeverity,
                    byImpact: summary.byImpact,
                    issuesByRule: summary.issuesByRule &&
                        typeof summary.issuesByRule === 'object' &&
                        !Array.isArray(summary.issuesByRule)
                        ? summary.issuesByRule
                        : undefined,
                }
                : undefined,
            config: raw.config
                ? {
                    tier: raw.config.tier,
                    enabledRuleCount: raw.config.enabledRuleCount,
                    enabledRuleNames: Array.isArray(raw.config.enabledRuleNames)
                        ? raw.config.enabledRuleNames
                        : undefined,
                    stylisticRuleNames: Array.isArray(raw.config.stylisticRuleNames)
                        ? raw.config.stylisticRuleNames
                        : undefined,
                }
                : undefined,
        };
    }
    catch {
        return null;
    }
}
function hasViolations(workspaceRoot) {
    const data = readViolations(workspaceRoot);
    if (!data)
        return false;
    return (data.summary?.totalViolations ?? data.violations.length) > 0;
}
//# sourceMappingURL=violationsReader.js.map