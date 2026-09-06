/**
 * Map Drift Advisor table/column to Dart file and line for editor navigation.
 *
 * Heuristics: table names (snake_case) are converted to Dart class names (PascalCase);
 * column names to getter names (camelCase). We search workspace Dart files for
 * "class TableName extends Table" (or WithClassName<TableName>) and for "get columnName =>"
 * or "get columnName()". First match wins; no ambiguity resolution.
 *
 * PERFORMANCE / CRASH HISTORY (plans/history/2026.09/2026.09.05/infra_drift_poll_opens_every_dart_file_triggers_full_project_scan.md):
 * This module is driven by the Drift Advisor 30-second poll timer, not by user action. The
 * previous implementation resolved a table name by calling `vscode.workspace.openTextDocument()`
 * on EVERY Dart file in the workspace until a regex matched, and threw its cache away at the end
 * of each call. Two things went wrong:
 *   1. Every programmatic `openTextDocument` fires `onDidOpenTextDocument`. The scan-on-save
 *      controller treats that event as "the user opened a file" and queues a resolved
 *      full-project lint scan. In the contacts project (4598 Dart files) that cascade launched
 *      33 full-project `dart run saropa_lints scan --resolve` runs in 50 minutes, and two
 *      dart.exe processes reached 22 GB and 13 GB of commit memory before VS Code was killed by
 *      the low-virtual-memory condition. The same opens also pinned all 4598 files as priority
 *      files in the Dart analysis server.
 *   2. A table name that resolved to nothing re-walked the entire workspace on the next poll,
 *      forever, because the cache was local to one call.
 * The fixes below are therefore load-bearing, not optimizations: file content is read with
 * `vscode.workspace.fs.readFile` (a raw filesystem read that creates no VS Code document and
 * fires no document events), the table -> location map lives at module scope so a poll costs
 * nothing once warm, and a filesystem watcher clears that map when Dart sources actually change.
 * Do NOT reintroduce `openTextDocument` in this file.
 */

import * as vscode from 'vscode';
import type { DriftIssueRaw, DriftIssueMapped } from './types';

/** Resolved position of a Drift table class (or of one of its column getters). */
interface DartLocation {
  uri: vscode.Uri;
  line: number;
}

/**
 * Module-level table -> location cache, shared by every `mapIssuesToLocations` call.
 *
 * A `undefined` VALUE (with the key present) is a cached NEGATIVE result: the table name was
 * searched for and found nowhere. Caching negatives is the point — without it, an unresolvable
 * table re-walks the whole workspace on every 30-second poll. `has()` is therefore the presence
 * test; never use `get() === undefined` to decide whether to search.
 */
const tableLocationCache = new Map<string, DartLocation | undefined>();

/**
 * Cached result of the workspace Dart-file walk. `findFiles` itself is a full filesystem
 * traversal, so caching only the table map would still pay a directory walk every poll.
 * Invalidated by the same watcher that invalidates `tableLocationCache`.
 */
let cachedDartFiles: vscode.Uri[] | undefined;

/**
 * Monotonic generation counter, bumped by every cache invalidation.
 *
 * Guards a real race: both cache writes happen AFTER an `await` (the `findFiles` walk, and the
 * per-table file scan). If a watcher event fires while one of those awaits is in flight,
 * `resetTableLocationCache()` clears the caches and then the completing operation writes its
 * now-stale result straight back in — the invalidation is silently undone, and the stale entry
 * survives until the NEXT Dart edit. Every writer therefore snapshots this counter before its
 * await and refuses to write if the value moved. Do not remove the checks: a simple
 * "clear then write" is not safe in async code.
 */
let cacheGeneration = 0;

/**
 * Watcher that invalidates the caches above when Dart sources change. Created lazily on first
 * use rather than at activation, and kept in a module-level variable disposed by
 * `disposeTableLocationWatcher()`. Chosen over "return a disposable from every call" because
 * this module exposes plain async functions, not a class with a lifecycle — callers
 * (`extension.ts` poll timer, tree/view code) have nowhere natural to hold a per-call
 * disposable, and a per-call watcher would leak one watcher per poll.
 */
let dartFileWatcher: vscode.FileSystemWatcher | undefined;

/**
 * Listener that invalidates the caches when workspace folders appear or change.
 *
 * Separate from {@link dartFileWatcher} because it must be armed on a path where that watcher
 * cannot be: with no folder open there is nothing for a `**\/*.dart` watcher to observe, yet the
 * folder arriving later is exactly the event that makes previously unresolvable tables
 * resolvable. Without this, a session that started folderless keeps stale state until an edit.
 */
let workspaceFolderListener: vscode.Disposable | undefined;

/**
 * Arm the workspace-folder listener on first use.
 *
 * Guarded by a null check for hosts (and test mocks) that do not expose the event, so a missing
 * API degrades to "no extra invalidation" rather than throwing on the mapping path.
 */
function ensureWorkspaceFolderListener(): void {
  if (workspaceFolderListener) return;
  workspaceFolderListener = vscode.workspace.onDidChangeWorkspaceFolders?.(() =>
    resetTableLocationCache(),
  );
}

/**
 * Drop every cached table location and the cached file list.
 *
 * Exported so tests and any caller that knows the workspace changed (for example, after a branch
 * switch or a pub get) can force the next resolution to re-walk. Cheap: the next poll simply
 * pays one directory walk again.
 */
export function resetTableLocationCache(): void {
  tableLocationCache.clear();
  cachedDartFiles = undefined;
  // Bumping the generation is what makes any walk/resolution already in flight discard its
  // result instead of writing it back over this clear.
  cacheGeneration++;
}

/**
 * Dispose the lazily created Dart file watcher and clear the caches.
 *
 * Call from the extension's `deactivate` (or from a test's teardown) so the watcher does not
 * outlive the extension host. Safe to call when no watcher was ever created.
 */
export function disposeTableLocationWatcher(): void {
  dartFileWatcher?.dispose();
  dartFileWatcher = undefined;
  // The folder listener is armed on a different path (no workspace open) than the file watcher,
  // so it has to be torn down explicitly here too or it would outlive the extension host.
  workspaceFolderListener?.dispose();
  workspaceFolderListener = undefined;
  resetTableLocationCache();
}

/**
 * Create the Dart file watcher on first use.
 *
 * The watcher only invalidates caches; it never reads files, so a broad `**\/*.dart` glob is
 * cheap and avoids missing a table that lives outside `lib/`. Create/change/delete all clear the
 * cache: a create can introduce a table that is currently cached as a negative, a delete can
 * invalidate a cached hit, and a change can move a class to a different line.
 */
function ensureDartFileWatcher(): void {
  if (dartFileWatcher) return;
  dartFileWatcher = vscode.workspace.createFileSystemWatcher('**/*.dart');
  dartFileWatcher.onDidChange(() => resetTableLocationCache());
  dartFileWatcher.onDidCreate(() => resetTableLocationCache());
  dartFileWatcher.onDidDelete(() => resetTableLocationCache());
}

/** snake_case → PascalCase (e.g. users → Users, user_tasks → UserTasks). */
function toPascalCase(s: string): string {
  return s
    .split('_')
    .map((part) => (part.length > 0 ? part[0].toUpperCase() + part.slice(1).toLowerCase() : ''))
    .join('');
}

/** snake_case → camelCase (e.g. user_id → userId). */
function toCamelCase(s: string): string {
  const pascal = toPascalCase(s);
  return pascal.length > 0 ? pascal[0].toLowerCase() + pascal.slice(1) : s;
}

/**
 * Directories and generated files that can never contain a hand-written Drift table class.
 *
 * Deliberately an exclude list rather than a hard `lib/**` include: some projects keep tables in
 * a nested package under `packages/`, in `bin/`, or in a melos sub-project, and restricting to
 * `lib/` would silently stop resolving those (a false negative the user cannot diagnose). What is
 * excluded here is either machine-generated (`*.g.dart`, `*.freezed.dart` — Drift's generated
 * companions reference the table but never declare it), never source (`build/`, `.dart_tool/`,
 * `.symlinks/`, `.pub-cache/`), or by convention not application code (`test/`,
 * `integration_test/`, `dependency_overrides/`). Cutting these is what turns the 4598-file walk
 * in the crash report into a few hundred files.
 */
const DART_FILE_EXCLUDE_GLOB =
  '{**/build/**,**/.dart_tool/**,**/.symlinks/**,**/.pub-cache/**,' +
  '**/test/**,**/integration_test/**,**/dependency_overrides/**,' +
  '**/*.g.dart,**/*.freezed.dart,**/*.gen.dart,**/*.mocks.dart}';

/**
 * Find Dart files that might define Drift tables, memoized across polls.
 *
 * The 8000-file cap is unchanged from the original implementation (verified against
 * `git show HEAD:extension/src/driftAdvisor/mapper.ts`); it is a backstop for pathological
 * workspaces, and with the exclude list above a normal project stays far below it.
 */
async function findDartFiles(): Promise<vscode.Uri[] | undefined> {
  // Serve the memoized list when the watcher has not seen a Dart change since the last walk.
  if (cachedDartFiles) return cachedDartFiles;
  const folders = vscode.workspace.workspaceFolders;
  if (!folders?.length) {
    // "Could not search", NOT "searched and found nothing" — the distinction is load-bearing.
    // This path returns BEFORE `ensureDartFileWatcher`, so no watcher exists to invalidate
    // anything; a caller that cached the resulting negative would keep it for the whole session
    // and the table would never resolve once a folder finally appeared. `undefined` (rather than
    // an empty array) is what tells the caller the result is not cacheable. Arm the folder
    // listener so the folder arriving does clear whatever else is cached.
    ensureWorkspaceFolderListener();
    return undefined;
  }
  // Arm the invalidation watcher before the walk starts, so a change landing mid-walk bumps the
  // generation and the staleness check below throws this walk's result away.
  ensureDartFileWatcher();
  const generation = cacheGeneration;
  const out: vscode.Uri[] = [];
  for (const folder of folders) {
    const uris = await vscode.workspace.findFiles(
      new vscode.RelativePattern(folder, '**/*.dart'),
      DART_FILE_EXCLUDE_GLOB,
      8000,
    );
    out.push(...uris);
  }
  // Only publish the walk if nothing invalidated the cache while `findFiles` was awaiting;
  // otherwise this list already misses (or still contains) a file that just changed. The caller
  // still gets it for THIS resolution — a marginally stale answer once is fine — but it must not
  // be remembered for the next poll.
  if (generation === cacheGeneration) cachedDartFiles = out;
  return out;
}

/** Regex to find class Foo extends Table (or WithClassName<Foo>, etc.). */
function tableClassRegex(className: string): RegExp {
  const escaped = className.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
  return new RegExp(
    `\\bclass\\s+${escaped}\\s+extends\\s+(?:Table|\\w+\\s*<\\s*${escaped}\\s*>)`,
    'm',
  );
}

/** Regex to find getter for column (get columnName => or get columnName()). */
function columnGetterRegex(columnNameCamel: string): RegExp {
  const escaped = columnNameCamel.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
  return new RegExp(`\\bget\\s+${escaped}\\s*[=(]`, 'm');
}

/** Find line number (0-based) of first match of regex in text. */
function lineOfMatch(text: string, re: RegExp): number | undefined {
  const m = text.match(re);
  if (!m || m.index === undefined) return undefined;
  let line = 0;
  for (let i = 0; i < m.index && i < text.length; i++) {
    if (text[i] === '\n') line++;
  }
  return line;
}

/**
 * Read a file as UTF-8 text WITHOUT creating a VS Code text document.
 *
 * `vscode.workspace.fs.readFile` goes straight to the filesystem provider and raises no
 * `onDidOpenTextDocument`, so nothing downstream mistakes this bulk walk for the user opening
 * thousands of files. This is the single change that stops the scan cascade described at the top
 * of this file; `openTextDocument` must not come back here even "just for the one hit file".
 */
async function readFileText(uri: vscode.Uri): Promise<string | undefined> {
  try {
    const bytes = await vscode.workspace.fs.readFile(uri);
    return Buffer.from(bytes).toString('utf8');
  } catch {
    // Unreadable (deleted between the walk and the read, permission denied, binary provider):
    // skipping is correct — a missing candidate is not an error for a best-effort heuristic.
    return undefined;
  }
}

/**
 * Resolve table name to a Dart file and line (class declaration).
 * When files is provided, uses that list instead of calling findDartFiles() (avoids repeated scans).
 */
async function resolveTableToLocation(
  tableName: string,
  files?: vscode.Uri[],
): Promise<DartLocation | undefined> {
  const className = toPascalCase(tableName);
  const re = tableClassRegex(className);
  // `?? []` collapses the "could not search" case to an empty scan: this helper only reports a
  // location, and the cacheability decision belongs to the caller that owns the cache.
  const fileList = files ?? (await findDartFiles()) ?? [];
  for (const uri of fileList) {
    const text = await readFileText(uri);
    if (text === undefined) continue;
    // Cheap substring gate before the regex: the class name must appear literally in any file
    // that declares it, and a plain indexOf over a few hundred files is far cheaper than
    // compiling backtracking regex matches against each one.
    if (!text.includes(className)) continue;
    const line = lineOfMatch(text, re);
    if (line !== undefined) return { uri, line };
  }
  return undefined;
}

/**
 * Given the TEXT of a file containing a table class, find the line of a column getter (optional).
 * If column is null/blank, returns the table class line.
 *
 * Takes a string rather than a `vscode.TextDocument` precisely so the caller never has to open a
 * document to answer this. Line numbers stay 0-based and identical to the previous
 * `doc.positionAt`-free implementation, which already counted newlines in `lineOfMatch`.
 */
function resolveColumnInText(
  text: string,
  columnName: string | null,
  tableLine: number,
): number | undefined {
  if (!columnName || columnName.trim() === '') return tableLine;
  const camel = toCamelCase(columnName.trim());
  const re = columnGetterRegex(camel);
  const line = lineOfMatch(text, re);
  // Fall back to the class declaration line when the getter cannot be found: navigating to the
  // table is still useful, and is what the previous implementation did.
  return line ?? tableLine;
}

/**
 * Map a single raw issue to file/line when possible. Delegates to mapIssuesToLocations.
 */
export async function mapIssueToLocation(issue: DriftIssueRaw): Promise<DriftIssueMapped> {
  const mapped = await mapIssuesToLocations([issue]);
  return mapped[0] ?? { ...issue };
}

/**
 * Map all issues to locations.
 *
 * Both the file list and the table -> location map are module-level caches, so a warm poll does
 * no filesystem work at all when the issue set repeats (the common case: the Drift server keeps
 * reporting the same issues until the schema changes).
 */
export async function mapIssuesToLocations(issues: DriftIssueRaw[]): Promise<DriftIssueMapped[]> {
  // Lazy: only walk the filesystem if at least one table still needs resolving. An entirely
  // warm cache must not pay for a directory traversal.
  let files: vscode.Uri[] | undefined;
  const resolveTable = async (table: string): Promise<DartLocation | undefined> => {
    // `has` (not a truthiness check) so a cached negative short-circuits the walk too.
    if (tableLocationCache.has(table)) return tableLocationCache.get(table);
    // Snapshot BEFORE the file-list await, not just before the scan: the resolution is only as
    // valid as the list it searched, so an invalidation landing during the walk must also void
    // the location derived from that walk. Same race as in findDartFiles — the scan awaits many
    // reads, and an invalidation during it would be undone by the `set` afterwards.
    const generation = cacheGeneration;
    files ??= await findDartFiles();
    // Only a NEGATIVE that came from a real search is cacheable. An absent list (no workspace
    // folder yet) or an empty one means nothing was actually examined, and no watcher exists to
    // invalidate such an entry — caching it would permanently break navigation for this table
    // once a folder appeared. Returning undefined without a `set` costs one retry per poll,
    // which is exactly what the retry is for.
    if (!files || files.length === 0) return undefined;
    const located = await resolveTableToLocation(table, files);
    if (generation === cacheGeneration) tableLocationCache.set(table, located);
    return located;
  };

  /**
   * Per-call memo of file text, keyed by fsPath.
   *
   * Local to this call on purpose: file CONTENT must never be cached across polls, or an edit
   * between polls would be invisible until the watcher happened to fire. Within one call it is
   * safe and necessary — a table with 40 column issues would otherwise read and UTF-8 decode the
   * same file 40 times per poll. `undefined` entries memoize an unreadable file so a failing read
   * is not retried per issue either.
   */
  const textByPath = new Map<string, string | undefined>();
  const readTextOnce = async (uri: vscode.Uri): Promise<string | undefined> => {
    if (!textByPath.has(uri.fsPath)) textByPath.set(uri.fsPath, await readFileText(uri));
    return textByPath.get(uri.fsPath);
  };

  const result: DriftIssueMapped[] = [];
  for (const issue of issues) {
    const loc = await resolveTable(issue.table);
    const mapped: DriftIssueMapped = { ...issue };
    if (loc) {
      mapped.uri = { fsPath: loc.uri.fsPath };
      mapped.line = loc.line;
      if (issue.column) {
        // Read the one file that actually contains the table, via the filesystem so no document
        // event is raised, and through the per-call memo so that N issues on the same table cost
        // exactly one read and one decode for this poll rather than N.
        const text = await readTextOnce(loc.uri);
        if (text !== undefined) {
          const columnLine = resolveColumnInText(text, issue.column, loc.line);
          if (columnLine !== undefined) mapped.line = columnLine;
        }
        // If the file became unreadable, keep the table line — a slightly imprecise jump beats
        // no navigation at all.
      }
    }
    result.push(mapped);
  }
  return result;
}
