"use strict";
/**
 * Tree data provider for Saropa Lints Overview (dashboard) view.
 * Shows Health Score as the primary number, then issues, trends, and links.
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
exports.OverviewTreeProvider = void 0;
const vscode = __importStar(require("vscode"));
const violationsReader_1 = require("../violationsReader");
const runHistory_1 = require("../runHistory");
const healthScore_1 = require("../healthScore");
const projectRoot_1 = require("../projectRoot");
/** C1: Format an ISO timestamp as a human-readable relative time. */
function formatTimeAgo(iso) {
    const ms = Date.now() - new Date(iso).getTime();
    if (ms < 0 || !Number.isFinite(ms))
        return 'just now';
    const sec = Math.floor(ms / 1000);
    if (sec < 60)
        return 'just now';
    const min = Math.floor(sec / 60);
    if (min < 60)
        return `${min} min ago`;
    const hrs = Math.floor(min / 60);
    if (hrs < 24)
        return `${hrs}h ago`;
    const days = Math.floor(hrs / 24);
    return `${days}d ago`;
}
class OverviewItem extends vscode.TreeItem {
    constructor(label, description, commandId, args = []) {
        super(label, vscode.TreeItemCollapsibleState.None);
        this.description = description;
        this.command = { command: commandId, title: label, arguments: args };
        this.contextValue = 'overviewItem';
    }
}
class OverviewTreeProvider {
    _onDidChangeTreeData = new vscode.EventEmitter();
    onDidChangeTreeData = this._onDidChangeTreeData.event;
    workspaceState;
    constructor(workspaceState) {
        this.workspaceState = workspaceState;
    }
    refresh() {
        this._onDidChangeTreeData.fire();
    }
    getTreeItem(element) {
        return element;
    }
    async getChildren() {
        const cfg = vscode.workspace.getConfiguration('saropaLints');
        const enabled = cfg.get('enabled', false) ?? false;
        // C5: Return empty array so VS Code's viewsWelcome content renders instead.
        if (!enabled)
            return [];
        const root = (0, projectRoot_1.getProjectRoot)();
        const data = root ? (0, violationsReader_1.readViolations)(root) : null;
        const total = data?.summary?.totalViolations ?? data?.violations?.length ?? 0;
        const critical = data?.summary?.byImpact?.critical ?? 0;
        const items = [];
        // C5: No violations.json yet — return empty so viewsWelcome "Run Analysis" shows.
        if (!data)
            return [];
        // H2: Health Score — the primary number in Overview.
        // data is guaranteed non-null here (early return above handles null).
        const history = (0, runHistory_1.loadHistory)(this.workspaceState);
        const health = (0, healthScore_1.computeHealthScore)(data);
        if (health) {
            const prevScore = (0, runHistory_1.findPreviousScore)(history);
            const delta = prevScore !== undefined
                ? (0, healthScore_1.formatScoreDelta)(health.score, prevScore)
                : '';
            const scoreDesc = delta
                ? `${delta} from last run`
                : total === 0
                    ? 'No violations'
                    : `${total} violations`;
            items.push(new OverviewItem(`Health: ${health.score}`, scoreDesc, 'saropaLints.focusIssues'));
        }
        // Violation summary — secondary to the score.
        if (total > 0) {
            const issueLabel = critical > 0
                ? `${critical} critical, ${total} total`
                : `${total} violations`;
            items.push(new OverviewItem(issueLabel, 'View in Issues', 'saropaLints.focusIssues'));
        }
        else {
            // Zero violations after analysis — clean project.
            items.push(new OverviewItem('No violations', 'All clear', 'saropaLints.focusIssues'));
        }
        // D5: Score-driven trend — show score sparkline with time span.
        const scoreTrend = (0, runHistory_1.getScoreTrendSummary)(history);
        if (scoreTrend) {
            items.push(new OverviewItem('Trends', scoreTrend, 'saropaLints.focusIssues'));
        }
        else {
            // Fall back to violation-count trend when no scores available yet.
            const trend = (0, runHistory_1.getTrendSummary)(history);
            if (trend) {
                items.push(new OverviewItem('Trends', trend, 'saropaLints.focusIssues'));
            }
        }
        // D5: Regression alert — show when score dropped.
        const regression = (0, runHistory_1.detectScoreRegression)(history);
        if (regression) {
            const criticalCount = data.summary?.byImpact?.critical ?? 0;
            const regDesc = criticalCount > 0
                ? `${criticalCount} critical violation${criticalCount === 1 ? '' : 's'}`
                : 'View issues';
            items.push(new OverviewItem(`Score dropped ${regression.previousScore} \u2192 ${regression.currentScore}`, regDesc, 'saropaLints.focusIssues'));
        }
        // W6: Celebration — show delta when violations decreased.
        if (history.length >= 2) {
            const prev = history[history.length - 2];
            const curr = history[history.length - 1];
            const violationDelta = prev.total - curr.total;
            if (violationDelta > 0) {
                items.push(new OverviewItem(`\u2193 ${violationDelta} fewer issues`, 'since last run', 'saropaLints.focusIssues'));
            }
        }
        // C1: "Last run" timestamp from most recent history entry.
        if (history.length > 0) {
            const lastTs = history[history.length - 1].timestamp;
            items.push(new OverviewItem('Last run', formatTimeAgo(lastTs), 'saropaLints.runAnalysis'));
        }
        // C1: Primary CTA — always available for re-running analysis.
        items.push(new OverviewItem('Run Analysis', undefined, 'saropaLints.runAnalysis'));
        items.push(new OverviewItem('Summary', undefined, 'saropaLints.summary.focus'), new OverviewItem('Config', undefined, 'saropaLints.config.focus'), new OverviewItem('Suggestions', undefined, 'saropaLints.suggestions.focus'));
        return items;
    }
}
exports.OverviewTreeProvider = OverviewTreeProvider;
//# sourceMappingURL=overviewTree.js.map