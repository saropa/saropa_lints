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
exports.BudgetItem = exports.BudgetGroupItem = void 0;
const vscode = __importStar(require("vscode"));
/**
 * Budget-related tree item classes for the sidebar tree view.
 * Extracted from tree-item-classes.ts to keep files under 300 lines.
 *
 * Contains:
 * - BudgetGroupItem: collapsible group node showing overall budget health
 * - BudgetItem: individual budget dimension row (e.g. "end-of-life count")
 * - budgetStatusIcon / budgetStatusColor: private helpers for status styling
 */
/**
 * Maps a budget status string to a codicon icon name.
 * Used by both BudgetGroupItem and BudgetItem for consistent icon styling.
 */
function budgetStatusIcon(status) {
    switch (status) {
        case 'under': return 'pass';
        case 'warning': return 'warning';
        case 'exceeded': return 'error';
        default: return 'circle-outline';
    }
}
/**
 * Maps a budget status string to a VS Code theme color.
 * Follows the same green/yellow/red pattern used elsewhere in the tree view.
 */
function budgetStatusColor(status) {
    switch (status) {
        case 'under': return new vscode.ThemeColor('testing.iconPassed');
        case 'warning': return new vscode.ThemeColor('editorWarning.foreground');
        case 'exceeded': return new vscode.ThemeColor('editorError.foreground');
        default: return new vscode.ThemeColor('disabledForeground');
    }
}
/**
 * Collapsible group node for the dependency health budget section.
 * Shows an overall status icon (error > warning > pass) based on the
 * worst-case result across all budget dimensions.
 */
class BudgetGroupItem extends vscode.TreeItem {
    budgetResults;
    constructor(budgetResults, summary) {
        super('📊 Budget', vscode.TreeItemCollapsibleState.Expanded);
        this.budgetResults = budgetResults;
        this.description = summary;
        const hasExceeded = budgetResults.some(r => r.status === 'exceeded');
        const hasWarning = budgetResults.some(r => r.status === 'warning');
        // Icon escalates: pass (all good) → warning → error (any exceeded)
        if (hasExceeded) {
            this.iconPath = new vscode.ThemeIcon('error', new vscode.ThemeColor('editorError.foreground'));
        }
        else if (hasWarning) {
            this.iconPath = new vscode.ThemeIcon('warning', new vscode.ThemeColor('editorWarning.foreground'));
        }
        else {
            this.iconPath = new vscode.ThemeIcon('pass', new vscode.ThemeColor('testing.iconPassed'));
        }
        this.tooltip = 'Dependency health budget status';
        this.contextValue = 'vibrancyBudgetGroup';
    }
}
exports.BudgetGroupItem = BudgetGroupItem;
/**
 * Leaf tree item for a single budget dimension (e.g. "End-of-Life Count").
 * Displays the dimension name as the label, details as the description,
 * and an appropriate status icon + color.
 */
class BudgetItem extends vscode.TreeItem {
    budgetResult;
    constructor(budgetResult) {
        super(budgetResult.dimension, vscode.TreeItemCollapsibleState.None);
        this.budgetResult = budgetResult;
        this.description = budgetResult.details;
        // Add status emoji suffix to description for at-a-glance scanning
        const emoji = budgetResult.status === 'under' ? '✅'
            : budgetResult.status === 'warning' ? '⚠️'
                : budgetResult.status === 'exceeded' ? '❌' : '';
        if (budgetResult.status !== 'unconfigured' && emoji) {
            this.description = `${budgetResult.details} ${emoji}`;
        }
        this.iconPath = new vscode.ThemeIcon(budgetStatusIcon(budgetResult.status), budgetStatusColor(budgetResult.status));
        // Tooltip provides actionable context depending on status
        if (budgetResult.status === 'exceeded') {
            this.tooltip = `Exceeded: ${budgetResult.details}. Action required.`;
        }
        else if (budgetResult.status === 'warning') {
            this.tooltip = `Warning: ${budgetResult.details}. Approaching limit.`;
        }
        else if (budgetResult.status === 'under') {
            this.tooltip = `OK: ${budgetResult.details}`;
        }
        else {
            this.tooltip = `${budgetResult.dimension}: ${budgetResult.details} (no limit set)`;
        }
        this.contextValue = 'vibrancyBudgetItem';
    }
}
exports.BudgetItem = BudgetItem;
//# sourceMappingURL=tree-item-budget-classes.js.map