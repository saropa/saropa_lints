import * as vscode from 'vscode';
import {
    Problem, problemMessage, problemTypeLabel, severityIcon,
} from '../problems/problem-types';
import { PackageProblems } from '../problems/problem-registry';
import { SuggestedAction, actionIcon } from '../problems/problem-actions';
import {
    severityColor, severityIcon as severityThemeIcon,
} from './tree-item-classes';

/** Root group for all problems. */
export class ProblemsRootItem extends vscode.TreeItem {
    constructor(
        public readonly packageProblems: readonly PackageProblems[],
        totalCount: number,
    ) {
        const highCount = packageProblems.filter(p => p.highestSeverity === 'high').length;
        const label = highCount > 0
            ? `Problems (${totalCount}) — ${highCount} high severity`
            : `Problems (${totalCount})`;

        super(label, vscode.TreeItemCollapsibleState.Expanded);
        this.iconPath = new vscode.ThemeIcon(
            'warning',
            new vscode.ThemeColor('editorWarning.foreground'),
        );
        this.contextValue = 'vibrancyProblemsRoot';
    }
}

/** A package with its associated problems. */
export class PackageWithProblemsItem extends vscode.TreeItem {
    constructor(
        public readonly pkgProblems: PackageProblems,
        public readonly suggestedAction: SuggestedAction | null,
    ) {
        const count = pkgProblems.problems.length;
        const label = `${pkgProblems.package} (${count} problem${count === 1 ? '' : 's'})`;

        super(label, vscode.TreeItemCollapsibleState.Collapsed);

        this.description = suggestedAction?.type !== 'none'
            ? `💡 ${suggestedAction?.description ?? ''}`
            : undefined;

        this.iconPath = new vscode.ThemeIcon(
            severityThemeIcon(pkgProblems.highestSeverity),
            severityColor(pkgProblems.highestSeverity),
        );

        this.contextValue = 'vibrancyPackageWithProblems';
        this.command = {
            command: 'saropaLints.packageVibrancy.goToPackage',
            title: 'Go to pubspec.yaml',
            arguments: [pkgProblems.package],
        };
    }
}

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

/** Group for packages with no problems (healthy). */
export class HealthyPackagesItem extends vscode.TreeItem {
    constructor(count: number) {
        super(`Healthy Packages (${count})`, vscode.TreeItemCollapsibleState.Collapsed);
        this.iconPath = new vscode.ThemeIcon(
            'check',
            new vscode.ThemeColor('testing.iconPassed'),
        );
        this.contextValue = 'vibrancyHealthyGroup';
    }
}

/** A healthy package with no problems. */
export class HealthyPackageItem extends vscode.TreeItem {
    public readonly packageName: string;

    constructor(name: string, score: number) {
        super(name, vscode.TreeItemCollapsibleState.None);
        this.packageName = name;
        this.description = `${Math.round(score / 10)}/10`;
        this.iconPath = new vscode.ThemeIcon(
            'pass',
            new vscode.ThemeColor('testing.iconPassed'),
        );
        this.contextValue = 'vibrancyHealthyPackage';
        this.command = {
            command: 'saropaLints.packageVibrancy.goToPackage',
            title: 'Go to pubspec.yaml',
            arguments: [name],
        };
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

/** Build child items for a package with problems. */
export function buildPackageProblemsChildren(
    pkgProblems: PackageProblems,
    action: SuggestedAction | null,
    unlocks: readonly string[],
): vscode.TreeItem[] {
    const items: vscode.TreeItem[] = [];

    const pkg = pkgProblems.package;

    for (const problem of pkgProblems.problems) {
        items.push(new ProblemItem(problem, pkg));
    }

    if (action && action.type !== 'none') {
        items.push(new SuggestionItem(action, unlocks, pkg));
    }

    return items;
}
