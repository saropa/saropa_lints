"use strict";
/**
 * Saropa Lints extension entry point.
 * Master switch (saropaLints.enabled) gates setup and analysis; when on,
 * extension manages pubspec and analysis_options and runs init/analyze.
 */
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
exports.activate = activate;
exports.deactivate = deactivate;
const vscode = __importStar(require("vscode"));
const fs = __importStar(require("fs"));
const path = __importStar(require("path"));
const setup_1 = require("./setup");
const codeLensProvider_1 = require("./codeLensProvider");
const issuesTree_1 = require("./views/issuesTree");
const overviewTree_1 = require("./views/overviewTree");
const summaryTree_1 = require("./views/summaryTree");
const configTree_1 = require("./views/configTree");
const suggestionsTree_1 = require("./views/suggestionsTree");
const securityPostureTree_1 = require("./views/securityPostureTree");
const fileRiskTree_1 = require("./views/fileRiskTree");
const aboutView_1 = require("./views/aboutView");
const violationsReader_1 = require("./violationsReader");
const pubspecReader_1 = require("./pubspecReader");
const runHistory_1 = require("./runHistory");
const healthScore_1 = require("./healthScore");
const inlineAnnotations_1 = require("./inlineAnnotations");
const configWriter_1 = require("./configWriter");
const reportWriter_1 = require("./reportWriter");
const owaspExport_1 = require("./owaspExport");
const projectRoot_1 = require("./projectRoot");
const extension_activation_1 = require("./vibrancy/extension-activation");
const copyTreeAsJson_1 = require("./copyTreeAsJson");
const treeSerializers_1 = require("./treeSerializers");
function getConfig() {
    return vscode.workspace.getConfiguration('saropaLints');
}
function updateContext(enabled, hasViolations) {
    void vscode.commands.executeCommand('setContext', 'saropaLints.enabled', enabled);
    void vscode.commands.executeCommand('setContext', 'saropaLints.hasViolations', hasViolations);
}
function updateIssuesBadge(view, issuesProvider) {
    const root = (0, projectRoot_1.getProjectRoot)();
    if (!root)
        return;
    const data = (0, violationsReader_1.readViolations)(root);
    const total = data?.summary?.totalViolations ?? data?.violations?.length ?? 0;
    const critical = data?.summary?.byImpact?.critical ?? 0;
    if (total > 0 && view.badge !== undefined) {
        view.badge = {
            value: critical > 0 ? critical : total,
            tooltip: critical > 0 ? `${critical} critical, ${total} total` : `${total} violations`,
        };
    }
    else if (view.badge !== undefined) {
        view.badge = undefined;
    }
}
function activate(context) {
    // Detect whether this workspace is a Dart/Flutter project so the UI can
    // show appropriate welcome content instead of a misleading "Enable" button.
    // getProjectRoot() searches workspace root then one-level-deep subdirectories.
    const root = (0, projectRoot_1.getProjectRoot)();
    const isDartProject = root !== undefined;
    void vscode.commands.executeCommand('setContext', 'saropaLints.isDartProject', isDartProject);
    const cfg = getConfig();
    let enabled = cfg.get('enabled', false) ?? false;
    // Auto-enable when saropa_lints is already in pubspec.yaml but the user
    // hasn't explicitly toggled the setting. This avoids the "off by default"
    // friction for projects that already depend on the package — no files are
    // touched, we just flip the workspace flag.
    if (!enabled && isDartProject) {
        const inspection = cfg.inspect('enabled');
        const explicitlySet = inspection?.workspaceValue !== undefined
            || inspection?.workspaceFolderValue !== undefined;
        if (!explicitlySet && root && (0, pubspecReader_1.hasSaropaLintsDep)(root)) {
            enabled = true;
            // Fire-and-forget: persist so subsequent activations skip this check.
            void cfg.update('enabled', true, vscode.ConfigurationTarget.Workspace);
        }
    }
    updateContext(enabled, false);
    const issuesProvider = new issuesTree_1.IssuesTreeProvider(context.workspaceState);
    const overviewProvider = new overviewTree_1.OverviewTreeProvider(context.workspaceState);
    const summaryProvider = new summaryTree_1.SummaryTreeProvider();
    const configProvider = new configTree_1.ConfigTreeProvider();
    const suggestionsProvider = new suggestionsTree_1.SuggestionsTreeProvider();
    const securityProvider = new securityPostureTree_1.SecurityPostureTreeProvider();
    const fileRiskProvider = new fileRiskTree_1.FileRiskTreeProvider();
    context.subscriptions.push(vscode.window.registerTreeDataProvider('saropaLints.overview', overviewProvider));
    const issuesView = vscode.window.createTreeView('saropaLints.issues', {
        treeDataProvider: issuesProvider,
        showCollapseAll: true,
    });
    updateIssuesBadge(issuesView, issuesProvider);
    function updateIssuesViewMessage() {
        const state = issuesProvider.getFilterState();
        const focused = issuesProvider.getFocusedFile();
        void vscode.commands.executeCommand('setContext', 'saropaLints.hasIssuesFilter', state.hasActiveFilters);
        void vscode.commands.executeCommand('setContext', 'saropaLints.hasSuppressions', state.hasSuppressions);
        void vscode.commands.executeCommand('setContext', 'saropaLints.hasFocusedFile', focused !== undefined);
        if (focused) {
            const basename = focused.split('/').pop() ?? focused;
            issuesView.message = `Focused: ${basename} \u2014 Showing ${state.filteredCount} of ${state.totalUnfiltered}`;
        }
        else if (state.hasActiveFilters || state.hasSuppressions) {
            issuesView.message = `Showing ${state.filteredCount} of ${state.totalUnfiltered}`;
        }
        else {
            issuesView.message = undefined;
        }
    }
    updateIssuesViewMessage();
    (0, issuesTree_1.registerIssueCommands)(issuesProvider, context);
    (0, codeLensProvider_1.registerCodeLensProvider)(context);
    (0, inlineAnnotations_1.registerInlineAnnotations)(context);
    context.subscriptions.push(issuesView, vscode.window.registerTreeDataProvider('saropaLints.summary', summaryProvider), vscode.window.registerTreeDataProvider('saropaLints.config', configProvider), vscode.window.registerTreeDataProvider('saropaLints.suggestions', suggestionsProvider), vscode.window.registerTreeDataProvider('saropaLints.securityPosture', securityProvider), vscode.window.registerTreeDataProvider('saropaLints.fileRisk', fileRiskProvider));
    const refreshAll = () => {
        issuesProvider.refresh();
        overviewProvider.refresh();
        summaryProvider.refresh();
        configProvider.refresh();
        suggestionsProvider.refresh();
        securityProvider.refresh();
        fileRiskProvider.refresh();
        (0, codeLensProvider_1.invalidateCodeLenses)();
        updateIssuesBadge(issuesView, issuesProvider);
        updateIssuesViewMessage();
        // D3: Invalidate cache then refresh inline annotations for new data.
        (0, inlineAnnotations_1.invalidateAnnotationCache)();
        (0, inlineAnnotations_1.updateAnnotationsForAllEditors)();
    };
    context.subscriptions.push(vscode.workspace.onDidChangeConfiguration((e) => {
        if (!e.affectsConfiguration('saropaLints'))
            return;
        const c = getConfig();
        const en = c.get('enabled', false) ?? false;
        updateContext(en, issuesProvider.hasViolations());
        refreshAll();
        // Status bars must update when config changes (e.g. tier changed via Settings UI).
        updateAllStatusBars();
    }));
    // Invalidate cached project root when workspace folders change so the
    // extension re-discovers pubspec.yaml in the new layout.
    context.subscriptions.push(vscode.workspace.onDidChangeWorkspaceFolders(() => {
        (0, projectRoot_1.invalidateProjectRoot)();
        refreshAll();
    }));
    const violationsPath = () => {
        const root = (0, projectRoot_1.getProjectRoot)();
        return root ? path.join(root, 'reports', '.saropa_lints', 'violations.json') : null;
    };
    // Debounce refresh when violations.json changes to avoid rapid successive updates.
    let refreshDebounceTimer;
    const debouncedRefresh = () => {
        if (refreshDebounceTimer)
            clearTimeout(refreshDebounceTimer);
        refreshDebounceTimer = setTimeout(() => {
            refreshDebounceTimer = undefined;
            // W5/W6/H1: Record snapshot BEFORE refreshing views so tree providers
            // see the updated history (avoids stale findPreviousScore reads).
            const root = (0, projectRoot_1.getProjectRoot)();
            if (root) {
                const data = (0, violationsReader_1.readViolations)(root);
                if (data) {
                    const { history, appended } = (0, runHistory_1.appendSnapshot)(context.workspaceState, data);
                    // Refresh views after snapshot is persisted so Overview reads fresh history.
                    refreshAll();
                    // Pass pre-loaded data to avoid re-reading violations.json from disk.
                    updateAllStatusBars(data);
                    // C7: Keep viewsWelcome when-clauses current when data appears via file watcher.
                    updateContext(getConfig().get('enabled', false) ?? false, issuesProvider.hasViolations());
                    // Only show celebration when a genuinely new snapshot was recorded.
                    if (appended && history.length >= 2) {
                        const prev = history[history.length - 2];
                        const curr = history[history.length - 1];
                        const delta = prev.total - curr.total;
                        // D8: Score-driven celebration — mention score delta when available.
                        const scoreDelta = (prev.score !== undefined && curr.score !== undefined)
                            ? (0, healthScore_1.formatScoreDelta)(curr.score, prev.score)
                            : '';
                        if (delta > 0) {
                            const scoreMsg = scoreDelta ? ` (Score: ${curr.score} ${scoreDelta})` : '';
                            void vscode.window.setStatusBarMessage(`You fixed ${delta} issue${delta === 1 ? '' : 's'}!${scoreMsg}`, 5000);
                        }
                        if (prev.critical > 0 && curr.critical === 0) {
                            void vscode.window.showInformationMessage('Saropa Lints: No critical issues!');
                        }
                        // D8: Score crossed a milestone threshold.
                        if (curr.score !== undefined) {
                            const crossing = (0, runHistory_1.detectThresholdCrossing)(curr.score, (0, runHistory_1.findPreviousScore)(history));
                            if (crossing?.direction === 'up') {
                                // Report: log milestone crossing.
                                (0, reportWriter_1.logSection)('Milestone');
                                (0, reportWriter_1.logReport)(`- Score reached ${crossing.threshold} (current: ${curr.score})`);
                                if (root)
                                    (0, reportWriter_1.flushReport)(root);
                                void vscode.window.showInformationMessage(`Saropa Lints: Score reached ${crossing.threshold} \u2014 great work!`);
                            }
                            else if (crossing?.direction === 'down') {
                                // D8: Non-shaming regression nudge with actionable button.
                                const msg = curr.critical > 0
                                    ? `${curr.critical} critical issue${curr.critical === 1 ? '' : 's'} \u2014 view.`
                                    : `Score dipped below ${crossing.threshold} \u2014 view issues.`;
                                void vscode.window.showInformationMessage(`Saropa Lints: ${msg}`, 'View Issues')
                                    .then((choice) => {
                                    if (choice === 'View Issues') {
                                        void vscode.commands.executeCommand('saropaLints.focusIssues');
                                    }
                                });
                            }
                        }
                    }
                    return;
                }
            }
            // Fallback: no root or no data — still refresh views.
            refreshAll();
        }, 300);
    };
    context.subscriptions.push({
        dispose: () => {
            if (refreshDebounceTimer)
                clearTimeout(refreshDebounceTimer);
        },
    });
    const watchViolations = () => {
        const p = violationsPath();
        if (!p)
            return;
        const watcher = vscode.workspace.createFileSystemWatcher(p);
        watcher.onDidChange(debouncedRefresh);
        watcher.onDidCreate(debouncedRefresh);
        context.subscriptions.push(watcher);
    };
    watchViolations();
    const extVersion = context.extension.packageJSON.version;
    const statusBarItem = vscode.window.createStatusBarItem(vscode.StatusBarAlignment.Right, 100);
    context.subscriptions.push(statusBarItem);
    // Vibrancy data pushed from the vibrancy subsystem via callback.
    let vibrancyData = null;
    // Single unified status bar item showing lint score, tier, and vibrancy.
    // Accepts optional pre-loaded data to avoid re-reading violations.json from disk
    // when the caller already has it (e.g. debouncedRefresh).
    const updateAllStatusBars = (preloadedData) => {
        // Hide status bar entirely for non-Dart projects.
        if (!isDartProject) {
            statusBarItem.hide();
            return;
        }
        const en = getConfig().get('enabled', false) ?? false;
        const tier = getConfig().get('tier', 'recommended') ?? 'recommended';
        // Check whether vibrancy score should be shown in the status bar.
        const showVibrancy = vscode.workspace
            .getConfiguration('saropaLints.packageVibrancy')
            .get('showInStatusBar', true) && vibrancyData !== null;
        // Format vibrancy segment: "7/10" (score out of 10).
        const vibrancyLabel = showVibrancy
            ? `${Math.round(vibrancyData.averageScore / 10)}/10`
            : null;
        if (en) {
            // Use pre-loaded data when supplied; otherwise read from disk.
            const root = (0, projectRoot_1.getProjectRoot)();
            const data = preloadedData ?? (root ? (0, violationsReader_1.readViolations)(root) : null);
            const health = data ? (0, healthScore_1.computeHealthScore)(data) : null;
            // Build the trailing segment: vibrancy score if available, otherwise tier name.
            const trailLabel = vibrancyLabel ?? tier;
            if (health) {
                // Show lint score with delta + trailing segment.
                const history = (0, runHistory_1.loadHistory)(context.workspaceState);
                const prevScore = (0, runHistory_1.findPreviousScore)(history);
                const delta = prevScore !== undefined ? ` ${(0, healthScore_1.formatScoreDelta)(health.score, prevScore)}` : '';
                statusBarItem.text = `$(checklist) Saropa: ${health.score}%${delta} · ${trailLabel}`;
                // Color the status bar based on lint score band.
                const band = (0, healthScore_1.scoreColorBand)(health.score);
                statusBarItem.backgroundColor = band === 'red'
                    ? new vscode.ThemeColor('statusBarItem.errorBackground')
                    : band === 'yellow'
                        ? new vscode.ThemeColor('statusBarItem.warningBackground')
                        : undefined;
            }
            else {
                // No lint score yet — show name + trailing segment.
                statusBarItem.text = `$(checklist) Saropa Lints · ${trailLabel}`;
                statusBarItem.backgroundColor = undefined;
            }
            // Build rich tooltip with all details.
            const tooltipLines = [`Saropa Lints v${extVersion}`];
            tooltipLines.push(`Tier: ${tier}`);
            if (health) {
                tooltipLines.push(`Lint score: ${health.score}%`);
            }
            if (showVibrancy) {
                tooltipLines.push(`Vibrancy: ${vibrancyLabel}`);
                tooltipLines.push(`${vibrancyData.packageCount} packages scanned`);
                if (vibrancyData.updateCount > 0) {
                    tooltipLines.push(`${vibrancyData.updateCount} update(s) available`);
                }
                if (vibrancyData.actionCount > 0) {
                    tooltipLines.push(`${vibrancyData.actionCount} action item(s)`);
                }
            }
            statusBarItem.tooltip = tooltipLines.join('\n');
        }
        else {
            statusBarItem.text = '$(checklist) Saropa Lints: Off';
            statusBarItem.tooltip = `Saropa Lints v${extVersion} — Disabled`;
            statusBarItem.backgroundColor = undefined;
        }
        statusBarItem.command = 'saropaLints.focusView';
        statusBarItem.show();
    };
    updateAllStatusBars();
    context.subscriptions.push(vscode.commands.registerCommand('saropaLints.enable', async () => {
        const success = await (0, setup_1.runEnable)(context);
        if (!success)
            return;
        await cfg.update('enabled', true, vscode.ConfigurationTarget.Workspace);
        updateContext(true, issuesProvider.hasViolations());
        // I5: Record snapshot before refreshing views so Overview sees fresh history.
        const root = (0, projectRoot_1.getProjectRoot)();
        const data = root ? (0, violationsReader_1.readViolations)(root) : null;
        if (data) {
            (0, runHistory_1.appendSnapshot)(context.workspaceState, data);
        }
        refreshAll();
        updateAllStatusBars(data ?? undefined);
        // I5: Auto-focus Overview to show Health Score immediately.
        await vscode.commands.executeCommand('saropaLints.overview.focus');
        // I5: Show score-aware notification with actionable buttons.
        const health = data ? (0, healthScore_1.computeHealthScore)(data) : null;
        const totalViolations = data?.summary?.totalViolations ?? data?.violations?.length ?? 0;
        // Report: log enable result with score.
        if (root) {
            (0, reportWriter_1.logSection)('Enable Result');
            if (health) {
                (0, reportWriter_1.logReport)(`- Score: ${health.score}%`);
            }
            (0, reportWriter_1.logReport)(`- Violations: ${totalViolations}`);
            (0, reportWriter_1.flushReport)(root);
        }
        await showFirstRunNotification(health, totalViolations);
    }), vscode.commands.registerCommand('saropaLints.disable', async () => {
        await (0, setup_1.runDisable)();
        await cfg.update('enabled', false, vscode.ConfigurationTarget.Workspace);
        updateContext(false, false);
        refreshAll();
        updateAllStatusBars();
    }), vscode.commands.registerCommand('saropaLints.runAnalysis', async () => {
        const ok = await (0, setup_1.runAnalysis)(context);
        if (ok) {
            refreshAll();
            updateAllStatusBars();
            updateContext(getConfig().get('enabled', false) ?? false, issuesProvider.hasViolations());
            // C7: Focus Overview after analysis to show Health Score delta.
            await vscode.commands.executeCommand('saropaLints.overview.focus');
            // C7: Include score in completion message when available.
            const root = (0, projectRoot_1.getProjectRoot)();
            const postData = root ? (0, violationsReader_1.readViolations)(root) : null;
            const health = postData ? (0, healthScore_1.computeHealthScore)(postData) : null;
            const scoreMsg = health ? ` Score: ${health.score}` : '';
            void vscode.window.setStatusBarMessage(`Saropa Lints: Analysis complete.${scoreMsg}`, 4000);
        }
    }), vscode.commands.registerCommand('saropaLints.initializeConfig', async () => {
        const success = await (0, setup_1.runInitializeConfig)(context);
        if (success) {
            // C6: Auto-run analysis after config change if setting is on.
            const runAfter = getConfig().get('runAnalysisAfterConfigChange', true) ?? true;
            if (runAfter) {
                await (0, setup_1.runAnalysis)(context);
            }
            refreshAll();
            updateAllStatusBars();
            updateContext(getConfig().get('enabled', false) ?? false, issuesProvider.hasViolations());
        }
    }), vscode.commands.registerCommand('saropaLints.openConfig', setup_1.openConfig), vscode.commands.registerCommand('saropaLints.focusView', () => {
        void vscode.commands.executeCommand('saropaLints.overview.focus');
    }), vscode.commands.registerCommand('saropaLints.openWalkthrough', () => {
        void vscode.commands.executeCommand('workbench.action.openWalkthrough', 'saropa.saropa-lints#saropaLints.gettingStarted', false);
    }), vscode.commands.registerCommand('saropaLints.showAbout', () => {
        (0, aboutView_1.showAboutPanel)(context.extensionUri, extVersion);
    }), 
    // Show all issues: clear filters and focus Issues view (e.g. from Summary "Total violations").
    vscode.commands.registerCommand('saropaLints.focusIssues', () => {
        issuesProvider.clearFilters();
        updateIssuesViewMessage();
        void vscode.commands.executeCommand('saropaLints.issues.focus');
    }), 
    // Focus Issues view filtered to a single file (Code Lens, Problems view "Show in Saropa Lints").
    vscode.commands.registerCommand('saropaLints.focusIssuesForFile', (filePath) => {
        const normalized = typeof filePath === 'string' ? filePath.replace(/\\/g, '/') : '';
        if (!normalized)
            return;
        issuesProvider.setTextFilter(normalized);
        updateIssuesViewMessage();
        void vscode.commands.executeCommand('saropaLints.issues.focus');
    }), 
    // Focus Issues view filtered to the active editor's file (e.g. from Problems view context menu).
    vscode.commands.registerCommand('saropaLints.focusIssuesForActiveFile', () => {
        const root = (0, projectRoot_1.getProjectRoot)();
        const editor = vscode.window.activeTextEditor;
        if (!root || !editor?.document?.uri) {
            void vscode.window.showInformationMessage('Open a file to show its issues in Saropa Lints.');
            return;
        }
        const relative = path.relative(root, editor.document.uri.fsPath).replace(/\\/g, '/');
        issuesProvider.setTextFilter(relative);
        updateIssuesViewMessage();
        void vscode.commands.executeCommand('saropaLints.issues.focus');
    }), vscode.commands.registerCommand('saropaLints.focusIssuesWithImpactFilter', (impact) => {
        if (impact && typeof impact === 'string') {
            issuesProvider.setImpactFilter(new Set([impact]));
            issuesProvider.setSeverityFilter(new Set(['error', 'warning', 'info']));
            updateIssuesViewMessage();
            void vscode.commands.executeCommand('saropaLints.issues.focus');
        }
    }), vscode.commands.registerCommand('saropaLints.focusIssuesWithSeverityFilter', (severity) => {
        if (severity && typeof severity === 'string') {
            issuesProvider.setSeverityFilter(new Set([severity]));
            issuesProvider.setImpactFilter(new Set(['critical', 'high', 'medium', 'low', 'opinionated']));
            updateIssuesViewMessage();
            void vscode.commands.executeCommand('saropaLints.issues.focus');
        }
    }), vscode.commands.registerCommand('saropaLints.refresh', () => {
        refreshAll();
        updateAllStatusBars();
        updateContext(getConfig().get('enabled', false) ?? false, issuesProvider.hasViolations());
    }), vscode.commands.registerCommand('saropaLints.repairConfig', async () => {
        const success = await (0, setup_1.runRepairConfig)(context);
        if (success)
            refreshAll();
    }), vscode.commands.registerCommand('saropaLints.setTier', async () => {
        // Capture pre-tier violation count for delta display in the notification.
        const root = (0, projectRoot_1.getProjectRoot)();
        const preTierTotal = root ? ((0, violationsReader_1.readViolations)(root)?.summary?.totalViolations ?? 0) : 0;
        const result = await (0, setup_1.runSetTier)(context);
        if (result) {
            // C6: setup.ts already runs analysis inside runSetTier when
            // runAnalysisAfterConfigChange is on; no duplicate call here.
            refreshAll();
            updateAllStatusBars();
            updateContext(getConfig().get('enabled', false) ?? false, issuesProvider.hasViolations());
            // Smart tier transition: build notification info from post-tier data.
            // Note: postData may reflect a prior analysis if dart analyze has not yet
            // written violations.json — counts will update on the next file-watcher refresh.
            const postData = root ? (0, violationsReader_1.readViolations)(root) : null;
            const postTotal = postData?.summary?.totalViolations ?? postData?.violations.length ?? 0;
            const isUpgrade = setup_1.TIER_ORDER.indexOf(result.tier) > setup_1.TIER_ORDER.indexOf(result.previousTier);
            // Single pass to count critical+high violations (avoids 3 filter passes over 65k items).
            let critHigh = 0;
            for (const v of postData?.violations ?? []) {
                if (v.impact === 'critical' || v.impact === 'high')
                    critHigh++;
            }
            // Auto-filter on upgrade when there are many violations and some are critical/high.
            // This shows the user a manageable set of high-priority issues instead of thousands.
            if (isUpgrade && postTotal > 50 && critHigh > 0) {
                issuesProvider.setImpactFilter(new Set(['critical', 'high']));
                issuesProvider.setSeverityFilter(new Set(['error', 'warning', 'info']));
                updateIssuesViewMessage();
            }
            await showTierChangeNotification({
                tierLabel: result.tierLabel,
                isUpgrade,
                postTotal,
                criticalPlusHigh: critHigh,
                delta: postTotal - preTierTotal,
            });
        }
    }), 
    // D1/I1: Focus Issues view filtered to a set of rule names.
    // Shared helper — hides all rules EXCEPT the given set and resets orthogonal filters.
    ...['saropaLints.focusIssuesForOwasp', 'saropaLints.focusIssuesForRules'].map((cmdId) => vscode.commands.registerCommand(cmdId, (arg) => {
        // Resolve rules: direct string[] (TreeItem click) or node (context menu).
        let rules;
        if (Array.isArray(arg)) {
            rules = arg;
        }
        else if (arg && typeof arg === 'object' && 'kind' in arg) {
            const node = arg;
            if (node.kind === 'triageGroup' && Array.isArray(node.rules)) {
                rules = node.rules;
            }
            else if (node.kind === 'triageRule' && typeof node.ruleName === 'string') {
                rules = [node.ruleName];
            }
        }
        if (!rules || rules.length === 0)
            return;
        const allRules = issuesProvider.getRuleNamesFromData();
        const keep = new Set(rules);
        const toHide = new Set(allRules.filter((r) => !keep.has(r)));
        issuesProvider.setTextFilter('');
        issuesProvider.setSeverityFilter(new Set(['error', 'warning', 'info']));
        issuesProvider.setImpactFilter(new Set(['critical', 'high', 'medium', 'low', 'opinionated']));
        issuesProvider.setRulesToHide(toHide);
        updateIssuesViewMessage();
        void vscode.commands.executeCommand('saropaLints.issues.focus');
    })), vscode.commands.registerCommand('saropaLints.showOutput', setup_1.showOutputChannel), 
    // D2: Export OWASP Compliance Report as markdown.
    vscode.commands.registerCommand('saropaLints.exportOwaspReport', async () => {
        const root = (0, projectRoot_1.getProjectRoot)();
        if (!root) {
            vscode.window.showErrorMessage('No workspace folder open.');
            return;
        }
        const data = (0, violationsReader_1.readViolations)(root);
        if (!data) {
            vscode.window.showErrorMessage('No analysis data. Run analysis first.');
            return;
        }
        const report = (0, owaspExport_1.generateOwaspReport)(data, root);
        const folder = path.join(root, 'reports', '.saropa_lints');
        try {
            fs.mkdirSync(folder, { recursive: true });
        }
        catch { /* exists */ }
        const filePath = path.join(folder, 'owasp_compliance_report.md');
        fs.writeFileSync(filePath, report, 'utf-8');
        const doc = await vscode.workspace.openTextDocument(vscode.Uri.file(filePath));
        await vscode.window.showTextDocument(doc);
        // Report: log export action.
        (0, reportWriter_1.logSection)('OWASP Export');
        (0, reportWriter_1.logReport)(`- Exported to ${filePath}`);
        (0, reportWriter_1.flushReport)(root);
    }), vscode.commands.registerCommand('saropaLints.setIssuesFilter', async () => {
        const state = issuesProvider.getFilterState();
        const value = await vscode.window.showInputBox({
            title: 'Filter issues',
            placeHolder: 'Search file path, rule, or message',
            value: state.textFilter,
            prompt: 'Leave empty to show all. Case-insensitive substring match.',
        });
        if (value !== undefined) {
            issuesProvider.setTextFilter(value);
            updateIssuesViewMessage();
        }
    }), vscode.commands.registerCommand('saropaLints.setIssuesFilterByType', async () => {
        const typeState = issuesProvider.getTypeFilterState();
        const severityIds = ['error', 'warning', 'info'];
        const impactIds = ['critical', 'high', 'medium', 'low', 'opinionated'];
        const quickPick = vscode.window.createQuickPick();
        quickPick.title = 'Filter by severity and impact';
        quickPick.canSelectMany = true;
        quickPick.items = [
            { label: 'Severity', kind: vscode.QuickPickItemKind.Separator },
            ...severityIds.map((s) => ({
                label: s.charAt(0).toUpperCase() + s.slice(1),
                description: s,
                picked: typeState.severitiesToShow.has(s),
            })),
            { label: 'Impact', kind: vscode.QuickPickItemKind.Separator },
            ...impactIds.map((s) => ({
                label: s.charAt(0).toUpperCase() + s.slice(1),
                description: s,
                picked: typeState.impactsToShow.has(s),
            })),
        ];
        quickPick.onDidAccept(() => {
            const selected = new Set(quickPick.selectedItems.map((it) => it.description ?? '').filter(Boolean));
            const severities = new Set(severityIds.filter((s) => selected.has(s)));
            const impacts = new Set(impactIds.filter((s) => selected.has(s)));
            issuesProvider.setSeverityFilter(severities.size > 0 ? severities : new Set(severityIds));
            issuesProvider.setImpactFilter(impacts.size > 0 ? impacts : new Set(impactIds));
            updateIssuesViewMessage();
            quickPick.hide();
        });
        quickPick.show();
    }), vscode.commands.registerCommand('saropaLints.setIssuesFilterByRule', async () => {
        const ruleNames = issuesProvider.getRuleNamesFromData();
        if (ruleNames.length === 0) {
            void vscode.window.showInformationMessage('No violations in current data. Run analysis first.');
            return;
        }
        const rulesToHide = issuesProvider.getRulesToHide();
        const quickPick = vscode.window.createQuickPick();
        quickPick.title = 'Filter by rule (deselect to hide)';
        quickPick.canSelectMany = true;
        quickPick.matchOnDescription = true;
        quickPick.items = ruleNames.map((rule) => ({
            label: rule,
            description: rule,
            picked: !rulesToHide.has(rule),
        }));
        quickPick.onDidAccept(() => {
            const selected = new Set(quickPick.selectedItems.map((it) => it.label));
            const toHide = new Set(ruleNames.filter((r) => !selected.has(r)));
            issuesProvider.setRulesToHide(toHide);
            updateIssuesViewMessage();
            quickPick.hide();
        });
        quickPick.show();
    }), vscode.commands.registerCommand('saropaLints.clearIssuesFilters', () => {
        issuesProvider.clearFilters();
        updateIssuesViewMessage();
    }), vscode.commands.registerCommand('saropaLints.clearSuppressions', () => {
        issuesProvider.clearSuppressionsAndRefresh();
        updateIssuesViewMessage();
    }), 
    // W7: Focus mode — show only one file's violations in the Issues tree.
    vscode.commands.registerCommand('saropaLints.focusFile', (element) => {
        if (element && typeof element === 'object' && 'kind' in element && element.kind === 'file') {
            const filePath = element.filePath;
            issuesProvider.setFocusedFile(filePath);
            updateIssuesViewMessage();
        }
    }), vscode.commands.registerCommand('saropaLints.clearFocusFile', () => {
        issuesProvider.clearFocusedFile();
        updateIssuesViewMessage();
    }), 
    // D10: Group-by picker for the Issues tree.
    vscode.commands.registerCommand('saropaLints.setGroupBy', async () => {
        const current = issuesProvider.getGroupBy();
        const items = [
            { label: 'Severity', id: 'severity' },
            { label: 'File', id: 'file' },
            { label: 'Impact', id: 'impact' },
            { label: 'Rule', id: 'rule' },
            { label: 'OWASP Category', id: 'owasp' },
        ].map((m) => ({
            label: m.id === current ? `$(check) ${m.label}` : m.label,
            description: m.id === current ? 'Current' : undefined,
            id: m.id,
        }));
        const pick = await vscode.window.showQuickPick(items, {
            title: 'Group issues by',
            placeHolder: `Current: ${current}`,
        });
        if (pick) {
            issuesProvider.setGroupBy(pick.id);
            updateIssuesViewMessage();
        }
    }), 
    // I2: Triage actions — disable/enable rules via analysis_options_custom.yaml overrides.
    // Shared helper extracts rule names from string[] (TreeItem click) or node (context menu).
    ...['saropaLints.disableRules', 'saropaLints.enableRules'].map((cmdId) => vscode.commands.registerCommand(cmdId, async (arg) => {
        const isDisable = cmdId === 'saropaLints.disableRules';
        const rules = resolveRulesFromArg(arg);
        if (!rules || rules.length === 0)
            return;
        const root = (0, projectRoot_1.getProjectRoot)();
        if (!root)
            return;
        // Confirm for large groups (>5 rules).
        if (rules.length > 5) {
            const verb = isDisable ? 'Disable' : 'Enable';
            const ok = await vscode.window.showWarningMessage(`${verb} ${rules.length} rules? This updates analysis_options_custom.yaml.`, { modal: true }, verb);
            if (ok !== verb)
                return;
        }
        // I2: Write overrides then re-init + re-analyze.
        if (isDisable) {
            (0, configWriter_1.writeRuleOverrides)(root, rules.map((r) => ({ rule: r, enabled: false })));
        }
        else {
            // Enable: remove false overrides so tier default applies.
            (0, configWriter_1.removeRuleOverrides)(root, rules);
        }
        const initOk = await (0, setup_1.runInitializeConfig)(context, `${isDisable ? 'Disabling' : 'Enabling'} ${rules.length} rule${rules.length === 1 ? '' : 's'}`);
        if (!initOk)
            return;
        const runAfter = getConfig().get('runAnalysisAfterConfigChange', true) ?? true;
        if (runAfter)
            await (0, setup_1.runAnalysis)(context);
        refreshAll();
        updateAllStatusBars();
        updateContext(getConfig().get('enabled', false) ?? false, issuesProvider.hasViolations());
        await vscode.commands.executeCommand('saropaLints.overview.focus');
    })));
    // ── Copy as JSON commands ───────────────────────────────────────────────
    // Each view gets its own command so context menus target the right view.
    registerCopyAsJsonCommands(context, {
        issuesProvider,
        configProvider,
        summaryProvider,
        securityProvider,
        fileRiskProvider,
        overviewProvider,
        suggestionsProvider,
    });
    // Package Vibrancy subsystem — registers its own views, commands, and providers
    // under the shared saropaLints sidebar container.
    // Wrapped in try/catch so a vibrancy failure doesn't kill the entire extension.
    try {
        (0, extension_activation_1.runActivation)(context, (data) => {
            vibrancyData = data;
            updateAllStatusBars();
        });
    }
    catch (err) {
        console.error('[Saropa Lints] Package Vibrancy activation failed:', err);
    }
}
/** Extract rule names from command arg: string[] (TreeItem click) or triage node (context menu). */
function resolveRulesFromArg(arg) {
    if (Array.isArray(arg))
        return arg;
    if (arg && typeof arg === 'object' && 'kind' in arg) {
        const node = arg;
        if (node.kind === 'triageGroup' && Array.isArray(node.rules))
            return node.rules;
        if (node.kind === 'triageRule' && typeof node.ruleName === 'string')
            return [node.ruleName];
    }
    return undefined;
}
/**
 * Show a smart notification after a tier change.
 *
 * On upgrade with many violations, tells the user the Issues view has been
 * auto-filtered to critical+high so they aren't overwhelmed by thousands of
 * new violations at once. Provides a "Show All" escape hatch.
 *
 * On downgrade or small upgrade (≤50 total), shows a simple delta message
 * without auto-filtering.
 */
async function showTierChangeNotification(info) {
    const deltaText = info.delta > 0 ? `+${info.delta.toLocaleString()}` : info.delta.toLocaleString();
    if (info.isUpgrade && info.postTotal > 50 && info.criticalPlusHigh > 0) {
        // Auto-filter was applied by the handler — notify user and offer escape hatch.
        const msg = `${info.tierLabel} tier: ${info.postTotal.toLocaleString()} violations (${deltaText}). `
            + `Showing ${info.criticalPlusHigh} critical + high — fix these first.`;
        const choice = await vscode.window.showInformationMessage(msg, 'View Issues', 'Show All');
        if (choice === 'View Issues') {
            // Use issues.focus (not focusIssues) to preserve the auto-filter that was
            // applied by the handler — focusIssues calls clearFilters() first.
            await vscode.commands.executeCommand('saropaLints.issues.focus');
        }
        else if (choice === 'Show All') {
            // User wants to see everything — clear the auto-filter via the existing command.
            await vscode.commands.executeCommand('saropaLints.clearIssuesFilters');
            await vscode.commands.executeCommand('saropaLints.issues.focus');
        }
    }
    else {
        // Downgrade, small upgrade, or zero critical+high — simple confirmation.
        const msg = info.delta !== 0
            ? `Tier changed to ${info.tierLabel} (${deltaText} violations).`
            : `Tier changed to ${info.tierLabel}.`;
        const choice = await vscode.window.showInformationMessage(msg, 'View Issues');
        if (choice === 'View Issues') {
            await vscode.commands.executeCommand('saropaLints.issues.focus');
        }
    }
}
/**
 * I5: Show a score-aware notification after enable with action buttons.
 * Three cases:
 *   1. Score available → "Your project scores 72/100. Room to improve."
 *   2. Violations but no score → "Saropa Lints found N issues."
 *   3. No data (analysis didn't run) → "Saropa Lints is enabled."
 */
async function showFirstRunNotification(health, totalViolations) {
    let message;
    let primaryAction;
    if (health) {
        const band = (0, healthScore_1.scoreColorBand)(health.score);
        const qualifier = band === 'green' ? 'Great start!'
            : band === 'yellow' ? 'Room to improve.'
                : 'Needs attention.';
        message = `Saropa Lints: Your project scores ${health.score}/100. ${qualifier}`;
        primaryAction = 'View Issues';
    }
    else if (totalViolations > 0) {
        message = `Saropa Lints found ${totalViolations} issue${totalViolations === 1 ? '' : 's'}.`;
        primaryAction = 'View Issues';
    }
    else {
        message = 'Saropa Lints is enabled. Run analysis to see your health score.';
        primaryAction = 'Run Analysis';
    }
    const choice = await vscode.window.showInformationMessage(message, primaryAction, 'Configure Rules');
    if (choice === 'View Issues') {
        await vscode.commands.executeCommand('saropaLints.focusIssues');
    }
    else if (choice === 'Run Analysis') {
        await vscode.commands.executeCommand('saropaLints.runAnalysis');
    }
    else if (choice === 'Configure Rules') {
        await vscode.commands.executeCommand('saropaLints.config.focus');
    }
}
/** Register "Copy as JSON" commands for all lints tree views (not vibrancy — handled separately). */
function registerCopyAsJsonCommands(context, providers) {
    const { issuesProvider, configProvider, summaryProvider, securityProvider, fileRiskProvider, overviewProvider, suggestionsProvider } = providers;
    context.subscriptions.push(vscode.commands.registerCommand('saropaLints.issues.copyAsJson', (item, selected) => (0, copyTreeAsJson_1.copyTreeNodesToClipboard)(item, selected, treeSerializers_1.serializeIssueNode, (n) => issuesProvider.getChildren(n), 'Issues')), vscode.commands.registerCommand('saropaLints.config.copyAsJson', (item, selected) => (0, copyTreeAsJson_1.copyTreeNodesToClipboard)(item, selected, treeSerializers_1.serializeConfigNode, (n) => configProvider.getChildren(n), 'Config')), vscode.commands.registerCommand('saropaLints.summary.copyAsJson', (item, selected) => (0, copyTreeAsJson_1.copyTreeNodesToClipboard)(item, selected, treeSerializers_1.serializeSummaryNode, (n) => summaryProvider.getChildren(n), 'Summary')), vscode.commands.registerCommand('saropaLints.securityPosture.copyAsJson', (item, selected) => (0, copyTreeAsJson_1.copyTreeNodesToClipboard)(item, selected, treeSerializers_1.serializeSecurityNode, (n) => securityProvider.getChildren(n), 'Security Posture')), vscode.commands.registerCommand('saropaLints.fileRisk.copyAsJson', (item, selected) => (0, copyTreeAsJson_1.copyTreeNodesToClipboard)(item, selected, treeSerializers_1.serializeFileRiskNode, (n) => fileRiskProvider.getChildren(n), 'File Risk')), vscode.commands.registerCommand('saropaLints.overview.copyAsJson', (item, selected) => (0, copyTreeAsJson_1.copyTreeNodesToClipboard)(item, selected, treeSerializers_1.serializeOverviewNode, (n) => overviewProvider.getChildren(), 'Overview')), vscode.commands.registerCommand('saropaLints.suggestions.copyAsJson', (item, selected) => (0, copyTreeAsJson_1.copyTreeNodesToClipboard)(item, selected, treeSerializers_1.serializeSuggestionNode, (n) => suggestionsProvider.getChildren(), 'Suggestions')));
}
function deactivate() {
    // Wrapped in try/catch so a vibrancy teardown error doesn't prevent clean shutdown.
    try {
        (0, extension_activation_1.stopFreshnessWatcher)();
    }
    catch (err) {
        console.error('[Saropa Lints] Package Vibrancy deactivation failed:', err);
    }
}
//# sourceMappingURL=extension.js.map