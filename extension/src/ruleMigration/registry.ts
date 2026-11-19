/**
 * Loads the rename registry shipped inside the installed saropa_lints package
 * (`lib/src/config/rule_renames.json`). A missing file means no migration.
 */
import * as path from 'node:path';
import { fileURLToPath } from 'node:url';
import type { RenameEntry } from './types';

export interface RegistryIo {
  /** File text, or undefined when absent/unreadable. */
  read(file: string): string | undefined;
}

/** Pure: major.minor.patch compare; prerelease and build suffixes are ignored. -1, 0, 1; NaN when unparseable. */
export function compareVersions(a: string, b: string): number {
  const parse = (v: string): number[] | undefined => {
    const m = /^(\d+)\.(\d+)\.(\d+)/.exec(v.trim());
    return m ? [Number(m[1]), Number(m[2]), Number(m[3])] : undefined;
  };
  const pa = parse(a);
  const pb = parse(b);
  if (!pa || !pb) return Number.NaN;
  for (let i = 0; i < 3; i++) if (pa[i] !== pb[i]) return pa[i] < pb[i] ? -1 : 1;
  return 0;
}

/** Pure: absolute root of a package named in `.dart_tool/package_config.json`. */
export function parsePackageRoot(packageConfigJson: string, configDir: string, pkg: string): string | undefined {
  try {
    const cfg = JSON.parse(packageConfigJson) as { packages?: { name?: unknown; rootUri?: unknown }[] };
    const hit = cfg.packages?.find((p) => p.name === pkg);
    if (typeof hit?.rootUri !== 'string') return undefined;
    return hit.rootUri.startsWith('file:')
      ? fileURLToPath(hit.rootUri)
      : path.resolve(configDir, decodeURIComponent(hit.rootUri));
  } catch {
    return undefined;
  }
}

/** Pure: valid entries from the registry JSON; malformed entries are dropped. */
export function parseRegistry(json: string): RenameEntry[] {
  try {
    const doc = JSON.parse(json) as { version?: unknown; renames?: unknown };
    if (doc.version !== 1 || !Array.isArray(doc.renames)) return [];
    const out: RenameEntry[] = [];
    for (const r of doc.renames as Record<string, unknown>[]) {
      if (typeof r?.old !== 'string' || typeof r.since !== 'string') continue;
      if (r.new !== null && typeof r.new !== 'string') continue;
      out.push({ old: r.old, new: r.new, since: r.since, note: typeof r.note === 'string' ? r.note : undefined });
    }
    return out;
  } catch {
    return [];
  }
}

/** Pure: entries introduced in (previous, current]. No previous version means no lower bound. */
export function filterBySince(
  entries: readonly RenameEntry[],
  previous: string | undefined,
  current: string,
): RenameEntry[] {
  return entries.filter((e) => {
    if (compareVersions(e.since, current) > 0) return false; // NaN compares false, so bad versions pass
    return previous === undefined || !(compareVersions(e.since, previous) <= 0);
  });
}

/**
 * Entries to migrate for a project whose data root (pubspec.lock and
 * .dart_tool) is `dataRoot`. Empty when the package or the registry is absent.
 */
export function loadRenames(
  io: RegistryIo,
  dataRoot: string,
  previous: string | undefined,
  current: string,
): RenameEntry[] {
  const dartTool = path.join(dataRoot, '.dart_tool');
  const cfg = io.read(path.join(dartTool, 'package_config.json'));
  if (cfg === undefined) return [];
  const root = parsePackageRoot(cfg, dartTool, 'saropa_lints');
  if (!root) return [];
  const text = io.read(path.join(root, 'lib', 'src', 'config', 'rule_renames.json'));
  if (text === undefined) return [];
  return filterBySince(parseRegistry(text), previous, current);
}
