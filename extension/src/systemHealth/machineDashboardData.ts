/**
 * Pure aggregation and recommendation logic for the Machine Health dashboard.
 *
 * Separated from `machineDashboard.ts` (the webview class) so the grouping
 * and recommendation rules — the part someone will actually want to change
 * ("why didn't it warn me about X?") — are unit-testable without a webview
 * or a live process table.
 *
 * **Key invariant:** process categorization delegates to `classifyProcess()`
 * (the single source of truth shared with the status bar and Process Health
 * panel). Any new process category MUST be added there first — this module
 * translates its enum into dashboard group keys, so a category rename
 * upstream fails to compile here rather than silently mis-bucketing.
 *
 * **Platform assumption:** all data sources are Windows-only (CIM queries,
 * Ollama CLI). Non-Windows callers receive empty results, never errors.
 */
import { l10n } from '../i18n/runtime';
import {
  classifyProcess,
  formatBytes,
  ProcessCategory,
  HEAP_CAP_FLAG,
} from './processQuery';
import type { DartProcessInfo } from './types';
import type { HostProcessInfo } from './orphanHosts';
import type { LoadedModel } from './ollamaQuery';
import type { SystemMemorySnapshot } from './systemQuery';

/**
 * One row rendered inside a process group's expandable table. Deliberately
 * a plain data shape (not `DartProcessInfo`/`HostProcessInfo` directly) so
 * `groupDartProcesses` and `groupModelHosts` can feed the same table
 * renderer despite their two source types having different field names
 * (`workingSetSize` vs `committedBytes`, etc).
 */
export interface DisplayProcessRow {
  processId: number;
  parentProcessId: number;
  rssBytes: number;
  commandLine: string;
  isOrphan: boolean;
}

/** One category section of the dashboard (Analysis Server, Flutter Daemon, etc). */
export interface ProcessGroup {
  key: 'analysisServer' | 'flutterDaemon' | 'saropa' | 'otherDart' | 'modelHost';
  processCount: number;
  totalRssBytes: number;
  orphanCount: number;
  rows: DisplayProcessRow[];
}

/** Threshold, in GB, past which a single analysis-server process gets its own recommendation. */
const DEFAULT_ANALYSIS_SERVER_WARNING_GB = 4;
const BYTES_PER_GB = 1_073_741_824;

/** Default free-RAM percentage below which a recommendation fires (matches package.json default). */
const DEFAULT_SYSTEM_MEMORY_WARNING_PERCENT = 15;

/** Default dev-tool memory budget as a percentage of total system RAM. */
const DEFAULT_DEV_TOOL_BUDGET_PERCENT = 60;

/** Budget computation result — how much of the machine's RAM dev tools are using vs the target. */
export interface DevToolBudget {
  /** Sum of all tracked process groups' RSS, in bytes. */
  devToolBytes: number;
  /** devToolBytes as a percentage of total system RAM. */
  usedPercent: number;
  /** The user's configured budget target. */
  budgetPercent: number;
  /** Whether the dev tools exceed the budget. */
  overBudget: boolean;
}

/**
 * Compute how much of the machine's total RAM is consumed by tracked dev
 * tools (every process group in the dashboard). Returns undefined when
 * system RAM is unknown (non-Windows or query failure).
 */
export function computeDevToolBudget(
  system: SystemMemorySnapshot | undefined,
  groups: readonly ProcessGroup[],
  budgetPercent: number,
): DevToolBudget | undefined {
  if (!system) return undefined;
  // Sum every tracked group's RSS — this is deliberately broader than
  // saropa-owned RSS (which only counts this extension's own processes)
  // because the budget answers "how much RAM are my dev tools using total?"
  const devToolBytes = groups.reduce((sum, g) => sum + g.totalRssBytes, 0);
  const usedPercent = (devToolBytes / system.totalBytes) * 100;
  return {
    devToolBytes,
    usedPercent: Math.round(usedPercent * 10) / 10,
    budgetPercent,
    overBudget: usedPercent > budgetPercent,
  };
}

/** One actionable or informational line in the dashboard's Recommendations panel. */
export interface Recommendation {
  id: string;
  severity: 'info' | 'warning' | 'critical';
  text: string;
  /** VS Code command to run when the recommendation's button is clicked, if any. */
  actionCommand?: string;
  actionLabel?: string;
  /** Positional arguments forwarded to `actionCommand` (e.g. which model to unload). */
  actionArgs?: string[];
}

/**
 * Partition Dart processes into category groups, marking orphans within each.
 * Delegates classification to `classifyProcess` (the single source of truth
 * shared with the status bar and Process Health panel) so this dashboard can
 * never disagree with those surfaces about what a process is.
 */
export function groupDartProcesses(
  processes: readonly DartProcessInfo[],
  orphanPids: ReadonlySet<number>,
): ProcessGroup[] {
  // Map, not a fixed 4-key object literal, because the dashboard only wants
  // to render groups that actually have processes in them (an empty "Flutter
  // Daemon" section on a pure-backend project is noise) — buildGroupsSection
  // already filters on processCount, but starting from an empty map means
  // that filter has real work to do instead of always seeing all 4 keys.
  const buckets = new Map<ProcessGroup['key'], ProcessGroup>();
  // classifyProcess's ProcessCategory enum is shared with the status bar and
  // Process Health panel; this local map only translates its 4 values into
  // this dashboard's own group keys, so a category rename upstream fails to
  // compile here instead of silently mis-bucketing.
  const keyFor = (category: ProcessCategory): ProcessGroup['key'] => {
    switch (category) {
      case ProcessCategory.AnalysisServer: return 'analysisServer';
      case ProcessCategory.Daemon: return 'flutterDaemon';
      case ProcessCategory.Saropa: return 'saropa';
      default: return 'otherDart';
    }
  };

  for (const p of processes) {
    const key = keyFor(classifyProcess(p).category);
    let group = buckets.get(key);
    if (!group) {
      // First process seen for this category — lazily create its bucket
      // rather than pre-seeding all 4, per the comment above.
      group = { key, processCount: 0, totalRssBytes: 0, orphanCount: 0, rows: [] };
      buckets.set(key, group);
    }
    const isOrphan = orphanPids.has(p.processId);
    group.processCount++;
    group.totalRssBytes += p.workingSetSize;
    if (isOrphan) group.orphanCount++;
    group.rows.push({
      processId: p.processId,
      parentProcessId: p.parentProcessId,
      rssBytes: p.workingSetSize,
      commandLine: p.commandLine,
      isOrphan,
    });
  }
  return [...buckets.values()];
}

/**
 * Convert model-host processes (Ollama/llama-server) into a dashboard group.
 * Returns a single group (not an array like `groupDartProcesses`) because
 * `orphanHosts.ts` treats every model-host image name as one category —
 * there is no equivalent of "Flutter daemon vs analysis server" split to make
 * within this process family.
 */
export function groupModelHosts(
  hosts: readonly HostProcessInfo[],
  orphanPids: ReadonlySet<number>,
): ProcessGroup {
  const group: ProcessGroup = {
    key: 'modelHost',
    processCount: hosts.length,
    totalRssBytes: 0,
    orphanCount: 0,
    rows: [],
  };
  for (const h of hosts) {
    const isOrphan = orphanPids.has(h.processId);
    // committedBytes (WMI PageFileUsage), not a working-set figure — model
    // hosts hold large weight tensors that are often paged out but still
    // "owned" memory the user cares about reclaiming; see orphanHosts.ts.
    group.totalRssBytes += h.committedBytes;
    if (isOrphan) group.orphanCount++;
    group.rows.push({
      processId: h.processId,
      parentProcessId: h.parentProcessId,
      rssBytes: h.committedBytes,
      commandLine: h.name,
      isOrphan,
    });
  }
  return group;
}

/** Inputs to {@link buildRecommendations} — bundled because every field can independently trigger a rule. */
export interface RecommendationInput {
  system: SystemMemorySnapshot | undefined;
  groups: readonly ProcessGroup[];
  loadedModels: readonly LoadedModel[];
  orphanCount: number;
  orphanTotalBytes: number;
  analysisServerWarningGB: number;
  /** Free-RAM percentage below which the systemLowMemory recommendation fires.
   *  Must match the same setting processMonitor reads, so the dashboard and
   *  the proactive notification agree on when memory is "low". */
  systemMemoryWarningPercent: number;
  /** Target percentage of total RAM for dev tools — the budget threshold. */
  devToolBudgetPercent: number;
  /** Raw `dart.analyzerVmAdditionalArgs` setting value, to detect a missing heap cap. */
  analyzerVmArgs: readonly string[];
}

/**
 * Derive the dashboard's Recommendations panel from current state. Pure and
 * order-independent of caller side effects — every rule reads only from
 * `input`, so adding a new rule never needs to touch the webview class.
 */
export function buildRecommendations(input: RecommendationInput): Recommendation[] {
  const recs: Recommendation[] = [];

  // Highest severity first: a machine-wide low-memory condition matters more
  // than any single process's attribution.
  // Use the same configurable threshold that processMonitor's checkSystemMemory reads,
  // so the dashboard's "low memory" card and the proactive notification agree.
  const warningFraction = (input.systemMemoryWarningPercent ?? DEFAULT_SYSTEM_MEMORY_WARNING_PERCENT) / 100;
  if (input.system && input.system.freeFraction < warningFraction) {
    recs.push({
      id: 'systemLowMemory',
      severity: 'critical',
      text: l10n('machineDashboard.recommendation.systemLowMemory', {
        free: formatBytes(input.system.freeBytes),
        total: formatBytes(input.system.totalBytes),
      }),
    });
  }

  if (input.orphanCount > 0) {
    recs.push({
      id: 'orphansFound',
      severity: 'warning',
      text: l10n('machineDashboard.recommendation.orphansFound', {
        count: String(input.orphanCount),
        size: formatBytes(input.orphanTotalBytes),
      }),
      actionCommand: 'saropaLints.checkOrphanedProcesses',
      actionLabel: l10n('machineDashboard.action.reclaim'),
    });
  }

  const analysisGroup = input.groups.find((g) => g.key === 'analysisServer');
  const warningBytes = input.analysisServerWarningGB * BYTES_PER_GB;
  if (analysisGroup) {
    // Per-process check (not group total) — one runaway `dart.exe` at 6 GB
    // is a restart candidate; four healthy 1 GB servers summing to the same
    // total are not (that's the "multiple servers" case below instead).
    const oversized = analysisGroup.rows.filter((r) => r.rssBytes >= warningBytes);
    if (oversized.length > 0) {
      recs.push({
        id: 'analysisServerLarge',
        severity: 'warning',
        text: l10n('machineDashboard.recommendation.analysisServerLarge', {
          count: String(oversized.length),
          size: formatBytes(Math.max(...oversized.map((r) => r.rssBytes))),
        }),
        // dart.restartAnalysisServer is Dart-Code's own built-in command —
        // deliberately reused rather than killing the PID directly, since a
        // bare kill leaves Dart-Code's client state out of sync until the
        // user manually reloads the window.
        actionCommand: 'dart.restartAnalysisServer',
        actionLabel: l10n('machineDashboard.action.restartAnalysisServer'),
      });
    }
    // >=2 analysis servers usually means multiple VS Code windows open on
    // overlapping projects — informational only (no single action fixes it;
    // the fix is "close a window", which isn't ours to do for the user).
    if (analysisGroup.processCount >= 2) {
      recs.push({
        id: 'multipleAnalysisServers',
        severity: 'info',
        text: l10n('machineDashboard.recommendation.multipleAnalysisServers', {
          count: String(analysisGroup.processCount),
        }),
      });
    }
    // HEAP_CAP_FLAG absence means the analysis server has no per-VM memory
    // ceiling at all — see ANALYSIS_dev_machine_stability.md §1: this is the
    // one lever Dart-Code exposes and most users never discover it because
    // it's a VM flag buried in an "additional args" setting, not a checkbox.
    const hasHeapCap = input.analyzerVmArgs.some((a) => a.includes(HEAP_CAP_FLAG));
    if (!hasHeapCap && analysisGroup.processCount > 0) {
      recs.push({
        id: 'noHeapCap',
        severity: 'info',
        text: l10n('machineDashboard.recommendation.noHeapCap'),
        actionCommand: 'saropaLints.setAnalysisServerHeapCap',
        actionLabel: l10n('machineDashboard.action.setHeapCap'),
      });
    }
  }

  // One recommendation per loaded model (not one aggregate line) because
  // each has its own actionArgs — the unload button must name exactly which
  // model to stop, and a combined line would need buttons anyway.
  if (input.loadedModels.length > 0) {
    for (const model of input.loadedModels) {
      recs.push({
        id: `modelLoaded:${model.name}`,
        severity: 'info',
        text: l10n('machineDashboard.recommendation.modelLoaded', {
          model: model.name,
          size: formatBytes(model.sizeBytes),
        }),
        actionCommand: 'saropaLints.unloadOllamaModel',
        actionLabel: l10n('machineDashboard.action.unloadModel'),
        actionArgs: [model.name],
      });
    }
  }

  // Budget overspend: when dev tools collectively exceed the user's configured
  // share of total RAM. Lower severity than systemLowMemory (which fires
  // when the machine is actually in trouble) — this is a proactive nudge.
  const budget = computeDevToolBudget(
    input.system,
    input.groups,
    input.devToolBudgetPercent ?? DEFAULT_DEV_TOOL_BUDGET_PERCENT,
  );
  if (budget?.overBudget) {
    recs.push({
      id: 'budgetOverspend',
      severity: 'warning',
      text: l10n('machineDashboard.recommendation.budgetOverspend', {
        used: String(budget.usedPercent),
        budget: String(budget.budgetPercent),
        size: formatBytes(budget.devToolBytes),
      }),
    });
  }

  return recs;
}

export { DEFAULT_ANALYSIS_SERVER_WARNING_GB, DEFAULT_SYSTEM_MEMORY_WARNING_PERCENT, DEFAULT_DEV_TOOL_BUDGET_PERCENT };
