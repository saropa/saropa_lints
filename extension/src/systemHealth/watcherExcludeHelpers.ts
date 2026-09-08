/**
 * Shared helper for merging patterns into `files.watcherExclude`.
 *
 * Both the watcher-exclude audit and the workspace hazard scan need to
 * read the current excludes, add new keys, and write back at workspace
 * level. This module is the single place that logic lives so neither
 * caller can drift out of sync with the other.
 */

import * as vscode from 'vscode';

// Check whether a relative path matches a files.watcherExclude glob.
// Supports double-star, single-star, and literal segments. A leading
// double-star-slash matches zero or more directory levels, so a pattern
// like "**/*.hprof" matches both "dir/foo.hprof" and bare "foo.hprof"
// at the workspace root. Nested `**/` sequences (e.g. `**/dep/**/build/**`)
// are handled by replacing `**/` first, then a trailing lone `**`, then
// single `*`.
function matchGlob(filePath: string, pattern: string): boolean {
  // Escape regex metacharacters, then convert glob wildcards to regex.
  // `**/` is replaced first to avoid the `*` pass eating the leading `*`.
  const re = pattern
    .replace(/[.+^${}()|[\]\\]/g, '\\$&')
    .replace(/\*\*\//g, '(.*/)?')
    .replace(/\*\*/g, '.*')
    .replace(/\*/g, '[^/]*');
  return new RegExp(`^${re}$`).test(filePath);
}

/** True when the file is covered by at least one active watcher exclude. */
export function isCovered(
  relative: string,
  excludes: Record<string, boolean>,
): boolean {
  for (const [pattern, active] of Object.entries(excludes)) {
    if (active && matchGlob(relative, pattern)) return true;
  }
  return false;
}

/**
 * Merge one or more glob patterns into the workspace-level
 * `files.watcherExclude` setting.
 *
 * Existing patterns and their boolean values are preserved; each new
 * pattern is added as `true`. The write targets
 * `ConfigurationTarget.Workspace` so it lands in `.vscode/settings.json`,
 * not the user's global config.
 */
export async function mergeWatcherExcludes(
  patterns: readonly string[],
): Promise<void> {
  const config = vscode.workspace.getConfiguration('files');
  // VS Code stores watcherExclude as Record<string, boolean>.
  const current =
    config.get<Record<string, boolean>>('watcherExclude') ?? {};

  // Build the merged object: keep all existing entries, add the new ones.
  const merged: Record<string, boolean> = { ...current };
  for (const p of patterns) {
    merged[p] = true;
  }

  // Write at workspace level so the change lands in .vscode/settings.json.
  await config.update(
    'watcherExclude',
    merged,
    vscode.ConfigurationTarget.Workspace,
  );
}
