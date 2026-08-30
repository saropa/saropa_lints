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
import { l10n } from '../i18n/runtime';
import { openAuditReport } from './audit-report-panel';

/** In-flight guard — prevents double-spawning an audit. */
let inflight: Promise<void> | undefined;

/** Registers the `saropaLints.fullAudit` command; call once at activation. */
export function registerAuditCommand(context: vscode.ExtensionContext): void {
  context.subscriptions.push(
    vscode.commands.registerCommand('saropaLints.fullAudit', () => runAudit(context)),
  );
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

  const root = getProjectRoot();
  if (!root) {
    void vscode.window.showErrorMessage(l10n('audit.noProject'));
    return;
  }
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
  const result = await vscode.window.withProgress(
    {
      location: vscode.ProgressLocation.Notification,
      title: l10n('audit.progress.title'),
      cancellable: true,
    },
    (progress, token) => spawnAuditCli(root, sinceRef, useBaseline, token, progress),
  );

  if (!result) return;
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
 */
function spawnAuditCli(
  root: string,
  sinceRef: string | null,
  useBaseline: boolean,
  token: vscode.CancellationToken,
  progress: vscode.Progress<{ message?: string; increment?: number }>,
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
    });

    let stdout = '';
    let stderrBuf = '';
    let lastPct = 0;

    child.stdout.on('data', (d: Buffer) => (stdout += d.toString()));

    // Parse structured JSON progress lines from stderr for the progress bar.
    child.stderr.on('data', (d: Buffer) => {
      stderrBuf += d.toString();
      // Process complete lines (progress lines are newline-terminated).
      const lines = stderrBuf.split('\n');
      // Keep the last incomplete chunk for the next data event.
      stderrBuf = lines.pop() ?? '';

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
              message: `${pct}% · ${p.progress}/${p.total} files · ${p.issues ?? 0} issues · ${shortFile}`,
            });
          }
        } catch {
          // Not a progress line — ignore.
        }
      }
    });

    // Tree-kill on cancel — shell:true means child is cmd.exe; child.kill()
    // alone orphans the dart grandchild.
    token.onCancellationRequested(() => {
      killProcessTree(child);
      resolve(null);
    });

    child.on('error', (e: Error) => {
      void vscode.window.showErrorMessage(
        l10n('audit.error.spawnFailed', { message: e.message }),
      );
      resolve(null);
    });

    child.on('close', (code: number | null) => {
      // Report completion.
      if (lastPct < 100) {
        progress.report({ increment: 100 - lastPct, message: l10n('audit.progress.title') });
      }

      // Exit 2 = invalid args or not a Dart project.
      if (code === 2) {
        // Find the first non-JSON, non-empty line from stderr for the error.
        const allStderr = stderrBuf;
        const first = allStderr.split('\n').find((l) => l.trim().length > 0 && !l.trim().startsWith('{')) ?? '';
        void vscode.window.showErrorMessage(
          l10n('audit.error.invalidProject', { details: first }),
        );
        resolve(null);
        return;
      }

      // Exit 0 or 1 = audit completed (0 = clean, 1 = findings found).
      try {
        const json = JSON.parse(stdout) as Record<string, unknown>;
        resolve(json);
      } catch {
        void vscode.window.showErrorMessage(
          l10n('audit.error.parseFailed'),
        );
        resolve(null);
      }
    });
  });
}
