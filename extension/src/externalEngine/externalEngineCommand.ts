/**
 * vscode glue for "Scan with latest engine" (see externalEngine.ts for why).
 *
 * Flow: pick the newer `dart` -> verify its version -> (first run, after the
 * user agrees) install the engine globally -> scan the whole project -> publish
 * results into the shared `saropa_lints` Problems collection.
 */
import { execFile } from 'node:child_process';
import * as vscode from 'vscode';
import { l10n } from '../i18n/runtime';
import { getProjectRoot } from '../projectRoot';
import { parseScanOnSaveOutput, readScanTimeoutMs } from '../scanOnSave/scanOnSaveRunner';
import { groupDiagnosticsByFile, toVscodeDiagnostic } from '../scanOnSave/scanOnSaveController';
import {
  buildEngineActivateArgs,
  buildEngineScanArgs,
  ENGINE_MIN_DART,
  isDartNewEnough,
  parseDartVersion,
  resolveEngineDart,
} from './externalEngine';

/**
 * Own collection (not the scan-on-save one): a whole-project latest-engine scan
 * must not clear or be overwritten by per-save results. Created lazily and
 * disposed with the extension.
 */
let engineDiagnostics: vscode.DiagnosticCollection | undefined;

function getEngineDiagnostics(context: vscode.ExtensionContext): vscode.DiagnosticCollection {
  if (!engineDiagnostics) {
    engineDiagnostics = vscode.languages.createDiagnosticCollection('saropa_lints_latest_engine');
    context.subscriptions.push(engineDiagnostics);
  }
  return engineDiagnostics;
}

/** globalState flag: the user already agreed to install the engine globally. */
const ACTIVATED_KEY = 'saropaLints.externalEngine.activated';

interface RunResult {
  readonly code: number;
  readonly stdout: string;
  readonly stderr: string;
}

/**
 * Runs one process to completion; never rejects. A spawn failure or timeout
 * yields code -1 with the error text appended to stderr so callers can show it.
 */
function run(command: string, args: string[], shell: boolean, cwd: string, timeoutMs: number): Promise<RunResult> {
  return new Promise((resolve) => {
    execFile(
      command,
      args,
      { cwd, shell, timeout: timeoutMs, maxBuffer: 256 * 1024 * 1024, windowsHide: true },
      (err, stdout, stderr) => {
        // Node sets err.code to the numeric exit code for non-zero exits, and to a
        // string (e.g. 'ENOENT') for spawn failures.
        const rawCode = (err as { code?: unknown } | null)?.code;
        const code = !err ? 0 : typeof rawCode === 'number' ? rawCode : -1;
        resolve({ code, stdout, stderr: code === -1 && err ? `${stderr}${err.message}` : stderr });
      },
    );
  });
}

/**
 * Command body for `saropaLints.scanWithLatestEngine`. Every exit path shows a
 * visible message so the button never fails silently.
 */
export async function scanWithLatestEngine(context: vscode.ExtensionContext): Promise<void> {
  const root = getProjectRoot();
  if (!root) {
    void vscode.window.showWarningMessage(l10n('externalEngine.noProject'));
    return;
  }
  const cfg = vscode.workspace.getConfiguration('saropaLints');
  const dart = resolveEngineDart(cfg.get<string>('externalEngine.dartSdkPath'));
  const timeoutMs = readScanTimeoutMs();

  // 1. The engine needs a newer SDK than the project's pin; verify before any download.
  const ver = await run(dart.command, ['--version'], dart.useShell, root, 30_000);
  const parsed = parseDartVersion(`${ver.stdout}\n${ver.stderr}`);
  if (!parsed || !isDartNewEnough(parsed)) {
    void vscode.window.showErrorMessage(
      l10n('externalEngine.sdkTooOld', {
        found: parsed ? `${parsed[0]}.${parsed[1]}` : l10n('externalEngine.sdkUnknown'),
        required: `${ENGINE_MIN_DART[0]}.${ENGINE_MIN_DART[1]}`,
      }),
    );
    return;
  }

  // 2. First run: installing a global package touches the network and the user's pub cache.
  if (!context.globalState.get<boolean>(ACTIVATED_KEY)) {
    const yes = l10n('externalEngine.install.confirm');
    const pick = await vscode.window.showInformationMessage(l10n('externalEngine.install.prompt'), { modal: true }, yes);
    if (pick !== yes) {
      return;
    }
  }

  await vscode.window.withProgress(
    { location: vscode.ProgressLocation.Notification, title: l10n('externalEngine.progress'), cancellable: false },
    async () => {
      // Activate is idempotent and keeps the engine current on every run.
      const act = await run(dart.command, buildEngineActivateArgs(), dart.useShell, root, timeoutMs);
      if (act.code !== 0) {
        void vscode.window.showErrorMessage(
          l10n('externalEngine.installFailed', { detail: act.stderr.trim().slice(0, 300) }),
        );
        return;
      }
      await context.globalState.update(ACTIVATED_KEY, true);

      const tier = cfg.get<string>('tier', 'recommended') ?? 'recommended';
      const scan = await run(dart.command, buildEngineScanArgs(root, tier), dart.useShell, root, timeoutMs);
      const payload = parseScanOnSaveOutput(scan.stdout);
      // Exit 0 = clean, 1 = findings; anything else (or unparsable output) is a failure.
      if (!payload || (scan.code !== 0 && scan.code !== 1)) {
        void vscode.window.showErrorMessage(
          l10n('externalEngine.scanFailed', { detail: (scan.stderr || scan.stdout).trim().slice(0, 300) }),
        );
        return;
      }
      const diagnostics = getEngineDiagnostics(context);
      diagnostics.clear();
      for (const [file, list] of groupDiagnosticsByFile(payload.diagnostics)) {
        diagnostics.set(vscode.Uri.file(file), list.map(toVscodeDiagnostic));
      }
      void vscode.window.showInformationMessage(
        l10n('externalEngine.done', { count: String(payload.diagnostics.length), version: `${parsed[0]}.${parsed[1]}` }),
      );
    },
  );
}
