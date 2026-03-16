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
  'reports',
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
  if (!wsRoot) {
    cachedProjectRoot = undefined;
    return undefined;
  }

  // Common case: pubspec.yaml at workspace root.
  if (fs.existsSync(path.join(wsRoot, 'pubspec.yaml'))) {
    cachedProjectRoot = wsRoot;
    return wsRoot;
  }

  // Search one level deep for a subdirectory containing pubspec.yaml.
  try {
    const entries = fs.readdirSync(wsRoot, { withFileTypes: true });
    for (const entry of entries) {
      if (!entry.isDirectory()) continue;
      if (entry.name.startsWith('.') || SKIP_DIRS.has(entry.name)) continue;
      const candidate = path.join(wsRoot, entry.name);
      if (fs.existsSync(path.join(candidate, 'pubspec.yaml'))) {
        cachedProjectRoot = candidate;
        return candidate;
      }
    }
  } catch {
    // Permission error or similar — fall through.
  }

  cachedProjectRoot = undefined;
  return undefined;
}

/** Clear cached project root. Call if workspace structure changes. */
export function invalidateProjectRoot(): void {
  cachedProjectRoot = null;
}
