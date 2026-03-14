/**
 * Saropa Lints extension entry point.
 * Master switch (saropaLints.enabled) gates setup and analysis; when on,
 * extension manages pubspec and analysis_options and runs init/analyze.
 */

import * as vscode from 'vscode';
import * as path from 'path';
import {
  runEnable,
  runDisable,
  runAnalysis,
  runInitializeConfig,
  openConfig,
  runRepairConfig,
  runSetTier,
  showOutputChannel,
} from './setup';
import { invalidateCodeLenses, registerCodeLensProvider } from './codeLensProvider';
import { IssuesTreeProvider, registerIssueCommands } from './views/issuesTree';
import { OverviewTreeProvider } from './views/overviewTree';
import { SummaryTreeProvider } from './views/summaryTree';
import { ConfigTreeProvider } from './views/configTree';
import { LogsTreeProvider } from './views/logsTree';
import { SuggestionsTreeProvider } from './views/suggestionsTree';
import { SecurityPostureTreeProvider } from './views/securityPostureTree';
import { readViolations, ViolationsData } from './violationsReader';
import { appendSnapshot, loadHistory, findPreviousScore } from './runHistory';
import { computeHealthScore, formatScoreDelta, scoreColorBand } from './healthScore';
import { registerInlineAnnotations, updateAnnotationsForAllEditors } from './inlineAnnotations';

function getConfig() {
  return vscode.workspace.getConfiguration('saropaLints');
}

function updateContext(enabled: boolean, hasViolations: boolean) {
  void vscode.commands.executeCommand('setContext', 'saropaLints.enabled', enabled);
  void vscode.commands.executeCommand('setContext', 'saropaLints.hasViolations', hasViolations);
}

function updateIssuesBadge(view: vscode.TreeView<unknown>, issuesProvider: IssuesTreeProvider) {
  const root = vscode.workspace.workspaceFolders?.[0]?.uri.fsPath;
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
  const cfg = getConfig();
  const enabled = cfg.get<boolean>('enabled', false) ?? false;
  updateContext(enabled, false);

  const issuesProvider = new IssuesTreeProvider(context.workspaceState);
  const overviewProvider = new OverviewTreeProvider(context.workspaceState);
  const summaryProvider = new SummaryTreeProvider();
  const configProvider = new ConfigTreeProvider();
  const logsProvider = new LogsTreeProvider();
  const suggestionsProvider = new SuggestionsTreeProvider();
  const securityProvider = new SecurityPostureTreeProvider();

  context.subscriptions.push(
    vscode.window.registerTreeDataProvider('saropaLints.overview', overviewProvider),
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
    issuesView,
    vscode.window.registerTreeDataProvider('saropaLints.summary', summaryProvider),
    vscode.window.registerTreeDataProvider('saropaLints.config', configProvider),
    vscode.window.registerTreeDataProvider('saropaLints.logs', logsProvider),
    vscode.window.registerTreeDataProvider('saropaLints.suggestions', suggestionsProvider),
    vscode.window.registerTreeDataProvider('saropaLints.securityPosture', securityProvider),
  );

  const refreshAll = () => {
    issuesProvider.refresh();
    overviewProvider.refresh();
    summaryProvider.refresh();
    configProvider.refresh();
    logsProvider.refresh();
    suggestionsProvider.refresh();
    securityProvider.refresh();
    invalidateCodeLenses();
    updateIssuesBadge(issuesView, issuesProvider);
    updateIssuesViewMessage();
    // D3: Refresh inline annotations when violations data changes.
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
  );

  const violationsPath = (): string | null => {
    const root = vscode.workspace.workspaceFolders?.[0]?.uri.fsPath;
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
      const root = vscode.workspace.workspaceFolders?.[0]?.uri.fsPath;
      if (root) {
        const data = readViolations(root);
        if (data) {
          const { history, appended } = appendSnapshot(context.workspaceState, data);
          // Refresh views after snapshot is persisted so Overview reads fresh history.
          refreshAll();
          // Pass pre-loaded data to avoid re-reading violations.json from disk.
          updateAllStatusBars(data);
          // C7: Keep viewsWelcome when-clauses current when data appears via file watcher.
          updateContext(getConfig().get<boolean>('enabled', false) ?? false, issuesProvider.hasViolations());
          // Only show celebration when a genuinely new snapshot was recorded.
          if (appended && history.length >= 2) {
            const prev = history[history.length - 2];
            const curr = history[history.length - 1];
            const delta = prev.total - curr.total;
            // D8: Score-driven celebration — mention score delta when available.
            const scoreDelta = (prev.score !== undefined && curr.score !== undefined)
              ? formatScoreDelta(curr.score, prev.score)
              : '';
            if (delta > 0) {
              const scoreMsg = scoreDelta ? ` (Score: ${curr.score} ${scoreDelta})` : '';
              void vscode.window.setStatusBarMessage(
                `You fixed ${delta} issue${delta === 1 ? '' : 's'}!${scoreMsg}`,
                5000,
              );
            }
            if (prev.critical > 0 && curr.critical === 0) {
              void vscode.window.showInformationMessage('Saropa Lints: No critical issues!');
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

  const statusBarItem = vscode.window.createStatusBarItem(vscode.StatusBarAlignment.Right, 100);
  context.subscriptions.push(statusBarItem);

  // W8: Separate status bar item showing the current tier; click to change.
  const tierStatusBarItem = vscode.window.createStatusBarItem(vscode.StatusBarAlignment.Right, 99);
  context.subscriptions.push(tierStatusBarItem);

  // Combined updater for both status bar items to avoid scattered calls.
  // Accepts optional pre-loaded data to avoid re-reading violations.json from disk
  // when the caller already has it (e.g. debouncedRefresh).
  const updateAllStatusBars = (preloadedData?: ViolationsData) => {
    const en = getConfig().get<boolean>('enabled', false) ?? false;
    // Main status bar: Health Score when available, else On/Off state.
    if (en) {
      // Use pre-loaded data when supplied; otherwise read from disk.
      const root = vscode.workspace.workspaceFolders?.[0]?.uri.fsPath;
      const data = preloadedData ?? (root ? readViolations(root) : null);
      const health = data ? computeHealthScore(data) : null;

      if (health) {
        // Show score with delta from previous run if available.
        const history = loadHistory(context.workspaceState);
        const prevScore = findPreviousScore(history);
        const delta = prevScore !== undefined ? ` ${formatScoreDelta(health.score, prevScore)}` : '';
        statusBarItem.text = `$(checklist) Saropa: ${health.score}${delta}`;
        // Color the status bar based on score band.
        const band = scoreColorBand(health.score);
        statusBarItem.backgroundColor = band === 'red'
          ? new vscode.ThemeColor('statusBarItem.errorBackground')
          : band === 'yellow'
            ? new vscode.ThemeColor('statusBarItem.warningBackground')
            : undefined;
        statusBarItem.tooltip = `Health Score: ${health.score}/100. Click to open Saropa Lints.`;
      } else {
        statusBarItem.text = issuesProvider.hasViolations() ? '$(checklist) Saropa Lints: On' : '$(checklist) Saropa Lints';
        statusBarItem.tooltip = 'Saropa Lints is enabled. Click to open view.';
        statusBarItem.backgroundColor = undefined;
      }
    } else {
      statusBarItem.text = '$(checklist) Saropa Lints: Off';
      statusBarItem.tooltip = 'Enable Saropa Lints';
      statusBarItem.backgroundColor = undefined;
    }
    statusBarItem.command = 'saropaLints.focusView';
    statusBarItem.show();
    // Tier status bar: current tier, click to change.
    if (en) {
      const tier = getConfig().get<string>('tier', 'recommended') ?? 'recommended';
      tierStatusBarItem.text = `$(tag) ${tier}`;
      tierStatusBarItem.tooltip = 'Saropa Lints tier. Click to change.';
      tierStatusBarItem.command = 'saropaLints.setTier';
      tierStatusBarItem.show();
    } else {
      tierStatusBarItem.hide();
    }
  };
  updateAllStatusBars();

  context.subscriptions.push(
    vscode.commands.registerCommand('saropaLints.enable', async () => {
      const success = await runEnable(context);
      if (success) {
        await cfg.update('enabled', true, vscode.ConfigurationTarget.Workspace);
        updateContext(true, issuesProvider.hasViolations());
        refreshAll();
        updateAllStatusBars();
      }
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
        const root = vscode.workspace.workspaceFolders?.[0]?.uri.fsPath;
        const postData = root ? readViolations(root) : null;
        const health = postData ? computeHealthScore(postData) : null;
        const scoreMsg = health ? ` Score: ${health.score}` : '';
        void vscode.window.setStatusBarMessage(`Saropa Lints: Analysis complete.${scoreMsg}`, 4000);
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
      void vscode.commands.executeCommand('saropaLints.overview.focus');
    }),
    // Show all issues: clear filters and focus Issues view (e.g. from Summary "Total violations").
    vscode.commands.registerCommand('saropaLints.focusIssues', () => {
      issuesProvider.clearFilters();
      updateIssuesViewMessage();
      void vscode.commands.executeCommand('saropaLints.issues.focus');
    }),
    // Focus Issues view filtered to a single file (Code Lens, Problems view "Show in Saropa Lints").
    vscode.commands.registerCommand('saropaLints.focusIssuesForFile', (filePath: string) => {
      const normalized = typeof filePath === 'string' ? filePath.replace(/\\/g, '/') : '';
      if (!normalized) return;
      issuesProvider.setTextFilter(normalized);
      updateIssuesViewMessage();
      void vscode.commands.executeCommand('saropaLints.issues.focus');
    }),
    // Focus Issues view filtered to the active editor's file (e.g. from Problems view context menu).
    vscode.commands.registerCommand('saropaLints.focusIssuesForActiveFile', () => {
      const root = vscode.workspace.workspaceFolders?.[0]?.uri.fsPath;
      const editor = vscode.window.activeTextEditor;
      if (!root || !editor?.document?.uri) {
        void vscode.window.showInformationMessage('Open a file to show its issues in Saropa Lints.');
        return;
      }
      const relative = path.relative(root, editor.document.uri.fsPath).replace(/\\/g, '/');
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
    vscode.commands.registerCommand('saropaLints.repairConfig', async () => {
      const success = await runRepairConfig(context);
      if (success) refreshAll();
    }),
    vscode.commands.registerCommand('saropaLints.setTier', async () => {
      const success = await runSetTier(context);
      if (success) {
        // C6: setup.ts already runs analysis inside runSetTier when
        // runAnalysisAfterConfigChange is on; no duplicate call here.
        refreshAll();
        updateAllStatusBars();
        updateContext(getConfig().get<boolean>('enabled', false) ?? false, issuesProvider.hasViolations());
        // C6: Focus Overview after tier change so user sees score delta.
        await vscode.commands.executeCommand('saropaLints.overview.focus');
      }
    }),
    // D1: Focus Issues view filtered to rules mapped to an OWASP category.
    // Uses rule-hide filter: hide all rules EXCEPT the ones mapped to this category.
    vscode.commands.registerCommand('saropaLints.focusIssuesForOwasp', (rules: string[]) => {
      if (!Array.isArray(rules) || rules.length === 0) return;
      const allRules = issuesProvider.getRuleNamesFromData();
      const keep = new Set(rules);
      const toHide = new Set(allRules.filter((r) => !keep.has(r)));
      issuesProvider.setRulesToHide(toHide);
      updateIssuesViewMessage();
      void vscode.commands.executeCommand('saropaLints.issues.focus');
    }),
    vscode.commands.registerCommand('saropaLints.showOutput', showOutputChannel),
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
  );
}

export function deactivate(): void {}
