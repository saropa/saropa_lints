import * as vscode from 'vscode';
import {
    Problem, problemMessage, problemTypeLabel, severityIcon,
} from '../problems/problem-types';
import { SuggestedAction, actionIcon } from '../problems/problem-actions';
import {
    severityColor, severityIcon as severityThemeIcon,
} from './tree-item-classes';

/** A single problem affecting a package. */
export class ProblemItem extends vscode.TreeItem {
    constructor(
        public readonly problem: Problem,
        public readonly packageName: string,
    ) {
        const typeLabel = problemTypeLabel(problem.type);
        super(typeLabel, vscode.TreeItemCollapsibleState.None);

        this.description = problemMessage(problem);
        this.iconPath = new vscode.ThemeIcon(
            severityThemeIcon(problem.severity),
            severityColor(problem.severity),
        );

        this.contextValue = `vibrancyProblem.${problem.type}`;
        this.tooltip = new vscode.MarkdownString(this._buildTooltip());

        this.command = {
            command: 'saropaLints.packageVibrancy.goToLine',
            title: 'Go to line',
            arguments: [problem.line],
        };
    }

    private _buildTooltip(): string {
        const icon = severityIcon(this.problem.severity);
        let md = `**${icon} ${problemTypeLabel(this.problem.type)}**\n\n`;
        md += `${problemMessage(this.problem)}\n\n`;
        md += `*Line ${this.problem.line + 1}*`;
        return md;
    }
}

/** A suggested action item. */
export class SuggestionItem extends vscode.TreeItem {
    constructor(
        public readonly action: SuggestedAction,
        public readonly unlocksPackages: readonly string[],
        public readonly packageName: string,
    ) {
        const icon = actionIcon(action.type);
        super(`${icon} ${action.description}`, vscode.TreeItemCollapsibleState.None);

        if (unlocksPackages.length > 0) {
            this.description = `Unlocks: ${unlocksPackages.join(', ')}`;
        }

        this.iconPath = new vscode.ThemeIcon(
            'lightbulb',
            new vscode.ThemeColor('editorLightBulb.foreground'),
        );

        this.contextValue = `vibrancySuggestion.${action.type}`;
    }
}

/** Summary statistics item. */
export class ProblemSummaryItem extends vscode.TreeItem {
    constructor(
        highCount: number,
        mediumCount: number,
        lowCount: number,
    ) {
        const parts: string[] = [];
        if (highCount > 0) { parts.push(`🔴 ${highCount}`); }
        if (mediumCount > 0) { parts.push(`🟡 ${mediumCount}`); }
        if (lowCount > 0) { parts.push(`🔵 ${lowCount}`); }

        super(parts.join('  '), vscode.TreeItemCollapsibleState.None);
        this.contextValue = 'vibrancyProblemSummary';
    }
}
