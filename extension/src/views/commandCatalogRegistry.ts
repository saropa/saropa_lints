/**
 * Static registry of all extension commands for the command catalog webview.
 *
 * Maintenance: when adding or removing a command in package.json, update this
 * registry to match. A test validates that the two stay in sync.
 *
 * Most of this file is the `catalogEntries` literal: titles align with
 * `package.json` `contributes.commands` labels so the palette and catalog stay
 * consistent. Descriptions stay short; the webview search field concatenates
 * title, id, and description for matching.
 */

import { CatalogCategory, CatalogEntry } from './commandCatalogTypes';
import { projectCatalogEntries } from './commandCatalogEntriesProject';
import { vibrancyCatalogEntries } from './commandCatalogEntriesVibrancy';
import { miscCatalogEntries } from './commandCatalogEntriesMisc';

// Re-export the catalog types so existing importers keep referencing
// commandCatalogRegistry.ts unchanged after the data split.
export type { CatalogCategory, CatalogEntry } from './commandCatalogTypes';

// ── Helpers ──────────────────────────────────────────────────────────────────

/**
 * Ordered list of categories — controls the display order of sections in the
 * catalog webview.
 */
export const catalogCategoryOrder: readonly CatalogCategory[] = [
  'Setup & Configuration',
  'Analysis',
  'Violations & Filtering',
  'Rules & Fixes',
  'Security Posture',
  'Reporting & Export',
  'Code Health',
  'Package Vibrancy',
  'Package Vibrancy — Filters',
  'Package Vibrancy — Updates',
  'Package Vibrancy — Registries',
  'TODOs & Hacks',
  'Drift Advisor',
  'Views & Navigation',
];

// ── Registry ─────────────────────────────────────────────────────────────────

/**
 * All catalog entries, composed from the per-group data files. Order here
 * only affects insertion order; the catalog UI groups by `category` and
 * orders sections via {@link catalogCategoryOrder}.
 */
export const catalogEntries: readonly CatalogEntry[] = [
  ...projectCatalogEntries,
  ...vibrancyCatalogEntries,
  ...miscCatalogEntries,
];

/** Fast lookup for titles, icons, and history (see command catalog webview). */
export const catalogEntryByCommand: ReadonlyMap<string, CatalogEntry> = new Map(
  catalogEntries.map((e) => [e.command, e]),
);

/**
 * Returns catalog entries grouped by category, in the order defined by
 * {@link catalogCategoryOrder}. Categories with no entries are omitted.
 */
export function entriesByCategory(): Map<CatalogCategory, CatalogEntry[]> {
  const map = new Map<CatalogCategory, CatalogEntry[]>();

  // Seed map in display order so iteration order is deterministic.
  for (const cat of catalogCategoryOrder) {
    map.set(cat, []);
  }

  for (const entry of catalogEntries) {
    const list = map.get(entry.category);
    if (list) {
      list.push(entry);
    }
  }

  // Remove empty categories.
  for (const [cat, list] of map) {
    if (list.length === 0) {
      map.delete(cat);
    }
  }

  // Stable, predictable order within each section (title A→Z).
  for (const list of map.values()) {
    list.sort((a, b) =>
      a.title.localeCompare(b.title, 'en', { sensitivity: 'base' }),
    );
  }

  return map;
}

