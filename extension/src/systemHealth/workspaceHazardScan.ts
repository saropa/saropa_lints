/**
 * One-shot workspace hazard scan for dangerously large files.
 *
 * Walks the workspace root for files that VS Code's file watcher will try to
 * track and that are large enough to crash it — a 2.2 GB `.hprof` caused the
 * 2026-09-05 VS Code crash because the watcher memory-mapped it. Flags known
 * hazard patterns above 50 MB and any file above 100 MB, warns when they are
 * NOT covered by `files.watcherExclude`, and offers a one-click fix.
 *
 * Runs once per session, deferred 10 s past activation. Disabled via
 * `saropaLints.systemHealth.workspaceHazardScan`.
 */

import * as vscode from 'vscode';
import * as fs from 'fs';
import * as path from 'path';
import { l10n } from '../i18n/runtime';
import { formatBytes } from './processQuery';
import { isCovered, mergeWatcherExcludes } from './watcherExcludeHelpers';

/** Known hazard patterns (heap dumps, crash logs) trigger at this bar. */
const HAZARD_THRESHOLD = 50 * 1024 * 1024;
/** Any file above this size is flagged regardless of extension. */
const GENERIC_THRESHOLD = 100 * 1024 * 1024;
/** Max directory depth — guards against symlink loops. */
const MAX_DEPTH = 8;

/** Directories always skipped — huge, irrelevant, or tracked elsewhere. */
const ALWAYS_SKIP: ReadonlySet<string> = new Set([
  'build', '.dart_tool', 'node_modules', '.git', 'reports', 'blobs',
]);

/** Known hazard name matchers — files matching these use the lower 50 MB bar. */
const KNOWN_HAZARDS: ReadonlyArray<(name: string) => boolean> = [
  (n) => n.endsWith('.hprof'),
  (n) => n === 'custom_lint.log',
  (n) => /^hs_err_pid\d*\.log$/.test(n),
  (n) => n.endsWith('.log'),
];

/** A file the scan flagged as a potential hazard. */
export interface HazardFile {
  /** Workspace-relative path (forward slashes) for display. */
  relative: string;
  /** Size in bytes. */
  size: number;
}

/**
 * Check a single file entry against the hazard thresholds. Returns a
 * HazardFile if the file exceeds its applicable bar, undefined otherwise.
 * Uses async stat to avoid blocking the extension host on large directories.
 */
async function checkFileHazard(
  entry: fs.Dirent,
  dir: string,
  root: string,
): Promise<HazardFile | undefined> {
  const isKnown = KNOWN_HAZARDS.some((test) => test(entry.name));
  const threshold = isKnown ? HAZARD_THRESHOLD : GENERIC_THRESHOLD;
  let size: number;
  try {
    const stat = await fs.promises.stat(path.join(dir, entry.name));
    size = stat.size;
  } catch {
    return undefined; // Stat failed — skip.
  }
  if (size < threshold) return undefined;
  const relative = path
    .relative(root, path.join(dir, entry.name))
    .replace(/\\/g, '/');
  return { relative, size };
}

/** Recursively collect files exceeding the hazard or generic threshold.
 *  Skips directories in ALWAYS_SKIP and respects MAX_DEPTH.
 *  Uses async fs operations to avoid blocking the extension host thread. */
async function collectHazards(
  dir: string,
  root: string,
  depth: number,
): Promise<HazardFile[]> {
  if (depth > MAX_DEPTH) return [];
  let entries: fs.Dirent[];
  try {
    entries = await fs.promises.readdir(dir, { withFileTypes: true });
  } catch {
    return []; // Permission denied or broken symlink — skip silently.
  }

  // Fan out subdirectory walks and file checks concurrently.
  const subDirs: Promise<HazardFile[]>[] = [];
  const fileChecks: Promise<HazardFile | undefined>[] = [];

  for (const entry of entries) {
    if (entry.isDirectory()) {
      if (ALWAYS_SKIP.has(entry.name.toLowerCase())) continue;
      subDirs.push(
        collectHazards(path.join(dir, entry.name), root, depth + 1),
      );
    } else if (entry.isFile()) {
      fileChecks.push(checkFileHazard(entry, dir, root));
    }
  }

  // Await all concurrently and flatten results.
  const [fileResults, ...subResults] = await Promise.all([
    Promise.all(fileChecks),
    ...subDirs,
  ]);
  const results: HazardFile[] = [];
  for (const hit of fileResults) {
    if (hit) results.push(hit);
  }
  for (const sub of subResults) {
    results.push(...(sub as HazardFile[]));
  }
  return results;
}

/** Build minimal glob patterns that cover the given files.
 *  Prefers extension-based globs (e.g. `**\/*.hprof`) over per-file entries. */
function buildExcludePatterns(files: readonly HazardFile[]): string[] {
  const patterns = new Set<string>();
  for (const f of files) {
    const ext = path.extname(f.relative);
    // Known hazard extensions get a broad glob; others get a literal path.
    if (ext === '.hprof' || ext === '.log') {
      patterns.add(`**/*${ext}`);
    } else {
      patterns.add(f.relative);
    }
  }
  return [...patterns].sort();
}

/** Show a warning listing uncovered hazard files with an action to
 *  add watcher exclude patterns for them. */
async function notifyUncovered(uncovered: readonly HazardFile[]): Promise<void> {
  const summary = uncovered
    .map((f) => `${f.relative} (${formatBytes(f.size)})`)
    .join(', ');
  const addLabel = l10n('systemHealth.hazardScan.addExclusions');
  const dismissLabel = l10n('systemHealth.hazardScan.dismiss');

  const choice = await vscode.window.showWarningMessage(
    l10n('systemHealth.hazardScan.warning', { count: String(uncovered.length), files: summary }),
    addLabel,
    dismissLabel,
  );
  if (choice === addLabel) {
    // Merge computed exclusion patterns via the shared helper.
    const patterns = buildExcludePatterns(uncovered);
    await mergeWatcherExcludes(patterns);
    void vscode.window.showInformationMessage(
      l10n('systemHealth.hazardScan.added', { count: String(patterns.length) }),
    );
  }
}

/**
 * Collect hazard files that are NOT covered by watcher excludes.
 * Pure data collection — no UI side effects. Returns an empty array when
 * the setting is disabled or no workspace folder is open.
 */
export async function getUncoveredHazards(): Promise<HazardFile[]> {
  const cfg = vscode.workspace.getConfiguration('saropaLints.systemHealth');
  if (!cfg.get<boolean>('workspaceHazardScan', true)) return [];

  const folder = vscode.workspace.workspaceFolders?.[0];
  if (!folder) return [];

  const root = folder.uri.fsPath;
  const hazards = await collectHazards(root, root, 0);
  if (hazards.length === 0) return [];

  // Filter to files not already covered by watcher excludes.
  const excludesCfg = vscode.workspace.getConfiguration('files');
  const excludes = excludesCfg.get<Record<string, boolean>>('watcherExclude') ?? {};
  return hazards.filter((f) => !isCovered(f.relative, excludes));
}

/** Run the workspace hazard scan. Called once from `activate()` via a
 *  deferred `setTimeout`. Checks the enable setting, walks the workspace
 *  root, and warns about any dangerously large unexcluded files. */
export async function scanWorkspaceForHazards(): Promise<void> {
  const uncovered = await getUncoveredHazards();
  if (uncovered.length === 0) return;

  await notifyUncovered(uncovered);
}
