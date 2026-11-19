/**
 * Solver probe: asks pub whether a `saropa_lints` constraint would resolve in a
 * project, without changing anything on disk.
 *
 * Runs `dart pub add --dev saropa_lints:<constraint> --dry-run` in the project
 * root. `--dry-run` prints the resolution (or the solver's failure text) and
 * writes neither pubspec.yaml nor pubspec.lock. This is the authoritative
 * answer to "can this project take that version": pub already knows every
 * transitive constraint, so the extension does not re-derive them.
 *
 * Command running and the Flutter fallback reuse `shouldRetryWithFlutter`
 * from setup.ts, the same rule `resolveDependencies` applies to `pub get`.
 * The runner is injectable so tests never spawn a process.
 */
import * as crypto from 'node:crypto';
import * as fs from 'node:fs';
import * as path from 'node:path';

export type ProbeResult =
  | { ok: true }
  | { ok: false; blockingPackage?: string; reason: string; raw: string; toolError?: undefined }
  /** The tool itself failed (not on PATH, runner error, network): no verdict on the constraint. */
  | { ok: false; toolError: true; reason: string; raw: string };

export interface RunResult {
  ok: boolean;
  stderr: string;
  stdout: string;
}

/** Runs one command in `cwd`. `useShell` is true only for `flutter` (a .bat on Windows). */
export type CommandRunner = (
  cwd: string,
  command: string,
  args: string[],
  useShell: boolean,
) => Promise<RunResult>;

/** Test seams; production callers pass nothing. */
export interface ProbeDeps {
  runner?: CommandRunner;
  /** SDK version text mixed into the cache key; default reads `dart --version`. */
  sdkVersion?: () => Promise<string>;
  shouldRetryWithFlutter?: (root: string, stderr: string) => boolean;
}

const cache = new Map<string, ProbeResult>();

/** Drops every cached probe result. */
export function clearProbeCache(): void {
  cache.clear();
}

function readOrEmpty(file: string): string {
  try {
    return fs.readFileSync(file, 'utf8');
  } catch {
    return '';
  }
}

function cacheKey(root: string, constraint: string, sdk: string): string {
  // pubspec.yaml is hashed too so two projects with no lock yet cannot collide.
  return crypto
    .createHash('sha256')
    .update(readOrEmpty(path.join(root, 'pubspec.lock')))
    .update('\0')
    .update(readOrEmpty(path.join(root, 'pubspec.yaml')))
    .update('\0')
    .update(constraint)
    .update('\0')
    .update(sdk)
    .digest('hex');
}

/** Dart/Flutter SDK text for the cache key; empty when it cannot be read. */
async function defaultSdkVersion(root: string, runner: CommandRunner): Promise<string> {
  try {
    const r = await runner(root, 'dart', ['--version'], false);
    return `${r.stdout}${r.stderr}`.trim();
  } catch {
    return '';
  }
}

/** True when the text is pub's solver verdict rather than a tooling failure. */
function looksLikeSolverText(raw: string): boolean {
  return /version solving failed|[Bb]ecause\b/.test(raw);
}

/** Default runner: the extension's own workspace command runner, loaded lazily so tests do not need `vscode`. */
const defaultRunner: CommandRunner = async (cwd, command, args, useShell) => {
  const { runInWorkspaceAsync } = await import('../setup');
  return runInWorkspaceAsync(cwd, command, args, {
    logToOutput: false,
    shell: useShell,
  });
};

/**
 * Pulls the blocking package out of pub's solver text.
 *
 * Pub phrases the blame as "<pkg> [range] depends on <dep> ...". The blocker
 * is the first such subject that is neither saropa_lints nor the root project
 * (a third-party package that caps a shared dependency). When the root project
 * itself pins the shared dependency ("t depends on analyzer 11.0.0"), the
 * pinned dependency is the blocker. An SDK failure through a dependency
 * ("depends on newpkg from path which requires SDK version") names that dependency.
 */
export function parseSolverText(raw: string): { blockingPackage?: string; reason: string } {
  const text = raw.trim();
  const reason = text
    .split(/\r?\n/)
    .map((l) => l.trim())
    .filter((l) => l.length > 0)
    .join(' ');

  const root = /[Ss]o, because (\S+) (?:depends on|requires)/.exec(text)?.[1]
    ?? /[Bb]ecause (\S+) depends on/.exec(text)?.[1];
  const skip = new Set(['saropa_lints', root ?? '']);

  const sdk = /depends on (\S+) from \w+ which requires SDK/.exec(text);
  if (sdk) return { blockingPackage: sdk[1], reason };

  const subject = /(?:[Bb]ecause|[Aa]nd because|[Ss]o, because) (?!saropa_lints\b)([a-z_][a-z0-9_]*)(?: [^.]*?)? depends on/g;
  for (const m of text.matchAll(subject)) {
    if (!skip.has(m[1])) return { blockingPackage: m[1], reason };
  }

  if (root) {
    const rootDep = new RegExp(`\\b${root}\\b depends on (?:both )?([a-z_][a-z0-9_]*)\\b`).exec(text);
    if (rootDep && !skip.has(rootDep[1])) return { blockingPackage: rootDep[1], reason };
  }
  return { reason };
}

/**
 * Would `saropa_lints:<constraint>` resolve in `root`? Nothing is written.
 *
 * Results are cached by the pubspec.lock + pubspec.yaml content and the
 * constraint, so re-asking about an unchanged project is free. The key also
 * includes the SDK version text. A tooling failure (no solver text) is
 * returned as `toolError` and never cached.
 */
export async function probeConstraint(
  root: string,
  constraint: string,
  deps: ProbeDeps = {},
): Promise<ProbeResult> {
  const runner = deps.runner ?? defaultRunner;
  const sdk = await (deps.sdkVersion ? deps.sdkVersion() : defaultSdkVersion(root, runner));
  const key = cacheKey(root, constraint, sdk);
  const hit = cache.get(key);
  if (hit) return hit;

  const args = ['pub', 'add', '--dev', `saropa_lints:${constraint}`, '--dry-run'];
  let res: RunResult;
  try {
    res = await runner(root, 'dart', args, false);
    if (!res.ok) {
      const retry = deps.shouldRetryWithFlutter ?? (await import('../setup')).shouldRetryWithFlutter;
      if (retry(root, res.stderr)) {
        res = await runner(root, 'flutter', args, true);
      }
    }
  } catch (err) {
    const detail = err instanceof Error ? err.message : String(err);
    return { ok: false, toolError: true, reason: detail, raw: detail };
  }

  let result: ProbeResult;
  if (res.ok) {
    result = { ok: true };
  } else {
    const raw = res.stderr.trim() || res.stdout.trim();
    if (!looksLikeSolverText(raw)) {
      return {
        ok: false,
        toolError: true,
        reason: raw || 'dart pub add --dry-run failed with no output',
        raw,
      };
    }
    const parsed = parseSolverText(raw);
    result = {
      ok: false,
      ...(parsed.blockingPackage ? { blockingPackage: parsed.blockingPackage } : {}),
      reason: parsed.reason || 'dart pub add --dry-run failed with no output',
      raw,
    };
  }
  cache.set(key, result);
  return result;
}
