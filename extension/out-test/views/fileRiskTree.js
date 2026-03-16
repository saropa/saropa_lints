"use strict";
/**
 * D6: File Risk tree — files ranked by violation density.
 * Shows the riskiest files first so developers know where to focus.
 * Click a file to filter the Issues view to that file.
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
exports.FileRiskTreeProvider = void 0;
const vscode = __importStar(require("vscode"));
const path = __importStar(require("path"));
const violationsReader_1 = require("../violationsReader");
const projectRoot_1 = require("../projectRoot");
/**
 * Impact weights matching healthScore.ts so that risk ranking is
 * consistent with the health score formula. A single critical violation
 * outweighs 8 medium ones in the weighted score.
 */
const RISK_WEIGHTS = {
    critical: 8,
    high: 3,
    medium: 1,
    low: 0.25,
    opinionated: 0.05,
};
const MAX_FILES = 30;
/**
 * Aggregate violations per file and compute a weighted risk score.
 * Returns files sorted by risk score descending — worst files first.
 */
function buildFileRisks(violations) {
    const byFile = new Map();
    for (const v of violations) {
        const entry = byFile.get(v.file) ?? { total: 0, critical: 0, high: 0, weighted: 0 };
        entry.total++;
        const impact = (v.impact ?? 'medium').toLowerCase();
        if (impact === 'critical')
            entry.critical++;
        if (impact === 'high')
            entry.high++;
        entry.weighted += RISK_WEIGHTS[impact] ?? 1;
        byFile.set(v.file, entry);
    }
    const risks = [];
    for (const [filePath, entry] of byFile) {
        risks.push({
            filePath,
            total: entry.total,
            critical: entry.critical,
            high: entry.high,
            riskScore: entry.weighted,
        });
    }
    // Sort by weighted risk score descending, then by total count.
    risks.sort((a, b) => b.riskScore - a.riskScore || b.total - a.total);
    return risks;
}
/** Pick an icon reflecting severity mix: flame for critical, warning for high, info otherwise. */
function riskIcon(r) {
    if (r.critical > 0)
        return new vscode.ThemeIcon('flame', new vscode.ThemeColor('list.errorForeground'));
    if (r.high > 0)
        return new vscode.ThemeIcon('warning', new vscode.ThemeColor('list.warningForeground'));
    return new vscode.ThemeIcon('info');
}
class FileRiskTreeProvider {
    _onDidChangeTreeData = new vscode.EventEmitter();
    onDidChangeTreeData = this._onDidChangeTreeData.event;
    refresh() {
        this._onDidChangeTreeData.fire();
    }
    getTreeItem(element) {
        if (element.kind === 'summary') {
            const item = new vscode.TreeItem(element.label, vscode.TreeItemCollapsibleState.None);
            item.description = element.description;
            item.iconPath = new vscode.ThemeIcon('graph');
            item.contextValue = 'fileRiskSummary';
            return item;
        }
        const r = element.risk;
        const base = path.basename(r.filePath);
        const item = new vscode.TreeItem(base, vscode.TreeItemCollapsibleState.None);
        item.description = r.filePath;
        item.iconPath = riskIcon(r);
        // Build tooltip with breakdown.
        const parts = [`${r.total} violation${r.total === 1 ? '' : 's'}`];
        if (r.critical > 0)
            parts.push(`${r.critical} critical`);
        if (r.high > 0)
            parts.push(`${r.high} high`);
        item.tooltip = `${r.filePath}\n${parts.join(', ')}\nRisk score: ${Math.round(r.riskScore)}`;
        // Click → filter Issues view to this file.
        item.command = {
            command: 'saropaLints.focusIssuesForFile',
            title: 'Show issues for this file',
            arguments: [r.filePath],
        };
        item.contextValue = 'fileRiskFile';
        return item;
    }
    getChildren(element) {
        if (element)
            return [];
        const cfg = vscode.workspace.getConfiguration('saropaLints');
        if (!(cfg.get('enabled', false) ?? false))
            return [];
        const root = (0, projectRoot_1.getProjectRoot)();
        if (!root)
            return [];
        const data = (0, violationsReader_1.readViolations)(root);
        if (!data || data.violations.length === 0)
            return [];
        const risks = buildFileRisks(data.violations);
        if (risks.length === 0)
            return [];
        const items = [];
        // D6: Summary — "Top N files have X% of critical issues".
        const totalCritical = risks.reduce((s, r) => s + r.critical, 0);
        if (totalCritical > 0) {
            const topN = Math.min(5, risks.length);
            const topCritical = risks.slice(0, topN).reduce((s, r) => s + r.critical, 0);
            const pct = Math.round((topCritical / totalCritical) * 100);
            items.push({
                kind: 'summary',
                label: `Top ${topN} files have ${pct}% of critical issues`,
                description: `${totalCritical} critical total`,
            });
        }
        // File items capped at MAX_FILES.
        for (const risk of risks.slice(0, MAX_FILES)) {
            items.push({ kind: 'file', risk });
        }
        return items;
    }
}
exports.FileRiskTreeProvider = FileRiskTreeProvider;
//# sourceMappingURL=fileRiskTree.js.map