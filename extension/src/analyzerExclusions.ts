/**
 * Extension-native check: suggests excluding folders that need no analysis
 * from the Dart analysis server (`dart.analysisExcludedFolders` in
 * `.vscode/settings.json`), because slow quick fixes and high analysis-server
 * memory grow with the number of analyzed files.
 *
 * Design: `bugs/proposal_infra_analyzer_exclude_folders_check.md`. This reads
 * non-Dart files and the folder tree, so the Dart AST engine cannot do it.
 *
 * Layout: the first half is pure (no `vscode`, no fs) so it can be unit
 * tested with injected inputs; the second half gathers the real inputs,
 * publishes diagnostics on its own collection, and offers the quick action.
 * The quick action only ever edits `dart.analysisExcludedFolders` and never
 * touches `analysis_options.yaml`.
 */
import * as fs from 'node:fs';
import * as os from 'node:os';
import * as path from 'node:path';
import * as vscode from 'vscode';
import { l10n } from './i18n/runtime';

// ── Pure logic ─────────────────────────────────────────────────

/** Folders worth excluding when present (relative to the workspace folder). */
export const CANDIDATE_FOLDERS: readonly string[] = [
  'android', 'ios', 'macos', 'windows', 'linux', 'web',
  'build', '.dart_tool', 'coverage',
  'dependency_overrides', 'third_party', 'vendor',
  'docs', 'doc', 'bugs', 'plans', 'reports', 'scripts',
  'assets',
  '.claude/worktrees',
];

/** First-party code folders: never suggested, never reported as drift. */
const NEVER_FOLDERS: readonly string[] = ['lib', 'test', 'integration_test', 'bin'];

/** Analyzed-file count above which the large-workspace finding applies. */
export const FILE_COUNT_THRESHOLD = 3000;
/** RAM (GB, rounded) at or below which the large-workspace finding names RAM. */
export const LOW_RAM_GB = 8;

export type FindingKind =
  | 'missing' // candidate not in dart.analysisExcludedFolders
  | 'driftOnly' // in analyzer: exclude: but not in dart.analysisExcludedFolders
  | 'largeWorkspace' // many analyzed files (and low RAM when known)
  | 'imported'; // candidate, but first-party code depends on it

export interface ExclusionFinding {
  readonly kind: FindingKind;
  /** Folder the finding is about (absent for `largeWorkspace`). */
  readonly folder?: string;
  /** `largeWorkspace` only. */
  readonly fileCount?: number;
  /** `largeWorkspace` only; undefined when RAM could not be read. */
  readonly ramGb?: number;
}

export interface ExclusionInputs {
  /** Existing directories: top-level names, plus `.claude/worktrees` if present. */
  readonly existingFolders: readonly string[];
  /** Dart file count per entry of `existingFolders`. */
  readonly dartFileCounts: Readonly<Record<string, number>>;
  /**
   * Dart file count per nested entry of `settingsExcluded` (for example
   * `lib/generated`), so the analyzed total can subtract them.
   */
  readonly nestedExcludedCounts?: Readonly<Record<string, number>>;
  /** Entries of `dart.analysisExcludedFolders`. */
  readonly settingsExcluded: readonly string[];
  /** Plain-folder entries of `analyzer: exclude:` (see `parseAnalyzerExclude`). */
  readonly analysisOptionsExcluded: readonly string[];
  /** Local `path:` dependency targets (see `parsePathDependencies`). */
  readonly pathDependencies: readonly string[];
  /** Total system RAM in GB, or undefined when unavailable. */
  readonly ramGb?: number;
  readonly fileThreshold?: number;
}

/** Normalizes a folder path: forward slashes, no leading `./`, no trailing `/`. */
export function normalizeFolder(p: string): string {
  let s = p.trim().replace(/\\/g, '/');
  while (s.startsWith('./')) s = s.slice(2);
  return s.replace(/\/+$/, '');
}

/** True when `folder` equals an entry or sits under one. */
function isCovered(folder: string, entries: readonly string[]): boolean {
  return entries.some((e) => {
    const n = normalizeFolder(e);
    return n !== '' && (folder === n || folder.startsWith(`${n}/`));
  });
}

/**
 * Reads plain folder entries from the `analyzer: exclude:` list. A trailing
 * `/**` or `/*` is stripped; entries with other glob characters (for example
 * `**` + `/*.g.dart`) are not folders and are dropped.
 */
export function parseAnalyzerExclude(yaml: string): string[] {
  const out: string[] = [];
  let inAnalyzer = false;
  let inExclude = false;
  for (const raw of yaml.split(/\r?\n/)) {
    const line = raw.replace(/\s+#.*$/, '');
    if (line.trim() === '' || line.trim().startsWith('#')) continue;
    const indent = line.length - line.trimStart().length;
    if (indent === 0) {
      inAnalyzer = /^analyzer:\s*$/.test(line);
      inExclude = false;
      continue;
    }
    if (!inAnalyzer) continue;
    if (/^\s+exclude:\s*$/.test(line)) { inExclude = true; continue; }
    const inline = /^\s+exclude:\s*\[(.*)\]\s*$/.exec(line);
    if (inline) {
      inExclude = false;
      for (const item of inline[1].split(',')) addExcludeEntry(out, item);
      continue;
    }
    const item = /^\s*-\s*(.+)$/.exec(line);
    if (inExclude && item) { addExcludeEntry(out, item[1]); continue; }
    // Another key under analyzer: ends the exclude list.
    if (/^\s+\S+:/.test(line)) inExclude = false;
  }
  return out;
}

function addExcludeEntry(out: string[], rawItem: string): void {
  const unquoted = rawItem.trim().replace(/^['"]|['"]$/g, '');
  const folder = normalizeFolder(unquoted.replace(/\/\*{1,2}$/, ''));
  if (folder !== '' && !/[*?[\]{}]/.test(folder)) out.push(folder);
}

/**
 * Reads local `path:` targets from the `dependencies` and `dev_dependencies`
 * sections of pubspec.yaml (not `dependency_overrides`: those are resolution
 * pins, not something first-party code declares it needs). Targets are
 * returned relative to the pubspec folder.
 */
export function parsePathDependencies(pubspec: string): string[] {
  const out: string[] = [];
  let inDeps = false;
  for (const raw of pubspec.split(/\r?\n/)) {
    const line = raw.replace(/\s+#.*$/, '');
    if (line.trim() === '') continue;
    if (!line.startsWith(' ') && !line.startsWith('\t')) {
      inDeps = /^(dependencies|dev_dependencies):\s*$/.test(line);
      continue;
    }
    if (!inDeps) continue;
    const m = /\bpath:\s*['"]?([^\s,}'"]+)/.exec(line);
    if (m) out.push(path.posix.normalize(normalizeFolder(m[1])));
  }
  return out;
}

/** Produces the findings for one workspace folder from injected inputs. */
export function evaluateAnalyzerExclusions(i: ExclusionInputs): ExclusionFinding[] {
  const findings: ExclusionFinding[] = [];
  const existing = i.existingFolders.map(normalizeFolder);
  const isImported = (f: string): boolean =>
    i.pathDependencies.some((d) => d === f || d.startsWith(`${f}/`));

  for (const folder of existing) {
    if (NEVER_FOLDERS.includes(folder)) continue;
    if (isCovered(folder, i.settingsExcluded)) continue;
    const isCandidate = CANDIDATE_FOLDERS.includes(folder);
    const inOptions = isCovered(folder, i.analysisOptionsExcluded);
    if (!isCandidate && !inOptions) continue;
    if (isImported(folder)) {
      findings.push({ kind: 'imported', folder });
    } else {
      findings.push({ kind: inOptions ? 'driftOnly' : 'missing', folder });
    }
  }

  const uncovered = existing.filter((f) => !isCovered(f, i.settingsExcluded));
  const topLevel = uncovered.reduce((sum, f) => sum + (i.dartFileCounts[f] ?? 0), 0);
  // Nested excluded folders (e.g. lib/generated) inside a still-analyzed folder.
  const entries = Object.keys(i.nestedExcludedCounts ?? {}).map(normalizeFolder);
  const nestedExcluded = entries
    .filter((n) => uncovered.some((f) => n.startsWith(`${f}/`)))
    // Skip an entry nested inside another listed entry (avoid double subtraction).
    .filter((n) => !entries.some((o) => o !== n && n.startsWith(`${o}/`)))
    .reduce((sum, n) => sum + (i.nestedExcludedCounts?.[n] ?? 0), 0);
  const analyzed = Math.max(0, topLevel - nestedExcluded);
  const threshold = i.fileThreshold ?? FILE_COUNT_THRESHOLD;
  if (analyzed > threshold) {
    // Edge case 5: RAM unknown -> report the file count only.
    if (i.ramGb === undefined) {
      findings.push({ kind: 'largeWorkspace', fileCount: analyzed });
    } else if (i.ramGb <= LOW_RAM_GB) {
      findings.push({ kind: 'largeWorkspace', fileCount: analyzed, ramGb: i.ramGb });
    }
  }
  return findings;
}

/** Folders a quick action may add (findings 1 and 2). */
export function addableFolders(findings: readonly ExclusionFinding[]): string[] {
  return findings
    .filter((f) => (f.kind === 'missing' || f.kind === 'driftOnly') && f.folder)
    .map((f) => f.folder as string);
}

/** Run token: only the latest run may publish results; older runs are dropped. */
export class RunToken {
  private _latest = 0;
  /** Starts a new run and returns its id. */
  next(): number { return ++this._latest; }
  isLatest(id: number): boolean { return id === this._latest; }
}

// ── Extension wiring ───────────────────────────────────────────

const SETTING_SECTION = 'saropaLints.analyzerExclusions';
const DIAGNOSTIC_CODE = 'analyzer_exclusions';
const ADD_COMMAND = 'saropaLints.analyzerExclusions.addFolders';
const WATCHED_FILES = new Set(['analysis_options.yaml', 'settings.json', 'pubspec.yaml']);
const SKIP_WALK = new Set(['.git', 'node_modules']);

interface FolderState {
  readonly folderUri: vscode.Uri;
  readonly findings: ExclusionFinding[];
  readonly hasSettingsFile: boolean;
}

let _collection: vscode.DiagnosticCollection | undefined;
/** Latest findings per workspace folder (keyed by folder uri string). */
const _state = new Map<string, FolderState>();
const _runs = new RunToken();

function isEnabled(): boolean {
  return vscode.workspace.getConfiguration(SETTING_SECTION).get<boolean>('enabled', true);
}

function readText(file: string): string {
  try { return fs.readFileSync(file, 'utf8'); } catch { return ''; }
}

/** Counts `.dart` files under `dir`, skipping symlinks and VCS/node folders. */
async function countDartFiles(dir: string): Promise<number> {
  let count = 0;
  let entries: fs.Dirent[];
  try { entries = await fs.promises.readdir(dir, { withFileTypes: true }); } catch { return 0; }
  for (const e of entries) {
    if (e.isSymbolicLink() || SKIP_WALK.has(e.name)) continue;
    if (e.isDirectory()) count += await countDartFiles(path.join(dir, e.name));
    else if (e.name.endsWith('.dart')) count++;
  }
  return count;
}

/** Top-level directories (except `.claude`) plus `.claude/worktrees` when present. */
async function listFolders(root: string): Promise<string[]> {
  let entries: fs.Dirent[];
  try { entries = await fs.promises.readdir(root, { withFileTypes: true }); } catch { return []; }
  const out = entries
    .filter((e) => e.isDirectory() && !e.isSymbolicLink() && e.name !== '.claude' && !SKIP_WALK.has(e.name))
    .map((e) => e.name);
  if (fs.existsSync(path.join(root, '.claude', 'worktrees'))) out.push('.claude/worktrees');
  return out;
}

function ramGb(): number | undefined {
  const bytes = os.totalmem();
  return Number.isFinite(bytes) && bytes > 0 ? Math.round(bytes / 1024 ** 3) : undefined;
}

export function findingMessage(f: ExclusionFinding, hasSettingsFile: boolean): string {
  const folder = f.folder ?? '';
  switch (f.kind) {
    case 'missing':
      return l10n(hasSettingsFile ? 'analyzerExclusions.diagnostic.missing' : 'analyzerExclusions.diagnostic.missingCreate', { folder });
    case 'driftOnly':
      return l10n('analyzerExclusions.diagnostic.driftOnly', { folder });
    case 'imported':
      return l10n('analyzerExclusions.diagnostic.imported', { folder });
    case 'largeWorkspace':
      return f.ramGb === undefined
        ? l10n('analyzerExclusions.diagnostic.largeNoRam', { count: f.fileCount ?? 0 })
        : l10n('analyzerExclusions.diagnostic.large', { count: f.fileCount ?? 0, ram: f.ramGb });
  }
}

async function checkWorkspaceFolder(wf: vscode.WorkspaceFolder, runId: number): Promise<void> {
  const root = wf.uri.fsPath;
  const pubspecPath = path.join(root, 'pubspec.yaml');
  const key = wf.uri.toString();
  // Not a Dart/Flutter project folder: nothing to analyze or report.
  if (!fs.existsSync(pubspecPath)) {
    _state.delete(key);
    _collection?.delete(vscode.Uri.file(pubspecPath));
    return;
  }

  const existingFolders = await listFolders(root);
  const dartFileCounts: Record<string, number> = {};
  for (const f of existingFolders) dartFileCounts[f] = await countDartFiles(path.join(root, f));

  const settingsFile = path.join(root, '.vscode', 'settings.json');
  const settingsExcluded = vscode.workspace
    .getConfiguration('dart', wf.uri)
    .get<string[]>('analysisExcludedFolders', []);
  const nestedExcludedCounts: Record<string, number> = {};
  for (const raw of settingsExcluded) {
    const n = normalizeFolder(raw);
    if (n.includes('/') && !(n in nestedExcludedCounts)) {
      nestedExcludedCounts[n] = await countDartFiles(path.join(root, n));
    }
  }
  // A newer run started while we were scanning: drop this result.
  if (!_runs.isLatest(runId)) return;
  const findings = evaluateAnalyzerExclusions({
    existingFolders,
    dartFileCounts,
    nestedExcludedCounts,
    settingsExcluded,
    analysisOptionsExcluded: parseAnalyzerExclude(readText(path.join(root, 'analysis_options.yaml'))),
    pathDependencies: parsePathDependencies(readText(pubspecPath)),
    ramGb: ramGb(),
  });
  const hasSettingsFile = fs.existsSync(settingsFile);
  _state.set(key, { folderUri: wf.uri, findings, hasSettingsFile });

  const range = new vscode.Range(0, 0, 0, 0);
  const diags = findings.map((f) => {
    const d = new vscode.Diagnostic(range, findingMessage(f, hasSettingsFile), vscode.DiagnosticSeverity.Information);
    d.source = 'Saropa Lints';
    d.code = DIAGNOSTIC_CODE;
    return d;
  });
  _collection?.set(vscode.Uri.file(pubspecPath), diags);
}

async function checkAll(): Promise<void> {
  if (!_collection) return;
  const runId = _runs.next();
  if (!isEnabled()) {
    _collection.clear();
    _state.clear();
    return;
  }
  for (const wf of vscode.workspace.workspaceFolders ?? []) {
    if (!_runs.isLatest(runId)) return;
    await checkWorkspaceFolder(wf, runId);
  }
}

/**
 * Quick fix on this check's own diagnostics (scoped via `code`, since
 * `source` is shared by every Saropa check). The command asks which of the
 * addable folders to add, with the clicked diagnostic's folder preselected.
 */
export class AnalyzerExclusionsCodeActionProvider implements vscode.CodeActionProvider {
  provideCodeActions(document: vscode.TextDocument, _range: vscode.Range, context: vscode.CodeActionContext): vscode.CodeAction[] {
    const diags = context.diagnostics.filter((d) => d.code === DIAGNOSTIC_CODE);
    if (diags.length === 0) return [];
    const wf = vscode.workspace.getWorkspaceFolder(document.uri);
    const state = wf ? _state.get(wf.uri.toString()) : undefined;
    if (!state) return [];
    const preselect = state.findings
      .filter((f) => diags.some((d) => d.message === findingMessage(f, state.hasSettingsFile)))
      .map((f) => f.folder)
      .filter((f): f is string => !!f);
    if (addableFolders(state.findings).length === 0) return [];
    const title = l10n('analyzerExclusions.quickFix.title');
    const action = new vscode.CodeAction(title, vscode.CodeActionKind.QuickFix);
    action.diagnostics = diags;
    action.command = { command: ADD_COMMAND, title, arguments: [state.folderUri, preselect] };
    return [action];
  }
}

/** Adds the user-selected folders to `dart.analysisExcludedFolders` in the folder's .vscode/settings.json. */
async function addFoldersCommand(folderUri: vscode.Uri, preselect: string[]): Promise<void> {
  const state = _state.get(folderUri.toString());
  const addable = state ? addableFolders(state.findings) : [];
  if (addable.length === 0) return;
  const picked = await vscode.window.showQuickPick(
    addable.map((label) => ({ label, picked: preselect.includes(label) })),
    { canPickMany: true, placeHolder: l10n('analyzerExclusions.quickFix.pickPlaceholder') },
  );
  if (!picked || picked.length === 0) return;
  const config = vscode.workspace.getConfiguration('dart', folderUri);
  const current = config.inspect<string[]>('analysisExcludedFolders')?.workspaceFolderValue ?? [];
  const next = [...current, ...picked.map((p) => p.label).filter((f) => !current.includes(f))];
  try {
    // WorkspaceFolder target writes <folder>/.vscode/settings.json (created if missing).
    await config.update('analysisExcludedFolders', next, vscode.ConfigurationTarget.WorkspaceFolder);
  } catch (err) {
    void vscode.window.showErrorMessage(l10n('analyzerExclusions.error.writeFailed', { error: String(err) }));
    return;
  }
  await checkAll();
}

/** Registers the analyzer-exclusions check. Call once at extension activation. */
export function registerAnalyzerExclusions(context: vscode.ExtensionContext): void {
  _collection = vscode.languages.createDiagnosticCollection('saropa-analyzer-exclusions');
  context.subscriptions.push(_collection);

  const run = (): void => { void checkAll(); };
  context.subscriptions.push(
    vscode.workspace.onDidSaveTextDocument((doc) => {
      if (WATCHED_FILES.has(path.basename(doc.fileName))) run();
    }),
    vscode.workspace.onDidChangeWorkspaceFolders((e) => {
      for (const wf of e.removed) {
        _state.delete(wf.uri.toString());
        _collection?.delete(vscode.Uri.file(path.join(wf.uri.fsPath, 'pubspec.yaml')));
      }
      run();
    }),
    vscode.workspace.onDidChangeConfiguration((e) => {
      if (e.affectsConfiguration(SETTING_SECTION) || e.affectsConfiguration('dart.analysisExcludedFolders')) run();
    }),
    vscode.languages.registerCodeActionsProvider(
      { language: 'yaml', pattern: '**/pubspec.yaml' },
      new AnalyzerExclusionsCodeActionProvider(),
      { providedCodeActionKinds: [vscode.CodeActionKind.QuickFix] },
    ),
    vscode.commands.registerCommand(ADD_COMMAND, addFoldersCommand),
  );
  run();
}
