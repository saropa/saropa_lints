import * as vscode from 'vscode';
import { VibrancyResult } from '../types';
import { ProblemRegistry } from '../problems/problem-registry';
import {
    determineBestAction, getUnlockedPackages, SuggestedAction,
} from '../problems/problem-actions';
import {
    ProblemsRootItem, PackageWithProblemsItem, ProblemItem,
    SuggestionItem, HealthyPackagesItem, HealthyPackageItem,
    ProblemSummaryItem, buildPackageProblemsChildren,
} from './problem-tree-items';

type TreeNode =
    | ProblemsRootItem
    | PackageWithProblemsItem
    | ProblemItem
    | SuggestionItem
    | HealthyPackagesItem
    | HealthyPackageItem
    | ProblemSummaryItem;

/**
 * Tree data provider that displays packages organized by problems.
 * Provides a problem-centric view of dependencies.
 */
export class ProblemTreeProvider implements vscode.TreeDataProvider<TreeNode> {
    private _registry: ProblemRegistry = new ProblemRegistry();
    private _healthyPackages: Array<{ name: string; score: number }> = [];
    private _actionCache = new Map<string, SuggestedAction>();
    private _unlocksCache = new Map<string, readonly string[]>();

    private readonly _onDidChangeTreeData = new vscode.EventEmitter<void>();
    readonly onDidChangeTreeData = this._onDidChangeTreeData.event;

    /**
     * Update the registry and refresh the tree.
     */
    updateRegistry(registry: ProblemRegistry): void {
        this._registry = registry;
        this._rebuildCaches();
        this._onDidChangeTreeData.fire();
    }

    /**
     * Set the list of healthy packages (those with no problems).
     */
    setHealthyPackages(packages: readonly VibrancyResult[]): void {
        this._healthyPackages = packages.map(p => ({
            name: p.package.name,
            score: p.score,
        }));
        this._onDidChangeTreeData.fire();
    }

    /**
     * Force a refresh of the tree.
     */
    refresh(): void {
        this._onDidChangeTreeData.fire();
    }

    /**
     * Get the current registry.
     */
    getRegistry(): ProblemRegistry {
        return this._registry;
    }

    getTreeItem(element: TreeNode): vscode.TreeItem {
        return element;
    }

    getChildren(element?: TreeNode): TreeNode[] {
        if (!element) {
            return this._buildRootChildren();
        }

        if (element instanceof ProblemsRootItem) {
            return this._buildProblemsChildren(element);
        }

        if (element instanceof PackageWithProblemsItem) {
            return this._buildPackageChildren(element);
        }

        if (element instanceof HealthyPackagesItem) {
            return this._healthyPackages.map(
                p => new HealthyPackageItem(p.name, p.score),
            );
        }

        return [];
    }

    private _buildRootChildren(): TreeNode[] {
        const items: TreeNode[] = [];

        const sorted = this._registry.getAllSortedByPriority();
        const totalProblems = this._registry.totalCount;

        if (totalProblems > 0) {
            const counts = this._registry.countBySeverity();
            items.push(new ProblemSummaryItem(counts.high, counts.medium, counts.low));
            items.push(new ProblemsRootItem(sorted, totalProblems));
        }

        if (this._healthyPackages.length > 0) {
            items.push(new HealthyPackagesItem(this._healthyPackages.length));
        }

        return items;
    }

    private _buildProblemsChildren(root: ProblemsRootItem): TreeNode[] {
        return root.packageProblems.map(pkgProblems => {
            const action = this._actionCache.get(pkgProblems.package) ?? null;
            return new PackageWithProblemsItem(pkgProblems, action);
        });
    }

    private _buildPackageChildren(pkg: PackageWithProblemsItem): TreeNode[] {
        const action = this._actionCache.get(pkg.pkgProblems.package) ?? null;
        const unlocks = this._unlocksCache.get(pkg.pkgProblems.package) ?? [];
        return buildPackageProblemsChildren(pkg.pkgProblems, action, unlocks);
    }

    private _rebuildCaches(): void {
        this._actionCache.clear();
        this._unlocksCache.clear();

        for (const pkgProblems of this._registry.getAllSortedByPriority()) {
            const action = determineBestAction(pkgProblems.problems, []);
            this._actionCache.set(pkgProblems.package, action);

            const unlocks = getUnlockedPackages(pkgProblems.package, this._registry);
            this._unlocksCache.set(pkgProblems.package, unlocks);
        }
    }
}

/**
 * Register the problem tree view.
 */
export function registerProblemTreeView(
    context: vscode.ExtensionContext,
    provider: ProblemTreeProvider,
): vscode.TreeView<TreeNode> {
    const treeView = vscode.window.createTreeView(
        'saropaLints.packageVibrancy.problems',
        { treeDataProvider: provider },
    );
    treeView.description = 'Package Problems';
    context.subscriptions.push(treeView);
    return treeView;
}
