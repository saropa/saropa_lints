/**
 * Saropa Lints extension entry point.
 * `saropaLints.enabled` defaults on: upgrade checks and integration state.
 * Sidebar overview, triage, and rule-pack dashboards stay available for Dart workspaces;
 * TODOs workspace scan is opt-in via `todosAndHacks.workspaceScanEnabled`.
 *
 * Activation registers tree providers and command handlers in dependency order:
 * violations/overview trees read `reports/.saropa_lints/violations.json` written by
 * the analyzer plugin; drift advisor and vibrancy commands coordinate with workspace
 * memento keys documented on their providers. Prefer small focused modules under
 * `views/` and `commands/` over growing this file when adding features.
 */

import * as vscode from 'vscode';
import * as fs from 'node:fs';
import * as path from 'node:path';
import {
  runEnable,
  runDisable,
  runAnalysis as runAnalysisCommand,
  runAnalysisForFiles as runAnalysisForFilesCommand,
  runInitializeConfig,
  runEmitCompositePluginScaffold,
  openConfig,
  runRepairConfig,
  runSetTier,
  showOutputChannel,
  getSharedOutputChannel,
  TIER_ORDER,
} from './setup';
import { verifyPluginLiveness, surfaceLivenessResult } from './pluginLiveness';
import type { SaropaLintsApi } from './api';
import { invalidateCodeLenses, registerCodeLensProvider } from './codeLensProvider';
import { IssuesTreeProvider, parseViolationsGroupBy, registerIssueCommands, type IssueTreeNode } from './views/issuesTree';
import {
  createSidebarSectionProviders,
  SECTION_VIEW_IDS,
  updateSidebarSectionContext,
} from './views/sectionedSidebar';
import { showHelpHubQuickPick } from './views/helpHub';
import { SummaryTreeProvider } from './views/summaryTree';
import { SuppressionsTreeProvider } from './views/suppressionsTree';
import { ConfigTreeProvider } from './views/configTree';
import { readRulePacksEnabled, writeRulePacksEnabled } from './rulePacks/rulePackYaml';
import { SecurityPostureTreeProvider } from './views/securityPostureTree';
import { FileRiskTreeProvider } from './views/fileRiskTree';
import { TodosAndHacksTreeProvider } from './views/todosAndHacksTree';
import { showAboutPanel } from './views/aboutView';
import { registerIssuesViewCommands } from './commands/issuesViewCommands';
import { showCommandCatalogPanel } from './views/commandCatalogView';
import { showRelatedRuleTelemetryPanel } from './views/relatedRuleTelemetryView';
import { openProjectVibrancyReport, refreshCodeHealthDashboardIfOpen } from './views/projectVibrancyReportView';
import { registerProjectMapCommand } from './views/projectMapView';
import { registerHealthCodeLens } from './views/healthCodeLens';
import { discoverServer } from './driftAdvisor/discovery';
import { fetchIssues } from './driftAdvisor/client';
import { mapIssuesToLocations } from './driftAdvisor/mapper';
import { DriftAdvisorTreeProvider } from './driftAdvisor/driftAdvisorTree';
import { registerSuiteCommands } from './suite/commands';
import { maybeNudgeCrashCoveredRule } from './suite/crashCoverageNudge';
import { exportLintsEnvelope } from './suite/exporter';
import { RulePacksWebviewProvider } from './rulePacks/rulePacksWebviewProvider';
import { maybeShowStartupSuggestion } from './rulePacks/startupSuggestionNudge';
import {
  openRuleExplainPanelForViolation,
  openRuleExplainPanel,
  setRuleExplainTelemetry,
} from './views/ruleExplainView';
import {
  readViolations,
  hasViolations,
  ViolationsData,
  getViolationsPath as getViolationsFilePath,
} from './violationsReader';
// Status-bar score reads LIVE diagnostics (same source as the Findings wide
// report and the Issues tree) so the grade never lags the Problems panel.
import { readLiveViolations, readVisibleLiveViolations } from './liveViolationsData';
import { initRuleCatalog } from './ruleCatalog';
import {
  SecurityHotspotReviewStateService,
} from './securityHotspotReviewState';
import {
  setConflictingRulesMetadata,
  setRelatedRulesMetadata,
  setRuleTagsMetadata,
  setSupersedesRulesMetadata,
} from './ruleMetadata';
import { hasSaropaLintsDep } from './pubspecReader';
import { createPubspecValidation, registerFallbackPubspecListeners } from './pubspec-validation';
import { PubspecCodeActionProvider } from './pubspec-code-actions';
import {
  appendSnapshot,
  loadHistory,
  findPreviousScore,
  detectThresholdCrossing,
  type RunSnapshot,
} from './runHistory';
import {
  computeHealthScore,
  formatScoreDelta,
  scoreColorBand,
  isReportTooPartial,
  IMPACT_WEIGHTS,
  DECAY_RATE,
} from './healthScore';
import { registerInlineAnnotations, updateAnnotationsForAllEditors, invalidateAnnotationCache } from './inlineAnnotations';
import {
  writeRuleOverrides,
  removeRuleOverrides,
  invalidateDisabledRulesCache,
  readDisabledRules,
  readRuleOverrides,
} from './configWriter';
import { logReport, logSection, flushReport, findLatestAnalysisReport } from './reportWriter';
import { generateOwaspReport } from './owaspExport';
import { getProjectRoot, invalidateProjectRoot } from './projectRoot';
import {
  runActivation as runVibrancyActivation,
  stopFreshnessWatcher,
  VibrancyStatusData,
  getLatestResults,
} from './vibrancy/extension-activation';
import { registerSidebarSectionVisibility, updateSidebarSectionVisibility } from './sidebarSectionVisibility';
import {
  onDriftAdvisorDisconnected,
  setDriftAdvisorServerConnected,
} from './driftAdvisor/driftAdvisorUiState';
import { SIDEBAR_SECTION_CONFIG_KEYS, defaultSidebarSectionVisible, sidebarSectionContextKey } from './sidebarSectionVisibilityKeys';
import { checkForUpgrade } from './upgrade-checker';
import { buildStatusBarLabel } from './statusBarLabel';
import { createRelatedRuleTelemetry } from './relatedRuleTelemetry';
import { registerCrossFileCommands } from './cross-file-commands';
import { registerCopyAsJsonCommands } from './extensionCopyAsJsonCommands';
import { openViolationsWideReport, refreshFindingsDashboardIfOpen } from './views/violationsWideReportView';
import { openConsolidatedDashboard } from './views/consolidated/consolidatedView';
import { pickWorkspaceFolder } from './workspaceFolderPicker';
import { setCurrentLocale, l10n } from './i18n/runtime';
import { buildUiLanguageQuickPickItems, type LanguagePickItem } from './i18n/languagePick';
import { VibrancyReportPanel } from './vibrancy/views/report-webview';

function getConfig() {
  return vscode.workspace.getConfiguration('saropaLints');
}

/**
 * D8: Show regression nudge when score dipped below a threshold.
 *
 * Four-layer protection against repeat / false-positive toasts:
 *
 * 1. **User opt-out (`saropaLints.regressionNudge.enabled`):** when off,
 *    no regression toasts fire at all. Defaults to on.
 *
 * 2. **Per-threshold memory in workspaceState:** once we have nudged
 *    about crossing band T (e.g. 50), we record T in
 *    [NUDGE_NOTIFIED_THRESHOLDS_KEY] and silently suppress further
 *    crossings of the same T until the score recovers clearly above
 *    that band. This kills the previous failure mode where the
 *    visibility gate released the moment the user dismissed the toast,
 *    so a score oscillating around an edge (89 \u2194 91) produced a fresh
 *    "below 90" toast on every save. Re-arm lives in
 *    [rearmNotifiedThresholds] and runs from `runCelebrationIfNeeded`.
 *
 * 3. **Two-snapshot confirmation ([NUDGE_PENDING_ANCHOR_KEY]):** a
 *    downward crossing detected on one snapshot is *pended*, not fired,
 *    and only confirmed if the next snapshot still scores below the same
 *    band. This defends against the dashboard-vs-toast misalignment seen
 *    when the IDE writes an intermediate partial sweep that crosses
 *    `MIN_COVERAGE_FOR_SCORE` (15%) but skews the score downward \u2014 the
 *    dashboard later shows a healthy 93 while a stale toast for "below
 *    50" had already fired from a 1-file batch. The anchor stores the
 *    pre-regression score so the confirming snapshot re-runs the
 *    crossing detector against the true baseline, preserving the lowest
 *    threshold crossed.
 *
 * 4. **Debounce (3 s):** the analyzer writes violations.json in batches
 *    >300ms apart, each crossing a lower threshold (70 \u2192 60 \u2192 50).
 *    The debounce coalesces rapid crossings and keeps only the worst
 *    (lowest) threshold before firing a single notification.
 */
const NUDGE_NOTIFIED_THRESHOLDS_KEY = 'saropaLints.regressionNudge.notifiedThresholds';
const NUDGE_PENDING_ANCHOR_KEY = 'saropaLints.regressionNudge.pendingAnchor';
const NO_ERRORS_CELEBRATED_KEY = 'saropaLints.noErrorsCelebrated';
// Required recovery above a notified band before we will nudge again
// for that band. 5 points is a full grade step in the score formula, so
// the score must climb solidly out of the band \u2014 not just bounce one
// point above the edge \u2014 before we'll fire a second toast for it.
const NUDGE_REARM_MARGIN = 5;

let regressionNudgeTimer: ReturnType<typeof setTimeout> | undefined;
let pendingNudgeCrossing: { threshold: number } | undefined;
let pendingNudgeSnapshot: RunSnapshot | undefined;

function readNotifiedThresholds(state: vscode.Memento): number[] {
  const raw = state.get<unknown>(NUDGE_NOTIFIED_THRESHOLDS_KEY);
  if (!Array.isArray(raw)) return [];
  return raw.filter((n): n is number => typeof n === 'number' && Number.isFinite(n));
}

function writeNotifiedThresholds(state: vscode.Memento, thresholds: number[]): void {
  void state.update(NUDGE_NOTIFIED_THRESHOLDS_KEY, thresholds);
}

/**
 * Re-arm regression nudges for any band the score has clearly climbed
 * out of. Called from `runCelebrationIfNeeded` on every recorded snapshot
 * so a band that was previously notified can fire again after a real
 * recovery, but small oscillations around the edge do not.
 */
function rearmNotifiedThresholds(state: vscode.Memento, currentScore: number): void {
  const notified = readNotifiedThresholds(state);
  if (notified.length === 0) return;
  const remaining = notified.filter((t) => currentScore < t + NUDGE_REARM_MARGIN);
  if (remaining.length !== notified.length) writeNotifiedThresholds(state, remaining);
}

/**
 * Read the pending-anchor (pre-regression score) from workspaceState.
 * Returns undefined when nothing is pending or the stored value is malformed
 * (defensive — workspaceState is opaque storage and a stale extension build
 * could have written a different shape).
 */
function readPendingAnchor(state: vscode.Memento): number | undefined {
  const raw = state.get<unknown>(NUDGE_PENDING_ANCHOR_KEY);
  return typeof raw === 'number' && Number.isFinite(raw) ? raw : undefined;
}

function writePendingAnchor(state: vscode.Memento, anchor: number | undefined): void {
  void state.update(NUDGE_PENDING_ANCHOR_KEY, anchor);
}

function showRegressionNudge(
  state: vscode.Memento,
  crossing: { threshold: number },
  curr: RunSnapshot,
): void {
  // Layer 1: setting opt-out. User can silence regression toasts entirely.
  if (getConfig().get<boolean>('regressionNudge.enabled', true) !== true) return;

  // Layer 2: memory gate. We have already nudged about this band and
  // the score has not recovered above (threshold + REARM_MARGIN), so a
  // fresh crossing in the same direction is the same news \u2014 stay quiet.
  if (readNotifiedThresholds(state).includes(crossing.threshold)) return;

  // Layer 3: keep whichever threshold is worse (lower) within the
  // coalesce window. During a multi-step slide (score drops through 70,
  // then 60, then 50) this ensures we show only the final "below 50"
  // toast, not all three.
  if (!pendingNudgeCrossing || crossing.threshold < pendingNudgeCrossing.threshold) {
    pendingNudgeCrossing = crossing;
  }
  pendingNudgeSnapshot = curr;

  if (regressionNudgeTimer) clearTimeout(regressionNudgeTimer);
  // 3 s: long enough that slow-lint batches coalesce, short enough
  // that the user still sees the nudge promptly after linting settles.
  regressionNudgeTimer = setTimeout(() => {
    regressionNudgeTimer = undefined;
    const c = pendingNudgeCrossing!;
    const s = pendingNudgeSnapshot!;
    pendingNudgeCrossing = undefined;
    pendingNudgeSnapshot = undefined;

    // Re-check the memory gate at fire time: a re-arm or a parallel
    // crossing for the same band could have updated state during the
    // 3 s coalesce window.
    const notifiedNow = readNotifiedThresholds(state);
    if (notifiedNow.includes(c.threshold)) return;
    writeNotifiedThresholds(state, [...notifiedNow, c.threshold]);

    const errorSuffix = s.error === 1 ? '' : 's';
    const msg =
      s.error > 0
        ? `${s.error} error${errorSuffix} \u2014 view.`
        : `Score dipped below ${c.threshold} \u2014 view issues.`;
    vscode.window.showInformationMessage(`Saropa Lints: ${msg}`, 'View Violations').then((choice) => {
      if (choice === 'View Violations') {
        vscode.commands.executeCommand('saropaLints.focusIssues');
      }
    });
  }, 3000);
}

/** Show celebration/milestone UI when a new snapshot was appended and history has at least 2 entries. */
function runCelebrationIfNeeded(
  state: vscode.Memento,
  root: string,
  history: RunSnapshot[],
  appended: boolean,
): void {
  if (!appended || history.length < 2) return;
  const prev = history.at(-2)!;
  const curr = history.at(-1)!;
  const delta = prev.total - curr.total;
  const scoreDelta =
    prev.score !== undefined && curr.score !== undefined
      ? formatScoreDelta(curr.score, prev.score)
      : '';
  if (delta > 0) {
    const scoreMsg = scoreDelta ? ` (Score: ${curr.score} ${scoreDelta})` : '';
    vscode.window.setStatusBarMessage(
      `You fixed ${delta} issue${delta === 1 ? '' : 's'}!${scoreMsg}`,
      5000,
    );
  }

  // Re-arm regression-nudge memory when the score has climbed clearly
  // above a previously-notified band. Runs every appended snapshot so a
  // genuine recovery → regression cycle still produces one toast per cycle.
  if (curr.score !== undefined) rearmNotifiedThresholds(state, curr.score);

  // Celebrate clearing all ERROR-severity diagnostics (must-fix), but at
  // most once per zero-streak. Without the persisted flag, an error count
  // that flickers 0 ↔ 1 across saves (intermediate analyzer batches that
  // briefly drop and re-add an error) re-fires the toast every time.
  // The flag re-arms the next time errors return so a real cleanup that
  // happens after a regression still earns a fresh "No errors!".
  if (curr.error > 0) {
    if (state.get<boolean>(NO_ERRORS_CELEBRATED_KEY) === true) {
      void state.update(NO_ERRORS_CELEBRATED_KEY, false);
    }
  } else if (prev.error > 0 && curr.error === 0) {
    if (state.get<boolean>(NO_ERRORS_CELEBRATED_KEY) !== true) {
      void state.update(NO_ERRORS_CELEBRATED_KEY, true);
      vscode.window.showInformationMessage('Saropa Lints: No errors!');
    }
  }

  if (curr.score === undefined) return;

  // Two-snapshot confirmation gate. A downward crossing detected last
  // snapshot was pended (not fired); this snapshot decides. Re-running
  // detectThresholdCrossing against the stored anchor (the pre-regression
  // score) returns the *current* lowest crossed band — important for a
  // genuine multi-step slide where the score has dropped further between
  // the pending and confirming snapshots.
  const pendingAnchor = readPendingAnchor(state);
  if (pendingAnchor !== undefined) {
    writePendingAnchor(state, undefined);
    const confirmed = detectThresholdCrossing(curr.score, pendingAnchor);
    if (confirmed?.direction === 'down') {
      showRegressionNudge(state, confirmed, curr);
      return;
    }
    // Anchor cleared without firing: the next-snapshot bounce-back is
    // evidence the prior dip was transient (partial sweep). Fall through
    // and let this snapshot independently start a new pending if it
    // crosses its own band.
  }

  const crossing = detectThresholdCrossing(curr.score, findPreviousScore(history));
  if (crossing?.direction === 'up') {
    logSection('Milestone');
    logReport(`- Score reached ${crossing.threshold} (current: ${curr.score})`);
    flushReport(root);
    // Status bar only: upward score bands fire during steady cleanup; notification
    // toasts stacked annoyingly (milestones at 50/60/70/80/90).
    vscode.window.setStatusBarMessage(
      `Saropa Lints: Health score reached ${crossing.threshold}`,
      5000,
    );
    return;
  }
  if (crossing?.direction === 'down') {
    // Pend, don't fire. The next snapshot either confirms (score is
    // still below the band — fire then) or clears (score recovered —
    // the dip was a transient partial sweep, stay quiet). The anchor
    // stores the pre-regression score so the confirming snapshot can
    // re-derive the lowest band crossed.
    const previousScore = findPreviousScore(history);
    if (previousScore !== undefined) writePendingAnchor(state, previousScore);
  }
}

function updateContext(enabled: boolean, hasViolations: boolean) {
  void vscode.commands.executeCommand('setContext', 'saropaLints.enabled', enabled);
  void vscode.commands.executeCommand('setContext', 'saropaLints.hasViolations', hasViolations);
}

/**
 * Dashboard-consistent view of violations:
 * apply disabled-rule filtering to the current report before computing scores.
 */
// Live source: the status bar and the views that call this now grade against
// the analyzer's current diagnostics, not the stale violations.json export.
// Always returns data (live is never "no report") — an empty result means the
// project is clean, which the status bar renders as a 100% score rather than a
// blank. Disabled rules are filtered so a muted rule never drags the grade.
function readVisibleViolations(root: string): ViolationsData {
  return readVisibleLiveViolations(root);
}

/**
 * Findings indicator merged into the unified Saropa status-bar item.
 *
 * Headlines the error count (must-fix) when there are errors, else the total
 * finding count. Returns null when the project is clean so the badge vanishes.
 * Was previously a SEPARATE status-bar item, which put a "98%" score right next
 * to a "⚠ 96" count — visually contradictory and cluttered. Folded into the one
 * item so there is a single Saropa entry. Error-headlining was keyed on
 * LintImpact.critical before the 5-bucket taxonomy retired 2026-05-03.
 */
function findingsBadge(
  data: ViolationsData | null,
): { suffix: string; tooltip: string } | null {
  const total = data?.summary?.totalViolations ?? data?.violations?.length ?? 0;
  if (total <= 0) return null;
  const errorCount = data?.summary?.byImpact?.error ?? 0;
  const shown = errorCount > 0 ? errorCount : total;
  const tooltip = errorCount > 0
    ? `${errorCount} error(s) of ${total} finding(s)`
    : `${total} finding(s)`;
  return { suffix: ` · $(warning) ${shown}`, tooltip };
}

function syncRuleMetadataFromViolations(data: ViolationsData | null): void {
  setRelatedRulesMetadata(data?.config?.relatedRulesByRule);
  setConflictingRulesMetadata(data?.config?.conflictingRulesByRule);
  setSupersedesRulesMetadata(data?.config?.supersedesRulesByRule);
  setRuleTagsMetadata(data?.config?.ruleMetadataByRule);
}

export function activate(context: vscode.ExtensionContext): SaropaLintsApi {
  const applyUiLocalePreference = (): string => {
    const cfg = vscode.workspace.getConfiguration('saropaLints');
    const preferred = cfg.get<string>('uiLanguage', 'auto') ?? 'auto';
    const requested = preferred === 'auto' ? vscode.env.language : preferred;
    return setCurrentLocale(requested);
  };
  applyUiLocalePreference();

  // Load the bundled rule-metadata catalog once so the live-diagnostics path can
  // attach per-rule type/status/security flags (a Diagnostic carries none). Cached
  // for the session; a missing asset degrades to an empty catalog, never throws.
  initRuleCatalog(context.extensionUri.fsPath);

  // Detect whether this workspace is a Dart/Flutter project so the UI can
  // show appropriate welcome content instead of a misleading "Enable" button.
  // getProjectRoot() searches workspace root then one-level-deep subdirectories.
  const root = getProjectRoot();
  const isDartProject = root !== undefined;
  void vscode.commands.executeCommand('setContext', 'saropaLints.isDartProject', isDartProject);
  updateSidebarSectionVisibility();
  registerSidebarSectionVisibility(context);

  const cfg = getConfig();
  const relatedRuleTelemetry = createRelatedRuleTelemetry(context.workspaceState);
  setRuleExplainTelemetry((event, props = {}) => {
    if (event === 'open') {
      relatedRuleTelemetry.track('ruleExplain.open', props);
      return;
    }
    if (event === 'relatedClick') {
      relatedRuleTelemetry.track('ruleExplain.relatedClick', props);
      return;
    }
    relatedRuleTelemetry.track('ruleExplain.docClick', props);
  });

  let enabled = cfg.get<boolean>('enabled', true) ?? true;

  // Auto-enable when saropa_lints is already in pubspec.yaml but the user
  // has not explicitly set `saropaLints.enabled`, so existing adopters are not
  // left with integration inactive — no files are touched; we flip the workspace flag.
  if (!enabled && isDartProject) {
    const inspection = cfg.inspect<boolean>('enabled');
    const explicitlySet = inspection?.workspaceValue !== undefined
      || inspection?.workspaceFolderValue !== undefined;
    if (!explicitlySet && root && hasSaropaLintsDep(root)) {
      enabled = true;
      // Fire-and-forget: persist so subsequent activations skip this check.
      void cfg.update('enabled', true, vscode.ConfigurationTarget.Workspace);
    }
  }

  // Match disk-backed violation report so `saropaLints.hasViolations` is correct on first tick.
  updateContext(enabled, root ? hasViolations(root) : false);

  const todosAndHacksProvider = new TodosAndHacksTreeProvider();
  const driftAdvisorDiagCollection = vscode.languages.createDiagnosticCollection('Saropa Drift Advisor');
  context.subscriptions.push(driftAdvisorDiagCollection);
  const driftAdvisorProvider = new DriftAdvisorTreeProvider(driftAdvisorDiagCollection);

  // Pubspec validation: inline diagnostics for dependency ordering,
  // version syntax, and constraint issues on pubspec.yaml.
  // Listeners are registered centrally in extension-activation.ts to
  // share a single pubspec.yaml watcher with SDK diagnostics.
  const pubspecValidator = createPubspecValidation(context);

  // Quick-fix code actions for pubspec validation diagnostics
  // (caret/pin syntax, publish_to, blank lines, resolution workspace)
  context.subscriptions.push(
    vscode.languages.registerCodeActionsProvider(
      { language: 'yaml', pattern: '**/pubspec.yaml' },
      new PubspecCodeActionProvider(),
      { providedCodeActionKinds: [vscode.CodeActionKind.QuickFix] },
    ),
  );

  const issuesProvider = new IssuesTreeProvider(context.workspaceState);
  const hotspotReviewState = new SecurityHotspotReviewStateService(context.workspaceState);
  const summaryProvider = new SummaryTreeProvider(context.workspaceState);
  const suppressionsProvider = new SuppressionsTreeProvider();
  const configProvider = new ConfigTreeProvider();
  // Sectioned sidebar: each VS Code view (Banner / Editor dashboards / Actions /
  // Status / Settings / Triage / Help) is its own collapsible panel. Items
  // inside each panel are flat leaves only — the panel title bar is the
  // only collapse handle, no chevrons appear next to rows.
  const sectionProviders = createSidebarSectionProviders(context.workspaceState, configProvider);
  const refreshAllSections = (): void => {
    for (const p of sectionProviders) p.refresh();
    updateSidebarSectionContext(context.workspaceState);
  };
  for (const provider of sectionProviders) {
    // The Help panel surfaces the installed version in its title. The version
    // must NOT be baked into the localized view name (package.nls used
    // "Help (vX.Y.Z)"): that froze the string per release, forced a manual bump
    // every version, and made it a perpetual missing translation in all 24
    // locales. Inject it at runtime via createTreeView().title so it tracks
    // package.json automatically while the word "Help" stays localized through
    // the runtime catalog. Other panels keep the lighter registerTreeDataProvider.
    if (provider.viewId === SECTION_VIEW_IDS.help) {
      const helpView = vscode.window.createTreeView(provider.viewId, {
        treeDataProvider: provider,
      });
      const helpExtVersion = (context.extension.packageJSON as { version: string }).version;
      helpView.title = `${l10n('findingsDash.menuPalette.help')} (v${helpExtVersion})`;
      context.subscriptions.push(helpView);
      continue;
    }
    context.subscriptions.push(
      vscode.window.registerTreeDataProvider(provider.viewId, provider),
    );
  }
  updateSidebarSectionContext(context.workspaceState);

  const securityProvider = new SecurityPostureTreeProvider();
  const fileRiskProvider = new FileRiskTreeProvider(context.workspaceState);

  // The dedicated "Suggestions" sidebar view was removed: its long
  // "Enable the X rule pack" list was noise. Proactive pack discovery now flows
  // through the single startup toast (maybeShowStartupSuggestion) whose action
  // opens the Manage Rule Packs webview — the one surface that lists every
  // applicable pack with a toggle and an "Enable all recommended packs" button.

  context.subscriptions.push(
    vscode.workspace.onDidChangeConfiguration((e) => {
      if (
        SIDEBAR_SECTION_CONFIG_KEYS.some((rel) =>
          e.affectsConfiguration(sidebarSectionContextKey(rel)),
        )
      ) {
        refreshAllSections();
      }
      if (e.affectsConfiguration('saropaLints.enabled') || e.affectsConfiguration('saropaLints.tier')) {
        refreshAllSections();
      }
    }),
  );

  context.subscriptions.push(
    todosAndHacksProvider.onDidChangeTreeData(() => {
      refreshAllSections();
    }),
    driftAdvisorProvider.onDidChangeTreeData(() => {
      refreshAllSections();
    }),
  );

  const rulePacksWebviewProvider = new RulePacksWebviewProvider(context.extensionUri);
  const reloadOpenDashboardsForLocale = (): void => {
    refreshFindingsDashboardIfOpen(context);
    rulePacksWebviewProvider.refresh();
    if (VibrancyReportPanel.currentPanel) {
      void vscode.commands.executeCommand('saropaLints.packageVibrancy.showReport');
    }
    refreshCodeHealthDashboardIfOpen();
  };

  registerCrossFileCommands(context);
  registerProjectMapCommand(context);
  registerHealthCodeLens(context);
  let driftAdvisorRefreshInProgress = false;

  let todosAndHacksSaveDebounce: ReturnType<typeof setTimeout> | undefined;
  context.subscriptions.push(
    vscode.workspace.onDidSaveTextDocument((doc) => {
      const base = doc.uri.fsPath.replaceAll('\\', '/');
      if (base.endsWith('/analysis_options.yaml') || base.endsWith('/analysis_options_custom.yaml')) {
        // Invalidate the disabled-rules cache so tree views pick up
        // rule enable/disable changes on the next refresh.
        invalidateDisabledRulesCache();
        if (base.endsWith('/analysis_options.yaml')) {
          rulePacksWebviewProvider.refresh();
        }
      }
      const cfg = vscode.workspace.getConfiguration('saropaLints.todosAndHacks');
      if (!cfg.get<boolean>('workspaceScanEnabled', false)) return;
      if (!cfg.get<boolean>('autoRefresh', true)) return;
      const folder = vscode.workspace.getWorkspaceFolder(doc.uri);
      if (!folder) return;
      if (todosAndHacksSaveDebounce) clearTimeout(todosAndHacksSaveDebounce);
      todosAndHacksSaveDebounce = setTimeout(() => {
        todosAndHacksSaveDebounce = undefined;
        todosAndHacksProvider.refresh();
      }, 600);
    }),
  );

  function updateIssuesViewMessage(): void {
    const state = issuesProvider.getFilterState();
    const focused = issuesProvider.getFocusedFile();
    void vscode.commands.executeCommand('setContext', 'saropaLints.hasIssuesFilter', state.hasActiveFilters);
    void vscode.commands.executeCommand('setContext', 'saropaLints.hasSuppressions', state.hasSuppressions);
    void vscode.commands.executeCommand('setContext', 'saropaLints.hasFocusedFile', focused !== undefined);
  }
  updateIssuesViewMessage();

  context.subscriptions.push(
    issuesProvider.onDidChangeTreeData(() => {
      refreshFindingsDashboardIfOpen(context);
      updateIssuesViewMessage();
    }),
  );

  registerIssueCommands(issuesProvider, context);
  registerCodeLensProvider(context);
  registerInlineAnnotations(context);

  context.subscriptions.push({
    dispose: () => {
      if (todosAndHacksSaveDebounce) clearTimeout(todosAndHacksSaveDebounce);
    },
  });

  const refreshAll = () => {
    const root = getProjectRoot();
    syncRuleMetadataFromViolations(root ? readViolations(root) : null);
    issuesProvider.refresh();
    refreshAllSections();
    summaryProvider.refresh();
    suppressionsProvider.refresh();
    configProvider.refresh();
    securityProvider.refresh();
    fileRiskProvider.refresh();
    rulePacksWebviewProvider.refresh();
    invalidateCodeLenses();
    updateIssuesViewMessage();
    // D3: Invalidate cache then refresh inline annotations for new data.
    invalidateAnnotationCache();
    updateAnnotationsForAllEditors();
  };

  void vscode.commands.executeCommand('setContext', 'saropaLints.driftAdvisor.connected', false);
  // Sync integration toggle button state on startup so toolbar shows correct icon immediately.
  void vscode.commands.executeCommand('setContext', 'saropaLints.driftAdvisor.integration', vscode.workspace.getConfiguration('saropaLints.driftAdvisor').get<boolean>('integration', false));

  let driftAdvisorPollTimer: ReturnType<typeof setInterval> | undefined;
  function scheduleDriftAdvisorPoll(): void {
    if (driftAdvisorPollTimer) {
      clearInterval(driftAdvisorPollTimer);
      driftAdvisorPollTimer = undefined;
    }
    const cfg = vscode.workspace.getConfiguration('saropaLints.driftAdvisor');
    if (!cfg.get<boolean>('integration', false)) return;
    const ms = cfg.get<number>('pollIntervalMs', 30000);
    if (ms <= 0) return;
    driftAdvisorPollTimer = setInterval(() => {
      void vscode.commands.executeCommand('saropaLints.driftAdvisor.refresh');
    }, ms);
  }
  scheduleDriftAdvisorPoll();
  if (vscode.workspace.getConfiguration('saropaLints.driftAdvisor').get<boolean>('integration', false)) {
    void vscode.commands.executeCommand('saropaLints.driftAdvisor.refresh');
  }
  // Poll dispose + workspace listeners registered together (one subscription batch).
  context.subscriptions.push(
    {
      dispose: () => {
        if (driftAdvisorPollTimer) clearInterval(driftAdvisorPollTimer);
      },
    },
    vscode.workspace.onDidChangeConfiguration((e) => {
      if (!e.affectsConfiguration('saropaLints')) return;
      if (e.affectsConfiguration('saropaLints.uiLanguage')) {
        applyUiLocalePreference();
        refreshAllSections();
        reloadOpenDashboardsForLocale();
      }
      if (e.affectsConfiguration('saropaLints.violationsGroupBy')) {
        issuesProvider.setGroupBy(parseViolationsGroupBy(vscode.workspace.getConfiguration('saropaLints')));
      }
      const c = getConfig();
      const en = c.get<boolean>('enabled', true) ?? true;
      updateContext(en, issuesProvider.hasViolations());
      refreshAll();
      if (e.affectsConfiguration('saropaLints.todosAndHacks')) {
        todosAndHacksProvider.refresh();
      }
      // Status bars must update when config changes (e.g. tier changed via Settings UI).
      updateAllStatusBars();
      if (e.affectsConfiguration('saropaLints.driftAdvisor')) {
        // Keep toolbar toggle icon in sync when setting changes via Settings UI.
        void vscode.commands.executeCommand('setContext', 'saropaLints.driftAdvisor.integration', vscode.workspace.getConfiguration('saropaLints.driftAdvisor').get<boolean>('integration', false));
        void vscode.commands.executeCommand('saropaLints.driftAdvisor.refresh');
        scheduleDriftAdvisorPoll();
      }
    }),
    vscode.workspace.onDidChangeWorkspaceFolders(() => {
      invalidateProjectRoot();
      refreshAll();
    }),
  );

  const violationsPath = (): string | null => {
    const root = getProjectRoot();
    return root ? path.join(root, 'reports', '.saropa_lints', 'violations.json') : null;
  };
  // Debounce refresh when violations.json changes to avoid rapid successive updates.
  let refreshDebounceTimer: ReturnType<typeof setTimeout> | undefined;
  const debouncedRefresh = () => {
    if (refreshDebounceTimer) clearTimeout(refreshDebounceTimer);
    refreshDebounceTimer = setTimeout(() => {
      refreshDebounceTimer = undefined;
      // W5/W6/H1: Record snapshot BEFORE refreshing views so tree providers
      // see the updated history (avoids stale findPreviousScore reads).
      const root = getProjectRoot();
      if (root) {
        const data = readVisibleViolations(root);
        if (data) {
          syncRuleMetadataFromViolations(readViolations(root));
          const { history, appended } = appendSnapshot(context.workspaceState, data);
          refreshAll();
          updateAllStatusBars(data);
          updateContext(getConfig().get<boolean>('enabled', true) ?? true, issuesProvider.hasViolations());
          runCelebrationIfNeeded(context.workspaceState, root, history, appended);
          return;
        }
      }
      // Fallback: no root or no data — still refresh views.
      syncRuleMetadataFromViolations(null);
      refreshAll();
    }, 300);
  };
  context.subscriptions.push({
    dispose: () => {
      if (refreshDebounceTimer) clearTimeout(refreshDebounceTimer);
      if (regressionNudgeTimer) clearTimeout(regressionNudgeTimer);
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

  // ── Auto-analyze on dependency changes ──────────────────────────────────
  // When pubspec.lock changes (after `pub get` / `pub upgrade` / extension
  // update that resolves new packages), stale violations.json no longer
  // reflects the current dependency tree.  This watcher debounces rapid
  // lock-file rewrites (burst `pub get` calls) and cancel-restarts: each
  // new change resets the timer so only one trailing analysis runs.
  {
    let depChangeTimer: ReturnType<typeof setTimeout> | undefined;
    // Guard against overlapping analysis runs — if a run is already in
    // flight (from the manual "Analyze" button or a prior timer fire),
    // skip the auto-trigger to avoid double progress toasts and contention.
    let analysisInFlight = false;

    const triggerAnalysisAfterDependencyChange = () => {
      // Cancel-restart: clear any pending timer so the most recent
      // pubspec.lock write wins and only one analysis runs.
      if (depChangeTimer) clearTimeout(depChangeTimer);

      // 10 s debounce — long enough for `pub get` to settle in a
      // multi-package workspace, short enough to feel responsive.
      // Vibrancy uses 30 s because its scan is much heavier; analysis
      // is lighter and the user expects near-immediate feedback.
      depChangeTimer = setTimeout(async () => {
        depChangeTimer = undefined;
        const cfg = getConfig();
        if (!(cfg.get<boolean>('runAnalysisAfterDependencyChange', true) ?? true)) return;
        if (analysisInFlight) return;
        analysisInFlight = true;
        try {
          const ok = await runAnalysisCommand(context);
          if (ok) {
            refreshAll();
            updateAllStatusBars();
            updateContext(
              cfg.get<boolean>('enabled', true) ?? true,
              issuesProvider.hasViolations(),
            );
          }
        } finally {
          analysisInFlight = false;
        }
      }, 10_000);
    };

    const depWatcher = vscode.workspace.createFileSystemWatcher('**/pubspec.lock');
    depWatcher.onDidChange(triggerAnalysisAfterDependencyChange);
    depWatcher.onDidCreate(triggerAnalysisAfterDependencyChange);
    // A resolved-version change (after `pub upgrade`) may bring the project into
    // range of a semver-gated migration pack; surface it through the single
    // coalesced suggestion toast rather than a competing per-pack notification.
    depWatcher.onDidChange(() => void maybeShowStartupSuggestion(context));
    depWatcher.onDidCreate(() => void maybeShowStartupSuggestion(context));
    context.subscriptions.push(depWatcher, {
      dispose: () => { if (depChangeTimer) clearTimeout(depChangeTimer); },
    });
  }

  // Surface applicable rule-pack suggestions in one coalesced toast on activation
  // (deferred so it never blocks startup); subsequent offers fire from the
  // pubspec.lock watcher above. The in-flight guard in the nudge collapses any
  // overlap between this timer and the watcher to a single notification.
  setTimeout(() => void maybeShowStartupSuggestion(context), 4_000);

  syncRuleMetadataFromViolations(root ? readViolations(root) : null);

  const extVersion = (context.extension.packageJSON as { version: string }).version;

  const statusBarItem = vscode.window.createStatusBarItem(vscode.StatusBarAlignment.Right, 100);
  context.subscriptions.push(statusBarItem);

  // Vibrancy data pushed from the vibrancy subsystem via callback.
  let vibrancyData: VibrancyStatusData | null = null;

  /** Build tooltip lines for the status bar (version, tier, score, vibrancy details). */
  function buildStatusBarTooltipLines(
    tier: string,
    health: { score: number } | null,
    showVibrancy: boolean,
    vibrancyLabel: string | null,
    scorePending: boolean,
  ): string[] {
    const base = [`Saropa Lints v${extVersion}`, `Tier: ${tier}`];
    if (health) {
      base.push(`Lint score: ${health.score}%`);
    } else if (scorePending) {
      // The report covers too little of the project to score reliably. Tell
      // the user how to get a real score instead of leaving the line blank.
      base.push('Lint score: run a full analysis (partial scan)');
    }
    if (showVibrancy && vibrancyData !== null) {
      // "Scanned" counts everything; the suffix explains why the assessment
      // numbers below (vibrancy, updates) are over the smaller active set.
      const scanned =
        vibrancyData.suppressedCount > 0
          ? `${vibrancyData.packageCount} packages scanned (${vibrancyData.suppressedCount} suppressed)`
          : `${vibrancyData.packageCount} packages scanned`;
      base.push(`Vibrancy: ${vibrancyLabel}`, scanned);
      if (vibrancyData.updateCount > 0) base.push(`${vibrancyData.updateCount} update(s) available`);
      if (vibrancyData.actionCount > 0) base.push(`${vibrancyData.actionCount} action item(s)`);
    }
    return base;
  }

  // Single unified status bar item showing lint score, tier, and vibrancy.
  // Accepts optional pre-loaded data to avoid re-reading violations.json from disk
  // when the caller already has it (e.g. debouncedRefresh).
  const updateAllStatusBars = (preloadedData?: ViolationsData) => {
    if (!isDartProject) {
      // Surface the version even outside a Dart workspace so users can verify
      // that a fresh build has loaded — previously the bar was hidden here and
      // the only version readout was a tooltip on a tree that itself required
      // a Dart project to render. That made "is my build live?" unanswerable
      // before opening a project.
      statusBarItem.text = `$(checklist) Saropa Lints v${extVersion}`;
      statusBarItem.tooltip = `Saropa Lints v${extVersion} — open a folder containing pubspec.yaml to enable analysis.`;
      statusBarItem.backgroundColor = undefined;
      statusBarItem.command = 'saropaLints.showAbout';
      statusBarItem.show();
      return;
    }
    const en = getConfig().get<boolean>('enabled', true) ?? true;
    const tier = getConfig().get<string>('tier', 'recommended') ?? 'recommended';
    const showVibrancy =
      vscode.workspace.getConfiguration('saropaLints.packageVibrancy').get<boolean>('showInStatusBar', true) &&
      vibrancyData !== null;
    const vibrancyLabel = showVibrancy ? `${Math.round(vibrancyData!.averageScore / 10)}/10` : null;

    if (en) {
      const root = getProjectRoot();
      // Live + disabled-filtered: the score matches the Problems panel and never
      // counts a muted rule. (Was the raw, file-based readViolations.)
      const data = preloadedData ?? (root ? readVisibleViolations(root) : null);
      const health = data ? computeHealthScore(data) : null;
      // Finding count folded into this single item (was a separate ⚠ entry).
      const badge = findingsBadge(data);
      const badgeSuffix = badge?.suffix ?? '';
      if (health) {
        const history = loadHistory(context.workspaceState);
        const prevScore = findPreviousScore(history);
        const delta = prevScore === undefined ? '' : ` ${formatScoreDelta(health.score, prevScore)}`;
        const detailLabel = buildStatusBarLabel({
          hasHealth: true,
          healthScore: health.score,
          delta,
          tier,
          showVibrancy,
          vibrancyLabel,
        });
        statusBarItem.text = `$(checklist) Saropa: ${detailLabel}${badgeSuffix}`;
        // Never paint the score onto a colored (esp. red) status-bar
        // background — a low lint score is informational, not an error, and a
        // red fill reads as "broken". The number alone carries the signal.
        statusBarItem.backgroundColor = undefined;
      } else {
        statusBarItem.text = `$(checklist) ${buildStatusBarLabel({
          hasHealth: false,
          tier,
          showVibrancy,
          vibrancyLabel,
        })}${badgeSuffix}`;
        statusBarItem.backgroundColor = undefined;
      }
      // "Score pending": we have a report but it covers too little of the
      // project to score (partial IDE sweep) — surface a hint, not a blank.
      const scorePending = health === null && data !== null && isReportTooPartial(data);
      const tooltipLines = buildStatusBarTooltipLines(
        tier,
        health,
        showVibrancy,
        vibrancyLabel,
        scorePending,
      );
      if (badge) tooltipLines.push(badge.tooltip);
      statusBarItem.tooltip = tooltipLines.join('\n');
      // Click opens the Findings Dashboard (the most actionable destination)
      // now that this item also carries the finding count.
      statusBarItem.command = 'saropaLints.openViolationsWideReport';
    } else {
      statusBarItem.text = '$(checklist) Saropa Lints: Off';
      statusBarItem.tooltip = `Saropa Lints v${extVersion} — Disabled`;
      statusBarItem.backgroundColor = undefined;
      statusBarItem.command = 'saropaLints.editorDashboards.focus';
    }
    statusBarItem.show();
  };
  updateAllStatusBars();

  // The status-bar score and Issues tree now read live diagnostics, so they must
  // refresh when the analyzer updates them — otherwise they would only move on an
  // explicit command and re-introduce the very staleness this migration removes.
  // Debounced to coalesce the per-file burst VS Code emits during one analysis
  // pass into a single refresh (same 400ms the consolidated dashboard uses).
  let diagnosticsRefreshTimer: NodeJS.Timeout | undefined;
  context.subscriptions.push(
    vscode.languages.onDidChangeDiagnostics(() => {
      if (diagnosticsRefreshTimer) clearTimeout(diagnosticsRefreshTimer);
      diagnosticsRefreshTimer = setTimeout(() => {
        diagnosticsRefreshTimer = undefined;
        updateAllStatusBars();
        issuesProvider.refresh();
        // Code lenses and inline annotations also read live diagnostics now, so
        // refresh them on the same debounced tick rather than only when
        // violations.json is rewritten.
        invalidateCodeLenses();
        invalidateAnnotationCache();
        updateAnnotationsForAllEditors();
        updateContext(
          getConfig().get<boolean>('enabled', true) ?? true,
          issuesProvider.hasViolations(),
        );
        // R1: refresh the offline envelope mirror the sibling suite tools read
        // (.saropa/diagnostics/lints.json). Same settled live-diagnostics source
        // the surfaces above use, so the mirror never disagrees with the UI. A
        // write failure (read-only tree, race) must never disrupt linting.
        const envelopeRoot = getProjectRoot();
        if (envelopeRoot) {
          try {
            exportLintsEnvelope(envelopeRoot, extVersion);
          } catch (err) {
            console.error('saropa_lints: could not write diagnostics envelope:', err);
          }
        }
      }, 400);
    }),
    { dispose: () => diagnosticsRefreshTimer && clearTimeout(diagnosticsRefreshTimer) },
  );

  // R4: contribute the suite's deep-link command ids (enableRule, openFinding) as
  // Lints' public integration surface for sibling envelope `fix.command`s.
  registerSuiteCommands(context, getProjectRoot);

  // R3: crash-to-rule attribution. When Log Capture records a runtime crash whose
  // preventing Lints rule is disabled, offer a once-only "enable rule X" toast.
  // Fire on activation and whenever Log Capture rewrites its crash mirror; the
  // nudge gates per-rule in globalState so a re-written mirror never re-nags.
  {
    const nudgeCrashCoverage = () => {
      const root = getProjectRoot();
      if (root) void maybeNudgeCrashCoveredRule(context, root);
    };
    nudgeCrashCoverage();
    const crashMirrorWatcher = vscode.workspace.createFileSystemWatcher(
      '**/.saropa/diagnostics/log-capture.json',
    );
    crashMirrorWatcher.onDidChange(nudgeCrashCoverage);
    crashMirrorWatcher.onDidCreate(nudgeCrashCoverage);
    context.subscriptions.push(crashMirrorWatcher);
  }

  context.subscriptions.push(
    vscode.commands.registerCommand('saropaLints.enable', async () => {
      const success = await runEnable(context);
      if (!success) return;

      await cfg.update('enabled', true, vscode.ConfigurationTarget.Workspace);
      updateContext(true, issuesProvider.hasViolations());

      // I5: Record snapshot before refreshing views so Overview sees fresh history.
      const root = getProjectRoot();
      const data = root ? readVisibleViolations(root) : null;
      if (data) {
        appendSnapshot(context.workspaceState, data);
      }

      refreshAll();
      updateAllStatusBars(data ?? undefined);

      // I5: Auto-focus Overview to show Health Score immediately.
      await vscode.commands.executeCommand('saropaLints.editorDashboards.focus');

      // I5: Show score-aware notification with actionable buttons.
      const health = data ? computeHealthScore(data) : null;
      const totalViolations = data?.summary?.totalViolations ?? data?.violations?.length ?? 0;

      // Report: log enable result with score.
      if (root) {
        logSection('Enable Result');
        if (health) {
          logReport(`- Score: ${health.score}%`);
        }
        logReport(`- Violations: ${totalViolations}`);
        flushReport(root);
      }

      // Plugin liveness probe: detect the "analyzer launched the plugin but
      // zero diagnostics flow" failure mode. Before the fix for the
      // `Directory.current` bug (config_loader reading config relative to
      // the wrong cwd), this was the default experience for any consumer
      // who opened VS Code via the file picker rather than `code .` from
      // the project folder — the plugin registered no rules and silently
      // produced no warnings. The probe reads violations.json (written by
      // the plugin itself) and surfaces a specific, actionable warning if
      // the plugin wrote no report, loaded zero rules, or analyzed zero
      // files. Skipped silently when the plugin is alive.
      if (root) {
        const liveness = verifyPluginLiveness(root);
        logReport(`- Liveness: ${liveness.status}`);
        logReport(`- Enabled rules: ${liveness.enabledRuleCount}`);
        logReport(`- Files analyzed: ${liveness.filesAnalyzed}`);
        flushReport(root);
        await surfaceLivenessResult(liveness, getSharedOutputChannel());
      }

      await showFirstRunNotification(health, totalViolations);
    }),
    vscode.commands.registerCommand('saropaLints.disable', async () => {
      await runDisable();
      await cfg.update('enabled', false, vscode.ConfigurationTarget.Workspace);
      updateContext(false, false);
      refreshAll();
      updateAllStatusBars();
    }),
    // Standalone liveness check. Users hit this from the command palette when
    // they suspect saropa_lints is silent (Problems pane empty even though
    // the plugin is declared in analysis_options.yaml). The probe returns
    // an explicit status — `alive`, `no-report`, `config-not-loaded`, or
    // `no-files-analyzed` — and surfaces a warning with the recovery step
    // when the plugin is mis-wired. When alive, the command shows a brief
    // confirmation (because the user explicitly asked) with the enabled
    // rule count, so they can see the plugin is doing its job.
    vscode.commands.registerCommand('saropaLints.verifyPlugin', async () => {
      const root = getProjectRoot();
      if (!root) {
        await vscode.window.showErrorMessage(
          'Saropa Lints: no workspace folder is open. Open your Dart/Flutter project first.',
        );
        return;
      }
      const liveness = verifyPluginLiveness(root);
      if (liveness.status === 'alive') {
        await vscode.window.showInformationMessage(
          `Saropa Lints is alive: ${liveness.enabledRuleCount} rules enabled, ` +
          `${liveness.filesAnalyzed} files analyzed.`,
        );
        return;
      }
      await surfaceLivenessResult(liveness, getSharedOutputChannel());
    }),
    vscode.commands.registerCommand('saropaLints.runAnalysis', async () => {
      const ok = await runAnalysisCommand(context);
      if (ok) {
        refreshAll();
        updateAllStatusBars();
        updateContext(getConfig().get<boolean>('enabled', true) ?? true, issuesProvider.hasViolations());
        // C7: Focus Overview after analysis to show Health Score delta.
        await vscode.commands.executeCommand('saropaLints.editorDashboards.focus');
        // C7: Include score in completion message when available.
        const root = getProjectRoot();
        const postData = root ? readViolations(root) : null;
        const health = postData ? computeHealthScore(postData) : null;
        const scoreMsg = health ? ` Score: ${health.score}` : '';
        vscode.window.setStatusBarMessage(`Saropa Lints: Analysis complete.${scoreMsg}`, 4000);
      }
    }),
    vscode.commands.registerCommand('saropaLints.initializeConfig', async () => {
      const success = await runInitializeConfig(context);
      if (success) {
        // C6: Auto-run analysis after config change if setting is on.
        const runAfter = getConfig().get<boolean>('runAnalysisAfterConfigChange', true) ?? true;
        if (runAfter) {
          await runAnalysisCommand(context);
        }
        refreshAll();
        updateAllStatusBars();
        updateContext(getConfig().get<boolean>('enabled', true) ?? true, issuesProvider.hasViolations());
      }
    }),
    // One-click enable of a rule pack (used by the startup toast follow-through
    // and programmatic callers). Writes the pack into analysis_options.yaml,
    // refreshes the Manage Rule Packs webview, and confirms with a toast naming
    // the pack — so the user sees the exact thing that changed.
    vscode.commands.registerCommand('saropaLints.enableRulePack', async (packId?: unknown) => {
      const id = typeof packId === 'string' ? packId : '';
      const root = getProjectRoot();
      if (!id || !root) return;
      const enabled = readRulePacksEnabled(root);
      if (enabled.includes(id)) {
        rulePacksWebviewProvider.refresh();
        return;
      }
      const ok = writeRulePacksEnabled(root, [...enabled, id].sort());
      if (!ok) {
        void vscode.window.showErrorMessage(
          l10n('configSuggestions.enableFailed', { pack: id }),
        );
        return;
      }
      rulePacksWebviewProvider.refresh();
      void vscode.window.showInformationMessage(
        l10n('configSuggestions.enabledToast', { pack: id }),
      );
      // Re-analyze so the newly-enabled pack's rules surface immediately, matching
      // the post-config-change behavior of the init command.
      const runAfter = getConfig().get<boolean>('runAnalysisAfterConfigChange', true) ?? true;
      if (runAfter) {
        await runAnalysisCommand(context);
        refreshAll();
      }
    }),
    vscode.commands.registerCommand('saropaLints.emitCompositePluginScaffold', async () => {
      await runEmitCompositePluginScaffold();
    }),
    vscode.commands.registerCommand('saropaLints.openConfig', openConfig),
    // Open pubspec.yaml — paired with the sidebar "Detected" row so a click on
    // that row takes the user to the file whose contents it summarizes.
    // Same multi-root guard as openConfig: never default to workspaceFolders[0].
    vscode.commands.registerCommand('saropaLints.openPubspec', async () => {
      const folder = await pickWorkspaceFolder({
        placeHolder: 'Choose the project whose pubspec.yaml to open',
      });
      if (!folder) return;
      const uri = vscode.Uri.file(path.join(folder.uri.fsPath, 'pubspec.yaml'));
      try {
        const doc = await vscode.workspace.openTextDocument(uri);
        await vscode.window.showTextDocument(doc);
      } catch (e) {
        const msg = e instanceof Error ? e.message : String(e);
        void vscode.window.showErrorMessage(`Failed to open pubspec.yaml: ${msg}`);
      }
    }),
    // One-click toggle for the "Run analysis after config change" sidebar row.
    // Writing the boolean directly avoids dragging the user into the Settings
    // UI just to flip a checkbox; the row label updates on the next refresh.
    vscode.commands.registerCommand('saropaLints.toggleRunAnalysisAfterConfigChange', async () => {
      const cfg = vscode.workspace.getConfiguration('saropaLints');
      const cur = cfg.get<boolean>('runAnalysisAfterConfigChange', true) ?? true;
      const target = vscode.workspace.workspaceFolders?.length
        ? vscode.ConfigurationTarget.Workspace
        : vscode.ConfigurationTarget.Global;
      await cfg.update('runAnalysisAfterConfigChange', !cur, target);
      refreshAllSections();
    }),
    // One-click toggle for "Run analysis after dependency change" sidebar row.
    vscode.commands.registerCommand('saropaLints.toggleRunAnalysisAfterDependencyChange', async () => {
      const cfg = vscode.workspace.getConfiguration('saropaLints');
      const cur = cfg.get<boolean>('runAnalysisAfterDependencyChange', true) ?? true;
      const target = vscode.workspace.workspaceFolders?.length
        ? vscode.ConfigurationTarget.Workspace
        : vscode.ConfigurationTarget.Global;
      await cfg.update('runAnalysisAfterDependencyChange', !cur, target);
      refreshAllSections();
    }),
    vscode.commands.registerCommand(
      'saropaLints.toggleTodosAndHacksScanner',
      async () => {
        // Note: writes to the EXISTING setting key
        // `saropaLints.todosAndHacks.workspaceScanEnabled` — no migration.
        // This command exists so the scanner toggle is invokable from the
        // palette and the dashboard pill without duplicating the setting.
        const cfg = vscode.workspace.getConfiguration('saropaLints.todosAndHacks');
        const cur = cfg.get<boolean>('workspaceScanEnabled', false);
        const target = vscode.workspace.workspaceFolders?.length
          ? vscode.ConfigurationTarget.Workspace
          : vscode.ConfigurationTarget.Global;
        await cfg.update('workspaceScanEnabled', !cur, target);
        refreshAllSections();
        refreshFindingsDashboardIfOpen(context);
      },
    ),
    vscode.commands.registerCommand('saropaLints.pickUiLanguage', async () => {
      const cfg = vscode.workspace.getConfiguration('saropaLints');
      const current = cfg.get<string>('uiLanguage', 'auto') ?? 'auto';
      const picked = await vscode.window.showQuickPick<LanguagePickItem>(
        buildUiLanguageQuickPickItems(),
        {
          title: l10n('uiLanguage.pick.title'),
          placeHolder: l10n('uiLanguage.pick.placeholder'),
        },
      );
      if (!picked || picked.value === current) return;
      // User settings: workspace-level writes can fail on some hosts (e.g. policy
      // or manifest edge cases) with "not a registered configuration"; UI
      // language is a personal preference and should match other global UX.
      await cfg.update('uiLanguage', picked.value, vscode.ConfigurationTarget.Global);
      const locale = applyUiLocalePreference();
      refreshAllSections();
      reloadOpenDashboardsForLocale();
      // Manifest NLS labels (activity bar, command titles, settings) are baked
      // at activation by VS Code and cannot be hot-swapped. A window reload is
      // required for those strings to pick up the new locale. Dashboards and
      // webviews refresh immediately via reloadOpenDashboardsForLocale above.
      const reloadChoice = await vscode.window.showInformationMessage(
        l10n('uiLanguage.reloadPrompt', { locale }),
        l10n('uiLanguage.reloadNow'),
        l10n('uiLanguage.reloadLater'),
      );
      if (reloadChoice === l10n('uiLanguage.reloadNow')) {
        await vscode.commands.executeCommand('workbench.action.reloadWindow');
      }
    }),
    vscode.commands.registerCommand('saropaLints.toggleSidebarSection', async (key: unknown) => {
      if (typeof key !== 'string') {
        // Command was invoked without a valid section key (e.g. from the
        // command palette where no argument is passed).  Nothing to toggle.
        return;
      }
      try {
        const cfg = vscode.workspace.getConfiguration('saropaLints');
        const def = defaultSidebarSectionVisible(key);
        const cur = cfg.get<boolean>(key, def) ?? def;
        const next = !cur;
        const target = vscode.workspace.workspaceFolders?.length
          ? vscode.ConfigurationTarget.Workspace
          : vscode.ConfigurationTarget.Global;
        await cfg.update(key, next, target);
        updateSidebarSectionVisibility();
        refreshAllSections();
      } catch (err) {
        // Surface config-update failures so the user sees feedback.
        const msg = err instanceof Error ? err.message : String(err);
        console.error(`toggleSidebarSection error for "${key}": ${msg}`);
        void vscode.window.showErrorMessage(
          `Saropa Lints: failed to toggle sidebar section — ${msg}`,
        );
      }
    }),
    vscode.commands.registerCommand('saropaLints.openRulePacks', () => {
      rulePacksWebviewProvider.openEditorPanel();
    }),
    vscode.commands.registerCommand('saropaLints.openConfigDashboard', () => {
      rulePacksWebviewProvider.openEditorPanel();
    }),
    vscode.commands.registerCommand('saropaLints.openPackageVibrancy', async () => {
      await vscode.commands.executeCommand('saropaLints.packageVibrancy.showReport');
      if (getLatestResults().length === 0) {
        await vscode.commands.executeCommand('saropaLints.packageVibrancy.scan');
      }
    }),
    vscode.commands.registerCommand('saropaLints.openViolationsWideReport', async () => {
      await openViolationsWideReport(context);
    }),
    vscode.commands.registerCommand('saropaLints.revealFindingsDashboard', async () => {
      await openViolationsWideReport(context);
    }),
    vscode.commands.registerCommand('saropaLints.openConsolidatedDashboard', () => {
      openConsolidatedDashboard(context);
    }),
    vscode.commands.registerCommand('saropaLints.openProjectVibrancyReport', async () => {
      await openProjectVibrancyReport();
    }),
    vscode.commands.registerCommand('saropaLints.openProjectVibrancySettings', async () => {
      await vscode.commands.executeCommand('workbench.action.openSettings', 'saropaLints.projectVibrancy');
    }),
    vscode.commands.registerCommand('saropaLints.openWalkthrough', () => {
      void vscode.commands.executeCommand(
        'workbench.action.openWalkthrough',
        'saropa.saropa-lints#saropaLints.gettingStarted',
        false,
      );
    }),
    vscode.commands.registerCommand('saropaLints.openHelpHub', () => {
      void showHelpHubQuickPick();
    }),
    vscode.commands.registerCommand('saropaLints.showAbout', () => {
      showAboutPanel(context.extensionUri, extVersion);
    }),
    vscode.commands.registerCommand('saropaLints.showCommandCatalog', () => {
      showCommandCatalogPanel(context);
    }),
    vscode.commands.registerCommand('saropaLints.openPubDevSaropaLints', () => {
      void vscode.env.openExternal(vscode.Uri.parse('https://pub.dev/packages/saropa_lints'));
    }),
    // Creates .cursor/rules/saropa_lints_instructions.mdc from bundled template for AI agent guidelines.
    vscode.commands.registerCommand('saropaLints.createSaropaInstructions', async () => {
      // Multi-root bug: previously hard-coded `workspaceFolders?.[0]`, which
      // wrote into whichever folder happened to be first in the workspace
      // (e.g. saropa_drift_advisor) rather than the project the user was
      // actually working on. Pick the active editor's folder when available;
      // otherwise prompt so the user controls the destination explicitly.
      const folder = await pickWorkspaceFolder({
        placeHolder: 'Choose the project that should receive the Saropa Lints AI agent instructions',
      });
      if (!folder) {
        void vscode.window.showErrorMessage('Open a workspace folder first.');
        return;
      }
      const rulesDir = path.join(folder.uri.fsPath, '.cursor', 'rules');
      const destPath = path.join(rulesDir, 'saropa_lints_instructions.mdc');
      const templatePath = path.join(context.extensionUri.fsPath, 'media', 'saropa_lints_instructions.mdc');
      try {
        await vscode.window.withProgress(
          {
            location: vscode.ProgressLocation.Notification,
            title: 'Creating Saropa Lints instructions…',
            cancellable: false,
          },
          async () => {
            await fs.promises.mkdir(rulesDir, { recursive: true });
            await fs.promises.copyFile(templatePath, destPath);
          },
        );
        void vscode.window.showInformationMessage(
          'Created .cursor/rules/saropa_lints_instructions.mdc for AI agents.',
        );
        const doc = await vscode.workspace.openTextDocument(destPath);
        void vscode.window.showTextDocument(doc);
      } catch (e) {
        const msg = e instanceof Error ? e.message : String(e);
        void vscode.window.showErrorMessage(`Failed to create Saropa Lints instructions: ${msg}`);
      }
    }),
    vscode.commands.registerCommand('saropaLints.focusView', async () => {
      // After consolidating Dashboards + Overview into a single flat view,
      // `focusView` is a backwards-compat alias for revealing the unified sidebar.
      await vscode.commands.executeCommand('saropaLints.editorDashboards.focus');
    }),
    vscode.commands.registerCommand('saropaLints.focusPackageVibrancyPackages', async () => {
      await vscode.commands.executeCommand('saropaLints.packageVibrancy.showReport');
    }),
    // Show all findings: clear filters and focus Violations view (e.g. from Summary "Total violations").
    vscode.commands.registerCommand('saropaLints.focusIssues', () => {
      issuesProvider.clearFilters();
      updateIssuesViewMessage();
      issuesProvider.expandAll();
      void vscode.commands.executeCommand('saropaLints.revealFindingsDashboard');
    }),
    // Focus Violations view filtered to a single file (Code Lens, Problems view "Show in Saropa Lints").
    vscode.commands.registerCommand('saropaLints.focusIssuesForFile', (filePath: string) => {
      const normalized = typeof filePath === 'string' ? filePath.replaceAll('\\', '/') : '';
      if (!normalized) return;
      issuesProvider.setTextFilter(normalized);
      updateIssuesViewMessage();
      issuesProvider.expandAll();
      void vscode.commands.executeCommand('saropaLints.revealFindingsDashboard');
    }),
    // Open file in editor AND filter Violations view (File Risk tree click).
    vscode.commands.registerCommand('saropaLints.openFileAndFocusIssues', (filePath: string) => {
      const normalized = typeof filePath === 'string' ? filePath.replaceAll('\\', '/') : '';
      if (!normalized) return;
      // Open the file in the editor so the user can see the source.
      const root = getProjectRoot();
      if (root) {
        const absPath = path.resolve(root, normalized);
        void vscode.window.showTextDocument(vscode.Uri.file(absPath), { preview: true });
      }
      // Also filter the Violations view to this file.
      issuesProvider.setTextFilter(normalized);
      updateIssuesViewMessage();
      issuesProvider.expandAll();
    }),
    // Focus Violations view filtered to the active editor's file (e.g. from Problems view context menu).
    vscode.commands.registerCommand('saropaLints.focusIssuesForActiveFile', () => {
      const root = getProjectRoot();
      const editor = vscode.window.activeTextEditor;
      if (!root || !editor?.document?.uri) {
        void vscode.window.showInformationMessage('Open a file to show its issues in Saropa Lints.');
        return;
      }
      const relative = path.relative(root, editor.document.uri.fsPath).replaceAll('\\', '/');
      // Reuse text filter path matching instead of adding a second "file-only"
      // code path inside IssuesTreeProvider.
      issuesProvider.setTextFilter(relative);
      updateIssuesViewMessage();
      issuesProvider.expandAll();
      void vscode.commands.executeCommand('saropaLints.revealFindingsDashboard');
    }),
    vscode.commands.registerCommand('saropaLints.focusIssuesWithImpactFilter', (impact: string) => {
      if (impact && typeof impact === 'string') {
        issuesProvider.setImpactFilter(new Set([impact]));
        issuesProvider.setSeverityFilter(new Set(['error', 'warning', 'info']));
        updateIssuesViewMessage();
        issuesProvider.expandAll();
        void vscode.commands.executeCommand('saropaLints.revealFindingsDashboard');
      }
    }),
    vscode.commands.registerCommand('saropaLints.focusIssuesWithSeverityFilter', (severity: string) => {
      if (severity && typeof severity === 'string') {
        issuesProvider.setSeverityFilter(new Set([severity]));
        issuesProvider.setImpactFilter(new Set(['critical', 'high', 'medium', 'low', 'opinionated']));
        updateIssuesViewMessage();
        issuesProvider.expandAll();
        void vscode.commands.executeCommand('saropaLints.revealFindingsDashboard');
      }
    }),
    vscode.commands.registerCommand('saropaLints.refresh', () => {
      refreshAll();
      updateAllStatusBars();
      updateContext(getConfig().get<boolean>('enabled', true) ?? true, issuesProvider.hasViolations());
    }),
    vscode.commands.registerCommand('saropaLints.todosAndHacks.refresh', () => {
      const tcfg = vscode.workspace.getConfiguration('saropaLints.todosAndHacks');
      if (tcfg.get<boolean>('workspaceScanEnabled', false)) {
        void vscode.window.setStatusBarMessage('Saropa TODOs & Hacks: scanning…', 4000);
      }
      todosAndHacksProvider.refresh();
      void vscode.commands.executeCommand('saropaLints.revealFindingsDashboard');
    }),
    vscode.commands.registerCommand('saropaLints.todosAndHacks.toggleGroupByTag', async () => {
      const cfg = vscode.workspace.getConfiguration('saropaLints.todosAndHacks');
      const scanOn = cfg.get<boolean>('workspaceScanEnabled', false);
      const current = cfg.get<boolean>('groupByTag', false);
      await cfg.update('groupByTag', !current, vscode.ConfigurationTarget.Workspace);
      if (scanOn) {
        void vscode.window.setStatusBarMessage('Saropa TODOs & Hacks: scanning…', 4000);
      }
      todosAndHacksProvider.refresh();
      void vscode.commands.executeCommand('saropaLints.revealFindingsDashboard');
    }),
    vscode.commands.registerCommand('saropaLints.todosAndHacks.enableWorkspaceScan', async () => {
      const tcfg = vscode.workspace.getConfiguration('saropaLints.todosAndHacks');
      await tcfg.update('workspaceScanEnabled', true, vscode.ConfigurationTarget.Workspace);
      todosAndHacksProvider.refresh();
      void vscode.commands.executeCommand('saropaLints.revealFindingsDashboard');
    }),
    vscode.commands.registerCommand('saropaLints.driftAdvisor.refresh', async () => {
      const cfg = vscode.workspace.getConfiguration('saropaLints.driftAdvisor');
      if (!cfg.get<boolean>('integration', false)) {
        driftAdvisorProvider.setState(null, []);
        await onDriftAdvisorDisconnected(context.workspaceState);
        void vscode.commands.executeCommand('setContext', 'saropaLints.driftAdvisor.connected', false);
        refreshAllSections();
        return;
      }
      if (driftAdvisorRefreshInProgress) return;
      driftAdvisorRefreshInProgress = true;
      void vscode.window.setStatusBarMessage('Saropa Drift Advisor: discovering server…', 4000);
      driftAdvisorProvider.setLoading(true);
      const portRange = cfg.get<number[]>('portRange', [8642, 8649]);
      const portMin = Array.isArray(portRange) && portRange.length >= 1 ? Math.max(1, portRange[0]) : 8642;
      const portMax = Array.isArray(portRange) && portRange.length >= 2 ? Math.min(65535, portRange[1]) : 8649;
      try {
        const server = await discoverServer(portMin, portMax);
        if (!server) {
          driftAdvisorProvider.setState(null, []);
          await onDriftAdvisorDisconnected(context.workspaceState);
          void vscode.commands.executeCommand('setContext', 'saropaLints.driftAdvisor.connected', false);
          void vscode.window.setStatusBarMessage('Saropa Drift Advisor: no server found', 5000);
          return;
        }
        const issues = await fetchIssues(server);
        const mapped = await mapIssuesToLocations(issues);
        driftAdvisorProvider.setState(server, mapped);
        setDriftAdvisorServerConnected(true);
        void vscode.commands.executeCommand('setContext', 'saropaLints.driftAdvisor.connected', true);
        void vscode.window.setStatusBarMessage('Saropa Drift Advisor: connected', 3000);
      } catch {
        driftAdvisorProvider.setState(null, []);
        await onDriftAdvisorDisconnected(context.workspaceState);
        void vscode.commands.executeCommand('setContext', 'saropaLints.driftAdvisor.connected', false);
        void vscode.window.setStatusBarMessage('Saropa Drift Advisor: error fetching issues', 5000);
      } finally {
        driftAdvisorRefreshInProgress = false;
        refreshAllSections();
      }
    }),
    vscode.commands.registerCommand('saropaLints.driftAdvisor.openInBrowser', () => {
      const server = driftAdvisorProvider.getServer();
      if (server?.baseUrl) {
        void vscode.env.openExternal(vscode.Uri.parse(server.baseUrl));
      } else {
        void vscode.window.showInformationMessage('Drift Advisor is not connected. Click Refresh after starting the server.');
      }
    }),
    vscode.commands.registerCommand('saropaLints.driftAdvisor.enableIntegration', async () => {
      await vscode.workspace.getConfiguration('saropaLints.driftAdvisor').update('integration', true, vscode.ConfigurationTarget.Global);
      // Update context immediately so the toolbar icon flips without waiting for the config-change event.
      void vscode.commands.executeCommand('setContext', 'saropaLints.driftAdvisor.integration', true);
    }),
    vscode.commands.registerCommand('saropaLints.driftAdvisor.disableIntegration', async () => {
      await vscode.workspace.getConfiguration('saropaLints.driftAdvisor').update('integration', false, vscode.ConfigurationTarget.Global);
      // Update context immediately so the toolbar icon flips without waiting for the config-change event.
      void vscode.commands.executeCommand('setContext', 'saropaLints.driftAdvisor.integration', false);
    }),
    vscode.commands.registerCommand('saropaLints.repairConfig', async () => {
      const success = await runRepairConfig(context);
      if (success) refreshAll();
    }),
    vscode.commands.registerCommand('saropaLints.setTier', async () => {
      // Capture pre-tier violation count for delta display in the notification.
      const root = getProjectRoot();
      const preTierTotal = root ? (readViolations(root)?.summary?.totalViolations ?? 0) : 0;

      const result = await runSetTier(context);
      if (result) {
        // C6: setup.ts already runs analysis inside runSetTier when
        // runAnalysisAfterConfigChange is on; no duplicate call here.
        refreshAll();
        updateAllStatusBars();
        updateContext(getConfig().get<boolean>('enabled', true) ?? true, issuesProvider.hasViolations());

        // Smart tier transition: build notification info from post-tier data.
        // Note: postData may reflect a prior analysis if dart analyze has not yet
        // written violations.json — counts will update on the next file-watcher refresh.
        const postData = root ? readViolations(root) : null;
        const postTotal = postData?.summary?.totalViolations ?? postData?.violations.length ?? 0;
        const isUpgrade = TIER_ORDER.indexOf(result.tier) > TIER_ORDER.indexOf(result.previousTier);

        // Single pass to count critical+high violations (avoids 3 filter passes over 65k items).
        let critHigh = 0;
        for (const v of postData?.violations ?? []) {
          if (v.impact === 'critical' || v.impact === 'high') critHigh++;
        }

        // Auto-filter on upgrade when there are many violations and some are critical/high.
        // This shows the user a manageable set of high-priority issues instead of thousands.
        if (isUpgrade && postTotal > 50 && critHigh > 0) {
          issuesProvider.setImpactFilter(new Set(['critical', 'high']));
          issuesProvider.setSeverityFilter(new Set(['error', 'warning', 'info']));
          updateIssuesViewMessage();
        }

        await showTierChangeNotification({
          tierLabel: result.tierLabel,
          isUpgrade,
          postTotal,
          criticalPlusHigh: critHigh,
          delta: postTotal - preTierTotal,
        });
      }
    }),
    // D1/I1: Focus Violations view filtered to a set of rule names.
    // Shared helper — hides all rules EXCEPT the given set and resets orthogonal filters.
    ...['saropaLints.focusIssuesForOwasp', 'saropaLints.focusIssuesForRules'].map((cmdId) =>
      vscode.commands.registerCommand(cmdId, (arg: unknown) => {
        // Resolve rules: direct string[] (TreeItem click) or node (context menu).
        let rules: string[] | undefined;
        if (Array.isArray(arg)) {
          rules = arg;
        } else if (arg && typeof arg === 'object' && 'kind' in arg) {
          const node = arg as { kind: string; rules?: string[]; ruleName?: string };
          if (node.kind === 'triageGroup' && Array.isArray(node.rules)) {
            rules = node.rules;
          } else if (node.kind === 'triageRule' && typeof node.ruleName === 'string') {
            rules = [node.ruleName];
          }
        }
        if (!rules || rules.length === 0) return;
        const allRules = issuesProvider.getRuleNamesFromData();
        const keep = new Set(rules);
        const toHide = new Set(allRules.filter((r) => !keep.has(r)));
        issuesProvider.setTextFilter('');
        issuesProvider.setSeverityFilter(new Set(['error', 'warning', 'info']));
        issuesProvider.setImpactFilter(new Set(['critical', 'high', 'medium', 'low', 'opinionated']));
        issuesProvider.setRulesToHide(toHide);
        updateIssuesViewMessage();
        issuesProvider.expandAll();
        void vscode.commands.executeCommand('saropaLints.revealFindingsDashboard');
      }),
    ),
    // Summary metadata drill-down: filter Issues view by rules whose metadata
    // field matches the selected value (e.g. ruleType=vulnerability).
    vscode.commands.registerCommand(
      'saropaLints.focusIssuesByRuleMetadata',
      (field: 'ruleType' | 'ruleStatus', expectedValue: string) => {
        if (!field || !expectedValue) return;
        const root = getProjectRoot();
        if (!root) return;
        const data = readViolations(root);
        if (!data) return;

        const matchingRules = new Set<string>();
        const byRule = data.config?.ruleMetadataByRule ?? {};
        for (const [ruleName, metadata] of Object.entries(byRule)) {
          if (!metadata || typeof metadata !== 'object') continue;
          const candidate =
            field === 'ruleType' ? metadata.ruleType : metadata.ruleStatus;
          if (candidate === expectedValue) matchingRules.add(ruleName);
        }
        // Backfill from per-violation metadata for backward compatibility.
        for (const violation of data.violations) {
          const candidate =
            field === 'ruleType'
              ? violation.metadata?.ruleType
              : violation.metadata?.ruleStatus;
          if (candidate === expectedValue) matchingRules.add(violation.rule);
        }

        if (matchingRules.size === 0) return;
        const allRules = issuesProvider.getRuleNamesFromData();
        const toHide = new Set(allRules.filter((r) => !matchingRules.has(r)));
        issuesProvider.setTextFilter('');
        issuesProvider.setSeverityFilter(new Set(['error', 'warning', 'info']));
        issuesProvider.setImpactFilter(
          new Set(['critical', 'high', 'medium', 'low', 'opinionated']),
        );
        issuesProvider.setRulesToHide(toHide);
        updateIssuesViewMessage();
        issuesProvider.expandAll();
        void vscode.commands.executeCommand('saropaLints.revealFindingsDashboard');
      },
    ),
    vscode.commands.registerCommand('saropaLints.explainRule', (arg: unknown) => {
      if (typeof arg === 'string' && arg.trim().length > 0) {
        openRuleExplainPanel({ ruleName: arg.trim() });
        return;
      }
      // Accept the documented `{ ruleId }` object form a sibling envelope's
      // `fix.command` passes (plan §3); the suite contract keys on `ruleId`.
      if (arg && typeof arg === 'object' && 'ruleId' in arg) {
        const ruleId = (arg as { ruleId: unknown }).ruleId;
        if (typeof ruleId === 'string' && ruleId.trim().length > 0) {
          openRuleExplainPanel({ ruleName: ruleId.trim() });
          return;
        }
      }
      const node = arg as IssueTreeNode | undefined;
      if (node?.kind === 'violation' && 'violation' in node) {
        openRuleExplainPanelForViolation(node.violation);
        return;
      }
      const root = getProjectRoot();
      if (!root) {
        void vscode.window.showInformationMessage('Open a workspace folder first.');
        return;
      }
      const data = readViolations(root);
      const violations = data?.violations ?? [];
      if (violations.length === 0) {
        void vscode.window.showInformationMessage('No violations in current data. Run analysis first.');
        return;
      }
      const ruleNames = [...new Set(violations.map((v) => v.rule))].sort((a, b) => a.localeCompare(b));
      void vscode.window.showQuickPick(ruleNames, {
        title: 'Explain rule',
        placeHolder: 'Select a rule to view details',
        matchOnDescription: true,
      }).then((selected) => {
        if (!selected) return;
        const first = violations.find((v) => v.rule === selected);
        if (first) openRuleExplainPanelForViolation(first);
        else openRuleExplainPanel({ ruleName: selected });
      });
    }),
    vscode.commands.registerCommand(
      'saropaLints.explainRuleFromSuggestion',
      (ruleName: unknown, sourceRule: unknown) => {
        if (typeof ruleName !== 'string' || ruleName.trim().length === 0) return;
        const normalizedRule = ruleName.trim();
        const source = typeof sourceRule === 'string' ? sourceRule.trim() : '';
        relatedRuleTelemetry.track('suggestions.relatedRuleOpen', {
          ruleName: normalizedRule,
          sourceRule: source,
        });
        openRuleExplainPanel({ ruleName: normalizedRule });
      },
    ),
    vscode.commands.registerCommand('saropaLints.showOutput', showOutputChannel),
    vscode.commands.registerCommand('saropaLints.showRelatedRuleTelemetry', () => {
      showRelatedRuleTelemetryPanel(relatedRuleTelemetry);
    }),
    vscode.commands.registerCommand('saropaLints.resetRelatedRuleTelemetry', () => {
      relatedRuleTelemetry.reset();
      void vscode.window.showInformationMessage(
        'Saropa Lints: related rule telemetry counters reset.',
      );
    }),
    // "Copy Latest Report" — grabs the newest `*_saropa_lint_report.log`
    // (the Dart plugin's consolidated analysis report with top rules,
    // concentration, and triage sections) and puts its full contents on
    // the clipboard. Lets users paste directly into a chat / issue /
    // email without navigating date folders. Chosen over exporting a
    // curated subset: the whole report is small enough (< 1 MB on the
    // real contacts project even with 14k issues), and users who pipe
    // into an LLM always want the full header + every section.
    vscode.commands.registerCommand('saropaLints.copyLatestReport', async () => {
      const root = getProjectRoot();
      if (!root) {
        vscode.window.showErrorMessage('No workspace folder open.');
        return;
      }
      const reportPath = findLatestAnalysisReport(root);
      if (!reportPath) {
        vscode.window.showWarningMessage(
          'Saropa Lints: no analysis report found under reports/. Run "Saropa Lints: Run Analysis" first.',
        );
        return;
      }
      try {
        const content = fs.readFileSync(reportPath, 'utf-8');
        await vscode.env.clipboard.writeText(content);
        // Show the resolved filename so users who have multiple runs in
        // flight can confirm which one landed on their clipboard.
        const name = path.basename(reportPath);
        void vscode.window.showInformationMessage(`Copied ${name} to clipboard.`);
      } catch (err) {
        const message = err instanceof Error ? err.message : String(err);
        void vscode.window.showErrorMessage(
          `Saropa Lints: failed to read report — ${message}`,
        );
      }
    }),
    // "Open Latest Report" — opens the newest `*_saropa_lint_report.log`
    // in an editor tab. Preview mode is off (preserveFocus: false, preview:
    // false) because users who explicitly asked to open the report want
    // a persistent tab, not a fleeting peek that gets replaced by the
    // next file they click.
    vscode.commands.registerCommand('saropaLints.openLatestReport', async () => {
      const root = getProjectRoot();
      if (!root) {
        vscode.window.showErrorMessage('No workspace folder open.');
        return;
      }
      const reportPath = findLatestAnalysisReport(root);
      if (!reportPath) {
        vscode.window.showWarningMessage(
          'Saropa Lints: no analysis report found under reports/. Run "Saropa Lints: Run Analysis" first.',
        );
        return;
      }
      try {
        const uri = vscode.Uri.file(reportPath);
        const doc = await vscode.workspace.openTextDocument(uri);
        await vscode.window.showTextDocument(doc, { preview: false });
      } catch (err) {
        const message = err instanceof Error ? err.message : String(err);
        void vscode.window.showErrorMessage(
          `Saropa Lints: failed to open report — ${message}`,
        );
      }
    }),
    // D2: Export OWASP Compliance Report as markdown.
    vscode.commands.registerCommand('saropaLints.exportOwaspReport', async () => {
      const root = getProjectRoot();
      if (!root) {
        vscode.window.showErrorMessage('No workspace folder open.');
        return;
      }
      const data = readViolations(root);
      if (!data) {
        vscode.window.showErrorMessage('No analysis data. Run analysis first.');
        return;
      }
      const report = generateOwaspReport(data, root);
      const folder = path.join(root, 'reports', '.saropa_lints');
      try { fs.mkdirSync(folder, { recursive: true }); } catch { /* exists */ }
      const filePath = path.join(folder, 'owasp_compliance_report.md');
      fs.writeFileSync(filePath, report, 'utf-8');
      const doc = await vscode.workspace.openTextDocument(vscode.Uri.file(filePath));
      await vscode.window.showTextDocument(doc);
      // Report: log export action.
      logSection('OWASP Export');
      logReport(`- Exported to ${filePath}`);
      flushReport(root);
    }),
    ...registerIssuesViewCommands({
      issuesProvider,
      updateIssuesViewMessage,
      getProjectRoot,
      // Live source enriched with the bundled rule catalog: the metadata filters
      // and hotspot review read per-rule type/status from the catalog now, so
      // they stay in sync with the Problems panel instead of a stale export.
      readViolations: readLiveViolations,
      hotspotReviewState,
    }),
    // I2: Triage actions — disable/enable rules via analysis_options_custom.yaml overrides.
    // Shared helper extracts rule names from string[] (TreeItem click) or node (context menu).
    ...['saropaLints.disableRules', 'saropaLints.enableRules'].map((cmdId) =>
      vscode.commands.registerCommand(cmdId, async (arg: unknown) => {
        const isDisable = cmdId === 'saropaLints.disableRules';
        const rules = resolveRulesFromArg(arg);
        if (!rules || rules.length === 0) return;
        const root = getProjectRoot();
        if (!root) return;
        // Confirm for large groups (>5 rules).
        if (rules.length > 5) {
          const verb = isDisable ? 'Disable' : 'Enable';
          const ok = await vscode.window.showWarningMessage(
            `${verb} ${rules.length} rules? This updates analysis_options_custom.yaml.`,
            { modal: true },
            verb,
          );
          if (ok !== verb) return;
        }
        // I2: Write overrides then re-init + re-analyze.
        if (isDisable) {
          writeRuleOverrides(root, rules.map((r) => ({ rule: r, enabled: false })));
        } else {
          // Enable: remove false overrides so tier default applies.
          removeRuleOverrides(root, rules);
        }
        const initOk = await runInitializeConfig(context, `${isDisable ? 'Disabling' : 'Enabling'} ${rules.length} rule${rules.length === 1 ? '' : 's'}`);
        if (!initOk) return;
        const runAfter = getConfig().get<boolean>('runAnalysisAfterConfigChange', true) ?? true;
        if (runAfter) await runAnalysisCommand(context);
        refreshAll();
        updateAllStatusBars();
        updateContext(getConfig().get<boolean>('enabled', true) ?? true, issuesProvider.hasViolations());
        await vscode.commands.executeCommand('saropaLints.editorDashboards.focus');
      }),
    ),
    /* Re-enable disabled rules — multi-select quick-pick over the rules
       currently disabled in analysis_options_custom.yaml. Surfaced from
       the Findings dashboard More menu because users who disabled a rule
       from that dashboard previously had no in-dashboard path back to
       enable it.
       Why filter to readRuleOverrides() instead of readDisabledRules():
       saropaLints.enableRules delegates to removeRuleOverrides, which
       only edits analysis_options_custom.yaml. Rules disabled at the
       analysis_options.yaml diagnostics level (also returned by
       readDisabledRules) cannot be re-enabled by that path — listing
       them here would be a quiet no-op for the user. */
    vscode.commands.registerCommand('saropaLints.reEnableDisabledRules', async () => {
      const root = getProjectRoot();
      if (!root) return;
      const overrides = readRuleOverrides(root);
      const disabled: string[] = [];
      for (const [rule, enabled] of overrides) {
        if (!enabled) disabled.push(rule);
      }
      disabled.sort();
      if (disabled.length === 0) {
        await vscode.window.showInformationMessage(
          l10n('findingsDash.menuPalette.reEnableNoneMessage'),
        );
        return;
      }
      const picks = await vscode.window.showQuickPick(
        disabled.map((r) => ({ label: r, picked: false })),
        {
          canPickMany: true,
          title: l10n('findingsDash.menuPalette.reEnableQuickPickTitle'),
          placeHolder: l10n('findingsDash.menuPalette.reEnableQuickPickPlaceholder'),
          matchOnDescription: true,
        },
      );
      if (!picks || picks.length === 0) return;
      const ruleNames = picks.map((p) => p.label);
      await vscode.commands.executeCommand('saropaLints.enableRules', ruleNames);
    }),
  );

  // ── Copy as JSON commands ───────────────────────────────────────────────
  // Each view gets its own command so context menus target the right view.
  registerCopyAsJsonCommands(context, {
    issuesProvider,
    summaryProvider,
    securityProvider,
    fileRiskProvider,
  });

  // Package Vibrancy subsystem — registers its own views, commands, and providers
  // under the shared saropaLints sidebar container.
  // Wrapped in try/catch so a vibrancy failure doesn't kill the entire extension.
  try {
    runVibrancyActivation(context, (data) => {
      vibrancyData = data;
      updateAllStatusBars();
      refreshAllSections();
    }, pubspecValidator);
  } catch (err) {
    console.error('[Saropa Lints] Package Vibrancy activation failed:', err);
    // Fallback: if vibrancy fails, register standalone pubspec listeners
    // so pubspec validation still works without vibrancy/SDK diagnostics.
    registerFallbackPubspecListeners(context, pubspecValidator);
  }

  // Background upgrade check — runs asynchronously, fails silently.
  // Only checks when saropa_lints is already in the project and extension is enabled.
  if (isDartProject && enabled && root) {
    void checkForUpgrade(context, root).catch((err) => {
      console.error('[Saropa Lints] Upgrade check failed:', err);
    });
  }

  // Prompt setup when this is a Dart project but saropa_lints is not in
  // pubspec.yaml. The notification is the most discoverable entry point for
  // new users who don't yet know to look in the sidebar.
  if (isDartProject && root && !hasSaropaLintsDep(root)) {
    void vscode.window.showInformationMessage(
      'Saropa Lints detected a Dart project without saropa_lints configured. Set up now for 2100+ lint rules.',
      'Set Up Project',
      'Not Now',
    ).then((choice) => {
      if (choice === 'Set Up Project') {
        void vscode.commands.executeCommand('saropaLints.enable');
      }
    });
  }

  // Public API for other extensions (e.g. Saropa Log Capture). See api.ts and extension README.
  const api: SaropaLintsApi = {
    getViolationsData(): ViolationsData | null {
      const r = getProjectRoot();
      return r ? readViolations(r) : null;
    },
    getViolationsPath(): string | null {
      const r = getProjectRoot();
      return r ? getViolationsFilePath(r) : null;
    },
    getHealthScoreParams() {
      return {
        impactWeights: { ...IMPACT_WEIGHTS },
        decayRate: DECAY_RATE,
      };
    },
    runAnalysis(): Promise<boolean> {
      return runAnalysisCommand(context);
    },
    runAnalysisForFiles(files: string[]): Promise<boolean> {
      return runAnalysisForFilesCommand(context, files, { showProgress: false });
    },
    getVersion(): string {
      return extVersion || '0.0.0';
    },
  };
  return api;
}

/** Extract rule names from command arg: string[] (TreeItem click) or triage node (context menu). */
function resolveRulesFromArg(arg: unknown): string[] | undefined {
  if (Array.isArray(arg)) return arg;
  if (arg && typeof arg === 'object' && 'kind' in arg) {
    const node = arg as { kind: string; rules?: string[]; ruleName?: string; violation?: { rule?: string } };
    if (node.kind === 'triageGroup' && Array.isArray(node.rules)) return node.rules;
    if (node.kind === 'triageRule' && typeof node.ruleName === 'string') return [node.ruleName];
    // Support invoking disableRules from a violation node in the issues tree.
    if (node.kind === 'violation' && typeof node.violation?.rule === 'string') return [node.violation.rule];
  }
  return undefined;
}

/** Pre-computed counts passed from the tier-change handler to the notification. */
interface TierChangeNotification {
  tierLabel: string;
  isUpgrade: boolean;
  postTotal: number;
  criticalPlusHigh: number;
  delta: number;
}

/**
 * Show a smart notification after a tier change.
 *
 * On upgrade with many violations, tells the user the Violations view has been
 * auto-filtered to critical+high so they aren't overwhelmed by thousands of
 * new violations at once. Provides a "Show All" escape hatch.
 *
 * On downgrade or small upgrade (≤50 total), shows a simple delta message
 * without auto-filtering.
 */
async function showTierChangeNotification(info: TierChangeNotification): Promise<void> {
  const deltaText = info.delta > 0 ? `+${info.delta.toLocaleString()}` : info.delta.toLocaleString();

  if (info.isUpgrade && info.postTotal > 50 && info.criticalPlusHigh > 0) {
    // Auto-filter was applied by the handler — notify user and offer escape hatch.
    const msg = `${info.tierLabel} tier: ${info.postTotal.toLocaleString()} violations (${deltaText}). `
      + `Showing ${info.criticalPlusHigh} critical + high — fix these first.`;
    const choice = await vscode.window.showInformationMessage(msg, 'View Violations', 'Show All');
    if (choice === 'View Violations') {
      // Use revealFindingsDashboard (not focusIssues) to preserve the auto-filter that was
      // applied by the handler — focusIssues calls clearFilters() first.
      await vscode.commands.executeCommand('saropaLints.revealFindingsDashboard');
    } else if (choice === 'Show All') {
      // User wants to see everything — clear the auto-filter via the existing command.
      await vscode.commands.executeCommand('saropaLints.clearIssuesFilters');
      await vscode.commands.executeCommand('saropaLints.revealFindingsDashboard');
    }
  } else {
    // Downgrade, small upgrade, or zero critical+high — simple confirmation.
    const msg = info.delta === 0
      ? `Tier changed to ${info.tierLabel}.`
      : `Tier changed to ${info.tierLabel} (${deltaText} violations).`;
    const choice = await vscode.window.showInformationMessage(msg, 'View Violations');
    if (choice === 'View Violations') {
      await vscode.commands.executeCommand('saropaLints.revealFindingsDashboard');
    }
  }
}

/**
 * I5: Show a score-aware notification after enable with action buttons.
 * Three cases:
 *   1. Score available → "Your project scores 72/100. Room to improve."
 *   2. Violations but no score → "Saropa Lints found N violations."
 *   3. No data (analysis didn't run) → "Saropa Lints is enabled."
 */
async function showFirstRunNotification(
  health: { score: number } | null,
  totalViolations: number,
): Promise<void> {
  let message: string;
  let primaryAction: string;

  if (health) {
    const band = scoreColorBand(health.score);
    // User-facing qualifier for the score band (avoids nested ternary for lint compliance).
    let qualifier: string;
    if (band === 'green') {
      qualifier = 'Great start!';
    } else if (band === 'yellow') {
      qualifier = 'Room to improve.';
    } else {
      qualifier = 'Needs attention.';
    }
    message = `Saropa Lints: Your project scores ${health.score}/100. ${qualifier}`;
    primaryAction = 'View Violations';
  } else if (totalViolations > 0) {
    message = `Saropa Lints found ${totalViolations} violation${totalViolations === 1 ? '' : 's'}.`;
    primaryAction = 'View Violations';
  } else {
    message = 'Saropa Lints is enabled. Run analysis to see your health score.';
    primaryAction = 'Run Analysis';
  }

  const choice = await vscode.window.showInformationMessage(
    message,
    primaryAction,
    'Configure Rules',
  );

  if (choice === 'View Violations') {
    await vscode.commands.executeCommand('saropaLints.focusIssues');
  } else if (choice === 'Run Analysis') {
    await vscode.commands.executeCommand('saropaLints.runAnalysis');
  } else if (choice === 'Configure Rules') {
    await vscode.commands.executeCommand('saropaLints.openConfigDashboard');
  }
}

export function deactivate(): void {
  // Wrapped in try/catch so a vibrancy teardown error doesn't prevent clean shutdown.
  try {
    stopFreshnessWatcher();
  } catch (err) {
    console.error('[Saropa Lints] Package Vibrancy deactivation failed:', err);
  }
}
