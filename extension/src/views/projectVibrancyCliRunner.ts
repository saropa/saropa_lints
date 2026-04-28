import * as vscode from 'vscode';
import { spawn } from 'node:child_process';
import type { ProjectVibrancyPayload } from './projectVibrancyTypes';

export interface ProjectVibrancyScanResult {
  readonly payload: ProjectVibrancyPayload | null;
  readonly rawStdout: string;
  readonly exitCode: number;
}

function normalizeMinGrade(value: string | undefined): string {
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

/** Options passed to `dart run bin/project_vibrancy.dart` from workspace settings (no CLI-only workflow). */
export function buildProjectVibrancyDartArgs(
  projectRoot: string,
  options: { readonly since?: string },
): string[] {
  const c = vscode.workspace.getConfiguration('saropaLints');
  const lcovRaw = c.get<string>('projectVibrancy.lcovPath');
  const lcovPath = (lcovRaw ?? '').trim().length > 0 ? lcovRaw!.trim() : 'coverage/lcov.info';
  const minGrade = normalizeMinGrade(c.get<string>('projectVibrancy.minGrade'));
  const maxUnused = readOptionalPositiveGate('projectVibrancy.maxUnused');
  const maxUncovered = readOptionalPositiveGate('projectVibrancy.maxUncovered');
  const maxStubTested = readOptionalPositiveGate('projectVibrancy.maxStubTested');
  const maxSuspiciousCoverage = readOptionalPositiveGate('projectVibrancy.maxSuspiciousCoverage');
  const maxTestDrift = readOptionalPositiveGate('projectVibrancy.maxTestDrift');

  const args = [
    'run',
    'bin/project_vibrancy.dart',
    '--path',
    projectRoot,
    '--format',
    'json',
    '--lcov',
    lcovPath,
    '--min-grade',
    minGrade,
  ];
  const since = options.since?.trim();
  if (since && since.length > 0) {
    args.push('--since', since);
  }
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

export function runProjectVibrancyScan(
  projectRoot: string,
  options: { readonly since?: string },
): Promise<ProjectVibrancyScanResult> {
  return new Promise((resolve) => {
    const args = buildProjectVibrancyDartArgs(projectRoot, options);
    const child = spawn('dart', args, { cwd: projectRoot, shell: false });
    let stdout = '';
    let stderr = '';
    child.stdout.on('data', (chunk: Buffer | string) => {
      stdout += chunk.toString();
    });
    child.stderr.on('data', (chunk: Buffer | string) => {
      stderr += chunk.toString();
    });
    child.on('error', () => {
      void vscode.window.showErrorMessage(
        'Project Vibrancy scan failed to start. Ensure Dart SDK is installed.',
      );
      resolve({ payload: null, rawStdout: '', exitCode: -1 });
    });
    child.on('close', (code) => {
      const exitCode = code ?? -1;
      const raw = stdout;
      if (exitCode !== 0 && raw.trim().length === 0) {
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
