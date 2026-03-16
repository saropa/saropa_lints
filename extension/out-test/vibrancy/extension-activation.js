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
exports.getLatestResults = getLatestResults;
exports.getScannedPubspecUri = getScannedPubspecUri;
exports.getLatestInsights = getLatestInsights;
exports.getStateManager = getStateManager;
exports.getRegistryService = getRegistryService;
exports.getProblemRegistry = getProblemRegistry;
exports.runActivation = runActivation;
exports.stopFreshnessWatcher = stopFreshnessWatcher;
const vscode = __importStar(require("vscode"));
const cache_service_1 = require("./services/cache-service");
const tree_data_provider_1 = require("./providers/tree-data-provider");
const diagnostics_1 = require("./providers/diagnostics");
const code_action_provider_1 = require("./providers/code-action-provider");
const codelens_provider_1 = require("./providers/codelens-provider");
const hover_provider_1 = require("./providers/hover-provider");
const codelens_toggle_1 = require("./ui/codelens-toggle");
const prerelease_toggle_1 = require("./ui/prerelease-toggle");
const report_webview_1 = require("./views/report-webview");
const known_issues_webview_1 = require("./views/known-issues-webview");
const about_webview_1 = require("./views/about-webview");
const comparison_webview_1 = require("./views/comparison-webview");
const detail_view_provider_1 = require("./views/detail-view-provider");
const detail_logger_1 = require("./services/detail-logger");
const report_exporter_1 = require("./services/report-exporter");
const sbom_exporter_1 = require("./services/sbom-exporter");
const scan_logger_1 = require("./services/scan-logger");
const types_1 = require("./types");
const status_classifier_1 = require("./scoring/status-classifier");
const tree_commands_1 = require("./providers/tree-commands");
const upgrade_command_1 = require("./providers/upgrade-command");
const annotate_command_1 = require("./providers/annotate-command");
const scan_helpers_1 = require("./scan-helpers");
const import_scanner_1 = require("./services/import-scanner");
const unused_detector_1 = require("./scoring/unused-detector");
const flutter_releases_1 = require("./services/flutter-releases");
const lock_diff_notifier_1 = require("./services/lock-diff-notifier");
const family_conflict_detector_1 = require("./scoring/family-conflict-detector");
const adoption_gate_1 = require("./providers/adoption-gate");
const blocker_enricher_1 = require("./services/blocker-enricher");
const upgrade_sequencer_1 = require("./scoring/upgrade-sequencer");
const upgrade_executor_1 = require("./services/upgrade-executor");
const dep_graph_1 = require("./services/dep-graph");
const pubspec_parser_1 = require("./services/pubspec-parser");
const transitive_analyzer_1 = require("./scoring/transitive-analyzer");
const known_issues_1 = require("./scoring/known-issues");
const override_runner_1 = require("./services/override-runner");
const consolidate_insights_1 = require("./scoring/consolidate-insights");
const freshness_watcher_1 = require("./services/freshness-watcher");
const config_service_1 = require("./services/config-service");
const osv_api_1 = require("./services/osv-api");
const github_advisory_api_1 = require("./services/github-advisory-api");
const pubspec_sorter_1 = require("./services/pubspec-sorter");
const indicator_config_1 = require("./services/indicator-config");
const pubspec_editor_1 = require("./services/pubspec-editor");
const state_1 = require("./state");
const budget_checker_1 = require("./scoring/budget-checker");
const comparison_ranker_1 = require("./scoring/comparison-ranker");
const pub_dev_api_1 = require("./services/pub-dev-api");
const github_api_1 = require("./services/github-api");
const bloat_calculator_1 = require("./scoring/bloat-calculator");
const save_task_runner_1 = require("./services/save-task-runner");
const bulk_updater_1 = require("./services/bulk-updater");
const registry_service_1 = require("./services/registry-service");
const registry_commands_1 = require("./providers/registry-commands");
const threshold_suggester_1 = require("./services/threshold-suggester");
const ci_generator_1 = require("./services/ci-generator");
const problems_1 = require("./problems");
const pubspec_parser_2 = require("./services/pubspec-parser");
const problem_types_1 = require("./problems/problem-types");
const vibrancy_filter_state_1 = require("./providers/vibrancy-filter-state");
const tree_item_classes_1 = require("./providers/tree-item-classes");
const status_classifier_2 = require("./scoring/status-classifier");
let latestResults = [];
let lastParsedDeps = null;
let lastReverseDeps = null;
let lastOverrideAnalyses = [];
let lastInsights = [];
let lastBudgetResults = [];
let lastScanMeta = {
    flutterVersion: 'unknown',
    dartVersion: 'unknown',
    executionTimeMs: 0,
};
let freshnessWatcher = null;
let stateManager = null;
let detailViewProvider = null;
let detailLogger = null;
let detailChannel = null;
let saveTaskRunner = null;
let registryService = null;
let vibrancyStatusCallback = null;
const problemRegistry = new problems_1.ProblemRegistry();
/** Get the latest scan results (used by providers). */
function getLatestResults() {
    return latestResults;
}
/** Get the pubspec.yaml URI from the last scan (used by navigation commands). */
function getScannedPubspecUri() {
    return lastParsedDeps?.yamlUri ?? null;
}
/** Get the latest consolidated insights (used by providers). */
function getLatestInsights() {
    return lastInsights;
}
/** Get the vibrancy state manager (used by providers). */
function getStateManager() {
    return stateManager;
}
/** Get the registry service (used by providers). */
function getRegistryService() {
    return registryService;
}
/** Get the problem registry (used by providers). */
function getProblemRegistry() {
    return problemRegistry;
}
/** Main activation wiring. */
function runActivation(context, onStatusUpdate) {
    vibrancyStatusCallback = onStatusUpdate ?? null;
    const cache = new cache_service_1.CacheService(context.globalState);
    registryService = new registry_service_1.RegistryService(context.secrets);
    context.subscriptions.push(registryService);
    const treeProvider = new tree_data_provider_1.VibrancyTreeProvider();
    const hoverProvider = new hover_provider_1.VibrancyHoverProvider();
    const codeLensProvider = new codelens_provider_1.VibrancyCodeLensProvider();
    const codeLensToggle = new codelens_toggle_1.CodeLensToggle();
    const prereleaseToggle = new prerelease_toggle_1.PrereleaseToggle();
    const diagCollection = vscode.languages.createDiagnosticCollection('saropa-vibrancy');
    const diagnostics = new diagnostics_1.VibrancyDiagnostics(diagCollection);
    stateManager = new state_1.VibrancyStateManager();
    (0, codelens_provider_1.setCodeLensToggle)(codeLensToggle);
    (0, codelens_provider_1.setPrereleaseToggle)(prereleaseToggle);
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
    context.subscriptions.push(diagCollection, codeLensToggle, prereleaseToggle, stateManager);
    const adoptionGate = new adoption_gate_1.AdoptionGateProvider(cache);
    adoptionGate.register(context);
    const codeActionProvider = new code_action_provider_1.VibrancyCodeActionProvider();
    freshnessWatcher = new freshness_watcher_1.FreshnessWatcher(cache);
    freshnessWatcher.setOnNewVersions(handleNewVersions);
    saveTaskRunner = new save_task_runner_1.SaveTaskRunner();
    context.subscriptions.push(saveTaskRunner);
    const targets = {
        tree: treeProvider, hover: hoverProvider,
        codeLens: codeLensProvider, codeActions: codeActionProvider,
        diagnostics, cache, adoptionGate, codeLensToggle,
        prereleaseToggle, state: stateManager,
    };
    detailViewProvider = new detail_view_provider_1.DetailViewProvider(context.extensionUri);
    context.subscriptions.push(vscode.window.registerWebviewViewProvider(detail_view_provider_1.DETAIL_VIEW_ID, detailViewProvider));
    detailChannel = vscode.window.createOutputChannel(detail_logger_1.DETAIL_CHANNEL_NAME);
    detailLogger = new detail_logger_1.DetailLogger(detailChannel);
    context.subscriptions.push(detailChannel);
    registerTreeView(context, treeProvider);
    registerProviders(context, hoverProvider, codeLensProvider, codeActionProvider);
    registerCommands(context, targets);
    registerFilterCommands(context, treeProvider);
    (0, tree_commands_1.registerTreeCommands)(context, treeProvider, detailViewProvider, detailLogger);
    (0, upgrade_command_1.registerUpgradeCommand)(context);
    (0, annotate_command_1.registerAnnotateCommand)(context);
    (0, registry_commands_1.registerRegistryCommands)(context, registryService);
    registerFileWatcher(context, targets);
    registerSuppressListener(context, targets);
    registerConfigListener(context, codeLensProvider, treeProvider, prereleaseToggle);
    autoScanIfPubspec(targets);
}
function registerFileWatcher(context, targets) {
    const watcher = vscode.workspace.createFileSystemWatcher('**/pubspec.lock');
    watcher.onDidChange(() => runScan(targets));
    context.subscriptions.push(watcher);
}
function registerSuppressListener(context, targets) {
    context.subscriptions.push(vscode.workspace.onDidChangeConfiguration(e => {
        if (!e.affectsConfiguration('saropaLints.packageVibrancy.suppressedPackages')) {
            return;
        }
        targets.tree.refresh();
        if (lastParsedDeps && latestResults.length > 0) {
            updateFilteredTargets(targets, latestResults, lastParsedDeps);
        }
    }));
}
function registerConfigListener(context, codeLensProvider, treeProvider, prereleaseToggle) {
    context.subscriptions.push(vscode.workspace.onDidChangeConfiguration(e => {
        if (e.affectsConfiguration('saropaLints.packageVibrancy.indicators')
            || e.affectsConfiguration('saropaLints.packageVibrancy.indicatorStyle')) {
            (0, indicator_config_1.clearIndicatorCache)();
            codeLensProvider.refresh();
        }
        if (e.affectsConfiguration('saropaLints.packageVibrancy.showPrereleases')
            || e.affectsConfiguration('saropaLints.packageVibrancy.prereleaseTagFilter')) {
            // Sync in-memory state + context key when user edits settings.json directly
            prereleaseToggle.refresh();
            codeLensProvider.refresh();
            treeProvider.refresh();
        }
    }));
}
function registerTreeView(context, provider) {
    const tv = vscode.window.createTreeView('saropaLints.packageVibrancy.packages', { treeDataProvider: provider });
    tv.description = `v${context.extension.packageJSON.version}`;
    context.subscriptions.push(tv);
    syncDetailOnSelection(tv, item => {
        if ('result' in item) {
            return item.result;
        }
        if ('insight' in item) {
            return provider.getResultByName(item.insight.name);
        }
        if ('analysis' in item) {
            return provider.getResultByName(item.analysis.entry.name);
        }
        // Problem child nodes (ProblemItem, SuggestionItem) carry a packageName field
        if ('packageName' in item) {
            return provider.getResultByName(item.packageName);
        }
        return undefined;
    });
}
/** Wire a tree view selection to the Package Details panel. */
function syncDetailOnSelection(tv, resolve) {
    tv.onDidChangeSelection(e => {
        if (!detailViewProvider) {
            return;
        }
        if (e.selection.length !== 1) {
            detailViewProvider.clear();
            return;
        }
        const result = resolve(e.selection[0]);
        if (result) {
            detailViewProvider.update(result);
        }
        else {
            detailViewProvider.clear();
        }
    });
}
function registerProviders(context, hoverProvider, codeLensProvider, codeActionProvider) {
    const pubspecSelector = { language: 'yaml', pattern: '**/pubspec.yaml' };
    context.subscriptions.push(vscode.languages.registerHoverProvider(pubspecSelector, hoverProvider), vscode.languages.registerCodeActionsProvider(pubspecSelector, codeActionProvider, { providedCodeActionKinds: [vscode.CodeActionKind.QuickFix] }), vscode.languages.registerCodeLensProvider(pubspecSelector, codeLensProvider));
}
/** Sync the hasFilter context key after any filter change. */
function updateVibrancyFilterState(provider) {
    if (!stateManager) {
        return;
    }
    const state = provider.getFilterState();
    stateManager.hasFilter.value = state.hasActiveFilters;
}
function registerFilterCommands(context, provider) {
    context.subscriptions.push(vscode.commands.registerCommand('saropaLints.packageVibrancy.search', async () => {
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
    }), vscode.commands.registerCommand('saropaLints.packageVibrancy.filterBySeverity', async () => {
        const current = provider.getFilterState().severityFilter;
        const picks = await vscode.window.showQuickPick(vibrancy_filter_state_1.ALL_SEVERITIES.map(s => ({
            label: s.charAt(0).toUpperCase() + s.slice(1),
            picked: current.has(s),
            id: s,
        })), { canPickMany: true, title: 'Filter by Problem Severity' });
        if (picks) {
            provider.setSeverityFilter(new Set(picks.map(p => p.id)));
            updateVibrancyFilterState(provider);
        }
    }), vscode.commands.registerCommand('saropaLints.packageVibrancy.filterByProblemType', async () => {
        const current = provider.getFilterState().problemTypeFilter;
        const picks = await vscode.window.showQuickPick(vibrancy_filter_state_1.ALL_PROBLEM_TYPES.map(t => ({
            label: (0, problem_types_1.problemTypeLabel)(t),
            picked: current.has(t),
            id: t,
        })), { canPickMany: true, title: 'Filter by Problem Type' });
        if (picks) {
            provider.setProblemTypeFilter(new Set(picks.map(p => p.id)));
            updateVibrancyFilterState(provider);
        }
    }), vscode.commands.registerCommand('saropaLints.packageVibrancy.filterByCategory', async () => {
        const current = provider.getFilterState().categoryFilter;
        const picks = await vscode.window.showQuickPick(vibrancy_filter_state_1.ALL_CATEGORIES.map(c => ({
            label: (0, status_classifier_2.categoryLabel)(c),
            picked: current.has(c),
            id: c,
        })), { canPickMany: true, title: 'Filter by Health Category' });
        if (picks) {
            provider.setCategoryFilter(new Set(picks.map(p => p.id)));
            updateVibrancyFilterState(provider);
        }
    }), vscode.commands.registerCommand('saropaLints.packageVibrancy.filterBySection', async () => {
        const current = provider.getFilterState().sectionFilter;
        const picks = await vscode.window.showQuickPick(vibrancy_filter_state_1.ALL_SECTIONS.map(s => ({
            label: tree_item_classes_1.SECTION_LABELS[s],
            picked: current.has(s),
            id: s,
        })), { canPickMany: true, title: 'Filter by Dependency Section' });
        if (picks) {
            provider.setSectionFilter(new Set(picks.map(p => p.id)));
            updateVibrancyFilterState(provider);
        }
    }), vscode.commands.registerCommand('saropaLints.packageVibrancy.showProblemsOnly', () => {
        const current = provider.getFilterState().viewMode;
        // Toggle between 'all' and 'problems-only'
        provider.setViewMode(current === 'all' ? 'problems-only' : 'all');
        updateVibrancyFilterState(provider);
    }), vscode.commands.registerCommand('saropaLints.packageVibrancy.clearFilters', () => {
        provider.clearFilters();
        updateVibrancyFilterState(provider);
    }));
}
function registerCommands(context, targets) {
    context.subscriptions.push(vscode.commands.registerCommand('saropaLints.packageVibrancy.scan', () => runScan(targets)), vscode.commands.registerCommand('saropaLints.packageVibrancy.showReport', () => report_webview_1.VibrancyReportPanel.createOrShow(latestResults)), vscode.commands.registerCommand('saropaLints.packageVibrancy.clearCache', async () => {
        await targets.cache.clear();
        vscode.window.showInformationMessage('Vibrancy cache cleared');
    }), vscode.commands.registerCommand('saropaLints.packageVibrancy.exportReport', () => requireResults(r => (0, report_exporter_1.exportReports)(r, lastScanMeta).then(f => f.length || null), n => `Reports saved: ${n} files`)), vscode.commands.registerCommand('saropaLints.packageVibrancy.browseKnownIssues', () => known_issues_webview_1.KnownIssuesPanel.createOrShow()), vscode.commands.registerCommand('saropaLints.packageVibrancy.about', () => about_webview_1.AboutPanel.createOrShow(context.extension.packageJSON.version)), vscode.commands.registerCommand('saropaLints.packageVibrancy.exportSbom', () => requireResults(r => (0, sbom_exporter_1.exportSbomReport)(r, context.extension.packageJSON.version), p => `SBOM exported: ${p}`)), vscode.commands.registerCommand('saropaLints.packageVibrancy.planUpgrades', () => planAndExecuteUpgrades()), vscode.commands.registerCommand('saropaLints.packageVibrancy.goToOverride', (packageName) => goToOverride(packageName)), vscode.commands.registerCommand('saropaLints.packageVibrancy.suppressPackageByName', (packageName) => suppressPackageByName(packageName, targets)), vscode.commands.registerCommand('saropaLints.packageVibrancy.suppressByCategory', () => suppressByCategory(targets)), vscode.commands.registerCommand('saropaLints.packageVibrancy.suppressAllProblems', () => suppressAllProblems(targets)), vscode.commands.registerCommand('saropaLints.packageVibrancy.unsuppressAll', () => unsuppressAll(targets)), vscode.commands.registerCommand('saropaLints.packageVibrancy.sortDependencies', () => runSortDependencies()), vscode.commands.registerCommand('saropaLints.packageVibrancy.showCodeLens', () => targets.codeLensToggle.show()), vscode.commands.registerCommand('saropaLints.packageVibrancy.hideCodeLens', () => targets.codeLensToggle.hide()), vscode.commands.registerCommand('saropaLints.packageVibrancy.toggleCodeLens', () => targets.codeLensToggle.toggle()), vscode.commands.registerCommand('saropaLints.packageVibrancy.showPrereleases', () => targets.prereleaseToggle.show()), vscode.commands.registerCommand('saropaLints.packageVibrancy.hidePrereleases', () => targets.prereleaseToggle.hide()), vscode.commands.registerCommand('saropaLints.packageVibrancy.updateToPrerelease', (packageName, version) => updateToPrerelease(packageName, version)), vscode.commands.registerCommand('saropaLints.packageVibrancy.updateAllLatest', () => runBulkUpdate('all', targets)), vscode.commands.registerCommand('saropaLints.packageVibrancy.updateAllMajor', () => runBulkUpdate('major', targets)), vscode.commands.registerCommand('saropaLints.packageVibrancy.updateAllMinor', () => runBulkUpdate('minor', targets)), vscode.commands.registerCommand('saropaLints.packageVibrancy.updateAllPatch', () => runBulkUpdate('patch', targets)), vscode.commands.registerCommand('saropaLints.packageVibrancy.generateCiConfig', () => generateCiConfig()), vscode.commands.registerCommand('saropaLints.packageVibrancy.comparePackages', () => runComparePackages(targets.cache)), vscode.commands.registerCommand('saropaLints.packageVibrancy.copyHoverToClipboard', async (packageName) => {
        const text = targets.hover.getClipboardText(packageName);
        if (!text) {
            return;
        }
        await vscode.env.clipboard.writeText(text);
        vscode.window.showInformationMessage(`Copied ${packageName} info to clipboard`);
    }));
}
async function autoScanIfPubspec(targets) {
    const config = vscode.workspace.getConfiguration('saropaLints.packageVibrancy');
    if (!config.get('scanOnOpen', true)) {
        return;
    }
    const files = await vscode.workspace.findFiles('**/pubspec.yaml', '**/.*/**', 1);
    if (files.length > 0) {
        await runScan(targets);
    }
}
async function runScan(targets) {
    if (targets.state.isScanning.value) {
        return;
    }
    targets.state.startScanning();
    try {
        await runScanInner(targets);
    }
    finally {
        targets.state.stopScanning();
    }
}
async function runScanInner(targets) {
    await vscode.window.withProgress({
        location: vscode.ProgressLocation.Notification,
        title: 'Scanning package vibrancy...',
        cancellable: false,
    }, async (progress) => {
        const startTime = Date.now();
        const oldVersions = (0, lock_diff_notifier_1.snapshotVersions)(latestResults);
        const parsed = await (0, scan_helpers_1.findAndParseDeps)();
        if (!parsed) {
            vscode.window.showWarningMessage('No pubspec.yaml/pubspec.lock found in workspace');
            return;
        }
        const logger = new scan_logger_1.ScanLogger();
        const flutterReleases = await (0, flutter_releases_1.fetchFlutterReleases)(targets.cache, logger);
        const scanConfig = {
            ...(0, scan_helpers_1.readScanConfig)(), logger, flutterReleases,
        };
        const deps = parsed.deps.filter(d => !scanConfig.allowSet.has(d.name));
        logger.info(`Scan started — ${deps.length} packages`);
        const rawResults = await (0, scan_helpers_1.scanPackages)(deps, targets.cache, scanConfig, progress);
        progress.report({ message: 'Scanning imports...' });
        const workspaceRoot = vscode.Uri.joinPath(parsed.yamlUri, '..');
        const imported = await (0, import_scanner_1.scanDartImports)(workspaceRoot);
        const unusedNames = new Set((0, unused_detector_1.detectUnused)(deps.map(d => d.name), imported));
        // Only mark as unused when eligible for removal; dev_dependencies are used by tooling.
        const withUnused = rawResults.map(r => unusedNames.has(r.package.name) && (0, types_1.isUnusedRemovalEligibleSection)(r.package.section)
            ? { ...r, isUnused: true, alternatives: [] } : r);
        progress.report({ message: 'Analyzing upgrade blockers...' });
        const enrichResult = await (0, blocker_enricher_1.enrichWithBlockers)(withUnused, workspaceRoot.fsPath, logger);
        let results = enrichResult.results;
        lastReverseDeps = enrichResult.reverseDeps;
        progress.report({ message: 'Analyzing dependency graph...' });
        const depGraph = await (0, dep_graph_1.fetchDepGraph)(workspaceRoot.fsPath);
        let depGraphSummary = null;
        if (depGraph.success && depGraph.packages.length > 0) {
            const directDeps = deps.filter(d => d.isDirect).map(d => d.name);
            const overrides = (0, pubspec_parser_1.parseDependencyOverrides)(parsed.yamlContent);
            const knownIssuesMap = (0, known_issues_1.allKnownIssues)();
            const transitiveInfos = (0, transitive_analyzer_1.countTransitives)(directDeps, depGraph.packages);
            const sharedDeps = (0, transitive_analyzer_1.findSharedDeps)(directDeps, depGraph.packages);
            const enrichedInfos = (0, transitive_analyzer_1.enrichTransitiveInfo)(transitiveInfos, sharedDeps, knownIssuesMap);
            const transitiveMap = new Map(enrichedInfos.map((t) => [t.directDep, t]));
            results = results.map(r => {
                const tInfo = transitiveMap.get(r.package.name) ?? null;
                if (!tInfo) {
                    return r;
                }
                const penalty = (0, transitive_analyzer_1.calcTransitiveRiskPenalty)(tInfo);
                const adjustedScore = Math.max(0, r.score - penalty);
                return { ...r, transitiveInfo: tInfo, score: adjustedScore };
            });
            depGraphSummary = (0, transitive_analyzer_1.buildDepGraphSummary)(directDeps, depGraph.packages, overrides.length);
            logger.info(`Dep graph: ${depGraphSummary.directCount} direct, ` +
                `${depGraphSummary.transitiveCount} transitive, ` +
                `${overrides.length} overrides`);
        }
        progress.report({ message: 'Analyzing overrides...' });
        const overrideAnalyses = await (0, override_runner_1.runOverrideAnalysis)(parsed.yamlContent, deps, depGraph.success ? depGraph.packages : [], workspaceRoot.fsPath, logger);
        lastOverrideAnalyses = overrideAnalyses;
        if (overrideAnalyses.length > 0) {
            const staleCount = overrideAnalyses.filter(a => a.status === 'stale').length;
            logger.info(`Overrides: ${overrideAnalyses.length} total, ${staleCount} stale`);
        }
        if ((0, config_service_1.getVulnScanEnabled)()) {
            progress.report({ message: 'Scanning for vulnerabilities...' });
            const vulnQueries = results.map(r => ({
                name: r.package.name,
                version: r.package.version,
            }));
            // Query OSV and GitHub Advisory in parallel for performance
            const [osvResults, ghsaResults] = await Promise.all([
                (0, osv_api_1.queryVulnerabilities)(vulnQueries, targets.cache, logger),
                (0, config_service_1.getGitHubAdvisoryEnabled)()
                    ? (0, github_advisory_api_1.queryGitHubAdvisories)(vulnQueries, (0, config_service_1.getGithubToken)() || undefined, targets.cache, logger)
                    : Promise.resolve([]),
            ]);
            const osvMap = new Map(osvResults.map(vr => [`${vr.name}@${vr.version}`, vr.vulnerabilities]));
            const ghsaMap = new Map(ghsaResults.map(vr => [`${vr.name}@${vr.version}`, vr.vulnerabilities]));
            results = results.map(r => {
                const key = `${r.package.name}@${r.package.version}`;
                const osvVulns = osvMap.get(key) ?? [];
                const ghsaVulns = ghsaMap.get(key) ?? [];
                const merged = (0, github_advisory_api_1.mergeVulnerabilities)(osvVulns, ghsaVulns);
                return merged.length > 0 ? { ...r, vulnerabilities: merged } : r;
            });
            const vulnCount = results.filter(r => r.vulnerabilities.length > 0).length;
            if (vulnCount > 0) {
                logger.info(`Vulnerabilities: ${vulnCount} package(s) affected`);
            }
        }
        latestResults = results;
        lastParsedDeps = parsed;
        lastScanMeta = await (0, scan_helpers_1.buildScanMeta)(startTime);
        const counts = (0, status_classifier_1.countByCategory)(results);
        logger.info(`Scan complete — ${logger.elapsedMs}ms — ` +
            `vibrant:${counts.vibrant} quiet:${counts.quiet} ` +
            `legacy:${counts.legacy} stale:${counts.stale} eol:${counts.eol}`);
        publishResults(targets, results, parsed, depGraphSummary);
        (0, lock_diff_notifier_1.notifyLockDiff)(oldVersions, results);
        try {
            await logger.writeToFile();
        }
        catch {
            // Log write is best-effort — never block scan results
        }
    });
}
function getSuppressedSet() {
    const config = vscode.workspace.getConfiguration('saropaLints.packageVibrancy');
    return new Set(config.get('suppressedPackages', []));
}
function publishResults(targets, results, parsed, depGraphSummary = null) {
    targets.adoptionGate.clearDecorations();
    targets.tree.updateResults(results);
    targets.tree.updateDepGraphSummary(depGraphSummary);
    targets.tree.updateOverrideAnalyses(lastOverrideAnalyses);
    targets.state.updateFromResults(results);
    const config = vscode.workspace.getConfiguration('saropaLints.packageVibrancy');
    const budgetConfig = (0, budget_checker_1.readBudgetConfig)(key => config.get(key));
    if ((0, budget_checker_1.hasBudgets)(budgetConfig)) {
        lastBudgetResults = (0, budget_checker_1.checkBudgets)(results, budgetConfig);
        const budgetSummary = (0, budget_checker_1.formatBudgetSummary)(lastBudgetResults);
        targets.tree.updateBudgetResults(lastBudgetResults, budgetSummary);
        targets.diagnostics.updateBudgetResults(lastBudgetResults);
    }
    else {
        lastBudgetResults = [];
        targets.tree.updateBudgetResults([], '');
        targets.diagnostics.updateBudgetResults([]);
    }
    updateFilteredTargets(targets, results, parsed);
    freshnessWatcher?.start(results);
}
function updateFilteredTargets(targets, results, parsed) {
    const suppressed = getSuppressedSet();
    const active = results.filter(r => !suppressed.has(r.package.name));
    const splits = (0, family_conflict_detector_1.detectFamilySplits)(active);
    lastInsights = (0, consolidate_insights_1.consolidateInsights)(active, lastOverrideAnalyses, splits);
    const packageRanges = buildPackageRanges(parsed.yamlContent, active);
    const collectorContext = {
        packageRanges,
        overrideAnalyses: lastOverrideAnalyses,
        familySplits: splits,
    };
    (0, problems_1.collectProblemsFromResults)(active, collectorContext, problemRegistry);
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
    // Fire callback to update the unified status bar in extension.ts
    if (vibrancyStatusCallback) {
        const avg = results.reduce((s, r) => s + r.score, 0) / results.length;
        const updateCount = results.filter(r => r.updateInfo && r.updateInfo.updateStatus !== 'up-to-date').length;
        vibrancyStatusCallback({
            packageCount: results.length,
            averageScore: Math.round(avg),
            updateCount,
            actionCount: lastInsights.length,
        });
    }
}
let upgradeChannel = null;
async function planAndExecuteUpgrades() {
    if (latestResults.length === 0) {
        vscode.window.showWarningMessage('Run a scan first');
        return;
    }
    if (!upgradeChannel) {
        upgradeChannel = vscode.window.createOutputChannel('Saropa: Upgrade Plan');
    }
    upgradeChannel.clear();
    (0, upgrade_sequencer_1.setOverrideAnalyses)(lastOverrideAnalyses);
    const reverseDeps = lastReverseDeps ?? new Map();
    const steps = (0, upgrade_sequencer_1.buildUpgradeOrder)(latestResults, reverseDeps);
    if (steps.length === 0) {
        vscode.window.showInformationMessage('No upgradable packages found');
        return;
    }
    upgradeChannel.appendLine((0, upgrade_executor_1.formatUpgradePlan)(steps));
    upgradeChannel.show(true);
    const choice = await vscode.window.showInformationMessage(`Proceed with ${steps.length} upgrade(s)? Stop on first failure.`, 'Execute', 'Cancel');
    if (choice !== 'Execute') {
        return;
    }
    const config = vscode.workspace.getConfiguration('saropaLints.packageVibrancy');
    const report = await vscode.window.withProgress({
        location: vscode.ProgressLocation.Notification,
        title: 'Executing upgrade plan...',
        cancellable: false,
    }, () => (0, upgrade_executor_1.executeUpgradePlan)(steps, upgradeChannel, {
        skipTests: config.get('upgradeSkipTests', false),
        maxSteps: config.get('upgradeMaxSteps', 20),
        autoCommit: config.get('upgradeAutoCommit', false),
    }));
    upgradeChannel.appendLine('\n' + (0, upgrade_executor_1.formatUpgradeReport)(report));
    upgradeChannel.show(true);
    if (report.failedAt) {
        vscode.window.showWarningMessage(`Upgrade stopped at ${report.failedAt} — ${report.completedCount}/${steps.length} completed`);
    }
    else {
        vscode.window.showInformationMessage(`All ${report.completedCount} upgrades completed successfully`);
    }
}
async function requireResults(action, successMsg) {
    if (latestResults.length === 0) {
        vscode.window.showWarningMessage('Run a scan first');
        return;
    }
    const result = await action(latestResults);
    if (result) {
        vscode.window.showInformationMessage(successMsg(result));
    }
}
async function goToOverride(packageName) {
    const analysis = lastOverrideAnalyses.find(a => a.entry.name === packageName);
    if (!analysis || !lastParsedDeps) {
        return;
    }
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
async function handleNewVersions(notifications) {
    if (notifications.length === 0) {
        return;
    }
    const message = (0, freshness_watcher_1.formatNotificationMessage)(notifications);
    const actions = (0, freshness_watcher_1.createNotificationActions)();
    const choice = await vscode.window.showInformationMessage(message, ...actions);
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
async function suppressPackageByName(packageName, targets) {
    await (0, config_service_1.addSuppressedPackage)(packageName);
    vscode.window.showInformationMessage(`Suppressed "${packageName}" — diagnostics will be hidden`);
    if (lastParsedDeps) {
        updateFilteredTargets(targets, latestResults, lastParsedDeps);
    }
}
async function suppressByCategory(targets) {
    if (latestResults.length === 0) {
        vscode.window.showWarningMessage('Run a scan first');
        return;
    }
    const items = [
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
    if (!selection) {
        return;
    }
    let toSuppress = [];
    if (selection.label.includes('End of Life')) {
        toSuppress = getPackagesByCategory('end-of-life');
    }
    else if (selection.label.includes('Legacy-Locked')) {
        toSuppress = getPackagesByCategory('legacy-locked');
    }
    else if (selection.label.includes('Quiet')) {
        toSuppress = getPackagesByCategory('quiet');
    }
    else if (selection.label.includes('Blocked')) {
        toSuppress = getBlockedPackages();
    }
    if (toSuppress.length === 0) {
        vscode.window.showInformationMessage('No packages to suppress');
        return;
    }
    const count = await (0, config_service_1.addSuppressedPackages)(toSuppress);
    vscode.window.showInformationMessage(`Suppressed ${count} package(s)`);
    if (lastParsedDeps) {
        updateFilteredTargets(targets, latestResults, lastParsedDeps);
    }
}
async function suppressAllProblems(targets) {
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
    const confirm = await vscode.window.showWarningMessage(`Suppress all ${unhealthy.length} unhealthy packages? This will hide all diagnostics.`, { modal: true }, 'Suppress All');
    if (confirm !== 'Suppress All') {
        return;
    }
    const count = await (0, config_service_1.addSuppressedPackages)(unhealthy);
    vscode.window.showInformationMessage(`Suppressed ${count} package(s)`);
    if (lastParsedDeps) {
        updateFilteredTargets(targets, latestResults, lastParsedDeps);
    }
}
async function unsuppressAll(targets) {
    const count = await (0, config_service_1.clearSuppressedPackages)();
    if (count === 0) {
        vscode.window.showInformationMessage('No suppressed packages');
        return;
    }
    vscode.window.showInformationMessage(`Unsuppressed ${count} package(s)`);
    if (lastParsedDeps) {
        updateFilteredTargets(targets, latestResults, lastParsedDeps);
    }
}
function countCategory(category) {
    return latestResults.filter(r => r.category === category).length;
}
function countBlocked() {
    return latestResults.filter(r => r.blocker !== undefined).length;
}
function getPackagesByCategory(category) {
    return latestResults
        .filter(r => r.category === category)
        .map(r => r.package.name);
}
function getBlockedPackages() {
    return latestResults
        .filter(r => r.blocker !== undefined)
        .map(r => r.package.name);
}
function stopFreshnessWatcher() {
    freshnessWatcher?.stop();
    // Dispose the lazily-created output channel to avoid a resource leak
    // when the extension deactivates (it was never disposed before).
    if (upgradeChannel) {
        upgradeChannel.dispose();
        upgradeChannel = null;
    }
}
async function runSortDependencies() {
    const pubspecUri = await (0, pubspec_editor_1.findPubspecYaml)();
    if (!pubspecUri) {
        vscode.window.showWarningMessage('No pubspec.yaml found in workspace');
        return;
    }
    const config = vscode.workspace.getConfiguration('saropaLints.packageVibrancy');
    const sdkFirst = config.get('sortSdkFirst', true);
    const result = await (0, pubspec_sorter_1.sortDependencies)(pubspecUri, { sdkFirst });
    if (!result.sorted) {
        vscode.window.showInformationMessage('Dependencies already sorted');
        return;
    }
    vscode.window.showInformationMessage(`Sorted ${result.entriesMoved} dependencies in ${result.sectionsModified.join(', ')}`);
}
async function updateToPrerelease(packageName, version) {
    const pubspecUri = await (0, pubspec_editor_1.findPubspecYaml)();
    if (!pubspecUri) {
        vscode.window.showWarningMessage('No pubspec.yaml found');
        return;
    }
    const confirm = await vscode.window.showWarningMessage(`Update ${packageName} to prerelease ${version}? Prereleases may contain breaking changes.`, { modal: true }, 'Update');
    if (confirm !== 'Update') {
        return;
    }
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
async function runBulkUpdate(filter, targets) {
    if (latestResults.length === 0) {
        vscode.window.showWarningMessage('Run a scan first');
        return;
    }
    const result = await (0, bulk_updater_1.bulkUpdate)(latestResults, {
        incrementFilter: filter,
    });
    if (result.updated.length > 0 && !result.cancelled) {
        await runScan(targets);
    }
}
async function generateCiConfig() {
    if (latestResults.length === 0) {
        vscode.window.showWarningMessage('Run a scan first to generate CI config with appropriate thresholds');
        return;
    }
    const platforms = (0, ci_generator_1.getAvailablePlatforms)();
    const platformSelection = await vscode.window.showQuickPick(platforms.map(p => ({
        label: p.label,
        description: p.description,
        id: p.id,
    })), {
        title: 'Generate CI Pipeline',
        placeHolder: 'Select CI platform',
    });
    if (!platformSelection) {
        return;
    }
    const platform = platformSelection.id;
    const suggested = (0, threshold_suggester_1.suggestThresholds)(latestResults);
    const thresholds = await promptThresholds(suggested);
    if (!thresholds) {
        return;
    }
    const content = (0, ci_generator_1.generateCiWorkflow)(platform, thresholds);
    const defaultPath = (0, ci_generator_1.getDefaultOutputPath)(platform);
    const folders = vscode.workspace.workspaceFolders;
    if (!folders || folders.length === 0) {
        vscode.window.showErrorMessage('No workspace folder open');
        return;
    }
    const targetPath = vscode.Uri.joinPath(folders[0].uri, defaultPath);
    let shouldWrite = true;
    try {
        await vscode.workspace.fs.stat(targetPath);
        const overwrite = await vscode.window.showWarningMessage(`${defaultPath} already exists. Overwrite?`, { modal: true }, 'Overwrite');
        shouldWrite = overwrite === 'Overwrite';
    }
    catch {
        const parentDir = vscode.Uri.joinPath(targetPath, '..');
        try {
            await vscode.workspace.fs.stat(parentDir);
        }
        catch {
            await vscode.workspace.fs.createDirectory(parentDir);
        }
    }
    if (!shouldWrite) {
        return;
    }
    await vscode.workspace.fs.writeFile(targetPath, Buffer.from(content, 'utf-8'));
    const doc = await vscode.workspace.openTextDocument(targetPath);
    await vscode.window.showTextDocument(doc);
    vscode.window.showInformationMessage(`CI pipeline generated: ${defaultPath}`);
}
async function promptThresholds(suggested) {
    const summary = (0, threshold_suggester_1.formatThresholdsSummary)(suggested);
    const action = await vscode.window.showQuickPick([
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
    ], {
        title: 'Configure CI Thresholds',
        placeHolder: 'Based on current scan results',
    });
    if (!action) {
        return undefined;
    }
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
    if (maxEol === undefined) {
        return undefined;
    }
    const maxStale = await vscode.window.showInputBox({
        title: 'Max Stale Packages',
        prompt: 'Maximum number of stale packages allowed (low maintenance activity)',
        value: String(suggested.maxStale),
        validateInput: v => {
            const n = parseInt(v, 10);
            return isNaN(n) || n < 0 ? 'Enter a non-negative number' : undefined;
        },
    });
    if (maxStale === undefined) {
        return undefined;
    }
    const maxLegacy = await vscode.window.showInputBox({
        title: 'Max Legacy-Locked Packages',
        prompt: 'Maximum number of legacy-locked packages allowed',
        value: String(suggested.maxLegacyLocked),
        validateInput: v => {
            const n = parseInt(v, 10);
            return isNaN(n) || n < 0 ? 'Enter a non-negative number' : undefined;
        },
    });
    if (maxLegacy === undefined) {
        return undefined;
    }
    const minVibrancy = await vscode.window.showInputBox({
        title: 'Minimum Average Vibrancy',
        prompt: 'Minimum average vibrancy score (0-100) required',
        value: String(suggested.minAverageVibrancy),
        validateInput: v => {
            const n = parseInt(v, 10);
            return isNaN(n) || n < 0 || n > 100 ? 'Enter a number between 0 and 100' : undefined;
        },
    });
    if (minVibrancy === undefined) {
        return undefined;
    }
    const failOnVuln = await vscode.window.showQuickPick([
        { label: 'Yes', description: 'Fail CI on known vulnerabilities', value: true },
        { label: 'No', description: 'Warn but do not fail', value: false },
    ], {
        title: 'Fail on Vulnerabilities?',
        placeHolder: 'Should the CI fail when vulnerabilities are detected?',
    });
    if (!failOnVuln) {
        return undefined;
    }
    return {
        maxStale: parseInt(maxStale, 10),
        maxEndOfLife: parseInt(maxEol, 10),
        maxLegacyLocked: parseInt(maxLegacy, 10),
        minAverageVibrancy: parseInt(minVibrancy, 10),
        failOnVulnerability: failOnVuln.value,
    };
}
async function runComparePackages(cache) {
    const packageNames = await promptForPackageNames();
    if (!packageNames || packageNames.length < 2) {
        vscode.window.showWarningMessage('Select 2-3 packages to compare');
        return;
    }
    if (packageNames.length > 3) {
        vscode.window.showWarningMessage('Maximum 3 packages for comparison');
        return;
    }
    const comparisonData = await vscode.window.withProgress({
        location: vscode.ProgressLocation.Notification,
        title: 'Fetching package data...',
        cancellable: false,
    }, async () => {
        const resolvedNames = new Set(latestResults.map(r => r.package.name));
        const data = [];
        for (const name of packageNames) {
            const existing = latestResults.find(r => r.package.name === name);
            if (existing) {
                data.push((0, comparison_ranker_1.resultToComparisonData)(existing, true));
            }
            else {
                const fetched = await fetchComparisonData(name, cache);
                if (fetched) {
                    data.push({ ...fetched, inProject: resolvedNames.has(name) });
                }
            }
        }
        return data;
    });
    if (comparisonData.length < 2) {
        vscode.window.showWarningMessage('Could not fetch enough package data');
        return;
    }
    comparison_webview_1.ComparisonPanel.createOrShow(comparisonData);
}
async function promptForPackageNames() {
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
    if (!input) {
        return undefined;
    }
    return input.split(',')
        .map(s => s.trim())
        .filter(s => s.length > 0);
}
async function fetchComparisonData(name, cache) {
    const [info, metrics, publisher, archiveSize] = await Promise.all([
        (0, pub_dev_api_1.fetchPackageInfo)(name, cache),
        (0, pub_dev_api_1.fetchPackageMetrics)(name, cache),
        (0, pub_dev_api_1.fetchPublisher)(name, cache),
        (0, pub_dev_api_1.fetchArchiveSize)(name, cache),
    ]);
    if (!info) {
        return null;
    }
    let stars = null;
    let openIssues = null;
    if (info.repositoryUrl?.includes('github.com')) {
        const extracted = (0, github_api_1.extractGitHubRepo)(info.repositoryUrl);
        if (extracted) {
            const ghMetrics = await (0, github_api_1.fetchRepoMetrics)(extracted.owner, extracted.repo, { cache });
            if (ghMetrics) {
                stars = ghMetrics.stars;
                // Prefer true issue count (excluding PRs) when available
                openIssues = ghMetrics.trueOpenIssues ?? ghMetrics.openIssues;
            }
        }
    }
    const bloatRating = archiveSize !== null ? (0, bloat_calculator_1.calcBloatRating)(archiveSize) : null;
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
function buildPackageRanges(yamlContent, results) {
    const ranges = new Map();
    for (const result of results) {
        const range = (0, pubspec_parser_2.findPackageRange)(yamlContent, result.package.name);
        if (range) {
            ranges.set(result.package.name, range);
        }
    }
    return ranges;
}
//# sourceMappingURL=extension-activation.js.map