/**
 * Searchable, categorized command catalog webview panel.
 *
 * Opens as a singleton editor tab (like the About panel). Users can browse
 * every extension command grouped by category, search/filter by title or
 * description, and click to execute. Recent runs are stored for one-click replay.
 */

import * as vscode from 'vscode';
import { catalogEntries, catalogEntryByCommand } from './commandCatalogRegistry';
import {
  clearCommandHistory,
  readCommandHistory,
  recordCommandHistory,
} from './commandCatalogHistory';
import { buildCommandCatalogHtml } from './commandCatalogWebviewHtml';

let currentPanel: vscode.WebviewPanel | undefined;

const knownCommands = new Set(catalogEntries.map((e) => e.command));

function postHistory(context: vscode.ExtensionContext): void {
  if (!currentPanel) {
    return;
  }
  void currentPanel.webview.postMessage({
    type: 'history',
    items: readCommandHistory(context),
  });
}

function handleWebviewMessage(
  context: vscode.ExtensionContext,
  message: unknown,
): void {
  if (!message || typeof message !== 'object') {
    return;
  }

  const rec = message as { type?: string; command?: string };

  if (rec.type === 'clearHistory') {
    void clearCommandHistory(context).then(() => postHistory(context));
    return;
  }

  if (rec.type !== 'executeCommand' || !rec.command) {
    return;
  }

  if (!knownCommands.has(rec.command)) {
    return;
  }

  const entry = catalogEntryByCommand.get(rec.command);
  if (entry) {
    recordCommandHistory(context, rec.command, entry.title, entry.icon);
    postHistory(context);
  }

  void vscode.commands.executeCommand(rec.command);
}

/**
 * Show (or re-focus) the command catalog panel. Call this from the registered
 * command handler in extension.ts.
 */
export function showCommandCatalogPanel(context: vscode.ExtensionContext): void {
  if (currentPanel) {
    currentPanel.reveal(vscode.ViewColumn.One);
    postHistory(context);
    return;
  }

  currentPanel = vscode.window.createWebviewPanel(
    'saropaLints.commandCatalog',
    'Saropa Lints: Command Catalog',
    vscode.ViewColumn.One,
    {
      enableScripts: true,
      localResourceRoots: [context.extensionUri],
    },
  );

  const history = readCommandHistory(context);
  currentPanel.webview.html = buildCommandCatalogHtml(
    currentPanel.webview,
    context.extensionUri,
    history,
  );

  currentPanel.webview.onDidReceiveMessage((msg) =>
    handleWebviewMessage(context, msg),
  );

  currentPanel.onDidDispose(() => {
    currentPanel = undefined;
  });
}
