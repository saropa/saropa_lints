/**
 * Module overview (comment coverage pass).
 * comment-coverage: module overview (batch).
 *
 * VS Code views: trees, dashboards, or webview HTML builders.
 */

import * as vscode from 'vscode';
import { spawn } from 'node:child_process';
import * as fs from 'node:fs';
import * as os from 'node:os';
import * as path from 'node:path';
import type {
  ProjectVibrancyPayload,
  VibrancyScanControl,
  VibrancyScanEvent,
  VibrancyScanHandlers,
} from './projectVibrancyTypes';

export interface ProjectVibrancyScanResult {
  readonly payload: ProjectVibrancyPayload | null;
  readonly rawStdout: string;
  readonly exitCode: number;
}

// Routing through the OS shell on Windows lets PATHEXT resolve `dart.bat`
// the way a user terminal does, AND satisfies Node's CVE-2024-27980
// mitigation (Node 18.20+/20.12+/22+ refuses to spawn .bat/.cmd unless
// shell:true). Args here come from buildProjectVibrancyDartArgs (controlled
// flag values + projectRoot) — no untrusted user shell text — so cmd-quoting
// remains safe.
const SPAWN_USE_SHELL = process.platform === 'win32';

function dartCommandForPlatform(): string {
  // With shell:true on Windows, plain "dart" works because the shell consults
  // PATHEXT; on POSIX it's just the binary name.
  return 'dart';
}

function normalizeMinGrade(value: string | undefined): string {
  // Keep gate input bounded to known report grades so invalid settings fail
  // closed (strictest default) rather than silently widening acceptance.
  const u = (value ?? 'F').toUpperCase().trim();
  return /^[A-F]$/.test(u) ? u : 'F';
}

function readOptionalPositiveGate(key: string): number {
  const c = vscode.workspace.getConfiguration('saropaLints');
  const n = c.get<number>(key, 0);
  if (typeof n !== 'number' || Number.isNaN(n) || n < 0) {
    return 0;
  }
  return Math.floor(n);
}

/** Builds argv for `dart run saropa_lints:project_vibrancy` from workspace settings (extension host only). */
export function buildProjectVibrancyDartArgs(projectRoot: string): string[] {
  const c = vscode.workspace.getConfiguration('saropaLints');
  const lcovRaw = c.get<string>('projectVibrancy.lcovPath');
  const lcovPath = (lcovRaw ?? '').trim().length > 0 ? lcovRaw!.trim() : 'coverage/lcov.info';
  const minGrade = normalizeMinGrade(c.get<string>('projectVibrancy.minGrade'));
  const maxUnused = readOptionalPositiveGate('projectVibrancy.maxUnused');
  const maxUncovered = readOptionalPositiveGate('projectVibrancy.maxUncovered');
  const maxStubTested = readOptionalPositiveGate('projectVibrancy.maxStubTested');
  const maxSuspiciousCoverage = readOptionalPositiveGate('projectVibrancy.maxSuspiciousCoverage');
  const maxTestDrift = readOptionalPositiveGate('projectVibrancy.maxTestDrift');

  // Invoke via the registered package executable (`saropa_lints:project_vibrancy`)
  // rather than the source path `bin/project_vibrancy.dart`. The source path only
  // resolves when cwd happens to be the saropa_lints repo, so the previous form
  // failed in every consumer workspace ("Could not find file bin/...").
  // Requires `project_vibrancy: project_vibrancy` to be listed under
  // `executables:` in pubspec.yaml — without that registration, this call also
  // fails. See pubspec.yaml.
  const args = [
    'run',
    'saropa_lints:project_vibrancy',
    '--path',
    projectRoot,
    '--format',
    'json',
    '--lcov',
    lcovPath,
    '--min-grade',
    minGrade,
  ];
  if (maxUnused > 0) {
    args.push('--max-unused', String(maxUnused));
  }
  if (maxUncovered > 0) {
    args.push('--max-uncovered', String(maxUncovered));
  }
  if (maxStubTested > 0) {
    args.push('--max-stub-tested', String(maxStubTested));
  }
  if (maxSuspiciousCoverage > 0) {
    args.push('--max-suspicious-coverage', String(maxSuspiciousCoverage));
  }
  if (maxTestDrift > 0) {
    args.push('--max-test-drift', String(maxTestDrift));
  }
  return args;
}

/**
 * Allocates a unique control file under the OS temp dir, seeded with `run`. The
 * dashboard rewrites it with `pause`/`run`/`cancel`; the dart scan polls it at
 * each unit of work. Temp (not the project tree) so a scan never dirties the
 * user's workspace or git status.
 */
function createControlFile(): string {
  const controlPath = path.join(
    os.tmpdir(),
    `saropa-health-control-${process.pid}-${Date.now()}.txt`,
  );
  try {
    fs.writeFileSync(controlPath, 'run');
  } catch {
    // Best-effort: if temp is not writable the scan still runs, just without
    // pause/cancel-via-file (token cancellation still kills the child).
  }
  return controlPath;
}

function writeControl(controlPath: string, command: string): void {
  try {
    fs.writeFileSync(controlPath, command);
  } catch {
    // Best-effort: a failed control write leaves the scan running; the user can
    // still cancel via the notification token (which kills the child).
  }
}

/**
 * Kills the scan process AND its descendants. On Windows we spawn through the
 * shell (shell:true, required for dart.bat resolution), so `child` is the
 * `cmd.exe` wrapper — `child.kill()` reaps the shell but orphans the real
 * `dart.exe` grandchild, which keeps pegging the machine (the "cancel does
 * nothing / page locked up" bug). `taskkill /T` kills the whole tree. On POSIX
 * a plain kill of the (non-shell) child suffices.
 */
function killProcessTree(child: ReturnType<typeof spawn>): void {
  const pid = child.pid;
  if (pid === undefined) return;
  if (process.platform === 'win32') {
    try {
      spawn('taskkill', ['/F', '/T', '/PID', String(pid)], { windowsHide: true });
      return;
    } catch {
      // Fall through to child.kill() if taskkill is somehow unavailable.
    }
  }
  try {
    child.kill();
  } catch {
    // Best-effort: child may have already exited.
  }
}

/**
 * Working directory for the `dart run` that resolves which saropa_lints CLI
 * executes. Normally the scanned project (so it uses that project's own
 * saropa_lints version, the correct production behavior). BUT when the extension
 * itself is the in-development build (F5 from the repo), the package source sits
 * at `<extensionPath>/..`; running from there uses the in-development CLI —
 * which has live progress and the symlink-safe walk — to scan the project via
 * `--path`, instead of whatever older version the project happens to pin. Pure
 * filesystem detection (bin script present), so an installed production
 * extension transparently falls back to the project's CLI.
 */
function resolveCliCwd(projectRoot: string): string {
  try {
    const extPath = vscode.extensions.getExtension('saropa.saropa-lints')?.extensionPath;
    if (extPath) {
      const repoRoot = path.dirname(extPath);
      const hasCli = fs.existsSync(path.join(repoRoot, 'bin', 'project_vibrancy.dart'));
      const hasPubspec = fs.existsSync(path.join(repoRoot, 'pubspec.yaml'));
      if (hasCli && hasPubspec) return repoRoot;
    }
  } catch {
    // Fall through to the project root on any detection error.
  }
  return projectRoot;
}

export function runProjectVibrancyScan(
  projectRoot: string,
  cancellationToken?: vscode.CancellationToken,
  handlers?: VibrancyScanHandlers,
): Promise<ProjectVibrancyScanResult> {
  return new Promise((resolve) => {
    const args = buildProjectVibrancyDartArgs(projectRoot);
    // Streaming mode: opt in to NDJSON progress on stderr + a control file the
    // dashboard rewrites for pause/cancel. Absent handlers, the invocation is
    // identical to the original buffered scan (CI, tests).
    const streaming = handlers !== undefined;
    const controlPath = streaming ? createControlFile() : undefined;
    if (streaming) {
      args.push('--progress');
      if (controlPath) args.push('--control', controlPath);
    }
    const command = dartCommandForPlatform();
    // cwd decides which saropa_lints CLI runs (see resolveCliCwd): the project's
    // own version in production, or the in-development repo CLI under F5.
    const cliCwd = resolveCliCwd(projectRoot);
    // shell:true on Windows is required for .bat/.cmd resolution; see
    // SPAWN_USE_SHELL comment above for the CVE-2024-27980 reason.
    const child = spawn(command, args, { cwd: cliCwd, shell: SPAWN_USE_SHELL });
    let stdout = '';
    let stderr = '';
    let stderrLine = ''; // carries an incomplete trailing NDJSON line between chunks
    let cancelled = false;
    const cleanupControl = (): void => {
      if (controlPath) {
        try {
          fs.unlinkSync(controlPath);
        } catch {
          // Best-effort temp cleanup; a leftover tiny file is harmless.
        }
      }
    };
    // Wire user cancellation to a real process kill — without this the dart
    // run keeps consuming CPU even after the progress notification is dismissed,
    // which is exactly the "non-stop scanning" pile-up symptom we're guarding
    // against.
    const cancelSubscription = cancellationToken?.onCancellationRequested(() => {
      cancelled = true;
      if (controlPath) writeControl(controlPath, 'cancel');
      killProcessTree(child);
    });
    // Hand pause/resume/cancel controls back to the caller (the dashboard wires
    // them to its buttons). Pause/resume are cooperative via the control file;
    // cancel both signals the file and kills the child so it stops promptly.
    if (handlers?.onControl && controlPath) {
      const control: VibrancyScanControl = {
        pause: () => writeControl(controlPath, 'pause'),
        resume: () => writeControl(controlPath, 'run'),
        cancel: () => {
          cancelled = true;
          writeControl(controlPath, 'cancel');
          killProcessTree(child);
        },
      };
      handlers.onControl(control);
    }
    child.stdout.on('data', (chunk: Buffer | string) => {
      stdout += chunk.toString();
    });
    child.stderr.on('data', (chunk: Buffer | string) => {
      if (!streaming) {
        stderr += chunk.toString();
        return;
      }
      // Split NDJSON events from real error text. Each complete line that parses
      // to an object with `.event` is a progress event; everything else is kept
      // as diagnostic stderr for the failure path.
      stderrLine += chunk.toString();
      const lines = stderrLine.split('\n');
      stderrLine = lines.pop() ?? '';
      for (const line of lines) {
        const trimmed = line.trim();
        if (trimmed.length === 0) continue;
        const event = tryParseEvent(trimmed);
        if (event) {
          handlers?.onEvent?.(event);
        } else {
          stderr += `${trimmed}\n`;
        }
      }
    });
    child.on('error', (err: NodeJS.ErrnoException) => {
      cancelSubscription?.dispose();
      cleanupControl();
      // Startup failures happen before exit/close when the runtime is missing
      // or non-executable in PATH.
      const details = err?.message?.trim();
      // User-facing wording matches the "Code Health Dashboard" panel name.
      // The CLI tool stays `saropa_lints:project_vibrancy` (pubspec executable
      // name) and the setting keys stay `saropaLints.projectVibrancy.*` so
      // existing user settings.json entries keep working — neither is shown
      // to the user.
      void vscode.window.showErrorMessage(
        details && details.length > 0
          ? `Code Health scan failed to start (${command}): ${details}`
          : 'Code Health scan failed to start. Ensure Dart SDK is installed.',
      );
      resolve({ payload: null, rawStdout: '', exitCode: -1 });
    });
    child.on('close', (code) => {
      cancelSubscription?.dispose();
      cleanupControl();
      const exitCode = code ?? -1;
      const raw = stdout;
      // Suppress error toasts when we killed the child ourselves — the user
      // already chose to cancel, surfacing "scan failed" on top would be noise.
      if (cancelled) {
        resolve({ payload: null, rawStdout: raw, exitCode });
        return;
      }
      if (exitCode !== 0 && raw.trim().length === 0) {
        // Prefer stderr details when available; otherwise keep a generic
        // user-facing message for non-diagnostic failures.
        const details = stderr.trim();
        void vscode.window.showErrorMessage(
          details.length === 0
            ? 'Code Health scan failed.'
            : `Code Health scan failed: ${details}`,
        );
        resolve({ payload: null, rawStdout: raw, exitCode });
        return;
      }
      try {
        const payload = JSON.parse(raw) as ProjectVibrancyPayload;
        if (payload.gates?.pass === false) {
          // Gate failures still return a valid payload; warn instead of error
          // so users can inspect violations without re-running.
          void vscode.window.showWarningMessage(
            'Code Health: configured quality gates failed. Open Code Health settings or copy JSON to inspect gates.violations.',
          );
        }
        resolve({ payload, rawStdout: raw, exitCode });
      } catch {
        void vscode.window.showErrorMessage('Code Health returned invalid JSON output.');
        resolve({ payload: null, rawStdout: raw, exitCode });
      }
    });
  });
}

/** Parses one NDJSON stderr line into a scan event, or null if it isn't one. */
function tryParseEvent(line: string): VibrancyScanEvent | undefined {
  if (!line.startsWith('{')) return undefined;
  try {
    const parsed = JSON.parse(line) as { event?: unknown };
    if (typeof parsed.event === 'string') return parsed as VibrancyScanEvent;
  } catch {
    // Not an event line (e.g. a dart stack trace). Caller keeps it as stderr.
  }
  return undefined;
}
