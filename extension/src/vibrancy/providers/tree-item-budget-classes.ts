import * as vscode from 'vscode';

import { BudgetResult } from '../types';

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
function budgetStatusIcon(status: string): string {
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
function budgetStatusColor(status: string): vscode.ThemeColor {
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
export class BudgetGroupItem extends vscode.TreeItem {
    constructor(
        public readonly budgetResults: readonly BudgetResult[],
        summary: string,
    ) {
        super('📊 Budget', vscode.TreeItemCollapsibleState.Expanded);
        this.description = summary;

        const hasExceeded = budgetResults.some(r => r.status === 'exceeded');
        const hasWarning = budgetResults.some(r => r.status === 'warning');

        // Icon escalates: pass (all good) → warning → error (any exceeded)
        if (hasExceeded) {
            this.iconPath = new vscode.ThemeIcon(
                'error',
                new vscode.ThemeColor('editorError.foreground'),
            );
        } else if (hasWarning) {
            this.iconPath = new vscode.ThemeIcon(
                'warning',
                new vscode.ThemeColor('editorWarning.foreground'),
            );
        } else {
            this.iconPath = new vscode.ThemeIcon(
                'pass',
                new vscode.ThemeColor('testing.iconPassed'),
            );
        }

        this.tooltip = 'Dependency health budget status';
        this.contextValue = 'vibrancyBudgetGroup';
    }
}

/**
 * Leaf tree item for a single budget dimension (e.g. "End-of-Life Count").
 * Displays the dimension name as the label, details as the description,
 * and an appropriate status icon + color.
 */
export class BudgetItem extends vscode.TreeItem {
    constructor(public readonly budgetResult: BudgetResult) {
        super(budgetResult.dimension, vscode.TreeItemCollapsibleState.None);
        this.description = budgetResult.details;

        // Add status emoji suffix to description for at-a-glance scanning
        const emoji = budgetResult.status === 'under' ? '✅'
            : budgetResult.status === 'warning' ? '⚠️'
                : budgetResult.status === 'exceeded' ? '❌' : '';

        if (budgetResult.status !== 'unconfigured' && emoji) {
            this.description = `${budgetResult.details} ${emoji}`;
        }

        this.iconPath = new vscode.ThemeIcon(
            budgetStatusIcon(budgetResult.status),
            budgetStatusColor(budgetResult.status),
        );

        // Tooltip provides actionable context depending on status
        if (budgetResult.status === 'exceeded') {
            this.tooltip = `Exceeded: ${budgetResult.details}. Action required.`;
        } else if (budgetResult.status === 'warning') {
            this.tooltip = `Warning: ${budgetResult.details}. Approaching limit.`;
        } else if (budgetResult.status === 'under') {
            this.tooltip = `OK: ${budgetResult.details}`;
        } else {
            this.tooltip = `${budgetResult.dimension}: ${budgetResult.details} (no limit set)`;
        }

        this.contextValue = 'vibrancyBudgetItem';
    }
}
