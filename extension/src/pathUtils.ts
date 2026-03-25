/**
 * Path helpers shared by Code Lens, Issues tree, and commands.
 * Ensures consistent normalization for comparison with violations.json paths (forward slashes).
 *
 * Also provides a cached file-existence check used by the Issues tree to detect
 * files that were moved or deleted since the last analysis run, avoiding broken
 * "file not found" navigation without repeated disk I/O.
 */

import * as fs from 'fs';

/** Normalize path to forward slashes for consistent match with violations.json file paths. */
export function normalizePath(p: string): string {
  return p.replace(/\\/g, '/');
}

/**
 * Per-render-cycle cache for file existence checks.
 * Avoids redundant `fs.existsSync` calls when multiple violations reference the same file.
 * Call {@link clearFileExistsCache} on tree refresh so renames/deletes are picked up promptly.
 */
const fileExistsCache = new Map<string, boolean>();

/**
 * Check whether a file exists on disk, caching results keyed by normalized
 * (forward-slash) path to avoid repeated I/O for the same file.
 */
export function cachedFileExists(absPath: string): boolean {
  const key = normalizePath(absPath);
  let exists = fileExistsCache.get(key);
  if (exists === undefined) {
    exists = fs.existsSync(absPath);
    fileExistsCache.set(key, exists);
  }
  return exists;
}

/** Clear the file-existence cache (e.g. on tree refresh). */
export function clearFileExistsCache(): void {
  fileExistsCache.clear();
}
