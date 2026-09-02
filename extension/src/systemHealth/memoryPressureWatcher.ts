import * as fs from 'fs';
import * as path from 'path';
import * as vscode from 'vscode';
import { l10n } from '../i18n/runtime';
import { saropaLintsDataPath } from '../reportsPaths';

/**
 * Plugin-side memory pressure state, written to `memory_state.json`
 * by the Dart analyzer plugin on shed-level transitions.
 */
export interface MemoryPressureState {
  /** Cost-aware shed level: 0=normal, 1=expensive (type-resolving+high-cost), 2=+INFO, 3=+WARNING. */
  shedLevel: number;
  /** Current resident-set size in MB when the transition occurred. */
  rssMb: number;
  /** Soft memory limit in MB (70% of hard limit). */
  softLimitMb: number;
  /** Hard memory limit in MB (env SAROPA_LINTS_MAX_RSS_MB or 4096). */
  hardLimitMb: number;
  /** Whether the soft RSS threshold has been crossed. */
  softLimitTripped: boolean;
  /** Whether the hard RSS limit has been exceeded (all rules paused). */
  hardLimitTripped: boolean;
  /** Number of rules currently shed. */
  shedRuleCount: number;
  /** Whether the user has opted in via `shed_rules: true`. */
  shedEnabled: boolean;
  /** ISO 8601 timestamp of the transition. */
  timestamp: string;
  /** Breakdown of shed rules by category — written when shedLevel > 0. */
  shedDetails?: {
    typeResolving: number;
    highCost: number;
    infoSeverity: number;
    warningSeverity: number;
    typeResolvingRules?: string[];
    highCostRules?: string[];
    infoSeverityRules?: string[];
    warningSeverityRules?: string[];
  };
}

/**
 * Watches `reports/.saropa_lints/memory_state.json` for shed-level transitions
 * written by the analyzer plugin and notifies listeners on significant changes.
 *
 * Uses `fs.watch` on the reports directory — no polling. Only fires when
 * shedLevel or hardLimitTripped changes to avoid noisy re-renders.
 */
export class MemoryPressureWatcher implements vscode.Disposable {
  private _watcher: fs.FSWatcher | null = null;
  private _state: MemoryPressureState | null = null;
  private _onStateChange:
    | ((state: MemoryPressureState | null) => void)
    | null = null;

  /** Register the callback invoked on significant state changes. */
  onStateChange(cb: (state: MemoryPressureState | null) => void): void {
    this._onStateChange = cb;
  }

  /** Begin watching the reports directory under [root]. */
  start(root: string): void {
    this.dispose();

    // Shared helper keeps this in sync with the other reports/.saropa_lints consumers.
    const reportsDir = saropaLintsDataPath(root);
    const stateFile = path.join(reportsDir, 'memory_state.json');

    // Try an initial read — the file may already exist from a prior session.
    this._tryRead(stateFile);

    // Watch the directory, filtering for memory_state.json changes.
    // fs.watch `filename` can be null on macOS FSEvents and some Linux
    // configurations — fall back to reading on any event when null.
    try {
      let debounceTimer: ReturnType<typeof setTimeout> | null = null;
      this._watcher = fs.watch(reportsDir, (_eventType, filename) => {
        if (filename !== null && filename !== 'memory_state.json') return;
        // Debounce — Windows commonly fires 2-3 events per write.
        if (debounceTimer) clearTimeout(debounceTimer);
        debounceTimer = setTimeout(() => this._tryRead(stateFile), 80);
      });
      // Swallow watcher errors (directory may vanish mid-session).
      this._watcher.on('error', () => {});
    } catch {
      // Directory may not exist yet — the plugin creates it on first write.
      // The watcher will be retried on the next start() call (e.g. after
      // workspace folder change triggers extension re-init).
    }
  }

  /** Parse the state file and notify only on significant transitions. */
  private _tryRead(filePath: string): void {
    try {
      const raw = fs.readFileSync(filePath, 'utf8');
      const parsed = JSON.parse(raw) as MemoryPressureState;

      // Notify on shed level, hard-limit, or soft-limit trip state changes.
      // softLimitTripped is needed so the "enable shedding" prompt fires
      // when shedding is off (shedLevel stays 0 in that path).
      const changed =
        this._state === null ||
        this._state.shedLevel !== parsed.shedLevel ||
        this._state.hardLimitTripped !== parsed.hardLimitTripped ||
        this._state.softLimitTripped !== parsed.softLimitTripped;

      this._state = parsed;
      if (changed) {
        this._onStateChange?.(parsed);
      }
    } catch {
      // Swallow parse errors from partial writes or missing file.
    }
  }

  dispose(): void {
    this._watcher?.close();
    this._watcher = null;
  }
}

/**
 * Produces the status-bar suffix for the current memory-pressure state,
 * or undefined when no pressure suffix is warranted.
 *
 * Priority over the process-level `systemHealthSuffix` — plugin-level
 * memory pressure is more actionable than aggregate process RSS.
 */
/**
 * l10n key map for each pressure band. Single source of truth — both the
 * status-bar suffix and the tooltip line read from this table so they
 * never disagree about which state won.
 */
interface PressureBandKeys {
  statusBar: string;
  tooltip: string;
}

/** Ordered priority: hardTripped > shedLevel 3 > 2 > 1 > softNoShed. */
const PRESSURE_BANDS: readonly {
  match: (s: MemoryPressureState) => boolean;
  keys: PressureBandKeys;
  /** l10n interpolation tokens for this band. */
  params: (s: MemoryPressureState) => Record<string, string>;
}[] = [
  {
    match: (s) => s.hardLimitTripped,
    keys: {
      statusBar: 'memoryPressure.statusBar.hardTripped',
      tooltip: 'memoryPressure.tooltip.hardTripped',
    },
    params: (s) => ({ rssMb: String(s.rssMb) }),
  },
  {
    match: (s) => s.shedLevel >= 3,
    keys: {
      statusBar: 'memoryPressure.statusBar.shedCritical',
      tooltip: 'memoryPressure.tooltip.shedLevel3',
    },
    params: (s) => ({ count: String(s.shedRuleCount) }),
  },
  {
    match: (s) => s.shedLevel >= 2,
    keys: {
      statusBar: 'memoryPressure.statusBar.shedWarning',
      tooltip: 'memoryPressure.tooltip.shedLevel2',
    },
    params: (s) => ({ count: String(s.shedRuleCount) }),
  },
  {
    match: (s) => s.shedLevel >= 1,
    keys: {
      statusBar: 'memoryPressure.statusBar.shedInfo',
      tooltip: 'memoryPressure.tooltip.shedLevel1',
    },
    params: (s) => ({ count: String(s.shedRuleCount) }),
  },
  {
    match: (s) => s.softLimitTripped && !s.shedEnabled,
    keys: {
      statusBar: 'memoryPressure.statusBar.pressureNoShed',
      tooltip: 'memoryPressure.tooltip.pressureNoShed',
    },
    params: (s) => ({ rssMb: String(s.rssMb) }),
  },
];

/** Pick the first matching pressure band for the given state. */
function matchPressureBand(state: MemoryPressureState | null) {
  if (!state) return undefined;
  for (const band of PRESSURE_BANDS) {
    if (band.match(state)) return { keys: band.keys, params: band.params(state) };
  }
  return undefined;
}

export function memoryPressureSuffix(
  state: MemoryPressureState | null,
): string | undefined {
  const band = matchPressureBand(state);
  return band ? l10n(band.keys.statusBar, band.params) : undefined;
}

/**
 * Produces the tooltip line for the current memory-pressure state, or
 * undefined when no line is warranted. Uses the same priority table as
 * {@link memoryPressureSuffix} so the two never disagree.
 */
export function memoryPressureTooltipLine(
  state: MemoryPressureState | null,
): string | undefined {
  const band = matchPressureBand(state);
  if (!band) return undefined;
  const base = l10n(band.keys.tooltip, band.params);
  // Append shed breakdown when details are available.
  const details = state?.shedDetails;
  if (!details || !state || state.shedLevel <= 0) return base;
  const parts: string[] = [];
  if (details.typeResolving > 0) parts.push(`${details.typeResolving} type-resolving`);
  if (details.highCost > 0) parts.push(`${details.highCost} high-cost`);
  if (details.infoSeverity > 0) parts.push(`${details.infoSeverity} INFO`);
  if (details.warningSeverity > 0) parts.push(`${details.warningSeverity} WARNING`);
  return parts.length > 0 ? `${base} (${parts.join(', ')})` : base;
}

/**
 * Shows a VS Code warning notification when memory pressure is detected but
 * rule shedding is not enabled. Prompts the user to enable `shed_rules: true`
 * in their config. Keyed per workspace root so multi-root workspaces get
 * independent prompts, each firing at most once per extension host lifetime.
 */
const _shedPromptShownForRoot = new Set<string>();

export function promptEnableShedRulesIfNeeded(
  state: MemoryPressureState | null,
): void {
  if (!state) return;
  // Only prompt when soft limit is tripped but shedding is off.
  if (!state.softLimitTripped || state.shedEnabled) return;

  // Key by workspace root so multi-root workspaces get per-project prompts.
  const root = vscode.workspace.workspaceFolders?.[0]?.uri.fsPath ?? '';
  if (_shedPromptShownForRoot.has(root)) return;
  _shedPromptShownForRoot.add(root);

  const message = l10n('memoryPressure.notification.shedDisabled', {
    rssMb: String(state.rssMb),
    softLimitMb: String(state.softLimitMb),
  });
  const enableLabel = l10n('memoryPressure.notification.enableButton');
  const learnMoreLabel = l10n('memoryPressure.notification.learnMoreButton');

  void vscode.window
    .showWarningMessage(message, enableLabel, learnMoreLabel)
    .then((choice) => {
      if (choice === enableLabel) {
        void _enableShedRulesInConfig(root);
      } else if (choice === learnMoreLabel) {
        void vscode.env.openExternal(
          vscode.Uri.parse(
            'https://pub.dev/packages/saropa_lints#memory-pressure',
          ),
        );
      }
    });
}

/**
 * Writes `shed_rules: true` into `analysis_options_custom.yaml` at [root].
 * If the line already exists (commented or not), flips it to `true`.
 * If the file doesn't exist, guides the user to run `dart run saropa_lints:init`.
 */
async function _enableShedRulesInConfig(root: string): Promise<void> {
  if (!root) return;
  const configUri = vscode.Uri.joinPath(
    vscode.Uri.file(root),
    'analysis_options_custom.yaml',
  );

  let content: string;
  try {
    const bytes = await vscode.workspace.fs.readFile(configUri);
    content = Buffer.from(bytes).toString('utf8');
  } catch {
    // File doesn't exist — guide the user to generate it.
    void vscode.window.showInformationMessage(
      l10n('memoryPressure.notification.runInit'),
    );
    return;
  }

  // Replace commented or false shed_rules line, or append if missing.
  const shedLinePattern = /^[# ]*shed_rules\s*:.*$/m;
  let updated: string;
  if (shedLinePattern.test(content)) {
    // Flip existing line (commented or false) to true.
    updated = content.replace(shedLinePattern, 'shed_rules: true');
  } else {
    // Append at end with a blank line separator.
    const separator = content.endsWith('\n') ? '' : '\n';
    updated = `${content}${separator}\nshed_rules: true\n`;
  }

  await vscode.workspace.fs.writeFile(
    configUri,
    Buffer.from(updated, 'utf8'),
  );
  void vscode.window.showInformationMessage(
    l10n('memoryPressure.notification.enabledConfirmation'),
  );
}
