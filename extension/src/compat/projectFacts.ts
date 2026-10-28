/**
 * Read-only facts about a target project, gathered from files on disk only
 * (no network, no process spawn except the optional Flutter SDK lookup that
 * `deriveSdkPinsOrNull` already performs). Slice A of the extension
 * compatibility design in plans/PLAN_analyzer_12_to_13_14_upgrade.md.
 *
 * Every field is optional/absent when its source is missing or unparseable;
 * a reader never throws.
 */
import * as fs from 'node:fs';
import * as path from 'node:path';
import { getPluginsIntegrationState } from '../setup';
import { readConfiguredPluginVersion } from '../analysisOptionsVersion';
import { readInstalledVersion } from '../upgrade-checker';
import { deriveSdkPinsOrNull } from '../vibrancy/services/sdk-pins';

export interface ProjectFacts {
  dartVersion?: string;
  flutterVersion?: string;
  flutterMetaPin?: string;
  locked: {
    saropaLints?: { version: string; source: string };
    analyzer?: string;
    meta?: string;
  };
  /** saropa_lints is declared in pubspec.yaml dependencies or dev_dependencies. */
  inPubspec: boolean;
  /** Version string from the live `plugins: saropa_lints: version:` entry. */
  pluginVersion?: string;
  /** The plugins block was commented out by the extension's Off toggle. */
  pluginBlockDisabled: boolean;
  /** Set when this package is a pub workspace member; the workspace root dir. */
  workspaceRoot?: string;
}

function readText(file: string): string | undefined {
  try {
    return fs.readFileSync(file, 'utf8');
  } catch {
    return undefined;
  }
}

/** Pure: Dart SDK version from `.dart_tool/package_config.json` generatorVersion. */
export function parseDartVersion(packageConfigJson: string): string | undefined {
  try {
    const v = (JSON.parse(packageConfigJson) as { generatorVersion?: unknown }).generatorVersion;
    return typeof v === 'string' && /^\d+\.\d+\.\d+/.test(v.trim()) ? v.trim() : undefined;
  } catch {
    return undefined;
  }
}

/** Pure: Flutter version from `.dart_tool/version` (first non-empty line). */
export function parseFlutterVersion(versionFile: string): string | undefined {
  const first = versionFile.split(/\r?\n/).map((l) => l.trim()).find((l) => l.length > 0);
  return first && /^\d+\.\d+\.\d+/.test(first) ? first : undefined;
}

/** Pure: a package's locked version from pubspec.lock content. */
export function parseLockedVersion(lock: string, pkg: string): string | undefined {
  let inBlock = false;
  for (const line of lock.split(/\r?\n/)) {
    if (/^ {2}[\w-]+:\s*$/.test(line)) {
      inBlock = line.trim() === `${pkg}:`;
      continue;
    }
    if (/^\S/.test(line)) inBlock = false;
    if (!inBlock) continue;
    const m = line.match(/^ {4}version:\s*["']?([^"'\s#]+)["']?/);
    if (m) return m[1];
  }
  return undefined;
}

/** Pure: pubspec has top-level `resolution: workspace`. */
export function isWorkspaceMember(pubspec: string): boolean {
  return /^resolution:\s*["']?workspace["']?\s*(?:#.*)?$/m.test(pubspec.replace(/\r/g, ''));
}

/** Pure: pubspec declares a top-level `workspace:` list (workspace root). */
function isWorkspaceRoot(pubspec: string): boolean {
  return /^workspace:\s*(?:#.*)?$/m.test(pubspec.replace(/\r/g, ''));
}

/** Pure: saropa_lints is a key under dependencies: or dev_dependencies:. */
export function pubspecDeclaresSaropaLints(pubspec: string): boolean {
  let inDeps = false;
  for (const raw of pubspec.split(/\r?\n/)) {
    if (/^\S/.test(raw)) {
      inDeps = /^(dev_)?dependencies:\s*(?:#.*)?$/.test(raw);
      continue;
    }
    if (inDeps && /^ {2}saropa_lints:/.test(raw)) return true;
  }
  return false;
}

/**
 * Pure: version under the live top-level `plugins:` -> `saropa_lints:` entry.
 * Handles the nested form (`version: "x"`) and the shorthand (`saropa_lints: x`).
 */
export function parsePluginVersion(analysisOptions: string): string | undefined {
  return readConfiguredPluginVersion(analysisOptions)?.raw;
}

/** Nearest ancestor directory whose pubspec declares a workspace. */
function findWorkspaceRoot(start: string): string | undefined {
  let dir = path.dirname(start);
  for (;;) {
    const text = readText(path.join(dir, 'pubspec.yaml'));
    if (text !== undefined && isWorkspaceRoot(text)) return dir;
    const parent = path.dirname(dir);
    if (parent === dir) return undefined;
    dir = parent;
  }
}

/** Directory holding pubspec.lock and .dart_tool: the workspace root for a pub workspace member. */
export function resolveDataRoot(root: string): string {
  const pubspec = readText(path.join(root, 'pubspec.yaml'));
  const member = pubspec !== undefined && isWorkspaceMember(pubspec);
  return (member ? findWorkspaceRoot(root) : undefined) ?? root;
}

export async function readProjectFacts(
  root: string,
  findFlutterRoot?: () => Promise<string | null>,
): Promise<ProjectFacts> {
  const pubspec = readText(path.join(root, 'pubspec.yaml'));
  const member = pubspec !== undefined && isWorkspaceMember(pubspec);
  const workspaceRoot = member ? findWorkspaceRoot(root) : undefined;
  // Pub workspaces keep lock and .dart_tool at the workspace root.
  const dataRoot = workspaceRoot ?? root;

  const facts: ProjectFacts = {
    locked: {},
    inPubspec: pubspec !== undefined && pubspecDeclaresSaropaLints(pubspec),
    pluginBlockDisabled: false,
  };
  if (workspaceRoot) facts.workspaceRoot = workspaceRoot;

  const pkgConfig = readText(path.join(dataRoot, '.dart_tool', 'package_config.json'));
  if (pkgConfig !== undefined) facts.dartVersion = parseDartVersion(pkgConfig);

  const flutterFile = readText(path.join(dataRoot, '.dart_tool', 'version'));
  if (flutterFile !== undefined) {
    facts.flutterVersion = parseFlutterVersion(flutterFile);
    if (facts.flutterVersion) {
      const pins = findFlutterRoot
        ? await deriveSdkPinsOrNull(dataRoot, findFlutterRoot)
        : await deriveSdkPinsOrNull(dataRoot);
      facts.flutterMetaPin = pins?.get('meta');
    }
  }

  const lock = readText(path.join(dataRoot, 'pubspec.lock'));
  if (lock !== undefined) {
    const saropa = readInstalledVersion(lock);
    if (saropa) facts.locked.saropaLints = saropa;
    const analyzer = parseLockedVersion(lock, 'analyzer');
    if (analyzer) facts.locked.analyzer = analyzer;
    const meta = parseLockedVersion(lock, 'meta');
    if (meta) facts.locked.meta = meta;
  }

  const options = readText(path.join(root, 'analysis_options.yaml'));
  if (options !== undefined) {
    facts.pluginVersion = parsePluginVersion(options);
    try {
      facts.pluginBlockDisabled = getPluginsIntegrationState(root) === 'disabled';
    } catch {
      /* unreadable: leave false */
    }
  }
  return facts;
}
