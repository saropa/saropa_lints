/**
 * Persists recently executed catalog commands so the webview can offer
 * one-click re-runs and a usage-driven "Frequent" band.
 *
 * Stored in global state (follows the user across folders).
 *
 * Schema note: records carry both `at` (last run timestamp, drives the Recent
 * band's reverse-chronological order) and `count` (lifetime run total, drives
 * the Frequent band's frequency-weighted ranking). Older records that pre-date
 * the `count` field are migrated to `count: 1` on read so a single missing
 * field cannot break the catalog UI.
 */

import type * as vscode from 'vscode';

export const COMMAND_CATALOG_HISTORY_KEY = 'saropaLints.commandCatalog.history';

export const MAX_COMMAND_HISTORY = 25;

/** One row in the catalog "Recent" / "Frequent" strips (JSON-serializable for globalState). */
export interface CatalogHistoryRecord {
  command: string;
  title: string;
  icon: string;
  /** Most recent run timestamp (ms since epoch). */
  at: number;
  /** Total lifetime runs of this command. Added 2026-05; older records read as 1. */
  count: number;
}

const META_NO_HISTORY = 'saropaLints.showCommandCatalog';

export function readCommandHistory(
  context: vscode.ExtensionContext,
): CatalogHistoryRecord[] {
  // Why migrate-on-read: globalState may hold records from before `count` existed.
  // Without the default, the Frequent band would compare numbers against undefined
  // and silently fail to rank old records. One-time normalize keeps the rest of
  // the codepath simple — no `count ?? 1` sprinkled through every consumer.
  const raw =
    context.globalState.get<Partial<CatalogHistoryRecord>[]>(
      COMMAND_CATALOG_HISTORY_KEY,
    ) ?? [];
  return raw
    .filter(
      (r): r is Partial<CatalogHistoryRecord> & {
        command: string;
        title: string;
        icon: string;
        at: number;
      } =>
        typeof r?.command === 'string' &&
        typeof r.title === 'string' &&
        typeof r.icon === 'string' &&
        typeof r.at === 'number',
    )
    .map((r) => ({
      command: r.command,
      title: r.title,
      icon: r.icon,
      at: r.at,
      count: typeof r.count === 'number' && r.count > 0 ? r.count : 1,
    }));
}

/**
 * Append or promote a command to the front and increment its lifetime count;
 * returns the list after update.
 */
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
  const existing = prev.find((h) => h.command === command);
  const filtered = prev.filter((h) => h.command !== command);
  const next: CatalogHistoryRecord[] = [
    {
      command,
      title,
      icon,
      at: Date.now(),
      // Preserve the lifetime counter when promoting an existing record so the
      // Frequent band reflects total usage, not just "did it run twice this hour".
      count: (existing?.count ?? 0) + 1,
    },
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
