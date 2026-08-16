/**
 * Keep the sidebar's "Analyzer plugin" row — and the disable-ownership claim
 * behind it — honest against a file that anything can rewrite.
 *
 * The row reads the `plugins:` block straight off disk, but the tree only
 * rebuilds on discrete events, so a block changed outside the extension
 * (`dart run saropa_lints:init`, a git checkout, a hand-edit, a merge) left the
 * row asserting a state analysis_options.yaml contradicted. That silent drift
 * between what the UI claims and what the file says is the whole defect class
 * the row was added to close, so watching the file is what makes the row
 * trustworthy rather than merely usually-right.
 *
 * Lives in its own module rather than inline in activate() because it has to
 * track per-folder state across workspace-folder changes, which is more than a
 * block of activation code can carry legibly.
 */

import * as vscode from 'vscode';
import { getProjectRoot } from './projectRoot';
import { describePluginOwnership, reconcilePluginOwnership } from './setup';

/**
 * Trailing debounce before reacting to an analysis_options.yaml write.
 *
 * Same reasoning as the violations (300 ms) and pubspec.lock watchers: one
 * Enable rewrites this file twice in quick succession — the plugins-block
 * restore, then the `write_config` subprocess — and the command handler already
 * calls refreshAll() when it finishes. Reacting to each raw event would run
 * several redundant full refreshes (every provider plus the per-editor
 * annotation cache) for a single user action, which shows up as sidebar
 * flicker. The value is a deliberate over-estimate of that gap rather than a
 * measured one: everything this fires is idempotent and off the interactive
 * path, so erring long costs a slightly later row update and erring short costs
 * visible flicker.
 */
const OPTIONS_CHANGE_DEBOUNCE_MS = 500;

/**
 * Every folder whose analysis_options.yaml is worth watching.
 *
 * A multi-root window holds several independent Dart projects; each has its own
 * `plugins:` block and its own ownership claim, keyed by root. Watching only
 * `getProjectRoot()` (which resolves to exactly one folder) meant a second
 * root's block could be disabled by us and then silently drift with nothing
 * reconciling it. `getProjectRoot()` is still unioned in because it can resolve
 * to a nested project directory that is not itself a workspace folder.
 *
 * Known remaining gap: the sidebar row itself still renders a single root, so a
 * second root's state is reconciled but not displayed.
 */
function analyzerRoots(): string[] {
  const roots = new Set<string>();
  for (const folder of vscode.workspace.workspaceFolders ?? []) roots.add(folder.uri.fsPath);
  const primary = getProjectRoot();
  if (primary) roots.add(primary);
  return [...roots];
}

/** Build the watcher + debounce timer for one root, as a single disposable. */
function watchRoot(
  context: vscode.ExtensionContext,
  root: string,
  refreshAll: () => void,
  log: (message: string) => void,
): vscode.Disposable {
  const watcher = vscode.workspace.createFileSystemWatcher(
    new vscode.RelativePattern(root, 'analysis_options.yaml'),
  );

  let timer: ReturnType<typeof setTimeout> | undefined;
  const onChanged = () => {
    if (timer) clearTimeout(timer);
    timer = setTimeout(() => {
      timer = undefined;
      void (async () => {
        const cleared = await reconcilePluginOwnership(context, root);
        if (cleared) {
          log(`[saropa] plugins: block went live outside the extension (${root}) — cleared stale disable ownership.`);
        }
        refreshAll();
      })();
    }, OPTIONS_CHANGE_DEBOUNCE_MS);
  };

  watcher.onDidChange(onChanged);
  watcher.onDidCreate(onChanged);
  watcher.onDidDelete(onChanged);

  return {
    dispose: () => {
      if (timer) clearTimeout(timer);
      watcher.dispose();
    },
  };
}

/**
 * Register the analysis_options.yaml watchers and keep the set in sync with the
 * workspace.
 *
 * Re-registering on `onDidChangeWorkspaceFolders` closes a latent gap the
 * original inline version shared with `watchViolations()`: the root was
 * captured ONCE at activation, so a window opened empty (or on a folder added
 * a moment later — a common flow when VS Code restores a session) never got a
 * watcher at all, for the entire session, with no symptom other than a row that
 * quietly stopped updating.
 */
export function registerAnalyzerPluginWatchers(
  context: vscode.ExtensionContext,
  refreshAll: () => void,
  log: (message: string) => void,
): void {
  const active = new Map<string, vscode.Disposable>();

  const sync = () => {
    const wanted = new Set(analyzerRoots());
    // Drop watchers for folders that left the workspace.
    for (const [root, disposable] of active) {
      if (wanted.has(root)) continue;
      disposable.dispose();
      active.delete(root);
    }
    for (const root of wanted) {
      if (active.has(root)) continue;
      active.set(root, watchRoot(context, root, refreshAll, log));
      // Probe the ownership records once per newly-watched root. The restore
      // path fails silently when a record is lost, and that failure looks
      // exactly like the original bug, so this line is the only thing that
      // makes "the claim was never made" distinguishable from "the claim was
      // lost" in a bug report.
      log(describePluginOwnership(context, root));
    }
  };

  sync();
  context.subscriptions.push(
    vscode.workspace.onDidChangeWorkspaceFolders(sync),
    { dispose: () => { for (const d of active.values()) d.dispose(); active.clear(); } },
  );
}
