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
 *                             - Live analysis (live/disabled/absent) → moved
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
import * as nodeFs from 'node:fs';
import * as nodePath from 'node:path';
import type { ViolationsData } from '../violationsReader';
import { readVisibleLiveViolations, computeLiveHealthScore, getLastDiagnosticsChangeIso, isDiagnosticsStale } from '../liveViolationsData';
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
// Hotspot review-progress row (PLAN_ext_ui_sidebar_reset.md §3 STATUS row 3,
// "Hotspots · N% reviewed"). Reuses the EXACT counting function and service
// the Findings dashboard's status-line pill uses
// (`violationsWideReportView.ts` buildHotspotsSlice) — one source of truth
// for "how many hotspots are open" so the sidebar row and the dashboard pill
// can never disagree while both exist.
import { SecurityHotspotReviewStateService, countSecurityHotspotReviewStates } from '../securityHotspotReviewState';
// Lane value for the Lints Config row description (WP2, sidebar row collapse
// plan) — same reader the removed configTree.ts `buildLaneNode` used, so the
// folded description agrees with what the in-process plugin actually reads.
import { readRawLaneFromCustomConfig } from '../config/laneConfig';
// TASK A (PLAN_ext_ui_sidebar_reset.md §5 P1, "row descriptions are live"):
// Code Health's row description reads the in-memory result of the last scan
// this session ran. This is a pure accessor (never spawns `dart run`) so it
// is safe to call on every sidebar rebuild — see its own doc comment.
import { getLastProjectVibrancyPayload } from './projectVibrancyReportView';
import { saropaLintsDataPath } from '../reportsPaths';

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

// ── Shared sidebar data snapshot ────────────────────────────────────────────
//
// Computed once per refresh cycle, consumed by BOTH the Dashboards and Status
// section builders. Eliminates the duplicate live-diagnostics read +
// computeLiveHealthScore parse that buildFindingsDescription and appendHealthRow
// previously performed independently, and guarantees all rows show identical
// numbers from a single computation.

/** All sidebar-relevant data, computed once per invalidateSharedCache(). */
interface SidebarDataSnapshot {
    /** Filtered violations data (suppressions applied). Null if no project root. */
    filtered: { data: ViolationsData; root: string } | null;
    /** Health score from live diagnostics + cached violations.json. Null if
     *  analysis has never run (no violations.json) or no project root. */
    healthScore: number | null;
    /** Total filtered violation count (post-suppression). */
    totalViolations: number;
    /** Critical (error-severity) violation count (post-suppression). */
    criticalViolations: number;
}

let _cachedSnapshot: SidebarDataSnapshot | undefined;

/**
 * Build or return the cached sidebar data snapshot. Called by both the
 * Dashboards and Status section builders on the same refresh cycle — the
 * first call computes, the rest hit the cache.
 */
function getSnapshot(workspaceState: vscode.Memento): SidebarDataSnapshot {
    if (_cachedSnapshot !== undefined) return _cachedSnapshot;

    const root = getProjectRoot();
    if (!root) {
        _cachedSnapshot = {
            filtered: null,
            healthScore: null,
            totalViolations: 0,
            criticalViolations: 0,
        };
        return _cachedSnapshot;
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

    const total = data.summary?.totalViolations ?? data.violations?.length ?? 0;
    // Was data.summary.byImpact.critical (5-bucket taxonomy retired 2026-05-03).
    const critical = data.summary?.byImpact?.error ?? 0;

    // Health score — computeLiveHealthScore reads violations.json from disk
    // (the one expensive call). Done once here, shared by Findings row and
    // Health row so they always show the same number.
    const health = computeLiveHealthScore(root, data);

    _cachedSnapshot = {
        filtered: { data, root },
        healthScore: health?.score ?? null,
        totalViolations: total,
        criticalViolations: critical,
    };
    return _cachedSnapshot;
}

/**
 * Legacy accessor for callers that only need the filtered violations data.
 * Delegates to getSnapshot so the computation is shared.
 */
function loadFilteredViolations(
    workspaceState: vscode.Memento,
): { data: ViolationsData; root: string } | null {
    return getSnapshot(workspaceState).filtered;
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

/**
 * Pre-compute the shared sidebar snapshot for a refresh cycle. Call once at
 * the TOP of refreshAllSections — every provider's getChildren / getBadge
 * then hits the cache instead of recomputing. Replaces the old per-provider
 * invalidateSharedCache pattern that cleared and rebuilt the cache N times.
 */
export function prepareRefreshCycle(workspaceState: vscode.Memento): void {
    _cachedSnapshot = undefined;
    // Eagerly build so the loop only reads cache hits.
    getSnapshot(workspaceState);
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
 * The "dependency present but integration off" case is reflected in the
 * Engines row's scan-on-save entry — once the dependency exists, the
 * on/off state belongs next to Health and Engines, not in a separate
 * banner view.
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
 * Code Health row description (PLAN_ext_ui_sidebar_reset.md §5 P1: "Code
 * Health uses `getLastProjectVibrancyPayload()`"). BUGFIX: a previous pass at
 * the sidebar rebuild left this row's description as the hardcoded literal
 * "Function-level code health" with no grade, score, or gate state — the
 * live-data requirement the plan specified was never actually wired up. Now
 * mirrors the grade/score and the gate-failing flag the Code Health
 * dashboard's own hero renders (`projectVibrancyReportView.ts`'s `buildHero`,
 * `payload.gates?.pass === false`) — same field, so the sidebar and the
 * dashboard can never disagree about whether the gate is passing.
 *
 * `getLastProjectVibrancyPayload()` only returns a scan that already
 * completed THIS session (module-level in-memory cache) — it never spawns
 * `dart run saropa_lints:project_vibrancy` itself, so this is free to compute
 * on every sidebar rebuild without triggering a scan (the row-description
 * contract this plan section requires).
 */
function buildCodeHealthDescription(): { description: string; gateFailing: boolean } {
    const payload = getLastProjectVibrancyPayload();
    if (!payload) {
        // No scan has completed this session — degrade honestly rather than
        // showing a stale/fabricated grade. Matches the Health status row's
        // own "never run" pattern (`status.health.neverRunDescription`).
        return { description: l10n('sidebar.dashboards.codeHealthNeverScanned'), gateFailing: false };
    }
    const grade = payload.summary?.averageGrade ?? '—';
    const score = String(Math.round(payload.summary?.averageScore ?? 0));
    const gateFailing = payload.gates?.pass === false;
    const description = gateFailing
        ? l10n('sidebar.dashboards.codeHealthDescriptionGateFailing', { grade, score })
        : l10n('sidebar.dashboards.codeHealthDescription', { grade, score });
    return { description, gateFailing };
}

/**
 * Project Map's report file — the exact `outputDir`/`index.html` path
 * `projectMapView.ts`'s `runScanAndRender` writes to (`<root>/reports/
 * .saropa_lints/health/index.html`). Duplicated here as a path literal rather
 * than importing from `projectMapView.ts` because this file owns the sidebar
 * and must not edit — or take on a dependency that could pull in — the
 * Project Map view module another agent is actively working in; the path
 * segments themselves come from the shared `saropaLintsDataPath` helper so
 * only the `health/index.html` suffix is duplicated, not the whole path.
 */
function projectMapReportIndexPath(root: string): string {
    return nodePath.join(saropaLintsDataPath(root), 'health', 'index.html');
}

/**
 * Last-scan mtime of the Project Map report (PLAN_ext_ui_sidebar_reset.md §5
 * P1: "Project Map uses `getLastProjectMapMtime()`"). A plain `fs.statSync`
 * on the already-written report file is effectively free — nothing here
 * spawns `dart run saropa_lints:project_health`, so this never triggers a
 * scan. Returns undefined when no report has ever been written for this
 * workspace (fresh project, or a scan that never completed) — ENOENT and any
 * other stat failure collapse to the same "no data yet" outcome for the
 * caller.
 *
 * STATED DECISION (raised in review, not silently repeated): this is a
 * second synchronous disk read on the sidebar refresh path, the same class
 * of finding PLAN_ext_ui_sidebar_reset.md §6 already logged and deferred for
 * `computeLiveHealthScore` ("code-review finding, low"). Left synchronous
 * here too, deliberately, not by oversight:
 *   - It runs once per sidebar section rebuild (a user action or a
 *     diagnostics-change event), never in a hot loop or on a timer — the
 *     same trigger cadence `computeLiveHealthScore` already accepts.
 *   - A `fs.statSync` reads only inode metadata, not the (multi-MB) report
 *     HTML body — orders of magnitude cheaper than the JSON parse
 *     `computeLiveHealthScore` performs on every call, which is already
 *     accepted at this same call site.
 *   - Converting one row's data source to async while the rest of
 *     `buildEditorDashboardItems`/`buildStatusItems` stay synchronous would
 *     require a larger refactor of `TreeDataProvider.getChildren`'s
 *     synchronous contract across every section — a bigger blast radius
 *     than this bugfix's scope, and not requested.
 * If this ever shows up as an actual jank complaint, fix it alongside
 * `computeLiveHealthScore` in one pass rather than diverging one row now.
 */
function getLastProjectMapMtime(root: string): Date | undefined {
    try {
        return nodeFs.statSync(projectMapReportIndexPath(root)).mtime;
    } catch {
        return undefined;
    }
}

/**
 * Project Map row description. Live scan age via [getLastProjectMapMtime],
 * degrading to the "never scanned" catalog string when no report file exists
 * yet — same honesty contract as the Code Health description above and the
 * existing Findings/Health "never run" rows.
 *
 * Size/file count (`ProjectMapTotals`) is intentionally NOT surfaced here:
 * the only place that cache lives is a workspaceState key private to
 * `projectMapView.ts` (`TOTALS_STATE_KEY`, not exported), and duplicating
 * that key string here would violate the single-source-of-truth rule the
 * moment either file changes it independently. The report file's mtime is
 * the one fact genuinely available without either an import into the file
 * another agent owns or a duplicated private constant.
 */
function buildProjectMapDescription(): string {
    const root = getProjectRoot();
    if (!root) return l10n('sidebar.dashboards.projectMapNeverScanned');
    const mtime = getLastProjectMapMtime(root);
    if (!mtime) return l10n('sidebar.dashboards.projectMapNeverScanned');
    return l10n('sidebar.dashboards.projectMapDescription', { ago: formatTimeAgo(mtime.toISOString()) });
}

/**
 * Findings Dashboard row description: live violation count + health score,
 * so the sidebar itself tells users whether there's something to click on.
 * Reads from the shared SidebarDataSnapshot so the count matches the
 * Status/Health row exactly — both read one computation, not two.
 */
function buildFindingsDescription(snapshot: SidebarDataSnapshot): string {
    if (!snapshot.filtered) return l10n('sidebar.dashboards.findingsNoProject');
    // No health score means analysis has never run (violations.json missing).
    if (snapshot.healthScore === null) return l10n('sidebar.dashboards.findingsNeverScanned');
    // Undefined until the first `onDidChangeDiagnostics` event this session
    // (see liveViolationsData.ts) — omit the "updated Ns ago" suffix rather
    // than claim a freshness we haven't actually observed yet.
    const lastChangeIso = getLastDiagnosticsChangeIso();
    const ago = lastChangeIso ? formatTimeAgo(lastChangeIso) : undefined;
    if (snapshot.totalViolations === 0) {
        return ago
            ? l10n('sidebar.dashboards.findingsCleanFresh', { score: String(snapshot.healthScore), ago })
            : l10n('sidebar.dashboards.findingsClean', { score: String(snapshot.healthScore) });
    }
    return ago
        ? l10n('sidebar.dashboards.findingsWithViolationsFresh', {
              count: String(snapshot.totalViolations),
              score: String(snapshot.healthScore),
              ago,
          })
        : l10n('sidebar.dashboards.findingsWithViolations', {
              count: String(snapshot.totalViolations),
              score: String(snapshot.healthScore),
          });
}

/**
 * True when the Findings Dashboard row's "updated Ns ago" suffix is old
 * enough to read as "possibly stale" rather than reassuringly current (see
 * `isDiagnosticsStale`). False both when no diagnostics event has fired yet
 * this session (no claim of freshness is being made at all) and when the
 * last event is recent — only an aging claim needs the visual downgrade.
 */
function isFindingsRowStale(): boolean {
    const lastChangeIso = getLastDiagnosticsChangeIso();
    return lastChangeIso !== undefined && isDiagnosticsStale(lastChangeIso);
}

/**
 * Package Dashboard row description: live adoption needle count, so users
 * see at a glance how many dependencies have features they haven't tried.
 * Falls back to a "run scan" prompt before the first vibrancy scan.
 */
function buildPackageDescription(): string {
    const needles = countAdoptionNeedles();
    const results = getLatestResults();
    // No scan results at all — vibrancy hasn't run yet.
    if (results.length === 0) return l10n('sidebar.dashboards.packagesNeverScanned');
    if (needles === 0) return l10n('sidebar.dashboards.packagesAllAdopted');
    return l10n('sidebar.dashboards.packagesNeedlesCount', { count: String(needles) });
}

/**
 * The six DASHBOARDS rows (PLAN_ext_ui_sidebar_reset.md §3): Findings
 * first (it's the row most users click first — health score + issue count),
 * then Lints Config, Packages, Code Health, Project Map, and "All commands…"
 * last as the escape hatch. Full Audit is no longer a separate row — its
 * workspace-wide scope picker (full project / changed vs main / changed vs
 * branch) is now the Findings row's own toolbar scope selector, so running
 * it and viewing its results happen in the same dashboard rather than a
 * second panel opened from a VS Code quick-pick. Analysis Optimizer, Upgrade
 * Opportunities, and the Feature Inventory export are deliberately NOT
 * separate rows here — they render as tabs inside Rules & Tiers (Analysis
 * Optimizer, embedded per rulePacksWebviewProvider.ts's getEmbeddedBodyHtml)
 * and inside the Package Dashboard (Upgrades / Full report tabs,
 * packages-tabs.ts). A standalone sidebar row pointing at content one
 * tab-click away inside a dashboard this list already links to was the same
 * kind of duplication the "Saropa Dashboards" home hub was removed for (see
 * CHANGELOG.md, commit ea2c7a8e) — moved, not deleted: both features are
 * still reachable, just from inside the dashboard that now owns them.
 *
 * Command Catalog moved HERE from the Actions panel (reset plan §3.1) — it
 * opens a page/picker like every other row in this section, it never runs
 * anything itself, so ACTIONS (whose section semantics are "runs something
 * now") was the wrong home for it.
 *
 * Every description answers "what will I find when I click this?" with a
 * live count where one exists — not a format label or static blurb.
 */
function buildEditorDashboardItems(snapshot: SidebarDataSnapshot): LeafItem[] {
    // Stale claims get a distinct icon (clock, not warning) and a muted
    // theme color, so an old "updated Ns ago" count reads as "go re-run
    // analysis" rather than a currently-accurate warning.
    const findingsStale = isFindingsRowStale();
    return [
        new LeafItem(
            'Findings Dashboard',
            buildFindingsDescription(snapshot),
            'saropaLints.openViolationsWideReport',
            findingsStale ? 'history' : 'warning',
            new vscode.ThemeColor(findingsStale ? 'descriptionForeground' : 'editorWarning.foreground'),
        ),
        new LeafItem(
            'Lints Config',
            buildLintsConfigDescription(),
            'saropaLints.openConfigDashboard',
            'settings-gear',
            new vscode.ThemeColor('activityBarBadge.foreground'),
        ),
        new LeafItem(
            'Package Dashboard',
            buildPackageDescription(),
            'saropaLints.packageVibrancy.showReport',
            'package',
            new vscode.ThemeColor('charts.green'),
        ),
        (() => {
            const codeHealth = buildCodeHealthDescription();
            return new LeafItem(
                'Code Health Dashboard',
                codeHealth.description,
                'saropaLints.openProjectVibrancyReport',
                'symbol-method',
                // Warning color when the last scan's quality gate failed — makes a
                // failing gate visible from the sidebar without opening the
                // dashboard (TASK B's "surface quality-gate status where users
                // already look" applies here too: this row IS one of those places).
                codeHealth.gateFailing
                    ? new vscode.ThemeColor('list.warningForeground')
                    : new vscode.ThemeColor('charts.purple'),
            );
        })(),
        new LeafItem(
            'Saropa Project Map',
            buildProjectMapDescription(),
            'saropaLints.openProjectHealthDashboard',
            'flame',
            new vscode.ThemeColor('charts.orange'),
        ),
        // Full-project audit is now a scope option inside the Findings
        // Dashboard's own toolbar (Live / Full project / Changed vs main /
        // Changed vs branch) rather than a separate sidebar entry that opened
        // a VS Code quick-pick menu and a second report panel.
        new LeafItem(
            l10n('sidebar.dashboards.commandCatalogLabel'),
            l10n('sidebar.dashboards.commandCatalogDescription'),
            'saropaLints.showCommandCatalog',
            'symbol-event',
            new vscode.ThemeColor('charts.purple'),
        ),
    ];
}

function buildActionItems(): LeafItem[] {
    // "Pick UI language" is intentionally NOT here — it's a select on the
    // Rules & Tiers Extension tab, not a run action.
    //
    // Exactly 3 rows now (PLAN_ext_ui_sidebar_reset.md §3 ACTIONS target):
    // every row here RUNS something now, with a visible outcome (progress,
    // toast, diff) — the section's one job per §2's table. Two rows that
    // used to live here moved out because they don't run anything:
    // Command Catalog → DASHBOARDS (opens a picker, doesn't act); Migrate
    // config keys → dropped from the sidebar entirely (P2: a button on the
    // Lints Config › Config file tab, plus the command palette — see
    // configTree.ts, `getSettingAndActionNodes` removed).
    return [
        new LeafItem(
            l10n('sidebar.actions.runAnalysisLabel'),
            l10n('sidebar.actions.runAnalysisDescription'),
            'saropaLints.runAnalysis',
            'play',
            new vscode.ThemeColor('debugIcon.startForeground'),
        ),
        // Stale ignore detection and cleanup — was two rows (Find, then Fix)
        // requiring the user to run Find first to learn whether Fix was even
        // needed. One row now: it finds first, reports the count via the
        // existing confirm dialog, and only proceeds to the (destructive)
        // fix after that confirmation — see runFindAndFixStaleIgnores in
        // stale-ignore-commands.ts. This IS the resolution to plan §7.2's
        // open "one row or two" question: the merged command already shows
        // what it will remove and asks before writing, so the "keep both if
        // it deletes silently" fallback never applies — one row is correct.
        // The separate `findStaleIgnores` / `fixStaleIgnores` commands stay
        // registered for the command palette and the per-file quick fix;
        // only the sidebar row merged. No extra `when` gating needed here:
        // the whole Actions VIEW (package.json "saropaLints.actions")
        // already requires saropaLints.isDartProject, so this row is hidden
        // together with the rest of the panel on non-Dart projects.
        new LeafItem(
            l10n('staleIgnores.sidebar.fixLabel'),
            l10n('staleIgnores.sidebar.fixDescription'),
            'saropaLints.findAndFixStaleIgnores',
            'trash',
            new vscode.ThemeColor('charts.red'),
        ),
        new LeafItem(
            l10n('sidebar.actions.updateConfigLabel'),
            l10n('sidebar.actions.updateConfigDescription'),
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
    total: number,
    critical: number,
    healthScore: number | null,
): void {
    // Health score comes from the shared SidebarDataSnapshot — computed once
    // per refresh, shared with the Findings Dashboard row so both always
    // show the same number.
    if (healthScore === null) {
        // computeLiveHealthScore returns null when reports/.saropa_lints/
        // violations.json has never been written (no `filesAnalyzed`) — i.e.
        // analysis has never run for this project (empty-state audit, case
        // c: "analysis never run"). This row used to just vanish here,
        // leaving Status silently missing its first and most important row
        // with zero explanation. Show a row that says so.
        items.push(new LeafItem(
            l10n('status.health.neverRunLabel'),
            l10n('status.health.neverRunDescription'),
            // BUGFIX (PLAN_ext_ui_sidebar_reset.md P1, §2 STATUS invariant):
            // used to target `saropaLints.runAnalysis` directly — a STATUS
            // row running something, exactly what the reset plan's "no
            // STATUS/DASHBOARDS row targets a run/toggle command" guard
            // exists to catch. Findings' own empty state explains "no
            // analysis yet" and carries the Run button, so this still opens
            // "the detail for the fact" (an empty one) rather than acting.
            'saropaLints.openViolationsWideReport',
            'pulse',
            new vscode.ThemeColor('descriptionForeground'),
        ));
        return;
    }
    const prevScore = findPreviousScore(history);
    const delta = prevScore !== undefined ? formatScoreDelta(healthScore, prevScore) : '';
    const item = new LeafItem(
        `Health: ${healthScore}`,
        healthScoreDescription(delta, total, critical),
        'saropaLints.focusIssues',
        'pulse',
    );
    items.push(item);
}

/**
 * "Last run · Nh ago" — reinstated as its own STATUS row
 * (PLAN_ext_ui_sidebar_reset.md §3, row 4). It used to be folded into the
 * Health row's tooltip (WP5, sidebar row collapse) on the theory that hover
 * text was enough — but a tooltip is invisible until you hover, so a fact as
 * basic as "when did this last run" had no on-screen home. Hidden entirely
 * before the first run (no history yet), matching the plan's "hidden before
 * the first run" spec. Opens Findings (same target as the Health row) since
 * that is where the run this timestamp refers to is fully described.
 */
function appendLastRunRow(items: LeafItem[], history: ReturnType<typeof loadHistory>): void {
    const lastRunIso = history.at(-1)?.timestamp;
    if (!lastRunIso) return;
    items.push(new LeafItem(
        l10n('sidebar.status.lastRunLabel', { ago: formatTimeAgo(lastRunIso) }),
        undefined,
        'saropaLints.openViolationsWideReport',
        'history',
    ));
}

/**
 * "Hotspots · N% reviewed" — reinstated as its own STATUS row
 * (PLAN_ext_ui_sidebar_reset.md §3, row 3). WP5 (sidebar row collapse) cut
 * this row on the theory that the Findings dashboard's status-line pill
 * covered it — but that pill only appears once you've already opened
 * Findings, which is exactly the "have to guess/explore to find out" problem
 * the reset plan is fixing. Reuses the identical counting function and
 * per-viewer review-state service the Findings pill uses
 * (`violationsWideReportView.ts` buildHotspotsSlice /
 * securityHotspotReviewState.ts), so the two can never disagree.
 * Hidden entirely when there are no security-sensitive violations at all
 * (`total <= 0`) — a project with none has nothing to review.
 */
function appendHotspotsRow(
    items: LeafItem[],
    data: ViolationsData,
    workspaceState: vscode.Memento,
): void {
    const service = new SecurityHotspotReviewStateService(workspaceState);
    const counts = countSecurityHotspotReviewStates(
        data.violations ?? [],
        data.config?.ruleMetadataByRule,
        service,
    );
    if (counts.total <= 0) return;
    const reviewed = counts.reviewedSafe + counts.reviewedFixed;
    const percent = Math.round((reviewed / counts.total) * 100);
    items.push(new LeafItem(
        l10n('sidebar.status.hotspotsLabel', { percent: String(percent) }),
        l10n('sidebar.status.hotspotsDescription', { open: String(counts.open) }),
        'saropaLints.reviewHotspotState',
        'shield',
        // Warning color while any hotspot is still open/unreviewed — matches
        // the Findings pill's `pill warn` vs `pill good` split.
        counts.open > 0 ? new vscode.ThemeColor('list.warningForeground') : undefined,
    ));
}

// Maps the machine-readable EngineStatus.key to the debug.engine.* l10n
// namespace, which uses 'analyzerPlugin' rather than 'analyzer'.
const ENGINE_NAME_KEY: Record<'analyzer' | 'scanDaemon' | 'lspServer' | 'ci', string> = {
    analyzer: 'analyzerPlugin',
    scanDaemon: 'scanDaemon',
    lspServer: 'lspServer',
    ci: 'ci',
};

/**
 * "Engines: N running" summary row, sourced from the same snapshot the
 * Health Panel shows (HealthPanel.getEngineStatuses() — see its doc comment:
 * built specifically so the sidebar and panel can never disagree). Silently
 * omitted only while the engines aren't wired up yet (early in activate).
 * No longer gated on saropaLints.debug.enabled: this row is the way into the
 * panel that holds the CI off switch, and an off switch you cannot find is
 * not an off switch.
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
 * Static launcher row for the Machine Health dashboard (PLAN_memory_stability_features.md
 * Phase 1). Unlike appendEnginesRow above, this row carries no live summary —
 * the dashboard's data (system RAM, Ollama models, every Dart process on the
 * box) is expensive enough to gather that re-querying it just to render one
 * sidebar description line would duplicate the panel's own refresh cost on
 * every sidebar repaint. Windows-only, matching the subsystem it opens
 * (processQuery.ts, orphanHosts.ts, systemQuery.ts all shell out to
 * PowerShell CIM queries with no cross-platform equivalent yet).
 */
function appendMachineHealthRow(items: LeafItem[]): void {
    if (process.platform !== 'win32') return;
    items.push(new LeafItem(
        l10n('sidebar.status.machineHealthLabel'),
        l10n('sidebar.status.machineHealthDescription'),
        'saropaLints.showMachineDashboard',
        'dashboard',
    ));
}

// `appendLintIntegrationRow` ("Lint integration: On/Off") was REMOVED here
// (PLAN_ext_ui_sidebar_reset.md P3, §3.1 row "Lint integration: On/Off
// (Settings)"). Two reasons:
//   1. It was a STATUS row whose click FLIPPED a setting
//      (saropaLints.disable/enable) — a direct violation of §2's rule that a
//      STATUS row "never changes anything." That is the exact bug class the
//      reset plan exists to remove (see §2's table).
//   2. Its only unique fact — whether scan-on-save is delivering — is now
//      correctly represented in the Engines row's scan-on-save/Scan Daemon
//      entry (see the bugfix in extension.ts's `getScanDaemonStatus`, which
//      used to report "idle" even when `saropaLints.enabled=false`). Folding
//      it there means "off" always sits next to the engine facts that
//      explain WHY, instead of as a lone alarming word beside live findings
//      (plan §1 point 5, "two truths on one screen").
// The `saropaLints.enable` / `saropaLints.disable` commands stay registered
// for the command palette and the Banner's "Set Up Project" row; only this
// STATUS row is gone.

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
 * Status section (PLAN_ext_ui_sidebar_reset.md §3 target — 4 rows, 2
 * conditional): Health · Engines (conditional on debug.enabled) · Hotspots
 * (conditional, hidden when there are none) · Last run (conditional, hidden
 * before the first run).
 *
 * Lint integration and the analyzer-plugin warning are GONE from this
 * section (not merely moved) — both used to run/toggle a command directly
 * from a STATUS row, which breaks §2's rule that a STATUS click "never
 * changes anything." Their facts are still visible: scan-on-save state is
 * now correctly folded into the Engines row's Scan Daemon entry (see
 * extension.ts's `getScanDaemonStatus` bugfix), and analyzer-plugin state is
 * one of the three engines Engines already lists. Suppressed/Trends/Score
 * dropped/Fewer issues stay cut — they live on the Findings dashboard's
 * status-line pills, which have room for the breakdown a sidebar row does
 * not.
 *
 * The view's own `when` clause (package.json `saropaLints.status`) does not
 * require `saropaLints.hasViolations`: a clean project with scan-on-save off
 * still needs the Engines row visible to explain why it's clean.
 */
function buildStatusItems(workspaceState: vscode.Memento): SectionNode[] {
    // Read from the shared snapshot so Dashboards and Status sections always
    // agree on violation count, health score, and critical count.
    const snapshot = getSnapshot(workspaceState);
    if (!snapshot.filtered) return [];
    const { data } = snapshot.filtered;

    const items: LeafItem[] = [];
    const history = loadHistory(workspaceState);

    appendHealthRow(items, history, snapshot.totalViolations, snapshot.criticalViolations, snapshot.healthScore);
    appendEnginesRow(items);
    appendMachineHealthRow(items);
    appendHotspotsRow(items, data, workspaceState);
    appendLastRunRow(items, history);

    return items;
}

// ── ConfigTreeProvider-backed node support ──────────────────────────────────
// (PLAN_ext_ui_sidebar_reset.md P1/P2: neither remaining section — Actions
// nor Status — mixes in a raw ConfigTreeNode any more. Status dropped its
// only ConfigTreeNode row, the analyzer-plugin warning, because a STATUS row
// running `reenablePlugin`/`initializeConfig` on click violated §2's "a
// STATUS click never changes anything" rule; that fact is already visible in
// the Engines row instead. `isConfigTreeNode` / the ConfigTreeNode branch in
// `FlatSectionProvider.getTreeItem()` below are left in place — they cost
// nothing at rest and keep the door open for a future section that does need
// a live ConfigTreeNode row — but nothing currently constructs one.)

function isConfigTreeNode(node: unknown): node is ConfigTreeNode {
    if (typeof node !== 'object' || node === null || !('kind' in node)) return false;
    const k = (node as { kind: unknown }).kind;
    return typeof k === 'string' && OVERVIEW_EMBEDDED_CONFIG_KINDS.has(k);
}

/**
 * Actions panel (PLAN_ext_ui_sidebar_reset.md §3 ACTIONS target): exactly the
 * 3 rows from `buildActionItems()`, nothing merged in from
 * `ConfigTreeProvider` any more. It used to also pull in
 * `configProvider.getSettingAndActionNodes()` (the conditional Migrate row),
 * filtered through `isRedundantSettingsAction` to drop the entries that
 * duplicated `buildActionItems()`'s own rows. Both are gone: the Migrate row
 * was cut from the sidebar outright per the reset plan's row table (P2 adds
 * a button on the Lints Config › Config file tab instead), which left
 * `isRedundantSettingsAction` filtering an always-empty list — dead code,
 * deleted rather than kept "just in case."
 */
function buildActionsItems(): SectionNode[] {
    return buildActionItems();
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

    /** Fire the tree-data-changed event. Snapshot is pre-computed by
     *  prepareRefreshCycle — no per-provider cache invalidation needed. */
    refresh(): void {
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
    // Renamed from `saropaLints.settings` (PLAN_ext_ui_sidebar_reset.md P1):
    // this panel has been action-rows-only since the 2026-09-04 row collapse
    // (severity toggles / setting-value rows / triage all moved out) — the
    // "Settings" name was left over from when it also carried config-value
    // rows. Now that it is provably just 3 verbs (run/fix/initialize), the
    // id and view name match what it actually does.
    actions: 'saropaLints.actions',
} as const;

/**
 * Build all section providers wired to the shared dependencies.
 *
 * Returned in render order (top → bottom in the activity bar). The caller
 * is responsible for `vscode.window.createTreeView(viewId, { treeDataProvider })`
 * for each one and for invoking `refresh()` on every relevant provider when
 * upstream data changes.
 *
 * `configProvider` is accepted for call-site stability (extension.ts already
 * owns a `ConfigTreeProvider` instance with its own lifecycle/refresh wiring
 * unrelated to this sidebar) but is no longer read here: both places that
 * used to pull a ConfigTreeNode into a section (Actions' Migrate row,
 * Status's analyzer-plugin warning) were removed in the P1/P3 row-set
 * rewrite — see `buildActionsItems` and `buildStatusItems`'s doc comments.
 */
export function createSidebarSectionProviders(
    workspaceState: vscode.Memento,
    _configProvider: ConfigTreeProvider,
): FlatSectionProvider[] {
    return [
        new FlatSectionProvider(SECTION_VIEW_IDS.banner, () => buildBannerItems()),
        // No badge builder — adoption needles are informational, not problems.
        // The count is already shown in the Package Dashboard row description.
        // Putting it on the view badge inflated the activity bar number and
        // misled users into thinking 79 packages had lint errors.
        //
        // Both Dashboards and Status read from the shared SidebarDataSnapshot
        // (getSnapshot) so violations.json is parsed once, not twice, and
        // the Findings row's count always matches the Health row's count.
        new FlatSectionProvider(
            SECTION_VIEW_IDS.editorDashboards,
            () => buildEditorDashboardItems(getSnapshot(workspaceState)),
        ),
        new FlatSectionProvider(SECTION_VIEW_IDS.actions, () => buildActionsItems()),
        new FlatSectionProvider(
            SECTION_VIEW_IDS.status,
            () => buildStatusItems(workspaceState),
            () => computeStatusBadge(workspaceState),
        ),
    ];
}


/**
 * Status view badge: critical (error-severity) violation count when any
 * exist, else the total violation count, else undefined (clean project or no
 * analysis has run yet — matches the Health row's own "no badge when there
 * is nothing to flag" behavior). Reads the same filtered/live snapshot the
 * Health row's description is built from, so the two can never disagree.
 */
function computeStatusBadge(workspaceState: vscode.Memento): vscode.ViewBadge | undefined {
    // Read from the shared snapshot — same single computation that feeds
    // Findings Dashboard and Health row.
    const snapshot = getSnapshot(workspaceState);
    if (snapshot.totalViolations <= 0) return undefined;
    if (snapshot.criticalViolations > 0) {
        return {
            value: snapshot.criticalViolations,
            tooltip: l10n('status.badge.criticalTooltip', {
                critical: String(snapshot.criticalViolations),
                total: String(snapshot.totalViolations),
            }),
        };
    }
    return {
        value: snapshot.totalViolations,
        tooltip: l10n('status.badge.totalTooltip', { total: String(snapshot.totalViolations) }),
    };
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
    // Cache invalidation moved to prepareRefreshCycle — called once at the
    // top of refreshAllSections instead of per-provider and per-context-update.
}
