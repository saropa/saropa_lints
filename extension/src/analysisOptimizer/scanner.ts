import * as path from 'path';
import * as vscode from 'vscode';
import * as cp from 'child_process';
import * as fs from 'fs';
import type { FileAnalysisMetrics } from './types';
import { gitIgnoredPaths } from './nestedRoots';

const GENERATED_SUFFIXES = [
  '.g.dart',
  '.freezed.dart',
  '.mocks.dart',
  '.gr.dart',
  '.config.dart',
  '.gen.dart',
  '.chopper.dart',
  '.graphql.dart',
];

const CONCURRENCY = 30;
const RECENT_DAYS = 30;

// Hard cap passed to vscode.workspace.findFiles. Kept as a named constant so
// the truncation check below stays in sync with the value actually passed.
const MAX_FILES = 50_000;

// The Dart analysis server never analyzes anything under a dot-folder:
// analyzer's ContextLocatorImpl skips directories whose name starts with
// '.' when building context roots, and ContextRootImpl excludes any file
// with a '.'-prefixed segment between the root and the file. Folders like
// `.claude/worktrees/*` (agent-tool git worktrees), `.dart_tool/`,
// `ios/.symlinks/`, and `.fvm/` therefore cost the analyzer nothing, but
// findFiles would otherwise walk them, burn scan capacity, and skew the
// "no recent edits" exclusion suggestions. Exported (vscode-free) so it can
// be unit tested directly.
export function isInDotFolder(relativePath: string): boolean {
  const segments = relativePath.split('/');
  return segments.some(segment => segment.startsWith('.'));
}

// Builds the findFiles exclude glob. VS Code applies `files.exclude` only
// when the exclude argument is undefined, so we always pass an explicit glob
// and merge in (a) the enabled `files.exclude` keys and (b) fully
// git-ignored directories, so neither burns the MAX_FILES cap. Exported
// (vscode-free) for unit testing.
export function buildScanExcludeGlob(
  filesExclude: Record<string, unknown> | undefined,
  ignoredDirs: readonly string[],
): string {
  const parts = ['**/build/**', '**/.*/**'];
  for (const [glob, on] of Object.entries(filesExclude ?? {})) {
    if (on === true && !glob.includes(',') && !glob.includes('{')) parts.push(glob);
  }
  for (const dir of ignoredDirs) {
    if (!/[,{}]/.test(dir)) parts.push(`${dir.replace(/\/+$/, '')}/**`);
  }
  return `{${[...new Set(parts)].join(',')}}`;
}

// Directories git ignores wholesale (from `.gitignore`, `.git/info/exclude`
// and the global ignore file), relative to `root` with no trailing slash.
// Empty when git is unavailable or `root` is not a repository.
export function queryGitIgnoredDirs(root: string): string[] {
  try {
    const out = cp.execFileSync(
      'git',
      ['ls-files', '--others', '--ignored', '--exclude-standard', '--directory'],
      { cwd: root, encoding: 'utf8', timeout: 15_000, maxBuffer: 10 * 1024 * 1024, stdio: ['ignore', 'pipe', 'ignore'] },
    );
    return out.split('\n').map(l => l.trim()).filter(l => l.endsWith('/')).map(l => l.slice(0, -1));
  } catch {
    return [];
  }
}

// Converts a `files.exclude` glob to a RegExp (supports `**`, `*`, `?`).
function globToRegExp(glob: string): RegExp {
  let re = '';
  for (let i = 0; i < glob.length; i++) {
    const c = glob[i];
    if (c === '*') {
      if (glob[i + 1] === '*') {
        i++;
        if (glob[i + 1] === '/') { i++; re += '(?:.*/)?'; } else re += '.*';
      } else re += '[^/]*';
    } else if (c === '?') re += '[^/]';
    else re += c.replace(/[.+^${}()|[\]\\]/g, '\\$&');
  }
  return new RegExp(`^${re}$`);
}

// Parses NUL-separated `git ls-files -z` output into scan candidates,
// applying the dot-folder filter, build/** exclusion and enabled
// `files.exclude` globs (a glob matching a directory prefix excludes
// everything beneath it). Pure and vscode-free for unit testing.
export function filterGitFileList(
  output: string,
  filesExclude: Record<string, unknown> | undefined,
): string[] {
  const excludes = Object.entries(filesExclude ?? {})
    .filter(([g, on]) => on === true && !g.includes(',') && !g.includes('{'))
    .map(([g]) => globToRegExp(g.replace(/\/+$/, '')));
  const seen = new Set<string>();
  const out: string[] = [];
  for (const raw of output.split('\0')) {
    // git always emits '/' separators (even on Windows); a backslash is a legal POSIX filename char.
    const rel = raw;
    if (!rel.endsWith('.dart') || seen.has(rel)) continue;
    seen.add(rel);
    if (isInDotFolder(rel)) continue;
    const segs = rel.split('/');
    if (segs.slice(0, -1).includes('build')) continue;
    let excluded = false;
    for (let i = 1; i <= segs.length && !excluded; i++) {
      const prefix = segs.slice(0, i).join('/');
      excluded = excludes.some(r => r.test(prefix));
    }
    if (!excluded) out.push(rel);
  }
  return out;
}

// One `git ls-files` call: tracked + untracked-not-ignored Dart files.
// Returns undefined when git is missing or root is not a work tree.
async function listDartFilesViaGit(root: string): Promise<string | undefined> {
  return new Promise(resolve => {
    cp.execFile(
      'git',
      ['ls-files', '--cached', '--others', '--exclude-standard', '-z', '--', '*.dart'],
      { cwd: root, encoding: 'utf8', timeout: 60_000, maxBuffer: 256 * 1024 * 1024 },
      (err, stdout) => resolve(err ? undefined : stdout),
    );
  });
}

async function existingOnly(root: string, rels: string[]): Promise<string[]> {
  const keep: string[] = [];
  for (let i = 0; i < rels.length; i += 200) {
    const batch = rels.slice(i, i + 200);
    const ok = await Promise.all(batch.map(r =>
      fs.promises.access(path.join(root, r)).then(() => true, () => false)));
    batch.forEach((r, j) => { if (ok[j]) keep.push(r); });
  }
  return keep;
}

export function computeFileMetrics(
  content: string,
  relativePath: string,
): Omit<FileAnalysisMetrics, 'daysSinceLastEdit'> {
  const lines = content.split('\n');
  const lineCount = lines.length;

  let importCount = 0;
  let classCount = 0;
  let functionCount = 0;
  let hasWidgets = false;
  let hasAsyncCode = false;

  for (const line of lines) {
    const trimmed = line.trimStart();
    if (trimmed.startsWith('import ')) importCount++;
    if (trimmed.startsWith('class ') || trimmed.startsWith('abstract class ') || trimmed.startsWith('mixin ')) classCount++;
    if (/^\s*\w[\w<>,\s]*\s+\w+\s*\(/.test(line) && !trimmed.startsWith('import ') && !trimmed.startsWith('//')) functionCount++;
    if (!hasWidgets && /Widget\b|\bState</.test(line)) hasWidgets = true;
    if (!hasAsyncCode && /\basync\b|\bFuture\b|\bStream\b/.test(line)) hasAsyncCode = true;
  }

  const isGenerated = GENERATED_SUFFIXES.some(s => relativePath.endsWith(s));

  return {
    relativePath,
    lineCount,
    classCount,
    functionCount,
    importCount,
    hasWidgets,
    hasAsyncCode,
    isGenerated,
  };
}

function queryGitRecency(root: string): Map<string, number> {
  const recency = new Map<string, number>();
  try {
    const since = `${RECENT_DAYS} days ago`;
    const now = Date.now();
    // Scoped to --since so the walk stays bounded by RECENT_DAYS regardless of
    // total repo history size — files outside the window are simply absent
    // from `recency` (their daysSinceLastEdit stays undefined upstream).
    const out = cp.execSync(
      `git log --diff-filter=M --name-only --format=">>>%aI" --since="${since}" -- "*.dart"`,
      { cwd: root, encoding: 'utf8', timeout: 15_000, maxBuffer: 10 * 1024 * 1024 },
    );
    let currentDate = now;
    for (const line of out.split('\n')) {
      const trimmed = line.trim();
      if (trimmed.startsWith('>>>')) {
        const iso = trimmed.slice(3);
        const parsed = new Date(iso).getTime();
        currentDate = Number.isFinite(parsed) ? parsed : now;
      } else if (trimmed.endsWith('.dart')) {
        const posix = trimmed.replace(/\\/g, '/');
        const days = Math.max(0, Math.floor((now - currentDate) / 86_400_000));
        const existing = recency.get(posix);
        if (existing === undefined || days < existing) {
          recency.set(posix, days);
        }
      }
    }
  } catch {
    // git unavailable — all files get undefined recency
  }
  return recency;
}

export async function scanWorkspace(
  root: string,
  progress: vscode.Progress<{ message?: string; increment?: number }>,
  token: vscode.CancellationToken,
): Promise<FileAnalysisMetrics[]> {
  const filesExclude = vscode.workspace.getConfiguration('files').get<Record<string, unknown>>('exclude');
  let files: vscode.Uri[];
  const gitOut = await listDartFilesViaGit(root);
  if (gitOut !== undefined) {
    // Git path: honours .gitignore natively; no cap needed.
    const rels = await existingOnly(root, filterGitFileList(gitOut, filesExclude));
    files = rels.map(r => vscode.Uri.file(path.join(root, r)));
    if (token.isCancellationRequested) return [];
  } else {
    const allFiles = await vscode.workspace.findFiles(
      new vscode.RelativePattern(root, '**/*.dart'),
      buildScanExcludeGlob(filesExclude, queryGitIgnoredDirs(root)),
      MAX_FILES,
    );
    if (token.isCancellationRequested) return [];

    if (allFiles.length === MAX_FILES) {
      const message = `Analysis Optimizer scan hit the ${MAX_FILES.toLocaleString()}-file cap; results are partial.`;
      progress.report({ message });
      void vscode.window.showWarningMessage(message);
    }

    const rel = (f: vscode.Uri): string => path.relative(root, f.fsPath).replace(/\\/g, '/');
    const dotFiltered = allFiles.filter(f => !isInDotFolder(rel(f)));
    const ignored = gitIgnoredPaths(root, dotFiltered.map(rel));
    files = ignored.size === 0 ? dotFiltered : dotFiltered.filter(f => !ignored.has(rel(f)));
  }

  const total = files.length;
  progress.report({ message: `Found ${total} Dart files` });

  const gitRecency = queryGitRecency(root);

  const results: FileAnalysisMetrics[] = [];
  let completed = 0;
  let lastReportedPct = 0;

  const rootUri = vscode.Uri.file(root);

  async function processFile(uri: vscode.Uri): Promise<void> {
    if (token.isCancellationRequested) return;
    try {
      const raw = await vscode.workspace.fs.readFile(uri);
      const content = Buffer.from(raw).toString('utf8');
      const relativePath = vscode.workspace.asRelativePath(uri, false).replace(/\\/g, '/');
      const metrics = computeFileMetrics(content, relativePath);
      const days = gitRecency.get(relativePath);
      results.push({ ...metrics, daysSinceLastEdit: days });
    } catch {
      // skip unreadable files
    }
    completed++;
    const pct = Math.floor((completed / total) * 100);
    if (pct > lastReportedPct) {
      lastReportedPct = pct;
      progress.report({
        message: `Scanning: ${completed}/${total} files (${pct}%)`,
        increment: pct - lastReportedPct,
      });
    }
  }

  for (let i = 0; i < files.length; i += CONCURRENCY) {
    if (token.isCancellationRequested) break;
    const batch = files.slice(i, i + CONCURRENCY);
    await Promise.all(batch.map(f => processFile(f)));
  }

  return results;
}
