/**
 * The "fast" whole-project baseline scan: one `dart run saropa_lints:scan`
 * process using several parallel worker isolates (`--jobs`) with the syntactic
 * scan. Measured at roughly 60+ files/s per worker on a 1.4k-file project,
 * versus ~3 files/s for the type-aware daemon (a 4,478-file project takes
 * ~25 minutes deep, about a minute here).
 *
 * The scan process throttles itself under memory pressure (see
 * `parallel_scan_engine.dart`); this runner relays its machine-readable
 * progress/throttle events (`--progress json`) to the caller so the UI can
 * show progress and offer fixes. It never rejects — every failure settles
 * with `payload: null` and a message, like `runScanOnSave`.
 */
import { spawn, type ChildProcess } from 'node:child_process';
import { resolveCliCwd, killProcessTree } from '../views/devCliRoot';
import { l10n } from '../i18n/runtime';
import { parseScanOnSaveOutput, type ScanOnSavePayload } from '../scanOnSave/scanOnSaveRunner';
import { applyWindowsPriority, lowPrioritySpec } from './lowPriority';
import {
  parseScanEventLine,
  splitLines,
  type ScanEvent,
  type ScanProgressEvent,
  type ScanSummary,
  type ScanThrottleEvent,
} from './scanEvents';
import type { ResolvedScanResources } from './scanResourceSettings';

const SPAWN_USE_SHELL = process.platform === 'win32';

/** No progress event for this long means the scan process is wedged. */
export const FAST_SCAN_STALL_MS = 180_000;
/** Absolute ceiling for one fast whole-project scan. */
export const FAST_SCAN_MAX_MS = 60 * 60_000;

/**
 * argv for the fast baseline: project root FIRST (scan's parser takes the
 * first non-flag token as the path), then explicit worker count and memory
 * budget so the scan uses exactly what the user was shown, and JSON events.
 */
export function buildFastBaselineArgs(
  projectRoot: string,
  tier: string,
  resources: Pick<ResolvedScanResources, 'jobs' | 'maxMemoryMb'>,
  maxIssues = 0,
): string[] {
  return [
    projectRoot,
    '--tier',
    tier,
    '--jobs',
    String(resources.jobs),
    '--max-memory-mb',
    String(resources.maxMemoryMb),
    '--max-issues',
    String(Math.max(0, Math.floor(maxIssues))),
    '--progress',
    'json',
    '--format',
    'json',
  ];
}

export interface FastBaselineOptions {
  readonly resources: ResolvedScanResources;
  readonly lowPriority: boolean;
  /** Non-error issue cap (0 = unlimited). */
  readonly maxIssues?: number;
  readonly isCanceled: () => boolean;
  readonly onProgress?: (event: ScanProgressEvent) => void;
  readonly onThrottle?: (event: ScanThrottleEvent) => void;
  /** Stall / total ceilings, overridable for tests. */
  readonly stallMs?: number;
  readonly maxMs?: number;
}

export interface FastBaselineResult {
  readonly payload: ScanOnSavePayload | null;
  readonly exitCode: number;
  readonly errorMessage?: string;
  readonly summary?: ScanSummary;
  readonly canceled: boolean;
}

/** Runs the fast baseline scan. Never rejects. */
export function runFastBaselineScan(
  projectRoot: string,
  tier: string,
  options: FastBaselineOptions,
): Promise<FastBaselineResult> {
  return new Promise((resolvePromise) => {
    const args = ['run', 'saropa_lints:scan', ...buildFastBaselineArgs(projectRoot, tier, options.resources, options.maxIssues ?? 0)];
    const spec = lowPrioritySpec('dart', args, options.lowPriority);
    let child: ChildProcess;
    try {
      child = spawn(spec.command, [...spec.args], {
        cwd: resolveCliCwd(projectRoot),
        shell: SPAWN_USE_SHELL,
      });
    } catch (err) {
      resolvePromise({
        payload: null,
        exitCode: -1,
        errorMessage: err instanceof Error ? err.message : l10n('notify.commands.scanOnSaveStartFailed'),
        canceled: false,
      });
      return;
    }
    applyWindowsPriority(child.pid, options.lowPriority);

    let stdout = '';
    let stderrRest = '';
    let summary: ScanSummary | undefined;
    let settled = false;
    let canceled = false;
    let lastActivity = Date.now();
    const startedAt = Date.now();
    const stallMs = options.stallMs ?? FAST_SCAN_STALL_MS;
    const maxMs = options.maxMs ?? FAST_SCAN_MAX_MS;

    const finish = (result: FastBaselineResult): void => {
      if (settled) return;
      settled = true;
      clearInterval(watchdog);
      resolvePromise(result);
    };

    // One timer covers cancellation polling, the stall watchdog and the
    // absolute ceiling. Kill the whole tree — on Windows the shell wrapper
    // would otherwise orphan dart.exe and its worker memory.
    const watchdog = setInterval(() => {
      if (options.isCanceled() && !canceled) {
        canceled = true;
        killProcessTree(child);
        return;
      }
      const now = Date.now();
      if (!canceled && now - lastActivity > stallMs) {
        killProcessTree(child);
        finish({
          payload: null,
          exitCode: -1,
          errorMessage: l10n('notify.commands.scanOnSaveDaemonTimeout'),
          canceled: false,
        });
      } else if (!canceled && now - startedAt > maxMs) {
        killProcessTree(child);
        finish({
          payload: null,
          exitCode: -1,
          errorMessage: l10n('notify.commands.scanOnSaveDaemonTimeout'),
          canceled: false,
        });
      }
    }, 1000);
    watchdog.unref?.();

    const handleEvent = (event: ScanEvent): void => {
      lastActivity = Date.now();
      if (event.event === 'progress') options.onProgress?.(event);
      else if (event.event === 'throttle') options.onThrottle?.(event);
      else if (event.event === 'summary') summary = event;
    };

    child.stdout?.on('data', (chunk: Buffer | string) => {
      stdout += chunk.toString();
    });
    child.stderr?.on('data', (chunk: Buffer | string) => {
      lastActivity = Date.now();
      const { lines, rest } = splitLines(stderrRest + chunk.toString());
      stderrRest = rest;
      for (const line of lines) {
        const ev = parseScanEventLine(line);
        if (ev) handleEvent(ev);
      }
    });
    child.on('error', (err: NodeJS.ErrnoException) => {
      finish({
        payload: null,
        exitCode: -1,
        errorMessage: err?.message?.trim() || l10n('notify.commands.scanOnSaveStartFailed'),
        canceled: false,
      });
    });
    child.on('close', (code) => {
      const exitCode = code ?? -1;
      if (canceled) {
        finish({ payload: null, exitCode, summary, canceled: true });
        return;
      }
      // 0 = clean, 1 = issues found — both are successful runs. 3 = the scan
      // stopped early to protect the machine: the payload is valid but
      // partial, and the summary event carries the reason.
      if (exitCode !== 0 && exitCode !== 1 && exitCode !== 3) {
        finish({
          payload: null,
          exitCode,
          summary,
          errorMessage: l10n('notify.commands.scanOnSaveFailed'),
          canceled: false,
        });
        return;
      }
      const payload = parseScanOnSaveOutput(stdout);
      if (!payload) {
        finish({
          payload: null,
          exitCode,
          summary,
          errorMessage: l10n('notify.commands.scanOnSaveInvalidJson'),
          canceled: false,
        });
        return;
      }
      finish({ payload, exitCode, summary, canceled: false });
    });
  });
}
