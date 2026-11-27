/**
 * Plans where "Check Accepted Findings" runs the scan CLI: which folders to
 * check, and from which folder to launch `dart run saropa_lints:scan`.
 *
 * Pure (file probes are injected) so it is unit-tested without the editor.
 *
 * Why a plan and not "every folder that depends on saropa_lints": the check
 * used to skip two cases. A workspace folder whose `pubspec.yaml` sits one
 * level down (`app/pubspec.yaml`) was tested at the folder itself and found
 * no dependency. A folder whose package does not list saropa_lints (it can
 * still use the analyzer plugin through `analysis_options.yaml`) could not
 * host `dart run saropa_lints:scan`. The scan CLI takes its target as an
 * argument and resolves it with the target's own package config, so such a
 * folder is checked by launching the CLI from a folder that has the package.
 */
import * as path from 'node:path';
import { ACCEPTED_FILE_NAME } from './acceptedFindingsModel';
import { INTEGRATION_OFF_SENTINEL } from './integrationOffSentinel';

/** File probes the planner needs; production passes fs-backed versions. */
export interface CheckRootProbes {
  /** Package root for a workspace folder: the folder or one level down. */
  projectRootIn(folder: string): string | undefined;
  /** True when [root]'s pubspec.yaml lists (or is) saropa_lints. */
  hasDep(root: string): boolean;
  /** True when [file] exists. */
  exists(file: string): boolean;
  /** File text, or undefined when unreadable. */
  read(file: string): string | undefined;
}

/** One CLI run: launch from [host], check every list under [target]. */
export interface CheckRun {
  host: string;
  target: string;
}

/**
 * True when [root] is worth a resolved scan without listing saropa_lints in
 * its pubspec: it has a list beside its pubspec, or its analysis options
 * enable the saropa_lints plugin (live, or commented out by this extension).
 * Without this gate every unrelated folder in
 * a multi-root workspace would cost a full scan that can find nothing.
 */
function usesSaropa(root: string, probes: CheckRootProbes): boolean {
  if (probes.exists(path.join(root, ACCEPTED_FILE_NAME))) return true;
  const options = probes.read(path.join(root, 'analysis_options.yaml'));
  if (options === undefined) return false;
  // Indented key: the plugin entry under `plugins:`.
  if (/^\s+saropa_lints\s*:/m.test(options)) return true;
  // With the language server on (the default) the extension comments that
  // block out; the project still uses the plugin's rules. Requires the marker
  // so a hand-written commented example does not cost a scan.
  return options.includes(INTEGRATION_OFF_SENTINEL) && /^#\s+saropa_lints\s*:/m.test(options);
}

/**
 * The runs for [folders] (workspace folder paths, first one first). Returns
 * an empty list when no folder has saropa_lints as a dependency, because no
 * folder can host the CLI; the caller reports that as a missing dependency.
 */
export function planCheckRuns(folders: readonly string[], probes: CheckRootProbes): CheckRun[] {
  const roots = [...new Set(
    folders
      .map((f) => probes.projectRootIn(f))
      .filter((r): r is string => !!r)
      .map((r) => path.resolve(r)),
  )];
  // Any root with the package can host runs for roots without it, including
  // a nested one: an outer plugin-only folder is then scanned from inside.
  const host = roots.find((r) => probes.hasDep(r));
  if (host === undefined) return [];
  // Decide which roots will actually run BEFORE removing nested ones. The
  // old order dropped every nested root first and filtered by dependency
  // after, so an outer folder without saropa_lints discarded an inner
  // package that has it, and that package was never checked.
  const runnable = roots.filter((r) => probes.hasDep(r) || usesSaropa(r, probes));
  // A root inside another runnable root is dropped: the CLI already checks
  // every list under its target, so scanning both would report nested lists
  // twice. A root inside a folder that will not run is kept.
  const kept = runnable.filter((r) => !runnable.some((o) => o !== r && isInside(o, r)));
  return kept.map((target) => ({
    host: probes.hasDep(target) ? target : host,
    target,
  }));
}

/** True when [child] is strictly inside [parent]. */
function isInside(parent: string, child: string): boolean {
  const rel = path.relative(parent, child);
  return !!rel && !rel.startsWith('..') && !path.isAbsolute(rel);
}
