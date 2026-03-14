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
import { readViolations } from './violationsReader';
import { appendSnapshot } from './runHistory';

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

  context.subscriptions.push(
    issuesView,
    vscode.window.registerTreeDataProvider('saropaLints.summary', summaryProvider),
    vscode.window.registerTreeDataProvider('saropaLints.config', configProvider),
    vscode.window.registerTreeDataProvider('saropaLints.logs', logsProvider),
    vscode.window.registerTreeDataProvider('saropaLints.suggestions', suggestionsProvider),
  );

  const refreshAll = () => {
    issuesProvider.refresh();
    overviewProvider.refresh();
    summaryProvider.refresh();
    configProvider.refresh();
    logsProvider.refresh();
    suggestionsProvider.refresh();
    invalidateCodeLenses();
    updateIssuesBadge(issuesView, issuesProvider);
    updateIssuesViewMessage();
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
      refreshAll();
      // W5/W6: Snapshot current data for trends and show celebration messages.
      const root = vscode.workspace.workspaceFolders?.[0]?.uri.fsPath;
      if (root) {
        const data = readViolations(root);
        if (data) {
          const history = appendSnapshot(context.workspaceState, data);
          if (history.length >= 2) {
            const prev = history[history.length - 2];
            const curr = history[history.length - 1];
            const delta = prev.total - curr.total;
            if (delta > 0) {
              void vscode.window.setStatusBarMessage(
                `You fixed ${delta} issue${delta === 1 ? '' : 's'}!`,
                5000,
              );
            }
            if (prev.critical > 0 && curr.critical === 0) {
              void vscode.window.showInformationMessage('Saropa Lints: No critical issues!');
            }
          }
        }
      }
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
  const updateAllStatusBars = () => {
    const en = getConfig().get<boolean>('enabled', false) ?? false;
    // Main status bar: On/Off state.
    if (en) {
      statusBarItem.text = issuesProvider.hasViolations() ? '$(checklist) Saropa Lints: On' : '$(checklist) Saropa Lints';
      statusBarItem.tooltip = 'Saropa Lints is enabled. Click to open view.';
    } else {
      statusBarItem.text = '$(checklist) Saropa Lints: Off';
      statusBarItem.tooltip = 'Enable Saropa Lints';
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
        await vscode.commands.executeCommand('saropaLints.issues.focus');
        void vscode.window.setStatusBarMessage('Saropa Lints: Analysis complete', 3000);
      }
    }),
    vscode.commands.registerCommand('saropaLints.initializeConfig', async () => {
      const success = await runInitializeConfig(context);
      if (success) {
        refreshAll();
        updateAllStatusBars();
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
        refreshAll();
        updateAllStatusBars();
      }
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
