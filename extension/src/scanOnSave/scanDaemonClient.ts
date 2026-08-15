/**
 * Client for the long-lived `dart run saropa_lints:scan_daemon` process
 * (bin/scan_daemon.dart). Spawn-per-save `scan --resolve` pays a fixed
 * ~80s floor per invocation — a fresh VM must resolve the saved file's
 * transitive import graph every time. The daemon builds the analyzer's
 * AnalysisContextCollection once and keeps resolved state warm, so each
 * save after the first costs well under a second.
 *
 * Protocol (NDJSON over stdin/stdout): the daemon emits {"event":"ready"}
 * once its collection is built; each request {"id","files":[...]} gets one
 * {"id","ok":...} response line. All daemon logging goes to stderr.
 *
 * The FIRST request after spawn still pays the initial transitive
 * resolution (~1 minute on a large project) — hence the separate
 * first-request timeout and `isWarming` for the controller's status bar.
 */
import { spawn, type ChildProcess } from 'node:child_process';
import { resolveCliCwd, killProcessTree } from '../views/devCliRoot';
import { l10n } from '../i18n/runtime';
import type { ScanOnSavePayload, ScanOnSaveResult } from './scanOnSaveRunner';

// See projectVibrancyCliRunner.ts SPAWN_USE_SHELL for the CVE-2024-27980 /
// PATHEXT rationale — identical reasoning applies to every dart spawn here.
const SPAWN_USE_SHELL = process.platform === 'win32';

/** First request resolves the saved file's whole transitive import graph. */
export const FIRST_REQUEST_TIMEOUT_MS = 180_000;
/** Warm requests measured sub-second; 60s is a generous stuck-daemon bound. */
export const WARM_REQUEST_TIMEOUT_MS = 60_000;

/** Shape of one parsed NDJSON line from the daemon (all fields untrusted). */
export interface DaemonLine {
  id?: unknown;
  event?: unknown;
  ok?: unknown;
  error?: unknown;
  version?: unknown;
  diagnostics?: unknown;
  files?: unknown;
}

/** Splits accumulated stdout into complete lines plus the trailing partial. */
export function splitNdjsonBuffer(buffer: string): { lines: string[]; rest: string } {
  const parts = buffer.split('\n');
  const rest = parts.pop() ?? '';
  return { lines: parts.map((p) => p.trim()).filter((p) => p.length > 0), rest };
}

/** Maps one daemon response line onto the runner's result shape. */
export function daemonResponseToResult(response: DaemonLine): ScanOnSaveResult {
  if (response.ok === true && Array.isArray(response.diagnostics)) {
    return {
      payload: {
        version: typeof response.version === 'number' ? response.version : 1,
        diagnostics: response.diagnostics as ScanOnSavePayload['diagnostics'],
      },
      exitCode: 0,
    };
  }
  return {
    payload: null,
    exitCode: -1,
    errorMessage:
      typeof response.error === 'string' && response.error.length > 0
        ? response.error
        : l10n('notify.commands.scanOnSaveDaemonBadResponse'),
  };
}

/**
 * Maps a `listFiles` response line onto an absolute path list, or null on
 * any error/malformed shape — mirrors {@link daemonResponseToResult}'s
 * never-throw contract so a bad response can't crash the baseline-scan caller.
 */
export function daemonResponseToFileList(response: DaemonLine): string[] | null {
  if (response.ok === true && Array.isArray(response.files)) {
    return response.files.filter((f): f is string => typeof f === 'string');
  }
  return null;
}

/** One in-flight request: how to settle its promise (given the raw response line) + its watchdog timer. */
interface PendingRequest {
  settle: (line: DaemonLine) => void;
  timer: NodeJS.Timeout;
}

export class ScanDaemonClient {
  /** The spawned daemon (cmd.exe wrapper on Windows — see killProcessTree). */
  private _child: ChildProcess | undefined;
  /** Trailing partial NDJSON line carried between stdout chunks. */
  private _stdoutRest = '';
  /** Monotonic request-id source; ids correlate responses to requests. */
  private _nextRequestId = 1;
  /** Requests awaiting a response, keyed by request id. */
  private readonly _pending = new Map<string, PendingRequest>();
  /** Guards double-settling `_ready` (ready event vs. process death). */
  private _readySettled = false;
  /** Resolver captured out of the `_ready` promise executor below. */
  private _settleReady!: (ready: boolean) => void;
  /**
   * Settles true when the daemon prints {"event":"ready"}, false if it dies
   * first. A resolved boolean (never a rejection) so awaiting callers can't
   * leak unhandled rejections.
   */
  private readonly _ready = new Promise<boolean>((res) => {
    this._settleReady = res;
  });
  /** False until start(), false again once the process closes. */
  private _alive = false;
  /** Set on the first successful response — ends the "warming up" phase. */
  private _completedFirstRequest = false;
  /** Distinguishes deliberate teardown from a crash in _onClose. */
  private _disposed = false;

  constructor(
    private readonly _projectRoot: string,
    private readonly _tier: string,
    private readonly _onUnexpectedExit: () => void,
  ) {}

  get isAlive(): boolean {
    return this._alive;
  }

  /** True from spawn until the first scan response — drives the "warming up" UI. */
  get isWarming(): boolean {
    return this._alive && !this._completedFirstRequest;
  }

  start(): void {
    const child = spawn(
      'dart',
      ['run', 'saropa_lints:scan_daemon', this._projectRoot, '--tier', this._tier],
      { cwd: resolveCliCwd(this._projectRoot), shell: SPAWN_USE_SHELL },
    );
    this._child = child;
    this._alive = true;
    child.stdout?.on('data', (chunk: Buffer | string) => this._onStdout(chunk.toString()));
    // stderr carries daemon progress logs; consume so the pipe never backs up.
    child.stderr?.on('data', () => undefined);
    child.on('error', () => this._onClose(-1));
    child.on('close', (code) => this._onClose(code ?? -1));
  }

  /**
   * Sends one scan request and resolves with its response. Never rejects —
   * daemon death, timeout, and malformed responses all settle with
   * `payload: null` + `errorMessage`, matching `runScanOnSave`'s contract.
   */
  async scan(files: readonly string[]): Promise<ScanOnSaveResult> {
    const becameReady = await this._ready;
    const stdin = this._child?.stdin;
    if (!becameReady || !this._alive || !stdin?.writable) {
      return this._errorResult('notify.commands.scanOnSaveDaemonDown');
    }
    const id = String(this._nextRequestId++);
    const timeoutMs = this._completedFirstRequest
      ? WARM_REQUEST_TIMEOUT_MS
      : FIRST_REQUEST_TIMEOUT_MS;
    return new Promise<ScanOnSaveResult>((settle) => {
      const timer = setTimeout(() => {
        this._pending.delete(id);
        settle(this._errorResult('notify.commands.scanOnSaveDaemonTimeout'));
      }, timeoutMs);
      this._pending.set(id, {
        timer,
        settle: (line) => {
          const result = daemonResponseToResult(line);
          if (result.payload) this._completedFirstRequest = true;
          settle(result);
        },
      });
      stdin.write(`${JSON.stringify({ id, files: [...files] })}\n`);
    });
  }

  /**
   * Lists every Dart file the daemon's project-root walk would scan (same
   * exclusions as an unscoped `scan`), for the baseline-scan caller to chunk
   * into batches. Never rejects — null on daemon-down/timeout/malformed
   * response, matching {@link scan}'s contract. Does not affect
   * `isWarming` — only a real scan response ends the warming phase.
   */
  async listFiles(): Promise<string[] | null> {
    const becameReady = await this._ready;
    const stdin = this._child?.stdin;
    if (!becameReady || !this._alive || !stdin?.writable) return null;
    const id = String(this._nextRequestId++);
    return new Promise<string[] | null>((settle) => {
      const timer = setTimeout(() => {
        this._pending.delete(id);
        settle(null);
      }, WARM_REQUEST_TIMEOUT_MS);
      this._pending.set(id, {
        timer,
        settle: (line) => settle(daemonResponseToFileList(line)),
      });
      stdin.write(`${JSON.stringify({ id, cmd: 'listFiles' })}\n`);
    });
  }

  dispose(): void {
    this._disposed = true;
    const child = this._child;
    if (!child) return;
    try {
      child.stdin?.end(`${JSON.stringify({ id: 'dispose', cmd: 'shutdown' })}\n`);
    } catch {
      // Already dead — the tree kill below is the backstop either way.
    }
    killProcessTree(child);
  }

  private _errorResult(messageKey: string): ScanOnSaveResult {
    return { payload: null, exitCode: -1, errorMessage: l10n(messageKey) };
  }

  private _onStdout(chunk: string): void {
    const { lines, rest } = splitNdjsonBuffer(this._stdoutRest + chunk);
    this._stdoutRest = rest;
    for (const line of lines) this._onLine(line);
  }

  private _onLine(line: string): void {
    let parsed: DaemonLine;
    try {
      parsed = JSON.parse(line) as DaemonLine;
    } catch {
      return; // Non-protocol noise on stdout; ignore.
    }
    if (parsed.event === 'ready') {
      this._readySettled = true;
      this._settleReady(true);
      return;
    }
    const id = typeof parsed.id === 'string' ? parsed.id : undefined;
    const pending = id === undefined ? undefined : this._pending.get(id);
    if (id === undefined || !pending) return;
    this._pending.delete(id);
    clearTimeout(pending.timer);
    pending.settle(parsed);
  }

  private _onClose(exitCode: number): void {
    if (!this._alive) return;
    this._alive = false;
    if (!this._readySettled) {
      this._readySettled = true;
      this._settleReady(false);
    }
    // Routed through the same DaemonLine shape as a real response — each
    // pending request's settle() maps `ok: false` onto its own error result
    // (ScanOnSaveResult for scan(), null for listFiles()). The real process
    // exitCode isn't preserved past this point; only the error path cared
    // about it, and daemonResponseToResult already normalizes error exit
    // codes to -1.
    for (const pending of this._pending.values()) {
      clearTimeout(pending.timer);
      pending.settle({ ok: false, error: l10n('notify.commands.scanOnSaveDaemonExited') });
    }
    this._pending.clear();
    if (!this._disposed) this._onUnexpectedExit();
  }
}
