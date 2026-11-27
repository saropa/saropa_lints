/**
 * VS Code surface for `dart run saropa_lints:baseline --explain <file>`: which
 * baseline settings hide findings in one Dart file. Read-only; the report is
 * the CLI's own text in the shared Output channel, so the wording and matching
 * live once, in Dart.
 */
import * as fs from 'node:fs';
import * as path from 'node:path';
import * as vscode from 'vscode';
import { runInWorkspaceAsync, getSharedOutputChannel } from './setup';
import { findProjectRootIn } from './projectRoot';
import { findPackageRoot } from './acceptedFindingsModel';
import { hasSaropaLintsDep } from './pubspecReader';
import { createBusyGuard } from './commandGuards';
import { summarizeError } from './stale-ignore-commands';
import { l10n } from './i18n/runtime';

/** One report at a time per window: two `dart run` calls contend for the pub lock. */
const withBusyGuard = createBusyGuard(() => l10n('baselineExplain.info.alreadyRunning'));

/**
 * The file to explain: the one a context menu passed, else the active editor's
 * (palette and catalog pass nothing). Undefined for anything but a Dart file.
 */
export function resolveExplainTarget(
  clicked: vscode.Uri | undefined,
  active: vscode.Uri | undefined,
): string | undefined {
  const uri = clicked ?? active;
  // Untitled buffers and diff views have no file on disk for the CLI to read.
  if (!uri || uri.scheme !== 'file' || !uri.fsPath.endsWith('.dart')) return undefined;
  return uri.fsPath;
}

/**
 * The directory to launch `dart run` from, which must depend on saropa_lints:
 * the file's nearest package, else a workspace folder's package (a plugin-only
 * nested package cannot run the CLI itself).
 */
export function resolveExplainHost(file: string, folders: readonly string[]): string | undefined {
  const own = findPackageRoot(file, fs.existsSync);
  const candidates = [own, ...folders.map(findProjectRootIn)];
  return candidates.find((root): root is string => !!root && hasSaropaLintsDep(root));
}

/**
 * Characters that cmd.exe (or the `dart.bat` wrapper it runs) can still act on
 * inside double quotes: `%` (variable expansion, always on), `!` (expansion
 * when a batch file enables delayed expansion), `"` (ends the quote), `^`
 * (escape, re-read when a batch file re-parses `%*` through `call`) and any
 * control character (a line break ends the command). A path holding one is
 * never sent through the shell, so a hostile file name cannot run commands.
 */
const CMD_UNSAFE = /[%!"^\u0000-\u001f]/;

/**
 * Quotes one argument for a shell, or null when no quoting is safe.
 */
export function quoteForShell(arg: string, platform: NodeJS.Platform): string | null {
  // Plain tokens need no quoting.
  if (/^[\w:.\-]+$/.test(arg)) return arg;
  // POSIX single quotes are literal; a quote inside is closed, escaped, reopened.
  // NUL cannot be passed in any argv, so it is refused rather than truncated.
  if (platform !== 'win32') {
    return arg.includes('\u0000') ? null : `'${arg.replaceAll("'", "'\\''")}'`;
  }
  if (CMD_UNSAFE.test(arg)) return null;
  // Inside quotes `&|<>()` are literal to cmd.exe. A trailing backslash would
  // otherwise escape the closing quote for the program's argv parser.
  return `"${arg.replace(/\\+$/, '$&$&')}"`;
}

/**
 * CLI arguments, plain and shell-quoted. `--dry-run` is for saropa_lints older
 * than 17.10.0: it ignores the unknown `--explain` and would otherwise write a
 * baseline. Current versions return from `--explain` before reading it.
 */
export function buildExplainArgs(
  file: string,
  platform: NodeJS.Platform,
): { args: string[]; shellArgs: string[] | null } {
  const args = ['run', 'saropa_lints:baseline', '--dry-run', '--explain', file];
  const quoted = args.map((a) => quoteForShell(a, platform));
  return { args, shellArgs: quoted.every((a): a is string => a !== null) ? quoted : null };
}

/**
 * The error text for a failed run. On Windows a refused shell fallback leaves
 * only Node's "spawn dart ENOENT" (`dart` being a .bat that needs the shell),
 * which does not say that the file path is the cause, so that case is named.
 */
export function explainFailureMessage(
  stderr: string,
  shellArgs: string[] | null,
  platform: NodeJS.Platform,
): string {
  if (platform === 'win32' && shellArgs === null && stderr.includes('ENOENT')) {
    return l10n('baselineExplain.error.unsafePath');
  }
  return l10n('baselineExplain.error.failed', { message: summarizeError(stderr) });
}

/** Runs the report for one file. Every exit shows a message or the channel. */
async function runExplain(clicked: vscode.Uri | undefined): Promise<void> {
  const file = resolveExplainTarget(clicked, vscode.window.activeTextEditor?.document.uri);
  if (!file) {
    void vscode.window.showInformationMessage(l10n('baselineExplain.error.noFile'));
    return;
  }
  const folders = vscode.workspace.workspaceFolders?.map((f) => f.uri.fsPath) ?? [];
  const host = resolveExplainHost(file, folders);
  if (!host) {
    void vscode.window.showErrorMessage(l10n('baselineExplain.error.noProject'));
    return;
  }
  await withBusyGuard(async () => {
    const { args, shellArgs } = buildExplainArgs(file, process.platform);
    // Shown before the run so the streamed report is visible as it arrives.
    getSharedOutputChannel().show(true);
    const title = l10n('baselineExplain.progress', { file: path.basename(file) });
    const result = await vscode.window.withProgress(
      { location: vscode.ProgressLocation.Notification, title, cancellable: true },
      (_progress, token) =>
        // shell: false keeps the path literal; the quoted form is only for the
        // fallback taken when `dart` is a .bat (Flutter SDK on Windows).
        runInWorkspaceAsync(host, 'dart', args, {
          token,
          shell: false,
          shellFallbackArgs: shellArgs,
          env: { DART_SUPPRESS_ANALYTICS: 'true' },
        }),
    );
    // A cancel is the user's own action and is already logged in the channel.
    if (result.ok || result.cancelled) return;
    const text = explainFailureMessage(result.stderr, shellArgs, process.platform);
    void vscode.window.showErrorMessage(text);
  });
}

/** Registers the command; the caller disposes the returned registration. */
export function registerBaselineExplainCommand(): vscode.Disposable {
  return vscode.commands.registerCommand('saropaLints.explainBaseline', (uri?: vscode.Uri) =>
    runExplain(uri),
  );
}
