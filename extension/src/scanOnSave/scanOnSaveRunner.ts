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
  line: number;
  column: number;
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
    let cancelled = false;
    const cancelSubscription = cancellationToken?.onCancellationRequested(() => {
      cancelled = true;
      killProcessTree(child);
    });
    child.stdout.on('data', (chunk: Buffer | string) => {
      stdout += chunk.toString();
    });
    child.stderr.on('data', (chunk: Buffer | string) => {
      stderr += chunk.toString();
    });
    child.on('error', (err: NodeJS.ErrnoException) => {
      cancelSubscription?.dispose();
      resolvePromise({
        payload: null,
        exitCode: -1,
        errorMessage: err?.message?.trim() || l10n('notify.commands.scanOnSaveStartFailed'),
      });
    });
    child.on('close', (code) => {
      cancelSubscription?.dispose();
      const exitCode = code ?? -1;
      if (cancelled) {
        resolvePromise({ payload: null, exitCode });
        return;
      }
      // 0 = clean, 1 = issues found — both are successful runs.
      if (exitCode !== 0 && exitCode !== 1) {
        resolvePromise({
          payload: null,
          exitCode,
          errorMessage: stderr.trim() || l10n('notify.commands.scanOnSaveFailed'),
        });
        return;
      }
      const payload = parseScanOnSaveOutput(stdout);
      if (!payload) {
        resolvePromise({
          payload: null,
          exitCode,
          errorMessage: l10n('notify.commands.scanOnSaveInvalidJson'),
        });
        return;
      }
      resolvePromise({ payload, exitCode });
    });
  });
}
