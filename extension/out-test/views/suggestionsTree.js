"use strict";
/**
 * Tree data provider for Saropa Lints Suggestions view.
 * "What to do next" from violations.json and workspace state.
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
exports.SuggestionsTreeProvider = void 0;
const vscode = __importStar(require("vscode"));
const path = __importStar(require("path"));
const fs = __importStar(require("fs"));
const violationsReader_1 = require("../violationsReader");
const healthScore_1 = require("../healthScore");
const projectRoot_1 = require("../projectRoot");
class SuggestionItem extends vscode.TreeItem {
    commandId;
    args;
    constructor(label, description, commandId, args = []) {
        super(label, vscode.TreeItemCollapsibleState.None);
        this.commandId = commandId;
        this.args = args;
        this.description = description;
        if (commandId) {
            this.command = { command: commandId, title: label, arguments: args };
        }
        this.iconPath = new vscode.ThemeIcon('lightbulb');
        this.contextValue = 'suggestionItem';
    }
}
class SuggestionsTreeProvider {
    _onDidChangeTreeData = new vscode.EventEmitter();
    onDidChangeTreeData = this._onDidChangeTreeData.event;
    refresh() {
        this._onDidChangeTreeData.fire();
    }
    getTreeItem(element) {
        return element;
    }
    async getChildren() {
        const root = (0, projectRoot_1.getProjectRoot)();
        const items = [];
        const cfg = vscode.workspace.getConfiguration('saropaLints');
        const enabled = cfg.get('enabled', false) ?? false;
        // C5: When disabled, return empty so viewsWelcome "Enable" shows.
        if (!enabled)
            return [];
        const data = root ? (0, violationsReader_1.readViolations)(root) : null;
        // C5: When no data, return empty so viewsWelcome "Run analysis" shows.
        if (!data)
            return [];
        const byImpact = data?.summary?.byImpact;
        const bySeverity = data?.summary?.bySeverity;
        const total = data?.summary?.totalViolations ?? data?.violations?.length ?? 0;
        const critical = byImpact?.critical ?? 0;
        const high = byImpact?.high ?? 0;
        const errors = bySeverity?.error ?? 0;
        // C3: Compute current score and projected scores for impact suggestions.
        const currentScore = (0, healthScore_1.computeHealthScore)(data)?.score;
        if (critical > 0) {
            // C3: Show estimated score gain from fixing all critical issues.
            // Skip score message when gain is zero ("+0 points" is not useful).
            const projected = (0, healthScore_1.estimateScoreWithout)(data, 'critical');
            const gain = (currentScore !== undefined && projected !== null)
                ? projected - currentScore
                : null;
            const desc = (gain !== null && gain > 0)
                ? `estimated +${gain} points`
                : 'Show in Issues';
            items.push(new SuggestionItem(`Fix ${critical} critical issue(s)`, desc, 'saropaLints.focusIssuesWithImpactFilter', ['critical']));
        }
        if (high > 0 && items.length < 3) {
            const projected = (0, healthScore_1.estimateScoreWithout)(data, 'high');
            const gain = (currentScore !== undefined && projected !== null)
                ? projected - currentScore
                : null;
            const desc = (gain !== null && gain > 0)
                ? `estimated +${gain} points`
                : 'Show in Issues';
            items.push(new SuggestionItem(`Address ${high} high-impact issue(s)`, desc, 'saropaLints.focusIssuesWithImpactFilter', ['high']));
        }
        if (errors > 0 && !items.some((i) => String(i.label).includes('error'))) {
            items.push(new SuggestionItem(`Fix ${errors} analyzer error(s)`, 'Show in Issues', 'saropaLints.focusIssuesWithSeverityFilter', ['error']));
        }
        const baselinePath = root ? path.join(root, 'saropa_baseline.json') : '';
        if (total > 0 && root && !fs.existsSync(baselinePath)) {
            items.push(new SuggestionItem('Create baseline to suppress existing violations', 'New code still checked', 'saropaLints.openConfig'));
        }
        const tier = cfg.get('tier', 'recommended') ?? 'recommended';
        if (tier === 'recommended' && total > 0) {
            items.push(new SuggestionItem('Consider professional tier for more rules', 'Settings → saropaLints.tier', 'saropaLints.initializeConfig'));
        }
        items.push(new SuggestionItem('Run analysis', 'Refresh violations', 'saropaLints.runAnalysis'));
        items.push(new SuggestionItem('Open config', 'analysis_options_custom.yaml', 'saropaLints.openConfig'));
        return items.slice(0, 8);
    }
}
exports.SuggestionsTreeProvider = SuggestionsTreeProvider;
//# sourceMappingURL=suggestionsTree.js.map