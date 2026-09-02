/**
 * VS Code command registration for the full audit feature.
 *
 * Spawns `dart run saropa_lints audit` as a child process, streams
 * progress via a notification, and opens the audit report webview
 * on completion. Handles multi-root workspaces, cancellation, and
 * the --since quick-pick prompt.
 */
import * as cp from 'node:child_process';
import * as fs from 'node:fs';
import * as path from 'node:path';
import * as vscode from 'vscode';
import { getProjectRoot } from '../projectRoot';
import { hasSaropaLintsDep } from '../pubspecReader';
import { killProcessTree, resolveCliCwd } from '../views/devCliRoot';
import { pickWorkspaceFolder } from '../workspaceFolderPicker';
import { l10n } from '../i18n/runtime';
import { openAuditError, openAuditReport } from './audit-report-panel';

/** In-flight guard — prevents double-spawning an audit. */
let inflight: Promise<void> | undefined;

/**
 * Cross-platform tree-kill for the spawned audit CLI process.
 *
 * `devCliRoot`'s shared `killProcessTree` handles Windows correctly
 * (`taskkill /F /T` walks the process tree by PID, independent of process
 * groups). Its POSIX fallback is a plain `child.kill()`, which — with
 * `shell: true` — only signals the shell wrapping `dart`, not the `dart`
 * process itself; the shell dies and `dart` is silently orphaned, so
 * cancellation would appear to succeed (toast shown) while the audit kept
 * running in the background. That gap is closed here (rather than in the
 * shared helper, which other callers such as scanOnSave's long-lived daemon
 * rely on with different lifecycle assumptions) by killing the NEGATIVE pid
 * of the process group the spawn call above puts the shell in — POSIX
 * delivers the signal to every process in that group, including `dart`.
 */
/** @internal Exported for testing only — not part of the public API. */
export function killAuditProcessTree(child: cp.ChildProcess): void {
  if (process.platform !== 'win32' && child.pid) {
    try {
      process.kill(-child.pid, 'SIGKILL');
      return;
    } catch {
      // Process group already gone (e.g. dart already exited) — fall
      // through to the shared best-effort path below.
    }
  }
  killProcessTree(child);
}

/** Registers the `saropaLints.fullAudit` and `saropaLints.auditFolder` commands; call once at activation. */
export function registerAuditCommand(context: vscode.ExtensionContext): void {
  context.subscriptions.push(
    vscode.commands.registerCommand('saropaLints.fullAudit', () => runAudit(context)),
    // Explorer context-menu entry: "Saropa: Audit Folder...". Always scoped
    // to the right-clicked folder and always full (no --since/--baseline
    // quick-pick) — per the plan, the context menu is for a targeted,
    // no-decisions audit of one directory.
    vscode.commands.registerCommand(
      'saropaLints.auditFolder',
      (uri?: vscode.Uri) => runFolderAudit(context, uri),
    ),
  );
}

/** Resolves which project root to audit for the sidebar/palette command.
 *  Single-root workspaces use the existing pubspec-search heuristic
 *  unchanged. Multi-root workspaces prompt via the shared
 *  `pickWorkspaceFolder` picker (same one every other multi-root-aware
 *  command in the extension uses) rather than silently defaulting to
 *  `workspaceFolders[0]`, which has bitten other commands before (see
 *  workspaceFolderPicker.ts doc comment). */
async function resolveAuditRoot(): Promise<string | undefined> {
  const folders = vscode.workspace.workspaceFolders;
  if (!folders || folders.length <= 1) {
    const root = getProjectRoot();
    if (!root) void vscode.window.showErrorMessage(l10n('audit.noProject'));
    return root;
  }

  // Undefined here means the user dismissed the picker — not an error,
  // so no message (matches every other pickWorkspaceFolder call site).
  const picked = await pickWorkspaceFolder({
    placeHolder: l10n('audit.pickWorkspaceFolder'),
  });
  if (!picked) return undefined;

  // The picked folder itself must be (or directly contain) the Dart
  // project — audit is config-independent and does not do the same
  // one-level subdirectory search getProjectRoot() does for the
  // single-root case, since that could still resolve to the WRONG
  // multi-root folder's nested project.
  if (fs.existsSync(path.join(picked.uri.fsPath, 'pubspec.yaml'))) {
    return picked.uri.fsPath;
  }
  void vscode.window.showErrorMessage(l10n('audit.noProject'));
  return undefined;
}

/** Explorer context-menu entry point: audits exactly the right-clicked folder. */
async function runFolderAudit(context: vscode.ExtensionContext, uri?: vscode.Uri): Promise<void> {
  if (inflight) {
    void vscode.window.showInformationMessage(l10n('audit.alreadyRunning'));
    return;
  }
  const folder = uri?.fsPath;
  if (!folder) {
    void vscode.window.showErrorMessage(l10n('audit.noProject'));
    return;
  }
  if (!hasSaropaLintsDep(folder)) {
    void vscode.window.showErrorMessage(l10n('audit.missingDep'));
    return;
  }
  // No scope quick-pick here — always full, per the plan ("the Explorer
  // context-menu entry always runs full — it's already scoped to a folder").
  inflight = doAudit(context, folder, null, false).finally(() => {
    inflight = undefined;
  });
}

/** Scope picker result — what mode and optional git ref. */
interface AuditScopeResult {
  sinceRef: string | null;
  useBaseline: boolean;
}

/** Main entry point: shows the scope quick-pick then spawns the audit CLI. */
async function runAudit(context: vscode.ExtensionContext): Promise<void> {
  if (inflight) {
    void vscode.window.showInformationMessage(
      l10n('audit.alreadyRunning'),
    );
    return;
  }

  // Prompts for a workspace folder when the workspace has more than one
  // root; resolveAuditRoot shows its own error message for a real failure
  // (no project found) and stays silent for a plain picker cancel.
  const root = await resolveAuditRoot();
  if (!root) return;
  if (!hasSaropaLintsDep(root)) {
    void vscode.window.showErrorMessage(l10n('audit.missingDep'));
    return;
  }

  // Quick-pick: audit scope selection.
  const scope = await pickAuditScope(root);
  // undefined = user cancelled the quick-pick.
  if (scope === undefined) return;

  inflight = doAudit(context, root, scope.sinceRef, scope.useBaseline).finally(
    () => {
      inflight = undefined;
    },
  );
}

/**
 * Shows a quick-pick for the audit scope. Returns an AuditScopeResult
 * with the git ref (or null for full project) and whether to compare
 * against the baseline. Returns undefined if the user cancelled.
 */
async function pickAuditScope(root: string): Promise<AuditScopeResult | undefined> {
  // Check whether a baseline file exists to conditionally show that option.
  const baselineFile = path.join(root, '.saropa', 'audit_baseline.json');
  const hasBaseline = fs.existsSync(baselineFile);

  const items: vscode.QuickPickItem[] = [
    {
      label: l10n('audit.scope.full'),
      description: l10n('audit.scope.fullDescription'),
    },
    {
      label: l10n('audit.scope.changedVsMain'),
      description: l10n('audit.scope.changedVsMainDescription'),
    },
    {
      label: l10n('audit.scope.changedPickBranch'),
      description: l10n('audit.scope.changedPickBranchDescription'),
    },
  ];

  // Only show the baseline option when one exists.
  if (hasBaseline) {
    items.push({
      label: l10n('audit.scope.compareBaseline'),
      description: l10n('audit.scope.compareBaselineDescription'),
    });
  }

  const pick = await vscode.window.showQuickPick(items, {
    placeHolder: l10n('audit.scope.placeholder'),
  });
  if (!pick) return undefined;

  if (pick.label === l10n('audit.scope.full')) {
    return { sinceRef: null, useBaseline: false };
  }
  if (pick.label === l10n('audit.scope.changedVsMain')) {
    return { sinceRef: 'main', useBaseline: false };
  }
  if (pick.label === l10n('audit.scope.compareBaseline')) {
    return { sinceRef: null, useBaseline: true };
  }

  // "Pick branch..." — show a branch input box.
  const branch = await vscode.window.showInputBox({
    prompt: l10n('audit.scope.branchPrompt'),
    placeHolder: 'main',
    value: 'main',
  });
  if (branch === undefined) return undefined;
  return { sinceRef: branch, useBaseline: false };
}

/** Spawns the audit CLI and opens the report on success. */
async function doAudit(
  context: vscode.ExtensionContext,
  root: string,
  sinceRef: string | null,
  useBaseline: boolean,
): Promise<void> {
  // spawnAuditCli reports the specific failure/cancel reason through this
  // callback (in addition to its own toast) so doAudit can render the same
  // message into the webview — the toast alone would leave a stale or
  // blank report panel behind if one was already open from a prior run.
  let failure: { message: string; canceled: boolean } | null = null;
  const onFailure = (message: string, canceled: boolean): void => {
    failure = { message, canceled };
  };

  const result = await vscode.window.withProgress(
    {
      location: vscode.ProgressLocation.Notification,
      title: l10n('audit.progress.title'),
      cancellable: true,
    },
    (progress, token) => spawnAuditCli(root, sinceRef, useBaseline, token, progress, onFailure),
  );

  if (!result) {
    if (failure) {
      const f: { message: string; canceled: boolean } = failure;
      openAuditError(context, root, f.message, f.canceled);
    }
    return;
  }
  // Open the audit report webview with the JSON payload.
  openAuditReport(context, result, root);
}

/** Progress data parsed from a JSON line on stderr. */
interface AuditProgress {
  progress: number;
  total: number;
  elapsed: string;
  issues: number;
  file: string;
}

/**
 * Spawns `dart run saropa_lints audit` and collects the JSON output
 * from stdout. Returns the parsed JSON object, or null on failure/cancel.
 *
 * The CLI emits JSON progress lines on stderr (one per ~10 files) when
 * `--quiet` is passed. These are parsed to update the VS Code progress
 * notification with percentage and current file.
 *
 * @param onFailure Invoked with the localized failure/cancel message right
 *   before resolving null, so the caller can surface the same text in the
 *   report webview (toasts alone are easy to miss/dismiss).
 */
function spawnAuditCli(
  root: string,
  sinceRef: string | null,
  useBaseline: boolean,
  token: vscode.CancellationToken,
  progress: vscode.Progress<{ message?: string; increment?: number }>,
  onFailure: (message: string, canceled: boolean) => void,
): Promise<Record<string, unknown> | null> {
  return new Promise((resolve) => {
    const args = ['run', 'saropa_lints', 'audit', root, '--quiet'];
    if (sinceRef) {
      args.push('--since', sinceRef);
    }
    if (useBaseline) {
      args.push('--baseline');
    }

    const child = cp.spawn('dart', args, {
      cwd: resolveCliCwd(root),
      shell: true,
      // POSIX only (no-op on win32, where killProcessTree's `taskkill /T`
      // walks the tree by PID instead). Makes the spawned shell the leader
      // of a NEW process group, so the dart grandchild it launches shares
      // that group id — required for killAuditProcessTree's negative-pid
      // kill below to reach it. Without this, the shell and dart stay in
      // this Node process's own group and a group-kill would also try to
      // kill the extension host itself.
      detached: process.platform !== 'win32',
    });

    let stdout = '';
    let stderrBuf = '';
    // Complete stderr lines — accumulated for the exit-code-2 error path,
    // where the human-readable error message is a full newline-terminated
    // line (not the trailing fragment left in stderrBuf after progress
    // JSON parsing).
    const stderrLines: string[] = [];
    let lastPct = 0;
    // Cancellation already resolved + surfaced a message; taskkill's forced
    // tree-kill still fires 'close' afterward with truncated/empty stdout,
    // which would otherwise JSON.parse-fail and pop a second, contradictory
    // "output could not be read" toast on top of "Audit canceled".
    let canceled = false;

    child.stdout.on('data', (d: Buffer) => (stdout += d.toString()));

    // Parse structured JSON progress lines from stderr for the progress bar.
    child.stderr.on('data', (d: Buffer) => {
      stderrBuf += d.toString();
      // Process complete lines (progress lines are newline-terminated).
      const lines = stderrBuf.split('\n');
      // Keep the last incomplete chunk for the next data event.
      stderrBuf = lines.pop() ?? '';

      // Preserve all complete lines for the exit-code-2 error path.
      stderrLines.push(...lines);

      for (const line of lines) {
        const trimmed = line.trim();
        if (!trimmed.startsWith('{')) continue;
        try {
          const p = JSON.parse(trimmed) as Partial<AuditProgress>;
          if (typeof p.progress === 'number' && typeof p.total === 'number' && p.total > 0) {
            const pct = Math.round((p.progress / p.total) * 100);
            const increment = pct - lastPct;
            lastPct = pct;

            // Short filename for the message — strip path.
            const shortFile = (p.file ?? '').split(/[/\\]/).pop() ?? '';
            progress.report({
              increment,
              // Localized progress string with file counts and current filename.
              message: l10n('audit.progress.message', {
                pct: String(pct),
                scanned: String(p.progress),
                total: String(p.total),
                issues: String(p.issues ?? 0),
                file: shortFile,
              }),
            });
          }
        } catch {
          // Not a progress line — ignore.
        }
      }
    });

    // Tree-kill on cancel — shell:true means child is cmd.exe; child.kill()
    // alone orphans the dart grandchild. A cancel previously resolved
    // silently with no toast or webview update — violates the project's
    // "no silent async" rule, since the user has no confirmation the
    // in-flight audit actually stopped.
    token.onCancellationRequested(() => {
      canceled = true;
      killAuditProcessTree(child);
      const message = l10n('audit.error.canceled');
      void vscode.window.showInformationMessage(message);
      onFailure(message, true);
      resolve(null);
    });

    child.on('error', (e: Error) => {
      // After cancellation the tree-kill can trigger a belated 'error'
      // (e.g. EPIPE from the killed process). The cancel path already
      // resolved + toasted, so a second onFailure here would overwrite
      // the canceled flag and produce a contradictory "spawn failed" toast.
      if (canceled) return;

      const message = l10n('audit.error.spawnFailed', { message: e.message });
      void vscode.window.showErrorMessage(message);
      onFailure(message, false);
      resolve(null);
    });

    child.on('close', (code: number | null) => {
      // The cancellation path already resolved the promise and surfaced its
      // own message; the tree-kill's belated 'close' carries no useful
      // result, so stop here rather than risk a second, contradictory toast.
      if (canceled) return;

      // Report completion.
      if (lastPct < 100) {
        progress.report({ increment: 100 - lastPct, message: l10n('audit.progress.title') });
      }

      // Exit 2 = invalid args or not a Dart project.
      if (code === 2) {
        // Find the first non-JSON, non-empty line from the accumulated stderr
        // output. Uses stderrLines (complete lines) rather than stderrBuf
        // (which only holds the trailing fragment after progress parsing).
        const first = stderrLines.find((l) => l.trim().length > 0 && !l.trim().startsWith('{')) ?? '';
        const message = l10n('audit.error.invalidProject', { details: first });
        void vscode.window.showErrorMessage(message);
        onFailure(message, false);
        resolve(null);
        return;
      }

      // Exit 0 or 1 = audit completed (0 = clean, 1 = findings found).
      try {
        const json = JSON.parse(stdout) as Record<string, unknown>;
        resolve(json);
      } catch {
        const message = l10n('audit.error.parseFailed');
        void vscode.window.showErrorMessage(message);
        onFailure(message, false);
        resolve(null);
      }
    });
  });
}
