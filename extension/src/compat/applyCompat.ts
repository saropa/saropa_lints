/**
 * Pure Apply flow for a version recommendation: snapshot the files (including pubspec.lock), write the
 * edits, resolve, align the plugin version to the exact locked version, then
 * re-initialize the config. If dependency resolution fails (or is cancelled)
 * both files are restored to the snapshot. All I/O is injected, so this module
 * has no `vscode` or `fs` dependency and is unit-tested directly.
 */
import { applyRecommendation, type ConfigFiles, type Recommendation } from './configEdits';

export interface ApplyPaths {
  pubspec: string;
  analysisOptions: string;
  /** pubspec.lock; snapshotted and restored with the other files when present. */
  lock?: string;
}

export interface ApplyDeps {
  /** File text, or undefined when the file does not exist. */
  read(file: string): string | undefined;
  write(file: string, text: string): void;
  /** Runs pub get. */
  resolve(): Promise<{ ok: boolean; stderr: string; cancelled: boolean }>;
  /** The saropa_lints version in pubspec.lock after resolve. */
  readLockedVersion(): Promise<string | undefined>;
  initializeConfig(): Promise<void>;
}

export type ApplyOutcome =
  | { status: 'noChange' }
  | { status: 'applied'; version?: string }
  | { status: 'failed'; reason: string; restored: boolean }
  | { status: 'cancelled'; restored: boolean };

export interface FileEdit {
  file: string;
  before: string;
  after: string;
}

/** Files whose text would change; used by Preview and Apply. */
export function planEdits(
  deps: Pick<ApplyDeps, 'read'>,
  paths: ApplyPaths,
  rec: Recommendation,
): FileEdit[] {
  const files: ConfigFiles = {
    pubspec: deps.read(paths.pubspec),
    analysisOptions: deps.read(paths.analysisOptions),
  };
  const out = applyRecommendation(files, rec);
  const edits: FileEdit[] = [];
  if (files.pubspec !== undefined && out.pubspec !== undefined && out.pubspec !== files.pubspec) {
    edits.push({ file: paths.pubspec, before: files.pubspec, after: out.pubspec });
  }
  if (
    files.analysisOptions !== undefined &&
    out.analysisOptions !== undefined &&
    out.analysisOptions !== files.analysisOptions
  ) {
    edits.push({ file: paths.analysisOptions, before: files.analysisOptions, after: out.analysisOptions });
  }
  return edits;
}

/** Writes the snapshot back; false when any restore write throws. */
function restore(deps: ApplyDeps, snaps: Snapshot[]): boolean {
  let ok = true;
  for (const e of snaps) {
    try {
      deps.write(e.file, e.before);
    } catch {
      ok = false;
    }
  }
  return ok;
}

interface Snapshot {
  file: string;
  before: string;
}

export async function applyCompatibility(
  deps: ApplyDeps,
  paths: ApplyPaths,
  rec: Recommendation,
): Promise<ApplyOutcome> {
  const edits = planEdits(deps, paths, rec);
  if (edits.length === 0) return { status: 'noChange' };

  // pub get rewrites the lock, so it is part of the snapshot when it exists.
  const snaps: Snapshot[] = edits.map((e) => ({ file: e.file, before: e.before }));
  const lockBefore = paths.lock ? deps.read(paths.lock) : undefined;
  if (paths.lock && lockBefore !== undefined) snaps.push({ file: paths.lock, before: lockBefore });

  // Any throw after the first write puts every file back.
  try {
    for (const e of edits) deps.write(e.file, e.after);

    // A plugin-only change has no dependency to resolve.
    if (!rec.constraint) {
      await deps.initializeConfig();
      return { status: 'applied', version: rec.pluginVersion };
    }

    let res: { ok: boolean; stderr: string; cancelled: boolean };
    try {
      res = await deps.resolve();
    } catch (err) {
      res = { ok: false, stderr: err instanceof Error ? err.message : String(err), cancelled: false };
    }
    if (res.cancelled) return { status: 'cancelled', restored: restore(deps, snaps) };
    if (!res.ok) {
      return { status: 'failed', reason: res.stderr, restored: restore(deps, snaps) };
    }

    // The plugin entry must name the exact version pub locked.
    const locked = await deps.readLockedVersion();
    if (locked) {
      const current = deps.read(paths.analysisOptions);
      if (current !== undefined) {
        const next = applyRecommendation({ analysisOptions: current }, { pluginVersion: locked }).analysisOptions;
        if (next !== undefined && next !== current) deps.write(paths.analysisOptions, next);
      }
    }

    await deps.initializeConfig();
    return { status: 'applied', version: locked ?? rec.pluginVersion };
  } catch (err) {
    return {
      status: 'failed',
      reason: err instanceof Error ? err.message : String(err),
      restored: restore(deps, snaps),
    };
  }
}
