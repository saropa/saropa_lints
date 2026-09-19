/**
 * One-shot audit for git-ignored nested Dart analysis roots.
 *
 * A non-dot directory with a `pubspec.yaml` plus `.dart_tool/package_config.json`
 * (or `BUILD.gn`) becomes its own analysis context, even when git ignores it
 * (e.g. a scratch copy of the repo). Dot-folders such as `.claude/worktrees`
 * are never analyzed by the Dart analyzer and are not reported. This audit
 * warns once per workspace, offers a one-click fix covering `analysis_options.yaml`
 * `exclude`, `dart.analysisExcludedFolders` and `files.watcherExclude`, and
 * lets the user dismiss per folder (stored in `workspaceState`).
 */
import * as vscode from 'vscode';
import { l10n } from '../i18n/runtime';
import {
  discoverNestedPackageGroups,
  findUnexcludedNestedGroups,
  nestedGroupPattern,
} from '../analysisOptimizer/nestedRoots';
import {
  mergeExclusions,
  readAnalyzerExcludes,
  writeAnalyzerExcludes,
} from '../analysisOptimizer/analyzerExcludeYaml';
import type { NestedPackageGroup } from '../analysisOptimizer/types';
import { mergeWatcherExcludes } from './watcherExcludeHelpers';

const DISMISSED_KEY = 'nestedPackageRoots.dismissedFolders';

/** Folder -> group, for groups still unexcluded in one workspace root. */
export function findPendingNestedGroups(
  root: string,
  excludedFolders: readonly string[],
): NestedPackageGroup[] {
  return findUnexcludedNestedGroups(
    discoverNestedPackageGroups(root),
    readAnalyzerExcludes(root),
    excludedFolders,
  );
}

/** Adds `folders` to the workspace `dart.analysisExcludedFolders` setting. */
async function mergeExcludedFolders(folders: readonly string[]): Promise<void> {
  const config = vscode.workspace.getConfiguration('dart');
  const current = config.get<string[]>('analysisExcludedFolders') ?? [];
  const merged = [...new Set([...current, ...folders])];
  await config.update('analysisExcludedFolders', merged, vscode.ConfigurationTarget.Workspace);
}

/** Applies the three-way exclusion for `groups` under `root`. */
export async function applyNestedRootFix(
  root: string,
  groups: readonly NestedPackageGroup[],
): Promise<void> {
  const folders = groups.map(g => g.folder);
  const patterns = groups.map(nestedGroupPattern);
  // analysis_options.yaml may not exist; the other two still apply.
  writeAnalyzerExcludes(root, mergeExclusions(readAnalyzerExcludes(root), patterns));
  await mergeExcludedFolders(folders);
  await mergeWatcherExcludes(folders.map(f => `**/${f}/**`));
}

function getDismissed(context: vscode.ExtensionContext): string[] {
  try {
    return context.workspaceState.get<string[]>(DISMISSED_KEY) ?? [];
  } catch {
    return [];
  }
}

export async function auditNestedPackageRoots(
  context: vscode.ExtensionContext,
): Promise<void> {
  const workspaceFolders = vscode.workspace.workspaceFolders;
  if (!workspaceFolders) return;
  const dismissed = getDismissed(context);
  const excludedFolders =
    vscode.workspace.getConfiguration('dart').get<string[]>('analysisExcludedFolders') ?? [];

  for (const wf of workspaceFolders) {
    const root = wf.uri.fsPath;
    let pending: NestedPackageGroup[];
    try {
      pending = findPendingNestedGroups(root, excludedFolders)
        .filter(g => !dismissed.includes(g.folder));
    } catch {
      continue; // a filesystem hiccup must not crash activation
    }
    if (pending.length === 0) continue;

    const total = pending.reduce((n, g) => n + g.contextCount, 0);
    const fixLabel = l10n('systemHealth.nestedRoots.fix');
    const dismissLabel = l10n('systemHealth.nestedRoots.dismiss');
    const choice = await vscode.window.showWarningMessage(
      l10n('systemHealth.nestedRoots.prompt', {
        folders: pending.map(g => g.folder).join(', '),
        count: String(total),
      }),
      fixLabel,
      dismissLabel,
    );
    if (choice === fixLabel) {
      await applyNestedRootFix(root, pending);
      void vscode.window.showInformationMessage(
        l10n('systemHealth.nestedRoots.fixed', { folders: pending.map(g => g.folder).join(', ') }),
      );
    } else if (choice === dismissLabel) {
      try {
        await context.workspaceState.update(
          DISMISSED_KEY,
          [...new Set([...dismissed, ...pending.map(g => g.folder)])],
        );
      } catch {
        // will simply re-prompt next session
      }
    }
  }
}
