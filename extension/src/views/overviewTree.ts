/**
 * Tree data provider for Saropa Lints Overview (dashboard) view.
 * Shows Health Score as the primary number, then issues, trends, and links.
 * Includes a Sidebar group with toggles for each activity-bar section.
 */

import * as vscode from 'vscode';
import { readViolations, type ViolationsData } from '../violationsReader';
import { loadHistory, getTrendSummary, getScoreTrendSummary, findPreviousScore, detectScoreRegression } from '../runHistory';
import { computeHealthScore, formatScoreDelta } from '../healthScore';
import { getProjectRoot } from '../projectRoot';
import {
    OverviewSidebarSectionParent,
    OverviewSidebarToggleItem,
    buildSidebarToggleItems,
} from './overviewSidebarTree';

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
        commandId: string,
        iconId?: string,
        iconColor?: vscode.ThemeColor,
    ) {
        super(label, vscode.TreeItemCollapsibleState.None);
        this.description = description;
        this.command = { command: commandId, title: label, arguments: [] };
        this.contextValue = 'overviewItem';
        if (iconId) {
            this.iconPath = new vscode.ThemeIcon(iconId, iconColor);
        }
    }
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

export type OverviewTreeNode = OverviewItem | OverviewSidebarSectionParent | OverviewSidebarToggleItem;

export type SidebarSectionCountGetter = () => ReadonlyMap<string, number | undefined>;

export class OverviewTreeProvider implements vscode.TreeDataProvider<OverviewTreeNode> {
    private readonly _onDidChangeTreeData = new vscode.EventEmitter<OverviewTreeNode | undefined | void>();
    readonly onDidChangeTreeData = this._onDidChangeTreeData.event;

    constructor(
        private readonly workspaceState: vscode.Memento,
        private readonly getSectionCounts: SidebarSectionCountGetter = () => new Map(),
    ) {}

    refresh(): void {
        this._onDidChangeTreeData.fire();
    }

    getTreeItem(element: OverviewTreeNode): vscode.TreeItem {
        return element;
    }

    async getChildren(element?: OverviewTreeNode): Promise<OverviewTreeNode[]> {
        const cfg = vscode.workspace.getConfiguration('saropaLints');

        if (element instanceof OverviewSidebarSectionParent) {
            return buildSidebarToggleItems(cfg, this.workspaceState, this.getSectionCounts());
        }
        if (element !== undefined) {
            return [];
        }

        const enabled = cfg.get<boolean>('enabled', false) ?? false;
        if (!enabled) return [];

        const sidebarParent = new OverviewSidebarSectionParent();
        const root = getProjectRoot();
        const data = root ? readViolations(root) : null;

        if (data === null) {
            return [sidebarParent];
        }

        return [sidebarParent, ...buildDashboardItems(this.workspaceState, data)];
    }
}
