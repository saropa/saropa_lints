/**
 * # Saropa Lints sidebar — flat tree data provider
 *
 * Single sidebar view that renders **all** sidebar content as a flat list of rows
 * (no parent group headers). Replaced the previous Dashboards / Overview & options
 * split because those panels duplicated each other (Run analysis, Getting Started,
 * About, pub.dev, Findings Dashboard) and added an extra collapse layer for no
 * navigational benefit.
 *
 * ## Row order (top → bottom, conditional rows hide when not applicable)
 *
 * 1. **Setup banner** — `Set Up Project` row when `saropa_lints` is missing from
 *    `pubspec.yaml` (warning styling). Primary onboarding affordance.
 * 2. **Lint integration off banner** — when integration is disabled but pubspec is fine.
 * 3. **Editor dashboards** — opens editor-tab dashboards (Lints Config, Package, Project,
 *    Violations, Command Catalog).
 * 4. **Actions** — Run analysis, Open Findings Dashboard, Initialize/Update config,
 *    Open `analysis_options_custom.yaml`, Composite analyzer plugin scaffold.
 * 5. **Status** — Health score, violation count, suppressions, trends, regression,
 *    fewer-issues delta, last-run timestamp, hotspots (only when `violations.json` exists).
 * 6. **Settings** — Lint integration toggle, Tier selector, Run-after-config toggle,
 *    Detected packages info row.
 * 7. **Triage** — rules grouped by violation count (only when issuesByRule data exists).
 *    These remain expandable because they are *data* (each group expands to show
 *    individual rules), not structural section headers.
 * 8. **Help** — Lints info row, Getting Started, About, pub.dev, Create AI agent
 *    instructions.
 *
 * ## Behaviour contracts
 *
 * - **Dart workspace:** always returns the editor-dashboards links and help links so
 *   users are never stuck on a bare welcome with only an "Enable" affordance.
 *   `saropaLints.enabled` defaults **true**; when a user turns lint integration
 *   **off**, a **Lint integration: Off** row (warning styling) still links to
 *   **Set Up Project** so onboarding is discoverable.
 * - **Non-Dart:** empty root so `viewsWelcome` can prompt to open a pubspec folder.
 * - **Embedded triage:** delegates to the same `ConfigTreeProvider` instance the
 *   triage groups originate from — `refresh()` clears the triage cache once.
 * - **Flat:** root-level entries do **not** include parent containers. The only
 *   collapsible rows are triage groups (which expand to show member rules).
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

const OVERVIEW_INTRO_TOOLTIP =
    'Saropa Lints provides 2100+ Dart and Flutter lint rules for security, accessibility, and performance. '
    + 'It has two components: a pub.dev package with the rules and a VS Code extension for visual analysis and configuration.';

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

/** Sidebar row: label + optional description, click command, and Codicon icon. */
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

// ── Static row builders ─────────────────────────────────────────────────────

function buildEditorDashboardItems(): OverviewItem[] {
    // Editor-tab dashboards. Order matches user-facing priority — config first
    // (most-used), then package + project reports, then the wide violations table,
    // then the catalog escape-hatch.
    return [
        // Sidebar labels match the editor-tab titles 1:1 and never carry the
        // "Saropa" prefix — the activity-bar product name already provides
        // that context, and duplicating it makes every row read as
        // "Saropa Saropa Lints …" in the parent tree.
        new OverviewItem(
            'Lints Config',
            'Tiers, rule packs, SDK rollout',
            'saropaLints.openConfigDashboard',
            'settings-gear',
            new vscode.ThemeColor('activityBarBadge.foreground'),
        ),
        new OverviewItem(
            'Package Dashboard',
            'Dependency vibrancy report',
            'saropaLints.packageVibrancy.showReport',
            'package',
            new vscode.ThemeColor('charts.green'),
        ),
        new OverviewItem(
            'Code Health Dashboard',
            'Function-level code health',
            'saropaLints.openProjectVibrancyReport',
            'symbol-method',
            new vscode.ThemeColor('charts.purple'),
        ),
        new OverviewItem(
            'Findings Dashboard',
            'Editor tab · filters · JSON',
            'saropaLints.openViolationsWideReport',
            'warning',
            new vscode.ThemeColor('editorWarning.foreground'),
        ),
        new OverviewItem(
            'Command Catalog',
            'Search all commands',
            'saropaLints.showCommandCatalog',
            'symbol-event',
            new vscode.ThemeColor('charts.purple'),
        ),
    ];
}

function buildActionItems(): OverviewItem[] {
    // Common actions deduped against the dashboard / settings / help sections.
    // `Run analysis` lives here (not Settings) because it is an action, not a
    // configuration knob; the redundant Settings copy was removed.
    return [
        new OverviewItem(
            'Run analysis',
            'Re-run analyzer',
            'saropaLints.runAnalysis',
            'play',
            new vscode.ThemeColor('debugIcon.startForeground'),
        ),
        new OverviewItem(
            'Open Findings Dashboard',
            'Editor tab · filters · JSON',
            'saropaLints.revealFindingsDashboard',
            'list-tree',
            new vscode.ThemeColor('textLink.foreground'),
        ),
        new OverviewItem(
            'Initialize / Update config',
            undefined,
            'saropaLints.initializeConfig',
            'gear',
        ),
        new OverviewItem(
            'Open analysis_options_custom.yaml',
            undefined,
            'saropaLints.openConfig',
            'file-code',
        ),
        new OverviewItem(
            'Composite analyzer plugin (scaffold)',
            'Meta-plugin package for org + Saropa',
            'saropaLints.emitCompositePluginScaffold',
            'extensions',
        ),
    ];
}

function buildHelpItems(): OverviewItem[] {
    // Help links. The lone duplicate from earlier was `Getting Started` /
    // `About` / `pub.dev` appearing in both Dashboards and Help; keep the canonical
    // copy here.
    const summary = new OverviewItem(
        'Lints',
        'Package + extension for Dart/Flutter',
        undefined,
        'info',
    );
    summary.tooltip = OVERVIEW_INTRO_TOOLTIP;
    return [
        summary,
        new OverviewItem('Getting Started', 'Walkthrough', 'saropaLints.openWalkthrough', 'compass'),
        new OverviewItem('About Saropa Lints', 'Documentation', 'saropaLints.showAbout', 'book'),
        new OverviewItem(
            'Package on pub.dev',
            'saropa_lints',
            'saropaLints.openPubDevSaropaLints',
            'link-external',
            new vscode.ThemeColor('textLink.foreground'),
        ),
        new OverviewItem(
            'Create AI agent instructions',
            '.cursor/rules template',
            'saropaLints.createSaropaInstructions',
            'sparkle',
        ),
    ];
}

// ── Status row builders (only when violations.json exists) ─────────────────

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
                issueLabel, 'View in Findings', 'saropaLints.focusIssues',
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
    const violationsTotal = data.summary?.totalViolations ?? data.violations?.length ?? 0;
    const denominator = violationsTotal + total;
    const rate = denominator > 0 ? Math.round((total / denominator) * 1000) / 10 : 0;

    // Compact breakdown — e.g. "5 ignore, 3 file-level, 2 baseline".
    const parts: string[] = [];
    const byKind = sup?.byKind;
    if (byKind?.ignore) parts.push(`${byKind.ignore} ignore`);
    if (byKind?.ignoreForFile) parts.push(`${byKind.ignoreForFile} file-level`);
    if (byKind?.baseline) parts.push(`${byKind.baseline} baseline`);
    if (denominator > 0) {
        parts.push(`${rate}% suppression rate`);
    }
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
        items.push(
            new OverviewItem(
                `↓ ${violationDelta} fewer issues`,
                'since last run',
                'saropaLints.focusIssues',
                'star-full',
                new vscode.ThemeColor('testing.iconPassed'),
            ),
        );
    }
}

function buildStatusItems(workspaceState: vscode.Memento, data: ViolationsData): OverviewItem[] {
    const items: OverviewItem[] = [];
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
        items.push(
            new OverviewItem(
                `Hotspots: ${percent}% reviewed`,
                `${hotspotCounts.open} open, ${hotspotCounts.reviewedSafe} safe, ${hotspotCounts.reviewedFixed} fixed`,
                'saropaLints.reviewHotspotState',
                'shield',
            ),
        );
    }
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

// ── Filtered violation cache (shared with status rows) ─────────────────────

let _cachedFiltered: { data: ViolationsData; root: string } | null | undefined;

/**
 * Read `violations.json` and apply both `analysis_options.yaml` rule disables
 * and view-level suppressions (path hide / rule hide / severity / impact).
 * Result is cached until the next `OverviewTreeProvider.refresh()` so the
 * status section reuses one read.
 */
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

/**
 * Rebuild summary counts to reflect a filtered violation set.
 * Preserves config / tier / file-count fields from the original summary;
 * recomputes severity / impact / total counts from the filtered violations.
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

/** Clear the filtered-violations cache — call from `refresh()`. */
function invalidateEmbeddedCache(): void {
    _cachedFiltered = undefined;
}

// ── Type guard for embedded ConfigTree nodes ───────────────────────────────

function isConfigTreeNode(node: OverviewTreeNode): node is ConfigTreeNode {
    if (typeof node !== 'object' || node === null || !('kind' in node)) {
        return false;
    }
    const k = (node as { kind: unknown }).kind;
    return typeof k === 'string' && OVERVIEW_EMBEDDED_CONFIG_KINDS.has(k);
}

export type OverviewTreeNode = OverviewItem | ConfigTreeNode;

export class OverviewTreeProvider implements vscode.TreeDataProvider<OverviewTreeNode> {
    private readonly _onDidChangeTreeData = new vscode.EventEmitter<OverviewTreeNode | undefined | void>();
    readonly onDidChangeTreeData = this._onDidChangeTreeData.event;

    constructor(
        private readonly workspaceState: vscode.Memento,
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
        // Triage groups are the only expandable rows; delegate to ConfigTreeProvider.
        if (element !== undefined && isConfigTreeNode(element)) {
            return this.configProvider.getChildren(element);
        }
        if (element !== undefined) {
            return [];
        }

        const root = getProjectRoot();
        if (!root) {
            return [];
        }

        const cfg = vscode.workspace.getConfiguration('saropaLints');
        const enabled = cfg.get<boolean>('enabled', true) ?? true;
        const items: OverviewTreeNode[] = [];

        // Setup banner — primary onboarding affordance when saropa_lints is not in
        // pubspec.yaml. Must be impossible to miss so new users do not get stuck.
        const needsSetup = !hasSaropaLintsDep(root);
        if (needsSetup) {
            items.push(new OverviewItem(
                'Set Up Project',
                'Add saropa_lints to pubspec + configure analysis',
                'saropaLints.enable',
                'rocket',
                new vscode.ThemeColor('list.warningForeground'),
            ));
        } else if (!enabled) {
            // Pubspec is fine but the user explicitly disabled integration —
            // show the warning row pointing at the same setup command.
            items.push(new OverviewItem(
                'Lint integration: Off',
                'Set up pubspec + analysis_options',
                'saropaLints.enable',
                'warning',
                new vscode.ThemeColor('list.warningForeground'),
            ));
        }

        items.push(...buildEditorDashboardItems());
        items.push(...buildActionItems());

        const data = readFilteredViolationsOrNull(this.workspaceState);
        if (data) {
            items.push(...buildStatusItems(this.workspaceState, data));
        } else {
            // No analysis yet — keep the inline cue so users know what unlocks the
            // status rows. Welcome view only fires for non-Dart projects.
            items.push(new OverviewItem(
                'No analysis yet',
                'Run analysis first; status rows fill in.',
                'saropaLints.runAnalysis',
                'beaker',
            ));
        }

        // Settings rows: lint integration / tier / run-after-config / detected.
        // `Run analysis` is intentionally excluded here — already in Actions.
        items.push(...this.configProvider
            .getSettingAndActionNodes()
            .filter((n) => !isRedundantSettingsAction(n)));

        // Triage groups (data, not structure) — expandable to member rules.
        items.push(...this.configProvider.getTriageNodes());

        items.push(...buildHelpItems());

        return items;
    }
}

/**
 * Filter out settings nodes that duplicate top-level Actions / Editor dashboard
 * rows. Keeping the deduped list inline keeps the source of truth in
 * `ConfigTreeProvider.getSettingAndActionNodes()` while letting this view drop
 * the redundant copies.
 */
function isRedundantSettingsAction(node: ConfigTreeNode): boolean {
    if (node.kind !== 'configSetting') return false;
    const cmd = node.commandId;
    // Dedupe: these commands already appear in Actions / Editor dashboards above.
    return cmd === 'saropaLints.runAnalysis'
        || cmd === 'saropaLints.openConfig'
        || cmd === 'saropaLints.initializeConfig'
        || cmd === 'saropaLints.emitCompositePluginScaffold';
}

/**
 * Apply suppressions / disabled-rule filters and return the violation set, or
 * null when the project has no `violations.json` yet so the caller can render
 * the **No analysis yet** placeholder. The caller is expected to have already
 * validated the project root.
 */
function readFilteredViolationsOrNull(
    workspaceState: vscode.Memento,
): ViolationsData | null {
    const filtered = loadFilteredViolations(workspaceState);
    return filtered ? filtered.data : null;
}
