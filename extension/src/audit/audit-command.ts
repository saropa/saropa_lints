/**
 * VS Code command registration for the explorer "Audit Folder..." command.
 *
 * Spawns `dart run saropa_lints audit` (via the shared `auditCliRunner`) as a
 * child process, streams progress via a notification, and opens the audit
 * report webview on completion.
 *
 * The former sidebar "Full Audit" entry point (workspace-wide scope
 * quick-pick: full project / changed-vs-main / changed-vs-branch) has been
 * folded into the Findings Dashboard's own toolbar scope selector — see
 * `violationsWideReportView.ts` — so that workflow no longer lives here or
 * behind a VS Code quick-pick menu. This file now only covers the
 * folder-targeted explorer context-menu action, which is inherently
 * folder-scoped (no scope decision to make) and opens its own lightweight
 * report rather than the workspace-wide Findings Dashboard.
 */
import * as vscode from 'vscode';
import { hasSaropaLintsDep } from '../pubspecReader';
import { l10n } from '../i18n/runtime';
import { spawnAuditCli } from './auditCliRunner';
import { openAuditError, openAuditReport } from './audit-report-panel';

/** In-flight guard — prevents double-spawning an audit. */
let inflight: Promise<void> | undefined;

/** Registers the `saropaLints.auditFolder` command; call once at activation. */
export function registerAuditCommand(context: vscode.ExtensionContext): void {
  context.subscriptions.push(
    // Explorer context-menu entry: "Saropa: Audit Folder...". Always scoped
    // to the right-clicked folder and always full (no scope decision to
    // make — it's already scoped to one directory).
    vscode.commands.registerCommand(
      'saropaLints.auditFolder',
      (uri?: vscode.Uri) => runFolderAudit(context, uri),
    ),
  );
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
  inflight = doAudit(context, folder, null, false).finally(() => {
    inflight = undefined;
  });
}

/** Spawns the audit CLI and opens the report on success. */
async function doAudit(
  context: vscode.ExtensionContext,
  root: string,
  sinceRef: string | null,
  useBaseline: boolean,
): Promise<void> {
  // spawnAuditCli reports the specific failure/cancel reason through this
  // callback so doAudit can render the same message into the webview — a
  // toast alone would leave a stale or blank report panel behind if one was
  // already open from a prior run.
  let failure: { message: string; canceled: boolean } | null = null;
  const onFailure = (message: string, canceled: boolean): void => {
    failure = { message, canceled };
    if (canceled) {
      void vscode.window.showInformationMessage(message);
    } else {
      void vscode.window.showErrorMessage(message);
    }
  };

  const result = await vscode.window.withProgress(
    {
      location: vscode.ProgressLocation.Notification,
      title: l10n('audit.progress.title'),
      cancellable: true,
    },
    (progress, token) => {
      // spawnAuditCli reports ABSOLUTE percentages; vscode.Progress wants
      // increments, so track the delta here rather than inside the shared
      // runner (which the Findings Dashboard's own progress bar consumes
      // directly as an absolute width — see violations-dashboard-script.ts).
      let lastPct = 0;
      return spawnAuditCli(
        root,
        sinceRef,
        useBaseline,
        token,
        (update) => {
          const increment = update.pct - lastPct;
          lastPct = update.pct;
          progress.report({ increment, message: update.message });
        },
        onFailure,
      );
    },
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
