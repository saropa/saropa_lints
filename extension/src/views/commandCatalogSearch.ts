/**
 * Command catalog webview — search index for client-side filtering.
 *
 * The webview matches user input against a single lowercase blob per entry so
 * typing fragments of the title, description, or command id (with or without
 * dots) all work. Keep this module free of HTML concerns so behavior is unit
 * tested independently of the webview template.
 */

import type { CatalogEntry } from './commandCatalogRegistry';

/**
 * Builds the normalized string stored in each row's `data-search` attribute.
 * Includes title, description, full command id, and id with `.` / `:` as spaces.
 */
export function buildCatalogSearchBlob(entry: CatalogEntry): string {
  const cmd = entry.command.toLowerCase();
  const cmdSpaced = cmd.replaceAll('.', ' ').replaceAll(':', ' ');
  return [entry.title, entry.description, cmd, cmdSpaced]
    .join(' ')
    .toLowerCase()
    .replaceAll(/\s+/g, ' ')
    .trim();
}
