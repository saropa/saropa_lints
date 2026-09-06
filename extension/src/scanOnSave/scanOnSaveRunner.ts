/**
 * Spawns `dart run saropa_lints:scan` for a small set of files and parses its
 * `--format json` stdout. This is the Lane 1 mechanism from
 * plans/PLAN_scan_only_diagnostics.md: findings delivered by an external,
 * short-lived process instead of the in-process analyzer plugin (which was
 * measured to cost 7.8-13.6 GB resident on large projects — see the plan for
 * the control-experiment evidence).
 *
 * Exit-code contract (bin/scan.dart): 0 = no issues, 1 = issues found (NOT a
 * failure — the payload is still valid JSON), 2 = config/tier error. This
 * differs from `runProjectVibrancyScan`, which treats any non-zero exit as a
 * failure; scan's exit 1 is the common case and must not be treated as such.
 */
import { spawn } from 'node:child_process';
import * as vscode from 'vscode';
import { resolveCliCwd, killProcessTree } from '../views/devCliRoot';
import { l10n } from '../i18n/runtime';

// See projectVibrancyCliRunner.ts SPAWN_USE_SHELL for the CVE-2024-27980 /
// PATHEXT rationale — identical reasoning applies to every dart spawn here.
const SPAWN_USE_SHELL = process.platform === 'win32';

/**
 * Default wall-clock ceiling on one `dart run saropa_lints:scan` invocation,
 * in seconds. User-overridable via `saropaLints.scanOnSave.timeoutSeconds`.
 *
 * Without a ceiling a hung child is permanent death for the feature: `close`
 * never fires, this promise never settles, the controller's `_scanInFlight`
 * flag stays true forever, and every later save is silently swallowed while
 * the orphaned `dart` process keeps its resolved-analysis memory. That is
 * exactly what the incident log shows — roughly 57 `scanning ...` starts
 * against a single `scan complete` in one 50-minute window.
 *
 * 180 s is not a round-number guess; it is the smallest value that covers the
 * slowest LEGITIMATE run this code path can produce, from three measurements
 * already recorded in this repo:
 *  - `baselineScanRunner.ts` documents a measured full pass on `contacts`
 *    (4,478 files, recommended tier) at a steady ~3 files/s.
 *  - `scanOnSaveController.ts` caps one batch at {@link MAX_QUEUED_SCAN_FILES}
 *    = 200 files, so the largest batch this runner can ever be handed costs
 *    roughly 200 / 3 = ~67 s of scanning.
 *  - `scanDaemonClient.ts` puts the cold-VM floor at ~80 s and already budgets
 *    exactly 180 s for its own first request (FIRST_REQUEST_TIMEOUT_MS).
 * ~67 s of work plus a cold `dart run` snapshot compile on a loaded machine
 * lands inside 180 s with headroom, and matching the daemon's first-request
 * budget means both scan lanes give up on the same schedule instead of one
 * silently outliving the other.
 */
export const SCAN_TIMEOUT_DEFAULT_SECONDS = 180;

/**
 * Floor for the user-configurable timeout.
 *
 * Below this the watchdog starts killing HEALTHY runs: the warm case is only
 * 2-4 s, but a cold `dart run` that must compile the CLI snapshot routinely
 * costs tens of seconds, and a killed first run looks identical to a broken
 * feature. 30 s is under the ~80 s cold floor on purpose — it is the point
 * past which a smaller number can only be a mistake, not a preference.
 */
export const SCAN_TIMEOUT_MIN_SECONDS = 30;

/**
 * Ceiling for the user-configurable timeout.
 *
 * 30 minutes exceeds the measured ~25-minute WHOLE-PROJECT pass, so any larger
 * value cannot describe a real single-batch scan and can only mean "never time
 * out" — which reinstates the permanent-death hang this watchdog exists to
 * prevent. Clamping rather than honoring it keeps the guarantee that every
 * scan settles.
 */
export const SCAN_TIMEOUT_MAX_SECONDS = 1800;

/** The default expressed in milliseconds, for the exported arm/lifecycle helpers. */
const SCAN_TIMEOUT_MS = SCAN_TIMEOUT_DEFAULT_SECONDS * 1000;

/**
 * Turns a configured `timeoutSeconds` into a milliseconds value that is always
 * usable.
 *
 * Every rejected input falls back rather than throwing, because this runs
 * inside a save handler: a hand-edited `settings.json` with a string, a
 * negative number, or `NaN` must degrade to the default, not disable
 * scan-on-save. Out-of-range numbers are CLAMPED rather than rejected so a
 * user who asks for "10 seconds" still gets the shortest defensible timeout
 * instead of being silently overridden back to three minutes.
 *
 * Pure and exported so the clamp is unit-testable without a live workspace.
 */
export function resolveScanTimeoutMs(configuredSeconds: unknown): number {
  if (typeof configuredSeconds !== 'number' || !Number.isFinite(configuredSeconds)) {
    return SCAN_TIMEOUT_MS;
  }
  const clamped = Math.min(
    SCAN_TIMEOUT_MAX_SECONDS,
    Math.max(SCAN_TIMEOUT_MIN_SECONDS, configuredSeconds),
  );
  return Math.round(clamped * 1000);
}

/**
 * Reads the effective timeout from settings at spawn time (not at module load)
 * so a user who raises it after hitting a timeout does not have to reload the
 * window for the new value to take effect.
 */
export function readScanTimeoutMs(): number {
  const cfg = vscode.workspace.getConfiguration('saropaLints');
  return resolveScanTimeoutMs(cfg.get<number>('scanOnSave.timeoutSeconds'));
}

/**
 * Builds argv for `dart run saropa_lints:scan`. The project root MUST be the
 * first positional element — `parseScanArgs` (scan_cli_args.dart) takes the
 * *first* non-flag token as `path`, and `--tier`'s value is itself a
 * non-flag token that would otherwise be picked up if it preceded the root.
 */
export function buildScanOnSaveArgs(
  projectRoot: string,
  filePaths: readonly string[],
  tier: string,
  resolve: boolean,
): string[] {
  const args = [projectRoot, '--tier', tier, '--files', ...filePaths];
  if (resolve) args.push('--resolve');
  args.push('--format', 'json');
  return args;
}

export interface ScanOnSaveDiagnostic {
  filePath: string;
  /** 1-based start line. */
  line: number;
  /** 1-based start column. */
  column: number;
  /** 1-based end line (may be absent in older scan output). */
  endLine?: number;
  /** 1-based end column, exclusive (may be absent in older scan output). */
  endColumn?: number;
  ruleName: string;
  severity: string;
  problemMessage?: string | null;
  correctionMessage?: string | null;
}

export interface ScanOnSavePayload {
  version: number;
  diagnostics: ScanOnSaveDiagnostic[];
}

export interface ScanOnSaveResult {
  readonly payload: ScanOnSavePayload | null;
  readonly exitCode: number;
  readonly errorMessage?: string;
}

/** Parses scan's `--format json` stdout. Returns null (not throws) on malformed JSON. */
export function parseScanOnSaveOutput(raw: string): ScanOnSavePayload | null {
  const trimmed = raw.trim();
  if (trimmed.length === 0) return null;
  try {
    const parsed = JSON.parse(trimmed) as Partial<ScanOnSavePayload>;
    if (!Array.isArray(parsed.diagnostics)) return null;
    return { version: parsed.version ?? 1, diagnostics: parsed.diagnostics };
  } catch {
    return null;
  }
}

/**
 * The result a timed-out scan resolves with. Exit code -1 matches the spawn-
 * error path: there is no real process exit code to report. Reuses the
 * existing "did not respond in time" string rather than introducing a new
 * catalog key, so no locale regeneration is needed for this fix.
 */
export function buildScanTimeoutResult(): ScanOnSaveResult {
  return {
    payload: null,
    exitCode: -1,
    errorMessage: l10n('notify.commands.scanOnSaveDaemonTimeout'),
  };
}

/**
 * Starts the watchdog timer and returns a disposer that must be called on
 * EVERY exit path (`close`, `error`, cancellation).
 *
 * Extracted and exported so the arm/disarm contract is unit-testable without
 * waiting {@link SCAN_TIMEOUT_MS} or spawning a real `dart` process. The timer
 * is `unref`ed because a pending watchdog must never be a reason for the
 * host's event loop to stay alive; `unref` is absent in some non-Node timer
 * shims, hence the optional call.
 */
export function armScanTimeout(
  onTimeout: () => void,
  timeoutMs: number = SCAN_TIMEOUT_MS,
): () => void {
  const timer = setTimeout(onTimeout, timeoutMs);
  timer.unref?.();
  return () => clearTimeout(timer);
}

/**
 * Per-run settlement bookkeeping: settles the promise exactly once, and tears
 * the watchdog down only when that happens.
 */
export interface ScanLifecycle {
  /** Settles the run. The first call wins; every later call is a no-op. */
  readonly settle: (result: ScanOnSaveResult) => void;
  /** Cancellation requested: kills the child but deliberately leaves the watchdog armed. */
  readonly requestCancel: () => void;
  /** True once cancellation was requested, so `close` can report a cancelled run. */
  readonly wasCancelled: () => boolean;
  /** Cancellation-token subscription, disposed at settlement. Assigned by the caller. */
  subscription?: { dispose(): void };
}

/**
 * Builds the settle-once lifecycle for a single scan run.
 *
 * ORDERING REQUIREMENT (do not "simplify" this back): a cancellation must kill
 * the child WITHOUT disarming the watchdog. `killProcessTree` is best-effort —
 * on Windows it is a fire-and-forget `taskkill` that no-ops entirely when
 * `child.pid` is undefined. If the kill does not take effect, the child's
 * `close` event never fires; an earlier revision disarmed the timer on
 * cancellation, so the promise then never settled, the controller's `finally`
 * never ran, `_scanInFlight` stayed true, and scan-on-save was dead for the
 * rest of the session. That is precisely the hang the watchdog was added to
 * prevent, and `_supersedeStaleScan` makes cancellation routine rather than
 * rare. The timer is therefore disarmed in exactly one place — {@link
 * ScanLifecycle.settle} — which is also the only place the promise resolves,
 * so no path can leave the timer armed after settlement or settle twice.
 *
 * Exported so this contract is unit-testable without spawning a real `dart`
 * process or waiting {@link SCAN_TIMEOUT_MS}.
 */
export function createScanLifecycle(
  settleWith: (result: ScanOnSaveResult) => void,
  killChild: () => void,
  timeoutMs: number = SCAN_TIMEOUT_MS,
): ScanLifecycle {
  let settled = false;
  let cancelled = false;
  const lifecycle: ScanLifecycle = {
    settle: (result: ScanOnSaveResult): void => {
      // Exactly-once guard: a `close` arriving after the watchdog already gave
      // up must not re-run the teardown below (double-dispose) nor resolve again.
      if (settled) return;
      settled = true;
      disarm();
      lifecycle.subscription?.dispose();
      settleWith(result);
    },
    requestCancel: (): void => {
      cancelled = true;
      // Kill only — see the ordering requirement above. Disarming here is the bug.
      killChild();
    },
    wasCancelled: (): boolean => cancelled,
  };
  const disarm = armScanTimeout(() => {
    // The child never closed: it hung, or a cancellation kill silently failed.
    // Kill again (harmless if it is already gone) and settle so the caller's
    // in-flight state is released either way.
    killChild();
    lifecycle.settle(buildScanTimeoutResult());
  }, timeoutMs);
  return lifecycle;
}

/**
 * Runs one scan pass over [filePaths] and resolves with the parsed payload.
 * Never rejects — callers get `payload: null` plus `errorMessage` on any
 * failure (spawn error, non-{0,1} exit, unparsable stdout) so a single bad
 * save never crashes the save-triggered controller's queue loop.
 */
export function runScanOnSave(
  projectRoot: string,
  filePaths: readonly string[],
  tier: string,
  resolve: boolean,
  cancellationToken?: vscode.CancellationToken,
): Promise<ScanOnSaveResult> {
  return new Promise((resolvePromise) => {
    if (filePaths.length === 0) {
      resolvePromise({ payload: { version: 1, diagnostics: [] }, exitCode: 0 });
      return;
    }
    const args = buildScanOnSaveArgs(projectRoot, filePaths, tier, resolve);
    const cliCwd = resolveCliCwd(projectRoot);
    const child = spawn('dart', ['run', 'saropa_lints:scan', ...args], {
      cwd: cliCwd,
      shell: SPAWN_USE_SHELL,
    });
    let stdout = '';
    let stderr = '';
    // Watchdog + settle-once bookkeeping. A `dart` child that never exits would
    // otherwise leave this promise pending forever and permanently wedge the
    // caller's queue. The whole process tree is killed (the shell wrapper on
    // Windows spawns dart as a grandchild, so killing `child` alone would
    // orphan it); see createScanLifecycle for why cancellation must NOT disarm.
    // Timeout read per run, so a settings change applies to the next save.
    const lifecycle = createScanLifecycle(
      resolvePromise,
      () => killProcessTree(child),
      readScanTimeoutMs(),
    );
    // Assigned after construction so the lifecycle can dispose it at settlement.
    // A token that is already cancelled fires this listener synchronously, which
    // only kills the child — nothing here depends on the assignment having run.
    lifecycle.subscription = cancellationToken?.onCancellationRequested(() => {
      lifecycle.requestCancel();
    });
    child.stdout.on('data', (chunk: Buffer | string) => {
      stdout += chunk.toString();
    });
    child.stderr.on('data', (chunk: Buffer | string) => {
      stderr += chunk.toString();
    });
    child.on('error', (err: NodeJS.ErrnoException) => {
      // Spawn failed outright (no dart on PATH, etc.). Settling here is what
      // disarms the watchdog — it must not fire against a process that never
      // started, but only because the run is genuinely over, not because a
      // kill was merely requested.
      lifecycle.settle({
        payload: null,
        exitCode: -1,
        errorMessage: err?.message?.trim() || l10n('notify.commands.scanOnSaveStartFailed'),
      });
    });
    child.on('close', (code) => {
      // Normal exit path. Every branch below settles through the lifecycle, so
      // the watchdog is disarmed exactly once and only on real settlement.
      const exitCode = code ?? -1;
      if (lifecycle.wasCancelled()) {
        lifecycle.settle({ payload: null, exitCode });
        return;
      }
      // 0 = clean, 1 = issues found — both are successful runs.
      if (exitCode !== 0 && exitCode !== 1) {
        lifecycle.settle({
          payload: null,
          exitCode,
          errorMessage: stderr.trim() || l10n('notify.commands.scanOnSaveFailed'),
        });
        return;
      }
      const payload = parseScanOnSaveOutput(stdout);
      if (!payload) {
        lifecycle.settle({
          payload: null,
          exitCode,
          errorMessage: l10n('notify.commands.scanOnSaveInvalidJson'),
        });
        return;
      }
      lifecycle.settle({ payload, exitCode });
    });
  });
}
