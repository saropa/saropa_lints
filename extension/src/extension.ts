/**
 * Saropa Lints extension entry point.
 * Master switch (saropaLints.enabled) gates setup and analysis; when on,
 * extension manages pubspec and analysis_options and runs init/analyze.
 */

import * as vscode from 'vscode';
import * as fs from 'node:fs';
import * as path from 'node:path';
import {
  runEnable,
  runDisable,
  runAnalysis,
  runInitializeConfig,
  openConfig,
  runRepairConfig,
  runSetTier,
  showOutputChannel,
  TIER_ORDER,
} from './setup';
import { invalidateCodeLenses, registerCodeLensProvider } from './codeLensProvider';
import { IssuesTreeProvider, registerIssueCommands, type IssueTreeNode } from './views/issuesTree';
import { OverviewTreeProvider } from './views/overviewTree';
import { SummaryTreeProvider } from './views/summaryTree';
import { ConfigTreeProvider } from './views/configTree';
import { SuggestionsTreeProvider } from './views/suggestionsTree';
import { SecurityPostureTreeProvider } from './views/securityPostureTree';
import { FileRiskTreeProvider } from './views/fileRiskTree';
import { TodosAndHacksTreeProvider } from './views/todosAndHacksTree';
import { showAboutPanel } from './views/aboutView';
import { openRuleExplainPanelForViolation, openRuleExplainPanel } from './views/ruleExplainView';
import { readViolations, ViolationsData } from './violationsReader';
import { hasSaropaLintsDep } from './pubspecReader';
import {
  appendSnapshot,
  loadHistory,
  findPreviousScore,
  detectThresholdCrossing,
  type RunSnapshot,
} from './runHistory';
import { computeHealthScore, formatScoreDelta, scoreColorBand } from './healthScore';
import { registerInlineAnnotations, updateAnnotationsForAllEditors, invalidateAnnotationCache } from './inlineAnnotations';
import { writeRuleOverrides, removeRuleOverrides } from './configWriter';
import { logReport, logSection, flushReport } from './reportWriter';
import { generateOwaspReport } from './owaspExport';
import { getProjectRoot, invalidateProjectRoot } from './projectRoot';
import { runActivation as runVibrancyActivation, stopFreshnessWatcher, VibrancyStatusData } from './vibrancy/extension-activation';
import { copyTreeNodesToClipboard } from './copyTreeAsJson';
import { checkForUpgrade } from './upgrade-checker';
import {
  serializeIssueNode,
  serializeConfigNode,
  serializeSummaryNode,
  serializeSecurityNode,
  serializeFileRiskNode,
  serializeOverviewNode,
  serializeSuggestionNode,
} from './treeSerializers';

function getConfig() {
  return vscode.workspace.getConfiguration('saropaLints');
}

/** D8: Show regression nudge when score dipped below a threshold; offers "View Issues" action. */
function showRegressionNudge(crossing: { threshold: number }, curr: RunSnapshot): void {
  const criticalSuffix = curr.critical === 1 ? '' : 's';
  const msg =
    curr.critical > 0
      ? `${curr.critical} critical issue${criticalSuffix} \u2014 view.`
      : `Score dipped below ${crossing.threshold} \u2014 view issues.`;
  vscode.window.showInformationMessage(`Saropa Lints: ${msg}`, 'View Issues').then((choice) => {
    if (choice === 'View Issues') {
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

function updateIssuesBadge(view: vscode.TreeView<unknown>, issuesProvider: IssuesTreeProvider) {
  const root = getProjectRoot();
  if (!root) return;
  const data = readViolations(root);
  const total = data?.summary?.totalViolations ?? data?.violations?.length ?? 0;
  const critical = data?.summary?.byImpact?.critical ?? 0;
  if (total > 0 && view.badge !== undefined) {
    view.badge = {
      value: critical > 0 ? critical : total,
      tooltip: critical > 0 ? `${critical} critical, ${total} total` : `${total} violations`,
    };
  } else if (view.badge !== undefined) {
    view.badge = undefined;
  }
}

export function activate(context: vscode.ExtensionContext): void {
  // Detect whether this workspace is a Dart/Flutter project so the UI can
  // show appropriate welcome content instead of a misleading "Enable" button.
  // getProjectRoot() searches workspace root then one-level-deep subdirectories.
  const root = getProjectRoot();
  const isDartProject = root !== undefined;
  void vscode.commands.executeCommand('setContext', 'saropaLints.isDartProject', isDartProject);

  const cfg = getConfig();
  let enabled = cfg.get<boolean>('enabled', false) ?? false;

  // Auto-enable when saropa_lints is already in pubspec.yaml but the user
  // hasn't explicitly toggled the setting. This avoids the "off by default"
  // friction for projects that already depend on the package — no files are
  // touched, we just flip the workspace flag.
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

  updateContext(enabled, false);

  const issuesProvider = new IssuesTreeProvider(context.workspaceState);
  const overviewProvider = new OverviewTreeProvider(context.workspaceState);
  const summaryProvider = new SummaryTreeProvider();
  const configProvider = new ConfigTreeProvider();
  const suggestionsProvider = new SuggestionsTreeProvider();
  const securityProvider = new SecurityPostureTreeProvider();
  const fileRiskProvider = new FileRiskTreeProvider();
  const todosAndHacksProvider = new TodosAndHacksTreeProvider();

  context.subscriptions.push(
    vscode.window.registerTreeDataProvider('saropaLints.overview', overviewProvider),
  );

  const todosAndHacksView = vscode.window.createTreeView('saropaLints.todosAndHacks', {
    treeDataProvider: todosAndHacksProvider,
    showCollapseAll: true,
  });
  context.subscriptions.push(todosAndHacksView);

  let todosAndHacksSaveDebounce: ReturnType<typeof setTimeout> | undefined;
  context.subscriptions.push(
    vscode.workspace.onDidSaveTextDocument((doc) => {
      const cfg = vscode.workspace.getConfiguration('saropaLints.todosAndHacks');
      if (!cfg.get<boolean>('autoRefresh', true)) return;
      const folder = vscode.workspace.getWorkspaceFolder(doc.uri);
      if (!folder) return;
      if (todosAndHacksSaveDebounce) clearTimeout(todosAndHacksSaveDebounce);
      todosAndHacksSaveDebounce = setTimeout(() => {
        todosAndHacksSaveDebounce = undefined;
        todosAndHacksProvider.refresh();
        todosAndHacksView.message = undefined;
      }, 600);
    }),
  );

  const issuesView = vscode.window.createTreeView('saropaLints.issues', {
    treeDataProvider: issuesProvider,
    showCollapseAll: true,
  });
  updateIssuesBadge(issuesView, issuesProvider);

  function updateIssuesViewMessage(): void {
    const state = issuesProvider.getFilterState();
    const focused = issuesProvider.getFocusedFile();
    void vscode.commands.executeCommand('setContext', 'saropaLints.hasIssuesFilter', state.hasActiveFilters);
    void vscode.commands.executeCommand('setContext', 'saropaLints.hasSuppressions', state.hasSuppressions);
    void vscode.commands.executeCommand('setContext', 'saropaLints.hasFocusedFile', focused !== undefined);
    if (focused) {
      const basename = focused.split('/').pop() ?? focused;
      issuesView.message = `Focused: ${basename} \u2014 Showing ${state.filteredCount} of ${state.totalUnfiltered}`;
    } else if (state.hasActiveFilters || state.hasSuppressions) {
      issuesView.message = `Showing ${state.filteredCount} of ${state.totalUnfiltered}`;
    } else {
      issuesView.message = undefined;
    }
  }
  updateIssuesViewMessage();

  registerIssueCommands(issuesProvider, context);
  registerCodeLensProvider(context);
  registerInlineAnnotations(context);

  context.subscriptions.push(
    {
      dispose: () => {
        if (todosAndHacksSaveDebounce) clearTimeout(todosAndHacksSaveDebounce);
      },
    },
    issuesView,
    vscode.window.registerTreeDataProvider('saropaLints.summary', summaryProvider),
    vscode.window.registerTreeDataProvider('saropaLints.config', configProvider),
    vscode.window.registerTreeDataProvider('saropaLints.suggestions', suggestionsProvider),
    vscode.window.registerTreeDataProvider('saropaLints.securityPosture', securityProvider),
    vscode.window.registerTreeDataProvider('saropaLints.fileRisk', fileRiskProvider),
  );

  const refreshAll = () => {
    issuesProvider.refresh();
    overviewProvider.refresh();
    summaryProvider.refresh();
    configProvider.refresh();
    suggestionsProvider.refresh();
    securityProvider.refresh();
    fileRiskProvider.refresh();
    invalidateCodeLenses();
    updateIssuesBadge(issuesView, issuesProvider);
    updateIssuesViewMessage();
    // D3: Invalidate cache then refresh inline annotations for new data.
    invalidateAnnotationCache();
    updateAnnotationsForAllEditors();
  };

  context.subscriptions.push(
    vscode.workspace.onDidChangeConfiguration((e) => {
      if (!e.affectsConfiguration('saropaLints')) return;
      const c = getConfig();
      const en = c.get<boolean>('enabled', false) ?? false;
      updateContext(en, issuesProvider.hasViolations());
      refreshAll();
      // Status bars must update when config changes (e.g. tier changed via Settings UI).
      updateAllStatusBars();
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
          const { history, appended } = appendSnapshot(context.workspaceState, data);
          refreshAll();
          updateAllStatusBars(data);
          updateContext(getConfig().get<boolean>('enabled', false) ?? false, issuesProvider.hasViolations());
          runCelebrationIfNeeded(root, history, appended);
          return;
        }
      }
      // Fallback: no root or no data — still refresh views.
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
      statusBarItem.hide();
      return;
    }
    const en = getConfig().get<boolean>('enabled', false) ?? false;
    const tier = getConfig().get<string>('tier', 'recommended') ?? 'recommended';
    const showVibrancy =
      vscode.workspace.getConfiguration('saropaLints.packageVibrancy').get<boolean>('showInStatusBar', true) &&
      vibrancyData !== null;
    const vibrancyLabel = showVibrancy ? `${Math.round(vibrancyData!.averageScore / 10)}/10` : null;
    const trailLabel = vibrancyLabel ?? tier;

    if (en) {
      const root = getProjectRoot();
      const data = preloadedData ?? (root ? readViolations(root) : null);
      const health = data ? computeHealthScore(data) : null;
      if (health) {
        const history = loadHistory(context.workspaceState);
        const prevScore = findPreviousScore(history);
        const delta = prevScore === undefined ? '' : ` ${formatScoreDelta(health.score, prevScore)}`;
        statusBarItem.text = `$(checklist) Saropa: ${health.score}%${delta} · ${trailLabel}`;
        statusBarItem.backgroundColor = statusBarBackgroundForScore(health.score);
      } else {
        statusBarItem.text = `$(checklist) Saropa Lints · ${trailLabel}`;
        statusBarItem.backgroundColor = undefined;
      }
      statusBarItem.tooltip = buildStatusBarTooltipLines(tier, health, showVibrancy, vibrancyLabel).join('\n');
    } else {
      statusBarItem.text = '$(checklist) Saropa Lints: Off';
      statusBarItem.tooltip = `Saropa Lints v${extVersion} — Disabled`;
      statusBarItem.backgroundColor = undefined;
    }
    statusBarItem.command = 'saropaLints.focusView';
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
      await vscode.commands.executeCommand('saropaLints.overview.focus');

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

      await showFirstRunNotification(health, totalViolations);
    }),
    vscode.commands.registerCommand('saropaLints.disable', async () => {
      await runDisable();
      await cfg.update('enabled', false, vscode.ConfigurationTarget.Workspace);
      updateContext(false, false);
      refreshAll();
      updateAllStatusBars();
    }),
    vscode.commands.registerCommand('saropaLints.runAnalysis', async () => {
      const ok = await runAnalysis(context);
      if (ok) {
        refreshAll();
        updateAllStatusBars();
        updateContext(getConfig().get<boolean>('enabled', false) ?? false, issuesProvider.hasViolations());
        // C7: Focus Overview after analysis to show Health Score delta.
        await vscode.commands.executeCommand('saropaLints.overview.focus');
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
          await runAnalysis(context);
        }
        refreshAll();
        updateAllStatusBars();
        updateContext(getConfig().get<boolean>('enabled', false) ?? false, issuesProvider.hasViolations());
      }
    }),
    vscode.commands.registerCommand('saropaLints.openConfig', openConfig),
    vscode.commands.registerCommand('saropaLints.focusView', () => {
      vscode.commands.executeCommand('saropaLints.overview.focus');
    }),
    vscode.commands.registerCommand('saropaLints.openWalkthrough', () => {
      void vscode.commands.executeCommand(
        'workbench.action.openWalkthrough',
        'saropa.saropa-lints#saropaLints.gettingStarted',
        false,
      );
    }),
    vscode.commands.registerCommand('saropaLints.showAbout', () => {
      showAboutPanel(context.extensionUri, extVersion);
    }),
    vscode.commands.registerCommand('saropaLints.createSonarQubeMcpInstructions', async () => {
      const folder = vscode.workspace.workspaceFolders?.[0];
      if (!folder) {
        void vscode.window.showErrorMessage('Open a workspace folder first.');
        return;
      }
      const rulesDir = path.join(folder.uri.fsPath, '.cursor', 'rules');
      const destPath = path.join(rulesDir, 'sonarqube_mcp_instructions.mdc');
      const templatePath = path.join(context.extensionUri.fsPath, 'media', 'sonarqube_mcp_instructions.mdc');
      try {
        fs.mkdirSync(rulesDir, { recursive: true });
        fs.copyFileSync(templatePath, destPath);
        void vscode.window.showInformationMessage(
          'Created .cursor/rules/sonarqube_mcp_instructions.mdc for AI agents.',
        );
        const doc = await vscode.workspace.openTextDocument(destPath);
        void vscode.window.showTextDocument(doc);
      } catch (e) {
        const msg = e instanceof Error ? e.message : String(e);
        void vscode.window.showErrorMessage(`Failed to create SonarQube MCP instructions: ${msg}`);
      }
    }),
    // Show all issues: clear filters and focus Issues view (e.g. from Summary "Total violations").
    vscode.commands.registerCommand('saropaLints.focusIssues', () => {
      issuesProvider.clearFilters();
      updateIssuesViewMessage();
      void vscode.commands.executeCommand('saropaLints.issues.focus');
    }),
    // Focus Issues view filtered to a single file (Code Lens, Problems view "Show in Saropa Lints").
    vscode.commands.registerCommand('saropaLints.focusIssuesForFile', (filePath: string) => {
      const normalized = typeof filePath === 'string' ? filePath.replaceAll('\\', '/') : '';
      if (!normalized) return;
      issuesProvider.setTextFilter(normalized);
      updateIssuesViewMessage();
      void vscode.commands.executeCommand('saropaLints.issues.focus');
    }),
    // Focus Issues view filtered to the active editor's file (e.g. from Problems view context menu).
    vscode.commands.registerCommand('saropaLints.focusIssuesForActiveFile', () => {
      const root = getProjectRoot();
      const editor = vscode.window.activeTextEditor;
      if (!root || !editor?.document?.uri) {
        void vscode.window.showInformationMessage('Open a file to show its issues in Saropa Lints.');
        return;
      }
      const relative = path.relative(root, editor.document.uri.fsPath).replaceAll('\\', '/');
      issuesProvider.setTextFilter(relative);
      updateIssuesViewMessage();
      void vscode.commands.executeCommand('saropaLints.issues.focus');
    }),
    vscode.commands.registerCommand('saropaLints.focusIssuesWithImpactFilter', (impact: string) => {
      if (impact && typeof impact === 'string') {
        issuesProvider.setImpactFilter(new Set([impact]));
        issuesProvider.setSeverityFilter(new Set(['error', 'warning', 'info']));
        updateIssuesViewMessage();
        void vscode.commands.executeCommand('saropaLints.issues.focus');
      }
    }),
    vscode.commands.registerCommand('saropaLints.focusIssuesWithSeverityFilter', (severity: string) => {
      if (severity && typeof severity === 'string') {
        issuesProvider.setSeverityFilter(new Set([severity]));
        issuesProvider.setImpactFilter(new Set(['critical', 'high', 'medium', 'low', 'opinionated']));
        updateIssuesViewMessage();
        void vscode.commands.executeCommand('saropaLints.issues.focus');
      }
    }),
    vscode.commands.registerCommand('saropaLints.refresh', () => {
      refreshAll();
      updateAllStatusBars();
      updateContext(getConfig().get<boolean>('enabled', false) ?? false, issuesProvider.hasViolations());
    }),
    vscode.commands.registerCommand('saropaLints.todosAndHacks.refresh', () => {
      todosAndHacksProvider.refresh();
      todosAndHacksView.message = undefined;
      void vscode.commands.executeCommand('saropaLints.todosAndHacks.focus');
    }),
    vscode.commands.registerCommand('saropaLints.todosAndHacks.toggleGroupByTag', async () => {
      const cfg = vscode.workspace.getConfiguration('saropaLints.todosAndHacks');
      const current = cfg.get<boolean>('groupByTag', false);
      await cfg.update('groupByTag', !current, vscode.ConfigurationTarget.Workspace);
      todosAndHacksProvider.refresh();
      todosAndHacksView.message = undefined;
      void vscode.commands.executeCommand('saropaLints.todosAndHacks.focus');
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
        updateContext(getConfig().get<boolean>('enabled', false) ?? false, issuesProvider.hasViolations());

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
    // D1/I1: Focus Issues view filtered to a set of rule names.
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
        void vscode.commands.executeCommand('saropaLints.issues.focus');
      }),
    ),
    vscode.commands.registerCommand('saropaLints.explainRule', (arg: unknown) => {
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
    vscode.commands.registerCommand('saropaLints.showOutput', showOutputChannel),
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
    vscode.commands.registerCommand('saropaLints.setIssuesFilter', async () => {
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
    }),
    vscode.commands.registerCommand('saropaLints.setIssuesFilterByType', async () => {
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
    }),
    vscode.commands.registerCommand('saropaLints.setIssuesFilterByRule', async () => {
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
    }),
    vscode.commands.registerCommand('saropaLints.clearIssuesFilters', () => {
      issuesProvider.clearFilters();
      updateIssuesViewMessage();
    }),
    vscode.commands.registerCommand('saropaLints.clearSuppressions', () => {
      issuesProvider.clearSuppressionsAndRefresh();
      updateIssuesViewMessage();
    }),
    // W7: Focus mode — show only one file's violations in the Issues tree.
    vscode.commands.registerCommand('saropaLints.focusFile', (element: unknown) => {
      if (element && typeof element === 'object' && 'kind' in element && (element as { kind: string }).kind === 'file') {
        const filePath = (element as unknown as { filePath: string }).filePath;
        issuesProvider.setFocusedFile(filePath);
        updateIssuesViewMessage();
      }
    }),
    vscode.commands.registerCommand('saropaLints.clearFocusFile', () => {
      issuesProvider.clearFocusedFile();
      updateIssuesViewMessage();
    }),
    // D10: Group-by picker for the Issues tree.
    vscode.commands.registerCommand('saropaLints.setGroupBy', async () => {
      const current = issuesProvider.getGroupBy();
      interface GroupByPickItem extends vscode.QuickPickItem {
        id: import('./views/issuesTree').GroupByMode;
      }
      const items: GroupByPickItem[] = [
        { label: 'Severity', id: 'severity' },
        { label: 'File', id: 'file' },
        { label: 'Impact', id: 'impact' },
        { label: 'Rule', id: 'rule' },
        { label: 'OWASP Category', id: 'owasp' },
      ].map((m) => ({
        label: m.id === current ? `$(check) ${m.label}` : m.label,
        description: m.id === current ? 'Current' : undefined,
        id: m.id as import('./views/issuesTree').GroupByMode,
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
        if (runAfter) await runAnalysis(context);
        refreshAll();
        updateAllStatusBars();
        updateContext(getConfig().get<boolean>('enabled', false) ?? false, issuesProvider.hasViolations());
        await vscode.commands.executeCommand('saropaLints.overview.focus');
      }),
    ),
  );

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
    runVibrancyActivation(context, (data) => {
      vibrancyData = data;
      updateAllStatusBars();
    });
  } catch (err) {
    console.error('[Saropa Lints] Package Vibrancy activation failed:', err);
  }

  // Background upgrade check — runs asynchronously, fails silently.
  // Only checks when saropa_lints is already in the project and extension is enabled.
  if (isDartProject && enabled && root) {
    void checkForUpgrade(context, root).catch((err) => {
      console.error('[Saropa Lints] Upgrade check failed:', err);
    });
  }
}

/** Extract rule names from command arg: string[] (TreeItem click) or triage node (context menu). */
function resolveRulesFromArg(arg: unknown): string[] | undefined {
  if (Array.isArray(arg)) return arg;
  if (arg && typeof arg === 'object' && 'kind' in arg) {
    const node = arg as { kind: string; rules?: string[]; ruleName?: string };
    if (node.kind === 'triageGroup' && Array.isArray(node.rules)) return node.rules;
    if (node.kind === 'triageRule' && typeof node.ruleName === 'string') return [node.ruleName];
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
 * On upgrade with many violations, tells the user the Issues view has been
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
    const choice = await vscode.window.showInformationMessage(msg, 'View Issues', 'Show All');
    if (choice === 'View Issues') {
      // Use issues.focus (not focusIssues) to preserve the auto-filter that was
      // applied by the handler — focusIssues calls clearFilters() first.
      await vscode.commands.executeCommand('saropaLints.issues.focus');
    } else if (choice === 'Show All') {
      // User wants to see everything — clear the auto-filter via the existing command.
      await vscode.commands.executeCommand('saropaLints.clearIssuesFilters');
      await vscode.commands.executeCommand('saropaLints.issues.focus');
    }
  } else {
    // Downgrade, small upgrade, or zero critical+high — simple confirmation.
    const msg = info.delta === 0
      ? `Tier changed to ${info.tierLabel}.`
      : `Tier changed to ${info.tierLabel} (${deltaText} violations).`;
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
    primaryAction = 'View Issues';
  } else if (totalViolations > 0) {
    message = `Saropa Lints found ${totalViolations} issue${totalViolations === 1 ? '' : 's'}.`;
    primaryAction = 'View Issues';
  } else {
    message = 'Saropa Lints is enabled. Run analysis to see your health score.';
    primaryAction = 'Run Analysis';
  }

  const choice = await vscode.window.showInformationMessage(
    message,
    primaryAction,
    'Configure Rules',
  );

  if (choice === 'View Issues') {
    await vscode.commands.executeCommand('saropaLints.focusIssues');
  } else if (choice === 'Run Analysis') {
    await vscode.commands.executeCommand('saropaLints.runAnalysis');
  } else if (choice === 'Configure Rules') {
    await vscode.commands.executeCommand('saropaLints.config.focus');
  }
}

/** Register "Copy as JSON" commands for all lints tree views (not vibrancy — handled separately). */
function registerCopyAsJsonCommands(
  context: vscode.ExtensionContext,
  providers: {
    issuesProvider: IssuesTreeProvider;
    configProvider: ConfigTreeProvider;
    summaryProvider: SummaryTreeProvider;
    securityProvider: SecurityPostureTreeProvider;
    fileRiskProvider: FileRiskTreeProvider;
    overviewProvider: OverviewTreeProvider;
    suggestionsProvider: SuggestionsTreeProvider;
  },
): void {
  const { issuesProvider, configProvider, summaryProvider, securityProvider, fileRiskProvider, overviewProvider, suggestionsProvider } = providers;

  context.subscriptions.push(
    vscode.commands.registerCommand('saropaLints.issues.copyAsJson', (item: unknown, selected?: unknown[]) =>
      copyTreeNodesToClipboard(item, selected, serializeIssueNode, (n) => issuesProvider.getChildren(n as never), 'Issues'),
    ),
    vscode.commands.registerCommand('saropaLints.config.copyAsJson', (item: unknown, selected?: unknown[]) =>
      copyTreeNodesToClipboard(item, selected, serializeConfigNode, (n) => configProvider.getChildren(n as never), 'Config'),
    ),
    vscode.commands.registerCommand('saropaLints.summary.copyAsJson', (item: unknown, selected?: unknown[]) =>
      copyTreeNodesToClipboard(item, selected, serializeSummaryNode, (n) => summaryProvider.getChildren(n as never), 'Summary'),
    ),
    vscode.commands.registerCommand('saropaLints.securityPosture.copyAsJson', (item: unknown, selected?: unknown[]) =>
      copyTreeNodesToClipboard(item, selected, serializeSecurityNode, (n) => securityProvider.getChildren(n as never), 'Security Posture'),
    ),
    vscode.commands.registerCommand('saropaLints.fileRisk.copyAsJson', (item: unknown, selected?: unknown[]) =>
      copyTreeNodesToClipboard(item, selected, serializeFileRiskNode, (n) => fileRiskProvider.getChildren(n as never), 'File Risk'),
    ),
    vscode.commands.registerCommand('saropaLints.overview.copyAsJson', (item: unknown, selected?: unknown[]) =>
      copyTreeNodesToClipboard(item, selected, serializeOverviewNode, (n) => overviewProvider.getChildren(), 'Overview'),
    ),
    vscode.commands.registerCommand('saropaLints.suggestions.copyAsJson', (item: unknown, selected?: unknown[]) =>
      copyTreeNodesToClipboard(item, selected, serializeSuggestionNode, (n) => suggestionsProvider.getChildren(), 'Suggestions'),
    ),
  );
}

export function deactivate(): void {
  // Wrapped in try/catch so a vibrancy teardown error doesn't prevent clean shutdown.
  try {
    stopFreshnessWatcher();
  } catch (err) {
    console.error('[Saropa Lints] Package Vibrancy deactivation failed:', err);
  }
}
