import * as vscode from 'vscode';
import { VibrancyResult, FamilySplit, OverrideAnalysis, DepGraphSummary, DependencySection, PackageInsight, BudgetResult } from '../types';
import {
    PackageItem, DetailItem, GroupItem, SuppressedGroupItem,
    SuppressedPackageItem, buildGroupItems, SectionGroupItem,
    OverridesGroupItem, OverrideItem, buildOverrideDetails,
    DepGraphSummaryItem, buildDepGraphSummaryDetails,
    ActionItemsGroupItem, InsightItem, buildInsightDetails,
    BudgetGroupItem, BudgetItem, PrereleaseItem,
} from './tree-items';
import {
    FamilyConflictGroupItem, FamilySplitItem, buildFamilySplitDetails,
} from './family-tree-items';
import { arePrereleasesEnabled, getPrereleaseTagFilter } from '../ui/prerelease-toggle';

type TreeNode =
    | PackageItem | GroupItem | DetailItem
    | SuppressedGroupItem | FamilyConflictGroupItem | FamilySplitItem
    | OverridesGroupItem | OverrideItem | DepGraphSummaryItem
    | SectionGroupItem | ActionItemsGroupItem | InsightItem
    | BudgetGroupItem | BudgetItem | PrereleaseItem;

export class VibrancyTreeProvider implements vscode.TreeDataProvider<TreeNode> {
    private _results: VibrancyResult[] = [];
    private _familySplits: FamilySplit[] = [];
    private _overrideAnalyses: OverrideAnalysis[] = [];
    private _depGraphSummary: DepGraphSummary | null = null;
    private _insights: PackageInsight[] = [];
    private _budgetResults: BudgetResult[] = [];
    private _budgetSummary: string = '';
    private readonly _onDidChangeTreeData = new vscode.EventEmitter<void>();
    readonly onDidChangeTreeData = this._onDidChangeTreeData.event;

    /** Update results and refresh the tree. Sorted worst-first. */
    updateResults(results: VibrancyResult[]): void {
        this._results = [...results].sort((a, b) => a.score - b.score);
        this._onDidChangeTreeData.fire();
    }

    /** Update detected family version splits. */
    updateFamilySplits(splits: FamilySplit[]): void {
        this._familySplits = splits;
        this._onDidChangeTreeData.fire();
    }

    /** Update dependency graph summary. */
    updateDepGraphSummary(summary: DepGraphSummary | null): void {
        this._depGraphSummary = summary;
        this._onDidChangeTreeData.fire();
    }

    /** Update override analyses. */
    updateOverrideAnalyses(analyses: OverrideAnalysis[]): void {
        this._overrideAnalyses = analyses;
        this._onDidChangeTreeData.fire();
    }

    /** Update consolidated insights. */
    updateInsights(insights: readonly PackageInsight[]): void {
        this._insights = [...insights];
        this._onDidChangeTreeData.fire();
    }

    /** Update budget check results. */
    updateBudgetResults(results: readonly BudgetResult[], summary: string): void {
        this._budgetResults = [...results];
        this._budgetSummary = summary;
        this._onDidChangeTreeData.fire();
    }

    /** Re-fire the change event to refresh the tree display. */
    refresh(): void {
        this._onDidChangeTreeData.fire();
    }

    getResults(): readonly VibrancyResult[] {
        return this._results;
    }

    /** Get a single result by package name. Used when an Action Items (InsightItem) selection should sync the Package Details panel. */
    getResultByName(name: string): VibrancyResult | undefined {
        return this._results.find(r => r.package.name === name);
    }

    getTreeItem(element: TreeNode): vscode.TreeItem {
        return element;
    }

    getChildren(element?: TreeNode): TreeNode[] {
        if (!element) {
            return this._buildRootChildren();
        }
        if (element instanceof BudgetGroupItem) {
            return element.budgetResults
                .filter(r => r.status !== 'unconfigured')
                .map(r => new BudgetItem(r));
        }
        if (element instanceof ActionItemsGroupItem) {
            return element.insights.map(i => new InsightItem(i));
        }
        if (element instanceof InsightItem) {
            return buildInsightDetails(element.insight);
        }
        if (element instanceof FamilyConflictGroupItem) {
            return element.splits.map(s => new FamilySplitItem(s));
        }
        if (element instanceof FamilySplitItem) {
            return buildFamilySplitDetails(element.split);
        }
        if (element instanceof OverridesGroupItem) {
            return element.analyses.map(a => new OverrideItem(a));
        }
        if (element instanceof OverrideItem) {
            return buildOverrideDetails(element.analysis);
        }
        if (element instanceof DepGraphSummaryItem) {
            return buildDepGraphSummaryDetails(element.summary);
        }
        if (element instanceof SuppressedGroupItem) {
            return this._getSuppressedResults().map(
                r => new SuppressedPackageItem(r),
            );
        }
        if (element instanceof SectionGroupItem) {
            return element.results.map(r => new PackageItem(r));
        }
        if (element instanceof PackageItem) {
            const children: TreeNode[] = [];
            if (arePrereleasesEnabled() && element.result.latestPrerelease) {
                const tagFilter = getPrereleaseTagFilter();
                const tag = element.result.prereleaseTag;
                const passesFilter = tagFilter.length === 0
                    || (tag && tagFilter.some(f => f.toLowerCase() === tag.toLowerCase()));
                if (passesFilter) {
                    children.push(new PrereleaseItem(
                        element.result.package.name,
                        element.result.latestPrerelease,
                        element.result.prereleaseTag,
                    ));
                }
            }
            children.push(...buildGroupItems(element.result));
            return children;
        }
        if (element instanceof GroupItem) {
            return element.children;
        }
        return [];
    }

    private _buildRootChildren(): TreeNode[] {
        const items: TreeNode[] = [];

        const configuredBudgets = this._budgetResults.filter(
            r => r.status !== 'unconfigured',
        );
        if (configuredBudgets.length > 0) {
            items.push(new BudgetGroupItem(this._budgetResults, this._budgetSummary));
        }

        if (this._insights.length > 0) {
            items.push(new ActionItemsGroupItem(this._insights));
        }
        if (this._depGraphSummary) {
            items.push(new DepGraphSummaryItem(this._depGraphSummary));
        }
        if (this._overrideAnalyses.length > 0) {
            items.push(new OverridesGroupItem(this._overrideAnalyses));
        }
        if (this._familySplits.length > 0) {
            items.push(
                new FamilyConflictGroupItem(this._familySplits),
            );
        }
        const suppressed = this._getSuppressedSet();
        const active = this._results.filter(
            r => !suppressed.has(r.package.name),
        );

        const grouping = this._getTreeGrouping();
        if (grouping === 'section') {
            this._buildSectionGroups(active, items);
        } else {
            for (const r of active) {
                items.push(new PackageItem(r));
            }
        }

        const suppressedCount = this._results.length - active.length;
        if (suppressedCount > 0) {
            items.push(new SuppressedGroupItem(suppressedCount));
        }
        return items;
    }

    private _getTreeGrouping(): 'none' | 'section' {
        const config = vscode.workspace.getConfiguration('saropaLints.packageVibrancy');
        return config.get<'none' | 'section'>('treeGrouping', 'none');
    }

    private _buildSectionGroups(
        results: VibrancyResult[],
        items: TreeNode[],
    ): void {
        const sections: DependencySection[] = [
            'dependencies',
            'dev_dependencies',
            'transitive',
        ];

        for (const section of sections) {
            const sectionResults = results
                .filter(r => r.package.section === section)
                .sort((a, b) => a.score - b.score);

            if (sectionResults.length > 0) {
                items.push(new SectionGroupItem(section, sectionResults));
            }
        }
    }

    private _getSuppressedSet(): Set<string> {
        const config = vscode.workspace.getConfiguration(
            'saropaLints.packageVibrancy',
        );
        return new Set(config.get<string[]>('suppressedPackages', []));
    }

    private _getSuppressedResults(): VibrancyResult[] {
        const suppressed = this._getSuppressedSet();
        return this._results.filter(
            r => suppressed.has(r.package.name),
        );
    }
}
