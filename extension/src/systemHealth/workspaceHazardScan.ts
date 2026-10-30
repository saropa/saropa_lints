/**
 * One-shot workspace hazard scan for dangerously large files.
 *
 * Walks the workspace root for folders with too many files and files that VS Code's file watcher will try to
 * track and that are large enough to crash it — a 2.2 GB `.hprof` caused the
 * 2026-09-05 VS Code crash because the watcher memory-mapped it. Flags known
 * hazard patterns above 50 MB and any file above `saropaLints.watcherExclude.maxFileKb`, warns when they are
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
import { getProjectRoot } from '../projectRoot';

/** Known hazard patterns (heap dumps, crash logs) trigger at this bar. */
const HAZARD_THRESHOLD = 50 * 1024 * 1024;
/** Defaults for `saropaLints.watcherExclude.maxFileKb` / `maxFolderFiles`. */
const DEFAULT_MAX_FILE_KB = 5120;
const DEFAULT_MAX_FOLDER_FILES = 1000;

/** Scan limits resolved from settings. */
interface ScanLimits {
  /** Size bar in bytes applied to any file. */
  fileBytes: number;
  /** Max direct files per folder before the folder is flagged. */
  folderFiles: number;
}
/** Max directory depth — guards against symlink loops. */
const MAX_DEPTH = 8;

/** Directories always skipped — huge, irrelevant, or tracked elsewhere. */
const ALWAYS_SKIP: ReadonlySet<string> = new Set([
  'build', '.dart_tool', 'node_modules', '.git', 'reports', 'blobs',
  '.gradle', 'pods', 'deriveddata', '.venv',
]);

/** True for `.claude/worktrees` — agent copies of the repo, not workspace content. */
function isAgentWorktreesDir(parent: string, name: string): boolean {
  return name.toLowerCase() === 'worktrees' && path.basename(parent).toLowerCase() === '.claude';
}

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
  /** Size in bytes (0 for folder hazards). */
  size: number;
  /** Set for folder hazards: direct file count. `relative` is the folder. */
  fileCount?: number;
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
  limits: ScanLimits,
): Promise<HazardFile | undefined> {
  const isKnown = KNOWN_HAZARDS.some((test) => test(entry.name));
  const threshold = isKnown
    ? Math.min(HAZARD_THRESHOLD, limits.fileBytes)
    : limits.fileBytes;
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
  limits: ScanLimits,
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
      if (isAgentWorktreesDir(dir, entry.name)) continue;
      subDirs.push(
        collectHazards(path.join(dir, entry.name), root, depth + 1, limits),
      );
    } else if (entry.isFile()) {
      fileChecks.push(checkFileHazard(entry, dir, root, limits));
    }
  }

  // Await all concurrently and flatten results.
  const [fileResults, ...subResults] = await Promise.all([
    Promise.all(fileChecks),
    ...subDirs,
  ]);
  const results: HazardFile[] = [];
  // Direct children only (not recursive) keeps the count cheap. Root is never flagged.
  const fileCount = entries.filter((e) => e.isFile()).length;
  if (dir !== root && limits.folderFiles > 0 && fileCount > limits.folderFiles) {
    results.push({
      relative: path.relative(root, dir).replace(/\\/g, '/'),
      size: 0,
      fileCount,
    });
  }
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
export function buildExcludePatterns(files: readonly HazardFile[]): string[] {
  const patterns = new Set<string>();
  for (const f of files) {
    if (f.fileCount !== undefined) {
      patterns.add(`${f.relative}/**`);
      continue;
    }
    if (f.relative.split('/').includes('.gradle')) {
      patterns.add('**/.gradle/**');
      continue;
    }
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

/** Max files named in the warning; the rest are summarized as "and N more". */
const MAX_LISTED = 3;

/** Build the {files} text: at most MAX_LISTED entries plus "and N more". */
export function summarizeHazards(uncovered: readonly HazardFile[]): string {
  const listed = uncovered
    .slice(0, MAX_LISTED)
    .map((f) =>
      f.fileCount === undefined
        ? `${f.relative} (${formatBytes(f.size)})`
        : `${f.relative}/ (${f.fileCount} files)`,
    );
  const extra = uncovered.length - MAX_LISTED;
  if (extra > 0) {
    listed.push(l10n('systemHealth.hazardScan.andMore', { count: String(extra) }));
  }
  return listed.join(', ');
}

/** Show a warning listing uncovered hazard files with an action to
 *  add watcher exclude patterns for them. */
async function notifyUncovered(uncovered: readonly HazardFile[]): Promise<void> {
  const summary = summarizeHazards(uncovered);
  const folder =
    path.basename(vscode.workspace.workspaceFolders?.[0]?.uri.fsPath ?? '') ||
    l10n('systemHealth.hazardScan.unnamedFolder');
  const addLabel = l10n('systemHealth.hazardScan.addExclusions');
  const dismissLabel = l10n('systemHealth.hazardScan.dismiss');

  const choice = await vscode.window.showWarningMessage(
    l10n('systemHealth.hazardScan.warning', { count: String(uncovered.length), folder, files: summary }),
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
  lastUncovered = await computeUncoveredHazards();
  return lastUncovered;
}

/** Most recent result of {@link getUncoveredHazards}, so UI can reuse it without rescanning. */
let lastUncovered: HazardFile[] | undefined;
export function getLastUncoveredHazards(): HazardFile[] | undefined {
  return lastUncovered;
}

async function computeUncoveredHazards(): Promise<HazardFile[]> {
  const cfg = vscode.workspace.getConfiguration('saropaLints.systemHealth');
  if (!cfg.get<boolean>('workspaceHazardScan', true)) return [];
  // The watcher-crash hazards this scan targets are Dart/Flutter tooling output;
  // other workspaces (web, Python) only produced false alarms on media assets.
  if (getProjectRoot() === undefined) return [];

  const folder = vscode.workspace.workspaceFolders?.[0];
  if (!folder) return [];

  const root = folder.uri.fsPath;
  const wcfg = vscode.workspace.getConfiguration('saropaLints.watcherExclude');
  const limits: ScanLimits = {
    fileBytes: Math.max(1, wcfg.get<number>('maxFileKb', DEFAULT_MAX_FILE_KB)) * 1024,
    folderFiles: wcfg.get<number>('maxFolderFiles', DEFAULT_MAX_FOLDER_FILES),
  };
  const hazards = await collectHazards(root, root, 0, limits);
  if (hazards.length === 0) return [];

  // Filter to files not already covered by watcher excludes.
  const excludesCfg = vscode.workspace.getConfiguration('files');
  const excludes = excludesCfg.get<Record<string, boolean>>('watcherExclude') ?? {};
  return hazards.filter((f) =>
    !isCovered(f.fileCount === undefined ? f.relative : `${f.relative}/`, excludes),
  );
}

/** Run the workspace hazard scan. Called once from `activate()` via a
 *  deferred `setTimeout`. Checks the enable setting, walks the workspace
 *  root, and warns about any dangerously large unexcluded files. */
export async function scanWorkspaceForHazards(): Promise<void> {
  const uncovered = await getUncoveredHazards();
  if (uncovered.length === 0) return;

  await notifyUncovered(uncovered);
}
