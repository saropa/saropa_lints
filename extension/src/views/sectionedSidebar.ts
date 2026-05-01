/**
 * # Saropa Lints sidebar — sectioned multi-view layout
 *
 * The Saropa activity-bar container hosts **multiple separate views** stacked
 * vertically. Each view is its own collapsible panel (its title bar is the
 * collapse handle), and the rows inside every view are flat clickable leaves
 * — never `CollapsibleState.Collapsed` / `Expanded`. That is the only way to
 * get "expander panels for grouping" in VS Code without rendering chevrons
 * next to individual rows (which is what a TreeView with collapsible items
 * looks like).
 *
 * View contents:
 *   - **Banner**          — setup banner / lint integration off (auto-hides)
 *   - **Editor dashboards** — open Saropa editor-tab dashboards
 *   - **Actions**         — run analyzer, open config, scaffold composite plugin
 *   - **Status**          — health / violations / suppressions / trends / last run
 *   - **Settings**        — lint integration toggle, tier selector, etc.
 *   - **Triage**          — rules grouped by violation count and override status
 *   - **Help**            — walkthrough, About, pub.dev, AI agent template
 *
 * Each section reads the same upstream data (violations.json, pubspec, history)
 * but renders its own slice. Visibility is gated by `when` clauses on each
 * view in `package.json` so empty sections do not pollute the sidebar.
 */

import * as vscode from 'vscode';
import { readViolations, filterDisabledFromData, type ViolationsData } from '../violationsReader';
import { loadHistory, getTrendSummary, getScoreTrendSummary, findPreviousScore, detectScoreRegression } from '../runHistory';
import { computeHealthScore, formatScoreDelta } from '../healthScore';
import { getProjectRoot } from '../projectRoot';
import { hasSaropaLintsDep } from '../pubspecReader';
import { readDisabledRules } from '../configWriter';
import type { ConfigTreeProvider } from './configTree';
import type { ConfigTreeNode } from './triageTree';
import { renderTreeItem } from './triageTree';
import { OVERVIEW_EMBEDDED_CONFIG_KINDS } from '../overviewEmbeddedConfigKinds';
import { loadSuppressions, isPathHidden, isRuleHidden } from '../suppressionsStore';
import {
    SecurityHotspotReviewStateService,
    countSecurityHotspotReviewStates,
} from '../securityHotspotReviewState';

export type SectionNode = vscode.TreeItem | ConfigTreeNode;

/** Format an ISO timestamp as a human-readable relative time. */
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

/**
 * Single sidebar row. Always a leaf — `CollapsibleState.None` so VS Code
 * does NOT render a chevron next to it. The view's panel title bar is the
 * only collapse handle.
 */
class LeafItem extends vscode.TreeItem {
    constructor(
        label: string,
        description: string | undefined,
        commandId: string | undefined,
        iconId?: string,
        iconColor?: vscode.ThemeColor,
        commandArgs?: unknown[],
    ) {
        super(label, vscode.TreeItemCollapsibleState.None);
        this.description = description;
        if (commandId) {
            this.command = { command: commandId, title: label, arguments: commandArgs ?? [] };
        }
        this.contextValue = 'saropaSidebarLeaf';
        if (iconId) {
            this.iconPath = new vscode.ThemeIcon(iconId, iconColor);
        }
    }
}

// ── Filtered violation cache (shared across status view) ───────────────────

let _cachedFiltered: { data: ViolationsData; root: string } | null | undefined;

function loadFilteredViolations(
    workspaceState: vscode.Memento,
): { data: ViolationsData; root: string } | null {
    if (_cachedFiltered !== undefined) return _cachedFiltered;

    const root = getProjectRoot();
    if (!root) {
        _cachedFiltered = null;
        return null;
    }
    const raw = readViolations(root);
    if (!raw) {
        _cachedFiltered = null;
        return null;
    }

    const disabled = readDisabledRules(root);
    const afterDisabled = filterDisabledFromData(raw, disabled);
    const suppressions = loadSuppressions(workspaceState);

    const filtered = afterDisabled.violations.filter((v) => {
        if (isPathHidden(suppressions, v.file)) return false;
        if (isRuleHidden(suppressions, v.file, v.rule)) return false;
        const severity = (v.severity ?? 'info').toLowerCase();
        if (suppressions.hiddenSeverities.includes(severity)) return false;
        const impact = (v.impact ?? 'low').toLowerCase();
        if (suppressions.hiddenImpacts.includes(impact)) return false;
        return true;
    });

    const data: ViolationsData = {
        ...afterDisabled,
        violations: filtered,
        summary: rebuildSummary(afterDisabled, filtered),
    };

    _cachedFiltered = { data, root };
    return _cachedFiltered;
}

function rebuildSummary(
    original: ViolationsData,
    filtered: ViolationsData['violations'],
): ViolationsData['summary'] {
    const s = original.summary;
    const bySeverity: Record<string, number> = {};
    const byImpact: Record<string, number> = {};
    for (const v of filtered) {
        const sev = (v.severity ?? 'info').toLowerCase();
        bySeverity[sev] = (bySeverity[sev] ?? 0) + 1;
        const imp = (v.impact ?? 'low').toLowerCase();
        byImpact[imp] = (byImpact[imp] ?? 0) + 1;
    }
    return {
        ...s,
        totalViolations: filtered.length,
        bySeverity: {
            error: bySeverity['error'] ?? 0,
            warning: bySeverity['warning'] ?? 0,
            info: bySeverity['info'] ?? 0,
        },
        byImpact: {
            critical: byImpact['critical'] ?? 0,
            high: byImpact['high'] ?? 0,
            medium: byImpact['medium'] ?? 0,
            low: byImpact['low'] ?? 0,
            opinionated: byImpact['opinionated'] ?? 0,
        },
    };
}

/** Clear the filtered-violations cache — call from each provider's `refresh()`. */
function invalidateSharedCache(): void {
    _cachedFiltered = undefined;
}

// ── Per-view item builders ────────────────────────────────────────────────

function buildBannerItems(): LeafItem[] {
    const root = getProjectRoot();
    if (!root) return [];
    const cfg = vscode.workspace.getConfiguration('saropaLints');
    const enabled = cfg.get<boolean>('enabled', true) ?? true;

    if (!hasSaropaLintsDep(root)) {
        return [new LeafItem(
            'Set Up Project',
            'Add saropa_lints to pubspec + configure analysis',
            'saropaLints.enable',
            'rocket',
            new vscode.ThemeColor('list.warningForeground'),
        )];
    }
    if (!enabled) {
        return [new LeafItem(
            'Lint integration: Off',
            'Set up pubspec + analysis_options',
            'saropaLints.enable',
            'warning',
            new vscode.ThemeColor('list.warningForeground'),
        )];
    }
    return [];
}

function buildEditorDashboardItems(): LeafItem[] {
    return [
        new LeafItem(
            'Lints Config',
            'Tiers, rule packs, SDK rollout',
            'saropaLints.openConfigDashboard',
            'settings-gear',
            new vscode.ThemeColor('activityBarBadge.foreground'),
        ),
        new LeafItem(
            'Package Dashboard',
            'Dependency vibrancy report',
            'saropaLints.packageVibrancy.showReport',
            'package',
            new vscode.ThemeColor('charts.green'),
        ),
        new LeafItem(
            'Code Health Dashboard',
            'Function-level code health',
            'saropaLints.openProjectVibrancyReport',
            'symbol-method',
            new vscode.ThemeColor('charts.purple'),
        ),
        new LeafItem(
            'Findings Dashboard',
            'Editor tab · filters · JSON',
            'saropaLints.openViolationsWideReport',
            'warning',
            new vscode.ThemeColor('editorWarning.foreground'),
        ),
        new LeafItem(
            'Command Catalog',
            'Search all commands',
            'saropaLints.showCommandCatalog',
            'symbol-event',
            new vscode.ThemeColor('charts.purple'),
        ),
    ];
}

function buildActionItems(): LeafItem[] {
    return [
        new LeafItem(
            'Run analysis',
            'Re-run analyzer',
            'saropaLints.runAnalysis',
            'play',
            new vscode.ThemeColor('debugIcon.startForeground'),
        ),
        new LeafItem(
            'Open Findings Dashboard',
            'Editor tab · filters · JSON',
            'saropaLints.revealFindingsDashboard',
            'list-tree',
            new vscode.ThemeColor('textLink.foreground'),
        ),
        new LeafItem(
            'Initialize / Update config',
            undefined,
            'saropaLints.initializeConfig',
            'gear',
        ),
        // `Open analysis_options_custom.yaml` was intentionally REMOVED from the
        // sidebar. The generated file carries a "DO NOT EDIT MANUALLY — use the
        // Saropa Lints VS Code extension" banner, so a sidebar row pointing
        // straight to it directly contradicted that guidance. Users who genuinely
        // need to view the file have the command palette (`Saropa Lints: Open
        // Analysis Options`); rule overrides are now managed graphically in the
        // Lints Config dashboard's Disabled rules section.
        //
        // Composite analyzer plugin scaffold is also intentionally NOT exposed
        // here. The action targets a tiny audience (teams shipping their own
        // custom analyzer rules alongside Saropa) and the term is jargon to
        // everyone else. It remains discoverable via the command palette,
        // the command catalog, the CLI flag, and the guide.
    ];
}

function buildHelpItems(): LeafItem[] {
    return [
        new LeafItem('Getting Started', 'Walkthrough', 'saropaLints.openWalkthrough', 'compass'),
        new LeafItem('About Saropa Lints', 'Documentation', 'saropaLints.showAbout', 'book'),
        new LeafItem(
            'Package on pub.dev',
            'saropa_lints',
            'saropaLints.openPubDevSaropaLints',
            'link-external',
            new vscode.ThemeColor('textLink.foreground'),
        ),
        new LeafItem(
            'Create AI agent instructions',
            '.cursor/rules template',
            'saropaLints.createSaropaInstructions',
            'sparkle',
        ),
    ];
}

// ── Status section builders ───────────────────────────────────────────────

function healthScoreDescription(delta: string, total: number): string {
    if (delta) return `${delta} from last run`;
    if (total === 0) return 'No violations';
    return `${total} violations`;
}

function appendHealthRow(
    items: LeafItem[],
    history: ReturnType<typeof loadHistory>,
    data: ViolationsData,
    total: number,
): void {
    const health = computeHealthScore(data);
    if (!health) return;
    const prevScore = findPreviousScore(history);
    const delta = prevScore !== undefined ? formatScoreDelta(health.score, prevScore) : '';
    items.push(new LeafItem(
        `Health: ${health.score}`,
        healthScoreDescription(delta, total),
        'saropaLints.focusIssues',
        'pulse',
    ));
}

function appendViolationCountRow(items: LeafItem[], total: number, critical: number): void {
    if (total > 0) {
        const issueLabel = critical > 0
            ? `${critical} critical, ${total} total`
            : `${total} violations`;
        items.push(new LeafItem(
            issueLabel, 'View in Findings', 'saropaLints.focusIssues',
            'warning', new vscode.ThemeColor('list.warningForeground'),
        ));
        return;
    }
    items.push(new LeafItem(
        'No violations', 'All clear', 'saropaLints.focusIssues',
        'pass', new vscode.ThemeColor('testing.iconPassed'),
    ));
}

function appendSuppressionRow(items: LeafItem[], data: ViolationsData): void {
    const sup = data.summary?.suppressions;
    const total = sup?.total ?? 0;
    if (total <= 0) return;
    const violationsTotal = data.summary?.totalViolations ?? data.violations?.length ?? 0;
    const denominator = violationsTotal + total;
    const rate = denominator > 0 ? Math.round((total / denominator) * 1000) / 10 : 0;

    const parts: string[] = [];
    const byKind = sup?.byKind;
    if (byKind?.ignore) parts.push(`${byKind.ignore} ignore`);
    if (byKind?.ignoreForFile) parts.push(`${byKind.ignoreForFile} file-level`);
    if (byKind?.baseline) parts.push(`${byKind.baseline} baseline`);
    if (denominator > 0) parts.push(`${rate}% suppression rate`);
    const desc = parts.length > 0 ? parts.join(', ') : 'View details';

    items.push(new LeafItem(
        `${total} suppressed`, desc,
        'saropaLints.focusIssues', 'eye-closed',
    ));
}

function appendTrendRow(items: LeafItem[], history: ReturnType<typeof loadHistory>): void {
    const scoreTrend = getScoreTrendSummary(history);
    if (scoreTrend) {
        items.push(new LeafItem('Trends', scoreTrend, 'saropaLints.focusIssues', 'graph-line'));
        return;
    }
    const trend = getTrendSummary(history);
    if (trend) {
        items.push(new LeafItem('Trends', trend, 'saropaLints.focusIssues', 'graph-line'));
    }
}

function appendRegressionAndMilestone(
    items: LeafItem[],
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
        items.push(new LeafItem(
            `Score dropped ${regression.previousScore} → ${regression.currentScore}`,
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
        items.push(new LeafItem(
            `↓ ${violationDelta} fewer issues`,
            'since last run',
            'saropaLints.focusIssues',
            'star-full',
            new vscode.ThemeColor('testing.iconPassed'),
        ));
    }
}

function buildStatusItems(workspaceState: vscode.Memento): SectionNode[] {
    const loaded = loadFilteredViolations(workspaceState);
    if (!loaded) return [];
    const { data } = loaded;

    const items: LeafItem[] = [];
    const history = loadHistory(workspaceState);
    const total = data.summary?.totalViolations ?? data.violations?.length ?? 0;
    const critical = data.summary?.byImpact?.critical ?? 0;
    const hotspotReviewState = new SecurityHotspotReviewStateService(workspaceState);
    const hotspotCounts = countSecurityHotspotReviewStates(
        data.violations ?? [],
        data.config?.ruleMetadataByRule,
        hotspotReviewState,
    );

    appendHealthRow(items, history, data, total);
    appendViolationCountRow(items, total, critical);
    if (hotspotCounts.total > 0) {
        const reviewed = hotspotCounts.reviewedSafe + hotspotCounts.reviewedFixed;
        const percent = Math.round((reviewed / hotspotCounts.total) * 100);
        items.push(new LeafItem(
            `Hotspots: ${percent}% reviewed`,
            `${hotspotCounts.open} open, ${hotspotCounts.reviewedSafe} safe, ${hotspotCounts.reviewedFixed} fixed`,
            'saropaLints.reviewHotspotState',
            'shield',
        ));
    }
    appendSuppressionRow(items, data);
    appendTrendRow(items, history);
    appendRegressionAndMilestone(items, history, data);

    const lastEntry = history.at(-1);
    if (lastEntry) {
        items.push(new LeafItem(
            'Last run',
            formatTimeAgo(lastEntry.timestamp),
            'saropaLints.runAnalysis',
            'history',
        ));
    }
    return items;
}

// ── ConfigTreeProvider-backed sections (Settings + Triage) ─────────────────

function isConfigTreeNode(node: unknown): node is ConfigTreeNode {
    if (typeof node !== 'object' || node === null || !('kind' in node)) return false;
    const k = (node as { kind: unknown }).kind;
    return typeof k === 'string' && OVERVIEW_EMBEDDED_CONFIG_KINDS.has(k);
}

/**
 * Filter out settings nodes that duplicate top-level Actions / Editor dashboard
 * rows. ConfigTreeProvider stays the source of truth for live settings rows;
 * this view drops the redundant copies so each command has exactly one entry
 * in the sidebar.
 */
function isRedundantSettingsAction(node: ConfigTreeNode): boolean {
    if (node.kind !== 'configSetting') return false;
    const cmd = node.commandId;
    return cmd === 'saropaLints.runAnalysis'
        || cmd === 'saropaLints.openConfig'
        || cmd === 'saropaLints.initializeConfig'
        || cmd === 'saropaLints.emitCompositePluginScaffold';
}

function buildSettingsItems(configProvider: ConfigTreeProvider): SectionNode[] {
    return configProvider
        .getSettingAndActionNodes()
        .filter((n) => !isRedundantSettingsAction(n));
}

function buildTriageItems(configProvider: ConfigTreeProvider): SectionNode[] {
    // Triage groups themselves carry collapsibleState in renderTreeItem; we
    // override to None so no chevron renders inside the panel.
    return configProvider.getTriageNodes();
}

// ── Provider class ────────────────────────────────────────────────────────

/**
 * One TreeDataProvider per visible section. Each instance returns a flat
 * list of leaves at the root and nothing else — the panel title bar is the
 * collapse handle, NOT a tree node. `force-flat` rule:
 * `getChildren(element)` for any non-undefined `element` always returns `[]`.
 */
export class FlatSectionProvider implements vscode.TreeDataProvider<SectionNode> {
    private readonly _onDidChangeTreeData = new vscode.EventEmitter<SectionNode | undefined | void>();
    readonly onDidChangeTreeData = this._onDidChangeTreeData.event;

    constructor(
        public readonly viewId: string,
        private readonly buildItems: () => SectionNode[],
    ) {}

    refresh(): void {
        invalidateSharedCache();
        this._onDidChangeTreeData.fire();
    }

    getTreeItem(element: SectionNode): vscode.TreeItem {
        if (isConfigTreeNode(element)) {
            const item = renderTreeItem(element);
            // Force leaf rendering — no chevrons inside any panel, ever.
            item.collapsibleState = vscode.TreeItemCollapsibleState.None;
            return item;
        }
        return element;
    }

    getChildren(element?: SectionNode): SectionNode[] {
        if (element !== undefined) return [];
        return this.buildItems();
    }
}

// ── Section identifiers + factories ───────────────────────────────────────

/** Stable view IDs registered in package.json. Keep in sync with `contributes.views.saropaLints`. */
export const SECTION_VIEW_IDS = {
    banner: 'saropaLints.banner',
    editorDashboards: 'saropaLints.editorDashboards',
    actions: 'saropaLints.actions',
    status: 'saropaLints.status',
    settings: 'saropaLints.settings',
    triage: 'saropaLints.triage',
    help: 'saropaLints.help',
} as const;

/**
 * Build all six section providers wired to the shared dependencies.
 *
 * Returned in render order (top → bottom in the activity bar). The caller
 * is responsible for `vscode.window.createTreeView(viewId, { treeDataProvider })`
 * for each one and for invoking `refresh()` on every relevant provider when
 * upstream data changes.
 */
export function createSidebarSectionProviders(
    workspaceState: vscode.Memento,
    configProvider: ConfigTreeProvider,
): FlatSectionProvider[] {
    return [
        new FlatSectionProvider(SECTION_VIEW_IDS.banner, () => buildBannerItems()),
        new FlatSectionProvider(SECTION_VIEW_IDS.editorDashboards, () => buildEditorDashboardItems()),
        new FlatSectionProvider(SECTION_VIEW_IDS.actions, () => buildActionItems()),
        new FlatSectionProvider(SECTION_VIEW_IDS.status, () => buildStatusItems(workspaceState)),
        new FlatSectionProvider(SECTION_VIEW_IDS.settings, () => buildSettingsItems(configProvider)),
        new FlatSectionProvider(SECTION_VIEW_IDS.triage, () => buildTriageItems(configProvider)),
        new FlatSectionProvider(SECTION_VIEW_IDS.help, () => buildHelpItems()),
    ];
}

/**
 * Compute and push the context keys gating each section view's visibility.
 * Call this whenever the underlying data (violations / pubspec / triage)
 * changes; the values feed each view's `when` clause in `package.json`.
 */
export function updateSidebarSectionContext(workspaceState: vscode.Memento): void {
    const root = getProjectRoot();
    if (!root) {
        void vscode.commands.executeCommand('setContext', 'saropaLints.needsBanner', false);
        void vscode.commands.executeCommand('setContext', 'saropaLints.hasTriage', false);
        return;
    }
    const cfg = vscode.workspace.getConfiguration('saropaLints');
    const enabled = cfg.get<boolean>('enabled', true) ?? true;
    const needsBanner = !hasSaropaLintsDep(root) || !enabled;
    void vscode.commands.executeCommand('setContext', 'saropaLints.needsBanner', needsBanner);

    // Triage view shown only when ConfigTreeProvider would actually return rows.
    // Cheap proxy: violations.json must exist; ConfigTreeProvider does its own
    // freshness/completeness checks downstream when assembling the rows.
    const hasViolations = readViolations(root) !== null;
    void vscode.commands.executeCommand('setContext', 'saropaLints.hasTriage', hasViolations);
    invalidateSharedCache();
}
