/**
 * Spawns `dart run saropa_lints:project_health` for the Project Map webview.
 *
 * WP1 (`plans/PLAN_ext_ui_dart_deferred.md`): `bin/project_health.dart` now
 * supports `--progress` (NDJSON scan events on stderr, mirroring
 * `project_vibrancy`'s identical protocol exactly — see
 * `lib/src/cli/project_health/scan_progress.dart`) and `--control <path>`
 * (pause/cancel via a rewritten text file). This module is the ONE place that
 * builds those flags and separates progress-event lines from real diagnostic
 * stderr, so `projectMapView.ts` gets a parsed `VibrancyScanEvent` stream
 * instead of raw text to regex against.
 *
 * The event shape is reused from `projectVibrancyTypes.ts`
 * (`VibrancyScanEvent`) rather than re-declared, per the plan's instruction
 * not to invent a second protocol — Project Health's `--progress` emits the
 * exact same `{event, phase, done, total, file}` keys Code Health does.
 */
import * as cp from 'node:child_process';
import * as fs from 'node:fs';
import * as os from 'node:os';
import * as path from 'node:path';
import type * as vscode from 'vscode';
import type { VibrancyScanEvent } from './projectVibrancyTypes';
import { killProcessTree } from './devCliRoot';

/** Pause/resume/cancel handle for an in-flight streaming Project Health scan. */
export interface ProjectHealthScanControl {
  pause(): void;
  resume(): void;
  cancel(): void;
}

/** Streaming hooks for [runProjectHealthScan]. Both optional; supplying either enables `--progress`. */
export interface ProjectHealthScanHandlers {
  /** One parsed NDJSON progress event per call (phase/tick/done). */
  readonly onProgress?: (event: VibrancyScanEvent) => void;
  /** One line of REAL stderr/stdout output (not a progress event) — feeds the panel's activity log. */
  readonly onOutputLine?: (line: string, stream: 'stdout' | 'stderr') => void;
  /** Hands back pause/resume/cancel once the control file exists. */
  readonly onControl?: (control: ProjectHealthScanControl) => void;
}

/** Extra Project Health CLI flags this Map-tab scan always wants, beyond `--path`/`--output-dir`. */
const BASE_ARGS = [
  '--complexity',
  '--git',
  // Per-feature performance gravity panel (compound widget patterns).
  '--performance',
  '--format',
  'html',
  // Re-parse only changed files on rescans (the project_health cache).
  '--cache',
] as const;

/** Builds argv for `dart run saropa_lints:project_health --format html`. Exported for tests. */
export function buildProjectHealthArgs(
  root: string,
  outputDir: string,
  streaming: boolean,
  controlPath: string | undefined,
): string[] {
  const args = ['run', 'saropa_lints:project_health', '--path', root, '--output-dir', outputDir, ...BASE_ARGS];
  // --progress is opt-in: without a handler the scan's stdout/exit-code
  // contract is byte-for-byte identical to before this feature existed
  // (scanProjectMapToParts, the consolidated-dashboard embed path, never
  // passes handlers — it keeps the original buffered behavior on purpose).
  if (streaming) {
    args.push('--progress');
    if (controlPath) args.push('--control', controlPath);
  }
  return args;
}

/** Allocates a unique control file under the OS temp dir, seeded with `run` — same shape as project_vibrancy's. */
function createControlFile(): string {
  const controlPath = path.join(os.tmpdir(), `saropa-health-map-control-${process.pid}-${Date.now()}.txt`);
  try {
    fs.writeFileSync(controlPath, 'run');
  } catch {
    // Best-effort: if temp is not writable the scan still runs, just without
    // pause/cancel-via-file (the cancellation token still kills the child).
  }
  return controlPath;
}

function writeControl(controlPath: string, command: string): void {
  try {
    fs.writeFileSync(controlPath, command);
  } catch {
    // Best-effort: a failed control write leaves the scan running; the caller
    // can still cancel via the cancellation token (which kills the child).
  }
}

/** Parses one NDJSON stderr line into a progress event, or undefined if it isn't one. */
export function tryParseHealthProgressEvent(line: string): VibrancyScanEvent | undefined {
  if (!line.startsWith('{')) return undefined;
  try {
    const parsed = JSON.parse(line) as { event?: unknown };
    if (typeof parsed.event === 'string') return parsed as VibrancyScanEvent;
  } catch {
    // Not an event line (e.g. a dart stack trace) — caller keeps it as real stderr.
  }
  return undefined;
}

/** Outcome of [runProjectHealthScan]: exit status plus enough detail to build an error toast. */
export interface ProjectHealthScanResult {
  /** True only on a clean, non-canceled exit (code 0) — the report was written. */
  readonly ok: boolean;
  /** True when `token`/`handlers.onControl().cancel()` initiated the exit — never surface as an error. */
  readonly cancelled: boolean;
  readonly exitCode: number | null;
  /** First non-empty raw stderr line (diagnostic text, not a progress event) — for the failure toast. */
  readonly firstStderrLine: string;
  /** Set when the process itself could not start (e.g. `dart` missing from PATH) — distinct from a scan failure. */
  readonly spawnErrorMessage?: string;
}

/**
 * Runs the Project Health scan, resolving with its exit status. Mirrors
 * `runScan`'s previous shape (cwd resolution, tree-kill on cancel, buffered
 * stdout/stderr line splitting) but adds `--progress` NDJSON parsing when
 * [handlers] is given, and returns enough detail for the caller to build the
 * same error toast the old inline runner did.
 */
export function runProjectHealthScan(
  root: string,
  outputDir: string,
  cliCwd: string,
  token: vscode.CancellationToken,
  handlers?: ProjectHealthScanHandlers,
): Promise<ProjectHealthScanResult> {
  return new Promise((resolve) => {
    const streaming = handlers !== undefined;
    const controlPath = streaming ? createControlFile() : undefined;
    const args = buildProjectHealthArgs(root, outputDir, streaming, controlPath);
    const child = cp.spawn('dart', args, { cwd: cliCwd, shell: true });
    let stderr = '';
    let cancelled = false;
    // Buffers an incomplete trailing line between chunks so streamed output
    // never splits mid-word (same shape as the old inline runner).
    let stdoutBuf = '';
    let stderrBuf = '';
    const cleanupControl = (): void => {
      if (controlPath) {
        try {
          fs.unlinkSync(controlPath);
        } catch {
          // Best-effort temp cleanup; a leftover tiny file is harmless.
        }
      }
    };
    if (handlers?.onControl && controlPath) {
      handlers.onControl({
        pause: () => writeControl(controlPath, 'pause'),
        resume: () => writeControl(controlPath, 'run'),
        cancel: () => {
          cancelled = true;
          writeControl(controlPath, 'cancel');
          killProcessTree(child);
        },
      });
    }
    token.onCancellationRequested(() => {
      cancelled = true;
      if (controlPath) writeControl(controlPath, 'cancel');
      killProcessTree(child);
    });
    const flushStdout = (chunk: string): void => {
      const combined = stdoutBuf + chunk;
      const lines = combined.split('\n');
      stdoutBuf = lines.pop() ?? '';
      for (const line of lines) handlers?.onOutputLine?.(line.replace(/\r$/, ''), 'stdout');
    };
    const flushStderr = (chunk: string): void => {
      stderr += chunk;
      const combined = stderrBuf + chunk;
      const lines = combined.split('\n');
      stderrBuf = lines.pop() ?? '';
      for (const raw of lines) {
        const line = raw.replace(/\r$/, '');
        const trimmed = line.trim();
        if (trimmed.length === 0) continue;
        // Split progress events from real diagnostic stderr text — same
        // discipline as projectVibrancyCliRunner's tryParseEvent.
        const event = streaming ? tryParseHealthProgressEvent(trimmed) : undefined;
        if (event) {
          handlers?.onProgress?.(event);
        } else {
          handlers?.onOutputLine?.(line, 'stderr');
        }
      }
    };
    child.stdout.on('data', (d: Buffer) => flushStdout(d.toString()));
    child.stderr.on('data', (d: Buffer) => flushStderr(d.toString()));
    child.on('error', (err: NodeJS.ErrnoException) => {
      cleanupControl();
      resolve({
        ok: false,
        cancelled,
        exitCode: null,
        firstStderrLine: '',
        spawnErrorMessage: err.message,
      });
    });
    child.on('close', (code: number | null) => {
      cleanupControl();
      // Flush remaining partial lines. stdout goes straight through, but
      // stderr must go through `flushStderr` so a trailing progress event
      // without a final '\n' (e.g. `{"event":"done"}`) still gets parsed
      // by `tryParseHealthProgressEvent` — without this, the progress bar
      // never reaches 100%.
      if (stdoutBuf.length > 0) handlers?.onOutputLine?.(stdoutBuf, 'stdout');
      if (stderrBuf.length > 0) flushStderr('\n');
      const firstStderrLine = stderr.split('\n').find((l) => l.trim().length > 0) ?? '';
      resolve({ ok: code === 0, cancelled, exitCode: code, firstStderrLine });
    });
  });
}
