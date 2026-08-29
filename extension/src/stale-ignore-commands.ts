/**
 * VS Code commands for detecting and fixing stale `// ignore:` comments.
 *
 * Wraps `dart run saropa_lints:scan --find-stale-ignores` (detection) and
 * `--fix-stale-ignores` (auto-removal) behind command palette entries and
 * sidebar actions, publishing results as Problems-panel diagnostics so stale
 * ignores appear as squiggly lines on the offending comment lines.
 */
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
 * Registers the stale-ignore commands and returns the diagnostic collection
 * so the caller can add it to `context.subscriptions` for cleanup.
 */
export function registerStaleIgnoreCommands(
  context: vscode.ExtensionContext,
): vscode.DiagnosticCollection {
  const diags = getDiagnosticCollection();

  // Find stale ignores — detect and publish diagnostics.
  context.subscriptions.push(
    vscode.commands.registerCommand('saropaLints.findStaleIgnores', () =>
      runFindStaleIgnores(),
    ),
  );

  // Fix stale ignores — detect, confirm, auto-remove, then re-scan.
  context.subscriptions.push(
    vscode.commands.registerCommand('saropaLints.fixStaleIgnores', () =>
      runFixStaleIgnores(),
    ),
  );

  return diags;
}

// ── Find stale ignores ────────────────────────────────────────────────────────

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

  // Run with cancellable progress — the scan can take 30+ seconds on large
  // projects because it runs all rules before checking ignores.
  const result = await vscode.window.withProgress(
    {
      location: vscode.ProgressLocation.Notification,
      title: l10n('staleIgnores.progress.finding'),
      cancellable: true,
    },
    async (_progress, token) => {
      // Write JSON to a temp file to avoid stdout capture issues (#310).
      const tmpDir = path.join(root, 'reports', '.saropa_lints');
      const jsonPath = path.join(tmpDir, 'stale_ignores.json');
      const args = [
        'run',
        'saropa_lints:scan',
        root,
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

  if (result.cancelled) return;

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
    return;
  }

  // Read the JSON output file.
  const jsonPath = path.join(root, 'reports', '.saropa_lints', 'stale_ignores.json');
  let parsed: StaleIgnoreResult;
  try {
    const fs = await import('node:fs');
    const raw = fs.readFileSync(jsonPath, 'utf-8');
    parsed = JSON.parse(raw) as StaleIgnoreResult;
  } catch {
    // No JSON file means no stale ignores (exit 0, no file written).
    publishDiagnostics([]);
    void vscode.window.showInformationMessage(
      l10n('staleIgnores.info.noneFound'),
    );
    return;
  }

  publishDiagnostics(parsed.staleIgnores);

  // Show result summary.
  const count = parsed.summary.totalCount;
  const fileCount = Object.keys(parsed.summary.byFile).length;
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

// ── Fix stale ignores ─────────────────────────────────────────────────────────

/**
 * Runs the scan CLI with `--fix-stale-ignores` to auto-remove stale ignore
 * comments. Confirms with the user before modifying files, then clears the
 * diagnostic collection on success.
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

  const result = await vscode.window.withProgress(
    {
      location: vscode.ProgressLocation.Notification,
      title: l10n('staleIgnores.progress.fixing'),
      cancellable: true,
    },
    async (_progress, token) => {
      const args = [
        'run',
        'saropa_lints:scan',
        root,
        '--fix-stale-ignores',
      ];
      return runInWorkspaceAsync(root, 'dart', args, {
        logToOutput: true,
        token,
      });
    },
  );

  if (result.cancelled) return;

  // Unlike --find-stale-ignores, --fix-stale-ignores exits 0 on EVERY
  // success path (nothing to fix, or fixed successfully) and 1 ONLY on a
  // genuine failure (stale ignores detected but no files could be modified,
  // e.g. deleted between detection and fix — bin/scan.dart:547-552). There
  // is no "expected" non-zero exit here, so any non-ok result is a real
  // failure — even with empty stderr, since that failure path prints only
  // to stdout.
  if (!result.ok) {
    const message = result.stderr.trim()
      ? summarizeError(result.stderr)
      : summarizeError(result.stdout);
    void vscode.window.showErrorMessage(
      l10n('staleIgnores.error.fixFailed', { message }),
    );
    getSharedOutputChannel().show(true);
    return;
  }

  // Fix succeeded — clear diagnostics since the stale ignores are gone.
  getDiagnosticCollection().clear();

  void vscode.window.showInformationMessage(
    l10n('staleIgnores.info.fixed'),
  );
  getSharedOutputChannel().show(true);
}

// ── Diagnostic publishing ─────────────────────────────────────────────────────

/**
 * Converts stale ignore entries into VS Code diagnostics and publishes them
 * to the Problems panel. Each stale ignore becomes a warning on the comment
 * line, making them visible as squiggly lines in the editor.
 */
function publishDiagnostics(staleIgnores: StaleIgnoreEntry[]): void {
  const collection = getDiagnosticCollection();
  collection.clear();

  // Group by file for batch publishing — one `collection.set()` per file.
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
    diag.source = 'Saropa Lints';
    // Code links to the rule name so the user can search for it.
    diag.code = entry.ruleName;

    const list = byFile.get(key) ?? [];
    list.push(diag);
    byFile.set(key, list);
  }

  // Publish all diagnostics in one batch per file.
  for (const [uriStr, diags] of byFile) {
    collection.set(vscode.Uri.parse(uriStr), diags);
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

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
