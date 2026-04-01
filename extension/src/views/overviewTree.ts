/**
 * # Overview & options — tree data provider
 *
 * Single sidebar view that combines onboarding copy, **Settings** (embedded
 * {@link ConfigTreeProvider} settings + actions), **Issues** (triage groups from
 * {@link ConfigTreeProvider}), **Sidebar** (per-section visibility), and the
 * **dashboard** (health, violations, trends) when `violations.json` exists.
 *
 * ## Behaviour contracts (for reviewers)
 *
 * - **Dart workspace:** always returns intro rows, **Settings** (embedded config),
 *   conditionally **Issues** (when triage data exists),
 *   and **Sidebar** section toggles so users are never stuck on a bare welcome with only
 *   a single “Enable” affordance. `saropaLints.enabled` defaults **true**; when a user turns
 *   lint integration **off**, a **Lint integration: Off** row (warning styling) still links
 *   to **Set Up Project** so onboarding is discoverable without hiding the rest of the tree.
 * - **Non-Dart:** empty root so `viewsWelcome` can prompt to open a pubspec folder.
 * - **Embedded config:** delegates to the same `ConfigTreeProvider` instance as the
 *   standalone Config view — `refreshAll` clears triage cache once; no duplicate logic.
 * - **Recursion:** `getChildren` depth is bounded (root → settings/issues → triage groups
 *   → rules; root → sidebar → leaves). No cycles.
 * - **Type guard:** {@link isConfigTreeNode} only accepts known `ConfigTreeNode.kind`
 *   values so arbitrary objects with a `kind` property cannot reach `renderTreeItem`.
 */

import * as vscode from 'vscode';
import { readViolations, type ViolationsData } from '../violationsReader';
import { loadHistory, getTrendSummary, getScoreTrendSummary, findPreviousScore, detectScoreRegression } from '../runHistory';
import { computeHealthScore, formatScoreDelta } from '../healthScore';
import { getProjectRoot } from '../projectRoot';
import type { ConfigTreeProvider } from './configTree';
import type { ConfigTreeNode } from './triageTree';
import { renderTreeItem } from './triageTree';
import { OVERVIEW_EMBEDDED_CONFIG_KINDS } from '../overviewEmbeddedConfigKinds';
import {
    OverviewSidebarSectionParent,
    OverviewSidebarToggleItem,
    buildSidebarToggleItems,
} from './overviewSidebarTree';

const OVERVIEW_INTRO_TOOLTIP =
    'Saropa Lints provides 2050+ Dart and Flutter lint rules for security, accessibility, and performance. '
    + 'It has two components: a pub.dev package with the rules and a VS Code extension for visual analysis and configuration.';

/** Collapsible group for lint settings and config actions. */
export class OverviewSettingsParent extends vscode.TreeItem {
    constructor() {
        super('Settings', vscode.TreeItemCollapsibleState.Expanded);
        this.contextValue = 'overviewSettingsSection';
        this.iconPath = new vscode.ThemeIcon('settings-gear');
        this.tooltip = 'Lint integration, tier, analysis behavior, detected packages, and config actions';
    }
}

/** Collapsible group for issue triage (rules grouped by violation count). */
export class OverviewIssuesParent extends vscode.TreeItem {
    constructor() {
        super('Issues', vscode.TreeItemCollapsibleState.Expanded);
        this.contextValue = 'overviewIssuesSection';
        this.iconPath = new vscode.ThemeIcon('list-filter');
        this.tooltip = 'Rules grouped by violation count for triage';
    }
}

/** C1: Format an ISO timestamp as a human-readable relative time. */
function formatTimeAgo(iso: string): string {
    const ms = Date.now() - new Date(iso).getTime();
    if (ms < 0 || !Number.isFinite(ms)) return 'just now';
    const sec = Math.floor(ms / 1000);
    if (sec < 60) return 'just now';
    const min = Math.floor(sec / 60);
    if (min < 60) return `${min} min ago`;
    const hrs = Math.floor(min / 60);
    if (hrs < 24) return `${hrs}h ago`;
    const days = Math.floor(hrs / 24);
    return `${days}d ago`;
}

/** Dashboard row: label + optional description, click command, and Codicon icon. */
class OverviewItem extends vscode.TreeItem {
    constructor(
        label: string,
        description: string | undefined,
        commandId: string | undefined,
        iconId?: string,
        iconColor?: vscode.ThemeColor,
    ) {
        super(label, vscode.TreeItemCollapsibleState.None);
        this.description = description;
        if (commandId) {
            this.command = { command: commandId, title: label, arguments: [] };
        }
        this.contextValue = 'overviewItem';
        if (iconId) {
            this.iconPath = new vscode.ThemeIcon(iconId, iconColor);
        }
    }
}

function buildOverviewIntroItems(): OverviewItem[] {
    const summary = new OverviewItem(
        'Saropa Lints',
        'Package + extension for Dart/Flutter',
        undefined,
        'info',
    );
    summary.tooltip = OVERVIEW_INTRO_TOOLTIP;
    return [
        summary,
        new OverviewItem('Learn more on pub.dev', 'saropa_lints', 'saropaLints.openPubDevSaropaLints', 'link-external'),
        new OverviewItem('About Saropa Lints', 'Documentation', 'saropaLints.showAbout', 'book'),
        new OverviewItem('Getting Started', 'Walkthrough', 'saropaLints.openWalkthrough', 'compass'),
    ];
}

function healthScoreDescription(delta: string, total: number): string {
    if (delta) {
        return `${delta} from last run`;
    }
    if (total === 0) {
        return 'No violations';
    }
    return `${total} violations`;
}

function appendHealthRow(
    items: OverviewItem[],
    history: ReturnType<typeof loadHistory>,
    data: ViolationsData,
    total: number,
): void {
    const health = computeHealthScore(data);
    if (!health) return;

    const prevScore = findPreviousScore(history);
    let delta = '';
    if (prevScore !== undefined) {
        delta = formatScoreDelta(health.score, prevScore);
    }
    items.push(
        new OverviewItem(
            `Health: ${health.score}`,
            healthScoreDescription(delta, total),
            'saropaLints.focusIssues',
            'pulse',
        ),
    );
}

function appendViolationCountRow(items: OverviewItem[], total: number, critical: number): void {
    if (total > 0) {
        const issueLabel = critical > 0
            ? `${critical} critical, ${total} total`
            : `${total} violations`;
        items.push(
            new OverviewItem(
                issueLabel, 'View in Violations', 'saropaLints.focusIssues',
                'warning', new vscode.ThemeColor('list.warningForeground'),
            ),
        );
        return;
    }
    items.push(
        new OverviewItem(
            'No violations', 'All clear', 'saropaLints.focusIssues',
            'pass', new vscode.ThemeColor('testing.iconPassed'),
        ),
    );
}

function appendTrendRow(items: OverviewItem[], history: ReturnType<typeof loadHistory>): void {
    const scoreTrend = getScoreTrendSummary(history);
    if (scoreTrend) {
        items.push(new OverviewItem('Trends', scoreTrend, 'saropaLints.focusIssues', 'graph-line'));
        return;
    }
    const trend = getTrendSummary(history);
    if (trend) {
        items.push(new OverviewItem('Trends', trend, 'saropaLints.focusIssues', 'graph-line'));
    }
}

function appendRegressionAndMilestone(
    items: OverviewItem[],
    history: ReturnType<typeof loadHistory>,
    data: ViolationsData,
): void {
    const regression = detectScoreRegression(history);
    if (regression) {
        const criticalCount = data.summary?.byImpact?.critical ?? 0;
        const plural = criticalCount === 1 ? '' : 's';
        const regDesc = criticalCount > 0
            ? `${criticalCount} critical violation${plural}`
            : 'View issues';
        items.push(new OverviewItem(
            `Score dropped ${regression.previousScore} \u2192 ${regression.currentScore}`,
            regDesc,
            'saropaLints.focusIssues',
            'arrow-down',
            new vscode.ThemeColor('list.errorForeground'),
        ));
    }

    if (history.length < 2) return;
    const prev = history.at(-2)!;
    const curr = history.at(-1)!;
    const violationDelta = prev.total - curr.total;
    if (violationDelta > 0) {
        items.push(
            new OverviewItem(
                `\u2193 ${violationDelta} fewer issues`,
                'since last run',
                'saropaLints.focusIssues',
                'star-full',
                new vscode.ThemeColor('testing.iconPassed'),
            ),
        );
    }
}

function buildDashboardItems(workspaceState: vscode.Memento, data: ViolationsData): OverviewItem[] {
    const items: OverviewItem[] = [];
    const history = loadHistory(workspaceState);
    const total = data.summary?.totalViolations ?? data.violations?.length ?? 0;
    const critical = data.summary?.byImpact?.critical ?? 0;

    appendHealthRow(items, history, data, total);
    appendViolationCountRow(items, total, critical);
    appendTrendRow(items, history);
    appendRegressionAndMilestone(items, history, data);

    const lastEntry = history.at(-1);
    if (lastEntry) {
        items.push(
            new OverviewItem('Last run', formatTimeAgo(lastEntry.timestamp), 'saropaLints.runAnalysis', 'history'),
        );
    }

    return items;
}

function isConfigTreeNode(node: OverviewTreeNode): node is ConfigTreeNode {
    if (typeof node !== 'object' || node === null || !('kind' in node)) {
        return false;
    }
    const k = (node as { kind: unknown }).kind;
    return typeof k === 'string' && OVERVIEW_EMBEDDED_CONFIG_KINDS.has(k);
}

export type OverviewTreeNode =
    | OverviewItem
    | OverviewSettingsParent
    | OverviewIssuesParent
    | OverviewSidebarSectionParent
    | OverviewSidebarToggleItem
    | ConfigTreeNode;

export type SidebarSectionCountGetter = () => ReadonlyMap<string, number | undefined>;

export class OverviewTreeProvider implements vscode.TreeDataProvider<OverviewTreeNode> {
    private readonly _onDidChangeTreeData = new vscode.EventEmitter<OverviewTreeNode | undefined | void>();
    readonly onDidChangeTreeData = this._onDidChangeTreeData.event;

    constructor(
        private readonly workspaceState: vscode.Memento,
        private readonly getSectionCounts: SidebarSectionCountGetter = () => new Map(),
        private readonly configProvider: ConfigTreeProvider,
    ) {}

    refresh(): void {
        this._onDidChangeTreeData.fire();
    }

    getTreeItem(element: OverviewTreeNode): vscode.TreeItem {
        if (isConfigTreeNode(element)) {
            return renderTreeItem(element);
        }
        return element;
    }

    async getChildren(element?: OverviewTreeNode): Promise<OverviewTreeNode[]> {
        const cfg = vscode.workspace.getConfiguration('saropaLints');

        if (element instanceof OverviewSettingsParent) {
            return this.configProvider.getSettingAndActionNodes();
        }
        if (element instanceof OverviewIssuesParent) {
            return this.configProvider.getTriageNodes();
        }
        if (element !== undefined && isConfigTreeNode(element)) {
            return this.configProvider.getChildren(element);
        }
        if (element instanceof OverviewSidebarSectionParent) {
            return buildSidebarToggleItems(cfg, this.workspaceState, this.getSectionCounts());
        }
        if (element !== undefined) {
            return [];
        }

        const root = getProjectRoot();
        if (!root) {
            return [];
        }

        const enabled = cfg.get<boolean>('enabled', true) ?? true;
        const intro = buildOverviewIntroItems();
        const integrationOff: OverviewItem[] = [];
        if (!enabled) {
            integrationOff.push(
                new OverviewItem(
                    'Lint integration: Off',
                    'Set up pubspec + analysis_options',
                    'saropaLints.enable',
                    'warning',
                    new vscode.ThemeColor('list.warningForeground'),
                ),
            );
        }
        const settingsParent = new OverviewSettingsParent();
        const issuesParent = new OverviewIssuesParent();
        const sidebarParent = new OverviewSidebarSectionParent();
        const data = readViolations(root);

        // Only show "Issues" section when triage data exists.
        const hasIssues = this.configProvider.getTriageNodes().length > 0;

        if (data === null) {
            const items: OverviewTreeNode[] = [
                ...intro,
                ...integrationOff,
                settingsParent,
            ];
            if (hasIssues) items.push(issuesParent);
            items.push(
                sidebarParent,
                new OverviewItem(
                    'No analysis yet',
                    'Run analysis to populate the dashboard',
                    'saropaLints.runAnalysis',
                    'beaker',
                ),
            );
            return items;
        }

        const items: OverviewTreeNode[] = [
            ...intro,
            ...integrationOff,
            settingsParent,
        ];
        if (hasIssues) items.push(issuesParent);
        items.push(sidebarParent, ...buildDashboardItems(this.workspaceState, data));
        return items;
    }
}
