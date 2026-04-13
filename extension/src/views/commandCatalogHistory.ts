/**
 * Persists recently executed catalog commands so the webview can offer
 * one-click re-runs. Stored in global state (follows the user across folders).
 */

import type * as vscode from 'vscode';

export const COMMAND_CATALOG_HISTORY_KEY = 'saropaLints.commandCatalog.history';

export const MAX_COMMAND_HISTORY = 25;

/** One row in the catalog “Recent” strip (JSON-serializable for globalState). */
export interface CatalogHistoryRecord {
  command: string;
  title: string;
  icon: string;
  at: number;
}

const META_NO_HISTORY = 'saropaLints.showCommandCatalog';

export function readCommandHistory(
  context: vscode.ExtensionContext,
): CatalogHistoryRecord[] {
  return context.globalState.get<CatalogHistoryRecord[]>(
    COMMAND_CATALOG_HISTORY_KEY,
  ) ?? [];
}

/** Append or promote a command to the front; returns the list after update. */
export function recordCommandHistory(
  context: vscode.ExtensionContext,
  command: string,
  title: string,
  icon: string,
): CatalogHistoryRecord[] {
  if (command === META_NO_HISTORY) {
    return readCommandHistory(context);
  }

  const prev = readCommandHistory(context);
  const filtered = prev.filter((h) => h.command !== command);
  const next: CatalogHistoryRecord[] = [
    { command, title, icon, at: Date.now() },
    ...filtered,
  ].slice(0, MAX_COMMAND_HISTORY);

  void context.globalState.update(COMMAND_CATALOG_HISTORY_KEY, next);
  return next;
}

export async function clearCommandHistory(
  context: vscode.ExtensionContext,
): Promise<void> {
  await context.globalState.update(COMMAND_CATALOG_HISTORY_KEY, []);
}
