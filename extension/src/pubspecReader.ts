/**
 * Read pubspec.yaml for platform and package detection.
 * Used to show "Detected: Riverpod, Flutter" in Config and for triage.
 */

import * as fs from 'fs';
import * as path from 'path';

/** Package names saropa_lints knows about (matches lib/src/tiers.dart allPackages). */
const KNOWN_PACKAGES = [
  'bloc',
  'provider',
  'riverpod',
  'getx',
  'flutter_hooks',
  'equatable',
  'freezed',
  'firebase',
  'isar',
  'hive',
  'shared_preferences',
  'sqflite',
  'drift',
  'dio',
  'graphql',
  'supabase',
  'get_it',
  'workmanager',
  'url_launcher',
  'geolocator',
  'qr_scanner',
  'flame',
] as const;

/** Pubspec dependency name → saropa_lints package name. */
const DEP_ALIASES: Record<string, string> = {
  bloc: 'bloc',
  flutter_bloc: 'bloc',
  get: 'getx',
  getx: 'getx',
  firebase_core: 'firebase',
  firebase_auth: 'firebase',
  cloud_firestore: 'firebase',
  firebase_storage: 'firebase',
  firebase_messaging: 'firebase',
  firebase_analytics: 'firebase',
  mobile_scanner: 'qr_scanner',
  qr_code_scanner: 'qr_scanner',
};

export interface PubspecInfo {
  /** True if pubspec has Flutter SDK or flutter_test. */
  isFlutter: boolean;
  /** Detected package names (subset of KNOWN_PACKAGES). */
  packages: string[];
  /** For Flutter: typically ios, android; for Dart-only: []. */
  platforms: string[];
}

/**
 * Check whether saropa_lints appears in pubspec.yaml dependencies or
 * dev_dependencies. Used to auto-enable the extension when the package
 * is already present — no files are modified.
 */
export function hasSaropaLintsDep(workspaceRoot: string): boolean {
  const pubspecPath = path.join(workspaceRoot, 'pubspec.yaml');
  if (!fs.existsSync(pubspecPath)) return false;
  try {
    const content = fs.readFileSync(pubspecPath, 'utf-8');
    // Match "saropa_lints:" as a dependency entry (indented under a deps block).
    return /^\s+saropa_lints:/m.test(content);
  } catch {
    return false;
  }
}

/**
 * Read and parse pubspec.yaml in workspace root.
 * Returns default (isFlutter: false, packages: [], platforms: []) if file missing or invalid.
 */
export function readPubspec(workspaceRoot: string): PubspecInfo {
  const pubspecPath = path.join(workspaceRoot, 'pubspec.yaml');
  if (!fs.existsSync(pubspecPath)) {
    return { isFlutter: false, packages: [], platforms: [] };
  }
  try {
    const content = fs.readFileSync(pubspecPath, 'utf-8');
    const isFlutter =
      /flutter:\s*$/m.test(content) ||
      content.includes('sdk: flutter') ||
      content.includes('flutter_test:');
    const depNames = new Set<string>();
    const depRegex = /^\s+(\w+):/gm;
    let m: RegExpExecArray | null;
    while ((m = depRegex.exec(content)) !== null) {
      depNames.add(m[1]);
    }
    const packages: string[] = [];
    const seen = new Set<string>();
    for (const pkg of KNOWN_PACKAGES) {
      if (seen.has(pkg)) continue;
      const aliases = Object.entries(DEP_ALIASES)
        .filter(([, v]) => v === pkg)
        .map(([k]) => k);
      const names = aliases.length > 0 ? aliases : [pkg];
      if (names.some((name) => depNames.has(name))) {
        packages.push(pkg);
        seen.add(pkg);
      }
    }
    const platforms = isFlutter ? ['ios', 'android'] : [];
    return { isFlutter, packages, platforms };
  } catch {
    return { isFlutter: false, packages: [], platforms: [] };
  }
}
