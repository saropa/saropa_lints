/**
 * Editor-area **Findings Dashboard**: grouped findings (same modes as the Issues
 * sidebar), severity/impact filters, text search, JSON export, navigation, export-summary
 * suppressions (by kind / rule / file), and workspace “view hides” with clear — not a single
 * flat table. Uses `reports/.saropa_lints/violations.json` with disabled-rule filtering and
 * suppressions aligned to the Violations tree.
 */

import * as vscode from 'vscode';
import * as nodePath from 'node:path';
import { getProjectRoot } from '../projectRoot';
import {
  filterDisabledFromData,
  type Violation,
  type ViolationsData,
} from '../violationsReader';
import { buildViolationsDataFromDiagnostics } from '../liveDiagnosticsModel';
import { sortedNumericCountEntries } from '../keyedCountBreakdown';
import type { Suppressions } from '../suppressionsStore';
import { readDisabledRules } from '../configWriter';
import { loadSuppressions } from '../suppressionsStore';
import { scanWorkspace } from '../services/todosAndHacksScanner';
import {
  DEFAULT_TODOS_AND_HACKS_EXCLUDE_GLOBS,
  DEFAULT_TODOS_AND_HACKS_INCLUDE_GLOBS,
  DEFAULT_TODOS_AND_HACKS_TAGS,
} from './todosAndHacksDefaults';
import { discoverServer } from '../driftAdvisor/discovery';
import { fetchIssues } from '../driftAdvisor/client';
import { mapIssuesToLocations } from '../driftAdvisor/mapper';
import {
  sortViolationsByReportPriority,
  buildFilteredIndex,
  buildDashboardSections,
  parseViolationsGroupBy,
  collectAllViolationsFromIndex,
  violationDedupeKey,
  getPageSize,
  type GroupByMode,
  VIOLATIONS_GROUP_BY_MODES,
} from './issuesTreeModel';
import {
  renderViolationsDashboardHtml,
  type AnalyzerSuppressionsSlice,
  type ViewSuppressionsSlice,
} from './violationsDashboardHtml';
import { l10n } from '../i18n/runtime';

const PANEL_VIEW_TYPE = 'saropaViolationsWideReport';
const MAX_SOURCE_VIOLATIONS = 4000;

let currentPanel: vscode.WebviewPanel | undefined;
let todosAndHacksSnapshot: TodoHackSnapshot | undefined;
// Live-diagnostics refresh: rebuilds the dashboard from getDiagnostics() on
// every (debounced) diagnostic change, so it stays in sync with the Problems
// panel. Disposed when the panel closes. Debounced so a flurry of analyzer
// updates (VS Code re-emits many per-file diagnostic changes after a run)
// coalesces into a single rebuild.
let liveDiagnosticsListener: vscode.Disposable | undefined;
let liveRefreshTimer: NodeJS.Timeout | undefined;
const LIVE_REFRESH_DEBOUNCE_MS = 500;

interface DashboardState {
  groupBy: GroupByMode;
  textFilter: string;
  severitiesToShow: Set<string>;
  impactsToShow: Set<string>;
}

interface TodoHackItem {
  file: string;
  line: number;
  snippet: string;
}

interface TodoHackSnapshot {
  enabled: boolean;
  capped: boolean;
  todos: TodoHackItem[];
  hacks: TodoHackItem[];
}

interface DriftAdvisorSnapshot {
  integrationEnabled: boolean;
  connected: boolean;
  serverLabel?: string;
  issues: Array<{ source: string; severity: string; message: string; file?: string; line?: number }>;
}

let dashboardState: DashboardState | undefined;
let lastExportViolations: Violation[] = [];
let driftAdvisorSnapshot: DriftAdvisorSnapshot | undefined;

const VIEW_SUP_SAMPLE = 14;

function buildAnalyzerSuppressionsSlice(data: ViolationsData): AnalyzerSuppressionsSlice {
  const sup = data.summary?.suppressions;
  const total = sup?.total ?? 0;
  if (!sup || total <= 0) {
    return { total: 0, byKind: [], byRule: [], byFile: [] };
  }
  return {
    total,
    byKind: sortedNumericCountEntries(sup.byKind),
    byRule: sortedNumericCountEntries(sup.byRule),
    byFile: sortedNumericCountEntries(sup.byFile),
  };
}

function buildViewSuppressionsSlice(s: Suppressions): ViewSuppressionsSlice {
  const ruleInFileEntryCount = Object.keys(s.hiddenRuleInFile).length;
  const active =
    s.hiddenFolders.length > 0 ||
    s.hiddenFiles.length > 0 ||
    s.hiddenRules.length > 0 ||
    ruleInFileEntryCount > 0 ||
    s.hiddenSeverities.length > 0 ||
    s.hiddenImpacts.length > 0;
  const sampleRuleInFileLines = Object.entries(s.hiddenRuleInFile)
    .slice(0, VIEW_SUP_SAMPLE)
    .map(([path, rules]) => `${path}: ${(rules ?? []).join(', ')}`);
  return {
    active,
    folderCount: s.hiddenFolders.length,
    fileCount: s.hiddenFiles.length,
    ruleCount: s.hiddenRules.length,
    ruleInFileEntryCount,
    severityCount: s.hiddenSeverities.length,
    impactCount: s.hiddenImpacts.length,
    sampleFolders: s.hiddenFolders.slice(0, VIEW_SUP_SAMPLE),
    sampleFiles: s.hiddenFiles.slice(0, VIEW_SUP_SAMPLE),
    sampleRules: s.hiddenRules.slice(0, VIEW_SUP_SAMPLE),
    sampleRuleInFileLines,
  };
}

function defaultDashboardState(cfg: vscode.WorkspaceConfiguration): DashboardState {
  return {
    groupBy: parseViolationsGroupBy(cfg),
    textFilter: '',
    severitiesToShow: new Set(['error', 'warning', 'info']),
    // Three-bucket severity model (was: critical/high/medium/low/opinionated;
    // collapsed 2026-05-03 — see plan/COLLAPSE_LINT_IMPACT_TO_SEVERITY.md).
    impactsToShow: new Set(['error', 'warning', 'info']),
  };
}

function getDashboardState(cfg: vscode.WorkspaceConfiguration): DashboardState {
  if (!dashboardState) {
    dashboardState = defaultDashboardState(cfg);
  }
  return dashboardState;
}

function mergeDashboardUpdate(
  cfg: vscode.WorkspaceConfiguration,
  msg: {
    groupBy?: string;
    textFilter?: string;
    severities?: string[];
    impacts?: string[];
  },
): void {
  const st = getDashboardState(cfg);
  if (typeof msg.groupBy === 'string' && (VIOLATIONS_GROUP_BY_MODES as readonly string[]).includes(msg.groupBy)) {
    st.groupBy = msg.groupBy as GroupByMode;
    void cfg.update('violationsGroupBy', msg.groupBy, vscode.ConfigurationTarget.Workspace);
  }
  if (typeof msg.textFilter === 'string') {
    st.textFilter = msg.textFilter;
  }
  if (Array.isArray(msg.severities) && msg.severities.length > 0) {
    st.severitiesToShow = new Set(msg.severities.map((s) => String(s).toLowerCase()));
  }
  if (Array.isArray(msg.impacts) && msg.impacts.length > 0) {
    st.impactsToShow = new Set(msg.impacts.map((s) => String(s).toLowerCase()));
  }
}

/** Opens or focuses the violations dashboard, rebuilding HTML from disk and state. */
export async function openViolationsWideReport(context: vscode.ExtensionContext): Promise<void> {
  const root = getProjectRoot();
  if (!root) {
    void vscode.window.showErrorMessage(l10n('wideReport.openWorkspaceFirst'));
    return;
  }

  const panel = getOrCreatePanel(context);
  await rebuildDashboardHtml(context, panel);
  panel.reveal(vscode.ViewColumn.One);
}

async function rebuildDashboardHtml(
  context: vscode.ExtensionContext,
  panel: vscode.WebviewPanel,
): Promise<void> {
  const root = getProjectRoot();
  if (!root) {
    return;
  }

  const cfg = vscode.workspace.getConfiguration('saropaLints');

  // Source findings from LIVE diagnostics — the same array the Problems panel
  // shows — not the batch violations.json export. This keeps the dashboard
  // structurally in sync with Problems (no stale "0 findings / grade A" while
  // Problems shows dozens) and triggers zero analysis (the analyzer already
  // produced these for the Problems panel; we only read the result). An empty
  // result is a genuine clean state that renders the zeroed dashboard, not a
  // "no report yet" wall — so there is no early-return empty-state branch here
  // any more. Phase #1a: findings only, no per-rule enrichment (see
  // liveDiagnosticsModel).
  const raw = buildViolationsDataFromDiagnostics(root, undefined, cfg.get<string>('tier'));

  const state = getDashboardState(cfg);
  const disabled = readDisabledRules(root);
  const afterDisabled = filterDisabledFromData(raw, disabled);
  const totalAfterDisable = afterDisabled.violations.length;

  const suppressions = loadSuppressions(context.workspaceState);
  const sorted = [...afterDisabled.violations].sort(sortViolationsByReportPriority);
  const truncatedSource = sorted.length > MAX_SOURCE_VIOLATIONS;
  const sourceSlice = truncatedSource ? sorted.slice(0, MAX_SOURCE_VIOLATIONS) : sorted;

  const index = buildFilteredIndex(
    sourceSlice,
    state.textFilter,
    state.severitiesToShow,
    state.impactsToShow,
    new Set<string>(),
    suppressions,
    undefined,
  );

  const sections = buildDashboardSections(index, state.groupBy);
  const flat = collectAllViolationsFromIndex(index);
  const dedup = new Map<string, Violation>();
  for (const v of flat) {
    dedup.set(violationDedupeKey(v), v);
  }
  lastExportViolations = [...dedup.values()].sort(sortViolationsByReportPriority);

  let filteredCount = 0;
  for (const byFile of index.values()) {
    for (const list of byFile.values()) {
      filteredCount += list.length;
    }
  }

  if (!todosAndHacksSnapshot) {
    todosAndHacksSnapshot = await loadTodoHackSnapshot();
  }
  if (!driftAdvisorSnapshot) {
    driftAdvisorSnapshot = await loadDriftAdvisorSnapshot();
  }

  // Scanner promo state (file-system TODO/HACK scanner). Read fresh each
  // rebuild so toggling the scanner flips its pill on the next paint.
  const scanner = buildScannerSlice(cfg);

  panel.webview.html = renderViolationsDashboardHtml({
    exportViolations: lastExportViolations,
    totalRawAfterDisable: totalAfterDisable,
    filteredCount,
    truncatedSource,
    maxSourceViolations: MAX_SOURCE_VIOLATIONS,
    pageSize: getPageSize(),
    groupBy: state.groupBy,
    textFilter: state.textFilter,
    severities: [...state.severitiesToShow],
    impacts: [...state.impactsToShow],
    sections,
    analyzerSuppressions: buildAnalyzerSuppressionsSlice(afterDisabled),
    viewSuppressions: buildViewSuppressionsSlice(suppressions),
    todoHackSnapshot: todosAndHacksSnapshot,
    driftAdvisorSnapshot,
    severityCounts: countBySeverity(lastExportViolations),
    impactCounts: countByImpact(lastExportViolations),
    /* Status-line and KPI plumbing — sourced from violations.json so the
       dashboard can answer "is this fresh?" / "what is the dominant rule?"
       without reading the file again client-side. */
    reportTimestamp: raw.timestamp,
    extensionVersion: getExtensionVersion(context),
    topRule: pickTopRule(afterDisabled.violations),
    /* Top-N rules table is computed from `lastExportViolations` (post-filter,
       post-suppress) so the ranking matches what the user is seeing in the
       findings table below — already-hidden rules don't reappear here. */
    topRules: pickTopRules(lastExportViolations, TOP_RULES_LIMIT),
    filesAffected: countDistinctFiles(afterDisabled.violations),
    enabledRuleCount: raw.config?.enabledRuleCount,
    scanner,
  });

  void panel.webview.postMessage({
    type: 'hydrateRecentSearches',
    queries: context.workspaceState.get<string[]>('saropa.findingsDashboard.recentSearches', []),
  });
}

/**
 * Scanner-promo state for the status line: whether the file-system TODO/HACK
 * scanner is enabled, and whether the workspace has any Dart files worth
 * scanning. `hasDartFiles` reads already-computed VS Code diagnostics (a
 * `.dart` file in the Problems set means there is Dart to scan) — no analysis
 * is triggered, so it is safe on every rebuild.
 */
function buildScannerSlice(
  cfg: vscode.WorkspaceConfiguration,
): { enabled: boolean; hasDartFiles: boolean } {
  const hasDartFiles = vscode.languages
    .getDiagnostics()
    .some(([uri]) => uri.fsPath.endsWith('.dart'));
  return {
    enabled: cfg.get<boolean>('todosAndHacks.workspaceScanEnabled', false),
    hasDartFiles,
  };
}

function countBySeverity(violations: readonly Violation[]): Record<string, number> {
  return {
    error: violations.filter((v) => (v.severity ?? 'info').toLowerCase() === 'error').length,
    warning: violations.filter((v) => (v.severity ?? 'info').toLowerCase() === 'warning').length,
    info: violations.filter((v) => (v.severity ?? 'info').toLowerCase() === 'info').length,
  };
}

function countByImpact(violations: readonly Violation[]): Record<string, number> {
  // Three-bucket severity model (was: 5-bucket critical/high/medium/low/
  // opinionated taxonomy; collapsed 2026-05-03).
  return {
    error: violations.filter((v) => (v.impact ?? 'info').toLowerCase() === 'error').length,
    warning: violations.filter((v) => (v.impact ?? 'info').toLowerCase() === 'warning').length,
    info: violations.filter((v) => (v.impact ?? 'info').toLowerCase() === 'info').length,
  };
}

/** Highest-volume rule across the post-disable violations; absent if no rules. */
function pickTopRule(violations: readonly Violation[]): { name: string; count: number } | undefined {
  if (violations.length === 0) return undefined;
  const counts = new Map<string, number>();
  for (const v of violations) {
    counts.set(v.rule, (counts.get(v.rule) ?? 0) + 1);
  }
  let best: { name: string; count: number } | undefined;
  for (const [name, count] of counts) {
    if (!best || count > best.count) best = { name, count };
  }
  return best;
}

/**
 * Cap on rows in the noisy-rule triage table. Trimmed 20 → 10 so the table
 * stays scannable above the fold: each row now expands to its full message +
 * affected-file list, so 10 rich rows beat 20 terse ones.
 */
const TOP_RULES_LIMIT = 10;

/**
 * Per-rule cap on files listed inside an expanded Top-Rules row. Guards against
 * a pathological "one rule, hundreds of files" case ballooning the webview DOM.
 */
const TOP_RULE_FILES_LIMIT = 12;

interface TopRuleEntry {
  name: string;
  count: number;
  severity: string;
  /** Representative finding message (first occurrence), shown on expand. */
  message: string;
  /** Files carrying this rule, highest-count first, with a representative line. */
  files: Array<{ file: string; count: number; line: number }>;
}

interface RuleAccumulator {
  count: number;
  severity: string;
  message: string;
  /** file path → { occurrence count, lowest line seen } for that rule. */
  files: Map<string, { count: number; line: number }>;
}

/** Single pass: tally per-rule count, severity, first message, and per-file stats. */
function accumulateRuleStats(violations: readonly Violation[]): Map<string, RuleAccumulator> {
  const acc = new Map<string, RuleAccumulator>();
  for (const v of violations) {
    let entry = acc.get(v.rule);
    if (!entry) {
      // A rule has a single LintCode severity, so first-seen is deterministic.
      entry = {
        count: 0,
        severity: (v.severity ?? 'info').toLowerCase(),
        message: v.message ?? '',
        files: new Map(),
      };
      acc.set(v.rule, entry);
    }
    entry.count += 1;
    if (!entry.message && v.message) entry.message = v.message;
    const line = v.line ?? 1;
    const perFile = entry.files.get(v.file);
    if (perFile) {
      perFile.count += 1;
      if (line < perFile.line) perFile.line = line;
    } else {
      entry.files.set(v.file, { count: 1, line });
    }
  }
  return acc;
}

/**
 * Top-N rules by violation count. Sorted by count desc; ties broken by rule
 * name for stable rendering between rebuilds. Each entry carries the data the
 * dashboard's expandable Top-Rules row needs (message + affected files), so
 * the user can triage without scrolling to the findings table.
 */
function pickTopRules(violations: readonly Violation[], limit: number): TopRuleEntry[] {
  if (violations.length === 0) return [];
  const acc = accumulateRuleStats(violations);
  const entries = Array.from(acc, ([name, stats]) => ({ name, stats }));
  entries.sort((a, b) => b.stats.count - a.stats.count || a.name.localeCompare(b.name));
  return entries.slice(0, limit).map(({ name, stats }) => {
    const files = Array.from(stats.files, ([file, s]) => ({ file, count: s.count, line: s.line }))
      .sort((a, b) => b.count - a.count || a.file.localeCompare(b.file))
      .slice(0, TOP_RULE_FILES_LIMIT);
    return { name, count: stats.count, severity: stats.severity, message: stats.message, files };
  });
}

function countDistinctFiles(violations: readonly Violation[]): number {
  const set = new Set<string>();
  for (const v of violations) set.add(v.file);
  return set.size;
}

function getExtensionVersion(context: vscode.ExtensionContext): string | undefined {
  /* `packageJSON` is not in the typed surface but is provided by the
     extension host at runtime; cast through `unknown` rather than `any`
     to keep tsc strict-checked. */
  const pkg = (context.extension as unknown as { packageJSON?: { version?: string } })?.packageJSON;
  return typeof pkg?.version === 'string' ? pkg.version : undefined;
}

async function loadTodoHackSnapshot(): Promise<TodoHackSnapshot> {
  const cfg = vscode.workspace.getConfiguration('saropaLints.todosAndHacks');
  const workspaceScanEnabled = cfg.get<boolean>('workspaceScanEnabled', false) ?? false;
  if (!workspaceScanEnabled) {
    return { enabled: false, capped: false, todos: [], hacks: [] };
  }
  const folders = vscode.workspace.workspaceFolders ?? [];
  if (folders.length === 0) {
    return { enabled: true, capped: false, todos: [], hacks: [] };
  }
  const options = {
    tags: cfg.get<string[]>('tags', [...DEFAULT_TODOS_AND_HACKS_TAGS]),
    includeGlobs: cfg.get<string[]>('includeGlobs', [...DEFAULT_TODOS_AND_HACKS_INCLUDE_GLOBS]),
    excludeGlobs: cfg.get<string[]>('excludeGlobs', [...DEFAULT_TODOS_AND_HACKS_EXCLUDE_GLOBS]),
    maxFilesToScan: cfg.get<number>('maxFilesToScan', 2000),
    customRegex: cfg.get<string>('customRegex') || undefined,
  };
  const todos: TodoHackItem[] = [];
  const hacks: TodoHackItem[] = [];
  let capped = false;
  for (const folder of folders) {
    const result = await scanWorkspace(folder, options);
    capped = capped || result.capped;
    for (const marker of result.markers) {
      const tag = marker.tag.toUpperCase();
      if (tag !== 'TODO' && tag !== 'HACK') continue;
      const item: TodoHackItem = {
        file: marker.uri.fsPath,
        line: marker.lineIndex + 1,
        snippet: marker.snippet || marker.fullLine || tag,
      };
      if (tag === 'TODO') {
        todos.push(item);
      } else {
        hacks.push(item);
      }
    }
  }
  const sortByPathLine = (a: TodoHackItem, b: TodoHackItem): number =>
    a.file.localeCompare(b.file) || a.line - b.line;
  todos.sort(sortByPathLine);
  hacks.sort(sortByPathLine);
  return { enabled: true, capped, todos, hacks };
}

async function loadDriftAdvisorSnapshot(): Promise<DriftAdvisorSnapshot> {
  const cfg = vscode.workspace.getConfiguration('saropaLints.driftAdvisor');
  const integrationEnabled = cfg.get<boolean>('integration', false) ?? false;
  if (!integrationEnabled) {
    return { integrationEnabled: false, connected: false, issues: [] };
  }
  const [portMin, portMax] = cfg.get<[number, number]>('portRange', [8642, 8649]) ?? [8642, 8649];
  const server = await discoverServer(portMin, portMax);
  if (!server) {
    return { integrationEnabled: true, connected: false, issues: [] };
  }
  try {
    const raw = await fetchIssues(server);
    const mapped = await mapIssuesToLocations(raw);
    return {
      integrationEnabled: true,
      connected: true,
      serverLabel: `127.0.0.1:${server.port}${server.version ? ` (v${server.version})` : ''}`,
      issues: mapped.map((issue) => ({
        source: issue.source,
        severity: issue.severity,
        message: issue.message,
        file: issue.uri?.fsPath,
        line: issue.line != null ? issue.line + 1 : undefined,
      })),
    };
  } catch {
    return {
      integrationEnabled: true,
      connected: true,
      serverLabel: `127.0.0.1:${server.port}${server.version ? ` (v${server.version})` : ''}`,
      issues: [],
    };
  }
}

function getOrCreatePanel(context: vscode.ExtensionContext): vscode.WebviewPanel {
  if (currentPanel) {
    return currentPanel;
  }

  currentPanel = vscode.window.createWebviewPanel(
    PANEL_VIEW_TYPE,
    l10n('findingsDash.documentTitle'),
    vscode.ViewColumn.One,
    { enableScripts: true, retainContextWhenHidden: true },
  );

  currentPanel.onDidDispose(() => {
    currentPanel = undefined;
    // Stop listening for live diagnostic changes once the dashboard is gone —
    // no point rebuilding a panel that does not exist, and we leak the
    // listener if we do not dispose explicitly.
    liveDiagnosticsListener?.dispose();
    liveDiagnosticsListener = undefined;
    if (liveRefreshTimer) {
      clearTimeout(liveRefreshTimer);
      liveRefreshTimer = undefined;
    }
  });

  // Live refresh. The Problems panel updates as analysis runs; this listener
  // rebuilds the dashboard from the same diagnostics so the two stay in sync
  // without the user clicking refresh. Debounced because a single analysis run
  // typically emits dozens of per-URI diagnostic events.
  liveDiagnosticsListener = vscode.languages.onDidChangeDiagnostics(() => {
    if (!currentPanel?.visible) return;
    // Diagnostics are actively changing → analysis is streaming results in, so
    // the on-disk health score is mid-flight. Dim the gauge to "computing" now
    // (avoids the A→E whiplash); the debounced rebuild below ships a fresh
    // gauge with the settled grade once the dust settles.
    void currentPanel.webview.postMessage({ type: 'gaugePending', pending: true });
    if (liveRefreshTimer) clearTimeout(liveRefreshTimer);
    liveRefreshTimer = setTimeout(() => {
      liveRefreshTimer = undefined;
      if (currentPanel?.visible) {
        void rebuildDashboardHtml(context, currentPanel);
      }
    }, LIVE_REFRESH_DEBOUNCE_MS);
  });

  currentPanel.webview.onDidReceiveMessage(async (msg: unknown) => {
    const data = msg as {
      type?: string;
      file?: string;
      line?: number;
      groupBy?: string;
      textFilter?: string;
      severities?: string[];
      impacts?: string[];
    };
    const cfg = vscode.workspace.getConfiguration('saropaLints');

    if (data.type === 'dashboardUpdate') {
      mergeDashboardUpdate(cfg, data);
      if (currentPanel) {
        await rebuildDashboardHtml(context, currentPanel);
      }
      return;
    }
    if (data.type === 'refresh') {
      todosAndHacksSnapshot = undefined;
      driftAdvisorSnapshot = undefined;
      await rebuildDashboardHtml(context, currentPanel!);
      return;
    }
    if (data.type === 'runAnalysis') {
      currentPanel?.webview.postMessage({ type: 'analysisProgress', status: 'started' });
      try {
        await vscode.commands.executeCommand('saropaLints.runAnalysis');
        // Force a full dashboard rebuild after analysis so all panels (findings,
        // TODO/HACK snapshot, drift section) reflect the newest run immediately.
        todosAndHacksSnapshot = undefined;
        driftAdvisorSnapshot = undefined;
        if (currentPanel) {
          await rebuildDashboardHtml(context, currentPanel);
          currentPanel.webview.postMessage({ type: 'analysisProgress', status: 'completed' });
        }
      } catch {
        currentPanel?.webview.postMessage({ type: 'analysisProgress', status: 'failed' });
      }
      return;
    }
    if (data.type === 'copyFilteredJson') {
      try {
        await vscode.env.clipboard.writeText(JSON.stringify(lastExportViolations, null, 2));
        void vscode.window.setStatusBarMessage(
          l10n('wideReport.copiedViolationsJson', { count: String(lastExportViolations.length) }),
          4000,
        );
      } catch {
        void vscode.window.showErrorMessage(l10n('wideReport.clipboardCopyFailed'));
      }
      return;
    }
    if (data.type === 'saveFilteredJson') {
      await saveReportJson(lastExportViolations);
      return;
    }
    if (data.type === 'copySingleFinding') {
      const d = data as { file?: string; line?: number; rule?: string };
      const match = lastExportViolations.find((v) =>
        v.file === d.file && v.line === d.line && v.rule === d.rule,
      );
      if (match) {
        try {
          await vscode.env.clipboard.writeText(JSON.stringify(match, null, 2));
          void vscode.window.setStatusBarMessage(l10n('wideReport.copiedOneViolationJson'), 3000);
        } catch {
          void vscode.window.showErrorMessage(l10n('wideReport.clipboardCopyFailed'));
        }
      }
      return;
    }
    if (data.type === 'resetFilters') {
      /* Wipe in-memory filter state back to defaults; persist groupBy
         choice so the user's preferred grouping survives a reset. */
      const cur = getDashboardState(cfg);
      cur.textFilter = '';
      cur.severitiesToShow = new Set(['error', 'warning', 'info']);
      // Three-bucket severity model (post-collapse, 2026-05-03).
      cur.impactsToShow = new Set(['error', 'warning', 'info']);
      if (currentPanel) {
        await rebuildDashboardHtml(context, currentPanel);
      }
      return;
    }
    if (data.type === 'enableTodosScan') {
      const todoCfg = vscode.workspace.getConfiguration('saropaLints.todosAndHacks');
      await todoCfg.update('workspaceScanEnabled', true, vscode.ConfigurationTarget.Workspace);
      todosAndHacksSnapshot = undefined;
      await rebuildDashboardHtml(context, currentPanel!);
      return;
    }
    // Scanner pill click — the webview posts `{ type: 'toggleSupplementary',
    // source: 'scanner' }`. Flip the file-system TODO/HACK scanner setting and
    // invalidate its snapshot so the next rebuild re-scans (or stops). The
    // 'other'/'todos' analyzer toggles were removed when the dashboard became
    // holistic; those findings now appear directly in the main list.
    if (data.type === 'toggleSupplementary') {
      if ((data as { source?: string }).source === 'scanner') {
        const todoCfg = vscode.workspace.getConfiguration('saropaLints.todosAndHacks');
        const cur = todoCfg.get<boolean>('workspaceScanEnabled', false);
        await todoCfg.update(
          'workspaceScanEnabled',
          !cur,
          vscode.ConfigurationTarget.Workspace,
        );
        todosAndHacksSnapshot = undefined;
      }
      // Force the rebuild — onDidChangeConfiguration is racey vs user
      // expectations after a pill click; the pill should flip on the next paint.
      if (currentPanel) {
        await rebuildDashboardHtml(context, currentPanel);
      }
      return;
    }
    if (data.type === 'driftRefresh') {
      driftAdvisorSnapshot = undefined;
      await rebuildDashboardHtml(context, currentPanel!);
      return;
    }
    if (data.type === 'driftEnable') {
      await vscode.workspace
        .getConfiguration('saropaLints.driftAdvisor')
        .update('integration', true, vscode.ConfigurationTarget.Global);
      driftAdvisorSnapshot = undefined;
      await rebuildDashboardHtml(context, currentPanel!);
      return;
    }
    if (data.type === 'driftDisable') {
      await vscode.workspace
        .getConfiguration('saropaLints.driftAdvisor')
        .update('integration', false, vscode.ConfigurationTarget.Global);
      driftAdvisorSnapshot = undefined;
      await rebuildDashboardHtml(context, currentPanel!);
      return;
    }
    if (data.type === 'driftOpenBrowser') {
      if (!driftAdvisorSnapshot?.serverLabel?.startsWith('127.0.0.1:')) {
        void vscode.window.showInformationMessage(l10n('wideReport.driftNotConnected'));
        return;
      }
      const host = driftAdvisorSnapshot.serverLabel.split(' ')[0];
      await vscode.env.openExternal(vscode.Uri.parse(`http://${host}`));
      return;
    }
    if (data.type === 'focusIssues') {
      await vscode.commands.executeCommand('saropaLints.focusIssues');
      return;
    }
    if (data.type === 'focusIssuesForRules') {
      const rules = (data as { rules?: unknown }).rules;
      if (Array.isArray(rules) && rules.every((r) => typeof r === 'string')) {
        await vscode.commands.executeCommand('saropaLints.focusIssuesForRules', rules);
      }
      return;
    }
    if (data.type === 'openFileAndFocusIssues') {
      const fp = (data as { filePath?: unknown }).filePath;
      if (typeof fp === 'string' && fp.length > 0) {
        await vscode.commands.executeCommand('saropaLints.openFileAndFocusIssues', fp);
      }
      return;
    }
    if (data.type === 'clearWorkspaceSuppressions') {
      await vscode.commands.executeCommand('saropaLints.clearSuppressions');
      if (currentPanel) {
        await rebuildDashboardHtml(context, currentPanel);
      }
      return;
    }
    if (data.type === 'suppressRule') {
      /* Triggered by the Top Rules table's per-row Hide button. The command
         applies a workspace-level rule hide (same as the Issues tree's
         "Hide rule" — reversible via Clear Suppressions), then the
         issuesProvider's onDidChangeTreeData fires and rebuilds this panel
         automatically (extension.ts wires that). No manual rebuild here. */
      const rule = (data as { rule?: unknown }).rule;
      if (typeof rule === 'string' && rule.length > 0) {
        await vscode.commands.executeCommand('saropaLints.suppressRuleByName', rule);
      }
      return;
    }
    if (data.type === 'disableRule') {
      /* Triggered by the Top Rules table's per-row Disable button. Reuses
         the existing saropaLints.disableRules command, which writes
         analysis_options_custom.yaml, re-initializes config, and re-runs
         analysis (when runAnalysisAfterConfigChange is on). The command
         takes an array of rule names; we wrap the single rule in [rule]. */
      const rule = (data as { rule?: unknown }).rule;
      if (typeof rule === 'string' && rule.length > 0) {
        await vscode.commands.executeCommand('saropaLints.disableRules', [rule]);
      }
      return;
    }
    if (data.type === 'copyBulkFindings') {
      const blobs = (data as { violations?: unknown }).violations;
      const matches: Violation[] = [];
      if (Array.isArray(blobs)) {
        const key = (file: unknown, line: unknown, rule: unknown) =>
          `${String(file)}@${String(line)}@${String(rule)}`;
        const target = new Set(
          blobs
            .filter((b): b is Record<string, unknown> =>
              Boolean(b && typeof b === 'object'),
            )
            .map((b) =>
              key(
                typeof b.file === 'string' ? b.file : '',
                typeof b.line === 'number' ? b.line : 0,
                typeof b.rule === 'string' ? b.rule : '',
              ),
            ),
        );
        for (const v of lastExportViolations) {
          if (target.has(`${v.file}@${v.line ?? 0}@${v.rule}`)) {
            matches.push(v);
          }
        }
      }
      if (matches.length > 0) {
        await vscode.env.clipboard.writeText(JSON.stringify(matches, null, 2));
        void vscode.window.setStatusBarMessage(
          l10n('wideReport.copiedBulkFindings', { count: String(matches.length) }),
          4000,
        );
      } else {
        void vscode.window.setStatusBarMessage(l10n('wideReport.noMatchingFindingsCopy'), 2500);
      }
      return;
    }
    if (data.type === 'saveFindingsRecent') {
      const q = (data as { queries?: unknown }).queries;
      if (Array.isArray(q) && q.every((x) => typeof x === 'string')) {
        await context.workspaceState.update(
          'saropa.findingsDashboard.recentSearches',
          q.slice(0, 12),
        );
      }
      return;
    }
    if (data.type === 'paletteCommand') {
      const cmd = (data as { commandId?: unknown }).commandId;
      if (typeof cmd !== 'string' || !cmd.startsWith('saropaLints.')) {
        return;
      }
      await vscode.commands.executeCommand(cmd);
      if (currentPanel) {
        await rebuildDashboardHtml(context, currentPanel);
      }
      return;
    }
    if (data.type !== 'openFile' || typeof data.file !== 'string') {
      return;
    }
    await openFileAtLine(data.file, data.line ?? 1);
  });

  return currentPanel;
}

async function openFileAtLine(relativePath: string, line: number): Promise<void> {
  const root = getProjectRoot();
  if (!root) {
    return;
  }
  try {
    const uri = resolveWorkspaceFileUri(root, relativePath);
    const doc = await vscode.workspace.openTextDocument(uri);
    const editor = await vscode.window.showTextDocument(doc);
    const targetLine = Math.max(0, line - 1);
    const pos = new vscode.Position(targetLine, 0);
    editor.selection = new vscode.Selection(pos, pos);
    editor.revealRange(new vscode.Range(pos, pos), vscode.TextEditorRevealType.InCenter);
  } catch {
    void vscode.window.showErrorMessage(l10n('wideReport.couldNotOpenFile', { path: relativePath }));
  }
}

/** Rebuild Findings when `IssuesTreeProvider` fires (filters/suppressions) while the panel is open. */
export function refreshFindingsDashboardIfOpen(context: vscode.ExtensionContext): void {
  if (currentPanel) {
    void rebuildDashboardHtml(context, currentPanel);
  }
}

/**
 * Save the current filtered finding set to `reports/YYYYMMDD/HHMMSS_findings.json`.
 *
 * Mirrors the package-vibrancy save pattern so all dashboards drop their
 * exports under the same project-rooted folder structure. Filename embeds
 * a timestamp so successive saves never clobber each other.
 */
async function saveReportJson(violations: readonly Violation[]): Promise<void> {
  try {
    const folder = vscode.workspace.workspaceFolders?.[0];
    if (!folder) {
      void vscode.window.showWarningMessage(l10n('wideReport.saveReportNoWorkspace'));
      return;
    }
    const now = new Date();
    const ymd = `${now.getFullYear()}${pad2(now.getMonth() + 1)}${pad2(now.getDate())}`;
    const hms = `${pad2(now.getHours())}${pad2(now.getMinutes())}${pad2(now.getSeconds())}`;
    const dir = vscode.Uri.joinPath(folder.uri, 'reports', ymd);
    await vscode.workspace.fs.createDirectory(dir);
    const file = vscode.Uri.joinPath(dir, `${ymd}_${hms}_findings.json`);
    const content = JSON.stringify(violations, null, 2);
    await vscode.workspace.fs.writeFile(file, new TextEncoder().encode(content));
    void vscode.window.showInformationMessage(
      l10n('wideReport.savedFindings', {
        count: String(violations.length),
        path: file.fsPath,
      }),
    );
  } catch {
    void vscode.window.showErrorMessage(l10n('wideReport.couldNotSaveReportJson'));
  }
}

function pad2(n: number): string {
  return String(n).padStart(2, '0');
}

function resolveWorkspaceFileUri(root: string, filePathFromReport: string): vscode.Uri {
  const raw = filePathFromReport.trim();
  const windowsAbsolute = /^[a-zA-Z]:[\\/]/.test(raw);
  const posixAbsolute = raw.startsWith('/');
  if (windowsAbsolute || posixAbsolute) {
    return vscode.Uri.file(raw);
  }
  const normalizedRelative = raw
    .replaceAll('\\', '/')
    .replace(/^(\.\/)+/, '')
    .replace(/^\/+/, '');
  return vscode.Uri.file(nodePath.resolve(root, normalizedRelative));
}
