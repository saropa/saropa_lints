/**
 * Saropa Lints extension entry point.
 * `saropaLints.enabled` defaults on: upgrade checks and integration state.
 * Sidebar overview, triage, and rule-pack dashboards stay available for Dart workspaces;
 * TODOs workspace scan is opt-in via `todosAndHacks.workspaceScanEnabled`.
 *
 * Activation registers tree providers and command handlers in dependency order:
 * violations/overview trees read `reports/.saropa_lints/violations.json` written by
 * the analyzer plugin; drift advisor and vibrancy commands coordinate with workspace
 * memento keys documented on their providers. Prefer small focused modules under
 * `views/` and `commands/` over growing this file when adding features.
 */

import * as vscode from 'vscode';
import * as fs from 'node:fs';
import * as path from 'node:path';
import {
  runEnable,
  runDisable,
  runAnalysis as runAnalysisCommand,
  runAnalysisForFiles as runAnalysisForFilesCommand,
  runInitializeConfig,
  runEmitCompositePluginScaffold,
  openConfig,
  runRepairConfig,
  runSetTier,
  showOutputChannel,
  getSharedOutputChannel,
  TIER_ORDER,
} from './setup';
import { verifyPluginLiveness, surfaceLivenessResult } from './pluginLiveness';
import type { SaropaLintsApi } from './api';
import { invalidateCodeLenses, registerCodeLensProvider } from './codeLensProvider';
import { IssuesTreeProvider, parseViolationsGroupBy, registerIssueCommands, type IssueTreeNode } from './views/issuesTree';
import {
  createSidebarSectionProviders,
  updateSidebarSectionContext,
} from './views/sectionedSidebar';
import { showHelpHubQuickPick } from './views/helpHub';
import { SummaryTreeProvider } from './views/summaryTree';
import { SuppressionsTreeProvider } from './views/suppressionsTree';
import { ConfigTreeProvider } from './views/configTree';
import { SuggestionsTreeProvider } from './views/suggestionsTree';
import { SecurityPostureTreeProvider } from './views/securityPostureTree';
import { FileRiskTreeProvider } from './views/fileRiskTree';
import { TodosAndHacksTreeProvider } from './views/todosAndHacksTree';
import { showAboutPanel } from './views/aboutView';
import { registerIssuesViewCommands } from './commands/issuesViewCommands';
import { showCommandCatalogPanel } from './views/commandCatalogView';
import { showRelatedRuleTelemetryPanel } from './views/relatedRuleTelemetryView';
import { openProjectVibrancyReport } from './views/projectVibrancyReportView';
import { discoverServer } from './driftAdvisor/discovery';
import { fetchIssues } from './driftAdvisor/client';
import { mapIssuesToLocations } from './driftAdvisor/mapper';
import { DriftAdvisorTreeProvider } from './driftAdvisor/driftAdvisorTree';
import { RulePacksWebviewProvider } from './rulePacks/rulePacksWebviewProvider';
import {
  openRuleExplainPanelForViolation,
  openRuleExplainPanel,
  setRuleExplainTelemetry,
} from './views/ruleExplainView';
import {
  readViolations,
  hasViolations,
  ViolationsData,
  getViolationsPath as getViolationsFilePath,
} from './violationsReader';
import {
  SecurityHotspotReviewStateService,
} from './securityHotspotReviewState';
import {
  setConflictingRulesMetadata,
  setRelatedRulesMetadata,
  setRuleTagsMetadata,
  setSupersedesRulesMetadata,
} from './ruleMetadata';
import { hasSaropaLintsDep } from './pubspecReader';
import { createPubspecValidation, registerFallbackPubspecListeners } from './pubspec-validation';
import { PubspecCodeActionProvider } from './pubspec-code-actions';
import {
  appendSnapshot,
  loadHistory,
  findPreviousScore,
  detectThresholdCrossing,
  type RunSnapshot,
} from './runHistory';
import {
  computeHealthScore,
  formatScoreDelta,
  scoreColorBand,
  IMPACT_WEIGHTS,
  DECAY_RATE,
} from './healthScore';
import { registerInlineAnnotations, updateAnnotationsForAllEditors, invalidateAnnotationCache } from './inlineAnnotations';
import { writeRuleOverrides, removeRuleOverrides, invalidateDisabledRulesCache } from './configWriter';
import { logReport, logSection, flushReport, findLatestAnalysisReport } from './reportWriter';
import { generateOwaspReport } from './owaspExport';
import { getProjectRoot, invalidateProjectRoot } from './projectRoot';
import {
  runActivation as runVibrancyActivation,
  stopFreshnessWatcher,
  VibrancyStatusData,
  getLatestResults,
} from './vibrancy/extension-activation';
import { registerSidebarSectionVisibility, updateSidebarSectionVisibility } from './sidebarSectionVisibility';
import {
  onDriftAdvisorDisconnected,
  setDriftAdvisorServerConnected,
} from './driftAdvisor/driftAdvisorUiState';
import { SIDEBAR_SECTION_CONFIG_KEYS, defaultSidebarSectionVisible, sidebarSectionContextKey } from './sidebarSectionVisibilityKeys';
import { checkForUpgrade } from './upgrade-checker';
import { buildStatusBarLabel } from './statusBarLabel';
import { createRelatedRuleTelemetry } from './relatedRuleTelemetry';
import { registerCrossFileCommands } from './cross-file-commands';
import { registerCopyAsJsonCommands } from './extensionCopyAsJsonCommands';
import { openViolationsWideReport, refreshFindingsDashboardIfOpen } from './views/violationsWideReportView';
import { pickWorkspaceFolder } from './workspaceFolderPicker';

function getConfig() {
  return vscode.workspace.getConfiguration('saropaLints');
}

/** D8: Show regression nudge when score dipped below a threshold; offers "View Violations" action. */
function showRegressionNudge(crossing: { threshold: number }, curr: RunSnapshot): void {
  const criticalSuffix = curr.critical === 1 ? '' : 's';
  const msg =
    curr.critical > 0
      ? `${curr.critical} critical issue${criticalSuffix} \u2014 view.`
      : `Score dipped below ${crossing.threshold} \u2014 view issues.`;
  vscode.window.showInformationMessage(`Saropa Lints: ${msg}`, 'View Violations').then((choice) => {
    if (choice === 'View Violations') {
      vscode.commands.executeCommand('saropaLints.focusIssues');
    }
  });
}

/** Show celebration/milestone UI when a new snapshot was appended and history has at least 2 entries. */
function runCelebrationIfNeeded(root: string, history: RunSnapshot[], appended: boolean): void {
  if (!appended || history.length < 2) return;
  const prev = history.at(-2)!;
  const curr = history.at(-1)!;
  const delta = prev.total - curr.total;
  const scoreDelta =
    prev.score !== undefined && curr.score !== undefined
      ? formatScoreDelta(curr.score, prev.score)
      : '';
  if (delta > 0) {
    const scoreMsg = scoreDelta ? ` (Score: ${curr.score} ${scoreDelta})` : '';
    vscode.window.setStatusBarMessage(
      `You fixed ${delta} issue${delta === 1 ? '' : 's'}!${scoreMsg}`,
      5000,
    );
  }
  if (prev.critical > 0 && curr.critical === 0) {
    vscode.window.showInformationMessage('Saropa Lints: No critical issues!');
  }
  if (curr.score === undefined) return;
  const crossing = detectThresholdCrossing(curr.score, findPreviousScore(history));
  if (crossing?.direction === 'up') {
    logSection('Milestone');
    logReport(`- Score reached ${crossing.threshold} (current: ${curr.score})`);
    flushReport(root);
    vscode.window.showInformationMessage(
      `Saropa Lints: Score reached ${crossing.threshold} \u2014 great work!`,
    );
    return;
  }
  if (crossing?.direction === 'down') {
    showRegressionNudge(crossing, curr);
  }
}

function updateContext(enabled: boolean, hasViolations: boolean) {
  void vscode.commands.executeCommand('setContext', 'saropaLints.enabled', enabled);
  void vscode.commands.executeCommand('setContext', 'saropaLints.hasViolations', hasViolations);
}

/** Compact status entry: opens the Findings Dashboard (replaces the Violations tree badge). */
function updateFindingsStatusBar(item: vscode.StatusBarItem, dartProject: boolean): void {
  const root = getProjectRoot();
  if (!root || !dartProject) {
    item.hide();
    return;
  }
  const data = readViolations(root);
  const total = data?.summary?.totalViolations ?? data?.violations?.length ?? 0;
  const critical = data?.summary?.byImpact?.critical ?? 0;
  if (total <= 0) {
    item.hide();
    return;
  }
  item.text = critical > 0 ? `$(warning) ${critical}` : `$(warning) ${total}`;
  item.tooltip = critical > 0
    ? `${critical} critical of ${total} total — Open Findings Dashboard`
    : `${total} violation(s) — Open Findings Dashboard`;
  item.command = 'saropaLints.openViolationsWideReport';
  item.show();
}

function syncRuleMetadataFromViolations(data: ViolationsData | null): void {
  setRelatedRulesMetadata(data?.config?.relatedRulesByRule);
  setConflictingRulesMetadata(data?.config?.conflictingRulesByRule);
  setSupersedesRulesMetadata(data?.config?.supersedesRulesByRule);
  setRuleTagsMetadata(data?.config?.ruleMetadataByRule);
}

export function activate(context: vscode.ExtensionContext): SaropaLintsApi {
  // Detect whether this workspace is a Dart/Flutter project so the UI can
  // show appropriate welcome content instead of a misleading "Enable" button.
  // getProjectRoot() searches workspace root then one-level-deep subdirectories.
  const root = getProjectRoot();
  const isDartProject = root !== undefined;
  void vscode.commands.executeCommand('setContext', 'saropaLints.isDartProject', isDartProject);
  updateSidebarSectionVisibility();
  registerSidebarSectionVisibility(context);

  const cfg = getConfig();
  const relatedRuleTelemetry = createRelatedRuleTelemetry(context.workspaceState);
  setRuleExplainTelemetry((event, props = {}) => {
    if (event === 'open') {
      relatedRuleTelemetry.track('ruleExplain.open', props);
      return;
    }
    if (event === 'relatedClick') {
      relatedRuleTelemetry.track('ruleExplain.relatedClick', props);
      return;
    }
    relatedRuleTelemetry.track('ruleExplain.docClick', props);
  });

  let enabled = cfg.get<boolean>('enabled', true) ?? true;

  // Auto-enable when saropa_lints is already in pubspec.yaml but the user
  // has not explicitly set `saropaLints.enabled`, so existing adopters are not
  // left with integration inactive — no files are touched; we flip the workspace flag.
  if (!enabled && isDartProject) {
    const inspection = cfg.inspect<boolean>('enabled');
    const explicitlySet = inspection?.workspaceValue !== undefined
      || inspection?.workspaceFolderValue !== undefined;
    if (!explicitlySet && root && hasSaropaLintsDep(root)) {
      enabled = true;
      // Fire-and-forget: persist so subsequent activations skip this check.
      void cfg.update('enabled', true, vscode.ConfigurationTarget.Workspace);
    }
  }

  // Match disk-backed violation report so `saropaLints.hasViolations` is correct on first tick.
  updateContext(enabled, root ? hasViolations(root) : false);

  const todosAndHacksProvider = new TodosAndHacksTreeProvider();
  const driftAdvisorDiagCollection = vscode.languages.createDiagnosticCollection('Saropa Drift Advisor');
  context.subscriptions.push(driftAdvisorDiagCollection);
  const driftAdvisorProvider = new DriftAdvisorTreeProvider(driftAdvisorDiagCollection);

  // Pubspec validation: inline diagnostics for dependency ordering,
  // version syntax, and constraint issues on pubspec.yaml.
  // Listeners are registered centrally in extension-activation.ts to
  // share a single pubspec.yaml watcher with SDK diagnostics.
  const pubspecValidator = createPubspecValidation(context);

  // Quick-fix code actions for pubspec validation diagnostics
  // (caret/pin syntax, publish_to, blank lines, resolution workspace)
  context.subscriptions.push(
    vscode.languages.registerCodeActionsProvider(
      { language: 'yaml', pattern: '**/pubspec.yaml' },
      new PubspecCodeActionProvider(),
      { providedCodeActionKinds: [vscode.CodeActionKind.QuickFix] },
    ),
  );

  const issuesProvider = new IssuesTreeProvider(context.workspaceState);
  const findingsStatusBarItem = vscode.window.createStatusBarItem(vscode.StatusBarAlignment.Right, 99);
  findingsStatusBarItem.name = 'Saropa Findings';
  context.subscriptions.push(findingsStatusBarItem);
  const hotspotReviewState = new SecurityHotspotReviewStateService(context.workspaceState);
  const summaryProvider = new SummaryTreeProvider(context.workspaceState);
  const suppressionsProvider = new SuppressionsTreeProvider();
  const configProvider = new ConfigTreeProvider();
  // Sectioned sidebar: each VS Code view (Banner / Editor dashboards / Actions /
  // Status / Settings / Triage / Help) is its own collapsible panel. Items
  // inside each panel are flat leaves only — the panel title bar is the
  // only collapse handle, no chevrons appear next to rows.
  const sectionProviders = createSidebarSectionProviders(context.workspaceState, configProvider);
  const refreshAllSections = (): void => {
    for (const p of sectionProviders) p.refresh();
    updateSidebarSectionContext(context.workspaceState);
  };
  for (const provider of sectionProviders) {
    context.subscriptions.push(
      vscode.window.registerTreeDataProvider(provider.viewId, provider),
    );
  }
  updateSidebarSectionContext(context.workspaceState);

  const suggestionsProvider = new SuggestionsTreeProvider();
  const securityProvider = new SecurityPostureTreeProvider();
  const fileRiskProvider = new FileRiskTreeProvider(context.workspaceState);

  context.subscriptions.push(
    vscode.workspace.onDidChangeConfiguration((e) => {
      if (
        SIDEBAR_SECTION_CONFIG_KEYS.some((rel) =>
          e.affectsConfiguration(sidebarSectionContextKey(rel)),
        )
      ) {
        refreshAllSections();
      }
      if (e.affectsConfiguration('saropaLints.enabled') || e.affectsConfiguration('saropaLints.tier')) {
        refreshAllSections();
      }
    }),
  );

  context.subscriptions.push(
    todosAndHacksProvider.onDidChangeTreeData(() => {
      refreshAllSections();
    }),
    driftAdvisorProvider.onDidChangeTreeData(() => {
      refreshAllSections();
    }),
  );

  const rulePacksWebviewProvider = new RulePacksWebviewProvider(context.extensionUri);

  registerCrossFileCommands(context);
  let driftAdvisorRefreshInProgress = false;

  let todosAndHacksSaveDebounce: ReturnType<typeof setTimeout> | undefined;
  context.subscriptions.push(
    vscode.workspace.onDidSaveTextDocument((doc) => {
      const base = doc.uri.fsPath.replaceAll('\\', '/');
      if (base.endsWith('/analysis_options.yaml') || base.endsWith('/analysis_options_custom.yaml')) {
        // Invalidate the disabled-rules cache so tree views pick up
        // rule enable/disable changes on the next refresh.
        invalidateDisabledRulesCache();
        if (base.endsWith('/analysis_options.yaml')) {
          rulePacksWebviewProvider.refresh();
        }
      }
      const cfg = vscode.workspace.getConfiguration('saropaLints.todosAndHacks');
      if (!cfg.get<boolean>('workspaceScanEnabled', false)) return;
      if (!cfg.get<boolean>('autoRefresh', true)) return;
      const folder = vscode.workspace.getWorkspaceFolder(doc.uri);
      if (!folder) return;
      if (todosAndHacksSaveDebounce) clearTimeout(todosAndHacksSaveDebounce);
      todosAndHacksSaveDebounce = setTimeout(() => {
        todosAndHacksSaveDebounce = undefined;
        todosAndHacksProvider.refresh();
      }, 600);
    }),
  );

  function updateIssuesViewMessage(): void {
    const state = issuesProvider.getFilterState();
    const focused = issuesProvider.getFocusedFile();
    void vscode.commands.executeCommand('setContext', 'saropaLints.hasIssuesFilter', state.hasActiveFilters);
    void vscode.commands.executeCommand('setContext', 'saropaLints.hasSuppressions', state.hasSuppressions);
    void vscode.commands.executeCommand('setContext', 'saropaLints.hasFocusedFile', focused !== undefined);
    updateFindingsStatusBar(findingsStatusBarItem, isDartProject);
    const filterHint = focused
      ? `List: focused on ${focused.split('/').pop() ?? focused} (${state.filteredCount}/${state.totalUnfiltered})`
      : state.hasActiveFilters || state.hasSuppressions
        ? `List: filtered ${state.filteredCount}/${state.totalUnfiltered}`
        : `List: ${state.filteredCount} visible (of ${state.totalUnfiltered})`;
    if (findingsStatusBarItem.tooltip) {
      findingsStatusBarItem.tooltip = `${findingsStatusBarItem.tooltip}\n${filterHint}`;
    }
  }
  updateIssuesViewMessage();

  context.subscriptions.push(
    issuesProvider.onDidChangeTreeData(() => {
      refreshFindingsDashboardIfOpen(context);
      updateIssuesViewMessage();
    }),
  );

  registerIssueCommands(issuesProvider, context);
  registerCodeLensProvider(context);
  registerInlineAnnotations(context);

  context.subscriptions.push({
    dispose: () => {
      if (todosAndHacksSaveDebounce) clearTimeout(todosAndHacksSaveDebounce);
    },
  });

  const refreshAll = () => {
    const root = getProjectRoot();
    syncRuleMetadataFromViolations(root ? readViolations(root) : null);
    issuesProvider.refresh();
    refreshAllSections();
    summaryProvider.refresh();
    suppressionsProvider.refresh();
    configProvider.refresh();
    suggestionsProvider.refresh();
    securityProvider.refresh();
    fileRiskProvider.refresh();
    rulePacksWebviewProvider.refresh();
    invalidateCodeLenses();
    updateIssuesViewMessage();
    // D3: Invalidate cache then refresh inline annotations for new data.
    invalidateAnnotationCache();
    updateAnnotationsForAllEditors();
  };

  void vscode.commands.executeCommand('setContext', 'saropaLints.driftAdvisor.connected', false);
  // Sync integration toggle button state on startup so toolbar shows correct icon immediately.
  void vscode.commands.executeCommand('setContext', 'saropaLints.driftAdvisor.integration', vscode.workspace.getConfiguration('saropaLints.driftAdvisor').get<boolean>('integration', false));

  let driftAdvisorPollTimer: ReturnType<typeof setInterval> | undefined;
  function scheduleDriftAdvisorPoll(): void {
    if (driftAdvisorPollTimer) {
      clearInterval(driftAdvisorPollTimer);
      driftAdvisorPollTimer = undefined;
    }
    const cfg = vscode.workspace.getConfiguration('saropaLints.driftAdvisor');
    if (!cfg.get<boolean>('integration', false)) return;
    const ms = cfg.get<number>('pollIntervalMs', 30000);
    if (ms <= 0) return;
    driftAdvisorPollTimer = setInterval(() => {
      void vscode.commands.executeCommand('saropaLints.driftAdvisor.refresh');
    }, ms);
  }
  scheduleDriftAdvisorPoll();
  if (vscode.workspace.getConfiguration('saropaLints.driftAdvisor').get<boolean>('integration', false)) {
    void vscode.commands.executeCommand('saropaLints.driftAdvisor.refresh');
  }
  // Poll dispose + workspace listeners registered together (one subscription batch).
  context.subscriptions.push(
    {
      dispose: () => {
        if (driftAdvisorPollTimer) clearInterval(driftAdvisorPollTimer);
      },
    },
    vscode.workspace.onDidChangeConfiguration((e) => {
      if (!e.affectsConfiguration('saropaLints')) return;
      if (e.affectsConfiguration('saropaLints.violationsGroupBy')) {
        issuesProvider.setGroupBy(parseViolationsGroupBy(vscode.workspace.getConfiguration('saropaLints')));
      }
      const c = getConfig();
      const en = c.get<boolean>('enabled', true) ?? true;
      updateContext(en, issuesProvider.hasViolations());
      refreshAll();
      if (e.affectsConfiguration('saropaLints.todosAndHacks')) {
        todosAndHacksProvider.refresh();
      }
      // Status bars must update when config changes (e.g. tier changed via Settings UI).
      updateAllStatusBars();
      if (e.affectsConfiguration('saropaLints.driftAdvisor')) {
        // Keep toolbar toggle icon in sync when setting changes via Settings UI.
        void vscode.commands.executeCommand('setContext', 'saropaLints.driftAdvisor.integration', vscode.workspace.getConfiguration('saropaLints.driftAdvisor').get<boolean>('integration', false));
        void vscode.commands.executeCommand('saropaLints.driftAdvisor.refresh');
        scheduleDriftAdvisorPoll();
      }
    }),
    vscode.workspace.onDidChangeWorkspaceFolders(() => {
      invalidateProjectRoot();
      refreshAll();
    }),
  );

  const violationsPath = (): string | null => {
    const root = getProjectRoot();
    return root ? path.join(root, 'reports', '.saropa_lints', 'violations.json') : null;
  };
  // Debounce refresh when violations.json changes to avoid rapid successive updates.
  let refreshDebounceTimer: ReturnType<typeof setTimeout> | undefined;
  const debouncedRefresh = () => {
    if (refreshDebounceTimer) clearTimeout(refreshDebounceTimer);
    refreshDebounceTimer = setTimeout(() => {
      refreshDebounceTimer = undefined;
      // W5/W6/H1: Record snapshot BEFORE refreshing views so tree providers
      // see the updated history (avoids stale findPreviousScore reads).
      const root = getProjectRoot();
      if (root) {
        const data = readViolations(root);
        if (data) {
          syncRuleMetadataFromViolations(data);
          const { history, appended } = appendSnapshot(context.workspaceState, data);
          refreshAll();
          updateAllStatusBars(data);
          updateContext(getConfig().get<boolean>('enabled', true) ?? true, issuesProvider.hasViolations());
          runCelebrationIfNeeded(root, history, appended);
          return;
        }
      }
      // Fallback: no root or no data — still refresh views.
      syncRuleMetadataFromViolations(null);
      refreshAll();
    }, 300);
  };
  context.subscriptions.push({
    dispose: () => {
      if (refreshDebounceTimer) clearTimeout(refreshDebounceTimer);
    },
  });
  const watchViolations = () => {
    const p = violationsPath();
    if (!p) return;
    const watcher = vscode.workspace.createFileSystemWatcher(p);
    watcher.onDidChange(debouncedRefresh);
    watcher.onDidCreate(debouncedRefresh);
    context.subscriptions.push(watcher);
  };
  watchViolations();
  syncRuleMetadataFromViolations(root ? readViolations(root) : null);

  const extVersion = (context.extension.packageJSON as { version: string }).version;

  const statusBarItem = vscode.window.createStatusBarItem(vscode.StatusBarAlignment.Right, 100);
  context.subscriptions.push(statusBarItem);

  // Vibrancy data pushed from the vibrancy subsystem via callback.
  let vibrancyData: VibrancyStatusData | null = null;

  /** Theme color for status bar by score band (red / yellow / none). */
  function statusBarBackgroundForScore(score: number): vscode.ThemeColor | undefined {
    const band = scoreColorBand(score);
    if (band === 'red') return new vscode.ThemeColor('statusBarItem.errorBackground');
    if (band === 'yellow') return new vscode.ThemeColor('statusBarItem.warningBackground');
    return undefined;
  }

  /** Build tooltip lines for the status bar (version, tier, score, vibrancy details). */
  function buildStatusBarTooltipLines(
    tier: string,
    health: { score: number } | null,
    showVibrancy: boolean,
    vibrancyLabel: string | null,
  ): string[] {
    const base = [`Saropa Lints v${extVersion}`, `Tier: ${tier}`];
    if (health) base.push(`Lint score: ${health.score}%`);
    if (showVibrancy && vibrancyData !== null) {
      base.push(`Vibrancy: ${vibrancyLabel}`, `${vibrancyData.packageCount} packages scanned`);
      if (vibrancyData.updateCount > 0) base.push(`${vibrancyData.updateCount} update(s) available`);
      if (vibrancyData.actionCount > 0) base.push(`${vibrancyData.actionCount} action item(s)`);
    }
    return base;
  }

  // Single unified status bar item showing lint score, tier, and vibrancy.
  // Accepts optional pre-loaded data to avoid re-reading violations.json from disk
  // when the caller already has it (e.g. debouncedRefresh).
  const updateAllStatusBars = (preloadedData?: ViolationsData) => {
    if (!isDartProject) {
      // Surface the version even outside a Dart workspace so users can verify
      // that a fresh build has loaded — previously the bar was hidden here and
      // the only version readout was a tooltip on a tree that itself required
      // a Dart project to render. That made "is my build live?" unanswerable
      // before opening a project.
      statusBarItem.text = `$(checklist) Saropa Lints v${extVersion}`;
      statusBarItem.tooltip = `Saropa Lints v${extVersion} — open a folder containing pubspec.yaml to enable analysis.`;
      statusBarItem.backgroundColor = undefined;
      statusBarItem.command = 'saropaLints.showAbout';
      statusBarItem.show();
      return;
    }
    const en = getConfig().get<boolean>('enabled', true) ?? true;
    const tier = getConfig().get<string>('tier', 'recommended') ?? 'recommended';
    const showVibrancy =
      vscode.workspace.getConfiguration('saropaLints.packageVibrancy').get<boolean>('showInStatusBar', true) &&
      vibrancyData !== null;
    const vibrancyLabel = showVibrancy ? `${Math.round(vibrancyData!.averageScore / 10)}/10` : null;

    if (en) {
      const root = getProjectRoot();
      const data = preloadedData ?? (root ? readViolations(root) : null);
      const health = data ? computeHealthScore(data) : null;
      if (health) {
        const history = loadHistory(context.workspaceState);
        const prevScore = findPreviousScore(history);
        const delta = prevScore === undefined ? '' : ` ${formatScoreDelta(health.score, prevScore)}`;
        const detailLabel = buildStatusBarLabel({
          hasHealth: true,
          healthScore: health.score,
          delta,
          tier,
          showVibrancy,
          vibrancyLabel,
        });
        statusBarItem.text = `$(checklist) Saropa: ${detailLabel}`;
        statusBarItem.backgroundColor = statusBarBackgroundForScore(health.score);
      } else {
        statusBarItem.text = `$(checklist) ${buildStatusBarLabel({
          hasHealth: false,
          tier,
          showVibrancy,
          vibrancyLabel,
        })}`;
        statusBarItem.backgroundColor = undefined;
      }
      statusBarItem.tooltip = buildStatusBarTooltipLines(tier, health, showVibrancy, vibrancyLabel).join('\n');
    } else {
      statusBarItem.text = '$(checklist) Saropa Lints: Off';
      statusBarItem.tooltip = `Saropa Lints v${extVersion} — Disabled`;
      statusBarItem.backgroundColor = undefined;
    }
    statusBarItem.command = 'saropaLints.editorDashboards.focus';
    statusBarItem.show();
  };
  updateAllStatusBars();

  context.subscriptions.push(
    vscode.commands.registerCommand('saropaLints.enable', async () => {
      const success = await runEnable(context);
      if (!success) return;

      await cfg.update('enabled', true, vscode.ConfigurationTarget.Workspace);
      updateContext(true, issuesProvider.hasViolations());

      // I5: Record snapshot before refreshing views so Overview sees fresh history.
      const root = getProjectRoot();
      const data = root ? readViolations(root) : null;
      if (data) {
        appendSnapshot(context.workspaceState, data);
      }

      refreshAll();
      updateAllStatusBars(data ?? undefined);

      // I5: Auto-focus Overview to show Health Score immediately.
      await vscode.commands.executeCommand('saropaLints.editorDashboards.focus');

      // I5: Show score-aware notification with actionable buttons.
      const health = data ? computeHealthScore(data) : null;
      const totalViolations = data?.summary?.totalViolations ?? data?.violations?.length ?? 0;

      // Report: log enable result with score.
      if (root) {
        logSection('Enable Result');
        if (health) {
          logReport(`- Score: ${health.score}%`);
        }
        logReport(`- Violations: ${totalViolations}`);
        flushReport(root);
      }

      // Plugin liveness probe: detect the "analyzer launched the plugin but
      // zero diagnostics flow" failure mode. Before the fix for the
      // `Directory.current` bug (config_loader reading config relative to
      // the wrong cwd), this was the default experience for any consumer
      // who opened VS Code via the file picker rather than `code .` from
      // the project folder — the plugin registered no rules and silently
      // produced no warnings. The probe reads violations.json (written by
      // the plugin itself) and surfaces a specific, actionable warning if
      // the plugin wrote no report, loaded zero rules, or analyzed zero
      // files. Skipped silently when the plugin is alive.
      if (root) {
        const liveness = verifyPluginLiveness(root);
        logReport(`- Liveness: ${liveness.status}`);
        logReport(`- Enabled rules: ${liveness.enabledRuleCount}`);
        logReport(`- Files analyzed: ${liveness.filesAnalyzed}`);
        flushReport(root);
        await surfaceLivenessResult(liveness, getSharedOutputChannel());
      }

      await showFirstRunNotification(health, totalViolations);
    }),
    vscode.commands.registerCommand('saropaLints.disable', async () => {
      await runDisable();
      await cfg.update('enabled', false, vscode.ConfigurationTarget.Workspace);
      updateContext(false, false);
      refreshAll();
      updateAllStatusBars();
    }),
    // Standalone liveness check. Users hit this from the command palette when
    // they suspect saropa_lints is silent (Problems pane empty even though
    // the plugin is declared in analysis_options.yaml). The probe returns
    // an explicit status — `alive`, `no-report`, `config-not-loaded`, or
    // `no-files-analyzed` — and surfaces a warning with the recovery step
    // when the plugin is mis-wired. When alive, the command shows a brief
    // confirmation (because the user explicitly asked) with the enabled
    // rule count, so they can see the plugin is doing its job.
    vscode.commands.registerCommand('saropaLints.verifyPlugin', async () => {
      const root = getProjectRoot();
      if (!root) {
        await vscode.window.showErrorMessage(
          'Saropa Lints: no workspace folder is open. Open your Dart/Flutter project first.',
        );
        return;
      }
      const liveness = verifyPluginLiveness(root);
      if (liveness.status === 'alive') {
        await vscode.window.showInformationMessage(
          `Saropa Lints is alive: ${liveness.enabledRuleCount} rules enabled, ` +
          `${liveness.filesAnalyzed} files analyzed.`,
        );
        return;
      }
      await surfaceLivenessResult(liveness, getSharedOutputChannel());
    }),
    vscode.commands.registerCommand('saropaLints.runAnalysis', async () => {
      const ok = await runAnalysisCommand(context);
      if (ok) {
        refreshAll();
        updateAllStatusBars();
        updateContext(getConfig().get<boolean>('enabled', true) ?? true, issuesProvider.hasViolations());
        // C7: Focus Overview after analysis to show Health Score delta.
        await vscode.commands.executeCommand('saropaLints.editorDashboards.focus');
        // C7: Include score in completion message when available.
        const root = getProjectRoot();
        const postData = root ? readViolations(root) : null;
        const health = postData ? computeHealthScore(postData) : null;
        const scoreMsg = health ? ` Score: ${health.score}` : '';
        vscode.window.setStatusBarMessage(`Saropa Lints: Analysis complete.${scoreMsg}`, 4000);
      }
    }),
    vscode.commands.registerCommand('saropaLints.initializeConfig', async () => {
      const success = await runInitializeConfig(context);
      if (success) {
        // C6: Auto-run analysis after config change if setting is on.
        const runAfter = getConfig().get<boolean>('runAnalysisAfterConfigChange', true) ?? true;
        if (runAfter) {
          await runAnalysisCommand(context);
        }
        refreshAll();
        updateAllStatusBars();
        updateContext(getConfig().get<boolean>('enabled', true) ?? true, issuesProvider.hasViolations());
      }
    }),
    vscode.commands.registerCommand('saropaLints.emitCompositePluginScaffold', async () => {
      await runEmitCompositePluginScaffold();
    }),
    vscode.commands.registerCommand('saropaLints.openConfig', openConfig),
    // Open pubspec.yaml — paired with the sidebar "Detected" row so a click on
    // that row takes the user to the file whose contents it summarizes.
    // Same multi-root guard as openConfig: never default to workspaceFolders[0].
    vscode.commands.registerCommand('saropaLints.openPubspec', async () => {
      const folder = await pickWorkspaceFolder({
        placeHolder: 'Choose the project whose pubspec.yaml to open',
      });
      if (!folder) return;
      const uri = vscode.Uri.file(path.join(folder.uri.fsPath, 'pubspec.yaml'));
      try {
        const doc = await vscode.workspace.openTextDocument(uri);
        await vscode.window.showTextDocument(doc);
      } catch (e) {
        const msg = e instanceof Error ? e.message : String(e);
        void vscode.window.showErrorMessage(`Failed to open pubspec.yaml: ${msg}`);
      }
    }),
    // One-click toggle for the "Run analysis after config change" sidebar row.
    // Writing the boolean directly avoids dragging the user into the Settings
    // UI just to flip a checkbox; the row label updates on the next refresh.
    vscode.commands.registerCommand('saropaLints.toggleRunAnalysisAfterConfigChange', async () => {
      const cfg = vscode.workspace.getConfiguration('saropaLints');
      const cur = cfg.get<boolean>('runAnalysisAfterConfigChange', true) ?? true;
      const target = vscode.workspace.workspaceFolders?.length
        ? vscode.ConfigurationTarget.Workspace
        : vscode.ConfigurationTarget.Global;
      await cfg.update('runAnalysisAfterConfigChange', !cur, target);
      refreshAllSections();
    }),
    vscode.commands.registerCommand('saropaLints.toggleSidebarSection', async (key: unknown) => {
      if (typeof key !== 'string') {
        // Command was invoked without a valid section key (e.g. from the
        // command palette where no argument is passed).  Nothing to toggle.
        return;
      }
      try {
        const cfg = vscode.workspace.getConfiguration('saropaLints');
        const def = defaultSidebarSectionVisible(key);
        const cur = cfg.get<boolean>(key, def) ?? def;
        const next = !cur;
        const target = vscode.workspace.workspaceFolders?.length
          ? vscode.ConfigurationTarget.Workspace
          : vscode.ConfigurationTarget.Global;
        await cfg.update(key, next, target);
        updateSidebarSectionVisibility();
        refreshAllSections();
      } catch (err) {
        // Surface config-update failures so the user sees feedback.
        const msg = err instanceof Error ? err.message : String(err);
        console.error(`toggleSidebarSection error for "${key}": ${msg}`);
        void vscode.window.showErrorMessage(
          `Saropa Lints: failed to toggle sidebar section — ${msg}`,
        );
      }
    }),
    vscode.commands.registerCommand('saropaLints.openRulePacks', () => {
      rulePacksWebviewProvider.openEditorPanel();
    }),
    vscode.commands.registerCommand('saropaLints.openConfigDashboard', () => {
      rulePacksWebviewProvider.openEditorPanel();
    }),
    vscode.commands.registerCommand('saropaLints.openPackageVibrancy', async () => {
      await vscode.commands.executeCommand('saropaLints.packageVibrancy.showReport');
      if (getLatestResults().length === 0) {
        await vscode.commands.executeCommand('saropaLints.packageVibrancy.scan');
      }
    }),
    vscode.commands.registerCommand('saropaLints.openViolationsWideReport', async () => {
      await openViolationsWideReport(context);
    }),
    vscode.commands.registerCommand('saropaLints.revealFindingsDashboard', async () => {
      await openViolationsWideReport(context);
    }),
    vscode.commands.registerCommand('saropaLints.openProjectVibrancyReport', async () => {
      await openProjectVibrancyReport();
    }),
    vscode.commands.registerCommand('saropaLints.openProjectVibrancySettings', async () => {
      await vscode.commands.executeCommand('workbench.action.openSettings', 'saropaLints.projectVibrancy');
    }),
    vscode.commands.registerCommand('saropaLints.openWalkthrough', () => {
      void vscode.commands.executeCommand(
        'workbench.action.openWalkthrough',
        'saropa.saropa-lints#saropaLints.gettingStarted',
        false,
      );
    }),
    vscode.commands.registerCommand('saropaLints.openHelpHub', () => {
      void showHelpHubQuickPick();
    }),
    vscode.commands.registerCommand('saropaLints.showAbout', () => {
      showAboutPanel(context.extensionUri, extVersion);
    }),
    vscode.commands.registerCommand('saropaLints.showCommandCatalog', () => {
      showCommandCatalogPanel(context);
    }),
    vscode.commands.registerCommand('saropaLints.openPubDevSaropaLints', () => {
      void vscode.env.openExternal(vscode.Uri.parse('https://pub.dev/packages/saropa_lints'));
    }),
    // Creates .cursor/rules/saropa_lints_instructions.mdc from bundled template for AI agent guidelines.
    vscode.commands.registerCommand('saropaLints.createSaropaInstructions', async () => {
      // Multi-root bug: previously hard-coded `workspaceFolders?.[0]`, which
      // wrote into whichever folder happened to be first in the workspace
      // (e.g. saropa_drift_advisor) rather than the project the user was
      // actually working on. Pick the active editor's folder when available;
      // otherwise prompt so the user controls the destination explicitly.
      const folder = await pickWorkspaceFolder({
        placeHolder: 'Choose the project that should receive the Saropa Lints AI agent instructions',
      });
      if (!folder) {
        void vscode.window.showErrorMessage('Open a workspace folder first.');
        return;
      }
      const rulesDir = path.join(folder.uri.fsPath, '.cursor', 'rules');
      const destPath = path.join(rulesDir, 'saropa_lints_instructions.mdc');
      const templatePath = path.join(context.extensionUri.fsPath, 'media', 'saropa_lints_instructions.mdc');
      try {
        await vscode.window.withProgress(
          {
            location: vscode.ProgressLocation.Notification,
            title: 'Creating Saropa Lints instructions…',
            cancellable: false,
          },
          async () => {
            await fs.promises.mkdir(rulesDir, { recursive: true });
            await fs.promises.copyFile(templatePath, destPath);
          },
        );
        void vscode.window.showInformationMessage(
          'Created .cursor/rules/saropa_lints_instructions.mdc for AI agents.',
        );
        const doc = await vscode.workspace.openTextDocument(destPath);
        void vscode.window.showTextDocument(doc);
      } catch (e) {
        const msg = e instanceof Error ? e.message : String(e);
        void vscode.window.showErrorMessage(`Failed to create Saropa Lints instructions: ${msg}`);
      }
    }),
    vscode.commands.registerCommand('saropaLints.focusView', async () => {
      // After consolidating Dashboards + Overview into a single flat view,
      // `focusView` is a backwards-compat alias for revealing the unified sidebar.
      await vscode.commands.executeCommand('saropaLints.editorDashboards.focus');
    }),
    vscode.commands.registerCommand('saropaLints.focusPackageVibrancyPackages', async () => {
      await vscode.commands.executeCommand('saropaLints.packageVibrancy.showReport');
    }),
    // Show all findings: clear filters and focus Violations view (e.g. from Summary "Total violations").
    vscode.commands.registerCommand('saropaLints.focusIssues', () => {
      issuesProvider.clearFilters();
      updateIssuesViewMessage();
      issuesProvider.expandAll();
      void vscode.commands.executeCommand('saropaLints.revealFindingsDashboard');
    }),
    // Focus Violations view filtered to a single file (Code Lens, Problems view "Show in Saropa Lints").
    vscode.commands.registerCommand('saropaLints.focusIssuesForFile', (filePath: string) => {
      const normalized = typeof filePath === 'string' ? filePath.replaceAll('\\', '/') : '';
      if (!normalized) return;
      issuesProvider.setTextFilter(normalized);
      updateIssuesViewMessage();
      issuesProvider.expandAll();
      void vscode.commands.executeCommand('saropaLints.revealFindingsDashboard');
    }),
    // Open file in editor AND filter Violations view (File Risk tree click).
    vscode.commands.registerCommand('saropaLints.openFileAndFocusIssues', (filePath: string) => {
      const normalized = typeof filePath === 'string' ? filePath.replaceAll('\\', '/') : '';
      if (!normalized) return;
      // Open the file in the editor so the user can see the source.
      const root = getProjectRoot();
      if (root) {
        const absPath = path.resolve(root, normalized);
        void vscode.window.showTextDocument(vscode.Uri.file(absPath), { preview: true });
      }
      // Also filter the Violations view to this file.
      issuesProvider.setTextFilter(normalized);
      updateIssuesViewMessage();
      issuesProvider.expandAll();
    }),
    // Focus Violations view filtered to the active editor's file (e.g. from Problems view context menu).
    vscode.commands.registerCommand('saropaLints.focusIssuesForActiveFile', () => {
      const root = getProjectRoot();
      const editor = vscode.window.activeTextEditor;
      if (!root || !editor?.document?.uri) {
        void vscode.window.showInformationMessage('Open a file to show its issues in Saropa Lints.');
        return;
      }
      const relative = path.relative(root, editor.document.uri.fsPath).replaceAll('\\', '/');
      // Reuse text filter path matching instead of adding a second "file-only"
      // code path inside IssuesTreeProvider.
      issuesProvider.setTextFilter(relative);
      updateIssuesViewMessage();
      issuesProvider.expandAll();
      void vscode.commands.executeCommand('saropaLints.revealFindingsDashboard');
    }),
    vscode.commands.registerCommand('saropaLints.focusIssuesWithImpactFilter', (impact: string) => {
      if (impact && typeof impact === 'string') {
        issuesProvider.setImpactFilter(new Set([impact]));
        issuesProvider.setSeverityFilter(new Set(['error', 'warning', 'info']));
        updateIssuesViewMessage();
        issuesProvider.expandAll();
        void vscode.commands.executeCommand('saropaLints.revealFindingsDashboard');
      }
    }),
    vscode.commands.registerCommand('saropaLints.focusIssuesWithSeverityFilter', (severity: string) => {
      if (severity && typeof severity === 'string') {
        issuesProvider.setSeverityFilter(new Set([severity]));
        issuesProvider.setImpactFilter(new Set(['critical', 'high', 'medium', 'low', 'opinionated']));
        updateIssuesViewMessage();
        issuesProvider.expandAll();
        void vscode.commands.executeCommand('saropaLints.revealFindingsDashboard');
      }
    }),
    vscode.commands.registerCommand('saropaLints.refresh', () => {
      refreshAll();
      updateAllStatusBars();
      updateContext(getConfig().get<boolean>('enabled', true) ?? true, issuesProvider.hasViolations());
    }),
    vscode.commands.registerCommand('saropaLints.todosAndHacks.refresh', () => {
      const tcfg = vscode.workspace.getConfiguration('saropaLints.todosAndHacks');
      if (tcfg.get<boolean>('workspaceScanEnabled', false)) {
        void vscode.window.setStatusBarMessage('Saropa TODOs & Hacks: scanning…', 4000);
      }
      todosAndHacksProvider.refresh();
      void vscode.commands.executeCommand('saropaLints.revealFindingsDashboard');
    }),
    vscode.commands.registerCommand('saropaLints.todosAndHacks.toggleGroupByTag', async () => {
      const cfg = vscode.workspace.getConfiguration('saropaLints.todosAndHacks');
      const scanOn = cfg.get<boolean>('workspaceScanEnabled', false);
      const current = cfg.get<boolean>('groupByTag', false);
      await cfg.update('groupByTag', !current, vscode.ConfigurationTarget.Workspace);
      if (scanOn) {
        void vscode.window.setStatusBarMessage('Saropa TODOs & Hacks: scanning…', 4000);
      }
      todosAndHacksProvider.refresh();
      void vscode.commands.executeCommand('saropaLints.revealFindingsDashboard');
    }),
    vscode.commands.registerCommand('saropaLints.todosAndHacks.enableWorkspaceScan', async () => {
      const tcfg = vscode.workspace.getConfiguration('saropaLints.todosAndHacks');
      await tcfg.update('workspaceScanEnabled', true, vscode.ConfigurationTarget.Workspace);
      todosAndHacksProvider.refresh();
      void vscode.commands.executeCommand('saropaLints.revealFindingsDashboard');
    }),
    vscode.commands.registerCommand('saropaLints.driftAdvisor.refresh', async () => {
      const cfg = vscode.workspace.getConfiguration('saropaLints.driftAdvisor');
      if (!cfg.get<boolean>('integration', false)) {
        driftAdvisorProvider.setState(null, []);
        await onDriftAdvisorDisconnected(context.workspaceState);
        void vscode.commands.executeCommand('setContext', 'saropaLints.driftAdvisor.connected', false);
        refreshAllSections();
        return;
      }
      if (driftAdvisorRefreshInProgress) return;
      driftAdvisorRefreshInProgress = true;
      void vscode.window.setStatusBarMessage('Saropa Drift Advisor: discovering server…', 4000);
      driftAdvisorProvider.setLoading(true);
      const portRange = cfg.get<number[]>('portRange', [8642, 8649]);
      const portMin = Array.isArray(portRange) && portRange.length >= 1 ? Math.max(1, portRange[0]) : 8642;
      const portMax = Array.isArray(portRange) && portRange.length >= 2 ? Math.min(65535, portRange[1]) : 8649;
      try {
        const server = await discoverServer(portMin, portMax);
        if (!server) {
          driftAdvisorProvider.setState(null, []);
          await onDriftAdvisorDisconnected(context.workspaceState);
          void vscode.commands.executeCommand('setContext', 'saropaLints.driftAdvisor.connected', false);
          void vscode.window.setStatusBarMessage('Saropa Drift Advisor: no server found', 5000);
          return;
        }
        const issues = await fetchIssues(server);
        const mapped = await mapIssuesToLocations(issues);
        driftAdvisorProvider.setState(server, mapped);
        setDriftAdvisorServerConnected(true);
        void vscode.commands.executeCommand('setContext', 'saropaLints.driftAdvisor.connected', true);
        void vscode.window.setStatusBarMessage('Saropa Drift Advisor: connected', 3000);
      } catch {
        driftAdvisorProvider.setState(null, []);
        await onDriftAdvisorDisconnected(context.workspaceState);
        void vscode.commands.executeCommand('setContext', 'saropaLints.driftAdvisor.connected', false);
        void vscode.window.setStatusBarMessage('Saropa Drift Advisor: error fetching issues', 5000);
      } finally {
        driftAdvisorRefreshInProgress = false;
        refreshAllSections();
      }
    }),
    vscode.commands.registerCommand('saropaLints.driftAdvisor.openInBrowser', () => {
      const server = driftAdvisorProvider.getServer();
      if (server?.baseUrl) {
        void vscode.env.openExternal(vscode.Uri.parse(server.baseUrl));
      } else {
        void vscode.window.showInformationMessage('Drift Advisor is not connected. Click Refresh after starting the server.');
      }
    }),
    vscode.commands.registerCommand('saropaLints.driftAdvisor.enableIntegration', async () => {
      await vscode.workspace.getConfiguration('saropaLints.driftAdvisor').update('integration', true, vscode.ConfigurationTarget.Global);
      // Update context immediately so the toolbar icon flips without waiting for the config-change event.
      void vscode.commands.executeCommand('setContext', 'saropaLints.driftAdvisor.integration', true);
    }),
    vscode.commands.registerCommand('saropaLints.driftAdvisor.disableIntegration', async () => {
      await vscode.workspace.getConfiguration('saropaLints.driftAdvisor').update('integration', false, vscode.ConfigurationTarget.Global);
      // Update context immediately so the toolbar icon flips without waiting for the config-change event.
      void vscode.commands.executeCommand('setContext', 'saropaLints.driftAdvisor.integration', false);
    }),
    vscode.commands.registerCommand('saropaLints.repairConfig', async () => {
      const success = await runRepairConfig(context);
      if (success) refreshAll();
    }),
    vscode.commands.registerCommand('saropaLints.setTier', async () => {
      // Capture pre-tier violation count for delta display in the notification.
      const root = getProjectRoot();
      const preTierTotal = root ? (readViolations(root)?.summary?.totalViolations ?? 0) : 0;

      const result = await runSetTier(context);
      if (result) {
        // C6: setup.ts already runs analysis inside runSetTier when
        // runAnalysisAfterConfigChange is on; no duplicate call here.
        refreshAll();
        updateAllStatusBars();
        updateContext(getConfig().get<boolean>('enabled', true) ?? true, issuesProvider.hasViolations());

        // Smart tier transition: build notification info from post-tier data.
        // Note: postData may reflect a prior analysis if dart analyze has not yet
        // written violations.json — counts will update on the next file-watcher refresh.
        const postData = root ? readViolations(root) : null;
        const postTotal = postData?.summary?.totalViolations ?? postData?.violations.length ?? 0;
        const isUpgrade = TIER_ORDER.indexOf(result.tier) > TIER_ORDER.indexOf(result.previousTier);

        // Single pass to count critical+high violations (avoids 3 filter passes over 65k items).
        let critHigh = 0;
        for (const v of postData?.violations ?? []) {
          if (v.impact === 'critical' || v.impact === 'high') critHigh++;
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
    // D1/I1: Focus Violations view filtered to a set of rule names.
    // Shared helper — hides all rules EXCEPT the given set and resets orthogonal filters.
    ...['saropaLints.focusIssuesForOwasp', 'saropaLints.focusIssuesForRules'].map((cmdId) =>
      vscode.commands.registerCommand(cmdId, (arg: unknown) => {
        // Resolve rules: direct string[] (TreeItem click) or node (context menu).
        let rules: string[] | undefined;
        if (Array.isArray(arg)) {
          rules = arg;
        } else if (arg && typeof arg === 'object' && 'kind' in arg) {
          const node = arg as { kind: string; rules?: string[]; ruleName?: string };
          if (node.kind === 'triageGroup' && Array.isArray(node.rules)) {
            rules = node.rules;
          } else if (node.kind === 'triageRule' && typeof node.ruleName === 'string') {
            rules = [node.ruleName];
          }
        }
        if (!rules || rules.length === 0) return;
        const allRules = issuesProvider.getRuleNamesFromData();
        const keep = new Set(rules);
        const toHide = new Set(allRules.filter((r) => !keep.has(r)));
        issuesProvider.setTextFilter('');
        issuesProvider.setSeverityFilter(new Set(['error', 'warning', 'info']));
        issuesProvider.setImpactFilter(new Set(['critical', 'high', 'medium', 'low', 'opinionated']));
        issuesProvider.setRulesToHide(toHide);
        updateIssuesViewMessage();
        issuesProvider.expandAll();
        void vscode.commands.executeCommand('saropaLints.revealFindingsDashboard');
      }),
    ),
    // Summary metadata drill-down: filter Issues view by rules whose metadata
    // field matches the selected value (e.g. ruleType=vulnerability).
    vscode.commands.registerCommand(
      'saropaLints.focusIssuesByRuleMetadata',
      (field: 'ruleType' | 'ruleStatus', expectedValue: string) => {
        if (!field || !expectedValue) return;
        const root = getProjectRoot();
        if (!root) return;
        const data = readViolations(root);
        if (!data) return;

        const matchingRules = new Set<string>();
        const byRule = data.config?.ruleMetadataByRule ?? {};
        for (const [ruleName, metadata] of Object.entries(byRule)) {
          if (!metadata || typeof metadata !== 'object') continue;
          const candidate =
            field === 'ruleType' ? metadata.ruleType : metadata.ruleStatus;
          if (candidate === expectedValue) matchingRules.add(ruleName);
        }
        // Backfill from per-violation metadata for backward compatibility.
        for (const violation of data.violations) {
          const candidate =
            field === 'ruleType'
              ? violation.metadata?.ruleType
              : violation.metadata?.ruleStatus;
          if (candidate === expectedValue) matchingRules.add(violation.rule);
        }

        if (matchingRules.size === 0) return;
        const allRules = issuesProvider.getRuleNamesFromData();
        const toHide = new Set(allRules.filter((r) => !matchingRules.has(r)));
        issuesProvider.setTextFilter('');
        issuesProvider.setSeverityFilter(new Set(['error', 'warning', 'info']));
        issuesProvider.setImpactFilter(
          new Set(['critical', 'high', 'medium', 'low', 'opinionated']),
        );
        issuesProvider.setRulesToHide(toHide);
        updateIssuesViewMessage();
        issuesProvider.expandAll();
        void vscode.commands.executeCommand('saropaLints.revealFindingsDashboard');
      },
    ),
    vscode.commands.registerCommand('saropaLints.explainRule', (arg: unknown) => {
      if (typeof arg === 'string' && arg.trim().length > 0) {
        openRuleExplainPanel({ ruleName: arg.trim() });
        return;
      }
      const node = arg as IssueTreeNode | undefined;
      if (node?.kind === 'violation' && 'violation' in node) {
        openRuleExplainPanelForViolation(node.violation);
        return;
      }
      const root = getProjectRoot();
      if (!root) {
        void vscode.window.showInformationMessage('Open a workspace folder first.');
        return;
      }
      const data = readViolations(root);
      const violations = data?.violations ?? [];
      if (violations.length === 0) {
        void vscode.window.showInformationMessage('No violations in current data. Run analysis first.');
        return;
      }
      const ruleNames = [...new Set(violations.map((v) => v.rule))].sort((a, b) => a.localeCompare(b));
      void vscode.window.showQuickPick(ruleNames, {
        title: 'Explain rule',
        placeHolder: 'Select a rule to view details',
        matchOnDescription: true,
      }).then((selected) => {
        if (!selected) return;
        const first = violations.find((v) => v.rule === selected);
        if (first) openRuleExplainPanelForViolation(first);
        else openRuleExplainPanel({ ruleName: selected });
      });
    }),
    vscode.commands.registerCommand(
      'saropaLints.explainRuleFromSuggestion',
      (ruleName: unknown, sourceRule: unknown) => {
        if (typeof ruleName !== 'string' || ruleName.trim().length === 0) return;
        const normalizedRule = ruleName.trim();
        const source = typeof sourceRule === 'string' ? sourceRule.trim() : '';
        relatedRuleTelemetry.track('suggestions.relatedRuleOpen', {
          ruleName: normalizedRule,
          sourceRule: source,
        });
        openRuleExplainPanel({ ruleName: normalizedRule });
      },
    ),
    vscode.commands.registerCommand('saropaLints.showOutput', showOutputChannel),
    vscode.commands.registerCommand('saropaLints.showRelatedRuleTelemetry', () => {
      showRelatedRuleTelemetryPanel(relatedRuleTelemetry);
    }),
    vscode.commands.registerCommand('saropaLints.resetRelatedRuleTelemetry', () => {
      relatedRuleTelemetry.reset();
      void vscode.window.showInformationMessage(
        'Saropa Lints: related rule telemetry counters reset.',
      );
    }),
    // "Copy Latest Report" — grabs the newest `*_saropa_lint_report.log`
    // (the Dart plugin's consolidated analysis report with top rules,
    // concentration, and triage sections) and puts its full contents on
    // the clipboard. Lets users paste directly into a chat / issue /
    // email without navigating date folders. Chosen over exporting a
    // curated subset: the whole report is small enough (< 1 MB on the
    // real contacts project even with 14k issues), and users who pipe
    // into an LLM always want the full header + every section.
    vscode.commands.registerCommand('saropaLints.copyLatestReport', async () => {
      const root = getProjectRoot();
      if (!root) {
        vscode.window.showErrorMessage('No workspace folder open.');
        return;
      }
      const reportPath = findLatestAnalysisReport(root);
      if (!reportPath) {
        vscode.window.showWarningMessage(
          'Saropa Lints: no analysis report found under reports/. Run "Saropa Lints: Run Analysis" first.',
        );
        return;
      }
      try {
        const content = fs.readFileSync(reportPath, 'utf-8');
        await vscode.env.clipboard.writeText(content);
        // Show the resolved filename so users who have multiple runs in
        // flight can confirm which one landed on their clipboard.
        const name = path.basename(reportPath);
        void vscode.window.showInformationMessage(`Copied ${name} to clipboard.`);
      } catch (err) {
        const message = err instanceof Error ? err.message : String(err);
        void vscode.window.showErrorMessage(
          `Saropa Lints: failed to read report — ${message}`,
        );
      }
    }),
    // "Open Latest Report" — opens the newest `*_saropa_lint_report.log`
    // in an editor tab. Preview mode is off (preserveFocus: false, preview:
    // false) because users who explicitly asked to open the report want
    // a persistent tab, not a fleeting peek that gets replaced by the
    // next file they click.
    vscode.commands.registerCommand('saropaLints.openLatestReport', async () => {
      const root = getProjectRoot();
      if (!root) {
        vscode.window.showErrorMessage('No workspace folder open.');
        return;
      }
      const reportPath = findLatestAnalysisReport(root);
      if (!reportPath) {
        vscode.window.showWarningMessage(
          'Saropa Lints: no analysis report found under reports/. Run "Saropa Lints: Run Analysis" first.',
        );
        return;
      }
      try {
        const uri = vscode.Uri.file(reportPath);
        const doc = await vscode.workspace.openTextDocument(uri);
        await vscode.window.showTextDocument(doc, { preview: false });
      } catch (err) {
        const message = err instanceof Error ? err.message : String(err);
        void vscode.window.showErrorMessage(
          `Saropa Lints: failed to open report — ${message}`,
        );
      }
    }),
    // D2: Export OWASP Compliance Report as markdown.
    vscode.commands.registerCommand('saropaLints.exportOwaspReport', async () => {
      const root = getProjectRoot();
      if (!root) {
        vscode.window.showErrorMessage('No workspace folder open.');
        return;
      }
      const data = readViolations(root);
      if (!data) {
        vscode.window.showErrorMessage('No analysis data. Run analysis first.');
        return;
      }
      const report = generateOwaspReport(data, root);
      const folder = path.join(root, 'reports', '.saropa_lints');
      try { fs.mkdirSync(folder, { recursive: true }); } catch { /* exists */ }
      const filePath = path.join(folder, 'owasp_compliance_report.md');
      fs.writeFileSync(filePath, report, 'utf-8');
      const doc = await vscode.workspace.openTextDocument(vscode.Uri.file(filePath));
      await vscode.window.showTextDocument(doc);
      // Report: log export action.
      logSection('OWASP Export');
      logReport(`- Exported to ${filePath}`);
      flushReport(root);
    }),
    ...registerIssuesViewCommands({
      issuesProvider,
      updateIssuesViewMessage,
      getProjectRoot,
      readViolations,
      hotspotReviewState,
    }),
    // I2: Triage actions — disable/enable rules via analysis_options_custom.yaml overrides.
    // Shared helper extracts rule names from string[] (TreeItem click) or node (context menu).
    ...['saropaLints.disableRules', 'saropaLints.enableRules'].map((cmdId) =>
      vscode.commands.registerCommand(cmdId, async (arg: unknown) => {
        const isDisable = cmdId === 'saropaLints.disableRules';
        const rules = resolveRulesFromArg(arg);
        if (!rules || rules.length === 0) return;
        const root = getProjectRoot();
        if (!root) return;
        // Confirm for large groups (>5 rules).
        if (rules.length > 5) {
          const verb = isDisable ? 'Disable' : 'Enable';
          const ok = await vscode.window.showWarningMessage(
            `${verb} ${rules.length} rules? This updates analysis_options_custom.yaml.`,
            { modal: true },
            verb,
          );
          if (ok !== verb) return;
        }
        // I2: Write overrides then re-init + re-analyze.
        if (isDisable) {
          writeRuleOverrides(root, rules.map((r) => ({ rule: r, enabled: false })));
        } else {
          // Enable: remove false overrides so tier default applies.
          removeRuleOverrides(root, rules);
        }
        const initOk = await runInitializeConfig(context, `${isDisable ? 'Disabling' : 'Enabling'} ${rules.length} rule${rules.length === 1 ? '' : 's'}`);
        if (!initOk) return;
        const runAfter = getConfig().get<boolean>('runAnalysisAfterConfigChange', true) ?? true;
        if (runAfter) await runAnalysisCommand(context);
        refreshAll();
        updateAllStatusBars();
        updateContext(getConfig().get<boolean>('enabled', true) ?? true, issuesProvider.hasViolations());
        await vscode.commands.executeCommand('saropaLints.editorDashboards.focus');
      }),
    ),
  );

  // ── Copy as JSON commands ───────────────────────────────────────────────
  // Each view gets its own command so context menus target the right view.
  registerCopyAsJsonCommands(context, {
    issuesProvider,
    summaryProvider,
    securityProvider,
    fileRiskProvider,
    suggestionsProvider,
  });

  // Package Vibrancy subsystem — registers its own views, commands, and providers
  // under the shared saropaLints sidebar container.
  // Wrapped in try/catch so a vibrancy failure doesn't kill the entire extension.
  try {
    runVibrancyActivation(context, (data) => {
      vibrancyData = data;
      updateAllStatusBars();
      refreshAllSections();
    }, pubspecValidator);
  } catch (err) {
    console.error('[Saropa Lints] Package Vibrancy activation failed:', err);
    // Fallback: if vibrancy fails, register standalone pubspec listeners
    // so pubspec validation still works without vibrancy/SDK diagnostics.
    registerFallbackPubspecListeners(context, pubspecValidator);
  }

  // Background upgrade check — runs asynchronously, fails silently.
  // Only checks when saropa_lints is already in the project and extension is enabled.
  if (isDartProject && enabled && root) {
    void checkForUpgrade(context, root).catch((err) => {
      console.error('[Saropa Lints] Upgrade check failed:', err);
    });
  }

  // Prompt setup when this is a Dart project but saropa_lints is not in
  // pubspec.yaml. The notification is the most discoverable entry point for
  // new users who don't yet know to look in the sidebar.
  if (isDartProject && root && !hasSaropaLintsDep(root)) {
    void vscode.window.showInformationMessage(
      'Saropa Lints detected a Dart project without saropa_lints configured. Set up now for 2100+ lint rules.',
      'Set Up Project',
      'Not Now',
    ).then((choice) => {
      if (choice === 'Set Up Project') {
        void vscode.commands.executeCommand('saropaLints.enable');
      }
    });
  }

  // Public API for other extensions (e.g. Saropa Log Capture). See api.ts and extension README.
  const api: SaropaLintsApi = {
    getViolationsData(): ViolationsData | null {
      const r = getProjectRoot();
      return r ? readViolations(r) : null;
    },
    getViolationsPath(): string | null {
      const r = getProjectRoot();
      return r ? getViolationsFilePath(r) : null;
    },
    getHealthScoreParams() {
      return {
        impactWeights: { ...IMPACT_WEIGHTS },
        decayRate: DECAY_RATE,
      };
    },
    runAnalysis(): Promise<boolean> {
      return runAnalysisCommand(context);
    },
    runAnalysisForFiles(files: string[]): Promise<boolean> {
      return runAnalysisForFilesCommand(context, files, { showProgress: false });
    },
    getVersion(): string {
      return extVersion || '0.0.0';
    },
  };
  return api;
}

/** Extract rule names from command arg: string[] (TreeItem click) or triage node (context menu). */
function resolveRulesFromArg(arg: unknown): string[] | undefined {
  if (Array.isArray(arg)) return arg;
  if (arg && typeof arg === 'object' && 'kind' in arg) {
    const node = arg as { kind: string; rules?: string[]; ruleName?: string; violation?: { rule?: string } };
    if (node.kind === 'triageGroup' && Array.isArray(node.rules)) return node.rules;
    if (node.kind === 'triageRule' && typeof node.ruleName === 'string') return [node.ruleName];
    // Support invoking disableRules from a violation node in the issues tree.
    if (node.kind === 'violation' && typeof node.violation?.rule === 'string') return [node.violation.rule];
  }
  return undefined;
}

/** Pre-computed counts passed from the tier-change handler to the notification. */
interface TierChangeNotification {
  tierLabel: string;
  isUpgrade: boolean;
  postTotal: number;
  criticalPlusHigh: number;
  delta: number;
}

/**
 * Show a smart notification after a tier change.
 *
 * On upgrade with many violations, tells the user the Violations view has been
 * auto-filtered to critical+high so they aren't overwhelmed by thousands of
 * new violations at once. Provides a "Show All" escape hatch.
 *
 * On downgrade or small upgrade (≤50 total), shows a simple delta message
 * without auto-filtering.
 */
async function showTierChangeNotification(info: TierChangeNotification): Promise<void> {
  const deltaText = info.delta > 0 ? `+${info.delta.toLocaleString()}` : info.delta.toLocaleString();

  if (info.isUpgrade && info.postTotal > 50 && info.criticalPlusHigh > 0) {
    // Auto-filter was applied by the handler — notify user and offer escape hatch.
    const msg = `${info.tierLabel} tier: ${info.postTotal.toLocaleString()} violations (${deltaText}). `
      + `Showing ${info.criticalPlusHigh} critical + high — fix these first.`;
    const choice = await vscode.window.showInformationMessage(msg, 'View Violations', 'Show All');
    if (choice === 'View Violations') {
      // Use revealFindingsDashboard (not focusIssues) to preserve the auto-filter that was
      // applied by the handler — focusIssues calls clearFilters() first.
      await vscode.commands.executeCommand('saropaLints.revealFindingsDashboard');
    } else if (choice === 'Show All') {
      // User wants to see everything — clear the auto-filter via the existing command.
      await vscode.commands.executeCommand('saropaLints.clearIssuesFilters');
      await vscode.commands.executeCommand('saropaLints.revealFindingsDashboard');
    }
  } else {
    // Downgrade, small upgrade, or zero critical+high — simple confirmation.
    const msg = info.delta === 0
      ? `Tier changed to ${info.tierLabel}.`
      : `Tier changed to ${info.tierLabel} (${deltaText} violations).`;
    const choice = await vscode.window.showInformationMessage(msg, 'View Violations');
    if (choice === 'View Violations') {
      await vscode.commands.executeCommand('saropaLints.revealFindingsDashboard');
    }
  }
}

/**
 * I5: Show a score-aware notification after enable with action buttons.
 * Three cases:
 *   1. Score available → "Your project scores 72/100. Room to improve."
 *   2. Violations but no score → "Saropa Lints found N violations."
 *   3. No data (analysis didn't run) → "Saropa Lints is enabled."
 */
async function showFirstRunNotification(
  health: { score: number } | null,
  totalViolations: number,
): Promise<void> {
  let message: string;
  let primaryAction: string;

  if (health) {
    const band = scoreColorBand(health.score);
    // User-facing qualifier for the score band (avoids nested ternary for lint compliance).
    let qualifier: string;
    if (band === 'green') {
      qualifier = 'Great start!';
    } else if (band === 'yellow') {
      qualifier = 'Room to improve.';
    } else {
      qualifier = 'Needs attention.';
    }
    message = `Saropa Lints: Your project scores ${health.score}/100. ${qualifier}`;
    primaryAction = 'View Violations';
  } else if (totalViolations > 0) {
    message = `Saropa Lints found ${totalViolations} violation${totalViolations === 1 ? '' : 's'}.`;
    primaryAction = 'View Violations';
  } else {
    message = 'Saropa Lints is enabled. Run analysis to see your health score.';
    primaryAction = 'Run Analysis';
  }

  const choice = await vscode.window.showInformationMessage(
    message,
    primaryAction,
    'Configure Rules',
  );

  if (choice === 'View Violations') {
    await vscode.commands.executeCommand('saropaLints.focusIssues');
  } else if (choice === 'Run Analysis') {
    await vscode.commands.executeCommand('saropaLints.runAnalysis');
  } else if (choice === 'Configure Rules') {
    await vscode.commands.executeCommand('saropaLints.openConfigDashboard');
  }
}

export function deactivate(): void {
  // Wrapped in try/catch so a vibrancy teardown error doesn't prevent clean shutdown.
  try {
    stopFreshnessWatcher();
  } catch (err) {
    console.error('[Saropa Lints] Package Vibrancy deactivation failed:', err);
  }
}
