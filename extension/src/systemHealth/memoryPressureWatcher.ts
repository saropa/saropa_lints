import * as fs from 'fs';
import * as path from 'path';
import * as vscode from 'vscode';
import { l10n } from '../i18n/runtime';

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

    const reportsDir = path.join(root, 'reports', '.saropa_lints');
    const stateFile = path.join(reportsDir, 'memory_state.json');

    // Try an initial read — the file may already exist from a prior session.
    this._tryRead(stateFile);

    // Watch the directory, filtering for memory_state.json changes.
    try {
      this._watcher = fs.watch(reportsDir, (eventType, filename) => {
        if (filename === 'memory_state.json') {
          this._tryRead(stateFile);
        }
      });
      // Swallow watcher errors (directory may vanish mid-session).
      this._watcher.on('error', () => {});
    } catch {
      // Directory may not exist yet — the plugin creates it on first write.
    }
  }

  /** Parse the state file and notify only on significant transitions. */
  private _tryRead(filePath: string): void {
    try {
      const raw = fs.readFileSync(filePath, 'utf8');
      const parsed = JSON.parse(raw) as MemoryPressureState;

      // Notify only when the shed level or hard-limit trip state changes —
      // avoids re-rendering on every RSS fluctuation within the same band.
      const changed =
        this._state === null ||
        this._state.shedLevel !== parsed.shedLevel ||
        this._state.hardLimitTripped !== parsed.hardLimitTripped;

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
  return undefined;
}
