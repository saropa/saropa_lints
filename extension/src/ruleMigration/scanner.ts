/**
 * Workspace scanner: finds files that mention an old rule name and computes
 * their rewritten text. All file discovery and reading is injected.
 */
import * as path from 'node:path';
import { findNestedPubspecDirs } from '../analysisOptimizer/nestedRoots';
import { rewriteBaseline, rewriteDartIgnores, rewriteYamlKeys } from './rewriters';
import type { Finding, RenameMap } from './types';

export interface ScanDeps {
  /** Absolute paths matching `glob` (relative to `root`), minus `excludeGlob`. */
  findFiles(root: string, glob: string, excludeGlob: string): Promise<string[]>;
  /** File text, or undefined when unreadable. */
  read(file: string): string | undefined;
}

export type SkipReason = 'generated' | 'unreadable' | 'unparseable';

export interface FileChange {
  file: string;
  before: string;
  after: string;
  hits: number;
  findings: Finding[];
}

export interface ScanResult {
  changes: FileChange[];
  skipped: { file: string; reason: SkipReason }[];
}

/** One package root with the renames that apply to it. */
export interface PackageScan {
  root: string;
  renames: RenameMap;
}

export const EXCLUDE_GLOB = '**/{build,.dart_tool,.saropa_lints,node_modules,.git}/**';
const GENERATED = /\.(g|freezed|gr)\.dart$/;

/** The workspace root plus its nested package roots (absolute), for per-package scans. */
export function packageRoots(
  workspaceRoot: string,
  findNested: (root: string) => string[] = findNestedPubspecDirs,
): string[] {
  return [workspaceRoot, ...findNested(workspaceRoot).map((rel) => path.join(workspaceRoot, rel))];
}

/** The deepest root in `roots` that contains `file`, or '' when none does. */
export function owningRoot(file: string, roots: readonly string[]): string {
  let best = '';
  for (const r of roots) {
    const rel = path.relative(r, file);
    if (!rel.startsWith('..') && !path.isAbsolute(rel) && r.length > best.length) best = r;
  }
  return best;
}

function kindOf(file: string): 'dart' | 'options' | 'custom' | 'baseline' {
  const base = path.basename(file);
  if (base === 'analysis_options.yaml') return 'options';
  if (base === 'analysis_options_custom.yaml') return 'custom';
  if (base.endsWith('.json')) return 'baseline';
  return 'dart';
}

/** Cheap pre-check: does the text contain any old name at all? */
function mentionsAny(text: string, renames: RenameMap): boolean {
  for (const old of renames.keys()) {
    if (text.includes(old) || text.includes(old.replace(/_/g, '-'))) return true;
  }
  return false;
}

export async function scanWorkspace(deps: ScanDeps, packages: readonly PackageScan[]): Promise<ScanResult> {
  const result: ScanResult = { changes: [], skipped: [] };
  const roots = packages.map((p) => p.root);
  const seen = new Set<string>();
  for (const pkg of packages) {
    if (pkg.renames.size === 0) continue;
    const globs = ['**/*.dart', '**/analysis_options.yaml', '**/analysis_options_custom.yaml', '**/*baseline*.json'];
    for (const glob of globs) {
      for (const file of await deps.findFiles(pkg.root, glob, EXCLUDE_GLOB)) {
        // A nested package's files belong to its own scan (its own locked version).
        if (owningRoot(file, roots) !== pkg.root || seen.has(file)) continue;
        seen.add(file);
        if (GENERATED.test(file)) {
          result.skipped.push({ file, reason: 'generated' });
          continue;
        }
        const before = deps.read(file);
        if (before === undefined) {
          result.skipped.push({ file, reason: 'unreadable' });
          continue;
        }
        if (!mentionsAny(before, pkg.renames)) continue;
        const kind = kindOf(file);
        if (kind === 'baseline' && !isJson(before)) {
          result.skipped.push({ file, reason: 'unparseable' });
          continue;
        }
        const r =
          kind === 'dart'
            ? rewriteDartIgnores(before, pkg.renames)
            : kind === 'baseline'
              ? rewriteBaseline(before, pkg.renames)
              : rewriteYamlKeys(before, pkg.renames, kind);
        if (r.text !== before || r.findings.length > 0) {
          result.changes.push({ file, before, after: r.text, hits: r.hits, findings: r.findings });
        }
      }
    }
  }
  return result;
}

function isJson(text: string): boolean {
  try {
    JSON.parse(text);
    return true;
  } catch {
    return false;
  }
}
