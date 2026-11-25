/**
 * Module overview (comment coverage pass).
 * comment-coverage: module overview (batch).
 *
 * Vibrancy UI experiment: scoring, providers, and webview assets.
 */

import { execFile } from 'child_process';
import * as fs from 'node:fs';
import * as path from 'node:path';
import { parseDepSpecs, usesFlutterSdk } from './pub-dep-specs';
import type { ResolvedDart } from '../../debug/lspResolution';
import {
    describeGuard, guardPubCommand, resolveDartForProject, workspaceFolderOf, resolveFlutterForProject,
    shellSafeCommand,
} from './sdk-toolchain';

/** Result of a Flutter CLI command execution. */
export interface CommandResult {
    readonly success: boolean;
    readonly output: string;
    /**
     * Node error message when the process failed to spawn or exited
     * with non-zero status. Populated only on failure so callers can
     * log a concrete reason instead of a generic "CLI failed".
     */
    readonly errorMessage?: string;
}

/**
 * Spawns [exe] and folds the result into a [CommandResult].
 *
 * Shell use is decided by the resolver (`exe.useShell`): bare PATH `dart` /
 * `flutter` on Windows are `.bat` files that `execFile` cannot find without a
 * shell (PATHEXT is not consulted), while absolute SDK paths need none. Args
 * are hardcoded and `cwd` is a workspace path we control — no injection risk.
 */
function spawnCommand(
    exe: ResolvedDart, args: string[], cwd: string, timeout: number,
): Promise<CommandResult> {
    return new Promise((resolve) => {
        execFile(
            // Quote absolute SDK paths with spaces when a shell is in play.
            shellSafeCommand(exe.command, exe.useShell), args,
            { encoding: 'utf-8', timeout, cwd, shell: exe.useShell },
            (err, stdout, stderr) => {
                resolve({
                    success: !err,
                    output: (stdout || '') + (stderr || ''),
                    errorMessage: err ? err.message : undefined,
                });
            },
        );
    });
}

/**
 * Bug fix: `flutter` used to be spawned by bare name from the host PATH, so a
 * newer global SDK ran against an FVM-pinned project. Resolve the workspace's
 * SDK instead (settings -> FVM pin -> PATH).
 */
function runFlutterCommand(
    args: string[], cwd: string, timeout: number,
): Promise<CommandResult> {
    return spawnCommand(resolveFlutterForProject(cwd), args, cwd, timeout);
}

/**
 * Runs a READ-ONLY `dart pub` query. Bug fix: bare PATH `dart` re-resolved the
 * project with the wrong SDK and rewrote pubspec.lock / package_config.json.
 * Now (1) the workspace SDK is used and (2) when that SDK still differs from
 * the one that last resolved the project, the command is NOT run, because pub
 * would re-resolve and mutate the lockfile. A skipped run reports failure with
 * the reason so callers degrade like any other CLI failure.
 */
async function runDartCommand(
    args: string[], cwd: string, timeout: number,
): Promise<CommandResult> {
    const dart = resolveDartForProject(cwd);
    const guard = await guardPubCommand(cwd, dart, { stopAt: workspaceFolderOf(cwd) });
    if (!guard.safe) {
        // The guard already recorded this skip (status-bar item + "Explain Last
        // Vibrancy Skip"); the same localized text is the failure reason.
        const reason = describeGuard(guard);
        return { success: false, output: '', errorMessage: reason };
    }
    return spawnCommand(dart, args, cwd, timeout);
}

/**
 * Run `dart pub outdated --json --transitive` in the given directory.
 *
 * `--transitive` is required so contested SHARED transitive deps (analyzer,
 * meta, characters, …) appear in the output with their own resolvable/latest.
 * Diamond-conflict detection pivots on those rows: a direct dep is held back
 * because a sibling caps a shared transitive dep below the version the direct
 * dep needs. Without `--transitive` the pivot dep is invisible and the block
 * looks like an unexplained "constrained" with no named blocker. Adding
 * transitive rows is strictly more data — direct-dep classification still
 * keys off the direct entries, so the extra rows do not change it.
 */
export function runDartPubOutdated(cwd: string): Promise<CommandResult> {
    return runDartCommand(
        ['pub', 'outdated', '--json', '--transitive'], cwd, 120_000,
    );
}

/** Run `dart pub deps --json` in the given directory. */
export function runDartPubDeps(cwd: string): Promise<CommandResult> {
    return runDartCommand(['pub', 'deps', '--json'], cwd, 60_000);
}

/** Run `flutter pub get` in the given directory. */
export function runPubGet(cwd: string): Promise<CommandResult> {
    return runFlutterCommand(['pub', 'get'], cwd, 60_000);
}

/** Run `flutter test` in the given directory. */
export function runFlutterTest(cwd: string): Promise<CommandResult> {
    return runFlutterCommand(['test'], cwd, 300_000);
}

/** Which tool `pub get` should use for a project, and the resolved executable. */
export interface PubGetPlan {
    readonly tool: 'dart' | 'flutter';
    readonly exe: ResolvedDart;
}

/**
 * Chooses `flutter pub get` for projects that depend on the Flutter SDK
 * (`sdk: flutter`) and `dart pub get` otherwise. Why: a pure-Dart project with
 * only `dart.sdkPath` set has no Flutter SDK configured, so always running
 * `flutter` would fall back to the PATH Flutter, the exact wrong-SDK situation
 * this guard exists to prevent. An unreadable pubspec defaults to flutter (the
 * pre-existing behavior).
 */
export function planPubGet(cwd: string): PubGetPlan {
    let flutter = true;
    try {
        flutter = usesFlutterSdk(parseDepSpecs(fs.readFileSync(path.join(cwd, 'pubspec.yaml'), 'utf8')));
    } catch {
        // Unreadable pubspec: keep the default (flutter).
    }
    return flutter
        ? { tool: 'flutter', exe: resolveFlutterForProject(cwd) }
        : { tool: 'dart', exe: resolveDartForProject(cwd) };
}

/**
 * Runs `pub get` with the project's own SDK per [planPubGet]. This is the
 * user-initiated remedy for a guard skip, so it is deliberately NOT guarded:
 * rewriting the lock is its job.
 */
export function runPubGetWithProjectSdk(cwd: string): Promise<CommandResult> {
    return spawnCommand(planPubGet(cwd).exe, ['pub', 'get'], cwd, 120_000);
}
