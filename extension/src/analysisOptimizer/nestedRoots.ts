/**
 * Nested Dart package-root detection (vscode-free so it is unit testable).
 *
 * The Dart analyzer never analyzes dot-folders (its context locator skips
 * directories starting with '.', and files under '.'-prefixed segments are
 * dropped), so `.claude/worktrees/*` is NOT a set of analysis contexts and is
 * deliberately never reported here. A real nested analysis root is created by
 * `.dart_tool/package_config.json` (or `BUILD.gn`), not `pubspec.yaml` alone
 * (which also matches Flutter tooling symlinks). A candidate is therefore a
 * non-dot directory with a pubspec.yaml AND a package_config.json/BUILD.gn
 * that git ignores; a non-ignored `packages/foo` is a legitimate monorepo
 * member and is left alone so real workspaces are never nagged.
 */
import * as cp from 'child_process';
import * as fs from 'fs';
import * as path from 'path';
import type { NestedPackageGroup } from './types';
import { isPatternCovered } from './analyzerExcludeYaml';

const MAX_DEPTH = 6;
const MAX_DIRS = 20_000;

/** Directories never descended into (dot-folders are skipped separately). */
const SKIP_DIRS = new Set(['node_modules', 'build']);

/**
 * Relative posix paths of non-dot directories (below root) that form an
 * analyzer context root: a pubspec.yaml plus `.dart_tool/package_config.json`
 * or `BUILD.gn`.
 */
export function findNestedPubspecDirs(root: string): string[] {
  const found: string[] = [];
  let visited = 0;
  const walk = (rel: string, depth: number): void => {
    if (depth > MAX_DEPTH || visited++ > MAX_DIRS) return;
    const abs = path.join(root, rel);
    let entries: fs.Dirent[];
    try {
      entries = fs.readdirSync(abs, { withFileTypes: true });
    } catch {
      return;
    }
    if (rel !== '' && entries.some(e => e.isFile() && e.name === 'pubspec.yaml')) {
      const hasRoot = entries.some(e => e.isFile() && e.name === 'BUILD.gn')
        || fs.existsSync(path.join(abs, '.dart_tool', 'package_config.json'));
      if (hasRoot) found.push(rel);
    }
    for (const e of entries) {
      // isDirectory() is false for symlinks, so links are never followed.
      if (!e.isDirectory() || e.name.startsWith('.') || SKIP_DIRS.has(e.name)) continue;
      walk(rel === '' ? e.name : `${rel}/${e.name}`, depth + 1);
    }
  };
  walk('', 0);
  return found;
}

/** Subset of `relPaths` that git ignores; empty when git is unavailable. */
export function gitIgnoredPaths(root: string, relPaths: readonly string[]): Set<string> {
  if (relPaths.length === 0) return new Set();
  try {
    const out = cp.execFileSync('git', ['check-ignore', '--stdin'], {
      cwd: root, input: relPaths.join('\n'), encoding: 'utf8', timeout: 15_000,
      maxBuffer: 10 * 1024 * 1024, stdio: ['pipe', 'pipe', 'ignore'],
    });
    return new Set(out.split('\n').map(l => l.trim()).filter(Boolean));
  } catch (e) {
    // check-ignore exits 1 when nothing matched (stdout empty) or git is missing.
    const stdout = (e as { stdout?: string }).stdout;
    return new Set((stdout ?? '').split('\n').map(l => l.trim()).filter(Boolean));
  }
}

/**
 * Pure grouping: keep only git-ignored context roots (never a path with a
 * dot-prefixed segment) and report each as its own group to exclude.
 */
export function groupNestedPackages(
  pubspecDirs: readonly string[],
  isIgnored: (relPath: string) => boolean,
): NestedPackageGroup[] {
  const groups: NestedPackageGroup[] = [];
  for (const dir of pubspecDirs) {
    if (dir.split('/').some(s => s.startsWith('.'))) continue;
    if (!isIgnored(dir)) continue;
    groups.push({ folder: dir, contextCount: 1, packages: [dir] });
  }
  return groups.sort((a, b) => a.folder.localeCompare(b.folder));
}

export function discoverNestedPackageGroups(root: string): NestedPackageGroup[] {
  const dirs = findNestedPubspecDirs(root);
  const ignored = gitIgnoredPaths(root, dirs);
  return groupNestedPackages(dirs, p => ignored.has(p));
}

/** Analyzer-exclude glob for a group folder. */
export function nestedGroupPattern(g: NestedPackageGroup): string {
  return `${g.folder}/**`;
}

/**
 * Pure: groups that are not yet excluded from analysis, either via
 * `dart.analysisExcludedFolders` (entry equal to the folder or a parent of
 * it) or an `analysis_options.yaml` exclude pattern covering it.
 */
export function findUnexcludedNestedGroups(
  groups: readonly NestedPackageGroup[],
  analyzerExcludes: readonly string[],
  excludedFolders: readonly string[],
): NestedPackageGroup[] {
  const norm = (s: string): string => s.replace(/\\/g, '/').replace(/^\.\//, '').replace(/\/+$/, '');
  const folders = excludedFolders.map(norm);
  return groups.filter(g => {
    const byFolder = folders.some(f => g.folder === f || g.folder.startsWith(`${f}/`));
    const byYaml = analyzerExcludes.includes(nestedGroupPattern(g))
      || isPatternCovered(nestedGroupPattern(g), analyzerExcludes);
    return !(byFolder || byYaml);
  });
}
