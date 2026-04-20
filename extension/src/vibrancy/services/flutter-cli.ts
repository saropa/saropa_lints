import { execFile } from 'child_process';

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
 * Shell flag for child process spawning on Windows.
 *
 * Flutter installs `dart` and `flutter` as `.bat` files on Windows.
 * Node's `execFile('dart', ...)` does NOT consult `PATHEXT`, so the
 * lookup fails with ENOENT even when `dart` is fully on PATH and
 * runs fine from a terminal. Routing through a shell (cmd.exe) lets
 * the OS resolve the `.bat` extension the same way a user shell
 * does. Args here are all hardcoded (e.g. `['pub', 'deps', '--json']`)
 * and `cwd` is a workspace folder path we control — no injection risk.
 */
const USE_SHELL = process.platform === 'win32';

function runFlutterCommand(
    args: string[], cwd: string, timeout: number,
): Promise<CommandResult> {
    return new Promise((resolve) => {
        execFile(
            'flutter', args,
            { encoding: 'utf-8', timeout, cwd, shell: USE_SHELL },
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

function runDartCommand(
    args: string[], cwd: string, timeout: number,
): Promise<CommandResult> {
    return new Promise((resolve) => {
        execFile(
            'dart', args,
            { encoding: 'utf-8', timeout, cwd, shell: USE_SHELL },
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

/** Run `dart pub outdated --json` in the given directory. */
export function runDartPubOutdated(cwd: string): Promise<CommandResult> {
    return runDartCommand(['pub', 'outdated', '--json'], cwd, 120_000);
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
