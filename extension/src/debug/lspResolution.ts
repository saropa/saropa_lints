import * as fs from 'node:fs';
import * as path from 'node:path';
import { fileURLToPath } from 'node:url';

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

/** First saropa_lints release that ships the `lsp_server` executable (15.2.8 and older do not). */
export const MIN_LSP_VERSION = '15.2.10';

/** Dart SDK floor of every saropa_lints release that ships `lsp_server` (analyzer 12+). */
export const MIN_LSP_DART = [3, 9] as const;

/**
 * True when the project's Dart SDK (from `.dart_tool/version`, written by pub)
 * is below [MIN_LSP_DART]. Such a project cannot resolve any LSP-capable
 * saropa_lints, so upgrading the dependency alone will not help — the message
 * must say the SDK is the blocker. Unreadable file => false (do not guess).
 */
export function isDartSdkTooOld(projectRoot: string): boolean {
  try {
    const raw = fs.readFileSync(path.join(projectRoot, '.dart_tool', 'version'), 'utf8').trim();
    const m = /^(\d+)\.(\d+)/.exec(raw);
    if (!m) {
      return false;
    }
    const [maj, min] = [Number(m[1]), Number(m[2])];
    return maj < MIN_LSP_DART[0] || (maj === MIN_LSP_DART[0] && min < MIN_LSP_DART[1]);
  } catch {
    return false;
  }
}

/**
 * Directory of the resolved `saropa_lints` package, from `.dart_tool/package_config.json`
 * (`rootUri` is a file:// URI or a path relative to `.dart_tool`). Undefined when the
 * config is unreadable, the package is absent, or the directory does not exist.
 */
export function resolveSaropaLintsDir(projectRoot: string): string | undefined {
  try {
    const cfgDir = path.join(projectRoot, '.dart_tool');
    const raw = fs.readFileSync(path.join(cfgDir, 'package_config.json'), 'utf8');
    const pkg = (JSON.parse(raw) as { packages?: Array<{ name?: unknown; rootUri?: unknown }> }).packages?.find(
      (p) => p?.name === 'saropa_lints',
    );
    if (typeof pkg?.rootUri !== 'string') {
      return undefined;
    }
    const dir = pkg.rootUri.startsWith('file:')
      ? fileURLToPath(pkg.rootUri)
      : path.resolve(cfgDir, decodeURIComponent(pkg.rootUri));
    return fs.existsSync(dir) ? dir : undefined;
  } catch {
    return undefined;
  }
}

/**
 * Returns the installed version when the resolved `saropa_lints` package directory
 * exists on disk and has no `bin/lsp_server.dart`; otherwise undefined. Why: old
 * versions (e.g. 4.15.1) resolve fine but ship no `lsp_server` executable, so the
 * spawn exits non-zero and the client crash-loops 5x. Undefined also covers "cannot
 * tell" so the caller falls through to the normal spawn rather than blocking on a guess.
 */
export function findLspServerMissing(projectRoot: string): { readonly version: string } | undefined {
  const dir = resolveSaropaLintsDir(projectRoot);
  if (!dir || fs.existsSync(path.join(dir, 'bin', 'lsp_server.dart'))) {
    return undefined;
  }
  // Pub-cache dirs are named `saropa_lints-<version>`; path deps have no version.
  const m = /saropa_lints-(\d[^\\/]*)[\\/]*$/.exec(dir);
  return { version: m ? m[1] : 'unknown' };
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
 * Picks the `flutter` executable for the workspace's configured SDK. Lives next
 * to [resolveDartExecutable] so both share ONE candidate order
 * (`dart.flutterSdkPath`, `<root>/.fvm/flutter_sdk`, then PATH) and cannot drift.
 * Used by the Vibrancy CLI wrapper; the LSP launcher only needs `dart`.
 */
export function resolveFlutterExecutable(
  projectRoot: string,
  settings: DartSdkSettings,
  exists: (p: string) => boolean = fs.existsSync,
  platform: NodeJS.Platform = process.platform,
): ResolvedDart {
  // Flutter ships `flutter.bat` on Windows; even an absolute .bat needs a shell to run.
  const exe = platform === 'win32' ? 'flutter.bat' : 'flutter';
  const abs = (p: string): string => (path.isAbsolute(p) ? p : path.join(projectRoot, p));
  const candidates: Array<{ file: string; source: ResolvedDart['source'] }> = [];
  const flutterSdk = settings.flutterSdkPath?.trim();
  if (flutterSdk) {
    candidates.push({ file: path.join(abs(flutterSdk), 'bin', exe), source: 'dart.flutterSdkPath' });
  }
  // FVM pin is honoured even when the user never set a VS Code setting.
  candidates.push({ file: path.join(abs(path.join('.fvm', 'flutter_sdk')), 'bin', exe), source: 'fvm' });
  for (const c of candidates) {
    if (exists(c.file)) {
      return { command: c.file, useShell: platform === 'win32', source: c.source };
    }
  }
  // Nothing configured: bare PATH `flutter` (shell on Windows so flutter.bat resolves).
  return { command: 'flutter', useShell: platform === 'win32', source: 'path' };
}

/**
 * Argv for the LSP server. `dart run --no-pub` is NOT a valid option (Dart 3.8 and
 * 3.14 both reject it), and plain `dart run <pkg>:<exe>` may implicitly `pub get`,
 * rewriting pubspec.lock / package_config.json. So when the package directory is
 * resolvable, run its script file directly against the project's package_config:
 * no pub resolution happens at all. Falls back to `dart run` only when the path
 * cannot be resolved.
 */
export function buildLspServerArgs(projectRoot: string): string[] {
  const dir = resolveSaropaLintsDir(projectRoot);
  const script = dir ? path.join(dir, 'bin', 'lsp_server.dart') : undefined;
  if (script && fs.existsSync(script)) {
    const cfg = path.join(projectRoot, '.dart_tool', 'package_config.json');
    return [`--packages=${cfg}`, script];
  }
  return ['run', 'saropa_lints:lsp_server'];
}
