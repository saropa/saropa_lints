/**
 * Centralized project root discovery.
 *
 * The "project root" is the directory containing pubspec.yaml, which may
 * differ from the VS Code workspace root when the Dart project lives in
 * a subdirectory (e.g. `game/pubspec.yaml`).
 *
 * All Dart-related operations (commands, violations, config files) should
 * use getProjectRoot(). Only VS Code-level operations (configuration,
 * workspace state) should use getWorkspaceRoot().
 */

import * as vscode from 'vscode';
import * as fs from 'fs';
import * as path from 'path';
// Shared path-segment constant — keeps the 'reports' directory name in one place.
import { REPORTS_DIR } from './reportsPaths';

/**
 * Directories to skip when scanning one level deep for pubspec.yaml.
 * Hidden directories (starting with '.') are skipped separately.
 */
const SKIP_DIRS = new Set([
  'android',
  'build',
  'coverage',
  'doc',
  'docs',
  'example',
  'integration_test',
  'ios',
  'linux',
  'macos',
  'node_modules',
  REPORTS_DIR,
  'scripts',
  'test',
  'web',
  'windows',
]);

// null = not yet searched; undefined = searched, not found; string = found
let cachedProjectRoot: string | undefined | null = null;

/** Get the VS Code workspace root (first workspace folder). */
export function getWorkspaceRoot(): string | undefined {
  return vscode.workspace.workspaceFolders?.[0]?.uri.fsPath;
}

/**
 * Discover the Dart project root — the directory containing pubspec.yaml.
 * Checks workspace root first, then immediate subdirectories (one level).
 * Result is cached per session.
 */
export function getProjectRoot(): string | undefined {
  if (cachedProjectRoot !== null) return cachedProjectRoot;

  const wsRoot = getWorkspaceRoot();
  cachedProjectRoot = wsRoot ? findProjectRootIn(wsRoot) : undefined;
  return cachedProjectRoot;
}

/**
 * The Dart project root for any folder (not only the first workspace
 * folder): the folder itself when it holds pubspec.yaml, else its first
 * immediate subdirectory that does. Uncached. Split out of getProjectRoot so
 * multi-root features (the accepted-findings check) apply the same one-level
 * rule to every workspace folder instead of only the first.
 */
export function findProjectRootIn(folder: string): string | undefined {
  // Common case: pubspec.yaml at the folder itself.
  if (fs.existsSync(path.join(folder, 'pubspec.yaml'))) return folder;

  // Search one level deep for a subdirectory containing pubspec.yaml.
  try {
    const entries = fs.readdirSync(folder, { withFileTypes: true });
    for (const entry of entries) {
      if (!entry.isDirectory()) continue;
      if (entry.name.startsWith('.') || SKIP_DIRS.has(entry.name)) continue;
      const candidate = path.join(folder, entry.name);
      if (fs.existsSync(path.join(candidate, 'pubspec.yaml'))) return candidate;
    }
  } catch {
    // Permission error or similar — fall through.
  }
  return undefined;
}

/** Clear cached project root. Call if workspace structure changes. */
export function invalidateProjectRoot(): void {
  cachedProjectRoot = null;
}
