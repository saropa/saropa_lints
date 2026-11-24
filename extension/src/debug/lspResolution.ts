import * as fs from 'node:fs';
import * as path from 'node:path';

/**
 * True when `<projectRoot>/.dart_tool/package_config.json` lists a package
 * named `saropa_lints`. Missing/unreadable/malformed file => false. Spawning
 * `dart run saropa_lints:lsp_server` without it exits 255 ("Could not find
 * package saropa_lints") and the client restart loop stacks error toasts.
 */
export function isSaropaLintsResolved(projectRoot: string): boolean {
  try {
    const raw = fs.readFileSync(path.join(projectRoot, '.dart_tool', 'package_config.json'), 'utf8');
    const packages = (JSON.parse(raw) as { packages?: Array<{ name?: unknown }> }).packages;
    return Array.isArray(packages) && packages.some((p) => p?.name === 'saropa_lints');
  } catch {
    return false;
  }
}

/** Inputs for [resolveDartExecutable]; settings are the raw Dart-Code values (may be relative or blank). */
export interface DartSdkSettings {
  /** `dart.sdkPath` — a Dart SDK root (contains `bin/dart`). */
  readonly dartSdkPath?: string;
  /** `dart.flutterSdkPath` — a Flutter SDK root (e.g. `.fvm/flutter_sdk`). */
  readonly flutterSdkPath?: string;
}

/** Result of SDK resolution: what to spawn and whether a shell is needed. */
export interface ResolvedDart {
  readonly command: string;
  /** True only for the bare PATH `dart` on Windows (needs PATHEXT / dart.bat). */
  readonly useShell: boolean;
  /** Where the executable came from; surfaced in the output channel for diagnosis. */
  readonly source: 'dart.sdkPath' | 'dart.flutterSdkPath' | 'fvm' | 'path';
}

/**
 * Picks the `dart` executable for the workspace's configured SDK instead of the
 * bare PATH `dart`. Why: `dart run` re-resolves (implicit `pub get`) when the
 * package_config was written by a different SDK, so a PATH SDK newer than an
 * FVM pin rewrote pubspec.lock / package_config.json on every server start.
 *
 * Order: dart.sdkPath, dart.flutterSdkPath, <root>/.fvm/flutter_sdk, then PATH.
 * `exists` and `platform` are injectable so the logic is unit-testable without
 * a real SDK on disk.
 */
export function resolveDartExecutable(
  projectRoot: string,
  settings: DartSdkSettings,
  exists: (p: string) => boolean = fs.existsSync,
  platform: NodeJS.Platform = process.platform,
): ResolvedDart {
  const exe = platform === 'win32' ? 'dart.exe' : 'dart';
  // Settings may be relative to the workspace (FVM users commonly set `.fvm/flutter_sdk`).
  const abs = (p: string): string => (path.isAbsolute(p) ? p : path.join(projectRoot, p));
  const flutterDart = (root: string): string => path.join(abs(root), 'bin', 'cache', 'dart-sdk', 'bin', exe);

  const candidates: Array<{ file: string; source: ResolvedDart['source'] }> = [];
  const dartSdk = settings.dartSdkPath?.trim();
  if (dartSdk) {
    candidates.push({ file: path.join(abs(dartSdk), 'bin', exe), source: 'dart.sdkPath' });
  }
  const flutterSdk = settings.flutterSdkPath?.trim();
  if (flutterSdk) {
    candidates.push({ file: flutterDart(flutterSdk), source: 'dart.flutterSdkPath' });
  }
  // FVM pin picked up even when the user never set a VS Code setting.
  candidates.push({ file: flutterDart(path.join('.fvm', 'flutter_sdk')), source: 'fvm' });

  for (const c of candidates) {
    if (exists(c.file)) {
      // Absolute exe path: no shell, so paths with spaces are not split.
      return { command: c.file, useShell: false, source: c.source };
    }
  }
  // Nothing configured: legacy behavior (shell on Windows so dart.bat resolves).
  return { command: 'dart', useShell: platform === 'win32', source: 'path' };
}

/**
 * Args for the LSP server. `--no-pub` stops `dart run` from running an implicit
 * `pub get`, which is what rewrote pubspec.lock / package_config.json.
 */
export const LSP_SERVER_ARGS: readonly string[] = ['run', '--no-pub', 'saropa_lints:lsp_server'];
