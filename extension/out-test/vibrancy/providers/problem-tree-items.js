"use strict";
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
exports.ProblemSummaryItem = exports.SuggestionItem = exports.ProblemItem = void 0;
const vscode = __importStar(require("vscode"));
const problem_types_1 = require("../problems/problem-types");
const problem_actions_1 = require("../problems/problem-actions");
const tree_item_classes_1 = require("./tree-item-classes");
/** A single problem affecting a package. */
class ProblemItem extends vscode.TreeItem {
    problem;
    packageName;
    constructor(problem, packageName) {
        const typeLabel = (0, problem_types_1.problemTypeLabel)(problem.type);
        super(typeLabel, vscode.TreeItemCollapsibleState.None);
        this.problem = problem;
        this.packageName = packageName;
        this.description = (0, problem_types_1.problemMessage)(problem);
        this.iconPath = new vscode.ThemeIcon((0, tree_item_classes_1.severityIcon)(problem.severity), (0, tree_item_classes_1.severityColor)(problem.severity));
        this.contextValue = `vibrancyProblem.${problem.type}`;
        this.tooltip = new vscode.MarkdownString(this._buildTooltip());
        this.command = {
            command: 'saropaLints.packageVibrancy.goToLine',
            title: 'Go to line',
            arguments: [problem.line],
        };
    }
    _buildTooltip() {
        const icon = (0, problem_types_1.severityIcon)(this.problem.severity);
        let md = `**${icon} ${(0, problem_types_1.problemTypeLabel)(this.problem.type)}**\n\n`;
        md += `${(0, problem_types_1.problemMessage)(this.problem)}\n\n`;
        md += `*Line ${this.problem.line + 1}*`;
        return md;
    }
}
exports.ProblemItem = ProblemItem;
/** A suggested action item. */
class SuggestionItem extends vscode.TreeItem {
    action;
    unlocksPackages;
    packageName;
    constructor(action, unlocksPackages, packageName) {
        const icon = (0, problem_actions_1.actionIcon)(action.type);
        super(`${icon} ${action.description}`, vscode.TreeItemCollapsibleState.None);
        this.action = action;
        this.unlocksPackages = unlocksPackages;
        this.packageName = packageName;
        if (unlocksPackages.length > 0) {
            this.description = `Unlocks: ${unlocksPackages.join(', ')}`;
        }
        this.iconPath = new vscode.ThemeIcon('lightbulb', new vscode.ThemeColor('editorLightBulb.foreground'));
        this.contextValue = `vibrancySuggestion.${action.type}`;
    }
}
exports.SuggestionItem = SuggestionItem;
/** Summary statistics item. */
class ProblemSummaryItem extends vscode.TreeItem {
    constructor(highCount, mediumCount, lowCount) {
        const parts = [];
        if (highCount > 0) {
            parts.push(`🔴 ${highCount}`);
        }
        if (mediumCount > 0) {
            parts.push(`🟡 ${mediumCount}`);
        }
        if (lowCount > 0) {
            parts.push(`🔵 ${lowCount}`);
        }
        super(parts.join('  '), vscode.TreeItemCollapsibleState.None);
        this.contextValue = 'vibrancyProblemSummary';
    }
}
exports.ProblemSummaryItem = ProblemSummaryItem;
//# sourceMappingURL=problem-tree-items.js.map