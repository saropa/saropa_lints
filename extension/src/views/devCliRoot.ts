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
 * Kills the spawned scan process AND its descendants. On Windows the scans run
 * through the shell (shell:true, for dart.bat resolution), so `child` is the
 * `cmd.exe` wrapper — `child.kill()` reaps the shell but orphans the real
 * `dart.exe` grandchild, which keeps pegging the machine (the "cancel does
 * nothing / locked up" bug). `taskkill /T` kills the whole tree.
 */
export function killProcessTree(child: cp.ChildProcess): void {
  const procId = child.pid;
  if (procId === undefined) return;
  if (process.platform === 'win32') {
    try {
      cp.spawn('taskkill', ['/F', '/T', '/PID', String(procId)], { windowsHide: true });
      return;
    } catch {
      // Fall through to child.kill() if taskkill is unavailable.
    }
  }
  try {
    child.kill();
  } catch {
    // Best-effort: child may have already exited.
  }
}
