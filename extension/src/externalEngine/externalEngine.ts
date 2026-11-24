/**
 * "Scan with latest engine": runs the current saropa_lints scan CLI under a
 * NEWER Dart SDK than the one the project is pinned to.
 *
 * Why: the analyzer plugin and LSP server run inside the project's own SDK, so
 * a project pinned to Dart < 3.11 (e.g. FVM on Flutter 3.32 = Dart 3.8) cannot
 * resolve saropa_lints 17.x. The scan CLI, however, is a standalone tool that
 * analyzes any Dart folder without the project depending on it. Installing the
 * engine globally (`dart pub global activate`) under a newer SDK therefore
 * gives pinned projects the latest rules without touching their pubspec.
 *
 * Pure helpers live here (unit-tested); the vscode glue is in
 * externalEngineCommand.ts.
 */
import * as fs from 'node:fs';
import * as path from 'node:path';

/** Dart SDK floor of the current engine (saropa_lints 17.x). */
export const ENGINE_MIN_DART: readonly [number, number] = [3, 11];

/** Parses `Dart SDK version: 3.14.0 (stable) ...` into [major, minor]; undefined if absent. */
export function parseDartVersion(output: string): [number, number] | undefined {
  const m = /Dart SDK version:\s*(\d+)\.(\d+)/.exec(output);
  return m ? [Number(m[1]), Number(m[2])] : undefined;
}

/** True when [version] meets [ENGINE_MIN_DART]. */
export function isDartNewEnough(version: readonly [number, number]): boolean {
  const [maj, min] = version;
  return maj > ENGINE_MIN_DART[0] || (maj === ENGINE_MIN_DART[0] && min >= ENGINE_MIN_DART[1]);
}

/**
 * The `dart` executable for the engine. A configured SDK root wins (so a user
 * with an FVM-pinned PATH can point at a second, newer SDK); blank falls back
 * to the PATH `dart`. Also reports whether a shell is needed (bare `dart` on
 * Windows must resolve `dart.bat` via PATHEXT).
 */
export function resolveEngineDart(
  sdkPath: string | undefined,
  platform: NodeJS.Platform = process.platform,
): { command: string; useShell: boolean } {
  const root = sdkPath?.trim();
  if (root) {
    const exe = platform === 'win32' ? 'dart.exe' : 'dart';
    return { command: path.join(root, 'bin', exe), useShell: false };
  }
  return { command: 'dart', useShell: platform === 'win32' };
}

/** Args that install/upgrade the engine globally. Idempotent; a no-op when current. */
export function buildEngineActivateArgs(): string[] {
  return ['pub', 'global', 'activate', 'saropa_lints'];
}

/**
 * Args for the global scan run. The project root MUST be the first positional
 * token: `parseScanArgs` takes the first non-flag token as the path, and the
 * value after `--tier` is itself a non-flag token.
 */
export function buildEngineScanArgs(projectRoot: string, tier: string): string[] {
  return ['pub', 'global', 'run', 'saropa_lints:scan', projectRoot, '--tier', tier, '--format', 'json'];
}

/**
 * Dart SDK [major, minor] the project last resolved with, from
 * `.dart_tool/version` (written by pub). Undefined when absent/unreadable so
 * callers never act on a guess.
 */
export function readProjectDartVersion(projectRoot: string): [number, number] | undefined {
  try {
    const raw = fs.readFileSync(path.join(projectRoot, '.dart_tool', 'version'), 'utf8').trim();
    const m = /^(\d+)\.(\d+)/.exec(raw);
    return m ? [Number(m[1]), Number(m[2])] : undefined;
  } catch {
    return undefined;
  }
}

/** True when the project's SDK is known and below the engine floor. */
export function projectNeedsExternalEngine(version: readonly [number, number] | undefined): boolean {
  return version !== undefined && !isDartNewEnough(version);
}
