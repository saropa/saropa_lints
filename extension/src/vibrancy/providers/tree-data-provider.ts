import * as vscode from 'vscode';
import { VibrancyResult, VibrancyCategory, FamilySplit, OverrideAnalysis, DepGraphSummary, DependencySection, PackageInsight, BudgetResult } from '../types';
import {
    PackageItem, DetailItem, GroupItem, SuppressedGroupItem,
    SuppressedPackageItem, buildGroupItems, SectionGroupItem,
    OverridesGroupItem, OverrideItem, buildOverrideDetails,
    DepGraphSummaryItem, buildDepGraphSummaryDetails,
    ActionItemsGroupItem, InsightItem, buildInsightDetails,
    BudgetGroupItem, BudgetItem, PrereleaseItem, SeverityGroupItem,
} from './tree-items';
import {
    FamilyConflictGroupItem, FamilySplitItem, buildFamilySplitDetails,
} from './family-tree-items';
import { ProblemItem, SuggestionItem } from './problem-tree-items';
import { ProblemRegistry } from '../problems/problem-registry';
import {
    determineBestAction, getUnlockedPackages, SuggestedAction,
} from '../problems/problem-actions';
import { arePrereleasesEnabled, getPrereleaseTagFilter } from '../ui/prerelease-toggle';
import { VibrancyFilterManager, VibrancyFilterState, VibrancyViewMode } from './vibrancy-filter-state';
import { ProblemSeverity, ProblemType } from '../problems/problem-types';

type TreeNode =
    | PackageItem | GroupItem | DetailItem
    | SuppressedGroupItem | FamilyConflictGroupItem | FamilySplitItem
    | OverridesGroupItem | OverrideItem | DepGraphSummaryItem
    | SectionGroupItem | ActionItemsGroupItem | InsightItem
    | BudgetGroupItem | BudgetItem | PrereleaseItem
    | ProblemItem | SuggestionItem | SeverityGroupItem;

export class VibrancyTreeProvider implements vscode.TreeDataProvider<TreeNode> {
    private _results: VibrancyResult[] = [];
    private _familySplits: FamilySplit[] = [];
    private _overrideAnalyses: OverrideAnalysis[] = [];
    private _depGraphSummary: DepGraphSummary | null = null;
    private _insights: PackageInsight[] = [];
    private _budgetResults: BudgetResult[] = [];
    private _budgetSummary: string = '';

    // Problem data (absorbed from ProblemTreeProvider)
    private _registry: ProblemRegistry = new ProblemRegistry();
    private _actionCache = new Map<string, SuggestedAction>();
    private _unlocksCache = new Map<string, readonly string[]>();

    // Filter state
    private readonly _filterManager = new VibrancyFilterManager();

    // When true, getTreeItem overrides Collapsed → Expanded.
    // Cleared on next data update (scan, registry change, etc.).
    private _expandAllOverride = false;

    private readonly _onDidChangeTreeData = new vscode.EventEmitter<void>();
    readonly onDidChangeTreeData = this._onDidChangeTreeData.event;

    /** Expand all tree nodes by forcing Collapsed → Expanded and refreshing. */
    expandAll(): void {
        this._expandAllOverride = true;
        this._onDidChangeTreeData.fire();
    }

    /** Update results and refresh the tree. Sorted worst-first. */
    updateResults(results: VibrancyResult[]): void {
        this._expandAllOverride = false;
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

    /** Update problem registry and rebuild caches. */
    updateRegistry(registry: ProblemRegistry): void {
        this._registry = registry;
        this._rebuildProblemCaches();
        this._onDidChangeTreeData.fire();
    }

    /** Get the current problem registry. */
    getRegistry(): ProblemRegistry {
        return this._registry;
    }

    /** Re-fire the change event to refresh the tree display. */
    refresh(): void {
        this._onDidChangeTreeData.fire();
    }

    getResults(): readonly VibrancyResult[] {
        return this._results;
    }

    /** Get a single result by package name. */
    getResultByName(name: string): VibrancyResult | undefined {
        return this._results.find(r => r.package.name === name);
    }

    // --- Filter API ---

    setTextFilter(value: string): void {
        if (this._filterManager.setTextFilter(value)) {
            this._onDidChangeTreeData.fire();
        }
    }

    setViewMode(mode: VibrancyViewMode): void {
        if (this._filterManager.setViewMode(mode)) {
            this._onDidChangeTreeData.fire();
        }
    }

    setSeverityFilter(severities: ReadonlySet<ProblemSeverity>): void {
        if (this._filterManager.setSeverityFilter(severities)) {
            this._onDidChangeTreeData.fire();
        }
    }

    setProblemTypeFilter(types: ReadonlySet<ProblemType>): void {
        if (this._filterManager.setProblemTypeFilter(types)) {
            this._onDidChangeTreeData.fire();
        }
    }

    setCategoryFilter(categories: ReadonlySet<VibrancyCategory>): void {
        if (this._filterManager.setCategoryFilter(categories)) {
            this._onDidChangeTreeData.fire();
        }
    }

    setSectionFilter(sections: ReadonlySet<DependencySection>): void {
        if (this._filterManager.setSectionFilter(sections)) {
            this._onDidChangeTreeData.fire();
        }
    }

    getFilterState(): VibrancyFilterState {
        return this._filterManager.getState();
    }

    clearFilters(): void {
        this._filterManager.clearAll();
        this._onDidChangeTreeData.fire();
    }

    // --- Tree data ---

    getTreeItem(element: TreeNode): vscode.TreeItem {
        // When expand-all is active, force Collapsed items to Expanded
        if (this._expandAllOverride
            && element.collapsibleState === vscode.TreeItemCollapsibleState.Collapsed) {
            element.collapsibleState = vscode.TreeItemCollapsibleState.Expanded;
        }
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
        if (element instanceof SeverityGroupItem) {
            return element.results.map(r => this._buildPackageItem(r));
        }
        if (element instanceof SectionGroupItem) {
            return element.results.map(
                r => this._buildPackageItem(r),
            );
        }
        if (element instanceof PackageItem) {
            return this._buildPackageChildren(element);
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

        // Apply suppression, then filters
        const suppressed = this._getSuppressedSet();
        const active = this._results.filter(
            r => !suppressed.has(r.package.name),
        );
        const filtered = this._filterManager.filterResults(active, this._registry);

        const grouping = this._getTreeGrouping();
        if (grouping === 'section') {
            this._buildSectionGroups(filtered, items);
        } else {
            this._buildSeverityGroups(filtered, items);
        }

        const suppressedCount = this._results.length - active.length;
        if (suppressedCount > 0) {
            items.push(new SuppressedGroupItem(suppressedCount));
        }
        return items;
    }

    /** Build a PackageItem with its problem count attached. */
    private _buildPackageItem(result: VibrancyResult): PackageItem {
        const problemCount = this._registry.getForPackage(result.package.name).length;
        return new PackageItem(result, problemCount);
    }

    /** Build children for a package: problems + suggestion + prerelease + detail groups. */
    private _buildPackageChildren(element: PackageItem): TreeNode[] {
        const children: TreeNode[] = [];
        const pkgName = element.result.package.name;

        // Problem items for this package
        const problems = this._registry.getForPackage(pkgName);
        for (const problem of problems) {
            children.push(new ProblemItem(problem, pkgName));
        }

        // Suggested action (if any problems exist)
        const action = this._actionCache.get(pkgName);
        if (action && action.type !== 'none') {
            const unlocks = this._unlocksCache.get(pkgName) ?? [];
            children.push(new SuggestionItem(action, unlocks, pkgName));
        }

        // Prerelease item (existing logic)
        if (arePrereleasesEnabled() && element.result.latestPrerelease) {
            const tagFilter = getPrereleaseTagFilter();
            const tag = element.result.prereleaseTag;
            const passesFilter = tagFilter.length === 0
                || (tag && tagFilter.some(f => f.toLowerCase() === tag.toLowerCase()));
            if (passesFilter) {
                children.push(new PrereleaseItem(
                    pkgName,
                    element.result.latestPrerelease,
                    element.result.prereleaseTag,
                ));
            }
        }

        // Detail groups (Version, Update, Community, etc.)
        children.push(...buildGroupItems(element.result));
        return children;
    }

    private _rebuildProblemCaches(): void {
        this._actionCache.clear();
        this._unlocksCache.clear();

        for (const pkgProblems of this._registry.getAllSortedByPriority()) {
            const action = determineBestAction(pkgProblems.problems, []);
            this._actionCache.set(pkgProblems.package, action);

            const unlocks = getUnlockedPackages(pkgProblems.package, this._registry);
            this._unlocksCache.set(pkgProblems.package, unlocks);
        }
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

    /** Group packages by their worst problem severity, alphabetized within each group. */
    private _buildSeverityGroups(
        results: VibrancyResult[],
        items: TreeNode[],
    ): void {
        const groups = new Map<string, VibrancyResult[]>([
            ['high', []], ['medium', []], ['low', []], ['healthy', []],
        ]);

        for (const result of results) {
            const severity = this._getPackageSeverity(result);
            groups.get(severity)!.push(result);
        }

        const order = ['high', 'medium', 'low', 'healthy'] as const;
        for (const severity of order) {
            const list = (groups.get(severity) ?? [])
                .sort((a, b) => a.package.name.localeCompare(b.package.name));
            if (list.length > 0) {
                items.push(new SeverityGroupItem(severity, list));
            }
        }
    }

    /** Derive worst severity for a package from registry problems or vibrancy category. */
    private _getPackageSeverity(
        result: VibrancyResult,
    ): 'high' | 'medium' | 'low' | 'healthy' {
        const problems = this._registry.getForPackage(result.package.name);
        if (problems.some(p => p.severity === 'high')) { return 'high'; }
        if (problems.some(p => p.severity === 'medium')) { return 'medium'; }
        if (problems.length > 0) { return 'low'; }
        // No registry problems — fall back to vibrancy category
        if (result.category === 'end-of-life' || result.category === 'abandoned') {
            return 'high';
        }
        if (result.category === 'outdated') { return 'medium'; }
        return 'healthy';
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
