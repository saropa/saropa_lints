import * as vscode from 'vscode';
import { CacheService } from './services/cache-service';
import { VibrancyTreeProvider } from './providers/tree-data-provider';
import { VibrancyDiagnostics } from './providers/diagnostics';
import { VibrancyCodeActionProvider } from './providers/code-action-provider';
import { VibrancyCodeLensProvider, setCodeLensToggle, setPrereleaseToggle } from './providers/codelens-provider';
import { VibrancyHoverProvider } from './providers/hover-provider';
import { VibrancyStatusBar } from './ui/status-bar';
import { CodeLensToggle } from './ui/codelens-toggle';
import { PrereleaseToggle } from './ui/prerelease-toggle';
import { VibrancyReportPanel } from './views/report-webview';
import { KnownIssuesPanel } from './views/known-issues-webview';
import { AboutPanel } from './views/about-webview';
import { ComparisonPanel } from './views/comparison-webview';
import { DetailViewProvider, DETAIL_VIEW_ID } from './views/detail-view-provider';
import { DetailLogger, DETAIL_CHANNEL_NAME } from './services/detail-logger';
import { exportReports, ReportMetadata } from './services/report-exporter';
import { exportSbomReport } from './services/sbom-exporter';
import { ScanLogger } from './services/scan-logger';
import { VibrancyResult, VibrancyCategory, DependencySection, isUnusedRemovalEligibleSection } from './types';
import { countByCategory } from './scoring/status-classifier';
import { registerTreeCommands } from './providers/tree-commands';
import { registerUpgradeCommand } from './providers/upgrade-command';
import { registerAnnotateCommand } from './providers/annotate-command';
import { readScanConfig, scanPackages, buildScanMeta, ParsedDeps, findAndParseDeps } from './scan-helpers';
import { scanDartImports } from './services/import-scanner';
import { detectUnused } from './scoring/unused-detector';
import { fetchFlutterReleases } from './services/flutter-releases';
import { snapshotVersions, notifyLockDiff } from './services/lock-diff-notifier';
import { detectFamilySplits } from './scoring/family-conflict-detector';
import { AdoptionGateProvider } from './providers/adoption-gate';
import { enrichWithBlockers } from './services/blocker-enricher';
import { buildUpgradeOrder, setOverrideAnalyses } from './scoring/upgrade-sequencer';
import { executeUpgradePlan, formatUpgradePlan, formatUpgradeReport } from './services/upgrade-executor';
import { fetchDepGraph, buildReverseDeps } from './services/dep-graph';
import { parseDependencyOverrides } from './services/pubspec-parser';
import {
    countTransitives, findSharedDeps, enrichTransitiveInfo, buildDepGraphSummary,
    calcTransitiveRiskPenalty,
} from './scoring/transitive-analyzer';
import { allKnownIssues } from './scoring/known-issues';
import { runOverrideAnalysis } from './services/override-runner';
import { OverrideAnalysis, NewVersionNotification, PackageInsight } from './types';
import { consolidateInsights } from './scoring/consolidate-insights';
import {
    FreshnessWatcher, formatNotificationMessage, createNotificationActions,
} from './services/freshness-watcher';
import {
    addSuppressedPackage, addSuppressedPackages, clearSuppressedPackages,
    getVulnScanEnabled, getGitHubAdvisoryEnabled, getGithubToken,
} from './services/config-service';
import { queryVulnerabilities } from './services/osv-api';
import { queryGitHubAdvisories, mergeVulnerabilities } from './services/github-advisory-api';
import { sortDependencies } from './services/pubspec-sorter';
import { clearIndicatorCache } from './services/indicator-config';
import { findPubspecYaml } from './services/pubspec-editor';
import { VibrancyStateManager } from './state';
import {
    readBudgetConfig, checkBudgets, formatBudgetSummary, hasBudgets,
} from './scoring/budget-checker';
import { BudgetResult, ComparisonData } from './types';
import { resultToComparisonData } from './scoring/comparison-ranker';
import {
    fetchPackageInfo, fetchPackageMetrics, fetchPublisher, fetchArchiveSize,
} from './services/pub-dev-api';
import { extractGitHubRepo, fetchRepoMetrics } from './services/github-api';
import { calcBloatRating } from './scoring/bloat-calculator';
import { SaveTaskRunner } from './services/save-task-runner';
import { bulkUpdate } from './services/bulk-updater';
import { IncrementFilter } from './scoring/version-increment';
import { RegistryService } from './services/registry-service';
import { registerRegistryCommands } from './providers/registry-commands';
import { suggestThresholds, formatThresholdsSummary } from './services/threshold-suggester';
import {
    generateCiWorkflow, getDefaultOutputPath, getAvailablePlatforms,
} from './services/ci-generator';
import { CiPlatform, CiThresholds } from './types';
import { ProblemRegistry, collectProblemsFromResults, CollectorContext } from './problems';
import { findPackageRange } from './services/pubspec-parser';
import { ProblemSeverity, ProblemType, problemTypeLabel } from './problems/problem-types';
import {
    ALL_SEVERITIES, ALL_PROBLEM_TYPES, ALL_CATEGORIES, ALL_SECTIONS,
} from './providers/vibrancy-filter-state';
import { SECTION_LABELS } from './providers/tree-item-classes';
import { categoryLabel } from './scoring/status-classifier';

let latestResults: VibrancyResult[] = [];
let lastParsedDeps: ParsedDeps | null = null;
let lastReverseDeps: ReadonlyMap<string, readonly import('./types').DepEdge[]> | null = null;
let lastOverrideAnalyses: OverrideAnalysis[] = [];
let lastInsights: PackageInsight[] = [];
let lastBudgetResults: BudgetResult[] = [];
let lastScanMeta: ReportMetadata = {
    flutterVersion: 'unknown',
    dartVersion: 'unknown',
    executionTimeMs: 0,
};
let freshnessWatcher: FreshnessWatcher | null = null;
let stateManager: VibrancyStateManager | null = null;
let detailViewProvider: DetailViewProvider | null = null;
let detailLogger: DetailLogger | null = null;
let detailChannel: vscode.OutputChannel | null = null;
let saveTaskRunner: SaveTaskRunner | null = null;
let registryService: RegistryService | null = null;
const problemRegistry: ProblemRegistry = new ProblemRegistry();

/** Get the latest scan results (used by providers). */
export function getLatestResults(): readonly VibrancyResult[] {
    return latestResults;
}

/** Get the pubspec.yaml URI from the last scan (used by navigation commands). */
export function getScannedPubspecUri(): vscode.Uri | null {
    return lastParsedDeps?.yamlUri ?? null;
}

/** Get the latest consolidated insights (used by providers). */
export function getLatestInsights(): readonly PackageInsight[] {
    return lastInsights;
}

/** Get the vibrancy state manager (used by providers). */
export function getStateManager(): VibrancyStateManager | null {
    return stateManager;
}

/** Get the registry service (used by providers). */
export function getRegistryService(): RegistryService | null {
    return registryService;
}

/** Get the problem registry (used by providers). */
export function getProblemRegistry(): ProblemRegistry {
    return problemRegistry;
}

/** Main activation wiring. */
export function runActivation(context: vscode.ExtensionContext): void {
    const cache = new CacheService(context.globalState);
    registryService = new RegistryService(context.secrets);
    context.subscriptions.push(registryService);

    const treeProvider = new VibrancyTreeProvider();
    const hoverProvider = new VibrancyHoverProvider();
    const codeLensProvider = new VibrancyCodeLensProvider();
    const codeLensToggle = new CodeLensToggle();
    const prereleaseToggle = new PrereleaseToggle();
    const statusBar = new VibrancyStatusBar();
    const diagCollection = vscode.languages.createDiagnosticCollection(
        'saropa-vibrancy',
    );
    const diagnostics = new VibrancyDiagnostics(diagCollection);

    stateManager = new VibrancyStateManager();

    setCodeLensToggle(codeLensToggle);
    setPrereleaseToggle(prereleaseToggle);
    codeLensToggle.onDidChange(enabled => {
        if (stateManager) {
            stateManager.codeLensEnabled.value = enabled;
        }
        codeLensProvider.refresh();
    });
    prereleaseToggle.onDidChange(() => {
        codeLensProvider.refresh();
        treeProvider.refresh();
    });

    context.subscriptions.push(diagCollection, statusBar, codeLensToggle, prereleaseToggle, stateManager);

    const adoptionGate = new AdoptionGateProvider(cache);
    adoptionGate.register(context);

    const codeActionProvider = new VibrancyCodeActionProvider();

    freshnessWatcher = new FreshnessWatcher(cache);
    freshnessWatcher.setOnNewVersions(handleNewVersions);

    saveTaskRunner = new SaveTaskRunner();
    context.subscriptions.push(saveTaskRunner);

    const targets: ScanTargets = {
        tree: treeProvider, hover: hoverProvider,
        codeLens: codeLensProvider, codeActions: codeActionProvider,
        statusBar, diagnostics, cache, adoptionGate, codeLensToggle,
        prereleaseToggle, state: stateManager,
    };

    detailViewProvider = new DetailViewProvider(context.extensionUri);
    context.subscriptions.push(
        vscode.window.registerWebviewViewProvider(DETAIL_VIEW_ID, detailViewProvider),
    );

    detailChannel = vscode.window.createOutputChannel(DETAIL_CHANNEL_NAME);
    detailLogger = new DetailLogger(detailChannel);
    context.subscriptions.push(detailChannel);

    registerTreeView(context, treeProvider);
    registerProviders(context, hoverProvider, codeLensProvider, codeActionProvider);
    registerCommands(context, targets);
    registerFilterCommands(context, treeProvider);
    registerTreeCommands(context, treeProvider, detailViewProvider, detailLogger);
    registerUpgradeCommand(context);
    registerAnnotateCommand(context);
    registerRegistryCommands(context, registryService);
    registerFileWatcher(context, targets);
    registerSuppressListener(context, targets);
    registerConfigListener(context, codeLensProvider, treeProvider, prereleaseToggle);
    autoScanIfPubspec(targets);
}

function registerFileWatcher(
    context: vscode.ExtensionContext,
    targets: ScanTargets,
): void {
    const watcher = vscode.workspace.createFileSystemWatcher('**/pubspec.lock');
    watcher.onDidChange(() => runScan(targets));
    context.subscriptions.push(watcher);
}

function registerSuppressListener(
    context: vscode.ExtensionContext,
    targets: ScanTargets,
): void {
    context.subscriptions.push(
        vscode.workspace.onDidChangeConfiguration(e => {
            if (!e.affectsConfiguration('saropaLints.packageVibrancy.suppressedPackages')) {
                return;
            }
            targets.tree.refresh();
            if (lastParsedDeps && latestResults.length > 0) {
                updateFilteredTargets(targets, latestResults, lastParsedDeps);
            }
        }),
    );
}

function registerConfigListener(
    context: vscode.ExtensionContext,
    codeLensProvider: VibrancyCodeLensProvider,
    treeProvider: VibrancyTreeProvider,
    prereleaseToggle: PrereleaseToggle,
): void {
    context.subscriptions.push(
        vscode.workspace.onDidChangeConfiguration(e => {
            if (e.affectsConfiguration('saropaLints.packageVibrancy.indicators')
                || e.affectsConfiguration('saropaLints.packageVibrancy.indicatorStyle')) {
                clearIndicatorCache();
                codeLensProvider.refresh();
            }
            if (e.affectsConfiguration('saropaLints.packageVibrancy.showPrereleases')
                || e.affectsConfiguration('saropaLints.packageVibrancy.prereleaseTagFilter')) {
                // Sync in-memory state + context key when user edits settings.json directly
                prereleaseToggle.refresh();
                codeLensProvider.refresh();
                treeProvider.refresh();
            }
        }),
    );
}

function registerTreeView(
    context: vscode.ExtensionContext,
    provider: VibrancyTreeProvider,
): void {
    const tv = vscode.window.createTreeView(
        'saropaLints.packageVibrancy.packages',
        { treeDataProvider: provider },
    );
    tv.description = `v${context.extension.packageJSON.version}`;
    context.subscriptions.push(tv);

    syncDetailOnSelection(tv, item => {
        if ('result' in (item as object)) {
            return (item as { result: VibrancyResult }).result;
        }
        if ('insight' in (item as object)) {
            return provider.getResultByName(
                (item as { insight: { name: string } }).insight.name,
            );
        }
        if ('analysis' in (item as object)) {
            return provider.getResultByName(
                (item as { analysis: { entry: { name: string } } }).analysis.entry.name,
            );
        }
        // Problem child nodes (ProblemItem, SuggestionItem) carry a packageName field
        if ('packageName' in (item as object)) {
            return provider.getResultByName(
                (item as { packageName: string }).packageName,
            );
        }
        return undefined;
    });
}

/** Wire a tree view selection to the Package Details panel. */
function syncDetailOnSelection(
    tv: vscode.TreeView<unknown>,
    resolve: (item: unknown) => VibrancyResult | undefined,
): void {
    tv.onDidChangeSelection(e => {
        if (!detailViewProvider) { return; }
        if (e.selection.length !== 1) {
            detailViewProvider.clear();
            return;
        }
        const result = resolve(e.selection[0]);
        if (result) {
            detailViewProvider.update(result);
        } else {
            detailViewProvider.clear();
        }
    });
}

function registerProviders(
    context: vscode.ExtensionContext,
    hoverProvider: VibrancyHoverProvider,
    codeLensProvider: VibrancyCodeLensProvider,
    codeActionProvider: VibrancyCodeActionProvider,
): void {
    const pubspecSelector = { language: 'yaml', pattern: '**/pubspec.yaml' };

    context.subscriptions.push(
        vscode.languages.registerHoverProvider(pubspecSelector, hoverProvider),
        vscode.languages.registerCodeActionsProvider(
            pubspecSelector,
            codeActionProvider,
            { providedCodeActionKinds: [vscode.CodeActionKind.QuickFix] },
        ),
        vscode.languages.registerCodeLensProvider(
            pubspecSelector, codeLensProvider,
        ),
    );
}

/** Sync the hasFilter context key after any filter change. */
function updateVibrancyFilterState(provider: VibrancyTreeProvider): void {
    if (!stateManager) { return; }
    const state = provider.getFilterState();
    stateManager.hasFilter.value = state.hasActiveFilters;
}

function registerFilterCommands(
    context: vscode.ExtensionContext,
    provider: VibrancyTreeProvider,
): void {
    context.subscriptions.push(
        vscode.commands.registerCommand(
            'saropaLints.packageVibrancy.search', async () => {
                const current = provider.getFilterState().textFilter;
                const value = await vscode.window.showInputBox({
                    title: 'Search Packages',
                    prompt: 'Filter by package name (case-insensitive substring)',
                    value: current,
                });
                if (value !== undefined) {
                    provider.setTextFilter(value);
                    updateVibrancyFilterState(provider);
                }
            },
        ),
        vscode.commands.registerCommand(
            'saropaLints.packageVibrancy.filterBySeverity', async () => {
                const current = provider.getFilterState().severityFilter;
                const picks = await vscode.window.showQuickPick(
                    ALL_SEVERITIES.map(s => ({
                        label: s.charAt(0).toUpperCase() + s.slice(1),
                        picked: current.has(s),
                        id: s,
                    })),
                    { canPickMany: true, title: 'Filter by Problem Severity' },
                );
                if (picks) {
                    provider.setSeverityFilter(
                        new Set(picks.map(p => p.id as ProblemSeverity)),
                    );
                    updateVibrancyFilterState(provider);
                }
            },
        ),
        vscode.commands.registerCommand(
            'saropaLints.packageVibrancy.filterByProblemType', async () => {
                const current = provider.getFilterState().problemTypeFilter;
                const picks = await vscode.window.showQuickPick(
                    ALL_PROBLEM_TYPES.map(t => ({
                        label: problemTypeLabel(t),
                        picked: current.has(t),
                        id: t,
                    })),
                    { canPickMany: true, title: 'Filter by Problem Type' },
                );
                if (picks) {
                    provider.setProblemTypeFilter(
                        new Set(picks.map(p => p.id as ProblemType)),
                    );
                    updateVibrancyFilterState(provider);
                }
            },
        ),
        vscode.commands.registerCommand(
            'saropaLints.packageVibrancy.filterByCategory', async () => {
                const current = provider.getFilterState().categoryFilter;
                const picks = await vscode.window.showQuickPick(
                    ALL_CATEGORIES.map(c => ({
                        label: categoryLabel(c),
                        picked: current.has(c),
                        id: c,
                    })),
                    { canPickMany: true, title: 'Filter by Health Category' },
                );
                if (picks) {
                    provider.setCategoryFilter(
                        new Set(picks.map(p => p.id as VibrancyCategory)),
                    );
                    updateVibrancyFilterState(provider);
                }
            },
        ),
        vscode.commands.registerCommand(
            'saropaLints.packageVibrancy.filterBySection', async () => {
                const current = provider.getFilterState().sectionFilter;
                const picks = await vscode.window.showQuickPick(
                    ALL_SECTIONS.map(s => ({
                        label: SECTION_LABELS[s],
                        picked: current.has(s),
                        id: s,
                    })),
                    { canPickMany: true, title: 'Filter by Dependency Section' },
                );
                if (picks) {
                    provider.setSectionFilter(
                        new Set(picks.map(p => p.id as DependencySection)),
                    );
                    updateVibrancyFilterState(provider);
                }
            },
        ),
        vscode.commands.registerCommand(
            'saropaLints.packageVibrancy.showProblemsOnly', () => {
                const current = provider.getFilterState().viewMode;
                // Toggle between 'all' and 'problems-only'
                provider.setViewMode(current === 'all' ? 'problems-only' : 'all');
                updateVibrancyFilterState(provider);
            },
        ),
        vscode.commands.registerCommand(
            'saropaLints.packageVibrancy.clearFilters', () => {
                provider.clearFilters();
                updateVibrancyFilterState(provider);
            },
        ),
    );
}

interface ScanTargets {
    tree: VibrancyTreeProvider;
    hover: VibrancyHoverProvider;
    codeLens: VibrancyCodeLensProvider;
    codeActions: VibrancyCodeActionProvider;
    statusBar: VibrancyStatusBar;
    diagnostics: VibrancyDiagnostics;
    cache: CacheService;
    adoptionGate: AdoptionGateProvider;
    codeLensToggle: CodeLensToggle;
    prereleaseToggle: PrereleaseToggle;
    state: VibrancyStateManager;
}

function registerCommands(
    context: vscode.ExtensionContext,
    targets: ScanTargets,
): void {
    context.subscriptions.push(
        vscode.commands.registerCommand(
            'saropaLints.packageVibrancy.scan',
            () => runScan(targets),
        ),
        vscode.commands.registerCommand(
            'saropaLints.packageVibrancy.showReport',
            () => VibrancyReportPanel.createOrShow(latestResults),
        ),
        vscode.commands.registerCommand(
            'saropaLints.packageVibrancy.clearCache',
            async () => {
                await targets.cache.clear();
                vscode.window.showInformationMessage('Vibrancy cache cleared');
            },
        ),
        vscode.commands.registerCommand(
            'saropaLints.packageVibrancy.exportReport',
            () => requireResults(
                r => exportReports(r, lastScanMeta).then(f => f.length || null),
                n => `Reports saved: ${n} files`,
            ),
        ),
        vscode.commands.registerCommand(
            'saropaLints.packageVibrancy.browseKnownIssues',
            () => KnownIssuesPanel.createOrShow(),
        ),
        vscode.commands.registerCommand(
            'saropaLints.packageVibrancy.about',
            () => AboutPanel.createOrShow(
                context.extension.packageJSON.version,
            ),
        ),
        vscode.commands.registerCommand(
            'saropaLints.packageVibrancy.exportSbom',
            () => requireResults(
                r => exportSbomReport(r, context.extension.packageJSON.version),
                p => `SBOM exported: ${p}`,
            ),
        ),
        vscode.commands.registerCommand(
            'saropaLints.packageVibrancy.planUpgrades',
            () => planAndExecuteUpgrades(),
        ),
        vscode.commands.registerCommand(
            'saropaLints.packageVibrancy.goToOverride',
            (packageName: string) => goToOverride(packageName),
        ),
        vscode.commands.registerCommand(
            'saropaLints.packageVibrancy.suppressPackageByName',
            (packageName: string) => suppressPackageByName(packageName, targets),
        ),
        vscode.commands.registerCommand(
            'saropaLints.packageVibrancy.suppressByCategory',
            () => suppressByCategory(targets),
        ),
        vscode.commands.registerCommand(
            'saropaLints.packageVibrancy.suppressAllProblems',
            () => suppressAllProblems(targets),
        ),
        vscode.commands.registerCommand(
            'saropaLints.packageVibrancy.unsuppressAll',
            () => unsuppressAll(targets),
        ),
        vscode.commands.registerCommand(
            'saropaLints.packageVibrancy.sortDependencies',
            () => runSortDependencies(),
        ),
        vscode.commands.registerCommand(
            'saropaLints.packageVibrancy.showCodeLens',
            () => targets.codeLensToggle.show(),
        ),
        vscode.commands.registerCommand(
            'saropaLints.packageVibrancy.hideCodeLens',
            () => targets.codeLensToggle.hide(),
        ),
        vscode.commands.registerCommand(
            'saropaLints.packageVibrancy.toggleCodeLens',
            () => targets.codeLensToggle.toggle(),
        ),
        vscode.commands.registerCommand(
            'saropaLints.packageVibrancy.showPrereleases',
            () => targets.prereleaseToggle.show(),
        ),
        vscode.commands.registerCommand(
            'saropaLints.packageVibrancy.hidePrereleases',
            () => targets.prereleaseToggle.hide(),
        ),
        vscode.commands.registerCommand(
            'saropaLints.packageVibrancy.updateToPrerelease',
            (packageName: string, version: string) =>
                updateToPrerelease(packageName, version),
        ),
        vscode.commands.registerCommand(
            'saropaLints.packageVibrancy.updateAllLatest',
            () => runBulkUpdate('all', targets),
        ),
        vscode.commands.registerCommand(
            'saropaLints.packageVibrancy.updateAllMajor',
            () => runBulkUpdate('major', targets),
        ),
        vscode.commands.registerCommand(
            'saropaLints.packageVibrancy.updateAllMinor',
            () => runBulkUpdate('minor', targets),
        ),
        vscode.commands.registerCommand(
            'saropaLints.packageVibrancy.updateAllPatch',
            () => runBulkUpdate('patch', targets),
        ),
        vscode.commands.registerCommand(
            'saropaLints.packageVibrancy.generateCiConfig',
            () => generateCiConfig(),
        ),
        vscode.commands.registerCommand(
            'saropaLints.packageVibrancy.comparePackages',
            () => runComparePackages(targets.cache),
        ),
        vscode.commands.registerCommand(
            'saropaLints.packageVibrancy.copyHoverToClipboard',
            async (packageName: string) => {
                const text = targets.hover.getClipboardText(packageName);
                if (!text) { return; }
                await vscode.env.clipboard.writeText(text);
                vscode.window.showInformationMessage(
                    `Copied ${packageName} info to clipboard`,
                );
            },
        ),
    );
}

async function autoScanIfPubspec(targets: ScanTargets): Promise<void> {
    const config = vscode.workspace.getConfiguration('saropaLints.packageVibrancy');
    if (!config.get<boolean>('scanOnOpen', true)) { return; }

    const files = await vscode.workspace.findFiles(
        '**/pubspec.yaml', '**/.*/**', 1,
    );
    if (files.length > 0) {
        await runScan(targets);
    }
}

async function runScan(targets: ScanTargets): Promise<void> {
    if (targets.state.isScanning.value) { return; }
    targets.state.startScanning();
    try {
        await runScanInner(targets);
    } finally {
        targets.state.stopScanning();
    }
}

async function runScanInner(targets: ScanTargets): Promise<void> {
    await vscode.window.withProgress(
        {
            location: vscode.ProgressLocation.Notification,
            title: 'Scanning package vibrancy...',
            cancellable: false,
        },
        async (progress) => {
            const startTime = Date.now();
            const oldVersions = snapshotVersions(latestResults);

            const parsed = await findAndParseDeps();
            if (!parsed) {
                vscode.window.showWarningMessage(
                    'No pubspec.yaml/pubspec.lock found in workspace',
                );
                return;
            }

            const logger = new ScanLogger();
            const flutterReleases = await fetchFlutterReleases(
                targets.cache, logger,
            );
            const scanConfig = {
                ...readScanConfig(), logger, flutterReleases,
            };
            const deps = parsed.deps.filter(
                d => !scanConfig.allowSet.has(d.name),
            );
            logger.info(`Scan started — ${deps.length} packages`);

            const rawResults = await scanPackages(
                deps, targets.cache, scanConfig, progress,
            );

            progress.report({ message: 'Scanning imports...' });
            const workspaceRoot = vscode.Uri.joinPath(parsed.yamlUri, '..');
            const imported = await scanDartImports(workspaceRoot);
            const unusedNames = new Set(detectUnused(
                deps.map(d => d.name), imported,
            ));
            // Only mark as unused when eligible for removal; dev_dependencies are used by tooling.
            const withUnused = rawResults.map(r =>
                unusedNames.has(r.package.name) && isUnusedRemovalEligibleSection(r.package.section)
                    ? { ...r, isUnused: true, alternatives: [] } : r,
            );

            progress.report({ message: 'Analyzing upgrade blockers...' });
            const enrichResult = await enrichWithBlockers(
                withUnused, workspaceRoot.fsPath, logger,
            );
            let results = enrichResult.results;
            lastReverseDeps = enrichResult.reverseDeps;

            progress.report({ message: 'Analyzing dependency graph...' });
            const depGraph = await fetchDepGraph(workspaceRoot.fsPath);
            let depGraphSummary: import('./types').DepGraphSummary | null = null;
            if (depGraph.success && depGraph.packages.length > 0) {
                const directDeps = deps.filter(d => d.isDirect).map(d => d.name);
                const overrides = parseDependencyOverrides(parsed.yamlContent);
                const knownIssuesMap = allKnownIssues();

                const transitiveInfos = countTransitives(directDeps, depGraph.packages);
                const sharedDeps = findSharedDeps(directDeps, depGraph.packages);
                const enrichedInfos = enrichTransitiveInfo(
                    transitiveInfos, sharedDeps, knownIssuesMap,
                );

                const transitiveMap = new Map(
                    enrichedInfos.map((t): [string, import('./types').TransitiveInfo] => [t.directDep, t]),
                );
                results = results.map(r => {
                    const tInfo = transitiveMap.get(r.package.name) ?? null;
                    if (!tInfo) { return r; }
                    const penalty = calcTransitiveRiskPenalty(tInfo);
                    const adjustedScore = Math.max(0, r.score - penalty);
                    return { ...r, transitiveInfo: tInfo, score: adjustedScore };
                }) as VibrancyResult[];

                depGraphSummary = buildDepGraphSummary(
                    directDeps, depGraph.packages, overrides.length,
                );
                logger.info(
                    `Dep graph: ${depGraphSummary!.directCount} direct, ` +
                    `${depGraphSummary!.transitiveCount} transitive, ` +
                    `${overrides.length} overrides`,
                );
            }

            progress.report({ message: 'Analyzing overrides...' });
            const overrideAnalyses = await runOverrideAnalysis(
                parsed.yamlContent,
                deps,
                depGraph.success ? depGraph.packages : [],
                workspaceRoot.fsPath,
                logger,
            );
            lastOverrideAnalyses = overrideAnalyses;
            if (overrideAnalyses.length > 0) {
                const staleCount = overrideAnalyses.filter(a => a.status === 'stale').length;
                logger.info(
                    `Overrides: ${overrideAnalyses.length} total, ${staleCount} stale`,
                );
            }

            if (getVulnScanEnabled()) {
                progress.report({ message: 'Scanning for vulnerabilities...' });
                const vulnQueries = results.map(r => ({
                    name: r.package.name,
                    version: r.package.version,
                }));

                // Query OSV and GitHub Advisory in parallel for performance
                const [osvResults, ghsaResults] = await Promise.all([
                    queryVulnerabilities(vulnQueries, targets.cache, logger),
                    getGitHubAdvisoryEnabled()
                        ? queryGitHubAdvisories(
                            vulnQueries,
                            getGithubToken() || undefined,
                            targets.cache,
                            logger,
                        )
                        : Promise.resolve([]),
                ]);

                const osvMap = new Map(
                    osvResults.map(vr => [`${vr.name}@${vr.version}`, vr.vulnerabilities]),
                );
                const ghsaMap = new Map(
                    ghsaResults.map(vr => [`${vr.name}@${vr.version}`, vr.vulnerabilities]),
                );

                results = results.map(r => {
                    const key = `${r.package.name}@${r.package.version}`;
                    const osvVulns = osvMap.get(key) ?? [];
                    const ghsaVulns = ghsaMap.get(key) ?? [];
                    const merged = mergeVulnerabilities(osvVulns, ghsaVulns);
                    return merged.length > 0 ? { ...r, vulnerabilities: merged } : r;
                }) as VibrancyResult[];

                const vulnCount = results.filter(r => r.vulnerabilities.length > 0).length;
                if (vulnCount > 0) {
                    logger.info(`Vulnerabilities: ${vulnCount} package(s) affected`);
                }
            }

            latestResults = results;
            lastParsedDeps = parsed;
            lastScanMeta = await buildScanMeta(startTime);

            const counts = countByCategory(results);
            logger.info(
                `Scan complete — ${logger.elapsedMs}ms — ` +
                `vibrant:${counts.vibrant} quiet:${counts.quiet} ` +
                `legacy:${counts.legacy} eol:${counts.eol}`,
            );

            publishResults(targets, results, parsed, depGraphSummary);
            notifyLockDiff(oldVersions, results);

            try {
                await logger.writeToFile();
            } catch {
                // Log write is best-effort — never block scan results
            }
        },
    );
}

function getSuppressedSet(): Set<string> {
    const config = vscode.workspace.getConfiguration('saropaLints.packageVibrancy');
    return new Set(config.get<string[]>('suppressedPackages', []));
}

function publishResults(
    targets: ScanTargets,
    results: VibrancyResult[],
    parsed: ParsedDeps,
    depGraphSummary: import('./types').DepGraphSummary | null = null,
): void {
    targets.adoptionGate.clearDecorations();
    targets.tree.updateResults(results);
    targets.tree.updateDepGraphSummary(depGraphSummary);
    targets.tree.updateOverrideAnalyses(lastOverrideAnalyses);
    targets.state.updateFromResults(results);

    const config = vscode.workspace.getConfiguration('saropaLints.packageVibrancy');
    const budgetConfig = readBudgetConfig(key => config.get(key));
    if (hasBudgets(budgetConfig)) {
        lastBudgetResults = checkBudgets(results, budgetConfig);
        const budgetSummary = formatBudgetSummary(lastBudgetResults);
        targets.tree.updateBudgetResults(lastBudgetResults, budgetSummary);
        targets.diagnostics.updateBudgetResults(lastBudgetResults);
    } else {
        lastBudgetResults = [];
        targets.tree.updateBudgetResults([], '');
        targets.diagnostics.updateBudgetResults([]);
    }

    updateFilteredTargets(targets, results, parsed);

    freshnessWatcher?.start(results);
}

function updateFilteredTargets(
    targets: ScanTargets,
    results: VibrancyResult[],
    parsed: ParsedDeps,
): void {
    const suppressed = getSuppressedSet();
    const active = results.filter(r => !suppressed.has(r.package.name));
    const splits = detectFamilySplits(active);

    lastInsights = consolidateInsights(active, lastOverrideAnalyses, splits);

    const packageRanges = buildPackageRanges(parsed.yamlContent, active);
    const collectorContext: CollectorContext = {
        packageRanges,
        overrideAnalyses: lastOverrideAnalyses,
        familySplits: splits,
    };
    collectProblemsFromResults(active, collectorContext, problemRegistry);

    // Feed problem data into the unified tree provider
    targets.tree.updateRegistry(problemRegistry);

    targets.tree.updateFamilySplits(splits);
    targets.tree.updateInsights(lastInsights);
    targets.hover.updateResults(active);
    targets.hover.updateFamilySplits(splits);
    targets.hover.updateInsights(lastInsights);
    targets.codeLens.updateResults(active);
    targets.codeActions.updateResults(active);
    targets.diagnostics.updateFamilySplits(splits);
    targets.diagnostics.updateOverrideAnalyses(lastOverrideAnalyses);
    targets.diagnostics.update(parsed.yamlUri, parsed.yamlContent, active);
    targets.statusBar.update(results, lastInsights);
}

let upgradeChannel: vscode.OutputChannel | null = null;

async function planAndExecuteUpgrades(): Promise<void> {
    if (latestResults.length === 0) {
        vscode.window.showWarningMessage('Run a scan first');
        return;
    }

    if (!upgradeChannel) {
        upgradeChannel = vscode.window.createOutputChannel(
            'Saropa: Upgrade Plan',
        );
    }
    upgradeChannel.clear();

    setOverrideAnalyses(lastOverrideAnalyses);
    const reverseDeps = lastReverseDeps ?? new Map();
    const steps = buildUpgradeOrder(latestResults, reverseDeps);
    if (steps.length === 0) {
        vscode.window.showInformationMessage(
            'No upgradable packages found',
        );
        return;
    }

    upgradeChannel.appendLine(formatUpgradePlan(steps));
    upgradeChannel.show(true);

    const choice = await vscode.window.showInformationMessage(
        `Proceed with ${steps.length} upgrade(s)? Stop on first failure.`,
        'Execute', 'Cancel',
    );
    if (choice !== 'Execute') { return; }

    const config = vscode.workspace.getConfiguration('saropaLints.packageVibrancy');
    const report = await vscode.window.withProgress(
        {
            location: vscode.ProgressLocation.Notification,
            title: 'Executing upgrade plan...',
            cancellable: false,
        },
        () => executeUpgradePlan(steps, upgradeChannel!, {
            skipTests: config.get<boolean>('upgradeSkipTests', false),
            maxSteps: config.get<number>('upgradeMaxSteps', 20),
            autoCommit: config.get<boolean>('upgradeAutoCommit', false),
        }),
    );

    upgradeChannel.appendLine('\n' + formatUpgradeReport(report));
    upgradeChannel.show(true);

    if (report.failedAt) {
        vscode.window.showWarningMessage(
            `Upgrade stopped at ${report.failedAt} — ${report.completedCount}/${steps.length} completed`,
        );
    } else {
        vscode.window.showInformationMessage(
            `All ${report.completedCount} upgrades completed successfully`,
        );
    }
}

async function requireResults<T>(
    action: (results: VibrancyResult[]) => Promise<T | null>,
    successMsg: (result: T) => string,
): Promise<void> {
    if (latestResults.length === 0) {
        vscode.window.showWarningMessage('Run a scan first');
        return;
    }
    const result = await action(latestResults);
    if (result) {
        vscode.window.showInformationMessage(successMsg(result));
    }
}

async function goToOverride(packageName: string): Promise<void> {
    const analysis = lastOverrideAnalyses.find(a => a.entry.name === packageName);
    if (!analysis || !lastParsedDeps) { return; }

    const doc = await vscode.workspace.openTextDocument(lastParsedDeps.yamlUri);
    const editor = await vscode.window.showTextDocument(doc);

    const line = analysis.entry.line;
    const lineText = doc.lineAt(line).text;
    const match = lineText.match(/^\s{2}(\w[\w_]*)/);
    const startChar = match ? lineText.indexOf(match[1]) : 2;
    const endChar = match ? startChar + match[1].length : lineText.length;

    const range = new vscode.Range(line, startChar, line, endChar);
    editor.selection = new vscode.Selection(range.start, range.end);
    editor.revealRange(range, vscode.TextEditorRevealType.InCenter);
}

async function handleNewVersions(
    notifications: NewVersionNotification[],
): Promise<void> {
    if (notifications.length === 0) { return; }

    const message = formatNotificationMessage(notifications);
    const actions = createNotificationActions();

    const choice = await vscode.window.showInformationMessage(
        message,
        ...actions,
    );

    switch (choice) {
        case 'View Details':
            vscode.commands.executeCommand('saropaLints.packageVibrancy.showReport');
            break;
        case 'Update All':
            vscode.commands.executeCommand('saropaLints.packageVibrancy.planUpgrades');
            break;
        case 'Dismiss':
            break;
    }
}

async function suppressPackageByName(
    packageName: string,
    targets: ScanTargets,
): Promise<void> {
    await addSuppressedPackage(packageName);
    vscode.window.showInformationMessage(
        `Suppressed "${packageName}" — diagnostics will be hidden`,
    );
    if (lastParsedDeps) {
        updateFilteredTargets(targets, latestResults, lastParsedDeps);
    }
}

async function suppressByCategory(targets: ScanTargets): Promise<void> {
    if (latestResults.length === 0) {
        vscode.window.showWarningMessage('Run a scan first');
        return;
    }

    const items: vscode.QuickPickItem[] = [
        {
            label: '$(warning) End of Life packages',
            description: `${countCategory('end-of-life')} packages`,
            detail: 'Suppress all packages marked as end-of-life',
        },
        {
            label: '$(info) Legacy-Locked packages',
            description: `${countCategory('legacy-locked')} packages`,
            detail: 'Suppress all packages marked as legacy-locked',
        },
        {
            label: '$(question) Quiet packages',
            description: `${countCategory('quiet')} packages`,
            detail: 'Suppress all packages with low activity',
        },
        {
            label: '$(circle-slash) All Blocked packages',
            description: `${countBlocked()} packages`,
            detail: 'Suppress packages that cannot be upgraded due to blockers',
        },
    ];

    const selection = await vscode.window.showQuickPick(items, {
        title: 'Suppress Packages by Category',
        placeHolder: 'Select which packages to suppress',
    });

    if (!selection) { return; }

    let toSuppress: string[] = [];
    if (selection.label.includes('End of Life')) {
        toSuppress = getPackagesByCategory('end-of-life');
    } else if (selection.label.includes('Legacy-Locked')) {
        toSuppress = getPackagesByCategory('legacy-locked');
    } else if (selection.label.includes('Quiet')) {
        toSuppress = getPackagesByCategory('quiet');
    } else if (selection.label.includes('Blocked')) {
        toSuppress = getBlockedPackages();
    }

    if (toSuppress.length === 0) {
        vscode.window.showInformationMessage('No packages to suppress');
        return;
    }

    const count = await addSuppressedPackages(toSuppress);
    vscode.window.showInformationMessage(
        `Suppressed ${count} package(s)`,
    );
    if (lastParsedDeps) {
        updateFilteredTargets(targets, latestResults, lastParsedDeps);
    }
}

async function suppressAllProblems(targets: ScanTargets): Promise<void> {
    if (latestResults.length === 0) {
        vscode.window.showWarningMessage('Run a scan first');
        return;
    }

    const unhealthy = latestResults
        .filter(r => r.category !== 'vibrant')
        .map(r => r.package.name);

    if (unhealthy.length === 0) {
        vscode.window.showInformationMessage('No unhealthy packages to suppress');
        return;
    }

    const confirm = await vscode.window.showWarningMessage(
        `Suppress all ${unhealthy.length} unhealthy packages? This will hide all diagnostics.`,
        { modal: true },
        'Suppress All',
    );

    if (confirm !== 'Suppress All') { return; }

    const count = await addSuppressedPackages(unhealthy);
    vscode.window.showInformationMessage(`Suppressed ${count} package(s)`);
    if (lastParsedDeps) {
        updateFilteredTargets(targets, latestResults, lastParsedDeps);
    }
}

async function unsuppressAll(targets: ScanTargets): Promise<void> {
    const count = await clearSuppressedPackages();
    if (count === 0) {
        vscode.window.showInformationMessage('No suppressed packages');
        return;
    }
    vscode.window.showInformationMessage(`Unsuppressed ${count} package(s)`);
    if (lastParsedDeps) {
        updateFilteredTargets(targets, latestResults, lastParsedDeps);
    }
}

function countCategory(category: string): number {
    return latestResults.filter(r => r.category === category).length;
}

function countBlocked(): number {
    return latestResults.filter(r => r.blocker !== undefined).length;
}

function getPackagesByCategory(category: string): string[] {
    return latestResults
        .filter(r => r.category === category)
        .map(r => r.package.name);
}

function getBlockedPackages(): string[] {
    return latestResults
        .filter(r => r.blocker !== undefined)
        .map(r => r.package.name);
}

export function stopFreshnessWatcher(): void {
    freshnessWatcher?.stop();

    // Dispose the lazily-created output channel to avoid a resource leak
    // when the extension deactivates (it was never disposed before).
    if (upgradeChannel) {
        upgradeChannel.dispose();
        upgradeChannel = null;
    }
}

async function runSortDependencies(): Promise<void> {
    const pubspecUri = await findPubspecYaml();
    if (!pubspecUri) {
        vscode.window.showWarningMessage('No pubspec.yaml found in workspace');
        return;
    }

    const config = vscode.workspace.getConfiguration('saropaLints.packageVibrancy');
    const sdkFirst = config.get<boolean>('sortSdkFirst', true);

    const result = await sortDependencies(pubspecUri, { sdkFirst });

    if (!result.sorted) {
        vscode.window.showInformationMessage('Dependencies already sorted');
        return;
    }

    vscode.window.showInformationMessage(
        `Sorted ${result.entriesMoved} dependencies in ${result.sectionsModified.join(', ')}`,
    );
}

async function updateToPrerelease(
    packageName: string,
    version: string,
): Promise<void> {
    const pubspecUri = await findPubspecYaml();
    if (!pubspecUri) {
        vscode.window.showWarningMessage('No pubspec.yaml found');
        return;
    }

    const confirm = await vscode.window.showWarningMessage(
        `Update ${packageName} to prerelease ${version}? Prereleases may contain breaking changes.`,
        { modal: true },
        'Update',
    );

    if (confirm !== 'Update') { return; }

    const doc = await vscode.workspace.openTextDocument(pubspecUri);
    const edit = new vscode.WorkspaceEdit();
    const text = doc.getText();
    const lines = text.split('\n');

    let found = false;
    const escapedName = packageName.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
    for (let i = 0; i < lines.length; i++) {
        const line = lines[i];
        const match = line.match(new RegExp(`^(\\s*${escapedName}:\\s*)(\\S+.*?)$`));
        if (match) {
            const start = new vscode.Position(i, match[1].length);
            const end = new vscode.Position(i, line.length);
            edit.replace(doc.uri, new vscode.Range(start, end), `^${version}`);
            found = true;
            break;
        }
    }

    if (!found) {
        vscode.window.showWarningMessage(`Package ${packageName} not found in pubspec.yaml`);
        return;
    }

    await vscode.workspace.applyEdit(edit);
    await doc.save();
    vscode.window.showInformationMessage(`Updated ${packageName} to ${version}`);
}

async function runBulkUpdate(
    filter: IncrementFilter,
    targets: ScanTargets,
): Promise<void> {
    if (latestResults.length === 0) {
        vscode.window.showWarningMessage('Run a scan first');
        return;
    }

    const result = await bulkUpdate(latestResults, {
        incrementFilter: filter,
    });

    if (result.updated.length > 0 && !result.cancelled) {
        await runScan(targets);
    }
}

async function generateCiConfig(): Promise<void> {
    if (latestResults.length === 0) {
        vscode.window.showWarningMessage('Run a scan first to generate CI config with appropriate thresholds');
        return;
    }

    const platforms = getAvailablePlatforms();
    const platformSelection = await vscode.window.showQuickPick(
        platforms.map(p => ({
            label: p.label,
            description: p.description,
            id: p.id,
        })),
        {
            title: 'Generate CI Pipeline',
            placeHolder: 'Select CI platform',
        },
    );

    if (!platformSelection) { return; }

    const platform = platformSelection.id as CiPlatform;
    const suggested = suggestThresholds(latestResults);

    const thresholds = await promptThresholds(suggested);
    if (!thresholds) { return; }

    const content = generateCiWorkflow(platform, thresholds);
    const defaultPath = getDefaultOutputPath(platform);

    const folders = vscode.workspace.workspaceFolders;
    if (!folders || folders.length === 0) {
        vscode.window.showErrorMessage('No workspace folder open');
        return;
    }

    const targetPath = vscode.Uri.joinPath(folders[0].uri, defaultPath);

    let shouldWrite = true;
    try {
        await vscode.workspace.fs.stat(targetPath);
        const overwrite = await vscode.window.showWarningMessage(
            `${defaultPath} already exists. Overwrite?`,
            { modal: true },
            'Overwrite',
        );
        shouldWrite = overwrite === 'Overwrite';
    } catch {
        const parentDir = vscode.Uri.joinPath(targetPath, '..');
        try {
            await vscode.workspace.fs.stat(parentDir);
        } catch {
            await vscode.workspace.fs.createDirectory(parentDir);
        }
    }

    if (!shouldWrite) { return; }

    await vscode.workspace.fs.writeFile(targetPath, Buffer.from(content, 'utf-8'));

    const doc = await vscode.workspace.openTextDocument(targetPath);
    await vscode.window.showTextDocument(doc);

    vscode.window.showInformationMessage(
        `CI pipeline generated: ${defaultPath}`,
    );
}

async function promptThresholds(
    suggested: CiThresholds,
): Promise<CiThresholds | undefined> {
    const summary = formatThresholdsSummary(suggested);

    const action = await vscode.window.showQuickPick(
        [
            {
                label: '$(check) Use suggested thresholds',
                description: summary,
                action: 'use',
            },
            {
                label: '$(edit) Customize thresholds...',
                description: 'Edit each threshold value',
                action: 'edit',
            },
        ],
        {
            title: 'Configure CI Thresholds',
            placeHolder: 'Based on current scan results',
        },
    );

    if (!action) { return undefined; }

    if (action.action === 'use') {
        return suggested;
    }

    const maxEol = await vscode.window.showInputBox({
        title: 'Max End-of-Life Packages',
        prompt: 'Maximum number of EOL packages allowed (current PRs with more will fail)',
        value: String(suggested.maxEndOfLife),
        validateInput: v => {
            const n = parseInt(v, 10);
            return isNaN(n) || n < 0 ? 'Enter a non-negative number' : undefined;
        },
    });
    if (maxEol === undefined) { return undefined; }

    const maxLegacy = await vscode.window.showInputBox({
        title: 'Max Legacy-Locked Packages',
        prompt: 'Maximum number of legacy-locked packages allowed',
        value: String(suggested.maxLegacyLocked),
        validateInput: v => {
            const n = parseInt(v, 10);
            return isNaN(n) || n < 0 ? 'Enter a non-negative number' : undefined;
        },
    });
    if (maxLegacy === undefined) { return undefined; }

    const minVibrancy = await vscode.window.showInputBox({
        title: 'Minimum Average Vibrancy',
        prompt: 'Minimum average vibrancy score (0-100) required',
        value: String(suggested.minAverageVibrancy),
        validateInput: v => {
            const n = parseInt(v, 10);
            return isNaN(n) || n < 0 || n > 100 ? 'Enter a number between 0 and 100' : undefined;
        },
    });
    if (minVibrancy === undefined) { return undefined; }

    const failOnVuln = await vscode.window.showQuickPick(
        [
            { label: 'Yes', description: 'Fail CI on known vulnerabilities', value: true },
            { label: 'No', description: 'Warn but do not fail', value: false },
        ],
        {
            title: 'Fail on Vulnerabilities?',
            placeHolder: 'Should the CI fail when vulnerabilities are detected?',
        },
    );
    if (!failOnVuln) { return undefined; }

    return {
        maxEndOfLife: parseInt(maxEol, 10),
        maxLegacyLocked: parseInt(maxLegacy, 10),
        minAverageVibrancy: parseInt(minVibrancy, 10),
        failOnVulnerability: failOnVuln.value,
    };
}

async function runComparePackages(cache: CacheService): Promise<void> {
    const packageNames = await promptForPackageNames();
    if (!packageNames || packageNames.length < 2) {
        vscode.window.showWarningMessage('Select 2-3 packages to compare');
        return;
    }

    if (packageNames.length > 3) {
        vscode.window.showWarningMessage('Maximum 3 packages for comparison');
        return;
    }

    const comparisonData = await vscode.window.withProgress(
        {
            location: vscode.ProgressLocation.Notification,
            title: 'Fetching package data...',
            cancellable: false,
        },
        async () => {
            const resolvedNames = new Set(latestResults.map(r => r.package.name));
            const data: ComparisonData[] = [];

            for (const name of packageNames) {
                const existing = latestResults.find(r => r.package.name === name);
                if (existing) {
                    data.push(resultToComparisonData(existing, true));
                } else {
                    const fetched = await fetchComparisonData(name, cache);
                    if (fetched) {
                        data.push({ ...fetched, inProject: resolvedNames.has(name) });
                    }
                }
            }

            return data;
        },
    );

    if (comparisonData.length < 2) {
        vscode.window.showWarningMessage('Could not fetch enough package data');
        return;
    }

    ComparisonPanel.createOrShow(comparisonData);
}

async function promptForPackageNames(): Promise<string[] | undefined> {
    const scannedItems = latestResults.map(r => ({
        label: r.package.name,
        description: `${r.score}/100 — ${r.category}`,
        picked: false,
    }));

    if (scannedItems.length > 0) {
        const selection = await vscode.window.showQuickPick(scannedItems, {
            title: 'Select packages to compare',
            placeHolder: 'Choose 2-3 packages (or type to search pub.dev)',
            canPickMany: true,
        });

        if (selection && selection.length >= 2) {
            return selection.map(s => s.label);
        }
    }

    const input = await vscode.window.showInputBox({
        title: 'Compare Packages',
        prompt: 'Enter 2-3 package names separated by commas',
        placeHolder: 'e.g., http, dio, chopper',
    });

    if (!input) { return undefined; }

    return input.split(',')
        .map(s => s.trim())
        .filter(s => s.length > 0);
}

async function fetchComparisonData(
    name: string,
    cache: CacheService,
): Promise<ComparisonData | null> {
    const [info, metrics, publisher, archiveSize] = await Promise.all([
        fetchPackageInfo(name, cache),
        fetchPackageMetrics(name, cache),
        fetchPublisher(name, cache),
        fetchArchiveSize(name, cache),
    ]);

    if (!info) { return null; }

    let stars: number | null = null;
    let openIssues: number | null = null;

    if (info.repositoryUrl?.includes('github.com')) {
        const extracted = extractGitHubRepo(info.repositoryUrl);
        if (extracted) {
            const ghMetrics = await fetchRepoMetrics(
                extracted.owner,
                extracted.repo,
                { cache },
            );
            if (ghMetrics) {
                stars = ghMetrics.stars;
                openIssues = ghMetrics.openIssues;
            }
        }
    }

    const bloatRating = archiveSize !== null ? calcBloatRating(archiveSize) : null;

    return {
        name,
        vibrancyScore: null,
        category: null,
        latestVersion: info.latestVersion,
        publishedDate: info.publishedDate?.split('T')[0] ?? null,
        publisher,
        pubPoints: metrics.pubPoints,
        stars,
        openIssues,
        archiveSizeBytes: archiveSize,
        bloatRating,
        license: info.license,
        platforms: metrics.platforms,
        inProject: false,
    };
}

function buildPackageRanges(
    yamlContent: string,
    results: readonly VibrancyResult[],
): Map<string, import('./types').PackageRange> {
    const ranges = new Map<string, import('./types').PackageRange>();
    for (const result of results) {
        const range = findPackageRange(yamlContent, result.package.name);
        if (range) {
            ranges.set(result.package.name, range);
        }
    }
    return ranges;
}

