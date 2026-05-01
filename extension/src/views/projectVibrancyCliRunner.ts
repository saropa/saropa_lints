import * as vscode from 'vscode';
import { spawn } from 'node:child_process';
import type { ProjectVibrancyPayload } from './projectVibrancyTypes';

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

export function runProjectVibrancyScan(projectRoot: string): Promise<ProjectVibrancyScanResult> {
  return new Promise((resolve) => {
    const args = buildProjectVibrancyDartArgs(projectRoot);
    const command = dartCommandForPlatform();
    // shell:true on Windows is required for .bat/.cmd resolution; see
    // SPAWN_USE_SHELL comment above for the CVE-2024-27980 reason.
    const child = spawn(command, args, { cwd: projectRoot, shell: SPAWN_USE_SHELL });
    let stdout = '';
    let stderr = '';
    child.stdout.on('data', (chunk: Buffer | string) => {
      stdout += chunk.toString();
    });
    child.stderr.on('data', (chunk: Buffer | string) => {
      stderr += chunk.toString();
    });
    child.on('error', (err: NodeJS.ErrnoException) => {
      // Startup failures happen before exit/close when the runtime is missing
      // or non-executable in PATH.
      const details = err?.message?.trim();
      void vscode.window.showErrorMessage(
        details && details.length > 0
          ? `Project Vibrancy scan failed to start (${command}): ${details}`
          : 'Project Vibrancy scan failed to start. Ensure Dart SDK is installed.',
      );
      resolve({ payload: null, rawStdout: '', exitCode: -1 });
    });
    child.on('close', (code) => {
      const exitCode = code ?? -1;
      const raw = stdout;
      if (exitCode !== 0 && raw.trim().length === 0) {
        // Prefer stderr details when available; otherwise keep a generic
        // user-facing message for non-diagnostic failures.
        const details = stderr.trim();
        void vscode.window.showErrorMessage(
          details.length === 0
            ? 'Project Vibrancy scan failed.'
            : `Project Vibrancy scan failed: ${details}`,
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
            'Project Vibrancy: configured quality gates failed. Open Project Vibrancy settings or copy JSON to inspect gates.violations.',
          );
        }
        resolve({ payload, rawStdout: raw, exitCode });
      } catch {
        void vscode.window.showErrorMessage('Project Vibrancy returned invalid JSON output.');
        resolve({ payload: null, rawStdout: raw, exitCode });
      }
    });
  });
}
