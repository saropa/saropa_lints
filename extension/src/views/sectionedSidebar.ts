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
 *   - **Editor dashboards** — open Saropa editor-tab dashboards; the "..."
 *                           view/title menu carries Help (walkthrough, About,
 *                           pub.dev, AI agent template) so it needs no panel
 *                           of its own
 *   - **Settings**        — run analyzer + initialize config (actions), lint
 *                           integration toggle, tier selector, UI language,
 *                           triage rows (volume groups / override counts),
 *                           and diagnostics controls (severity toggles,
 *                           analyzer plugin, tier) — folded in from the
 *                           former standalone Diagnostics panel
 *   - **Status**          — health / violations / suppressions / trends / last run
 *
 * Each section reads the same upstream data (live diagnostics, pubspec, history)
 * but renders its own slice. Visibility is gated by `when` clauses on each
 * view in `package.json` so empty sections do not pollute the sidebar.
 */

import * as vscode from 'vscode';
import type { ViolationsData } from '../violationsReader';
import { readVisibleLiveViolations, computeLiveHealthScore } from '../liveViolationsData';
import { loadHistory, getTrendSummary, getScoreTrendSummary, findPreviousScore, detectScoreRegression } from '../runHistory';
import { formatScoreDelta } from '../healthScore';
import { getProjectRoot } from '../projectRoot';
import { hasSaropaLintsDep } from '../pubspecReader';
import type { ConfigTreeProvider } from './configTree';
import type { ConfigTreeNode } from './triageTree';
import { renderTreeItem } from './triageTree';
import { OVERVIEW_EMBEDDED_CONFIG_KINDS } from '../overviewEmbeddedConfigKinds';
import { loadSuppressions, isPathHidden, isRuleHidden } from '../suppressionsStore';
import { l10n } from '../i18n/runtime';
import {
    SecurityHotspotReviewStateService,
    countSecurityHotspotReviewStates,
} from '../securityHotspotReviewState';
import { getLatestResults } from '../vibrancy/extension-activation';
import { HealthPanel } from '../systemHealth/healthPanel';

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

/** Severity toggle row — single click flips the severity's visibility. */
export class SeverityToggleItem extends vscode.TreeItem {
    /** The command executed on click. */
    readonly toggleCommandId: string;

    constructor(
        label: string,
        description: string,
        toggleCommandId: string,
        iconId: string,
        iconColor: vscode.ThemeColor,
    ) {
        super(label, vscode.TreeItemCollapsibleState.None);
        this.description = description;
        this.toggleCommandId = toggleCommandId;
        this.tooltip = l10n('diagnostics.sidebar.severityToggleTooltip', { severity: label.toLowerCase() });
        this.contextValue = 'severityToggle';
        this.iconPath = new vscode.ThemeIcon(iconId, iconColor);
        // Single-click toggles directly — the prior double-click gesture required
        // undiscoverable rapid re-selection with no visible affordance.
        this.command = { command: toggleCommandId, title: label, arguments: [] };
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

    // Live diagnostics (vscode.languages.getDiagnostics()), not the cached
    // reports/.saropa_lints/violations.json export. The status bar and Issues
    // tree already made this switch (extension.ts's readVisibleViolations /
    // liveViolationsData.ts) so the Problems panel and this Status section
    // read the exact same source and cannot disagree. Before this fix, Status
    // read the cached-report file and showed "No violations / All clear"
    // whenever no scan had ever been run — even with real diagnostics visible
    // in the Problems panel (a user-reported trust bug). Live is never "no
    // report": an empty result means the project is clean. Disabled-rule
    // filtering is already applied inside readVisibleLiveViolations.
    const afterDisabled = readVisibleLiveViolations(root);
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
            // Three severity buckets — the 5-bucket
            // (critical/high/medium/low/opinionated) taxonomy collapsed on
            // 2026-05-03 (plan/COLLAPSE_LINT_IMPACT_TO_SEVERITY.md).
            error: byImpact['error'] ?? 0,
            warning: byImpact['warning'] ?? 0,
            info: byImpact['info'] ?? 0,
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

/**
 * Count packages that have at least one changelog feature not yet referenced in
 * project source — the adoption "needles" the Package Dashboard ranks. Surfaced
 * as a badge on the sidebar row so the count is visible without opening the
 * dashboard. Reads the latest scan results; the vibrancy status callback in
 * extension.ts already calls refreshAllSections() on scan completion, so the
 * badge updates itself.
 */
function countAdoptionNeedles(): number {
    return getLatestResults().filter(
        r => (r.unadoptedApiNames?.length ?? 0) > 0,
    ).length;
}

function buildEditorDashboardItems(): LeafItem[] {
    // Append a needle count to the Package Dashboard row when the last scan
    // found unadopted features, so under-used dependencies are visible at a
    // glance. Falls back to the plain description before any scan has run.
    const needles = countAdoptionNeedles();
    const packageDesc = needles > 0
        ? `Dependency vibrancy report · ${needles} to adopt`
        : 'Dependency vibrancy report';
    return [
        new LeafItem(
            'Lints Config',
            'Tiers, rule packs, SDK rollout',
            'saropaLints.openConfigDashboard',
            'settings-gear',
            new vscode.ThemeColor('activityBarBadge.foreground'),
        ),
        new LeafItem(
            l10n('analysisOptimizer.sidebar.label'),
            l10n('analysisOptimizer.sidebar.description'),
            'saropaLints.openAnalysisOptimizer',
            'zap',
            new vscode.ThemeColor('charts.yellow'),
        ),
        new LeafItem(
            'Package Dashboard',
            packageDesc,
            'saropaLints.packageVibrancy.showReport',
            'package',
            new vscode.ThemeColor('charts.green'),
        ),
        // Dedicated focused list of dependencies with unadopted features. Only
        // shown once a scan has surfaced at least one, so it does not advertise
        // an empty view.
        ...(needles > 0 ? [new LeafItem(
            'Upgrade Opportunities',
            `${needles} ${needles === 1 ? 'package' : 'packages'} with features to adopt`,
            'saropaLints.packageVibrancy.showOpportunities',
            'rocket',
            new vscode.ThemeColor('charts.blue'),
        )] : []),
        // The exhaustive export: every package and every changelog feature with
        // usage counted from zero upward. Unlike the panel above it is not gated
        // on unadopted features — a fully-adopted project is a valid report.
        new LeafItem(
            l10n('featureInventory.sidebar.label'),
            l10n('featureInventory.sidebar.description'),
            'saropaLints.packageVibrancy.exportOpportunitiesReport',
            'export',
            new vscode.ThemeColor('charts.blue'),
        ),
        new LeafItem(
            'Code Health Dashboard',
            'Function-level code health',
            'saropaLints.openProjectVibrancyReport',
            'symbol-method',
            new vscode.ThemeColor('charts.purple'),
        ),
        new LeafItem(
            'Saropa Project Map',
            'Size · dead-weight · complexity · hot spots',
            'saropaLints.openProjectHealthDashboard',
            'flame',
            new vscode.ThemeColor('charts.orange'),
        ),
        new LeafItem(
            'Findings Dashboard',
            'Editor tab · filters · JSON',
            'saropaLints.openViolationsWideReport',
            'warning',
            new vscode.ThemeColor('editorWarning.foreground'),
        ),
        // Full project audit with scope picker and filterable report webview.
        new LeafItem(
            l10n('fullAudit.sidebar.label'),
            l10n('fullAudit.sidebar.description'),
            'saropaLints.fullAudit',
            'shield',
            new vscode.ThemeColor('charts.red'),
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
    // "Pick UI language" is intentionally NOT here. The Settings rows below
    // include a "UI language — <current>" row bound to the same
    // `saropaLints.pickUiLanguage` command; it shows the current language AND
    // is clickable, so it strictly supersedes a bare action row. Keeping both
    // put the identical command in the sidebar twice.
    return [
        new LeafItem(
            'Run analysis',
            'Re-run analyzer',
            'saropaLints.runAnalysis',
            'play',
            new vscode.ThemeColor('debugIcon.startForeground'),
        ),
        new LeafItem(
            'Initialize / Update config',
            undefined,
            'saropaLints.initializeConfig',
            'gear',
        ),
        // Stale ignore detection and cleanup — surfaces the CLI's
        // --find-stale-ignores / --fix-stale-ignores as clickable sidebar rows
        // so the feature is discoverable without knowing CLI flags. No extra
        // `when` gating needed here: the whole Settings VIEW (package.json
        // "saropaLints.settings") already requires saropaLints.isDartProject,
        // so these rows are hidden together with the rest of the panel on
        // non-Dart projects — no separate enablement check required.
        new LeafItem(
            l10n('staleIgnores.sidebar.findLabel'),
            l10n('staleIgnores.sidebar.findDescription'),
            'saropaLints.findStaleIgnores',
            'search-remove',
            new vscode.ThemeColor('charts.orange'),
        ),
        new LeafItem(
            l10n('staleIgnores.sidebar.fixLabel'),
            l10n('staleIgnores.sidebar.fixDescription'),
            'saropaLints.fixStaleIgnores',
            'trash',
            new vscode.ThemeColor('charts.red'),
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

// Help commands (Getting Started, About, pub.dev, AI agent instructions) no
// longer render as a stacked sidebar panel — they moved to the "..." overflow
// on the Dashboards view/title menu (package.json `view/title`), reachable in
// one click without a dedicated scroll section for 4 rarely-used rows.

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
    root: string,
): void {
    // Live severity counts, cached-report file-count denominator — see
    // computeLiveHealthScore's doc comment for why the score can't be purely
    // live-sourced.
    const health = computeLiveHealthScore(root, data);
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

// Maps the machine-readable EngineStatus.key to the debug.engine.* l10n
// namespace, which uses 'analyzerPlugin' rather than 'analyzer'.
const ENGINE_NAME_KEY: Record<'analyzer' | 'scanDaemon' | 'lspServer', string> = {
    analyzer: 'analyzerPlugin',
    scanDaemon: 'scanDaemon',
    lspServer: 'lspServer',
};

/**
 * "Engines: N running" summary row, sourced from the same snapshot the
 * Health Panel shows (HealthPanel.getEngineStatuses() — see its doc comment:
 * built specifically so the sidebar and panel can never disagree). Silently
 * omitted when saropaLints.debug.enabled is off or engines aren't wired up
 * yet, matching the panel's own behavior.
 */
function appendEnginesRow(items: LeafItem[]): void {
    const engines = HealthPanel.getEngineStatuses();
    if (!engines) return;
    const running = engines.filter(e => e.enabled).length;
    const summary = engines
        .map(e => `${l10n(`debug.engine.${ENGINE_NAME_KEY[e.key]}`)} ${l10n(`debug.engine.statusValue.${e.status}`)}`)
        .join(' · ');
    items.push(new LeafItem(
        l10n('debug.sidebar.enginesLabel', { count: String(running) }),
        summary,
        'saropaLints.showProcessHealth',
        'server-process',
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
        // Headline regression on errors (must-fix). Was previously keyed on
        // LintImpact.critical (5-bucket taxonomy retired 2026-05-03).
        const errorCount = data.summary?.byImpact?.error ?? 0;
        const plural = errorCount === 1 ? '' : 's';
        const regDesc = errorCount > 0
            ? `${errorCount} error${plural}`
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
    const { data, root } = loaded;

    const items: LeafItem[] = [];
    const history = loadHistory(workspaceState);
    const total = data.summary?.totalViolations ?? data.violations?.length ?? 0;
    // Was data.summary.byImpact.critical (5-bucket taxonomy retired 2026-05-03).
    const critical = data.summary?.byImpact?.error ?? 0;
    const hotspotReviewState = new SecurityHotspotReviewStateService(workspaceState);
    const hotspotCounts = countSecurityHotspotReviewStates(
        data.violations ?? [],
        data.config?.ruleMetadataByRule,
        hotspotReviewState,
    );

    appendHealthRow(items, history, data, total, root);
    appendEnginesRow(items);
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

/**
 * Actions + Settings + Triage rows merged into one panel. Order: actions
 * first (run analysis, initialize config), then settings (lint integration
 * toggle, tier, run-after-config, UI language, detected packages), then
 * triage rows (per-rule volume groups, "X rules disabled by override",
 * "X rules with zero issues") when triage data is available.
 *
 * Why merged: the former standalone Actions panel sat directly above this
 * one and the two read as duplicates — Actions held a handful of operations,
 * Settings held the config those operations target. They are one story
 * ("operate and configure my project's lints"), so they share one panel.
 * Triage was folded in earlier for the same reason. The play-button in the
 * panel title bar still runs analysis (view/title menu moved to this view).
 */
function buildSettingsItems(configProvider: ConfigTreeProvider): SectionNode[] {
    const actions = buildActionItems();
    const settings = configProvider
        .getSettingAndActionNodes()
        .filter((n) => !isRedundantSettingsAction(n));
    // Triage rows render flat; renderTreeItem may set collapsibleState on
    // group nodes, but `getTreeItem` overrides it back to None so no chevrons
    // appear next to any row inside this panel.
    const triage = configProvider.getTriageNodes();
    // Diagnostics (severity toggles + lint integration/plugin/tier controls)
    // folded in here — they were their own stacked panel, which meant a 7th
    // scroll section for 8 rows that are all "things that control what
    // diagnostics you see", the same story this panel already tells.
    const diagnostics = buildDiagnosticsItems(configProvider);
    return [...actions, ...settings, ...triage, ...diagnostics];
}

/**
 * Diagnostics rows — severity filter toggles plus the 3 core diagnostic
 * controls (Lint integration, Analyzer plugin, Tier). Appended to the
 * Settings panel by `buildSettingsItems` rather than rendered as their own
 * view — they govern the same "what do I see and how is it configured"
 * story as the rest of that panel.
 */
function buildDiagnosticsItems(configProvider: ConfigTreeProvider): SectionNode[] {
    const cfg = vscode.workspace.getConfiguration('saropaLints');
    const showErrors = cfg.get<boolean>('severity.error', true) !== false;
    const showWarnings = cfg.get<boolean>('severity.warning', true) !== false;
    const showInfos = cfg.get<boolean>('severity.info', true) !== false;
    const showHints = cfg.get<boolean>('severity.hint', true) !== false;
    return [
        // Each severity gets a distinct icon + theme color so the user can
        // visually distinguish them at a glance without reading the label.
        new SeverityToggleItem(
            'Show errors', showErrors ? 'On' : 'Off',
            'saropaLints.toggleSeverityError', 'error',
            new vscode.ThemeColor('list.errorForeground'),
        ),
        new SeverityToggleItem(
            'Show warnings', showWarnings ? 'On' : 'Off',
            'saropaLints.toggleSeverityWarning', 'warning',
            new vscode.ThemeColor('list.warningForeground'),
        ),
        new SeverityToggleItem(
            'Show infos', showInfos ? 'On' : 'Off',
            'saropaLints.toggleSeverityInfo', 'info',
            new vscode.ThemeColor('charts.blue'),
        ),
        new SeverityToggleItem(
            'Show hints', showHints ? 'On' : 'Off',
            'saropaLints.toggleSeverityHint', 'lightbulb',
            new vscode.ThemeColor('charts.green'),
        ),
        // Lint integration, Analyzer plugin, and Tier — moved here from
        // the Settings section because they directly control which
        // diagnostics appear (same concern as the severity toggles above).
        ...configProvider.getDiagnosticControlNodes(),
    ];
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
    status: 'saropaLints.status',
    // Settings now also hosts the action rows (run analysis, initialize config)
    // and the triage rows (rules grouped by violation count, plus "X rules
    // disabled by override" / "X rules with zero issues"). The standalone
    // Actions and Triage views were merged in: the user wanted a single panel
    // to operate and configure the project's lints in one place.
    settings: 'saropaLints.settings',
} as const;

/**
 * Build all section providers wired to the shared dependencies.
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
        // Merged Actions + Settings + Triage panel, placed at the former Actions
        // slot (above Status) so the run/initialize operations stay prominent.
        new FlatSectionProvider(SECTION_VIEW_IDS.settings, () => buildSettingsItems(configProvider)),
        new FlatSectionProvider(SECTION_VIEW_IDS.status, () => buildStatusItems(workspaceState)),
    ];
}

/**
 * Compute and push the context keys gating each section view's visibility.
 * Call this whenever the underlying data (violations / pubspec / triage)
 * changes; the values feed each view's `when` clause in `package.json`.
 *
 * `saropaLints.hasTriage` is no longer set — Triage is no longer its own
 * view; its rows render inside the always-visible Settings panel.
 */
export function updateSidebarSectionContext(workspaceState: vscode.Memento): void {
    const root = getProjectRoot();
    if (!root) {
        void vscode.commands.executeCommand('setContext', 'saropaLints.needsBanner', false);
        return;
    }
    const cfg = vscode.workspace.getConfiguration('saropaLints');
    const enabled = cfg.get<boolean>('enabled', true) ?? true;
    const needsBanner = !hasSaropaLintsDep(root) || !enabled;
    void vscode.commands.executeCommand('setContext', 'saropaLints.needsBanner', needsBanner);
    invalidateSharedCache();
}
