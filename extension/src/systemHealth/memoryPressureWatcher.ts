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
  /** Graduated shed level: 0=normal, 1=INFO shed, 2=INFO+WARNING shed. */
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
export function memoryPressureSuffix(
  state: MemoryPressureState | null,
): string | undefined {
  if (!state) return undefined;

  // Hard limit tripped — all rules paused, most urgent.
  if (state.hardLimitTripped) {
    return l10n('memoryPressure.statusBar.hardTripped', {
      rssMb: String(state.rssMb),
    });
  }
  // Level 2: INFO + WARNING rules shed.
  if (state.shedLevel >= 2) {
    return l10n('memoryPressure.statusBar.shedWarning', {
      count: String(state.shedRuleCount),
    });
  }
  // Level 1: INFO rules shed — informational.
  if (state.shedLevel >= 1) {
    return l10n('memoryPressure.statusBar.shedInfo', {
      count: String(state.shedRuleCount),
    });
  }
  // Soft limit tripped but shedding not enabled — persistent indicator so
  // the user has ongoing visibility even after dismissing the one-shot toast.
  if (state.softLimitTripped && !state.shedEnabled) {
    return l10n('memoryPressure.statusBar.pressureNoShed', {
      rssMb: String(state.rssMb),
    });
  }
  return undefined;
}

/**
 * Produces the tooltip line for the current memory-pressure state, or
 * undefined when no line is warranted. Shares the same hard-tripped /
 * shed-level-2 / shed-level-1 priority order as {@link memoryPressureSuffix}
 * so the status-bar text and tooltip never disagree about which state won.
 */
export function memoryPressureTooltipLine(
  state: MemoryPressureState | null,
): string | undefined {
  if (!state) return undefined;

  if (state.hardLimitTripped) {
    return l10n('memoryPressure.tooltip.hardTripped');
  }
  if (state.shedLevel >= 2) {
    return l10n('memoryPressure.tooltip.shedLevel2', {
      count: String(state.shedRuleCount),
    });
  }
  if (state.shedLevel >= 1) {
    return l10n('memoryPressure.tooltip.shedLevel1', {
      count: String(state.shedRuleCount),
    });
  }
  // Soft limit tripped with shedding off — show a tooltip so the user
  // knows pressure exists even if they dismissed the one-shot toast.
  if (state.softLimitTripped && !state.shedEnabled) {
    return l10n('memoryPressure.tooltip.pressureNoShed');
  }
  return undefined;
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
