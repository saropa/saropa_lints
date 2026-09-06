/**
 * Resolves the working directory for the `dart run saropa_lints:<tool>` that the
 * Code Health and Saropa Project Map dashboards spawn.
 *
 * Which directory wins decides WHICH saropa_lints CLI executes:
 *  - Production: the scanned project (so it uses that project's own pinned
 *    saropa_lints — correct, version-matched behavior).
 *  - In-development (F5 from this repo): the extension lives at
 *    `<repo>/extension`, so running from `<repo>` uses the in-development CLI —
 *    which has live progress, the symlink-safe pruned walk, and any brand-new
 *    tools (e.g. `project_health`) that the scanned project's published package
 *    does not have yet. The dashboards still pass `--path <project>`, so the
 *    local CLI scans the opened project either way.
 *
 * Detection is pure filesystem (the package's bin script + pubspec are present
 * one level up from the extension), so an installed production build — where no
 * sibling repo exists — transparently falls back to the project's own CLI.
 */
import * as cp from 'node:child_process';
import * as fs from 'node:fs';
import * as path from 'node:path';
import * as vscode from 'vscode';

let cached: string | null | undefined;

/** Repo root if the running extension is the in-development build, else undefined. */
function devRepoRoot(): string | undefined {
  if (cached !== undefined) return cached ?? undefined;
  cached = null;
  try {
    const extPath = vscode.extensions.getExtension('saropa.saropa-lints')?.extensionPath;
    if (extPath) {
      const repoRoot = path.dirname(extPath);
      const hasCli = fs.existsSync(path.join(repoRoot, 'bin', 'project_health.dart'));
      const hasPubspec = fs.existsSync(path.join(repoRoot, 'pubspec.yaml'));
      if (hasCli && hasPubspec) cached = repoRoot;
    }
  } catch {
    // Fall through to undefined (production fallback).
  }
  return cached ?? undefined;
}

/** Working directory for the scan spawn: the in-dev repo if detected, else the project. */
export function resolveCliCwd(projectRoot: string): string {
  return devRepoRoot() ?? projectRoot;
}

/**
 * Flags for the Windows tree kill, built as a pure function so the exact
 * command shape is unit-testable without spawning anything.
 *
 * `/T` is the load-bearing flag and must never be dropped: it is what makes
 * taskkill walk the process TREE. Every scan is spawned with `shell: true` on
 * Windows (for `dart.bat` resolution), so `child.pid` is the `cmd.exe`
 * wrapper and the real `dart.exe` is a GRANDCHILD. Without `/T` only the
 * shell dies and the orphaned `dart.exe` keeps its multi-GB resolved-analysis
 * heap until reboot. `/F` forces the kill, because a `dart` process that is
 * busy resolving does not respond to a polite terminate request.
 */
export function buildTaskkillArgs(procId: number): string[] {
  return ['/F', '/T', '/PID', String(procId)];
}

/**
 * Last-resort single-process kill. Wrapped because the child may already have
 * exited between the caller's decision and this call, and a throw here would
 * escape into an event handler or a `finally` block where nothing would
 * report it.
 */
function fallbackKill(child: cp.ChildProcess): void {
  try {
    child.kill();
  } catch {
    // Already exited — nothing to reap.
  }
}

/**
 * Windows tree kill via `taskkill /F /T /PID`.
 *
 * The `error` listener is not optional. `cp.spawn` reports a failed launch
 * (taskkill missing from PATH, denied by policy) ASYNCHRONOUSLY through an
 * `error` event, which the caller's try/catch cannot see. Two bugs followed
 * from leaving it unhandled: an unhandled `error` on a ChildProcess is an
 * uncaught exception that takes down the extension host, and the fallback
 * below never ran, so the `dart` child survived while cancellation reported
 * success.
 */
function killWindowsProcessTree(
  child: cp.ChildProcess,
  procId: number,
  spawnFn: typeof cp.spawn,
): void {
  try {
    const killer = spawnFn('taskkill', buildTaskkillArgs(procId), { windowsHide: true });
    killer.on('error', () => fallbackKill(child));
  } catch {
    // Synchronous spawn rejection (invalid args) — still try the plain kill.
    fallbackKill(child);
  }
}

/**
 * POSIX tree kill via a process-GROUP signal.
 *
 * A negative pid means "every process in the group whose id is [procId]".
 * A child spawned with `detached: true` is the leader of its own new group, so
 * this reaches the `dart` grandchild that `shell: true` put underneath it —
 * a plain `child.kill()` signals only the shell and silently orphans `dart`,
 * which is the same leak the Windows `/T` flag exists to prevent.
 *
 * It is safe for NON-detached children too, and that is why no caller has to
 * declare which kind it spawned: a non-detached child shares this Node
 * process's group, whose id is the host's pid and therefore never equal to the
 * child's own pid, so `-procId` names a group that does not exist, `kill`
 * throws ESRCH, and we fall through. There is no path on which this signals
 * the extension host itself.
 */
function killPosixProcessTree(child: cp.ChildProcess, procId: number): void {
  try {
    process.kill(-procId, 'SIGKILL');
  } catch {
    // No such group (non-detached child) or already gone — single-process kill.
    fallbackKill(child);
  }
}

/**
 * Kills the spawned scan process AND its descendants, on both platforms.
 *
 * Best-effort by contract: callers must never assume a `close` event follows
 * (see `createScanLifecycle` in scanOnSaveRunner.ts, whose watchdog exists
 * precisely because this can fail to take effect).
 *
 * [spawnFn] exists only as a test seam and every production caller omits it:
 * Node exposes `child_process.spawn` as a non-configurable property, so a test
 * cannot replace it on the module, and without an injection point the Windows
 * branch — the one that actually matters, since it is the platform where the
 * `dart.exe` grandchild hides behind a shell — would be unverifiable.
 */
export function killProcessTree(
  child: cp.ChildProcess,
  spawnFn: typeof cp.spawn = cp.spawn,
): void {
  const procId = child.pid;
  // No pid means the spawn itself failed (ENOENT, EPERM) and there is nothing
  // to reap. Returning early is correct rather than merely defensive: passing
  // `undefined` into either branch below would target the wrong process — a
  // `taskkill /PID undefined` or a `process.kill(NaN)` — and callers that
  // believed a kill had been issued would be told nothing went wrong.
  if (procId === undefined) return;
  if (process.platform === 'win32') {
    killWindowsProcessTree(child, procId, spawnFn);
    return;
  }
  killPosixProcessTree(child, procId);
}
