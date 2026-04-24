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
 * - **Dart workspace:** always returns a **Help & resources** group (intro links), **Settings** (embedded config),
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
import * as path from 'node:path';
import * as fs from 'node:fs';
import { readViolations, filterDisabledFromData, type ViolationsData } from '../violationsReader';
import { loadHistory, getTrendSummary, getScoreTrendSummary, findPreviousScore, detectScoreRegression } from '../runHistory';
import { computeHealthScore, formatScoreDelta, estimateScoreWithout } from '../healthScore';
import { getProjectRoot } from '../projectRoot';
import { hasSaropaLintsDep } from '../pubspecReader';
import { readDisabledRules } from '../configWriter';
import type { ConfigTreeProvider } from './configTree';
import type { ConfigTreeNode } from './triageTree';
import { renderTreeItem } from './triageTree';
import { OVERVIEW_EMBEDDED_CONFIG_KINDS } from '../overviewEmbeddedConfigKinds';
import {
    OverviewSidebarSectionParent,
    OverviewSidebarToggleItem,
    buildSidebarToggleItems,
} from './overviewSidebarTree';
import { buildFileRisks } from './fileRiskTree';
import { loadSuppressions, isPathHidden, isRuleHidden } from '../suppressionsStore';

const OVERVIEW_INTRO_TOOLTIP =
    'Saropa Lints provides 2100+ Dart and Flutter lint rules for security, accessibility, and performance. '
    + 'It has two components: a pub.dev package with the rules and a VS Code extension for visual analysis and configuration.';

/** Collapsible group for onboarding and documentation links (always first when the tree has content). */
export class OverviewHelpParent extends vscode.TreeItem {
    constructor() {
        super('Help & resources', vscode.TreeItemCollapsibleState.Expanded);
        this.contextValue = 'overviewHelpSection';
        this.iconPath = new vscode.ThemeIcon('question');
        this.tooltip = 'Walkthrough, About, commands, and pub.dev';
    }
}

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

/** Collapsible group: health summary (tier, counts, severity/impact breakdown). */
export class OverviewSummaryParent extends vscode.TreeItem {
    constructor() {
        super('Health Summary', vscode.TreeItemCollapsibleState.Collapsed);
        this.contextValue = 'overviewSummarySection';
        this.iconPath = new vscode.ThemeIcon('dashboard');
        this.tooltip = 'Tier, file counts, and violation breakdown by severity and impact';
    }
}

/** Collapsible group: prioritized next steps (what to fix first). */
export class OverviewSuggestionsParent extends vscode.TreeItem {
    constructor() {
        super('Next Steps', vscode.TreeItemCollapsibleState.Collapsed);
        this.contextValue = 'overviewSuggestionsSection';
        this.iconPath = new vscode.ThemeIcon('lightbulb');
        this.tooltip = 'Prioritized actions — what to fix next and estimated score impact';
    }
}

/** Collapsible group: riskiest files (top files by weighted violation density). */
export class OverviewRiskParent extends vscode.TreeItem {
    constructor() {
        super('Riskiest Files', vscode.TreeItemCollapsibleState.Collapsed);
        this.contextValue = 'overviewRiskSection';
        this.iconPath = new vscode.ThemeIcon('flame');
        this.tooltip = 'Files ranked by violation severity — where to focus first';
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
        commandArgs?: unknown[],
    ) {
        super(label, vscode.TreeItemCollapsibleState.None);
        this.description = description;
        if (commandId) {
            this.command = { command: commandId, title: label, arguments: commandArgs ?? [] };
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

function appendSuppressionRow(items: OverviewItem[], data: ViolationsData): void {
    const sup = data.summary?.suppressions;
    const total = sup?.total ?? 0;
    if (total <= 0) return;

    // Build a short breakdown description, e.g. "5 ignore, 3 file-level, 2 baseline"
    const parts: string[] = [];
    const byKind = sup?.byKind;
    if (byKind?.ignore) parts.push(`${byKind.ignore} ignore`);
    if (byKind?.ignoreForFile) parts.push(`${byKind.ignoreForFile} file-level`);
    if (byKind?.baseline) parts.push(`${byKind.baseline} baseline`);
    const desc = parts.length > 0 ? parts.join(', ') : 'View details';

    items.push(
        new OverviewItem(
            `${total} suppressed`, desc,
            'saropaLints.focusIssues', 'eye-closed',
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
    appendSuppressionRow(items, data);
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

// ── Embedded group builders ─────────────────────────────────────────────────
//
// These mirror the data from the standalone Summary, Suggestions, and File Risk
// providers but render as OverviewItem instances so they live inside the
// Overview tree without type-system coupling to other providers.

/** Max files to show in the embedded "Riskiest Files" group. */
const EMBEDDED_RISK_MAX = 10;

/** Cached result from loadFilteredViolations — cleared on each refresh(). */
let _cachedFiltered: { data: ViolationsData; root: string } | null | undefined;

/**
 * Load violations data filtered by disabled rules and view-level suppressions.
 * Result is cached until the next OverviewTreeProvider.refresh() call so all
 * three embedded groups (Summary, Suggestions, Risk) share one read.
 *
 * Applies the same suppression filtering as the standalone File Risk view
 * (path hiding, rule hiding, severity hiding, impact hiding) so the embedded
 * groups stay consistent with the standalone views.
 */
function loadFilteredViolations(
    workspaceState: vscode.Memento,
): { data: ViolationsData; root: string } | null {
    // Return cached result if available (set to undefined on refresh).
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

    // Filter disabled rules (analysis_options.yaml) then view-level suppressions.
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

    // Rebuild summary counts to match filtered violations.
    const data: ViolationsData = {
        ...afterDisabled,
        violations: filtered,
        summary: rebuildSummary(afterDisabled, filtered),
    };

    _cachedFiltered = { data, root };
    return _cachedFiltered;
}

/**
 * Rebuild the summary section to reflect a filtered violation set.
 * Preserves config, tier, and file-count fields from the original summary;
 * recomputes severity/impact/total counts from the filtered violations.
 */
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

/** Clear the cached filtered violations — call from refresh(). */
function invalidateEmbeddedCache(): void {
    _cachedFiltered = undefined;
}

/**
 * Health Summary: tier, file counts, severity/impact breakdown.
 * Mirrors summaryTree.ts logic but renders as OverviewItems.
 */
function buildEmbeddedSummaryItems(workspaceState: vscode.Memento): OverviewItem[] {
    const loaded = loadFilteredViolations(workspaceState);
    if (!loaded) return [];
    const { data } = loaded;
    const s = data.summary;
    const c = data.config;
    const total = s?.totalViolations ?? data.violations.length;

    const items: OverviewItem[] = [
        new OverviewItem('Total violations', String(total), 'saropaLints.focusIssues', 'symbol-number'),
        new OverviewItem('Tier', c?.tier ?? '—', undefined, 'shield'),
    ];
    if (s?.filesAnalyzed != null) {
        items.push(new OverviewItem('Files analyzed', String(s.filesAnalyzed), undefined, 'file'));
    }
    if (s?.filesWithIssues != null) {
        items.push(new OverviewItem('Files with violations', String(s.filesWithIssues), undefined, 'file'));
    }

    // Suppression count — shows how many diagnostics were silenced by
    // ignore comments or the baseline so teams can track tech debt.
    const supTotal = s?.suppressions?.total ?? 0;
    if (supTotal > 0) {
        const ruleCount = Object.keys(s?.suppressions?.byRule ?? {}).length;
        const fileCount = Object.keys(s?.suppressions?.byFile ?? {}).length;
        // e.g. "across 5 rules in 3 files"
        const detail = ruleCount > 0
            ? `across ${ruleCount} rule${ruleCount === 1 ? '' : 's'} in ${fileCount} file${fileCount === 1 ? '' : 's'}`
            : undefined;
        items.push(new OverviewItem('Suppressed', `${supTotal}${detail ? ` — ${detail}` : ''}`, undefined, 'eye-closed'));
    }

    // Severity breakdown — each item filters the Violations view.
    if (s?.bySeverity) {
        const sev = s.bySeverity;
        if (sev.error) {
            items.push(new OverviewItem(
                `Errors: ${sev.error}`, 'Click to filter',
                'saropaLints.focusIssuesWithSeverityFilter', 'error',
                undefined, ['error'],
            ));
        }
        if (sev.warning) {
            items.push(new OverviewItem(
                `Warnings: ${sev.warning}`, 'Click to filter',
                'saropaLints.focusIssuesWithSeverityFilter', 'warning',
                undefined, ['warning'],
            ));
        }
        if (sev.info) {
            items.push(new OverviewItem(
                `Info: ${sev.info}`, 'Click to filter',
                'saropaLints.focusIssuesWithSeverityFilter', 'info',
                undefined, ['info'],
            ));
        }
    }

    // Impact breakdown — each item filters the Violations view.
    if (s?.byImpact) {
        const bi = s.byImpact;
        if (bi.critical) {
            items.push(new OverviewItem(
                `Critical: ${bi.critical}`, 'Click to filter',
                'saropaLints.focusIssuesWithImpactFilter', 'flame',
                new vscode.ThemeColor('list.errorForeground'), ['critical'],
            ));
        }
        if (bi.high) {
            items.push(new OverviewItem(
                `High: ${bi.high}`, 'Click to filter',
                'saropaLints.focusIssuesWithImpactFilter', 'warning',
                new vscode.ThemeColor('list.warningForeground'), ['high'],
            ));
        }
    }
    return items;
}

/**
 * Next Steps: prioritized actions with estimated score impact.
 * Mirrors suggestionsTree.ts logic but renders as OverviewItems.
 */
function buildEmbeddedSuggestionItems(workspaceState: vscode.Memento): OverviewItem[] {
    const loaded = loadFilteredViolations(workspaceState);
    if (!loaded) return [];
    const { data, root } = loaded;
    const byImpact = data.summary?.byImpact;
    const bySeverity = data.summary?.bySeverity;
    const total = data.summary?.totalViolations ?? data.violations.length;
    const critical = byImpact?.critical ?? 0;
    const high = byImpact?.high ?? 0;
    const errors = bySeverity?.error ?? 0;

    const currentScore = computeHealthScore(data)?.score;
    const items: OverviewItem[] = [];

    if (critical > 0) {
        const projected = estimateScoreWithout(data, 'critical');
        const gain = (currentScore !== undefined && projected !== null)
            ? projected - currentScore : null;
        const desc = (gain !== null && gain > 0)
            ? `estimated +${gain} points` : 'Show in Issues';
        items.push(new OverviewItem(
            `Fix ${critical} critical issue(s)`, desc,
            'saropaLints.focusIssuesWithImpactFilter', 'flame',
            new vscode.ThemeColor('list.errorForeground'), ['critical'],
        ));
    }
    if (high > 0 && items.length < 3) {
        const projected = estimateScoreWithout(data, 'high');
        const gain = (currentScore !== undefined && projected !== null)
            ? projected - currentScore : null;
        const desc = (gain !== null && gain > 0)
            ? `estimated +${gain} points` : 'Show in Issues';
        items.push(new OverviewItem(
            `Address ${high} high-impact issue(s)`, desc,
            'saropaLints.focusIssuesWithImpactFilter', 'warning',
            new vscode.ThemeColor('list.warningForeground'), ['high'],
        ));
    }
    if (errors > 0 && !items.some((i) => String(i.label).includes('error'))) {
        items.push(new OverviewItem(
            `Fix ${errors} analyzer error(s)`, 'Show in Issues',
            'saropaLints.focusIssuesWithSeverityFilter', 'error',
            undefined, ['error'],
        ));
    }

    // Baseline suggestion — only if no baseline file exists.
    const baselinePath = path.join(root, 'saropa_baseline.json');
    if (total > 0 && !fs.existsSync(baselinePath)) {
        items.push(new OverviewItem(
            'Create baseline', 'Suppress existing, check new code',
            'saropaLints.openConfig', 'new-file',
        ));
    }

    return items.slice(0, 6);
}

/**
 * Riskiest Files: top N files by severity-weighted violation density.
 * Compact version of fileRiskTree.ts — shows fewer files with simpler rendering.
 */
function buildEmbeddedRiskItems(workspaceState: vscode.Memento): OverviewItem[] {
    const loaded = loadFilteredViolations(workspaceState);
    if (!loaded) return [];
    const { data } = loaded;
    if (data.violations.length === 0) return [];

    const risks = buildFileRisks(data.violations);
    if (risks.length === 0) return [];

    const items: OverviewItem[] = [];
    for (const r of risks.slice(0, EMBEDDED_RISK_MAX)) {
        const base = path.basename(r.filePath);
        // Pick icon based on severity: flame for critical, warning for high, info otherwise.
        let iconId = 'info';
        let iconColor: vscode.ThemeColor | undefined;
        if (r.critical > 0) {
            iconId = 'flame';
            iconColor = new vscode.ThemeColor('list.errorForeground');
        } else if (r.high > 0) {
            iconId = 'warning';
            iconColor = new vscode.ThemeColor('list.warningForeground');
        }

        const parts: string[] = [`${r.total} violation${r.total === 1 ? '' : 's'}`];
        if (r.critical > 0) parts.push(`${r.critical} critical`);
        if (r.high > 0) parts.push(`${r.high} high`);

        items.push(new OverviewItem(
            base, parts.join(', '),
            'saropaLints.openFileAndFocusIssues', iconId, iconColor,
            [r.filePath],
        ));
    }

    // If there are more files than shown, add a "Show all" item that
    // enables the standalone File Risk sidebar section.
    if (risks.length > EMBEDDED_RISK_MAX) {
        items.push(new OverviewItem(
            `${risks.length - EMBEDDED_RISK_MAX} more files…`,
            'Open File Risk section',
            'saropaLints.toggleSidebarSection', 'ellipsis',
            undefined, ['sidebar.showFileRisk'],
        ));
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
    | OverviewHelpParent
    | OverviewSettingsParent
    | OverviewIssuesParent
    | OverviewSummaryParent
    | OverviewSuggestionsParent
    | OverviewRiskParent
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
        invalidateEmbeddedCache();
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

        if (element instanceof OverviewHelpParent) {
            return buildOverviewIntroItems();
        }
        if (element instanceof OverviewSettingsParent) {
            return this.configProvider.getSettingAndActionNodes();
        }
        if (element instanceof OverviewIssuesParent) {
            return this.configProvider.getTriageNodes();
        }
        if (element !== undefined && isConfigTreeNode(element)) {
            return this.configProvider.getChildren(element);
        }
        if (element instanceof OverviewSummaryParent) {
            return buildEmbeddedSummaryItems(this.workspaceState);
        }
        if (element instanceof OverviewSuggestionsParent) {
            return buildEmbeddedSuggestionItems(this.workspaceState);
        }
        if (element instanceof OverviewRiskParent) {
            return buildEmbeddedRiskItems(this.workspaceState);
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
        const helpParent = new OverviewHelpParent();

        // Prominent setup banner when saropa_lints is not yet in pubspec.yaml.
        // This is the primary onboarding affordance — it must be impossible to
        // miss so new users don't get stuck wondering why nothing works.
        const needsSetup = !hasSaropaLintsDep(root);
        const setupBanner: OverviewItem[] = [];
        if (needsSetup) {
            setupBanner.push(
                new OverviewItem(
                    'Set Up Project',
                    'Add saropa_lints to pubspec + configure analysis',
                    'saropaLints.enable',
                    'rocket',
                    new vscode.ThemeColor('list.warningForeground'),
                ),
            );
        }

        const integrationOff: OverviewItem[] = [];
        if (!enabled && !needsSetup) {
            // Only show the "integration off" row when the package is already
            // installed but the user explicitly disabled integration.
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
                ...setupBanner,
                helpParent,
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
            ...setupBanner,
            helpParent,
            ...integrationOff,
            settingsParent,
        ];
        if (hasIssues) items.push(issuesParent);
        items.push(sidebarParent, ...buildDashboardItems(this.workspaceState, data));

        // Embedded groups: surface Summary, Suggestions, and File Risk data
        // directly inside Overview so users discover them without enabling
        // standalone sidebar sections. Each group builds items on expand using
        // the same violations.json data the standalone views read.
        const total = data.summary?.totalViolations ?? data.violations?.length ?? 0;
        if (total > 0) {
            items.push(
                new OverviewSummaryParent(),
                new OverviewSuggestionsParent(),
                new OverviewRiskParent(),
            );
        }
        return items;
    }
}
