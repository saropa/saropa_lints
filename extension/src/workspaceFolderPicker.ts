/**
 * Workspace folder picker shared by every command that opens or writes a
 * project file from the Saropa Lints sidebar.
 *
 * # The bug this guards against
 *
 * VS Code's `workspace.workspaceFolders` is just an ordered list. Many
 * command implementations defaulted to `workspaceFolders[0]?.uri.fsPath`,
 * which silently writes into a sibling project (e.g. `saropa_drift_advisor`)
 * whenever that project happens to be first in a multi-root workspace. The
 * user reported `Open analysis_options_custom.yaml` opening the wrong
 * project's file, and the same root cause affected `Create AI agent
 * instructions` — both were resolving against `[0]`.
 *
 * # Resolution strategy (per call site)
 *
 * 1. **Single-folder workspace** — return that folder.
 * 2. **Active editor** — return the workspace folder containing the file
 *    the user is currently looking at. This matches "what the user means by
 *    'this project'" the overwhelming majority of the time.
 * 3. **Folder pick** — open VS Code's built-in workspace folder picker so
 *    the user makes the choice explicitly. Returns `undefined` if cancelled.
 *
 * The placeholder is configurable per call site so the picker can mention
 * the actual action (e.g. "open analysis_options_custom.yaml" vs. "create
 * AI agent instructions").
 */

import * as vscode from 'vscode';

export interface WorkspaceFolderPickOptions {
  /** Shown above the picker list. Be concrete about what is being written. */
  readonly placeHolder: string;
}

export async function pickWorkspaceFolder(
  opts: WorkspaceFolderPickOptions,
): Promise<vscode.WorkspaceFolder | undefined> {
  const folders = vscode.workspace.workspaceFolders;
  if (!folders || folders.length === 0) return undefined;
  if (folders.length === 1) return folders[0];

  const activeUri = vscode.window.activeTextEditor?.document.uri;
  if (activeUri) {
    const ws = vscode.workspace.getWorkspaceFolder(activeUri);
    if (ws) return ws;
  }
  return vscode.window.showWorkspaceFolderPick({ placeHolder: opts.placeHolder });
}
