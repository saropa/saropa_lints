/**
 * Registers VS Code command handlers for the Issues / Violations tree: text and
 * structured filters, security-hotspot triage, focus-one-file mode, and group-by.
 *
 * Each handler updates `IssuesTreeProvider` state and refreshes the view title
 * via `updateIssuesViewMessage` where needed. Returned disposables must be
 * pushed onto the extension context subscription list so commands unregister on
 * deactivate.
 */
import * as vscode from 'vscode';
import { type GroupByMode, type IssueTreeNode, type IssuesTreeProvider } from '../views/issuesTree';
import { type SecurityHotspotReviewState, type SecurityHotspotReviewStateService, isSecurityHotspotViolation } from '../securityHotspotReviewState';
import { type ViolationsData } from '../violationsReader';

/** Injected collaborators so `registerIssuesViewCommands` stays testable and thin. */
interface RegisterIssuesViewCommandsDeps {
  /** Backing data model for the Issues tree (filters, grouping, refresh). */
  issuesProvider: IssuesTreeProvider;
  /** Recomputes the view title / description after filter mutations. */
  updateIssuesViewMessage: () => void;
  /** Workspace folder root for reading `violations.json` off disk. */
  getProjectRoot: () => string | undefined;
  /** Loads the latest violations payload for metadata-driven filters. */
  readViolations: (root: string) => ViolationsData | null;
  /** Persists per-violation hotspot review state in workspace memento storage. */
  hotspotReviewState: SecurityHotspotReviewStateService;
}

/** Wires `saropaLints.*` palette and tree commands; returns all `Disposable`s to retain. */
export function registerIssuesViewCommands(
  deps: RegisterIssuesViewCommandsDeps,
): vscode.Disposable[] {
  const {
    issuesProvider,
    updateIssuesViewMessage,
    getProjectRoot,
    readViolations,
    hotspotReviewState,
  } = deps;

  return [
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
        // Empty selection means "show all" for that dimension instead of
        // accidentally hiding everything.
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
    vscode.commands.registerCommand('saropaLints.setIssuesFilterByMetadata', async () => {
      const root = getProjectRoot();
      if (!root) return;
      const data = readViolations(root);
      if (!data) {
        void vscode.window.showInformationMessage('No violations in current data. Run analysis first.');
        return;
      }

      const typeCounts = data.summary?.byRuleType ?? {};
      const statusCounts = data.summary?.byRuleStatus ?? {};
      const metadataByRule = data.config?.ruleMetadataByRule ?? {};

      // Backfill counts from per-rule metadata if summary fields are absent.
      const mergedTypeCounts: Record<string, number> = { ...typeCounts };
      const mergedStatusCounts: Record<string, number> = { ...statusCounts };
      if (Object.keys(mergedTypeCounts).length === 0 || Object.keys(mergedStatusCounts).length === 0) {
        // Reconstruct aggregates from issuesByRule + metadata map so older
        // violations.json schemas still drive the metadata filter UI.
        const issueCounts = data.summary?.issuesByRule ?? {};
        for (const [ruleName, count] of Object.entries(issueCounts)) {
          const meta = metadataByRule[ruleName];
          const type = meta?.ruleType ?? 'unspecified';
          const status = meta?.ruleStatus ?? 'ready';
          mergedTypeCounts[type] = (mergedTypeCounts[type] ?? 0) + count;
          mergedStatusCounts[status] = (mergedStatusCounts[status] ?? 0) + count;
        }
      }

      type MetadataPick = vscode.QuickPickItem & {
        kindId: 'ruleType' | 'ruleStatus';
        value: string;
      };
      const quickPick = vscode.window.createQuickPick<MetadataPick>();
      quickPick.title = 'Filter by rule metadata';
      quickPick.matchOnDescription = true;
      quickPick.items = [
        { label: 'Rule type', kind: vscode.QuickPickItemKind.Separator, kindId: 'ruleType', value: '' },
        ...Object.entries(mergedTypeCounts)
          .sort((a, b) => b[1] - a[1])
          .map(([value, count]) => ({
            label: value,
            description: `${count} issue${count === 1 ? '' : 's'}`,
            kindId: 'ruleType' as const,
            value,
          })),
        { label: 'Rule status', kind: vscode.QuickPickItemKind.Separator, kindId: 'ruleStatus', value: '' },
        ...Object.entries(mergedStatusCounts)
          .sort((a, b) => b[1] - a[1])
          .map(([value, count]) => ({
            label: value,
            description: `${count} issue${count === 1 ? '' : 's'}`,
            kindId: 'ruleStatus' as const,
            value,
          })),
      ];

      quickPick.onDidAccept(() => {
        const selected = quickPick.selectedItems[0];
        if (!selected || !selected.value) {
          quickPick.hide();
          return;
        }
        void vscode.commands.executeCommand(
          'saropaLints.focusIssuesByRuleMetadata',
          selected.kindId,
          selected.value,
        );
        quickPick.hide();
      });
      quickPick.show();
    }),
    vscode.commands.registerCommand('saropaLints.reviewHotspotState', async (arg: unknown) => {
      const root = getProjectRoot();
      if (!root) return;
      const data = readViolations(root);
      if (!data) {
        void vscode.window.showInformationMessage('No analysis data. Run analysis first.');
        return;
      }
      const node = arg as IssueTreeNode | undefined;
      const fromNode = node?.kind === 'violation' ? node.violation : undefined;
      const allHotspots = data.violations.filter((violation) =>
        isSecurityHotspotViolation(violation, data.config?.ruleMetadataByRule),
      );
      if (allHotspots.length === 0) {
        void vscode.window.showInformationMessage('No security hotspots found in current report.');
        return;
      }
      let target = fromNode;
      if (
        !target ||
        !isSecurityHotspotViolation(target, data.config?.ruleMetadataByRule)
      ) {
        // If command is invoked from toolbar/palette without a node argument,
        // let user pick a hotspot interactively.
        const picks = allHotspots.map((violation) => ({
          label: `${violation.rule} (${violation.impact ?? 'low'})`,
          description: `${violation.file}:${violation.line}`,
          detail: violation.message,
          violation,
        }));
        const picked = await vscode.window.showQuickPick(picks, {
          title: 'Review security hotspot',
          placeHolder: 'Choose a hotspot to triage',
          matchOnDetail: true,
        });
        if (!picked) return;
        target = picked.violation;
      }
      const current = hotspotReviewState.getEffective(target, data.config?.ruleMetadataByRule);
      const statePicks: Array<{
        label: string;
        description: string;
        state: SecurityHotspotReviewState;
      }> = [
          { label: 'Open', description: 'Needs review or follow-up', state: 'open' },
          { label: 'Reviewed Safe', description: 'Reviewed and accepted as safe', state: 'reviewed-safe' },
          { label: 'Reviewed Fixed', description: 'Issue has been fixed', state: 'reviewed-fixed' },
        ];
      const pickedState = await vscode.window.showQuickPick(statePicks, {
        title: `Set hotspot state (${target.rule} @ ${target.file}:${target.line})`,
        placeHolder: `Current: ${current}`,
      });
      if (!pickedState) return;
      await hotspotReviewState.set(target, pickedState.state);
      // Refresh only the issues tree; no full re-analysis required because
      // review state is workspace memento metadata.
      issuesProvider.refresh();
      void vscode.window.showInformationMessage(
        `Hotspot marked as ${pickedState.state}.`,
      );
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
    // D10: Group-by picker for the Violations tree.
    vscode.commands.registerCommand('saropaLints.setGroupBy', async () => {
      const current = issuesProvider.getGroupBy();
      interface GroupByPickItem extends vscode.QuickPickItem {
        id: GroupByMode;
      }
      const baseModes: { label: string; description?: string; id: GroupByMode }[] = [
        { label: 'Severity', id: 'severity' },
        { label: 'File', id: 'file' },
        { label: 'Impact', description: 'Critical / High first', id: 'impact' },
        { label: 'Rule', id: 'rule' },
        { label: 'OWASP Category', id: 'owasp' },
        { label: 'Rule Type', id: 'ruleType' },
        { label: 'Rule Status', id: 'ruleStatus' },
      ];
      const items: GroupByPickItem[] = baseModes.map((m) => {
        const subtitle = m.description;
        return {
          label: m.id === current ? `$(check) ${m.label}` : m.label,
          description: m.id === current ? 'Current' : subtitle,
          id: m.id,
        };
      });
      const pick = await vscode.window.showQuickPick(items, {
        title: 'Group violations by',
        placeHolder: `Current: ${current}`,
      });
      if (pick) {
        issuesProvider.setGroupBy(pick.id);
        updateIssuesViewMessage();
      }
    }),
  ];
}
