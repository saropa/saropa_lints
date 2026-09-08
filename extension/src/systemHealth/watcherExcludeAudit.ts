/**
 * One-shot audit of the workspace's `files.watcherExclude` setting.
 *
 * Flutter/Dart workspaces routinely contain multi-GB files (heap dumps, build
 * output, ARB translation bundles) that VS Code's file watcher tracks by
 * default. Watching these bloats the watcher's memory and can crash VS Code
 * entirely — the 2026-09-05 incident was caused by a 2.2 GB `.hprof` and
 * 281 MB of ARB files the watcher never needed to see.
 *
 * This module checks the workspace config once per activation (deferred well
 * past startup), computes which recommended patterns are missing, and offers
 * to add them all in one click. A "Dismiss" action suppresses the prompt for
 * the workspace permanently via `workspaceState`.
 */

import * as vscode from 'vscode';
import { l10n } from '../i18n/runtime';
import { mergeWatcherExcludes } from './watcherExcludeHelpers';

/**
 * WorkspaceState key used to record that the user dismissed the prompt.
 * Once set, the audit never fires again for this workspace.
 */
const DISMISSED_KEY = 'watcherExcludeAudit.dismissed';

/**
 * Recommended `files.watcherExclude` patterns for Flutter/Dart workspaces.
 *
 * Each entry is a glob VS Code's file watcher should ignore. The patterns
 * target files that are either very large (heap dumps, build output) or
 * change frequently without user-facing relevance (tooling caches, logs).
 */
const RECOMMENDED_EXCLUDES: readonly string[] = [
  '**/*.hprof',
  '**/*.log',
  '**/build/**',
  '**/.dart_tool/**',
  '**/reports/**',
  '**/.vs/**',
  '**/dependency_overrides/**/build/**',
  '**/dependency_overrides/**/.dart_tool/**',
];

/**
 * Compute which recommended patterns are not already present in the
 * workspace's `files.watcherExclude` config. A pattern is "covered" if
 * the config object has an entry with that exact key set to `true`.
 */
export function findMissingExcludes(): string[] {
  const config = vscode.workspace.getConfiguration('files');
  // VS Code stores watcherExclude as Record<string, boolean>.
  const current = config.get<Record<string, boolean>>('watcherExclude') ?? {};

  // Only patterns whose key is absent or explicitly false are "missing".
  return RECOMMENDED_EXCLUDES.filter((pattern) => current[pattern] !== true);
}

/**
 * Format the missing patterns into a readable list for the notification.
 * Joins with commas — VS Code info messages are single-line toasts, so a
 * newline-separated list would be clipped.
 */
function formatMissingList(missing: readonly string[]): string {
  return missing.join(', ');
}

/**
 * Run the watcher-exclude audit and show a notification if gaps exist.
 *
 * Called once per session from `activate()` via a deferred `setTimeout`.
 * The dismissal flag prevents repeat prompts across sessions.
 */
export async function auditWatcherExcludes(
  context: vscode.ExtensionContext,
): Promise<void> {
  // Respect the user's previous dismissal — never re-prompt.
  // Guard: corrupted workspaceState after a VS Code crash can throw on get;
  // treat that as "not dismissed" so the audit still fires.
  try {
    if (context.workspaceState.get<boolean>(DISMISSED_KEY)) {
      return;
    }
  } catch {
    // workspaceState corrupted — fall through and run the audit.
  }

  const missing = findMissingExcludes();

  // Nothing to recommend — the workspace already covers everything.
  if (missing.length === 0) {
    return;
  }

  const addAllLabel = l10n('systemHealth.watcherExclude.addAll');
  const dismissLabel = l10n('systemHealth.watcherExclude.dismiss');

  // Show an information notification with the two action buttons.
  const choice = await vscode.window.showInformationMessage(
    l10n('systemHealth.watcherExclude.prompt', {
      count: String(missing.length),
      patterns: formatMissingList(missing),
    }),
    addAllLabel,
    dismissLabel,
  );

  if (choice === addAllLabel) {
    await mergeWatcherExcludes(missing);
    // Confirm the write so the user knows the patterns are now active.
    void vscode.window.showInformationMessage(
      l10n('systemHealth.watcherExclude.added', {
        count: String(missing.length),
      }),
    );
  } else if (choice === dismissLabel) {
    // Suppress the prompt for this workspace in future sessions.
    await context.workspaceState.update(DISMISSED_KEY, true);
  }
  // If the user closes the notification without clicking either button,
  // do nothing — the audit will re-run next session.
}
