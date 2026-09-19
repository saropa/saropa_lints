/**
 * One-shot audit of the workspace's `files.watcherExclude` setting.
 *
 * Flutter/Dart workspaces routinely contain multi-GB files (heap dumps, build
 * output, ARB translation bundles) that VS Code's file watcher tracks by
 * default. Watching these bloats the watcher's memory and can crash VS Code
 * entirely — the 2026-09-05 incident was caused by a 2.2 GB `.hprof` and
 * 281 MB of ARB files the watcher never needed to see.
 *
 * A second, conditional source of watcher bloat: agent tools such as Claude
 * Code create git worktrees under `.claude/worktrees/<name>/`, each a full
 * repo copy (often ~1 GB with `build/`/`.dart_tool/` inside it). The watcher
 * has no reason to track those either. Unlike the unconditional patterns
 * below, this one is only recommended when a `.claude/worktrees` directory
 * actually exists on disk in a workspace folder — most workspaces have never
 * run an agent tool, so recommending it unconditionally would just be noise.
 * (The Dart analysis server already skips dot-folders on its own, so this is
 * purely about VS Code's file-watcher memory.)
 *
 * This module checks the workspace config once per activation (deferred well
 * past startup), computes which recommended patterns are missing, and offers
 * to add them all in one click. A "Dismiss" action suppresses only the
 * patterns offered at dismissal time — a pattern that becomes newly relevant
 * later (e.g. `.claude/worktrees` appearing after the user dismissed the
 * original prompt) can still surface on a later run.
 */

import * as fs from 'node:fs';
import * as path from 'node:path';
import * as vscode from 'vscode';
import { l10n } from '../i18n/runtime';
import { mergeWatcherExcludes } from './watcherExcludeHelpers';

/**
 * WorkspaceState key used to record that the user dismissed the prompt.
 * Legacy boolean flag, kept for backward compatibility with workspaces that
 * dismissed before `DISMISSED_PATTERNS_KEY` existed. See `getDismissedPatterns`.
 */
const DISMISSED_KEY = 'watcherExcludeAudit.dismissed';

/**
 * WorkspaceState key holding the list of patterns the user has dismissed.
 * Replaces the all-or-nothing `DISMISSED_KEY` boolean so that a pattern
 * added to `RECOMMENDED_EXCLUDES` (or the conditional agent-worktree
 * pattern becoming relevant) after a dismissal can still be offered.
 */
const DISMISSED_PATTERNS_KEY = 'watcherExcludeAudit.dismissedPatterns';

/**
 * Recommended `files.watcherExclude` patterns for Flutter/Dart workspaces.
 *
 * Each entry is a glob VS Code's file watcher should ignore. The patterns
 * target files that are either very large (heap dumps, build output) or
 * change frequently without user-facing relevance (tooling caches, logs).
 * These are recommended unconditionally, unlike the agent-worktree pattern
 * below.
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
 * Glob recommended when a `.claude/worktrees` directory is found on disk in
 * any workspace folder. Not part of `RECOMMENDED_EXCLUDES` because it's
 * conditional, not unconditional.
 */
const CLAUDE_WORKTREE_PATTERN = '**/.claude/worktrees/**';

/**
 * Config keys that already cover the agent-worktree case. A workspace that
 * excludes all of `.claude` (or already has the exact worktree pattern) has
 * no gap, even though none of these match `CLAUDE_WORKTREE_PATTERN` exactly.
 */
const CLAUDE_WORKTREE_COVERING_KEYS: readonly string[] = [
  '**/.claude/worktrees/**',
  '**/.claude/**',
  '.claude/**',
  '.claude/worktrees/**',
];

/**
 * True when `current` already excludes agent-tool worktrees under `.claude`,
 * whether via the exact pattern or a broader `.claude` exclusion.
 */
function isClaudeWorktreeCovered(current: Record<string, boolean>): boolean {
  return CLAUDE_WORKTREE_COVERING_KEYS.some((key) => current[key] === true);
}

/**
 * Compute which recommended patterns are not already present in the
 * workspace's `files.watcherExclude` config. Pure and vscode-free so it can
 * be unit tested directly.
 *
 * A pattern is "covered" if the config object has an entry with that exact
 * key set to `true` (or, for the agent-worktree pattern, any of
 * `CLAUDE_WORKTREE_COVERING_KEYS`). The agent-worktree pattern is only
 * considered missing when `opts.hasClaudeWorktrees` is true — it's noise
 * for workspaces that have never run an agent tool.
 */
export function computeMissingExcludes(
  current: Record<string, boolean>,
  opts: { hasClaudeWorktrees: boolean },
): string[] {
  // Only patterns whose key is absent or explicitly false are "missing".
  const missing = RECOMMENDED_EXCLUDES.filter(
    (pattern) => current[pattern] !== true,
  );

  if (opts.hasClaudeWorktrees && !isClaudeWorktreeCovered(current)) {
    missing.push(CLAUDE_WORKTREE_PATTERN);
  }

  return missing;
}

/**
 * True when any workspace folder has a `.claude/worktrees` directory on
 * disk. Errors (missing path, permission denied, etc.) are treated as
 * "absent" for that folder rather than propagating — a filesystem hiccup
 * here shouldn't crash the audit.
 */
async function hasClaudeWorktrees(): Promise<boolean> {
  const folders = vscode.workspace.workspaceFolders;
  if (!folders) {
    return false;
  }

  for (const folder of folders) {
    try {
      const stat = await fs.promises.stat(
        path.join(folder.uri.fsPath, '.claude', 'worktrees'),
      );
      if (stat.isDirectory()) {
        return true;
      }
    } catch {
      // Absent, not a directory, or inaccessible — check the next folder.
    }
  }

  return false;
}

/**
 * Read the workspace's current `files.watcherExclude` config, check for a
 * `.claude/worktrees` directory on disk, and compute which recommended
 * patterns are missing.
 */
export async function findMissingExcludes(): Promise<string[]> {
  const config = vscode.workspace.getConfiguration('files');
  // VS Code stores watcherExclude as Record<string, boolean>.
  const current = config.get<Record<string, boolean>>('watcherExclude') ?? {};

  const worktreesPresent = await hasClaudeWorktrees();

  return computeMissingExcludes(current, {
    hasClaudeWorktrees: worktreesPresent,
  });
}

/**
 * Read the set of patterns the user has already dismissed, honoring the
 * legacy all-or-nothing boolean flag for workspaces that dismissed before
 * `DISMISSED_PATTERNS_KEY` existed.
 *
 * Guard: corrupted workspaceState after a VS Code crash can throw on get;
 * treat that as "nothing dismissed" so the audit still fires.
 */
function getDismissedPatterns(context: vscode.ExtensionContext): string[] {
  try {
    const storedList = context.workspaceState.get<string[]>(
      DISMISSED_PATTERNS_KEY,
    );
    if (storedList) {
      return storedList;
    }

    // Legacy dismissal predates per-pattern tracking. Treat it as having
    // dismissed exactly the original unconditional patterns, so only the
    // new agent-worktree pattern (unknown at the time) can still re-prompt.
    if (context.workspaceState.get<boolean>(DISMISSED_KEY)) {
      return [...RECOMMENDED_EXCLUDES];
    }
  } catch {
    // workspaceState corrupted — fall through and treat as not dismissed.
  }

  return [];
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
 * Dismissal is per-pattern: a pattern the user has already dismissed stays
 * quiet, but a newly-relevant one (or one added to the recommended list
 * later) can still prompt.
 */
export async function auditWatcherExcludes(
  context: vscode.ExtensionContext,
): Promise<void> {
  const dismissed = getDismissedPatterns(context);

  const missing = await findMissingExcludes();
  const promptable = missing.filter((pattern) => !dismissed.includes(pattern));

  // Nothing left to recommend — the workspace covers everything the user
  // hasn't already dismissed.
  if (promptable.length === 0) {
    return;
  }

  const addAllLabel = l10n('systemHealth.watcherExclude.addAll');
  const dismissLabel = l10n('systemHealth.watcherExclude.dismiss');

  // Show an information notification with the two action buttons.
  const choice = await vscode.window.showInformationMessage(
    l10n('systemHealth.watcherExclude.prompt', {
      count: String(promptable.length),
      patterns: formatMissingList(promptable),
    }),
    addAllLabel,
    dismissLabel,
  );

  if (choice === addAllLabel) {
    await mergeWatcherExcludes(promptable);
    // Confirm the write so the user knows the patterns are now active.
    void vscode.window.showInformationMessage(
      l10n('systemHealth.watcherExclude.added', {
        count: String(promptable.length),
      }),
    );
  } else if (choice === dismissLabel) {
    // Suppress only the patterns offered this time; anything newly missing
    // later (a future recommended pattern, or worktrees appearing after
    // this run) can still prompt.
    try {
      const merged = [...new Set([...dismissed, ...promptable])];
      await context.workspaceState.update(DISMISSED_PATTERNS_KEY, merged);
    } catch {
      // workspaceState write failed — the prompt will simply reappear next
      // session, which is safe (if mildly repetitive).
    }
  }
  // If the user closes the notification without clicking either button,
  // do nothing — the audit will re-run next session.
}
