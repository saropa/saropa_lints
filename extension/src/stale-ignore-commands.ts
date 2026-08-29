/**
 * VS Code commands for detecting and fixing stale `// ignore:` comments.
 *
 * Wraps `dart run saropa_lints:scan --find-stale-ignores` (detection) and
 * `--fix-stale-ignores` (auto-removal) behind command palette entries and
 * sidebar actions, publishing results as Problems-panel diagnostics so stale
 * ignores appear as squiggly lines on the offending comment lines. A
 * CodeActionProvider offers a per-file quick fix on each diagnostic, scoped
 * via the CLI's `--files` flag so the removal logic stays in one place (the
 * Dart fixer) instead of being re-implemented in TypeScript.
 */
import * as crypto from 'node:crypto';
import * as path from 'node:path';
import * as vscode from 'vscode';
import { runInWorkspaceAsync, getSharedOutputChannel } from './setup';
import { getProjectRoot } from './projectRoot';
import { hasSaropaLintsDep } from './pubspecReader';
import { l10n } from './i18n/runtime';

// ── Types matching the scan CLI's `--find-stale-ignores --format json` output ─

/** A single stale ignore entry from the scan CLI JSON output. */
interface StaleIgnoreEntry {
  filePath: string;
  commentLine: number;
  targetLine: number;
  ruleName: string;
  commentText: string;
}

/** Top-level JSON envelope from `--find-stale-ignores --format json`. */
interface StaleIgnoreResult {
  version: number;
  staleIgnores: StaleIgnoreEntry[];
  summary: {
    totalCount: number;
    byFile: Record<string, number>;
    byRule: Record<string, number>;
  };
}

/** Diagnostic source string — also the CodeActionProvider's filter key. */
const DIAGNOSTIC_SOURCE = 'Saropa Lints';

// Shared diagnostic collection so results persist until the next run or
// the extension deactivates. One collection for both find and fix — a fix
// run clears any prior find diagnostics as part of its success path.
let _diagnosticCollection: vscode.DiagnosticCollection | undefined;

/** Returns (or lazily creates) the shared diagnostic collection. */
function getDiagnosticCollection(): vscode.DiagnosticCollection {
  if (!_diagnosticCollection) {
    _diagnosticCollection = vscode.languages.createDiagnosticCollection('saropaStaleIgnores');
  }
  return _diagnosticCollection;
}

/**
 * Registers the stale-ignore commands and code action provider, and returns
 * the diagnostic collection so the caller can add it to
 * `context.subscriptions` for cleanup.
 */
export function registerStaleIgnoreCommands(
  context: vscode.ExtensionContext,
): vscode.DiagnosticCollection {
  const diags = getDiagnosticCollection();

  // Find stale ignores — detect and publish diagnostics for the whole project.
  context.subscriptions.push(
    vscode.commands.registerCommand('saropaLints.findStaleIgnores', () =>
      runFindStaleIgnores(),
    ),
  );

  // Fix stale ignores — confirm, auto-remove across the whole project.
  context.subscriptions.push(
    vscode.commands.registerCommand('saropaLints.fixStaleIgnores', () =>
      runFixStaleIgnores(),
    ),
  );

  // Fix stale ignores in a single file — no confirmation dialog, since this
  // is invoked from a lightbulb quick fix on one diagnostic rather than a
  // bulk sidebar/palette action. Lower blast radius (one file, already
  // visible to the user in the editor) justifies skipping the modal.
  context.subscriptions.push(
    vscode.commands.registerCommand(
      'saropaLints.fixStaleIgnoresInFile',
      (uri: vscode.Uri) => runFixStaleIgnoresInFile(uri),
    ),
  );

  // Quick fix: offers "Fix stale ignores in this file" on each stale-ignore
  // diagnostic. Scoped to Dart files only, matching where these diagnostics
  // can appear.
  context.subscriptions.push(
    vscode.languages.registerCodeActionsProvider(
      { language: 'dart' },
      new StaleIgnoreCodeActionProvider(),
      { providedCodeActionKinds: [vscode.CodeActionKind.QuickFix] },
    ),
  );

  return diags;
}

// ── Find stale ignores (whole project) ──────────────────────────────────────

/**
 * Runs the scan CLI with `--find-stale-ignores --format json`, parses the
 * output, and publishes diagnostics on the stale ignore comment lines.
 * Wrapped in a progress notification so the user sees activity during the
 * (potentially long) scan.
 */
async function runFindStaleIgnores(): Promise<void> {
  const root = getWorkspaceRootOrError();
  if (!root) return;
  if (!ensureSaropaDependency(root)) return;

  const jsonPath = path.join(root, 'reports', '.saropa_lints', 'stale_ignores.json');
  const scan = await runFindScan(root, jsonPath, l10n('staleIgnores.progress.finding'));
  if (scan === null) return; // Cancelled or a genuine error already reported.

  publishDiagnostics(scan.staleIgnores);

  const count = scan.summary.totalCount;
  const fileCount = Object.keys(scan.summary.byFile).length;
  if (count === 0) {
    void vscode.window.showInformationMessage(
      l10n('staleIgnores.info.noneFound'),
    );
  } else {
    void vscode.window.showWarningMessage(
      l10n('staleIgnores.info.found', {
        count: String(count),
        fileCount: String(fileCount),
      }),
    );
  }
}

/**
 * Shared find-and-parse logic used by both the whole-project find command
 * and the per-file diagnostic refresh after a scoped fix. Runs the CLI,
 * checks exit-code semantics, reads and parses the JSON output file.
 *
 * Returns `null` when cancelled or on a genuine failure (both cases already
 * show the appropriate message to the user before returning). Optionally
 * scoped to a single file via [filePath] — when set, only that file's ignore
 * comments are checked against diagnostics from the same scoped scan.
 */
async function runFindScan(
  root: string,
  jsonPath: string,
  progressTitle: string,
  filePath?: string,
): Promise<StaleIgnoreResult | null> {
  const result = await vscode.window.withProgress(
    {
      location: vscode.ProgressLocation.Notification,
      title: progressTitle,
      cancellable: true,
    },
    async (_progress, token) => {
      const args = [
        'run',
        'saropa_lints:scan',
        root,
        ...(filePath ? ['--files', filePath] : []),
        '--find-stale-ignores',
        '--format',
        'json',
        '--json-file-path',
        jsonPath,
        '-q', // Suppress text output; JSON goes to the file.
      ];
      return runInWorkspaceAsync(root, 'dart', args, {
        logToOutput: true,
        token,
      });
    },
  );

  if (result.cancelled) return null;

  // The CLI exits 0 when no stale ignores found, 1 when some exist — both
  // are success from our perspective. A genuine error produces stderr output
  // AND a non-zero exit that isn't just "findings present". We check for
  // meaningful stderr rather than exit code alone.
  if (!result.ok && !isExpectedNonZeroExit(result.stderr)) {
    const message = summarizeError(result.stderr);
    void vscode.window.showErrorMessage(
      l10n('staleIgnores.error.findFailed', { message }),
    );
    getSharedOutputChannel().show(true);
    return null;
  }

  // Read the JSON output file. The CLI's `--format json` path (bin/scan.dart)
  // ALWAYS calls _writeJson before exiting, even when zero stale ignores were
  // found — so on a normal completion this file is guaranteed to exist and be
  // well-formed. A read/parse failure here means something genuinely broke
  // (corrupted write, permissions, disk full) — NOT "clean, no findings" —
  // so it surfaces as an error rather than silently reporting success.
  try {
    const fs = await import('node:fs');
    const raw = fs.readFileSync(jsonPath, 'utf-8');
    return JSON.parse(raw) as StaleIgnoreResult;
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    void vscode.window.showErrorMessage(
      l10n('staleIgnores.error.findFailed', { message }),
    );
    getSharedOutputChannel().show(true);
    return null;
  }
}

// ── Fix stale ignores (whole project) ───────────────────────────────────────

/**
 * Runs the scan CLI with `--fix-stale-ignores` to auto-remove stale ignore
 * comments across the whole project. Confirms with the user before
 * modifying files, then clears the diagnostic collection on success.
 */
async function runFixStaleIgnores(): Promise<void> {
  const root = getWorkspaceRootOrError();
  if (!root) return;
  if (!ensureSaropaDependency(root)) return;

  // Confirm before modifying source files — the fix is destructive (removes
  // comments from disk). The user can always undo via git, but still.
  const confirmLabel = l10n('staleIgnores.confirm.fixAction');
  const choice = await vscode.window.showWarningMessage(
    l10n('staleIgnores.confirm.fixMessage'),
    { modal: true },
    confirmLabel,
  );
  if (choice !== confirmLabel) return;

  const result = await runFixScan(root, l10n('staleIgnores.progress.fixing'));
  if (result === null) return; // Cancelled.

  if (!result.ok) {
    void showFixFailure(result);
    return;
  }

  // Fix succeeded — clear diagnostics since the stale ignores are gone.
  getDiagnosticCollection().clear();

  // Matches the cross-file command convention (cross-file-commands.ts): the
  // Output channel is only force-revealed on error. A successful run gets a
  // lighter-weight info message instead of yanking focus away from the
  // editor — the channel already has the full CLI output from the run
  // (logToOutput: true) for anyone who wants to check it.
  void vscode.window.showInformationMessage(
    l10n('staleIgnores.info.fixed'),
  );
}

// ── Fix stale ignores (single file, from a quick fix) ───────────────────────

/**
 * Runs `--fix-stale-ignores --files <path>` scoped to one file, then
 * re-scans just that file to refresh its diagnostics without disturbing
 * diagnostics for any other file. No confirmation dialog — invoked from a
 * lightbulb quick fix on a single diagnostic, a much smaller blast radius
 * than the bulk sidebar/palette action.
 */
async function runFixStaleIgnoresInFile(uri: vscode.Uri): Promise<void> {
  const root = getWorkspaceRootOrError();
  if (!root) return;
  if (!ensureSaropaDependency(root)) return;

  const filePath = uri.fsPath;
  const result = await runFixScan(
    root,
    l10n('staleIgnores.progress.fixing'),
    filePath,
  );
  if (result === null) return; // Cancelled.

  if (!result.ok) {
    void showFixFailure(result);
    return;
  }

  // Re-scan just this file to refresh its diagnostics. The JSON output path
  // is hashed from the file path (not a fixed shared filename) so two
  // per-file fixes on DIFFERENT files triggered close together — e.g. two
  // quick fixes clicked in quick succession — can't have one run's write
  // land between the other run's write and read and cross-contaminate each
  // other's diagnostics via updateDiagnosticsForUri.
  const jsonPath = perFileJsonPath(root, filePath);
  const scan = await runFindScan(root, jsonPath, l10n('staleIgnores.progress.finding'), filePath);
  if (scan !== null) {
    updateDiagnosticsForUri(uri, scan.staleIgnores);
  }

  vscode.window.setStatusBarMessage(
    l10n('staleIgnores.info.fixedInFile'),
    5000,
  );
}

/**
 * Shared fix-CLI invocation for both the whole-project and single-file fix
 * commands. Returns `null` when cancelled.
 */
async function runFixScan(
  root: string,
  progressTitle: string,
  filePath?: string,
): Promise<{ ok: boolean; stdout: string; stderr: string } | null> {
  const result = await vscode.window.withProgress(
    {
      location: vscode.ProgressLocation.Notification,
      title: progressTitle,
      cancellable: true,
    },
    async (_progress, token) => {
      const args = [
        'run',
        'saropa_lints:scan',
        root,
        ...(filePath ? ['--files', filePath] : []),
        '--fix-stale-ignores',
      ];
      return runInWorkspaceAsync(root, 'dart', args, {
        logToOutput: true,
        token,
      });
    },
  );

  if (result.cancelled) return null;
  return result;
}

/**
 * Unlike --find-stale-ignores, --fix-stale-ignores exits 0 on EVERY success
 * path (nothing to fix, or fixed successfully) and 1 ONLY on a genuine
 * failure (stale ignores detected but no files could be modified, e.g.
 * deleted between detection and fix — bin/scan.dart:547-552). There is no
 * "expected" non-zero exit here, so any non-ok result is a real failure —
 * even with empty stderr, since that failure path prints only to stdout.
 */
async function showFixFailure(result: { stdout: string; stderr: string }): Promise<void> {
  const message = result.stderr.trim()
    ? summarizeError(result.stderr)
    : summarizeError(result.stdout);
  void vscode.window.showErrorMessage(
    l10n('staleIgnores.error.fixFailed', { message }),
  );
  getSharedOutputChannel().show(true);
}

// ── Diagnostic publishing ─────────────────────────────────────────────────────

/**
 * Converts stale ignore entries into VS Code diagnostics and republishes the
 * ENTIRE collection (clearing prior results first). Used for whole-project
 * find runs where every file's state is known fresh.
 */
function publishDiagnostics(staleIgnores: StaleIgnoreEntry[]): void {
  const collection = getDiagnosticCollection();
  collection.clear();

  const byFile = groupDiagnosticsByFile(staleIgnores);
  for (const [uriStr, diags] of byFile) {
    collection.set(vscode.Uri.parse(uriStr), diags);
  }
}

/**
 * Replaces diagnostics for a SINGLE file without touching any other file's
 * entries in the collection. Used after a per-file scoped fix, where only
 * one file's state is known fresh and the rest of the collection (from a
 * possibly-earlier whole-project find) must be left alone.
 */
function updateDiagnosticsForUri(uri: vscode.Uri, staleIgnores: StaleIgnoreEntry[]): void {
  const byFile = groupDiagnosticsByFile(staleIgnores);
  const diags = byFile.get(uri.toString()) ?? [];
  getDiagnosticCollection().set(uri, diags);
}

/** Builds one `vscode.Diagnostic` per stale ignore, grouped by file URI. */
function groupDiagnosticsByFile(staleIgnores: StaleIgnoreEntry[]): Map<string, vscode.Diagnostic[]> {
  const byFile = new Map<string, vscode.Diagnostic[]>();

  for (const entry of staleIgnores) {
    const uri = vscode.Uri.file(entry.filePath);
    const key = uri.toString();

    // Diagnostic range: the full comment line. 0-based line index.
    // `commentText` is `line.trim()` on the Dart side (leading whitespace
    // stripped), so its length does NOT match the real column offset for
    // indented ignore comments. Use MAX_SAFE_INTEGER for the end column —
    // VS Code clamps it to the actual end of the line, covering the whole
    // line regardless of indentation.
    const lineIdx = entry.commentLine - 1;
    const range = new vscode.Range(lineIdx, 0, lineIdx, Number.MAX_SAFE_INTEGER);

    const diag = new vscode.Diagnostic(
      range,
      l10n('staleIgnores.diagnostic.message', { ruleName: entry.ruleName }),
      vscode.DiagnosticSeverity.Warning,
    );
    diag.source = DIAGNOSTIC_SOURCE;
    // Code links to the rule name so the user can search for it.
    diag.code = entry.ruleName;

    const list = byFile.get(key) ?? [];
    list.push(diag);
    byFile.set(key, list);
  }

  return byFile;
}

// ── Quick fix ────────────────────────────────────────────────────────────────

/**
 * Offers a "Fix stale ignores in this file" quick fix on each stale-ignore
 * diagnostic. Delegates to `saropaLints.fixStaleIgnoresInFile` (the CLI's
 * `--fix-stale-ignores --files <path>`) rather than editing text directly —
 * the comment-removal logic (standalone vs inline, multi-rule pruning) lives
 * once in the Dart fixer (`lib/src/scan/stale_ignore_detector.dart`), so this
 * avoids re-implementing and risking drift from that source of truth. The
 * fix is file-scoped, not line-scoped: clicking it may remove more than the
 * one clicked diagnostic if the file has other stale ignores too, which the
 * action's label makes explicit.
 */
export class StaleIgnoreCodeActionProvider implements vscode.CodeActionProvider {
  provideCodeActions(
    document: vscode.TextDocument,
    _range: vscode.Range,
    context: vscode.CodeActionContext,
  ): vscode.CodeAction[] {
    const staleDiags = context.diagnostics.filter((d) => d.source === DIAGNOSTIC_SOURCE);
    if (staleDiags.length === 0) return [];

    const action = new vscode.CodeAction(
      l10n('staleIgnores.quickFix.title'),
      vscode.CodeActionKind.QuickFix,
    );
    action.diagnostics = staleDiags;
    action.isPreferred = true;
    action.command = {
      command: 'saropaLints.fixStaleIgnoresInFile',
      title: l10n('staleIgnores.quickFix.title'),
      arguments: [document.uri],
    };
    return [action];
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

/**
 * Derives a per-file JSON output path for the scoped find-refresh in
 * `runFixStaleIgnoresInFile`. Hashing the target file path (rather than a
 * single fixed filename) means two per-file fixes on DIFFERENT files
 * triggered close together get independent output files and cannot
 * cross-contaminate each other's diagnostics — see the race condition this
 * guards against in `runFixStaleIgnoresInFile`'s comment.
 */
export function perFileJsonPath(root: string, filePath: string): string {
  const hash = crypto.createHash('md5').update(filePath).digest('hex').slice(0, 12);
  return path.join(root, 'reports', '.saropa_lints', `stale_ignores_file_${hash}.json`);
}

/** Returns the workspace root or shows an error and returns null. */
function getWorkspaceRootOrError(): string | null {
  const root = getProjectRoot();
  if (!root) {
    void vscode.window.showErrorMessage(
      l10n('staleIgnores.error.noWorkspace'),
    );
    return null;
  }
  return root;
}

/** Checks that saropa_lints is a dependency; shows an error if not. */
function ensureSaropaDependency(workspaceRoot: string): boolean {
  if (hasSaropaLintsDep(workspaceRoot)) return true;
  void vscode.window.showErrorMessage(
    l10n('staleIgnores.error.missingDep'),
  );
  return false;
}

/**
 * The scan CLI exits 1 when stale ignores are found — that's "success with
 * findings", not a failure. A genuine error has meaningful stderr content
 * beyond the Dart VM's boilerplate. This heuristic distinguishes the two.
 */
function isExpectedNonZeroExit(stderr: string): boolean {
  const trimmed = stderr.trim();
  // Empty stderr or only Dart observatory/VM-service lines = expected exit.
  if (!trimmed) return true;
  // Dart VM prints an observatory URI to stderr on startup; ignore it.
  return trimmed.split(/\r?\n/).every(
    (line) => line.includes('Observatory listening') || line.includes('VM service'),
  );
}

/** Extracts a short error message from stderr for user-facing notifications. */
function summarizeError(stderr: string): string {
  const trimmed = stderr.trim();
  if (!trimmed) return 'See Output for details.';
  const firstLine = trimmed.split(/\r?\n/)[0] ?? 'See Output for details.';
  return firstLine.length > 180 ? `${firstLine.slice(0, 177)}...` : firstLine;
}
