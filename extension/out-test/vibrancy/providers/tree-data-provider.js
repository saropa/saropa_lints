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
exports.VibrancyTreeProvider = void 0;
const vscode = __importStar(require("vscode"));
const tree_items_1 = require("./tree-items");
const family_tree_items_1 = require("./family-tree-items");
const problem_tree_items_1 = require("./problem-tree-items");
const problem_registry_1 = require("../problems/problem-registry");
const problem_actions_1 = require("../problems/problem-actions");
const prerelease_toggle_1 = require("../ui/prerelease-toggle");
const vibrancy_filter_state_1 = require("./vibrancy-filter-state");
class VibrancyTreeProvider {
    _results = [];
    _familySplits = [];
    _overrideAnalyses = [];
    _depGraphSummary = null;
    _insights = [];
    _budgetResults = [];
    _budgetSummary = '';
    // Problem data (absorbed from ProblemTreeProvider)
    _registry = new problem_registry_1.ProblemRegistry();
    _actionCache = new Map();
    _unlocksCache = new Map();
    // Filter state
    _filterManager = new vibrancy_filter_state_1.VibrancyFilterManager();
    _onDidChangeTreeData = new vscode.EventEmitter();
    onDidChangeTreeData = this._onDidChangeTreeData.event;
    /** Update results and refresh the tree. Sorted worst-first. */
    updateResults(results) {
        this._results = [...results].sort((a, b) => a.score - b.score);
        this._onDidChangeTreeData.fire();
    }
    /** Update detected family version splits. */
    updateFamilySplits(splits) {
        this._familySplits = splits;
        this._onDidChangeTreeData.fire();
    }
    /** Update dependency graph summary. */
    updateDepGraphSummary(summary) {
        this._depGraphSummary = summary;
        this._onDidChangeTreeData.fire();
    }
    /** Update override analyses. */
    updateOverrideAnalyses(analyses) {
        this._overrideAnalyses = analyses;
        this._onDidChangeTreeData.fire();
    }
    /** Update consolidated insights. */
    updateInsights(insights) {
        this._insights = [...insights];
        this._onDidChangeTreeData.fire();
    }
    /** Update budget check results. */
    updateBudgetResults(results, summary) {
        this._budgetResults = [...results];
        this._budgetSummary = summary;
        this._onDidChangeTreeData.fire();
    }
    /** Update problem registry and rebuild caches. */
    updateRegistry(registry) {
        this._registry = registry;
        this._rebuildProblemCaches();
        this._onDidChangeTreeData.fire();
    }
    /** Get the current problem registry. */
    getRegistry() {
        return this._registry;
    }
    /** Re-fire the change event to refresh the tree display. */
    refresh() {
        this._onDidChangeTreeData.fire();
    }
    getResults() {
        return this._results;
    }
    /** Get a single result by package name. */
    getResultByName(name) {
        return this._results.find(r => r.package.name === name);
    }
    // --- Filter API ---
    setTextFilter(value) {
        if (this._filterManager.setTextFilter(value)) {
            this._onDidChangeTreeData.fire();
        }
    }
    setViewMode(mode) {
        if (this._filterManager.setViewMode(mode)) {
            this._onDidChangeTreeData.fire();
        }
    }
    setSeverityFilter(severities) {
        if (this._filterManager.setSeverityFilter(severities)) {
            this._onDidChangeTreeData.fire();
        }
    }
    setProblemTypeFilter(types) {
        if (this._filterManager.setProblemTypeFilter(types)) {
            this._onDidChangeTreeData.fire();
        }
    }
    setCategoryFilter(categories) {
        if (this._filterManager.setCategoryFilter(categories)) {
            this._onDidChangeTreeData.fire();
        }
    }
    setSectionFilter(sections) {
        if (this._filterManager.setSectionFilter(sections)) {
            this._onDidChangeTreeData.fire();
        }
    }
    getFilterState() {
        return this._filterManager.getState();
    }
    clearFilters() {
        this._filterManager.clearAll();
        this._onDidChangeTreeData.fire();
    }
    // --- Tree data ---
    getTreeItem(element) {
        return element;
    }
    getChildren(element) {
        if (!element) {
            return this._buildRootChildren();
        }
        if (element instanceof tree_items_1.BudgetGroupItem) {
            return element.budgetResults
                .filter(r => r.status !== 'unconfigured')
                .map(r => new tree_items_1.BudgetItem(r));
        }
        if (element instanceof tree_items_1.ActionItemsGroupItem) {
            return element.insights.map(i => new tree_items_1.InsightItem(i));
        }
        if (element instanceof tree_items_1.InsightItem) {
            return (0, tree_items_1.buildInsightDetails)(element.insight);
        }
        if (element instanceof family_tree_items_1.FamilyConflictGroupItem) {
            return element.splits.map(s => new family_tree_items_1.FamilySplitItem(s));
        }
        if (element instanceof family_tree_items_1.FamilySplitItem) {
            return (0, family_tree_items_1.buildFamilySplitDetails)(element.split);
        }
        if (element instanceof tree_items_1.OverridesGroupItem) {
            return element.analyses.map(a => new tree_items_1.OverrideItem(a));
        }
        if (element instanceof tree_items_1.OverrideItem) {
            return (0, tree_items_1.buildOverrideDetails)(element.analysis);
        }
        if (element instanceof tree_items_1.DepGraphSummaryItem) {
            return (0, tree_items_1.buildDepGraphSummaryDetails)(element.summary);
        }
        if (element instanceof tree_items_1.SuppressedGroupItem) {
            return this._getSuppressedResults().map(r => new tree_items_1.SuppressedPackageItem(r));
        }
        if (element instanceof tree_items_1.SectionGroupItem) {
            return element.results.map(r => this._buildPackageItem(r));
        }
        if (element instanceof tree_items_1.PackageItem) {
            return this._buildPackageChildren(element);
        }
        if (element instanceof tree_items_1.GroupItem) {
            return element.children;
        }
        return [];
    }
    _buildRootChildren() {
        const items = [];
        // Problem summary at the top (severity counts bar)
        const totalProblems = this._registry.totalCount;
        if (totalProblems > 0) {
            const counts = this._registry.countBySeverity();
            items.push(new problem_tree_items_1.ProblemSummaryItem(counts.high, counts.medium, counts.low));
        }
        const configuredBudgets = this._budgetResults.filter(r => r.status !== 'unconfigured');
        if (configuredBudgets.length > 0) {
            items.push(new tree_items_1.BudgetGroupItem(this._budgetResults, this._budgetSummary));
        }
        if (this._insights.length > 0) {
            items.push(new tree_items_1.ActionItemsGroupItem(this._insights));
        }
        if (this._depGraphSummary) {
            items.push(new tree_items_1.DepGraphSummaryItem(this._depGraphSummary));
        }
        if (this._overrideAnalyses.length > 0) {
            items.push(new tree_items_1.OverridesGroupItem(this._overrideAnalyses));
        }
        if (this._familySplits.length > 0) {
            items.push(new family_tree_items_1.FamilyConflictGroupItem(this._familySplits));
        }
        // Apply suppression, then filters
        const suppressed = this._getSuppressedSet();
        const active = this._results.filter(r => !suppressed.has(r.package.name));
        const filtered = this._filterManager.filterResults(active, this._registry);
        const grouping = this._getTreeGrouping();
        if (grouping === 'section') {
            this._buildSectionGroups(filtered, items);
        }
        else {
            for (const r of filtered) {
                items.push(this._buildPackageItem(r));
            }
        }
        const suppressedCount = this._results.length - active.length;
        if (suppressedCount > 0) {
            items.push(new tree_items_1.SuppressedGroupItem(suppressedCount));
        }
        return items;
    }
    /** Build a PackageItem with its problem count attached. */
    _buildPackageItem(result) {
        const problemCount = this._registry.getForPackage(result.package.name).length;
        return new tree_items_1.PackageItem(result, problemCount);
    }
    /** Build children for a package: problems + suggestion + prerelease + detail groups. */
    _buildPackageChildren(element) {
        const children = [];
        const pkgName = element.result.package.name;
        // Problem items for this package
        const problems = this._registry.getForPackage(pkgName);
        for (const problem of problems) {
            children.push(new problem_tree_items_1.ProblemItem(problem, pkgName));
        }
        // Suggested action (if any problems exist)
        const action = this._actionCache.get(pkgName);
        if (action && action.type !== 'none') {
            const unlocks = this._unlocksCache.get(pkgName) ?? [];
            children.push(new problem_tree_items_1.SuggestionItem(action, unlocks, pkgName));
        }
        // Prerelease item (existing logic)
        if ((0, prerelease_toggle_1.arePrereleasesEnabled)() && element.result.latestPrerelease) {
            const tagFilter = (0, prerelease_toggle_1.getPrereleaseTagFilter)();
            const tag = element.result.prereleaseTag;
            const passesFilter = tagFilter.length === 0
                || (tag && tagFilter.some(f => f.toLowerCase() === tag.toLowerCase()));
            if (passesFilter) {
                children.push(new tree_items_1.PrereleaseItem(pkgName, element.result.latestPrerelease, element.result.prereleaseTag));
            }
        }
        // Detail groups (Version, Update, Community, etc.)
        children.push(...(0, tree_items_1.buildGroupItems)(element.result));
        return children;
    }
    _rebuildProblemCaches() {
        this._actionCache.clear();
        this._unlocksCache.clear();
        for (const pkgProblems of this._registry.getAllSortedByPriority()) {
            const action = (0, problem_actions_1.determineBestAction)(pkgProblems.problems, []);
            this._actionCache.set(pkgProblems.package, action);
            const unlocks = (0, problem_actions_1.getUnlockedPackages)(pkgProblems.package, this._registry);
            this._unlocksCache.set(pkgProblems.package, unlocks);
        }
    }
    _getTreeGrouping() {
        const config = vscode.workspace.getConfiguration('saropaLints.packageVibrancy');
        return config.get('treeGrouping', 'none');
    }
    _buildSectionGroups(results, items) {
        const sections = [
            'dependencies',
            'dev_dependencies',
            'transitive',
        ];
        for (const section of sections) {
            const sectionResults = results
                .filter(r => r.package.section === section)
                .sort((a, b) => a.score - b.score);
            if (sectionResults.length > 0) {
                items.push(new tree_items_1.SectionGroupItem(section, sectionResults));
            }
        }
    }
    _getSuppressedSet() {
        const config = vscode.workspace.getConfiguration('saropaLints.packageVibrancy');
        return new Set(config.get('suppressedPackages', []));
    }
    _getSuppressedResults() {
        const suppressed = this._getSuppressedSet();
        return this._results.filter(r => suppressed.has(r.package.name));
    }
}
exports.VibrancyTreeProvider = VibrancyTreeProvider;
//# sourceMappingURL=tree-data-provider.js.map