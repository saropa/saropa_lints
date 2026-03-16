import * as vscode from 'vscode';

import {
    VibrancyResult, VibrancyCategory, DepGraphSummary,
    OverrideAnalysis, DependencySection, PackageInsight,
} from '../types';
import { categoryIcon, categoryLabel } from '../scoring/status-classifier';
import { formatPrereleaseTag } from '../scoring/prerelease-classifier';

/**
 * Tree item class definitions.
 * Extracted from tree-items.ts for modularity.
 */

const SECTION_LABELS: Record<DependencySection, string> = {
    dependencies: 'Dependencies',
    dev_dependencies: 'Dev Dependencies',
    transitive: 'Transitive',
};

const SECTION_ICONS: Record<DependencySection, string> = {
    dependencies: 'package',
    dev_dependencies: 'tools',
    transitive: 'references',
};

export function categoryColor(cat: VibrancyCategory): vscode.ThemeColor {
    switch (cat) {
        case 'vibrant': return new vscode.ThemeColor('testing.iconPassed');
        case 'quiet': return new vscode.ThemeColor('editorInfo.foreground');
        case 'legacy-locked': return new vscode.ThemeColor('editorWarning.foreground');
        case 'end-of-life': return new vscode.ThemeColor('editorError.foreground');
    }
}

export function severityIcon(severity: 'high' | 'medium' | 'low'): string {
    switch (severity) {
        case 'high': return 'error';
        case 'medium': return 'warning';
        case 'low': return 'info';
    }
}

export function severityColor(severity: 'high' | 'medium' | 'low'): vscode.ThemeColor {
    switch (severity) {
        case 'high': return new vscode.ThemeColor('editorError.foreground');
        case 'medium': return new vscode.ThemeColor('editorWarning.foreground');
        case 'low': return new vscode.ThemeColor('editorInfo.foreground');
    }
}

export class PackageItem extends vscode.TreeItem {
    constructor(
        public readonly result: VibrancyResult,
        problemCount?: number,
    ) {
        super(result.package.name, vscode.TreeItemCollapsibleState.Collapsed);
        const hasUpdate = result.updateInfo?.updateStatus
            && result.updateInfo.updateStatus !== 'up-to-date';
        const displayScore = Math.round(result.score / 10);
        let desc = `${displayScore}/10 — ${categoryLabel(result.category)}`;
        if (hasUpdate) {
            desc += ` → ${result.updateInfo!.latestVersion}`;
        }
        if (problemCount && problemCount > 0) {
            desc += ` — ${problemCount} problem${problemCount === 1 ? '' : 's'}`;
        }
        this.description = desc;
        this.iconPath = new vscode.ThemeIcon(
            categoryIcon(result.category),
            categoryColor(result.category),
        );
        const base = result.isUnused
            ? 'vibrancyPackageUnused' : 'vibrancyPackage';
        this.contextValue = hasUpdate ? base + 'Updatable' : base;
        this.command = {
            command: 'saropaLints.packageVibrancy.goToPackage',
            title: 'Go to pubspec.yaml',
            arguments: [result.package.name],
        };
    }
}

export class SuppressedGroupItem extends vscode.TreeItem {
    constructor(count: number) {
        super(`Suppressed (${count})`, vscode.TreeItemCollapsibleState.Collapsed);
        this.iconPath = new vscode.ThemeIcon(
            'eye-closed',
            new vscode.ThemeColor('disabledForeground'),
        );
        this.contextValue = 'vibrancySuppressedGroup';
    }
}

export class SectionGroupItem extends vscode.TreeItem {
    constructor(
        public readonly section: DependencySection,
        public readonly results: VibrancyResult[],
    ) {
        const label = SECTION_LABELS[section];
        const count = results.length;
        super(`${label} (${count})`, vscode.TreeItemCollapsibleState.Expanded);
        this.iconPath = new vscode.ThemeIcon(SECTION_ICONS[section]);
        this.contextValue = 'vibrancySectionGroup';
    }
}

export class SuppressedPackageItem extends PackageItem {
    constructor(result: VibrancyResult) {
        super(result);
        this.iconPath = new vscode.ThemeIcon(
            'eye-closed',
            new vscode.ThemeColor('disabledForeground'),
        );
        const hasUpdate = result.updateInfo?.updateStatus
            && result.updateInfo.updateStatus !== 'up-to-date';
        this.contextValue = hasUpdate
            ? 'vibrancyPackageSuppressedUpdatable'
            : 'vibrancyPackageSuppressed';
    }
}

export class DetailItem extends vscode.TreeItem {
    readonly url?: string;

    constructor(label: string, detail: string, url?: string) {
        super(label, vscode.TreeItemCollapsibleState.None);
        this.description = detail;
        if (url) {
            this.url = url;
            this.command = {
                command: 'saropaLints.packageVibrancy.openUrl',
                title: 'Open Link',
                arguments: [url],
            };
            this.tooltip = url;
            this.contextValue = 'vibrancyDetailLink';
        }
    }
}

export class PrereleaseItem extends vscode.TreeItem {
    constructor(
        public readonly packageName: string,
        public readonly prereleaseVersion: string,
        public readonly prereleaseTag: string | null,
    ) {
        const tag = formatPrereleaseTag(prereleaseTag);
        super(`🧪 Prerelease: ${prereleaseVersion}`, vscode.TreeItemCollapsibleState.None);
        this.description = tag;
        this.iconPath = new vscode.ThemeIcon(
            'beaker',
            new vscode.ThemeColor('editorInfo.foreground'),
        );
        this.tooltip = `Update to prerelease version ${prereleaseVersion} (${tag})`;
        this.contextValue = 'vibrancyPrerelease';
        this.command = {
            command: 'saropaLints.packageVibrancy.updateToPrerelease',
            title: 'Update to Prerelease',
            arguments: [packageName, prereleaseVersion],
        };
    }
}

export class GroupItem extends vscode.TreeItem {
    constructor(
        label: string,
        public readonly children: DetailItem[],
    ) {
        super(label, vscode.TreeItemCollapsibleState.Expanded);
    }
}

export class DepGraphSummaryItem extends vscode.TreeItem {
    constructor(public readonly summary: DepGraphSummary) {
        super('Dependency Graph', vscode.TreeItemCollapsibleState.Collapsed);
        this.iconPath = new vscode.ThemeIcon('graph');
        this.contextValue = 'vibrancyDepGraphSummary';
    }
}

export class OverridesGroupItem extends vscode.TreeItem {
    constructor(public readonly analyses: readonly OverrideAnalysis[]) {
        super(
            `Overrides (${analyses.length})`,
            vscode.TreeItemCollapsibleState.Expanded,
        );
        const staleCount = analyses.filter(a => a.status === 'stale').length;
        this.iconPath = new vscode.ThemeIcon(
            'wrench',
            staleCount > 0
                ? new vscode.ThemeColor('editorWarning.foreground')
                : new vscode.ThemeColor('editorInfo.foreground'),
        );
        this.tooltip = staleCount > 0
            ? `${staleCount} override(s) with no version conflict detected.`
            : 'Dependency overrides in pubspec.yaml.';
        this.contextValue = 'vibrancyOverridesGroup';
    }
}

export class OverrideItem extends vscode.TreeItem {
    constructor(public readonly analysis: OverrideAnalysis) {
        super(
            `${analysis.entry.name}: ${analysis.entry.version}`,
            vscode.TreeItemCollapsibleState.Collapsed,
        );
        this.description = analysis.status === 'stale' ? '⚠️ Stale' : '';
        this.iconPath = new vscode.ThemeIcon(
            analysis.status === 'stale' ? 'warning' : 'wrench',
            analysis.status === 'stale'
                ? new vscode.ThemeColor('editorWarning.foreground')
                : new vscode.ThemeColor('editorInfo.foreground'),
        );
        this.tooltip = analysis.status === 'stale'
            ? 'No version conflict detected — review this override.'
            : `Active override — ${analysis.blocker ?? 'resolves a conflict'}.`;
        this.contextValue = analysis.status === 'stale'
            ? 'vibrancyOverrideStale'
            : 'vibrancyOverrideActive';
        this.command = {
            command: 'saropaLints.packageVibrancy.goToOverride',
            title: 'Go to override in pubspec.yaml',
            arguments: [analysis.entry.name],
        };
    }
}

export class ActionItemsGroupItem extends vscode.TreeItem {
    constructor(public readonly insights: readonly PackageInsight[]) {
        super(`Action Items (${insights.length})`, vscode.TreeItemCollapsibleState.Expanded);
        this.iconPath = new vscode.ThemeIcon(
            'target',
            new vscode.ThemeColor('editorWarning.foreground'),
        );
        this.tooltip = `${insights.length} package(s) need attention. Sorted by risk.`;
        this.contextValue = 'vibrancyActionItemsGroup';
    }
}

export class InsightItem extends vscode.TreeItem {
    constructor(public readonly insight: PackageInsight) {
        const problemCount = insight.problems.length;
        super(insight.name, vscode.TreeItemCollapsibleState.Collapsed);
        this.description = `${insight.combinedRiskScore} risk — ${problemCount} problem(s)`;

        const highestSeverity = insight.problems.reduce<'low' | 'medium' | 'high'>(
            (max, p) => {
                if (p.severity === 'high') { return 'high'; }
                if (p.severity === 'medium' && max !== 'high') { return 'medium'; }
                return max;
            },
            'low',
        );
        this.iconPath = new vscode.ThemeIcon(
            severityIcon(highestSeverity),
            severityColor(highestSeverity),
        );
        this.tooltip = insight.suggestedAction ?? `${problemCount} problem(s) detected`;
        this.contextValue = 'vibrancyInsight';
        this.command = {
            command: 'saropaLints.packageVibrancy.goToPackage',
            title: 'Go to pubspec.yaml',
            arguments: [insight.name],
        };
    }
}

// Re-export budget classes from their own module so existing callers
// that import from this file continue to work without changes.
export { BudgetGroupItem, BudgetItem } from './tree-item-budget-classes';
