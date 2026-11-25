/**
 * SDK toolchain resolution for the Vibrancy CLI wrapper (`flutter-cli.ts`).
 *
 * Why this exists: the wrapper used to spawn bare `dart` / `flutter` from the
 * extension host's PATH. In a project pinned to an older SDK (FVM), the PATH
 * SDK is a different, newer one; `dart pub outdated` / `dart pub deps` then
 * re-resolve the project and rewrite `pubspec.lock` and
 * `.dart_tool/package_config.json` against the wrong SDK. This module picks
 * the workspace's SDK (reusing the LSP launcher's resolver so there is ONE
 * resolution order) and decides whether a read-only pub command is safe.
 */

import * as fs from 'node:fs';
import * as path from 'node:path';
import { execFile } from 'node:child_process';
import * as semver from 'semver';
import {
    resolveDartExecutable, resolveFlutterExecutable, DartSdkSettings, ResolvedDart,
} from '../../debug/lspResolution';
import { l10n } from '../../i18n/runtime';
import { parsePubspecYaml, parsePubspecLock } from './pubspec-parser';
import { recordGuardOutcome } from './pub-guard-record';
import { parseDepSpecs, DepSpec } from './pub-dep-specs';

/** Loads `vscode` lazily so the pure helpers stay importable outside an extension host. */
function tryVscode(): typeof import('vscode') | undefined {
    try {
        // eslint-disable-next-line @typescript-eslint/no-require-imports
        return require('vscode') as typeof import('vscode');
    } catch {
        // Not running inside an extension host (plain mocha): no settings, no UI.
        return undefined;
    }
}

/**
 * The workspace folder containing [cwd], or undefined. Used as the scope for
 * `dart.*` settings (multi-root workspaces can pin different SDKs per folder)
 * and as the base for relative SDK paths.
 */
export function workspaceFolderOf(cwd: string): string | undefined {
    const vscode = tryVscode();
    try {
        return vscode?.workspace.getWorkspaceFolder(vscode.Uri.file(cwd))?.uri.fsPath;
    } catch {
        // Mock/partial vscode without Uri or getWorkspaceFolder: treat as no folder.
        return undefined;
    }
}

/** Reads Dart-Code's `dart.sdkPath` / `dart.flutterSdkPath`, scoped to [cwd]'s workspace folder. */
export function readDartSdkSettings(cwd?: string): DartSdkSettings {
    const vscode = tryVscode();
    if (!vscode) { return {}; }
    try {
        // Scope to the folder so a multi-root workspace reads that folder's override.
        const scope = cwd ? vscode.Uri.file(cwd) : undefined;
        const cfg = vscode.workspace.getConfiguration('dart', scope);
        return {
            dartSdkPath: cfg.get<string>('sdkPath') ?? undefined,
            flutterSdkPath: cfg.get<string>('flutterSdkPath') ?? undefined,
        };
    } catch {
        // Settings API unavailable/throwing: behave as "nothing configured" (FVM / PATH).
        return {};
    }
}

/**
 * Directory against which relative SDK settings and the `.fvm` pin resolve.
 * Walks up from [cwd] to the containing workspace folder looking for
 * `.fvm/flutter_sdk` (a pubspec in a sub-package of a monorepo is pinned by the
 * FVM dir at the repo root, not next to it). Falls back to the workspace folder
 * (where users write relative `dart.sdkPath`), then [cwd].
 */
export function findSdkBase(
    cwd: string,
    workspaceFolder: string | undefined,
    exists: (p: string) => boolean = fs.existsSync,
): string {
    let dir = cwd;
    for (;;) {
        if (exists(path.join(dir, '.fvm', 'flutter_sdk'))) { return dir; }
        const parent = path.dirname(dir);
        // Stop at the workspace folder (do not climb out of the user's project)
        // or at the filesystem root (dirname fixed point).
        if (dir === workspaceFolder || parent === dir) { break; }
        dir = parent;
    }
    return workspaceFolder ?? cwd;
}

/**
 * Quotes a command for `shell: true` spawning. Node joins command and args with
 * spaces under a shell, so an absolute SDK path containing a space (e.g.
 * `C:\Program Files\...`) would be split without quoting.
 */
export function shellSafeCommand(command: string, useShell: boolean): string {
    return useShell && command.includes(' ') && !command.startsWith('"')
        ? `"${command}"` : command;
}

/** Extracts `3.8.1` from `Dart SDK version: 3.8.1 (stable) ...`; undefined if absent. */
export function parseDartVersion(text: string): string | undefined {
    const m = /Dart SDK version:\s*(\d+\.\d+\.\d+(?:-[0-9A-Za-z.\-]+)?)/.exec(text);
    return m ? m[1] : undefined;
}

/** Reads a UTF-8 file; injectable for tests. */
type ReadFile = (p: string) => string;
const realRead: ReadFile = (p) => fs.readFileSync(p, 'utf8');

/**
 * The SDK version pub last resolved this project with (`.dart_tool/version`,
 * written by pub). Undefined when absent/unreadable.
 */
export function readProjectSdkVersion(projectRoot: string, readFile: ReadFile = realRead): string | undefined {
    try {
        const v = readFile(path.join(projectRoot, '.dart_tool', 'version')).trim();
        return v || undefined;
    } catch {
        // No .dart_tool/version: project never resolved (or file unreadable).
        return undefined;
    }
}

/**
 * Dart SDK constraint pub recorded in `pubspec.lock` (`sdks:` -> `dart: "..."`).
 * Fallback evidence when `.dart_tool/version` is missing. Undefined if absent.
 */
export function readLockDartConstraint(projectRoot: string, readFile: ReadFile = realRead): string | undefined {
    try {
        const text = readFile(path.join(projectRoot, 'pubspec.lock'));
        const m = /^sdks:\s*\r?\n(?:[ \t]+.*\r?\n)*?[ \t]+dart:\s*["']?([^"'\r\n]+)["']?/m.exec(text);
        return m ? m[1].trim() : undefined;
    } catch {
        // No/unreadable lockfile: no constraint to enforce.
        return undefined;
    }
}

/**
 * Evaluates [version] against a pub constraint (SDK constraint from
 * pubspec.lock, or a dependency constraint from pubspec.yaml) using `semver`.
 *
 * Why semver and `includePrerelease`: pub's caret/range syntax is semver's
 * (`^0.0.3` -> `<0.0.4`, `^0.2.1` -> `<0.3.0`, `>=2.17.0-0 <4.0.0`), and
 * `includePrerelease` gives pub's ordering where a prerelease sorts BEFORE its
 * release (`3.8.0-dev` does not satisfy `>=3.8.0`; `4.0.0-dev` does not
 * satisfy `<4.0.0`).
 *
 * Returns UNDEFINED for empty/malformed/unsupported input (including `||`,
 * which pub does not support): the caller must treat that as "unknown", never
 * as a pass, because silently passing a constraint we cannot read is how the
 * wrong SDK got through before.
 */
export function satisfiesDartConstraint(version: string, constraint: string): boolean | undefined {
    const text = constraint.replace(/["']/g, '').trim();
    if (!text || text.includes('||')) { return undefined; }
    const v = semver.valid(version.trim());
    if (!v) { return undefined; }
    if (text === 'any') { return true; }
    // pub excludes the prereleases of an exclusive upper bound (`<4.0.0` does not
    // admit `4.0.0-dev`); semver only does that for caret/tilde, so rewrite
    // plain `<X.Y.Z` bounds to `<X.Y.Z-0` (the lowest prerelease) first.
    const pubText = text.replace(/(^|\s)<(\d+\.\d+\.\d+)(?![-+\d.])/g, '$1<$2-0');
    const range = semver.validRange(pubText, { includePrerelease: true });
    // validRange returns null for text semver cannot parse.
    if (!range) { return undefined; }
    return semver.satisfies(v, range, { includePrerelease: true });
}

/**
 * Version of a Dart SDK located by an absolute `<sdk>/bin/dart` path, read from
 * the `version` file at the SDK root. The two-levels-up step assumes the
 * standard SDK layout (`<root>/bin/dart[.exe]`); any other layout simply has no
 * `version` file there and yields undefined (then the caller probes instead).
 */
export function readSdkVersionFromExecutable(dartExe: string, readFile: ReadFile = realRead): string | undefined {
    // A bare name came from a PATH lookup: there is no directory to read.
    if (!path.isAbsolute(dartExe)) { return undefined; }
    try {
        const v = readFile(path.join(path.dirname(path.dirname(dartExe)), 'version')).trim();
        return v || undefined;
    } catch {
        return undefined;
    }
}

/** Outcome of the pre-flight check for a pub command that could rewrite the lockfile. */
export interface SdkGuardResult {
    readonly safe: boolean;
    /** l10n key of the skip reason; set only when `safe` is false. */
    readonly reasonKey?: string;
    readonly reasonParams?: Record<string, string>;
}

/**
 * Pure SDK decision. Evidence order: the version pub last resolved with
 * (`.dart_tool/version`), else the `sdks: dart:` constraint in pubspec.lock.
 * A bare-PATH `dart` whose version cannot be learned is refused: it is the
 * exact configuration that caused the bug, and "unknown" must not mean "safe".
 * A configured/FVM SDK with unreadable version is allowed (the user chose it).
 */
export function checkSdkCompatibility(
    projectSdkVersion: string | undefined,
    lockConstraint: string | undefined,
    toolSdkVersion: string | undefined,
    source: ResolvedDart['source'],
): SdkGuardResult {
    if (!toolSdkVersion) {
        return source === 'path'
            ? { safe: false, reasonKey: 'pubGuard.unknownPathSdk' }
            : { safe: true };
    }
    if (projectSdkVersion) {
        return projectSdkVersion === toolSdkVersion
            ? { safe: true }
            : {
                safe: false, reasonKey: 'pubGuard.sdkMismatch',
                reasonParams: { project: projectSdkVersion, tool: toolSdkVersion },
            };
    }
    // No .dart_tool/version: fall back to what the lockfile says the SDK must satisfy.
    const verdict = lockConstraint ? satisfiesDartConstraint(toolSdkVersion, lockConstraint) : undefined;
    if (verdict === false) {
        return {
            safe: false, reasonKey: 'pubGuard.lockSdkConstraint',
            reasonParams: { constraint: lockConstraint ?? '', tool: toolSdkVersion },
        };
    }
    // Missing/unparseable constraint (verdict undefined) = the project's SDK is
    // unknown. Same rule as an unknown tool version: a bare PATH SDK is the
    // configuration that caused the bug, so it is refused; a configured/FVM SDK
    // was chosen by the user and is allowed.
    if (verdict === undefined && source === 'path') {
        return { safe: false, reasonKey: 'pubGuard.unknownPathSdk' };
    }
    return { safe: true };
}

/** Filesystem/process access for the guard; injectable for tests. */
export interface GuardIo {
    readonly readFile: ReadFile;
    readonly mtimeMs: (p: string) => number | undefined;
    readonly probe: (command: string, useShell: boolean) => Promise<string | undefined>;
}

/** Package names listed in a package_config.json; undefined when unreadable/malformed. */
function configPackageNames(text: string): Set<string> | undefined {
    try {
        const pkgs = (JSON.parse(text) as { packages?: Array<{ name?: unknown }> }).packages;
        if (!Array.isArray(pkgs)) { return undefined; }
        return new Set(pkgs.map((p) => p?.name).filter((n): n is string => typeof n === 'string'));
    } catch {
        // Malformed JSON: caller treats it as "config does not list the locked packages".
        return undefined;
    }
}

/**
 * First directory at or above [projectRoot] that holds a `pubspec.lock`.
 * Why: `resolution: workspace` members have no lock or `.dart_tool` of their
 * own; pub keeps both at the workspace root, so judging a member by its own
 * folder would refuse it forever with a misleading "lock missing". [stopAt]
 * (the VS Code workspace folder) bounds the climb. Falls back to
 * [projectRoot] when no lock exists anywhere, which then reports the missing
 * lock honestly.
 */
export function findLockRoot(
    projectRoot: string,
    stopAt: string | undefined,
    mtimeMs: (p: string) => number | undefined,
): string {
    let dir = projectRoot;
    for (;;) {
        if (mtimeMs(path.join(dir, 'pubspec.lock')) !== undefined) { return dir; }
        const parent = path.dirname(dir);
        // Do not climb out of the workspace folder, or past the filesystem root.
        if (dir === stopAt || parent === dir) { break; }
        dir = parent;
    }
    return projectRoot;
}

/**
 * Decides whether pub WOULD re-resolve (and so rewrite pubspec.lock) for the
 * project at [projectRoot], mirroring pub's own `Entrypoint.isResolutionUpToDate`
 * (dart-lang/pub, lib/src/entrypoint.dart) rather than a stricter mtime rule.
 * [lockRoot] is where pubspec.lock / .dart_tool live (differs from
 * [projectRoot] for workspace members; see [findLockRoot]).
 *
 *  1. `.dart_tool/package_config.json` missing -> pub resolves (no existing
 *     resolution). `pubspec.lock` missing -> pub resolves.
 *  2. Fast path: pubspec.lock STRICTLY newer than pubspec.yaml,
 *     pubspec_overrides.yaml AND every path dependency's pubspec.yaml (member
 *     and workspace root), and package_config.json not older than the lock
 *     -> up to date, nothing else is checked.
 *  3. Otherwise pub does CONTENT checks and, if they pass, only touches
 *     mtimes (git-checkout skew lands here and is NOT a re-resolve). We
 *     approximate those checks:
 *       - a path dependency whose pubspec is newer than the lock -> refuse
 *         (pub re-reads it and may re-resolve; not worth emulating);
 *       - lock out of date vs pubspecs: every declared dependency (deps,
 *         dev_deps, dependency_overrides, pubspec_overrides.yaml) must be in
 *         the lock AND its locked version must satisfy the declared
 *         constraint (pub's `isLockFileUpToDate`). Anything we cannot evaluate
 *         (git, unparseable constraint, inline maps) counts as "pub may
 *         re-resolve";
 *       - config older than lock: every locked package must be listed in
 *         package_config.json.
 *  The SDK-change trigger of pub's check (generatorVersion / Flutter root) is
 *  covered separately by [checkSdkCompatibility].
 */
export function checkFreshness(
    projectRoot: string,
    io: Pick<GuardIo, 'mtimeMs' | 'readFile'>,
    lockRoot: string = projectRoot,
): SdkGuardResult {
    const lockPath = path.join(lockRoot, 'pubspec.lock');
    const cfgPath = path.join(lockRoot, '.dart_tool', 'package_config.json');
    // No pubspec.yaml in the member folder: nothing pub could resolve here.
    if (io.mtimeMs(path.join(projectRoot, 'pubspec.yaml')) === undefined) { return { safe: true }; }
    const lock = io.mtimeMs(lockPath);
    if (lock === undefined) { return { safe: false, reasonKey: 'pubGuard.staleLock' }; }
    const cfg = io.mtimeMs(cfgPath);
    if (cfg === undefined) { return { safe: false, reasonKey: 'pubGuard.staleConfig' }; }

    // Both the member's and (for workspaces) the root's pubspecs feed the resolution.
    const roots = lockRoot === projectRoot ? [projectRoot] : [projectRoot, lockRoot];
    let newest = -Infinity;
    let newestPathDep: string | undefined;
    const specs: DepSpec[] = [];
    try {
        for (const root of roots) {
            for (const file of ['pubspec.yaml', 'pubspec_overrides.yaml']) {
                const full = path.join(root, file);
                const m = io.mtimeMs(full);
                if (m === undefined) { continue; }
                newest = Math.max(newest, m);
                const parsed = parseDepSpecs(io.readFile(full));
                specs.push(...parsed);
                // pub also compares each path dependency's own pubspec.yaml to the lock.
                for (const s of parsed.filter((d) => d.kind === 'path' && d.path)) {
                    const pm = io.mtimeMs(path.resolve(root, s.path ?? '', 'pubspec.yaml'));
                    if (pm !== undefined && pm > lock) { newestPathDep = s.name; }
                    if (pm !== undefined) { newest = Math.max(newest, pm); }
                }
            }
        }
    } catch {
        // Cannot read the files pub would read: cannot prove pub stays read-only.
        return { safe: false, reasonKey: 'pubGuard.staleLock' };
    }
    const lockNewer = lock > newest;
    const configCurrent = cfg >= lock;
    // pub's fast path: nothing further is inspected.
    if (lockNewer && configCurrent) { return { safe: true }; }
    if (newestPathDep) {
        return { safe: false, reasonKey: 'pubGuard.pathDepNewer', reasonParams: { name: newestPathDep } };
    }

    try {
        if (!lockNewer) {
            const verdict = checkLockedConstraints(specs, io.readFile(lockPath));
            if (!verdict.safe) { return verdict; }
        }
        if (!configCurrent) {
            const inConfig = configPackageNames(io.readFile(cfgPath));
            const locked = parsePubspecLock(io.readFile(lockPath), []).map((p) => p.name);
            if (!inConfig || locked.some((n) => !inConfig.has(n))) {
                return { safe: false, reasonKey: 'pubGuard.staleConfig' };
            }
        }
    } catch {
        // Cannot read the files pub would read: cannot prove pub stays read-only.
        return { safe: false, reasonKey: 'pubGuard.staleLock' };
    }
    // Content is consistent: pub would only touch timestamps (git-checkout skew).
    return { safe: true };
}

/**
 * pub's `isLockFileUpToDate` approximation: every declared dependency is
 * locked and the locked version satisfies the declared constraint. A
 * constraint edit (`^1.0.0` -> `^2.0.0`) makes pub re-resolve even though the
 * package NAMES are unchanged, which is why names alone are not enough.
 */
function checkLockedConstraints(specs: readonly DepSpec[], lockText: string): SdkGuardResult {
    const locked = new Map(parsePubspecLock(lockText, []).map((p) => [p.name, p.version]));
    for (const s of specs) {
        const version = locked.get(s.name);
        if (version === undefined) { return { safe: false, reasonKey: 'pubGuard.depsNotLocked' }; }
        // sdk deps are pinned by the SDK and path deps are covered by the mtime check.
        if (s.kind === 'sdk' || s.kind === 'path') { continue; }
        // git / inline-map / unrecognized forms cannot be evaluated here.
        if (s.kind !== 'hosted') { return { safe: false, reasonKey: 'pubGuard.constraintUnverifiable' }; }
        // Hosted with no declared constraint accepts any version.
        if (!s.constraint) { continue; }
        const ok = satisfiesDartConstraint(version, s.constraint);
        if (ok === undefined) { return { safe: false, reasonKey: 'pubGuard.constraintUnverifiable' }; }
        if (!ok) {
            return {
                safe: false, reasonKey: 'pubGuard.constraintNotSatisfied',
                reasonParams: { name: s.name, version, constraint: s.constraint },
            };
        }
    }
    return { safe: true };
}

/**
 * How long a successful `dart --version` probe stays valid. Also the accepted
 * staleness bound for a change we cannot observe: an FVM `flutter_sdk` symlink
 * retargeted outside the watched files, or an SDK upgraded in place, is picked
 * up at the latest when this TTL expires (a 5-minute window of at most one
 * wrong probe is acceptable; the SDK `version` file read has no such window).
 */
const PROBE_TTL_MS = 5 * 60 * 1000;

/** Runs `<command> --version`; resolves its text, or undefined on error/timeout. */
export type VersionRunner = (command: string, useShell: boolean) => Promise<string | undefined>;

const defaultVersionRunner: VersionRunner = (command, useShell) => new Promise((resolve) => {
    execFile(
        shellSafeCommand(command, useShell), ['--version'],
        { encoding: 'utf-8', timeout: 15_000, shell: useShell },
        (err, stdout, stderr) => resolve(err ? undefined : parseDartVersion(`${stdout || ''}${stderr || ''}`)),
    );
});

/** Probe cache keyed by command + PATH, holding the in-flight promise so concurrent calls share one spawn. */
const probeCache = new Map<string, { at: number; promise: Promise<string | undefined> }>();

/**
 * Forgets every cached `dart --version` probe. Called when the SDK selection
 * can have changed (dart.* settings, FVM pin files) so a stale version never
 * validates a different SDK.
 */
export function resetProbeCache(): void {
    probeCache.clear();
}

/**
 * Asks `dart` for its version. Concurrent callers share one in-flight spawn;
 * successes are cached for [PROBE_TTL_MS] keyed by command+PATH; failures
 * (undefined) are evicted immediately so a transient timeout is retried
 * instead of poisoning the session as "unknown".
 */
export function probeDartVersion(
    command: string,
    useShell: boolean,
    run: VersionRunner = defaultVersionRunner,
    now: () => number = Date.now,
): Promise<string | undefined> {
    const key = `${command}\u0000${process.env.PATH ?? ''}`;
    const hit = probeCache.get(key);
    if (hit && now() - hit.at < PROBE_TTL_MS) { return hit.promise; }
    const promise = run(command, useShell);
    const entry = { at: now(), promise };
    probeCache.set(key, entry);
    void promise.then((v) => {
        // Only evict our own entry; a newer probe may have replaced it.
        if (v === undefined && probeCache.get(key) === entry) { probeCache.delete(key); }
    });
    return promise;
}

/** True when a configuration change can alter which SDK is selected. */
export function affectsSdkSelection(affects: (section: string) => boolean): boolean {
    return affects('dart.sdkPath') || affects('dart.flutterSdkPath');
}

/**
 * Wires cache invalidation to the things that change the selected SDK: the
 * `dart.sdkPath` / `dart.flutterSdkPath` settings and the FVM pin files
 * (`.fvmrc`, `.fvm/fvm_config.json`, `.fvm/flutter_sdk`). Without it a probe
 * result cached for the old SDK would validate the new one for up to the TTL.
 * Returns disposables the caller must push to `context.subscriptions`.
 */
export function registerSdkCacheInvalidation(): Array<{ dispose(): unknown }> {
    const vscode = tryVscode();
    // Outside an extension host there is nothing to listen to.
    if (!vscode) { return []; }
    const disposables: Array<{ dispose(): unknown }> = [];
    disposables.push(vscode.workspace.onDidChangeConfiguration((e) => {
        if (affectsSdkSelection((s) => e.affectsConfiguration(s))) { resetProbeCache(); }
    }));
    for (const glob of ['**/.fvmrc', '**/.fvm/fvm_config.json', '**/.fvm/flutter_sdk', '**/.fvm/flutter_sdk/version']) {
        const w = vscode.workspace.createFileSystemWatcher(glob);
        // Any create/change/delete of a pin file can re-point the SDK.
        disposables.push(w, w.onDidChange(resetProbeCache), w.onDidCreate(resetProbeCache), w.onDidDelete(resetProbeCache));
    }
    return disposables;
}

const realIo: GuardIo = {
    readFile: realRead,
    mtimeMs: (p) => {
        try { return fs.statSync(p).mtimeMs; } catch { return undefined; }
    },
    probe: (c, s) => probeDartVersion(c, s),
};

/** Optional collaborators for [guardPubCommand]; all default to the real thing. */
export interface GuardOptions {
    readonly io?: GuardIo;
    readonly now?: () => number;
    /** VS Code workspace folder; bounds the climb to a workspace-root lock. */
    readonly stopAt?: string;
}

/**
 * Pre-flight for read-only pub commands. Refuses (safe=false) when pub would
 * mutate pubspec.lock: it would re-resolve per [checkFreshness], or the
 * resolved SDK differs from / does not satisfy the one that resolved the
 * project. Every outcome is recorded (per project folder) for "Explain Last
 * Vibrancy Skip" and the status-bar item.
 */
export async function guardPubCommand(
    cwd: string,
    dart: ResolvedDart,
    options: GuardOptions = {},
): Promise<SdkGuardResult> {
    const io = options.io ?? realIo;
    const now = options.now ?? Date.now;
    // Workspace members keep lock + .dart_tool at the workspace root.
    const lockRoot = findLockRoot(cwd, options.stopAt, io.mtimeMs);
    const projectVersion = readProjectSdkVersion(lockRoot, io.readFile);
    const lockConstraint = readLockDartConstraint(lockRoot, io.readFile);
    let toolVersion: string | undefined;
    let result = checkFreshness(cwd, io, lockRoot);
    // Skip the (possibly spawning) SDK probe when freshness already refused.
    if (result.safe) {
        // Prefer the SDK's own version file; probe only when it is not available.
        toolVersion = readSdkVersionFromExecutable(dart.command, io.readFile)
            ?? await io.probe(dart.command, dart.useShell);
        result = checkSdkCompatibility(projectVersion, lockConstraint, toolVersion, dart.source);
    }
    recordGuardOutcome(result.safe, {
        at: now(), cwd, sdkCommand: dart.command, sdkSource: dart.source,
        projectVersion,
        projectVersionSource: projectVersion ? 'dartToolVersion' : lockConstraint ? 'lockConstraint' : 'none',
        lockConstraint, toolVersion,
        reasonKey: result.reasonKey ?? '', reasonParams: result.reasonParams,
    });
    return result;
}

/** Localized, human-readable skip reason for a refused guard result. */
export function describeGuard(g: SdkGuardResult): string {
    return g.reasonKey ? l10n(g.reasonKey, g.reasonParams) : '';
}

/** Resolves `dart` for [cwd] from the workspace settings / FVM pin / PATH. */
export function resolveDartForProject(cwd: string): ResolvedDart {
    const base = findSdkBase(cwd, workspaceFolderOf(cwd));
    return resolveDartExecutable(base, readDartSdkSettings(cwd));
}

/** Resolves `flutter` for [cwd] from the workspace settings / FVM pin / PATH. */
export function resolveFlutterForProject(cwd: string): ResolvedDart {
    const base = findSdkBase(cwd, workspaceFolderOf(cwd));
    return resolveFlutterExecutable(base, readDartSdkSettings(cwd));
}
