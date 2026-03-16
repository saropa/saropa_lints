"use strict";
/**
 * Tree data provider for Saropa Lints Summary view.
 * Shows totals, by severity, by impact, and tier from violations.json.
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
exports.SummaryTreeProvider = void 0;
const vscode = __importStar(require("vscode"));
const violationsReader_1 = require("../violationsReader");
const projectRoot_1 = require("../projectRoot");
/** Stable id used for expandable nodes (By severity, By impact) so getChildren does not rely on label text. */
class SummaryItem extends vscode.TreeItem {
    nodeId;
    constructor(label, description, collapsible = vscode.TreeItemCollapsibleState.None, nodeId, commandId, commandArgs) {
        super(label, collapsible);
        this.nodeId = nodeId;
        this.description = description;
        if (commandId) {
            this.command = { command: commandId, title: label, arguments: commandArgs ?? [] };
        }
        this.contextValue = 'summaryItem';
    }
}
class SummaryTreeProvider {
    _onDidChangeTreeData = new vscode.EventEmitter();
    onDidChangeTreeData = this._onDidChangeTreeData.event;
    refresh() {
        this._onDidChangeTreeData.fire();
    }
    getTreeItem(element) {
        return element;
    }
    async getChildren(element) {
        const root = (0, projectRoot_1.getProjectRoot)();
        // C5: Return empty for no-workspace and no-data so viewsWelcome renders.
        if (!root)
            return [];
        const data = (0, violationsReader_1.readViolations)(root);
        if (!data)
            return [];
        const s = data.summary;
        const c = data.config;
        if (!element) {
            const total = s?.totalViolations ?? data.violations.length;
            const items = [
                // Clickable: opens Issues view with all issues (clears filters).
                new SummaryItem('Total violations', String(total), vscode.TreeItemCollapsibleState.None, undefined, 'saropaLints.focusIssues'),
                new SummaryItem('Tier', c?.tier ?? '—'),
                new SummaryItem('Files analyzed', s?.filesAnalyzed != null ? String(s.filesAnalyzed) : '—'),
                new SummaryItem('Files with issues', s?.filesWithIssues != null ? String(s.filesWithIssues) : '—'),
            ];
            if (s?.bySeverity) {
                items.push(new SummaryItem('By severity', `${s.bySeverity.error ?? 0} error, ${s.bySeverity.warning ?? 0} warning, ${s.bySeverity.info ?? 0} info`, vscode.TreeItemCollapsibleState.Expanded, 'bySeverity'));
            }
            if (s?.byImpact) {
                const bi = s.byImpact;
                items.push(new SummaryItem('By impact', `critical ${bi.critical ?? 0}, high ${bi.high ?? 0}, medium ${bi.medium ?? 0}, low ${bi.low ?? 0}, opinionated ${bi.opinionated ?? 0}`, vscode.TreeItemCollapsibleState.Expanded, 'byImpact'));
            }
            return items;
        }
        if ((element.nodeId === 'bySeverity' || element.label === 'By severity') && s?.bySeverity) {
            return [
                new SummaryItem('Error', String(s.bySeverity.error ?? 0), vscode.TreeItemCollapsibleState.None, undefined, 'saropaLints.focusIssuesWithSeverityFilter', ['error']),
                new SummaryItem('Warning', String(s.bySeverity.warning ?? 0), vscode.TreeItemCollapsibleState.None, undefined, 'saropaLints.focusIssuesWithSeverityFilter', ['warning']),
                new SummaryItem('Info', String(s.bySeverity.info ?? 0), vscode.TreeItemCollapsibleState.None, undefined, 'saropaLints.focusIssuesWithSeverityFilter', ['info']),
            ];
        }
        if ((element.nodeId === 'byImpact' || element.label === 'By impact') && s?.byImpact) {
            return [
                new SummaryItem('Critical', String(s.byImpact.critical ?? 0), vscode.TreeItemCollapsibleState.None, undefined, 'saropaLints.focusIssuesWithImpactFilter', ['critical']),
                new SummaryItem('High', String(s.byImpact.high ?? 0), vscode.TreeItemCollapsibleState.None, undefined, 'saropaLints.focusIssuesWithImpactFilter', ['high']),
                new SummaryItem('Medium', String(s.byImpact.medium ?? 0), vscode.TreeItemCollapsibleState.None, undefined, 'saropaLints.focusIssuesWithImpactFilter', ['medium']),
                new SummaryItem('Low', String(s.byImpact.low ?? 0), vscode.TreeItemCollapsibleState.None, undefined, 'saropaLints.focusIssuesWithImpactFilter', ['low']),
                new SummaryItem('Opinionated', String(s.byImpact.opinionated ?? 0), vscode.TreeItemCollapsibleState.None, undefined, 'saropaLints.focusIssuesWithImpactFilter', ['opinionated']),
            ];
        }
        return [];
    }
}
exports.SummaryTreeProvider = SummaryTreeProvider;
//# sourceMappingURL=summaryTree.js.map