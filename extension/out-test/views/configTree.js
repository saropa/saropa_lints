"use strict";
/**
 * Tree data provider for Saropa Lints Config view.
 * Shows current settings, detected platform/packages, triage groups, and actions.
 *
 * I1: The triage section shows rules grouped by priority (critical, volume A–D,
 * stylistic) so users can see which rules produce the most violations and
 * navigate to them in the Issues view.
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
exports.ConfigTreeProvider = void 0;
const vscode = __importStar(require("vscode"));
const pubspecReader_1 = require("../pubspecReader");
const projectRoot_1 = require("../projectRoot");
const violationsReader_1 = require("../violationsReader");
const triageTree_1 = require("./triageTree");
function setting(label, description, commandId) {
    return { kind: 'configSetting', label, description, commandId };
}
class ConfigTreeProvider {
    _onDidChangeTreeData = new vscode.EventEmitter();
    onDidChangeTreeData = this._onDidChangeTreeData.event;
    // Cached per refresh so expanding groups reuses the same computation.
    cachedTriage = null;
    refresh() {
        this.cachedTriage = null;
        this._onDidChangeTreeData.fire();
    }
    getTreeItem(element) {
        return (0, triageTree_1.renderTreeItem)(element);
    }
    getChildren(element) {
        // Child level: expand triage groups to show individual rules.
        if (element?.kind === 'triageGroup') {
            const issuesByRule = this.cachedTriage?.issuesByRule ?? {};
            return (0, triageTree_1.getTriageGroupChildren)(element, issuesByRule);
        }
        if (element)
            return []; // Other nodes have no children.
        // Root level.
        const cfg = vscode.workspace.getConfiguration('saropaLints');
        const enabled = cfg.get('enabled', false) ?? false;
        // C5: When disabled, return empty so viewsWelcome "Enable" shows.
        if (!enabled)
            return [];
        const tier = cfg.get('tier', 'recommended') ?? 'recommended';
        const runAfter = cfg.get('runAnalysisAfterConfigChange', true) ?? true;
        const items = [
            setting('Enabled', 'Yes', 'saropaLints.disable'),
            setting('Tier', tier, 'saropaLints.setTier'),
            setting('Run analysis after config change', runAfter ? 'Yes' : 'No'),
        ];
        // Detected platform/packages from pubspec.
        const root = (0, projectRoot_1.getProjectRoot)();
        if (root) {
            const pubspec = (0, pubspecReader_1.readPubspec)(root);
            const parts = [];
            if (pubspec.isFlutter)
                parts.push('Flutter');
            if (pubspec.packages.length > 0) {
                const pkgs = pubspec.packages.slice(0, 5).join(', ');
                parts.push(pubspec.packages.length > 5 ? pkgs + '…' : pkgs);
            }
            if (parts.length > 0)
                items.push(setting('Detected', parts.join(' · ')));
        }
        // I1: Triage section — only when violations data with issuesByRule is available.
        if (root) {
            const data = (0, violationsReader_1.readViolations)(root);
            if (data) {
                this.cachedTriage = (0, triageTree_1.buildTriageData)(data, root);
                if (this.cachedTriage) {
                    items.push(...this.buildTriageNodes(this.cachedTriage));
                }
            }
        }
        items.push(setting('Open analysis_options_custom.yaml', undefined, 'saropaLints.openConfig'), setting('Initialize / Update config', undefined, 'saropaLints.initializeConfig'), setting('Run analysis', undefined, 'saropaLints.runAnalysis'));
        return items;
    }
    /** Build the flat list of triage group nodes for the root level. */
    buildTriageNodes(triage) {
        const nodes = [];
        if (triage.criticalGroup)
            nodes.push(triage.criticalGroup);
        nodes.push(...triage.volumeGroups);
        if (triage.zeroIssueCount > 0) {
            nodes.push({
                kind: 'triageInfo',
                label: `${triage.zeroIssueCount} rules with zero issues`,
                description: 'auto-enabled',
            });
        }
        // I2: Show count of rules explicitly disabled by user overrides.
        if (triage.disabledOverrideCount > 0) {
            nodes.push({
                kind: 'triageInfo',
                label: `${triage.disabledOverrideCount} rules disabled by override`,
            });
        }
        if (triage.stylisticGroup)
            nodes.push(triage.stylisticGroup);
        return nodes;
    }
}
exports.ConfigTreeProvider = ConfigTreeProvider;
//# sourceMappingURL=configTree.js.map