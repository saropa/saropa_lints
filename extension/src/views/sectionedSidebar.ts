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
 *   - **Settings**        — 4 action rows only (run analysis, initialize/
 *                           update config, fix stale ignores, command
 *                           catalog), plus a conditional 5th ("Migrate
 *                           config keys") that appears only while legacy
 *                           plugin-block keys remain. Everything else that
 *                           used to live here was a verified duplicate of a
 *                           richer surface and was cut, not lost:
 *                             - severity toggles (show errors/warnings/
 *                               infos/hints)  → Rules & Tiers Automation tab
 *                             - run-after-config / run-after-dependency /
 *                               UI language settings                → Rules
 *                               & Tiers Automation tab (config-change/
 *                               dependency-change toggles) / Extension tab
 *                               (UI language)
 *                             - "Detected: <packages>"          → Package
 *                               Dashboard (full dependency list) / Extension
 *                               tab platforms block
 *                             - triage rows (volume groups, critical group,
 *                               zero-issue/override counts, stylistic group)
 *                               → Findings Dashboard's top-rules triage table
 *                             - Tier / Lane                     → folded into
 *                               the Lints Config row's description
 *                             - Analyzer plugin (live/disabled/absent) → moved
 *                               to Status, as a conditional warning row (only
 *                               rendered when NOT live) — see WP3
 *                           See plans/PLAN_sidebar_row_collapse.md §2.1 for
 *                           the row-by-row evidence behind each move.
 *   - **Status**          — health (tooltip carries last-run time) / engines
 *                           / lint integration / analyzer plugin warning
 *                           (conditional, disabled/absent only — WP3).
 *                           Hotspots, Suppressed, Trends, Score dropped, and
 *                           Fewer issues all moved to the Findings dashboard's
 *                           status-line pills (WP4) or were straight cuts of
 *                           duplicate data (Suppressed) — WP5,
 *                           plans/PLAN_sidebar_row_collapse.md §2.2. The
 *                           view's `when` clause no longer requires
 *                           `saropaLints.hasViolations` (WP5), so the panel
 *                           stays visible on a clean project.
 *
 * Each section reads the same upstream data (live diagnostics, pubspec, history)
 * but renders its own slice. Visibility is gated by `when` clauses on each
 * view in `package.json` so empty sections do not pollute the sidebar.
 */

import * as vscode from 'vscode';
import type { ViolationsData } from '../violationsReader';
import { readVisibleLiveViolations, computeLiveHealthScore } from '../liveViolationsData';
// `getTrendSummary` / `getScoreTrendSummary` / `detectScoreRegression` were
// dropped from this import (WP5, sidebar row collapse): the Trends /
// Score-dropped / Fewer-issues rows they backed all moved to the Findings
// dashboard's status-line pills (WP4, `violations-dashboard-top.ts`
// `buildStatusLine`), which reads the same `runHistory.ts` data directly.
// `findPreviousScore` stays — the Health row's score-delta description still
// needs it.
import { loadHistory, findPreviousScore } from '../runHistory';
import { formatScoreDelta } from '../healthScore';
import { getProjectRoot } from '../projectRoot';
import { hasSaropaLintsDep } from '../pubspecReader';
import type { ConfigTreeProvider } from './configTree';
import type { ConfigTreeNode } from './triageTree';
import { renderTreeItem } from './triageTree';
import { OVERVIEW_EMBEDDED_CONFIG_KINDS } from '../overviewEmbeddedConfigKinds';
import { loadSuppressions, isPathHidden, isRuleHidden } from '../suppressionsStore';
import { l10n } from '../i18n/runtime';
// `SecurityHotspotReviewStateService` / `countSecurityHotspotReviewStates`
// were dropped from this import (WP5): the Hotspots row moved to the
// Findings dashboard's status-line pill (WP4), which computes its own
// hotspot counts from `violationsWideReportView.ts`.
import { getLatestResults } from '../vibrancy/extension-activation';
import { HealthPanel } from '../systemHealth/healthPanel';
// Lane value for the Lints Config row description (WP2, sidebar row collapse
// plan) — same reader the removed configTree.ts `buildLaneNode` used, so the
// folded description agrees with what the in-process plugin actually reads.
import { readRawLaneFromCustomConfig } from '../config/laneConfig';

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

// `SeverityToggleItem` was removed here (2026-09-04, sidebar row collapse
// WP1): the 4 severity toggle rows it rendered (show errors/warnings/infos/
// hints) duplicated boolean controls already on the Rules & Tiers Automation
// tab (`rulePacksWebviewProvider.ts` `_buildAutomationTab`) — same config
// keys (`severity.error|warning|info|hint`), same `cfg.update` +
// `refreshAllSections` behavior either way. The `toggleSeverity*` commands
// stay registered for the command palette; only the sidebar row is gone.

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

/**
 * Banner covers two cases, both gated by the view's own `when` clause
 * (`saropaLints.needsBanner || !saropaLints.isDartProject`):
 *   (a) no Dart project is open at all (no pubspec.yaml found) — handled by
 *       VS Code's native `viewsWelcome` contribution (package.json, `when:
 *       "!saropaLints.isDartProject"`), NOT by a tree row: `viewsWelcome`
 *       content only renders while its view's tree is genuinely empty, so
 *       this branch must keep returning `[]` (verified against the existing
 *       "contributes viewsWelcome on the Banner view for non-Dart projects"
 *       test in uxLabels.test.ts — pushing a row here would suppress that
 *       richer welcome screen, not add to it; checked before touching this
 *       during the empty-state audit, PHASE1_BADGES_AND_EMPTY_STATES);
 *   (b) a Dart project is open but doesn't depend on saropa_lints yet.
 * The "dependency present but integration off" case moved to Status's
 * Lint integration row (see appendLintIntegrationRow) — once the
 * dependency exists, the on/off state belongs next to Health and
 * Engines, not in a separate banner view.
 */
function buildBannerItems(): LeafItem[] {
    const root = getProjectRoot();
    if (!root) return [];
    if (!hasSaropaLintsDep(root)) {
        return [new LeafItem(
            'Set Up Project',
            'Add saropa_lints to pubspec + configure analysis',
            'saropaLints.enable',
            'rocket',
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

/**
 * The Lints Config row's description: `Tier: {tier} · Lane: {lane}` — folds
 * in the two rows the sidebar used to carry separately (Settings' "Tier" and
 * "Lane" rows, both of whose only click target was this same dashboard or a
 * QuickPick one step removed from it; see plans/PLAN_sidebar_row_collapse.md
 * §2.1 rows 24-25, WP2). Tier comes from the plain `saropaLints.tier`
 * extension setting; Lane comes from `analysis_options_custom.yaml`'s `lane:`
 * key via the SAME reader the removed `configTree.ts` `buildLaneNode` used,
 * so the folded text never disagrees with what the in-process plugin reads.
 *
 * With no project root there is no custom yaml to read `lane:` from, so the
 * Lane half is omitted entirely rather than guessing — a separate, shorter
 * catalog key covers that case instead of interpolating an empty/placeholder
 * value into the full template.
 */
function buildLintsConfigDescription(): string {
    const tier = vscode.workspace.getConfiguration('saropaLints').get<string>('tier', 'recommended') ?? 'recommended';
    const root = getProjectRoot();
    if (!root) {
        return l10n('dashboards.lintsConfig.descriptionNoLane', { tier });
    }
    // Absent/unrecognized `lane:` reads as 'light' — matches the Dart-side
    // default (RuleLane.light) and the same fallback the removed sidebar Lane
    // row and the Config file tab's Lane card both use.
    const raw = readRawLaneFromCustomConfig(root);
    const lane = raw === 'full' ? 'full' : 'light';
    return l10n('dashboards.lintsConfig.description', { tier, lane });
}

/**
 * The six first-class dashboards. Analysis Optimizer, Upgrade Opportunities,
 * and the Feature Inventory export are deliberately NOT separate rows here
 * any more — they render as tabs inside Rules & Tiers (Analysis Optimizer,
 * embedded per rulePacksWebviewProvider.ts's getEmbeddedBodyHtml) and inside
 * the Package Dashboard (Upgrades / Full report tabs, packages-tabs.ts).
 * A standalone sidebar row pointing at content one tab-click away inside a
 * dashboard this list already links to was the same kind of duplication the
 * "Saropa Dashboards" home hub was removed for (see CHANGELOG.md, commit
 * ea2c7a8e) — moved, not deleted: both features are still reachable, just
 * from inside the dashboard that now owns them. Command Catalog moved to the
 * Settings panel's action rows (all commands belongs with "run analysis",
 * not the list of dashboards).
 */
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
            buildLintsConfigDescription(),
            'saropaLints.openConfigDashboard',
            'settings-gear',
            new vscode.ThemeColor('activityBarBadge.foreground'),
        ),
        new LeafItem(
            'Package Dashboard',
            packageDesc,
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
        // Stale ignore detection and cleanup — was two rows (Find, then Fix)
        // requiring the user to run Find first to learn whether Fix was even
        // needed. One row now: it finds first, reports the count via the
        // existing confirm dialog, and only proceeds to the (destructive)
        // fix after that confirmation — see runFindAndFixStaleIgnores in
        // stale-ignore-commands.ts. The separate `findStaleIgnores` /
        // `fixStaleIgnores` commands stay registered for the command palette
        // and the per-file quick fix; only the sidebar row merged. No extra
        // `when` gating needed here: the whole Settings VIEW (package.json
        // "saropaLints.settings") already requires saropaLints.isDartProject,
        // so this row is hidden together with the rest of the panel on
        // non-Dart projects — no separate enablement check required.
        new LeafItem(
            l10n('staleIgnores.sidebar.fixLabel'),
            l10n('staleIgnores.sidebar.fixDescription'),
            'saropaLints.findAndFixStaleIgnores',
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
        //
        // Command Catalog moved here from the Dashboards section — it is an
        // action ("search all commands"), not a dashboard, and Quick Actions
        // is where the plan's target IA (PLAN_extension_ui_redesign.md §2.1)
        // puts the "All commands…" escape hatch.
        new LeafItem(
            'Command Catalog',
            'Search all commands',
            'saropaLints.showCommandCatalog',
            'symbol-event',
            new vscode.ThemeColor('charts.purple'),
        ),
    ];
}

// Help commands (Getting Started, About, pub.dev, AI agent instructions) no
// longer render as a stacked sidebar panel — they moved to the "..." overflow
// on the Dashboards view/title menu (package.json `view/title`), reachable in
// one click without a dedicated scroll section for 4 rarely-used rows.

// ── Status section builders ───────────────────────────────────────────────

/**
 * Folds in what used to be a separate "N critical, M total" row: on a first
 * run (no score delta yet) the description carries the same critical/total
 * breakdown that row showed, so removing it loses no information — it was
 * otherwise pure duplication of the total this row already renders (see
 * PLAN_extension_ui_redesign.md §2.1, "one job per row").
 */
function healthScoreDescription(delta: string, total: number, critical: number): string {
    if (delta) return `${delta} from last run`;
    if (total === 0) return 'No violations';
    return critical > 0 ? `${critical} critical, ${total} total` : `${total} violations`;
}

function appendHealthRow(
    items: LeafItem[],
    history: ReturnType<typeof loadHistory>,
    data: ViolationsData,
    total: number,
    critical: number,
    root: string,
): void {
    // Live severity counts, cached-report file-count denominator — see
    // computeLiveHealthScore's doc comment for why the score can't be purely
    // live-sourced.
    const health = computeLiveHealthScore(root, data);
    if (!health) {
        // computeLiveHealthScore returns null when reports/.saropa_lints/
        // violations.json has never been written (no `filesAnalyzed`) — i.e.
        // analysis has never run for this project (empty-state audit, case
        // c: "analysis never run"). This row used to just vanish here,
        // leaving Status silently missing its first and most important row
        // with zero explanation. Show a row that says so and reuses the same
        // run command Settings' action row and the Quick Actions row use, so
        // the fix is one click away from the message that explains it.
        items.push(new LeafItem(
            l10n('status.health.neverRunLabel'),
            l10n('status.health.neverRunDescription'),
            'saropaLints.runAnalysis',
            'pulse',
            new vscode.ThemeColor('descriptionForeground'),
        ));
        return;
    }
    const prevScore = findPreviousScore(history);
    const delta = prevScore !== undefined ? formatScoreDelta(health.score, prevScore) : '';
    const item = new LeafItem(
        `Health: ${health.score}`,
        healthScoreDescription(delta, total, critical),
        'saropaLints.focusIssues',
        'pulse',
    );
    // The dedicated "Last run" row was folded into this tooltip (WP5, sidebar
    // row collapse): the Findings dashboard already has its own freshness
    // pill, so the sidebar only needs the timestamp as hover text rather than
    // a whole extra row. `LeafItem`'s constructor has no tooltip parameter —
    // assign after construction. Omitted entirely when history is empty
    // (no analysis has ever run) rather than showing a misleading tooltip.
    const lastRunIso = history.at(-1)?.timestamp;
    if (lastRunIso) {
        item.tooltip = l10n('status.health.lastRunTooltip', { ago: formatTimeAgo(lastRunIso) });
    }
    items.push(item);
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
        .map(e => {
            const name = l10n(`debug.engine.${ENGINE_NAME_KEY[e.key]}`);
            // e.status is a machine key defined independently in extension.ts
            // (nothing enforces it stays in sync with debug.engine.statusValue.*
            // in en.json) — fall back to the raw value instead of an ugly
            // untranslated dotted key if a new status is ever added to one
            // without the other.
            const status = l10n(`debug.engine.statusValue.${e.status}`, undefined, { fallback: e.status });
            return `${name} ${status}`;
        })
        .join(' · ');
    // Zero engines running while this row exists (debug panel on) means no
    // diagnostics source is active at all — worth a warning color so it's
    // visible without opening the Health Panel. Individual engine health
    // beyond that isn't distinguishable from EngineStatus today: `enabled`
    // and `status` are derived together in extension.ts (e.g. analyzer's
    // status is always 'active' exactly when enabled is true), so there is
    // no "enabled but actually crashed" signal to color for yet.
    const color = running === 0 ? new vscode.ThemeColor('list.warningForeground') : undefined;
    items.push(new LeafItem(
        l10n('debug.sidebar.enginesLabel', { count: String(running) }),
        summary,
        'saropaLints.showProcessHealth',
        'server-process',
        color,
    ));
}

/**
 * "Lint integration: On/Off" row — merged in from what used to be a
 * dedicated Banner-view row (only shown when off) plus a duplicate toggle
 * buried in the Settings panel's diagnostics block (always shown). One row,
 * always shown once a project has the saropa_lints dependency, single click
 * toggles it (same enable/disable commands both prior locations used) — see
 * PLAN_extension_ui_redesign.md §2.1's 3-row Status target.
 */
function appendLintIntegrationRow(items: LeafItem[]): void {
    const enabled = vscode.workspace.getConfiguration('saropaLints').get<boolean>('enabled', true) ?? true;
    items.push(new LeafItem(
        enabled ? 'Lint integration: On' : 'Lint integration: Off',
        enabled ? 'Click to disable' : 'Click to enable',
        enabled ? 'saropaLints.disable' : 'saropaLints.enable',
        enabled ? 'check' : 'circle-slash',
        enabled ? undefined : new vscode.ThemeColor('list.warningForeground'),
    ));
}

// `appendSuppressionRow`, `appendTrendRow`, and `appendRegressionAndMilestone`
// were removed here (WP5, sidebar row collapse):
//   - Suppressions ("N suppressed") was a straight CUT — the Findings
//     dashboard already renders `analyzerSuppressions` + `viewSuppressions`
//     (`violationsWideReportView.ts`), so the sidebar row was pure
//     duplication with no unique information.
//   - Trends and "Score dropped A → B" MOVED to the Findings dashboard's
//     status-line pills (WP4, `violations-dashboard-top.ts` `buildStatusLine`)
//     — same `runHistory.ts` data (`getTrendSummary` /
//     `getScoreTrendSummary` / `detectScoreRegression`), a landing spot with
//     more room for detail (tooltip breakdown) than a sidebar row allowed.
//   - "↓ N fewer issues" FOLDED into the trend pill's `good` CSS class rather
//     than surviving as its own row — the arrow-series trend text already
//     conveys direction, so a separate milestone row was noise.
// See plans/PLAN_sidebar_row_collapse.md §2.2 for the per-row evidence.

/**
 * Status section: Health (with a "Last analysis" tooltip) · Engines
 * (conditional on debug.enabled) · Lint integration · analyzer plugin
 * warning (conditional, WP3). Hotspots, Suppressed, Trends, Score dropped,
 * Fewer issues, and the standalone Last-run row all moved elsewhere or were
 * cut outright — see the comment block above and
 * plans/PLAN_sidebar_row_collapse.md §2.2. The view's own `when` clause
 * (package.json `saropaLints.status`) no longer requires
 * `saropaLints.hasViolations` (WP5): Lint integration state matters most
 * exactly when there are no violations to gate the panel on (integration
 * off → nothing scans → zero violations → panel used to vanish, hiding the
 * one row that would explain why).
 */
function buildStatusItems(workspaceState: vscode.Memento, configProvider: ConfigTreeProvider): SectionNode[] {
    const loaded = loadFilteredViolations(workspaceState);
    if (!loaded) return [];
    const { data, root } = loaded;

    // `items` stays LeafItem[] because every `append*` helper below is typed
    // against LeafItem[] (they only ever construct vscode.TreeItem leaves).
    // The analyzer plugin warning row is a ConfigTreeNode (a different arm of
    // the SectionNode union — see `getAnalyzerPluginWarningNode`'s doc
    // comment in configTree.ts), so it is appended separately below rather
    // than threaded through the LeafItem-typed helpers.
    const items: LeafItem[] = [];
    const history = loadHistory(workspaceState);
    const total = data.summary?.totalViolations ?? data.violations?.length ?? 0;
    // Was data.summary.byImpact.critical (5-bucket taxonomy retired 2026-05-03).
    const critical = data.summary?.byImpact?.error ?? 0;

    appendHealthRow(items, history, data, total, critical, root);
    appendEnginesRow(items);
    appendLintIntegrationRow(items);

    // Analyzer plugin warning row (2026-09-04, sidebar row collapse WP3):
    // MOVED here from the Settings/Quick Actions section — a plugin state is
    // a fact about the project, not a setting, and it now sits right after
    // Lint integration since both rows describe how the project talks to
    // the analyzer. Only rendered when the plugin is disabled or absent —
    // `getAnalyzerPluginWarningNode` returns [] for the `live` state (its
    // `verifyPlugin` probe stays reachable via Command Catalog / Health
    // Panel instead of a sidebar row). It is now also the LAST row in the
    // section (WP5 removed everything that used to render after it —
    // Hotspots/Suppressed/Trends/Score-dropped/Last-run — so the splice this
    // function used to do at a captured "after Lint integration" index is no
    // longer needed; a plain append is correct).
    const pluginWarningRows: SectionNode[] = configProvider.getAnalyzerPluginWarningNode();

    return [...items, ...pluginWarningRows];
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
 * Actions-only panel (WP1, 2026-09-04): 4 rows always, +1 conditional.
 * Order: run analysis, initialize/update config, fix stale ignores, command
 * catalog, then (only when `configProvider.getSettingAndActionNodes()`
 * surfaces it) migrate legacy config keys.
 *
 * Everything else this panel used to carry — severity toggles, setting-value
 * rows (run-after-config/dependency, UI language, detected packages), and
 * triage rows — was a verified duplicate of a richer surface elsewhere and
 * was cut in the same change; see the file header comment and
 * plans/PLAN_sidebar_row_collapse.md §2.1 for the per-row evidence. The
 * `getSettingAndActionNodes()` call below now returns action nodes only
 * (`buildSettingNodes` was emptied and deleted in configTree.ts), so
 * `isRedundantSettingsAction` still filters out the handful of actions that
 * duplicate the top-level Editor dashboard / Actions rows (open config
 * dashboard, initialize config, run analysis, composite plugin scaffold).
 */
function buildSettingsItems(configProvider: ConfigTreeProvider): SectionNode[] {
    const actions = buildActionItems();
    const settings = configProvider
        .getSettingAndActionNodes()
        .filter((n) => !isRedundantSettingsAction(n));
    return [...actions, ...settings];
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
        // Optional view-level badge builder (live sidebar badges, Phase 1).
        // VS Code's TreeView API only supports ONE badge per VIEW
        // (`TreeView.badge`, a `ViewBadge {value, tooltip}` rendered on the
        // view's icon in the Activity Bar) — there is no `TreeItem.badge`
        // for individual rows, so a section carries at most one summary
        // count, not a badge per row. Sections with no meaningful single
        // count (Banner, Settings) simply omit this builder.
        private readonly buildBadge?: () => vscode.ViewBadge | undefined,
    ) {}

    /** Compute this section's view-level badge, or undefined to clear it. */
    getBadge(): vscode.ViewBadge | undefined {
        return this.buildBadge?.();
    }

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
        new FlatSectionProvider(
            SECTION_VIEW_IDS.editorDashboards,
            () => buildEditorDashboardItems(),
            () => computeDashboardsBadge(),
        ),
        // Merged Actions + Settings + Triage panel, placed at the former Actions
        // slot (above Status) so the run/initialize operations stay prominent.
        new FlatSectionProvider(SECTION_VIEW_IDS.settings, () => buildSettingsItems(configProvider)),
        new FlatSectionProvider(
            SECTION_VIEW_IDS.status,
            () => buildStatusItems(workspaceState, configProvider),
            () => computeStatusBadge(workspaceState),
        ),
    ];
}

/**
 * Dashboards view badge: count of packages with unadopted changelog features
 * (same "needles" the Package Dashboard row's description already surfaces —
 * see `countAdoptionNeedles`). Undefined (no badge) when there is nothing to
 * adopt, rather than a distracting "0" pill.
 */
function computeDashboardsBadge(): vscode.ViewBadge | undefined {
    const needles = countAdoptionNeedles();
    if (needles <= 0) return undefined;
    return {
        value: needles,
        tooltip: l10n('dashboards.badge.needlesTooltip', { count: String(needles) }),
    };
}

/**
 * Status view badge: critical (error-severity) violation count when any
 * exist, else the total violation count, else undefined (clean project or no
 * analysis has run yet — matches the Health row's own "no badge when there
 * is nothing to flag" behavior). Reads the same filtered/live snapshot the
 * Health row's description is built from, so the two can never disagree.
 */
function computeStatusBadge(workspaceState: vscode.Memento): vscode.ViewBadge | undefined {
    const loaded = loadFilteredViolations(workspaceState);
    if (!loaded) return undefined;
    const { data } = loaded;
    const total = data.summary?.totalViolations ?? data.violations?.length ?? 0;
    if (total <= 0) return undefined;
    // Was data.summary.byImpact.critical (5-bucket taxonomy retired 2026-05-03).
    const critical = data.summary?.byImpact?.error ?? 0;
    if (critical > 0) {
        return {
            value: critical,
            tooltip: l10n('status.badge.criticalTooltip', { critical: String(critical), total: String(total) }),
        };
    }
    return { value: total, tooltip: l10n('status.badge.totalTooltip', { total: String(total) }) };
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
